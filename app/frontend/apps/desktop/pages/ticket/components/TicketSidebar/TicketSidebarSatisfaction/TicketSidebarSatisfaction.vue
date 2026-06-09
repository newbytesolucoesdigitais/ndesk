<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed } from 'vue'

import { usePersistentStates } from '#desktop/pages/ticket/composables/usePersistentStates.ts'
import {
  type TicketSidebarProps,
  type TicketSidebarEmits,
} from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarContent from '../TicketSidebarContent.vue'
import TicketSidebarWrapper from '../TicketSidebarWrapper.vue'

const props = defineProps<TicketSidebarProps>()

const { persistentStates } = usePersistentStates()

const emit = defineEmits<TicketSidebarEmits>()

const satisfaction = computed(() => props.context.ticket?.value?.satisfaction)

const ratable = computed(() => props.context.ticket?.value?.satisfactionRatable)

emit('show')
</script>

<template>
  <TicketSidebarWrapper
    :key="sidebar"
    :sidebar="sidebar"
    :sidebar-plugin="sidebarPlugin"
    :selected="selected"
  >
    <TicketSidebarContent
      v-model="persistentStates.scrollPosition"
      :title="sidebarPlugin.title"
      :icon="sidebarPlugin.icon"
    >
      <template v-if="satisfaction">
        <CommonLabel size="large">
          {{ $t('Rating: %s/5', satisfaction.score) }}
        </CommonLabel>
        <CommonLabel v-if="satisfaction.comment" class="text-stone-200 dark:text-neutral-500">
          {{ satisfaction.comment }}
        </CommonLabel>
        <CommonLabel
          v-if="satisfaction.agent?.fullname"
          class="text-stone-200 dark:text-neutral-500"
        >
          {{ $t('Rated by %s', satisfaction.agent.fullname) }}
        </CommonLabel>
      </template>
      <CommonLabel v-else-if="ratable" class="text-stone-200 dark:text-neutral-500">
        {{ $t('Not rated yet') }}
      </CommonLabel>
      <CommonLabel v-else class="text-stone-200 dark:text-neutral-500">
        {{ $t('No rating') }}
      </CommonLabel>
    </TicketSidebarContent>
  </TicketSidebarWrapper>
</template>
