import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/voice_parser.dart';
import '../core/localization.dart';
import 'glass_popups.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceCommandOverlay extends StatefulWidget {
  final List<dynamic> widgets;
  final bool isLocalMode;
  final Function(String id, String type, dynamic value)? onCommandExecuted;
  const VoiceCommandOverlay({super.key, required this.widgets, this.isLocalMode = false, this.onCommandExecuted});

  static Future<void> show(BuildContext context, List<dynamic> widgets, {bool isLocalMode = false, Function(String id, String type, dynamic value)? onCommandExecuted}) {
    return showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => VoiceCommandOverlay(widgets: widgets, isLocalMode: isLocalMode, onCommandExecuted: onCommandExecuted),
    );
  }

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;
  
  bool _isProcessing = false;
  VoiceParsingResult? _result;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _checkFirstTime();
    _startListening();
  }

  void _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHelp = prefs.getBool('has_seen_voice_help_v2') ?? false;
    if (!hasSeenHelp) {
      await prefs.setBool('has_seen_voice_help_v2', true);
      if (mounted) {
        _stopListening();
        _showHelp();
      }
    }
  }

  void _showHelp() {
    final isAr = AppLocalization.isArabicNotifier.value;
    showGlassDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.glassDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, color: AppTheme.primaryCyan, size: 48),
              SizedBox(height: 16),
              Text(
                isAr ? 'كيف تستخدم المساعد الصوتي؟' : 'How to use Voice Assistant?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                isAr 
                  ? 'طريقة استخدام الأدوات بالصوت:\n\n'
                    '🔘 أزرار التشغيل/الإيقاف (Toggle):\n'
                    'قُل أمر (شغل، افتح، طفي، اقفل) + اسم الأداة.\n'
                    'مثال: "شغل التكييف" - "طفي نور الصالة"\n\n'
                    '👆 أزرار الضغط (Push):\n'
                    'قُل اسم الأداة فقط أو أمر تشغيل.\n'
                    'مثال: "جرس الباب" - "افتح بوابة الجراج"\n\n'
                    '🎚️ شريط التحكم بالقيم (Slider):\n'
                    'قُل اسم الأداة + القيمة الرقمية.\n'
                    'مثال: "خلي المروحة 50" - "التكييف 22"\n\n'
                    '🎨 أداة اختيار الألوان (Color Picker):\n'
                    'قُل (تغيير لون) + اسم الأداة + اللون.\n'
                    'مثال: "غير لون المكتب أحمر" - "أزرق للنجفة"\n\n'
                    '💻 شاشات الأوامر (Terminal):\n'
                    'قُل (ابعت، ارسل، قول) + الرسالة + للأداة.\n'
                    'مثال: "ابعت رسالة ترحيب للترمنال"'
                  : 'How to use tools with Voice:\n\n'
                    '🔘 Toggle Buttons:\n'
                    '[Turn On/Off] + [Name]. Ex: "Turn on AC"\n\n'
                    '👆 Push Buttons:\n'
                    'Just say the name. Ex: "Garage Door"\n\n'
                    '🎚️ Sliders:\n'
                    '[Name] + [Value]. Ex: "Set fan to 50"\n\n'
                    '🎨 Color Picker:\n'
                    '[Name] + [Color]. Ex: "Desk light to red"\n\n'
                    '💻 Terminal:\n'
                    '"Send" + [Message] + "to Terminal"',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.6),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: Text(isAr ? 'حسناً، فهمت' : 'Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
           if (mounted && _isListening) {
              setState(() => _isListening = false);
              _processCommand();
           }
        }
      },
      onError: (val) {
         if (mounted) {
           setState(() {
             _isListening = false;
             final isAr = AppLocalization.isArabicNotifier.value;
             if (val.errorMsg == 'error_no_match') {
                _result = VoiceParsingResult(false, isAr ? 'لم أتمكن من فهم أمرك. يرجى التحدث بوضوح.' : 'Could not understand your command. Please speak clearly.');
             } else if (val.errorMsg == 'error_speech_timeout') {
                _result = VoiceParsingResult(false, isAr ? 'انتهى الوقت ولم أسمع شيئاً.' : 'Speech timeout. I did not hear anything.');
             } else {
                _result = VoiceParsingResult(false, isAr ? 'خطأ في التعرف على الصوت: ${val.errorMsg}' : 'Voice recognition error: ${val.errorMsg}');
             }
           });
         }
      },
    );
    if (available) {
      if (mounted) setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          if (mounted) {
             setState(() {
               _text = val.recognizedWords;
               if (val.hasConfidenceRating && val.confidence > 0) {
                 _confidence = val.confidence;
               }
             });
             if (val.finalResult) {
                if (_isListening) {
                   _speech.stop();
                   setState(() => _isListening = false);
                   if (!_isProcessing) _processCommand();
                }
             }
          }
        },
        localeId: AppLocalization.isArabicNotifier.value ? 'ar_EG' : 'en_US',
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
      );
    } else {
      if (mounted) {
        setState(() {
        _isListening = false;
        _result = VoiceParsingResult(false, AppLocalization.isArabicNotifier.value ? 'تم رفض صلاحية الميكروفون أو غير متوفر.' : 'Microphone permission denied or unavailable.');
      });
      }
    }
  }

  void _stopListening() async {
    await _speech.stop();
    if (mounted && _isListening) {
       setState(() => _isListening = false);
       _processCommand();
    }
  }

  void _processCommand() async {
    if (_text.trim().isEmpty) {
      if (mounted) {
        setState(() {
         _result = VoiceParsingResult(false, AppLocalization.isArabicNotifier.value ? 'لم أسمع أي شيء.' : 'I did not hear anything.');
      });
      }
      return;
    }
    
    if (mounted) setState(() => _isProcessing = true);
    
    final res = await VoiceParser.parse(
      _text, 
      widget.widgets, 
      isLocalMode: widget.isLocalMode,
      onCommandExecuted: widget.onCommandExecuted,
    );
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _result = res;
      });
      
      // Auto close after 3 seconds on success
      if (res.success) {
         Future.delayed(const Duration(seconds: 3), () {
            if (mounted && Navigator.canPop(context)) {
               Navigator.pop(context);
            }
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor.withValues(alpha: 0.65),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryCyan.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)
        ]
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 40), // Spacer for balance
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: Colors.white54),
                onPressed: () {
                  _stopListening();
                  _showHelp();
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // Transcription Text
          Text(
            _text.isEmpty 
              ? (_isListening 
                  ? (AppLocalization.isArabicNotifier.value ? 'أستمع إليك...' : 'Listening...') 
                  : (AppLocalization.isArabicNotifier.value ? 'تحدث الآن' : 'Speak now')) 
              : _text,
            style: TextStyle(
               color: Colors.white, 
               fontSize: 22, 
               fontWeight: FontWeight.bold,
               shadows: [Shadow(color: AppTheme.primaryCyan.withValues(alpha: 0.5), blurRadius: 10)]
            ),
            textAlign: TextAlign.center,
          ),
          
          if (_confidence < 0.9 && _text.isNotEmpty && _isListening)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                AppLocalization.isArabicNotifier.value ? 'الرجاء التحدث بوضوح أكثر...' : 'Please speak more clearly...',
                style: TextStyle(color: Colors.white54, fontSize: 12)
              ),
            ),
          
          SizedBox(height: 32),
          
          // Microphone Button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: _isListening ? AppTheme.semanticError.withValues(alpha: 0.2) : AppTheme.primaryBrand.withValues(alpha: 0.2),
                 border: Border.all(
                   color: _isListening ? AppTheme.semanticError : AppTheme.primaryBrand, 
                   width: _isListening ? 3 : 2
                 ),
                 boxShadow: [
                    BoxShadow(
                       color: (_isListening ? AppTheme.semanticError : AppTheme.primaryBrand).withValues(alpha: _isListening ? 0.6 : 0.3),
                       blurRadius: _isListening ? 30 : 15,
                       spreadRadius: _isListening ? 10 : 2
                    )
                 ]
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? AppTheme.semanticError : Colors.white,
                size: 40,
              ),
            ),
          ),
          
          SizedBox(height: 32),
          
          // Result Status
          if (_isProcessing)
             CircularProgressIndicator(color: AppTheme.primaryCyan)
          else if (_result != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: _result!.success ? AppTheme.semanticSuccess.withValues(alpha: 0.1) : AppTheme.semanticError.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: _result!.success ? AppTheme.semanticSuccess : AppTheme.semanticError, width: 1),
               ),
               child: Row(
                 children: [
                   Icon(_result!.success ? Icons.check_circle : Icons.error, color: _result!.success ? AppTheme.semanticSuccess : AppTheme.semanticError),
                   SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       _result!.message,
                       style: TextStyle(color: Colors.white, fontSize: 14),
                     ),
                   )
                 ],
               ),
             )
        ],
      ),
    );
  }
}

