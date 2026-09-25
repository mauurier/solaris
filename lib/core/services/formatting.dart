/// Formatos de fecha en español sin depender de `intl`.
const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 24 Sep 2026
String fmtDate(DateTime d) => '${_two(d.day)} ${_months[d.month - 1]} ${d.year}';

/// 10:42
String fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// 24 Sep 2026 · 10:42
String fmtDateTime(DateTime d) => '${fmtDate(d)} · ${fmtTime(d)}';

/// 24/09/2026 10:42:15 — el sello de la marca de agua.
String fmtStamp(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

/// 2026-09-24 — para nombres de archivo.
String fmtIsoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "Hace 5 min", "Hace 3 h", "Ayer", o la fecha.
String fmtAgo(DateTime d, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'Justo ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'Ayer';
  return fmtDate(d);
}

/// 1.4 MB
String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Duración de una visita: "3 h 18 min".
String fmtDuration(Duration d) {
  if (d.inHours == 0) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}

/// 02:41 — cronómetro de grabación.
String fmtDurationClock(Duration d) =>
    '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';
