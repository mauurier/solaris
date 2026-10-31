import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth/user_directory.dart';
import '../../data/history.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../data/sync/remote_rows.dart';

/// Los eventos del historial en frases para la línea de tiempo, cada uno con
/// su (primera) entrada. Las respuestas seguidas de una misma persona en una
/// visita se juntan en un solo evento ("Capturó 12 respuestas").
List<(HistoryEntry, HistoryEvent)> describeHistory(List<HistoryEntry> entries) {
  final out = <(HistoryEntry, HistoryEvent)>[];
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    if (e.table != 'respuesta') {
      out.add((e, describeEntry(e)));
      continue;
    }
    var n = 1;
    while (i + n < entries.length &&
        entries[i + n].table == 'respuesta' &&
        entries[i + n].userId == e.userId &&
        entries[i + n].visitId == e.visitId) {
      n++;
    }
    out.add((
      e,
      _event(e, n == 1 ? 'Capturó una respuesta' : 'Capturó $n respuestas', _visitLabel(e.visitId),
          Icons.edit_note_rounded, AppColors.blue),
    ));
    i += n - 1;
  }
  return out;
}

HistoryEvent describeEntry(HistoryEntry e) {
  final r = e.row;
  final removed = e.action == 'eliminar';
  String verb(String crear, String editar, String eliminar) => switch (e.action) {
        'crear' => crear,
        'eliminar' => eliminar,
        _ => editar,
      };

  switch (e.table) {
    case 'proyecto':
      final what = '${r['codigo']} · ${r['nombre']}';
      if (e.action == 'editar' && e.changed.contains('estado')) {
        return _event(e, 'Proyecto: ${RemoteRows.statusFromDb(r['estado']).label}', what, Icons.flag_rounded,
            AppColors.accent);
      }
      if (e.action == 'editar' && e.changed.contains('id_supervisor')) {
        return _event(e, 'Cambió el supervisor', _name(r['id_supervisor']), Icons.supervisor_account_rounded,
            AppColors.teal);
      }
      return _event(e, verb('Creó el proyecto', 'Editó el proyecto', 'Borró el proyecto'),
          e.action == 'editar' ? '$what · ${_fields(e.changed)}' : what, Icons.folder_rounded, AppColors.blue);

    case 'proyecto_tecnico':
      final revived = e.action == 'editar' && r['eliminado_en'] == null;
      return _event(e, removed ? 'Quitó a un técnico' : (e.action == 'crear' || revived ? 'Asignó a un técnico' : 'Editó la asignación'),
          _name(r['id_tecnico']), removed ? Icons.person_remove_rounded : Icons.person_add_rounded, AppColors.teal);

    case 'visita':
      final visit = 'VIS-${'${r['numero']}'.padLeft(3, '0')}';
      if (e.action == 'editar') {
        final c = e.changed;
        if (c.contains('fecha_inicio') && e.before['fecha_inicio'] == null) {
          return _event(e, 'Inició la visita', visit, Icons.play_circle_rounded, AppColors.accent);
        }
        if (c.contains('fecha_fin') && e.before['fecha_fin'] == null) {
          return _event(e, 'Terminó la visita', visit, Icons.flag_rounded, AppColors.success);
        }
        if (c.contains('id_tecnico')) {
          return _event(e, 'Reasignó la visita', '$visit · ${_name(r['id_tecnico'])}', Icons.swap_horiz_rounded,
              AppColors.teal);
        }
        if (c.contains('justificaciones')) {
          return _event(e, 'Justificó un pendiente', visit, Icons.support_agent_rounded, AppColors.warning);
        }
        if (c.contains('estado')) {
          return _event(e, '$visit: ${RemoteRows.statusFromDb(r['estado']).label}', _fields(c), Icons.sync_alt_rounded,
              AppColors.accent);
        }
      }
      return _event(e, verb('Creó la visita', 'Editó la visita', 'Borró la visita'),
          e.action == 'crear' ? '$visit · ${_name(r['id_tecnico'])}' : visit, Icons.event_rounded, AppColors.accent);

    case 'evidencia':
      final kind = switch (r['tipo']) {
        'video' => 'un video',
        'documento' => 'un documento',
        'firma' => 'la firma',
        _ => 'una foto',
      };
      final name = '${r['nombre_original'] ?? r['clave_pregunta'] ?? ''} · ${_visitLabel(e.visitId)}';
      final title = e.action == 'editar' && e.changed.contains('ruta_archivo')
          ? 'Reemplazó $kind'
          : e.action == 'editar' && e.changed.contains('comentario')
              ? 'Comentó $kind'
              : verb('Subió $kind', 'Editó $kind', 'Borró $kind');
      return _event(e, title, name, Icons.photo_camera_rounded, AppColors.accent);

    case 'documento':
      final cat = DocCategory.byId('${r['categoria']}').label;
      return _event(e, verb('Subió un documento', 'Editó un documento', 'Borró un documento'),
          '${r['nombre_original'] ?? ''} · $cat', Icons.description_rounded, AppColors.violet);

    case 'revision':
      final approved = r['decision'] == 'aprobada';
      final notes = '${r['observaciones'] ?? ''}'.trim();
      return _event(e, approved ? 'Aprobó la visita' : 'Pidió correcciones',
          notes.isEmpty ? _visitLabel(e.visitId) : notes,
          approved ? Icons.verified_rounded : Icons.assignment_return_rounded,
          approved ? AppColors.success : AppColors.warning);

    case 'correccion':
      final attended = r['estado'] == 'atendida';
      final title = e.action == 'crear'
          ? 'Pidió corregir'
          : e.changed.contains('estado')
              ? (attended ? 'Atendió una corrección' : 'Reabrió una corrección')
              : verb('Pidió corregir', 'Editó una corrección', 'Quitó una corrección');
      return _event(e, title, '${r['descripcion'] ?? ''}', attended ? Icons.task_alt_rounded : Icons.rule_rounded,
          attended ? AppColors.success : AppColors.warning);

    case 'cliente':
      return _event(e, verb('Creó el cliente', 'Editó el cliente', 'Borró el cliente'), '${r['razon_social']}',
          Icons.business_rounded, AppColors.blue);
    case 'sitio':
      return _event(e, verb('Creó el sitio', 'Editó el sitio', 'Borró el sitio'), '${r['nombre']}',
          Icons.place_rounded, AppColors.blue);
    case 'plantilla':
      return _event(e, verb('Creó la plantilla', 'Editó la plantilla', 'Borró la plantilla'),
          '${r['nombre']} v${r['version_mayor']}.${r['version_menor']}', Icons.dashboard_customize_rounded,
          AppColors.accent);
    case 'tipo_proyecto' || 'motivo_visita':
      final kind = e.table == 'tipo_proyecto' ? 'el tipo de proyecto' : 'el motivo de visita';
      return _event(e, verb('Agregó $kind', 'Cambió $kind', 'Quitó $kind'), '${r['nombre']}', Icons.list_alt_rounded,
          AppColors.teal);
    case 'perfil':
      return _event(e, verb('Creó la cuenta', 'Cambió la cuenta', 'Borró la cuenta'), '${r['nombre']} · ${r['rol']}',
          Icons.person_rounded, AppColors.teal);
  }
  return _event(e, verb('Creó', 'Editó', 'Borró'), e.table, Icons.history_rounded, AppColors.textMuted);
}

HistoryEvent _event(HistoryEntry e, String title, String detail, IconData icon, Color color) => HistoryEvent(
      title: title,
      detail: detail,
      user: e.userId == null ? 'Sistema' : UserDirectory.instance.nameOf(e.userId),
      time: fmtTime(e.at),
      icon: e.action == 'eliminar' ? Icons.delete_outline_rounded : icon,
      color: e.action == 'eliminar' ? AppColors.danger : color,
    );

String _name(Object? id) => UserDirectory.instance.nameOf(id as String?);

String _visitLabel(String? visitId) {
  if (visitId == null || !SurveyStore.isReady) return '';
  final v = SurveyStore.instance.visit(visitId);
  return v?.label ?? '';
}

const _fieldNames = {
  'nombre': 'nombre',
  'codigo': 'clave',
  'descripcion': 'descripción',
  'fecha_programada': 'fecha',
  'id_sitio': 'sitio',
  'id_tipo_proyecto': 'tipo',
  'id_plantilla': 'plantilla',
  'repeticiones': 'bloques',
  'notas': 'notas',
  'estado': 'estado',
};

String _fields(Set<String> changed) =>
    [for (final c in changed) ?_fieldNames[c]].join(', ');
