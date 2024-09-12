import 'package:flutter/material.dart';

class ImageUtils {
  static Widget imageFromFile(dynamic file) {
    return Image.network(file.path);
  }
}
