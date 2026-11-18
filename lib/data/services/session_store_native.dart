import 'package:flutter/services.dart';

const _channel = MethodChannel('casa_em_dia/device');

Future<String?> readSession() async {
  try {
    return await _channel.invokeMethod<String>('readSession');
  } on MissingPluginException {
    return null;
  }
}

Future<void> writeSession(String value) async {
  try {
    await _channel.invokeMethod<void>('writeSession', value);
  } on MissingPluginException {
    // This platform has no native session storage.
  }
}
