# Plano — Atualizar Rails 8.0.4 → 8.1.3.1 (NDESK-45)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** Subir o NDesk de Rails 8.0.4 para 8.1.3.1 com `config.load_defaults 8.1` e Brakeman 8.0.6, para o
check Security Scan do CI voltar a passar sem o warning EOLRails.

**Architecture:** Uma PR sobre `newbyte-stable` com dois commits de implementação: (1) bump de gems, guard
de `lock!` e contratos de comportamento sempre-ativo; (2) `load_defaults 8.1` com um teste por ajuste.
Cada commit passa nos gates locais (boot em `test`, `zeitwerk:check`, Brakeman, `assets:precompile`,
specs afetadas); os 12 jobs de `ci-test.yml` são o gate remoto; o preview da PR é o gate de smoke.

**Tech Stack:** Ruby 3.4.8 (rbenv), Rails 8.1.3.1, Bundler 2.6.9, PostgreSQL 17 e Redis locais (Homebrew),
RSpec, Minitest, Brakeman 8.0.6, GitHub Actions.

**Spec:** `docs/plans/2026-09-08-atualizar-rails-design.md` (v2.1). O plano argumenta a partir dela; quem
executa lê os dois.

## Restrições globais

- Ruby fica em **3.4.8** (`Gemfile:6`, `.ruby-version`).
- Rails alvo **8.1.3.1** via `gem 'rails', '~> 8.1.0'`; Brakeman **8.0.6**.
- **Allowlist do lock** (spec §4.1), já resolvida em ensaio: Rails e seus 12 componentes
  `8.0.4 → 8.1.3.1`; `brakeman 8.0.2 → 8.0.6`; `action_text-trix (2.1.19)` entra (dependência nova de
  `actiontext`); `benchmark (0.5.0)` sai; `json (2.18.1)` fica, agora como dependência declarada de
  `activesupport`; `rack (2.2.22)`, `PLATFORMS`, `RUBY VERSION` e `BUNDLED WITH` inalterados. Qualquer
  outra diferença **para a execução** e reabre o escopo com o usuário.
- `config.load_defaults 8.1` sem arquivo `new_framework_defaults_8_1.rb`.
- Deprecação disparada por código do app é corrigida na origem; nunca entra em
  `spec/support/deprecation_toolkit.rb`.
- **Banco de teste por migrations:** o dump de `db/schema.rb` fica desligado em `test` e `development`; um
  `db/schema.rb` residual deve ser apagado (`rm -f db/schema.rb`, gitignored) antes de recriar o banco (R7/R8).
- **RSpec local:** todo gate de RSpec usa `--tag '~searchindex' --tag '~integration' --tag '~required_envs'`,
  como o CI (não há Elasticsearch local nem no CI; R6 do ledger de execução).
- **Shell:** a máquina usa zsh. Todo gate roda dentro de `bash -euo pipefail <<'GATE' … GATE`, define
  suas próprias variáveis, grava saída em arquivo e afirma o status numérico. Nada de `${PIPESTATUS}`
  nem de `~tag` sem aspas.
- **Git:** nunca reescrever histórico (`.claude/NEWBYTE_WORKFLOW.md`: sem `rebase`, `amend`, `reset --hard`,
  `push --force`). Correções depois do commit viram commits novos com o rótulo `(bump)` ou `(defaults)`
  no título. Mensagens no padrão do repo com os trailers `Co-Authored-By` e `Claude-Session`.
- Arquivos Ruby novos começam com
  `# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/`.
- Rubocop limpo nos arquivos tocados; `pnpm lint:md` limpo nos `.md` tocados.
- Temporários só em `$S`, onde
  `S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad`
  (redefinir em cada bloco).
- A PR só é aberta quando o usuário pedir (fluxo `dev-execution`); QA e Release seguem as skills
  `review-qa` e `release`, usando as Tasks 4 e 5 como roteiro.

## Arquivos

| Ação | Arquivo | Responsabilidade |
|---|---|---|
| Modificar | `Gemfile:7` | constraint do Rails |
| Modificar | `Gemfile.lock` | resolução (allowlist) |
| Modificar | `config/environments/test.rb`, `config/environments/development.rb` | `dump_schema_after_migration = false` (R7/R8): banco local sempre por migrations; Rails 8.1 dumpa colunas em ordem alfabética e `db:migrate` num banco vazio carrega o `schema.rb` |
| Modificar | `config/initializers/active_record_lock_issue_3664.rb` | replicar o guard de somente-leitura do 8.1 no `lock!` patchado |
| Modificar | `spec/lib/active_record/locking/pessimistic_spec.rb` | regressão do guard |
| Criar | `spec/requests/framework_query_string_spec.rb` | contrato do parser de query string do 8.1 |
| Modificar | `config/application.rb:22-23` | `load_defaults 8.1` + comentário |
| Modificar | `app/controllers/external_credentials_controller.rb:47` | passar `allow_other_host` de fato |
| Modificar | `spec/models/ticket/satisfaction_rating_spec.rb:15,59` | comentários que citam `load_defaults 8.0` |
| Criar | `spec/config/framework_defaults_spec.rb` | contrato dos sete ajustes + encoder + finders |
| Criar | `spec/controllers/framework_defaults_redirect_spec.rb` | guarda de redirect relativo ativa |
| Criar | `spec/requests/framework_defaults_json_spec.rb` | corpo JSON bruto sem escape (U+2028 e U+2029) |
| Criar | `spec/lib/sessions/store_roundtrip_spec.rb` | round-trip do store de sessão |
| Modificar | `spec/requests/external_credentials_spec.rb` | redirects de `link_account` e `callback` por backend |
| Modificar | `.claude/NEWBYTE_WORKFLOW.md` | entrada de changelog (obrigatória) |
| Criar (scratchpad) | `$S/diff_internals.sh`, `$S/lock_update.sh` | diff de corpos; resolução do lock com allowlist |

---

### Task 0: Ambiente local e baseline

**Files:**

- Nenhum arquivo **rastreado** muda (`pnpm install` e `assets:precompile` escrevem em caminhos ignorados).
  Saídas em `$S/`.

**Interfaces:**

- Produces: Ruby 3.4.8 ativo, bundle instalado, banco `zammad_test` preparado, assets compilados,
  fontes do Rails 8.1.3.1 em `$S/rails-8.1.3.1/`, hunks de diff em `$S/diffs/`, evidência do Brakeman
  falhando em `$S/baseline-brakeman.txt`.

- [ ] **Step 1: Bibliotecas nativas, Ruby 3.4.8 e Bundler do lock**

```bash
brew install imlib2 gnupg            # rszr precisa de Imlib2.h; specs de PGP chamam gpg
command -v pg_config && pg_config --version   # esperado: /opt/homebrew/opt/postgresql@17/bin/pg_config, 17.x
                                              # (não instalar libpq; o PostgreSQL 17 já fornece os headers)
rbenv install --list-all | grep -x 3.4.8      # esperado: 3.4.8
rbenv install 3.4.8                            # alguns minutos
ruby -v  # esperado: ruby 3.4.8
gem install bundler:2.6.9 && bundle -v         # esperado: Bundler version 2.6.9
node -v; pnpm -v                               # registrar: local Node 26.5.0 vs CI Node 22; pnpm 10.29.1
```

- [ ] **Step 2: Instalar as gems atuais (ainda Rails 8.0.4) e as dependências de frontend**

```bash
cd /Users/cauapuppim/newbyte/ndesk
bundle install -j "$(sysctl -n hw.ncpu)"       # esperado: Bundle complete!
pnpm install --frozen-lockfile                  # esperado: sem erro
```

- [ ] **Step 3: Apontar o banco local**

`config/database.yml` é ignorado pelo git e é cópia de `config/database/database.yml`. Confirmar que o
usuário do sistema entra no PostgreSQL 17 do Homebrew sem senha:

```bash
psql -d postgres -c 'select current_user, version();'
```

Se falhar, descomentar `username:` em `config/database.yml` com o usuário que o `psql` aceita. Não
commitar esse arquivo.

- [ ] **Step 4: Preparar banco e assets de teste (mesma sequência do cookbook e do CI)**

```bash
cd /Users/cauapuppim/newbyte/ndesk
RAILS_ENV=test bundle exec rake db:drop db:create zammad:ci:test:prepare   # = zammad:db:init + zammad:ci:settings
RAILS_ENV=test bin/rails assets:precompile                                   # roda vite build via vite_ruby
```

Esperado: os dois comandos terminam com status 0.

- [ ] **Step 5: Baseline (Rails 8.0.4): boot, Zeitwerk, Brakeman falhando, specs de referência**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
export RAILS_ENV=test
v=$(bundle exec rails runner 'print Rails.version'); [ "$v" = "8.0.4" ] || { echo "versão inesperada: $v"; exit 1; }
bundle exec rails zeitwerk:check > "$S/baseline-zeitwerk.txt"; tail -1 "$S/baseline-zeitwerk.txt"   # All is good!
set +e; bundle exec brakeman -q -o "$S/baseline-brakeman.txt" -o "$S/baseline-brakeman.html"; st=$?; set -e
grep -E "EOLRails|Support for Rails 8.0.4" "$S/baseline-brakeman.txt"
[ "$st" -eq 3 ] || { echo "brakeman baseline: esperado 3, obtido $st"; exit 1; }
bundle exec rspec spec/requests/session_spec.rb spec/requests/external_credentials_spec.rb \
  spec/lib/active_record/locking/pessimistic_spec.rb spec/lib/active_model/errors_spec.rb > "$S/baseline-rspec.txt"
tail -3 "$S/baseline-rspec.txt"          # esperado: 0 failures
echo "BASELINE OK (brakeman exit $st)"
GATE
```

- [ ] **Step 6: Baixar as fontes do Rails 8.1.3.1 para o diff dos internals**

```bash
bash -euo pipefail <<'GATE'
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
mkdir -p "$S/rails-8.1.3.1" && cd "$S/rails-8.1.3.1"
for g in actionpack activerecord activesupport activejob activemodel railties; do
  [ -d "$g-8.1.3.1" ] || { gem fetch "$g" -v 8.1.3.1 && gem unpack "$g-8.1.3.1.gem"; }
done
ls -d ./*-8.1.3.1/ | wc -l                   # esperado: 6
GATE
```

- [ ] **Step 7: Diff dos CORPOS dos arquivos reabertos (spec §2.6)**

Criar `$S/diff_internals.sh` (falha se um arquivo faltar de um lado; grava um `.diff` por arquivo e
imprime os hunks que tocam os métodos de interesse):

```bash
#!/usr/bin/env bash
# Compara arquivos upstream reabertos pelo NDesk: Rails instalado (bundle show) × 8.1.3.1 descompactado.
set -euo pipefail
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
NEW="$S/rails-8.1.3.1"; OUT="$S/diffs"; mkdir -p "$OUT"
cmp_file() { # gem, caminho relativo, regex ERE dos métodos que o NDesk reabre/chama
  local gem=$1 rel=$2 methods=$3
  local old new; old="$(bundle show "$gem")/$rel"; new="$NEW/$gem-8.1.3.1/$rel"
  [ -f "$old" ] || { echo "FALTA (instalado): $old"; exit 1; }
  [ -f "$new" ] || { echo "FALTA (8.1.3.1): $new"; exit 1; }
  local d="$OUT/$gem-$(echo "$rel" | tr '/' '_').diff"
  set +e; diff -u "$old" "$new" > "$d"; local st=$?; set -e
  [ "$st" -le 1 ] || { echo "diff falhou em $rel"; exit 1; }
  echo "### $gem/$rel — hunks: $(grep -c '^@@' "$d" || true)"
  # imprime cada hunk cujo cabeçalho de contexto ou conteúdo cite um dos métodos
  awk -v re="def ($methods)([[:space:](]|$)" '
    /^@@/ { if (buf != "" && hit) print buf; buf=$0 "\n"; hit=0; next }
    { buf = buf $0 "\n"; if ($0 ~ re) hit=1 }
    END { if (buf != "" && hit) print buf }' "$d"
}
cmp_file actionpack    lib/action_dispatch/middleware/cookies.rb                              'write_cookie[?]'
cmp_file activerecord  lib/active_record/connection_adapters/abstract/schema_statements.rb   'quoted_columns_for_index|add_index_options'
cmp_file activerecord  lib/active_record/connection_adapters/postgresql/schema_statements.rb 'quoted_columns_for_index'
cmp_file activerecord  lib/active_record/store.rb                                            'as_indifferent_hash|load|dump'
cmp_file activerecord  lib/active_record/locking/pessimistic.rb                              'lock!|with_lock'
cmp_file activerecord  lib/active_record/relation/calculations.rb                            'pluck|arel_columns'
cmp_file activerecord  lib/active_record/relation/batches.rb                                 'find_each|find_in_batches|in_batches'
cmp_file activesupport lib/active_support/callbacks.rb                                       'set_callback|skip_callback|define_callbacks'
cmp_file activesupport lib/active_support/tagged_logging.rb                                  'call|tagged|push_tags'
cmp_file activesupport lib/active_support/cache/file_store.rb                                '[a-z_]+'
cmp_file activejob     lib/active_job/queue_adapters/delayed_job_adapter.rb                  'max_attempts|max_run_time|perform|enqueue'
cmp_file activemodel   lib/active_model/errors.rb                                            'add|full_message|generate_message'
cmp_file activemodel   lib/active_model/error.rb                                             'full_message|message|details'
echo "diffs em $OUT"
```

Rodar com o Rails 8.0.4 ainda instalado (é o "old"):

```bash
chmod +x /private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad/diff_internals.sh
bash /private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad/diff_internals.sh \
  | tee /private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad/diff-internals.txt
```

Esperado (conforme os grills): hunks em `pessimistic.rb` (`lock!` ganha guard `current_preventing_writes`
no topo), `calculations.rb` (`pluck`), `batches.rb` e `callbacks.rb`; assinaturas iguais em todos. Para
cada arquivo, registrar em `$S/internals-review.md` uma linha `arquivo → método → decisão` com uma de:
"sem impacto no patch local", "ajuste no commit 1 (qual)". O caso já decidido é `lock!` (Task 1, Step 4).

---

### Task 1: Commit 1 — bump Rails 8.1.3.1 + Brakeman 8.0.6 + guard de `lock!` + contratos sempre-ativos

**Files:**

- Modify: `Gemfile:7`, `Gemfile.lock`
- Modify: `config/initializers/active_record_lock_issue_3664.rb:16-31`
- Test: `spec/lib/active_record/locking/pessimistic_spec.rb` (novo exemplo)
- Create: `spec/requests/framework_query_string_spec.rb`

**Interfaces:**

- Consumes: ambiente da Task 0.
- Produces: commit `chore(deps): Rails 8.0.4 → 8.1.3.1, Brakeman 8.0.6 e guard de lock! (NDESK-45)`;
  `Rails.version == "8.1.3.1"`; `loaded_config_version` ainda `8.0`; Brakeman exit 0.

- [ ] **Step 1: Mudar a constraint do Rails**

```bash
cd /Users/cauapuppim/newbyte/ndesk
sed -i '' "s/^gem 'rails', '~> 8.0.0'$/gem 'rails', '~> 8.1.0'/" Gemfile
git diff --stat Gemfile     # esperado: 1 file changed, 1 insertion(+), 1 deletion(-)
```

- [ ] **Step 2: Resolver o lock sem gravar e validar contra a allowlist (script autocontido)**

Criar `$S/lock_update.sh`:

```bash
#!/usr/bin/env bash
# Uso: lock_update.sh print   → resolve para $S/Gemfile.lock.new e valida a allowlist (não grava)
#      lock_update.sh write   → grava o lock com os MESMOS argumentos e confere byte a byte
set -euo pipefail
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
GEMS="rails actioncable actionmailbox actionmailer actionpack actiontext actionview activejob activemodel activerecord activestorage activesupport railties brakeman"
MODE=${1:?print|write}
if [ "$MODE" = print ]; then
  bundle lock --update $GEMS --conservative --print > "$S/Gemfile.lock.new"
  set +e; diff -u Gemfile.lock "$S/Gemfile.lock.new" > "$S/lock.diff"; set -e
  versions() { grep -E '^    [A-Za-z0-9_.-]+ \([0-9]' "$1" | sed -E 's/^ +//' | sort; }
  set +e; diff <(versions Gemfile.lock) <(versions "$S/Gemfile.lock.new") | grep -E '^[<>]' | sort > "$S/lock-versions.diff"; set -e
  cat > "$S/lock-expected.diff" <<'EXP'
< actioncable (8.0.4)
< actionmailbox (8.0.4)
< actionmailer (8.0.4)
< actionpack (8.0.4)
< actiontext (8.0.4)
< actionview (8.0.4)
< activejob (8.0.4)
< activemodel (8.0.4)
< activerecord (8.0.4)
< activestorage (8.0.4)
< activesupport (8.0.4)
< benchmark (0.5.0)
< brakeman (8.0.2)
< rails (8.0.4)
< railties (8.0.4)
> actioncable (8.1.3.1)
> actionmailbox (8.1.3.1)
> actionmailer (8.1.3.1)
> actionpack (8.1.3.1)
> action_text-trix (2.1.19)
> actiontext (8.1.3.1)
> actionview (8.1.3.1)
> activejob (8.1.3.1)
> activemodel (8.1.3.1)
> activerecord (8.1.3.1)
> activestorage (8.1.3.1)
> activesupport (8.1.3.1)
> brakeman (8.0.6)
> rails (8.1.3.1)
> railties (8.1.3.1)
EXP
  sort "$S/lock-expected.diff" > "$S/lock-expected.sorted"
  cmp -s "$S/lock-versions.diff" "$S/lock-expected.sorted" || { echo "VERSÕES FORA DA ALLOWLIST:"; diff "$S/lock-expected.sorted" "$S/lock-versions.diff" || true; exit 1; }
  grep -qE '^    rack \(2\.2\.22\)$' "$S/Gemfile.lock.new" || { echo "rack mudou"; exit 1; }
  grep -A3 '^    actiontext (8.1.3.1)' "$S/Gemfile.lock.new" | grep -q 'action_text-trix' || { echo "aresta actiontext→action_text-trix ausente"; exit 1; }
  grep -A12 '^    activesupport (8.1.3.1)' "$S/Gemfile.lock.new" | grep -q '      json' || { echo "aresta activesupport→json ausente"; exit 1; }
  for sec in PLATFORMS "RUBY VERSION" "BUNDLED WITH"; do
    diff <(awk -v s="$sec" '$0==s{f=1;next} /^[A-Z]/{f=0} f' Gemfile.lock) <(awk -v s="$sec" '$0==s{f=1;next} /^[A-Z]/{f=0} f' "$S/Gemfile.lock.new") >/dev/null || { echo "seção $sec mudou"; exit 1; }
  done
  grep -qE "^  rails \(~> 8\.1\.0\)$" "$S/Gemfile.lock.new" || { echo "DEPENDENCIES: constraint do rails inesperada"; exit 1; }
  echo "ALLOWLIST OK · diff integral em $S/lock.diff ($(grep -c '^[-+]' "$S/lock.diff") linhas +/-)"
else
  bundle lock --update $GEMS --conservative
  cmp -s Gemfile.lock "$S/Gemfile.lock.new" || { echo "lock gravado difere do ensaio"; exit 1; }
  echo "LOCK GRAVADO = ENSAIO"
fi
```

Rodar o ensaio e **ler o diff integral** antes de gravar:

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
chmod +x "$S/lock_update.sh" && bash "$S/lock_update.sh" print && sed -n '1,200p' "$S/lock.diff"
```

Esperado: `ALLOWLIST OK`. Se o script sair com 1, **parar** e levar `$S/lock-versions.diff` ao usuário
(spec D5).

- [ ] **Step 3: Gravar o lock com os mesmos argumentos e instalar**

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
bash "$S/lock_update.sh" write          # esperado: LOCK GRAVADO = ENSAIO
cd /Users/cauapuppim/newbyte/ndesk && bundle install -j "$(sysctl -n hw.ncpu)"
```

- [ ] **Step 4: TDD do guard de somente-leitura em `lock!`**

Adicionar ao final do bloco `RSpec.describe ActiveRecord::Locking::Pessimistic do` em
`spec/lib/active_record/locking/pessimistic_spec.rb`:

```ruby
  # Rails 8.1: lock! levanta ReadOnlyError em while_preventing_writes. O patch de
  # config/initializers/active_record_lock_issue_3664.rb tem um ramo que retorna
  # antes de chamar o lock! original; o guard precisa valer também nesse ramo.
  it 'raises ReadOnlyError while preventing writes even when only the store structure changed' do
    set_old_ticket_store

    ActiveRecord::Base.while_preventing_writes do
      expect { ticket.lock! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end
```

Rodar e confirmar o vermelho:

```bash
cd /Users/cauapuppim/newbyte/ndesk && RAILS_ENV=test bundle exec rspec spec/lib/active_record/locking/pessimistic_spec.rb
# esperado: 1 failure — "expected ActiveRecord::ReadOnlyError but nothing was raised"
```

Editar `config/initializers/active_record_lock_issue_3664.rb`, método `lock!`, inserindo o guard como
primeiras linhas do corpo (antes de `if persisted? && has_changes_to_save?`):

```ruby
    def lock!(lock = true) # rubocop:disable Style/OptionalBooleanParameter
      # Rails 8.1 guard (activerecord/lib/active_record/locking/pessimistic.rb):
      # precisa valer também no ramo abaixo, que retorna sem chamar orig_lock!.
      if self.class.current_preventing_writes
        raise ActiveRecord::ReadOnlyError, 'Lock query attempted while in readonly mode'
      end

      if persisted? && has_changes_to_save?
```

Rodar de novo:

```bash
cd /Users/cauapuppim/newbyte/ndesk && RAILS_ENV=test bundle exec rspec spec/lib/active_record/locking/pessimistic_spec.rb
# esperado: 0 failures
```

- [ ] **Step 5: Contrato do parser de query string (sempre-ativo no 8.1)**

Criar `spec/requests/framework_query_string_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1 (independente de load_defaults): ';' deixa de separar parâmetros e
# colchetes iniciais deixam de ser descartados (spec NDESK-45, §2.5).
RSpec.describe 'Query string parsing on Rails 8.1', type: :request do
  it 'keeps ";" inside a value and "[foo]" as a literal key' do
    get '/api/v1/getting_started?a=1;b=2&[foo]=bar'

    expect(response).to have_http_status(:ok)
    expect(request.query_parameters).to include('a' => '1;b=2', '[foo]' => 'bar')
    expect(request.query_parameters).not_to include('b', 'foo')
  end
end
```

```bash
cd /Users/cauapuppim/newbyte/ndesk && RAILS_ENV=test bundle exec rspec spec/requests/framework_query_string_spec.rb
# esperado: 0 failures (já vale após o bump; é guarda de regressão)
```

- [ ] **Step 6: Gates do commit 1**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
export RAILS_ENV=test
out=$(bundle exec rails runner 'print [Rails.version, Rails.application.config.loaded_config_version.to_s].join(" ")')
[ "$out" = "8.1.3.1 8.0" ] || { echo "boot inesperado: $out"; exit 1; }
bundle exec rails zeitwerk:check > "$S/c1-zeitwerk.txt"; tail -1 "$S/c1-zeitwerk.txt"
set +e; bundle exec brakeman -q -o "$S/c1-brakeman.txt" -o "$S/c1-brakeman.html"; st=$?; set -e
grep -E "Security Warnings|EOLRails" "$S/c1-brakeman.txt" || true
[ "$st" -eq 0 ] || { echo "brakeman: esperado 0, obtido $st (ver $S/c1-brakeman.txt)"; exit 1; }
bin/rails assets:precompile > "$S/c1-assets.txt" 2>&1; tail -2 "$S/c1-assets.txt"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/session_spec.rb spec/requests/external_credentials_spec.rb spec/requests/ticket_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb spec/requests/framework_query_string_spec.rb \
  spec/lib/core_ext spec/lib/sessions spec/lib/active_record spec/lib/active_model spec/jobs \
  spec/models/ticket_spec.rb spec/models/user_group_spec.rb spec/models/role_group_spec.rb \
  > "$S/c1-rspec.txt"
tail -3 "$S/c1-rspec.txt"
echo "GATES COMMIT 1 OK (brakeman exit $st)"
GATE
```

Se o Brakeman 8.0.6 trouxer warning novo: achado real → corrigir o código neste commit; falso positivo
→ `bundle exec brakeman -I` gera a entrada em `config/brakeman.ignore`, e a justificativa vai na mensagem
do commit (spec §4.3.6). Falha de spec por deprecação (`DEPRECATION WARNING` com stack em `app/` ou
`lib/`) é corrigida na origem e entra neste commit.

- [ ] **Step 7: Revisar os hunks dos internals com as gems instaladas**

```bash
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
bash "$S/diff_internals.sh" > "$S/diff-internals-after.txt"; grep -c "hunks: 0" "$S/diff-internals-after.txt"
```

Esperado: todos os arquivos com `hunks: 0` (agora old == new). A decisão por método fica registrada
em `$S/internals-review.md` (Task 0, Step 7); qualquer "ajuste no commit 1" pendente entra agora.

- [ ] **Step 8: Rubocop e commit 1**

```bash
cd /Users/cauapuppim/newbyte/ndesk
bundle exec rubocop Gemfile config/initializers/active_record_lock_issue_3664.rb \
  spec/lib/active_record/locking/pessimistic_spec.rb spec/requests/framework_query_string_spec.rb
git add Gemfile Gemfile.lock config/initializers/active_record_lock_issue_3664.rb \
  spec/lib/active_record/locking/pessimistic_spec.rb spec/requests/framework_query_string_spec.rb
git commit -F - <<'MSG'
chore(deps): Rails 8.0.4 → 8.1.3.1, Brakeman 8.0.6 e guard de lock! (NDESK-45)

Corrige o check Security Scan do CI: o Brakeman 8.0.2 marcava a série
Rails 8.0 como EOL em 2026-10-07 (exit 3). Lock: Rails e 12 componentes
8.0.4 → 8.1.3.1, brakeman 8.0.2 → 8.0.6, action_text-trix 2.1.19 entra,
benchmark 0.5.0 sai, rack mantido em 2.2.22. O patch de lock! replica o
guard de somente-leitura do 8.1 (o ramo de reload retornava antes do
original). Contrato do parser de query string do 8.1. load_defaults segue
em 8.0; o commit seguinte adota 8.1.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DrHNpApXBaQQAeEhi6QVmr
MSG
git log --oneline -1
```

Se o Step 6 exigiu outras mudanças, incluir os arquivos no `git add` e citar na mensagem.

---

### Task 2: Commit 2 — `config.load_defaults 8.1` (TDD, um oráculo por ajuste)

**Files:**

- Create: `spec/config/framework_defaults_spec.rb`, `spec/controllers/framework_defaults_redirect_spec.rb`,
  `spec/requests/framework_defaults_json_spec.rb`, `spec/lib/sessions/store_roundtrip_spec.rb`
- Modify: `spec/requests/external_credentials_spec.rb` (dentro de `context 'authenticated as admin'`)
- Modify: `config/application.rb:22-23`, `app/controllers/external_credentials_controller.rb:47`,
  `spec/models/ticket/satisfaction_rating_spec.rb:15,59`

**Interfaces:**

- Consumes: commit 1.
- Produces: commit `chore(config): adota config.load_defaults 8.1 (NDESK-45)`;
  `loaded_config_version.to_s == "8.1"` em `test` e `production`.

- [ ] **Step 1: Contrato dos sete ajustes, encoder e finders**

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
    # Relações vazias por coluna NOT NULL: o finder roda sem depender de seeds.
    it 'allows order-dependent finders on UserGroup and RoleGroup' do
      expect { UserGroup.where(user_id: nil).first }.not_to raise_error
      expect { RoleGroup.where(role_id: nil).last }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Prova de que a guarda de redirect relativo está ativa**

`spec/controllers/framework_defaults_redirect_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `action_on_path_relative_redirect = :raise` (spec NDESK-45, §2.5).
# Controller anônimo derivado de ActionController::Base: não passa pelo
# ApplicationController::HandlesErrors, então a exceção chega ao exemplo.
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

- [ ] **Step 3: Oráculo do corpo JSON bruto (U+2028 e U+2029)**

`spec/requests/framework_defaults_json_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `escape_json_responses = false` e `escape_js_separators_in_json = false`
# (spec NDESK-45, §2.5). O cliente faz JSON.parse; o que muda são os bytes no fio.
# Ticket#check_title só normaliza \s|\t|\r, que não casam U+2028/U+2029.
RSpec.describe 'JSON responses with Rails 8.1 defaults', type: :request do
  let(:title)   { "Tag <b>&amp;</b> \u2028line\u2029para" }
  let!(:ticket) { create(:ticket, title: title) }
  let(:agent)   { create(:agent, groups: Group.all) }

  before { authenticated_as(agent) }

  it 'sends HTML characters, U+2028 and U+2029 unescaped in the raw body' do
    get "/api/v1/tickets/#{ticket.id}", as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['title']).to eq(title)
    expect(response.body).to include('<b>&amp;</b>').and include("\u2028").and include("\u2029")
    expect(response.body).not_to include('\u003c')
    expect(response.body).not_to include('\u2028')
    expect(response.body).not_to include('\u2029')
  end
end
```

(`'\u003c'`, `'\u2028'` e `'\u2029'` entre aspas simples são as sequências escapadas, com barra literal,
que o Rails 8.0 emitia; entre aspas duplas são os caracteres em si.)

- [ ] **Step 4: Round-trip do store de sessão**

`spec/lib/sessions/store_roundtrip_spec.rb`:

```ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# O store de sessão serializa com to_json (encoder global do Active Support) e lê
# com JSON.parse. Com `escape_js_separators_in_json = false` os bytes gravados
# mudam; o valor lido não pode mudar (spec NDESK-45, §2.5).
RSpec.describe Sessions, 'store round-trip with Rails 8.1 JSON defaults' do
  let(:client_id) { "framework-defaults-#{SecureRandom.hex(4)}" }
  let(:note)      { "a\u2028b\u2029c <>&" }

  after { described_class.destroy(client_id) }

  it 'preserves U+2028, U+2029 and HTML characters through create/get' do
    described_class.create(client_id, { 'id' => 1, 'note' => note }, { type: 'websocket' })

    expect(described_class.get(client_id)[:user]['note']).to eq(note)
  end
end
```

- [ ] **Step 5: Redirects de `link_account` e `callback` por backend**

Em `spec/requests/external_credentials_spec.rb`, dentro de `context 'authenticated as admin' do`
(depois do `describe '#index'`), adicionar:

```ruby
    describe 'redirect targets (Rails 8.1: path-relative guard + allow_other_host)' do
      before { Setting.set('http_type', 'https') }

      let(:fqdn) { Setting.get('fqdn') }

      describe '#link_account' do
        %w[google microsoft365 microsoft_graph exchange].each do |provider|
          it "redirects #{provider} to the absolute authorize_url of the provider" do
            allow(ExternalCredential).to receive(:request_account_to_link)
              .and_return({ request_token: 'token', authorize_url: "https://login.#{provider}.example/authorize?state=1" })

            get "/api/v1/external_credentials/#{provider}/link_account"

            expect(response).to have_http_status(:found)
            expect(response.headers['Location']).to eq("https://login.#{provider}.example/authorize?state=1")
          end
        end
      end

      describe '#callback' do
        %w[microsoft365 microsoft_graph exchange].each do |provider|
          it "redirects #{provider} to an absolute error URL on another host (String from the backend)" do
            allow(ExternalCredential).to receive(:link_account)
              .and_return("https://error.#{provider}.example/#channels/#{provider}/error/AADSTS")

            get "/api/v1/external_credentials/#{provider}/callback"

            expect(response).to have_http_status(:found)
            expect(response.headers['Location']).to eq("https://error.#{provider}.example/#channels/#{provider}/error/AADSTS")
          end
        end

        it 'redirects google to the absolute app URL of the created channel' do
          channel = create(:google_channel)
          allow(ExternalCredential).to receive(:link_account).and_return(channel)

          get '/api/v1/external_credentials/google/callback'

          expect(response).to have_http_status(:found)
          expect(response.headers['Location']).to eq("https://#{fqdn}/#channels/google/#{channel.id}")
        end
      end
    end
```

Os backends first-party geram `authorize_url` absoluta (contrato já coberto em
`spec/lib/external_credential/{google,microsoft365,microsoft_graph,exchange}_spec.rb`); Microsoft 365,
Microsoft Graph e Exchange devolvem String absoluta em caminhos de erro; Google e Facebook devolvem
`Channel`. O host externo no caso String é o que torna a correção da linha 47 vermelha antes e verde
depois (`raise_on_open_redirects` vale desde os defaults 7.0).

- [ ] **Step 6: Rodar os cinco specs e confirmar o vermelho esperado**

```bash
cd /Users/cauapuppim/newbyte/ndesk && RAILS_ENV=test bundle exec rspec spec/config/framework_defaults_spec.rb \
  spec/controllers/framework_defaults_redirect_spec.rb spec/requests/framework_defaults_json_spec.rb \
  spec/lib/sessions/store_roundtrip_spec.rb spec/requests/external_credentials_spec.rb
```

Esperado com `load_defaults 8.0` e a linha 47 ainda errada:

- `framework_defaults_spec.rb`: falham os 8 exemplos de config; os valores lidos em 8.0 são
  `8.0`, `true`, `nil`, `:log`, `nil`, `nil`, `nil`, `nil` (configs não definidas ficam `nil` até o
  `load_defaults 8.1` atribuí-las); falha o encoder (`"a\\u2028b\\u2029c"`); passam os finders.
- `framework_defaults_redirect_spec.rb`: falha (`:log` não levanta erro).
- `framework_defaults_json_spec.rb`: falha (corpo contém `\u003c` e `\u2028`).
- `store_roundtrip_spec.rb`: **passa** (JSON.parse aceita as duas formas; é guarda de regressão).
- `external_credentials_spec.rb`: falham os 3 exemplos de String em host externo (o controller levanta
  `OpenRedirectError`, convertido em 500 por `HandlesErrors`); passam os de `link_account` e do canal.

Vermelho diferente do descrito: parar e entender antes de seguir; registrar em `$S/red-notes.md`.

- [ ] **Step 7: Adotar os defaults 8.1, corrigir a linha 47 e os comentários**

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

`app/controllers/external_credentials_controller.rb:47`, de:

```ruby
    return redirect_to(channel), allow_other_host: true if channel.instance_of?(String)
```

para:

```ruby
    return redirect_to(channel, allow_other_host: true) if channel.instance_of?(String)
```

`spec/models/ticket/satisfaction_rating_spec.rb`: nas linhas 15 e 59, trocar
`Under Rails' load_defaults 8.0` e `Under load_defaults 8.0` por `Since Rails' load_defaults 8.0 (kept
in 8.1)` e `Since load_defaults 8.0 (kept in 8.1)`. Só comentários.

- [ ] **Step 8: Rodar os cinco specs e confirmar o verde; valores efetivos em test e production**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
RAILS_ENV=test bundle exec rspec spec/config/framework_defaults_spec.rb \
  spec/controllers/framework_defaults_redirect_spec.rb spec/requests/framework_defaults_json_spec.rb \
  spec/lib/sessions/store_roundtrip_spec.rb spec/requests/external_credentials_spec.rb > "$S/c2-rspec-new.txt"
tail -3 "$S/c2-rspec-new.txt"                         # esperado: 0 failures
DUMP='c = Rails.application.config; print [c.loaded_config_version.to_s, c.yjit, c.action_controller.escape_json_responses, c.action_controller.action_on_path_relative_redirect, c.active_record.raise_on_missing_required_finder_order_columns, c.active_support.escape_js_separators_in_json, c.action_view.render_tracker, c.action_view.remove_hidden_field_autocomplete].inspect'
t=$(RAILS_ENV=test ZAMMAD_DISABLE_YJIT= bundle exec rails runner "$DUMP")
echo "test:       $t"
[ "$t" = '["8.1", false, false, :raise, true, false, :ruby, true]' ] || { echo "valores em test inesperados"; exit 1; }
set +e
p=$(RAILS_ENV=production ZAMMAD_DISABLE_YJIT= DATABASE_URL=postgresql://localhost/zammad_test SECRET_KEY_BASE=local-check bundle exec rails runner "$DUMP" 2>"$S/c2-prod-boot.err"); st=$?
set -e
if [ "$st" -eq 0 ]; then
  echo "production: $p"
  [ "$p" = '["8.1", true, false, :raise, true, false, :ruby, true]' ] || { echo "valores em production inesperados"; exit 1; }
else
  echo "production: boot local falhou (ver $S/c2-prod-boot.err); registrar e verificar no container do preview/produção com: rails runner 'puts RubyVM::YJIT.enabled?'"
fi
GATE
```

- [ ] **Step 9: Gates do commit 2 (mesmos do commit 1, mais as vizinhas dos sete ajustes)**

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
export RAILS_ENV=test
bundle exec rails zeitwerk:check > "$S/c2-zeitwerk.txt"; tail -1 "$S/c2-zeitwerk.txt"
set +e; bundle exec brakeman -q -o "$S/c2-brakeman.txt" -o "$S/c2-brakeman.html"; st=$?; set -e
[ "$st" -eq 0 ] || { echo "brakeman: esperado 0, obtido $st"; exit 1; }
bin/rails assets:precompile > "$S/c2-assets.txt" 2>&1; tail -2 "$S/c2-assets.txt"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  spec/requests/session_spec.rb spec/requests/ticket_spec.rb \
  spec/requests/ticket/article_attachments_spec.rb spec/requests/knowledge_base_public \
  spec/controllers spec/views spec/lib/sessions spec/lib/core_ext spec/lib/active_record \
  spec/lib/active_model spec/lib/external_credential spec/models > "$S/c2-rspec.txt"
tail -3 "$S/c2-rspec.txt"
echo "GATES COMMIT 2 OK"
GATE
```

`MissingRequiredOrderError` em algum call site: decidir por caso entre coluna real e determinística
(`order(:created_at, :id)` só se as colunas existirem), chave composta, `implicit_order_column` no
model, ou `take` quando a escolha arbitrária for intencional. Nunca `order(:id)` em tabela sem `id`;
nunca desligar o default.

- [ ] **Step 10: Rubocop e commit 2**

```bash
cd /Users/cauapuppim/newbyte/ndesk
bundle exec rubocop config/application.rb app/controllers/external_credentials_controller.rb \
  spec/config/framework_defaults_spec.rb spec/controllers/framework_defaults_redirect_spec.rb \
  spec/requests/framework_defaults_json_spec.rb spec/lib/sessions/store_roundtrip_spec.rb \
  spec/requests/external_credentials_spec.rb spec/models/ticket/satisfaction_rating_spec.rb
git add config/application.rb app/controllers/external_credentials_controller.rb spec/config \
  spec/controllers/framework_defaults_redirect_spec.rb spec/requests/framework_defaults_json_spec.rb \
  spec/lib/sessions/store_roundtrip_spec.rb spec/requests/external_credentials_spec.rb \
  spec/models/ticket/satisfaction_rating_spec.rb
git commit -F - <<'MSG'
chore(config): adota config.load_defaults 8.1 (NDESK-45)

Sete ajustes do 8.1 com um teste cada (spec/config/framework_defaults_spec.rb):
yjit só em produção, JSON sem escape de HTML e de U+2028/2029, redirect relativo
levanta erro, finders sem ordem em model sem chave levantam erro, render_tracker
:ruby, hidden fields sem autocomplete. Round-trip do store de sessão e redirects
de credenciais externas por backend; corrige a passagem de allow_other_host no
callback (era segundo valor do return).

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DrHNpApXBaQQAeEhi6QVmr
MSG
git log --oneline -3
```

---

### Task 3: Pré-check backend completo, changelog e push

**Files:**

- Modify: `.claude/NEWBYTE_WORKFLOW.md` (seção Changelog)
- Correções encontradas aqui: commits novos rotulados `(bump)` ou `(defaults)`.

**Interfaces:**

- Consumes: commits 1 e 2.
- Produces: branch publicada em `origin/chore/rails-8.1-upgrade`; logs em `$S/`; material técnico da PR.

- [ ] **Step 1: RSpec (união dos shards 1–4 do CI e o shard 5), reset do banco, Minitest, Rubocop, lint de md**

Sequência de `.github/workflows/ci/test.sh` e variáveis do job de RSpec do CI. Foreground; leva mais de
uma hora.

```bash
bash -euo pipefail <<'GATE'
cd /Users/cauapuppim/newbyte/ndesk
S=/private/tmp/claude-501/-Users-cauapuppim-newbyte-ndesk/28023456-199a-445e-94b0-522f9664502e/scratchpad
export RAILS_ENV=test TZ=Europe/London Z_LOCALES="en-us:de-de" REDIS_URL=redis://127.0.0.1:6379
find spec -name '*_spec.rb' -not -path 'spec/system/*' -not -path 'spec/db/migrate/*' | sort > "$S/shards-1-4.txt"
find spec/db/migrate -name '*_spec.rb' | sort > "$S/shard-5.txt"
echo "shards 1-4: $(wc -l < "$S/shards-1-4.txt") arquivos · shard 5: $(wc -l < "$S/shard-5.txt")"
bundle exec rspec --tag '~searchindex' --tag '~integration' --tag '~required_envs' \
  $(tr '\n' ' ' < "$S/shards-1-4.txt") > "$S/rspec-1-4.log" 2>&1
tail -3 "$S/rspec-1-4.log"
bundle exec rspec $(tr '\n' ' ' < "$S/shard-5.txt") > "$S/rspec-5.log" 2>&1
tail -3 "$S/rspec-5.log"
bundle exec rake zammad:db:reset > "$S/db-reset.log" 2>&1
bundle exec rake test:units > "$S/minitest.log" 2>&1; tail -3 "$S/minitest.log"
bundle exec rubocop --parallel > "$S/rubocop.log" 2>&1; tail -1 "$S/rubocop.log"
pnpm lint:md > "$S/lint-md.log" 2>&1; tail -1 "$S/lint-md.log"
echo "PRE-CHECK BACKEND OK"
GATE
```

Esperado: `PRE-CHECK BACKEND OK` (com `set -e`, qualquer status diferente de 0 interrompe antes). Os
jobs Lint e Frontend (Vitest) do CI não dependem desta mudança e ficam só remotos.

- [ ] **Step 2: Corrigir falhas como commits novos e repetir os gates**

```bash
cd /Users/cauapuppim/newbyte/ndesk
git add <arquivos da correção>
git commit -m "fix(bump): <o que corrigiu> (NDESK-45)"        # ou fix(defaults): …, conforme o commit de origem
```

Depois de cada correção, repetir Task 1 Step 6 (se `(bump)`), Task 2 Steps 8–9 (se `(defaults)`) e o
Step 1 desta task. Sem `rebase`, `amend` ou `fixup`.

- [ ] **Step 3: Entrada de changelog (obrigatória pelo workflow)**

Acrescentar ao final de `.claude/NEWBYTE_WORKFLOW.md`, na seção Changelog:

```markdown
### 2026-09-08 - branch chore/rails-8.1-upgrade (NDESK-45)

**Branch**: `chore/rails-8.1-upgrade`

Alteracoes:
- **Rails 8.0.4 → 8.1.3.1 e Brakeman 8.0.6**: o check Security Scan falhava por EOLRails
  (Brakeman 8.0.2 marcava a serie 8.0 como EOL em 2026-10-07). Lock: Rails e 12 componentes,
  `action_text-trix` entra, `benchmark` sai, rack fica em 2.2.22.
- **`config.load_defaults 8.1`**: sete ajustes com um teste cada (`spec/config/framework_defaults_spec.rb`):
  yjit so em producao, JSON sem escape de HTML/U+2028/U+2029, redirect relativo levanta erro, finders
  sem ordem em model sem chave levantam erro, render_tracker `:ruby`, hidden fields sem autocomplete.
- **Guard de somente-leitura em `lock!`** replicado no patch `active_record_lock_issue_3664.rb`.
- **`allow_other_host`** passado de fato no callback de credenciais externas.
- Spec e plano: `docs/plans/2026-09-08-atualizar-rails-design.md`, `docs/plans/2026-09-08-atualizar-rails.md`.

Arquivos modificados:
- `Gemfile`, `Gemfile.lock`, `config/application.rb`
- `config/initializers/active_record_lock_issue_3664.rb`
- `app/controllers/external_credentials_controller.rb`
- specs novos em `spec/config`, `spec/controllers`, `spec/requests`, `spec/lib/sessions`
```

```bash
cd /Users/cauapuppim/newbyte/ndesk && pnpm lint:md
git add .claude/NEWBYTE_WORKFLOW.md
git commit -m "docs(workflow): changelog — Rails 8.1 (NDESK-45)" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01DrHNpApXBaQQAeEhi6QVmr"
```

- [ ] **Step 4: Base ainda é a mesma? Publicar a branch**

```bash
cd /Users/cauapuppim/newbyte/ndesk
git fetch origin
git log --oneline HEAD..origin/newbyte-stable      # esperado: vazio
# se não estiver vazio: git merge origin/newbyte-stable (sem rebase) e repetir Task 1 Step 6, Task 2 Step 9 e Task 3 Step 1
git push -u origin chore/rails-8.1-upgrade
```

- [ ] **Step 5: Material técnico para a descrição da PR (a PR é aberta quando o usuário pedir)**

Incluir na descrição:

- Motivo: check Security Scan vermelho (Brakeman 8.0.2, EOLRails, 2026-10-07) e link do run que falhou.
- `$S/lock.diff` resumido e a allowlist da spec §4.1.
- Tabela dos sete ajustes do `load_defaults 8.1` com o teste de cada um (spec §2.5).
- Guard de `lock!` e correção do `allow_other_host`, com os testes.
- Saídas: `$S/c2-brakeman.txt` (0 warnings, exit 0), `$S/c2-zeitwerk.txt`, `$S/rspec-1-4.log` e
  `$S/rspec-5.log` (contagens finais), `$S/minitest.log`, valores efetivos dos defaults em test e
  production (Task 2, Step 8).
- O que o CI cobre e o que fica para o preview (spec §2.7 e §4.4).
- Links da spec, do plano e da task NDESK-45.

---

### Task 4: PR, CI, preview e QA (fase QA, skill `review-qa`; PR só com pedido explícito do usuário)

**Files:**

- Registro de trabalho em `.newbyte/qa/{N}/` (pasta local, não rastreada). Registro compartilhado: comentário de
  Veredito na PR e descrição do sub-item QA no Plane.

- [ ] **Step 1: Abrir a PR (quando autorizado) contra `newbyte-stable`**

```bash
cd /Users/cauapuppim/newbyte/ndesk
gh pr create -R newbytesolucoesdigitais/ndesk --base newbyte-stable --head chore/rails-8.1-upgrade \
  --title "chore: Rails 8.1.3.1, load_defaults 8.1 e Brakeman 8.0.6 (NDESK-45)" --body-file "$S/pr-body.md"
# fallback REST se o GraphQL falhar: gh api repos/newbytesolucoesdigitais/ndesk/pulls -f title=... -f head=newbytesolucoesdigitais:chore/rails-8.1-upgrade -f base=newbyte-stable -f body=...
```

- [ ] **Step 2: Os 12 checks verdes na head**

```bash
gh pr checks <N> -R newbytesolucoesdigitais/ndesk --watch      # esperado: 12 linhas "pass" (Security Scan, Lint, Minitest, RSpec 1–5, Frontend 1–4)
gh pr view <N> -R newbytesolucoesdigitais/ndesk --json headRefOid --jq .headRefOid   # anotar o SHA
```

- [ ] **Step 3: Preview no ar com o SHA da head**

```bash
curl -s "https://ndesk-pr-<N>.staging-preview.newbyte.net.br/api/v1/getting_started"   # esperado: "setup_done":true
curl -s -u '<usuário de QA>:<senha>' "https://ndesk-pr-<N>.staging-preview.newbyte.net.br/api/v1/version"
# esperado: "7.0.0-sha-<7 primeiros do SHA da head>" (o build carimba VERSION com sha-<short> fora de tag)
```

Preview ausente ou com SHA diferente **bloqueia** (spec D10); quem provisiona o preview é pergunta
aberta ao usuário (spec §8).

- [ ] **Step 4: Smoke da spec §4.5 e Veredito**

Casos e resultados esperados: tabela da spec §4.5 (UI clássica, pt-BR; desktop-view/mobile N/A). Registrar
data, tester, SHA de head e base, URL, resultado por caso, evidência, não testados, totais e Veredito
no comentário da PR e no sub-item QA do Plane. Se a head mudar depois do QA, repetir Steps 2–4.

---

### Task 5: Release (fase Release, skill `release`)

- [ ] **Step 1: Pré-condições (todas verificadas, nenhuma assumida)**

```bash
cd /Users/cauapuppim/newbyte/ndesk && git fetch origin --tags
gh pr checks <N> -R newbytesolucoesdigitais/ndesk | grep -c pass                   # esperado: 12
git diff --stat 43e237b860..origin/chore/rails-8.1-upgrade -- db/migrate           # esperado: vazio (zero migrations)
git tag -l 'nb.v*' | sort -V | tail -3; git ls-remote --tags origin 'nb.v*' | tail -3   # a tag nova não pode existir
sed -n '85,95p' .newbyte/qa/README.md                                              # ressalvas da PR #25: fechadas ou dispensadas pelo usuário
gh pr view 24 -R newbytesolucoesdigitais/ndesk --json state,title                  # #24 ainda mexe no workflow de deploy?
git show origin/chore/rails-8.1-upgrade:.github/workflows/docker-build.yml | sed -n '52,75p'   # reler o deploy no SHA que vai a produção
```

Perguntar ao usuário o número da tag (sugestão `nb.v1.6.0`) e obter a dispensa explícita das
ressalvas ainda abertas, se houver.

- [ ] **Step 2: Merge sem squash e tag no merge commit**

```bash
gh api repos/newbytesolucoesdigitais/ndesk/pulls/<N>/merge -X PUT -f merge_method=merge
git fetch origin newbyte-stable
git tag nb.v<X.Y.Z> origin/newbyte-stable && git push origin nb.v<X.Y.Z>
git rev-parse origin/newbyte-stable nb.v<X.Y.Z>          # os dois SHAs iguais; anotar
```

- [ ] **Step 3: Build, deploy e confirmação da imagem**

```bash
gh run list -R newbytesolucoesdigitais/ndesk --workflow docker-build.yml --limit 3
gh run watch <run id> -R newbytesolucoesdigitais/ndesk --exit-status           # esperado: build e deploy verdes
gh run view <run id> -R newbytesolucoesdigitais/ndesk --log | grep "Deployed tag"   # anotar a tag da imagem
curl -s -u '<usuário>:<senha>' https://<host de produção>/api/v1/version         # esperado: "7.0.0-nb.v<X.Y.Z>"
```

- [ ] **Step 4: Smoke pós-deploy e fechamento**

Login, criar ticket, abrir a Aba de um ticket existente, Taskbar. Registrar no Plane (sub-item Release) e
no comentário final da PR: SHA do merge, tag, tag da imagem, versão servida, resultado do smoke.

- [ ] **Step 5: Rollback (contingência, sempre por PR de revert e tag nova)**

```bash
# regressão só dos defaults: reverter, na ordem inversa, os commits (defaults) e o commit 2
git revert --no-edit <sha do commit 2 e dos fix(defaults), do mais novo ao mais antigo>
# regressão do framework: reverter também os (bump) e o commit 1, depois dos anteriores
# abrir PR de revert contra newbyte-stable, mergear sem squash, cortar tag nova (nunca mover a antiga)
```
