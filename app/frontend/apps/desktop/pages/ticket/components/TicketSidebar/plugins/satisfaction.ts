// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { useApplicationStore } from '#shared/stores/application.ts'

import { TicketSidebarScreenType } from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarSatisfaction from '../TicketSidebarSatisfaction/TicketSidebarSatisfaction.vue'

import type { TicketSidebarPlugin } from './types.ts'

export default <TicketSidebarPlugin>{
  title: __('Satisfaction'),
  component: TicketSidebarSatisfaction,
  permissions: ['csat.read'],
  screens: [TicketSidebarScreenType.TicketDetailView],
  views: ['agent'],
  icon: 'star',
  order: 700,
  available: () => {
    const { config } = useApplicationStore()

    return Boolean(config.csat_integration)
  },
}
