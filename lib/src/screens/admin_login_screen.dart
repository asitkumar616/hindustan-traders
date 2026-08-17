import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../services/supabase_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const String _adminUsername = String.fromEnvironment('ADMIN_USERNAME', defaultValue: 'admin');
  static const String _adminPassword = String.fromEnvironment('ADMIN_PASSWORD', defaultValue: 'Hindustan@123');

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter admin username and password.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final isValid = username == _adminUsername && password == _adminPassword;
      if (!mounted) {
        return;
      }

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid admin credentials.')),
        );
        return;
      }

      // MVP only: admin RPCs are granted to the authenticated role.
      // Create an anonymous Supabase session before opening the admin area.
      // This is NOT production-grade admin authentication; replace with a
      // real Supabase Auth admin identity before production release.
      if (SupabaseService.isInitialized && SupabaseService.client.auth.currentUser == null) {
        await SupabaseService.client.auth.signInAnonymously();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(size: 84, showLabel: true)),
                    const SizedBox(height: 24),
                    const Text('Admin access', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Sign in to review owners, businesses, and customer totals.'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _login,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Open dashboard'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Default demo credentials: admin / Hindustan@123',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}