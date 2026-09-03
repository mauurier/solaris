import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum UserRole { admin, supervisor, tecnico, revisor }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrador',
        UserRole.supervisor => 'Supervisor',
        UserRole.tecnico => 'Técnico de campo',
        UserRole.revisor => 'Revisor / Ingeniero',
      };

  String get short => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.supervisor => 'Supervisor',
        UserRole.tecnico => 'Técnico',
        UserRole.revisor => 'Revisor',
      };

  IconData get icon => switch (this) {
        UserRole.admin => Icons.admin_panel_settings_rounded,
        UserRole.supervisor => Icons.verified_user_rounded,
        UserRole.tecnico => Icons.engineering_rounded,
        UserRole.revisor => Icons.fact_check_rounded,
      };

  Color get color => switch (this) {
        UserRole.admin => AppColors.violet,
        UserRole.supervisor => AppColors.blue,
        UserRole.tecnico => AppColors.accent,
        UserRole.revisor => AppColors.teal,
      };
}

enum ProjectStatus {
  borrador,
  programado,
  asignado,
  enCampo,
  enCaptura,
  pendienteSync,
  enRevision,
  conCorrecciones,
  aprobado,
  cerrado,
}

extension ProjectStatusX on ProjectStatus {
  String get label => switch (this) {
        ProjectStatus.borrador => 'Borrador',
        ProjectStatus.programado => 'Programado',
        ProjectStatus.asignado => 'Asignado',
        ProjectStatus.enCampo => 'En campo',
        ProjectStatus.enCaptura => 'En captura',
        ProjectStatus.pendienteSync => 'Pend. sincronizar',
        ProjectStatus.enRevision => 'En revisión',
        ProjectStatus.conCorrecciones => 'Con correcciones',
        ProjectStatus.aprobado => 'Aprobado',
        ProjectStatus.cerrado => 'Cerrado',
      };

  Color get color => switch (this) {
        ProjectStatus.borrador => AppColors.textMuted,
        ProjectStatus.programado => AppColors.blue,
        ProjectStatus.asignado => AppColors.violet,
        ProjectStatus.enCampo => AppColors.accent,
        ProjectStatus.enCaptura => AppColors.accent,
        ProjectStatus.pendienteSync => AppColors.warning,
        ProjectStatus.enRevision => AppColors.teal,
        ProjectStatus.conCorrecciones => AppColors.danger,
        ProjectStatus.aprobado => AppColors.success,
        ProjectStatus.cerrado => AppColors.textSecondary,
      };

  IconData get icon => switch (this) {
        ProjectStatus.borrador => Icons.edit_note_rounded,
        ProjectStatus.programado => Icons.event_rounded,
        ProjectStatus.asignado => Icons.person_add_alt_1_rounded,
        ProjectStatus.enCampo => Icons.location_on_rounded,
        ProjectStatus.enCaptura => Icons.pending_actions_rounded,
        ProjectStatus.pendienteSync => Icons.cloud_upload_rounded,
        ProjectStatus.enRevision => Icons.rate_review_rounded,
        ProjectStatus.conCorrecciones => Icons.error_outline_rounded,
        ProjectStatus.aprobado => Icons.verified_rounded,
        ProjectStatus.cerrado => Icons.lock_rounded,
      };
}

enum Severity { baja, media, alta, critica }

extension SeverityX on Severity {
  String get label => switch (this) {
        Severity.baja => 'Baja',
        Severity.media => 'Media',
        Severity.alta => 'Alta',
        Severity.critica => 'Crítica',
      };
  Color get color => switch (this) {
        Severity.baja => AppColors.sevBaja,
        Severity.media => AppColors.sevMedia,
        Severity.alta => AppColors.sevAlta,
        Severity.critica => AppColors.sevCritica,
      };
}

enum FindingStatus { abierto, enRevision, corregido, cerrado }

extension FindingStatusX on FindingStatus {
  String get label => switch (this) {
        FindingStatus.abierto => 'Abierto',
        FindingStatus.enRevision => 'En revisión',
        FindingStatus.corregido => 'Corregido',
        FindingStatus.cerrado => 'Cerrado',
      };
  Color get color => switch (this) {
        FindingStatus.abierto => AppColors.danger,
        FindingStatus.enRevision => AppColors.warning,
        FindingStatus.corregido => AppColors.blue,
        FindingStatus.cerrado => AppColors.success,
      };
}

class AppUser {
  AppUser({
    required this.name,
    required this.role,
    required this.email,
    required this.initials,
    this.active = true,
    this.projects = 0,
  });

  final String name;
  final UserRole role;
  final String email;
  final String initials;
  bool active;
  final int projects;
}

class Client {
  const Client({required this.name, required this.rfc, required this.projects, required this.contact});
  final String name;
  final String rfc;
  final int projects;
  final String contact;
}

class Indicator {
  Indicator(this.label, this.value, this.color, this.icon);
  final String label;
  double value;
  final Color color;
  final IconData icon;
}

class Project {
  Project({
    required this.id,
    required this.name,
    required this.client,
    required this.type,
    required this.site,
    required this.address,
    required this.coords,
    required this.responsible,
    required this.supervisor,
    required this.technicians,
    required this.createdAt,
    required this.scheduledAt,
    required this.status,
    required this.progress,
    required this.indicators,
    required this.lastActivity,
    this.description = '',
    this.criticalFindings = 0,
    this.pendings = 0,
    this.visits = const [],
  });

  final String id;
  final String name;
  final String client;
  final String type;
  final String site;
  final String address;
  final String coords;
  final String responsible;
  final String supervisor;
  final List<String> technicians;
  final String createdAt;
  final String scheduledAt;
  ProjectStatus status;
  double progress;
  final List<Indicator> indicators;
  final String lastActivity;
  final String description;
  final int criticalFindings;
  final int pendings;
  final List<Visit> visits;
}

class Visit {
  Visit({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    required this.technician,
    required this.supervisor,
    required this.type,
    required this.motive,
    required this.status,
    required this.progress,
    this.locationStart = '25.6866, -100.3161',
    this.locationEnd = '25.6866, -100.3161',
  });

  final String id;
  final String date;
  final String start;
  final String end;
  final String technician;
  final String supervisor;
  final String type;
  final String motive;
  final ProjectStatus status;
  double progress;
  final String locationStart;
  final String locationEnd;
}

class SurveySection {
  SurveySection({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.done,
    required this.total,
    required this.route,
    this.requiredPending = 0,
  });

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  int done;
  final int total;
  final String route;
  final int requiredPending;

  double get progress => total == 0 ? 0 : done / total;
  bool get complete => done >= total;
}

class PhotoSlot {
  PhotoSlot({
    required this.title,
    required this.code,
    required this.isRequired,
    this.captured = false,
    this.comment = '',
    this.time = '',
  });

  final String title;
  final String code;
  final bool isRequired;
  bool captured;
  String comment;
  String time;
}

class PhotoGroup {
  PhotoGroup({required this.code, required this.title, required this.slots, required this.icon});
  final String code;
  final String title;
  final IconData icon;
  final List<PhotoSlot> slots;

  int get captured => slots.where((s) => s.captured).length;
  int get requiredPending => slots.where((s) => s.isRequired && !s.captured).length;
  double get progress => slots.isEmpty ? 0 : captured / slots.length;
}

class Measurement {
  Measurement({
    required this.point,
    required this.type,
    required this.value,
    required this.unit,
    required this.instrument,
    required this.time,
    this.note = '',
  });
  final String point;
  final String type;
  final String value;
  final String unit;
  final String instrument;
  final String time;
  final String note;
}

class Equipment {
  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.serial,
    required this.capacity,
    required this.location,
    required this.photos,
    required this.icon,
    this.complete = true,
  });
  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final String serial;
  final String capacity;
  final String location;
  final int photos;
  final IconData icon;
  final bool complete;
}

class Finding {
  Finding({
    required this.id,
    required this.category,
    required this.description,
    required this.severity,
    required this.location,
    required this.date,
    required this.user,
    required this.recommendation,
    required this.status,
    required this.evidences,
  });
  final String id;
  final String category;
  final String description;
  final Severity severity;
  final String location;
  final String date;
  final String user;
  final String recommendation;
  FindingStatus status;
  final int evidences;
}

class DocItem {
  DocItem({
    required this.name,
    required this.category,
    required this.size,
    required this.ext,
    required this.date,
    this.pending = false,
  });
  final String name;
  final String category;
  final String size;
  final String ext;
  final String date;
  final bool pending;

  Color get color => switch (ext.toLowerCase()) {
        'pdf' => AppColors.danger,
        'dwg' || 'dxf' => AppColors.violet,
        'xlsx' || 'xls' => AppColors.success,
        'docx' || 'doc' => AppColors.blue,
        'jpg' || 'png' => AppColors.teal,
        _ => AppColors.textMuted,
      };
}

class VideoItem {
  VideoItem({
    required this.title,
    required this.type,
    required this.duration,
    required this.size,
    required this.time,
    required this.description,
    this.uploaded = false,
  });
  final String title;
  final String type;
  final String duration;
  final String size;
  final String time;
  final String description;
  final bool uploaded;
}

class PendingItem {
  PendingItem({required this.title, required this.section, required this.blocking, this.justified = false});
  final String title;
  final String section;
  final bool blocking;
  bool justified;
}

class SyncItem {
  SyncItem({
    required this.name,
    required this.kind,
    required this.size,
    required this.progress,
    required this.state,
  });
  final String name;
  final String kind;
  final String size;
  double progress;
  String state; // pendiente | sincronizando | listo | error
}

class HistoryEvent {
  const HistoryEvent({
    required this.title,
    required this.detail,
    required this.user,
    required this.time,
    required this.icon,
    required this.color,
  });
  final String title;
  final String detail;
  final String user;
  final String time;
  final IconData icon;
  final Color color;
}

class TemplateSection {
  const TemplateSection({required this.code, required this.title, required this.questions, required this.evidences});
  final String code;
  final String title;
  final int questions;
  final int evidences;
}

class SurveyTemplate {
  const SurveyTemplate({
    required this.name,
    required this.version,
    required this.type,
    required this.sections,
    required this.updated,
    this.active = true,
  });
  final String name;
  final String version;
  final String type;
  final List<TemplateSection> sections;
  final String updated;
  final bool active;
}
