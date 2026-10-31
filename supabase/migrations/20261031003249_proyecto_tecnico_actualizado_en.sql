-- La app baja "lo que cambió desde X" con actualizado_en. proyecto_tecnico
-- no lo tenía, así que asignar o quitar un técnico no se enteraba.
alter table public.proyecto_tecnico
  add column actualizado_en timestamptz not null default now();

create trigger tocar_actualizado_en before update on public.proyecto_tecnico
  for each row execute function public.tocar_actualizado_en();

create index proyecto_tecnico_actualizado_en_idx on public.proyecto_tecnico (actualizado_en);
