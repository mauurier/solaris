import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:proyecto_app/core/services/report_service.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';

import 'test_helpers.dart';

File _jpeg(Directory dir, String name) {
  final image = img.Image(width: 2400, height: 1800)..clear(img.ColorRgb8(90, 140, 110));
  return File('${dir.path}/$name')..writeAsBytesSync(img.encodeJpg(image));
}

void main() {
  testWidgets('el reporte sale con hallazgos, respuestas y muchas fotos repartidas en páginas', (tester) async {
    signInAs(UserRole.tecnico);
    final store = await initTestStore();
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    // En el teléfono las pantallas escuchan el store y guardan objetos que no
    // pueden viajar a otro isolate. Antes el reporte mandaba el store entero
    // con cada foto y fallaba ("object is unsendable").
    final port = ReceivePort();
    addTearDown(port.close);
    store.addListener(() => port.hashCode);
    await store.setAnswer(v, const AnswerKey('g_transformador', 0, 'conexion'), 'Δ-Y');
    await store.setAnswer(v, const AnswerKey('g_datos', 0, 'obs'), 'Observación con acentos: ñandú, interconexión.');

    late List<int> bytes;
    var progress = 0;
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await store.addEvidence(
            visit: v, key: const AnswerKey('g_transformador', 0, 'generales'), kind: EvidenceKind.photo,
            file: _jpeg(store.files.root, 'f$i.jpg'));
      }
      final f = await store.addFinding(v,
          category: FindingCategory.electrico, severity: Severity.alta, description: 'ITM sin etiqueta');
      await store.addEvidence(visit: v, findingId: f.id, kind: EvidenceKind.photo, file: _jpeg(store.files.root, 'h.jpg'));
      bytes = await ReportService(store).build(v, onProgress: (done, total) => progress = done);
    });

    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(progress, 21, reason: 'avisa cada foto preparada');
    expect(bytes.length, lessThan(3 * 1024 * 1024), reason: 'las fotos se reducen');
    expect(ReportService(store).fileName(v), 'REPORTE_REY01202_VIS-001.pdf');
  });

  testWidgets('sólo salen las partes elegidas', (tester) async {
    signInAs(UserRole.tecnico);
    final store = await initTestStore();
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    const placa = AnswerKey('g_transformador', 0, 'generales');

    await tester.runAsync(() async {
      await store.addEvidence(visit: v, key: placa, kind: EvidenceKind.photo, file: _jpeg(store.files.root, 'a.jpg'));
      final f = await store.addFinding(v,
          category: FindingCategory.electrico, severity: Severity.alta, description: 'ITM sin etiqueta');
      await store.addEvidence(visit: v, findingId: f.id, kind: EvidenceKind.photo, file: _jpeg(store.files.root, 'h.jpg'));
    });

    final service = ReportService(store);
    expect(service.imagesFor(v, ReportOptions()), hasLength(2));
    expect(service.imagesFor(v, ReportOptions(excludedBlocks: {'g_transformador#0'})), hasLength(1),
        reason: 'el bloque quitado no prepara sus fotos');
    expect(service.imagesFor(v, ReportOptions(findings: false)), hasLength(1));
    expect(service.imagesFor(v, ReportOptions(photos: false)), isEmpty);

    // Sólo la portada: no truena aunque no quede ninguna sección.
    final template = store.templateFor(v);
    final none = ReportOptions(summary: false, findings: false, excludedBlocks: {
      for (final s in template.sections)
        for (final g in s.groups)
          for (var i = 0; i < store.engineFor(v).instanceCount(g); i++) ReportOptions.blockKey(g, i),
    });
    late List<int> bytes;
    var progress = 0;
    await tester.runAsync(() async {
      bytes = await service.build(v, options: none, onProgress: (done, _) => progress = done);
    });
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(progress, 0);
  });

  test('las coordenadas abren Google Maps', () {
    const point = GeoPoint(25.78123, -100.18456);
    expect(point.mapsText, 'maps.google.com/?q=25.78123,-100.18456');
    expect(point.mapsUrl, 'https://maps.google.com/?q=25.78123,-100.18456');
  });
}
