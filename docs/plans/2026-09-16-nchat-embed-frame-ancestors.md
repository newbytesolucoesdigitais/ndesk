# Plano — Permitir embed do NDesk nos aplicativos do NChat (NDESK-60)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** Fazer o NDesk aceitar ser emoldurado pelos dois deploys do NChat
(`https://chat.newbyte.net.br` e `https://nchat.newbyte.net.br`) declarando `frame-ancestors` na CSP e
removendo o `X-Frame-Options`, sem afrouxar nada além disso.

**Architecture:** Três mudanças de configuração no Rails (diretiva na CSP global, `delete` do XFO logo após
`load_defaults 8.1`, `frame-ancestors 'self'` na política de download), cada uma coberta por spec de
request pinando o contrato exato dos headers. ADR sistêmica registra decisão, risco aceito e o contrato do
lado do NChat (follow-up NCHATV4-271). O preview da PR é o gate de headers reais depois da borda; o embed
real é testado com o NDesk registrado como Aplicativo nos dois deploys do NChat.

**Tech Stack:** Ruby 3.4.8 (rbenv), Rails 8.1.3.1 (ActionDispatch CSP), RSpec (request specs), RuboCop,
markdownlint-cli2 (pnpm), PostgreSQL 17 e Redis locais.

**Spec:** `docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md` (v2.1; v2 aprovada em 2026-09-16).
O plano argumenta a partir dela; quem executa lê os dois.

## Restrições globais

- Allowlist exata e imutável (spec D2/D4): `frame-ancestors 'self' https://chat.newbyte.net.br
  https://nchat.newbyte.net.br`. Sem wildcard, sem porta, sem `http:`, sem barra final, nenhuma outra
  origem. Nos arquivos Ruby versionados, cada uma das duas origens ocorre em **exatamente dois arquivos**:
  o initializer da CSP e `spec/requests/frame_ancestors_spec.rb` (gate por `git grep` na Task 4). ADR,
  changelog, comandos e mensagens de commit são citações, não código.
- O `delete` do `X-Frame-Options` fica em `config/application.rb`, **imediatamente após**
  `config.load_defaults 8.1` (spec D5). Nunca num initializer.
- Política de download (spec D8): exatamente `default-src 'none'; frame-ancestors 'self'`.
- Nenhuma outra diretiva da CSP muda; a spec pina o baseline completo do ambiente de teste (spec §4.4).
- Nada muda no NChat (follow-up NCHATV4-271), no nginx do container nem no Cloudflare (spec §8).
- Arquivos Ruby novos começam com
  `# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/`.
- Specs de contrato seguem o estilo de `spec/requests/framework_query_string_spec.rb` e
  `spec/requests/framework_defaults_json_spec.rb`: `type: :request`, `:aggregate_failures` em exemplos com
  várias expectativas, comentário de cabeçalho apontando a seção do spec. Regex em `%r{}` (cop
  `Style/RegexpLiteral` do projeto).
- **RSpec local** espelha o CI (`.github/workflows/ci-test.yml:189`): todo gate de RSpec usa
  `--tag '~searchindex' --tag '~integration' --tag '~required_envs'`.
- RuboCop limpo (`no offenses detected`) em cada arquivo Ruby tocado; `pnpm exec markdownlint-cli2` com
  `0 error(s)` em cada `.md` **novo**. Exceção explícita (spec §4.5): `.claude/NEWBYTE_WORKFLOW.md` já tem
  **23 erros legados** na base; o gate é a contagem não subir (23 antes, 23 depois), não zerar o arquivo.
- **Shell:** a máquina usa zsh. Todo gate roda dentro de `bash -euo pipefail <<'GATE' … GATE`. Não existe
  `timeout` no macOS; o Bash tool limita cada comando a 10 min.
- **Scratchpad:** cada bloco define `S="${SCRATCHPAD:?}"`. Antes de executar, a sessão exporta
  `SCRATCHPAD=<diretório de scratchpad da sessão corrente>` (o harness informa o caminho; nunca gravar um
  caminho de sessão neste documento). Evidências de QA **não** são temporárias: vão para
  `.newbyte/qa/{N}/` (Task 5), conforme `.newbyte/qa/README.md`.
- **Git:** nunca reescrever histórico (`.claude/NEWBYTE_WORKFLOW.md`: sem `rebase`, `amend`,
  `reset --hard`, `push --force`). Correções depois de um commit viram commits novos. Mensagens em
  português no padrão do repo (`tipo(escopo): resumo (NDESK-60)`). Trailer de atribuição **conforme a
  instrução vigente da sessão que executa** (em 2026-09-16: `Co-Authored-By: Claude Fable 5.1
  <noreply@anthropic.com>`); quando a URL da sessão for conhecida, acrescentar `Claude-Session: <URL>`
  como segundo trailer (convenção dos commits da NDESK-45). Os comandos abaixo mostram o trailer vigente
  hoje; troque se a instrução da sessão for outra.
- A PR só é aberta quando o usuário pedir (fluxo `dev-execution`, Task 4 Step 5); QA e Release seguem as
  skills `review-qa` e `release`, usando as Tasks 5 e 6 como roteiro.

## Arquivos

| Ação | Arquivo | Responsabilidade |
|------|---------|------------------|
| Modificar | `config/initializers/content_security_policy.rb:51` | diretiva `frame_ancestors` na CSP global |
| Modificar | `config/application.rb:24` | `delete('X-Frame-Options')` logo após `load_defaults 8.1` |
| Modificar | `app/controllers/application_controller/has_download.rb:34-36` | `frame_ancestors :self` na política nula |
| Criar | `spec/requests/frame_ancestors_spec.rb` | contrato: oráculo de config, `GET /`, JSON, baseline |
| Modificar | `spec/requests/ticket/article_attachments_spec.rb:59,240` | expectativa da política de download; offense pré-existente de aspas |
| Criar | `docs/adr/0001-nchat-embed-frame-ancestors.md` | decisão, risco aceito, contrato do NChat |
| Modificar | `.claude/NEWBYTE_WORKFLOW.md:26` e fim do arquivo | tag atual e entrada de changelog (obrigatória) |
| Commitar | `docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md`, `docs/plans/2026-09-16-nchat-embed-frame-ancestors.md` | spec e plano viajam na PR |

---

### Task 0: Preflight e commit dos documentos

**Files:**

- Commit: `docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md`,
  `docs/plans/2026-09-16-nchat-embed-frame-ancestors.md`

**Interfaces:**

- Produces: branch `feat/nchat-embed-frame-ancestors` no commit de base `18cb3a13e4` + 1 commit de docs;
  banco de teste respondendo; baseline verde das specs que a Task 2 vai alterar.

- [ ] **Step 1: Confirmar branch, base e ambiente**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?exporte SCRATCHPAD com o scratchpad da sessão}"; mkdir -p "$S"
git fetch -q origin
test "$(git branch --show-current)" = feat/nchat-embed-frame-ancestors
test "$(git merge-base HEAD origin/newbyte-stable)" = "$(git rev-parse origin/newbyte-stable)"
ruby -v | grep -q '3\.4\.8'
pg_isready >/dev/null && redis-cli ping | grep -q PONG
echo PREFLIGHT_OK
GATE
```

Expected: `PREFLIGHT_OK`. Se a base divergir (a `newbyte-stable` andou), pare e relate: o plano foi
escrito sobre `18cb3a13e4` (tag `nb.v1.6`).

- [ ] **Step 2: Baseline verde das specs que serão alteradas e do ambiente de teste**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/ticket/article_attachments_spec.rb spec/config/framework_defaults_spec.rb \
  spec/requests/framework_query_string_spec.rb > "$S/task0-baseline.log" 2>&1
grep -E 'examples?, [0-9]+ failures?' "$S/task0-baseline.log"
grep -q '26 examples, 0 failures' "$S/task0-baseline.log"
echo BASELINE_OK
GATE
```

Expected: `26 examples, 0 failures` e `BASELINE_OK` (medido em 2026-09-16). Se falhar por banco
(`zammad_test` ausente), rode `RAILS_ENV=test bin/rake db:create db:migrate` e repita; qualquer outra falha
é pré-existente — relate.

- [ ] **Step 3: Lint dos documentos e commit**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
pnpm exec markdownlint-cli2 docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md \
  docs/plans/2026-09-16-nchat-embed-frame-ancestors.md
git add docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md \
  docs/plans/2026-09-16-nchat-embed-frame-ancestors.md
git commit -q -m "docs(plans): spec e plano do embed do NDesk nos aplicativos do NChat (NDESK-60)" \
  -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git log --oneline -1
GATE
```

Expected: `0 error(s)` do markdownlint e o commit listado.

---

### Task 1: Allowlist `frame-ancestors` e remoção do `X-Frame-Options` (red → green)

**Files:**

- Create: `spec/requests/frame_ancestors_spec.rb`
- Modify: `config/initializers/content_security_policy.rb:51` (após `policy.media_src   :self, :blob`)
- Modify: `config/application.rb:24` (após `config.load_defaults 8.1`)

**Interfaces:**

- Consumes: `GET /` (`init#index`, HTML) e `GET /api/v1/getting_started` (JSON público, 200 sem login),
  ambos já existentes; no ambiente de teste a CSP é aplicada (não report-only) e o header atual, medido
  em 2026-09-16, é
  `base-uri 'self'; default-src 'self' ws: wss: https://images.zammad.com; font-src 'self' data:;
  img-src * data: blob:; object-src 'none'; script-src 'self' 'unsafe-eval' 'nonce-…';
  style-src 'self' 'unsafe-inline'; frame-src www.youtube.com player.vimeo.com; media-src 'self' blob:`
  com `X-Frame-Options: SAMEORIGIN` (idêntico para `/` e para o JSON).
- Produces: header `frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br` em
  toda resposta com a política global; `X-Frame-Options` ausente em respostas de controller; o helper
  `csp_directives(header)` da spec (parser em mapa que falha em diretiva duplicada).

- [ ] **Step 1: Escrever a spec de contrato (falhando)**

Crie `spec/requests/frame_ancestors_spec.rb` com este conteúdo:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Contrato dos headers de framing (spec NDESK-60, §4.4): os Aplicativos do NChat emolduram o
# NDesk em iframe. A CSP declara a allowlist exata em `frame-ancestors`; o `X-Frame-Options`
# do Rails é removido porque não tem sintaxe de allowlist e contradiria a política.
RSpec.describe 'Frame ancestors allowlist (NDESK-60)', type: :request do
  # "a b; c d" → { 'a' => 'b', 'c' => 'd' }. Falha em diretiva duplicada em vez de sobrescrever.
  def csp_directives(header)
    header.split(';').map(&:strip).reject(&:empty?).each_with_object({}) do |directive, map|
      name, *sources = directive.split(%r{\s+})
      raise "diretiva CSP duplicada: #{name}" if map.key?(name)

      map[name] = sources.join(' ')
    end
  end

  let(:allowlist) { "'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br" }

  describe 'headers padrão do Rails' do
    it 'não incluem X-Frame-Options (config e o objeto usado por ActionDispatch::Response)', :aggregate_failures do
      expect(Rails.application.config.action_dispatch.default_headers).not_to have_key('X-Frame-Options')
      expect(ActionDispatch::Response.default_headers).not_to have_key('X-Frame-Options')
    end
  end

  describe 'GET / (documento HTML do app)' do
    before { get '/' }

    it 'libera exatamente self e as duas origens do NChat, sem X-Frame-Options', :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(csp_directives(response.headers['Content-Security-Policy'])['frame-ancestors']).to eq(allowlist)
      expect(response.headers['X-Frame-Options']).to be_nil
    end

    it 'mantém as demais diretivas no baseline do ambiente de teste' do
      # Produção acrescenta "http_type://fqdn" ao base-uri; development é report-only e
      # acrescenta http://… e ws://… ao connect-src (initializer). O nonce muda por resposta.
      directives = csp_directives(response.headers['Content-Security-Policy'])
      directives['script-src'] = directives['script-src'].sub(%r{ 'nonce-[^']+'\z}, '')

      expect(directives).to eq(
        'base-uri'        => "'self'",
        'default-src'     => "'self' ws: wss: https://images.zammad.com",
        'font-src'        => "'self' data:",
        'img-src'         => '* data: blob:',
        'object-src'      => "'none'",
        'script-src'      => "'self' 'unsafe-eval'",
        'style-src'       => "'self' 'unsafe-inline'",
        'frame-src'       => 'www.youtube.com player.vimeo.com',
        'media-src'       => "'self' blob:",
        'frame-ancestors' => allowlist,
      )
    end
  end

  describe 'GET /api/v1/getting_started (JSON público)' do
    it 'recebe a mesma allowlist e também sai sem X-Frame-Options', :aggregate_failures do
      get '/api/v1/getting_started'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(csp_directives(response.headers['Content-Security-Policy'])['frame-ancestors']).to eq(allowlist)
      expect(response.headers['X-Frame-Options']).to be_nil
    end
  end
end
```

- [ ] **Step 2: Rodar a spec e confirmar que falha pelo motivo certo**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
set +e
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/frame_ancestors_spec.rb > "$S/task1-red.log" 2>&1
set -e
grep -E 'examples?, [0-9]+ failures?' "$S/task1-red.log"
grep -q '4 examples, 4 failures' "$S/task1-red.log"
grep -q 'X-Frame-Options' "$S/task1-red.log"
echo RED_OK
GATE
```

Expected: `4 examples, 4 failures` e `RED_OK` (reproduzido em 2026-09-16 com a spec materializada). As
falhas: os dois hashes de `default_headers` ainda contêm `X-Frame-Options`; em `/`, `frame-ancestors` é
`nil` e o XFO é `"SAMEORIGIN"`; o baseline difere só pela chave `frame-ancestors` ausente; no JSON, idem
ao `/`. Qualquer outra falha (ex.: 500 ou 404 em `/`) é problema de ambiente — pare e relate.

- [ ] **Step 3: Declarar a diretiva no initializer da CSP**

Em `config/initializers/content_security_policy.rb`, logo após a linha `policy.media_src   :self, :blob`
(linha 51), acrescente:

```ruby
  # NDESK-60: os Aplicativos do NChat emolduram o NDesk em iframe. Origem exata: https, sem wildcard.
  # Allowlist e trade-offs em docs/adr/0001-nchat-embed-frame-ancestors.md.
  policy.frame_ancestors :self, 'https://chat.newbyte.net.br', 'https://nchat.newbyte.net.br'
```

O bloco `if Rails.env.development?` que vem depois não é alterado.

- [ ] **Step 4: Remover o `X-Frame-Options` logo após o `load_defaults`**

Em `config/application.rb`, a linha 24 é `config.load_defaults 8.1`. Imediatamente depois dela, acrescente:

```ruby

    # NDESK-60: framing é governado por `frame-ancestors` na CSP; o X-Frame-Options não tem sintaxe
    # de allowlist e contradiria a política. Tem de vir DEPOIS do load_defaults, que substitui o hash
    # inteiro de default_headers (um delete antes dele é desfeito em silêncio).
    config.action_dispatch.default_headers.delete('X-Frame-Options')
```

- [ ] **Step 5: Rodar a spec e confirmar verde**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/frame_ancestors_spec.rb > "$S/task1-green.log" 2>&1
grep -E 'examples?, [0-9]+ failures?' "$S/task1-green.log"
grep -q '4 examples, 0 failures' "$S/task1-green.log"
echo GREEN_OK
GATE
```

Expected: `4 examples, 0 failures` e `GREEN_OK`.

- [ ] **Step 6: RuboCop nos arquivos tocados**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
bundle exec rubocop config/application.rb config/initializers/content_security_policy.rb \
  spec/requests/frame_ancestors_spec.rb
GATE
```

Expected: `3 files inspected, no offenses detected` (verificado em 2026-09-16 com `--stdin` no caminho
final; os únicos offenses da primeira versão eram `Style/RegexpLiteral`, já resolvidos com `%r{}`). Se
aparecer outro offense, corrija na origem sem `rubocop:disable` e rode de novo.

- [ ] **Step 7: Commit**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
git add config/application.rb config/initializers/content_security_policy.rb \
  spec/requests/frame_ancestors_spec.rb
git commit -q -m "feat(csp): frame-ancestors para os aplicativos do NChat e remoção do X-Frame-Options (NDESK-60)" \
  -m "A CSP global passa a declarar frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br. O X-Frame-Options: SAMEORIGIN sai dos default_headers logo após o load_defaults 8.1 (que substitui o hash inteiro). Spec de request pina a allowlist exata, a ausência do XFO (config e respostas HTML/JSON) e o baseline das demais diretivas." \
  -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git log --oneline -1
GATE
```

---

### Task 2: Política de download declara `frame-ancestors 'self'` (red → green)

**Files:**

- Modify: `spec/requests/ticket/article_attachments_spec.rb:59` (expectativa) e `:240` (offense
  pré-existente `Style/StringLiterals`, que impediria o gate de RuboCop no arquivo)
- Modify: `app/controllers/application_controller/has_download.rb:34-36`

**Interfaces:**

- Consumes: Task 1 (sem o XFO, a política nula dos downloads ficou sem restrição de framing).
- Produces: `send_data`/`send_file` respondem `Content-Security-Policy: default-src 'none';
  frame-ancestors 'self'` (postura SAMEORIGIN dos anexos preservada, spec D8). A ordem é a de inserção
  das diretivas (`ActionDispatch::ContentSecurityPolicy#build`).

- [ ] **Step 1: Atualizar a expectativa da spec de anexos e corrigir as aspas da linha 240 (falhando)**

Em `spec/requests/ticket/article_attachments_spec.rb`, a linha 59 é:

```ruby
          expect(response.headers['Content-Security-Policy']).to eq("default-src 'none'")
```

Troque por:

```ruby
          # NDESK-60: sem X-Frame-Options, a política de download declara frame-ancestors 'self'.
          expect(response.headers['Content-Security-Policy']).to eq("default-src 'none'; frame-ancestors 'self'")
```

Na linha 240, `headers: { 'Range' => "bytes=0-99999" }` usa aspas duplas sem interpolação
(`Style/StringLiterals`, offense pré-existente na base). Troque por:

```ruby
            headers: { 'Range' => 'bytes=0-99999' }
```

- [ ] **Step 2: Rodar a spec e confirmar que falha só nessa expectativa**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
set +e
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/ticket/article_attachments_spec.rb > "$S/task2-red.log" 2>&1
set -e
grep -E 'examples?, [0-9]+ failures?' "$S/task2-red.log"
grep -q '15 examples, 1 failure' "$S/task2-red.log"
grep -q "expected: \"default-src 'none'; frame-ancestors 'self'\"" "$S/task2-red.log"
grep -q "got: \"default-src 'none'\"" "$S/task2-red.log"
echo RED_OK
GATE
```

Expected: `15 examples, 1 failure`, com `expected: "default-src 'none'; frame-ancestors 'self'"` e
`got: "default-src 'none'"`, e `RED_OK` (reproduzido em 2026-09-16).

- [ ] **Step 3: Declarar a diretiva na política nula**

Em `app/controllers/application_controller/has_download.rb`, o método `set_null_csp` (linhas 34-36) é:

```ruby
  def set_null_csp
    request.content_security_policy = ActionDispatch::ContentSecurityPolicy.new.tap { |p| p.default_src :none }
  end
```

Troque por:

```ruby
  def set_null_csp
    request.content_security_policy = ActionDispatch::ContentSecurityPolicy.new.tap do |p|
      p.default_src :none
      # NDESK-60: default-src não é fallback de frame-ancestors; sem o X-Frame-Options, esta
      # diretiva preserva a postura SAMEORIGIN dos anexos servidos inline.
      p.frame_ancestors :self
    end
  end
```

- [ ] **Step 4: Rodar as duas specs de contrato e confirmar verde**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/ticket/article_attachments_spec.rb spec/requests/frame_ancestors_spec.rb \
  > "$S/task2-green.log" 2>&1
grep -E 'examples?, [0-9]+ failures?' "$S/task2-green.log"
grep -q '19 examples, 0 failures' "$S/task2-green.log"
echo GREEN_OK
GATE
```

Expected: `19 examples, 0 failures` e `GREEN_OK`.

- [ ] **Step 5: RuboCop e commit**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
bundle exec rubocop app/controllers/application_controller/has_download.rb \
  spec/requests/ticket/article_attachments_spec.rb
git add app/controllers/application_controller/has_download.rb spec/requests/ticket/article_attachments_spec.rb
git commit -q -m "feat(csp): política de download declara frame-ancestors 'self' (NDESK-60)" \
  -m "Sem o X-Frame-Options, default-src 'none' não restringia ancestrais dos anexos servidos inline. A diretiva preserva a postura SAMEORIGIN anterior; a spec de anexos pina o valor exato e corrige um Style/StringLiterals pré-existente na linha 240." \
  -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git log --oneline -1
GATE
```

Expected: `2 files inspected, no offenses detected` e o commit listado.

---

### Task 3: ADR e changelog

**Files:**

- Create: `docs/adr/0001-nchat-embed-frame-ancestors.md`
- Modify: `.claude/NEWBYTE_WORKFLOW.md:26` (tag atual) e fim do arquivo (seção Changelog é a última)

**Interfaces:**

- Consumes: Tasks 1 e 2 (o que a ADR descreve já está no código); a task de follow-up
  [NCHATV4-271](https://plane.byte.newbyte.net.br/engenharia/browse/NCHATV4-271/) já existe (criada em
  2026-09-16, projeto NChat V4, responsável Gustavo Pies Ternus, relacionada à NDESK-60).
- Produces: documentação que o corpo da PR (Task 4 Step 5) e a QA referenciam.

- [ ] **Step 1: Escrever a ADR**

Crie `docs/adr/0001-nchat-embed-frame-ancestors.md`. O diretório `docs/adr/` é novo: decisões sistêmicas
vivem em `docs/adr/` (`.claude/skills/grill-with-docs/ADR-FORMAT.md`); os contextos CSAT e Taskbar têm as
suas próprias ADRs em `docs/{contexto}/adr/`.

```markdown
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
```

- [ ] **Step 2: Corrigir a tag atual e acrescentar a entrada de changelog**

Em `.claude/NEWBYTE_WORKFLOW.md`, a linha 26 diz que a tag mais recente é `nb.v1.3`; troque por `nb.v1.6`.
Depois acrescente a entrada abaixo **no fim do arquivo**: a seção Changelog é a última, e a entrada anterior
(2026-09-08, NDESK-45) começa na linha 166 e vai até o fim. Mantenha uma linha em branco antes de cada
lista (as entradas anteriores fazem isso; sem ela o lint acusa MD032):

```markdown
### 2026-09-16 - branch feat/nchat-embed-frame-ancestors (NDESK-60)

**Branch**: `feat/nchat-embed-frame-ancestors`

Alteracoes:

- **Embed do NDesk nos Aplicativos do NChat**: a CSP global declara
  `frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br`; o
  `X-Frame-Options: SAMEORIGIN` do Rails sai dos headers padrão (logo após `load_defaults 8.1`, que
  substitui o hash inteiro); a política de download de anexos passa a
  `default-src 'none'; frame-ancestors 'self'`. Nenhuma outra diretiva muda. Contrato e limitações do
  lado do NChat (`allow=` no iframe, credenciais na URL do `chat` antigo, auth só por senha/TOTP no
  embed) na ADR `docs/adr/0001-nchat-embed-frame-ancestors.md`; follow-up no NChat: NCHATV4-271.

Arquivos modificados:

- `config/initializers/content_security_policy.rb`
- `config/application.rb`
- `app/controllers/application_controller/has_download.rb`
- `spec/requests/frame_ancestors_spec.rb` (novo)
- `spec/requests/ticket/article_attachments_spec.rb`
- `docs/adr/0001-nchat-embed-frame-ancestors.md` (novo)
- `docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md` e
  `docs/plans/2026-09-16-nchat-embed-frame-ancestors.md` (novos)
```

- [ ] **Step 3: Lint (ADR limpa; workflow sem erro novo) e commit**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
pnpm exec markdownlint-cli2 docs/adr/0001-nchat-embed-frame-ancestors.md
# .claude/NEWBYTE_WORKFLOW.md: 23 erros legados na base; a entrada nova não pode acrescentar nenhum.
set +e
pnpm exec markdownlint-cli2 .claude/NEWBYTE_WORKFLOW.md > "$S/task3-workflow-lint.log" 2>&1
set -e
grep -E '^Summary: [0-9]+ error' "$S/task3-workflow-lint.log"
grep -q '^Summary: 23 error' "$S/task3-workflow-lint.log"
git add docs/adr/0001-nchat-embed-frame-ancestors.md .claude/NEWBYTE_WORKFLOW.md
git commit -q -m "docs(adr): embed do NDesk nos aplicativos do NChat e changelog (NDESK-60)" \
  -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git log --oneline -1
GATE
```

Expected: `0 error(s)` na ADR, `Summary: 23 error(s)` no workflow (igual à base) e o commit listado. Se a
contagem passar de 23, a entrada nova introduziu erro: corrija a entrada, não o legado.

---

### Task 4: Gates locais, push e corpo da PR

**Files:** nenhum modificado (o corpo da PR fica em `$S` até o usuário pedir a PR).

**Interfaces:**

- Consumes: Tasks 0–3.
- Produces: branch pushada; corpo da PR pronto; republicação de spec/plano no Plane (skill
  `dev-execution`).

- [ ] **Step 1: Suíte alvo, RuboCop, markdownlint e invariante das origens**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S="${SCRATCHPAD:?}"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/frame_ancestors_spec.rb spec/requests/ticket/article_attachments_spec.rb \
  spec/config/framework_defaults_spec.rb spec/requests/framework_query_string_spec.rb \
  > "$S/task4-rspec.log" 2>&1
grep -E 'examples?, [0-9]+ failures?' "$S/task4-rspec.log"
grep -q '30 examples, 0 failures' "$S/task4-rspec.log"
bundle exec rubocop config/application.rb config/initializers/content_security_policy.rb \
  app/controllers/application_controller/has_download.rb spec/requests/frame_ancestors_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb
pnpm exec markdownlint-cli2 docs/adr/0001-nchat-embed-frame-ancestors.md \
  docs/plans/2026-09-16-nchat-embed-frame-ancestors-design.md \
  docs/plans/2026-09-16-nchat-embed-frame-ancestors.md
# Invariante: cada origem do NChat ocorre em exatamente dois arquivos Ruby (initializer e spec).
for origin in https://chat.newbyte.net.br https://nchat.newbyte.net.br; do
  test "$(git grep -l --fixed-strings "$origin" -- '*.rb' | sort | tr '\n' ' ')" = \
    "config/initializers/content_security_policy.rb spec/requests/frame_ancestors_spec.rb "
done
echo GATES_OK
GATE
```

Expected: `30 examples, 0 failures`, `no offenses detected`, `0 error(s)` e `GATES_OK`.

- [ ] **Step 2: Runtime local (prova formato e remoção do XFO; a CSP em development é report-only)**

Com o servidor dev de pé (`bundle exec script/rails server -b 127.0.0.1 -p 3000`; a porta 3000 pode
estar ocupada pelo Puma do NChat — nesse caso use `-p 3001` e ajuste a URL):

```bash
bash -euo pipefail <<'GATE'
S="${SCRATCHPAD:?}"
curl -fsS -D "$S/task4-local-headers.txt" -o /dev/null http://127.0.0.1:3000/
tr -d '\r' < "$S/task4-local-headers.txt" | grep -i '^content-security-policy-report-only:' \
  | grep -q "frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br"
! grep -qi '^x-frame-options' "$S/task4-local-headers.txt"
echo LOCAL_OK
GATE
```

Expected: `LOCAL_OK`. Se não houver servidor local, pule este passo e registre no handoff: o gate real
de headers é o preview da PR (Task 5).

- [ ] **Step 3: Push da branch (sem abrir PR)**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
# Untracked locais desta máquina que nunca entram em commit: devcontainer-lock (listado em
# .claude/NEWBYTE_WORKFLOW.md) e artefatos de sessão (settings.local.json, skills/, .newbyte/qa/, skills-lock.json).
if git status --short | grep -vE '^\?\? (\.claude/settings\.local\.json|\.claude/skills/|\.devcontainer/default/devcontainer-lock\.json|\.newbyte/qa/|skills-lock\.json)$'; then
  echo "árvore suja: resolva antes do push"; exit 1
fi
test "$(git rev-list --count origin/newbyte-stable..HEAD)" = 4
git log --oneline origin/newbyte-stable..HEAD
git push -u origin feat/nchat-embed-frame-ancestors
GATE
```

Expected: 4 commits listados (docs, feat, feat, docs) e o push aceito.

- [ ] **Step 4: Republicar spec e plano no Plane** (procedimento `publicar-plane.md` da skill
  `dev-execution`, sub-item Planning NDESK-61, cabeçalho "fim da Execution"): só se os hashes dos dois
  arquivos mudaram desde a publicação do fim do Planning; read-back obrigatório.

- [ ] **Step 5: Corpo da PR (só quando o usuário pedir a PR; base `newbyte-stable`)**

Grave em `$S/pr-body.md` e use com `gh pr create -R newbytesolucoesdigitais/ndesk --base newbyte-stable
--title "feat(csp): embed do NDesk nos aplicativos do NChat via frame-ancestors (NDESK-60)" --body-file
"$S/pr-body.md"`; se o GraphQL falhar, use a API REST descrita em `.claude/NEWBYTE_WORKFLOW.md`:

```markdown
## 📋 Task

[NDESK-60 — Permitir embed do NDesk nos aplicativos do NChat (frame-ancestors allowlist)](https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-60/)

## 🧭 Contexto

Colocar o NDesk como Aplicativo do NChat (iframe em `https://chat.newbyte.net.br` e
`https://nchat.newbyte.net.br`) falhava: o NDesk respondia `X-Frame-Options: SAMEORIGIN` e uma CSP sem
`frame-ancestors`, então o navegador recusava o documento. Só header, gerado pelo Rails. Mesma demanda da
NCOLLECT-64 (PR 480 do NCollect), com mecanismo mais simples: diretiva nativa do Rails.

## 🔨 O que foi feito

- `config/initializers/content_security_policy.rb`: `frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br` (app inteiro; origem exata, sem wildcard).
- `config/application.rb`: `X-Frame-Options` removido dos `default_headers` logo após `load_defaults 8.1` (que substitui o hash inteiro). Navegadores com CSP2 já ignoravam o XFO na presença de `frame-ancestors`; o header contraditório saiu.
- `has_download.rb`: política de download passa a `default-src 'none'; frame-ancestors 'self'` (sem XFO, `default-src` não restringia ancestrais dos anexos inline).
- `spec/requests/frame_ancestors_spec.rb`: oráculo de config, `GET /`, `GET /api/v1/getting_started` e baseline exato da CSP. Spec de anexos atualizada.
- ADR `docs/adr/0001-nchat-embed-frame-ancestors.md`: risco aceito (UI redressing transitivo; credenciais do `chat` antigo na URL), auth no embed só por sessão/senha/TOTP, contrato do NChat.

**Contrato do lado do NChat** (task NCHATV4-271): iframe sem `sandbox`/`credentialless`; `allow="microphone; clipboard-write; camera; fullscreen"` para áudio, copiar, webcam e tela cheia. Sem o `allow=`, o embed básico já funciona com esta PR.

## 🧪 Como testar

1. `bundle exec rspec spec/requests/frame_ancestors_spec.rb spec/requests/ticket/article_attachments_spec.rb` — **Esperado:** 19 exemplos, 0 falhas.
2. No preview: `curl -fsS -D - -o /dev/null https://ndesk-pr-{N}.staging-preview.newbyte.net.br/ | grep -iE '^(content-security-policy|x-frame-options)'` — **Esperado:** um único CSP com `frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br`; nenhum `x-frame-options`.
3. Registrar o preview como Aplicativo nos dois deploys do NChat — **Esperado:** NDesk renderiza, sessão reaproveitada, login por senha funciona, ticket abre.
4. Iframe numa página HTTPS de outro domínio — **Esperado:** recusado pelo navegador.
```

---

### Task 5: Roteiro de QA (fase QA, skill `review-qa`)

**Files:** evidências em `.newbyte/qa/{N}/` (pasta da PR, conforme `.newbyte/qa/README.md`); nada
commitado no código.

**Interfaces:**

- Consumes: PR aberta (número `N`) e o preview `https://ndesk-pr-{N}.staging-preview.newbyte.net.br`
  (aplica os headers do Rails, ao contrário do preview do NCollect); acesso administrativo aos dois
  deploys do NChat (usuário ou Gustavo Pies Ternus, responsável pela NCHATV4-271) para cadastrar um
  Aplicativo.
- Produces: checklist QA Interno da NDESK-63 preenchido (critérios C1–C5 da NDESK-60); evidências em
  `.newbyte/qa/{N}/`.

Mapa critério → passo: **C1** (embed real nos dois deploys) → Step 3; **C2** (header exato) → Step 1;
**C3** (terceiro bloqueado, XFO não contradiz) → Steps 1 e 4; **C4** (spec passa no CI) → Step 5;
**C5** (sem regressão) → Step 6.

- [ ] **Step 1: Headers no preview — comparação exata (C2, C3)**

```bash
bash -euo pipefail <<'GATE'
PR=N   # número da PR
Q=/Users/cauapuppim/newbyte/ndesk/.newbyte/qa/$PR; mkdir -p "$Q"
WANT="frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br"
check_frame_headers() {  # $1 = URL, $2 = arquivo de evidência. GET real; 200; 1 CSP; 0 XFO; diretiva exata.
  curl -fsS -D "$2" -o /dev/null "$1"
  tr -d '\r' < "$2" > "$2.lf"
  grep -Eq '^HTTP/[0-9.]+ 200' "$2.lf"
  test "$(grep -ci '^content-security-policy:' "$2.lf")" = 1
  test "$(grep -ci '^x-frame-options:' "$2.lf")" = 0
  grep -i '^content-security-policy:' "$2.lf" | sed 's/^[^:]*: *//' | tr ';' '\n' | sed 's/^ *//' \
    | grep -qx "$WANT"
}
check_frame_headers "https://ndesk-pr-$PR.staging-preview.newbyte.net.br/" "$Q/headers-root.txt"
check_frame_headers "https://ndesk-pr-$PR.staging-preview.newbyte.net.br/api/v1/getting_started" "$Q/headers-json.txt"
echo PREVIEW_HEADERS_OK
GATE
```

Expected: `PREVIEW_HEADERS_OK`. O gate falha se houver segundo CSP (comma-join na borda), qualquer
`x-frame-options`, uma terceira origem na diretiva ou um status diferente de 200.

- [ ] **Step 2: CSP dos dois deploys do NChat não bloqueia frames filhos (estado observado → gate)**

```bash
bash -euo pipefail <<'GATE'
PR=N
Q=/Users/cauapuppim/newbyte/ndesk/.newbyte/qa/$PR; mkdir -p "$Q"
check_nchat_csp() {  # $1 = host do NChat. Cadeia para frames filhos: frame-src → child-src → default-src.
  curl -fsS -D "$Q/nchat-$1.txt" -o /dev/null "https://$1/"
  csp=$(tr -d '\r' < "$Q/nchat-$1.txt" | grep -i '^content-security-policy:' | sed 's/^[^:]*: *//' || true)
  echo "== $1: ${csp:-<sem CSP>}"
  for d in frame-src child-src default-src; do
    line=$(printf '%s\n' "$csp" | tr ';' '\n' | sed 's/^ *//' | grep "^$d " || true)
    if [ -n "$line" ]; then
      printf '%s\n' "$line" | grep -Eq 'ndesk(-pr-[0-9]+\.staging-preview)?\.newbyte\.net\.br|https://\*\.newbyte\.net\.br|\*\.newbyte\.net\.br|( |^)\*( |$)|( |^)https:( |$)' \
        || { echo "$1: '$line' bloqueia o NDesk"; exit 1; }
      break   # a primeira diretiva presente na cadeia é a que vale
    fi
  done
}
check_nchat_csp chat.newbyte.net.br
check_nchat_csp nchat.newbyte.net.br
echo NCHAT_CSP_OK
GATE
```

Expected: `NCHAT_CSP_OK`. Em 2026-09-16 os dois deploys emitem só
`frame-ancestors 'self' https://*.newbyte.net.br http://*.newbyte.net.br` (nenhuma diretiva de frames
filhos). Se algum deploy passar a bloquear, o embed falha do lado do NChat: registrar e avisar na
NCHATV4-271.

- [ ] **Step 3: Embed real nos dois deploys (C1)**

Pré-requisitos: acesso administrativo aos dois NChats. Criar um Aplicativo **novo e temporário** em cada
deploy, nome `NDesk (preview PR N)`, URL `https://ndesk-pr-{N}.staging-preview.newbyte.net.br/`; não
alterar Aplicativos existentes. Registrar quem criou e em qual conta em `.newbyte/qa/{N}/roteiro-qa.md`.
Os Aplicativos temporários são apagados na Task 6 (Step 4).

Em Chrome, Firefox e Safari, dentro do Aplicativo, registrar ✅/❌ por navegador:

1. o NDesk renderiza (sem "refused to connect"/"não pode ser exibido");
2. com sessão já aberta numa aba normal do preview, o embed entra logado (reuso de sessão);
3. em janela anônima, o login por senha (e TOTP, se o usuário tiver) funciona dentro do embed;
4. abrir um ticket, escrever uma nota e receber uma atualização em tempo real (outra aba edita o ticket);
5. `window.open`: num artigo com imagem, "abrir em nova aba" (`article_image_view.coffee:40`) abre a
   imagem numa aba nova;
6. notificações de desktop **com permissão já concedida** ao preview numa aba normal: dentro do embed, uma
   atualização de ticket atribuído gera notificação? Registrar por navegador (limitação esperada: o prompt
   de permissão não aparece dentro do embed);
7. Back do navegador: registrar o comportamento (percorre telas do NDesk; limitação aceita);
8. enviar artigo sem anexo quando o texto menciona anexo: o `confirm()` aparece? Registrar por navegador;
9. imprimir/baixar um anexo: funciona (sem `sandbox`).
10. `/desktop` dentro do embed (um navegador basta): abre e navega (o mecanismo é o mesmo middleware; é
    confirmação de que a D1 cobre a UI nova);
11. anexos dentro do embed: abrir uma imagem inline a partir de um artigo abre em nova aba e renderiza; se
    alguém navegar o próprio iframe para uma URL de `ticket_attachment`, o navegador recusa (cadeia
    NDesk → NChat não casa com `'self'`) — comportamento esperado da D8, registrar;
12. sessão reaproveitada com "Bloquear cookies de terceiros" ativo no Chrome e ETP estrito no Firefox: os três
    hosts são same-site, então o cookie deve continuar sendo enviado (fecha a premissa §5.6 do spec).

Gravação de áudio e botão de copiar **só** passam depois do `allow=` do NChat (NCHATV4-271): registrar
como "exige mudança no NChat", não como falha desta PR. Injeção de iframe por DevTools em
`chat.newbyte.net.br` vale como pré-teste, não substitui o Aplicativo registrado.

- [ ] **Step 4: Origem de terceiro continua bloqueada (C3)**

Numa página HTTPS de domínio realmente distinto (ex.: um HTML no GitHub Pages ou no CodePen), colar:

```html
<iframe src="https://ndesk-pr-{N}.staging-preview.newbyte.net.br/" style="width:100%;height:600px"></iframe>
```

Expected: o navegador recusa (console: `Refused to frame … because an ancestor violates the following
Content Security Policy directive: "frame-ancestors …"`). Não usar `about:blank` (herda a origem de quem
o criou). Guardar a captura em `.newbyte/qa/{N}/`.

- [ ] **Step 5: A spec nova rodou e passou no CI (C4)**

```bash
bash -euo pipefail <<'GATE'
PR=N
Q=/Users/cauapuppim/newbyte/ndesk/.newbyte/qa/$PR; mkdir -p "$Q"
RUN=$(gh run list -R newbytesolucoesdigitais/ndesk --branch feat/nchat-embed-frame-ancestors \
  --workflow ci-test.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$RUN" -R newbytesolucoesdigitais/ndesk --log > "$Q/ci-run-$RUN.log"
grep -l 'frame_ancestors_spec' "$Q/ci-run-$RUN.log"
grep 'frame_ancestors_spec' "$Q/ci-run-$RUN.log" | head -3
gh run view "$RUN" -R newbytesolucoesdigitais/ndesk --json conclusion --jq '.conclusion' | grep -qx success
echo CI_OK
GATE
```

Expected: o log mostra `spec/requests/frame_ancestors_spec.rb` executada num shard de RSpec e a conclusão
do run é `success`. Flakes conhecidos do Frontend (`TicketBulkEditFlyout`, mobile ticket-create):
`gh run rerun --failed` e repetir. Anotar o número do run e o shard no roteiro.

- [ ] **Step 6: Regressão rápida (C5)**

Fora de iframe, no preview: login, abrir ticket, upload e download de anexo (imagem inline abre; PDF
baixa), Knowledge Base pública abre. Nada mudou fora dos headers.

---

### Task 6: Release (fase Release, skill `release`)

**Files:** nenhum modificado neste repo.

**Interfaces:**

- Consumes: NDESK-63 (QA) em **Done** com o checklist aprovado; PR aprovada.
- Produces: tag `nb.v{next}`, produção com os headers novos, Aplicativos do NChat apontando para produção,
  NDESK-64 e NDESK-60 fechadas.

- [ ] **Step 1: Pré-condição e merge com tag** — confirmar NDESK-63 Done; merge via API e tag
  `nb.v{next}` no commit de merge conforme `.claude/NEWBYTE_WORKFLOW.md` (perguntar a versão ao usuário).
  O deploy em produção dispara pela tag.

- [ ] **Step 2: Headers em produção (mesmo gate do preview) e CSP do NChat de novo**

```bash
bash -euo pipefail <<'GATE'
S="${SCRATCHPAD:?}"
WANT="frame-ancestors 'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br"
check_frame_headers() {
  curl -fsS -D "$2" -o /dev/null "$1"
  tr -d '\r' < "$2" > "$2.lf"
  grep -Eq '^HTTP/[0-9.]+ 200' "$2.lf"
  test "$(grep -ci '^content-security-policy:' "$2.lf")" = 1
  test "$(grep -ci '^x-frame-options:' "$2.lf")" = 0
  grep -i '^content-security-policy:' "$2.lf" | sed 's/^[^:]*: *//' | tr ';' '\n' | sed 's/^ *//' \
    | grep -qx "$WANT"
}
check_frame_headers https://ndesk.newbyte.net.br/ "$S/release-headers-root.txt"
check_frame_headers https://ndesk.newbyte.net.br/api/v1/getting_started "$S/release-headers-json.txt"
grep -i '^content-security-policy:' "$S/release-headers-root.txt.lf" | grep -q "base-uri 'self' https://ndesk.newbyte.net.br"
for host in chat.newbyte.net.br nchat.newbyte.net.br; do
  csp=$(curl -fsS -D - -o /dev/null "https://$host/" | tr -d '\r' | grep -i '^content-security-policy:' | sed 's/^[^:]*: *//' || true)
  echo "== $host: ${csp:-<sem CSP>}"
  for d in frame-src child-src default-src; do
    line=$(printf '%s\n' "$csp" | tr ';' '\n' | sed 's/^ *//' | grep "^$d " || true)
    if [ -n "$line" ]; then
      printf '%s\n' "$line" | grep -Eq 'ndesk\.newbyte\.net\.br|https://\*\.newbyte\.net\.br|\*\.newbyte\.net\.br|( |^)\*( |$)|( |^)https:( |$)' \
        || { echo "$host: '$line' bloqueia o NDesk"; exit 1; }
      break
    fi
  done
done
echo RELEASE_HEADERS_OK
GATE
```

Expected: `RELEASE_HEADERS_OK`.

Se o gate falhar com um segundo `content-security-policy` ou um `x-frame-options` que o Rails não emite, a
borda (Transform Rules do Cloudflare, invisível pelo repo) está reinjetando header: corrigir lá antes de
fechar o Release.

- [ ] **Step 3: Apontar os Aplicativos para produção** — nos dois deploys do NChat, trocar a URL dos
  Aplicativos criados na Task 5 para `https://ndesk.newbyte.net.br/` (ou criar os definitivos e apagar os
  temporários `NDesk (preview PR N)`), e repetir os itens 1–4 do Step 3 da Task 5 em um navegador.

- [ ] **Step 4: Fechar no Plane** (skill `release`): NDESK-64 Done e NDESK-60 Done, com comentário de
  fechamento citando a tag e a dependência aberta NCHATV4-271 (`allow=` no iframe; credenciais na URL do
  `chat` antigo). Apagar os Aplicativos temporários se ainda existirem.

## Auto-revisão do plano (2026-09-16, após o grill)

- **Cobertura do spec:** §4.1 → Task 1 Step 3; §4.2 → Task 1 Step 4; §4.3 → Task 2; §4.4 → Task 1 Step 1
  (oráculo, `/`, JSON, baseline) e Task 2 Step 1 (anexos); §4.5 → Tasks 0, 3 e 4 Step 4 (publicação no
  Plane); §5 e §6 → ADR (Task 3) e corpo da PR (Task 4 Step 5); §7 → Tasks 4, 5 e 6, com os critérios
  C1–C5 da NDESK-60 mapeados na Task 5; §8 (fora do escopo) → nenhuma task toca NChat, nginx, Cloudflare
  ou outras diretivas.
- **Placeholders:** os valores preenchidos em execução são o número da PR (`PR=N`, `{N}`, Tasks 4–6), a
  próxima tag (`nb.v{next}`, Task 6) e a variável `SCRATCHPAD` da sessão. A task de follow-up do NChat já
  tem identificador (NCHATV4-271).
- **Consistência:** o helper `csp_directives` e o `let(:allowlist)` existem só na spec; a string da
  política de download (`default-src 'none'; frame-ancestors 'self'`) e a allowlist são idênticas entre
  spec, plano, ADR e gates de `curl`; a invariante "cada origem em exatamente dois arquivos Ruby" tem gate
  próprio (Task 4 Step 1).
