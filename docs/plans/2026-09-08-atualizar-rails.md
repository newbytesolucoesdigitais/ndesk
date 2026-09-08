# Plano — Atualizar Rails 8.0.4 → 8.1.3.1 (NDESK-45)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** Subir o NDesk de Rails 8.0.4 para 8.1.3.1 com `config.load_defaults 8.1` e Brakeman 8.0.6, para o
check Security Scan do CI voltar a passar sem o warning EOLRails.

**Architecture:** Dois commits de implementação numa única PR sobre `newbyte-stable`: (1) bump de gems
e ajustes que mudam só pela troca das gems; (2) `load_defaults 8.1` com um teste por default. Cada commit
passa nos gates locais (boot, `zeitwerk:check`, Brakeman, specs afetadas); os 12 jobs de `ci-test.yml`
são o gate remoto; o preview da PR é o gate de smoke.

**Tech Stack:** Ruby 3.4.8 (rbenv), Rails 8.1.3.1, Bundler 2.6.9, PostgreSQL 17 e Redis locais, RSpec,
Brakeman 8.0.6, GitHub Actions.

**Spec:** `docs/plans/2026-09-08-atualizar-rails-design.md` (v2, aprovada). O plano argumenta a partir
dela; quem executa lê os dois.

## Restrições globais

- Ruby fica em **3.4.8** (`Gemfile:6`, `.ruby-version`); não instalar outra versão para o bundle.
- Rails alvo **8.1.3.1** via `gem 'rails', '~> 8.1.0'`; Brakeman **8.0.6**.
- **Allowlist do lock** (spec §4.1): Rails e seus 12 componentes `8.0.4 → 8.1.3.1`; `brakeman 8.0.2 →
  8.0.6`; `action_text-trix` adicionada; `benchmark` removida; vínculo de `json` declarado com versão
  mantida; `rack` continua `2.2.22`. Qualquer outra mudança de versão **para a execução** e reabre o
  escopo com o usuário.
- `config.load_defaults 8.1` sem arquivo `new_framework_defaults_8_1.rb`.
- Deprecação disparada por código do app é corrigida na origem; nunca entra em
  `spec/support/deprecation_toolkit.rb`.
- Commits: exatamente dois de implementação (bump; defaults). Mensagens no padrão do repo
  (`chore(deps): …`, `chore(config): …`) com os trailers `Co-Authored-By` e `Claude-Session` da sessão.
- Arquivos Ruby novos começam com
  `# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/` (cop do Rubocop).
- Rubocop limpo nos arquivos tocados (`bundle exec rubocop <arquivos>`).
- Arquivos temporários só em
  `/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad`
  (abaixo, `$S`).
- Branch `chore/rails-8.1-upgrade`; nada de `git push --force` depois que a PR existir.

## Arquivos

| Ação | Arquivo | Responsabilidade |
|---|---|---|
| Modificar | `Gemfile:7` | constraint do Rails |
| Modificar | `Gemfile.lock` | resolução (allowlist) |
| Modificar | `config/application.rb:22-23` | `load_defaults 8.1` + comentário |
| Modificar | `app/controllers/external_credentials_controller.rb:47` | passar `allow_other_host` de fato |
| Criar | `spec/config/framework_defaults_spec.rb` | contrato dos sete ajustes do 8.1 + encoder + finders |
| Criar | `spec/controllers/framework_defaults_redirect_spec.rb` | guarda de redirect relativo ativa |
| Criar | `spec/requests/framework_defaults_json_spec.rb` | corpo JSON bruto sem escape |
| Modificar | `spec/requests/external_credentials_spec.rb` | formato da URL nos redirects do callback |
| Criar (scratchpad) | `$S/diff_internals.sh` | diff dos métodos reabertos 8.0.4 × 8.1.3.1 |

---

### Task 0: Ambiente local e baseline

**Files:**

- Nenhum arquivo do repo muda. Saídas em `$S/`.

**Interfaces:**

- Produces: Ruby 3.4.8 ativo, bundle instalado, banco `zammad_test` preparado, fontes do Rails 8.1.3.1
  em `$S/rails-8.1.3.1/`, evidência do Brakeman falhando em `$S/baseline-brakeman.txt`.

- [ ] **Step 1: Instalar Ruby 3.4.8 e o Bundler do lock**

```bash
cd /Users/cauapuppim/newbyte/ndesk
rbenv install 3.4.8          # ruby-build lista 3.4.8; leva alguns minutos
ruby -v                      # esperado: ruby 3.4.8
gem install bundler:2.6.9
bundle -v                    # esperado: Bundler version 2.6.9
```

- [ ] **Step 2: Instalar as gems atuais (ainda Rails 8.0.4) e as dependências de frontend**

```bash
bundle install -j "$(sysctl -n hw.ncpu)"
pnpm install --frozen-lockfile
```

Esperado: "Bundle complete!" e `pnpm` sem erro. Se `pg` ou `rszr` falharem ao compilar, instalar
`brew install libpq imlib2` e repetir.

- [ ] **Step 3: Apontar o banco local**

`config/database.yml` é ignorado pelo git e é cópia de `config/database/database.yml`. Confirmar que o
usuário do sistema entra no PostgreSQL 17 do Homebrew sem senha:

```bash
psql -d postgres -c 'select current_user, version();'
```

Se falhar, descomentar `username:` em `config/database.yml` com o usuário que o `psql` aceita. Não
commitar esse arquivo.

- [ ] **Step 4: Preparar banco e assets de teste**

```bash
RAILS_ENV=test bundle exec rake db:drop db:create zammad:ci:test:prepare
RAILS_ENV=test bin/rails assets:precompile
```

Esperado: sem erro. Se `zammad:ci:test:prepare` não existir nesta base, usar o comando do CI:
`RAILS_ENV=test bundle exec rake zammad:db:init`.

- [ ] **Step 5: Baseline (Rails 8.0.4): boot, Zeitwerk, Brakeman falhando, specs de referência**

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
bundle exec rails runner 'puts Rails.version'                     # esperado: 8.0.4
bundle exec rails zeitwerk:check                                  # esperado: All is good!
bundle exec brakeman -o /dev/stdout -o "$S/baseline-brakeman.html" | tee "$S/baseline-brakeman.txt"; echo "exit=${PIPESTATUS[0]}"
# esperado: "Check: EOLRails", "Support for Rails 8.0.4 ends on 2026-10-07", exit=3
bundle exec rspec spec/requests/session_spec.rb spec/requests/external_credentials_spec.rb
# esperado: 0 failures
```

- [ ] **Step 6: Baixar as fontes do Rails 8.1.3.1 para o diff dos internals**

```bash
mkdir -p "$S/rails-8.1.3.1" && cd "$S/rails-8.1.3.1"
for g in actionpack activerecord activesupport activejob activemodel railties; do
  gem fetch "$g" -v 8.1.3.1 && gem unpack "$g-8.1.3.1.gem"
done
ls -d */                      # esperado: actionpack-8.1.3.1/ activerecord-8.1.3.1/ ... (6 diretórios)
cd /Users/cauapuppim/newbyte/ndesk
```

- [ ] **Step 7: Diff dos métodos reaberto pelo NDesk (spec §2.6)**

Criar `$S/diff_internals.sh`:

```bash
#!/usr/bin/env bash
# Compara os arquivos upstream reabertos pelo NDesk entre o Rails instalado e o 8.1.3.1 descompactado.
set -uo pipefail
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
NEW="$S/rails-8.1.3.1"
cmp_file() { # gem, caminho relativo, regex dos métodos que o NDesk reabre/chama
  local gem=$1 rel=$2 methods=$3
  local old="$(bundle show "$gem")/$rel" new="$NEW/$gem-8.1.3.1/$rel"
  echo "### $gem/$rel"
  if diff -q "$old" "$new" >/dev/null; then echo "   idêntico"; return; fi
  diff -u "$old" "$new" | grep -E "^[-+].*def ($methods)\b" || echo "   nenhuma linha 'def' de ($methods) mudou"
  echo "   linhas alteradas no arquivo: $(diff -u "$old" "$new" | grep -cE '^[-+][^-+]')"
}
cmp_file actionpack    lib/action_dispatch/middleware/cookies.rb                          'write_cookie\?'
cmp_file activerecord  lib/active_record/connection_adapters/abstract/schema_statements.rb 'quoted_columns_for_index|add_index_options'
cmp_file activerecord  lib/active_record/connection_adapters/postgresql/schema_statements.rb 'quoted_columns_for_index'
cmp_file activerecord  lib/active_record/store.rb                                        'as_indifferent_hash|load|dump'
cmp_file activerecord  lib/active_record/locking/pessimistic.rb                          'lock!|with_lock'
cmp_file activerecord  lib/active_record/relation/calculations.rb                        'pluck|arel_columns'
cmp_file activerecord  lib/active_record/relation/batches.rb                             'find_each|find_in_batches|in_batches'
cmp_file activesupport lib/active_support/callbacks.rb                                   'set_callback|skip_callback|define_callbacks'
cmp_file activesupport lib/active_support/tagged_logging.rb                              'call|tagged|push_tags'
cmp_file activesupport lib/active_support/cache/file_store.rb                            '.*'
cmp_file activejob     lib/active_job/queue_adapters/delayed_job_adapter.rb              'max_attempts|perform|enqueue'
cmp_file activemodel   lib/active_model/error.rb                                         '.*'
```

Rodar com o Rails 8.0.4 ainda instalado (é o "old"):

```bash
chmod +x "$S/diff_internals.sh" && "$S/diff_internals.sh" | tee "$S/diff-internals.txt"
```

Esperado: nenhuma linha `def` dos métodos listados mudou. Para `pessimistic.rb`, ler o hunk completo
(`diff -u` dos dois arquivos) e confirmar que `lock!(lock = true)` mantém a assinatura e que o patch de
`config/initializers/active_record_lock_issue_3664.rb` continua correto ao delegar para `orig_lock!`.
Qualquer `def` alterado vira ajuste no commit 1 (Task 1, Step 6), com o método local adaptado.

---

### Task 1: Commit 1 — bump Rails 8.1.3.1 + Brakeman 8.0.6

**Files:**

- Modify: `Gemfile:7`
- Modify: `Gemfile.lock`
- Test: gates locais (boot, `zeitwerk:check`, Brakeman, specs listadas no Step 6)

**Interfaces:**

- Consumes: ambiente da Task 0.
- Produces: commit `chore(deps): Rails 8.0.4 → 8.1.3.1 e Brakeman 8.0.6 (NDESK-45)`; `Rails.version ==
  "8.1.3.1"`; Brakeman exit 0; `Rails.application.config.loaded_config_version` ainda `8.0`.

- [ ] **Step 1: Mudar a constraint do Rails**

```bash
sed -i '' "s/^gem 'rails', '~> 8.0.0'$/gem 'rails', '~> 8.1.0'/" Gemfile
git diff Gemfile     # esperado: apenas a linha 7
```

- [ ] **Step 2: Resolver o lock sem gravar e comparar com a allowlist**

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
bundle lock --update rails brakeman --conservative --print > "$S/Gemfile.lock.new"
extract() { grep -E '^    [A-Za-z0-9_.-]+ \([0-9]' "$1" | sed -E 's/^ +//' | sort; }
diff <(extract Gemfile.lock) <(extract "$S/Gemfile.lock.new") | tee "$S/lock-diff.txt"
```

Esperado, e **nada além disto**:

```text
< actioncable (8.0.4)        > actioncable (8.1.3.1)
< actionmailbox (8.0.4)      > actionmailbox (8.1.3.1)
< actionmailer (8.0.4)       > actionmailer (8.1.3.1)
< actionpack (8.0.4)         > actionpack (8.1.3.1)
< actiontext (8.0.4)         > actiontext (8.1.3.1)
< actionview (8.0.4)         > actionview (8.1.3.1)
< activejob (8.0.4)          > activejob (8.1.3.1)
< activemodel (8.0.4)        > activemodel (8.1.3.1)
< activerecord (8.0.4)       > activerecord (8.1.3.1)
< activestorage (8.0.4)      > activestorage (8.1.3.1)
< activesupport (8.0.4)      > activesupport (8.1.3.1)
< rails (8.0.4)              > rails (8.1.3.1)
< railties (8.0.4)           > railties (8.1.3.1)
< brakeman (8.0.2)           > brakeman (8.0.6)
                             > action_text-trix (2.1.x)
< benchmark (0.x)
```

`rack (2.2.22)` não pode aparecer no diff. Se o Bundler não destravar os componentes, repetir nomeando
todos: `bundle lock --update rails actioncable actionmailbox actionmailer actionpack actiontext actionview
activejob activemodel activerecord activestorage activesupport railties brakeman --conservative --print`.
Se aparecer qualquer outra gem, **parar** e levar o diff ao usuário (spec D5).

- [ ] **Step 3: Gravar o lock e instalar**

```bash
bundle lock --update rails brakeman --conservative   # mesma forma que passou no Step 2
bundle install -j "$(sysctl -n hw.ncpu)"
diff <(extract Gemfile.lock) <(extract "$S/Gemfile.lock.new") && echo "lock igual ao previsto"
```

- [ ] **Step 4: Gates de boot e Brakeman**

```bash
bundle exec rails runner 'puts Rails.version; puts Rails.application.config.loaded_config_version'
# esperado: 8.1.3.1 e 8.0
bundle exec rails zeitwerk:check                                    # esperado: All is good!
bundle exec brakeman -o /dev/stdout -o "$S/brakeman-8.1.html" | tee "$S/brakeman-8.1.txt"; echo "exit=${PIPESTATUS[0]}"
# esperado: "Security Warnings: 0", nenhum "EOLRails", exit=0
```

Se o Brakeman 8.0.6 trouxer warning novo: corrigir o código se for achado real; se for falso positivo,
`bundle exec brakeman -I` gera a entrada em `config/brakeman.ignore` e a justificativa vai na mensagem
do commit (spec §4.3.6).

- [ ] **Step 5: Repetir o diff dos internals com as gems instaladas**

```bash
"$S/diff_internals.sh" | tee "$S/diff-internals-after.txt"
```

Esperado: cada arquivo "idêntico" (agora old == new). O que importa foi decidido na Task 0, Step 7; este
passo só confirma que o `bundle show` aponta para 8.1.3.1.

- [ ] **Step 6: Specs afetadas pelo bump (comportamentos always-on da spec §2.5)**

```bash
bundle exec rspec \
  spec/requests/session_spec.rb \
  spec/requests/external_credentials_spec.rb \
  spec/requests/ticket_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb \
  spec/lib/core_ext \
  spec/lib/sessions \
  spec/jobs \
  spec/models/ticket_spec.rb \
  spec/models/user_group_spec.rb spec/models/role_group_spec.rb 2>&1 | tail -40
```

Esperado: 0 failures (os dois últimos arquivos podem não existir; nesse caso removê-los do comando).
Falha por deprecação (mensagem `DEPRECATION WARNING` com stack em `app/` ou `lib/`) é corrigida na origem
e entra neste commit. O spec do cookie `Secure` (`session_spec.rb`, "sets Cookie with 'secure' flag") é
o teste contratual dos três patches de cookie da spec §2.6.

- [ ] **Step 7: Rubocop e commit 1**

```bash
bundle exec rubocop Gemfile
git add Gemfile Gemfile.lock
git commit -F - <<'MSG'
chore(deps): Rails 8.0.4 → 8.1.3.1 e Brakeman 8.0.6 (NDESK-45)

Corrige o check Security Scan do CI: o Brakeman 8.0.2 marcava a série
Rails 8.0 como EOL em 2026-10-07 (exit 3). Lock: Rails e 12 componentes
8.0.4 → 8.1.3.1, brakeman 8.0.2 → 8.0.6, action_text-trix adicionada,
benchmark removida, rack mantido em 2.2.22. load_defaults segue em 8.0
(commit seguinte adota 8.1).

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DrHNpApXBaQQAeEhi6QVmr
MSG
git log --oneline -1
```

Se o Step 4 ou 6 exigiu mudança de código, incluir os arquivos no `git add` e citar na mensagem.

---

### Task 2: Commit 2 — `config.load_defaults 8.1` (TDD, um oráculo por ajuste)

**Files:**

- Create: `spec/config/framework_defaults_spec.rb`
- Create: `spec/controllers/framework_defaults_redirect_spec.rb`
- Create: `spec/requests/framework_defaults_json_spec.rb`
- Modify: `spec/requests/external_credentials_spec.rb` (dentro de `context 'authenticated as admin'`)
- Modify: `config/application.rb:22-23`
- Modify: `app/controllers/external_credentials_controller.rb:47`

**Interfaces:**

- Consumes: Rails 8.1.3.1 instalado (Task 1).
- Produces: commit `chore(config): adota config.load_defaults 8.1 (NDESK-45)`;
  `Rails.application.config.loaded_config_version.to_s == "8.1"`.

- [ ] **Step 1: Escrever o contrato dos sete ajustes, o encoder e os finders**

`spec/config/framework_defaults_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Contrato dos ajustes de `config.load_defaults 8.1` (spec NDESK-45, §2.5).
# Se um default for revertido de propósito em config/application.rb, o exemplo
# correspondente muda junto, com o motivo registrado na spec da task.
RSpec.describe 'Rails 8.1 framework defaults' do
  let(:config) { Rails.application.config }

  it 'loads the 8.1 defaults' do
    expect(config.loaded_config_version.to_s).to eq('8.1')
  end

  it 'disables YJIT in local environments (development/test)' do
    expect(config.yjit).to be(false)
  end

  it 'does not escape HTML entities in JSON responses' do
    expect(config.action_controller.escape_json_responses).to be(false)
  end

  it 'raises on path-relative redirects' do
    expect(config.action_controller.action_on_path_relative_redirect).to eq(:raise)
  end

  it 'raises on order-dependent finders without order columns' do
    expect(config.active_record.raise_on_missing_required_finder_order_columns).to be(true)
  end

  it 'does not escape JS line/paragraph separators in JSON' do
    expect(config.active_support.escape_js_separators_in_json).to be(false)
  end

  it 'tracks template dependencies with the ruby tracker' do
    expect(config.action_view.render_tracker).to eq(:ruby)
  end

  it 'omits autocomplete="off" on generated hidden fields' do
    expect(config.action_view.remove_hidden_field_autocomplete).to be(true)
  end

  describe 'ActiveSupport::JSON.encode' do
    it 'keeps U+2028 and U+2029 literal' do
      expect(ActiveSupport::JSON.encode("a\u2028b\u2029c")).to eq("\"a\u2028b\u2029c\"")
    end
  end

  describe 'join models with composite primary keys' do
    it 'allows order-dependent finders on UserGroup and RoleGroup' do
      expect { UserGroup.first }.not_to raise_error
      expect { RoleGroup.last }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Escrever a prova de que a guarda de redirect relativo está ativa**

`spec/controllers/framework_defaults_redirect_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `action_on_path_relative_redirect = :raise` (spec NDESK-45, §2.5).
RSpec.describe ActionController::Base, type: :controller do
  controller do
    def index
      redirect_to 'relative-target'
    end
  end

  it 'raises PathRelativeRedirectError for a target without leading slash or scheme' do
    expect { get :index }.to raise_error(ActionController::Redirecting::PathRelativeRedirectError)
  end
end
```

- [ ] **Step 3: Escrever o oráculo do corpo JSON bruto**

`spec/requests/framework_defaults_json_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `escape_json_responses = false` e `escape_js_separators_in_json = false`
# (spec NDESK-45, §2.5). O cliente faz JSON.parse; o que muda são os bytes no fio.
RSpec.describe 'JSON responses with Rails 8.1 defaults', type: :request do
  let(:title)   { "Tag <b>&amp;</b> \"quoted\" \u2028next" }
  let!(:ticket) { create(:ticket, title: title) }
  let(:agent)   { create(:agent, groups: Group.all) }

  before { authenticated_as(agent) }

  it 'sends HTML characters and U+2028 unescaped in the raw body' do
    get "/api/v1/tickets/#{ticket.id}", as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['title']).to eq(title)
    expect(response.body).to include('<b>&amp;</b>').and include("\u2028")
    expect(response.body).not_to include('\u003c')
    expect(response.body).not_to include('\u2028')
  end
end
```

(`'\u003c'` e `'\u2028'` entre aspas simples são as sequências escapadas, com barra literal, que o Rails 8.0
emitia; `"\u2028"` entre aspas duplas é o caractere em si.)

- [ ] **Step 4: Estender o spec de credenciais externas com o formato da URL dos redirects**

Em `spec/requests/external_credentials_spec.rb`, dentro de `context 'authenticated as admin' do`
(depois do `describe '#index'`), adicionar:

```ruby
    describe '#callback redirect targets (Rails 8.1 path-relative redirect guard)' do
      let(:fqdn) { Setting.get('fqdn') }

      before { Setting.set('http_type', 'https') }

      context 'when the backend returns an error URL as String' do
        before do
          allow(ExternalCredential).to receive(:link_account)
            .and_return("https://#{fqdn}/#channels/google/error/AADSTS")
        end

        it 'redirects to that absolute URL' do
          get '/api/v1/external_credentials/google/callback'

          expect(response).to have_http_status(:found)
          expect(response.headers['Location']).to eq("https://#{fqdn}/#channels/google/error/AADSTS")
        end
      end

      context 'when the backend returns a channel' do
        let(:channel) { create(:google_channel) }

        before { allow(ExternalCredential).to receive(:link_account).and_return(channel) }

        it 'redirects to the absolute app URL of the channel' do
          get '/api/v1/external_credentials/google/callback'

          expect(response).to have_http_status(:found)
          expect(response.headers['Location']).to eq("https://#{fqdn}/#channels/google/#{channel.id}")
        end
      end
    end
```

- [ ] **Step 5: Rodar os quatro specs e confirmar o vermelho esperado**

```bash
bundle exec rspec spec/config/framework_defaults_spec.rb \
  spec/controllers/framework_defaults_redirect_spec.rb \
  spec/requests/framework_defaults_json_spec.rb \
  spec/requests/external_credentials_spec.rb 2>&1 | tail -60
```

Esperado com `load_defaults 8.0`:

- `framework_defaults_spec.rb`: falham os 8 exemplos de config (`8.0`, `true`, `true`, `:log`, `false`,
  `true`, `:regex`, `false`) e o do encoder (`"a\\u2028b\\u2029c"`); passa o de `UserGroup`/`RoleGroup`.
- `framework_defaults_redirect_spec.rb`: falha (`:log` não levanta erro).
- `framework_defaults_json_spec.rb`: falha (corpo contém `\u003c`).
- `external_credentials_spec.rb`: os dois exemplos novos **passam** já em 8.0 (são guardas de regressão
  para o commit 2); os antigos continuam passando.

Se algum vermelho for diferente do descrito, entender antes de seguir.

- [ ] **Step 6: Adotar os defaults 8.1**

`config/application.rb`, linhas 22-23, de:

```ruby
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
```

para:

```ruby
    # Framework defaults adotados (NDESK-45): os sete ajustes do 8.1 têm um
    # teste cada em spec/config/framework_defaults_spec.rb.
    config.load_defaults 8.1
```

- [ ] **Step 7: Corrigir a passagem de `allow_other_host` no callback**

`app/controllers/external_credentials_controller.rb:47`, de:

```ruby
    return redirect_to(channel), allow_other_host: true if channel.instance_of?(String)
```

para:

```ruby
    return redirect_to(channel, allow_other_host: true) if channel.instance_of?(String)
```

(Hoje `allow_other_host: true` é o segundo valor do `return` e não chega ao `redirect_to`. Os backends
devolvem URL do próprio host, então o comportamento observável não muda; o spec do Step 4 cobre o caso.)

- [ ] **Step 8: Rodar os quatro specs e confirmar o verde**

```bash
bundle exec rspec spec/config/framework_defaults_spec.rb \
  spec/controllers/framework_defaults_redirect_spec.rb \
  spec/requests/framework_defaults_json_spec.rb \
  spec/requests/external_credentials_spec.rb 2>&1 | tail -20
# esperado: 0 failures
bundle exec rails runner 'c = Rails.application.config; puts [c.loaded_config_version, c.yjit, c.action_controller.escape_json_responses].inspect'
# esperado: [8.1, false, false]
```

- [ ] **Step 9: Specs vizinhas dos sete ajustes**

```bash
bundle exec rspec \
  spec/requests/session_spec.rb \
  spec/requests/ticket_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb \
  spec/requests/knowledge_base_public \
  spec/controllers \
  spec/views \
  spec/lib/sessions \
  spec/lib/core_ext \
  spec/models 2>&1 | tail -40
```

Esperado: 0 failures. `MissingRequiredOrderError` em algum model sem chave é corrigido no call site com
`order(:id)` ou equivalente, nunca desligando o default.

- [ ] **Step 10: Rubocop nos arquivos tocados e commit 2**

```bash
bundle exec rubocop config/application.rb app/controllers/external_credentials_controller.rb \
  spec/config/framework_defaults_spec.rb spec/controllers/framework_defaults_redirect_spec.rb \
  spec/requests/framework_defaults_json_spec.rb spec/requests/external_credentials_spec.rb
git add config/application.rb app/controllers/external_credentials_controller.rb spec/config \
  spec/controllers/framework_defaults_redirect_spec.rb spec/requests/framework_defaults_json_spec.rb \
  spec/requests/external_credentials_spec.rb
git commit -F - <<'MSG'
chore(config): adota config.load_defaults 8.1 (NDESK-45)

Sete ajustes do 8.1 com um teste cada (spec/config/framework_defaults_spec.rb):
yjit só em produção, JSON sem escape de HTML e de U+2028/2029, redirect relativo
levanta erro, finders sem ordem em model sem chave levantam erro, render_tracker
:ruby, hidden fields sem autocomplete. Corrige a passagem de allow_other_host no
callback de credenciais externas.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DrHNpApXBaQQAeEhi6QVmr
MSG
git log --oneline -3
```

---

### Task 3: Pré-check completo, push e material da PR

**Files:**

- Nenhum arquivo novo. Correções encontradas aqui entram no commit certo via `--fixup` + autosquash.

**Interfaces:**

- Consumes: commits 1 e 2.
- Produces: branch publicada em `origin/chore/rails-8.1-upgrade`; logs em `$S/`; texto técnico da PR.
  A abertura da PR é feita pelo fluxo `dev-execution` (PR autorizada, corpo padrão).

- [ ] **Step 1: RSpec local espelhando os shards 1–4 do CI (em background; leva mais de uma hora)**

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
find spec -name '*_spec.rb' -not -path 'spec/system/*' -not -path 'spec/db/migrate/*' | sort > "$S/all_specs.txt"
nohup bundle exec rspec -t ~searchindex -t ~integration -t ~required_envs $(tr '\n' ' ' < "$S/all_specs.txt") \
  > "$S/rspec-full.log" 2>&1 &
echo $! > "$S/rspec-full.pid"
```

Acompanhar com `tail -3 "$S/rspec-full.log"`. Esperado no fim: `0 failures`. Os `spec/db/migrate`
(shard 5) rodam só no CI.

- [ ] **Step 2: Minitest e Rubocop completo**

```bash
bundle exec rake test:units 2>&1 | tail -15      # comando do job test-minitest de ci-test.yml
bundle exec rubocop --parallel 2>&1 | tail -5     # esperado: no offenses detected
```

- [ ] **Step 3: Corrigir falhas no commit certo (sem reescrever o que já foi publicado)**

Enquanto a branch não foi publicada, cada correção vai para o commit a que pertence:

```bash
git add <arquivos>
git commit --fixup <sha do commit 1 ou 2>
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash 43e237b860
git log --oneline 43e237b860..HEAD    # esperado: commits de planejamento + exatamente 2 de implementação
```

Depois do push, correções viram commits novos na PR.

- [ ] **Step 4: Publicar a branch**

```bash
git push -u origin chore/rails-8.1-upgrade
```

- [ ] **Step 5: Material técnico para a descrição da PR (o fluxo dev-execution abre a PR)**

Incluir na descrição:

- Motivo: check Security Scan vermelho (Brakeman 8.0.2, EOLRails, 2026-10-07) e link do run que falhou.
- Diff do lock (`$S/lock-diff.txt`) e a allowlist da spec §4.1.
- Tabela dos sete ajustes do `load_defaults 8.1` com o teste de cada um (spec §2.5).
- Saída do Brakeman 8.0.6 (`$S/brakeman-8.1.txt`: 0 warnings, exit 0) e do `zeitwerk:check`.
- Resultado do RSpec local (`$S/rspec-full.log`, contagem final) e do Minitest.
- O que o CI cobre e o que fica para o preview (spec §2.7 e §4.4).
- Link da spec e do plano no repo, e da task NDESK-45.

---

## Gates depois da PR (fases QA e Release; não são passos deste plano)

Referência: spec §4.4–§4.6. Registrar tudo em `.newbyte/qa/{N}/` na convenção do
`.newbyte/qa/README.md`.

- [ ] Os 12 jobs de `ci-test.yml` verdes na head da PR (Security Scan, Lint, Minitest, RSpec 1–5,
  Frontend 1–4); URL dos runs e SHA anotados.
- [ ] Preview `ndesk-pr-{N}.staging-preview.newbyte.net.br` no ar com o SHA da head (registrar URL, SHA,
  readiness). Preview indisponível **bloqueia** (spec D10).
- [ ] Smoke da spec §4.5 executado no preview, com resultado esperado por caso e Veredito.
- [ ] Merge sem squash na `newbyte-stable`; tag `nb.*` única no merge commit (sugestão `nb.v1.6.0`);
  registrar SHA do merge, tag e tag da imagem impressa pelo job de deploy.
- [ ] Smoke pós-deploy em produção: login, criar ticket, abrir a Aba de um ticket existente, Taskbar.
- [ ] Rollback, se preciso, sempre com tag nova: reverter o commit 2 (regressão dos defaults) ou os dois
  commits (regressão do framework), nunca mover ou reutilizar tag.
