<script setup lang="ts">
defineProps<{
  label: string;
  value: string | number;
  icon: string;
  to?: string;
  loading?: boolean;
}>();
</script>

<template>
  <component
    :is="to ? 'NuxtLink' : 'div'"
    :to="to"
    class="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4 transition-colors"
    :class="{ 'hover:border-yellow-400 cursor-pointer': to }"
  >
    <div
      class="w-11 h-11 rounded-lg bg-yellow-400 flex items-center justify-center shrink-0"
    >
      <Icon :name="icon" class="w-5.5 h-5.5 text-gray-900" />
    </div>
    <div>
      <div
        v-if="loading"
        class="h-7 w-16 bg-gray-200 rounded animate-pulse mb-1"
      />
      <div v-else class="text-2xl font-bold text-gray-900">{{ value }}</div>
      <div class="text-sm text-gray-500">{{ label }}</div>
    </div>
  </component>
</template>
