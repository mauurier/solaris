import 'dart:io';

import 'package:path/path.dart' as p;

/// Archivos de evidencia dentro de la carpeta privada de la app.
///
/// La base de datos guarda rutas **relativas** a [root]: en iOS la ruta
/// absoluta del contenedor cambia entre instalaciones, la relativa no.
class FileStore {
  FileStore(this.root);
  final Directory root;

  File file(String relative) => File(p.join(root.path, relative));

  bool exists(String relative) => file(relative).existsSync();

  /// Copia [source] a `relDir/name` y devuelve la ruta relativa.
  Future<String> importFile(File source, String relDir, String name, {bool move = false}) async {
    final rel = p.join(relDir, name);
    final dest = file(rel);
    await dest.parent.create(recursive: true);
    if (move) {
      try {
        await source.rename(dest.path);
        return rel;
      } on FileSystemException {
        // Otro volumen (p. ej. temporales del sistema): se copia y se borra.
      }
    }
    await source.copy(dest.path);
    if (move) {
      try {
        await source.delete();
      } on FileSystemException {
        // El sistema limpia sus temporales; no es crítico.
      }
    }
    return rel;
  }

  Future<String> writeBytes(List<int> bytes, String relDir, String name) async {
    final rel = p.join(relDir, name);
    final dest = file(rel);
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes, flush: true);
    return rel;
  }

  Future<void> delete(String relative) async {
    final f = file(relative);
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteDir(String relative) async {
    final d = Directory(p.join(root.path, relative));
    if (await d.exists()) await d.delete(recursive: true);
  }

  int sizeOf(String relative) {
    final f = file(relative);
    return f.existsSync() ? f.lengthSync() : 0;
  }
}
