import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

class ServerLoadingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const ServerLoadingScreen({super.key, this.onComplete});

  @override
  State<ServerLoadingScreen> createState() => _ServerLoadingScreenState();
}

class _ServerLoadingScreenState extends State<ServerLoadingScreen>
    with TickerProviderStateMixin {
  
  final List<String> _messages = [
    "بنجيب العمال من الكافيتريا...",
    "الرامات بتفوق من النوم...",
    "بنوصل الأسلاك وبنظبط الفلاتر...",
    "بنعمل كوباية قهوة للـ Backend...",
    "بنجيب التصميم الـ Premium... ✨",
    "ثواني ونبدأ الأكشن! 🚀"
  ];
  
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  Timer? _completionTimer;

  // Background gradient animation
  late AnimationController _bgController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _messageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
        });
      }
    });

    _completionTimer = Timer(const Duration(seconds: 30), () {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _completionTimer?.cancel();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      body: Stack(
        children: [
          // Animated Neon Glowing Orbs Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                   Positioned(
                    top: -100 + (_bgController.value * 50),
                    left: -50,
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryViolet.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150 + ((1 - _bgController.value) * 80),
                    right: -100,
                    child: Transform.scale(
                      scale: 2.0 - (_pulseAnimation.value * 0.5),
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryCyan.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4,
                    left: MediaQuery.of(context).size.width * 0.2 + (_bgController.value * 100),
                    child: Transform.scale(
                      scale: _pulseAnimation.value * 0.8,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryCyan.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Blur Layer for Glassmorphic effect on the background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // Central Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimalist Glowing Logo / Spinner Placeholder
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryViolet.withOpacity(0.6)),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryViolet),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 60),

                // Dynamic Text with AnimatedSwitcher
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.2), 
                            end: Offset.zero
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _messages[_currentMessageIndex],
                      key: ValueKey<int>(_currentMessageIndex),
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: AppTheme.primaryCyan.withOpacity(0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

