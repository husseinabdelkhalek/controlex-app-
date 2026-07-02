import 'package:flutter/material.dart';
import 'ai_chat_overlay.dart';
import 'glass_popups.dart';

class AiFloatingButton extends StatelessWidget {
  final Key? tourKey;

  const AiFloatingButton({super.key, this.tourKey});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: tourKey,
      heroTag: 'aiAssistantFAB_global_${tourKey.hashCode}',
      backgroundColor: Colors.transparent,
      elevation: 0,
      onPressed: () {
        showGlassDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          builder: (context) => const AiChatOverlay(),
        );
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF8A2BE2), Color(0xFF00E5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ]
        ),
        child: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
      ),
    );
  }
}
