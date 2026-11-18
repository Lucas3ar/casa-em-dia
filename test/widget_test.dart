import 'package:casa_em_dia/data/repositories/home_repository.dart';
import 'package:casa_em_dia/data/services/device_service.dart';
import 'package:casa_em_dia/data/services/home_service.dart';
import 'package:casa_em_dia/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('demo abre as abas e adiciona uma tarefa', (tester) async {
    await initializeDateFormatting('pt_BR');
    const device = MethodChannel('casa_em_dia/device');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      device,
      (_) async => null,
    );
    await tester.pumpWidget(
      CasaEmDia(
        repository: HomeRepository(
          HomeService(Uri.parse('http://127.0.0.1:8080')),
        ),
        device: DeviceService(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar demonstração'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Mariana!'), findsOneWidget);

    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Arrumar a despensa',
    );
    await tester.scrollUntilVisible(
      find.text('Salvar tarefa'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvar tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Arrumar a despensa'),
      240,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('Arrumar a despensa'), findsOneWidget);
    await tester.tap(find.text('Pontos'));
    await tester.pumpAndSettle();
    expect(find.text('Pontos e recompensas'), findsOneWidget);
    await tester.tap(find.text('Equilíbrio'));
    await tester.pumpAndSettle();
    expect(find.text('Esforço por morador'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
