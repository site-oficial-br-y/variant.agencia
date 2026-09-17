-- Fecha o vazamento de Honk Coins causado por notificação repetida do Mercado Pago.
-- Rodar no SQL Editor do Supabase, na ordem, de cima pra baixo.
-- O passo 3 falha se ainda existir duplicata, então o 2 vem antes.

-- 1. Confere o estrago: lista os pagamentos que entraram mais de uma vez.
select mp_payment_id, email, coins, count(*) as vezes
from coin_purchases
where mp_payment_id is not null
group by mp_payment_id, email, coins
having count(*) > 1
order by vezes desc;

-- 2. Apaga as repetidas, mantendo a linha mais antiga de cada pagamento.
delete from coin_purchases a
using coin_purchases b
where a.mp_payment_id is not null
  and a.mp_payment_id = b.mp_payment_id
  and a.ctid > b.ctid;

-- 3. Tranca: o mesmo pagamento não entra duas vezes nunca mais.
-- Índice parcial porque linhas antigas sem mp_payment_id podem existir.
create unique index if not exists coin_purchases_mp_payment_id_key
  on coin_purchases (mp_payment_id)
  where mp_payment_id is not null;

-- 4. Confere que ficou limpo: tem que voltar zero linha.
select mp_payment_id, count(*)
from coin_purchases
where mp_payment_id is not null
group by mp_payment_id
having count(*) > 1;
