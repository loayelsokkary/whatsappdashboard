import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

enum PlayState { stopped, playing, paused }

/// Global audio controller using dart:html AudioElement for web playback.
/// Ensures only one voice message plays at a time.
class AudioController extends ChangeNotifier {
  static final AudioController instance = AudioController._();

  AudioController._();

  html.AudioElement? _audio;
  final List<StreamSubscription> _subs = [];

  String? _currentMessageId;
  PlayState _state = PlayState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get currentMessageId => _currentMessageId;
  PlayState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;

  bool isPlaying(String messageId) =>
      _currentMessageId == messageId && _state == PlayState.playing;

  bool isPaused(String messageId) =>
      _currentMessageId == messageId && _state == PlayState.paused;

  bool isActive(String messageId) =>
      _currentMessageId == messageId && _state != PlayState.stopped;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  void init() {
    // No-op — audio element created on demand per play()
  }

  void _disposeAudio() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _audio?.pause();
    _audio = null;
  }

  void play(String messageId, String url) {
    // If same message is paused, resume
    if (_currentMessageId == messageId && _state == PlayState.paused && _audio != null) {
      _audio!.play();
      _state = PlayState.playing;
      notifyListeners();
      return;
    }

    // Stop current playback
    _disposeAudio();
    _position = Duration.zero;
    _duration = Duration.zero;

    _currentMessageId = messageId;
    _state = PlayState.playing;
    notifyListeners();

    final audio = html.AudioElement(url);
    _audio = audio;

    _subs.add(audio.onTimeUpdate.listen((_) {
      _position = Duration(milliseconds: (audio.currentTime * 1000).round());
      notifyListeners();
    }));

    _subs.add(audio.onDurationChange.listen((_) {
      if (!audio.duration.isNaN && !audio.duration.isInfinite) {
        _duration = Duration(milliseconds: (audio.duration * 1000).round());
        notifyListeners();
      }
    }));

    _subs.add(audio.onEnded.listen((_) {
      _state = PlayState.stopped;
      _position = _duration;
      notifyListeners();
    }));

    _subs.add(audio.onError.listen((_) {
      debugPrint('Audio playback error for $url');
      _state = PlayState.stopped;
      notifyListeners();
    }));

    audio.play();
  }

  void pause() {
    _audio?.pause();
    _state = PlayState.paused;
    notifyListeners();
  }

  void stop() {
    _disposeAudio();
    _currentMessageId = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _state = PlayState.stopped;
    notifyListeners();
  }

  void seek(Duration position) {
    if (_audio != null) {
      _audio!.currentTime = position.inMilliseconds / 1000.0;
    }
  }

  @override
  void dispose() {
    _disposeAudio();
    super.dispose();
  }
}
