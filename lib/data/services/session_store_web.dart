import 'package:web/web.dart' as web;

const _key = 'casa-em-dia/session';
Future<String?> readSession() async => web.window.localStorage.getItem(_key);
Future<void> writeSession(String value) async =>
    web.window.localStorage.setItem(_key, value);
