<script setup lang="ts">
const props = defineProps<{
  page: number;
  pageSize: number;
  total: number;
  pageSizeOptions?: number[];
}>();

const emit = defineEmits<{
  "update:page": [number];
  "update:pageSize": [number];
}>();

const sizeOptions = computed(() => props.pageSizeOptions ?? [10, 25, 50, 100]);
const totalPages = computed(() =>
  Math.max(1, Math.ceil(props.total / props.pageSize)),
);

const rangeStart = computed(() =>
  props.total === 0 ? 0 : (props.page - 1) * props.pageSize + 1,
);
const rangeEnd = computed(() =>
  Math.min(props.page * props.pageSize, props.total),
);

// Page numbers with ellipsis, e.g. 1 … 4 5 [6] 7 8 … 20
const pageItems = computed<(number | "…")[]>(() => {
  const total = totalPages.value;
  const current = props.page;
  const items: (number | "…")[] = [];
  const add = (n: number | "…") => items.push(n);

  const window = 1;
  const start = Math.max(2, current - window);
  const end = Math.min(total - 1, current + window);

  add(1);
  if (start > 2) add("…");
  for (let p = start; p <= end; p++) add(p);
  if (end < total - 1) add("…");
  if (total > 1) add(total);

  return items;
});

const goTo = (p: number) => {
  if (p < 1 || p > totalPages.value || p === props.page) return;
  emit("update:page", p);
};

const onSizeChange = (e: Event) => {
  emit("update:pageSize", Number((e.target as HTMLSelectElement).value));
};
</script>

<template>
  <div
    class="flex flex-col sm:flex-row items-center justify-between gap-3 px-4 py-3 border-t border-gray-100 text-sm text-gray-500"
  >
    <div class="flex items-center gap-2">
      <span>Rows per page</span>
      <select
        :value="pageSize"
        class="px-2 py-1 border border-gray-300 rounded-lg text-sm focus:outline-none"
        @change="onSizeChange"
      >
        <option v-for="opt in sizeOptions" :key="opt" :value="opt">
          {{ opt }}
        </option>
      </select>
      <span v-if="total > 0" class="hidden sm:inline"
        >Showing {{ rangeStart }}–{{ rangeEnd }} of {{ total }}</span
      >
    </div>

    <div v-if="totalPages > 1" class="flex items-center gap-1">
      <button
        class="px-2.5 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
        :disabled="page <= 1"
        @click="goTo(page - 1)"
      >
        Prev
      </button>
      <template v-for="(item, idx) in pageItems" :key="idx">
        <span v-if="item === '…'" class="px-2 text-gray-400">…</span>
        <button
          v-else
          class="min-w-[2rem] px-2.5 py-1.5 border rounded-lg"
          :class="
            item === page
              ? 'border-yellow-400 bg-yellow-50 text-gray-900 font-medium'
              : 'border-gray-300 hover:bg-gray-50'
          "
          @click="goTo(item)"
        >
          {{ item }}
        </button>
      </template>
      <button
        class="px-2.5 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
        :disabled="page >= totalPages"
        @click="goTo(page + 1)"
      >
        Next
      </button>
    </div>
  </div>
</template>
