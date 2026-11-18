import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/home.dart';

class HomeService {
  final Uri base;
  final _client = http.Client();
  HomeService(this.base);

  Future<Json> read(String token) => _request('/home', token: token);

  Future<Json> post(String route, Json body, [String? token]) =>
      _request(route, body: body, token: token);

  WebSocketChannel events() => WebSocketChannel.connect(
    base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/events',
    ),
  );

  void close() => _client.close();

  Future<Json> _request(String path, {Json? body, String? token}) async {
    final uri = base.replace(path: path);
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    try {
      final future = body == null
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body));
      final response = await future.timeout(const Duration(seconds: 8));
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Json;
      if (response.statusCode != 200) {
        throw FormatException(
          json['error']?.toString() ?? 'Falha ao acessar a casa.',
        );
      }
      return json;
    } on TimeoutException {
      throw const FormatException(
        'O servidor demorou para responder. Confira a conexão.',
      );
    } on http.ClientException {
      throw const FormatException('Não foi possível acessar o servidor.');
    }
  }
}
