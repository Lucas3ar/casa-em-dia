import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/home.dart';
import 'components.dart';
import 'theme.dart';
import 'view_models.dart';

class HouseView extends StatelessWidget {
  const HouseView({
    super.key,
    required this.vm,
    required this.today,
    required this.session,
  });
  final HouseViewModel vm;
  final TodayViewModel today;
  final SessionViewModel session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PageList(
      bottom: 100,
      children: [
        Text('Sua casa', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 14),
        HeroPanel(
          label: 'GRUPO RESIDENCIAL',
          title: vm.name,
          icon: Icons.cottage_outlined,
          child: Text('${vm.members.length} moradores'),
        ),
        const Section('Convidar moradores'),
        Surface(
          child: vm.canInvite
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compartilhe este código com quem mora na casa.',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            vm.code,
                            style: const TextStyle(
                              fontSize: 20,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar código',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: vm.code),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código copiado.'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                )
              : const Text(
                  'Crie uma casa na tela inicial para gerar um código de convite.',
                ),
        ),
        const Section('Tarefas por cômodo'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final room in [null, ...rooms])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(room ?? 'Todos'),
                    selected: vm.room == room,
                    onSelected: (_) => vm.filter(room),
                  ),
                ),
            ],
          ),
        ),
        for (final room in vm.visibleRooms)
          if (vm.room != null || vm.choresIn(room).isNotEmpty) ...[
            Section(room),
            if (vm.choresIn(room).isEmpty)
              const Surface(child: Text('Sem tarefas pendentes neste cômodo.')),
            for (final task in vm.choresIn(room))
              ChoreTile(task: task, vm: today),
          ],
        if (vm.room == null && vm.home.chores.isEmpty)
          const Surface(child: Text('Use “Nova tarefa” para começar.')),
        const Section('Moradores'),
        Surface(
          child: Column(
            children: [
              for (final member in vm.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: mint,
                    child: Text(member.name.characters.first.toUpperCase()),
                  ),
                  title: Text(member.name),
                  trailing: member.id == vm.me
                      ? const Text('Você')
                      : !vm.canInvite
                      ? TextButton(
                          onPressed: () => vm.changeDemoMember(member.id),
                          child: const Text('Usar perfil'),
                        )
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            final leave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Encerrar sessão neste aparelho?'),
                content: Text(
                  vm.canInvite
                      ? 'Para voltar com o mesmo perfil, mantenha esta sessão. Entrar pelo convite cria outro morador.'
                      : 'Você poderá começar uma nova demonstração na tela inicial.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Encerrar'),
                  ),
                ],
              ),
            );
            if (leave == true) await session.leave();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Encerrar sessão'),
        ),
      ],
    ),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.vm});
  final HouseViewModel vm;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late String _owner = widget.vm.me;
  late String _room = widget.vm.room ?? rooms.first;
  int _interval = 0, _points = 5;
  bool _rotate = false, _proof = false, _saving = false;
  DateTime _due = DateTime.now().add(const Duration(hours: 2));
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (time == null || !mounted) return;
    setState(
      () => _due = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.vm.addTask({
      'title': _title.text,
      'room': _room,
      'owner': _owner,
      'interval': _interval,
      'points': _points,
      'rotate': _rotate,
      'proof': _proof,
      'due': _due.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.vm.error;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nova tarefa')),
    body: Form(
      key: _form,
      child: PageList(
        children: [
          const Section('O que precisa ser feito?'),
          TextFormField(
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome da tarefa',
              hintText: 'Ex.: Limpar a bancada',
            ),
            validator: (value) =>
                value!.trim().isEmpty ? 'Informe um nome.' : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _room,
            decoration: const InputDecoration(labelText: 'Cômodo'),
            items: [
              for (final room in rooms)
                DropdownMenuItem(value: room, child: Text(room)),
            ],
            onChanged: (value) => setState(() => _room = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _owner,
            decoration: const InputDecoration(labelText: 'Responsável'),
            items: [
              for (final member in widget.vm.members)
                DropdownMenuItem(value: member.id, child: Text(member.name)),
            ],
            onChanged: (value) => setState(() => _owner = value!),
          ),
          const Section('Prazo e frequência'),
          OutlinedButton.icon(
            onPressed: _date,
            icon: const Icon(Icons.calendar_month),
            label: Text(shortDate(_due)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _interval,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: [
              for (final entry in frequency.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() {
              _interval = value!;
              if (_interval == 0) _rotate = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rodízio automático'),
            subtitle: Text(
              _interval == 0
                  ? 'Disponível em tarefas recorrentes'
                  : 'Passa ao próximo morador após a conclusão',
            ),
            value: _rotate,
            onChanged: _interval == 0
                ? null
                : (value) => setState(() => _rotate = value),
          ),
          const Section('Esforço e comprovação'),
          Text(
            '$_points pontos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _points.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_points',
            onChanged: (value) => setState(() => _points = value.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exigir fotos antes e depois'),
            value: _proof,
            onChanged: (value) => setState(() => _proof = value),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: clay)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Salvando…' : 'Salvar tarefa'),
          ),
        ],
      ),
    ),
  );
}
