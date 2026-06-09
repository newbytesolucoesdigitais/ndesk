// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { getNode } from '@formkit/core'
import { waitFor } from '@testing-library/vue'

import { renderComponent } from '#tests/support/components/index.ts'
import { waitForNextTick } from '#tests/support/utils.ts'

import TicketSatisfactionDialog from '../TicketSatisfactionDialog.vue'

describe('TicketSatisfactionDialog', () => {
  it('renders the rating field and a submit button', async () => {
    const wrapper = renderComponent(TicketSatisfactionDialog, {
      props: {
        name: 'ticket-satisfaction',
      },
      form: true,
      dialog: true,
      router: true,
    })

    await waitForNextTick(true)

    expect(wrapper.getByText('How was your support?')).toBeInTheDocument()
    expect(wrapper.getByRole('button', { name: 'Submit' })).toBeInTheDocument()
  })

  it('delivers the submit payload to its opener', async () => {
    const onSubmit = vi.fn()

    const wrapper = renderComponent(TicketSatisfactionDialog, {
      props: {
        name: 'ticket-satisfaction',
        onSubmit,
      },
      form: true,
      dialog: true,
      router: true,
    })

    await waitForNextTick(true)

    // FormKit `input()` commits asynchronously; await it so the value is
    // settled before submitting, otherwise the assertion is flaky.
    await getNode('score')?.input(5)

    await wrapper.events.click(wrapper.getByRole('button', { name: 'Submit' }))

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({ score: 5, comment: undefined })
    })
  })
})
