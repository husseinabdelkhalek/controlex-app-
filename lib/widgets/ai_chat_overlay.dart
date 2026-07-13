import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
class AiChatOverlay extends StatefulWidget {
  const AiChatOverlay({super.key});

  @override
  State<AiChatOverlay> createState() => _AiChatOverlayState();
}

class _AiChatOverlayState extends State<AiChatOverlay> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isTyping = false;
  late AnimationController _glowController;
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _glowController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatHistory.add({
        'role': 'user',
        'parts': [{'text': text}]
      });
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final responseText = await AiService.processAICommand(
        text, 
        _chatHistory.where((m) => m['role'] != 'error').toList()
      );
      
      if (!mounted) return;

      Map<String, dynamic>? aiData;
      try {
        aiData = json.decode(responseText);
      } catch (e) {
        aiData = null;
      }

      setState(() {
        _isTyping = false;
        if (aiData != null && aiData['reply'] != null) {
          _chatHistory.add({
            'role': 'model',
            'parts': [{'text': aiData['reply'] is String ? aiData['reply'] : json.encode(aiData['reply'])}]
          });
        } else {
          _chatHistory.add({
            'role': 'model',
            'parts': [{'text': responseText}]
          });
        }
      });
      _scrollToBottom();

      if (aiData != null && aiData['commands'] is List) {
        for (var cmd in aiData['commands']) {
          await _executeCommand(cmd);
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _chatHistory.add({
            'role': 'error',
            'parts': [{'text': "عذراً، حدث خطأ أثناء المعالجة: ${e.toString().replaceAll('Exception:', '').trim()}"}]
          });
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _executeCommand(Map<String, dynamic> cmd) async {
    final action = cmd['action'];
    try {
      if (action == 'widget_command') {
        await ApiService.sendCommand(cmd['widgetId'], cmd['command']);
      } else if (action == 'execute_scene') {
        await ApiService.executeScene(cmd['sceneId'], []);
      } else if (action == 'navigate') {
        if (mounted) {
          Navigator.of(context).pushNamed(cmd['url']);
        }
      } else if (action == 'call_api') {
        final method = cmd['method'] ?? 'POST';
        final url = cmd['url'];
        final Map<String, dynamic>? body = cmd['body'] != null ? Map<String, dynamic>.from(cmd['body']) : null;
        if (url != null) {
          final res = await ApiService.executeGenericApiCall(method, url, body);
          if (mounted) {
            final isModifyingMethod = ['POST', 'PUT', 'DELETE'].contains(method.toString().toUpperCase());
            if (isModifyingMethod && (
              url.toString().contains('/api/user/update') ||
              url.toString().contains('/api/user/preferences') ||
              url.toString().contains('/api/scenes') ||
              url.toString().contains('/api/admin') ||
              url.toString().contains('/api/merchant')
            )) {
              setState(() {
                _chatHistory.add({
                  'role': 'model',
                  'parts': [{'text': 'تم تنفيذ الأمر بنجاح!'}],
                });
              });
              _scrollToBottom();
            }
          }
        }
      } else if (action == 'create_widget') {
        final widgetData = cmd['widgetData'];
        if (widgetData != null) {
          await ApiService.createWidget(Map<String, dynamic>.from(widgetData));
          if (mounted) {
            setState(() {
              _chatHistory.add({
                'role': 'model',
                'parts': [{'text': 'تم إنشاء الأداة بنجاح وربطها بنظامك!'}],
              });
            });
            _scrollToBottom();
          }
        }
      } else if (action == 'create_automation') {
        final automationData = cmd['automationData'];
        if (automationData != null) {
          await ApiService.createAutomationRule(Map<String, dynamic>.from(automationData));
          if (mounted) {
            setState(() {
              _chatHistory.add({
                'role': 'model',
                'parts': [{'text': 'تم تفعيل وإنشاء قاعدة التشغيل الآلي (Automation) بنجاح!'}],
              });
            });
            _scrollToBottom();
          }
        }
      } else if (action == 'register_user') {
        final userData = cmd['userData'];
        if (userData != null) {
          final username = userData['username'] ?? '';
          final email = userData['email'] ?? '';
          final password = userData['password'] ?? '';
          final adafruitUsername = userData['adafruitUsername'] ?? '';
          final adafruitApiKey = userData['adafruitApiKey'] ?? '';
          if (username.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
            final res = await ApiService.register(
              username,
              email,
              password,
              adafruitUsername: adafruitUsername,
              adafruitApiKey: adafruitApiKey,
            );
            if (mounted) {
              setState(() {
                _chatHistory.add({
                  'role': 'model',
                  'parts': [{'text': 'تم إنشاء الحساب بنجاح! ${res['msg'] ?? ''}'}],
                });
              });
              _scrollToBottom();
            }
          }
        }
      } else if (action == 'login_user') {
        final loginData = cmd['loginData'];
        if (loginData != null) {
          final email = loginData['email'];
          final password = loginData['password'];
          if (email != null && password != null) {
            final res = await ApiService.login(email, password);
            if (res['token'] != null) {
              await ApiService.saveToken(res['token']);
              if (mounted) {
                setState(() {
                  _chatHistory.add({
                    'role': 'model',
                    'parts': [{'text': 'تم تسجيل الدخول بنجاح!'}],
                  });
                });
                _scrollToBottom();
                Navigator.of(context).pushReplacementNamed('/dashboard');
              }
            } else if (res['twoFactorRequired'] == true) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('temp_email', email);
              if (mounted) {
                setState(() {
                  _chatHistory.add({
                    'role': 'model',
                    'parts': [{'text': res['msg'] ?? 'تم إرسال رمز التحقق إلى بريدك الإلكتروني.'}],
                  });
                });
                _scrollToBottom();
              }
            } else {
              throw Exception(res['msg'] ?? 'فشل تسجيل الدخول');
            }
          }
        }
      } else if (action == 'verify_2fa') {
        final code = cmd['code'];
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('temp_email') ?? '';
        if (code != null && email.isNotEmpty) {
          final res = await ApiService.verify2Fa(email, code);
          if (res['token'] != null) {
            await ApiService.saveToken(res['token']);
            await prefs.remove('temp_email');
            if (mounted) {
              setState(() {
                _chatHistory.add({
                  'role': 'model',
                  'parts': [{'text': 'تم التحقق بنجاح! جاري تحويلك إلى لوحة التحكم...'}],
                });
              });
              _scrollToBottom();
              Navigator.of(context).pushReplacementNamed('/dashboard');
            }
          } else {
            throw Exception(res['msg'] ?? 'فشل التحقق من الرمز');
          }
        }
      } else if (action == 'forgot_password') {
        final email = cmd['email'];
        if (email != null && email.isNotEmpty) {
          if (mounted) {
            setState(() {
              _chatHistory.add({
                'role': 'model',
                'parts': [{'text': 'جاري طلب استعادة كلمة المرور وإرسال الرابط...'}],
              });
            });
            _scrollToBottom();
          }
          final res = await ApiService.forgotPassword(email);
          if (mounted) {
            setState(() {
              _chatHistory.add({
                'role': 'model',
                'parts': [{'text': res['msg'] ?? 'تم إرسال بريد إلكتروني يحتوي على رابط مباشر لإعادة تعيين كلمة المرور بنجاح! يرجى مراجعة بريدك الإلكتروني والضغط على الرابط لتغيير الباسورد مباشرة.'}],
              });
            });
            _scrollToBottom();
          }
        }
      } else if (action == 'change_language') {
        final lang = cmd['lang'];
        if (lang != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('site_lang', lang);
          if (mounted) {
            setState(() {
              _chatHistory.add({
                'role': 'model',
                'parts': [{'text': 'تم تغيير لغة التطبيق بنجاح.'}],
              });
            });
            _scrollToBottom();
          }
        }
      } else if (action == 'emergency_call') {
        final title = cmd['title'] ?? 'تنبيه طوارئ يدوي';
        final body = cmd['body'] ?? 'تم طلب مكالمة طوارئ من المساعد الذكي.';
        await ApiService.triggerManualEmergencyCall(title, body);
        if (mounted) {
          setState(() {
            _chatHistory.add({
              'role': 'model',
              'parts': [{'text': 'جاري إطلاق مكالمة الطوارئ والإنذار الآن! 🚨'}],
            });
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("AI Command Error: $e");
      if (mounted) {
        setState(() {
          _chatHistory.add({
            'role': 'error',
            'parts': [{'text': 'فشل تنفيذ الأمر: ${e.toString().replaceAll('Exception:', '').trim()}'}],
          });
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A4B5E), Color(0xFF3B2A40), Color(0xFF221826)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFC7A5FF).withValues(alpha: 0.2), 
                  const Color(0xFFE5D5FF).withValues(alpha: 0.4), 
                  _glowController.value
                )!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B2A40).withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  children: [
                    // Handle line
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _buildHeader(),
                    Expanded(
                      child: _chatHistory.isEmpty 
                          ? _buildEmptyState() 
                          : _buildChatArea(),
                    ),
                    if (_isTyping) _buildTypingIndicator(),
                    _buildInputArea(),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // History button
              GestureDetector(
                onTap: () {
                   setState(() {
                     _chatHistory.clear();
                   });
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                ),
              ),
              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
          // Center title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ControleX AI',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC7A5FF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Beta',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE5D5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Glowing icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Color(0xFFE5D5FF),
                Color(0xFFC7A5FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC7A5FF).withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ]
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            isAr ? 'اسألني أي شيء عن النظام' : 'Ask me anything about ControleX',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final msg = _chatHistory[index];
        final isUser = msg['role'] == 'user';
        final isError = msg['role'] == 'error';
        final text = msg['parts'][0]['text']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 30, height: 30,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF8A2BE2).withValues(alpha: 0.4), const Color(0xFF00E5FF).withValues(alpha: 0.2)]
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 16),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser 
                      ? LinearGradient(colors: [Color(0xFF6e22c7), Color(0xFF4a1ab5)])
                      : (isError ? LinearGradient(colors: [Color(0xFFb51a1a), Color(0xFFc72222)]) : null),
                    color: (!isUser && !isError) ? Colors.white.withValues(alpha: 0.06) : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 5 : 20),
                      bottomRight: Radius.circular(isUser ? 20 : 5),
                    ),
                    border: (!isUser && !isError) ? Border.all(color: Colors.white.withValues(alpha: 0.09)) : null,
                    boxShadow: [
                      if (isUser)
                        BoxShadow(color: const Color(0xFF6e22c7).withValues(alpha: 0.35), blurRadius: 15, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.tajawal(
                      color: isUser ? Colors.white : const Color(0xFFe8e8f0),
                      fontSize: 15,
                      height: 1.6,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30, height: 30,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8A2BE2).withValues(alpha: 0.4), const Color(0xFF00E5FF).withValues(alpha: 0.2)]
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                SizedBox(width: 4),
                _buildDot(1),
                SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final double t = (_typingController.value - (index * 0.2)) % 1.0;
        double scale = 0.4;
        double opacity = 0.4;
        if (t > 0 && t < 0.6) {
          scale = 1.0;
          opacity = 1.0;
        } else if (t >= 0.6) {
          scale = 0.4;
          opacity = 0.4;
        }
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: Color(0xFF00E5FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildInputArea() {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1A27), // Dark grey pill
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: isAr ? 'كيف يمكنني مساعدتك اليوم؟' : 'How can I help you today?',
                  hintTextDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            GestureDetector(
              onTap: _isTyping ? null : _handleSend,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
