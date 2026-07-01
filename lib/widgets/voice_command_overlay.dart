import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/voice_parser.dart';
import '../core/localization.dart';
import 'glass_popups.dart';

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
    _startListening();
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
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 24),
          
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
                style: const TextStyle(color: Colors.white54, fontSize: 12)
              ),
            ),
          
          const SizedBox(height: 32),
          
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
          
          const SizedBox(height: 32),
          
          // Result Status
          if (_isProcessing)
             const CircularProgressIndicator(color: AppTheme.primaryCyan)
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
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       _result!.message,
                       style: const TextStyle(color: Colors.white, fontSize: 14),
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

