import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/features/admin/clients_screen.dart';
import 'package:proyecto_app/features/admin/templates_screen.dart';
import 'package:proyecto_app/features/admin/users_screen.dart';
import 'package:proyecto_app/features/auth/login_screen.dart';
import 'package:proyecto_app/features/documents/documents_screen.dart';
import 'package:proyecto_app/features/equipment/equipment_detail_screen.dart';
import 'package:proyecto_app/features/equipment/equipment_screen.dart';
import 'package:proyecto_app/features/export/export_screen.dart';
import 'package:proyecto_app/features/findings/finding_form_screen.dart';
import 'package:proyecto_app/features/findings/findings_screen.dart';
import 'package:proyecto_app/features/forms/dynamic_form_screen.dart';
import 'package:proyecto_app/features/history/history_screen.dart';
import 'package:proyecto_app/features/measurements/measurement_form_screen.dart';
import 'package:proyecto_app/features/measurements/measurements_screen.dart';
import 'package:proyecto_app/features/photos/camera_capture_screen.dart';
import 'package:proyecto_app/features/photos/photo_detail_screen.dart';
import 'package:proyecto_app/features/photos/photo_group_screen.dart';
import 'package:proyecto_app/features/photos/photo_sections_screen.dart';
import 'package:proyecto_app/features/projects/new_project_screen.dart';
import 'package:proyecto_app/features/projects/project_detail_screen.dart';
import 'package:proyecto_app/features/projects/projects_screen.dart';
import 'package:proyecto_app/features/profile/profile_screen.dart';
import 'package:proyecto_app/features/report/report_preview_screen.dart';
import 'package:proyecto_app/features/review/review_screen.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/stats/stats_screen.dart';
import 'package:proyecto_app/features/sync/sync_screen.dart';
import 'package:proyecto_app/features/validation/validation_screen.dart';
import 'package:proyecto_app/features/videos/video_record_screen.dart';
import 'package:proyecto_app/features/videos/videos_screen.dart';
import 'package:proyecto_app/features/visits/new_visit_screen.dart';
import 'package:proyecto_app/features/visits/observations_screen.dart';
import 'package:proyecto_app/features/visits/visit_screen.dart';

void main() {
  final project = Mock.projects.first;
  final visit = project.visits.first;
  final group = Mock.photoGroups()[3];

  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Inicio (shell)': () => const HomeShell(),
    'Proyectos': () => const Scaffold(body: ProjectsScreen()),
    'Detalle de proyecto': () => ProjectDetailScreen(project: project),
    'Nuevo proyecto': () => const NewProjectScreen(),
    'Nueva visita': () => NewVisitScreen(project: project),
    'Levantamiento': () => VisitScreen(project: project, visit: visit),
    'Formulario dinámico': () => const DynamicFormScreen(),
    'Documentos': () => const DocumentsScreen(),
    'Fotografías': () => const PhotoSectionsScreen(),
    'Subsección de fotos': () => PhotoGroupScreen(group: group),
    'Detalle de foto': () =>
        PhotoDetailScreen(slot: group.slots.first, group: group, seed: 1),
    'Cámara': () => const CameraCaptureScreen(
          slotTitle: 'Tablero Principal – frente',
          groupCode: '3.4',
          groupTitle: 'Tableros y Canalizaciones',
        ),
    'Videos': () => const VideosScreen(),
    'Grabar video': () => const VideoRecordScreen(),
    'Mediciones': () => const MeasurementsScreen(),
    'Nueva medición': () => const MeasurementFormScreen(),
    'Equipos': () => const EquipmentScreen(),
    'Detalle de equipo': () => EquipmentDetailScreen(equipment: Mock.equipment.first),
    'Hallazgos': () => const FindingsScreen(),
    'Detalle de hallazgo': () => FindingFormScreen(finding: Mock.findings.first),
    'Observaciones y firma': () => const ObservationsScreen(),
    'Validación': () => ValidationScreen(project: project, progress: 0.92),
    'Reporte': () => ReportPreviewScreen(project: project),
    'Exportar': () => ExportScreen(project: project),
    'Sincronización': () => const SyncScreen(),
    'Estadísticas': () => const StatsScreen(),
    'Revisión': () => ReviewScreen(project: project),
    'Historial': () => const HistoryScreen(),
    'Usuarios': () => const UsersScreen(),
    'Clientes': () => const ClientsScreen(),
    'Plantillas': () => const TemplatesScreen(),
    'Perfil': () => const ProfileScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('Se dibuja sin errores: ${entry.key}', (tester) async {
      AppState.instance.setRole(UserRole.tecnico);
      await pumpOnPhone(tester, entry.value());
      expectNoRenderErrors(tester);
    });
  }
}
