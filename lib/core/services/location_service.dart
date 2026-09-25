import 'package:geolocator/geolocator.dart';

import '../../data/survey/entities.dart';

enum GpsStatus { ok, disabled, denied, timeout }

class GpsFix {
  const GpsFix(this.point, this.status);
  final GeoPoint? point;
  final GpsStatus status;

  String get problem => switch (status) {
        GpsStatus.ok => '',
        GpsStatus.disabled => 'La ubicación del teléfono está apagada',
        GpsStatus.denied => 'Sin permiso de ubicación para Solaris',
        GpsStatus.timeout => 'Sin señal GPS disponible',
      };
}

/// Lectura de GPS con tolerancia a interiores: si no hay posición nueva en
/// [timeout], usa la última conocida y, si tampoco existe, avisa sin bloquear.
class LocationService {
  LocationService._();

  static Future<GpsFix> current({Duration timeout = const Duration(seconds: 6)}) {
    // Tope global por si el sistema nunca contesta. Deja margen para que el
    // técnico lea y acepte el aviso de permiso la primera vez.
    return _read(timeout).timeout(timeout + const Duration(seconds: 25),
        onTimeout: () => const GpsFix(null, GpsStatus.timeout));
  }

  static Future<GpsFix> _read(Duration timeout) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GpsFix(null, GpsStatus.disabled);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return const GpsFix(null, GpsStatus.denied);
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
        );
        return GpsFix(GeoPoint(pos.latitude, pos.longitude), GpsStatus.ok);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return GpsFix(GeoPoint(last.latitude, last.longitude), GpsStatus.ok);
        return const GpsFix(null, GpsStatus.timeout);
      }
    } catch (_) {
      // Plataforma sin GPS (pruebas, escritorio).
      return const GpsFix(null, GpsStatus.timeout);
    }
  }
}
