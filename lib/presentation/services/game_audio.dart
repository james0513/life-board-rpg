import 'package:audioplayers/audioplayers.dart';

/// Session audio: music and two SFX channels; no work is started from build().
class GameAudio {
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _fx = AudioPlayer();
  final AudioPlayer _hits = AudioPlayer();
  Future<void> _hitQueue = Future<void>.value();
  final AudioPlayer _steps = AudioPlayer();
  Future<void> _musicQueue = Future<void>.value();
  Future<void> _fxQueue = Future<void>.value();
  Future<void> _stepQueue = Future<void>.value();
  bool enabled = false;
  bool _foreground = true;
  bool _disposed = false;
  String _desired = 'morning';
  String? _loaded;
  String? error;

  Future<void> _sync() {
    final task = _musicQueue.then((_) async {
      if (_disposed) return;
      if (!enabled || !_foreground) {
        await _bgm.pause();
        await _fx.stop();
        await _steps.stop();
        await _hits.stop();
        return;
      }
      await _bgm.setVolume(0.25);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      if (_loaded != _desired) {
        final next = _desired;
        await _bgm.play(AssetSource('audio/music/${next}_loop.wav'));
        _loaded = next;
      } else {
        await _bgm.resume();
      }
      error = null;
    });
    _musicQueue = task.then<void>((_) {}, onError: (Object e, StackTrace s) {
      error = e.toString();
      enabled = false;
      _loaded = null;
    });
    return _musicQueue;
  }

  Future<void> setEnabled(bool value) {
    enabled = value;
    error = null;
    return _sync();
  }
  Future<void> music(String track) {
    if (!{'morning', 'board', 'evening', 'stage_1', 'stage_2', 'stage_3', 'stage_4', 'stage_5', 'stage_6', 'battle', 'boss'}.contains(track)) {
      throw ArgumentError.value(track, 'track');
    }
    _desired = track;
    return _sync();
  }
  Future<void> setForeground(bool foreground) {
    _foreground = foreground;
    return _sync();
  }
  Future<void> sfx(String name) {
    if (_disposed || !enabled || !_foreground) return Future<void>.value();
    final isStep = name == 'step';
    final isHit = name.startsWith('hit_');
    final player = isStep ? _steps : isHit ? _hits : _fx;
    final queue = isStep ? _stepQueue : isHit ? _hitQueue : _fxQueue;
    final task = queue.then((_) async {
      if (_disposed || !enabled || !_foreground) return;
      await player.play(AssetSource('audio/sfx/$name.wav'), volume: isStep ? 0.18 : 0.4);
    }).then<void>((_) {}, onError: (Object e, StackTrace s) {
      // Audio failure must not stop movement or state settlement.
      error = e.toString();
    });
    if (isStep) { _stepQueue = task; } else if (isHit) { _hitQueue = task; } else { _fxQueue = task; }
    return task;
  }
  Future<void> dispose() async {
    _disposed = true;
    await Future.wait([_musicQueue, _fxQueue, _stepQueue, _hitQueue]);
    await Future.wait([_bgm.dispose(), _fx.dispose(), _steps.dispose(), _hits.dispose()]);
  }
}
