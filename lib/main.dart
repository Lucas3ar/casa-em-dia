import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/repositories/home_repository.dart';
import 'data/services/device_service.dart';
import 'data/services/home_service.dart';
import 'ui/components.dart';
import 'ui/house.dart';
import 'ui/points.dart';
import 'ui/theme.dart';
import 'ui/today.dart';
import 'ui/view_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  const configured = String.fromEnvironment('CASA_API');
  final defaultHost = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  final service = HomeService(
    Uri.parse(configured.isEmpty ? 'http://$defaultHost:8080' : configured),
  );
  runApp(
    CasaEmDia(repository: HomeRepository(service), device: DeviceService()),
  );
}

class CasaEmDia extends StatefulWidget {
  const CasaEmDia({super.key, required this.repository, required this.device});
  final HomeRepository repository;
  final DeviceService device;

  @override
  State<CasaEmDia> createState() => _CasaEmDiaState();
}

class _CasaEmDiaState extends State<CasaEmDia> {
  late final session = SessionViewModel(widget.repository, widget.device);
  bool restoring = true;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    await session.restore();
    if (mounted) setState(() => restoring = false);
  }

  @override
  void dispose() {
    session.dispose();
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Casa em Dia',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: session,
      builder: (_, _) {
        if (restoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!session.hasHome) return WelcomeView(vm: session);
        return HomeShell(
          repository: widget.repository,
          session: session,
          device: widget.device,
        );
      },
    ),
  );
}

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key, required this.vm});
  final SessionViewModel vm;
  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  final name = TextEditingController();
  final value = TextEditingController();
  bool join = false;

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageList(
        children: [
          const SizedBox(height: 35),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.cottage_rounded, color: forest, size: 32),
            ),
          ),
          const SizedBox(height: 18),
          Text('Casa em Dia', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Organize as tarefas e divida o esforço da casa.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Criar casa')),
                ButtonSegment(value: true, label: Text('Entrar com código')),
              ],
              selected: {join},
              onSelectionChanged: widget.vm.busy
                  ? null
                  : (selection) => setState(() {
                      join = selection.first;
                      value.clear();
                    }),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Seu nome'),
          ),
          TextField(
            controller: value,
            maxLength: join ? 24 : 60,
            autocorrect: !join,
            textCapitalization: join
                ? TextCapitalization.characters
                : TextCapitalization.words,
            decoration: InputDecoration(
              labelText: join ? 'Código de convite' : 'Nome da casa',
              hintText: join ? null : 'Ex.: Apartamento 402',
            ),
          ),
          if (widget.vm.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.vm.error!,
                style: const TextStyle(color: clay),
              ),
            ),
          FilledButton(
            onPressed: widget.vm.busy
                ? null
                : () => widget.vm.open(name.text, value.text, join),
            child: Text(
              widget.vm.busy
                  ? 'Aguarde…'
                  : join
                  ? 'Entrar na casa'
                  : 'Criar minha casa',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.vm.busy ? null : widget.vm.startDemo,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Explorar demonstração'),
          ),
        ],
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.session,
    required this.device,
  });
  final HomeRepository repository;
  final SessionViewModel session;
  final DeviceService device;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final today = TodayViewModel(widget.repository, widget.device);
  late final house = HouseViewModel(widget.repository);
  late final points = PointsViewModel(widget.repository);
  late final balance = BalanceViewModel(widget.repository);
  int selected = 0;

  @override
  void dispose() {
    today.dispose();
    house.dispose();
    points.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Icon(Icons.cottage_rounded, color: forest, size: 21),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Casa em Dia',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          Text(
            widget.session.demo
                ? '${widget.session.houseName} · Demonstração'
                : widget.session.connected
                ? widget.session.houseName
                : '${widget.session.houseName} · Reconectando',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        ListenableBuilder(
          listenable: today,
          builder: (context, _) => IconButton(
            tooltip: 'Lembretes',
            icon: Badge(
              isLabelVisible: today.alerts.isNotEmpty,
              label: Text('${today.alerts.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlertsView(vm: today, session: widget.session),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: IndexedStack(
        index: selected,
        children: [
          TodayView(vm: today),
          HouseView(vm: house, today: today, session: widget.session),
          PointsView(vm: points),
          BalanceView(vm: balance),
        ],
      ),
    ),
    floatingActionButton: selected > 1
        ? null
        : FloatingActionButton.extended(
            backgroundColor: forest,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => TaskEditor(vm: house)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nova tarefa'),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.event_available_outlined),
          label: 'Hoje',
        ),
        NavigationDestination(
          icon: Icon(Icons.cottage_outlined),
          label: 'Casa',
        ),
        NavigationDestination(
          icon: Icon(Icons.stars_outlined),
          label: 'Pontos',
        ),
        NavigationDestination(
          icon: Icon(Icons.balance_outlined),
          label: 'Equilíbrio',
        ),
      ],
    ),
  );
}
