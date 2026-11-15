# Manual de usuario · Solaris

Solaris sirve para hacer levantamientos en campo de instalaciones
fotovoltaicas: llenar el formulario de la visita, tomar fotos y videos,
registrar problemas encontrados y entregar todo ordenado.

La app **funciona sin señal**. Todo lo que capturas se guarda en el teléfono
y se envía solo cuando hay internet.

## 1. Entrar a la app

1. Abre **Solaris**.
2. Escribe el correo y la contraseña que te dio el responsable de las cuentas
   (superadmin).
3. Deja marcada **"Mantener sesión para trabajo en campo"** si vas a trabajar
   sin señal: así podrás abrir la app aunque no tengas internet.
4. Toca **Iniciar sesión**.

La primera vez necesitas internet. Si olvidaste tu contraseña, pide al
superadmin que te asigne una nueva. Si tu cuenta venció o está desactivada, la
app te lo dirá al entrar.

## 2. La pantalla principal

Abajo hay cinco botones:

| Botón | Qué hay |
|---|---|
| **Inicio** | Resumen de tu trabajo |
| **Proyectos** | Proyectos agrupados por cliente |
| **Botón central** | Técnico: **+** para tomar fotos de lo que falta. Supervisor: **✓** con lo que tienes por aprobar. Administrador: **+** para crear proyectos o visitas |
| **Visitas** | Visitas ordenadas por estado: en curso, por iniciar, finalizadas y aprobadas |
| **Perfil** | Tu cuenta, ajustes y cerrar sesión |

Arriba, en Inicio, un indicador muestra si estás conectado. Si lo tocas, pausas
o reanudas el envío de información.

## 3. Técnico: hacer un levantamiento

### Encontrar tu visita
- En **Inicio** aparece tu visita reciente con el botón **Abrir** o **Continuar**.
- También puedes entrar por **Proyectos** o **Visitas**. Sólo ves lo que te asignaron.

### Iniciar la visita
1. Abre la visita y toca **Iniciar visita**.
2. La app guarda la hora y tu ubicación. Si no hay GPS, guarda la hora de todos modos.

### Llenar el levantamiento
1. Entra a cada **sección** de la lista.
2. Responde las preguntas. **Se guarda solo**, aunque cierres la app.
3. Algunas preguntas aparecen según lo que contestes (por ejemplo, si existe un sistema fotovoltaico).
4. En bloques como **Transformador** o **Tablero**, toca **agregar** para registrar otro (Transformador 2, Tablero 01…).
5. Al terminar una sección, toca **Siguiente** para pasar a la que sigue.

### Fotos, videos, documentos y firma
- Toca la cámara en la pregunta. La foto sale con **fecha, hora, ubicación y enlace de Google Maps** impresos.
- Revisa la foto y elige **aceptar** o **repetir**. Puedes **agregar texto** encima de la foto.
- También puedes subir fotos, videos o documentos que ya tengas en el teléfono. Se marcan con la hora y ubicación del momento en que los subes.
- Si una foto dice **SIN GPS**, el teléfono no tenía ubicación en ese momento.
- Para ver una foto ya tomada, tócala. Desde ahí puedes poner un comentario, reemplazarla o borrarla mientras la visita siga abierta. Tocar la foto abre en Maps el lugar donde se tomó.

### Tomar lo que falta, en cualquier orden
Toca el **+** del centro de la barra. Aparecen las fotos y videos que faltan
en tu visita; elige uno y se abre la cámara. Si tienes varias visitas en curso,
primero elige en cuál.

### Registrar un problema (hallazgo)
1. En la visita, toca **Registrar** en la parte de hallazgos.
2. Elige la categoría y la severidad, describe el problema, la ubicación y la recomendación.
3. Agrega fotos del problema.

### Terminar la visita
1. Toca **Validar y finalizar**.
2. La app te muestra lo que falta:
   - **Obligatorio**: tienes que completarlo antes de cerrar.
   - **Opcional**: puedes cerrar sin él.
   - **Justificado**: el supervisor permitió cerrar sin él.
3. Toca **Finalizar**. Puedes escribir notas de cierre. Se guarda la hora y tu ubicación.

Después, la visita se envía sola cuando haya internet y pasa a revisión del supervisor.

### Si te piden correcciones
La visita vuelve a abrirse con la lista de lo que debes corregir. Corrige cada
punto, tócalo para marcarlo como atendido y vuelve a finalizar. No podrás cerrar hasta
atenderlos todos.

## 4. Supervisor

- **Crear un proyecto:** en Proyectos, toca **Nuevo proyecto** y sigue los 4 pasos: datos, ubicación, equipo (técnicos) y plantilla con documentos. El primer técnico que elijas recibe la primera visita.
- **Cambiar técnicos o crear otra visita:** abre el proyecto y usa los botones de asignación o **Nueva visita** (eliges el motivo, la plantilla, el técnico y la fecha).
- **Aprobar:** toca la **✓** del centro. Verás las visitas finalizadas, la que más espera primero. Abre una y elige **Aprobar** o **Pedir correcciones** (escribe qué debe corregir el técnico).
- **Justificar un pendiente:** en la revisión de pendientes de una visita, puedes permitir que se cierre sin una respuesta obligatoria escribiendo el motivo.
- **Hallazgos:** sólo quien revisa puede cerrarlos.
- **Buscar visitas:** en Visitas puedes buscar y filtrar por técnico, fecha y estado.

## 5. Administrador

Además de lo del supervisor:

- **Botón + del centro:** crea un proyecto nuevo o una visita de un proyecto existente.
- **Clientes:** agrega y edita clientes.
- **Catálogos:** edita los tipos de proyecto y los motivos de visita (desde los accesos de administración en Inicio).
- **Plantillas:** crea, copia, activa o desactiva plantillas y edita sus secciones y preguntas. Cada vez que guardas se crea una versión nueva; las visitas ya iniciadas conservan la suya.
- **Usuarios:** ves todas las cuentas. Sólo el **superadmin** crea cuentas, cambia rol, vigencia o estado, y asigna contraseñas nuevas. Al crear una cuenta, la contraseña se muestra **una sola vez**: compártela con la persona.
- **Eliminar un proyecto:** desde el detalle del proyecto.

## 6. Reporte PDF y ZIP

- **Reporte PDF:** en la visita, toca el ícono de PDF. Elige qué incluir (resumen, hallazgos, fotos, sólo lo respondido, qué secciones) y genera. Funciona sin internet. Puedes verlo y compartirlo.
- **ZIP:** en el proyecto o en la visita, toca **Exportar ZIP**. Se arma con las carpetas y los nombres de archivo de la empresa y se comparte con las apps del teléfono.

## 7. Envío de información

- La app envía y recibe información sola: al recuperar la señal, poco después de cada cambio y cada 10 minutos.
- Con **"Sincronizar sólo con Wi-Fi"** (en Perfil), las fotos, videos y documentos esperan a que haya Wi-Fi; las respuestas se envían con cualquier conexión.
- En **Perfil › Sincronización** ves lo que falta enviar y si algo no se pudo enviar. Ahí también puedes pausar el envío.

## 8. Cerrar sesión

En **Perfil**, toca **Cerrar sesión**. Antes de salir, la app envía lo que
tengas pendiente. **No te dejará salir** si queda información sin enviar que
todavía se puede enviar (por ejemplo, si no hay señal o los archivos esperan
Wi-Fi). Conéctate y vuelve a intentarlo.

## Preguntas frecuentes

| Problema | Qué hacer |
|---|---|
| Olvidé mi contraseña | Pide al superadmin que te asigne una nueva |
| "Tu cuenta venció" o "está desactivada" | Pide al superadmin que la renueve o la active |
| No me deja cerrar la visita | Revisa los pendientes obligatorios y las correcciones sin atender |
| No me deja cerrar sesión | Falta enviar información: conéctate a internet (y a Wi-Fi si está activada esa opción) |
| La foto dice "SIN GPS" | Activa la ubicación del teléfono y espera a que tenga señal antes de tomarla |
| No veo un proyecto | Sólo ves los proyectos que te asignaron; pide al supervisor que te agregue |
