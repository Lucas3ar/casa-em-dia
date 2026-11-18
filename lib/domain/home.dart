import 'dart:convert';
import 'dart:math';

typedef Json = Map<String, dynamic>;

const rooms = [
  'Cozinha',
  'Banheiro',
  'Sala',
  'Quarto',
  'Área externa',
  'Outros',
];
const frequency = {0: 'Avulsa', 1: 'Diária', 7: 'Semanal', 14: 'Quinzenal'};

String newId([int bytes = 18]) {
  final random = Random.secure();
  return base64UrlEncode(List.generate(bytes, (_) => random.nextInt(256)));
}

class Member {
  final String id;
  final String name;
  Member.fromJson(Json json) : id = json['id'], name = json['name'];
}

class Chore {
  final String id, title, room, owner;
  final DateTime due;
  final int points, interval;
  final bool rotate, proof;
  Chore.fromJson(Json json)
    : id = json['id'],
      title = json['title'],
      room = json['room'],
      owner = json['owner'],
      due = DateTime.parse(json['due']).toLocal(),
      points = json['points'],
      interval = json['interval'],
      rotate = json['rotate'],
      proof = json['proof'];
}

class Reward {
  final String id, title;
  final int cost;
  Reward.fromJson(Json json)
    : id = json['id'],
      title = json['title'],
      cost = json['cost'];
}

class Home {
  final String name, code;
  final List<Member> members;
  final List<Chore> chores;
  final List<Reward> rewards;
  final List<Json> history, redemptions;

  Home.fromJson(Json json)
    : name = json['name'],
      code = json['code'],
      members = List.unmodifiable(_list(json, 'members').map(Member.fromJson)),
      chores = List.unmodifiable(_list(json, 'tasks').map(Chore.fromJson)),
      rewards = List.unmodifiable(_list(json, 'rewards').map(Reward.fromJson)),
      history = List.unmodifiable(_list(json, 'history')),
      redemptions = List.unmodifiable(_list(json, 'redemptions'));

  String memberName(String id) =>
      members.firstWhere((member) => member.id == id).name;

  ({int points, int count}) stats(String id, [DateTime? since]) {
    final events = history.where((event) {
      return event['owner'] == id &&
          (since == null || !DateTime.parse(event['at']).isBefore(since));
    }).toList();
    return (
      points: events.fold(0, (sum, e) => sum + (e['points'] as int)),
      count: events.length,
    );
  }

  int balance(String id) =>
      stats(id).points -
      redemptions
          .where((event) => event['owner'] == id)
          .fold<int>(0, (sum, e) => sum + (e['cost'] as int));
}

List<Json> _list(Json json, String key) => (json[key] as List).cast<Json>();

class HomeRules {
  static String label(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.trim().length > max) {
      throw const FormatException(
        'Preencha o nome respeitando o limite de caracteres.',
      );
    }
    return value.trim();
  }

  static Json newHome(String name, String code) => {
    'name': label(name, 60),
    'code': code,
    'members': <Json>[],
    'tasks': <Json>[],
    'history': <Json>[],
    'rewards': <Json>[],
    'redemptions': <Json>[],
  };

  static Json addMember(Json home, String name) {
    final member = {'id': newId(), 'name': label(name, 40)};
    _list(home, 'members').add(member);
    return member;
  }

  static Json apply(
    Json original,
    String actor,
    String action,
    Json input,
    DateTime now,
  ) {
    final home = jsonDecode(jsonEncode(original)) as Json;
    final members = _list(home, 'members');
    final tasks = _list(home, 'tasks');
    final rewards = _list(home, 'rewards');
    if (!members.any((member) => member['id'] == actor)) {
      throw const FormatException('Morador não encontrado.');
    }

    switch (action) {
      case 'task':
        final due = DateTime.tryParse(input['due']?.toString() ?? '');
        final points = input['points'];
        if (!rooms.contains(input['room']) ||
            !frequency.containsKey(input['interval']) ||
            points is! int ||
            points < 1 ||
            points > 10 ||
            due == null ||
            !members.any((member) => member['id'] == input['owner'])) {
          throw const FormatException('Confira os dados da tarefa.');
        }
        tasks.add({
          'id': newId(),
          'title': label(input['title'], 80),
          'room': input['room'],
          'owner': input['owner'],
          'due': due.toUtc().toIso8601String(),
          'points': points,
          'interval': input['interval'],
          'rotate': input['rotate'] == true && input['interval'] != 0,
          'proof': input['proof'] == true,
        });
      case 'complete':
        final task = _find(
          tasks,
          input['id'],
          'Esta tarefa já foi concluída ou reagendada.',
        );
        if (task['owner'] != actor) {
          throw const FormatException(
            'Somente a pessoa responsável pode concluir a tarefa.',
          );
        }
        final photos = <String, String>{};
        if (task['proof'] == true) {
          for (final key in ['before', 'after']) {
            final photo = input[key];
            if (photo is! String || photo.isEmpty || photo.length > 1900000) {
              throw const FormatException(
                'Anexe as duas fotos, com até 1,4 MB cada.',
              );
            }
            final bytes = base64Decode(photo);
            final jpeg = bytes.length > 4 && bytes[0] == 255 && bytes[1] == 216;
            final png =
                bytes.length > 8 &&
                bytes[0] == 137 &&
                bytes[1] == 80 &&
                bytes[2] == 78 &&
                bytes[3] == 71;
            if (!jpeg && !png) {
              throw const FormatException('Use fotos em JPEG ou PNG.');
            }
            photos[key] = photo;
          }
        }
        _list(home, 'history').add({
          'id': task['id'],
          'title': task['title'],
          'owner': actor,
          'points': task['points'],
          'at': now.toUtc().toIso8601String(),
          ...photos,
        });
        tasks.remove(task);
        final interval = task['interval'] as int;
        if (interval > 0) {
          final due = DateTime.parse(task['due']);
          final periods = max(1, now.difference(due).inDays ~/ interval + 1);
          final next = due.add(Duration(days: periods * interval));
          final position = members.indexWhere((m) => m['id'] == actor);
          tasks.add({
            ...task,
            'id': newId(),
            'due': next.toIso8601String(),
            'owner': task['rotate'] == true
                ? members[(position + 1) % members.length]['id']
                : actor,
          });
        }
      case 'reward':
        final cost = input['cost'];
        if (cost is! int || cost < 1 || cost > 9999) {
          throw const FormatException(
            'Informe um custo entre 1 e 9999 pontos.',
          );
        }
        rewards.add({
          'id': newId(),
          'title': label(input['title'], 80),
          'cost': cost,
        });
      case 'redeem':
        final reward = _find(
          rewards,
          input['id'],
          'Recompensa não encontrada.',
        );
        if (Home.fromJson(home).balance(actor) < (reward['cost'] as int)) {
          throw const FormatException('Saldo de pontos insuficiente.');
        }
        _list(
          home,
          'redemptions',
        ).add({...reward, 'owner': actor, 'at': now.toUtc().toIso8601String()});
      default:
        throw const FormatException('Operação desconhecida.');
    }
    return home;
  }

  static Json _find(List<Json> rows, Object? id, String message) =>
      rows.firstWhere(
        (row) => row['id'] == id,
        orElse: () => throw FormatException(message),
      );
}
