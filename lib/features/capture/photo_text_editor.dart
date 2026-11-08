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
}

/// Editor que sólo agrega texto encima de una foto: tocar la foto pone un
/// texto, arrastrarlo lo mueve, pellizcarlo cambia su tamaño y tocarlo lo
/// edita o lo borra. Al guardar se dibuja en la foto a su resolución real.
class PhotoTextEditor extends StatefulWidget {
  const PhotoTextEditor({super.key, required this.source});
  final File source;

  /// Devuelve la foto editada en un temporal, o nula si se canceló o no hubo
  /// cambios.
  static Future<File?> open(BuildContext context, File source) =>
      Navigator.of(context).push<File>(appRoute(PhotoTextEditor(source: source), fullscreenDialog: true));

  @override
  State<PhotoTextEditor> createState() => _PhotoTextEditorState();
}

class _PhotoTextEditorState extends State<PhotoTextEditor> {
  final _texts = <PhotoText>[];
  Size? _imageSize;
  bool _saving = false;

  // Gesto en curso sobre un texto.
  PhotoText? _active;
  double _startSize = 0;

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

  Future<void> _edit(PhotoText? existing, {Offset? at}) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      builder: (_) => _TextSheet(initial: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.delete || result.text.trim().isEmpty) {
        if (existing != null) _texts.remove(existing);
        return;
      }
      if (existing == null) {
        _texts.add(PhotoText(
          text: result.text.trim(),
          center: at ?? const Offset(0.5, 0.5),
          color: result.color,
          background: result.background,
        ));
      } else {
        existing
          ..text = result.text.trim()
          ..color = result.color
          ..background = result.background;
      }
    });
  }

  Future<void> _save() async {
    final size = _imageSize;
    if (size == null || _texts.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final file = await renderPhotoTexts(widget.source, _texts);
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      debugPrint('Editor: $e');
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, 'No se pudo guardar el texto en la foto', color: AppColors.danger);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_texts.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Descartar los textos?'),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _texts.isEmpty && !_saving,
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
            const Expanded(child: Text('Agregar texto', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
            AppButton(
              _saving ? 'Guardando…' : 'Listo',
              icon: Icons.check_rounded,
              compact: true,
              onPressed: _saving || _imageSize == null ? null : _save,
            ),
          ],
        ),
      );

  Widget _bottomBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _texts.isEmpty
                    ? 'Toca la foto donde quieras el texto.'
                    : 'Arrastra para mover, pellizca para cambiar el tamaño y toca un texto para editarlo.',
                style: T.tiny.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            AppButton('Texto', icon: Icons.text_fields_rounded, kind: AppButtonKind.secondary, compact: true,
                onPressed: _saving || _imageSize == null ? null : () => _edit(null)),
          ],
        ),
      );

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
            behavior: HitTestBehavior.opaque,
            onTapUp: _saving
                ? null
                : (d) => _edit(null, at: Offset(d.localPosition.dx / shown.width, d.localPosition.dy / shown.height)),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: Image.file(widget.source, fit: BoxFit.fill, cacheWidth: (shown.width * 3).round())),
                for (final t in _texts) _textWidget(t, shown),
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

  Widget _textWidget(PhotoText t, Size shown) {
    final w = shown.width;
    return Positioned(
      left: t.center.dx * w,
      top: t.center.dy * shown.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: _saving ? null : () => _edit(t),
          onScaleStart: (_) {
            _active = t;
            _startSize = t.size;
          },
          onScaleUpdate: (d) {
            if (_active != t) return;
            setState(() {
              t.center = Offset(
                (t.center.dx + d.focalPointDelta.dx / w).clamp(0.0, 1.0),
                (t.center.dy + d.focalPointDelta.dy / shown.height).clamp(0.0, 1.0),
              );
              if (d.pointerCount > 1) t.size = (_startSize * d.scale).clamp(PhotoText.minSize, PhotoText.maxSize);
            });
          },
          onScaleEnd: (_) => _active = null,
          child: Container(
            constraints: BoxConstraints(maxWidth: t.maxWidth(w)),
            padding: t.padding(w),
            decoration: t.background ? BoxDecoration(color: t.boxColor, borderRadius: BorderRadius.all(t.radius(w))) : null,
            child: Text(t.text, style: t.style(w), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

/// Dibuja [texts] sobre la foto a su resolución real y la guarda como JPEG
/// en un temporal (o en [into]). Conserva el EXIF de la original (fecha, GPS)
/// salvo la rotación, que ya queda aplicada.
Future<File> renderPhotoTexts(File source, List<PhotoText> texts, {Directory? into}) async {
  final bytes = await source.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final photo = (await codec.getNextFrame()).image;
  codec.dispose();
  final w = photo.width.toDouble(), h = photo.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(photo, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  for (final t in texts) {
    final painter = TextPainter(
      text: TextSpan(text: t.text, style: t.style(w)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final pad = t.padding(w);
    painter.layout(maxWidth: t.maxWidth(w) - pad.horizontal);
    final box = Size(painter.width + pad.horizontal, painter.height + pad.vertical);
    final topLeft = Offset(t.center.dx * w - box.width / 2, t.center.dy * h - box.height / 2);
    if (t.background) {
      canvas.drawRRect(RRect.fromRectAndRadius(topLeft & box, t.radius(w)), Paint()..color = t.boxColor);
    }
    painter.paint(canvas, topLeft + Offset(pad.left, pad.top));
    painter.dispose();
  }
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
  const _EditResult(this.text, this.color, this.background, {this.delete = false});
  final String text;
  final Color color;
  final bool background;
  final bool delete;
}

/// Hoja para escribir el texto, elegir color y si lleva recuadro.
class _TextSheet extends StatefulWidget {
  const _TextSheet({this.initial});
  final PhotoText? initial;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  static const _colors = [
    Colors.white,
    Colors.black,
    Color(0xFFFFC24B),
    Color(0xFFF87171),
    Color(0xFF3DD68C),
    Color(0xFF5B9DF9),
  ];

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
              for (final c in _colors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? AppColors.accent : AppColors.border,
                        width: _color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              const Text('Recuadro', style: T.small),
              Transform.scale(
                scale: 0.78,
                child: Switch(value: _background, onChanged: (v) => setState(() => _background = v)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (widget.initial != null) ...[
                Expanded(
                  child: AppButton('Borrar', icon: Icons.delete_outline_rounded, kind: AppButtonKind.danger, expand: true,
                      onPressed: () => Navigator.pop(context, _EditResult('', _color, _background, delete: true))),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppButton('Aceptar', icon: Icons.check_rounded, expand: true,
                    onPressed: () => Navigator.pop(context, _EditResult(_controller.text, _color, _background))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
