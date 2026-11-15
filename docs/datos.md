# Datos

La app guarda todo primero en el teléfono y lo sincroniza con Supabase. Este
documento describe los modelos, la base local, las preferencias, los archivos y
lo que se consume del servidor.

## 1. Modelos de la app

Están en `lib/data/`. Cada modelo tiene `toJson()` y `fromJson()`; ese JSON
es lo que se guarda en SQLite.

| Clase | Archivo | Tabla local | Tabla en Supabase | Contenido principal |
|---|---|---|---|---|
| `TemplateDef` (con `SectionDef`, `GroupDef`, `QuestionDef`, `ShowIf`) | `lib/data/survey/template.dart` | `templates` | `plantilla` | Nombre, tipo, versión (`major`.`minor`), activa, secciones → bloques → preguntas |
| `CatalogItem` | `lib/data/catalog.dart` | `project_types`, `visit_motives` | `tipo_proyecto`, `motivo_visita` | id, nombre, orden |
| `SurveyClient` | `lib/data/survey/entities.dart` | `clients` | `cliente` | Razón social, RFC, contacto |
| `SurveySite` | `lib/data/survey/entities.dart` | `sites` | `sitio` | Cliente, nombre, dirección, coordenadas |
| `SurveyProject` | `lib/data/survey/entities.dart` | `projects` | `proyecto` + `proyecto_tecnico` | Clave, nombre, sitio, supervisor, técnicos, plantilla, tipo, descripción, fechas, estado |
| `FieldVisit` | `lib/data/survey/entities.dart` | `visits` | `visita` | Número (VIS-001), técnico, supervisor, motivo, plantilla, fechas, GPS de inicio y fin, estado, copia de la plantilla, repeticiones, justificaciones, notas |
| Respuesta (mapa `clave → valor`) | `lib/data/survey_store.dart` | `answers` | `respuesta` | Clave `bloque#repetición/pregunta` y valor en texto |
| `Evidence` | `lib/data/survey/entities.dart` | `evidences` | `evidencia` | Tipo (foto, video, documento, firma), ruta, pregunta, GPS, comentario, importada, hallazgo |
| `ProjectDocument` | `lib/data/survey/entities.dart` | `documents` | `documento` | Categoría, ruta, nombre original, tamaño, quién lo subió |
| `VisitFinding` | `lib/data/survey/entities.dart` | `findings` | `hallazgo` | Código (HZ-001), categoría, severidad, descripción, ubicación, recomendación, estado, GPS |
| `VisitReview` | `lib/data/survey/entities.dart` | `reviews` | `revision` | Decisión (aprobada o con correcciones), observaciones, supervisor |
| `Correction` | `lib/data/survey/entities.dart` | `corrections` | `correccion` | Descripción, cuándo se atendió |
| `Profile` | `lib/data/auth/profile.dart` | (SharedPreferences) | `perfil` | Rol, activo, vigencia |
| `HistoryEntry` | `lib/data/history.dart` | (no se guarda) | `historial` | Tabla, acción, valores antes y después |

Otros tipos importantes:

- **Enums** (`lib/data/models.dart`): `UserRole` (admin, supervisor, tecnico),
  `ProjectStatus` (borrador, programado, asignado, enCampo, enCaptura,
  pendienteSync, enRevision, conCorrecciones, aprobado, cerrado), `VisitState`
  (porIniciar, enCurso, finalizada, aprobada; se calcula, no se guarda),
  `FindingCategory`, `Severity`, `FindingStatus`.
- **`QType`** (`lib/data/survey/template.dart`): tipos de pregunta: text,
  number, single, multi, scale, photo, video, document, signature.
- **`DocCategory.all`** (`lib/data/survey/entities.dart`): categorías de
  documento fijas en el código: recibo_cfe, unifilar, ingenieria, planos, cad,
  otro.
- **`Folders`** (`lib/data/survey/template.dart`): carpetas del ZIP (`01
  Información del Sitio` … `06 CAD y Modelos 3D`, `Evidencias Adicionales`).
- **`VisitEngine`** (`lib/data/survey/visit_engine.dart`): calcula preguntas
  visibles, avance por sección, pendientes (obligatorios, opcionales,
  justificados) y evidencias capturadas contra requeridas.

Los estados se guardan en camelCase en el teléfono y en snake_case en el
servidor (`enCaptura` ↔ `en_captura`); la conversión está en
`RemoteRows.statusToDb` y `RemoteRows.statusFromDb`
(`lib/data/sync/remote_rows.dart`).

## 2. Base de datos local (SQLite)

- **Archivo:** `solaris.db` en la carpeta de documentos de la app
  (`getApplicationDocumentsDirectory()`).
- **Implementación:** `SqlitePersistence` (`lib/data/storage/sqlite_persistence.dart`),
  con `sqflite`. Modo `WAL`.
- **No hay ORM, entidades Room ni DAOs.** Todas las tablas tienen el mismo
  esquema y guardan cada registro como JSON:

| Columna | Tipo | Uso |
|---|---|---|
| `id` | TEXT PK | Id del registro (uuid; en `answers`, `idVisita\|clave`) |
| `parent` | TEXT | Proyecto o visita dueña, para borrar en cascada |
| `data` | TEXT | El registro en JSON (`toJson()` del modelo) |
| `updated_at` | TEXT | Hora local de la última escritura (siempre creciente) |
| `pending` | INTEGER | 1 = falta subir al servidor |
| `deleted` | INTEGER | 1 = borrado en el teléfono; se borra de verdad cuando el servidor lo confirma |
| `base` | TEXT | El registro como estaba la última vez que coincidió con el servidor |

Índices: `idx_<tabla>_parent` y `idx_<tabla>_pending`.

**Tablas** (`Tables` en `lib/data/storage/persistence.dart`): `templates`,
`clients`, `sites`, `projects`, `documents`, `visits`, `answers`, `evidences`,
`project_types`, `visit_motives`, `reviews`, `corrections`, `findings`.

**Operaciones** (interfaz `Persistence`): `load`, `put` (con `pending: false`
para lo que llega del servidor), `remove`, `removeByParent`, `pending`,
`markSynced`, `forget`, `forgetByParent`. `MemoryPersistence` implementa la
misma interfaz en memoria para las pruebas.

**Migraciones** (versión actual: 9), en `SqlitePersistence.open`:

| Versión | Cambio |
|---|---|
| 2 | Tabla `project_types` |
| 3 | Tabla `visit_motives` |
| 4 | Ids del servidor, clientes y sitios, columnas `pending` y `deleted`. **Una base anterior a la 4 se vacía** (eran datos de prueba). |
| 5 | Se borra la copia local de la plantilla inicial para que baje la del servidor |
| 6 | Columna `base` |
| 7 | Se borra lo capturado en el modo demo (ids `demo-…`) |
| 8 | Tablas `reviews` y `corrections` |
| 9 | Tabla `findings` |

## 3. Archivos en el teléfono

`FileStore` (`lib/data/storage/file_store.dart`) guarda los archivos en
`<documentos de la app>/solaris_media/`. La base guarda rutas **relativas**.

| Qué | Ruta relativa |
|---|---|
| Evidencias de una visita | `media/<idProyecto>/<idVisita>/<id>.<ext>` |
| Documentos del proyecto | `media/<idProyecto>/docs/<id>.<ext>` |

Al arrancar se borran las carpetas `media/<id>` de proyectos que ya no están
en el teléfono.

## 4. Preferencias (SharedPreferences)

No se usa DataStore.

| Clave | Archivo | Contenido |
|---|---|---|
| `ajustes.solo_wifi` | `lib/data/app_state.dart` | Archivos sólo con Wi-Fi (por defecto `true`) |
| `ajustes.sync_auto` | `lib/data/app_state.dart` | Sincronización automática (por defecto `true`) |
| `ajustes.comentario_por_foto` | `lib/data/app_state.dart` | Pedir comentario tras cada foto (por defecto `false`) |
| `auth.perfil` | `lib/data/auth/auth_service.dart` | Perfil de la sesión, para entrar sin conexión |
| `auth.recordar` | `lib/data/auth/auth_service.dart` | "Mantener sesión" |
| `usuarios.lista` | `lib/data/auth/user_directory.dart` | Lista de cuentas para asignar sin conexión |
| `sync.usuario` | `lib/data/sync/sync_service.dart` | Dueño de los cursores de sincronización |
| `sync.desde.<tabla>` | `lib/data/sync/sync_service.dart` | Hasta qué `actualizado_en` ya se bajó cada tabla |
| `sync.por_revisar` | `lib/data/sync/sync_service.dart` | Visitas terminadas que pasan a revisión al terminar de subir |

"Pausar sincronización" (`AppState.offlineMode`) no se guarda: vuelve a
`false` al reiniciar la app.

Supabase Auth guarda además la sesión por su cuenta (paquete `supabase_flutter`).

## 5. Servidor: Supabase

### Conexión

- **Cliente:** `supabase_flutter`, inicializado en `AuthService.init()` con
  `SupabaseConfig.url` y `SupabaseConfig.publishableKey`
  (`lib/core/config/supabase_config.dart`). Ambos se pueden cambiar con
  `--dart-define` (ver [configuracion-y-build.md](configuracion-y-build.md)).
- **No hay API REST propia ni Retrofit.** La app usa la API REST que Supabase
  genera sobre las tablas (PostgREST, `<SUPABASE_URL>/rest/v1/<tabla>`), Storage,
  Auth y dos Edge Functions, siempre con la sesión del usuario.
- **Esquema:** `supabase/migrations/` (7 migraciones). La principal es
  `20261029120000_estructura_inicial.sql`. El diagrama entidad-relación está
  en [diagrama-er.md](diagrama-er.md).

### Tablas

| Tabla | La app la… | Notas |
|---|---|---|
| `perfil` | Lee y actualiza (superadmin) | Un registro por cuenta; lo crea el trigger `crear_perfil` al dar de alta en Auth |
| `cliente`, `sitio` | Sube y baja | |
| `tipo_proyecto`, `motivo_visita` | Sube y baja | Catálogos; nombre único entre los no borrados |
| `plantilla` | Sube y baja | `definicion` (jsonb) guarda las secciones |
| `proyecto`, `proyecto_tecnico` | Sube y baja | `codigo` único |
| `visita` | Sube y baja | `(id_proyecto, numero)` único |
| `respuesta` | Sube (upsert) y baja | Única por `(id_visita, clave_grupo, numero_repeticion, clave_pregunta)` |
| `evidencia`, `documento` | Sube y baja; los archivos van a Storage | `subido_en` nulo = archivo aún no sube |
| `hallazgo` | Sube y baja | `(id_visita, codigo)` único |
| `revision` | Sube y baja | No se edita; no tiene `actualizado_en` |
| `correccion` | Sube y baja | |
| `historial` | Sólo lee | La llenan triggers |
| `reporte`, `plantilla_reporte`, `configuracion` | **No las usa todavía** | Reservadas para una fase futura (ver abajo) |

Todas las tablas sincronizadas tienen `creado_en`, `actualizado_en` (un trigger
lo actualiza en cada `update`) y `eliminado_en` (borrado lógico).

**Tablas reservadas para una fase futura.** Se crearon con el resto del
esquema, pero la app todavía no las lee ni las escribe. Están vacías y no
afectan el funcionamiento:

| Tabla | Para qué está pensada | Cómo funciona hoy la app |
|---|---|---|
| `reporte` (y bucket `reportes`) | Guardar en el servidor cada PDF generado, con versión, autor y estado (borrador o final) | El PDF se genera en el teléfono y se comparte; no se sube al servidor |
| `plantilla_reporte` | Formato de reporte por cliente: logotipo, encabezado, pie y secciones | Hay un solo diseño de reporte, en `lib/core/services/report_service.dart` |
| `configuracion` | Ajustes generales de la empresa que edita el admin, como las carpetas del ZIP | Las carpetas del ZIP están fijas en `Folders` (`lib/data/survey/template.dart`) y "Pedir comentario por fotografía" es un ajuste de cada teléfono |

Para usarlas habría que agregarlas a la sincronización (`RemoteTable` y
`RemoteRows` en `lib/data/sync/remote_rows.dart`) o leerlas directamente con
Supabase, como hace el historial.

**Enums del servidor:** `rol_usuario`, `estado_trabajo`, `tipo_evidencia`,
`categoria_documento`, `categoria_hallazgo`, `severidad`, `estado_hallazgo`,
`decision_revision`, `estado_correccion`, `estado_reporte`, `accion_historial`.

**Datos iniciales:** 4 tipos de proyecto y 4 motivos de visita (migración
inicial) y la plantilla "Levantamiento eléctrico FV"
(`20261031022418_plantilla_levantamiento_electrico.sql`).

### Permisos (RLS) y triggers

- Funciones de permisos: `mi_rol()` (rol o nulo si la cuenta está inactiva,
  borrada o fuera de vigencia, con la fecha de `America/Mexico_City`),
  `es_admin()`, `es_superadmin()`, `puede_gestionar_proyecto()`,
  `puede_ver_proyecto()`, `puede_ver_visita()`, `puede_capturar_visita()`,
  `puede_revisar_visita()`.
- Resumen: el técnico ve sus proyectos y visitas y captura mientras la visita
  no esté aprobada o cerrada; el supervisor gestiona sus proyectos y revisa;
  el admin ve y gestiona todo; sólo el superadmin modifica `perfil`.
- Triggers: `tocar_actualizado_en`, `crear_perfil` y `copiar_email` (sobre
  `auth.users`), `proteger_visita` y `proteger_proyecto` (qué columnas puede
  cambiar el técnico) y `registrar_historial` (llena `historial` con los
  valores antes y después).

### Storage

Buckets privados, 50 MB por archivo:

| Bucket | Ruta | Tipos permitidos |
|---|---|---|
| `evidencias` | `{id_proyecto}/{id_visita}/{archivo}` | Cualquiera (se quitó la restricción en `20261031044831_evidencias_cualquier_tipo.sql`) |
| `documentos` | `{id_proyecto}/{archivo}` | Cualquiera |
| `reportes` | `{id_proyecto}/{archivo}.pdf`, `logos/{id}/{archivo}` | PDF, JPEG, PNG, SVG. Reservado para una fase futura. |

El acceso a cada archivo se decide con la carpeta de la ruta (proyecto o visita)
y las mismas funciones de permisos.

### Operaciones que hace la app

**Auth** (`lib/data/auth/auth_service.dart`):

| Operación | Detalle |
|---|---|
| `signInWithPassword` | Correo (en minúsculas) y contraseña. Tiempo límite 10 s. |
| `select` en `perfil` | `id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia, eliminado_en` del usuario con sesión |
| `signOut` | Sólo en este teléfono; funciona sin conexión |

**Sincronización** (`SupabaseRemote` en `lib/data/sync/sync_service.dart`):

| Operación | Cómo |
|---|---|
| Cambios desde una fecha | `select` con `actualizado_en >= desde − 2 min`, ordenado y paginado de 500 en 500 |
| Filas por id | `select … in (ids)` en grupos de 100 |
| Ids visibles | `select id` con `eliminado_en is null` (proyectos y visitas) |
| Alta | `insert` |
| Cambio | `update … match(id)`; si RLS no deja cambiar nada, se toma como rechazo |
| Respuestas | `upsert` con `onConflict: id_visita,clave_grupo,numero_repeticion,clave_pregunta` |
| Archivos | `storage.upload` (con `upsert`), `download`, `remove`; tiempo límite 5 min |

Tiempo límite de cada petición de datos: 20 s.

**Historial** (`lib/data/history.dart`): `select` en `historial`, del más
reciente al más antiguo, paginado de 50 en 50, filtrable por proyecto y por
tablas.

**Cuentas** (`lib/data/auth/user_directory.dart`): `select` y `update` en
`perfil` (rol, activo, vigencia) y las dos Edge Functions. Tiempo límite 15 s.

### Edge Functions

Código en `supabase/functions/`. Ambas tienen `verify_jwt = false` en
`supabase/config.toml` y revisan la sesión por su cuenta.

#### `POST <SUPABASE_URL>/functions/v1/crear-usuario`

Crea cuentas de admin, supervisor o técnico. Sólo un superadmin vigente.

- **Encabezado:** `Authorization: Bearer <access token del superadmin>`
- **Cuerpo:**

  ```json
  {
    "email": "usuario@empresa.com",
    "password": "<mínimo 8 caracteres>",
    "nombre": "Nombre Apellido",
    "rol": "admin | supervisor | tecnico",
    "inicio_vigencia": "AAAA-MM-DD",
    "fin_vigencia": "AAAA-MM-DD"
  }
  ```

  `inicio_vigencia` es opcional (por defecto hoy, hora de México);
  `fin_vigencia` es obligatoria y no puede ser anterior al inicio.
- **Respuesta 201:** `{ "perfil": { id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia } }`
- **Errores:** 400 datos inválidos (`{error, detalles}`), 401 sin sesión,
  403 no es superadmin, 405 método distinto de POST, 409 el correo ya existe,
  500 error del servidor. Si no se puede guardar el perfil, borra la cuenta
  recién creada.

#### `POST <SUPABASE_URL>/functions/v1/cambiar-contrasena`

Pone una contraseña nueva a una cuenta. Sólo un superadmin vigente; no aplica a
cuentas de superadmin.

- **Encabezado:** `Authorization: Bearer <access token del superadmin>`
- **Cuerpo:** `{ "id_usuario": "<uuid del perfil>", "password": "<mínimo 8 caracteres>" }`
- **Respuesta 200:** `{ "ok": true }`
- **Errores:** 400 datos inválidos, 401 sin sesión, 403 no es superadmin o la
  cuenta es de un superadmin, 404 la cuenta no existe, 500 error del servidor.

### Manejo de errores

- `remoteErrorMessage()` (`lib/data/remote_errors.dart`) convierte cualquier
  error en un mensaje para el usuario: sin red o tiempo agotado → "Sin
  conexión…"; errores de Edge Function → su campo `error` y `detalles`;
  errores de PostgREST o Auth → su mensaje.
- `AuthFailure`: error de inicio de sesión o de cuentas, se muestra tal cual.
- `RemoteRejected`: el servidor rechazó una escritura (permisos, dato
  repetido, archivo de más de 50 MB). La fila sigue pendiente y lo demás sí sube.
  Los errores de red, en cambio, cortan la sincronización.
- `HistoryError`: no se pudo leer el historial; la pantalla lo avisa.

## 6. Sincronización, en resumen

- **Orden de subida:** catálogos y plantillas → clientes → sitios → proyectos
  (y sus técnicos) → visitas → revisiones → correcciones → hallazgos →
  respuestas → documentos → evidencias. De documentos y evidencias sube primero
  el archivo y después la fila con `subido_en`.
- **Conflictos:** se comparan teléfono, `base` y servidor por columna. Sólo se
  sube lo que cambió el teléfono; si los dos cambiaron la misma columna, gana el
  cambio más reciente.
- **Bajada:** por tabla desde el último `actualizado_en` visto (con 2 minutos de
  margen). Proyectos y visitas se comparan además con los ids visibles, para
  traer lo recién asignado y quitar lo que ya no se puede ver.
- **Visita terminada:** queda en `pendiente_sync`; cuando ya subió todo, pasa
  sola a `en_revision`.
- Detalle del código: `lib/data/sync/push.dart` y `lib/data/sync/sync_service.dart`.
