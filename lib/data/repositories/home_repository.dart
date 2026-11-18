import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/home.dart';
import '../services/home_service.dart';
import '../services/session_store.dart';

class HomeRepository extends ChangeNotifier {
  HomeRepository(this._service);

  final HomeService _service;
  Home? _home;
  Home? get home => _home;
  String? _actor;
  String? get actor => _actor;
  String? _token;
  Json? _demo;
  bool get isDemo => _demo != null;
  bool get connected => _socket != null;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> restore() => _serial(() async {
    final stored = await readSession();
    if (stored == null || stored.isEmpty) return;
    final session = jsonDecode(stored) as Json;
    _token = session['token'];
    _demo = session['demo'];
    if (_demo != null) {
      _publish({'home': _demo, 'actor': session['actor']});
    } else if (_token case final token?) {
      _publish(await _service.read(token));
      unawaited(_connect(token));
    }
  });

  Future<void> open(String name, String houseOrCode, {required bool join}) =>
      _serial(() async {
        final result = await _service.post(join ? '/join' : '/create', {
          'name': name,
          (join ? 'code' : 'house'): houseOrCode,
        });
        await _disconnect();
        _demo = null;
        _token = result['token'];
        _publish(result);
        await writeSession(jsonEncode({'token': _token}));
        unawaited(_connect(_token!));
      });

  Future<void> startDemo() => _serial(() async {
    await _disconnect();
    _token = null;
    final home = HomeRules.newHome('Apartamento 402', 'DEMONSTRAÇÃO');
    final me = HomeRules.addMember(home, 'Mariana')['id'] as String;
    final other = HomeRules.addMember(home, 'Rafael')['id'] as String;
    final third = HomeRules.addMember(home, 'Luiza')['id'] as String;
    final now = DateTime.now();
    Json chore(
      String title,
      String room,
      String owner,
      int points,
      int interval, {
      int days = 0,
      bool proof = false,
    }) => {
      'title': title,
      'room': room,
      'owner': owner,
      'points': points,
      'interval': interval,
      'due': DateTime(
        now.year,
        now.month,
        now.day + days,
        19,
      ).toUtc().toIso8601String(),
      'rotate': interval > 0,
      'proof': proof,
    };
    final initial =
        [
          chore('Organizar a bancada', 'Cozinha', me, 4, 0),
          chore('Lavar o banheiro', 'Banheiro', me, 8, 7, days: -1),
          chore('Regar as plantas', 'Área externa', other, 3, 14),
          chore('Aspirar o tapete', 'Sala', third, 6, 7, days: 1, proof: true),
          chore('Separar a reciclagem', 'Cozinha', other, 5, 0),
          chore('Limpar a mesa', 'Sala', me, 6, 0),
        ].fold(
          home,
          (state, item) => HomeRules.apply(state, me, 'task', item, now),
        );
    var state = initial;
    for (final task in (initial['tasks'] as List).skip(4)) {
      state = HomeRules.apply(state, task['owner'], 'complete', {
        'id': task['id'],
      }, now);
    }
    for (final reward in [
      {'title': 'Escolher o filme de sexta', 'cost': 5},
      {'title': 'Folga da louça no domingo', 'cost': 15},
    ]) {
      state = HomeRules.apply(state, me, 'reward', reward, now);
    }
    _demo = state;
    _publish({'home': state, 'actor': me});
    await _saveDemo();
  });

  Future<void> _saveDemo() =>
      writeSession(jsonEncode({'demo': _demo, 'actor': _actor}));

  Future<void> act(String action, Json input) => _serial(() async {
    if (_demo case final demo?) {
      final next = HomeRules.apply(
        demo,
        _actor!,
        action,
        input,
        DateTime.now(),
      );
      await writeSession(jsonEncode({'demo': next, 'actor': _actor}));
      _demo = next;
      _publish({'home': next, 'actor': _actor});
    } else if (_token case final token?) {
      _publish(
        await _service.post('/action', {
          'action': action,
          'input': input,
        }, token),
      );
    } else {
      throw const FormatException('Entre na casa primeiro.');
    }
  });

  Future<void> switchDemoMember(String id) => _serial(() async {
    if (_demo case final demo?) {
      _publish({'home': demo, 'actor': id});
      await _saveDemo();
    }
  });

  Future<void> leave() => _serial(() async {
    await _disconnect();
    _token = null;
    _demo = null;
    _home = null;
    _actor = null;
    await writeSession('');
    notifyListeners();
  });

  void _publish(Json data) {
    _home = Home.fromJson(data['home']);
    _actor = data['actor'];
    notifyListeners();
  }

  Future<void> _connect(String token) async {
    final socket = _service.events();
    try {
      await socket.ready.timeout(const Duration(seconds: 8));
      if (_token != token) {
        await socket.sink.close();
        return;
      }
      _socket = socket;
      _subscription = socket.stream.listen(
        (_) {
          unawaited(
            _serial(() async {
              if (_token == token) _publish(await _service.read(token));
            }).catchError((Object _) {}),
          );
        },
        onDone: () => _reconnect(token),
        onError: (Object _) => _reconnect(token),
        cancelOnError: true,
      );
      socket.sink.add(token);
      notifyListeners();
    } catch (_) {
      unawaited(socket.sink.close().catchError((Object _) {}));
      _reconnect(token);
    }
  }

  void _reconnect(String token) {
    if (_token != token) return;
    _socket = null;
    _retry?.cancel();
    _retry = Timer(
      const Duration(seconds: 3),
      () => unawaited(_connect(token)),
    );
    notifyListeners();
  }

  Future<void> _disconnect() async {
    _retry?.cancel();
    await _subscription?.cancel();
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.sink.close());
  }

  @override
  void dispose() {
    _token = null;
    unawaited(_disconnect());
    _service.close();
    super.dispose();
  }
}
