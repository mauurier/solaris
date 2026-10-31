# Solaris · Levantamientos técnicos fotovoltaicos

Aplicación móvil en Flutter para realizar levantamientos eléctricos de
instalaciones fotovoltaicas con evidencia fotográfica, validación de pendientes
y exportación ordenada de la información.

Todo se guarda primero en el teléfono (SQLite + archivos en la carpeta privada
de la app), así que se trabaja sin señal. Con conexión se sincroniza con
**Solaris**, el proyecto de Supabase (base de datos, Storage y cuentas).

## Qué funciona

| Módulo | Detalle |
|---|---|
| **Proyectos** | Alta en 4 pasos (datos, ubicación con GPS, equipo, plantilla y documentos iniciales). Al crear se genera la visita del técnico. Asignación de supervisor y técnicos, visitas adicionales y borrado (admin). |
| **Documentos** | Recibo CFE, unifilar, ingeniería existente, planos, CAD y otros desde Archivos/iCloud/Drive. Si la plantilla los pide, cuentan como respondidos. |
| **Levantamiento** | Inicio y cierre con hora y GPS. Formulario generado desde la plantilla: condicionales, bloques repetibles (Transformador 1, 2…; Tablero Principal, Tablero 01…), guardado automático, avance por sección y captura fuera de orden. |
| **Cámara** | Cada foto lleva impresa la **fecha, hora y coordenadas** (o `SIN GPS`). Revisar, repetir, reemplazar, eliminar y comentar. Video narrado e importación de fotos/videos de dron o termografías. |
| **Validación** | Pendientes obligatorios (bloquean el cierre), opcionales y justificados por el supervisor. Firma del técnico. |
| **Plantillas** | Editor para el administrador: secciones, bloques, preguntas, tipo, obligatoriedad, condiciones, carpeta y prefijo de archivo. Cada guardado es una versión nueva; las visitas en curso conservan la suya. |
| **Exportar ZIP** | Estructura `01`–`06` de *Instrucciones de llenado de carpetas*, nombres automáticos (`TABLERO_PRINCIPAL_ITM_001.jpg`, `RECIBO_CFE_SITIO.pdf`) y CSV de respuestas, mediciones y metadatos de cada evidencia. Se comparte con el menú nativo. |
| **Cuentas** | Inicio de sesión con Supabase Auth. El superadmin crea las cuentas (Edge Function `crear-usuario`) y cambia rol, vigencia y si están activas. |
| **Revisión** | El supervisor aprueba la visita terminada o pide correcciones concretas; el técnico las marca como atendidas y no puede cerrar hasta atenderlas todas. Cada revisión queda registrada con sus observaciones. |
| **Historial** | Quién cambió qué y cuándo, por proyecto o de todo, leído del registro de Solaris (necesita conexión). |
| **Sincronización** | Sube sólo lo que cambió en el teléfono y baja lo que cambió en el servidor; si dos personas cambian lo mismo gana el cambio más reciente. Fotos, videos y documentos van a Storage (opción "Sólo con Wi-Fi"). Es automática al volver la conexión, tras cada cambio y cada 10 minutos; Perfil › Sincronización muestra lo pendiente y los errores. |

Reporte PDF y hallazgos siguen como **vista previa con datos de ejemplo**
(Perfil › Vista previa · próximas fases) mientras se hacen con datos reales.

## Cómo ejecutarlo

```bash
flutter pub get
flutter run
```

Requiere iOS 14 o superior y una cuenta de Solaris (la crea el superadmin). La
cámara y el GPS sólo funcionan en un teléfono real. **Para ejecutar SOLO en android con kotlin hay que copiar o abrir la carpeta /android en android studio.**

## Pruebas

```bash
flutter analyze
flutter test
```

Las pruebas usan un almacén en memoria y una carpeta temporal; la de SQLite
usa `sqflite_common_ffi` para abrir una base real en el escritorio.

## Estructura

```
lib/
├── main.dart                   Abre la base local y arranca la app
├── core/
│   ├── services/               GPS, marca de agua, exportación ZIP, formatos
│   ├── theme/                  Tokens de color, tipografía y ThemeData
│   └── widgets/                Sistema de componentes
├── data/
│   ├── survey/                 Plantilla (modelo y plantilla eléctrica FV),
│   │                           entidades y motor de avance/pendientes
│   ├── storage/                SQLite, persistencia en memoria y archivos
│   ├── auth/                   Sesión, perfil y lista de usuarios
│   ├── sync/                   Subida, bajada y cola de sincronización
│   ├── survey_store.dart       Fuente única de datos (ChangeNotifier)
│   └── mock_data.dart          Sesión y ajustes; datos de ejemplo de la vista previa
└── features/
    ├── projects/               Lista, alta, detalle, documentos y asignación
    ├── visits/                 Visita, secciones, preguntas, validación
    ├── capture/                Cámara, visor de evidencias, video
    ├── export/                 Exportación ZIP (y vista previa anterior)
    ├── admin/                  Plantillas y su editor; usuarios, clientes y catálogos
    ├── sync/                   Pantalla de sincronización
    ├── dashboard/  shell/      Inicio, navegación y captura rápida
    └── …                       Módulos en vista previa
```

## Roles

El rol viene de la cuenta: **Superadmin** (administra cuentas y usa la vista
del administrador), **Administrador**, **Supervisor** y **Técnico**. El técnico
sólo ve sus proyectos;
supervisor y admin crean proyectos y justifican pendientes; el supervisor
también revisa, solicita correcciones y aprueba o rechaza levantamientos
(absorbe el antiguo rol de revisor); el admin edita plantillas.
