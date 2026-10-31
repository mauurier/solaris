import '../storage/persistence.dart';
import '../survey_store.dart';

/// Un renglón de la cola de la pantalla de Sincronización.
class SyncQueueItem {
  const SyncQueueItem({
    required this.keys,
    required this.kind,
    required this.title,
    required this.detail,
    this.bytes,
    this.file = false,
    this.deleted = false,
  });

  /// Filas que representa, como `tabla local/id` (las llaves de
  /// `SyncService.failures`). Las respuestas de una visita van juntas.
  final List<String> keys;

  /// Proyecto, Visita, Foto…
  final String kind;
  final String title;
  final String detail;

  /// Tamaño del archivo, si lleva.
  final int? bytes;

  /// Lleva archivo: espera Wi-Fi si así está configurado.
  final bool file;

  /// Se borró en el teléfono y falta borrarlo en el servidor.
  final bool deleted;
}

/// Lo que falta subir, en el orden en que se sube.
Future<List<SyncQueueItem>> loadSyncQueue(SurveyStore store) async {
  String visitLabel(String? visitId) {
    final v = visitId == null ? null : store.visit(visitId);
    if (v == null) return 'Visita borrada';
    final code = store.project(v.projectId)?.code;
    return code == null ? 'Visita ${v.number}' : 'Visita ${v.number} · $code';
  }

  String projectLabel(String? projectId) => store.project(projectId ?? '')?.code ?? 'Proyecto borrado';

  final out = <SyncQueueItem>[];
  SyncQueueItem item(String table, PendingRow r, String kind, String title, String detail,
          {int? bytes, bool file = false}) =>
      SyncQueueItem(
        keys: ['$table/${r.id}'],
        kind: kind,
        title: title,
        detail: detail,
        bytes: bytes,
        file: file && !r.deleted,
        deleted: r.deleted,
      );

  for (final (table, kind) in [
    (Tables.projectTypes, 'Tipo de proyecto'),
    (Tables.visitMotives, 'Motivo de visita'),
    (Tables.templates, 'Plantilla'),
    (Tables.clients, 'Cliente'),
    (Tables.sites, 'Sitio'),
  ]) {
    for (final r in await store.db.pending(table)) {
      out.add(item(table, r, kind, '${r.data['name'] ?? ''}', kind));
    }
  }
  for (final r in await store.db.pending(Tables.projects)) {
    out.add(item(Tables.projects, r, 'Proyecto', '${r.data['code']} · ${r.data['name']}', 'Proyecto'));
  }
  for (final r in await store.db.pending(Tables.visits)) {
    out.add(item(Tables.visits, r, 'Visita', visitLabel(r.id), 'Visita'));
  }

  for (final r in await store.db.pending(Tables.reviews)) {
    final approved = r.data['decision'] == 'approved';
    out.add(item(Tables.reviews, r, 'Revisión', 'Revisión · ${visitLabel(r.data['visitId'] as String?)}',
        approved ? 'Aprobada' : 'Con correcciones'));
  }
  for (final r in await store.db.pending(Tables.corrections)) {
    out.add(item(Tables.corrections, r, 'Corrección', '${r.data['description']}',
        r.data['attendedAt'] == null ? 'Corrección pedida' : 'Corrección atendida'));
  }

  final answers = <String, List<PendingRow>>{};
  for (final r in await store.db.pending(Tables.answers)) {
    answers.putIfAbsent(r.parent ?? '', () => []).add(r);
  }
  for (final MapEntry(key: visitId, value: rows) in answers.entries) {
    out.add(SyncQueueItem(
      keys: [for (final r in rows) '${Tables.answers}/${r.id}'],
      kind: 'Respuestas',
      title: 'Respuestas · ${visitLabel(visitId)}',
      detail: rows.length == 1 ? '1 respuesta' : '${rows.length} respuestas',
    ));
  }

  for (final r in await store.db.pending(Tables.documents)) {
    final path = r.data['path'] as String? ?? '';
    out.add(item(Tables.documents, r, 'Documento', '${r.data['originalName'] ?? 'Documento'}',
        'Documento · ${projectLabel(r.data['projectId'] as String?)}',
        bytes: store.files.sizeOf(path), file: true));
  }
  const kinds = {'photo': 'Foto', 'video': 'Video', 'document': 'Documento', 'signature': 'Firma'};
  for (final r in await store.db.pending(Tables.evidences)) {
    final kind = kinds[r.data['kind']] ?? 'Evidencia';
    final name = r.data['originalName'] as String? ?? '';
    out.add(item(Tables.evidences, r, kind, name.isEmpty ? kind : name,
        '$kind · ${visitLabel(r.data['visitId'] as String?)}',
        bytes: store.files.sizeOf(r.data['path'] as String? ?? ''), file: true));
  }
  return out;
}
