-- correccion no tiene id_visita ni id_proyecto: se llega por su revisión.
-- Sin esto sus cambios no salían en el historial del proyecto.
create or replace function public.registrar_historial()
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
  if v_visita is null and tg_table_name = 'correccion' then
    select r.id_visita into v_visita from public.revision r where r.id = (fila ->> 'id_revision')::uuid;
  end if;
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
