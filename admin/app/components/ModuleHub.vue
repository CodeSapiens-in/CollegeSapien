<script setup lang="ts">
defineProps<{
  items: {
    label: string;
    description: string;
    to: string;
    icon: string;
    count?: number | null;
  }[];
}>();
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
    <NuxtLink
      v-for="item in items"
      :key="item.to"
      :to="item.to"
      class="bg-white rounded-xl border border-gray-200 p-5 hover:border-yellow-400 transition-colors flex flex-col items-start gap-3"
    >
      <div
        class="w-11 h-11 rounded-lg bg-yellow-400 flex items-center justify-center relative"
      >
        <Icon :name="item.icon" class="w-5.5 h-5.5 text-gray-900" />
        <span
          v-if="item.count"
          class="absolute -top-2 -right-2 min-w-[1.25rem] h-5 px-1 rounded-full bg-red-500 text-white text-[10px] font-semibold flex items-center justify-center"
        >
          {{ item.count }}
        </span>
      </div>
      <div>
        <div class="font-semibold text-gray-900 text-sm">{{ item.label }}</div>
        <div class="text-xs text-gray-500 mt-0.5">{{ item.description }}</div>
      </div>
    </NuxtLink>
  </div>
</template>
