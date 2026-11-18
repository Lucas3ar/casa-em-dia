import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/home.dart';
import 'components.dart';
import 'theme.dart';
import 'view_models.dart';

class TodayView extends StatelessWidget {
  const TodayView({super.key, required this.vm});
  final TodayViewModel vm;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PageList(
      bottom: 100,
      children: [
        Text(
          DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(vm.now).toUpperCase(),
          style: const TextStyle(
            color: forest,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Olá, ${vm.firstName}!',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        HeroPanel(
          label: 'RITMO DO LAR',
          title: '${(100 * vm.progress).round()}% concluído',
          icon: Icons.energy_savings_leaf_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: vm.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: mint,
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 10),
              Text(
                vm.progressTotal == 0
                    ? 'Nenhuma tarefa com prazo para hoje.'
                    : '${vm.doneToday} de ${vm.progressTotal} tarefas no resumo de hoje',
              ),
            ],
          ),
        ),
        const Section('Minhas tarefas'),
        if (vm.mine.isEmpty)
          const Surface(child: Text('Você está sem tarefas pendentes.')),
        for (final task in vm.mine) ChoreTile(task: task, vm: vm),
        const Section('Com os moradores'),
        if (vm.shared.isEmpty)
          const Surface(child: Text('As tarefas dos moradores aparecem aqui.')),
        for (final task in vm.shared) ChoreTile(task: task, vm: vm),
        const Section('Meu histórico'),
        if (vm.myHistory.isEmpty)
          const Surface(child: Text('Suas tarefas concluídas aparecem aqui.')),
        for (final row in vm.myHistory)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['title'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${shortDate(DateTime.parse(row['at']).toLocal())} · +${row['points']} pts',
                  ),
                  if (row['before'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          for (final (label, key) in [
                            ('Antes', 'before'),
                            ('Depois', 'after'),
                          ])
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label),
                                ProofPhoto(row[key], height: 64),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class AlertsView extends StatelessWidget {
  const AlertsView({super.key, required this.vm, required this.session});
  final TodayViewModel vm;
  final SessionViewModel session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lembretes')),
    body: ListenableBuilder(
      listenable: vm,
      builder: (context, _) => PageList(
        children: [
          const Section('Pendentes e atrasadas'),
          if (vm.alerts.isEmpty)
            const Surface(
              child: Text('Nenhuma tarefa sua vence hoje ou está atrasada.'),
            ),
          for (final Chore task in vm.alerts) ChoreTile(task: task, vm: vm),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final enabled = await session.enableReminders();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enabled
                          ? 'Notificações do Android habilitadas.'
                          : 'Os lembretes continuam disponíveis nesta tela.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Ativar notificações no Android'),
          ),
        ],
      ),
    ),
  );
}
