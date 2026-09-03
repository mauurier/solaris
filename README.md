# Solaris · Prototipo de plataforma de levantamientos técnicos

Prototipo de interfaz (UI/UX) en Flutter para la aplicación móvil levantamientos técnicos
de instalaciones fotovoltaicas con evidencia fotográfica, trazabilidad y
generación de reportes.

> **Sólo frontend.** No hay backend, base de datos ni acceso real a cámara/GPS:
> todos los datos provienen de `lib/data/mock_data.dart` y las acciones que
> tocarían el servidor muestran confirmaciones simuladas.

## Cómo ejecutarlo

```bash
flutter pub get
flutter run
```
**Para ejecutar SOLO en android con kotlin hay que copiar o abrir la carpeta /android en android studio**

## Estructura

```
lib/
├── main.dart                  App, tema oscuro y transiciones de página
├── core/
│   ├── theme/                 Tokens de color, tipografía y ThemeData
│   └── widgets/               Sistema de componentes (tarjetas, anillos de
│                              progreso, gráficas, panel de firma, marca)
├── data/                      Modelos y datos simulados en memoria
└── features/
    ├── auth/                  Acceso y selección de rol
    ├── shell/                 Navegación principal y captura rápida
    ├── dashboard/             Panel de inicio por rol
    ├── projects/              Cartera, detalle y alta de proyectos
    ├── visits/                Levantamiento, observaciones y firma
    ├── forms/                 Formulario dinámico con campos condicionales
    ├── photos/                Subsecciones, cámara simulada y metadatos
    ├── videos/  documents/    Evidencia complementaria
    ├── measurements/          Mediciones eléctricas
    ├── equipment/ findings/   Equipos y hallazgos
    ├── validation/            Pendientes obligatorios y cierre de visita
    ├── report/  export/       Reporte PDF, estructura de carpetas y ZIP
    ├── sync/                  Cola de sincronización y modo offline
    ├── stats/  history/       Estadísticas y trazabilidad
    ├── review/                Revisión, correcciones y aprobación
    ├── admin/                 Usuarios, clientes y plantillas
    └── profile/               Perfil y preferencias de captura
```

## Roles

La pantalla de acceso (y el perfil) permiten cambiar entre **Administrador**,
**Supervisor**, **Técnico** y **Revisor**. El panel de inicio, las acciones
disponibles y la validación cambian según el rol.

