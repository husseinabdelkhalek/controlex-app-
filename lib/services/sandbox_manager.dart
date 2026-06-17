import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SandboxState {
  inactive,
  needsWidget,
  needsEditMode,
  needsResize,
  completed
}

class SandboxManager extends ChangeNotifier {
  static final SandboxManager _instance = SandboxManager._internal();
  factory SandboxManager() => _instance;
  SandboxManager._internal();

  Timer? _idleTimer;
  SandboxState _currentState = SandboxState.inactive;
  bool _showHint = false;

  SandboxState get currentState => _currentState;
  bool get showHint => _showHint;

  Future<void> initialize(int widgetCount) async {
    final prefs = await SharedPreferences.getInstance();
    final bool completed = prefs.getBool('sandbox_completed') ?? false;
    final bool tourSeen = prefs.getBool('has_completed_tour_v1') ?? false;

    if (completed || !tourSeen) {
      _currentState = SandboxState.completed;
      return;
    }

    if (widgetCount == 0) {
      _currentState = SandboxState.needsWidget;
    } else if (_currentState != SandboxState.needsResize) {
      _currentState = SandboxState.needsEditMode;
    }

    _startTimer();
  }

  void _startTimer() {
    if (_currentState == SandboxState.completed || _currentState == SandboxState.inactive) return;
    
    _idleTimer?.cancel();
    if (_showHint) {
      _showHint = false;
      notifyListeners();
    }

    _idleTimer = Timer(const Duration(seconds: 10), () {
      _showHint = true;
      notifyListeners();
    });
  }

  void resetTimer() {
    if (_currentState == SandboxState.completed || _currentState == SandboxState.inactive) return;
    _startTimer();
  }

  void onWidgetCreated() {
    if (_currentState == SandboxState.needsWidget) {
      _currentState = SandboxState.needsEditMode;
      _startTimer();
    }
  }

  void onEditModeToggled(bool isEditing) {
    if (_currentState == SandboxState.needsEditMode && isEditing) {
      _currentState = SandboxState.needsResize;
      _startTimer();
    }
  }

  void onWidgetResizedOrMoved() async {
    if (_currentState == SandboxState.needsResize) {
      _currentState = SandboxState.completed;
      _idleTimer?.cancel();
      _showHint = false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sandbox_completed', true);
      notifyListeners();
    }
  }

  void completeManually() async {
    _currentState = SandboxState.completed;
    _idleTimer?.cancel();
    _showHint = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sandbox_completed', true);
    notifyListeners();
  }

  void pause() {
    _idleTimer?.cancel();
    _showHint = false;
    notifyListeners();
  }

  void resume() {
    if (_currentState != SandboxState.completed && _currentState != SandboxState.inactive) {
      _startTimer();
    }
  }
}
