import 'package:uuid/uuid.dart';

import 'storage/persistence.dart';

/// Listas de nombres que el administrador puede editar.
enum CatalogKind {
  projectTypes(
    title: 'Tipos de proyecto',
    singular: 'tipo',
    hint: 'Ej. Mantenimiento FV',
    usedBy: 'proyecto',
    usedWhen: 'Aparecen como opción al crear un proyecto.',
  ),
  visitMotives(
    title: 'Motivos de visita',
    singular: 'motivo',
    hint: 'Ej. Mantenimiento preventivo',
    usedBy: 'visita',
    usedWhen: 'Aparecen como opción al crear una visita.',
  );

  const CatalogKind({
    required this.title,
    required this.singular,
    required this.hint,
    required this.usedBy,
    required this.usedWhen,
  });

  final String title;
  final String singular;
  final String hint;

  /// Qué registros usan el elemento ("proyecto", "visita").
  final String usedBy;
  final String usedWhen;
}

/// Elemento de un catálogo (tablas `tipo_proyecto` y `motivo_visita`).
/// Proyectos y visitas guardan su id, así que renombrarlo cambia el nombre
/// en todos los registros que lo usan.
class CatalogItem {
  CatalogItem({required this.id, required this.name, required this.order});

  final String id;
  String name;
  int order;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'order': order};

  static CatalogItem fromJson(Map<String, Object?> j) =>
      CatalogItem(id: j['id'] as String, name: j['name'] as String, order: j['order'] as int? ?? 0);
}

/// Lista editable de nombres guardada en su propia tabla.
class Catalog {
  Catalog(this._db, this.table, {required this.uses});

  final Persistence _db;
  final String table;

  /// Cuántos registros usan el id; si hay alguno, no se puede borrar.
  final int Function(String id) uses;

  final items = <CatalogItem>[];
  static const _uuid = Uuid();

  /// Carga la tabla; si está vacía (instalación nueva) la llena con
  /// [defaults], que traen los mismos ids que la base del servidor.
  Future<void> load(List<(String, String)> defaults) async {
    items.addAll((await _db.load(table)).map(CatalogItem.fromJson));
    if (items.isEmpty) {
      for (final (id, name) in defaults) {
        // Ya existen en el servidor: no quedan pendientes de subir.
        final item = CatalogItem(id: id, name: name, order: items.length + 1);
        items.add(item);
        await _db.put(table, item.id, item.toJson(), pending: false);
      }
    }
    items.sort((a, b) => a.order.compareTo(b.order));
  }

  /// Motivo por el que [name] no es válido, o `null` si se puede usar.
  String? validate(String name, {CatalogItem? except}) {
    final n = name.trim();
    if (n.isEmpty) return 'Escribe el nombre';
    if (n.length > 40) return 'Usa 40 caracteres o menos';
    final taken = items.any((t) => t != except && t.name.toLowerCase() == n.toLowerCase());
    return taken ? 'Ya existe con ese nombre' : null;
  }

  Future<CatalogItem> add(String name) async {
    final error = validate(name);
    if (error != null) throw ArgumentError(error);
    final order = items.fold(-1, (m, t) => t.order > m ? t.order : m) + 1;
    final item = CatalogItem(id: _uuid.v4(), name: name.trim(), order: order);
    await _put(item);
    return item;
  }

  CatalogItem? byId(String? id) => items.where((t) => t.id == id).firstOrNull;

  Future<void> rename(CatalogItem item, String name) async {
    final error = validate(name, except: item);
    if (error != null) throw ArgumentError(error);
    item.name = name.trim();
    await _db.put(table, item.id, item.toJson());
  }

  Future<void> remove(CatalogItem item) async {
    final n = uses(item.id);
    if (n > 0) throw StateError('Está en uso en $n registro${n == 1 ? '' : 's'}');
    items.remove(item);
    await _db.remove(table, item.id);
  }

  Future<void> _put(CatalogItem item) async {
    items.add(item);
    await _db.put(table, item.id, item.toJson());
  }
}
