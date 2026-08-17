import 'package:flutter/material.dart';

class OwnerComingSoonScreen extends StatelessWidget {
  const OwnerComingSoonScreen({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48, color: Colors.black38),
              const SizedBox(height: 12),
              Text(
                message ?? '$title is coming soon.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
