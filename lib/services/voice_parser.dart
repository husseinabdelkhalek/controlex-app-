import 'api_service.dart';
import 'local_service.dart';
import '../core/localization.dart';
import '../widgets/terminal_widget.dart';

class VoiceParsingResult {
  final bool success;
  final String message;
  VoiceParsingResult(this.success, this.message);
}

class VoiceParser {
  // Advanced English-to-Arabic synonym dictionary mapping for intuitive device discovery
  static const Map<String, List<String>> _synonyms = {
    'motor': ['موتور', 'ماتور', 'محرك', 'مطور', 'motor'],
    'pump': ['مضخة', 'المضخة', 'طلمبة', 'مضخه', 'pump'],
    'lamp': ['لمبة', 'لمبه', 'مصباح', 'اضاءة', 'ضوء', 'اللمبة', 'lamp'],
    'light': ['لمبة', 'لمبه', 'مصباح', 'اضاءة', 'ضوء', 'اللمبة', 'light'],
    'fan': ['مروحة', 'مروحه', 'المروحة', 'تهوية', 'fan'],
    'ac': ['مكيف', 'المكيف', 'تكييف', 'التكييف', 'ac', 'air conditioner'],
    'door': ['باب', 'الباب', 'بوابة', 'البوابة', 'door'],
    'lock': ['قفل', 'القفل', 'قفل الباب', 'lock'],
    'heater': ['سخان', 'السخان', 'سخان المياه', 'heater'],
    'socket': ['فيشة', 'بريزة', 'كبس', 'مقبس', 'socket'],
    'switch': ['زر', 'مفتاح', 'سويتش', 'switch'],
  };

  // Normalizes Arabic and English inputs by stripping accents, prefix articles, and wake-words
  static String _normalizeArabic(String str) {
    str = str.toLowerCase().trim();
    // Normalize Arabic letters
    str = str.replaceAll(RegExp(r'[أإآ]'), 'ا');
    str = str.replaceAll(RegExp(r'ة'), 'ه');
    str = str.replaceAll(RegExp(r'ى'), 'ي');
    // Strip common prefix articles
    str = str.replaceAll(RegExp(r'^ال'), '');
    str = str.replaceAll(RegExp(r'\bال'), '');
    // Strip application wake-word
    str = str.replaceAll('كونترولكس', '');
    str = str.replaceAll('controlex', '');
    return str.trim();
  }

  // Strips special punctuation characters frequently used in naming (e.g. /, *, -, _)
  static String _cleanSpecialChars(String str) {
    str = str.replaceAll(RegExp(r'[\/*\-_]'), ' ');
    str = str.replaceAll(RegExp(r'\s+'), ' ');
    return str.trim();
  }

  // Custom word checker that evaluates direct equivalence or synonym equality
  static bool _wordsMatch(String w1, String w2) {
    if (w1 == w2) return true;
    for (var entry in _synonyms.entries) {
      final key = _normalizeArabic(entry.key);
      final list = entry.value.map((s) => _normalizeArabic(s)).toList();
      bool w1Matches = (w1 == key || list.contains(w1));
      bool w2Matches = (w2 == key || list.contains(w2));
      if (w1Matches && w2Matches) return true;
    }
    return false;
  }

  // Levenshtein similarity scorer (phonetic character distance)
  static double _calculateLevenshteinSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final s1Len = s1.length;
    final s2Len = s2.length;
    List<List<int>> d = List.generate(s1Len + 1, (_) => List.filled(s2Len + 1, 0));
    for (int i = 0; i <= s1Len; i++) d[i][0] = i;
    for (int j = 0; j <= s2Len; j++) d[0][j] = j;
    for (int i = 1; i <= s1Len; i++) {
      for (int j = 1; j <= s2Len; j++) {
        int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    int dist = d[s1Len][s2Len];
    int maxLen = s1Len > s2Len ? s1Len : s2Len;
    return 1.0 - (dist / maxLen);
  }

  static Future<void> _send(String id, dynamic value, {bool isLocalMode = false}) async {
    if (isLocalMode) {
      await LocalService.sendCommand(id, value);
    } else {
      await ApiService.sendCommand(id, value);
    }
  }

  static Future<VoiceParsingResult> parse(String text, List<dynamic> widgets, {bool isLocalMode = false, Function(String id, String type, dynamic value)? onCommandExecuted}) async {
    final isAr = AppLocalization.isArabicNotifier.value;
    
    // Global typo fixes for common speech-to-text mistakes in English
    var processedText = text.toLowerCase().trim();
    processedText = processedText.replaceAll(RegExp(r'\bof\b'), 'off');
    processedText = processedText.replaceAll(RegExp(r'\bon\b'), 'on');
    processedText = processedText.replaceAll(RegExp(r'\bzero\b'), '0');
    processedText = processedText.replaceAll(RegExp(r'\bone\b'), '1');
    processedText = processedText.replaceAll(RegExp(r'\btwo\b'), '2');

    final normalizedInput = _normalizeArabic(processedText);
    
    if (normalizedInput.isEmpty) {
      return VoiceParsingResult(false, isAr ? 'لم أسمع شيئاً للتنفيذ.' : 'I did not hear anything to execute.');
    }

    dynamic targetWidget;
    int bestScore = 0;
    
    for (var w in widgets) {
      String originalName = (w['name'] ?? '').toString();
      String wName = originalName.toLowerCase().trim();
      if (wName.isEmpty) continue;
      
      String wType = (w['type'] ?? '').toString().toLowerCase().trim();
      bool isActionable = (wType == 'toggle' || wType == 'slider' || wType == 'push' || wType == 'terminal');
      
      // Clean special characters first, then normalize
      final cleanedName = _cleanSpecialChars(wName);
      final normName = _normalizeArabic(cleanedName);
      
      final cleanedInput = _cleanSpecialChars(normalizedInput);
      final normInput = _normalizeArabic(cleanedInput);
      
      int score = 0;
      
      // 1. Direct contains check (perfect match)
      if (normInput.contains(normName) && normName.isNotEmpty) {
        score = 1000 + normName.length * 10;
      } else if (normName.contains(normInput) && normInput.isNotEmpty) {
        score = 500 + normInput.length * 5;
      } else {
        // 2. Word-level similarity with synonyms mapping
        final wWords = normName.split(' ').where((word) => word.trim().length > 1).toList();
        final inputWords = normInput.split(' ').where((word) => word.trim().length > 1).toList();
        
        if (wWords.isNotEmpty) {
          int matchedWordsCount = 0;
          for (var wWord in wWords) {
            for (var iWord in inputWords) {
              if (_wordsMatch(wWord, iWord) || wWord.contains(iWord) || iWord.contains(wWord)) {
                matchedWordsCount++;
                break;
              }
            }
          }
          
          double overlapRatio = matchedWordsCount / wWords.length;
          score = (overlapRatio * 400).toInt();
        }
      }
      
      // 3. Fallback: Levenshtein distance check (Character-level typo tolerance)
      if (score < 100) {
        final similarity = _calculateLevenshteinSimilarity(normInput, normName);
        if (similarity > 0.3) {
          score = (similarity * 300).toInt();
        }
      }
      
      if (score > 0 && isActionable) {
        score += 5000;
      }
      
      if (score > bestScore) {
        bestScore = score;
        targetWidget = w;
      }
    }

    if (targetWidget == null || bestScore < 100) {
      return VoiceParsingResult(
        false, 
        isAr 
          ? 'لم أستطع تمييز اسم الأداة من جملتك: "$text"'
          : 'Could not identify the device name from your phrase: "$text"'
      );
    }

    String type = targetWidget['type'] ?? 'toggle';
    String id = targetWidget['id'];
    String matchedName = targetWidget['name'];
    Map<String, dynamic> config = targetWidget['configuration'] ?? {};

    if (type == 'terminal') {
      int actionIndex = processedText.indexOf('sent');
      int offset = 4;
      if (actionIndex == -1) { actionIndex = processedText.indexOf('send'); offset = 4; }
      if (actionIndex == -1) { actionIndex = processedText.indexOf('say'); offset = 3; }
      if (actionIndex == -1) { actionIndex = processedText.indexOf('type'); offset = 4; }
      if (actionIndex == -1) { actionIndex = processedText.indexOf('ارسل'); offset = 4; }
      if (actionIndex == -1) { actionIndex = processedText.indexOf('اكتب'); offset = 4; }
      
      if (actionIndex == -1) {
        return VoiceParsingResult(
          false, 
          isAr 
            ? 'لم أسمع كلمة إرسال للترمنال [$matchedName].'
            : 'Did not hear SEND command for Terminal [$matchedName].'
        );
      }
      
      String message = processedText.substring(actionIndex + offset).trim();
      if (message.isEmpty) {
        return VoiceParsingResult(false, isAr ? 'لم أسمع النص المراد إرساله.' : 'Did not hear the text to send.');
      }
      try {
        await _send(id, message, isLocalMode: isLocalMode);
        targetWidget['state'] ??= {};
        targetWidget['state']['lastValue'] = message;
        
        // Append log instantly to active terminal widget if mounted!
        if (TerminalWidget.activeTerminals.containsKey(id)) {
           TerminalWidget.activeTerminals[id]!(message);
        }
        
        if (onCommandExecuted != null) onCommandExecuted(id, 'terminal', message);
        return VoiceParsingResult(
          true, 
          isAr 
            ? 'تم إرسال [ $message ] إلى $matchedName بنجاح.'
            : 'Sent [ $message ] to $matchedName successfully.'
        );
      } catch (e) {
        return VoiceParsingResult(false, '${isAr ? 'خطأ خادم: ' : 'Server error: '}${e.toString().replaceAll('Exception:', '').trim()}');
      }
    } 
    else if (type == 'slider') {
      RegExp exp = RegExp(r'\d+(\.\d+)?');
      Match? match = exp.firstMatch(processedText);
      if (match == null) {
        return VoiceParsingResult(
          false, 
          isAr 
            ? 'لم أجد أي قيمة عددية للسلايدر [$matchedName].'
            : 'Could not extract numeric value for Slider [$matchedName].'
        );
      }
      double val = double.parse(match.group(0)!);
      double min = double.tryParse(config['min']?.toString() ?? '0') ?? 0.0;
      double max = double.tryParse(config['max']?.toString() ?? '100') ?? 100.0;
      
      if (val < min || val > max) {
        return VoiceParsingResult(
          false, 
          isAr 
            ? 'الرقم $val خارج نطاق [$matchedName] المسموح ($min إلى $max).'
            : 'Value $val is out of range for [$matchedName] ($min to $max).'
        );
      }
      
      try {
        await _send(id, val.toStringAsFixed(0), isLocalMode: isLocalMode);
        targetWidget['state'] ??= {};
        targetWidget['state']['lastValue'] = val.toStringAsFixed(0);
        if (onCommandExecuted != null) onCommandExecuted(id, 'slider', val);
        return VoiceParsingResult(
          true, 
          isAr 
            ? 'تم تحريك [$matchedName] إلى ${val.toStringAsFixed(0)} بنجاح.'
            : 'Moved [$matchedName] to ${val.toStringAsFixed(0)} successfully.'
        );
      } catch (e) {
        return VoiceParsingResult(false, '${isAr ? 'خطأ خادم: ' : 'Server error: '}${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }
    else if (type == 'push') {
      String onOriginal = config['onCommand'] != null && config['onCommand'].toString().isNotEmpty ? config['onCommand'].toString() : 'ON';
      try {
        await _send(id, onOriginal, isLocalMode: isLocalMode);
        targetWidget['state'] ??= {};
        targetWidget['state']['lastValue'] = onOriginal;
        if (onCommandExecuted != null) onCommandExecuted(id, 'push', onOriginal);
        return VoiceParsingResult(
          true, 
          isAr 
            ? 'تم الضغط على [$matchedName] وإرسال [$onOriginal] بنجاح.'
            : 'Pressed [$matchedName] and sent [$onOriginal] successfully.'
        );
      } catch (e) {
        return VoiceParsingResult(false, '${isAr ? 'خطأ خادم: ' : 'Server error: '}${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }
    else if (type == 'toggle') {
      String onOriginal = config['onCommand'] != null && config['onCommand'].toString().isNotEmpty ? config['onCommand'].toString() : 'ON';
      String offOriginal = config['offCommand'] != null && config['offCommand'].toString().isNotEmpty ? config['offCommand'].toString() : 'OFF';
      
      final onKeywords = [
        'on', 'turn on', 'open', 'run', 'start', 'activate', '1',
        'شغل', 'شغلي', 'افتح', 'افتحي', 'تشغيل', 'شغال', 'اوبن', 'تيرن اون', 'تفعيل'
      ];
      
      final offKeywords = [
        'off', 'turn off', 'close', 'stop', 'deactivate', '0',
        'اطفي', 'اطفئ', 'أطفئ', 'سكر', 'قفل', 'أغلق', 'اقفل', 'توقيف', 'كلوز', 'تيرن اوف'
      ];

      bool isOn = false;
      bool isOff = false;

      for (var kw in onKeywords) {
        if (processedText.contains(kw) || normalizedInput.contains(_normalizeArabic(kw))) {
          isOn = true;
          break;
        }
      }
      for (var kw in offKeywords) {
        if (processedText.contains(kw) || normalizedInput.contains(_normalizeArabic(kw))) {
          isOff = true;
          break;
        }
      }

      String cmdToSend = '';
      if (isOn && !isOff) {
        cmdToSend = onOriginal;
      } else if (isOff && !isOn) {
        cmdToSend = offOriginal;
      } else {
        // Toggle default fallback
        cmdToSend = onOriginal;
      }
      
      try {
        await _send(id, cmdToSend, isLocalMode: isLocalMode);
        targetWidget['state'] ??= {};
        targetWidget['state']['lastValue'] = cmdToSend;
        if (cmdToSend == onOriginal) {
          targetWidget['state']['isActive'] = true;
        } else if (cmdToSend == offOriginal) {
          targetWidget['state']['isActive'] = false;
        }
        if (onCommandExecuted != null) onCommandExecuted(id, 'toggle', cmdToSend);
        return VoiceParsingResult(
          true, 
          isAr 
            ? 'تم إرسال أمر [$cmdToSend] إلى [$matchedName] بنجاح.'
            : 'Sent command [$cmdToSend] to [$matchedName] successfully.'
        );
      } catch (e) {
        return VoiceParsingResult(false, '${isAr ? 'خطأ خادم: ' : 'Server error: '}${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }

    return VoiceParsingResult(
      false, 
      isAr 
        ? 'نوع الأداة $type لا يدعم هذه الخاصية.' 
        : 'Widget type $type does not support voice execution.'
    );
  }
}
