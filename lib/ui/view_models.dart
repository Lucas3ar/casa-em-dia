import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/home_repository.dart';
import '../data/services/device_service.dart';
import '../domain/home.dart';

class ViewModel extends ChangeNotifier {
  ViewModel(this.repository) {
    repository.addListener(notifyListeners);
  }

  final HomeRepository repository;
  Home get home => repository.home!;
  String get actor => repository.actor!;
  bool busy = false;
  String? error;

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FormatException catch (failure) {
      error = failure.message;
      return false;
    } catch (_) {
      error = 'Não foi possível concluir a operação. Tente novamente.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    repository.removeListener(notifyListeners);
    super.dispose();
  }
}

class SessionViewModel extends ViewModel {
  SessionViewModel(super.repository, this.device) {
    repository.addListener(_scheduleReminders);
  }
  final DeviceService device;

  bool get hasHome => repository.home != null;
  String get houseName => home.name;
  bool get demo => repository.isDemo;
  bool get connected => repository.connected;
  Future<bool> restore() => run(repository.restore);
  Future<bool> open(String name, String value, bool join) =>
      run(() => repository.open(name, value, join: join));
  Future<bool> startDemo() => run(repository.startDemo);
  Future<bool> leave() => run(repository.leave);

  List<Chore> _scheduled = const [];
  Future<void> _scheduleReminders() async {
    final tasks =
        repository.home?.chores
            .where((task) => task.owner == repository.actor)
            .toList() ??
        <Chore>[];
    if (listEquals(
      _scheduled.map((task) => (task.id, task.due)).toList(),
      tasks.map((task) => (task.id, task.due)).toList(),
    )) {
      return;
    }
    try {
      await device.syncReminders(tasks);
      _scheduled = tasks;
    } catch (_) {
      // The in-app reminders remain available if native alarms fail.
    }
  }

  Future<bool> enableReminders() async {
    try {
      return await device.requestReminders();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    repository.removeListener(_scheduleReminders);
    super.dispose();
  }
}

DateTime dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

class TodayViewModel extends ViewModel {
  TodayViewModel(super.repository, this.device) {
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => notifyListeners(),
    );
  }
  final DeviceService device;
  late final Timer _clock;

  String get firstName => home.memberName(actor).split(' ').first;
  DateTime get now => DateTime.now();
  List<Chore> get tasks =>
      [...home.chores]..sort((a, b) => a.due.compareTo(b.due));
  List<Chore> get mine => tasks.where((task) => task.owner == actor).toList();
  List<Chore> get shared => tasks.where((task) => task.owner != actor).toList();
  List<Chore> get alerts => mine
      .where(
        (task) => task.due.isBefore(DateTime(now.year, now.month, now.day + 1)),
      )
      .toList();
  bool late(Chore task) => task.due.isBefore(now);
  int get doneToday => home.history
      .where((event) => !DateTime.parse(event['at']).isBefore(dayStart(now)))
      .length;
  int get dueToday =>
      tasks.where((task) => dayStart(task.due) == dayStart(now)).length;
  int get progressTotal => doneToday + dueToday;
  double get progress => progressTotal == 0 ? 0 : doneToday / progressTotal;
  String owner(Chore chore) => home.memberName(chore.owner);
  bool canComplete(Chore chore) => chore.owner == actor;
  List<Json> get myHistory => home.history
      .where((row) => row['owner'] == actor)
      .toList()
      .reversed
      .toList();

  Future<bool> complete(Chore task, {String? before, String? after}) => run(
    () => repository.act('complete', {
      'id': task.id,
      'before': before,
      'after': after,
    }),
  );

  Future<String?> photo({bool camera = false}) => device.photo(camera: camera);

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }
}

class HouseViewModel extends ViewModel {
  HouseViewModel(super.repository);
  String? room;
  String get code => home.code;
  String get name => home.name;
  bool get canInvite => !repository.isDemo;
  List<Member> get members => home.members;
  String get me => actor;
  List<String> get visibleRooms => room == null ? rooms : [room!];
  List<Chore> choresIn(String room) =>
      home.chores.where((task) => task.room == room).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
  void filter(String? value) {
    room = value;
    notifyListeners();
  }

  Future<bool> changeDemoMember(String id) =>
      run(() => repository.switchDemoMember(id));
  Future<bool> addTask(Json input) => run(() => repository.act('task', input));
}

typedef Score = ({String name, int points, int count, double share});

class PeriodViewModel extends ViewModel {
  PeriodViewModel(super.repository);
  bool month = false;
  void selectPeriod(bool value) {
    month = value;
    notifyListeners();
  }

  DateTime get since {
    final today = dayStart(DateTime.now());
    return month
        ? DateTime(today.year, today.month)
        : DateTime(today.year, today.month, today.day - today.weekday + 1);
  }

  List<Score> get scores {
    final rows = home.members
        .map(
          (member) => (name: member.name, stats: home.stats(member.id, since)),
        )
        .toList();
    final total = rows.fold(0, (sum, row) => sum + row.stats.points);
    return [
      for (final row in rows)
        (
          name: row.name,
          points: row.stats.points,
          count: row.stats.count,
          share: total == 0 ? 0.0 : row.stats.points / total,
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));
  }
}

class PointsViewModel extends PeriodViewModel {
  PointsViewModel(super.repository);
  int get balance => home.balance(actor);
  List<Reward> get rewards => home.rewards;
  List<Json> get redemptions => home.redemptions.reversed.toList();
  String memberName(String id) => home.memberName(id);
  Future<bool> addReward(String title, int cost) =>
      run(() => repository.act('reward', {'title': title, 'cost': cost}));
  Future<bool> redeem(Reward reward) =>
      run(() => repository.act('redeem', {'id': reward.id}));
}

class BalanceViewModel extends PeriodViewModel {
  BalanceViewModel(super.repository);
  int get totalTasks => scores.fold(0, (sum, row) => sum + row.count);
  int get totalPoints => scores.fold(0, (sum, row) => sum + row.points);
}
