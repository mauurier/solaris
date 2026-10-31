-- El técnico asignado cambia el estado del proyecto cuando inicia o termina
-- su visita (en_captura, pendiente_sync) y la app lo sube. Sólo eso:
-- proteger_proyecto rechaza cualquier otra columna, como proteger_visita.

drop policy proyecto_update on public.proyecto;
create policy proyecto_update on public.proyecto for update to authenticated
  using (
    public.puede_gestionar_proyecto(id)
    or (public.mi_rol() = 'tecnico' and public.puede_ver_proyecto(id))
  )
  with check (
    public.es_admin()
    or (public.mi_rol() = 'supervisor' and id_supervisor = (select auth.uid()))
    or (public.mi_rol() = 'tecnico' and public.puede_ver_proyecto(id))
  );

create function public.proteger_proyecto()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- service_role / editor SQL, admin y supervisor del proyecto: sin restricción.
  if (select auth.uid()) is null or public.puede_gestionar_proyecto(old.id) then
    return new;
  end if;

  if (to_jsonb(new) - 'estado' - 'actualizado_en') is distinct from (to_jsonb(old) - 'estado' - 'actualizado_en') then
    raise exception 'El técnico sólo puede cambiar el estado del proyecto'
      using errcode = '42501';
  end if;

  if new.estado is distinct from old.estado and new.estado in ('aprobado', 'cerrado') then
    raise exception 'Solo el supervisor puede aprobar o cerrar el proyecto'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke execute on function public.proteger_proyecto() from public, anon, authenticated;

create trigger proteger_proyecto
  before update on public.proyecto
  for each row execute function public.proteger_proyecto();
