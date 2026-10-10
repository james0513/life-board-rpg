import 'battle_audio_cues.dart';

import 'package:audioplayers/audioplayers.dart';

/// Session audio: music and isolated cast, impact, movement and general SFX channels; no work is started from build().
class GameAudio {
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _fx = AudioPlayer();
  final AudioPlayer _hits = AudioPlayer();
  final AudioPlayer _casts = AudioPlayer();
  Future<void> _castQueue = Future<void>.value();
  int _soundEpoch = 0;
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
        await Future.wait([
          _bgm.pause(),
          _fx.stop(),
          _steps.stop(),
          _hits.stop(),
          _casts.stop(),
        ]);
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
    _musicQueue = task.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {
        error = e.toString();
        enabled = false;
        _loaded = null;
      },
    );
    return _musicQueue;
  }

  Future<void> setEnabled(bool value) {
    enabled = value;
    if (!value) _soundEpoch++;
    error = null;
    return _sync();
  }

  Future<void> music(String track) {
    if (!{
      'morning',
      'board',
      'evening',
      'stage_1',
      'stage_2',
      'stage_3',
      'stage_4',
      'stage_5',
      'stage_6',
      'battle',
      'boss',
    }.contains(track)) {
      throw ArgumentError.value(track, 'track');
    }
    _desired = track;
    return _sync();
  }

  Future<void> setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) _soundEpoch++;
    return _sync();
  }

  Future<void> sfx(String name) {
    if (_disposed || !enabled || !_foreground) return Future<void>.value();
    final epoch = _soundEpoch;
    final isCast = isCastCue(name);
    final isStep = name == 'step';
    final isHit = name.startsWith('hit_');
    final player = isCast
        ? _casts
        : isStep
        ? _steps
        : isHit
        ? _hits
        : _fx;
    final queue = isCast
        ? _castQueue
        : isStep
        ? _stepQueue
        : isHit
        ? _hitQueue
        : _fxQueue;
    final task = queue
        .then((_) async {
          if (_disposed || !enabled || !_foreground || epoch != _soundEpoch)
            return;
          await player.play(
            AssetSource('audio/sfx/$name.wav'),
            volume: isCast
                ? 0.72
                : isStep
                ? 0.18
                : 0.4,
          );
        })
        .then<void>(
          (_) {},
          onError: (Object e, StackTrace s) {
            // Audio failure must not stop movement or state settlement.
            error = e.toString();
          },
        );
    if (isCast) {
      _castQueue = task;
    } else if (isStep) {
      _stepQueue = task;
    } else if (isHit) {
      _hitQueue = task;
    } else {
      _fxQueue = task;
    }
    return task;
  }

  Future<void> dispose() async {
    _disposed = true;
    _soundEpoch++;
    await Future.wait([
      _musicQueue,
      _fxQueue,
      _stepQueue,
      _hitQueue,
      _castQueue,
    ]);
    // Plugin teardown can fail after a browser tab loses its audio context.
    // Cleanup is best effort and must never escape an unawaited route dispose.
    await Future.wait(
      [_bgm, _fx, _steps, _hits, _casts].map((player) async {
        try {
          await player.dispose();
        } catch (e) {
          error = e.toString();
        }
      }),
    );
  }
}
