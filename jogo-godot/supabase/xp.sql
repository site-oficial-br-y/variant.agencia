-- Nível de conta / passe de batalha do Bicho Ehn.
-- O XP só é dado pelo servidor (o jogo pede "venci a fase X", o servidor decide quanto vale e se pode).
-- Tempo de jogo: 10 XP por minuto, somado dentro do bicho_somar_tempo (que já limita o ritmo).

alter table public.bicho_perfis add column if not exists xp integer not null default 0;
alter table public.bicho_perfis add column if not exists xp_dia date;
alter table public.bicho_perfis add column if not exists xp_hoje integer not null default 0;
alter table public.bicho_perfis add column if not exists xp_ultimo timestamptz;
alter table public.bicho_perfis add column if not exists fases_xp smallint[] not null default '{}';

-- XP retroativo: tempo já jogado (10/min) + 200 por fase que já tem recorde (só uma vez)
do $$
begin
  if not exists (select 1 from public.bicho_perfis where xp > 0) then
    update public.bicho_perfis p set
      xp = (p.tempo_jogo / 6) + 200 * coalesce((select count(*) from public.bicho_recordes r where r.user_id = p.id), 0),
      fases_xp = coalesce((select array_agg(r.fase) from public.bicho_recordes r where r.user_id = p.id), '{}');
  end if;
end $$;

-- soma XP com teto diário (8000) e devolve o total
create or replace function public._bicho_dar_xp(v_uid uuid, v_xp integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_total integer;
begin
  update public.bicho_perfis set
    xp_hoje = case when xp_dia = current_date then xp_hoje else 0 end,
    xp_dia = current_date
  where id = v_uid;
  update public.bicho_perfis set
    xp = xp + greatest(0, least(v_xp, 8000 - xp_hoje)),
    xp_hoje = xp_hoje + greatest(0, least(v_xp, 8000 - xp_hoje))
  where id = v_uid
  returning xp into v_total;
  return coalesce(v_total, 0);
end $$;
revoke all on function public._bicho_dar_xp(uuid, integer) from public, anon, authenticated;

-- o jogo avisa o que aconteceu; o servidor decide o XP. Devolve {"xp": total, "ganho": n}
create or replace function public.bicho_ganhar_xp(p_motivo text, p_fase integer default 0)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_ultimo timestamptz;
  v_fases smallint[];
  v_ganho integer := 0;
  v_chefe boolean := p_fase in (5, 6, 7, 8, 9, 10);
  v_total integer;
begin
  if v_uid is null then return jsonb_build_object('xp', 0, 'ganho', 0); end if;
  select xp_ultimo, fases_xp into v_ultimo, v_fases from public.bicho_perfis where id = v_uid for update;
  if not found then return jsonb_build_object('xp', 0, 'ganho', 0); end if;
  if v_ultimo is not null and now() - v_ultimo < interval '8 seconds' then      -- ninguém vence 2 fases em 8 s
    return jsonb_build_object('xp', (select xp from public.bicho_perfis where id = v_uid), 'ganho', 0);
  end if;
  if p_motivo = 'fase' and p_fase between 1 and 10 then
    if p_fase = any(v_fases) then
      v_ganho := case when v_chefe then 150 else 50 end;
    else
      v_ganho := case when v_chefe then 500 else 200 end;
      update public.bicho_perfis set fases_xp = array_append(fases_xp, p_fase::smallint) where id = v_uid;
    end if;
  elsif p_motivo = 'recorde' then v_ganho := 100;
  elsif p_motivo = 'online_1' then v_ganho := 120;
  elsif p_motivo = 'online_2' then v_ganho := 60;
  elsif p_motivo = 'online' then v_ganho := 20;
  end if;
  update public.bicho_perfis set xp_ultimo = now() where id = v_uid and v_ganho > 0 and p_motivo <> 'recorde';
  v_total := public._bicho_dar_xp(v_uid, v_ganho);
  return jsonb_build_object('xp', v_total, 'ganho', v_ganho);
end $$;
grant execute on function public.bicho_ganhar_xp(text, integer) to authenticated;

-- tempo de jogo agora também dá XP (10 por minuto)
create or replace function public.bicho_somar_tempo(p_segundos integer, p_personagem text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_ping timestamptz;
  v_soma integer;
begin
  if v_uid is null then return 0; end if;
  select ultimo_ping into v_ping from public.bicho_perfis where id = v_uid for update;
  if not found then return 0; end if;
  v_soma := least(greatest(coalesce(p_segundos, 0), 0), 120, floor(extract(epoch from (now() - v_ping)))::integer);
  update public.bicho_perfis
    set tempo_jogo = tempo_jogo + v_soma, ultimo_ping = now(),
        personagem = coalesce(left(p_personagem, 20), personagem)
    where id = v_uid;
  perform public._bicho_dar_xp(v_uid, v_soma / 6);
  return v_soma;
end $$;

-- passe: item -> nível que libera. Skin do passe vai pro inventário quando o nível chega.
create table if not exists public.bicho_passe (
  item text primary key references public.bicho_itens (item),
  nivel smallint not null
);
alter table public.bicho_passe enable row level security;
drop policy if exists "todos veem" on public.bicho_passe;
create policy "todos veem" on public.bicho_passe for select using (true);
grant select on public.bicho_passe to anon, authenticated;

-- nível a partir do XP (mesma conta do jogo: do nível n pro n+1 custa 150 + 50 n)
create or replace function public.bicho_nivel(p_xp integer)
returns integer language plpgsql immutable as $$
declare n integer := 1; resto integer := p_xp;
begin
  while resto >= 150 + 50 * n and n < 99 loop
    resto := resto - (150 + 50 * n);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.bicho_resgatar_passe()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_nivel integer; v_n integer;
begin
  if v_uid is null then return 0; end if;
  select public.bicho_nivel(xp) into v_nivel from public.bicho_perfis where id = v_uid;
  insert into public.bicho_inventario (user_id, item)
    select v_uid, p.item from public.bicho_passe p where p.nivel <= coalesce(v_nivel, 0)
    on conflict do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
grant execute on function public.bicho_resgatar_passe() to authenticated;

-- o próprio XP (pra mostrar o nível)
create or replace function public.bicho_meu_xp()
returns integer language sql security definer set search_path = '' as $$
  select coalesce((select xp from public.bicho_perfis where id = auth.uid()), 0)
$$;
grant execute on function public.bicho_meu_xp() to authenticated;
