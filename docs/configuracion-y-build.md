# Configuración y build

## Archivos de configuración

| Archivo | Para qué | ¿Se sube al repo? |
|---|---|---|
| `pubspec.yaml` | Nombre del paquete (`proyecto_app`), versión de la app (`1.0.0+1`), dependencias y assets (`assets/fonts/`) | Sí |
| `lib/core/config/supabase_config.dart` | URL y llave *publishable* de Supabase, con valores por defecto | Sí |
| `android/local.properties` | Ruta del SDK de Flutter (`flutter.sdk`) y de Android. Lo genera Flutter | No (lo ignora `android/.gitignore`) |
| `android/gradle.properties` | Memoria de Gradle (`-Xmx8G`), AndroidX y banderas de la plantilla de Flutter | Sí |
| `android/settings.gradle.kts` | Versiones de AGP (9.0.1) y Kotlin (2.3.20) | Sí |
| `android/app/build.gradle.kts` | `namespace` y `applicationId`, Java 17, firma de release, dependencias de Media3 | Sí |
| `supabase/config.toml` | Id del proyecto de Supabase y `verify_jwt = false` para las dos Edge Functions | Sí |
| `analysis_options.yaml` | Reglas de análisis (`flutter_lints`) | Sí |

**No existen** en el repositorio: `.env`, `google-services.json`,
`local.properties.example`, `key.properties` ni keystores. El `.gitignore`
ya excluye `*.env`, `.env*`, `android/key.properties`, `*.jks`, `*.keystore`,
`*.p12`, `*.pem` y `lib/**/secrets.dart`.

### Variables al compilar (`--dart-define`)

| Variable | Uso | Valor por defecto |
|---|---|---|
| `SUPABASE_URL` | URL del proyecto de Supabase | La del proyecto Solaris, en `supabase_config.dart` |
| `SUPABASE_PUBLISHABLE_KEY` | Llave *publishable* (pública) de Supabase | La del proyecto Solaris, en `supabase_config.dart` |

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<llave-publishable>
```

La llave *publishable* puede ir en la app: lo que cada usuario ve lo limitan las
políticas RLS. **La llave secreta nunca va en la app**; sólo la usan las Edge
Functions en el servidor.

### Variables de las Edge Functions

`crear-usuario` y `cambiar-contrasena` leen del entorno de Supabase:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEYS` o, si no existe, `SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEYS` o, si no existe, `SUPABASE_SERVICE_ROLE_KEY`

No hay que configurarlas: Supabase las pone automáticamente en todas las Edge
Functions del proyecto. `SUPABASE_PUBLISHABLE_KEYS` y `SUPABASE_SECRET_KEYS`
son objetos JSON y la función toma la llave `"default"`; las llaves anteriores
(`SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`) quedan como respaldo.

## Versiones de Android

| Ajuste | Valor | De dónde sale |
|---|---|---|
| `minSdk` | 24 (Android 7.0) | `flutter.minSdkVersion` |
| `targetSdk` | 36 | `flutter.targetSdkVersion` |
| `compileSdk` | 36 | `flutter.compileSdkVersion` |
| NDK | 28.2.13676358 | `flutter.ndkVersion` |
| Java / Kotlin JVM target | 17 | `android/app/build.gradle.kts` |
| `versionName` / `versionCode` | `1.0.0` / `1` | `version: 1.0.0+1` de `pubspec.yaml` |

Los valores `flutter.*` son los que trae Flutter 3.47.5 (con el que se compiló).
Con `--split-per-abi`, Flutter suma un desplazamiento por arquitectura al
`versionCode`.

Para publicar una actualización hay que subir `version` en `pubspec.yaml`
(por ejemplo `1.0.1+2`); si no, Android no la instala encima de la anterior.

## Build variants

No hay *product flavors*. Existen los tres tipos de compilación estándar de
Flutter: `debug`, `profile` y `release` (hay `AndroidManifest.xml` propios en
`android/app/src/debug/` y `android/app/src/profile/`, que sólo agregan el
permiso `INTERNET` para las herramientas de desarrollo).

## Generar el APK o AAB de release

Desde la raíz del proyecto:

```bash
flutter pub get

# APK único (sirve en cualquier teléfono)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Un APK por arquitectura (más ligero)
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (teléfonos actuales)
#   app-armeabi-v7a-release.apk, app-x86_64-release.apk

# App Bundle para Google Play
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Si Gradle se cierra sin un error claro, suele ser falta de memoria: cierra el
emulador y Android Studio mientras compila, o baja `-Xmx` en
`android/gradle.properties`.

## Firma de release

**Hoy el release se firma con la llave de depuración**
(`signingConfig = signingConfigs.getByName("debug")` en
`android/app/build.gradle.kts`). Sirve para pruebas, pero no para distribuir:
una app firmada con otra llave no se puede instalar encima, y al desinstalar
se pierde lo que el técnico no haya sincronizado.

Pasos para firmar con una llave propia (ningún dato real va en el repositorio):

1. Crear el keystore (una sola vez) y guardarlo **fuera del repositorio** y con
   respaldo:

   ```bash
   keytool -genkey -v -keystore ~/solaris-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias <alias>
   ```

2. Crear `android/key.properties` (ya está en `.gitignore`):

   ```properties
   storePassword=<contraseña-del-keystore>
   keyPassword=<contraseña-de-la-llave>
   keyAlias=<alias>
   storeFile=<ruta-absoluta-al-keystore>.jks
   ```

3. En `android/app/build.gradle.kts`, leer ese archivo y declarar un
   `signingConfigs.create("release")` con esos valores, y usarlo en
   `buildTypes.release` en lugar de `"debug"`.
4. Compilar con `flutter build apk --release` o `flutter build appbundle --release`.

⚠️ Pendiente de confirmar: quién guarda el keystore y sus contraseñas, y si la
app se distribuirá por Google Play o instalando el APK directamente.

⚠️ Pendiente de confirmar: el `applicationId` definitivo. Hoy es
`com.example.proyecto_app` (con un `TODO` de la plantilla de Flutter); Google
Play no acepta ids que empiecen con `com.example`, y cambiarlo después hace que
Android lo trate como otra app.

## Permisos

### Declarados en `android/app/src/main/AndroidManifest.xml`

| Permiso | Por qué |
|---|---|
| `INTERNET` | Iniciar sesión y sincronizar con Supabase |
| `CAMERA` | Tomar fotos y grabar video de evidencia (`CameraScreen`, paquete `camera`) |
| `RECORD_AUDIO` | Grabar el audio de los videos de evidencia |
| `ACCESS_FINE_LOCATION` | GPS preciso al iniciar y cerrar la visita, en cada foto y video, en hallazgos y en el alta de proyecto (`LocationService`, paquete `geolocator`) |
| `ACCESS_COARSE_LOCATION` | Ubicación aproximada; Android la pide junto con la precisa |

### Agregados por librerías al combinar manifiestos

Salen del reporte `build/app/outputs/logs/manifest-merger-release-report.txt`:

| Permiso | Lo agrega | Por qué |
|---|---|---|
| `ACCESS_NETWORK_STATE` | `androidx.media3` (`media3-exoplayer`, `media3-common`) | Estado de la red |
| `WAKE_LOCK` | `androidx.media3:media3-exoplayer` | Mantener el reproductor de video activo |
| `READ_EXTERNAL_STORAGE` | Implícito porque el plugin de cámara (`camerax`) pide `WRITE_EXTERNAL_STORAGE` | Acceso a almacenamiento en versiones viejas de Android |
| `com.example.proyecto_app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | `androidx.core` | Permiso interno de AndroidX para receptores no exportados |

### `<queries>` del Manifest

- `android.intent.action.PROCESS_TEXT` (`text/plain`): lo usa el motor de
  Flutter para las acciones de texto del sistema.
- `android.intent.action.VIEW` con esquema `https`: abrir en Google Maps las
  coordenadas de una foto (`url_launcher`, `lib/core/services/maps.dart`).

## Supabase

### Migraciones y funciones

El esquema está en `supabase/migrations/` y las funciones en
`supabase/functions/`. Las migraciones se aplican **en orden** (el nombre
empieza con la fecha):

1. `20261029120000_estructura_inicial.sql`
2. `20261030055142_ajustes_advisors.sql`
3. `20261031003249_proyecto_tecnico_actualizado_en.sql`
4. `20261031022418_plantilla_levantamiento_electrico.sql`
5. `20261031033904_tecnico_estado_proyecto.sql`
6. `20261031044831_evidencias_cualquier_tipo.sql`
7. `20261031080427_historial_correcciones.sql`

Un cambio nuevo en la base va siempre en un archivo nuevo en
`supabase/migrations/`; las migraciones ya aplicadas no se editan.

#### Forma recomendada: CLI de Supabase

La carpeta `supabase/` tiene la estructura de la CLI (`supabase/config.toml`).
La CLI se puede instalar o usar con `npx supabase …` (requiere Node.js).

```bash
# Una sola vez por equipo
supabase login                                # abre el navegador para autorizar
supabase link --project-ref <project-ref>     # pide la contraseña de la base

# Aplicar migraciones
supabase migration list                       # compara las del repo con las del servidor
supabase db push                              # aplica las que falten

# Publicar las Edge Functions
supabase functions deploy crear-usuario
supabase functions deploy cambiar-contrasena

# Crear una migración nueva
supabase migration new <nombre_del_cambio>    # crea supabase/migrations/<fecha>_<nombre>.sql
```

`functions deploy` lee `supabase/config.toml`, así que las dos funciones
quedan con `verify_jwt = false` sin pasos extra.

Si `supabase migration list` muestra como pendientes migraciones que ya
están aplicadas en el servidor (por ejemplo, porque se aplicaron desde el
panel web), hay que marcarlas como aplicadas antes de `db push`, o la CLI
intentará correrlas otra vez:

```bash
supabase migration repair --status applied <fecha_de_la_migracion>
```

#### Alternativa: panel web de Supabase

1. **Migraciones:** en *SQL Editor*, pegar y ejecutar el contenido de cada
   archivo de `supabase/migrations/`, uno por uno y en el orden de la lista.
2. **Edge Functions:** en *Edge Functions*, crear o editar la función con el
   nombre exacto (`crear-usuario` o `cambiar-contrasena`) y pegar el contenido
   de su `index.ts`.
3. **Desactivar la verificación de JWT** en la configuración de cada una de las
   dos funciones. Si se deja activada, rechazan las peticiones de la app; las
   funciones revisan la sesión por su cuenta.

Lo que se aplica desde el panel no queda registrado en el historial de
migraciones de la CLI. Si después se usa la CLI, primero hay que marcarlas
con `supabase migration repair` (ver arriba).

### Primer superadmin

Según el comentario al final de
`supabase/migrations/20261029120000_estructura_inicial.sql`, se hace una sola
vez, a mano:

1. En el panel de Supabase: Authentication → Users → Add user (correo y contraseña).
2. En el editor SQL:

   ```sql
   update public.perfil
   set rol = 'superadmin', activo = true, fin_vigencia = null
   where email = '<correo-del-superadmin>';
   ```

Las demás cuentas las crea el superadmin desde la app (pantalla Usuarios).

## Carpetas generadas y respaldo

### Carpetas que se generan solas

Estas carpetas no están en el repositorio (las excluye `.gitignore`) y se
vuelven a crear al trabajar con el proyecto. Se pueden borrar o dejar fuera de
un respaldo sin perder nada:

| Carpeta | Qué es | Cómo se regenera |
|---|---|---|
| `build/` | Compilaciones y APKs | Al compilar (`flutter run`, `flutter build apk`) |
| `.dart_tool/` | Caché de Flutter y de los paquetes | `flutter pub get` |
| `linux/flutter/ephemeral/`, `windows/flutter/ephemeral/`, `ios/Flutter/ephemeral/`, `macos/Flutter/ephemeral/` | Archivos generados por Flutter para cada plataforma | `flutter pub get` o al compilar |
| `android/.gradle/` | Caché de Gradle | Al compilar para Android |
| `android/local.properties` | Rutas locales al SDK de Flutter y de Android | Lo escribe Flutter al compilar |
| `.idea/` | Preferencias de Android Studio (pestañas, dispositivo elegido) | Android Studio la crea al abrir el proyecto, con su configuración por defecto |

Lo que **no** está en la carpeta del proyecto y hay que instalar o pedir
aparte: el Flutter SDK, el Android SDK, Android Studio, el JDK y el acceso al
proyecto de Supabase (ver [README](../README.md#requisitos)).

### Hacer un respaldo

Desde la carpeta que **contiene** al proyecto (en este ejemplo se llama
`solaris`):

```bash
tar --exclude=solaris/build --exclude=solaris/.dart_tool \
    --exclude='solaris/*/flutter/ephemeral' --exclude='solaris/*/Flutter/ephemeral' \
    --exclude=solaris/android/.gradle --exclude=solaris/.idea \
    -czf ~/solaris.tar.gz solaris
```

El archivo resultante pesa unos pocos MB e incluye la carpeta `.git` con todo
el historial, los commits que aún no se suben a GitHub y los archivos que no
están en Git. Las carpetas `ephemeral` tienen accesos directos (symlinks) que
suelen dar error al copiarlos a un NAS o a una unidad de red; por eso se
excluyen.

### Restaurar un respaldo

```bash
tar -xzf solaris.tar.gz          # crea la carpeta solaris/
cd solaris
flutter pub get
flutter run                      # o flutter build apk --release
```

Si al compilar para Android aparece *permission denied*, el almacenamiento
quitó el permiso de ejecución a `android/gradlew`:

```bash
chmod +x android/gradlew
```

No conviene trabajar el proyecto directamente desde un NAS o una carpeta de
red: Flutter y Gradle son muy lentos ahí y pueden fallar por bloqueos de
archivos. Copia la carpeta a la computadora para trabajar.
