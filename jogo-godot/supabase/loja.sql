-- Bicho Ehn: loja de skins (Pix), inventário e pedidos.
-- Rodar no Supabase: SQL Editor > New query > colar tudo > Run. Pode rodar de novo (não apaga nada).
-- Precisa do ranking.sql antes (usa a tabela bicho_perfis).

create extension if not exists pg_net with schema extensions;

-- o que está à venda (o preço que vale é o daqui, não o do jogo)
create table if not exists public.bicho_itens (
  item text primary key,
  personagem text not null,
  nome text not null,
  raridade text not null check (raridade in ('comum', 'epico', 'lendario')),
  preco numeric(6, 2) not null check (preco > 0),
  ativo boolean not null default true,
  ordem smallint not null default 0
);
insert into public.bicho_itens (item, personagem, nome, raridade, preco, ativo, ordem) values
  ('monociclo_folhas', 'monociclo', 'Folhas', 'comum', 5.90, true, 1),
  ('cadeira_zumbi', 'cadeira', 'Zumbi', 'comum', 5.90, true, 2),
  ('caio_santos', 'caio', 'Santos', 'epico', 9.90, true, 3),
  ('chefe_creta', 'chefe', 'Creta', 'epico', 9.90, false, 4),
  ('lima_dourado', 'lima', 'Gorila Dourado', 'lendario', 19.90, false, 5)
on conflict (item) do update set personagem = excluded.personagem, nome = excluded.nome,
  raridade = excluded.raridade, preco = excluded.preco, ordem = excluded.ordem;

create table if not exists public.bicho_inventario (
  user_id uuid not null references public.bicho_perfis (id) on delete cascade,
  item text not null references public.bicho_itens (item),
  quando timestamptz not null default now(),
  primary key (user_id, item)
);

create table if not exists public.bicho_pedidos (
  id bigserial primary key,
  codigo text not null unique,
  user_id uuid not null references public.bicho_perfis (id) on delete cascade,
  item text not null references public.bicho_itens (item),
  valor numeric(6, 2) not null,
  status text not null default 'aguardando' check (status in ('aguardando', 'pago', 'cancelado')),
  criado_em timestamptz not null default now(),
  pago_em timestamptz
);

-- quem confirma pagamento (o dono do jogo: conta vinirei)
create table if not exists public.bicho_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
insert into public.bicho_admins (user_id)
select id from auth.users where email = 'vinirei@bicho.honkponk.com.br'
on conflict do nothing;

alter table public.bicho_itens enable row level security;
alter table public.bicho_inventario enable row level security;
alter table public.bicho_pedidos enable row level security;
alter table public.bicho_admins enable row level security;
drop policy if exists "todos veem" on public.bicho_itens;
create policy "todos veem" on public.bicho_itens for select using (true);
drop policy if exists "dono ve" on public.bicho_inventario;
create policy "dono ve" on public.bicho_inventario for select using (user_id = auth.uid());
drop policy if exists "dono ve" on public.bicho_pedidos;
create policy "dono ve" on public.bicho_pedidos for select using (user_id = auth.uid());
grant select on public.bicho_itens to anon, authenticated;
grant select on public.bicho_inventario, public.bicho_pedidos to authenticated;
revoke insert, update, delete on public.bicho_itens, public.bicho_inventario, public.bicho_pedidos, public.bicho_admins
  from anon, authenticated;
revoke all on public.bicho_admins from anon, authenticated;

-- pedido novo: devolve código e valor pro jogo montar o Pix (pedido igual em aberto é reaproveitado)
create or replace function public.bicho_criar_pedido(p_item text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_preco numeric(6, 2);
  v_codigo text;
  v_letras text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if v_uid is null then
    return jsonb_build_object('erro', 'sem_conta');
  end if;
  select preco into v_preco from public.bicho_itens where item = p_item and ativo;
  if not found then
    return jsonb_build_object('erro', 'item');
  end if;
  if exists (select 1 from public.bicho_inventario where user_id = v_uid and item = p_item) then
    return jsonb_build_object('erro', 'ja_tem');
  end if;
  select codigo into v_codigo from public.bicho_pedidos
    where user_id = v_uid and item = p_item and status = 'aguardando';
  if found then
    return jsonb_build_object('codigo', v_codigo, 'valor', v_preco, 'item', p_item);
  end if;
  loop
    v_codigo := '';
    for i in 1..5 loop
      v_codigo := v_codigo || substr(v_letras, 1 + floor(random() * length(v_letras))::int, 1);
    end loop;
    begin
      insert into public.bicho_pedidos (codigo, user_id, item, valor) values (v_codigo, v_uid, p_item, v_preco);
      exit;
    exception when unique_violation then
      null;                                       -- código repetido: sorteia outro
    end;
  end loop;
  return jsonb_build_object('codigo', v_codigo, 'valor', v_preco, 'item', p_item);
end $$;

create or replace function public.bicho_sou_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.bicho_admins where user_id = auth.uid());
$$;

-- só o dono: pedidos esperando confirmação
create or replace function public.bicho_pedidos_abertos()
returns table (codigo text, apelido text, item text, nome text, valor numeric, criado_em timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.bicho_admins where user_id = auth.uid()) then
    return;
  end if;
  return query
    select p.codigo, f.apelido, p.item, i.nome, p.valor, p.criado_em
    from public.bicho_pedidos p
    join public.bicho_perfis f on f.id = p.user_id
    join public.bicho_itens i on i.item = p.item
    where p.status = 'aguardando'
    order by p.criado_em desc;
end $$;

-- só o dono: confirma (libera o item) ou cancela
create or replace function public.bicho_resolver_pedido(p_codigo text, p_pago boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ped public.bicho_pedidos;
begin
  if not exists (select 1 from public.bicho_admins where user_id = auth.uid()) then
    return 'sem_permissao';
  end if;
  select * into v_ped from public.bicho_pedidos where codigo = upper(p_codigo) and status = 'aguardando' for update;
  if not found then
    return 'nao_achou';
  end if;
  if p_pago then
    update public.bicho_pedidos set status = 'pago', pago_em = now() where id = v_ped.id;
    insert into public.bicho_inventario (user_id, item) values (v_ped.user_id, v_ped.item) on conflict do nothing;
    return 'pago';
  end if;
  update public.bicho_pedidos set status = 'cancelado' where id = v_ped.id;
  return 'cancelado';
end $$;

-- aviso no celular do dono (app ntfy, canal abaixo) a cada pedido novo
create or replace function public.bicho_avisar_pedido() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_apelido text;
  v_nome text;
begin
  select apelido into v_apelido from public.bicho_perfis where id = new.user_id;
  select nome into v_nome from public.bicho_itens where item = new.item;
  begin
    perform net.http_post(
      url := 'https://ntfy.sh/',
      body := jsonb_build_object(
        'topic', 'bichoehn-f9df21ad31',
        'title', 'Pedido novo no Bicho Ehn',
        'message', coalesce(v_apelido, '?') || ' quer ' || coalesce(v_nome, new.item) || ' (R$ '
                   || replace(to_char(new.valor, 'FM990.00'), '.', ',') || ') - código ' || new.codigo,
        'tags', jsonb_build_array('moneybag')));
  exception when others then
    null;                                         -- aviso falhou: o pedido continua valendo
  end;
  return new;
end $$;
drop trigger if exists bicho_avisar_pedido on public.bicho_pedidos;
create trigger bicho_avisar_pedido after insert on public.bicho_pedidos
  for each row execute function public.bicho_avisar_pedido();

revoke all on function public.bicho_criar_pedido(text) from public, anon;
revoke all on function public.bicho_sou_admin() from public, anon;
revoke all on function public.bicho_pedidos_abertos() from public, anon;
revoke all on function public.bicho_resolver_pedido(text, boolean) from public, anon;
revoke all on function public.bicho_avisar_pedido() from public, anon, authenticated;
grant execute on function public.bicho_criar_pedido(text) to authenticated;
grant execute on function public.bicho_sou_admin() to authenticated;
grant execute on function public.bicho_pedidos_abertos() to authenticated;
grant execute on function public.bicho_resolver_pedido(text, boolean) to authenticated;
