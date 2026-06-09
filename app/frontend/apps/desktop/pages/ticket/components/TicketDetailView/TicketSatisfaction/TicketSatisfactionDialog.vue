<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, markRaw, ref } from 'vue'

import Form from '#shared/components/Form/Form.vue'
import type { FormSchemaNode } from '#shared/components/Form/types.ts'
import { useForm } from '#shared/components/Form/useForm.ts'
import { useApplicationStore } from '#shared/stores/application.ts'

import CommonDialog from '#desktop/components/CommonDialog/CommonDialog.vue'
import CommonDialogActionFooter from '#desktop/components/CommonDialog/CommonDialogActionFooter.vue'
import { closeDialog } from '#desktop/components/CommonDialog/useDialog.ts'

interface Props {
  name: string
  onSubmit?: (data: { score: number; comment?: string }) => void | Promise<void>
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

// Tracks whether this dialog instance has already resolved (submitted or
// dismissed) so the dismissal side effect runs at most once.
const resolved = ref(false)

// Every non-submit exit path (X button, backdrop click, Escape key, and the
// footer cancel button) funnels through `CommonDialog`'s `close` event, which
// may emit `cancel` as `undefined`. Treat any such close as a dismissal so the
// `onDismiss` persistence runs regardless of which path the user took.
const close = () => {
  if (!resolved.value) {
    resolved.value = true
    props.onDismiss?.()
  }

  return closeDialog(props.name, true)
}

// Await the (async) submit handler before closing so the dialog stays open
// until the mutation resolves. `MutationHandler.send` rejects on failure, so a
// rejected submit skips the close below — the survey stays open and in context
// for a retry, and `resolved` is only set on success (mirrors FeedbackDialog).
const submit = async (data: { score: string; comment?: string }) => {
  await props.onSubmit?.({
    score: Number(data.score),
    comment: data.comment || undefined,
  })

  resolved.value = true

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
      <CommonDialogActionFooter
        :action-label="__('Submit')"
        :cancel-label="__('Not now')"
        :form-node-id="formNodeId"
        @cancel="close"
      />
    </template>
  </CommonDialog>
</template>
