import 'dart:convert';
import 'dart:io';

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
}
