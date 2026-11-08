import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/survey/entities.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// Abre [point] en Google Maps (la app si está instalada, si no el
/// navegador). Es el mismo enlace que va impreso en la marca de agua.
Future<void> openInMaps(BuildContext context, GeoPoint point) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(point.mapsUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showAppSnack(context, 'No se pudo abrir Maps · ${point.label}', color: AppColors.danger);
  }
}

/// Foto que, al tocarla, abre en Maps el lugar donde se tomó. Muestra un
/// botón "Maps" en la esquina para que se sepa. Sin coordenadas no hace nada.
class MapsPhoto extends StatelessWidget {
  const MapsPhoto({super.key, required this.point, required this.child});
  final GeoPoint? point;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = point;
    if (p == null) return child;
    return Stack(
      children: [
        GestureDetector(onTap: () => openInMaps(context, p), child: child),
        Positioned(
          right: 10,
          bottom: 10,
          child: GestureDetector(
            onTap: () => openInMaps(context, p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 14, color: AppColors.blue),
                  SizedBox(width: 5),
                  Text('Maps', style: TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
