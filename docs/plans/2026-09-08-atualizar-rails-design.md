# Spec — Atualizar Rails 8.0.4 → 8.1.3.1 (NDESK-45)

- **Task:** [NDESK-45](https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-45/) · `[NDesk] Atualizar Rails`
- **Data:** 2026-09-08 · **Fase:** Planning
- **Branch:** `chore/rails-8.1-upgrade` (base `newbyte-stable` @ `43e237b860`, tag `nb.v1.5.1`)
- **Status:** aprovado em conversa; aguardando grill e aprovação da versão escrita

## 1. Problema

O job **Security Scan** do CI (`.github/workflows/ci-test.yml`, passo Brakeman) falha com exit code 3
desde 2026-09-04. O Brakeman 8.0.2 (versão travada no `Gemfile.lock`) roda o check `EOLRails`, cuja
tabela interna diz que a série Rails 8.0 acaba em **2026-10-07**. O check emite warning fraco a 60 dias
do fim, médio a 30 dias e forte ("ended on") depois da data; qualquer warning faz o Brakeman sair com 3,
e o job fica vermelho. Enquanto isso, toda PR para `newbyte-stable` nasce com o check vermelho.

O NDesk está em Rails 8.0.4, Ruby 3.4.8, `config.load_defaults 8.0`, base Zammad 7.0.0
(merge-base com `upstream/develop` em 2026-02-09).

## 2. Pesquisa (verificada em 2026-09-08)

### 2.1 Datas de suporte

| Fonte | Série 8.0 (8.0.4 … 8.0.5.1) | Série 8.1 |
|---|---|---|
| [Política oficial do Rails](https://rubyonrails.org/maintenance) | bugfix acabou 2026-05-07; segurança até **2026-11-07** | bugfix até 2026-10-10; segurança até **2027-10-10** |
| Brakeman 8.0.2 (`check_eol_rails.rb` na tag v8.0.2) | **2026-10-07** (tabela fixa, um mês antes do oficial) | sem entrada → nunca avisa |
| Brakeman 8.0.6 (última publicada; tag v8.0.6) | 2026-11-07 | 2027-10-10 |

Consequências:

- Subir só o patch (8.0.5.1) **não resolve**: a série é a mesma. Mesmo com Brakeman 8.0.6, 2026-11-07
  menos 60 dias cai em 2026-09-08 (hoje), e o warning voltaria de imediato.
- Rails 8.1 resolve com qualquer um dos dois Brakemans; com o 8.0.6 o próximo aviso fraco seria
  por volta de 2027-08-11.
- Suporte é por série, não por patch: 8.0.5 tem a mesma data que 8.0.4.

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

### 2.4 Compatibilidade das gems com Rails 8.1 (gemspecs via API do RubyGems)

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

Nenhuma gem do lock limita Rails, railties, actionpack ou activerecord abaixo de 8.1. A expectativa
é que `bundle update rails --conservative` só troque Rails e seus componentes.

### 2.5 Mudanças do Rails 8.1 relevantes para o NDesk

Fontes: [guia de upgrade](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html),
[release notes 8.1](https://guides.rubyonrails.org/8_1_release_notes.html), CHANGELOGs do branch
`8-1-stable` e o template `new_framework_defaults_8_1.rb.tt` do railties.

#### Novos defaults (só ativam com `load_defaults 8.1`)

| Config | Novo valor | Impacto no NDesk | Verificação |
|---|---|---|---|
| `action_controller.escape_json_responses` | `false` | `render json` deixa de escapar `<>&` e U+2028/2029. 458 chamadas em `app/`, consumidas por XHR da UI legada e pelas UIs Vue; o escape não era fronteira de segurança | artigo/ticket com `<>&` no corpo e no título renderiza igual no zoom e na busca |
| `active_support.escape_js_separators_in_json` | `false` | idem, para U+2028/2029 | coberto pelo item acima |
| `active_record.raise_on_missing_required_finder_order_columns` | `true` | `#first`/`#last` sem `order` em relação cujo model não tem PK, `implicit_order_column` nem `query_constraints` levanta `MissingRequiredOrderError`. 262 usos de `.first` em `app/lib`, todos em models com `id`. 12 tabelas de junção sem PK (`groups_users`, `roles_users`, …) não têm model | suíte RSpec + Minitest; grep de queries diretas nas 12 tabelas |
| `action_controller.action_on_path_relative_redirect` | `:raise` | `redirect_to "x"` sem `/` inicial levanta `UnsafeRedirectError`. Grep não achou literal relativo; falta auditar redirects dinâmicos (OAuth, sessão, `return_to`) | auditoria de todos os `redirect_to` + request specs + smoke de login/OAuth no preview |
| `action_view.render_tracker` | `:ruby` | rastreio de dependências de templates para cache de fragmento; poucas views ERB | suíte; smoke das páginas ERB (login, erro) |
| `action_view.remove_hidden_field_autocomplete` | `true` | `form_tag`/`button_to` sem `autocomplete="off"` nos hidden; UI legada é JS | suíte; smoke |

#### Mudanças que valem independentemente dos defaults

| Mudança | Impacto | Verificação |
|---|---|---|
| Query string: `;` deixa de separar parâmetros; `[foo]=bar` vira chave `"[foo]"` | UIs não usam `;`; risco baixo | request specs |
| Rota para controller inexistente responde 500 em vez de 404 | 14 request specs afirmam 404, em rotas reais | suíte |
| `head` depois de `render` levanta `DoubleRenderError` | 2 controllers com `head` a auditar | suíte + leitura |
| `HEAD` em `PublicExceptions`/`DebugExceptions` volta corpo vazio | nenhum | suíte |
| `CurrentAttributes` zerado ao fim de cada request | Zammad já chama `clear_all` em 3 pontos e usa 2 classes `CurrentAttributes` | suíte |
| `schema.rb` ordenado alfabeticamente | `db/schema.rb` é ignorado pelo git | nenhuma |
| `database.yml`: `pool` renomeado para `max_connections` (compatível) | manter `pool: 50` como o upstream | log de deprecação; se houver, vem de `/gems/` e é permitido |
| Removidos: `Benchmark.ms`, `rails/console/methods`, `Time#since(Time)`, soma `Time + TimeWithZone`, `to_time` sem preservar timezone | grep: 0 usos | — |
| Deprecados: `String#mb_chars`, `ActiveSupport::Multibyte::Chars`, `ActiveSupport::Configurable`, `to_time_preserves_timezone`, `signed_id_verifier_secret`, `class_name` em `belongs_to` polimórfico, `insert_all`/`upsert_all` com registros não persistidos, `WITH`/`DISTINCT` em `update_all` | grep: 0 usos | — |
| `app/jobs/user_device_log_job.rb`: `self.enqueue_after_transaction_commit = false` | forma booleana continua válida em 8.1 (só os modos simbólicos e a config global foram removidos) | suíte |
| YJIT não é mais ligado em dev/test por padrão | NDesk tem `config/initializers/yjit.rb` próprio | nenhuma |

### 2.6 Pontos de acoplamento com internals (auditar contra a fonte 8.1.3.1)

`lib/core_ext` reabre:

- `ActionDispatch::Cookies::CookieJar#write_cookie?`
- `ActiveRecord::Calculations#pluck_as_hash` (+ `Enumerable`)
- `ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements#quoted_columns_for_index`
- `ActiveRecord::Store::IndifferentCoder.as_indifferent_hash`
- `ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper#max_attempts`
- `ActiveSupport::Callbacks::ClassMethods#without_callback`
- `ActiveSupport::TaggedLogging::Formatter#call`
- `Rack::Session::Abstract::Persisted#security_matches?` e `Rack::Utils.add_cookie_to_header` (Rack fica em 2.2, sem mudança)

Mais 43 initializers em `config/initializers`, dos quais os que tocam AR/AJ/AC
(`active_record_*.rb`, `delayed_jobs_*.rb`, `zzz_action_cable_preferences.rb`, `session_store.rb`,
`cookies_serializer.rb`, `wrap_parameters.rb`) são lidos na execução.

### 2.7 Suíte de testes

`spec/support/deprecation_toolkit.rb`: qualquer deprecação cujo topo da stack esteja fora de `/gems/`
ou `/ruby/` **falha o exemplo**. Deprecação vinda de gem é permitida. Logo, deprecações do 8.1
disparadas por código do app quebram o RSpec e precisam ser corrigidas na origem.

## 3. Decisões

| # | Decisão | Motivo |
|---|---|---|
| D1 | Versão alvo **Rails 8.1.3.1**, `gem 'rails', '~> 8.1.0'` | última publicada; única série que silencia o EOLRails nos dois Brakemans; suporte de segurança até 2027-10-10 |
| D2 | **Adotar `config.load_defaults 8.1` nesta task**, sem arquivo `new_framework_defaults_8_1.rb` | decisão do usuário; estilo do upstream (sem arquivo de defaults); cada default verificado explicitamente (§2.5) |
| D3 | Subir **Brakeman para 8.0.6** junto | gem só de desenvolvimento; com 8.0.2 o check EOLRails ficaria mudo para a série 8.1; alinha com o upstream |
| D4 | **Uma PR, dois commits**: (1) bump Rails + Brakeman + correções que a suíte exigir; (2) `load_defaults 8.1` + ajustes dos defaults | um preview e um QA; o commit 2 pode ser revertido sozinho |
| D5 | Ruby fica em 3.4.8; rack fica em 2.2.x; nenhuma outra gem é atualizada de propósito | fora do escopo; actionpack 8.1 aceita rack 2.2.4+ |
| D6 | `database.yml` mantém `pool: 50` | compatível; igual ao upstream; evita divergência |
| D7 | Deprecações no código do app são corrigidas na origem, nunca adicionadas a `allowed_deprecations` | política já vigente na suíte |
| D8 | Execução local com `rbenv install 3.4.8` + PostgreSQL 17 e Redis já instalados; CI da PR é a autoridade | Gemfile pina 3.4.8; máquina não tem Docker |
| D9 | "Staging" = preview de PR `ndesk-pr-{N}.staging-preview.newbyte.net.br` | é o ambiente que existe (usado no QA da PR #23) |

## 4. Design

### 4.1 Dependências

1. `Gemfile`: `gem 'rails', '~> 8.1.0'`.
2. `bundle update rails brakeman --conservative` → lock com rails 8.1.3.1 (todos os componentes) e
   brakeman 8.0.6. Se o bundler exigir bump transitivo, aceitar só o mínimo e listar na PR.
3. `bundle exec rails zeitwerk:check` e boot da app (`rails runner 'puts Rails.version'`).

### 4.2 Configuração

- `config/application.rb`: `config.load_defaults 8.1`.
- Sem `new_framework_defaults_8_1.rb`. Se algum default precisar ser revertido pontualmente, a
  exceção entra explícita em `config/application.rb` com comentário e é registrada na spec/PR.
- `config/database.yml`: sem mudança.

### 4.3 Código

Só o que a suíte, o Brakeman ou a auditoria exigirem. Roteiro de auditoria (antes de rodar a suíte
inteira):

1. Diff de cada método reaberto em `lib/core_ext` (§2.6) contra o código do Rails 8.1.3.1 instalado.
2. `grep -rn "redirect_to" app lib` → classificar cada um: URL absoluta, path com `/`, helper de rota,
   ou dinâmico. Dinâmicos ganham `allow_other_host`/normalização ou teste que prove o `/` inicial.
3. Os 2 controllers com `head` após render.
4. Queries diretas nas 12 tabelas de junção sem PK (`.first`/`.last`/`.take` sobre `Arel`/`select`).
5. Suíte completa (RSpec + Minitest) local; corrigir falhas; deprecações do app corrigidas na origem.
6. Brakeman 8.0.6 local: exit 0. Achados novos legítimos são corrigidos; falsos positivos entram em
   `config/brakeman.ignore` com justificativa no commit.

### 4.4 Ambiente

- Local: `rbenv install 3.4.8`, `bundle install`, banco de dev/test no PostgreSQL 17 local, Redis local.
  Elasticsearch não é necessário para a suíte padrão.
- CI (`ci-test.yml`): Security Scan (Brakeman), Lint, Minitest, RSpec 1–5, Frontend 1–4.
- Preview de PR para o smoke test.

### 4.5 Verificação e aceite

1. **Security Scan verde**: Brakeman 8.0.6 sai com 0, sem warning `EOLRails`.
2. **Suíte verde no CI**: Minitest + RSpec (5 shards) + Frontend (4 shards) + Lint.
3. **Smoke test no preview** (`ndesk-pr-{N}.staging-preview.newbyte.net.br`, UI clássica, pt-BR):
   login/logout; criar, responder e fechar ticket; artigo com `<>&"'` e caracteres U+2028 no corpo e
   no título aparecendo corretos no zoom, na overview e na busca; taskbar e coleções (drag & drop,
   recolher, F5); tela de admin (configurações, usuários); fluxo de redirect pós-login e, se
   configurado no preview, login OAuth; páginas ERB (login, 404 de rota real).
4. **Release**: tag `nb.*` seguinte (sugestão `nb.v1.6.0`, por ser mudança de plataforma), deploy
   pelo workflow existente, smoke reduzido em produção (login, abrir ticket, taskbar).
5. **Rollback**: reverter a PR na `newbyte-stable` e cortar tag da versão anterior; sem migrations
   nesta task, então o banco não trava o retorno.

Critérios de aceite da task (Plane) atualizados para refletir 1–4; o 5º é "release em produção sem
regressão".

## 5. Riscos

| Risco | Prob. | Mitigação |
|---|---|---|
| Regressão de comportamento por `escape_json_responses = false` em consumidor que dependia do escape | baixa | smoke com `<>&` no preview; commit 2 reversível sozinho |
| `UnsafeRedirectError` em redirect dinâmico não coberto pela suíte | média | auditoria completa de `redirect_to` (§4.3.2) + smoke de login/OAuth |
| Brakeman 8.0.6 traz checks novos com achados reais | média | corrigir; nunca ignorar em massa |
| Deprecação do 8.1 disparada por código do app quebra muitos specs | baixa (greps zerados) | corrigir na origem; D7 |
| Monkey patch em `lib/core_ext` com assinatura alterada no 8.1 | baixa | diff contra a fonte antes da suíte (§4.3.1) |
| NDesk à frente do upstream: conflitos em `Gemfile`, `Gemfile.lock`, `application.rb` nos próximos syncs | certa | conflitos triviais; quando o upstream for a 8.1, reconverge |
| Suíte local lenta ou instável fora do devcontainer | média | CI é a autoridade; rodar localmente os diretórios tocados e o `zeitwerk:check` |

## 6. Fora de escopo

- Bump de Ruby (3.4.8).
- Atualização de outras gems além de Rails (com componentes) e Brakeman.
- Sincronização com o upstream Zammad 7.1.
- Silenciar o EOLRails via `brakeman.ignore` ou flags do Brakeman.
- Mudanças de deploy/CI além do necessário para o Security Scan passar.

## 7. Perguntas em aberto

- O preview de PR é provisionado automaticamente ao abrir a PR? (o usuário afirmou que sim; o QA da
  PR #23 confirma o padrão de URL). Se o preview não subir, o smoke roda na stack local e o critério
  é registrado como executado localmente, com decisão explícita do usuário.
- Número da tag de release: decidido na fase de Release.
