import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class JoystickWidget extends StatefulWidget {
  final String id;
  final String title;
  final bool isEditMode;
  
  // Custom API Commands for directions
  final String upCmd;
  final String downCmd;
  final String leftCmd;
  final String rightCmd;

  const JoystickWidget({
    super.key, 
    required this.id, 
    required this.title,
    required this.isEditMode,
    this.upCmd = 'UP',
    this.downCmd = 'DOWN',
    this.leftCmd = 'LEFT',
    this.rightCmd = 'RIGHT',
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  String _currentDirection = 'Center';

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: Colors.transparent,
      baseColor: AppTheme.cardBaseColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.title, 
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_currentDirection, 
                    style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IgnorePointer(
                ignoring: widget.isEditMode, // Don't interact with joystick if editing grid
                child: Listener(
                  onPointerDown: (_) => widget.onInteractionStart?.call(),
                  onPointerUp: (_) => widget.onInteractionEnd?.call(),
                  onPointerCancel: (_) => widget.onInteractionEnd?.call(),
                  child: FittedBox(
                    fit: BoxFit.contain, // Ensures joystick scales with the grid item
                    child: Joystick(
                      mode: JoystickMode.all,
                      base: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Inner subtle rings for a tactical feel
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      stick: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryCyan, AppTheme.neonBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: AppTheme.primaryCyan.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 4)),
                          ],
                        ),
                      ),
                      listener: (details) {
                        // Calculate direction based on x and y thresholds
                        String dir = 'Center';
                        if (details.x > 0.5) dir = 'Right';
                        else if (details.x < -0.5) dir = 'Left';
                        else if (details.y > 0.5) dir = 'Down';
                        else if (details.y < -0.5) dir = 'Up';
                        
                        if (_currentDirection != dir) {
                          setState(() => _currentDirection = dir);
                          if (dir != 'Center' && !widget.isEditMode) {
                              String cmd = '';
                              if (dir == 'Up') cmd = widget.upCmd;
                              if (dir == 'Down') cmd = widget.downCmd;
                              if (dir == 'Left') cmd = widget.leftCmd;
                              if (dir == 'Right') cmd = widget.rightCmd;
                              
                              if (cmd.isNotEmpty) {
                                 ApiService.sendCommand(widget.id, cmd); // Send command
                              }
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

