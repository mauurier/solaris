# Dependencias

Versiones tomadas de `pubspec.yaml` (restricción) y `pubspec.lock` (versión
resuelta). Para ver las actualizaciones disponibles: `flutter pub outdated`.

## Flutter (Dart)

| Librería | Restricción | Resuelta | Uso en el proyecto |
|---|---|---|---|
| `flutter` (SDK) | — | — | Framework de la interfaz |
| `supabase_flutter` | ^2.18.3 | 2.18.3 | Cliente de Supabase: Auth, tablas (PostgREST), Storage y Edge Functions (`lib/data/auth/`, `lib/data/sync/sync_service.dart`, `lib/data/history.dart`) |
| `sqflite` | ^2.4.4 | 2.4.4 | Base de datos local SQLite (`lib/data/storage/sqlite_persistence.dart`) |
| `shared_preferences` | ^2.5.6 | 2.5.6 | Ajustes, perfil guardado, lista de usuarios y cursores de sincronización |
| `path_provider` | ^2.1.6 | 2.1.6 | Carpeta de documentos de la app y carpetas temporales |
| `path` | ^1.9.1 | 1.9.1 | Armar y separar rutas de archivos |
| `uuid` | ^4.6.0 | 4.6.0 | Ids de los registros creados en el teléfono (`SurveyStore`, `Catalog`, plantillas) |
| `connectivity_plus` | ^7.3.1 | 7.3.1 | Saber si hay red y si es Wi-Fi (`SyncService`) |
| `http` | ^1.6.0 | 1.6.0 | Sólo para reconocer `ClientException` como error de red (`lib/data/remote_errors.dart`) |
| `camera` | ^0.12.1 | 0.12.1 | Cámara para fotos y video (`lib/features/capture/camera_screen.dart`) |
| `geolocator` | ^14.0.3 | 14.0.3 | GPS (`lib/core/services/location_service.dart`) |
| `image` | ^4.10.1 | 4.10.1 | Imprimir la marca de agua y el texto sobre las fotos, reducir fotos para el PDF, generar el ícono (`tool/generate_app_icon.dart`) |
| `video_player` | ^2.14.0 | 2.14.0 | Reproducir videos de evidencia (`lib/features/capture/video_view.dart`) |
| `file_picker` | ^13.1.0 | 13.1.0 | Elegir fotos, videos y documentos de la galería o de Archivos |
| `archive` | ^4.3.0 | 4.3.0 | Crear el ZIP del proyecto (`lib/core/services/export_service.dart`) |
| `pdf` | ^3.13.1 | 3.13.1 | Armar el reporte PDF (`lib/core/services/report_service.dart`) |
| `printing` | ^5.15.1 | 5.15.1 | Mostrar el PDF página por página dentro de la app (`lib/features/report/report_screen.dart`) |
| `share_plus` | ^13.3.0 | 13.3.0 | Compartir el ZIP, el PDF, documentos y evidencias con el menú del sistema |
| `url_launcher` | ^6.3.3 | 6.3.3 | Abrir Google Maps con las coordenadas (`lib/core/services/maps.dart`) |
| `cupertino_icons` | ^1.0.8 | 1.0.9 | Viene de la plantilla de Flutter. **Ningún archivo lo usa.** |

## Desarrollo y pruebas

| Librería | Restricción | Resuelta | Uso |
|---|---|---|---|
| `flutter_test` (SDK) | — | — | Pruebas unitarias y de widgets (`test/`) |
| `integration_test` (SDK) | — | — | Prueba en dispositivo del video nativo (`integration_test/video_watermark_test.dart`) |
| `flutter_lints` | ^6.0.0 | 6.0.0 | Reglas de `flutter analyze` (`analysis_options.yaml`) |
| `sqflite_common_ffi` | ^2.4.3 | 2.4.3 | Abrir una base SQLite real en el escritorio durante las pruebas (`test/survey_test.dart`) |

## Android nativo

| Dependencia | Versión | Uso |
|---|---|---|
| `androidx.media3:media3-transformer` | 1.9.2 | Procesar el video: marca de agua y bajar a 720p (`VideoWatermark.kt`) |
| `androidx.media3:media3-effect` | 1.9.2 | Superposición de la marca y cambio de tamaño |
| `androidx.media3:media3-common` | 1.9.2 | Tipos comunes de Media3 |

Se usa la misma versión de Media3 que trae `video_player`, para no mezclar
versiones (comentario en `android/app/build.gradle.kts`).

### Herramientas de build

| Herramienta | Versión | Dónde |
|---|---|---|
| Android Gradle Plugin | 9.0.1 | `android/settings.gradle.kts` |
| Kotlin Android plugin | 2.3.20 | `android/settings.gradle.kts` |
| Gradle | 9.1.0 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Flutter plugin loader | 1.0.0 | `android/settings.gradle.kts` |

## Servidor (Edge Functions)

| Dependencia | Versión | Uso |
|---|---|---|
| `npm:@supabase/supabase-js` | 2 | Cliente de Supabase dentro de `crear-usuario` y `cambiar-contrasena` (Deno) |

## Assets

| Recurso | Licencia | Uso |
|---|---|---|
| Roboto Regular y Bold (`assets/fonts/`) | Apache 2.0 (`assets/fonts/ROBOTO_LICENSE.txt`) | Tipografía del reporte PDF |
