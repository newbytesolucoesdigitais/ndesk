# CSAT (Customer Satisfaction) — Design / Spec

- **Date:** 2026-06-09
- **Status:** Draft — pending final review · *fact-checked via workflow `csat-spec-verify` (6 agentes, 2026-06-09): claim crítico de tempo real **confirmado**; correções aplicadas (componente de estrelas inexistente, store de config, registro de nav dos settings, gate de permissão via controller policy).*
- **Target branch:** `feat/csat` → PR contra `newbyte-stable` (ver `.claude/NEWBYTE_WORKFLOW.md`)
- **Context base:** NDesk (fork do Zammad). Mapeamento de infraestrutura feito via workflow `csat-infra-map` — confirmado que o repo **não tem nenhum código de CSAT hoje** (o único "rating" é o thumbs-up/down booleano de IA em `app/models/ai/analytics/usage.rb`; o `satisfaction_rating` importado do Zendesk é parseado e descartado).

---

## 1. Objetivo

Permitir que o **cliente avalie o atendimento (1–5 estrelas + comentário opcional)** através de um **popup que abre dentro do próprio ticket** assim que ele é finalizado. As avaliações são armazenadas, exibidas para admin/manager dentro do app, e **puxáveis via API REST por sistemas externos** — inclusive **métricas por atendente**.

## 2. Decisões travadas

| Tema | Decisão |
|---|---|
| Escala | **1–5 estrelas**, inteiro. Tipo de escala reservado atrás de Setting (v1 só 1–5). |
| Comentário | **Opcional** (configurável: off / optional / required). |
| Quem avalia | **O cliente**, no popup da visão dele do ticket. |
| Gatilho | Ticket **finalizado** (`state_type = closed`, configurável). |
| Entrega | **Popup in-app apenas.** Sem e-mail, sem página externa, sem token público / magic-link. |
| Unicidade | **Write-once**: 1 avaliação por `[ticket, customer]`. |
| Atribuição | Snapshot do **último atendente atribuído** no momento do registro; **imutável** depois. |
| Visibilidade | **Admin/manager apenas** (in-app + API). |
| API | **REST** + bearer token; raw `/surveys` + agregados `/stats` (com quebra por atendente). |
| Frontend | **Vue desktop** (cliente e agente usam o mesmo app, com render condicional por papel). Mobile = fast-follow. |

## 3. Fora de escopo no v1 (YAGNI / dívida registrada)

E-mail-isca · página de pesquisa externa · magic-link/token público · NPS ou escala realmente configurável (setting reservado, mas v1 calcula média 1–5) · avaliação por artigo/agente (1 por ticket) · backfill do `satisfaction_rating` do Zendesk (hoje descartado na importação) · widget de dashboard em tempo real · **mobile** (espelhar depois) · tela de admin **custom** (o form vem de graça pela tela genérica; só falta um pequeno registro de nav — ver §11).

---

## 4. Arquitetura ponta-a-ponta

```
Agente finaliza o ticket (state -> closed)
        │  (subscription de ticket que já existe empurra a mudança)
        ▼
Visão do cliente (Vue desktop) reavalia ticket.satisfactionRatable
        │  true  =  current_user é o customer  &&  state closed  &&  sem rating
        ▼
Popup abre (ao vivo, ou no próximo open do ticket finalizado)
        │  cliente escolhe 1–5 estrelas (+ comentário opcional)
        ▼
mutation ticketSatisfactionRatingCreate(ticketId, score, comment)
        │  cria Ticket::SatisfactionRating, snapshot do agente (imutável)
        ▼
ChecksClientNotification empurra a atualização
   ├─► Admin/manager veem o resultado no ticket (campo gated por csat.read)
   └─► API REST externa: GET /api/v1/csat/surveys e /api/v1/csat/stats
```

Princípio central: como cliente e agente usam **o mesmo app Vue** (`TicketDetailViewContent.vue` decide `view: isTicketAgent ? 'agent' : 'customer'`) e o cliente já está **autenticado**, a avaliação é só uma **mutation autenticada** — sem token público, sem usuário inativo, sem página externa.

---

## 5. Modelo de dados — `Ticket::SatisfactionRating`

Espelha a convenção mais recente do repo: `app/models/recent_close.rb` + migration `db/migrate/20251106095318_create_recent_closes.rb`.

### Migration (sketch)
```ruby
create_table :ticket_satisfaction_ratings, id: :integer do |t|
  t.references :ticket,   null: false, type: :integer, foreign_key: { to_table: :tickets }
  t.references :customer, null: false, type: :integer, foreign_key: { to_table: :users }
  t.references :agent,    null: true,  type: :integer, foreign_key: { to_table: :users } # snapshot, imutável
  t.references :group,    null: true,  type: :integer, foreign_key: { to_table: :groups } # desnormalizado
  t.integer :score, null: false            # 1..5
  t.text    :comment
  t.timestamps limit: 3
end
add_index :ticket_satisfaction_ratings, %i[ticket_id customer_id], unique: true
add_index :ticket_satisfaction_ratings, %i[agent_id created_at]    # agregação por atendente / período
```

### Modelo
```ruby
class Ticket::SatisfactionRating < ApplicationModel
  include ChecksClientNotification
  include HasDefaultModelUserRelations   # created_by/updated_by

  belongs_to :ticket
  belongs_to :customer, class_name: 'User'
  belongs_to :agent,    class_name: 'User', optional: true
  belongs_to :group, optional: true

  validates :score, presence: true, inclusion: { in: 1..5 }
  validates :ticket_id, uniqueness: { scope: :customer_id }

  # imutabilidade pós-registro
  attr_readonly :ticket_id, :customer_id, :agent_id, :score

  before_create :snapshot_agent_and_group   # último atendente + grupo (§6); delega lógica como Ticket::TimeAccounting
end
```

**Notas de design**
- **Sem coluna `status`:** a linha existe ⇔ avaliado. "Precisa avaliar" é derivado (`closed` + é o customer + sem rating). Mais simples; *taxa de resposta* = avaliados ÷ fechados elegíveis.
- `attr_readonly` garante o "depois de registrado não muda" para `agent_id`/`score`/refs. **Nota (verificado):** é um método válido do Rails 7.2, porém **não usado em nenhum modelo do repo hoje** — o próprio `RecentClose` consegue imutabilidade via upsert/`find_or_initialize_by`. Estamos introduzindo o padrão conscientemente por ser a forma mais limpa de write-once aqui.
- Namespace `Ticket::` (tabela `ticket_satisfaction_ratings`) segue o padrão de submodelos de ticket do repo.

## 6. Regra de atribuição ao atendente

No momento do `create`:
1. `agent_id := ticket.owner_id` se for um **agente real** (não o usuário-sistema "—", id 1).
2. **Fallback:** se o ticket estiver sem dono no registro, pega o **último dono humano do histórico** (`History` do ticket, eventos de mudança de `owner_id`).
3. Grava em `agent_id` e **nunca atualiza** (`attr_readonly`). Reatribuir o ticket depois não altera avaliações já registradas.

> Implementação: hook `before_create :snapshot_agent_and_group` (espelha a delegação de lógica do `Ticket::TimeAccounting`). O fallback consulta o `History` do ticket pelos eventos de mudança de `owner_id`. "Sem dono" = `owner_id = 1` (usuário-sistema "—", padrão de ticket não atribuído).

`group_id` é desnormalizado da mesma forma (snapshot do grupo do ticket no registro) para filtro/pivô rápido.

---

## 7. GraphQL (app interno)

### Campos em `Gql::Types::TicketType` (`app/graphql/gql/types/ticket_type.rb`)
- `satisfaction: SatisfactionRatingType` — `{ score, comment, agent { ... }, createdAt }`.
  **Auth de campo (verificado):** resolver inline que retorna `nil` quando não autorizado (padrão em `ticket_type.rb:126-130`), ou `FieldScope` via `TicketPolicy` (`app/policies/application_policy/field_scope.rb`). Regra: admin/manager (`csat.read`) vê tudo; o **próprio cliente** vê só a dele; demais → `null`.
- `satisfactionRatable: Boolean!` — `true` quando `current_user == ticket.customer && state closed (por csat_closed_state_types) && sem rating`. Sinal que o front usa pra abrir o popup.

### Mutation
- `ticketSatisfactionRatingCreate(input: { ticketId: ID!, score: Int!, comment: String })` → `{ rating, errors }`.
- **Autorização:** `current_user == ticket.customer`, ticket finalizado, sem avaliação existente, `csat_integration` ligado. Valida `score` 1..5 e (se `csat_comment = required`) comentário presente.
- **Padrão a espelhar (verificado):** `app/graphql/gql/mutations/ticket/create.rb` (`requires_permission 'ticket.customer'`, input type em `gql/types/input/`, `errors` auto-incluído via `BaseMutation`). Policy `Ticket::SatisfactionRatingPolicy` espelhando `app/policies/ticket/time_accounting_policy.rb`.

### Tempo real
- **Reaproveita a subscription `ticketUpdates`** (`app/graphql/gql/subscriptions/ticket_updates.rb`; front `shared/entities/ticket/graphql/subscriptions/ticketUpdates.api.ts`). **Verificado** que o **cliente** também recebe: a subscription não tem auth própria; usa `TicketType` → `HasPunditAuthorization` → `TicketPolicy.show?` → `customer_access?` (`app/policies/ticket_policy.rb:83-104`). Logo a mudança de `state` chega à visão do cliente sem polling → o front reavalia `satisfactionRatable`. **Sem subscription nova.**
- `ChecksClientNotification` no modelo propaga o novo rating para os clientes admin abertos no ticket. (Escopar `client_notification_send_to` para não vazar/ruído — ver riscos.)

## 8. Popup (Vue desktop — visão do cliente)

```
┌─────────────────────────────────────────┐
│  Como foi seu atendimento?            ✕  │
│  Chamado #45213 · Resolvido              │
│                                          │
│        ☆   ☆   ☆   ☆   ☆                │
│       1    2    3    4    5              │
│                                          │
│  Quer deixar um comentário? (opcional)   │
│  ┌────────────────────────────────────┐ │
│  └────────────────────────────────────┘ │
│            [ Agora não ]   [ Enviar ]    │
└─────────────────────────────────────────┘
```

- **Composable** observa `ticket.state` + `ticket.satisfactionRatable`. Abre o modal quando o ticket **vira closed ao vivo**, ou **no mount** se já está fechado e `satisfactionRatable`.
- Componente próprio `TicketSatisfactionDialog.vue` via os primitivos de dialog existentes (`useDialog` / `CommonDialog` em `shared/components`).
- **Atenção (verificado):** **não existe** componente de estrelas em `shared/components/Form/fields/` (27 fields, nenhum de rating) → o seletor de estrelas **precisa ser construído** (componente custom ou novo field FormKit `FieldRating`).
- **Renderização só-cliente:** `v-if="!isTicketAgent"` em `TicketDetailViewContent.vue`, ou um sidebar plugin com `views: ['customer']` (`TicketSidebar/plugins/types.ts`).
- **Ler settings no front (verificado):** via `useApplicationStore().config['csat_integration'|'csat_comment']` (também exposto como global `$c`), populado pela query `applicationConfig` que filtra `Setting.where(frontend: true)`. *(Não existe `useApplicationConfigStore`/`useProductConfig` — nomes corrigidos.)*
- **"Agora não"** fecha o modal; um botão discreto **"Avaliar atendimento"** permanece no topo do ticket pra avaliar depois (sem martelar).
- Pós-envio: estado "Obrigado!"; `satisfactionRatable` vira `false`, não reabre.
- Renderização condicional por papel via o `view`/`isTicketAgent` já existente em `TicketDetailViewContent.vue`.

## 9. Exibição para agente/admin

- O mesmo campo `Ticket.satisfaction` renderizado num painel no ticket (sidebar/topbar do desktop Vue), **gated por `csat.read`**. Agente comum não vê.
- v1 = desktop. Mobile = fast-follow (mesmo campo GraphQL, componente espelhado).

---

## 10. API REST externa

Espelha `app/controllers/tickets_controller.rb` + `app/controllers/concerns/can_paginate.rb`.

### `GET /api/v1/csat/surveys`
Registros crus, paginado. Filtros: `?date_from`, `?date_to`, `?group_id`, `?agent_id`, `?score`.

### `GET /api/v1/csat/stats`
Agregados, **com quebra por atendente por padrão** + total geral. Aceita `?agent_id` (um atendente), `?group_id`, `?date_from`, `?date_to`.
```json
{
  "overall": { "count": 320, "average": 4.31, "response_rate": 0.58,
               "distribution": {"1":8,"2":12,"3":40,"4":110,"5":150} },
  "by_agent": [
    { "agent_id": 42, "agent": "Ana Souza", "count": 87, "average": 4.62, "distribution": {…} },
    { "agent_id": 17, "agent": "João Lima", "count": 64, "average": 3.98, "distribution": {…} }
  ]
}
```

### Auth
Bearer token autentica via `Token.check(action: 'api', ...)`; a **permissão é exigida no controller policy** (`Controllers::CsatControllerPolicy` com `permit! :action, to: 'csat.read'`) — **não** nos parâmetros do `Token.check` (verificado: `application_controller/authorizes.rb` → policy → `permit!` → `user.permissions!`). Como a visibilidade é admin-only, **sem group-scoping**.

---

## 11. Settings

Semeados em `db/seeds/settings.rb` (padrão `Setting.create_if_not_exists`, lidos via `Setting.get`; `frontend: true` expõe ao Vue). O **formulário** de edição é renderizado **automaticamente** pela tela genérica (`_settings/area.coffee` + `_settings/area_item.coffee`) a partir do `options.form` — **sem CoffeeScript de form**. **Porém (verificado):** a `area` precisa ser **registrada num nav** `_manage/*.coffee` para aparecer no menu (ex.: um pequeno `_manage/satisfaction.coffee` apontando para `area: 'CSAT::Settings'`). Ou seja: form de graça; **registro de nav é um detalhe pequeno**, não uma tela custom.

| Setting | Tipo / default | Função | `frontend` |
|---|---|---|---|
| `csat_integration` | boolean / `true` | Liga/desliga a feature sem deploy. | sim |
| `csat_comment` | select `off/optional/required` / `optional` | Mostra/obriga o comentário. | sim |
| `csat_closed_state_types` | lista / `['closed']` | Quais estados disparam o popup. | (backend) |

Permissões: **`admin.csat`** para editar os settings; **`csat.read`** para a API externa e a exibição admin in-app.

## 12. Casos de borda (resolvidos)

- **"Finalizado"** = `state_type closed` (via `csat_closed_state_types`); `merged` não conta.
- **Só o `customer_id` real** avalia — não colegas da organização.
- **Reabriu / refechou:** já avaliado → não repergunta (write-once + índice único); ainda não avaliado → segue podendo.
- **Cliente sempre logado** → sem token, sem usuário inativo.
- **Ticket sem dono no registro** → fallback pro último dono do histórico (§6).

## 13. Riscos / pontos de atenção

- ✅ **Tempo real para o cliente — confirmado:** a subscription `ticketUpdates` autoriza o cliente via `TicketPolicy` (`ticket_policy.rb:83-104`); a mudança de `state` chega à visão do cliente. (Risco rebaixado.)
- **`ChecksClientNotification` broadcast scope:** por padrão notifica amplo; escopar `client_notification_send_to` para não gerar ruído/vazar existência de rating.
- **`response_rate` no `/stats`:** exige contar "fechados elegíveis" — definir a janela (por `created_at` do ticket? por data de fechamento?) na implementação do agregado.
- **Permissões:** criar `admin.csat` e `csat.read` em `db/seeds/permissions.rb` (`Permission.create_if_not_exists`). **Confirmar na implementação o mecanismo de atribuição a papéis** — a verificação não localizou onde Admin/Manager ganham a permissão (provavelmente seeds de Role / `permission_grant`).

## 14. Estratégia de testes

- **RSpec**
  - Modelo: faixa 1–5, unicidade `[ticket, customer]`, imutabilidade (`attr_readonly`), atribuição de `agent_id` (dono real, fallback histórico, sem-dono).
  - Policy: cria só o customer; lê só admin (`csat.read`).
  - Mutation: sucesso; duplicado; ticket não-fechado; não-autorizado; comentário obrigatório quando `csat_comment=required`; feature desligada.
  - Campo GraphQL: auth (admin vê tudo, customer só o seu, agente não vê).
  - Controllers REST: auth por token, paginação, filtros (`agent_id`, `group_id`, datas, score), matemática do `/stats` (média, distribuição, quebra por atendente).
  - Factory `ticket_satisfaction_rating`.
- **Vitest / Testing Library**
  - Popup: aparece em `closed + customer + ratable`; some pros outros papéis; "Enviar" chama a mutation; "Agora não" + botão persistente; estado "Obrigado!".

## 15. Quebra de trabalho (anchors para espelhar)

1. **Backend dados:** migration + `Ticket::SatisfactionRating` (espelhar `recent_close.rb`); permissões + settings (seeds).
2. **GraphQL:** `SatisfactionRatingType`, campos em `ticket_type.rb`, mutation `ticketSatisfactionRatingCreate` (auth via policy).
3. **Atribuição:** lógica de snapshot do agente (+ fallback `History`) no create.
4. **Popup Vue:** composable de gatilho + `TicketSatisfactionDialog.vue` + botão persistente (desktop).
5. **Exibição admin:** painel gated no ticket (desktop).
6. **API REST:** `csat/surveys` + `csat/stats` controllers (espelhar `tickets_controller.rb` + `CanPaginate`), policy `csat.read`.
7. **Testes** (RSpec + Vitest) em cada camada.

---

> Próximo passo após aprovação deste spec: gerar o **plano de implementação** detalhado (skill writing-plans).
