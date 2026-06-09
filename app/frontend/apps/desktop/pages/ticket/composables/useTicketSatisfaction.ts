// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { watch } from 'vue'

import type { TicketById } from '#shared/entities/ticket/types.ts'
import MutationHandler from '#shared/server/apollo/handler/MutationHandler.ts'
import { useApplicationStore } from '#shared/stores/application.ts'

import { useDialog } from '#desktop/components/CommonDialog/useDialog.ts'

import { useTicketSatisfactionRatingCreateMutation } from '../graphql/mutations/ticketSatisfactionRatingCreate.api.ts'

import type { Ref } from 'vue'

const DIALOG_NAME = 'ticket-satisfaction'

const dismissedKey = (ticketId: string) => `csat-dismissed-${ticketId}`

export const useTicketSatisfaction = (ticket: Ref<TicketById | undefined>, refetch: () => void) => {
  const { config } = useApplicationStore()

  const { open } = useDialog({
    name: DIALOG_NAME,
    global: true,
    refocus: false,
    component: () =>
      import('#desktop/pages/ticket/components/TicketDetailView/TicketSatisfaction/TicketSatisfactionDialog.vue'),
  })

  const createMutation = new MutationHandler(useTicketSatisfactionRatingCreateMutation())

  const openDialog = (ticketId: string) => {
    return open({
      name: DIALOG_NAME,
      onSubmit: async (data: { score: number; comment?: string }) => {
        await createMutation.send({
          input: {
            ticketId,
            score: data.score,
            comment: data.comment,
          },
        })

        refetch()
      },
      onDismiss: () => {
        localStorage.setItem(dismissedKey(ticketId), 'true')
      },
    })
  }

  watch(
    () => ticket.value?.satisfactionRatable,
    (ratable) => {
      if (!config.csat_integration || !ratable || !ticket.value) return

      if (localStorage.getItem(dismissedKey(ticket.value.id))) return

      openDialog(ticket.value.id)
    },
    { immediate: true },
  )

  return {
    openSatisfactionDialog: () => ticket.value && openDialog(ticket.value.id),
  }
}
