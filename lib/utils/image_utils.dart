import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File, Platform;
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static Widget imageFromXFile(XFile file) {
    if (kIsWeb) {
      return Image.network(file.path);
    } else if (Platform.isAndroid || Platform.isIOS) {
      return Image.file(File(file.path));
    } else {
      return Text('Unsupported platform');
    }
  }
}