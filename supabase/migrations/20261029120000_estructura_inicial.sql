-- =====================================================================
-- Solaris · estructura inicial de la base de datos (Supabase / Postgres)
--
-- Basada en diagrama_er.txt (commit f36a174), con estos ajustes:
--   * plantilla usa version_mayor + version_menor, como la app (v1.2).
--   * perfil guarda una copia del email (la app lo muestra en Usuarios y
--     desde el cliente no se puede leer auth.users).
--   * un proyecto puede existir sin visitas.
--   * respuesta es única por (visita, grupo, repetición, pregunta) para que
--     la sincronización pueda hacer upsert.
--   * historial no tiene llaves foráneas a proyecto ni visita: se llena con
--     triggers AFTER y, al borrar un registro, este ya no existe.
--
-- Convenciones:
--   * Los ids son uuid y normalmente los genera el teléfono.
--   * actualizado_en lo pone el servidor; el teléfono pide "lo que cambió
--     desde X" con esa columna.
--   * eliminado_en es borrado lógico. Las políticas no esconden los
--     registros eliminados: el teléfono los necesita para enterarse.
--   * Desde la app no hay borrado físico (no hay políticas DELETE en tablas).
-- =====================================================================


-- =====================================================================
-- 1. Enums
-- =====================================================================

create type public.rol_usuario as enum ('superadmin', 'admin', 'supervisor', 'tecnico');

-- Lo usan proyecto y visita (en la app los dos usan ProjectStatus).
create type public.estado_trabajo as enum (
  'borrador', 'programado', 'asignado', 'en_campo', 'en_captura',
  'pendiente_sync', 'en_revision', 'con_correcciones', 'aprobado', 'cerrado'
);

create type public.tipo_evidencia as enum ('foto', 'video', 'documento', 'firma');

create type public.categoria_documento as enum (
  'recibo_cfe', 'unifilar', 'ingenieria', 'planos', 'cad', 'otro'
);

create type public.categoria_hallazgo as enum (
  'electrico', 'estructural', 'cubierta', 'seguridad',
  'termografico', 'documental', 'civil', 'otro'
);

create type public.severidad as enum ('baja', 'media', 'alta', 'critica');

create type public.estado_hallazgo as enum ('abierto', 'en_revision', 'corregido', 'cerrado');

create type public.decision_revision as enum ('aprobada', 'con_correcciones');

create type public.estado_correccion as enum ('pendiente', 'atendida');

create type public.estado_reporte as enum ('borrador', 'final');

create type public.accion_historial as enum ('crear', 'editar', 'eliminar');


-- =====================================================================
-- 2. Tablas
-- =====================================================================

-- ----- Personas y lugares --------------------------------------------

create table public.perfil (
  id              uuid primary key references auth.users (id) on delete cascade,
  creado_por      uuid references public.perfil (id),
  email           text,
  nombre          text not null,
  rol             public.rol_usuario not null default 'tecnico',
  activo          boolean not null default true,
  inicio_vigencia date not null default current_date,
  fin_vigencia    date,  -- nulo = no vence
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  eliminado_en    timestamptz,
  constraint perfil_vigencia_valida
    check (fin_vigencia is null or fin_vigencia >= inicio_vigencia),
  constraint perfil_superadmin_no_vence
    check (rol <> 'superadmin' or fin_vigencia is null)
);

create table public.cliente (
  id             uuid primary key default gen_random_uuid(),
  razon_social   text not null,
  rfc            text,
  contacto       text,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create unique index cliente_rfc_unico
  on public.cliente (rfc) where rfc is not null and eliminado_en is null;

create table public.sitio (
  id             uuid primary key default gen_random_uuid(),
  id_cliente     uuid not null references public.cliente (id),
  nombre         text not null,
  direccion      text,
  latitud        numeric(9, 6),
  longitud       numeric(9, 6),
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create index sitio_id_cliente_idx on public.sitio (id_cliente);

-- ----- Catálogos -----------------------------------------------------

create table public.tipo_proyecto (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  descripcion    text,
  orden          int not null default 0,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create unique index tipo_proyecto_nombre_unico
  on public.tipo_proyecto (nombre) where eliminado_en is null;

create table public.motivo_visita (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  orden          int not null default 0,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create unique index motivo_visita_nombre_unico
  on public.motivo_visita (nombre) where eliminado_en is null;

-- ----- Plantilla de levantamiento ------------------------------------

create table public.plantilla (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  tipo           text,
  version_mayor  int not null default 1,
  version_menor  int not null default 0,  -- sube en 1 con cada edición
  activa         boolean not null default true,
  definicion     jsonb not null,          -- secciones, grupos y preguntas
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz,
  constraint plantilla_version_valida check (version_mayor >= 1 and version_menor >= 0)
);

-- ----- Proyecto y visitas --------------------------------------------

create table public.proyecto (
  id               uuid primary key default gen_random_uuid(),
  id_sitio         uuid not null references public.sitio (id),
  id_tipo_proyecto uuid references public.tipo_proyecto (id),
  id_supervisor    uuid references public.perfil (id),
  id_plantilla     uuid references public.plantilla (id),  -- plantilla por defecto
  codigo           text not null,
  nombre           text not null,
  descripcion      text,
  fecha_programada timestamptz,
  estado           public.estado_trabajo not null default 'asignado',
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  eliminado_en     timestamptz
);

create unique index proyecto_codigo_unico
  on public.proyecto (codigo) where eliminado_en is null;
create index proyecto_id_sitio_idx on public.proyecto (id_sitio);
create index proyecto_id_supervisor_idx on public.proyecto (id_supervisor);
create index proyecto_actualizado_en_idx on public.proyecto (actualizado_en);

create table public.proyecto_tecnico (
  id_proyecto  uuid not null references public.proyecto (id) on delete cascade,
  id_tecnico   uuid not null references public.perfil (id),
  creado_en    timestamptz not null default now(),
  eliminado_en timestamptz,
  primary key (id_proyecto, id_tecnico)
);

create index proyecto_tecnico_id_tecnico_idx on public.proyecto_tecnico (id_tecnico);

create table public.visita (
  id                    uuid primary key default gen_random_uuid(),
  id_proyecto           uuid not null references public.proyecto (id) on delete cascade,
  id_tecnico            uuid references public.perfil (id),
  id_supervisor         uuid references public.perfil (id),
  id_motivo             uuid references public.motivo_visita (id),  -- nulo en la primera visita
  id_plantilla          uuid references public.plantilla (id),
  numero                int not null,
  fecha_programada      timestamptz,
  fecha_inicio          timestamptz,
  fecha_fin             timestamptz,
  lat_inicio            numeric(9, 6),
  lng_inicio            numeric(9, 6),
  lat_fin               numeric(9, 6),
  lng_fin               numeric(9, 6),
  estado                public.estado_trabajo not null default 'asignado',
  notas                 text,
  fecha_ultima_apertura timestamptz,
  plantilla_usada       jsonb,                         -- copia de la plantilla al capturar
  repeticiones          jsonb not null default '{}',   -- cuántas copias tiene cada grupo
  justificaciones       jsonb not null default '{}',   -- pendientes justificados
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now(),
  eliminado_en          timestamptz,
  constraint visita_numero_por_proyecto unique (id_proyecto, numero),
  constraint visita_numero_valido check (numero > 0),
  constraint visita_fechas_validas check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio)
);

create index visita_id_tecnico_idx on public.visita (id_tecnico);
create index visita_id_supervisor_idx on public.visita (id_supervisor);
create index visita_actualizado_en_idx on public.visita (actualizado_en);

-- ----- Captura en campo ----------------------------------------------

create table public.respuesta (
  id                uuid primary key default gen_random_uuid(),
  id_visita         uuid not null references public.visita (id) on delete cascade,
  clave_grupo       text not null,
  numero_repeticion int not null default 0,  -- la app cuenta desde 0 (g_tablero#0/...)
  clave_pregunta    text not null,
  valor             text,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  eliminado_en      timestamptz,
  constraint respuesta_unica unique (id_visita, clave_grupo, numero_repeticion, clave_pregunta),
  constraint respuesta_repeticion_valida check (numero_repeticion >= 0)
);

create index respuesta_actualizado_en_idx on public.respuesta (actualizado_en);

create table public.hallazgo (
  id             uuid primary key default gen_random_uuid(),
  id_visita      uuid not null references public.visita (id) on delete cascade,
  id_usuario     uuid references public.perfil (id),
  codigo         text not null,  -- HZ-001
  categoria      public.categoria_hallazgo not null,
  descripcion    text not null,
  severidad      public.severidad not null,
  ubicacion      text,
  recomendacion  text,
  estado         public.estado_hallazgo not null default 'abierto',
  latitud        numeric(9, 6),
  longitud       numeric(9, 6),
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz,
  constraint hallazgo_codigo_por_visita unique (id_visita, codigo)
);

create table public.evidencia (
  id                uuid primary key default gen_random_uuid(),
  id_visita         uuid not null references public.visita (id) on delete cascade,
  id_usuario        uuid references public.perfil (id),
  id_hallazgo       uuid references public.hallazgo (id) on delete set null,
  clave_grupo       text,
  numero_repeticion int,
  clave_pregunta    text,
  tipo              public.tipo_evidencia not null,
  ruta_archivo      text not null,  -- bucket evidencias: {id_proyecto}/{id_visita}/{archivo}
  hash_archivo      text,
  mime_type         text,
  tamano            bigint,
  nombre_original   text,
  fecha_captura     timestamptz not null default now(),
  latitud           numeric(9, 6),
  longitud          numeric(9, 6),
  comentario        text,
  importada         boolean not null default false,
  subido_en         timestamptz,  -- nulo = falta subir a Storage
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  eliminado_en      timestamptz,
  constraint evidencia_ruta_unica unique (ruta_archivo),
  constraint evidencia_tamano_valido check (tamano is null or tamano >= 0)
);

create index evidencia_id_visita_idx on public.evidencia (id_visita);
create index evidencia_hash_idx on public.evidencia (id_visita, hash_archivo);
create index evidencia_id_hallazgo_idx on public.evidencia (id_hallazgo);
create index evidencia_actualizado_en_idx on public.evidencia (actualizado_en);

create table public.documento (
  id              uuid primary key default gen_random_uuid(),
  id_proyecto     uuid not null references public.proyecto (id) on delete cascade,
  id_usuario      uuid references public.perfil (id),
  categoria       public.categoria_documento not null,
  ruta_archivo    text not null,  -- bucket documentos: {id_proyecto}/{archivo}
  mime_type       text,
  tamano          bigint,
  nombre_original text,
  subido_en       timestamptz,    -- nulo = falta subir a Storage
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  eliminado_en    timestamptz,
  constraint documento_ruta_unica unique (ruta_archivo),
  constraint documento_tamano_valido check (tamano is null or tamano >= 0)
);

create index documento_id_proyecto_idx on public.documento (id_proyecto);

-- ----- Revisión del supervisor ---------------------------------------

create table public.revision (
  id            uuid primary key default gen_random_uuid(),
  id_visita     uuid not null references public.visita (id) on delete cascade,
  id_supervisor uuid not null references public.perfil (id),
  decision      public.decision_revision not null,
  observaciones text,
  creado_en     timestamptz not null default now()
);

create index revision_id_visita_idx on public.revision (id_visita);

create table public.correccion (
  id             uuid primary key default gen_random_uuid(),
  id_revision    uuid not null references public.revision (id) on delete cascade,
  descripcion    text not null,
  estado         public.estado_correccion not null default 'pendiente',
  atendida_en    timestamptz,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create index correccion_id_revision_idx on public.correccion (id_revision);

-- ----- Reportes ------------------------------------------------------

create table public.plantilla_reporte (
  id             uuid primary key default gen_random_uuid(),
  id_cliente     uuid references public.cliente (id),  -- nulo = formato general
  nombre         text not null,
  descripcion    text,
  ruta_logotipo  text,  -- bucket reportes: logos/{id_plantilla_reporte}/{archivo}
  diseno         jsonb not null default '{}',
  activa         boolean not null default true,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  eliminado_en   timestamptz
);

create index plantilla_reporte_id_cliente_idx on public.plantilla_reporte (id_cliente);

create table public.reporte (
  id                   uuid primary key default gen_random_uuid(),
  id_proyecto          uuid not null references public.proyecto (id) on delete cascade,
  id_visita            uuid references public.visita (id),  -- opcional: reporte de una visita
  id_plantilla_reporte uuid references public.plantilla_reporte (id),
  id_usuario           uuid references public.perfil (id),
  version              int not null default 1,
  motivo_version       text,
  estado               public.estado_reporte not null default 'borrador',
  secciones            jsonb not null default '[]',
  ruta_pdf             text,  -- bucket reportes: {id_proyecto}/{archivo}.pdf
  creado_en            timestamptz not null default now(),
  actualizado_en       timestamptz not null default now(),
  eliminado_en         timestamptz,
  constraint reporte_version_unica unique nulls not distinct (id_proyecto, id_visita, version),
  constraint reporte_version_valida check (version >= 1)
);

-- ----- Trazabilidad y configuración ----------------------------------

create table public.historial (
  id              uuid primary key default gen_random_uuid(),
  id_usuario      uuid references public.perfil (id),  -- nulo = sistema
  id_proyecto     uuid,
  id_visita       uuid,
  tabla           text not null,
  id_registro     uuid,
  accion          public.accion_historial not null,
  valores_antes   jsonb,
  valores_despues jsonb,
  descripcion     text,
  creado_en       timestamptz not null default now()
);

create index historial_id_proyecto_idx on public.historial (id_proyecto, creado_en desc);
create index historial_id_visita_idx on public.historial (id_visita, creado_en desc);
create index historial_registro_idx on public.historial (tabla, id_registro);

create table public.configuracion (
  clave           text primary key,  -- ej. carpetas_zip, comentario_por_foto
  valor           jsonb not null,
  descripcion     text,
  actualizado_por uuid references public.perfil (id),
  actualizado_en  timestamptz not null default now()
);


-- =====================================================================
-- 3. Funciones de apoyo para permisos
--    security definer: leen perfil/proyecto/visita sin pasar por RLS
--    (evita recursión en las políticas).
-- =====================================================================

-- Fecha de hoy en México; la vigencia se cuenta en hora local.
create function public.hoy_mx()
returns date
language sql stable
set search_path = ''
as $$
  select (now() at time zone 'America/Mexico_City')::date;
$$;

-- Rol del usuario actual, o nulo si la cuenta está inactiva, eliminada o
-- fuera de su vigencia. El superadmin no vence.
create function public.mi_rol()
returns public.rol_usuario
language sql stable security definer
set search_path = ''
as $$
  select p.rol
  from public.perfil p
  where p.id = (select auth.uid())
    and p.activo
    and p.eliminado_en is null
    and (
      p.rol = 'superadmin'
      or (public.hoy_mx() >= p.inicio_vigencia
          and (p.fin_vigencia is null or public.hoy_mx() <= p.fin_vigencia))
    );
$$;

create function public.cuenta_vigente()
returns boolean
language sql stable
set search_path = ''
as $$
  select public.mi_rol() is not null;
$$;

create function public.es_superadmin()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(public.mi_rol() = 'superadmin', false);
$$;

create function public.es_admin()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(public.mi_rol() in ('admin', 'superadmin'), false);
$$;

-- Admin, o el supervisor del proyecto.
create function public.puede_gestionar_proyecto(p_id_proyecto uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.es_admin()
      or (public.mi_rol() = 'supervisor' and exists (
            select 1 from public.proyecto pr
            where pr.id = p_id_proyecto and pr.id_supervisor = (select auth.uid())));
$$;

-- Lo anterior, o un técnico asignado al proyecto o a alguna de sus visitas.
create function public.puede_ver_proyecto(p_id_proyecto uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.puede_gestionar_proyecto(p_id_proyecto)
      or (public.mi_rol() is not null and (
            exists (select 1 from public.proyecto_tecnico pt
                    where pt.id_proyecto = p_id_proyecto
                      and pt.id_tecnico = (select auth.uid())
                      and pt.eliminado_en is null)
         or exists (select 1 from public.visita v
                    where v.id_proyecto = p_id_proyecto
                      and (v.id_tecnico = (select auth.uid())
                           or v.id_supervisor = (select auth.uid())))));
$$;

create function public.puede_ver_visita(p_id_visita uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.mi_rol() is not null and exists (
    select 1 from public.visita v
    where v.id = p_id_visita
      and (v.id_tecnico = (select auth.uid())
           or v.id_supervisor = (select auth.uid())
           or public.puede_gestionar_proyecto(v.id_proyecto)));
$$;

-- Puede escribir respuestas, evidencias y hallazgos de la visita. El técnico
-- deja de poder hacerlo cuando la visita se aprueba o se cierra.
create function public.puede_capturar_visita(p_id_visita uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.mi_rol() is not null and exists (
    select 1 from public.visita v
    where v.id = p_id_visita
      and (v.id_supervisor = (select auth.uid())
           or public.puede_gestionar_proyecto(v.id_proyecto)
           or (v.id_tecnico = (select auth.uid())
               and v.estado not in ('aprobado', 'cerrado'))));
$$;

-- Admin, el supervisor de la visita o el del proyecto.
create function public.puede_revisar_visita(p_id_visita uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.mi_rol() is not null and exists (
    select 1 from public.visita v
    where v.id = p_id_visita
      and (v.id_supervisor = (select auth.uid())
           or public.puede_gestionar_proyecto(v.id_proyecto)));
$$;

-- Convierte a uuid una carpeta de Storage; nulo si no es un uuid.
create function public.a_uuid(p_texto text)
returns uuid
language sql immutable
set search_path = ''
as $$
  select case
    when p_texto ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then p_texto::uuid
  end;
$$;


-- =====================================================================
-- 4. Triggers
-- =====================================================================

-- ----- actualizado_en ------------------------------------------------

create function public.tocar_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'perfil', 'cliente', 'sitio', 'tipo_proyecto', 'motivo_visita', 'plantilla',
    'proyecto', 'visita', 'respuesta', 'hallazgo', 'evidencia', 'documento',
    'correccion', 'plantilla_reporte', 'reporte', 'configuracion'
  ] loop
    execute format(
      'create trigger tocar_actualizado_en before update on public.%I
         for each row execute function public.tocar_actualizado_en()', t);
  end loop;
end;
$$;

-- ----- Perfil al crear una cuenta ------------------------------------
-- La Edge Function del superadmin llama a auth.admin.createUser con
-- app_metadata = { rol, inicio_vigencia, fin_vigencia, creado_por } y
-- user_metadata = { nombre }. app_metadata no lo puede editar el usuario.
-- Una cuenta creada sin rol (p. ej. desde el panel de Supabase) queda
-- inactiva hasta que el superadmin la active.

create function public.crear_perfil_de_usuario()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  app jsonb := coalesce(new.raw_app_meta_data, '{}');
begin
  insert into public.perfil (id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia, creado_por)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'nombre', ''), split_part(new.email, '@', 1), 'Sin nombre'),
    coalesce((app ->> 'rol')::public.rol_usuario, 'tecnico'),
    app ? 'rol',
    coalesce((app ->> 'inicio_vigencia')::date, public.hoy_mx()),
    (app ->> 'fin_vigencia')::date,
    (app ->> 'creado_por')::uuid
  );
  return new;
end;
$$;

create trigger crear_perfil
  after insert on auth.users
  for each row execute function public.crear_perfil_de_usuario();

create function public.copiar_email_a_perfil()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.perfil set email = new.email where id = new.id;
  return new;
end;
$$;

create trigger copiar_email
  after update of email on auth.users
  for each row execute function public.copiar_email_a_perfil();

-- ----- Qué puede cambiar el técnico en su visita ---------------------
-- RLS decide qué filas puede tocar; esto decide qué columnas.

create function public.proteger_visita()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- service_role / editor SQL, admin y supervisores: sin restricción.
  if (select auth.uid()) is null
     or old.id_supervisor = (select auth.uid())
     or public.puede_gestionar_proyecto(old.id_proyecto) then
    return new;
  end if;

  if new.id_proyecto      is distinct from old.id_proyecto
  or new.id_tecnico       is distinct from old.id_tecnico
  or new.id_supervisor    is distinct from old.id_supervisor
  or new.id_motivo        is distinct from old.id_motivo
  or new.id_plantilla     is distinct from old.id_plantilla
  or new.numero           is distinct from old.numero
  or new.fecha_programada is distinct from old.fecha_programada
  or new.eliminado_en     is distinct from old.eliminado_en then
    raise exception 'El técnico no puede cambiar la asignación de la visita'
      using errcode = '42501';
  end if;

  if new.estado is distinct from old.estado and new.estado in ('aprobado', 'cerrado') then
    raise exception 'Solo el supervisor puede aprobar o cerrar la visita'
      using errcode = '42501';
  end if;

  if old.plantilla_usada is not null and new.plantilla_usada is distinct from old.plantilla_usada then
    raise exception 'La plantilla de la visita ya quedó fija al iniciar'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger proteger_visita
  before update on public.visita
  for each row execute function public.proteger_visita();

-- ----- Historial -----------------------------------------------------

create function public.registrar_historial()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  antes   jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  despues jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  fila    jsonb := coalesce(despues, antes);
  v_accion   public.accion_historial;
  v_proyecto uuid;
  v_visita   uuid;
begin
  -- Abrir una visita o solo tocar actualizado_en no es un cambio.
  if tg_op = 'UPDATE'
     and (antes - 'actualizado_en' - 'fecha_ultima_apertura')
       = (despues - 'actualizado_en' - 'fecha_ultima_apertura') then
    return null;
  end if;

  v_accion := case
    when tg_op = 'INSERT' then 'crear'
    when tg_op = 'DELETE' then 'eliminar'
    when antes ->> 'eliminado_en' is null and despues ->> 'eliminado_en' is not null then 'eliminar'
    else 'editar'
  end;

  v_visita := case when tg_table_name = 'visita' then (fila ->> 'id')::uuid
                   else (fila ->> 'id_visita')::uuid end;
  v_proyecto := case when tg_table_name = 'proyecto' then (fila ->> 'id')::uuid
                     else (fila ->> 'id_proyecto')::uuid end;
  if v_proyecto is null and v_visita is not null then
    select v.id_proyecto into v_proyecto from public.visita v where v.id = v_visita;
  end if;

  insert into public.historial
    (id_usuario, id_proyecto, id_visita, tabla, id_registro, accion, valores_antes, valores_despues)
  values
    ((select auth.uid()), v_proyecto, v_visita, tg_table_name,
     (fila ->> 'id')::uuid, v_accion, antes, despues);

  return null;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'perfil', 'cliente', 'sitio', 'tipo_proyecto', 'motivo_visita', 'plantilla',
    'proyecto', 'proyecto_tecnico', 'visita', 'respuesta', 'hallazgo', 'evidencia',
    'documento', 'revision', 'correccion', 'plantilla_reporte', 'reporte', 'configuracion'
  ] loop
    execute format(
      'create trigger registrar_historial after insert or update or delete on public.%I
         for each row execute function public.registrar_historial()', t);
  end loop;
end;
$$;


-- =====================================================================
-- 5. Row Level Security
-- =====================================================================

alter table public.perfil            enable row level security;
alter table public.cliente           enable row level security;
alter table public.sitio             enable row level security;
alter table public.tipo_proyecto     enable row level security;
alter table public.motivo_visita     enable row level security;
alter table public.plantilla         enable row level security;
alter table public.proyecto          enable row level security;
alter table public.proyecto_tecnico  enable row level security;
alter table public.visita            enable row level security;
alter table public.respuesta         enable row level security;
alter table public.hallazgo          enable row level security;
alter table public.evidencia         enable row level security;
alter table public.documento         enable row level security;
alter table public.revision          enable row level security;
alter table public.correccion        enable row level security;
alter table public.plantilla_reporte enable row level security;
alter table public.reporte           enable row level security;
alter table public.historial         enable row level security;
alter table public.configuracion     enable row level security;

-- ----- perfil: todos ven los nombres; solo el superadmin administra cuentas.
-- Una cuenta vencida puede leer su propio perfil (para avisar "tu cuenta venció").
create policy perfil_select on public.perfil for select to authenticated
  using (public.cuenta_vigente() or id = (select auth.uid()));
create policy perfil_update on public.perfil for update to authenticated
  using (public.es_superadmin()) with check (public.es_superadmin());

-- ----- cliente y sitio: admin y supervisores (los supervisores crean proyectos).
create policy cliente_select on public.cliente for select to authenticated
  using (public.cuenta_vigente());
create policy cliente_insert on public.cliente for insert to authenticated
  with check (public.mi_rol() in ('superadmin', 'admin', 'supervisor'));
create policy cliente_update on public.cliente for update to authenticated
  using (public.mi_rol() in ('superadmin', 'admin', 'supervisor'))
  with check (public.mi_rol() in ('superadmin', 'admin', 'supervisor'));

create policy sitio_select on public.sitio for select to authenticated
  using (public.cuenta_vigente());
create policy sitio_insert on public.sitio for insert to authenticated
  with check (public.mi_rol() in ('superadmin', 'admin', 'supervisor'));
create policy sitio_update on public.sitio for update to authenticated
  using (public.mi_rol() in ('superadmin', 'admin', 'supervisor'))
  with check (public.mi_rol() in ('superadmin', 'admin', 'supervisor'));

-- ----- Catálogos, plantillas y configuración: todos leen, el admin edita.
do $$
declare
  t text;
begin
  foreach t in array array['tipo_proyecto', 'motivo_visita', 'plantilla', 'plantilla_reporte', 'configuracion'] loop
    execute format(
      'create policy %1$s_select on public.%1$I for select to authenticated
         using (public.cuenta_vigente())', t);
    execute format(
      'create policy %1$s_insert on public.%1$I for insert to authenticated
         with check (public.es_admin())', t);
    execute format(
      'create policy %1$s_update on public.%1$I for update to authenticated
         using (public.es_admin()) with check (public.es_admin())', t);
  end loop;
end;
$$;

-- ----- proyecto
-- Las condiciones van sobre las columnas de la fila (y no con
-- puede_ver_proyecto(id)) para que insert ... returning funcione.
create policy proyecto_select on public.proyecto for select to authenticated
  using (
    public.es_admin()
    or (public.cuenta_vigente() and id_supervisor = (select auth.uid()))
    or public.puede_ver_proyecto(id)
  );
create policy proyecto_insert on public.proyecto for insert to authenticated
  with check (
    public.es_admin()
    or (public.mi_rol() = 'supervisor' and id_supervisor = (select auth.uid()))
  );
create policy proyecto_update on public.proyecto for update to authenticated
  using (public.puede_gestionar_proyecto(id))
  with check (
    public.es_admin()
    or (public.mi_rol() = 'supervisor' and id_supervisor = (select auth.uid()))
  );

-- ----- proyecto_tecnico
create policy proyecto_tecnico_select on public.proyecto_tecnico for select to authenticated
  using (public.puede_ver_proyecto(id_proyecto));
create policy proyecto_tecnico_insert on public.proyecto_tecnico for insert to authenticated
  with check (public.puede_gestionar_proyecto(id_proyecto));
create policy proyecto_tecnico_update on public.proyecto_tecnico for update to authenticated
  using (public.puede_gestionar_proyecto(id_proyecto))
  with check (public.puede_gestionar_proyecto(id_proyecto));

-- ----- visita: la crean admin y supervisor; el técnico la actualiza
-- (inicio, fin, repeticiones...) y proteger_visita limita las columnas.
create policy visita_select on public.visita for select to authenticated
  using (
    public.cuenta_vigente() and (
      id_tecnico = (select auth.uid())
      or id_supervisor = (select auth.uid())
      or public.puede_gestionar_proyecto(id_proyecto))
  );
create policy visita_insert on public.visita for insert to authenticated
  with check (public.puede_gestionar_proyecto(id_proyecto));
create policy visita_update on public.visita for update to authenticated
  using (
    public.cuenta_vigente() and (
      id_supervisor = (select auth.uid())
      or public.puede_gestionar_proyecto(id_proyecto)
      or (id_tecnico = (select auth.uid()) and estado not in ('aprobado', 'cerrado')))
  )
  with check (
    public.cuenta_vigente() and (
      id_tecnico = (select auth.uid())
      or id_supervisor = (select auth.uid())
      or public.puede_gestionar_proyecto(id_proyecto))
  );

-- ----- respuesta
create policy respuesta_select on public.respuesta for select to authenticated
  using (public.puede_ver_visita(id_visita));
create policy respuesta_insert on public.respuesta for insert to authenticated
  with check (public.puede_capturar_visita(id_visita));
create policy respuesta_update on public.respuesta for update to authenticated
  using (public.puede_capturar_visita(id_visita))
  with check (public.puede_capturar_visita(id_visita));

-- ----- hallazgo y evidencia: quien los crea queda como autor.
create policy hallazgo_select on public.hallazgo for select to authenticated
  using (public.puede_ver_visita(id_visita));
create policy hallazgo_insert on public.hallazgo for insert to authenticated
  with check (public.puede_capturar_visita(id_visita) and id_usuario = (select auth.uid()));
create policy hallazgo_update on public.hallazgo for update to authenticated
  using (public.puede_capturar_visita(id_visita))
  with check (public.puede_capturar_visita(id_visita));

create policy evidencia_select on public.evidencia for select to authenticated
  using (public.puede_ver_visita(id_visita));
create policy evidencia_insert on public.evidencia for insert to authenticated
  with check (public.puede_capturar_visita(id_visita) and id_usuario = (select auth.uid()));
create policy evidencia_update on public.evidencia for update to authenticated
  using (public.puede_capturar_visita(id_visita))
  with check (public.puede_capturar_visita(id_visita));

-- ----- documento: el técnico también sube documentos (p. ej. recibo CFE).
create policy documento_select on public.documento for select to authenticated
  using (public.puede_ver_proyecto(id_proyecto));
create policy documento_insert on public.documento for insert to authenticated
  with check (public.puede_ver_proyecto(id_proyecto) and id_usuario = (select auth.uid()));
create policy documento_update on public.documento for update to authenticated
  using (public.puede_gestionar_proyecto(id_proyecto) or id_usuario = (select auth.uid()))
  with check (public.puede_ver_proyecto(id_proyecto));

-- ----- revision: no se edita; cada decisión es un registro nuevo.
create policy revision_select on public.revision for select to authenticated
  using (public.puede_ver_visita(id_visita));
create policy revision_insert on public.revision for insert to authenticated
  with check (public.puede_revisar_visita(id_visita) and id_supervisor = (select auth.uid()));

-- ----- correccion: la pide el supervisor; el técnico la marca como atendida.
create policy correccion_select on public.correccion for select to authenticated
  using (exists (select 1 from public.revision r
                 where r.id = id_revision and public.puede_ver_visita(r.id_visita)));
create policy correccion_insert on public.correccion for insert to authenticated
  with check (exists (select 1 from public.revision r
                      where r.id = id_revision and public.puede_revisar_visita(r.id_visita)));
create policy correccion_update on public.correccion for update to authenticated
  using (exists (select 1 from public.revision r
                 where r.id = id_revision and public.puede_ver_visita(r.id_visita)))
  with check (exists (select 1 from public.revision r
                      where r.id = id_revision and public.puede_ver_visita(r.id_visita)));

-- ----- reporte
create policy reporte_select on public.reporte for select to authenticated
  using (public.puede_ver_proyecto(id_proyecto));
create policy reporte_insert on public.reporte for insert to authenticated
  with check (public.puede_gestionar_proyecto(id_proyecto) and id_usuario = (select auth.uid()));
create policy reporte_update on public.reporte for update to authenticated
  using (public.puede_gestionar_proyecto(id_proyecto))
  with check (public.puede_gestionar_proyecto(id_proyecto));

-- ----- historial: solo lectura; lo escriben los triggers.
create policy historial_select on public.historial for select to authenticated
  using (
    public.es_admin()
    or (id_proyecto is not null and public.puede_ver_proyecto(id_proyecto))
  );


-- =====================================================================
-- 6. Storage (fotos, videos, documentos y reportes)
--    Buckets privados: la app muestra los archivos con URLs firmadas.
--    Rutas:
--      evidencias/{id_proyecto}/{id_visita}/{archivo}
--      documentos/{id_proyecto}/{archivo}
--      reportes/{id_proyecto}/{archivo}.pdf
--      reportes/logos/{id_plantilla_reporte}/{archivo}
--    50 MB por archivo es el máximo del plan gratuito; súbanlo si cambian de plan.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('evidencias', 'evidencias', false, 52428800,
   array['image/jpeg', 'image/png', 'image/heic', 'image/webp',
         'video/mp4', 'video/quicktime', 'application/pdf']),
  ('documentos', 'documentos', false, 52428800, null),
  ('reportes', 'reportes', false, 52428800,
   array['application/pdf', 'image/jpeg', 'image/png', 'image/svg+xml'])
on conflict (id) do nothing;

-- ----- evidencias
create policy evidencias_select on storage.objects for select to authenticated
  using (bucket_id = 'evidencias'
         and public.puede_ver_visita(public.a_uuid((storage.foldername(name))[2])));
create policy evidencias_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'evidencias'
              and public.puede_capturar_visita(public.a_uuid((storage.foldername(name))[2])));
create policy evidencias_update on storage.objects for update to authenticated
  using (bucket_id = 'evidencias'
         and public.puede_capturar_visita(public.a_uuid((storage.foldername(name))[2])));
create policy evidencias_delete on storage.objects for delete to authenticated
  using (bucket_id = 'evidencias'
         and public.puede_capturar_visita(public.a_uuid((storage.foldername(name))[2])));

-- ----- documentos
create policy documentos_select on storage.objects for select to authenticated
  using (bucket_id = 'documentos'
         and public.puede_ver_proyecto(public.a_uuid((storage.foldername(name))[1])));
create policy documentos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos'
              and public.puede_ver_proyecto(public.a_uuid((storage.foldername(name))[1])));
create policy documentos_update on storage.objects for update to authenticated
  using (bucket_id = 'documentos'
         and public.puede_ver_proyecto(public.a_uuid((storage.foldername(name))[1])));
create policy documentos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documentos'
         and public.puede_gestionar_proyecto(public.a_uuid((storage.foldername(name))[1])));

-- ----- reportes (y logotipos de las plantillas de reporte)
create policy reportes_select on storage.objects for select to authenticated
  using (bucket_id = 'reportes' and (
         ((storage.foldername(name))[1] = 'logos' and public.cuenta_vigente())
         or public.puede_ver_proyecto(public.a_uuid((storage.foldername(name))[1]))));
create policy reportes_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'reportes' and (
              ((storage.foldername(name))[1] = 'logos' and public.es_admin())
              or public.puede_gestionar_proyecto(public.a_uuid((storage.foldername(name))[1]))));
create policy reportes_update on storage.objects for update to authenticated
  using (bucket_id = 'reportes' and (
         ((storage.foldername(name))[1] = 'logos' and public.es_admin())
         or public.puede_gestionar_proyecto(public.a_uuid((storage.foldername(name))[1]))));
create policy reportes_delete on storage.objects for delete to authenticated
  using (bucket_id = 'reportes' and (
         ((storage.foldername(name))[1] = 'logos' and public.es_admin())
         or public.puede_gestionar_proyecto(public.a_uuid((storage.foldername(name))[1]))));


-- =====================================================================
-- 7. Datos iniciales (los mismos de SurveyStore.catalogDefaults)
-- =====================================================================

insert into public.tipo_proyecto (nombre, orden) values
  ('Viabilidad FV', 1),
  ('Levantamiento eléctrico', 2),
  ('Auditoría FV', 3),
  ('Mantenimiento FV', 4);

insert into public.motivo_visita (nombre, orden) values
  ('Información incompleta', 1),
  ('Mediciones adicionales', 2),
  ('Corrección de información', 3),
  ('Actividades posteriores', 4);


-- =====================================================================
-- Primer superadmin (hacer una sola vez, a mano):
--   1. Authentication → Users → Add user (correo y contraseña).
--   2. En el editor SQL:
--        update public.perfil
--        set rol = 'superadmin', activo = true, fin_vigencia = null
--        where email = 'correo@ejemplo.com';
-- =====================================================================
