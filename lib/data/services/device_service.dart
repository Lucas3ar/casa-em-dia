import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/home.dart';

class DeviceService {
  static const _channel = MethodChannel('casa_em_dia/device');
  final _picker = ImagePicker();

  Future<String?> photo({bool camera = false}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1400000) {
      throw const FormatException('Escolha uma imagem de até 1,4 MB.');
    }
    return base64Encode(bytes);
  }

  Future<void> syncReminders(List<Chore> chores) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('syncReminders', [
      for (final chore in chores)
        {
          'id': chore.id,
          'title': chore.title,
          'due': chore.due.millisecondsSinceEpoch,
        },
    ]);
  }

  Future<bool> requestReminders() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('requestReminders') ?? false;
  }
}
