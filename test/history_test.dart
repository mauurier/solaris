import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/theme/app_colors.dart';
import 'package:proyecto_app/data/history.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/features/history/history_screen.dart';
import 'package:proyecto_app/features/history/history_text.dart';

import 'test_helpers.dart';

/// Historial en memoria, del más reciente al más antiguo.
class FakeHistory implements HistorySource {
  FakeHistory(this.entries);
  final List<HistoryEntry> entries;
  final asked = <({String? projectId, Set<String>? tables, int offset})>[];
  String? fail;

  @override
  Future<List<HistoryEntry>> page({String? projectId, Set<String>? tables, required int offset, required int limit}) async {
    asked.add((projectId: projectId, tables: tables, offset: offset));
    if (fail != null) throw HistoryError(fail!);
    final all = entries
        .where((e) => projectId == null || e.projectId == projectId)
        .where((e) => tables == null || tables.contains(e.table))
        .toList();
    return all.skip(offset).take(limit).toList();
  }
}

HistoryEntry entry(String table, String action,
        {Map<String, Object?> before = const {}, Map<String, Object?> after = const {}, String? user, String? visit, DateTime? at}) =>
    HistoryEntry(
      id: '$table-$action-${at?.microsecondsSinceEpoch ?? 0}-${after.hashCode}',
      table: table,
      action: action,
      at: at ?? DateTime.now(),
      userId: user,
      projectId: 'p1',
      visitId: visit,
      before: before,
      after: after,
    );

void main() {
  setUp(() async {
    signInAs(UserRole.admin);
    await initTestStore();
  });

  test('cada cambio se cuenta en una frase', () {
    final juan = uid('Juan Pérez');
    String title(HistoryEntry e) => describeEntry(e).title;

    expect(title(entry('proyecto', 'crear', after: {'codigo': 'MTY0142', 'nombre': 'TRUPER'})), 'Creó el proyecto');
    expect(describeEntry(entry('proyecto', 'editar', before: {'estado': 'en_captura'}, after: {'estado': 'en_revision'})).title,
        'Proyecto: En revisión');
    expect(title(entry('visita', 'editar', before: {'numero': 1, 'fecha_inicio': null}, after: {'numero': 1, 'fecha_inicio': '2026-10-31T10:00:00Z'})),
        'Inició la visita');
    expect(title(entry('visita', 'editar', before: {'numero': 1, 'fecha_fin': null}, after: {'numero': 1, 'fecha_fin': '2026-10-31T12:00:00Z'})),
        'Terminó la visita');
    expect(title(entry('evidencia', 'crear', after: {'tipo': 'video', 'nombre_original': 'recorrido.mp4'})), 'Subió un video');
    expect(title(entry('revision', 'crear', after: {'decision': 'aprobada'})), 'Aprobó la visita');
    expect(title(entry('correccion', 'editar', before: {'estado': 'pendiente'}, after: {'estado': 'atendida', 'descripcion': 'Medir L3'})),
        'Atendió una corrección');
    expect(title(entry('proyecto_tecnico', 'crear', after: {'id_tecnico': juan})), 'Asignó a un técnico');
    expect(describeEntry(entry('proyecto_tecnico', 'crear', after: {'id_tecnico': juan})).detail, 'Juan Pérez');

    final removed = describeEntry(entry('evidencia', 'eliminar', before: {'tipo': 'foto'}, after: {'tipo': 'foto', 'eliminado_en': 'x'}));
    expect(removed.title, 'Borró una foto');
    expect(removed.color, AppColors.danger);
    expect(describeEntry(entry('plantilla', 'crear', after: {'nombre': 'FV', 'version_mayor': 1, 'version_menor': 0})).user,
        'Sistema', reason: 'sin usuario lo hizo el sistema');
  });

  test('las respuestas seguidas de la misma visita se juntan', () {
    final juan = uid('Juan Pérez');
    final events = describeHistory([
      for (var i = 0; i < 3; i++) entry('respuesta', 'crear', after: {'clave_pregunta': 'q$i'}, user: juan, visit: 'v1'),
      entry('visita', 'editar', before: {'numero': 1, 'fecha_inicio': null}, after: {'numero': 1, 'fecha_inicio': 'x'}),
      entry('respuesta', 'crear', user: juan, visit: 'v1'),
    ]);
    expect(events.map((e) => e.$2.title), ['Capturó 3 respuestas', 'Inició la visita', 'Capturó una respuesta']);
  });

  testWidgets('la pantalla agrupa por día, filtra y pide más', (tester) async {
    final now = DateTime.now();
    final source = historySource = FakeHistory([
      for (var i = 0; i < 50; i++)
        entry('cliente', 'crear', after: {'razon_social': 'Cliente $i'}, at: now.subtract(Duration(minutes: i))),
      entry('revision', 'crear', after: {'decision': 'con_correcciones', 'observaciones': 'Falta la placa'},
          at: now.subtract(const Duration(days: 1))),
    ]);
    await pumpOnPhone(tester, const HistoryScreen());
    expect(find.text('HOY'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Ver más'), findsOneWidget, reason: 'vino una página completa');
    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(source.asked.last.offset, 50);

    await tester.tap(find.text('Revisión'));
    await tester.pumpAndSettle();
    expect(source.asked.last.tables, {'revision', 'correccion'});
    expect(find.text('AYER'), findsOneWidget);
    expect(find.text('Pidió correcciones'), findsOneWidget);
    expect(find.text('Falta la placa'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing);
    expectNoRenderErrors(tester);
  });

  testWidgets('sin conexión avisa en lugar de quedarse en blanco', (tester) async {
    historySource = FakeHistory([])..fail = 'Sin conexión. Inténtalo cuando tengas internet.';
    await pumpOnPhone(tester, const HistoryScreen());
    expect(find.textContaining('No se pudo cargar el historial'), findsOneWidget);
    expectNoRenderErrors(tester);
  });
}
