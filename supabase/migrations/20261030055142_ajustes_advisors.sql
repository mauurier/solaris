-- =====================================================================
-- Ajustes que marcó el Security/Performance Advisor de Supabase.
-- =====================================================================

-- ----- Permisos de ejecución de funciones -----------------------------
-- Postgres da EXECUTE a todos por defecto y PostgREST expone las funciones
-- de public como /rest/v1/rpc/...

-- Funciones de trigger: nadie las llama directamente.
revoke execute on function public.crear_perfil_de_usuario() from public, anon, authenticated;
revoke execute on function public.copiar_email_a_perfil() from public, anon, authenticated;
revoke execute on function public.registrar_historial() from public, anon, authenticated;
revoke execute on function public.proteger_visita() from public, anon, authenticated;
revoke execute on function public.tocar_actualizado_en() from public, anon, authenticated;

-- Funciones de permisos: las usan las políticas RLS, que se evalúan como el
-- usuario con sesión, así que authenticated sí debe poder ejecutarlas.
-- anon (sin sesión) no las necesita.
revoke execute on function public.hoy_mx() from public, anon;
revoke execute on function public.mi_rol() from public, anon;
revoke execute on function public.cuenta_vigente() from public, anon;
revoke execute on function public.es_superadmin() from public, anon;
revoke execute on function public.es_admin() from public, anon;
revoke execute on function public.puede_gestionar_proyecto(uuid) from public, anon;
revoke execute on function public.puede_ver_proyecto(uuid) from public, anon;
revoke execute on function public.puede_ver_visita(uuid) from public, anon;
revoke execute on function public.puede_capturar_visita(uuid) from public, anon;
revoke execute on function public.puede_revisar_visita(uuid) from public, anon;
revoke execute on function public.a_uuid(text) from public, anon;

grant execute on function public.hoy_mx() to authenticated;
grant execute on function public.mi_rol() to authenticated;
grant execute on function public.cuenta_vigente() to authenticated;
grant execute on function public.es_superadmin() to authenticated;
grant execute on function public.es_admin() to authenticated;
grant execute on function public.puede_gestionar_proyecto(uuid) to authenticated;
grant execute on function public.puede_ver_proyecto(uuid) to authenticated;
grant execute on function public.puede_ver_visita(uuid) to authenticated;
grant execute on function public.puede_capturar_visita(uuid) to authenticated;
grant execute on function public.puede_revisar_visita(uuid) to authenticated;
grant execute on function public.a_uuid(text) to authenticated;

-- ----- Índices para llaves foráneas ------------------------------------

create index perfil_creado_por_idx on public.perfil (creado_por);
create index proyecto_id_tipo_proyecto_idx on public.proyecto (id_tipo_proyecto);
create index proyecto_id_plantilla_idx on public.proyecto (id_plantilla);
create index visita_id_motivo_idx on public.visita (id_motivo);
create index visita_id_plantilla_idx on public.visita (id_plantilla);
create index hallazgo_id_usuario_idx on public.hallazgo (id_usuario);
create index evidencia_id_usuario_idx on public.evidencia (id_usuario);
create index documento_id_usuario_idx on public.documento (id_usuario);
create index revision_id_supervisor_idx on public.revision (id_supervisor);
create index reporte_id_visita_idx on public.reporte (id_visita);
create index reporte_id_plantilla_reporte_idx on public.reporte (id_plantilla_reporte);
create index reporte_id_usuario_idx on public.reporte (id_usuario);
create index historial_id_usuario_idx on public.historial (id_usuario);
create index configuracion_actualizado_por_idx on public.configuracion (actualizado_por);
