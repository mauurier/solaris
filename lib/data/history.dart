import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_errors.dart';

/// Un cambio registrado en Solaris. La tabla `historial` la llenan triggers
/// en cada alta, cambio o borrado; la app sólo la lee, y sólo con conexión.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.table,
    required this.action,
    required this.at,
    this.userId,
    this.projectId,
    this.visitId,
    this.before = const {},
    this.after = const {},
  });

  factory HistoryEntry.fromRow(Map<String, Object?> r) => HistoryEntry(
        id: r['id'] as String,
        table: r['tabla'] as String,
        action: r['accion'] as String,
        at: DateTime.parse(r['creado_en'] as String).toLocal(),
        userId: r['id_usuario'] as String?,
        projectId: r['id_proyecto'] as String?,
        visitId: r['id_visita'] as String?,
        before: _map(r['valores_antes']),
        after: _map(r['valores_despues']),
      );

  final String id;

  /// Tabla de Solaris: proyecto, visita, respuesta…
  final String table;

  /// crear | editar | eliminar
  final String action;
  final DateTime at;

  /// Id de `perfil`; nulo si lo hizo el sistema (migraciones, triggers).
  final String? userId;
  final String? projectId;
  final String? visitId;

  /// La fila antes y después del cambio (vacías al crear o borrar de verdad).
  final Map<String, Object?> before;
  final Map<String, Object?> after;

  /// La fila como quedó, o como estaba si se borró.
  Map<String, Object?> get row => after.isEmpty ? before : after;

  /// Columnas que cambiaron, sin contar `actualizado_en`.
  Set<String> get changed => {
        for (final k in {...before.keys, ...after.keys})
          if (k != 'actualizado_en' && '${before[k]}' != '${after[k]}') k,
      };

  static Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
}

/// De dónde sale el historial. Las pruebas usan uno falso.
abstract class HistorySource {
  /// Eventos del más reciente al más antiguo. Con [projectId], sólo los de
  /// ese proyecto; con [tables], sólo los de esas tablas.
  Future<List<HistoryEntry>> page({String? projectId, Set<String>? tables, required int offset, required int limit});
}

class SupabaseHistory implements HistorySource {
  static const _timeout = Duration(seconds: 20);

  @override
  Future<List<HistoryEntry>> page({
    String? projectId,
    Set<String>? tables,
    required int offset,
    required int limit,
  }) async {
    try {
      var q = Supabase.instance.client.from('historial').select(
          'id, id_usuario, id_proyecto, id_visita, tabla, accion, valores_antes, valores_despues, creado_en');
      if (projectId != null) q = q.eq('id_proyecto', projectId);
      if (tables != null) q = q.inFilter('tabla', tables.toList());
      final rows = await q.order('creado_en', ascending: false).range(offset, offset + limit - 1).timeout(_timeout);
      return rows.map(HistoryEntry.fromRow).toList();
    } catch (e) {
      throw HistoryError(remoteErrorMessage(e));
    }
  }
}

class HistoryError implements Exception {
  const HistoryError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Se cambia en las pruebas.
HistorySource historySource = SupabaseHistory();
