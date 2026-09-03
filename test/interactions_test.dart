import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/features/export/export_screen.dart';
import 'package:proyecto_app/features/photos/camera_capture_screen.dart';
import 'package:proyecto_app/features/projects/new_project_screen.dart';
import 'package:proyecto_app/features/projects/project_detail_screen.dart';
import 'package:proyecto_app/features/measurements/measurement_form_screen.dart';
import 'package:proyecto_app/features/report/report_preview_screen.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/stats/stats_screen.dart';
import 'package:proyecto_app/features/validation/validation_screen.dart';
import 'package:proyecto_app/features/visits/visit_screen.dart';

import 'test_helpers.dart';

void main() {
  final project = Mock.projects.first;

  testWidgets('El panel se adapta a cada rol', (tester) async {
    for (final role in UserRole.values) {
      AppState.instance.setRole(role);
      await pumpOnPhone(tester, const HomeShell());
      expectNoRenderErrors(tester);
      expect(find.textContaining('Hola,'), findsOneWidget);
    }
    AppState.instance.setRole(UserRole.tecnico);
  });

  testWidgets('Las pestañas del proyecto se dibujan sin errores', (tester) async {
    await pumpOnPhone(tester, ProjectDetailScreen(project: project));

    for (final tab in ['Visitas', 'Evidencias', 'Reportes', 'Resumen']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });

  testWidgets('Las pestañas de estadísticas se dibujan sin errores', (tester) async {
    await pumpOnPhone(tester, const StatsScreen());

    for (final scope in ['Técnico', 'Proyecto', 'Empresa']) {
      await tester.tap(find.text(scope));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });

  testWidgets('El asistente de nuevo proyecto avanza por sus pasos', (tester) async {
    await pumpOnPhone(tester, const NewProjectScreen());

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
    expect(find.text('Crear proyecto'), findsOneWidget);
  });

  testWidgets('La cámara muestra la vista previa tras capturar', (tester) async {
    await pumpOnPhone(
      tester,
      const CameraCaptureScreen(
        slotTitle: 'Transformador 01 – placa de datos',
        groupCode: '3.3',
        groupTitle: 'Acometida, Medidor y Transformador',
      ),
    );

    await tester.tap(find.byType(GestureDetector).last);
    await tester.pumpAndSettle();

    expect(find.text('Fotografía capturada'), findsOneWidget);
    expect(find.text('Usar fotografía'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('El formulario de mediciones cambia de parámetro', (tester) async {
    await pumpOnPhone(tester, const MeasurementFormScreen());

    for (final family in ['Corriente', 'Otros', 'Tensión']) {
      await tester.tap(find.text(family));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });

  testWidgets('La captura rápida se abre desde el levantamiento', (tester) async {
    AppState.instance.setRole(UserRole.tecnico);
    await pumpOnPhone(
      tester,
      VisitScreen(project: project, visit: project.visits.first),
    );

    await tester.tap(find.byIcon(Icons.add_a_photo_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Captura rápida'), findsOneWidget);
    expect(find.text('Medición'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('La validación permite justificar un pendiente', (tester) async {
    AppState.instance.setRole(UserRole.supervisor);
    await pumpOnPhone(tester, ValidationScreen(project: project, progress: 0.92));

    expect(find.text('Justificar'), findsWidgets);
    await tester.tap(find.text('Justificar').first);
    await tester.pumpAndSettle();

    expect(find.text('Justificar pendiente'), findsOneWidget);
    expectNoRenderErrors(tester);
    AppState.instance.setRole(UserRole.tecnico);
  });

  testWidgets('El reporte se genera y muestra el archivo', (tester) async {
    await pumpOnPhone(tester, ReportPreviewScreen(project: project));

    await tester.tap(find.text('Generar reporte PDF'));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('REPORTE_TRUPER_MTY_v1.2.pdf'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('REPORTE_TRUPER_MTY_v1.2.pdf'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('La exportación abre la hoja de compartir', (tester) async {
    await pumpOnPhone(tester, ExportScreen(project: project));

    await tester.scrollUntilVisible(
      find.text('Compartir con apps del dispositivo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Separa la fila del borde inferior para que no quede bajo la barra fija.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartir con apps del dispositivo'));
    await tester.pumpAndSettle();

    expect(find.text('Compartir proyecto'), findsOneWidget);
    expectNoRenderErrors(tester);
  });
}
