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

/// Elemento de un catálogo. Proyectos y visitas guardan el nombre, así que
/// borrar un elemento no altera los registros que ya lo usaban.
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
  Catalog(this._db, this.table, {required this.uses, required this.renameUses});

  final Persistence _db;
  final String table;

  /// Cuántos registros usan el nombre; si hay alguno, no se puede borrar.
  final int Function(String name) uses;

  /// Cambia el nombre en los registros que lo usan.
  final Future<void> Function(String from, String to) renameUses;

  final items = <CatalogItem>[];
  static const _uuid = Uuid();

  /// Carga la tabla; si está vacía (instalación nueva) la llena con [defaults].
  Future<void> load(List<String> defaults) async {
    items.addAll((await _db.load(table)).map(CatalogItem.fromJson));
    if (items.isEmpty) {
      for (final name in defaults) {
        await _put(CatalogItem(id: _uuid.v4(), name: name, order: items.length));
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

  /// Renombra el elemento y los registros que lo usan, para que no queden huérfanos.
  Future<void> rename(CatalogItem item, String name) async {
    final error = validate(name, except: item);
    if (error != null) throw ArgumentError(error);
    final old = item.name;
    item.name = name.trim();
    await _db.put(table, item.id, item.toJson());
    await renameUses(old, item.name);
  }

  Future<void> remove(CatalogItem item) async {
    final n = uses(item.name);
    if (n > 0) throw StateError('Está en uso en $n registro${n == 1 ? '' : 's'}');
    items.remove(item);
    await _db.remove(table, item.id);
  }

  Future<void> _put(CatalogItem item) async {
    items.add(item);
    await _db.put(table, item.id, item.toJson());
  }
}
