import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../main.dart';

/// Colores que se pueden elegir para textos y medidas.
const _palette = [
  Colors.white,
  Colors.black,
  Color(0xFFFFC24B),
  Color(0xFFF87171),
  Color(0xFF3DD68C),
  Color(0xFF5B9DF9),
];

/// Un texto puesto sobre la foto. Posición y tamaño son relativos a la foto
/// (0–1), así se ve igual en la pantalla que en el archivo de 4K.
class PhotoText {
  PhotoText({
    required this.text,
    required this.center,
    this.size = 0.055,
    this.color = Colors.white,
    this.background = true,
  });

  String text;

  /// Centro del texto, como fracción del ancho y del alto de la foto.
  Offset center;

  /// Tamaño de letra como fracción del ancho de la foto.
  double size;
  Color color;

  /// Recuadro oscuro detrás del texto para que se lea sobre cualquier fondo.
  bool background;

  static const minSize = 0.02;
  static const maxSize = 0.2;

  /// Estilo para un ancho de foto [width] (en pantalla o en el archivo).
  /// Sin heredar del tema: el texto en pantalla y el que se dibuja en el
  /// archivo usan exactamente la misma fuente y medidas.
  TextStyle style(double width) => TextStyle(
        inherit: false,
        color: color,
        fontSize: size * width,
        fontWeight: FontWeight.w700,
        height: 1.15,
        shadows: background
            ? null
            : [Shadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: size * width * 0.18)],
      );

  EdgeInsets padding(double width) =>
      EdgeInsets.symmetric(horizontal: size * width * 0.35, vertical: size * width * 0.15);

  Radius radius(double width) => Radius.circular(size * width * 0.25);

  /// Ancho máximo antes de partir el renglón.
  double maxWidth(double width) => width * 0.92;

  Color get boxColor => color.computeLuminance() > 0.5
      ? Colors.black.withValues(alpha: 0.62)
      : Colors.white.withValues(alpha: 0.8);

  /// El texto acomodado para una foto de [width] de ancho. Quien lo pide lo
  /// libera con `dispose`.
  TextPainter layout(double width) => TextPainter(
        text: TextSpan(text: text, style: style(width)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth(width) - padding(width).horizontal);

  /// Rectángulo que ocupa el texto con su recuadro en una foto de [size].
  Rect rect(Size size) {
    final painter = layout(size.width);
    final pad = padding(size.width);
    final box = Size(painter.width + pad.horizontal, painter.height + pad.vertical);
    painter.dispose();
    return Rect.fromCenter(
      center: Offset(center.dx * size.width, center.dy * size.height),
      width: box.width,
      height: box.height,
    );
  }
}

/// Línea de medida con flecha en los dos extremos, para señalar una distancia
/// (por ejemplo de un tablero a otro). Puede llevar al centro el valor medido.
/// Como [PhotoText], todo es relativo a la foto.
class PhotoLine {
  PhotoLine({
    required this.start,
    required this.end,
    this.color = const Color(0xFFFFC24B),
    this.label = '',
    this.width = 0.006,
  });

  /// Extremos, como fracción del ancho y del alto de la foto.
  Offset start;
  Offset end;
  Color color;

  /// Valor medido, p. ej. "1.20 m". Vacío = sin etiqueta.
  String label;

  /// Grosor de la línea como fracción del ancho de la foto.
  double width;

  static const minWidth = 0.002;
  static const maxWidth = 0.03;

  /// La etiqueta como texto con recuadro, al centro de la línea; su tamaño
  /// crece con el grosor.
  PhotoText? get labelText => label.trim().isEmpty
      ? null
      : PhotoText(
          text: label.trim(),
          center: Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
          size: (width * 7).clamp(0.025, 0.14),
          color: color,
        );
}

/// Dibuja medidas y textos sobre una foto de [size]. Lo usan la pantalla y el
/// archivo final, así lo que se ve es lo que se guarda.
void paintAnnotations(Canvas canvas, Size size, List<PhotoText> texts, List<PhotoLine> lines) {
  for (final l in lines) {
    _paintLine(canvas, size, l);
  }
  for (final t in [for (final l in lines) ?l.labelText, ...texts]) {
    _paintText(canvas, size, t);
  }
}

void _paintText(Canvas canvas, Size size, PhotoText t) {
  final w = size.width;
  final painter = t.layout(w);
  final pad = t.padding(w);
  final rect = t.rect(size);
  if (t.background) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, t.radius(w)), Paint()..color = t.boxColor);
  }
  painter.paint(canvas, rect.topLeft + Offset(pad.left, pad.top));
  painter.dispose();
}

void _paintLine(Canvas canvas, Size size, PhotoLine l) {
  final a = Offset(l.start.dx * size.width, l.start.dy * size.height);
  final b = Offset(l.end.dx * size.width, l.end.dy * size.height);
  final length = (b - a).distance;
  if (length < 1) return;
  final stroke = l.width * size.width;
  final u = (b - a) / length; // dirección de a hacia b
  final n = Offset(-u.dy, u.dx); // perpendicular
  final head = math.min(stroke * 4.5, length / 2.5);
  final half = head * 0.55;

  Path arrow(Offset tip, Offset inward) {
    final base = tip + inward * head;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + n.dx * half, base.dy + n.dy * half)
      ..lineTo(base.dx - n.dx * half, base.dy - n.dy * half)
      ..close();
  }

  final heads = [arrow(a, u), arrow(b, -u)];
  // La línea no llega hasta la punta para que no asome por la flecha.
  final from = a + u * head * 0.8, to = b - u * head * 0.8;

  // Contorno oscuro para que se vea sobre fondos claros.
  final outline = Color.fromRGBO(0, 0, 0, 0.55);
  canvas.drawLine(from, to, Paint()
    ..color = outline
    ..strokeWidth = stroke * 2.2);
  for (final h in heads) {
    canvas.drawPath(h, Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.2
      ..strokeJoin = StrokeJoin.round);
  }
  canvas.drawLine(from, to, Paint()
    ..color = l.color
    ..strokeWidth = stroke);
  for (final h in heads) {
    canvas.drawPath(h, Paint()..color = l.color);
  }
}

/// Editor para marcar una foto: textos y líneas de medida con flecha en los
/// dos extremos. Tocar la foto pone un texto, arrastrar mueve lo que se toque
/// (o un extremo de una medida), pellizcar con dos dedos en cualquier parte de
/// la foto cambia el tamaño de lo seleccionado, y tocar un elemento lo edita o
/// lo borra. Al guardar se dibuja en la foto a su resolución real.
class PhotoTextEditor extends StatefulWidget {
  const PhotoTextEditor({super.key, required this.source});
  final File source;

  /// Devuelve la foto editada en un temporal, o nula si se canceló o no hubo
  /// cambios.
  static Future<File?> open(BuildContext context, File source) =>
      Navigator.of(context).push<File>(appRoute(PhotoTextEditor(source: source), fullscreenDialog: true));

  @override
  State<PhotoTextEditor> createState() => PhotoTextEditorState();
}

/// Qué parte de un elemento se arrastra.
enum _Part { body, start, end }

class PhotoTextEditorState extends State<PhotoTextEditor> {
  final _texts = <PhotoText>[];
  final _lines = <PhotoLine>[];
  Size? _imageSize;
  bool _saving = false;

  /// Último elemento tocado: el pellizco le cambia el tamaño aunque los dedos
  /// no estén encima de él.
  Object? _selected;

  // Gesto en curso.
  Object? _dragItem;
  _Part _dragPart = _Part.body;
  bool _pinching = false;
  double _startSize = 0;

  /// Distancia en pantalla a la que se agarra un extremo o una línea.
  static const _handleReach = 28.0;
  static const _lineReach = 22.0;

  @visibleForTesting
  List<PhotoText> get texts => _texts;
  @visibleForTesting
  List<PhotoLine> get lines => _lines;
  @visibleForTesting
  Object? get selected => _selected;

  bool get _empty => _texts.isEmpty && _lines.isEmpty;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(await widget.source.readAsBytes());
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      // El descriptor no aplica la rotación EXIF; la imagen decodificada sí.
      final codec = await descriptor.instantiateCodec(targetWidth: 64);
      final frame = await codec.getNextFrame();
      final rotated = frame.image.width > frame.image.height != descriptor.width > descriptor.height;
      final size = rotated
          ? Size(descriptor.height.toDouble(), descriptor.width.toDouble())
          : Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      if (mounted) setState(() => _imageSize = size);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No se pudo abrir la foto', color: AppColors.danger);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _editText(PhotoText? existing, {Offset? at}) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      builder: (_) => _TextSheet(initial: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.delete || result.text.trim().isEmpty) {
        if (existing != null) _remove(existing);
        return;
      }
      if (existing == null) {
        final t = PhotoText(
          text: result.text.trim(),
          center: at ?? const Offset(0.5, 0.5),
          color: result.color,
          background: result.background,
        );
        _texts.add(t);
        _selected = t;
      } else {
        existing
          ..text = result.text.trim()
          ..color = result.color
          ..background = result.background;
        _selected = existing;
      }
    });
  }

  Future<void> _editLine(PhotoLine? existing) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      builder: (_) => _LineSheet(initial: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.delete) {
        if (existing != null) _remove(existing);
        return;
      }
      if (existing == null) {
        final l = PhotoLine(
          start: const Offset(0.25, 0.5),
          end: const Offset(0.75, 0.5),
          color: result.color,
          label: result.text.trim(),
        );
        _lines.add(l);
        _selected = l;
      } else {
        existing
          ..label = result.text.trim()
          ..color = result.color;
        _selected = existing;
      }
    });
  }

  void _remove(Object item) {
    _texts.remove(item);
    _lines.remove(item);
    if (_selected == item) _selected = null;
  }

  Future<void> _save() async {
    final size = _imageSize;
    if (size == null || _empty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final file = await renderPhotoTexts(widget.source, _texts, lines: _lines);
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      debugPrint('Editor: $e');
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, 'No se pudo guardar en la foto', color: AppColors.danger);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_empty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Descartar los cambios?'),
        content: const Text('La foto se queda como estaba.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir editando')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------------------- gestos

  /// Lo que hay bajo [point] (en la foto como se ve en pantalla): primero los
  /// extremos de las medidas, luego los textos y al final el resto de las
  /// medidas. Lo agregado al último queda encima.
  (Object, _Part)? _hitTest(Offset point, Size shown) {
    Offset abs(Offset rel) => Offset(rel.dx * shown.width, rel.dy * shown.height);
    for (final l in _lines.reversed) {
      if ((point - abs(l.start)).distance <= _handleReach) return (l, _Part.start);
      if ((point - abs(l.end)).distance <= _handleReach) return (l, _Part.end);
    }
    for (final t in _texts.reversed) {
      if (t.rect(shown).inflate(6).contains(point)) return (t, _Part.body);
    }
    for (final l in _lines.reversed) {
      if (_distanceToSegment(point, abs(l.start), abs(l.end)) <= _lineReach) return (l, _Part.body);
      if (l.labelText?.rect(shown).inflate(6).contains(point) ?? false) return (l, _Part.body);
    }
    return null;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  void _onTap(Offset point, Size shown) {
    final hit = _hitTest(point, shown);
    switch (hit?.$1) {
      case final PhotoText t:
        setState(() => _selected = t);
        _editText(t);
      case final PhotoLine l:
        setState(() => _selected = l);
        _editLine(l);
      default:
        _editText(null, at: Offset(point.dx / shown.width, point.dy / shown.height));
    }
  }

  void _onScaleStart(ScaleStartDetails d, Size shown) {
    // Al poner el segundo dedo el gesto vuelve a empezar con dos: entonces
    // se pellizca lo seleccionado, esté donde esté.
    if (d.pointerCount > 1) {
      final target = _selected ?? _hitTest(d.localFocalPoint, shown)?.$1;
      _dragItem = target;
      _pinching = target != null;
      _startSize = switch (target) {
        final PhotoText t => t.size,
        final PhotoLine l => l.width,
        _ => 0.0,
      };
      if (target != null) setState(() => _selected = target);
      return;
    }
    _pinching = false;
    final hit = _hitTest(d.localFocalPoint, shown);
    _dragItem = hit?.$1;
    _dragPart = hit?.$2 ?? _Part.body;
    if (hit != null) setState(() => _selected = hit.$1);
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size shown) {
    final item = _dragItem;
    if (item == null) return;
    final delta = Offset(d.focalPointDelta.dx / shown.width, d.focalPointDelta.dy / shown.height);
    Offset clamp(Offset o) => Offset(o.dx.clamp(0.0, 1.0), o.dy.clamp(0.0, 1.0));
    setState(() {
      if (_pinching && d.pointerCount > 1) {
        switch (item) {
          case final PhotoText t:
            t.size = (_startSize * d.scale).clamp(PhotoText.minSize, PhotoText.maxSize);
            t.center = clamp(t.center + delta);
          case final PhotoLine l:
            l.width = (_startSize * d.scale).clamp(PhotoLine.minWidth, PhotoLine.maxWidth);
        }
        return;
      }
      switch ((item, _dragPart)) {
        case (final PhotoText t, _):
          t.center = clamp(t.center + delta);
        case (final PhotoLine l, _Part.start):
          l.start = clamp(l.start + delta);
        case (final PhotoLine l, _Part.end):
          l.end = clamp(l.end + delta);
        case (final PhotoLine l, _Part.body):
          // Se mueve entera sin que ningún extremo salga de la foto.
          final dx = delta.dx.clamp(-math.min(l.start.dx, l.end.dx), 1 - math.max(l.start.dx, l.end.dx)).toDouble();
          final dy = delta.dy.clamp(-math.min(l.start.dy, l.end.dy), 1 - math.max(l.start.dy, l.end.dy)).toDouble();
          l.start += Offset(dx, dy);
          l.end += Offset(dx, dy);
      }
    });
  }

  void _onScaleEnd() {
    _dragItem = null;
    _pinching = false;
  }

  // ---------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _empty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: _canvas()),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: _saving
                  ? null
                  : () async {
                      if (await _confirmDiscard() && mounted) Navigator.pop(context);
                    },
            ),
            const Expanded(
              child: Text('Texto y medidas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            AppButton(
              _saving ? 'Guardando…' : 'Listo',
              icon: Icons.check_rounded,
              compact: true,
              onPressed: _saving || _imageSize == null ? null : _save,
            ),
          ],
        ),
      );

  Widget _bottomBar() {
    final ready = !_saving && _imageSize != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _empty
                ? 'Toca la foto donde quieras un texto, o agrega una medida.'
                : 'Arrastra para mover; en una medida, arrastra sus extremos. Con dos dedos en cualquier parte '
                    'de la foto cambias el tamaño de lo seleccionado. Toca un elemento para editarlo.',
            style: T.tiny.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton('Texto', icon: Icons.text_fields_rounded, kind: AppButtonKind.secondary, compact: true,
                    expand: true, onPressed: ready ? () => _editText(null) : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('Medida', icon: Icons.straighten_rounded, kind: AppButtonKind.secondary, compact: true,
                    expand: true, onPressed: ready ? () => _editLine(null) : null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    final size = _imageSize;
    if (size == null) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(builder: (context, box) {
      // La foto ajustada al espacio, como BoxFit.contain.
      final scale = math.min(box.maxWidth / size.width, box.maxHeight / size.height);
      final shown = Size(size.width * scale, size.height * scale);
      return Center(
        child: SizedBox.fromSize(
          size: shown,
          child: GestureDetector(
            key: const ValueKey('editor-canvas'),
            behavior: HitTestBehavior.opaque,
            onTapUp: _saving ? null : (d) => _onTap(d.localPosition, shown),
            onScaleStart: _saving ? null : (d) => _onScaleStart(d, shown),
            onScaleUpdate: _saving ? null : (d) => _onScaleUpdate(d, shown),
            onScaleEnd: _saving ? null : (_) => _onScaleEnd(),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: Image.file(widget.source, fit: BoxFit.fill, cacheWidth: (shown.width * 3).round())),
                Positioned.fill(
                  child: CustomPaint(painter: _EditorPainter(_texts, _lines, _selected)),
                ),
                if (_saving)
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.black54, child: Center(child: CircularProgressIndicator())),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Lo mismo que se guarda en la foto, más lo que sólo ayuda a editar: el
/// marco de lo seleccionado y los extremos de las medidas para arrastrarlos.
class _EditorPainter extends CustomPainter {
  _EditorPainter(this.texts, this.lines, this.selected);
  final List<PhotoText> texts;
  final List<PhotoLine> lines;
  final Object? selected;

  @override
  void paint(Canvas canvas, Size size) {
    paintAnnotations(canvas, size, texts, lines);
    final frame = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (selected case final PhotoText t) {
      canvas.drawRRect(RRect.fromRectAndRadius(t.rect(size).inflate(5), const Radius.circular(8)), frame);
    }
    for (final l in lines) {
      final on = identical(l, selected);
      for (final end in [l.start, l.end]) {
        final c = Offset(end.dx * size.width, end.dy * size.height);
        canvas.drawCircle(c, 10, Paint()..color = Colors.white.withValues(alpha: on ? 0.9 : 0.55));
        canvas.drawCircle(c, 10, Paint()
          ..color = on ? AppColors.accent : Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 3 : 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Dibuja [texts] y [lines] sobre la foto a su resolución real y la guarda
/// como JPEG en un temporal (o en [into]). Conserva el EXIF de la original
/// (fecha, GPS) salvo la rotación, que ya queda aplicada.
Future<File> renderPhotoTexts(File source, List<PhotoText> texts,
    {List<PhotoLine> lines = const [], Directory? into}) async {
  final bytes = await source.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final photo = (await codec.getNextFrame()).image;
  codec.dispose();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(photo, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  paintAnnotations(canvas, Size(photo.width.toDouble(), photo.height.toDouble()), texts, lines);
  final picture = recorder.endRecording();
  final out = await picture.toImage(photo.width, photo.height);
  picture.dispose();
  photo.dispose();
  final raw = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = out.width, height = out.height;
  out.dispose();
  if (raw == null) throw const FormatException('No se pudo dibujar la foto');

  final dir = into ?? await getTemporaryDirectory();
  final dest = p.join(dir.path, 'solaris_texto_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await _encodeJpeg(raw.buffer.asUint8List(), width, height, bytes, dest);
  return File(dest);
}

// Suelta para que el cierre que va al isolate sólo lleve sus argumentos.
Future<void> _encodeJpeg(Uint8List rgba, int width, int height, Uint8List original, String dest) => Isolate.run(() {
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      var jpeg = img.encodeJpg(image, quality: 92);
      final exif = img.decodeJpgExif(original);
      if (exif != null && !exif.isEmpty) {
        exif.imageIfd.orientation = null;
        jpeg = img.injectJpgExif(jpeg, exif) ?? jpeg;
      }
      File(dest).writeAsBytesSync(jpeg, flush: true);
    });

class _EditResult {
  const _EditResult(this.text, this.color, {this.background = true, this.delete = false});
  final String text;
  final Color color;
  final bool background;
  final bool delete;
}

/// Fila de colores para elegir.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelected});
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => onSelected(c),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == c ? AppColors.accent : AppColors.border,
                    width: selected == c ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      );
}

/// Botones Borrar (al editar) y Aceptar de las hojas.
Widget _sheetButtons(BuildContext context, {required bool editing, required _EditResult Function() result}) => Row(
      children: [
        if (editing) ...[
          Expanded(
            child: AppButton('Borrar', icon: Icons.delete_outline_rounded, kind: AppButtonKind.danger, expand: true,
                onPressed: () => Navigator.pop(context, _EditResult('', Colors.white, delete: true))),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AppButton('Aceptar', icon: Icons.check_rounded, expand: true,
              onPressed: () => Navigator.pop(context, result())),
        ),
      ],
    );

/// Hoja para escribir el texto, elegir color y si lleva recuadro.
class _TextSheet extends StatefulWidget {
  const _TextSheet({this.initial});
  final PhotoText? initial;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initial?.text ?? '');
  late Color _color = widget.initial?.color ?? Colors.white;
  late bool _background = widget.initial?.background ?? true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.initial == null ? 'Nuevo texto' : 'Editar texto', style: T.h3),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ej. ITM sin etiqueta'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ColorRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
              const Expanded(
                child: Text('Recuadro', style: T.small, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Transform.scale(
                scale: 0.78,
                child: Switch(value: _background, onChanged: (v) => setState(() => _background = v)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sheetButtons(context,
              editing: widget.initial != null,
              result: () => _EditResult(_controller.text, _color, background: _background)),
        ],
      ),
    );
  }
}

/// Hoja de una medida: el valor que se escribe al centro (opcional) y el color.
class _LineSheet extends StatefulWidget {
  const _LineSheet({this.initial});
  final PhotoLine? initial;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late final _controller = TextEditingController(text: widget.initial?.label ?? '');
  late Color _color = widget.initial?.color ?? const Color(0xFFFFC24B);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.initial == null ? 'Nueva medida' : 'Editar medida', style: T.h3),
          const SizedBox(height: 4),
          const Text('Línea con flecha en los dos extremos. Después arrastra sus extremos hasta los puntos que mides.',
              style: T.small),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: widget.initial == null,
            decoration: const InputDecoration(hintText: 'Medida (opcional), ej. 1.20 m'),
          ),
          const SizedBox(height: 14),
          _ColorRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
          const SizedBox(height: 14),
          _sheetButtons(context, editing: widget.initial != null, result: () => _EditResult(_controller.text, _color)),
        ],
      ),
    );
  }
}
