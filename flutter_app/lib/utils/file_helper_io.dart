// Non-web implementation with File support
import 'dart:io';
import 'package:flutter/material.dart';

Widget buildImageFromPath(String path) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
  );
}
