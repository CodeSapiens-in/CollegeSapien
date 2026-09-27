<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface Stats {
  approvedNotes: number;
  approvedQPs: number;
  pendingModeration: number;
  syllabus: number;
}

const { get } = useApi();
const stats = ref<Stats | null>(null);
const statsLoading = ref(true);
const statsError = ref("");
const syllabusCount = ref(0);

onMounted(async () => {
  try {
    stats.value = await get<Stats>("/admin/resources/stats");
  } catch (err) {
    console.error("Failed to load resource stats", err);
    statsError.value = "Failed to load stats.";
  }
  statsLoading.value = false;

  // /admin/resources/stats counts a legacy hub_resources category, not the
  // curriculum records this module actually publishes, so fetch the real count.
  try {
    const curricula = await get<unknown[]>("/curriculum/admin");
    syllabusCount.value = curricula.length;
  } catch (err) {
    console.error("Failed to load syllabus count", err);
  }
});

const modules = computed(() => [
  {
    label: "Syllabus",
    description: `${syllabusCount.value} published`,
    to: "/resources/syllabus",
    icon: "i-heroicons-book-open",
  },
  {
    label: "Notes",
    description: `${stats.value?.approvedNotes ?? 0} published`,
    to: "/resources/notes",
    icon: "i-heroicons-document-text",
  },
  {
    label: "Question Papers",
    description: `${stats.value?.approvedQPs ?? 0} published`,
    to: "/resources/question-papers",
    icon: "i-heroicons-academic-cap",
  },
]);
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-1">Resources</h1>
    <p class="text-sm text-gray-500 mb-6">
      Browse published syllabus, notes, and question papers.
    </p>

    <div v-if="statsLoading" class="text-gray-400 text-sm mb-6">
      Loading stats…
    </div>
    <div
      v-else-if="statsError"
      class="text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-4 text-sm mb-6"
    >
      {{ statsError }}
    </div>

    <ModuleHub :items="modules" />
  </div>
</template>
