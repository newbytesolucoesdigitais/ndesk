<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, markRaw } from 'vue'

import Form from '#shared/components/Form/Form.vue'
import type { FormSchemaNode } from '#shared/components/Form/types.ts'
import { useForm } from '#shared/components/Form/useForm.ts'
import { useApplicationStore } from '#shared/stores/application.ts'

import CommonDialog from '#desktop/components/CommonDialog/CommonDialog.vue'
import CommonDialogActionFooter from '#desktop/components/CommonDialog/CommonDialogActionFooter.vue'
import { closeDialog } from '#desktop/components/CommonDialog/useDialog.ts'

interface Props {
  name: string
  onSubmit?: (data: { score: number; comment?: string }) => void
  onDismiss?: () => void
}

const props = defineProps<Props>()

const { config } = useApplicationStore()

const commentMode = computed(() => (config.csat_comment as string) || 'optional')

const schema = markRaw([
  {
    isLayout: true,
    component: 'FormGroup',
    children: [
      {
        id: 'score',
        name: 'score',
        type: 'rating',
        label: __('How was your support?'),
        required: true,
      },
      ...(commentMode.value !== 'off'
        ? [
            {
              name: 'comment',
              type: 'textarea',
              label: __('Comment'),
              props: { rows: 4 },
              classes: { outer: 'text-left' },
              required: commentMode.value === 'required',
            },
          ]
        : []),
    ],
  },
] as FormSchemaNode[])

const { form, formNodeId } = useForm()

const dismissed = { value: false }

const close = (cancel?: boolean) => {
  if (cancel && !dismissed.value) {
    dismissed.value = true
    props.onDismiss?.()
  }

  return closeDialog(props.name, true)
}

const submit = (data: { score: string; comment?: string }) => {
  props.onSubmit?.({
    score: Number(data.score),
    comment: data.comment || undefined,
  })

  return closeDialog(props.name, true)
}
</script>

<template>
  <CommonDialog
    :name="name"
    :header-title="__('Rate this ticket')"
    header-icon="star"
    global
    @close="close"
  >
    <Form
      ref="form"
      :schema="schema"
      @submit="submit($event as { score: string; comment?: string })"
    />

    <template #footer>
      <CommonDialogActionFooter :action-label="__('Submit')" :form-node-id="formNodeId" />
    </template>
  </CommonDialog>
</template>
