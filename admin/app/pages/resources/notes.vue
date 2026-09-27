<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });
</script>

<template>
  <div>
    <NuxtLink
      to="/resources"
      class="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1 mb-2"
    >
      <Icon name="i-heroicons-arrow-left" class="w-3.5 h-3.5" />
      Resources
    </NuxtLink>
    <h1 class="text-xl font-bold text-gray-900 mb-6">Notes</h1>
    <ResourcesResourceBrowser category="Notes" />
  </div>
</template>
