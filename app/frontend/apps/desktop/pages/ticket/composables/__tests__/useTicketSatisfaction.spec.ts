// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { effectScope, ref } from 'vue'

import { mockApplicationConfig } from '#tests/support/mock-applicationConfig.ts'
import { waitForNextTick } from '#tests/support/utils.ts'

import type { TicketById } from '#shared/entities/ticket/types.ts'

import {
  mockTicketSatisfactionRatingCreateMutation,
  waitForTicketSatisfactionRatingCreateMutationCalls,
} from '../../graphql/mutations/ticketSatisfactionRatingCreate.mocks.ts'
import { useTicketSatisfaction } from '../useTicketSatisfaction.ts'

// Capture the props handed to `open()` so we can assert the dialog is opened
// and exercise its `onSubmit` / `onDismiss` callbacks in isolation.
const openMock = vi.hoisted(() => vi.fn())

vi.mock('#desktop/components/CommonDialog/useDialog.ts', async (originalModule) => {
  const module =
    await originalModule<typeof import('#desktop/components/CommonDialog/useDialog.ts')>()

  return {
    ...module,
    useDialog: () => ({
      open: openMock,
    }),
  }
})

const TICKET_ID = 'gid://zammad/Ticket/42'

const createTicketRef = (satisfactionRatable: boolean, id = TICKET_ID) =>
  ref({ id, satisfactionRatable } as TicketById)

const runComposable = (ticket: ReturnType<typeof createTicketRef>, refetch = vi.fn()) => {
  const scope = effectScope()

  const api = scope.run(() => useTicketSatisfaction(ticket, refetch))!

  return { api, refetch, scope }
}

describe('useTicketSatisfaction', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('opens the dialog when the ticket is ratable and the integration is enabled', () => {
    mockApplicationConfig({ csat_integration: true })

    runComposable(createTicketRef(true))

    expect(openMock).toHaveBeenCalledOnce()
    expect(openMock).toHaveBeenCalledWith(
      expect.objectContaining({
        name: 'ticket-satisfaction',
        onSubmit: expect.any(Function),
        onDismiss: expect.any(Function),
      }),
    )
  })

  it('does not open the dialog when the CSAT integration is disabled', () => {
    mockApplicationConfig({ csat_integration: false })

    runComposable(createTicketRef(true))

    expect(openMock).not.toHaveBeenCalled()
  })

  it('does not open the dialog when the ticket is not ratable', () => {
    mockApplicationConfig({ csat_integration: true })

    runComposable(createTicketRef(false))

    expect(openMock).not.toHaveBeenCalled()
  })

  it('does not open the dialog when the survey was previously dismissed', () => {
    mockApplicationConfig({ csat_integration: true })
    localStorage.setItem(`csat-dismissed-${TICKET_ID}`, 'true')

    runComposable(createTicketRef(true))

    expect(openMock).not.toHaveBeenCalled()
  })

  it('persists the dismissal so the survey stays closed on the next visit', () => {
    mockApplicationConfig({ csat_integration: true })

    runComposable(createTicketRef(true))

    expect(openMock).toHaveBeenCalledOnce()

    // Simulate the dialog being dismissed (X / backdrop / Escape / cancel).
    const { onDismiss } = openMock.mock.calls[0][0]
    onDismiss()

    expect(localStorage.getItem(`csat-dismissed-${TICKET_ID}`)).toBe('true')

    // A subsequent visit must not re-open the survey.
    openMock.mockClear()
    runComposable(createTicketRef(true))

    expect(openMock).not.toHaveBeenCalled()
  })

  it('submits the rating mutation and refetches when the survey is submitted', async () => {
    mockApplicationConfig({ csat_integration: true })
    mockTicketSatisfactionRatingCreateMutation({
      ticketSatisfactionRatingCreate: {
        satisfactionRating: {
          score: 5,
          comment: 'Great support',
        },
        errors: null,
      },
    })

    const { refetch } = runComposable(createTicketRef(true))

    const { onSubmit } = openMock.mock.calls[0][0]
    await onSubmit({ score: 5, comment: 'Great support' })

    const calls = await waitForTicketSatisfactionRatingCreateMutationCalls()

    expect(calls.at(-1)?.variables).toEqual({
      input: {
        ticketId: TICKET_ID,
        score: 5,
        comment: 'Great support',
      },
    })

    await waitForNextTick()

    expect(refetch).toHaveBeenCalledOnce()
  })
})
