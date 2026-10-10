import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../art/appearance.dart';
import '../art/equipment_layers.dart';

enum WalkDirection { down, up, left, right }

/// Four sprite-sheet rows = down/up/left/right, four walking frames each.
/// World position is the feet anchor, independent of animation offsets.
class PlayerComponent extends PositionComponent {
  PlayerComponent(Vector2 start, {Image? sheet})
      : _sheet = sheet,
        super(position: start, size: Vector2.all(64),
          anchor: Anchor.bottomCenter, priority: 1000);

  final Image? _sheet;
  static const stepDuration = 0.36;
  static const frameDuration = 0.09;
  final List<List<Sprite>> _frames = [];
  List<Sprite>? _careerFrames;
  String jobId = 'unemployed';
  EquipmentLook equipment = const EquipmentLook();
  void setCareer(Image atlas, String id) {
    jobId = id;
    final index = CareerAppearance.index(id);
    if (index == null) { _careerFrames = null; return; }
    final cols=CareerAppearance.columns(id);
    final cell = Vector2(atlas.width / cols, atlas.height / CareerAppearance.rows(id));
    _careerFrames = List.generate(2, (f) => Sprite(atlas,
      srcPosition: Vector2(((index+f*cols)%cols)*cell.x, ((index+f*cols)~/cols)*cell.y), srcSize: cell));
  }
  List<Vector2> _route = [];
  Vector2? _origin;
  int _step = 0;
  double _elapsed = 0;
  double _animationTime = 0;
  Completer<bool>? _completion;
  void Function(int)? _onStep;
  WalkDirection direction = WalkDirection.down;

  bool get isWalking => _completion != null;
  int get frameIndex => isWalking ? (_animationTime / frameDuration).floor() % 4 : 1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = _sheet;
    if (image == null) return; // Allows movement-only unit tests without GPU assets.
    final cell = Vector2(image.width / 4, image.height / 4);
    for (var row = 0; row < 4; row++) {
      _frames.add(List.generate(4, (col) => Sprite(image,
        srcPosition: Vector2(col * cell.x, row * cell.y), srcSize: cell)));
    }
  }

  void _faceTarget() {
    final delta = _route[_step] - position;
    if (delta.x.abs() > .01 && delta.y.abs() > .01) {
      direction = delta.x > 0
        ? (delta.y > 0 ? WalkDirection.right : WalkDirection.up)
        : (delta.y > 0 ? WalkDirection.down : WalkDirection.left);
    } else if (delta.x.abs() >= delta.y.abs()) {
      direction = delta.x >= 0 ? WalkDirection.right : WalkDirection.left;
    } else {
      direction = delta.y >= 0 ? WalkDirection.down : WalkDirection.up;
    }
  }

  Future<bool> walk(List<Vector2> route, void Function(int) onStep) {
    if (isWalking) throw StateError('Already moving');
    if (route.isEmpty) return Future.value(true);
    _route = route.map((p) => p.clone()).toList();
    _origin = position.clone();
    _step = 0;
    _elapsed = 0;
    _animationTime = 0;
    _onStep = onStep;
    _faceTarget();
    final completion = Completer<bool>();
    _completion = completion;
    return completion.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isWalking || dt <= 0) return;
    _animationTime += dt;
    _elapsed += dt;
    while (_elapsed >= stepDuration && isWalking) {
      position.setFrom(_route[_step]);
      _onStep?.call(_step);
      _elapsed -= stepDuration;
      _step++;
      if (_step == _route.length) {
        final completion = _completion!;
        _completion = null;
        _onStep = null;
        _animationTime = 0;
        completion.complete(true);
        return;
      }
      _origin = position.clone();
      _faceTarget();
    }
    // Linear speed between cells makes the walk cycle feel continuous.
    final t = (_elapsed / stepDuration).clamp(0.0, 1.0);
    position.setFrom(_origin! + (_route[_step] - _origin!) * t);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.x / 2, size.y - 2),
      width: 26, height: 8), Paint()..color = const Color(0x35000000));
    if (_careerFrames != null) {
      final frame = isWalking ? frameIndex % 2 : 0;
      final bob = isWalking ? -2.0 * math.sin(_animationTime / stepDuration * math.pi * 2).abs() : 0.0;
      canvas.save();
      if (direction == WalkDirection.left || direction == WalkDirection.down) {
        canvas.translate(size.x, 0); canvas.scale(-1, 1);
      }
      _careerFrames![frame].render(canvas, position: Vector2(0, bob), size: size);
      EquipmentLayers.paint(canvas,Rect.fromLTWH(0,bob,size.x,size.y),equipment,frame:frame);
      canvas.restore();
      return;
    }
    if (_frames.isEmpty) return;
    final bob = isWalking ? -1.2 * math.sin(_animationTime / stepDuration * math.pi * 2).abs() : 0.0;
    _frames[direction.index][frameIndex].render(canvas,
      position: Vector2(0, bob), size: size);
  }

  void resetTo(Vector2 point) {
    if (isWalking) throw StateError('Cannot reset during movement');
    position.setFrom(point);
    direction = WalkDirection.down;
    _animationTime = 0;
  }

  @override
  void onRemove() {
    final pending = _completion;
    _completion = null;
    _onStep = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    super.onRemove();
  }
}
