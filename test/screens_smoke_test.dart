import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/template.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:proyecto_app/features/admin/clients_screen.dart';
import 'package:proyecto_app/features/admin/question_editor_screen.dart';
import 'package:proyecto_app/features/admin/template_editor_screen.dart';
import 'package:proyecto_app/features/admin/templates_screen.dart';
import 'package:proyecto_app/features/admin/users_screen.dart';
import 'package:proyecto_app/features/auth/login_screen.dart';
import 'package:proyecto_app/features/capture/camera_screen.dart';
import 'package:proyecto_app/features/equipment/equipment_detail_screen.dart';
import 'package:proyecto_app/features/equipment/equipment_screen.dart';
import 'package:proyecto_app/features/export/export_screen.dart';
import 'package:proyecto_app/features/export/zip_export_screen.dart';
import 'package:proyecto_app/features/findings/finding_form_screen.dart';
import 'package:proyecto_app/features/findings/findings_screen.dart';
import 'package:proyecto_app/features/history/history_screen.dart';
import 'package:proyecto_app/features/measurements/measurement_form_screen.dart';
import 'package:proyecto_app/features/measurements/measurements_screen.dart';
import 'package:proyecto_app/features/photos/photo_sections_screen.dart';
import 'package:proyecto_app/features/profile/profile_screen.dart';
import 'package:proyecto_app/features/projects/new_project_screen.dart';
import 'package:proyecto_app/features/projects/project_detail_screen.dart';
import 'package:proyecto_app/features/projects/projects_screen.dart';
import 'package:proyecto_app/features/report/report_preview_screen.dart';
import 'package:proyecto_app/features/review/review_screen.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/stats/stats_screen.dart';
import 'package:proyecto_app/features/sync/sync_screen.dart';
import 'package:proyecto_app/features/visits/new_visit_screen.dart';
import 'package:proyecto_app/features/visits/section_screen.dart';
import 'package:proyecto_app/features/visits/validation_screen.dart';
import 'package:proyecto_app/features/visits/visit_screen.dart';
import 'package:proyecto_app/features/visits/visits_tab.dart';

void main() {
  late SurveyStore store;

  setUp(() async {
    AppState.instance.setRole(UserRole.tecnico);
    store = await initTestStore();
    await seedProject(store); // visita sin iniciar
    await seedProject(store, start: true); // visita en curso
  });

  final mock = Mock.projects.first;

  // Pantallas conectadas a datos reales.
  final real = <String, Widget Function(SurveyStore s)>{
    'Inicio (shell)': (_) => const HomeShell(),
    'Proyectos': (_) => const Scaffold(body: ProjectsScreen()),
    'Visitas': (_) => const Scaffold(body: VisitsTab()),
    'Detalle de proyecto': (s) => ProjectDetailScreen(project: s.projects.first),
    'Nuevo proyecto': (_) => const NewProjectScreen(),
    'Nueva visita': (s) => NewVisitScreen(project: s.projects.first),
    'Visita sin iniciar': (s) => VisitScreen(visit: s.visits.firstWhere((v) => !v.started)),
    'Visita en curso': (s) => VisitScreen(visit: s.visits.firstWhere((v) => v.started)),
    'Validación': (s) => ValidationScreen(visit: s.visits.firstWhere((v) => v.started)),
    'Exportar ZIP': (s) => ZipExportScreen(project: s.projects.first),
    'Plantillas': (_) => const TemplatesScreen(),
    'Editor de plantilla': (s) => TemplateEditorScreen(template: s.templates.first),
    'Editor de sección': (s) => SectionEditorScreen(section: s.templates.first.sections[1], sectionIndex: 1, onChanged: () {}),
    'Editor de pregunta': (s) => QuestionEditorScreen(
          group: s.templates.first.sections[1].groups[1],
          question: s.templates.first.sections[1].groups[1].questions.first.copy(),
        ),
    'Nueva pregunta de foto': (s) => QuestionEditorScreen(
          group: s.templates.first.sections[1].groups[1],
          question: QuestionDef(id: 'x', label: '', type: QType.photo),
        ),
    'Perfil': (_) => const ProfileScreen(),
    'Acceso': (_) => const LoginScreen(),
  };

  for (final entry in real.entries) {
    testWidgets('Se dibuja sin errores: ${entry.key}', (tester) async {
      await pumpOnPhone(tester, entry.value(store));
      expectNoRenderErrors(tester);
    });
  }

  testWidgets('La cámara sin hardware muestra el aviso y marca "SIN GPS"', (tester) async {
    await pumpOnPhone(tester, const CameraScreen(title: 'Placa de datos', subtitle: '2.1.11 · Transformador 1'));
    // En pruebas no hay cámara ni GPS: se agotan los topes de tiempo.
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
    expect(find.text('Cámara no disponible'), findsOneWidget);
    expect(find.text('SIN GPS'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  for (var i = 0; i < 6; i++) {
    testWidgets('Se dibuja sin errores: sección ${i + 1} del levantamiento', (tester) async {
      await pumpOnPhone(tester, SectionScreen(visit: store.visits.firstWhere((v) => v.started), sectionIndex: i, editable: true));
      expectNoRenderErrors(tester);
    });
  }

  // Módulos de vista previa que siguen con datos de ejemplo.
  final previews = <String, Widget Function()>{
    'Revisión': () => ReviewScreen(project: mock),
    'Reporte': () => ReportPreviewScreen(project: mock),
    'Exportar (vista previa)': () => ExportScreen(project: mock),
    'Fotografías (vista previa)': () => const PhotoSectionsScreen(),
    'Mediciones': () => const MeasurementsScreen(),
    'Nueva medición': () => const MeasurementFormScreen(),
    'Equipos': () => const EquipmentScreen(),
    'Detalle de equipo': () => EquipmentDetailScreen(equipment: Mock.equipment.first),
    'Hallazgos': () => const FindingsScreen(),
    'Detalle de hallazgo': () => FindingFormScreen(finding: Mock.findings.first),
    'Sincronización': () => const SyncScreen(),
    'Estadísticas': () => const StatsScreen(),
    'Historial': () => const HistoryScreen(),
    'Usuarios': () => const UsersScreen(),
    'Clientes': () => const ClientsScreen(),
  };

  for (final entry in previews.entries) {
    testWidgets('Se dibuja sin errores: ${entry.key}', (tester) async {
      await pumpOnPhone(tester, entry.value());
      expectNoRenderErrors(tester);
    });
  }
}
