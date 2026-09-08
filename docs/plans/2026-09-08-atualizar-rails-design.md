# Spec — Atualizar Rails 8.0.4 → 8.1.3.1 (NDESK-45)

- **Task:** [NDESK-45](https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-45/) · `[NDesk] Atualizar Rails`
- **Data:** 2026-09-08 · **Fase:** Planning · **Revisão:** v2.1 (v2 aprovada pelo usuário; v2.1 incorpora o grill do plano)
- **Branch:** `chore/rails-8.1-upgrade` (base `newbyte-stable` @ `43e237b860`, tag `nb.v1.5.1`)
- **Status:** v2 aprovada em 2026-09-08; ajustes v2.1 marcados nesta revisão

## 1. Problema

O check **Security Scan** do CI (`.github/workflows/ci-test.yml`, passo Brakeman) falha com exit code 3
desde 2026-09-04. O Brakeman 8.0.2 (versão travada no `Gemfile.lock`) roda o check `EOLRails`, cuja
tabela interna diz que a série Rails 8.0 acaba em **2026-10-07**. O check emite warning fraco a 60 dias
do fim, médio a 30 dias e forte ("ended on") depois da data; qualquer warning faz o Brakeman sair com 3.
Enquanto isso, toda PR para `newbyte-stable` nasce com o check vermelho.

O NDesk está em Rails 8.0.4, Ruby 3.4.8, `config.load_defaults 8.0`, base Zammad 7.0.0
(merge-base com `upstream/develop` em 2026-02-09).

## 2. Pesquisa (verificada em 2026-09-08)

### 2.1 Datas de suporte

| Fonte | Série 8.0 (8.0.4 … 8.0.5.1) | Série 8.1 |
|---|---|---|
| [Política oficial do Rails](https://rubyonrails.org/maintenance) | bugfix acabou 2026-05-07; segurança até **2026-11-07** | bugfix até 2026-10-10; segurança até **2027-10-10** |
| Brakeman 8.0.2 (`check_eol_rails.rb`, tag v8.0.2) | **2026-10-07** (tabela fixa, um mês antes do oficial) | sem entrada → nunca avisa |
| Brakeman 8.0.6 (última publicada, tag v8.0.6) | 2026-11-07 | 2027-10-10 |

Consequências:

- Subir só o patch (8.0.5.1) **não resolve**: a série é a mesma. Mesmo com Brakeman 8.0.6, 2026-11-07
  menos 60 dias cai em 2026-09-08 (hoje), e o warning voltaria de imediato.
- Rails 8.1 resolve com qualquer um dos dois Brakemans; com o 8.0.6 o próximo aviso fraco seria
  por volta de 2027-08-11.

### 2.2 Versões disponíveis (RubyGems)

- Rails: última publicada **8.1.3.1** (2026-07-29). Não existe 8.2 nem pré-release 9.x.
  Série 8.1: 8.1.0 (2025-10-22) → 8.1.3.1. Última da 8.0: 8.0.5.1 (2026-07-29).
- Brakeman: última publicada **8.0.6**.
- Ruby 3.4.8 é aceito pelo Rails 8.1 (mínimo 3.2.0).

### 2.3 Upstream Zammad

`upstream/develop` (2026-09-08) e `upstream/stable` (2026-09-07) estão em Rails **8.0.5.1** com
`gem 'rails', '~> 8.0.0'`, Brakeman 8.0.6/8.0.4. Nenhuma issue, PR ou commit em `zammad/zammad`
menciona Rails 8.1 (busca via API do GitHub). O NDesk será pioneiro; não há trabalho upstream para
aproveitar, e o upstream vai esbarrar no mesmo warning do Brakeman nesta semana.

### 2.4 Compatibilidade das gems e mudanças esperadas no lock

Constraints declaradas (gemspecs via API do RubyGems):

| Gem (versão travada) | Constraint declarada | Aceita 8.1? |
|---|---|---|
| actionpack 8.1.3.1 | `rack >= 2.2.4`, `rack-session >= 1.0.1` | rack 2.2.22 e rack-session 1.0.2 atendem |
| railties 8.1.3.1 | `rackup >= 1.0.0`, `zeitwerk ~> 2.6` | rackup 1.0.1 e zeitwerk 2.7.4 atendem |
| actioncable 8.1.3.1 | `websocket-driver >= 0.6.1` | 0.8.0 atende |
| activerecord-session_store 2.2.0 | actionpack/activerecord/railties `>= 7.0`, `rack < 4` | sim |
| activerecord-import 2.2.0 | `activerecord >= 4.2` | sim |
| sprockets-rails 3.5.2 / sprockets 3.7.5 | `actionpack >= 6.1` / `rack > 1, < 3` | sim (mantém rack 2) |
| vite_rails 3.0.20 | `railties >= 5.1, < 9` | sim |
| coffee-rails 5.0.0, sass-rails 5.1.0 | `railties >= 5.2.0` | sim |
| rspec-rails 8.0.2 | actionpack/activesupport/railties `>= 7.2` | sim |
| rails-controller-testing 1.0.5, factory_bot_rails 6.5.1, omniauth-rails_csrf_protection 2.0.1, doorkeeper 5.8.2, pundit 2.5.2, acts_as_list 1.2.6, shoulda-matchers 7.0.1, deprecation_toolkit 2.3.0 | limites inferiores apenas | sim |
| delayed_job 4.1.13 / delayed_job_active_record 4.1.11 | `activesupport < 9.0` / `activerecord < 9.0` | sim |
| rack-attack 6.8.0, rubocop-rails 2.34.3 | `rack < 4` / `rack >= 1.1` | sim |
| rack-session 1.0.2, rackup 1.0.1, rack-protection 3.2.0 | `rack < 3` / `rack ~> 2.2` | pinam rack 2.x; sem conflito com actionpack 8.1 |

Nenhuma gem do lock limita Rails, railties, actionpack ou activerecord abaixo de 8.1. O grafo do
Rails 8.1.3.1, porém, **não troca só Rails e Brakeman**: `actiontext` 8.1 passa a depender de
`action_text-trix (~> 2.1.15)` (gem nova no lock) e `activesupport` 8.1 deixa de depender de
`benchmark` (sai do lock se nenhuma outra gem a exigir) e passa a declarar `json` (versão atual
pode ficar). A allowlist de mudanças do lock está em §4.1.

**Rack 2.2.x é invariante técnica, não preferência:** `lib/core_ext/rack/utils.rb` reabre
`Rack::Utils.add_cookie_to_header`, removido no Rack 3 (com Rack 3.2.6 o arquivo levanta
`NameError`). O actionpack 8.1 aceita `rack >= 2.2.4`, e `rack-session`, `rackup`, `rack-protection`
e `sprockets` pinam `< 3`.

### 2.5 Mudanças do Rails 8.1 relevantes para o NDesk

Fontes: [guia de upgrade](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html),
[release notes 8.1](https://guides.rubyonrails.org/8_1_release_notes.html), CHANGELOGs do branch
`8-1-stable` e `railties/lib/rails/application/configuration.rb` da tag v8.1.3.1 (bloco `when "8.1"`).

#### Os sete ajustes de `config.load_defaults 8.1`

| Config | 8.0 → 8.1 | Impacto no NDesk | Oráculo |
|---|---|---|---|
| `config.yjit` | `true` → `!Rails.env.local?` | YJIT desligado em development/test, ligado em production. `config/initializers/yjit.rb` só força `false` com `ZAMMAD_DISABLE_YJIT`; não neutraliza | `rails runner` em test e production imprimindo `Rails.application.config.yjit` |
| `action_controller.escape_json_responses` | `true` → `false` | `render json` deixa de escapar `<>&` e U+2028/2029. ~460 chamadas em `app/`, consumidas por XHR das UIs (clássica e Vue), que fazem `JSON.parse`. Nenhuma view ERB embute JSON (`to_json`/`json_escape` ausentes em `app/views`), então não há consumidor que dependa do escape | request spec afirmando que o **corpo HTTP bruto** contém `<`, `>`, `&` literais e U+2028/U+2029 sem escape; grep de embedding em ERB registrado como N/A |
| `active_support.escape_js_separators_in_json` | `true` → `false` | afeta o encoder global (`ActiveSupport::JSON.encode`): além dos controllers, WebSocket server (`lib/websocket_server.rb`) e stores de sessão (`lib/sessions/store/{file,redis}.rb`), todos com `JSON.parse` do outro lado | teste unitário de `ActiveSupport::JSON.encode` com U+2028/U+2029; um teste de round-trip do store de sessão |
| `active_record.raise_on_missing_required_finder_order_columns` | `false` → `true` | `first`/`last`/finders posicionais sem `order` em model sem `primary_key`, `implicit_order_column` ou `query_constraints` levantam `MissingRequiredOrderError`. `take`/`find_by` não são afetados. 12 tabelas `id: false`: `groups_users` e `roles_groups` têm models (`UserGroup`, `RoleGroup`) com chave composta `ref_key, :group_id, :access`; as outras 10 são HABTM sem model. 377 chamadas de `.first/.last/.take` em `app/lib` revisadas: zero receivers sem coluna de ordem | RSpec + Minitest no CI; reflexão contra banco real na execução |
| `action_controller.action_on_path_relative_redirect` | `:log` → `:raise` | `redirect_to` com destino sem `/` inicial e sem esquema levanta `PathRelativeRedirectError`. 11 chamadas em `app/` (0 em `lib/`): 2 URL absoluta, 5 path com `/`, 2 helper de rota, 2 dinâmicas em `external_credentials_controller.rb` (linhas 41 e 47) cujo valor vem do backend OAuth e é URL absoluta nos backends first-party. `allow_other_host` **não** trata isso (é proteção de host externo, avaliada depois) | request spec por backend garantindo URL com esquema ou path com `/`; smoke de login/redirect pós-login no preview |
| `action_view.render_tracker` | `:regex` → `:ruby` | rastreio de dependências de templates para cache de fragmento; poucas views ERB | suíte; smoke das páginas ERB (login, KB pública) |
| `action_view.remove_hidden_field_autocomplete` | `false` → `true` | `form_tag`/`button_to` sem `autocomplete="off"` nos hidden; UI clássica é JS | suíte; N/A com evidência |

#### Mudanças que valem independentemente dos defaults

| Mudança | Impacto (auditado) | Verificação |
|---|---|---|
| Query string: `;` deixa de separar parâmetros; `[foo]=bar` vira chave `"[foo]"` | UIs não usam `;`; risco baixo | request specs |
| Rota para controller inexistente responde 500 em vez de 404 | 26 `have_http_status(:not_found)` em `spec/requests`, todos de rotas reais (não reproduzido caso de controller inexistente) | suíte |
| `head` depois de `render` levanta `DoubleRenderError` | 2 chamadas de `head` em `app/`: `tickets_controller.rb:285` (após `destroy!`, sem render anterior) e `ticket_articles_controller.rb:206` (branch exclusivo, renders anteriores retornam). Ambas cobertas por request specs | nenhuma correção |
| `HEAD` em `PublicExceptions`/`DebugExceptions` volta corpo vazio | nenhum | suíte |
| `CurrentAttributes` zerado ao fim de cada request | Zammad tem 2 classes `CurrentAttributes` e 4 `clear_all` manuais (has_cache, sessions/client, sessions/event, job_executor) | suíte |
| `schema.rb` ordenado alfabeticamente (incondicional no dumper) | **Corrigido na execução:** `db/schema.rb` é ignorado pelo git, mas `db:migrate` num banco vazio (caminho do `zammad:db:reset`, rodado antes de toda suíte, no CI também) carrega o `schema.rb` existente; com o dump alfabético, o banco de teste ficava com colunas em ordem alfabética, `Ticket.column_names` mudava e o cabeçalho de `CanCsvImport.csv_example` divergia de produção (shared example do upstream falhava). Decisão R7: `config.active_record.dump_schema_after_migration = false` em `test` (e `development`, R8), banco de teste sempre por migrations como produção; `csv_example`, spec e dumper intocados | probe `Ticket.column_names.first(8)` em ordem de criação após `zammad:db:reset`; spec `.csv_example` verde |
| `database.yml`: `pool` → `max_connections` | Rails 8.1.3.1 lê `pool:` silenciosamente como fallback de `max_connections` (`HashConfig`); só o método Ruby `HashConfig#pool` é deprecado, e o app não o chama. Manter `pool: 50` | nenhuma |
| `lock!` ganha guard no topo: levanta `ActiveRecord::ReadOnlyError` em `while_preventing_writes` | `config/initializers/active_record_lock_issue_3664.rb` reabre `Pessimistic#lock!(lock = true)`; o ramo que faz `reload(lock:)` e retorna **pula o guard** (um `SELECT … FOR UPDATE` não conta como escrita). Correção no commit 1: replicar o guard no topo do método patchado | spec de regressão em `spec/lib/active_record/locking/pessimistic_spec.rb` com `while_preventing_writes` |
| Removido `to_time` sem preservar timezone | 3 usos de `to_time` (ics_file/parse, handles_overview_caching, base_cached_connection); `load_defaults 8.0` já preserva timezone (`to_time_preserves_timezone = :zone`), sem mudança de comportamento | suíte |
| Removidos: `Benchmark.ms`, `rails/console/methods`, `Time#since(Time)`, `Time + TimeWithZone`, rotas com múltiplos paths, adapter Sucker Punch, Active Storage `:azure`, `:retries` SQLite, colunas unsigned MySQL | grep: 0 usos | auditado, N/A |
| Erro (não mais deprecação): `class_name:` em `belongs_to` polimórfico | grep: 0 usos | auditado, N/A |
| Deprecados: `String#mb_chars`, `ActiveSupport::Multibyte::Chars`, `ActiveSupport::Configurable`, `to_time_preserves_timezone`, `signed_id_verifier_secret`, `insert_all`/`upsert_all` com registros não persistidos, `WITH`/`DISTINCT` em `update_all` | grep: 0 usos | auditado, N/A |
| `app/jobs/user_device_log_job.rb`: `self.enqueue_after_transaction_commit = false` | forma booleana continua válida em 8.1 (só os modos simbólicos e a config global foram removidos) | suíte |

### 2.6 Pontos de acoplamento com internals

Comparação de fonte 8.0.4 × 8.1.3.1 (grills, sem boot): **nenhum patch de `lib/core_ext` muda de
assinatura no 8.1.3.1**, mas corpos mudaram (`lock!`, `pluck`, batches, callbacks). Assinatura igual não
basta: a execução compara os **corpos** dos métodos reabertos e roda os specs de cada patch.

| Local | Método reaberto | Nota |
|---|---|---|
| `lib/core_ext/action_dispatch/middleware/cookies.rb` | `ActionDispatch::Cookies::CookieJar#write_cookie?` | força `Secure`; torna público método privado upstream |
| `lib/core_ext/rack/session/abstract/id.rb` | `Rack::Session::Abstract::Persisted#security_matches?` | força `Secure`; Rack 2.2 |
| `lib/core_ext/rack/utils.rb` | `Rack::Utils.add_cookie_to_header` | força `Secure`; removido no Rack 3 |
| `lib/core_ext/active_record/calculations/pluck_as_hash.rb` | `pluck_as_hash` (AR + Enumerable) | método local; usa `pluck`/`arel_columns` |
| `lib/core_ext/active_record/connection_adapters/postgresql/schema_statements.rb` | `quoted_columns_for_index` | assinatura mantida |
| `lib/core_ext/active_record/store/indifferent_coder.rb` | `IndifferentCoder.as_indifferent_hash` | assinatura mantida |
| `lib/core_ext/activejob/lib/active_job/queue_adapters/delayed_job_adapter.rb` | `JobWrapper#max_attempts` | integração com Delayed Job |
| `lib/core_ext/activesupport/lib/active_support/callbacks.rb` | `ClassMethods#without_callback` | sem colisão |
| `lib/core_ext/activesupport/lib/active_support/tagged_logging/formatter.rb` | `Formatter#call` | assinatura mantida |
| `config/initializers/active_record_lock_issue_3664.rb` | `Locking::Pessimistic#lock!` | 8.1 mudou o corpo de `lock!` |
| `config/initializers/active_record_as_batches.rb` | define `ActiveRecord::AsBatches#as_batches` (módulo novo incluído em `Relation`); não reabre método upstream | specs que usam `as_batches` |
| `config/initializers/activemodel_error.rb` | `ActiveModel::Errors#add` (alias) e `ActiveModel::Error#localized_full_message` (novo) | upstream em `active_model/errors.rb`; `spec/lib/active_model/errors_spec.rb` |
| `config/initializers/delayed_jobs_timeout_per_job.rb` | `JobWrapper#max_run_time` | com `max_attempts`, cobre a integração AJ × Delayed Job |
| `lib/active_support/cache/zammad_file_store.rb` | `ActiveSupport::Cache::FileStore` | verificar na execução |

Os três patches de cookie `Secure` têm teste contratual em `spec/requests/session_spec.rb` ("sets Cookie
with 'secure' flag"), que entra nos gates dos dois commits.

### 2.7 Suíte de testes e CI

- `spec/support/deprecation_toolkit.rb`: deprecação cujo primeiro frame absoluto está fora de
  `/gems/` ou `/ruby/` **falha o exemplo**. Deprecação vinda de gem é permitida. Deprecações do 8.1
  disparadas por código do app quebram o RSpec e são corrigidas na origem.
- `ci-test.yml` tem 12 jobs: Lint (1), Frontend Tests/Vitest (4), Security Scan (1), RSpec (5),
  Minitest (1). O RSpec do CI **exclui** `spec/system`, `searchindex`, `integration` e
  `required_envs`. Não há gate de boot nem `zeitwerk:check` no CI. Não há QUnit/Cypress nesse
  workflow.
- Preparação local de banco e assets segue
  `doc/developer_manual/cookbook/how-to-test-with-rspec-and-capybara.md`.

## 3. Decisões

| # | Decisão | Motivo |
|---|---|---|
| D1 | Versão alvo **Rails 8.1.3.1**, `gem 'rails', '~> 8.1.0'` | última publicada; única série que silencia o EOLRails nos dois Brakemans; segurança até 2027-10-10 |
| D2 | **Adotar `config.load_defaults 8.1` nesta task**, sem `new_framework_defaults_8_1.rb` | decisão do usuário; estilo do upstream; os sete ajustes verificados um a um (§2.5) |
| D3 | Subir **Brakeman para 8.0.6** junto | gem só de desenvolvimento; com 8.0.2 o EOLRails ficaria mudo para a série 8.1; alinha com o upstream |
| D4 | **Uma PR** com os commits de planejamento (spec, plano) mais **dois commits de implementação**: (1) bump Rails + Brakeman + lock + ajustes que mudam só pela troca das gems; (2) `load_defaults 8.1` + ajustes causados pelos sete defaults + seus testes. Correções após o push entram como **commits novos rotulados** `(bump)` ou `(defaults)` no título; o histórico nunca é reescrito (`.claude/NEWBYTE_WORKFLOW.md` proíbe operações destrutivas). **Merge sem squash** (prática atual da `newbyte-stable`: merge commits) | um preview e um QA; o conjunto `(defaults)` pode ser revertido sem o `(bump)` |
| D5 | Ruby fica em 3.4.8; **rack fica em 2.2.x (invariante)**; mudanças no lock limitadas à allowlist de §4.1 | fora do escopo; patch em `Rack::Utils` incompatível com Rack 3 |
| D6 | `database.yml` mantém `pool: 50` | Rails 8.1.3.1 lê `pool:` como fallback de `max_connections` sem warning; igual ao upstream |
| D7 | Deprecações no código do app são corrigidas na origem, nunca adicionadas a `allowed_deprecations` | política já vigente na suíte |
| D8 | Execução local com `rbenv install 3.4.8` + PostgreSQL 17 e Redis já instalados; gates locais em §4.4; todos os jobs de `ci-test.yml` são o gate remoto | Gemfile pina 3.4.8; máquina não tem Docker |
| D9 | "Staging" = **preview da PR** `ndesk-pr-{N}.staging-preview.newbyte.net.br` (provisionador externo ao repo; padrão de URL visto no comentário de QA da PR #23 no GitHub) | é o ambiente que existe |
| D10 | **Preview indisponível bloqueia o release**; a stack local é pré-check, nunca substituto (não tem Elasticsearch, logo não cobre busca) | critério de aceite fixado no briefing |
| D11 | Sem ADR nem mudança em `CONTEXT.md` | upgrade de plataforma, sem conceito de domínio novo |

## 4. Design

### 4.1 Dependências

1. `Gemfile`: `gem 'rails', '~> 8.1.0'`.
2. `bundle lock --update rails brakeman --conservative --print` (Bundler 2.6.9, o do lock) e comparar
   com a allowlist antes de gravar. Se o resolver não destravar os componentes, repetir nomeando
   Rails + os 12 componentes + Brakeman, ainda `--conservative`.
3. **Allowlist do lock:** Rails e seus 12 componentes `8.0.4 → 8.1.3.1`; `brakeman 8.0.2 → 8.0.6`;
   `action_text-trix` adicionada; `benchmark` removida; vínculo de `json` declarado (versão mantida se
   o resolver permitir); `rack` continua `2.2.22`. **Qualquer outra mudança de versão para a
   execução e reabre o escopo com o usuário.**
4. Gates: `bundle install`, boot (`rails runner 'puts Rails.version'`), `bundle exec rails
   zeitwerk:check`, Brakeman exit 0.

### 4.2 Configuração

- `config/application.rb`: `config.load_defaults 8.1` e comentário da linha anterior atualizado
  (hoje diz "originally generated Rails version").
- Sem `new_framework_defaults_8_1.rb`. Se algum default precisar ser revertido pontualmente, a
  exceção entra explícita em `config/application.rb` com comentário e é registrada neste documento e
  na descrição da PR.
- `config/database.yml`: sem mudança.
- Valores efetivos dos sete ajustes conferidos por `rails runner` em `test` e `production`.

### 4.3 Código

Resultados da auditoria (fechados no grill; a execução os repete com as gems instaladas):

1. **Redirects:** 11 `redirect_to` em `app/`, 0 em `lib/`, 1 em `config/initializers/doorkeeper.rb`
   (`root_path`, seguro). Nenhum quebra com os produtores atuais. Os dinâmicos em
   `external_credentials_controller.rb` (linhas 41, 47 e 52) dependem do valor: request spec por
   backend OAuth garantindo URL com esquema ou path com `/`. A linha 47 tem
   `return redirect_to(channel), allow_other_host: true`, em que `allow_other_host` vira segundo valor
   do `return` e não chega ao `redirect_to`: corrigir a sintaxe no commit 2, com teste; comportamento
   para host próprio não muda.
2. **`head` após render:** nenhuma correção (§2.5).
3. **Finders sem ordem:** nenhuma correção (§2.5).
4. **Internals (§2.6):** diff dos corpos dos métodos reabertos com as gems instaladas; specs dos
   patches (`pessimistic_spec.rb`, `errors_spec.rb`, `session_spec.rb`); guard de somente-leitura
   replicado no patch de `lock!`, com teste de regressão.
5. Deprecações do app corrigidas na origem (D7).
6. Brakeman 8.0.6: achados novos legítimos são corrigidos; falsos positivos entram em
   `config/brakeman.ignore` com justificativa no commit.
7. Comentários que citam a versão do Rails (`config/application.rb:22`,
   `spec/models/ticket/satisfaction_rating_spec.rb:15,59`) são atualizados no commit 2, sem mudar
   comportamento. Entrada de changelog em `.claude/NEWBYTE_WORKFLOW.md` (obrigatória pelo workflow).

Fronteira dos commits: o commit 1 contém gems, lock e ajustes que mudam só pela troca das gems
(§2.5, tabela "independentemente dos defaults", e §2.6); o commit 2 contém `load_defaults 8.1`, os
ajustes dos sete defaults e seus testes. Commit 1 passa nos gates locais sozinho; commit 2 passa sobre
o commit 1.

### 4.4 Ambiente e gates

- **Local (obrigatório):** `brew install imlib2 gnupg` (rszr e specs de PGP), `rbenv install 3.4.8`,
  `bundle install`, preparação de banco/assets (cookbook), boot em `test`, `zeitwerk:check`, Brakeman,
  `assets:precompile` após o bump, specs dos pontos afetados, valores efetivos dos sete defaults em
  `test` e `production`. Comandos de gate rodam em `bash` com `set -euo pipefail` e status numérico
  (o shell da máquina é zsh; `~tag` sem aspas e `PIPESTATUS` não funcionam nele).
- **Remoto (autoridade):** os 12 jobs de `ci-test.yml` verdes no SHA da head da PR, com as exclusões
  conhecidas (§2.7) registradas. Os 4 jobs de frontend e o Lint não dependem desta mudança e são
  só remotos; localmente roda `pnpm lint:md` (docs tocados).
- **Preview da PR:** cobre busca (Elasticsearch), páginas ERB e caminhos fora do CI. Registrar URL,
  SHA implantado e readiness antes do smoke.

### 4.5 Verificação e aceite

Registro de trabalho do QA em `.newbyte/qa/{N}/` (convenção local do `.newbyte/qa/README.md`; a pasta
não é rastreada pelo git). O registro **compartilhado** é o comentário de Veredito na PR e a descrição
do sub-item QA no Plane, com data, tester, SHA de head e base, URL do preview, resultado por caso,
evidência, casos não testados, totais e Veredito.

Casos mínimos do smoke no preview, UI clássica, usuário pt-BR:

| Caso | Resultado esperado |
|---|---|
| Login e logout como agente | sessão criada; cookie de sessão com `Secure`; redirect pós-login para `/#` |
| Criar ticket com título e artigo contendo `<>&"'` e U+2028/U+2029 | zoom, overview e busca mostram o texto literal, sem entidades e sem quebra |
| Responder e **finalizar** o ticket (estado de categoria `closed`) | estado muda; CSAT: Cliente vê a Avaliação de Satisfação, envia Nota de Resolução, Nota de Atendimento e comentário com o mesmo corpus; F5 preserva e não repete a avaliação |
| Taskbar: uma Aba Solta e duas Abas numa Coleção nomeada; recolher; F5; logout/login | ordem, membros, nome e estado recolhido preservados; fechar o último membro remove a Coleção |
| Tela de admin (configurações, usuários) | carrega e salva sem erro |
| Página pública da Knowledge Base (ERB) | renderiza |
| Login OAuth | request spec incondicional pelo formato da URL; smoke real só se houver provider configurado no preview (senão N/A registrado) |
| desktop-view e mobile | N/A: o NDesk usa só a UI clássica (`.claude/NEWBYTE_WORKFLOW.md`, seção Frontend) |

### 4.6 Release e rollback

Pré-condições para criar a tag `nb.*` (sugestão `nb.v1.6.0`, mudança de plataforma; o número é
perguntado ao usuário antes de criar, como manda o workflow):

1. os 12 jobs verdes no SHA da head da PR e merge sem squash na `newbyte-stable`; se a head mudar
   depois do QA, CI e QA se repetem;
2. Veredito aprovado do QA no preview, no mesmo SHA;
3. `git diff --stat 43e237b860..<merge> -- db/migrate` vazio (zero migrations);
4. ressalvas do Veredito da PR #25 (`.newbyte/qa/README.md`: fail-fast do `script` de deploy,
   `deploy@host:porta` confirmado, `scp` da PR #24) fechadas **ou dispensadas explicitamente pelo
   usuário** antes da tag; workflow de deploy relido no SHA do merge;
5. tag inexistente local e remota; tag única apontando para o merge commit; registrar SHA do merge,
   tag e a tag da imagem impressa pelo job de deploy; aguardar build e deploy verdes;
6. smoke pós-deploy obrigatório em produção: login, criar ticket, abrir a Aba de um ticket existente,
   Taskbar; confirmar a versão servida (`/api/v1/version`, carimbada com a tag pelo build).

Rollback, sempre por PR de revert e tag **nova** (nunca mover ou reutilizar tag):

- **regressão só dos defaults:** reverter o commit 2 e seus commits `(defaults)`, na ordem inversa;
- **regressão do framework/gems:** reverter também o commit 1 e seus commits `(bump)`, depois dos
  anteriores.

A pré-condição 3 garante zero migrations, então o banco não trava o retorno.

## 5. Critérios de aceite (Plane)

- **Security Scan:** Brakeman 8.0.6 sai com 0 no CI, sem warning `EOLRails`.
- **CI:** todos os jobs de `ci-test.yml` verdes na head da PR.
- **Preview:** smoke de §4.5 executado no preview da PR com Veredito aprovado em `.newbyte/qa/{N}/`.
- **Release:** tag `nb.*` no merge aprovado, deploy pelo workflow existente e smoke pós-deploy sem
  regressão.

Rollback (§4.6) é contingência, não critério.

## 6. Riscos

| Risco | Prob. | Mitigação |
|---|---|---|
| Consumidor externo dependendo dos bytes escapados do JSON | baixa | nenhum conhecido; commit 2 reversível sozinho |
| `PathRelativeRedirectError` em backend OAuth que devolva valor inesperado | baixa | request specs por backend; smoke de login |
| Brakeman 8.0.6 traz checks novos com achados reais | média | corrigir; nunca ignorar em massa |
| Deprecação do 8.1 disparada por código do app quebra specs | baixa (greps zerados) | corrigir na origem (D7) |
| Reopening em `config/initializers` com corpo mudado no 8.1 (`lock!`) | média | diff com as gems instaladas antes da suíte |
| Resolver do Bundler muda algo fora da allowlist | média | `--print` + comparação antes de gravar; parar e reabrir escopo |
| NDesk à frente do upstream: conflitos em `Gemfile`, lock e `application.rb` nos próximos syncs | certa | conflitos triviais; quando o upstream for a 8.1, reconverge |
| Preview não sobe ou implanta SHA diferente | média | D10: bloqueia; registrar SHA implantado |

## 7. Fora de escopo

- Bump de Ruby (3.4.8).
- Atualização de outras gems além da allowlist de §4.1.
- Sincronização com o upstream Zammad 7.1.
- Silenciar o EOLRails via `brakeman.ignore` ou flags do Brakeman.
- Mudanças de deploy/CI além do necessário para o Security Scan passar. As ressalvas de infra já
  registradas no `.newbyte/qa/README.md` (fail-fast do deploy, `scp` da PR #24, proteção de branch)
  continuam abertas e não entram nesta task.

## 8. Perguntas em aberto

- Preview da PR: provisionado automaticamente ao abrir a PR, por sistema fora deste repo (resposta do
  usuário em 2026-09-08). Se não subir, o usuário é avisado e a release fica bloqueada (D10).
- `.claude/NEWBYTE_WORKFLOW.md` está desatualizado (formato de tag `nb.v{major}.{minor}` vs. `nb.v1.5.1`
  real; deploy via Coolify vs. workflow por tag + SSH). Atualizar é decisão do usuário; a entrada de
  changelog desta task entra de qualquer forma.
- Número da tag de release: decidido na fase de Release.
