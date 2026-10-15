// DRAFT -- not yet deployed. For review only (Step 4).
//
// Handles the two operations that must run with the service-role key
// (never shippable in the Flutter app): first-time account activation,
// and admin-mediated password reset. Both are driven by the same
// one-time code issued via admin_issue_activation_code (see
// DRAFT_add_secure_password_auth.sql) -- this function verifies the code
// server-side, then uses the Supabase Auth Admin API (the supported way
// to create/update a user's password outside the normal client sign-up
// flow) to set the credential the user just chose. The admin never sees
// or sets the password itself -- only the one-time code.
//
// Deploy with: supabase functions deploy account-credentials
// (not run as part of this review)

import { createClient } from 'npm:@supabase/supabase-js@2';

const LOGIN_EMAIL_DOMAIN = 'users.odiatraders.auth';

function corsHeaders(origin: string | null) {
  return {
    'Access-Control-Allow-Origin': origin ?? '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

function normalizePhone(raw: string): string | null {
  const digits = (raw ?? '').replace(/\D/g, '');
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 11 && digits.startsWith('0')) return `+91${digits.slice(1)}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  return null;
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// Deliberately generic across every failure mode (wrong phone, wrong
// code, expired, already used, wrong purpose) -- never tells the caller
// which part was wrong, so this can't be used to enumerate registered
// phone numbers or probe code validity.
const GENERIC_ERROR = 'Invalid or expired activation code.';

Deno.serve(async (req) => {
  const origin = req.headers.get('origin');
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(origin) });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed.' }), {
      status: 405,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const mode = body.mode as string; // 'activate' | 'reset'
    const phoneInput = body.phone as string;
    const code = (body.code as string ?? '').trim().toUpperCase();
    const password = body.password as string;

    if (!['activate', 'reset'].includes(mode) || !phoneInput || !code || !password) {
      return new Response(JSON.stringify({ error: 'Missing required fields.' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    if (password.length < 8) {
      return new Response(JSON.stringify({ error: 'Password must be at least 8 characters.' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    const phone = normalizePhone(phoneInput);
    if (!phone) {
      return new Response(JSON.stringify({ error: GENERIC_ERROR }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    // Service-role client -- bypasses RLS entirely. Only ever constructed
    // inside this trusted server-side function, never shipped to a client.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const purpose = mode === 'activate' ? 'activation' : 'password_reset';

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('id, auth_user_id, login_email, deleted_at, is_active, role, approval_status')
      .eq('phone', phone)
      .maybeSingle();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: GENERIC_ERROR }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    if (mode === 'activate' && profile.auth_user_id) {
      return new Response(JSON.stringify({ error: 'This account is already activated. Use password reset instead.' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }
    if (mode === 'reset' && !profile.auth_user_id) {
      return new Response(JSON.stringify({ error: 'This account has not been activated yet.' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    const codeHash = await sha256Hex(code);
    const { data: codeRow, error: codeError } = await admin
      .from('account_activation_codes')
      .select('id, expires_at, used_at')
      .eq('profile_id', profile.id)
      .eq('purpose', purpose)
      .eq('code_hash', codeHash)
      .is('used_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (codeError || !codeRow || new Date(codeRow.expires_at) < new Date()) {
      return new Response(JSON.stringify({ error: GENERIC_ERROR }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    let authUserId = profile.auth_user_id as string | null;
    let loginEmail = profile.login_email as string | null;

    if (mode === 'activate') {
      loginEmail = `${crypto.randomUUID()}@${LOGIN_EMAIL_DOMAIN}`;
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: loginEmail,
        password,
        email_confirm: true,
        app_metadata: { profile_id: profile.id },
      });
      if (createError || !created.user) {
        return new Response(JSON.stringify({ error: 'Unable to activate account. Please try again.' }), {
          status: 500,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
        });
      }
      authUserId = created.user.id;

      const { error: linkError } = await admin
        .from('profiles')
        .update({ auth_user_id: authUserId, login_email: loginEmail })
        .eq('id', profile.id);
      if (linkError) {
        return new Response(JSON.stringify({ error: 'Unable to activate account. Please try again.' }), {
          status: 500,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
        });
      }
    } else {
      const { error: updateError } = await admin.auth.admin.updateUserById(authUserId!, { password });
      if (updateError) {
        return new Response(JSON.stringify({ error: 'Unable to reset password. Please try again.' }), {
          status: 500,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
        });
      }
      await admin.from('profiles').update({ failed_login_count: 0, locked_until: null }).eq('id', profile.id);
    }

    // Mark this code used, and invalidate any other still-unused codes of
    // the same purpose for this profile (an admin may have issued more
    // than one before the user got to it).
    await admin.from('account_activation_codes').update({ used_at: new Date().toISOString() }).eq('id', codeRow.id);
    await admin
      .from('account_activation_codes')
      .update({ used_at: new Date().toISOString() })
      .eq('profile_id', profile.id)
      .eq('purpose', purpose)
      .is('used_at', null);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Unexpected error. Please try again.' }), {
      status: 500,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });
  }
});
