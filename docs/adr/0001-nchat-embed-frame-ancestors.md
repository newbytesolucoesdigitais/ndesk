---
status: accepted
---

# Os Aplicativos do NChat emolduram o NDesk via `frame-ancestors`; o `X-Frame-Options` sai

Um **Aplicativo do NChat** é uma URL externa registrada no painel do NChat (dashboard app do Chatwoot)
e exibida em `<iframe>` para o agente. Há dois deploys do NChat, com origens distintas:
`https://chat.newbyte.net.br` (build antigo) e `https://nchat.newbyte.net.br` (build novo).

O NDesk passa a declarar, na CSP global (`config/initializers/content_security_policy.rb`),
`frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br`; remove o
`X-Frame-Options: SAMEORIGIN` dos headers padrão do Rails (`config/application.rb`, logo após
`config.load_defaults 8.1`, que substitui o hash inteiro); e declara `frame-ancestors 'self'` na política
de download de anexos (`app/controllers/application_controller/has_download.rb`). Nenhuma outra diretiva
muda. `spec/requests/frame_ancestors_spec.rb` pina a allowlist exata, a ausência do XFO e o baseline.
Análise completa: `docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md` (NDESK-60).
Decisões e riscos aceitos em 2026-09-16 por Cauã Puppim Pereira Mendes (responsável pela NDESK-60).

## Alternativas rejeitadas

- **Transform Rule no Cloudflare**: a decisão sairia do repositório, sem review nem teste, e o header do
  Rails continuaria contradizendo a borda em previews e no acesso direto ao container.
- **`add_header`/`proxy_hide_header` no nginx do container**: duplicaria a CSP inteira em string num
  segundo lugar. Frágil.
- **Allowlist só em algumas rotas** (como o `/host` do NCollect): possível, mas o NDesk é uma SPA na raiz
  com roteamento client-side e não tem seção isolada a proteger. Rejeitado por decisão.
- **Manter o `X-Frame-Options: SAMEORIGIN`**: navegadores com CSP2 o ignoram quando `frame-ancestors`
  existe, mas o header contraditório confunde auditoria e QA. Removido, como no NCollect.

## Consequências

- **UI redressing transitivo**: quem renderizar HTML arbitrário em qualquer dos dois deploys do NChat em
  volta do iframe pode sobrepor o NDesk e induzir cliques de um agente logado. A postura anti-clickjacking
  do NDesk herda a do NChat. Aceito: produtos da mesma equipe, mesmo site `newbyte.net.br`.
- **Credenciais do NChat na URL do NDesk**: o dashboard app do `chat` antigo anexa `access-token`,
  `client` e `uid` do agente à URL do iframe; o NDesk os ignora, mas eles ficam na URL, no histórico e no
  access log do nginx. Risco aceito em 2026-09-16; o `nchat` novo usa `postMessage`. Correção opcional na
  NCHATV4-271.
- **Autenticação dentro do embed**: suportados sessão existente e login por senha (+TOTP). Security Key
  (WebAuthn), logins externos (OIDC/SAML/Google/Microsoft/GitHub), vinculação de conta e OAuth de canais
  **não** são suportados no iframe: usar aba normal.
- **Contrato do NChat** (task NCHATV4-271): iframe simples, nunca `sandbox` nem `credentialless` (quebram
  sessão e login); `allow="microphone; clipboard-write; camera; fullscreen"` para gravação de áudio,
  copiar, webcam do avatar e tela cheia funcionarem dentro do embed. Sem `allow=`, o embed básico funciona
  e essas quatro capacidades falham (o botão de copiar falha em silêncio). A CSP do NChat não pode ter
  `frame-src`, `child-src` ou `default-src` que bloqueie o NDesk (hoje só emite `frame-ancestors`).
- **Limitações registradas**: o prompt de permissão de notificações não funciona em iframe cross-origin;
  o roteamento por hash do NDesk entra no histórico da aba do NChat; `confirm()`/`alert()` dependem do
  navegador.
- **Sessão**: os três hosts são HTTPS e same-site, então o cookie de sessão (host-only, `Secure`,
  `HttpOnly`, hoje sem `SameSite` explícito) é enviado no iframe. Mutações são protegidas pelo token
  próprio em `X-CSRF-Token`; a checagem nativa de `Origin` do Rails está desativada. Débito, fora deste
  escopo: `same_site: :lax` explícito e a checagem de `Origin`.
- **Sem XFO**: navegadores sem CSP2 perdem o fallback anti-framing; em `development` a CSP é report-only
  e o servidor local fica emoldurável; políticas locais futuras precisam declarar `frame-ancestors`
  explicitamente. Estáticos e a página de exceção não tratada já saíam sem XFO.
- **Reverter**: técnico é remover as duas diretivas e restaurar o XFO, sem dados nem migração;
  operacional, depois que o NChat depender do embed, exige coordenação entre os dois produtos.
