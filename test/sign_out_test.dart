import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/app_state.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:proyecto_app/data/sync/sync_service.dart';
import 'package:proyecto_app/features/profile/sign_out.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_remote.dart';
import 'test_helpers.dart';

void main() {
  late SurveyStore store;
  late FakeRemote server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    signInAs(UserRole.admin);
    store = await initTestStore();
    server = FakeRemote();
    final sync = SyncService.instance;
    sync.remote = server;
    sync.filesAllowed = () async => true;
    sync.online = true;
    AppState.instance.offlineMode = false;
  });

  tearDown(() => AppState.instance.offlineMode = false);

  /// Botón que llama a [prepareSignOut] y guarda lo que contestó.
  Future<List<bool>> mount(WidgetTester tester) async {
    final answers = <bool>[];
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => answers.add(await prepareSignOut(context)),
            child: const Text('salir'),
          ),
        ),
      ),
    );
    return answers;
  }

  testWidgets('sin nada pendiente cierra de inmediato', (tester) async {
    final answers = await mount(tester);
    await tester.tap(find.text('salir'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
    expect(server.writes, isEmpty);
  });

  testWidgets('sube lo pendiente de esta cuenta antes de cerrar', (tester) async {
    await tester.runAsync(() => store.addClient('TRUPER'));
    expect(await tester.runAsync(store.pendingCount), 1);

    final answers = await mount(tester);
    await tester.tap(find.text('salir'));
    // La subida la lanza el propio cierre de sesión.
    for (var i = 0; i < 50 && answers.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }

    expect(answers, [true]);
    expect(find.text('Subiendo cambios'), findsNothing);
    expect(server.rows('cliente').single['razon_social'], 'TRUPER');
    expect(await tester.runAsync(store.pendingCount), 0);
  });

  testWidgets('si el servidor rechaza algo avisa y se puede cancelar', (tester) async {
    await tester.runAsync(() => store.addClient('TRUPER'));
    server.onWrite = (table, op) => throw const RemoteRejected('No tienes permiso para cambiar este registro.');

    final answers = await mount(tester);
    await tester.tap(find.text('salir'));
    await tester.pump();
    await tester.runAsync(() => SyncService.instance.sync());
    await tester.pumpAndSettle();

    expect(find.text('Queda 1 cambio sin subir'), findsOneWidget);
    expect(find.textContaining('El servidor no aceptó un cambio: No tienes permiso'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(answers, [false], reason: 'la sesión sigue abierta para resolverlo');
  });

  testWidgets('con la sincronización pausada no sube, avisa y deja salir', (tester) async {
    await tester.runAsync(() => store.addClient('TRUPER'));
    AppState.instance.offlineMode = true;

    final answers = await mount(tester);
    await tester.tap(find.text('salir'));
    await tester.pumpAndSettle();

    expect(find.text('Subiendo cambios'), findsNothing);
    expect(find.text('La sincronización está pausada.'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
    expect(server.writes, isEmpty);
  });
}
