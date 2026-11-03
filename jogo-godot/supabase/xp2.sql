-- Passe com 50 níveis: curva de XP mais suave (do nível n pro n+1: 150 + 30 n) e níveis de bônus.
-- Níveis de bônus (ganha só XP): alguns dão +300 XP na hora, outros XP em dobro por 15 min.
alter table public.bicho_perfis add column if not exists xp_dobro_ate timestamptz;

create or replace function public.bicho_nivel(p_xp integer)
returns integer language plpgsql immutable as $$
declare n integer := 1; resto integer := p_xp;
begin
  while resto >= 150 + 30 * n and n < 99 loop
    resto := resto - (150 + 30 * n);
    n := n + 1;
  end loop;
  return n;
end $$;

-- soma XP (dobra se o bônus estiver ativo), teto diário 8000, e aplica os bônus dos níveis que passou
create or replace function public._bicho_dar_xp(v_uid uuid, v_xp integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_total integer;
  v_antes integer;
  v_dobro timestamptz;
  v_ganho integer;
  n integer;
begin
  update public.bicho_perfis set
    xp_hoje = case when xp_dia = current_date then xp_hoje else 0 end,
    xp_dia = current_date
  where id = v_uid
  returning xp, xp_dobro_ate into v_antes, v_dobro;
  v_ganho := v_xp * (case when v_dobro is not null and v_dobro > now() then 2 else 1 end);
  update public.bicho_perfis set
    xp = xp + greatest(0, least(v_ganho, 8000 - xp_hoje)),
    xp_hoje = xp_hoje + greatest(0, least(v_ganho, 8000 - xp_hoje))
  where id = v_uid
  returning xp into v_total;
  -- bônus dos níveis que acabou de passar
  for n in (public.bicho_nivel(coalesce(v_antes, 0)) + 1) .. public.bicho_nivel(coalesce(v_total, 0)) loop
    if n in (3, 9, 15, 21, 27, 33, 39, 45) then
      update public.bicho_perfis set xp_dobro_ate = greatest(coalesce(xp_dobro_ate, now()), now()) + interval '15 minutes' where id = v_uid;
    elsif n in (5, 11, 17, 23, 29, 36, 41, 44, 47, 49, 13, 31) then
      update public.bicho_perfis set xp = xp + 300 where id = v_uid returning xp into v_total;
    end if;
  end loop;
  return coalesce(v_total, 0);
end $$;
revoke all on function public._bicho_dar_xp(uuid, integer) from public, anon, authenticated;

-- XP e até quando o XP em dobro vale
create or replace function public.bicho_meu_passe()
returns jsonb language sql security definer set search_path = '' as $$
  select jsonb_build_object('xp', coalesce(xp, 0), 'dobro_ate', xp_dobro_ate)
  from public.bicho_perfis where id = auth.uid()
$$;
grant execute on function public.bicho_meu_passe() to authenticated;
