// lib/providers/player_state_provider.dart
import 'package:flutter/material.dart';
import 'dart:math';

enum PlayerState {
  hidden,
  mini,
  full,
}

enum RepeatMode {
  off,    // No repeat
  one,    // Repeat current song
  all,    // Repeat entire playlist
}

class PlayerStateProvider extends ChangeNotifier {
  PlayerState _state = PlayerState.hidden;
  bool _isShuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _repeatOnceEnabled = false; // Repeat current song one extra time, then auto-disable
  bool _hasRepeatedOnceForCurrentTrack = false;
  List<int>? _shuffledIndices; // Store shuffled order when shuffle is enabled
  List<dynamic>? _originalPlaylist; // Store original playlist order
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  PlayerState get state => _state;
  bool get isHidden => _state == PlayerState.hidden;
  bool get isMini => _state == PlayerState.mini;
  bool get isFull => _state == PlayerState.full;
  bool get isShuffleEnabled => _isShuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  bool get repeatOnceEnabled => _repeatOnceEnabled;
  bool get hasRepeatedOnceForCurrentTrack => _hasRepeatedOnceForCurrentTrack;
  Duration get position => _position;
  Duration get duration => _duration;
  
  /// Update playback position (called by MediaPlayerWidget)
  void updatePosition(Duration position, Duration duration) {
    if (_position != position || _duration != duration) {
      _position = position;
      _duration = duration;
      notifyListeners();
    }
  }
  
  /// Enable/disable shuffle mode
  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    _shuffledIndices = null; // Reset shuffle order
    notifyListeners();
  }
  
  /// Cycle through repeat modes: off -> one -> all -> off
  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  /// Toggle repeat-once (repeat the current track exactly one extra time).
  /// When enabling, we reset the per-track "already repeated" flag.
  void toggleRepeatOnce() {
    _repeatOnceEnabled = !_repeatOnceEnabled;
    if (_repeatOnceEnabled) {
      _hasRepeatedOnceForCurrentTrack = false;
    }
    notifyListeners();
  }

  /// Call whenever the currently playing track changes.
  void onTrackChanged() {
    if (_hasRepeatedOnceForCurrentTrack) {
      _hasRepeatedOnceForCurrentTrack = false;
      notifyListeners();
      return;
    }
    // Avoid noisy rebuilds if already false.
    if (_hasRepeatedOnceForCurrentTrack != false) {
      _hasRepeatedOnceForCurrentTrack = false;
      notifyListeners();
    }
  }

  /// Mark that repeat-once has been consumed for the current track.
  void consumeRepeatOnceForCurrentTrack() {
    if (_repeatOnceEnabled && !_hasRepeatedOnceForCurrentTrack) {
      _hasRepeatedOnceForCurrentTrack = true;
      notifyListeners();
    }
  }

  /// Auto-disable repeat-once after it has been used.
  void disableRepeatOnce() {
    if (_repeatOnceEnabled) {
      _repeatOnceEnabled = false;
      notifyListeners();
    }
  }
  
  /// Initialize shuffle order for a playlist
  void initializeShuffle(List<dynamic> playlist, int currentIndex) {
    if (!_isShuffleEnabled || playlist.isEmpty) {
      _shuffledIndices = null;
      _originalPlaylist = null;
      return;
    }
    
    _originalPlaylist = List.from(playlist);
    final indices = List.generate(playlist.length, (i) => i);
    
    // Remove current index and shuffle the rest
    indices.removeAt(currentIndex);
    indices.shuffle(Random());
    
    // Put current index first, then shuffled rest
    _shuffledIndices = [currentIndex, ...indices];
  }
  
  /// Get the next index based on shuffle and repeat settings
  int? getNextIndex(int currentIndex, int playlistLength) {
    if (playlistLength == 0) return null;
    
    if (_isShuffleEnabled && _shuffledIndices != null) {
      final currentShuffledPos = _shuffledIndices!.indexOf(currentIndex);
      if (currentShuffledPos == -1) {
        // Current index not in shuffle, initialize
        initializeShuffle(_originalPlaylist ?? [], currentIndex);
        return getNextIndex(currentIndex, playlistLength);
      }
      
      if (currentShuffledPos < _shuffledIndices!.length - 1) {
        return _shuffledIndices![currentShuffledPos + 1];
      } else {
        // End of shuffled playlist
        if (_repeatMode == RepeatMode.all) {
          // Reshuffle and start from beginning
          initializeShuffle(_originalPlaylist ?? [], _shuffledIndices![0]);
          return _shuffledIndices!.isNotEmpty ? _shuffledIndices![0] : null;
        }
        return null; // No repeat, stop
      }
    } else {
      // Normal order
      if (currentIndex < playlistLength - 1) {
        return currentIndex + 1;
      } else {
        // End of playlist
        if (_repeatMode == RepeatMode.all) {
          return 0; // Loop to beginning
        }
        return null; // No repeat, stop
      }
    }
  }
  
  /// Get the previous index based on shuffle and repeat settings
  int? getPreviousIndex(int currentIndex, int playlistLength) {
    if (playlistLength == 0) return null;
    
    if (_isShuffleEnabled && _shuffledIndices != null) {
      final currentShuffledPos = _shuffledIndices!.indexOf(currentIndex);
      if (currentShuffledPos == -1) {
        // Current index not in shuffle, initialize
        initializeShuffle(_originalPlaylist ?? [], currentIndex);
        return getPreviousIndex(currentIndex, playlistLength);
      }
      
      if (currentShuffledPos > 0) {
        return _shuffledIndices![currentShuffledPos - 1];
      } else {
        // Beginning of shuffled playlist
        if (_repeatMode == RepeatMode.all) {
          // Go to end of shuffled list
          return _shuffledIndices!.isNotEmpty 
              ? _shuffledIndices![_shuffledIndices!.length - 1] 
              : null;
        }
        return null; // No repeat, stop
      }
    } else {
      // Normal order
      if (currentIndex > 0) {
        return currentIndex - 1;
      } else {
        // Beginning of playlist
        if (_repeatMode == RepeatMode.all) {
          return playlistLength - 1; // Loop to end
        }
        return null; // No repeat, stop
      }
    }
  }

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
