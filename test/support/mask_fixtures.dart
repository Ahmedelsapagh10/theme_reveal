import 'dart:ui' as ui;

import 'package:flutter/services.dart';

Future<Uint8List> pngFixture(
  int width,
  int height,
  void Function(ui.Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return Uint8List.fromList(
      (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class MaskBundle extends CachingAssetBundle {
  MaskBundle(this.files);
  final Map<String, Uint8List> files;
  final loads = <String>[];
  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final bytes = files[key];
    if (bytes == null) throw StateError('Missing test asset: $key');
    return ByteData.sublistView(bytes);
  }
}
