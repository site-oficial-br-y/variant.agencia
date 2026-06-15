# Honk Ponk (honkponk.com.br)

SaaS B2B de prospecção de leads. O usuário escolhe um tipo de serviço + cidade (ou "Todo o Brasil"), e o site retorna empresas que provavelmente precisam desse serviço, com contatos prontos (WhatsApp, Instagram, telefone, site).

## Stack

- Next.js 14.2.5 (App Router) + TypeScript, no diretório `honkponk-app/`
- Supabase: autenticação + banco Postgres (RLS ativado em todas as tabelas)
- Mercado Pago: pagamentos/assinaturas
- Google Places API: busca dos leads
- Deploy: Vercel (branch `main` = produção)
- E-mail transacional (reset de senha): Resend configurado como SMTP no Supabase

## Identidade visual

- Fundo escuro: `#0f0f1a`
- Cor principal (rosa/magenta): gradiente `#e879a0` → `#c2185b`
- Texto claro: branco com opacidades (`rgba(255,255,255,.4-.7)`)
- Acentos: verde `#4ade80` (positivo/ativo), laranja `#fb923c`/`#fbbf24` (aviso)
- Tipografia: Inter / sans-serif, títulos bem bold (800-900), letter-spacing negativo nos headings
- Cards com `border-radius` grande (16-20px), bordas sutis em rosa translúcido, sombras suaves no hover

## Planos (src/lib/plans.ts)

| Plano | Preço/mês | Principais limites |
|---|---|---|
| Grátis | R$0 | 1 busca/dia, 5 leads, sem todos os contatos |
| Freelancer | R$19,90 | 10 buscas/dia, resultados ilimitados, todos os contatos |
| Agência | R$59,90 | buscas ilimitadas, exporta Excel |
| Empresa | R$99,90 | tudo da Agência + até 5 usuários (equipe) + suporte dedicado |

## Decisões importantes já tomadas

- **Confirmação de e-mail no cadastro foi removida** — signup loga direto, sem depender de envio de e-mail (evita limite de e-mail do Supabase free).
- **Ativação de plano é só via webhook do Mercado Pago** (service_role key, ignora RLS). O front-end NÃO atualiza `plan` diretamente — isso foi removido do `checkout/success` por ser uma brecha de segurança (usuário podia se "promover" de graça).
- **RLS ativado** em `users_profiles`, `team_members`, `subscriptions`, `search_logs` — cada usuário só vê/edita os próprios dados.
- **Plano Empresa tem gestão de equipe**: dono convida até 4 e-mails (`team_members`), e quando essa pessoa loga, o sistema ativa o plano Empresa automaticamente pra ela (ver `dashboard/page.tsx`).
- **Validação de e-mail no cadastro**: checa se o domínio do e-mail tem MX record válido (`/api/validate-email`) — não verifica a caixa específica, só domínios inventados/temporários.
- **Busca "Todo o Brasil"** intercala resultados de 10 cidades grandes (SP, RJ, BH, Porto Alegre, Salvador, Fortaleza, Recife, Brasília, Belém, Manaus) pra dar mais variedade geográfica.

## Marketing / parcerias

- Estratégia: oferecer acesso gratuito a planos (geralmente Agência) em troca de divulgação (vídeo no TikTok/Instagram mostrando o uso real da plataforma).
- Liberação manual de plano de cortesia: rodar SQL direto no Supabase (`update users_profiles set plan = 'X' where email = '...'`), pois não há painel admin pra isso ainda.

## Segurança — chave do Supabase

- A `SUPABASE_SERVICE_ROLE_KEY` foi exposta uma vez numa conversa antiga (print de tela). Decisão: **não rotacionar** (rotacionar exige regenerar o JWT secret, derruba todas as sessões e invalida a anon key — risco maior que o benefício, dado que o banco não tem dados de cartão). Risco aceito como baixo.

## Convenções de código

- Estilo inline (`style={{...}}`) em todos os componentes, sem CSS Modules/Tailwind nas páginas principais (Tailwind está configurado mas pouco usado)
- Tom do site: em português, casual mas profissional
- Sem comentários desnecessários no código
