<script setup lang="ts">
defineProps<{
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
}>();

const emit = defineEmits<{
  confirm: [];
  cancel: [];
}>();
</script>

<template>
  <Modal max-width="max-w-sm">
    <div class="p-6">
      <h3 class="text-base font-semibold text-gray-900 mb-2">{{ title }}</h3>
      <p class="text-sm text-gray-600 mb-5 whitespace-pre-line">{{ message }}</p>
      <div class="flex justify-end gap-2">
        <button
          class="px-4 py-2 text-sm rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition-colors"
          @click="emit('cancel')"
        >
          Cancel
        </button>
        <button
          class="px-4 py-2 text-sm rounded-lg font-medium transition-colors"
          :class="
            danger
              ? 'bg-red-600 text-white hover:bg-red-700'
              : 'bg-yellow-400 text-gray-900 hover:bg-yellow-500'
          "
          @click="emit('confirm')"
        >
          {{ confirmLabel ?? "Confirm" }}
        </button>
      </div>
    </div>
  </Modal>
</template>
