-- ranking mostra o nível: as views passam a expor o XP de cada jogador
create or replace view public.bicho_rank_jogo as
  select p.apelido, p.tempo_jogo, p.personagem, p.id as user_id, p.xp
  from public.bicho_perfis p where p.tempo_jogo > 0;
create or replace view public.bicho_rank_tempos as
  select r.fase, p.apelido, r.tempo, r.personagem, r.quando, r.user_id, p.xp
  from public.bicho_recordes r join public.bicho_perfis p on p.id = r.user_id;
