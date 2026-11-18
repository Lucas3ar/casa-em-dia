import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/home.dart';
import 'theme.dart';
import 'view_models.dart';

String shortDate(DateTime value) =>
    DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(value);

class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.bottom = 28});
  final List<Widget> children;
  final double bottom;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottom),
        children: children,
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding, child: child),
  );
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.label,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String label, title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [forest, Color(0xff275547)]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xffc9e6cd),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Icon(icon, color: mint),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: child,
        ),
      ],
    ),
  );
}

IconData roomIcon(String room) => switch (room) {
  'Cozinha' => Icons.soup_kitchen_outlined,
  'Banheiro' => Icons.bathtub_outlined,
  'Sala' => Icons.weekend_outlined,
  'Quarto' => Icons.bed_outlined,
  'Área externa' => Icons.local_florist_outlined,
  _ => Icons.home_work_outlined,
};

class ChoreTile extends StatelessWidget {
  const ChoreTile({super.key, required this.task, required this.vm});
  final Chore task;
  final TodayViewModel vm;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: mint,
          foregroundColor: forest,
          child: Icon(roomIcon(task.room), size: 20),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${task.room} · ${vm.owner(task)}\n${vm.late(task) ? 'Atrasada · ' : ''}${shortDate(task.due)}',
          style: TextStyle(color: vm.late(task) ? clay : null),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${task.points} pts',
              style: const TextStyle(
                color: forest,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (task.proof) const Icon(Icons.photo_camera_outlined, size: 16),
          ],
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => CompleteDialog(task: task, vm: vm),
        ),
      ),
    ),
  );
}

class CompleteDialog extends StatefulWidget {
  const CompleteDialog({super.key, required this.task, required this.vm});
  final Chore task;
  final TodayViewModel vm;
  @override
  State<CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<CompleteDialog> {
  String? before, after, error;
  bool working = false;

  Future<void> _photo(bool isBefore) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final result = await widget.vm.photo(camera: camera);
      if (result != null) {
        if (isBefore) {
          before = result;
        } else {
          after = result;
        }
      }
    } on FormatException catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'Não foi possível selecionar a foto.';
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _complete() async {
    setState(() => working = true);
    final ok = await widget.vm.complete(
      widget.task,
      before: before,
      after: after,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      working = false;
      error = widget.vm.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final allowed = widget.vm.canComplete(task);
    return AlertDialog(
      title: Text(task.title),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${task.room} · ${widget.vm.owner(task)}'),
          const SizedBox(height: 6),
          Text(
            '${shortDate(task.due)} · ${task.points} pontos · ${frequency[task.interval]}',
          ),
          if (task.rotate) const Text('Rodízio automático ativo'),
          if (task.proof)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Comprovação antes e depois'),
            ),
          if (task.proof && allowed) ...[
            for (final (label, photo, first) in [
              ('Antes', before, true),
              ('Depois', after, false),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: working ? null : () => _photo(first),
                  icon: photo == null
                      ? const Icon(Icons.add_a_photo_outlined)
                      : ProofPhoto(photo, height: 32),
                  label: Text(label),
                ),
              ),
          ],
          if (error != null) Text(error!, style: const TextStyle(color: clay)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: working ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (allowed)
          FilledButton(
            onPressed:
                working || (task.proof && (before == null || after == null))
                ? null
                : _complete,
            child: Text(working ? 'Aguarde…' : 'Concluir'),
          ),
      ],
    );
  }
}

class ProofPhoto extends StatelessWidget {
  const ProofPhoto(this.image, {super.key, required this.height});
  final String image;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Image.memory(
      base64Decode(image),
      width: height * 1.35,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    ),
  );
}
