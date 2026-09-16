# Spec — Permitir embed do NDesk nos aplicativos do NChat (NDESK-60)

- **Task:** [NDESK-60](https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-60/) ·
  `[NDesk] Permitir embed do NDesk nos aplicativos do NChat (frame-ancestors allowlist)`
- **Data:** 2026-09-16 · **Fase:** Planning · **Revisão:** v2.1 (v1 passou pelo grill com modelo OpenAI;
  v2 incorporou os achados e as decisões D6–D9 e foi aprovada pelo usuário; v2.1 incorpora o grill do plano)
- **Branch:** `feat/nchat-embed-frame-ancestors` (base `origin/newbyte-stable` @ `18cb3a13e4`, tag `nb.v1.6`)
- **Referência:** NCollect [PR 480](https://github.com/newbytesolucoesdigitais/ncollect/pull/480) /
  [NCOLLECT-64](https://plane.byte.newbyte.net.br/engenharia/browse/NCOLLECT-64/) — mesma demanda, outro
  mecanismo

## 1. Problema

O NChat mostra **Aplicativos do NChat** (dashboard apps do Chatwoot: uma URL externa registrada no painel e
exibida em `<iframe>` para o agente). Há **dois deploys** do NChat, com origens distintas:
`https://chat.newbyte.net.br` (build antigo, Webpack) e `https://nchat.newbyte.net.br` (build novo, Vite). Não
são alias um do outro. Registrar o NDesk como aplicativo em qualquer um deles falha: o navegador recusa
renderizar o documento.

Evidência observada em produção (`curl -sI https://ndesk.newbyte.net.br/`, 2026-09-16):

```text
x-frame-options: SAMEORIGIN
content-security-policy: base-uri 'self' https://ndesk.newbyte.net.br; default-src 'self' ws: wss: https://images.zammad.com; font-src 'self' data:; img-src * data: blob:; object-src 'none'; script-src 'self' 'unsafe-eval' 'nonce-…'; style-src 'self' 'unsafe-inline'; frame-src www.youtube.com player.vimeo.com; media-src 'self' blob:
```

Os dois headers nascem no Rails, não na borda:

- `X-Frame-Options: SAMEORIGIN` é o default de `config.action_dispatch.default_headers`
  (`actionpack-8.1.3.1/lib/action_dispatch/railtie.rb:41`; o hash inteiro é substituído por
  `config.load_defaults 8.1`, `railties-8.1.3.1/lib/rails/application/configuration.rb:296-302`). Ele é
  mesclado nas respostas de **ActionController** (`ActionController::Metal::DefaultHeaders`); respostas Rack
  nuas não o recebem.
- A CSP vem de `config/initializers/content_security_policy.rb` e **não declara `frame-ancestors`**. O
  middleware da CSP decora toda resposta que atravessa a pilha com política (HTML, JSON, redirects, erros
  tratados pelo `ApplicationController`), exceto 304 e respostas que já trazem o header. Downloads de anexo
  trocam a política por `default-src 'none'` (`app/controllers/application_controller/has_download.rb`,
  `set_null_csp`).
- Fora dos dois: arquivos estáticos (`ActionDispatch::Static` e o nginx do container servindo `/assets/`,
  `robots.txt`, `favicon.ico`) e a página de exceção não tratada. Hoje já saem sem CSP e sem XFO.
- O nginx versionado (`contrib/nginx/zammad.conf`, transformado por `bin/docker-entrypoint`) não adiciona
  header de framing. A configuração do Cloudflare na frente de produção não é visível pelo repo; o `curl`
  acima é o resultado final observado.

Sem `frame-ancestors`, vale o XFO: só a própria origem pode emoldurar o NDesk. As origens do NChat são
outras origens (mesmo _site_ `newbyte.net.br`, origem diferente), logo são recusadas.

## 2. Por que é mais simples que no NCollect

No NCollect o header é servido pelo Cloudflare Pages via arquivo `_headers`, que não tem "substituir": foi
preciso destacar (`! Header`) e re-declarar a CSP inteira por rota, com a ordem dos blocos sendo
load-bearing e um teste que parseia blocos. No NDesk o header é gerado pelo Rails, que tem a diretiva
nativa (`policy.frame_ancestors`) e um hash de headers padrão editável. A mudança de código é **uma
diretiva nova, um `delete` e uma diretiva na política de download** (§4). A PR do NCollect é referência
para _o quê_ (allowlist exata, registro de risco, contrato com o NChat), não para _o como_.

Alternativas rejeitadas:

- **Transform Rule no Cloudflare** (modificar o header na borda): zero código, mas a decisão sai do
  repositório, não passa por review nem por teste, e o header do Rails continuaria dizendo o contrário
  atrás da borda (previews e acesso direto ao container).
- **`add_header`/`proxy_hide_header` no nginx do container**: precisa esconder o header do Rails e
  reescrever a CSP inteira em string, duplicando a política em dois lugares. Frágil.
- **Restringir por rota** (como o `/host` do NCollect): tecnicamente possível (política por controller), mas
  o NDesk é uma SPA na raiz com roteamento client-side (a diretiva só é avaliada no carregamento do
  documento) e não há seção isolada a proteger. Rejeitado por decisão (D1), não por impossibilidade.

## 3. Decisões

Fechadas com o usuário em 2026-09-16 (D1–D5 antes do grill; D6–D9 a partir dos achados do grill).

| #  | Decisão | Escolha | Motivo |
|----|---------|---------|--------|
| D1 | Escopo | **App inteiro**: todas as respostas dinâmicas que herdam a CSP global — UI clássica (`/`, `/#…`), `/desktop`, `/mobile`, Knowledge Base pública, login/admin, erros tratados. APIs JSON também recebem a diretiva (inócua). Estáticos e exceções não tratadas ficam como hoje. | SPA na raiz; nenhuma seção isolada a proteger. |
| D2 | `'self'` | **Manter** | Preserva a permissão SAMEORIGIN atual sem ampliar capacidade de um principal que já é same-origin. Nenhum auto-iframe do NDesk foi achado (o único iframe real é YouTube/Vimeo na KB, governado por `frame-src`), mas a razão durável é a anterior, não o grep. |
| D3 | `X-Frame-Options` | **Remover** dos `default_headers` | `frame-ancestors` prevalece sobre o XFO em navegadores com CSP2; um header contraditório confunde auditoria e QA. Mesma decisão do NCollect. Deltas reais em §5.5. |
| D4 | Origens | `https://chat.newbyte.net.br` e `https://nchat.newbyte.net.br`, literais | Origem exata: `https`, sem wildcard, sem porta, sem `http:`, sem barra final (a diretiva recebe origens, não URLs). Por decisão, somente estas duas origens são autorizadas. |
| D5 | Onde configurar | Diretiva no initializer da CSP; `delete` do XFO em `config/application.rb`, **imediatamente após `config.load_defaults 8.1`** | `load_defaults` substitui o hash inteiro de `default_headers`; um `delete` antes dele é desfeito em silêncio. `action_dispatch.configure` copia a referência do mesmo Hash para `ActionDispatch::Response`, então um `delete` num initializer também funcionaria hoje, mas dependeria de identidade de objeto. |
| D6 | Credenciais do `chat` antigo na URL | **Liberar os dois deploys e aceitar o risco** | O usuário aceita o vazamento descrito em §5.4; follow-up do lado do NChat (§6). |
| D7 | Autenticação no embed | **Só sessão existente e login por senha (+TOTP)** | Security Key (WebAuthn), logins externos (OIDC/SAML/Google/Microsoft/GitHub), vinculação de conta e OAuth de canais ficam explicitamente não suportados dentro do iframe (usar aba normal). |
| D8 | Política de download | **Adicionar `frame_ancestors :self`** | Sem XFO, `default-src 'none'` não restringe ancestrais; a diretiva preserva a postura SAMEORIGIN atual dos anexos. |
| D9 | Documentação | **ADR sistêmica** em `docs/adr/0001-nchat-embed-frame-ancestors.md`; **sem** `CONTEXT.md` novo | "Origem ancestral" e "allowlist de framing" são termos genéricos da Web, não de domínio; "Aplicativo do NChat" fica definido na ADR. `CONTEXT-MAP.md` intocado. |

## 4. Mudanças

### 4.1 `config/initializers/content_security_policy.rb`

Uma diretiva nova dentro do bloco existente, com as origens literais (D4):

```ruby
  # NDESK-60: os aplicativos do NChat emolduram o NDesk. Origem exata: https, sem wildcard.
  policy.frame_ancestors :self, 'https://chat.newbyte.net.br', 'https://nchat.newbyte.net.br'
```

Resultado esperado em toda resposta com a política global (HTML e JSON), incluindo `/`:

```text
frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br
```

As demais diretivas ficam idênticas às de hoje (§1). Em `development` a CSP continua report-only (linha
existente do initializer).

### 4.2 `config/application.rb`

Logo após `config.load_defaults 8.1` (D5):

```ruby
    # NDESK-60: framing é governado por `frame-ancestors` na CSP; o XFO não tem allowlist e contradiria a
    # política. Precisa vir DEPOIS do load_defaults, que substitui o hash inteiro de default_headers.
    config.action_dispatch.default_headers.delete('X-Frame-Options')
```

Os demais headers padrão (`X-Content-Type-Options`, `Referrer-Policy`, …) não mudam.

### 4.3 `app/controllers/application_controller/has_download.rb`

Política de download com `frame-ancestors` (D8):

```ruby
  def set_null_csp
    request.content_security_policy = ActionDispatch::ContentSecurityPolicy.new.tap do |p|
      p.default_src :none
      p.frame_ancestors :self # NDESK-60: sem XFO, preserva a postura SAMEORIGIN dos anexos
    end
  end
```

Resultado: `default-src 'none'; frame-ancestors 'self'`. A expectativa em
`spec/requests/ticket/article_attachments_spec.rb:59` é atualizada para esse valor.

### 4.4 Spec de request — `spec/requests/frame_ancestors_spec.rb`

Contrato dos headers, no estilo das specs de contrato do projeto (`spec/config/framework_defaults_spec.rb`,
`spec/requests/framework_defaults_json_spec.rb`), com `:aggregate_failures` nos exemplos de múltiplas
expectativas:

1. **Oráculo de configuração:** `Rails.application.config.action_dispatch.default_headers` e
   `ActionDispatch::Response.default_headers` não contêm `X-Frame-Options` (diagnostica ordem/propagação
   melhor que repetir "XFO ausente" por rota).
2. **`GET /`** (HTML, `init#index`, 200): a CSP é parseada num mapa `diretiva → valor` (o parser **falha**
   em diretiva duplicada, não sobrescreve); `frame-ancestors` **igual** a
   `'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br`; header `X-Frame-Options` ausente.
   A igualdade exata é o contrato (sem wildcard, sem `http:`, sem barra final); não há asserções negativas
   soltas sobre a política inteira.
3. **`GET /api/v1/getting_started`** (JSON público, 200, já usado em `spec/requests/framework_query_string_spec.rb`):
   mesmo `frame-ancestors`, `X-Frame-Options` ausente. Mostra que a remoção é global às respostas de
   controller e que a política cobre JSON.
4. **Baseline** (exemplo separado, com comentário): o mapa completo esperado no ambiente de teste, com o
   nonce de `script-src` normalizado. Delta documentado: produção adiciona `http_type://fqdn` ao
   `base-uri`; development é report-only e adiciona `http://…` ao `connect-src`.
5. **Não** testa 304 (não é rota estável de controller) e **não** duplica o contrato de download: a spec de
   anexos existente é atualizada (§4.3) e roda junto.

Ambiente de teste: a CSP é aplicada (não report-only) e o `base-uri` fica só `'self'` (o proc do
initializer só adiciona `http_type://fqdn` em produção).

### 4.5 Docs

- **ADR** `docs/adr/0001-nchat-embed-frame-ancestors.md` (decisão sistêmica: `docs/adr/` na raiz, conforme
  `.claude/skills/grill-with-docs/ADR-FORMAT.md`; formato das ADRs existentes, `status: accepted`):
  define _Aplicativo do NChat_, registra decisão, alternativas rejeitadas (§2), consequências (§5) e o
  contrato/limitações do lado do NChat (§6). O que a torna ADR: depois que o NChat depender do embed,
  reverter para SAMEORIGIN quebra produto e exige coordenação entre produtos (§5.8).
- **Changelog** em `.claude/NEWBYTE_WORKFLOW.md` (convenção do projeto): entrada
  `2026-09-16 - branch feat/nchat-embed-frame-ancestors (NDESK-60)` com resumo e "Arquivos modificados";
  no mesmo arquivo, corrigir a linha "tag mais recente" (diz `nb.v1.3`; a atual é `nb.v1.6`).
- Este spec e o plano em `docs/plans/`, publicados no sub-item Planning do Plane ao fim da fase.
- Todos os `.md` novos passam em `pnpm exec markdownlint-cli2`. Exceção explícita: `.claude/NEWBYTE_WORKFLOW.md`
  já tem 23 erros legados na base; o gate para ele é **não acrescentar erros** (contagem antes = contagem
  depois), não zerar o arquivo (fora do escopo).

## 5. Consequências e risco aceito

1. **Concreto — UI redressing transitivo.** Quem conseguir renderizar HTML arbitrário em qualquer dos dois
   deploys do NChat em volta do iframe (XSS no NChat, ou um Aplicativo que aceite HTML cru em vez de URL)
   pode sobrepor o NDesk emoldurado e induzir cliques de um agente logado. Impossível antes; a postura
   anti-clickjacking do NDesk passa a herdar a dos **dois** deploys do NChat. Aceito: produtos da mesma
   equipe, mesmo site `newbyte.net.br`.
2. **Potencial — canais laterais de framing** (timing de load, foco, contagem de frames). Nenhum sinal
   dependente de estado identificado; classe aceita, exploração especulativa.
3. **Não concedido pelo framing.** Same-origin policy continua bloqueando leitura de DOM, storage e cookies
   do NDesk pelo NChat; nenhuma capacidade além do que o NChat delegar em `allow=` (§6).
4. **Credenciais do NChat na URL do NDesk (D6).** O dashboard app do `chat` antigo lê `cw_d_session_info`
   do `localStorage` e anexa `access-token`, `client` e `uid` do agente à URL do iframe (observado no bundle
   implantado em 2026-09-16). O NDesk ignora esses parâmetros (autentica por sessão/header,
   `app/controllers/application_controller/authenticates.rb`), mas eles ficam na URL do iframe, no histórico
   do navegador e no access log do nginx (`contrib/nginx/zammad.conf:29`, sem filtro de query string). O
   `nchat` novo usa `postMessage` e não anexa nada. Risco aceito pelo usuário; follow-up do lado do NChat.
5. **Deltas reais de remover o XFO (D3):** (a) navegadores sem CSP2 perdem o fallback anti-framing; o piso
   suportado (Chrome/Firefox/Safari atuais) implementa `frame-ancestors`; (b) em `development` a CSP é
   report-only, então o servidor local fica emoldurável por qualquer origem — aceito, é ambiente local;
   (c) políticas locais futuras precisam declarar `frame-ancestors` explicitamente, não há mais fallback
   (a de download já recebe, D8); (d) 304 sai sem CSP, mas respostas de controller usam `no-store`, classe
   improvável. Estáticos e página de exceção não tratada não perdem nada: já não tinham XFO.
6. **Sessão dentro do embed é expectativa a validar no QA, não consequência de configuração.** Os três
   hosts são HTTPS e same-site (`newbyte.net.br` é o site registrável). O cookie de sessão (ActiveRecord
   store, `lib/zammad/application/initializer/session_store.rb`) é host-only, `Secure`, `HttpOnly` e hoje
   **não emite `SameSite`**: o Rack 2.2 preenche `same_site: nil` antes do cookie jar, então o default
   `:lax` do Rails não se aplica (observado em produção: `Set-Cookie: _zammad_session_…; path=/; secure;
   HttpOnly`). Navegadores atuais tratam a ausência como Lax e enviam o cookie em iframe same-site; Safari
   ITP e Firefox TCP não o tratam como terceiro nesse cenário. Mutações são protegidas pelo token próprio
   do Zammad em `X-CSRF-Token` (`app/controllers/application_controller/prevents_csrf.rb`); a verificação
   nativa de `Origin` do Rails está desativada (`verify_authenticity_token` é pulado). **Débito fora do
   escopo**, anotado na ADR: `same_site: :lax` explícito e a checagem de `Origin`.
7. **WebSocket e ActionCable não mudam.** `/ws` autentica por `session_id` na mensagem e não checa
   `Origin` (`lib/websocket_server.rb`); `/cable` vê a `Origin` do documento NDesk, não do frame-pai
   (`config/initializers/zzz_action_cable_preferences.rb`).
8. **Reverter.** Técnico: remover as duas diretivas e restaurar o XFO; sem dados nem migração.
   Operacional: depois que o NChat depender do embed, reativar SAMEORIGIN quebra produto e exige
   coordenação entre os dois produtos e atualização de testes/docs.

## 6. Contrato e limitações do lado do NChat

Sem código neste repositório; registrado na ADR e no corpo da PR. Os iframes reais dos dois deploys hoje
**não têm `allow=` nem `sandbox`** (observado nos bundles implantados). O embed básico funciona só com este
PR; as capacidades abaixo dependem da delegação do frame-pai (Permissions Policy: o padrão de `microphone`,
`camera`, `clipboard-write`, `fullscreen` e `publickey-credentials-*` é `self`, negado a iframes
cross-origin sem `allow=`).

| Capacidade | Estado no embed | O que muda no NChat |
|------------|-----------------|---------------------|
| Renderizar, sessão existente, login senha/TOTP, tickets, tempo real | **Suportado** com este PR | nada |
| Gravação de áudio (`ticket_zoom/article_new.coffee:895`, `getUserMedia`) | Exige mudança no NChat | `allow="microphone"` |
| Copiar (`_application_controller/_base.coffee:114`; hoje mostra "Copied!" mesmo falhando) | Exige mudança no NChat | `allow="clipboard-write"` |
| Webcam do avatar (`_profile/avatar.coffee:262`) | Limitação aceita | opcional `allow="camera"` |
| Tela cheia de vídeo na KB (`knowledge_base/reader_controller.coffee:128`) | Limitação aceita | opcional `allow="fullscreen"` |
| Security Key (WebAuthn), logins externos, vinculação de conta, OAuth de canais | **Não suportado** (D7): usar aba normal | — |
| Notificações de desktop (`_plugin/notify.coffee:53`) | Limitação: o prompt de permissão não funciona em iframe cross-origin; com permissão já concedida em aba normal, a entrega é validada por navegador no QA | — |
| `confirm()`/`alert()` (ex.: `article_new.coffee:422`, `agent_ticket_create.coffee:772`) | A validar por navegador no QA (o Chromium restringiu e reverteu) | — |
| Print, popups (`window.open`), downloads por gesto | Esperado funcionar; QA | nunca `sandbox` nem `credentialless` (quebram sessão/login) |
| Histórico | O roteamento por hash do NDesk entra no histórico da aba do NChat (Back percorre telas do NDesk). Limitação aceita | — |
| Credenciais na URL (`chat` antigo) | Risco aceito (D6) | follow-up opcional na NCHATV4-271: parar de anexar credenciais (o `nchat` já usa `postMessage`) |
| CSP do próprio NChat | Hoje só `frame-ancestors`, sem `frame-src` restritivo: carrega o NDesk e o preview (estado observado, não contrato) | manter `frame-src` liberado para o NDesk |

Recomendação para o NChat: `allow="microphone; clipboard-write; camera; fullscreen"` no iframe de dashboard
app dos dois deploys. Task de follow-up criada em 2026-09-16:
[NCHATV4-271](https://plane.byte.newbyte.net.br/engenharia/browse/NCHATV4-271/) (projeto NChat V4,
responsável Gustavo Pies Ternus), relacionada à NDESK-60.

## 7. Verificação

Gates locais (o ambiente tem Ruby 3.4.8, Postgres e Redis):

```bash
bundle exec rspec spec/requests/frame_ancestors_spec.rb spec/requests/ticket/article_attachments_spec.rb \
  spec/config/framework_defaults_spec.rb
bundle exec rubocop config/application.rb config/initializers/content_security_policy.rb \
  app/controllers/application_controller/has_download.rb spec/requests/frame_ancestors_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb
pnpm exec markdownlint-cli2 docs/plans/2026-09-16-nchat-embed-frame-ancestors*.md docs/adr/*.md
```

Runtime local (`development`, CSP report-only): prova formato e remoção do XFO, não o enforcement.

```bash
curl -sI http://127.0.0.1:3000/ | grep -iE 'content-security-policy|x-frame-options'
# esperado: content-security-policy-report-only contendo o frame-ancestors; nenhum x-frame-options
```

Preview da PR (`ndesk-pr-{N}.staging-preview.newbyte.net.br`, aplica os headers do Rails):

```bash
curl -sI https://ndesk-pr-{N}.staging-preview.newbyte.net.br/ | grep -iE 'content-security-policy|x-frame-options'
# esperado: frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br; nenhum x-frame-options
curl -sI https://ndesk-pr-{N}.staging-preview.newbyte.net.br/api/v1/getting_started | grep -iE 'content-security-policy|x-frame-options'
```

Embed real (QA): registrar o NDesk (URL do preview) como Aplicativo nos **dois** deploys do NChat e testar em
Chrome, Firefox e Safari: renderiza; sessão existente reaproveitada; login por senha (+TOTP); abrir ticket;
tempo real; Back; print/download; `confirm()`. Gravação de áudio e copiar só passam depois do `allow=` do
NChat (§6). Injeção de iframe por DevTools em `chat.newbyte.net.br` serve de pré-teste, não substitui o
Aplicativo registrado (não reproduz a URL nem o `allow=` reais).

Origem de terceiro: página HTTPS num domínio realmente distinto (ex.: um HTML publicado no GitHub Pages ou
CodePen) com `<iframe src="https://ndesk-pr-{N}.staging-preview.newbyte.net.br/">` — o navegador recusa.
Não usar `about:blank` (herda a origem de quem o criou).

Produção (fase Release): o mesmo `curl` em `https://ndesk.newbyte.net.br/` (`base-uri` com o fqdn) e a CSP
dos dois deploys do NChat conferida de novo: para frames filhos vale a cadeia `frame-src` → `child-src` →
`default-src`; nenhuma delas pode existir sem uma fonte que case com `https://ndesk.newbyte.net.br`
(hoje os dois deploys só emitem `frame-ancestors`, estado observado em 2026-09-16).

## 8. Fora do escopo

Mudanças no NChat (registradas como follow-up em §6); Security Key, logins externos e OAuth dentro do
iframe (D7); nginx e Cloudflare; `same_site` explícito e checagem de `Origin` (débito anotado); mitigação
de notificações e histórico dentro do embed; qualquer diretiva da CSP além das duas declaradas em §4.
