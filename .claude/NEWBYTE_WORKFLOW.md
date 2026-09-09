# NewByte NDesk - Workflow e Instrucoes para Sessoes Claude

## Branch e PR

- **Branch de producao**: `newbyte-stable` (NÃO é `main` nem `master`)
- Commit livre é permitido (liberado pelo CTO) — não é obrigatório passar por PR **por commit**
- **Mas SEMPRE na branch da feature — commit/push direto na `newbyte-stable` é PROIBIDO**
- **Push também é livre na branch da feature** — push NÃO abre PR; PR é sempre uma ação
  explícita e separada (confirmado pelo CTO em 2026-07-16)
- **A PR só deve ser aberta no final, quando o usuário pedir explicitamente**
- Criar branch com prefixo descritivo: `feat/`, `fix/`, `chore/`
- A PR (quando pedida) é aberta contra `newbyte-stable`
- Se o `gh pr create` falhar via GraphQL, usar a API REST:
  ```
  gh api repos/newbytesolucoesdigitais/ndesk/pulls \
    -f title="..." \
    -f head="newbytesolucoesdigitais:<branch>" \
    -f base="newbyte-stable" \
    -f body="..."
  ```

## Merge e Tags

- Toda merge em `newbyte-stable` DEVE ser acompanhada de uma tag
- Formato da tag: `nb.v{major}.{minor}` (ex: `nb.v1.3`)
- A tag mais recente ate esta sessao: `nb.v1.3`
- Fluxo de merge:
  ```bash
  # 1. Merge via API
  gh api repos/newbytesolucoesdigitais/ndesk/pulls/<PR_NUMBER>/merge \
    -X PUT -f merge_method=merge

  # 2. Fetch, criar tag no commit de merge e push
  git fetch origin newbyte-stable
  git tag nb.v<NEXT_VERSION> origin/newbyte-stable
  git push origin nb.v<NEXT_VERSION>
  ```
- Perguntar ao usuario qual sera a proxima versao da tag antes de criar

## Deploy (Coolify)

- O deploy e trigado automaticamente por push na branch configurada no Coolify
- Se o webhook nao disparar, fazer um commit vazio para re-triggar:
  ```bash
  git commit --allow-empty -m "chore: trigger deploy" && git push
  ```
- O build roda `assets:precompile` (Sprockets) - erros de CSS/CoffeeScript quebram o deploy

## Arquivos que NAO devem entrar na PR

Estes arquivos existem no workspace mas nao devem ser commitados:

- `.devcontainer/default/devcontainer-lock.json` - arquivo gerado pelo devcontainer
- `design-system-web.md` - documento de referencia de design, nao e codigo
- `logoblue.svg` - SVG fonte usado como referencia, ja incorporado no `icons.svg`
- Qualquer arquivo `.env`, credenciais ou secrets
- Arquivos temporarios ou de debug

## Restricoes de Git

- **NUNCA** fazer operacoes destrutivas (pull, reset --hard, push --force, checkout --) sem aprovacao explicita do usuario
- **NUNCA** commitar ou fazer push direto na `newbyte-stable` — trabalho sempre na branch da feature
- Preferir commits novos a amend

## Frontend — SOMENTE o app legacy

- **Todo trabalho de UI é no app legacy** (`app/assets/javascripts` e `app/assets/stylesheets`) — CoffeeScript/Spine.js, servido na raiz `/`.
- **NUNCA trabalhar nos apps Vue** (`app/frontend/apps/desktop` e `app/frontend/apps/mobile`). Eles são código oficial do upstream Zammad (a migração do desktop pra Vue, servida em `/desktop` e `/mobile`) e o NDesk **não** os usa nem customiza.
- Ignorar as mencoes aos apps Vue no `AGENTS.md` / CLAUDE.md — sao boilerplate herdado do upstream.

## Compatibilidade de Browser

- Testar considerando Chrome, Firefox e Safari
- Safari nao suporta `audio/webm` - usar `audio/mp4` como fallback
- Safari nao resolve `url(#id)` dentro de `<symbol>/<use>` no SVG (shadow DOM) - usar `fill` inline direto, sem `clipPath`, `<style>`, ou `linearGradient` dentro de symbols
- Firefox retorna `duration = Infinity` para blobs WebM - usar `isFinite()` guard

## Servidor de Desenvolvimento

- Para rodar local: verificar se o `Procfile.dev` esta configurado
- O CSS usa variaveis customizadas com `:root` (light) e `[data-theme='dark']` (dark)
- O mixin `@include dark { }` aplica estilos so no dark mode

---

## Changelog

> **Instrucao para sessoes futuras**: Ao finalizar uma sessao com alteracoes de codigo,
> adicionar uma entrada abaixo com a data, resumo das mudancas e branch/PR/tag.
> Isso mantem um historico legivel do que foi feito no projeto.

### 2026-05-27 - PR #16 (tag nb.v1.3)

**Branch**: `feat/audio-firefox-fix`

Alteracoes:
- **Fix Firefox audio**: Player de preview mostrava `0:00 / Infinity:NaN` porque blobs WebM retornam `duration = Infinity`. Adicionado guard `isFinite()` com fallback para duracao gravada.
- **Fix Safari audio**: Safari nao suporta `audio/webm`. Adicionado `audio/mp4` na cadeia de deteccao do `MediaRecorder`, com extensao `.m4a` no upload.
- **Fix Safari SVG**: Logos usavam `clipPath`, `<style>` e `linearGradient` dentro de `<symbol>` que nao funcionam no Safari via `<use>`. Substituidas por paths simples com `fill` inline.
- **Compose sticky**: Barra de composicao flutua no fundo da tela ao scrollar pra cima, com efeito frosted glass (`backdrop-filter: blur`).
- **Toggle minimize**: Botao para ocultar/mostrar compose. Bloqueado quando perto do fundo (200px). Auto-reopen ao scrollar de volta ao fundo. Fallback de reopen apos colapsar se ficou no fundo.
- **Sidebar clara (light mode)**: Menu lateral com tons claros no tema branco, dark mode inalterado com override explicito das variaveis `--menu-*`.
- **Logo azul (light mode)**: Logo New Byte azul (`#0077FF`) no light mode, branca no dark mode. Toggle via CSS `display` + `@include dark`.

Arquivos modificados:
- `app/assets/javascripts/app/controllers/article_view/item.coffee`
- `app/assets/javascripts/app/controllers/ticket_zoom/article_new.coffee`
- `app/assets/javascripts/app/views/navigation.jst.eco`
- `app/assets/javascripts/app/views/ticket_zoom/article_new.jst.eco`
- `app/assets/stylesheets/zammad.scss`
- `public/assets/images/icons.svg`

### 2026-07-06 - PR #<n> (tag nb.v<x>)

**Branch**: `feat/csat-two-scores`

Alteracoes:
- **CSAT em duas dimensões**: nota única vira Nota de Atendimento (`score` renomeado
  para `score_service`, ADR 0003) + nova Nota de Resolução (`score_resolution`, NULL
  nas avaliações antigas). Popup com duas fileiras de estrelas (resolução primeiro),
  ambas obrigatórias. POST/surveys/stats/embed do ticket expõem o par; stats com
  bloco por dimensão (médias ignoram NULL; `count_resolution` por atendente).
  Sem alias para o param antigo `score`.

### 2026-07-17 - branch feat/ticket-grouping

**Branch**: `feat/ticket-grouping`

Alteracoes:
- **Coleções de abas na taskbar**: o atendente organiza as Abas da taskbar (sidebar
  esquerda da UI clássica) em Coleções nomeadas via drag & drop, persistidas em
  `user.preferences` (`taskbar_collections`). Zero backend novo — save por
  `PUT /api/v1/users/preferences` (merge por chave), ordem via `prio` da taskbar.
  - **Módulo `App.TaskbarCollections`** (`lib/app_post/taskbar_collections.coffee`):
    dono único do documento (id/nome/collapsed/keys), filiação única de cada Aba,
    persistência debounced (nível `task`, cancelada no logout), reconciliação de keys
    órfãs (guard contra `reconcile(undefined)`), nome padrão traduzido ("Coleção N").
  - **Auto-limpeza**: `TaskManager.tasksAutoCleanup` pula Abas que estão em Coleção.
  - **Widget em dois níveis** (`controllers/taskbar_widget.coffee`): Abas soltas na
    raiz + container por Coleção (cabeçalho, contador, membros); recolher/expandir;
    auto-expand ao ativar membro (só em transição real de ativação).
  - **Menu ⋯**: renomear inline (Enter/Esc/blur), desfazer Coleção, fechar todas
    (modal única quando há rascunho não salvo).
  - **Drag & drop** (jQuery UI sortable em dois níveis): miolo (~60%) cria/adiciona à
    Coleção, bordas reordenam; cabeçalho recolhido expande no drop; guard contra
    aninhamento ilegal de Coleção; ordem achatada em `TaskManager.reorder`.
    `tolerance: 'intersect'` (não `'pointer'`): sem isso o rearrange do sortable
    disparava na borda e o alvo "fugia" do ponteiro antes do miolo — o gesto de criar
    grupo virava reordenação (corrigido no QA da PR).
  - **F5/relogin (item 7 do QA)**: Coleções, nomes, ordem e recolhimento sobrevivem;
    a Aba restaurada como ativa não reabre Coleção recolhida (bootActiveKeys) e o
    render em dois níveis não sai achatado no boot.
  - **Estilos** (`zammad.scss`, variáveis `--menu-*`, light/dark) e **i18n pt-BR**.
  - Docs de domínio: `docs/taskbar/CONTEXT.md`, ADR `docs/taskbar/adr/0001-*`,
    spec e plano em `docs/superpowers/`.

Arquivos modificados:
- `app/assets/javascripts/app/lib/app_post/taskbar_collections.coffee` (novo)
- `app/assets/javascripts/app/views/widget/task_collection.jst.eco` (novo)
- `app/assets/javascripts/app/controllers/taskbar_widget.coffee`
- `app/assets/javascripts/app/lib/app_post/task_manager/singleton.coffee`
- `app/assets/stylesheets/zammad.scss`
- `i18n/zammad.pt-br.po`
- `public/assets/tests/qunit/taskbar_collections.js` (novo)

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
- **`dump_schema_after_migration = false`** em `config/environments/test.rb` e `development.rb`: o
  dumper de schema do Rails 8.1 passou a ordenar as colunas em ordem alfabetica; como o `db:migrate`
  do `zammad:db:reset` carrega o `db/schema.rb` quando ele existe, em vez de rodar as migrations, o
  banco de teste ficava com `column_names` fora da ordem de criacao. Com o dump desligado nesses dois
  ambientes, o banco de teste passa a ser construido por migrations e o `db/schema.rb` continua ausente
  e gitignored.
- **Specs de migration instanciam a classe viva** (`spec/support/db_migration.rb`): sem `db/schema.rb`
  o `zammad:db:reset` do `before(:suite)` roda as migrations dentro do processo do RSpec e o
  `MigrationProxy` troca cada classe, deixando o `described_class` do arquivo de spec obsoleto.
- **Warning novo do `benchmark` no boot**: a `activesupport` 8.1 deixou de depender de `benchmark`
  (por isso a gem saiu do lock, bullet acima), mas `delayed_job` continua fazendo `require 'benchmark'`.
  Com Ruby 3.4 isso imprime, em todo boot (RSpec, Minitest e o worker do `delayed_job` em producao), o
  aviso de que `benchmark` deixara de ser gem padrao a partir do Ruby 4.0.0. Decisao pendente com o
  usuario no momento da PR: adicionar `gem 'benchmark'` no `Gemfile` (reabre a allowlist) ou aceitar o
  warning por ora.
- Spec e plano: `docs/plans/2026-09-08-atualizar-rails-design.md`, `docs/plans/2026-09-08-atualizar-rails.md`.

Arquivos modificados:

- Config: `Gemfile`, `Gemfile.lock`, `config/application.rb`, `config/brakeman.ignore`,
  `config/environments/development.rb`, `config/environments/test.rb`,
  `config/initializers/active_record_lock_issue_3664.rb`
- App: `app/controllers/external_credentials_controller.rb`
- Specs novos: `spec/config/framework_defaults_spec.rb`,
  `spec/controllers/framework_defaults_redirect_spec.rb`, `spec/lib/sessions/store_roundtrip_spec.rb`,
  `spec/requests/framework_defaults_json_spec.rb`, `spec/requests/framework_query_string_spec.rb`
- Specs modificados: `spec/lib/active_record/locking/pessimistic_spec.rb`,
  `spec/models/ticket/satisfaction_rating_spec.rb`, `spec/requests/external_credentials_spec.rb`,
  `spec/requests/knowledge_base_public/custom_path_spec.rb`, `spec/support/db_migration.rb`
