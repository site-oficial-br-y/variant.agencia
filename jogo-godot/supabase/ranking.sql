-- Bicho Ehn: contas (usuário + senha, com nick público), ranking dos melhores tempos e de tempo de jogo.
-- Rodar UMA vez no Supabase: SQL Editor > New query > colar tudo > Run.
-- Pode rodar de novo sem problema (não apaga nada).

create table if not exists public.bicho_perfis (
  id uuid primary key references auth.users (id) on delete cascade,
  apelido text not null check (char_length(apelido) between 3 and 16),
  personagem text,
  tempo_jogo integer not null default 0,
  ultimo_ping timestamptz not null default now(),
  criado_em timestamptz not null default now()
);
create unique index if not exists bicho_perfis_apelido on public.bicho_perfis (lower(apelido));

create table if not exists public.bicho_recordes (
  user_id uuid not null references public.bicho_perfis (id) on delete cascade,
  fase smallint not null check (fase between 1 and 8),
  tempo real not null check (tempo > 0),
  personagem text,
  quando timestamptz not null default now(),
  primary key (user_id, fase)
);
create index if not exists bicho_recordes_fase_tempo on public.bicho_recordes (fase, tempo);

-- todo mundo lê (ranking público); ninguém escreve direto, só pelas funções abaixo
alter table public.bicho_perfis enable row level security;
alter table public.bicho_recordes enable row level security;
drop policy if exists "ranking publico" on public.bicho_perfis;
create policy "ranking publico" on public.bicho_perfis for select using (true);
drop policy if exists "ranking publico" on public.bicho_recordes;
create policy "ranking publico" on public.bicho_recordes for select using (true);
grant select on public.bicho_perfis, public.bicho_recordes to anon, authenticated;
revoke insert, update, delete on public.bicho_perfis, public.bicho_recordes from anon, authenticated;

-- perfil com o apelido da conta (se o apelido repetir, ganha um final pra não travar)
create or replace function public.bicho_criar_perfil(p_id uuid, p_meta jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_apelido text := left(coalesce(nullif(trim(p_meta ->> 'apelido'), ''), 'jogador'), 16);
begin
  if char_length(v_apelido) < 3 then
    v_apelido := rpad(v_apelido, 3, '_');
  end if;
  begin
    insert into public.bicho_perfis (id, apelido) values (p_id, v_apelido);
  exception when unique_violation then
    insert into public.bicho_perfis (id, apelido) values (p_id, left(v_apelido, 11) || '_' || left(p_id::text, 4))
    on conflict (id) do nothing;
  end;
end $$;
revoke all on function public.bicho_criar_perfil(uuid, jsonb) from public, anon, authenticated;

-- conta nova no Auth = perfil novo
create or replace function public.bicho_novo_perfil() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.bicho_criar_perfil(new.id, new.raw_user_meta_data);
  return new;
end $$;
drop trigger if exists bicho_novo_perfil on auth.users;
create trigger bicho_novo_perfil after insert on auth.users
  for each row execute function public.bicho_novo_perfil();

-- quem criou conta antes deste script ganha perfil também
do $$
declare
  u record;
begin
  for u in select id, raw_user_meta_data from auth.users
           where id not in (select id from public.bicho_perfis) loop
    perform public.bicho_criar_perfil(u.id, u.raw_user_meta_data);
  end loop;
end $$;

-- recorde de uma fase (só guarda se for melhor que o anterior)
create or replace function public.bicho_registrar_recorde(p_fase integer, p_tempo real, p_personagem text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_fase is null or p_fase not between 1 and 8
     or p_tempo is null or p_tempo <= 0 then
    return false;
  end if;
  insert into public.bicho_recordes as r (user_id, fase, tempo, personagem)
  values (v_uid, p_fase, p_tempo, left(p_personagem, 20))
  on conflict (user_id, fase) do update
    set tempo = excluded.tempo, personagem = excluded.personagem, quando = now()
    where excluded.tempo < r.tempo;
  return true;
end $$;

-- soma tempo de jogo: nunca mais do que o tempo que passou de verdade desde o último envio
create or replace function public.bicho_somar_tempo(p_segundos integer, p_personagem text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_ping timestamptz;
  v_soma integer;
begin
  if v_uid is null then
    return 0;
  end if;
  select ultimo_ping into v_ping from public.bicho_perfis where id = v_uid for update;
  if not found then
    return 0;
  end if;
  v_soma := least(greatest(coalesce(p_segundos, 0), 0), 120, floor(extract(epoch from (now() - v_ping)))::integer);
  update public.bicho_perfis
    set tempo_jogo = tempo_jogo + v_soma, ultimo_ping = now(),
        personagem = coalesce(left(p_personagem, 20), personagem)
    where id = v_uid;
  return v_soma;
end $$;

-- trocar o nick (o que aparece no ranking); o usuário de entrar continua o mesmo
create or replace function public.bicho_trocar_apelido(p_apelido text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_apelido text := trim(coalesce(p_apelido, ''));
begin
  if v_uid is null then
    return 'sem_conta';
  end if;
  if char_length(v_apelido) not between 3 and 16 then
    return 'tamanho';
  end if;
  update public.bicho_perfis set apelido = v_apelido where id = v_uid;
  return 'ok';
exception when unique_violation then
  return 'existe';
end $$;

revoke all on function public.bicho_novo_perfil() from public, anon, authenticated;
revoke all on function public.bicho_registrar_recorde(integer, real, text) from public, anon;
revoke all on function public.bicho_somar_tempo(integer, text) from public, anon;
grant execute on function public.bicho_registrar_recorde(integer, real, text) to authenticated;
grant execute on function public.bicho_somar_tempo(integer, text) to authenticated;
revoke all on function public.bicho_trocar_apelido(text) from public, anon;
grant execute on function public.bicho_trocar_apelido(text) to authenticated;

-- o que o jogo lê pra montar o ranking
create or replace view public.bicho_rank_tempos with (security_invoker = true) as
  select r.fase, p.apelido, r.tempo, r.personagem, r.quando, r.user_id
  from public.bicho_recordes r join public.bicho_perfis p on p.id = r.user_id;
create or replace view public.bicho_rank_jogo with (security_invoker = true) as
  select p.apelido, p.tempo_jogo, p.personagem, p.id as user_id
  from public.bicho_perfis p where p.tempo_jogo > 0;
grant select on public.bicho_rank_tempos, public.bicho_rank_jogo to anon, authenticated;
