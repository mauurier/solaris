import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import 'auth/profile.dart';
import 'models.dart';

/// Estado global de la app: la sesión, el rol y los ajustes del teléfono.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  UserRole role = UserRole.tecnico;

  /// Id de `perfil` del usuario con sesión.
  String userId = '';
  String userName = '';
  String userInitials = '';

  /// Perfil de Supabase; nulo sin sesión.
  Profile? profile;
  /// "Pausar sincronización": no se sube ni se baja nada.
  bool offlineMode = false;

  /// Fotos, videos y documentos sólo se suben y bajan con Wi-Fi.
  bool syncOnWifiOnly = true;
  static const _wifiOnlyKey = 'ajustes.solo_wifi';

  /// Sincroniza sola al volver la conexión, tras cada cambio y cada rato.
  bool autoSync = true;
  static const _autoSyncKey = 'ajustes.sync_auto';

  /// La cámara pide un comentario después de cada foto.
  bool commentPerPhoto = false;
  static const _commentKey = 'ajustes.comentario_por_foto';

  void signIn(Profile p) {
    profile = p;
    role = p.uiRole;
    userId = p.id;
    userName = p.name;
    userInitials = p.initials;
    notifyListeners();
  }

  /// Al cerrar sesión.
  void signOut() {
    profile = null;
    role = UserRole.tecnico;
    userId = '';
    userName = '';
    userInitials = '';
    notifyListeners();
  }

  /// Lee los ajustes guardados en el teléfono.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    syncOnWifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
    autoSync = prefs.getBool(_autoSyncKey) ?? true;
    commentPerPhoto = prefs.getBool(_commentKey) ?? false;
  }

  Future<void> setCommentPerPhoto(bool v) async {
    commentPerPhoto = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_commentKey, v);
  }

  Future<void> setAutoSync(bool v) async {
    autoSync = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_autoSyncKey, v);
  }

  Future<void> setSyncOnWifiOnly(bool v) async {
    syncOnWifiOnly = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_wifiOnlyKey, v);
  }

  void toggleOffline() {
    offlineMode = !offlineMode;
    notifyListeners();
  }

  void update() => notifyListeners();
}

/// Datos de ejemplo de las pantallas que aún son vista previa (Reporte PDF y
/// Hallazgos). Se quitan cuando cada una use datos
/// reales.
class Mock {
  Mock._();

  static final projects = <Project>[
    Project(
      id: 'PRJ-2026-0142',
      name: 'TRUPER Monterrey',
      client: 'TRUPER',
      type: 'Viabilidad FV',
      site: 'CEDIS Monterrey',
      address: 'Av. Industrial 2200, Apodaca, N.L.',
      coords: '25.7834, -100.1889',
      responsible: 'Juan Pérez',
      supervisor: 'Laura Méndez',
      technicians: ['Juan Pérez', 'Diego Salas'],
      createdAt: '02 Ago 2026',
      scheduledAt: '16 Ago 2026',
      status: ProjectStatus.enCaptura,
      progress: 0.86,
      lastActivity: 'Hace 12 min',
      criticalFindings: 2,
      pendings: 3,
      description:
          'Levantamiento eléctrico para análisis de viabilidad fotovoltaica en cubierta de CEDIS. Incluye acometida en media tensión, dos transformadores y cuatro tableros.',
      indicators: [
        Indicator('Información', 1.00, AppColors.success, Icons.description_rounded),
        Indicator('Documentación', 0.80, AppColors.warning, Icons.folder_rounded),
        Indicator('Fotografías', 0.92, AppColors.accent, Icons.photo_camera_rounded),
        Indicator('Videos', 1.00, AppColors.success, Icons.videocam_rounded),
        Indicator('Mediciones', 0.85, AppColors.blue, Icons.electric_bolt_rounded),
        Indicator('Hallazgos', 1.00, AppColors.success, Icons.report_problem_rounded),
        Indicator('Reporte', 0.40, AppColors.danger, Icons.picture_as_pdf_rounded),
      ],
      visits: [
        Visit(
          id: 'VIS-001',
          date: '16 Ago 2026',
          start: '08:42',
          end: '—',
          technician: 'Juan Pérez',
          supervisor: 'Laura Méndez',
          type: 'Levantamiento eléctrico FV',
          motive: 'Levantamiento inicial',
          status: ProjectStatus.enCaptura,
          progress: 0.86,
          locationStart: '25.7834, -100.1889',
          locationEnd: '—',
        ),
        Visit(
          id: 'VIS-002',
          date: '09 Ago 2026',
          start: '09:15',
          end: '13:40',
          technician: 'Diego Salas',
          supervisor: 'Laura Méndez',
          type: 'Reconocimiento previo',
          motive: 'Validación de accesos y cubierta',
          status: ProjectStatus.aprobado,
          progress: 1.0,
        ),
      ],
    ),
    Project(
      id: 'PRJ-2026-0138',
      name: 'BIMBO Querétaro',
      client: 'Grupo BIMBO',
      type: 'Levantamiento eléctrico',
      site: 'Planta Querétaro',
      address: 'Parque Industrial Bernardo Quintana, Qro.',
      coords: '20.6180, -100.3899',
      responsible: 'Diego Salas',
      supervisor: 'Laura Méndez',
      technicians: ['Diego Salas'],
      createdAt: '28 Jul 2026',
      scheduledAt: '12 Ago 2026',
      status: ProjectStatus.enRevision,
      progress: 0.94,
      lastActivity: 'Hace 3 h',
      criticalFindings: 1,
      pendings: 1,
      description: 'Levantamiento de sistema FV existente de 320 kWp y ampliación proyectada.',
      indicators: [
        Indicator('Información', 1.00, AppColors.success, Icons.description_rounded),
        Indicator('Documentación', 1.00, AppColors.success, Icons.folder_rounded),
        Indicator('Fotografías', 0.96, AppColors.accent, Icons.photo_camera_rounded),
        Indicator('Videos', 1.00, AppColors.success, Icons.videocam_rounded),
        Indicator('Mediciones', 1.00, AppColors.success, Icons.electric_bolt_rounded),
        Indicator('Hallazgos', 0.90, AppColors.warning, Icons.report_problem_rounded),
        Indicator('Reporte', 0.75, AppColors.blue, Icons.picture_as_pdf_rounded),
      ],
      visits: [
        Visit(
          id: 'VIS-001',
          date: '12 Ago 2026',
          start: '07:50',
          end: '15:20',
          technician: 'Diego Salas',
          supervisor: 'Laura Méndez',
          type: 'Levantamiento eléctrico FV',
          motive: 'Levantamiento inicial',
          status: ProjectStatus.enRevision,
          progress: 0.94,
        ),
      ],
    ),
    Project(
      id: 'PRJ-2026-0151',
      name: 'CEMEX Puebla',
      client: 'CEMEX',
      type: 'Viabilidad FV',
      site: 'Planta Cementera Puebla',
      address: 'Carr. Federal Puebla-Tehuacán km 12, Pue.',
      coords: '18.9982, -98.1876',
      responsible: 'Ana Torres',
      supervisor: 'Laura Méndez',
      technicians: ['Ana Torres'],
      createdAt: '18 Ago 2026',
      scheduledAt: '03 Sep 2026',
      status: ProjectStatus.asignado,
      progress: 0.0,
      lastActivity: 'Ayer',
      pendings: 0,
      description: 'Estudio de viabilidad para planta FV en piso de 1.2 MWp.',
      indicators: [
        Indicator('Información', 0.0, AppColors.textMuted, Icons.description_rounded),
        Indicator('Documentación', 0.0, AppColors.textMuted, Icons.folder_rounded),
        Indicator('Fotografías', 0.0, AppColors.textMuted, Icons.photo_camera_rounded),
        Indicator('Videos', 0.0, AppColors.textMuted, Icons.videocam_rounded),
        Indicator('Mediciones', 0.0, AppColors.textMuted, Icons.electric_bolt_rounded),
        Indicator('Hallazgos', 0.0, AppColors.textMuted, Icons.report_problem_rounded),
        Indicator('Reporte', 0.0, AppColors.textMuted, Icons.picture_as_pdf_rounded),
      ],
      visits: [
        Visit(
          id: 'VIS-001',
          date: '03 Sep 2026',
          start: '—',
          end: '—',
          technician: 'Ana Torres',
          supervisor: 'Laura Méndez',
          type: 'Levantamiento eléctrico FV',
          motive: 'Levantamiento inicial',
          status: ProjectStatus.programado,
          progress: 0,
        ),
      ],
    ),
    Project(
      id: 'PRJ-2026-0129',
      name: 'FEMSA Guadalajara',
      client: 'FEMSA',
      type: 'Auditoría FV',
      site: 'CEDIS Zapopan',
      address: 'Anillo Periférico Nte. 1200, Zapopan, Jal.',
      coords: '20.7214, -103.4053',
      responsible: 'Juan Pérez',
      supervisor: 'Laura Méndez',
      technicians: ['Juan Pérez'],
      createdAt: '10 Jul 2026',
      scheduledAt: '24 Jul 2026',
      status: ProjectStatus.conCorrecciones,
      progress: 0.71,
      lastActivity: 'Hace 2 días',
      criticalFindings: 3,
      pendings: 5,
      description: 'Auditoría de sistema FV existente con 4 inversores centrales.',
      indicators: [
        Indicator('Información', 1.00, AppColors.success, Icons.description_rounded),
        Indicator('Documentación', 0.60, AppColors.danger, Icons.folder_rounded),
        Indicator('Fotografías', 0.78, AppColors.warning, Icons.photo_camera_rounded),
        Indicator('Videos', 0.50, AppColors.danger, Icons.videocam_rounded),
        Indicator('Mediciones', 0.90, AppColors.blue, Icons.electric_bolt_rounded),
        Indicator('Hallazgos', 1.00, AppColors.success, Icons.report_problem_rounded),
        Indicator('Reporte', 0.20, AppColors.danger, Icons.picture_as_pdf_rounded),
      ],
      visits: [
        Visit(
          id: 'VIS-001',
          date: '24 Jul 2026',
          start: '08:00',
          end: '14:10',
          technician: 'Juan Pérez',
          supervisor: 'Laura Méndez',
          type: 'Auditoría FV',
          motive: 'Levantamiento inicial',
          status: ProjectStatus.conCorrecciones,
          progress: 0.71,
        ),
      ],
    ),
    Project(
      id: 'PRJ-2026-0110',
      name: 'HEB Saltillo',
      client: 'HEB México',
      type: 'Viabilidad FV',
      site: 'Sucursal Saltillo Norte',
      address: 'Blvd. Nazario Ortiz 1400, Saltillo, Coah.',
      coords: '25.4589, -101.0044',
      responsible: 'Diego Salas',
      supervisor: 'Laura Méndez',
      technicians: ['Diego Salas'],
      createdAt: '02 Jun 2026',
      scheduledAt: '15 Jun 2026',
      status: ProjectStatus.aprobado,
      progress: 1.0,
      lastActivity: '20 Jun 2026',
      description: 'Levantamiento completo aprobado y entregado.',
      indicators: [
        Indicator('Información', 1.0, AppColors.success, Icons.description_rounded),
        Indicator('Documentación', 1.0, AppColors.success, Icons.folder_rounded),
        Indicator('Fotografías', 1.0, AppColors.success, Icons.photo_camera_rounded),
        Indicator('Videos', 1.0, AppColors.success, Icons.videocam_rounded),
        Indicator('Mediciones', 1.0, AppColors.success, Icons.electric_bolt_rounded),
        Indicator('Hallazgos', 1.0, AppColors.success, Icons.report_problem_rounded),
        Indicator('Reporte', 1.0, AppColors.success, Icons.picture_as_pdf_rounded),
      ],
      visits: [
        Visit(
          id: 'VIS-001',
          date: '15 Jun 2026',
          start: '08:30',
          end: '13:00',
          technician: 'Diego Salas',
          supervisor: 'Laura Méndez',
          type: 'Levantamiento eléctrico FV',
          motive: 'Levantamiento inicial',
          status: ProjectStatus.aprobado,
          progress: 1.0,
        ),
      ],
    ),
  ];

  static Project get active => projects.first;

  static final findings = <Finding>[
    Finding(
      id: 'HZ-001',
      category: 'Eléctrico',
      description: 'Interruptor principal sin señalización de bloqueo y etiquetado ilegible.',
      severity: Severity.alta,
      location: 'Cuarto eléctrico · Tablero Principal',
      date: '16 Ago 2026 · 11:08',
      user: 'Juan Pérez',
      recommendation: 'Instalar señalización LOTO y reetiquetar circuitos conforme NOM-001-SEDE.',
      status: FindingStatus.abierto,
      evidences: 3,
    ),
    Finding(
      id: 'HZ-002',
      category: 'Termográfico',
      description: 'Punto caliente de 92 °C en borne L2 del Tablero Principal.',
      severity: Severity.critica,
      location: 'Cuarto eléctrico · Tablero Principal',
      date: '16 Ago 2026 · 11:12',
      user: 'Juan Pérez',
      recommendation: 'Reapretar conexión y reprogramar termografía en 30 días.',
      status: FindingStatus.abierto,
      evidences: 2,
    ),
    Finding(
      id: 'HZ-003',
      category: 'Cubierta',
      description: 'Corrosión avanzada en lámina de cubierta, zona sur (aprox. 40 m²).',
      severity: Severity.critica,
      location: 'Cubierta · Zona sur',
      date: '16 Ago 2026 · 09:26',
      user: 'Juan Pérez',
      recommendation: 'Evaluación estructural previa a montaje de estructura FV.',
      status: FindingStatus.enRevision,
      evidences: 4,
    ),
    Finding(
      id: 'HZ-004',
      category: 'Seguridad',
      description: 'Ausencia de línea de vida en acceso a cubierta.',
      severity: Severity.media,
      location: 'Acceso a cubierta',
      date: '16 Ago 2026 · 09:05',
      user: 'Juan Pérez',
      recommendation: 'Instalar línea de vida certificada antes de trabajos en altura.',
      status: FindingStatus.corregido,
      evidences: 1,
    ),
    Finding(
      id: 'HZ-005',
      category: 'Documental',
      description: 'Diagrama unifilar no corresponde con la instalación actual.',
      severity: Severity.baja,
      location: 'Expediente técnico',
      date: '16 Ago 2026 · 12:40',
      user: 'Juan Pérez',
      recommendation: 'Actualizar unifilar as-built posterior al levantamiento.',
      status: FindingStatus.abierto,
      evidences: 1,
    ),
  ];

  static const folderTree = <(int, String, String)>[
    (0, 'TRUPER_MONTERREY', 'folder'),
    (1, '01 Información del Sitio', 'folder'),
    (2, 'INFO_GENERAL_SITIO.pdf', 'pdf'),
    (1, '02 Documentación Existente', 'folder'),
    (2, 'RECIBO_CFE_TRUPER_MONTERREY.pdf', 'pdf'),
    (2, 'DIAGRAMA_UNIFILAR_TRUPER_MTY.dwg', 'dwg'),
    (2, 'MEMORIA_CALCULO_2024.xlsx', 'xlsx'),
    (1, '03 Fotografías', 'folder'),
    (2, '3.1 Dron y Cubierta', 'folder'),
    (3, 'DRON_GENERAL_001.jpg', 'jpg'),
    (3, 'CUBIERTA_NORTE_002.jpg', 'jpg'),
    (2, '3.2 Sistema FV Existente', 'folder'),
    (2, '3.3 Acometida, Medidor y Transformador', 'folder'),
    (3, 'TRANSFORMADOR_PLACA_001.jpg', 'jpg'),
    (2, '3.4 Tableros y Canalizaciones', 'folder'),
    (3, 'Tablero Principal', 'folder'),
    (4, 'TABLERO_PRINCIPAL_FRENTE_001.jpg', 'jpg'),
    (4, 'TABLERO_PRINCIPAL_ITM_002.jpg', 'jpg'),
    (4, 'TABLERO_PRINCIPAL_TERMOGRAFIA_003.jpg', 'jpg'),
    (3, 'Tablero 01', 'folder'),
    (3, 'Tablero 02', 'folder'),
    (3, 'Tablero 03', 'folder'),
    (2, '3.5 Generales', 'folder'),
    (1, '04 Videos', 'folder'),
    (2, 'RECORRIDO_GENERAL_001.mp4', 'mp4'),
    (2, 'VUELO_DRON_001.mp4', 'mp4'),
    (1, '05 Reporte de Levantamiento', 'folder'),
    (2, 'REPORTE_TRUPER_MTY_v1.2.pdf', 'pdf'),
    (1, '06 CAD y Modelos 3D', 'folder'),
    (1, 'Evidencias Adicionales', 'folder'),
  ];
}
