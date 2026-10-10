import 'package:flutter/services.dart';

class AssetJsonLoader {
  final AssetBundle bundle;
  AssetJsonLoader({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  Future<String> load(String path) => bundle.loadString(path);
}
