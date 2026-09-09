# Handoff — NDESK-45 — [NDesk] Atualizar Rails

> Gerado em 2026-09-09 15:10. Consumido pelo fluxo Desenvolvimento → Handoff do
> plugin New Byte. Fonte da verdade sobre estado da task: o Plane.

## Task
- Identificador: NDESK-45
- Link: https://plane.byte.newbyte.net.br/engenharia/browse/NDESK-45/
- Projeto: NDesk

## Fase atual
QA — Execution concluída em 2026-09-09. PR #26 aberta
(https://github.com/newbytesolucoesdigitais/ndesk/pull/26, `chore/rails-8.1-upgrade` → `newbyte-stable`).
Retomar em: `/newbyte:newbyte` → Review + QA → NDESK-45 / PR #26 (skill `review-qa`), usando a Task 4 do
plano `docs/plans/2026-09-08-atualizar-rails.md` como roteiro; Release depois pela skill `release` (Task 5).

## O que já foi feito
- Plane: NDESK-46 (Planning) Done; NDESK-47 (Execution) Done; task principal In Progress com etiqueta **QA**;
  spec + plano republicados na descrição de NDESK-46 (fim da Execution, `nb-pub v1`, hashes
  `7b54e6a90c62` / `c54d540ef50f`, read-back OK).
- Branch `chore/rails-8.1-upgrade` pushada (base `newbyte-stable` @ `43e237b860`, tag `nb.v1.5.1`):
  - `639a77688c` chore(deps): Rails 8.0.4 → 8.1.3.1, Brakeman 8.0.6, guard de `lock!`, contratos de query string,
    `dump_schema_after_migration = false` em test; `1e6d9903a5` idem em development.
  - `e5b4fcc17b` chore(config): `config.load_defaults 8.1` com um oráculo por ajuste; `allow_other_host` real em
    `external_credentials_controller.rb:47` (+ `config/brakeman.ignore`).
  - `674b3185b7` fix(bump): `spec/support/db_migration.rb` usa a classe viva (sem `db/schema.rb`, o reset roda
    as 484 migrations dentro do RSpec e o `MigrationProxy` recarrega as classes).
  - `ca8f25a7f2` + `56ef8bc803` changelog em `.claude/NEWBYTE_WORKFLOW.md` (completo, lint-clean).
  - `1d90345ebe` / `848478816f` / `16af878582` correções da revisão final: comentários em inglês, helper
    `migration_class`, exemplo same-host do callback, título do yjit, instrução `rm -f db/schema.rb`, plano sem
    scratchpad de sessão.
  - `9e7c234c7e` fix(bump): `gem 'benchmark'` explícita (decisão do usuário; warning do delayed_job sumiu).
- Reviews: SDD Tasks 0–3 aprovadas (Task 3 após 1 fix round); revisão final da branch (Claude, modelo mais capaz)
  e review OpenAI (GPT-5.6 Sol) sem defeito de código; achados de documentação corrigidos e re-revisados.
- Gates locais (macOS): boot `8.1.3.1 8.1` sem warnings; `zeitwerk:check` OK; Brakeman 8.0.6 exit 0, 0 warnings;
  `assets:precompile` OK; RSpec shards 1–4 `13231 ex / 31 falhas` em 4 arquivos de ambiente (abaixo); shard 5
  `358/0`; Minitest `166/0`; specs do bump `953/0`; Rubocop limpo nos arquivos tocados; markdownlint sem erro
  novo. `user_agent_spec` confirmado `49/0` com a porta 3000 livre.
- GitHub: a ruleset "Restrict branch management" do ndesk tinha como único bypass um time apagado; com
  autorização do usuário, o bypass passou ao time `engenharia` (regras inalteradas).

## Decisões tomadas (e por quê)
- Rails 8.1.3.1 (não 8.0.5): suporte é por série; Brakeman 8.0.6 junto; `load_defaults 8.1` na mesma entrega.
- `gem 'benchmark'` adicionada (2026-09-09): `delayed_job` e `lib/background_services/service/base_delayed_jobs.rb`
  usam `Benchmark` sem `require`; sai das default gems no Ruby 4.0. Amplia a allowlist da spec §4.1 por uma linha.
- `dump_schema_after_migration = false` em test/development: o dumper do 8.1 ordena colunas alfabeticamente e o
  `db:migrate` num banco vazio carrega o dump; banco de teste por migrations. **`rm -f db/schema.rb` após checkout.**
- Falhas locais de ambiente (CI decide): `user_agent_spec` (porta 3000, já confirmado), `signature_detection_spec`
  (BSD diff), `hardware_spec` (lshw), `translation/search_spec.rb:47` (estado do banco; a mais fraca).
- Exceções registradas, sem correção (rewrite proibido): `commit --amend` de `9839438d2f` em 2026-09-08 18:11
  (docs do plano, antes da regra e do push); trailers em blocos separados em 6 commits `docs(*)` antigos.
- Handoff é rastreado no git de propósito (viaja para quem pegar o QA); `.newbyte/qa/` não é.

## Próximos passos
1. QA (skill `review-qa`): CI da PR #26 (`ci-test.yml`, 12 jobs) — Security Scan com exit 0 e sem EOLRails;
   conferir nos shards de RSpec os 4 arquivos de ambiente acima e o tempo do shard 5 (484 migrations por processo).
2. Preview `ndesk-pr-26.staging-preview.newbyte.net.br` — smoke da seção "Como testar" da PR: login/logout e
   redirect pós-login; ticket com `<>&"'` e U+2028/U+2029 (zoom, overview, busca/Elasticsearch); taskbar; KB
   pública; callback OAuth Microsoft se houver provider; `RubyVM::YJIT.enabled?` no container; log do worker
   do delayed_job sem warnings.
3. Ressalvas abertas do QA da PR #25 (`.newbyte/qa/README.md`: fail-fast do deploy, `deploy@host:porta`, `scp` da
   #24) são pré-condição da próxima tag (spec §4.6): fechar ou dispensa explícita do usuário.
4. Release (skill `release`, Task 5 do plano): merge sem squash + tag `nb.v…` conforme `.claude/NEWBYTE_WORKFLOW.md`.

## Arquivos relevantes
- `docs/plans/2026-09-08-atualizar-rails-design.md` — spec v2.1 (autoridade).
- `docs/plans/2026-09-08-atualizar-rails.md` — plano (Tasks 4 e 5 = roteiro QA/Release).
- `.claude/NEWBYTE_WORKFLOW.md` — regras de git/PR/tag e a entrada de changelog de 2026-09-08.
- `.newbyte/qa/README.md` — convenção de QA e ressalvas abertas da PR #25.
- Corpo da PR #26 — autossuficiente: tabela do lock, sete ajustes com teste, gates, falhas de ambiente, roteiro
  de teste; `lock.diff` e `lock_update.sh` anexados em comentário na PR.

## Artefatos
- Spec: `docs/plans/2026-09-08-atualizar-rails-design.md`
- Plano: `docs/plans/2026-09-08-atualizar-rails.md`
- Publicação no Plane: publicado (fim da Execution)
- Branch: `chore/rails-8.1-upgrade` (pushada, tracking `origin/chore/rails-8.1-upgrade`)
- PR: https://github.com/newbytesolucoesdigitais/ndesk/pull/26
- Estado do git: tudo pushado; sem mudanças locais nem stash. O workspace local `.superpowers/sdd/…` (ledger,
  relatórios e logs dos gates, não versionado) foi apagado ao fim da Execution, como manda o SDD; as evidências
  estão resumidas na PR.

## Pegadinhas / contexto que se perde
- `db/schema.rb` deve permanecer ausente: `rm -f db/schema.rb` após checkout e nunca `db:schema:dump`
  (`zammad:bootstrap:reset` grava um vazio, inofensivo).
- Gates locais em `bash -euo pipefail <<'GATE'` (zsh quebra `~tag` sem aspas e `PIPESTATUS`); RSpec com
  `--tag '~searchindex' --tag '~integration' --tag '~required_envs'`; nunca `rubocop --parallel` nesta máquina
  (16 GB); `pnpm lint:md` da base já é vermelho (469 erros pré-existentes) — julgar só os `.md` tocados.
- Porta 3000 ocupada por outro Puma derruba `user_agent_spec`; `diff` BSD muda `signature_detection_spec`.
- Plane MCP: `retrieve_work_item*` com `labels`/`assignees` em `fields` exige `expand`; labels sempre pelo
  conjunto completo via `update_work_item`; nunca `manage_work_item_label`; PQL `childOf` devolve o projeto inteiro.
- Alias `nb-review` no Agent tool: usar `subagent_type: Plan` (o `general-purpose` falha por schema da tool Artifact).
- `gh` sem `-R` aponta para `zammad/zammad`; sempre `-R newbytesolucoesdigitais/ndesk`.
- Push em branch nova só funciona para membros do time `engenharia` (bypass da ruleset).
- Nunca `rebase`/`amend`/`force`; correções viram commits `(bump)`/`(defaults)`; trailers num único bloco.
