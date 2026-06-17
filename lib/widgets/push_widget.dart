import 'package:flutter/material.dart';

class PushWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const PushWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          splashColor: const Color(0xFFFF00FF).withValues(alpha: 0.3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFFFF00FF)), // Magenta for Push Buttons
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('PUSH', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
