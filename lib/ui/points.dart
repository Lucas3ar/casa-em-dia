import 'package:flutter/material.dart';

import '../domain/home.dart';
import 'components.dart';
import 'theme.dart';
import 'view_models.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector(this.vm, {super.key});
  final PeriodViewModel vm;
  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('Esta semana')),
      ButtonSegment(value: true, label: Text('Este mês')),
    ],
    selected: {vm.month},
    onSelectionChanged: (values) => vm.selectPeriod(values.first),
  );
}

class PointsView extends StatelessWidget {
  const PointsView({super.key, required this.vm});
  final PointsViewModel vm;

  Future<void> _redeem(BuildContext context, Reward reward) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reward.title),
        content: Text(
          'Usar ${reward.cost} pontos para resgatar esta recompensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final ok = await vm.redeem(reward);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Recompensa resgatada.' : vm.error ?? 'Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PageList(
      children: [
        Text(
          'Pontos e recompensas',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        HeroPanel(
          label: 'SEU SALDO',
          title: '${vm.balance} pontos',
          icon: Icons.stars_outlined,
          child: const Text(
            'Conclua tarefas e troque pontos por recompensas da casa.',
          ),
        ),
        const Section('Ranking da casa'),
        Align(alignment: Alignment.centerLeft, child: PeriodSelector(vm)),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            children: [
              for (final (index, score) in vm.scores.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: mint,
                    child: Text('${index + 1}º'),
                  ),
                  title: Text(score.name),
                  subtitle: Text('${score.count} concluídas'),
                  trailing: Text(
                    '${score.points} pts',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
        Section(
          'Recompensas',
          action: IconButton(
            tooltip: 'Adicionar recompensa',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RewardEditor(vm),
            ),
          ),
        ),
        if (vm.rewards.isEmpty)
          const Surface(
            child: Text('Adicione uma recompensa combinada com a casa.'),
          ),
        for (final reward in vm.rewards)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: mint,
                  child: Icon(Icons.card_giftcard_outlined),
                ),
                title: Text(reward.title),
                subtitle: Text('${reward.cost} pts'),
                trailing: TextButton(
                  onPressed: vm.busy || vm.balance < reward.cost
                      ? null
                      : () => _redeem(context, reward),
                  child: const Text('Resgatar'),
                ),
              ),
            ),
          ),
        if (vm.redemptions.isNotEmpty) ...[
          const Section('Resgates da casa'),
          for (final row in vm.redemptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Surface(
                child: Text(
                  '${vm.memberName(row['owner'])} · ${row['title']} · ${row['cost']} pts',
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

class RewardEditor extends StatefulWidget {
  const RewardEditor(this.vm, {super.key});
  final PointsViewModel vm;
  @override
  State<RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends State<RewardEditor> {
  final title = TextEditingController();
  final cost = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    cost.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.vm.addReward(
      title.text,
      int.tryParse(cost.text.trim()) ?? 0,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      error = widget.vm.error;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova recompensa'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Recompensa'),
        ),
        TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Custo em pontos'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: const TextStyle(color: clay)),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Salvando…' : 'Salvar'),
      ),
    ],
  );
}

class BalanceView extends StatelessWidget {
  const BalanceView({super.key, required this.vm});
  final BalanceViewModel vm;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PageList(
      children: [
        Text(
          'Equilíbrio do lar',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: PeriodSelector(vm)),
        const SizedBox(height: 14),
        HeroPanel(
          label: 'RESUMO DA CASA',
          title: '${vm.totalTasks} concluídas',
          icon: Icons.balance_outlined,
          child: Text('${vm.totalPoints} pontos de esforço no período'),
        ),
        const Section('Esforço por morador'),
        if (vm.totalPoints == 0)
          const Surface(
            child: Text('Conclua tarefas para ver a distribuição de esforço.'),
          ),
        if (vm.totalPoints > 0)
          Surface(
            child: Column(
              children: [
                for (final score in vm.scores)
                  ShareBar(
                    name: score.name,
                    value: score.share,
                    detail: '${score.points} pts · ${score.count} tarefas',
                  ),
              ],
            ),
          ),
        const Section('Tarefas por morador'),
        if (vm.totalTasks == 0)
          const Surface(child: Text('Nenhuma tarefa concluída neste período.')),
        if (vm.totalTasks > 0)
          Surface(
            child: Column(
              children: [
                for (final score in vm.scores)
                  ShareBar(
                    name: score.name,
                    value: score.count / vm.totalTasks,
                    detail: '${score.count} concluídas',
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.name,
    required this.value,
    required this.detail,
  });
  final String name, detail;
  final double value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${(100 * value).round()}%',
              style: const TextStyle(
                color: forest,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: mint,
          borderRadius: BorderRadius.circular(10),
          semanticsLabel: 'Participação de $name',
        ),
        const SizedBox(height: 5),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
