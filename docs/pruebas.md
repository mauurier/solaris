# Pruebas

## Qué hay

| Tipo | Dónde | Cuántas |
|---|---|---|
| Unitarias y de widgets (Flutter) | `test/` | 17 archivos, 174 casos al ejecutarse (algunos se generan en bucle) |
| Integración en dispositivo | `integration_test/video_watermark_test.dart` | 1 |
| Pruebas instrumentadas o unitarias nativas de Android (`androidTest`, JUnit) | — | **No hay** |
| Pruebas de las Edge Functions o del SQL | — | **No hay** |

Las pruebas de Flutter no tocan Supabase ni el disco real:

- `MemoryPersistence` reemplaza a SQLite (salvo el grupo "SQLite", que abre una
  base real con `sqflite_common_ffi`).
- `test/fake_remote.dart` es un servidor falso que implementa `RemoteSource`.
- `test/test_helpers.dart` prepara el store, usuarios de prueba, proyectos de
  ejemplo y un teléfono virtual de 390 × 844.
- `test/fixtures/electric_template.dart` trae la plantilla eléctrica para las pruebas.

## Cómo ejecutarlas

```bash
flutter analyze                     # análisis estático
flutter test                        # todas las pruebas de test/
flutter test test/sync_test.dart    # un solo archivo
flutter test --name "gana el cambio más reciente"   # por nombre

# En un emulador o teléfono conectado (procesamiento nativo de video):
flutter test integration_test/video_watermark_test.dart -d <id-del-dispositivo>
```

`flutter devices` muestra el id del dispositivo. La prueba de integración deja
el video en la carpeta de la app e imprime su ruta, para revisarlo (debe salir
720×1280, derecho y con la marca abajo a la izquierda).

`tool/generate_app_icon.dart` no es una prueba: genera los íconos de la app y
se ejecuta con `flutter test tool/generate_app_icon.dart`.

## Qué cubren

| Archivo | Qué prueba |
|---|---|
| `survey_test.dart` | Plantilla (JSON, plantilla eléctrica, nombres de instancias); motor de visita (condicionales, bloques repetibles, documentos que responden preguntas, mínimo de fotos, pendientes); store (alta de proyecto y primera visita, borrado lógico, versión de plantilla por visita, finalizar, correcciones, aprobación, hallazgos, catálogos, indicadores del inicio); SQLite (persistencia, migraciones, columna `base`, borrado del modo demo); marca de agua |
| `sync_test.dart` | Bajada (primera y siguientes, cambios locales que no se pisan, proyectos asignados o quitados, archivos, hallazgos, revisiones); subida (orden, sólo columnas cambiadas, conflictos, borrados, técnicos, rechazos del servidor, archivos antes que filas, Wi-Fi, paso a revisión, reemplazo de foto); cola y pantalla de sincronización; ajustes |
| `interactions_test.dart` | Flujos completos en pantalla: panel por rol, alta de proyecto, iniciar visita sin GPS, bloques repetibles, guardado automático, validación y justificación, finalizar, correcciones, hallazgos, editor de plantillas |
| `widget_test.dart` | Login al iniciar, técnico sin visitas, apertura de secciones, validación que bloquea |
| `screens_smoke_test.dart` | Que cada pantalla y cada sección del levantamiento se dibuje sin errores; cámara sin hardware |
| `projects_tab_test.dart` | Proyectos por cliente para admin, técnico y supervisor; filtros; estado de seguimiento del supervisor; botón central |
| `visits_tab_test.dart` | Filtros, búsqueda y nueva visita por rol; filtros del supervisor por técnico, fecha y correcciones |
| `approvals_test.dart` | Botón ✓ del supervisor y su contador |
| `quick_capture_test.dart` | Captura rápida con una o varias visitas en curso |
| `breakdown_test.dart` | Indicadores del inicio y desglose de evidencias |
| `report_test.dart` | PDF con hallazgos, respuestas y muchas fotos; partes elegidas; enlace a Maps |
| `photo_edit_test.dart` | Texto y línea de medida dibujados en la foto; en el editor, pellizcar con los dedos fuera del texto cambia su tamaño y los extremos de una medida se arrastran; reducción de fotos grandes; archivos que no son imagen |
| `video_test.dart` | Avance del procesamiento de video y respaldo si falla |
| `history_test.dart` | Textos del historial, agrupación, filtros, sin conexión |
| `profile_test.dart` | Vigencia de la cuenta, rol de la interfaz, perfil guardado |
| `user_directory_test.dart` | Usuarios asignables y cambio de contraseña |
| `sign_out_test.dart` | Cierre de sesión con y sin pendientes, sin conexión, pausado, subida cortada, rechazos |

## Resultado actual

Ejecución en Linux (Flutter 3.47.5), con el editor de texto y medidas:

- `flutter analyze`: **sin problemas**.
- `flutter test`: **159 pasan y 15 fallan**.

Las 15 que fallan son de `screens_smoke_test.dart` (8), `interactions_test.dart`
(6) y `history_test.dart` (1). La mayoría reportan desbordes de diseño
("A RenderFlex overflowed"); las demás no encuentran un texto o un botón en
pantalla. La causa probable es que `loadRealFont()` en `test/test_helpers.dart`
carga la fuente del sistema de macOS (`/System/Library/Fonts/SFNS.ttf`); en
Linux no existe y las pruebas usan la fuente de reemplazo de Flutter, que dibuja
el texto más ancho.

⚠️ Pendiente de confirmar: que estas 15 pruebas pasen en macOS, y que las que
no encuentran un texto se deban a la misma causa.

Nota: `flutter test` y `flutter analyze` pueden modificar `pubspec.lock` y
`analysis_options.yaml` al resolver dependencias; revisa `git status` antes de
hacer commit.
