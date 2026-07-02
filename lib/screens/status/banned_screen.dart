import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization.dart';
import '../../theme/app_theme.dart';

class BannedScreen extends StatelessWidget {
  final String? message;
  const BannedScreen({super.key, this.message});

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/201091601661');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final Uri url = Uri.parse('mailto:hussianabdk577@gmail.com?subject=Account%20Suspension%20Appeal');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated-like background blobs
          Positioned(
            top: -100,
            right: -100,
            child: _buildBlob(AppTheme.primaryViolet.withValues(alpha: 0.3), 300),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlob(Colors.redAccent.withValues(alpha: 0.2), 250),
          ),
          
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with Glow
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Icon(Icons.block_flipped, color: Colors.redAccent, size: 80),
                      ),
                      SizedBox(height: 24),
                      
                      // Title
                      Text(
                        AppLocalization.get('banned_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Message
                      Text(
                        message ?? AppLocalization.get('banned_msg'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 40),
                      
                      // Contact Buttons
                      _buildContactButton(
                        label: AppLocalization.get('whatsapp_contact'),
                        icon: Icons.chat_bubble_outline,
                        color: Colors.greenAccent,
                        onTap: _launchWhatsApp,
                      ),
                      SizedBox(height: 16),
                      _buildContactButton(
                        label: AppLocalization.get('email_contact'),
                        icon: Icons.email_outlined,
                        color: Colors.blueAccent,
                        onTap: _launchEmail,
                      ),
                      
                      SizedBox(height: 32),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalization.get('close'),
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildContactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 14),
          ],
        ),
      ),
    );
  }
}
