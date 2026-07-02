import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../core/localization.dart';

class EmergencyCallScreen extends StatefulWidget {
  final String title;
  final String body;
  final String uuid;

  const EmergencyCallScreen({
    super.key,
    this.title = 'Emergency Call',
    this.body = 'Attention Required!',
    this.uuid = '',
  });

  @override
  State<EmergencyCallScreen> createState() => _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen> with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Setup audio player
    _audioPlayer = AudioPlayer();
    _playAlarm();

    // Auto-close after 60 seconds if no action
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        _stopAlarmAndClose();
      }
    });
  }

  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      debugPrint('Error playing alarm audio: $e');
    }
  }

  void _stopAlarmAndClose() async {
    _timeoutTimer?.cancel();
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalization.isArabicNotifier.value;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.5 * _animationController.value),
                      Colors.black,
                    ],
                    radius: 1.0 + (_animationController.value * 0.5),
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Warning Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.red, width: 4),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                ),
                
                SizedBox(height: 40),
                
                // Title
                Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 16),
                
                // Body/Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.body,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const Spacer(flex: 3),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Acknowledge Button
                    _buildActionButton(
                      icon: Icons.check_circle_outline,
                      label: isArabic ? 'حسناً' : 'Acknowledge',
                      color: Colors.green,
                      onTap: _stopAlarmAndClose,
                    ),
                    
                    // Mute / Ignore Button
                    _buildActionButton(
                      icon: Icons.volume_off,
                      label: isArabic ? 'تجاهل' : 'Mute',
                      color: Colors.grey,
                      onTap: _stopAlarmAndClose,
                    ),
                  ],
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 40),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
