# Handoff — NDESK-45 — [NDesk] Atualizar Rails

> Gerado em 2026-09-08 23:15. Consumido pelo fluxo Desenvolvimento → Handoff do
> plugin New Byte. Fonte da verdade sobre estado da task: o Plane.

## Task
- Identificador: NDESK-45
- Link: https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-45/
- Projeto: NDesk

## Fase atual
Execution — plano `docs/plans/2026-09-08-atualizar-rails.md` executado via subagent-driven-development
(SDD): Tasks 0, 1 e 2 concluídas e revisadas; Task 3 implementada (DONE_WITH_CONCERNS) e **ainda sem
revisão**. Retomar em: revisão da Task 3 → revisão final da branch → review OpenAI → autorização de
push + PR → republicação no Plane → Execution Done / etiqueta QA. Nada foi pushado.

## O que já foi feito
- Planning fechado no Plane (sub-item NDESK-46 Done); spec v2.1 e plano v2 publicados na descrição dele
  (marcador `nb-pub v1`, hashes `898b451fe973`/`089183be25c8`, hoje desatualizados: ver Artefatos).
- Task principal em In Progress com etiqueta **Execution**; sub-item Execution (NDESK-47) In Progress.
- Branch `chore/rails-8.1-upgrade` (base `newbyte-stable` @ `43e237b860`, tag `nb.v1.5.1`), 14 commits
  locais, árvore limpa, sem stash:
  - `639a77688c` chore(deps): Rails 8.0.4 → 8.1.3.1, Brakeman 8.0.6, guard de somente-leitura em `lock!`
    (`config/initializers/active_record_lock_issue_3664.rb`) com teste, contrato do parser de query string,
    `dump_schema_after_migration = false` em `config/environments/test.rb`.
  - `1e6d9903a5` fix(bump): mesmo flag em `development.rb`.
  - `e5b4fcc17b` chore(config): `config.load_defaults 8.1` com um teste por ajuste
    (`spec/config/framework_defaults_spec.rb` + oráculos em `spec/controllers`, `spec/requests`,
    `spec/lib/sessions`), `allow_other_host` passado de fato em `external_credentials_controller.rb:47`,
    entrada em `config/brakeman.ignore` (Redirect fraco na linha 47, mesmo padrão da 39),
    `custom_path_spec.rb` com expectativa absoluta.
  - `674b3185b7` fix(bump): `spec/support/db_migration.rb` usa a classe viva da migration (sem
    `db/schema.rb`, o `zammad:db:reset` roda as 484 migrations dentro do RSpec e o `MigrationProxy`
    recarrega as classes; afetaria o CI).
  - `ca8f25a7f2` docs(workflow): entrada de changelog em `.claude/NEWBYTE_WORKFLOW.md`.
  - Demais commits: `docs(planning)` (spec, plano e correções de execução R6–R9).
- Gates verificados (macOS, Ruby 3.4.8, PostgreSQL 17 e Redis locais, sem Docker/Elasticsearch):
  boot 8.1.3.1 com `loaded_config_version` 8.1; `zeitwerk:check` OK; Brakeman 8.0.6 exit 0, sem EOLRails
  (36 ignorados); `assets:precompile` OK; sete valores do 8.1 confirmados em `test` e `production`;
  RSpec shards 1–4: 13.231 exemplos, 31 falhas todas de ambiente (abaixo); shard 5 (migrations): 358/0;
  Minitest 166 runs/0; Rubocop nos 16 arquivos Ruby tocados: limpo; `pnpm lint:md`: 0 erros nos .md da
  branch (a base tem 469 erros pré-existentes).
- Reviews SDD: Task 0 aprovada (sonnet); Task 1 aprovada após 2 rounds (opus); Task 2 aprovada (opus).
  Minors deferidos no ledger `.superpowers/sdd/2026-09-08-atualizar-rails/progress.md`.
- Material técnico da PR já escrito: `.superpowers/sdd/2026-09-08-atualizar-rails/artifacts/pr-body.md`.

## Decisões tomadas (e por quê)
- Alvo Rails 8.1.3.1 (última publicada) e não 8.0.5: o suporte é por série; a tabela do Brakeman 8.0.2
  marca a série 8.0 como EOL em 2026-10-07 (oficial: 2026-11-07) e nem o Brakeman 8.0.6 evitaria o aviso.
- `load_defaults 8.1` na mesma entrega (decisão do usuário), com oráculo por ajuste; Brakeman 8.0.6 junto.
- Uma PR, dois commits de implementação + commits rotulados `(bump)`/`(defaults)`; nunca reescrever
  histórico (`.claude/NEWBYTE_WORKFLOW.md`); merge sem squash.
- R6: gates locais de RSpec usam `--tag '~searchindex' --tag '~integration' --tag '~required_envs'` como o CI.
- R7/R8: Rails 8.1 dumpa `schema.rb` com colunas alfabéticas e `db:migrate` num banco vazio carrega o
  dump (caminho do `zammad:db:reset` que roda antes de toda suíte, no CI também); isso mudava
  `Ticket.column_names` e o cabeçalho de `csv_example`. Dump desligado em `test` e `development`
  (produção já era). Efeito: cada processo RSpec roda as 484 migrations (~3 s) e `db/schema.rb` deve
  ficar ausente.
- R9: falhas só de ambiente local, classificadas com evidência: `spec/lib/user_agent_spec.rb` (27; porta
  3000 ocupada pelo Puma do projeto NChat, pid 60497), `spec/lib/signature_detection_spec.rb` (2; `diff`
  BSD via gem diffy, reproduzido sem Rails), `spec/services/service/translation/search_spec.rb:47` (passa
  isolado; depende de estado do banco), `spec/models/system_report/plugin/hardware_spec.rb` (lshw/Linux).
  `calendar_spec` e `set_defaults_spec` passam com `TZ=Europe/London`. O CI Linux é a autoridade.
- R10: Rubocop só nos arquivos tocados (o `--parallel` completo abriu 11 processos de 3,5 GB e 36 GB de
  swap; o CI desta PR não roda Rubocop).
- R11: `pnpm lint:md` só nos .md tocados (base vermelha).
- Warning do Ruby 3.4 "benchmark was loaded from the standard library" via delayed_job (a gem `benchmark`
  saiu do lock): **decisão do usuário na PR** (adicionar `gem 'benchmark'` foge da allowlist).
- Preview de PR é automático e externo ao repo; se não subir, bloqueia a release (D10).

## Próximos passos
1. `/newbyte:newbyte` → Desenvolvimento → task NDESK-45 → Handoff (skill `handoff`, modo retomar):
   validar no Plane (task In Progress + etiqueta Execution; NDESK-47 In Progress) e entrar em `dev-execution`
   no passo 1 (execução do plano), retomando o SDD pelo ledger.
2. SDD: gerar `review-package PLAN 61424b1faa HEAD` (scripts em
   `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/subagent-driven-development/scripts/`)
   e despachar o revisor da Task 3 com `task-3-brief.md` + `task-3-report.md`; tratar achados em rounds;
   ⚠️ conferir em especial a correção de `spec/support/db_migration.rb`.
3. SDD: revisão final de toda a branch (`review-package PLAN 43e237b860 HEAD`, modelo mais capaz), uma
   onda de correção + uma re-revisão; triagem dos minors deferidos do ledger.
4. `dev-execution` passo 2: review de código em agente separado com modelo OpenAI (`nb-review`) sobre
   `43e237b860..HEAD` contra o plano; discutir achados com o usuário. Passo 3 (teste visual) não se aplica
   à mudança; registrar.
5. Pedir autorização explícita para push + PR. Com ela: `git fetch origin` e conferir
   `git log HEAD..origin/newbyte-stable` vazio; `git push -u origin chore/rails-8.1-upgrade`;
   `gh pr create -R newbytesolucoesdigitais/ndesk --base newbyte-stable` com corpo no formato de
   `references/pr-template.md` da skill dev-execution, preenchido a partir de `artifacts/pr-body.md`
   (critérios de aceite = os 5 do briefing no Plane, um por linha).
6. Republicar spec + plano no sub-item Planning (NDESK-46, id `3713ddea-a4d3-4532-b92a-38f666523f27`):
   os hashes mudaram desde o Planning. Usar `artifacts/publish_plane.sh Execution DD/MM/AAAA` +
   `artifacts/readback.py` (antes, ajustar a variável `S=` dos três scripts para o scratchpad da nova
   sessão ou para `artifacts/`). Read-back obrigatório.
7. Sub-item Execution (NDESK-47, id `ef3de758-e324-4198-ba41-f4ed040826e6`) → Done; task principal
   (id `79382136-7d27-4944-8e70-7f2b2355d957`): labels `[QA]` (id `1ba2a547-541d-4186-9297-ecc637263486`)
   via `update_work_item` com o conjunto completo. Avisar que a PR está pronta para Review + QA.
8. Perguntar ao usuário sobre encerrar os processos do NChat na porta 3000 antes de rodar specs locais.

## Arquivos relevantes
- `docs/plans/2026-09-08-atualizar-rails-design.md` — spec v2.1 (autoridade).
- `docs/plans/2026-09-08-atualizar-rails.md` — plano v2 com correções R6–R9 (Tasks 4 e 5 = roteiro QA/Release).
- `.superpowers/sdd/2026-09-08-atualizar-rails/progress.md` — ledger SDD (rulings R1–R11, minors deferidos).
- `.superpowers/sdd/2026-09-08-atualizar-rails/task-{0,1,2,3}-report.md` — evidências de cada task.
- `.superpowers/sdd/2026-09-08-atualizar-rails/artifacts/` — `pr-body.md`, logs dos gates, scripts de
  publicação (`md2plane.py`, `publish_plane.sh`, `readback.py`), `lock.diff`, `internals-review.md`.
- `.claude/NEWBYTE_WORKFLOW.md` — regras de git/PR/tag do projeto (desatualizado em tag e deploy; o
  usuário decidiu não corrigir nesta task) e changelog.
- `.newbyte/qa/README.md` — convenção de QA e ressalvas abertas do QA da PR #25 (pré-condição da tag).

## Artefatos
- Spec: `docs/plans/2026-09-08-atualizar-rails-design.md`
- Plano: `docs/plans/2026-09-08-atualizar-rails.md`
- Publicação no Plane: publicado (fim do Planning); **republicação pendente no fim da Execution** (spec e
  plano mudaram depois; passo 6 acima).
- Branch: `chore/rails-8.1-upgrade`
- PR: não aberta
- Estado do git: branch só local (não pushada), 14 commits à frente de `newbyte-stable` @ `43e237b860`,
  sem mudanças não commitadas, sem stash. `.newbyte/` e `.superpowers/` não são rastreados.

## Pegadinhas / contexto que se perde
- O shell é zsh: `-t ~searchindex` sem aspas quebra e `PIPESTATUS` fica vazio; gates rodam em
  `bash -euo pipefail <<'GATE'`. O Bash tool tem limite de 10 min por comando: rodadas longas em
  background com arquivo `.status`.
- `db/schema.rb` deve permanecer ausente; não rodar `db:schema:dump`. Se aparecer, `rm -f db/schema.rb`.
- Porta 3000 ocupada pelo Puma do NChat (pid 60497, 23 dias) derruba `user_agent_spec` localmente.
- `diff` BSD do macOS muda o resultado de `signature_detection_spec`; no CI (GNU) passa.
- Nunca rodar `rubocop --parallel` completo nesta máquina (16 GB): 11 × 3,5 GB.
- `pnpm lint:md` da base inteira está vermelho (469 erros pré-existentes); julgar só os .md tocados.
- Scratchpad é por sessão: tudo que importa foi copiado para `.superpowers/sdd/.../artifacts/`; os
  scripts de publicação têm `S=` fixo do scratchpad antigo.
- MCP do Plane: `retrieve_work_item*` com `labels`/`assignees` não vazios em `fields` falha; usar
  `expand="labels"`. Nunca `manage_work_item_label`; labels sempre pelo conjunto completo.
- `firecrawl_agent` exige conta; usar `firecrawl_search`/WebFetch.
- Alias `nb-review` (GPT-5.6 Sol) está disponível no Agent tool para os reviews com modelo OpenAI.
- PR só com pedido explícito do usuário; push idem (workflow do projeto). Sem amend/rebase/force.
- Ressalvas do QA da PR #25 (fail-fast do deploy, `deploy@host:porta`, `scp` da #24) são pré-condição da
  próxima tag: fechar ou dispensa explícita do usuário (spec §4.6).
- O `benchmark` warning aparece em todo boot; decidir na PR se `gem 'benchmark'` entra.
- Reviewers apontaram minors não corrigidos (ledger): oráculos String OAuth com host externo (sem caso
  same-host), `allow_other_host: true` amplo, exemplos de config são detectores de mudança,
  `brakeman.ignore` editado à mão (cabeçalho 8.0.1), comentários em pt-BR em arquivos upstream.
