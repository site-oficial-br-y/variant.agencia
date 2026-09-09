-- Registro de chamadas REAIS ao Google.
--
-- Por que existe: o painel estimava custo contando linhas de `search_logs`, que
-- grava toda busca do usuário. Só que a maioria das buscas é respondida pelo
-- cache e nunca chega no Google, então aquilo contava busca, não chamada paga.
-- Com 29 assinantes buscando as mesmas cidades, o erro chegou a mais de 20x.
--
-- Aqui só entra linha quando a requisição de fato sai para o Google.

create table if not exists public.api_calls (
  id bigserial primary key,
  provider text not null check (provider in ('places', 'geocode')),
  created_at timestamptz not null default now()
);

create index if not exists api_calls_created_at_idx on public.api_calls (created_at);

-- Sem policy nenhuma: só a service_role (webhook e painel admin) enxerga.
alter table public.api_calls enable row level security;
