import 'package:flutter/material.dart';

/// Tipos de pregunta que sabe dibujar el motor de formularios.
enum QType {
  text('Texto corto', Icons.short_text_rounded),
  longText('Texto largo', Icons.notes_rounded),
  number('Número', Icons.pin_rounded),
  yesNo('Sí / No', Icons.toggle_on_rounded),
  single('Opción única', Icons.radio_button_checked_rounded),
  multi('Opción múltiple', Icons.check_box_rounded),
  scale('Escala', Icons.linear_scale_rounded),
  photo('Fotografías', Icons.photo_camera_rounded),
  video('Video', Icons.videocam_rounded),
  document('Documento', Icons.attach_file_rounded),
  signature('Firma', Icons.draw_rounded);

  const QType(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Las preguntas de evidencia se responden con archivos, no con un valor.
  bool get isEvidence => this == photo || this == video || this == document || this == signature;
  bool get hasOptions => this == single || this == multi;

  static QType parse(String s) => QType.values.firstWhere((t) => t.name == s, orElse: () => QType.text);
}

/// Muestra una pregunta sólo cuando otra pregunta del mismo bloque vale [equals].
class ShowIf {
  const ShowIf({required this.questionId, required this.equals});
  final String questionId;
  final String equals;

  Map<String, Object?> toJson() => {'q': questionId, 'eq': equals};
  static ShowIf? fromJson(Object? j) {
    if (j is! Map) return null;
    return ShowIf(questionId: j['q'] as String, equals: j['eq'] as String);
  }
}

class QuestionDef {
  QuestionDef({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.hint = '',
    this.unit = '',
    List<String>? options,
    this.min = 0,
    this.max = 5,
    this.minCount = 1,
    this.showIf,
    this.folder = '',
    this.prefix = '',
    this.docCategory = '',
  }) : options = options ?? [];

  /// Identificador estable: las respuestas guardadas se enlazan por él, así que
  /// renombrar o reordenar la pregunta no pierde lo capturado.
  final String id;
  String label;
  QType type;
  bool required;
  String hint;
  String unit;
  List<String> options;
  int min;
  int max;

  /// Mínimo de archivos para dar por respondida una pregunta de evidencia.
  int minCount;
  ShowIf? showIf;

  /// Carpeta del ZIP donde caen los archivos. Admite `{INSTANCIA}`.
  String folder;

  /// Prefijo del nombre de archivo. Admite `{INSTANCIA}`.
  String prefix;

  /// Si coincide con la categoría de un documento del proyecto, ese documento
  /// ya cuenta como respuesta (p. ej. el recibo CFE subido al crear el proyecto).
  String docCategory;

  QuestionDef copy() => QuestionDef.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        if (required) 'req': true,
        if (hint.isNotEmpty) 'hint': hint,
        if (unit.isNotEmpty) 'unit': unit,
        if (options.isNotEmpty) 'opts': options,
        if (type == QType.scale) ...{'min': min, 'max': max},
        if (type.isEvidence && minCount != 1) 'minCount': minCount,
        if (showIf != null) 'showIf': showIf!.toJson(),
        if (folder.isNotEmpty) 'folder': folder,
        if (prefix.isNotEmpty) 'prefix': prefix,
        if (docCategory.isNotEmpty) 'docCat': docCategory,
      };

  static QuestionDef fromJson(Map<String, Object?> j) => QuestionDef(
        id: j['id'] as String,
        label: j['label'] as String,
        type: QType.parse(j['type'] as String),
        required: j['req'] as bool? ?? false,
        hint: j['hint'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
        options: (j['opts'] as List?)?.cast<String>().toList(),
        min: j['min'] as int? ?? 0,
        max: j['max'] as int? ?? 5,
        minCount: j['minCount'] as int? ?? 1,
        showIf: ShowIf.fromJson(j['showIf']),
        folder: j['folder'] as String? ?? '',
        prefix: j['prefix'] as String? ?? '',
        docCategory: j['docCat'] as String? ?? '',
      );
}

/// Subsección de la plantilla. Si es repetible, el técnico agrega tantas
/// instancias como encuentre en sitio (Transformador 1, Transformador 2…).
class GroupDef {
  GroupDef({
    required this.id,
    required this.title,
    List<QuestionDef>? questions,
    this.repeatable = false,
    this.instanceLabel = '',
    this.firstInstanceLabel = '',
  }) : questions = questions ?? [];

  final String id;
  String title;
  bool repeatable;
  String instanceLabel;

  /// Nombre especial para la primera instancia ("Tablero Principal"); las
  /// siguientes se numeran "Tablero 01", "Tablero 02"…
  String firstInstanceLabel;
  List<QuestionDef> questions;

  String instanceName(int index) {
    if (!repeatable) return title;
    final base = instanceLabel.isEmpty ? title : instanceLabel;
    if (firstInstanceLabel.isNotEmpty) {
      return index == 0 ? firstInstanceLabel : '$base ${index.toString().padLeft(2, '0')}';
    }
    return '$base ${index + 1}';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        if (repeatable) 'rep': true,
        if (instanceLabel.isNotEmpty) 'inst': instanceLabel,
        if (firstInstanceLabel.isNotEmpty) 'first': firstInstanceLabel,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  static GroupDef fromJson(Map<String, Object?> j) => GroupDef(
        id: j['id'] as String,
        title: j['title'] as String,
        repeatable: j['rep'] as bool? ?? false,
        instanceLabel: j['inst'] as String? ?? '',
        firstInstanceLabel: j['first'] as String? ?? '',
        questions: (j['questions'] as List)
            .map((q) => QuestionDef.fromJson((q as Map).cast<String, Object?>()))
            .toList(),
      );
}

class SectionDef {
  SectionDef({required this.id, required this.title, this.icon = 'info', List<GroupDef>? groups})
      : groups = groups ?? [];

  final String id;
  String title;
  String icon;
  List<GroupDef> groups;

  IconData get iconData => sectionIcons[icon] ?? Icons.article_rounded;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  static SectionDef fromJson(Map<String, Object?> j) => SectionDef(
        id: j['id'] as String,
        title: j['title'] as String,
        icon: j['icon'] as String? ?? 'info',
        groups: (j['groups'] as List)
            .map((g) => GroupDef.fromJson((g as Map).cast<String, Object?>()))
            .toList(),
      );
}

/// Iconos disponibles para las secciones (se guardan por nombre en el JSON).
const sectionIcons = <String, IconData>{
  'info': Icons.info_rounded,
  'bolt': Icons.electric_bolt_rounded,
  'meter': Icons.speed_rounded,
  'roof': Icons.roofing_rounded,
  'camera': Icons.photo_library_rounded,
  'flag': Icons.flag_rounded,
  'solar': Icons.solar_power_rounded,
  'doc': Icons.folder_copy_rounded,
  'check': Icons.fact_check_rounded,
};

class TemplateDef {
  TemplateDef({
    required this.id,
    required this.name,
    required this.type,
    this.major = 1,
    this.minor = 0,
    this.active = true,
    DateTime? updatedAt,
    List<SectionDef>? sections,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        sections = sections ?? [];

  final String id;
  String name;
  String type;
  int major;
  int minor;
  bool active;
  DateTime updatedAt;
  List<SectionDef> sections;

  String get version => 'v$major.$minor';

  int get questionCount => sections.fold(0, (a, s) => a + s.groups.fold(0, (b, g) => b + g.questions.length));

  /// Código visible de una pregunta, calculado por posición (2.1.3), igual que
  /// en los reportes de SolarGrade. Se renumera solo al reordenar.
  static String code(int section, [int? group, int? question]) {
    final parts = [section + 1, if (group != null) group + 1, if (question != null) question + 1];
    return parts.join('.');
  }

  TemplateDef copy() => TemplateDef.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'major': major,
        'minor': minor,
        'active': active,
        'updatedAt': updatedAt.toIso8601String(),
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  static TemplateDef fromJson(Map<String, Object?> j) => TemplateDef(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? '',
        major: j['major'] as int? ?? 1,
        minor: j['minor'] as int? ?? 0,
        active: j['active'] as bool? ?? true,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        sections: (j['sections'] as List)
            .map((s) => SectionDef.fromJson((s as Map).cast<String, Object?>()))
            .toList(),
      );
}

/// Carpetas del ZIP según "Instrucciones de llenado de carpetas".
class Folders {
  Folders._();
  static const sitio = '01 Información del Sitio';
  static const documentacion = '02 Documentación Existente';
  static const fotos = '03 Fotografías';
  static const dron = '03 Fotografías/3.1 Dron y Cubierta';
  static const fvExistente = '03 Fotografías/3.2 Sistema FV Existente';
  static const acometida = '03 Fotografías/3.3 Acometida, Medidor y Transformador';
  static const tableros = '03 Fotografías/3.4 Tableros y Canalizaciones';
  static const generales = '03 Fotografías/3.5 Generales';
  static const videos = '04 Videos';
  static const reporte = '05 Reporte de Levantamiento';
  static const cad = '06 CAD y Modelos 3D';
  static const adicionales = 'Evidencias Adicionales';

  /// Estructura que siempre se crea en el ZIP, aunque alguna quede vacía.
  static const all = [
    sitio,
    documentacion,
    fotos,
    dron,
    fvExistente,
    acometida,
    tableros,
    generales,
    videos,
    reporte,
    cad,
    adicionales,
  ];
}
