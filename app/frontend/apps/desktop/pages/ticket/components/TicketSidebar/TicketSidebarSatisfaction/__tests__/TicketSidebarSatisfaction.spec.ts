// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { computed } from 'vue'

import { renderComponent } from '#tests/support/components/index.ts'
import { mockRouterHooks } from '#tests/support/mock-vue-router.ts'

import type { TicketById } from '#shared/entities/ticket/types.ts'

import { TicketSidebarScreenType } from '../../../../types/sidebar.ts'
import satisfactionSidebarPlugin from '../../plugins/satisfaction.ts'
import TicketSidebarSatisfaction from '../TicketSidebarSatisfaction.vue'

mockRouterHooks()

const renderTicketSidebarSatisfaction = (ticket: Partial<TicketById>) => {
  return renderComponent(TicketSidebarSatisfaction, {
    props: {
      sidebar: 'satisfaction',
      sidebarPlugin: satisfactionSidebarPlugin,
      selected: true,
      context: {
        screenType: TicketSidebarScreenType.TicketDetailView,
        view: 'agent',
        formValues: {},
        ticket: computed(() => ticket as TicketById),
      },
    },
    router: true,
    global: {
      stubs: {
        teleport: true,
      },
    },
  })
}

describe('TicketSidebarSatisfaction.vue', () => {
  it('renders the rating score when satisfaction is present', () => {
    const wrapper = renderTicketSidebarSatisfaction({
      satisfactionRatable: true,
      satisfaction: {
        __typename: 'TicketSatisfactionRating',
        score: 4,
        createdAt: '2026-06-09T10:00:00Z',
      },
    })

    expect(wrapper.getByText('Rating: 4/5')).toBeInTheDocument()
  })

  it('renders the comment when present', () => {
    const wrapper = renderTicketSidebarSatisfaction({
      satisfactionRatable: true,
      satisfaction: {
        __typename: 'TicketSatisfactionRating',
        score: 5,
        comment: 'Great support!',
        createdAt: '2026-06-09T10:00:00Z',
      },
    })

    expect(wrapper.getByText('Rating: 5/5')).toBeInTheDocument()
    expect(wrapper.getByText('Great support!')).toBeInTheDocument()
  })

  it('shows "Not rated yet" when the ticket is ratable but has no rating', () => {
    const wrapper = renderTicketSidebarSatisfaction({
      satisfactionRatable: true,
      satisfaction: null,
    })

    expect(wrapper.getByText('Not rated yet')).toBeInTheDocument()
  })

  it('shows "No rating" when the ticket is not ratable and has no rating', () => {
    const wrapper = renderTicketSidebarSatisfaction({
      satisfactionRatable: false,
      satisfaction: null,
    })

    expect(wrapper.getByText('No rating')).toBeInTheDocument()
  })
})
