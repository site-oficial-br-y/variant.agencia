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

## Preferências do dono

- **Sempre que o assunto Honk Ponk aparecer no início de uma conversa, mandar o link do painel admin: `honkponk.com.br/admin`** (precisa estar logado com o e-mail que está em `ADMIN_EMAILS`). O painel lê Supabase e Mercado Pago em tempo real: MRR, total recebido, custo estimado do Google e histórico de pagamentos.

## Sites para clientes (preferências fixas do dono)

- **Nunca fundo preto chapado.** O fundo tem que ser vivo: animado, reagindo ao cursor e à rolagem.
- **A paleta é escolhida por projeto**, combinando com o negócio do cliente. Não existe cor fixa para todo site. (Preto e vermelho foi a escolha da Alves Estética Automotiva, não um padrão.)
- **Muita animação e transição.** Revelação por rolagem, movimento no hover, transição entre seções.
- **O layout é feito em volta de fotos reais.** Reservar espaço generoso e bem enquadrado para imagem de verdade desde o começo, em vez de encher a tela de caixa colorida, ícone e gradiente. Quando a foto ainda não existe, deixar o espaço marcado e pronto para receber o arquivo.
- **Não pode ter cara de IA.** Evitar layout todo centralizado e simétrico, grade de cards iguais, gradiente roxo/azul, emoji, vidro fosco em tudo e texto genérico. Preferir layout editorial assimétrico, texto específico e concreto, tipografia com contraste forte de tamanho, textura sutil.

## Como construir site de cliente (método que funciona)

1. **Pedir antes de começar:** uma referência visual, as fotos e a lista de serviços com preço. Quando o dono manda tudo junto, o site sai quase de primeira; quando falta, cada ida e volta custa uma rodada.
2. **Renderizar e olhar.** Existe Chromium neste ambiente. Abrir o resultado, tirar print e conferir antes de entregar acha mais defeito do que reler o código.
3. **Entregar arquivo único.** Fontes e imagens embutidas em base64, porque o dono baixa o HTML e abre no celular na frente do cliente, sem pasta e às vezes sem internet.

### Técnicas que deram certo

- **Logo sobre fundo preto:** gerar PNG com transparência calculada pelo brilho de cada pixel (`alpha = luminância`). `mix-blend-mode: screen` falha dentro de cabeçalho fixo, porque o `z-index` cria camada isolada e não há fundo com que misturar.
- **Foto que não combina com a marca:** duotone. Mapear o brilho numa rampa feita só com as cores do site. A foto deixa de ter cor própria e passa a ser da mesma casa. De quebra o arquivo encolhe.
- **Borda de foto:** dissolver com máscara radial em vez de cortar reto, e sangrar a imagem até a borda da tela do lado que não dá para mascarar.
- **Emenda entre seções de cor diferente:** faixa de degradê no topo da seção seguinte (não no fim da anterior, que não cobre fundo animado clipado).
- **Cardápio grande:** filtro por categoria, busca por nome, exibição em blocos com botão de ver mais, e imagem carregada só quando chega perto da tela.

### Armadilhas já pagas (não repetir)

- **Dá para testar em largura de celular de verdade**, ao contrário do que estava anotado aqui antes. O truque é definir o viewport na criação da página (`browser.newPage({viewport:{width:390,height:844}, isMobile:true})`), e não com `setViewportSize` depois — aí o `window.innerWidth` é 390 mesmo. Conferir isso no próprio teste antes de confiar no print.
- **Print pega animação no meio.** Para fotografar é preciso desligar a revelação por rolagem. **Conferir o restauro com `git diff` antes de commitar** — eu já commitei a gambiarra por engano.
- **`grid-template-columns: 1fr` estoura o container** quando o conteúdo é largo: usar `minmax(0,1fr)`.
- **Elemento posicionado com `z-index:0` pinta acima de conteúdo não posicionado.** Faixa de degradê cobriu texto por isso.
- **Regra de display vence `[hidden]`.** Precisa de `[hidden]{display:none!important}`.
- **Máscara radial maior que a própria caixa não dissolve nada**, porque a parte transparente cai fora da área visível.
- **Véu escuro sobre foto precisa de `z-index`** se a imagem já tiver um, senão fica atrás dela e o texto some.
- **Supabase corta cada leitura em 1.000 linhas** e `.limit()` não passa por cima: tem que paginar com `range()`.
- **Ranking montado a partir da tabela de perfis some com quem não tem perfil.** No ZEBRA a
  conta do dono jogou sete partidas, todas gravadas, e nunca apareceu: faltava a linha dele em
  `zebra_perfis`, e o `left join` do ranking parte dos perfis. Conta criada antes do gatilho que
  cria o perfil junto fica órfã e desaparece calada. Antes de culpar a gravação, comparar
  `select count(*) from <partidas>` com o que a view devolve.
- **Filtro do PostgREST em coluna de agregação de view volta vazio.** `.gt('partidas', 0)` numa
  view com `group by` não traz nada, enquanto `.eq('user_id', ...)` na mesma view funciona. Se a
  lista inteira cabe numa leitura, filtrar no navegador.
- **`.catch(() => {})` numa leitura de estatística esconde exatamente o que falta ver.** Duas
  rodadas de diagnóstico se perderam porque o erro nunca chegava à tela.
- **Pausar todas as animações da página para fotografar apaga a página.** As seções entram com
  `animation: entra ... both`; congelar tudo trava elas no quadro zero, com opacidade zero. Pausar
  só o elemento que se quer fotografar.
- **Comentário JSX solto dentro de `.map()` quebra a sintaxe**, porque a função passa a retornar dois elementos.
- **Caixa cujos filhos são todos `position:absolute` tem largura intrínseca zero.** Dentro de um flex com `align-items:start` ela encolhe até sumir. No ZEBRA o campo murchou de 358px para 48px assim que a única legenda estática saiu da tela. Declarar `width` na caixa ou `align-items:stretch` no pai.
- **Dois handlers de clique no mesmo elemento: o segundo apaga o primeiro.** Botões de modo e de velocidade compartilhavam a classe `.sp`, e o `onclick` registrado depois anulou o anterior. Usar seletor com o atributo (`.sp[data-sp]`), não só a classe.
- **Contador animado por `requestAnimationFrame` congela** se a aba perde o foco. Contar por tempo decorrido e garantir o valor final num `setTimeout`.

## Como este dono gosta de trabalhar

- **Não agir sem pedido explícito.** Perguntar "quer que eu faça?" e esperar. Ele já interrompeu trabalho que eu comecei por conta própria.
- **Mudança em produção: mostrar print antes de subir.** O site tem assinantes pagando.
- **Nunca encostar no fluxo de busca** (`api/places`, `api/search`, `SearchResults`, `QuizOverlay`) em tarefa de design, e confirmar pelo diff que não encostou.
- Ele testa e aponta erro rápido. Quando ele diz que algo está errado, verificar de verdade antes de responder — às vezes ele está certo e eu não tinha visto, às vezes o erro está no meu print.

## Situação do negócio (setembro de 2026)

- **Honk Ponk:** 32 assinantes. O crescimento **empacou** e a entrada de dinheiro deu uma parada. Os números públicos do site são: mais de 2.800 usuários, 5.000 buscas e 20.000 locais prospectados.
- **Foco atual do dono: venda de sites**, não mais só o SaaS. Ele tem protótipos prontos de clínica, doceria e estética automotiva (Detail Garage e Lopes Estética), e prospecta presencialmente e por telefone em Santos.
- **Domínio dos sites de cliente:** ele decidiu **registrar e pagar no próprio nome** (cerca de R$40 por ano por cliente), em vez de deixar no nome do cliente. Isso combina com cobrança mensal para cobrir o custo recorrente.
- **Recebimento** ainda cai na conta Mercado Pago do irmão, que não repassa. Conta própria só aos 18 anos; existe uma conta com o pai como responsável, mas ele não quis usar.
