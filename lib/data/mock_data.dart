import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'models.dart';

/// Estado global del prototipo (sin backend, sólo datos simulados en memoria).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  UserRole role = UserRole.tecnico;
  String userName = 'Juan Pérez';
  String userInitials = 'JP';
  bool offlineMode = false;
  bool syncOnWifiOnly = true;
  bool autoSync = true;
  bool commentPerPhoto = false;
  bool gpsStamp = true;
  double syncProgress = 0.68;

  void setRole(UserRole r) {
    role = r;
    switch (r) {
      case UserRole.admin:
        userName = 'Mauricio Aquino';
        userInitials = 'MA';
      case UserRole.supervisor:
        userName = 'Laura Méndez';
        userInitials = 'LM';
      case UserRole.tecnico:
        userName = 'Juan Pérez';
        userInitials = 'JP';
      case UserRole.revisor:
        userName = 'Ing. Carlos Ruiz';
        userInitials = 'CR';
    }
    notifyListeners();
  }

  void toggleOffline() {
    offlineMode = !offlineMode;
    notifyListeners();
  }

  void update() => notifyListeners();
}

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

  static List<SurveySection> sections() => [
        SurveySection(
          code: '01',
          title: 'Información del Sitio',
          subtitle: 'Datos generales y condiciones',
          icon: Icons.apartment_rounded,
          color: AppColors.blue,
          done: 14,
          total: 14,
          route: 'form',
        ),
        SurveySection(
          code: '02',
          title: 'Documentación Existente',
          subtitle: 'Recibo CFE, unifilar, planos',
          icon: Icons.folder_copy_rounded,
          color: AppColors.violet,
          done: 4,
          total: 5,
          route: 'docs',
          requiredPending: 1,
        ),
        SurveySection(
          code: '03',
          title: 'Fotografías',
          subtitle: '5 subsecciones · 24 evidencias',
          icon: Icons.photo_camera_rounded,
          color: AppColors.accent,
          done: 22,
          total: 24,
          route: 'photos',
          requiredPending: 2,
        ),
        SurveySection(
          code: '04',
          title: 'Videos',
          subtitle: 'Recorrido general y vuelo de dron',
          icon: Icons.videocam_rounded,
          color: AppColors.teal,
          done: 2,
          total: 2,
          route: 'videos',
        ),
        SurveySection(
          code: '05',
          title: 'Mediciones Eléctricas',
          subtitle: 'Tensión, corriente y parámetros',
          icon: Icons.electric_bolt_rounded,
          color: AppColors.warning,
          done: 11,
          total: 13,
          route: 'measure',
          requiredPending: 1,
        ),
        SurveySection(
          code: '06',
          title: 'Equipos',
          subtitle: 'Transformadores, tableros, inversores',
          icon: Icons.precision_manufacturing_rounded,
          color: AppColors.blue,
          done: 7,
          total: 8,
          route: 'equipment',
          requiredPending: 1,
        ),
        SurveySection(
          code: '07',
          title: 'Hallazgos',
          subtitle: '5 registrados · 2 críticos',
          icon: Icons.report_problem_rounded,
          color: AppColors.danger,
          done: 5,
          total: 5,
          route: 'findings',
        ),
        SurveySection(
          code: '08',
          title: 'Observaciones y Firma',
          subtitle: 'Notas finales y cierre de visita',
          icon: Icons.draw_rounded,
          color: AppColors.success,
          done: 1,
          total: 2,
          route: 'notes',
        ),
      ];

  static List<PhotoGroup> photoGroups() => [
        PhotoGroup(code: '3.1', title: 'Dron y Cubierta', icon: Icons.flight_rounded, slots: [
          PhotoSlot(title: 'Vista aérea general', code: 'DRON_GENERAL_001', isRequired: true, captured: true, time: '09:12'),
          PhotoSlot(title: 'Cubierta – zona norte', code: 'CUBIERTA_NORTE_002', isRequired: true, captured: true, time: '09:15'),
          PhotoSlot(title: 'Cubierta – zona sur', code: 'CUBIERTA_SUR_003', isRequired: true, captured: true, time: '09:17'),
          PhotoSlot(title: 'Detalle de lámina / anclaje', code: 'CUBIERTA_DETALLE_004', isRequired: false, captured: true, time: '09:20'),
          PhotoSlot(title: 'Obstáculos y sombreados', code: 'CUBIERTA_SOMBRAS_005', isRequired: true, captured: true, time: '09:24'),
        ]),
        PhotoGroup(code: '3.2', title: 'Sistema FV Existente', icon: Icons.solar_power_rounded, slots: [
          PhotoSlot(title: 'Arreglo de módulos', code: 'FV_MODULOS_001', isRequired: true, captured: true, time: '09:44'),
          PhotoSlot(title: 'Placa de módulo', code: 'FV_PLACA_MODULO_002', isRequired: true, captured: true, time: '09:46'),
          PhotoSlot(title: 'Inversor 01 – frente', code: 'FV_INVERSOR01_003', isRequired: true, captured: true, time: '09:52'),
          PhotoSlot(title: 'Inversor 02 – frente', code: 'FV_INVERSOR02_004', isRequired: true, captured: true, time: '09:55'),
        ]),
        PhotoGroup(code: '3.3', title: 'Acometida, Medidor y Transformador', icon: Icons.bolt_rounded, slots: [
          PhotoSlot(title: 'Acometida general', code: 'ACOMETIDA_001', isRequired: true, captured: true, time: '10:20'),
          PhotoSlot(title: 'Medidor CFE', code: 'MEDIDOR_CFE_002', isRequired: true, captured: true, time: '10:23'),
          PhotoSlot(title: 'Transformador 01 – vista general', code: 'TRANSFORMADOR_01_003', isRequired: true, captured: true, time: '10:31'),
          PhotoSlot(title: 'Transformador 01 – placa de datos', code: 'TRANSFORMADOR_PLACA_004', isRequired: true, captured: false),
          PhotoSlot(title: 'Transformador 02 – vista general', code: 'TRANSFORMADOR_02_005', isRequired: false, captured: true, time: '10:38'),
        ]),
        PhotoGroup(code: '3.4', title: 'Tableros y Canalizaciones', icon: Icons.dashboard_customize_rounded, slots: [
          PhotoSlot(title: 'Tablero Principal – frente', code: 'TABLERO_PRINCIPAL_FRENTE_001', isRequired: true, captured: true, time: '11:02'),
          PhotoSlot(title: 'Tablero Principal – interruptor', code: 'TABLERO_PRINCIPAL_ITM_002', isRequired: true, captured: true, time: '11:04'),
          PhotoSlot(title: 'Tablero Principal – termografía', code: 'TABLERO_PRINCIPAL_TERMO_003', isRequired: true, captured: true, time: '11:07'),
          PhotoSlot(title: 'Tablero 01 – frente', code: 'TABLERO_01_FRENTE_004', isRequired: true, captured: true, time: '11:15'),
          PhotoSlot(title: 'Tablero 02 – frente', code: 'TABLERO_02_FRENTE_005', isRequired: true, captured: true, time: '11:19'),
          PhotoSlot(title: 'Tablero 03 – frente', code: 'TABLERO_03_FRENTE_006', isRequired: true, captured: false),
          PhotoSlot(title: 'Canalización principal', code: 'CANALIZACION_007', isRequired: false, captured: true, time: '11:26'),
        ]),
        PhotoGroup(code: '3.5', title: 'Generales', icon: Icons.image_rounded, slots: [
          PhotoSlot(title: 'Fachada del sitio', code: 'GENERAL_FACHADA_001', isRequired: true, captured: true, time: '08:50'),
          PhotoSlot(title: 'Acceso principal', code: 'GENERAL_ACCESO_002', isRequired: false, captured: true, time: '08:52'),
          PhotoSlot(title: 'Área disponible para inversores', code: 'GENERAL_AREA_003', isRequired: false, captured: true, time: '12:05'),
        ]),
      ];

  static final measurements = <Measurement>[
    Measurement(point: 'Tablero Principal', type: 'Tensión Fase-Fase (L1-L2)', value: '441.2', unit: 'V', instrument: 'Fluke 376 FC', time: '11:10'),
    Measurement(point: 'Tablero Principal', type: 'Tensión Fase-Fase (L2-L3)', value: '440.8', unit: 'V', instrument: 'Fluke 376 FC', time: '11:11'),
    Measurement(point: 'Tablero Principal', type: 'Tensión Fase-Fase (L1-L3)', value: '442.0', unit: 'V', instrument: 'Fluke 376 FC', time: '11:11'),
    Measurement(point: 'Tablero Principal', type: 'Tensión Fase-Neutro (L1-N)', value: '254.6', unit: 'V', instrument: 'Fluke 376 FC', time: '11:12'),
    Measurement(point: 'Tablero Principal', type: 'Corriente L1', value: '312.4', unit: 'A', instrument: 'Fluke 376 FC', time: '11:14'),
    Measurement(point: 'Tablero Principal', type: 'Corriente L2', value: '298.7', unit: 'A', instrument: 'Fluke 376 FC', time: '11:14'),
    Measurement(point: 'Tablero Principal', type: 'Corriente L3', value: '305.1', unit: 'A', instrument: 'Fluke 376 FC', time: '11:15', note: 'Desbalance < 5 %'),
    Measurement(point: 'Tablero 01', type: 'Tensión Fase-Fase (L1-L2)', value: '439.5', unit: 'V', instrument: 'Fluke 376 FC', time: '11:32'),
    Measurement(point: 'Tablero 01', type: 'Corriente L1', value: '128.9', unit: 'A', instrument: 'Fluke 376 FC', time: '11:33'),
    Measurement(point: 'Transformador 01', type: 'Resistencia de tierra', value: '3.8', unit: 'Ω', instrument: 'Megger DET3TC', time: '10:44'),
    Measurement(point: 'Transformador 01', type: 'Temperatura carcasa', value: '62.3', unit: '°C', instrument: 'FLIR E8', time: '10:47'),
  ];

  static final equipment = <Equipment>[
    Equipment(id: 'EQ-01', name: 'Transformador 01', category: 'Transformador', brand: 'Prolec GE', model: 'PAD-750', serial: 'TR-88213-A', capacity: '750 kVA · 23 kV / 440 V', location: 'Subestación exterior', photos: 4, icon: Icons.electrical_services_rounded),
    Equipment(id: 'EQ-02', name: 'Transformador 02', category: 'Transformador', brand: 'Prolec GE', model: 'PAD-500', serial: 'TR-88999-B', capacity: '500 kVA · 23 kV / 440 V', location: 'Subestación exterior', photos: 2, icon: Icons.electrical_services_rounded),
    Equipment(id: 'EQ-03', name: 'Tablero Principal', category: 'Tablero', brand: 'Schneider', model: 'Blokset', serial: 'TB-2201', capacity: '1600 A · 440 V', location: 'Cuarto eléctrico', photos: 3, icon: Icons.dashboard_customize_rounded),
    Equipment(id: 'EQ-04', name: 'Tablero 01', category: 'Tablero', brand: 'Square D', model: 'NQOD', serial: 'TB-2202', capacity: '400 A · 440 V', location: 'Nave A', photos: 2, icon: Icons.dashboard_customize_rounded),
    Equipment(id: 'EQ-05', name: 'Tablero 02', category: 'Tablero', brand: 'Square D', model: 'NQOD', serial: 'TB-2203', capacity: '400 A · 440 V', location: 'Nave B', photos: 2, icon: Icons.dashboard_customize_rounded),
    Equipment(id: 'EQ-06', name: 'Tablero 03', category: 'Tablero', brand: 'Square D', model: 'NQOD', serial: '—', capacity: '250 A · 440 V', location: 'Nave C', photos: 0, icon: Icons.dashboard_customize_rounded, complete: false),
    Equipment(id: 'EQ-07', name: 'Inversor 01', category: 'Inversor', brand: 'Huawei', model: 'SUN2000-100KTL', serial: 'INV-4471', capacity: '100 kW', location: 'Cuarto FV', photos: 3, icon: Icons.solar_power_rounded),
    Equipment(id: 'EQ-08', name: 'Inversor 02', category: 'Inversor', brand: 'Huawei', model: 'SUN2000-100KTL', serial: 'INV-4472', capacity: '100 kW', location: 'Cuarto FV', photos: 3, icon: Icons.solar_power_rounded),
  ];

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

  static final documents = <DocItem>[
    DocItem(name: 'RECIBO_CFE_TRUPER_MONTERREY', category: 'Recibo CFE', size: '1.4 MB', ext: 'pdf', date: '16 Ago · 08:55'),
    DocItem(name: 'DIAGRAMA_UNIFILAR_TRUPER_MTY', category: 'Diagrama unifilar', size: '820 KB', ext: 'dwg', date: '16 Ago · 09:02'),
    DocItem(name: 'PLANO_ARQUITECTONICO_CEDIS', category: 'Plano arquitectónico', size: '3.1 MB', ext: 'pdf', date: '16 Ago · 09:04'),
    DocItem(name: 'MEMORIA_CALCULO_2024', category: 'Memoria de cálculo', size: '640 KB', ext: 'xlsx', date: '16 Ago · 09:06'),
    DocItem(name: 'TERMOGRAFIA_TABLERO_PRINCIPAL', category: 'Cámara térmica', size: '2.2 MB', ext: 'jpg', date: '16 Ago · 11:12'),
  ];

  static const requiredDocs = <String>[
    'Recibo CFE',
    'Diagrama unifilar',
    'Plano arquitectónico',
    'Memoria de cálculo',
    'Plano estructural',
  ];

  static final videos = <VideoItem>[
    VideoItem(
      title: 'RECORRIDO_GENERAL_001',
      type: 'Recorrido general',
      duration: '04:32',
      size: '186 MB',
      time: '16 Ago · 12:15',
      description: 'Desde punto de interconexión hacia naves A, B y C.',
      uploaded: true,
    ),
    VideoItem(
      title: 'VUELO_DRON_001',
      type: 'Vuelo de dron',
      duration: '02:48',
      size: '243 MB',
      time: '16 Ago · 09:10',
      description: 'Vuelo perimetral y cenital de cubierta.',
    ),
  ];

  static final pendings = <PendingItem>[
    PendingItem(title: 'Falta fotografía de placa del transformador 01', section: '03 Fotografías · 3.3', blocking: true),
    PendingItem(title: 'Falta fotografía del Tablero 03 (frente)', section: '03 Fotografías · 3.4', blocking: true),
    PendingItem(title: 'Falta medición Fase-Tierra en Tablero Principal', section: '05 Mediciones', blocking: true),
    PendingItem(title: 'Falta número de serie del Tablero 03', section: '06 Equipos', blocking: false),
    PendingItem(title: 'Falta plano estructural', section: '02 Documentación', blocking: false),
    PendingItem(title: 'Observaciones finales sin capturar', section: '08 Observaciones', blocking: false),
  ];

  static final syncQueue = <SyncItem>[
    SyncItem(name: 'TABLERO_PRINCIPAL_TERMO_003.jpg', kind: 'Fotografía', size: '4.2 MB', progress: 1.0, state: 'listo'),
    SyncItem(name: 'RECORRIDO_GENERAL_001.mp4', kind: 'Video', size: '186 MB', progress: 0.42, state: 'sincronizando'),
    SyncItem(name: 'VUELO_DRON_001.mp4', kind: 'Video', size: '243 MB', progress: 0.0, state: 'pendiente'),
    SyncItem(name: 'Mediciones · Tablero 01', kind: 'Formulario', size: '18 KB', progress: 1.0, state: 'listo'),
    SyncItem(name: 'HZ-002 Punto caliente L2', kind: 'Hallazgo', size: '2.1 MB', progress: 1.0, state: 'listo'),
    SyncItem(name: 'DIAGRAMA_UNIFILAR_TRUPER_MTY.dwg', kind: 'Documento', size: '820 KB', progress: 0.0, state: 'error'),
    SyncItem(name: 'CUBIERTA_SOMBRAS_005.jpg', kind: 'Fotografía', size: '3.8 MB', progress: 1.0, state: 'listo'),
  ];

  static const history = <HistoryEvent>[
    HistoryEvent(title: 'Hallazgo registrado', detail: 'HZ-005 · Diagrama unifilar desactualizado', user: 'Juan Pérez', time: 'Hoy · 12:40', icon: Icons.report_problem_rounded, color: AppColors.danger),
    HistoryEvent(title: 'Video capturado', detail: 'RECORRIDO_GENERAL_001 · 04:32', user: 'Juan Pérez', time: 'Hoy · 12:15', icon: Icons.videocam_rounded, color: AppColors.teal),
    HistoryEvent(title: '3 fotografías agregadas', detail: '3.4 Tableros y Canalizaciones', user: 'Juan Pérez', time: 'Hoy · 11:19', icon: Icons.photo_camera_rounded, color: AppColors.accent),
    HistoryEvent(title: 'Mediciones capturadas', detail: 'Tablero Principal · 7 registros', user: 'Juan Pérez', time: 'Hoy · 11:15', icon: Icons.electric_bolt_rounded, color: AppColors.warning),
    HistoryEvent(title: 'Equipo registrado', detail: 'Tablero 03 · datos incompletos', user: 'Juan Pérez', time: 'Hoy · 10:58', icon: Icons.precision_manufacturing_rounded, color: AppColors.blue),
    HistoryEvent(title: 'Visita iniciada', detail: 'VIS-001 · GPS 25.7834, -100.1889', user: 'Juan Pérez', time: 'Hoy · 08:42', icon: Icons.play_circle_fill_rounded, color: AppColors.success),
    HistoryEvent(title: 'Proyecto descargado', detail: 'Plantilla v2.3 · 42 MB', user: 'Juan Pérez', time: 'Ayer · 20:11', icon: Icons.cloud_download_rounded, color: AppColors.violet),
    HistoryEvent(title: 'Técnico asignado', detail: 'Juan Pérez asignado al proyecto', user: 'Laura Méndez', time: '02 Ago · 10:30', icon: Icons.person_add_alt_1_rounded, color: AppColors.blue),
  ];

  static final users = <AppUser>[
    AppUser(name: 'Mauricio Aquino', role: UserRole.admin, email: 'm.aquino@solaris.mx', initials: 'MA', projects: 42),
    AppUser(name: 'Laura Méndez', role: UserRole.supervisor, email: 'l.mendez@solaris.mx', initials: 'LM', projects: 18),
    AppUser(name: 'Juan Pérez', role: UserRole.tecnico, email: 'j.perez@solaris.mx', initials: 'JP', projects: 27),
    AppUser(name: 'Diego Salas', role: UserRole.tecnico, email: 'd.salas@solaris.mx', initials: 'DS', projects: 21),
    AppUser(name: 'Ana Torres', role: UserRole.tecnico, email: 'a.torres@solaris.mx', initials: 'AT', projects: 9),
    AppUser(name: 'Ing. Carlos Ruiz', role: UserRole.revisor, email: 'c.ruiz@solaris.mx', initials: 'CR', projects: 33),
    AppUser(name: 'Sofía Herrera', role: UserRole.tecnico, email: 's.herrera@solaris.mx', initials: 'SH', projects: 4, active: false),
  ];

  static const clients = <Client>[
    Client(name: 'TRUPER', rfc: 'TRU850214QW3', projects: 7, contact: 'Ing. Roberto Lara'),
    Client(name: 'Grupo BIMBO', rfc: 'BIM450101HK1', projects: 12, contact: 'Ing. Patricia Nieto'),
    Client(name: 'CEMEX', rfc: 'CEM060215RT8', projects: 5, contact: 'Ing. Hugo Bautista'),
    Client(name: 'FEMSA', rfc: 'FEM880912LP0', projects: 9, contact: 'Ing. Mariana Cruz'),
    Client(name: 'HEB México', rfc: 'HEB970430MN2', projects: 3, contact: 'Ing. Óscar Domínguez'),
  ];

  static const templates = <SurveyTemplate>[
    SurveyTemplate(
      name: 'Levantamiento eléctrico FV',
      version: 'v2.3',
      type: 'Viabilidad fotovoltaica',
      updated: '12 Ago 2026',
      sections: [
        TemplateSection(code: '01', title: 'Información del Sitio', questions: 14, evidences: 2),
        TemplateSection(code: '02', title: 'Documentación Existente', questions: 5, evidences: 5),
        TemplateSection(code: '03', title: 'Fotografías', questions: 0, evidences: 24),
        TemplateSection(code: '04', title: 'Videos', questions: 2, evidences: 2),
        TemplateSection(code: '05', title: 'Mediciones Eléctricas', questions: 13, evidences: 4),
        TemplateSection(code: '06', title: 'Equipos', questions: 10, evidences: 8),
        TemplateSection(code: '07', title: 'Hallazgos', questions: 0, evidences: 0),
        TemplateSection(code: '08', title: 'Observaciones y Firma', questions: 2, evidences: 1),
      ],
    ),
    SurveyTemplate(
      name: 'Auditoría de sistema FV existente',
      version: 'v1.4',
      type: 'Auditoría',
      updated: '30 Jul 2026',
      sections: [
        TemplateSection(code: '01', title: 'Datos del sistema', questions: 18, evidences: 4),
        TemplateSection(code: '02', title: 'Módulos y estructura', questions: 12, evidences: 10),
        TemplateSection(code: '03', title: 'Inversores', questions: 9, evidences: 6),
        TemplateSection(code: '04', title: 'Termografía', questions: 4, evidences: 12),
      ],
    ),
    SurveyTemplate(
      name: 'Mantenimiento preventivo',
      version: 'v1.0',
      type: 'Mantenimiento',
      updated: '05 Jun 2026',
      active: false,
      sections: [
        TemplateSection(code: '01', title: 'Checklist preventivo', questions: 22, evidences: 8),
        TemplateSection(code: '02', title: 'Limpieza de módulos', questions: 6, evidences: 4),
      ],
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
