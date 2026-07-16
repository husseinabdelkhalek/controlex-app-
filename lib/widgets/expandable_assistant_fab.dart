import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'ai_chat_overlay.dart';
import 'voice_command_overlay.dart';
import 'glass_popups.dart';

import '../core/tour_keys.dart';

class ExpandableAssistantFab extends StatefulWidget {
  final Key? tourKey;
  final List<dynamic> widgets;
  final bool isLocalMode;

  const ExpandableAssistantFab({
    super.key,
    this.tourKey,
    required this.widgets,
    this.isLocalMode = false,
  });

  @override
  State<ExpandableAssistantFab> createState() => ExpandableAssistantFabState();
}

class ExpandableAssistantFabState extends State<ExpandableAssistantFab> {
  bool _isOpen = false;

  void toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }
  
  void open() {
    if (!_isOpen) {
      setState(() => _isOpen = true);
    }
  }

  void close() {
    if (_isOpen) {
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: _isOpen ? 180 : 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E213A).withOpacity(0.85),
              AppTheme.primaryCyan.withOpacity(0.35),
              const Color(0xFF281E3A).withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.25),
              blurRadius: 15,
              spreadRadius: -2,
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  // Main Toggle Button
                  GestureDetector(
                    onTap: toggle,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: AnimatedRotation(
                          turns: _isOpen ? 0.125 : 0.0, // Rotate 45 degrees
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutBack,
                          child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),

                  // Voice Command Button
                  GestureDetector(
                    key: TourKeys.fabVoice,
                    onTap: () {
                      toggle();
                      VoiceCommandOverlay.show(context, widget.widgets, isLocalMode: widget.isLocalMode);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: Icon(Icons.mic_rounded, color: AppTheme.primaryCyan, size: 28),
                      ),
                    ),
                  ),
                  
                  // Smart Assistant Button
                  GestureDetector(
                    key: TourKeys.fabAi,
                    onTap: () {
                      toggle();
                      showGlassDialog(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.5),
                        builder: (context) => const AiChatOverlay(),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFC7A5FF), size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
