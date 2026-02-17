// lib/providers/player_state_provider.dart
import 'package:flutter/material.dart';

enum PlayerState {
  hidden,
  mini,
  full,
}

class PlayerStateProvider extends ChangeNotifier {
  PlayerState _state = PlayerState.hidden;
  
  PlayerState get state => _state;
  bool get isHidden => _state == PlayerState.hidden;
  bool get isMini => _state == PlayerState.mini;
  bool get isFull => _state == PlayerState.full;

  void showMini() {
    if (_state != PlayerState.mini) {
      _state = PlayerState.mini;
      notifyListeners();
    }
  }

  void showFull() {
    if (_state != PlayerState.full) {
      _state = PlayerState.full;
      notifyListeners();
    }
  }

  void hide() {
    if (_state != PlayerState.hidden) {
      _state = PlayerState.hidden;
      notifyListeners();
    }
  }

  void toggle() {
    if (_state == PlayerState.mini) {
      showFull();
    } else if (_state == PlayerState.full) {
      showMini();
    }
  }
}
