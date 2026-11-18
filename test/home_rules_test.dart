import 'package:casa_em_dia/domain/home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recorrência gera uma ocorrência distinta e roda o responsável', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    var state = HomeRules.newHome('República', 'CASA');
    final first = HomeRules.addMember(state, 'Ana')['id'] as String;
    final second = HomeRules.addMember(state, 'Bruno')['id'] as String;
    state = HomeRules.apply(state, first, 'task', {
      'title': 'Lavar banheiro',
      'room': 'Banheiro',
      'owner': first,
      'points': 8,
      'interval': 7,
      'rotate': true,
      'proof': true,
      'due': now.toIso8601String(),
    }, now);
    final task = Home.fromJson(state).chores.single;
    expect(
      () => HomeRules.apply(state, second, 'complete', {'id': task.id}, now),
      throwsFormatException,
    );
    expect(
      () => HomeRules.apply(state, first, 'complete', {'id': task.id}, now),
      throwsFormatException,
    );

    const jpeg = '/9j/2f8=';
    state = HomeRules.apply(state, first, 'complete', {
      'id': task.id,
      'before': jpeg,
      'after': jpeg,
    }, now);
    final result = Home.fromJson(state);
    expect(result.chores.single.owner, second);
    expect(result.chores.single.due.toUtc(), now.add(const Duration(days: 7)));
    expect(result.chores.single.id, isNot(task.id));
    expect(result.stats(first).points, 8);
    expect(
      () => HomeRules.apply(state, first, 'complete', {'id': task.id}, now),
      throwsFormatException,
    );

    state = HomeRules.apply(state, first, 'reward', {
      'title': 'Escolher filme',
      'cost': 5,
    }, now);
    final reward = Home.fromJson(state).rewards.single;
    state = HomeRules.apply(state, first, 'redeem', {'id': reward.id}, now);
    expect(Home.fromJson(state).balance(first), 3);
    expect(
      () => HomeRules.apply(state, first, 'redeem', {'id': reward.id}, now),
      throwsFormatException,
    );
  });
}
