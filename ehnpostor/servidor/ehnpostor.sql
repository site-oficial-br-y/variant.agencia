-- EHNPOSTOR: servidor do modo online. Tudo passa por funções (as tabelas não têm acesso direto):
-- o sorteio da palavra e de quem é impostor fica aqui, e cada jogador só recebe o que é dele.
-- O jogo anda "sozinho": toda vez que alguém pede o estado, o servidor confere prazos e quedas.

create table if not exists public.ehn_salas (
  codigo text primary key,
  criado timestamptz not null default now(),
  mexido timestamptz not null default now(),
  fase text not null default 'sala',          -- sala, falando, discussao, votacao, revelacao, chute, fim
  config jsonb not null default '{"impostores":1,"dica":true,"tempo_vez":30,"tempo_disc":60,"tempo_voto":30,"chute":true,"categorias":[]}',
  palavra text, dica text, categoria text,
  rodada int not null default 0,
  vez text,
  primeiro int not null default 0,            -- assento de quem abriu a rodada
  prazo timestamptz,
  ult jsonb not null default '{}',            -- último acontecimento (votação, chute)
  vencedor text,
  partida int not null default 0
);
create table if not exists public.ehn_jogadores (
  sala text not null references public.ehn_salas (codigo) on delete cascade,
  id text not null,
  token text not null,
  nome text not null,
  boneco int not null default 0,
  assento int not null,
  jogando boolean not null default false,     -- está na partida atual (quem entra no meio assiste)
  vivo boolean not null default false,
  impostor boolean not null default false,
  host boolean not null default false,
  visto timestamptz not null default now(),
  voto text,
  emerg boolean not null default false,
  falas jsonb not null default '[]',
  ult_chat timestamptz,
  primary key (sala, id)
);
create unique index if not exists ehn_jogadores_token on public.ehn_jogadores (sala, token);
create table if not exists public.ehn_chat (
  id bigserial primary key,
  sala text not null references public.ehn_salas (codigo) on delete cascade,
  de text, tipo text not null, texto text not null, alvo text,
  morto boolean not null default false,
  quando timestamptz not null default now()
);
create index if not exists ehn_chat_sala on public.ehn_chat (sala, id);
create table if not exists public.ehn_palavras (
  categoria text not null, palavra text not null, dica text not null,
  primary key (categoria, palavra)
);
alter table public.ehn_salas enable row level security;
alter table public.ehn_jogadores enable row level security;
alter table public.ehn_chat enable row level security;
alter table public.ehn_palavras enable row level security;
revoke all on public.ehn_salas, public.ehn_jogadores, public.ehn_chat, public.ehn_palavras from anon, authenticated;

-- compara palavras sem acento, maiúscula, espaço ou pontuação
create or replace function public.ehn_norm(t text) returns text language sql immutable set search_path = public as $$
  select regexp_replace(translate(lower(coalesce(t, '')),
    'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'), '[^a-z0-9]', '', 'g')
$$;

create or replace function public._ehn_sis(p_sala text, p_texto text) returns void language sql set search_path = public as $$
  insert into public.ehn_chat (sala, de, tipo, texto) values (p_sala, null, 'sis', p_texto)
$$;

-- acabou? inocentes vencem sem impostor vivo; impostores vencem quando empatam em número
create or replace function public._ehn_vitoria(p_sala text) returns boolean language plpgsql set search_path = public as $$
declare imp int; ino int;
begin
  select count(*) filter (where impostor), count(*) filter (where not impostor) into imp, ino
    from public.ehn_jogadores where sala = p_sala and jogando and vivo;
  if imp = 0 then
    update public.ehn_salas set fase = 'fim', vencedor = 'inocentes', prazo = null, vez = null where codigo = p_sala;
    return true;
  elsif imp >= ino then
    update public.ehn_salas set fase = 'fim', vencedor = 'impostores', prazo = null, vez = null where codigo = p_sala;
    return true;
  end if;
  return false;
end $$;

create or replace function public._ehn_votacao(p_sala text) returns void language plpgsql set search_path = public as $$
declare s public.ehn_salas;
begin
  select * into s from public.ehn_salas where codigo = p_sala;
  update public.ehn_jogadores set voto = null, emerg = false where sala = p_sala;
  update public.ehn_salas set fase = 'votacao', vez = null,
    prazo = case when (s.config->>'tempo_voto')::int > 0 then now() + make_interval(secs => (s.config->>'tempo_voto')::int) else null end
    where codigo = p_sala;
end $$;

-- próximo vivo que ainda não falou nesta rodada; ninguém = acabou a rodada (discussão)
create or replace function public._ehn_passar(p_sala text) returns void language plpgsql set search_path = public as $$
declare s public.ehn_salas; atual int; prox text; td int;
begin
  select * into s from public.ehn_salas where codigo = p_sala;
  select assento into atual from public.ehn_jogadores where sala = p_sala and id = s.vez;
  atual := coalesce(atual, s.primeiro - 1);
  select id into prox from public.ehn_jogadores
    where sala = p_sala and jogando and vivo and jsonb_array_length(falas) < s.rodada
    order by (assento <= atual), assento limit 1;
  if prox is not null then
    update public.ehn_salas set vez = prox,
      prazo = case when (s.config->>'tempo_vez')::int > 0 then now() + make_interval(secs => (s.config->>'tempo_vez')::int) else null end
      where codigo = p_sala;
    return;
  end if;
  td := (s.config->>'tempo_disc')::int;
  if td > 0 then
    update public.ehn_salas set fase = 'discussao', vez = null, prazo = now() + make_interval(secs => td) where codigo = p_sala;
  else
    perform public._ehn_votacao(p_sala);
  end if;
end $$;

-- rodada nova (depois de uma votação que não acabou o jogo)
create or replace function public._ehn_rodada(p_sala text) returns void language plpgsql set search_path = public as $$
declare s public.ehn_salas; prim int;
begin
  if public._ehn_vitoria(p_sala) then return; end if;
  select * into s from public.ehn_salas where codigo = p_sala;
  select assento into prim from public.ehn_jogadores where sala = p_sala and jogando and vivo
    order by (assento <= s.primeiro), assento limit 1;
  update public.ehn_jogadores set voto = null, emerg = false where sala = p_sala;
  update public.ehn_salas set fase = 'falando', rodada = s.rodada + 1, primeiro = prim, vez = null where codigo = p_sala;
  perform public._ehn_passar(p_sala);                 -- sem "vez", começa no assento "primeiro"
end $$;

create or replace function public._ehn_apurar(p_sala text) returns void language plpgsql set search_path = public as $$
declare alvo text; n1 int; n2 int; eli text; era boolean := false; votos jsonb; empate boolean := false;
begin
  select coalesce(jsonb_object_agg(id, voto), '{}') into votos from public.ehn_jogadores where sala = p_sala and jogando and vivo and voto is not null;
  select voto, count(*) into alvo, n1 from public.ehn_jogadores where sala = p_sala and jogando and vivo and voto is not null
    group by voto order by count(*) desc, voto limit 1;
  select count(*) into n2 from public.ehn_jogadores where sala = p_sala and jogando and vivo and voto is not null and voto <> alvo
    group by voto order by count(*) desc limit 1;
  if alvo is not null and coalesce(n2, 0) = n1 then empate := true;
  elsif alvo is not null and alvo <> 'pular' then eli := alvo; end if;
  if eli is not null then
    update public.ehn_jogadores set vivo = false where sala = p_sala and id = eli returning impostor into era;
  end if;
  update public.ehn_salas set fase = 'revelacao', vez = null, prazo = now() + interval '8 seconds',
    ult = jsonb_build_object('tipo', 'voto', 'eliminado', eli, 'impostor', coalesce(era, false), 'votos', votos, 'empate', empate)
    where codigo = p_sala;
end $$;

-- confere prazos, quedas e troca de dono da sala
create or replace function public._ehn_tick(p_sala text) returns void language plpgsql set search_path = public as $$
declare s public.ehn_salas; j public.ehn_jogadores; novo text; caiu record; faltam int;
begin
  select * into s from public.ehn_salas where codigo = p_sala for update;
  if not found then return; end if;
  if not exists (select 1 from public.ehn_jogadores where sala = p_sala and host and visto > now() - interval '12 seconds') then
    select id into novo from public.ehn_jogadores where sala = p_sala and visto > now() - interval '6 seconds' order by assento limit 1;
    if novo is not null then
      update public.ehn_jogadores set host = (id = novo) where sala = p_sala;
    end if;
  end if;
  if s.fase = 'sala' then
    delete from public.ehn_jogadores where sala = p_sala and visto < now() - interval '25 seconds';
    return;
  end if;
  if s.fase = 'fim' then return; end if;
  for caiu in select id, nome from public.ehn_jogadores where sala = p_sala and jogando and vivo and visto < now() - interval '75 seconds' loop
    update public.ehn_jogadores set vivo = false where sala = p_sala and id = caiu.id;
    perform public._ehn_sis(p_sala, caiu.nome || ' caiu e saiu da partida');
  end loop;
  if s.fase in ('falando', 'discussao', 'votacao') and public._ehn_vitoria(p_sala) then return; end if;
  if s.fase = 'falando' then
    select * into j from public.ehn_jogadores where sala = p_sala and id = s.vez;
    if not found or not j.vivo or j.visto < now() - interval '10 seconds' or (s.prazo is not null and s.prazo < now()) then
      if found and j.vivo then
        update public.ehn_jogadores set falas = falas || '"—"'::jsonb where sala = p_sala and id = j.id;
      end if;
      perform public._ehn_passar(p_sala);
    end if;
  elsif s.fase = 'discussao' then
    if s.prazo is not null and s.prazo < now() then perform public._ehn_votacao(p_sala); end if;
  elsif s.fase = 'votacao' then
    select count(*) into faltam from public.ehn_jogadores where sala = p_sala and jogando and vivo and voto is null and visto > now() - interval '10 seconds';
    if faltam = 0 or (s.prazo is not null and s.prazo < now()) then perform public._ehn_apurar(p_sala); end if;
  elsif s.fase = 'revelacao' then
    if s.prazo < now() then
      if (s.ult->>'eliminado') is not null and (s.ult->>'impostor')::boolean and (s.config->>'chute')::boolean then
        update public.ehn_salas set fase = 'chute', vez = s.ult->>'eliminado', prazo = now() + interval '25 seconds' where codigo = p_sala;
      else
        perform public._ehn_rodada(p_sala);
      end if;
    end if;
  elsif s.fase = 'chute' then
    if s.prazo < now() or not exists (select 1 from public.ehn_jogadores where sala = p_sala and id = s.vez and visto > now() - interval '10 seconds') then
      update public.ehn_salas set ult = ult || '{"chute":"","acertou":false}'::jsonb where codigo = p_sala;
      perform public._ehn_rodada(p_sala);
    end if;
  end if;
end $$;

create or replace function public._ehn_eu(p_codigo text, p_token text) returns public.ehn_jogadores language sql set search_path = public as $$
  select * from public.ehn_jogadores where sala = upper(p_codigo) and token = p_token
$$;

create or replace function public.ehn_criar(p_nome text, p_boneco int, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare c text; letras text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; meu text;
begin
  if length(coalesce(p_token, '')) < 16 then return jsonb_build_object('erro', 'token'); end if;
  delete from public.ehn_salas where mexido < now() - interval '6 hours';
  loop
    c := '';
    for i in 1..4 loop c := c || substr(letras, 1 + floor(random() * length(letras))::int, 1); end loop;
    exit when not exists (select 1 from public.ehn_salas where codigo = c);
  end loop;
  meu := substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.ehn_salas (codigo) values (c);
  insert into public.ehn_jogadores (sala, id, token, nome, boneco, assento, host)
    values (c, meu, p_token, left(coalesce(nullif(trim(p_nome), ''), 'Jogador'), 14), greatest(0, least(15, coalesce(p_boneco, 0))), 0, true);
  return jsonb_build_object('codigo', c, 'id', meu);
end $$;

create or replace function public.ehn_entrar(p_codigo text, p_nome text, p_boneco int, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare c text := upper(trim(p_codigo)); j public.ehn_jogadores; n int; seat int; b int; meu text; s public.ehn_salas;
begin
  if length(coalesce(p_token, '')) < 16 then return jsonb_build_object('erro', 'token'); end if;
  select * into s from public.ehn_salas where codigo = c for update;
  if not found then return jsonb_build_object('erro', 'nao_existe'); end if;
  select * into j from public.ehn_jogadores where sala = c and token = p_token;
  if found then
    update public.ehn_jogadores set visto = now() where sala = c and id = j.id;
    return jsonb_build_object('codigo', c, 'id', j.id);
  end if;
  select count(*) into n from public.ehn_jogadores where sala = c;
  if n >= 8 then return jsonb_build_object('erro', 'cheia'); end if;
  select g into seat from generate_series(0, 7) g where g not in (select assento from public.ehn_jogadores where sala = c) order by g limit 1;
  b := greatest(0, least(15, coalesce(p_boneco, 0)));
  if exists (select 1 from public.ehn_jogadores where sala = c and boneco = b) then
    select g into b from generate_series(0, 15) g where g not in (select boneco from public.ehn_jogadores where sala = c) order by random() limit 1;
  end if;
  meu := substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.ehn_jogadores (sala, id, token, nome, boneco, assento)
    values (c, meu, p_token, left(coalesce(nullif(trim(p_nome), ''), 'Jogador'), 14), b, seat);
  update public.ehn_salas set mexido = now() where codigo = c;
  return jsonb_build_object('codigo', c, 'id', meu);
end $$;

create or replace function public.ehn_perfil(p_codigo text, p_token text, p_nome text, p_boneco int) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null then return jsonb_build_object('erro', 'fora'); end if;
  if p_boneco is not null and exists (select 1 from public.ehn_jogadores where sala = j.sala and boneco = p_boneco and id <> j.id) then
    return jsonb_build_object('erro', 'boneco_em_uso');
  end if;
  update public.ehn_jogadores set nome = left(coalesce(nullif(trim(p_nome), ''), nome), 14),
    boneco = greatest(0, least(15, coalesce(p_boneco, boneco))) where sala = j.sala and id = j.id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_config(p_codigo text, p_token text, p_config jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; c jsonb;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or not j.host then return jsonb_build_object('erro', 'so_o_dono'); end if;
  if (select fase from public.ehn_salas where codigo = j.sala) <> 'sala' then return jsonb_build_object('erro', 'em_jogo'); end if;
  c := jsonb_build_object(
    'impostores', greatest(1, least(3, coalesce((p_config->>'impostores')::int, 1))),
    'dica', coalesce((p_config->>'dica')::boolean, true),
    'chute', coalesce((p_config->>'chute')::boolean, true),
    'tempo_vez', greatest(0, least(120, coalesce((p_config->>'tempo_vez')::int, 30))),
    'tempo_disc', greatest(0, least(300, coalesce((p_config->>'tempo_disc')::int, 60))),
    'tempo_voto', greatest(10, least(120, coalesce((p_config->>'tempo_voto')::int, 30))),
    'categorias', coalesce(p_config->'categorias', '[]'::jsonb));
  update public.ehn_salas set config = c, mexido = now() where codigo = j.sala;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_iniciar(p_codigo text, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; n int; k int; w record; prim int;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or not j.host then return jsonb_build_object('erro', 'so_o_dono'); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase <> 'sala' then return jsonb_build_object('erro', 'em_jogo'); end if;
  delete from public.ehn_jogadores where sala = j.sala and visto < now() - interval '12 seconds' and id <> j.id;
  select count(*) into n from public.ehn_jogadores where sala = j.sala;
  if n < 3 then return jsonb_build_object('erro', 'poucos'); end if;
  k := least((s.config->>'impostores')::int, greatest(1, (n - 1) / 2));
  select categoria, palavra, dica into w from public.ehn_palavras
    where jsonb_array_length(s.config->'categorias') = 0 or categoria in (select jsonb_array_elements_text(s.config->'categorias'))
    order by random() limit 1;
  if w.palavra is null then select categoria, palavra, dica into w from public.ehn_palavras order by random() limit 1; end if;
  update public.ehn_jogadores set jogando = true, vivo = true, impostor = false, voto = null, emerg = false, falas = '[]' where sala = j.sala;
  update public.ehn_jogadores set impostor = true where sala = j.sala and id in
    (select id from public.ehn_jogadores where sala = j.sala order by random() limit k);
  select assento into prim from public.ehn_jogadores where sala = j.sala order by random() limit 1;
  delete from public.ehn_chat where sala = j.sala;
  update public.ehn_salas set fase = 'falando', palavra = w.palavra, dica = w.dica, categoria = w.categoria, rodada = 1,
    primeiro = prim, vez = null, ult = '{}', vencedor = null, partida = partida + 1, mexido = now() where codigo = j.sala;
  perform public._ehn_passar(j.sala);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_falar(p_codigo text, p_token text, p_palavra text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; t text := trim(coalesce(p_palavra, '')); nn text;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null then return jsonb_build_object('erro', 'fora'); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase <> 'falando' or s.vez <> j.id or not j.vivo then return jsonb_build_object('erro', 'nao_e_sua_vez'); end if;
  nn := public.ehn_norm(t);
  if length(nn) < 2 or length(t) > 18 then return jsonb_build_object('erro', 'tamanho'); end if;
  if t ~ '\s' then return jsonb_build_object('erro', 'uma_palavra'); end if;
  if not j.impostor and (nn = public.ehn_norm(s.palavra)) then return jsonb_build_object('erro', 'secreta'); end if;
  if exists (select 1 from public.ehn_jogadores q, jsonb_array_elements_text(q.falas) f where q.sala = j.sala and public.ehn_norm(f) = nn) then
    return jsonb_build_object('erro', 'repetida');
  end if;
  update public.ehn_jogadores set falas = falas || to_jsonb(t) where sala = j.sala and id = j.id;
  perform public._ehn_passar(j.sala);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_emergencia(p_codigo text, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; pedem int; vivos int;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or not j.vivo or not j.jogando then return jsonb_build_object('erro', 'fora'); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase not in ('falando', 'discussao') then return jsonb_build_object('erro', 'agora_nao'); end if;
  update public.ehn_jogadores set emerg = not emerg where sala = j.sala and id = j.id;
  select count(*) filter (where emerg), count(*) into pedem, vivos from public.ehn_jogadores where sala = j.sala and jogando and vivo;
  if pedem * 2 > vivos then
    perform public._ehn_sis(j.sala, 'VOTAÇÃO DE EMERGÊNCIA!');
    perform public._ehn_votacao(j.sala);
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_votar(p_codigo text, p_token text, p_alvo text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or not j.vivo or not j.jogando then return jsonb_build_object('erro', 'fora'); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase <> 'votacao' then return jsonb_build_object('erro', 'agora_nao'); end if;
  if p_alvo <> 'pular' and (p_alvo = j.id or not exists (select 1 from public.ehn_jogadores where sala = j.sala and id = p_alvo and jogando and vivo)) then
    return jsonb_build_object('erro', 'alvo');
  end if;
  update public.ehn_jogadores set voto = p_alvo where sala = j.sala and id = j.id;
  perform public._ehn_tick(j.sala);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_chutar(p_codigo text, p_token text, p_palavra text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; ok boolean;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null then return jsonb_build_object('erro', 'fora'); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase <> 'chute' or s.vez <> j.id then return jsonb_build_object('erro', 'agora_nao'); end if;
  ok := public.ehn_norm(p_palavra) = public.ehn_norm(s.palavra);
  update public.ehn_salas set ult = ult || jsonb_build_object('chute', left(trim(p_palavra), 24), 'acertou', ok) where codigo = j.sala;
  if ok then
    update public.ehn_salas set fase = 'fim', vencedor = 'impostores', prazo = null, vez = null where codigo = j.sala;
  else
    perform public._ehn_rodada(j.sala);
  end if;
  return jsonb_build_object('ok', true, 'acertou', ok);
end $$;

create or replace function public.ehn_denovo(p_codigo text, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or not j.host then return jsonb_build_object('erro', 'so_o_dono'); end if;
  update public.ehn_salas set fase = 'sala', vez = null, prazo = null, vencedor = null, ult = '{}', palavra = null, dica = null, rodada = 0, mexido = now()
    where codigo = j.sala and fase = 'fim';
  update public.ehn_jogadores set jogando = false, vivo = false, impostor = false, voto = null, emerg = false, falas = '[]' where sala = j.sala;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.ehn_sair(p_codigo text, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null then return jsonb_build_object('ok', true); end if;
  select * into s from public.ehn_salas where codigo = j.sala for update;
  if s.fase in ('sala', 'fim') or not j.jogando then
    delete from public.ehn_jogadores where sala = j.sala and id = j.id;
  else
    update public.ehn_jogadores set vivo = false, host = false, visto = now() - interval '1 hour', token = token || ':saiu' where sala = j.sala and id = j.id;
    perform public._ehn_sis(j.sala, j.nome || ' saiu da partida');
    perform public._ehn_tick(j.sala);
  end if;
  if not exists (select 1 from public.ehn_jogadores where sala = j.sala and visto > now() - interval '2 minutes') then
    delete from public.ehn_salas where codigo = j.sala;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- chat (só na discussão/votação pra quem está vivo; eliminados conversam só entre si) e emotes
create or replace function public.ehn_dizer(p_codigo text, p_token text, p_tipo text, p_texto text, p_alvo text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; t text := left(trim(coalesce(p_texto, '')), 120); fantasma boolean;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null or t = '' or p_tipo not in ('msg', 'emo') then return jsonb_build_object('erro', 'fora'); end if;
  if j.ult_chat is not null and j.ult_chat > now() - interval '500 milliseconds' then return jsonb_build_object('erro', 'calma'); end if;
  select * into s from public.ehn_salas where codigo = j.sala;
  fantasma := s.fase not in ('sala', 'fim') and not (j.jogando and j.vivo);
  if p_tipo = 'msg' and not fantasma and s.fase in ('falando', 'chute') then return jsonb_build_object('erro', 'chat_fechado'); end if;
  if p_tipo = 'msg' and not fantasma and s.fase not in ('sala', 'fim') and public.ehn_norm(t) like '%' || public.ehn_norm(s.palavra) || '%' and not j.impostor then
    return jsonb_build_object('erro', 'secreta');
  end if;
  update public.ehn_jogadores set ult_chat = now() where sala = j.sala and id = j.id;
  insert into public.ehn_chat (sala, de, tipo, texto, alvo, morto) values (j.sala, j.id, p_tipo, t, p_alvo, fantasma);
  return jsonb_build_object('ok', true);
end $$;

-- estado da sala do ponto de vista de UM jogador (só a palavra/dica dele)
create or replace function public.ehn_estado(p_codigo text, p_token text, p_desde bigint default 0) returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.ehn_jogadores; s public.ehn_salas; fim boolean; fantasma boolean; js jsonb; ch jsonb;
begin
  j := public._ehn_eu(p_codigo, p_token);
  if j.id is null then return jsonb_build_object('erro', 'fora'); end if;
  if j.visto < now() - interval '2 seconds' then
    update public.ehn_jogadores set visto = now() where sala = j.sala and id = j.id;
  end if;
  perform public._ehn_tick(j.sala);
  select * into s from public.ehn_salas where codigo = j.sala;
  j := public._ehn_eu(p_codigo, p_token);
  fim := s.fase in ('fim', 'sala');
  fantasma := not fim and not (j.jogando and j.vivo);
  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'nome', q.nome, 'boneco', q.boneco, 'assento', q.assento, 'jogando', q.jogando,
      'vivo', q.vivo, 'host', q.host, 'on', q.visto > now() - interval '8 seconds', 'falas', q.falas,
      'votou', q.voto is not null and s.fase = 'votacao', 'emerg', q.emerg,
      'impostor', case when s.fase = 'fim' or (q.jogando and not q.vivo) then q.impostor else null end) order by q.assento), '[]')
    into js from public.ehn_jogadores q where q.sala = j.sala;
  select coalesce(jsonb_agg(x order by (x->>'id')::bigint), '[]') into ch from (
    select jsonb_build_object('id', c.id, 'de', c.de, 'tipo', c.tipo, 'texto', c.texto, 'alvo', c.alvo, 'morto', c.morto) x
    from public.ehn_chat c where c.sala = j.sala and c.id > p_desde and (not c.morto or fantasma or fim)
    order by c.id desc limit 40) z;
  return jsonb_build_object(
    'agora', (extract(epoch from now()) * 1000)::bigint,
    'sala', jsonb_build_object('codigo', s.codigo, 'fase', s.fase, 'config', s.config, 'rodada', s.rodada, 'vez', s.vez,
      'prazo', case when s.prazo is null then null else (extract(epoch from s.prazo) * 1000)::bigint end,
      'ult', s.ult, 'vencedor', s.vencedor, 'partida', s.partida, 'categoria', s.categoria,
      'palavra', case when s.fase = 'fim' then s.palavra else null end),
    'eu', jsonb_build_object('id', j.id, 'host', j.host, 'jogando', j.jogando, 'vivo', j.vivo, 'impostor', j.impostor,
      'voto', j.voto,
      'palavra', case when j.jogando and not j.impostor then s.palavra else null end,
      'dica', case when j.jogando and j.impostor and (s.config->>'dica')::boolean then s.dica else null end),
    'jogadores', js, 'chat', ch);
end $$;

revoke all on function public._ehn_sis(text, text), public._ehn_vitoria(text), public._ehn_votacao(text), public._ehn_passar(text),
  public._ehn_rodada(text), public._ehn_apurar(text), public._ehn_tick(text), public._ehn_eu(text, text) from public, anon, authenticated;
grant execute on function public.ehn_criar(text, int, text), public.ehn_entrar(text, text, int, text), public.ehn_perfil(text, text, text, int),
  public.ehn_config(text, text, jsonb), public.ehn_iniciar(text, text), public.ehn_falar(text, text, text), public.ehn_emergencia(text, text),
  public.ehn_votar(text, text, text), public.ehn_chutar(text, text, text), public.ehn_denovo(text, text), public.ehn_sair(text, text),
  public.ehn_dizer(text, text, text, text, text), public.ehn_estado(text, text, bigint) to anon, authenticated;
