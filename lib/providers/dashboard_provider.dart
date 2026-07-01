import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  List<dynamic> _scenes = [];
  final Map<String, bool> _executingScenes = {};
  final List<dynamic> _rawWidgets = [];
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  final Map<String, bool> _localToggleStates = {};
  Map<String, dynamic>? _userProfile;
  List<dynamic> _pages = [];
  bool _isLoading = true;

  List<dynamic> get scenes => _scenes;
  Map<String, bool> get executingScenes => _executingScenes;
  List<dynamic> get rawWidgets => _rawWidgets;
  List<dynamic> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  Map<String, bool> get localToggleStates => _localToggleStates;
  Map<String, dynamic>? get userProfile => _userProfile;
  List<dynamic> get pages => _pages;
  bool get isLoading => _isLoading;

  Future<void> fetchProfile() async {
    try {
      final profile = await ApiService.userMe();
      _userProfile = profile;
      _pages = profile['preferences']?['pages'] ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final notifs = await ApiService.getNotifications();
      _notifications = notifs;
      _unreadCount = 0; // Or calculate from data
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadScenes() async {
    try {
      final list = await ApiService.getScenes();
      _scenes = list;
      notifyListeners();
    } catch (_) {}
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setToggleState(String id, bool state) {
    _localToggleStates[id] = state;
    notifyListeners();
  }
}
