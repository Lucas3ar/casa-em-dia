import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:casa_em_dia/domain/home.dart';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8080 : int.parse(args.first);
  final database = File(Platform.environment['CASA_DB'] ?? 'casas.jsonl');
  final store = Store(database);
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Casa em Dia disponível na porta ${server.port}');
  await for (final request in server) {
    unawaited(store.handle(request));
  }
}

class Store {
  final File database;
  final homes = <String, Json>{};
  final clients = <String, Set<WebSocket>>{};

  Store(this.database) {
    if (!database.existsSync()) return;
    final lines = database.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      try {
        final home = jsonDecode(lines[index]) as Json;
        homes[home['code']] = home;
      } on FormatException {
        if (index != lines.length - 1) rethrow;
        // An interrupted final append must not corrupt the next record.
        database.writeAsStringSync(
          lines.take(index).map((line) => '$line\n').join(),
          flush: true,
        );
      }
    }
  }

  void save(Json home) {
    final code = home['code'] as String;
    database.writeAsStringSync(
      '${jsonEncode(home)}\n',
      mode: FileMode.append,
      flush: true,
    );
    homes[code] = home;
    for (final client in clients[code] ?? <WebSocket>{}) {
      if (client.readyState == WebSocket.open) client.add('update');
    }
  }

  ({Json home, String actor})? session(String? token) {
    if (token == null) return null;
    for (final home in homes.values) {
      final sessions = home['sessions'] as Json;
      final actor = sessions[token];
      if (actor is String) return (home: home, actor: actor);
    }
    return null;
  }

  Json publicHome(Json home) => {...home}..remove('sessions');

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'content-type, authorization')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Cache-Control', 'no-store')
      ..contentType = ContentType.json;

    Future<void> send(int status, Json body) async {
      response.statusCode = status;
      response.write(jsonEncode(body));
      await response.close();
    }

    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        await response.close();
        return;
      }

      final path = request.uri.path;
      if (path == '/events' && WebSocketTransformer.isUpgradeRequest(request)) {
        final websocket = await WebSocketTransformer.upgrade(request);
        String? code;
        final timeout = Timer(const Duration(seconds: 5), () {
          if (code == null) unawaited(websocket.close(1008));
        });
        void cleanup() {
          timeout.cancel();
          clients[code]?.remove(websocket);
        }

        websocket.listen(
          (message) {
            if (code != null) return;
            final current = session(message is String ? message : null);
            if (current == null) {
              unawaited(websocket.close(1008));
              return;
            }
            code = current.home['code'];
            clients.putIfAbsent(code!, () => {}).add(websocket);
            websocket.add('update');
          },
          onDone: cleanup,
          onError: (Object _) => cleanup(),
        );
        return;
      }

      if (path == '/health' && request.method == 'GET') {
        await send(200, {'status': 'ok'});
        return;
      }
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      if (path == '/home' && request.method == 'GET') {
        final current = session(auth?.replaceFirst('Bearer ', ''));
        if (current == null) {
          await send(401, {'error': 'Sessão inválida. Entre novamente.'});
          return;
        }
        await send(200, {
          'home': publicHome(current.home),
          'actor': current.actor,
        });
        return;
      }
      if (request.method != 'POST' ||
          !['/create', '/join', '/action'].contains(path)) {
        await send(404, {'error': 'Rota inexistente.'});
        return;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in request) {
        bytes.add(chunk);
        if (bytes.length > 4000000) {
          throw const FormatException('Envio acima do limite.');
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is! Json) throw const FormatException('Dados inválidos.');
      if (path == '/create' || path == '/join') {
        final name = HomeRules.label(decoded['name'], 40);
        final Json home;
        if (path == '/create') {
          var code = newId(9).toUpperCase();
          while (homes.containsKey(code)) {
            code = newId(9).toUpperCase();
          }
          home = HomeRules.newHome(HomeRules.label(decoded['house'], 60), code)
            ..['sessions'] = <String, dynamic>{};
        } else {
          final code = HomeRules.label(decoded['code'], 24).toUpperCase();
          final prior = homes[code];
          if (prior == null) {
            throw const FormatException('Código de convite inválido.');
          }
          home = jsonDecode(jsonEncode(prior)) as Json;
        }
        final member = HomeRules.addMember(home, name);
        final token = newId(32);
        (home['sessions'] as Json)[token] = member['id'];
        save(home);
        await send(200, {
          'token': token,
          'actor': member['id'],
          'home': publicHome(home),
        });
        return;
      }
      final current = session(auth?.replaceFirst('Bearer ', ''));
      if (current == null) {
        await send(401, {'error': 'Sessão inválida. Entre novamente.'});
        return;
      }
      final action = HomeRules.label(decoded['action'], 24);
      final input = decoded['input'];
      if (input is! Json) throw const FormatException('Dados inválidos.');
      final home = HomeRules.apply(
        current.home,
        current.actor,
        action,
        input,
        DateTime.now(),
      );
      save(home);
      await send(200, {'actor': current.actor, 'home': publicHome(home)});
    } on FormatException catch (error) {
      await send(400, {'error': error.message});
    } catch (error) {
      stderr.writeln(error);
      await send(500, {'error': 'Serviço indisponível. Tente novamente.'});
    }
  }
}
