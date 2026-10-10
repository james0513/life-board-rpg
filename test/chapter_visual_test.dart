import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/presentation/three_d/chapter_board.dart';
import 'package:life_graybox/presentation/three_d/scene_3d.dart';
import 'package:life_graybox/presentation/widgets/chapter_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all six chapter backgrounds are bundled and decodable', () async {
    for (var stage = 1; stage <= 6; stage++) {
      final data = await rootBundle.load(chapterBackgroundAsset(stage));
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1536);
      expect(frame.image.height, 1024);
      frame.image.dispose();
      codec.dispose();
    }
  });
  test('six chapter landmarks contain finite geometry and render from both sides', () {
    final signatures = <String>{};
    for (var stage = 1; stage <= 6; stage++) {
      final scene = Scene3D();
      ChapterBoard.floor(scene, stage);
      ChapterBoard.scenery(scene, stage);
      for (final face in scene.faces) {
        for (final point in face.points) {
          expect(point.x.isFinite && point.y.isFinite && point.z.isFinite, isTrue);
        }
      }
      signatures.add(scene.faces.map((f) => '${f.color}:${f.center.x}:${f.center.y}:${f.center.z}').join('|'));
      for (final x in [-10.0, 10.0]) {
        final recorder = ui.PictureRecorder();
        scene.draw(Canvas(recorder), const Size(900, 560), Camera3D(eye: V3(x, 8, 10)));
        recorder.endRecording().dispose();
      }
    }
    expect(signatures.length, 6);
  });
}
