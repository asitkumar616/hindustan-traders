import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/role_router.dart';
import '../models/user_profile.dart';

class OwnerOnboardingScreen extends StatefulWidget {
  const OwnerOnboardingScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OwnerOnboardingScreen> createState() => _OwnerOnboardingScreenState();
}

class _OwnerOnboardingScreenState extends State<OwnerOnboardingScreen> {
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = AuthService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = await AuthService.ensureBusinessMembership(
        userId: user.id,
        phone: widget.phone,
        role: 'owner',
        name: AuthService.normalizeOwnerName(_nameController.text.trim()),
        businessName: AuthService.normalizeBusinessName(_shopNameController.text.trim()),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoleRouter.routeForUser(profile)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create shop: $error')),
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
      appBar: AppBar(title: const Text('Create your shop')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set up your business profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Owner name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Shop name',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create shop'),
            ),
          ],
        ),
      ),
    );
  }
}
