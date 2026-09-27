<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

const { get } = useApi();
const authStore = useAuthStore();
const isAmbassador = computed(() => authStore.user?.role === "ambassador");

const pendingSyllabus = ref(0);
const pendingNotes = ref(0);
const pendingQPs = ref(0);
const pendingEvents = ref(0);
const pendingReports = ref(0);
const loading = ref(true);

onMounted(async () => {
  const [syllabus, notes, qps, events, reports] = await Promise.allSettled([
    get<unknown[]>("/curriculum/pending"),
    get<unknown[]>("/admin/resources/pending?category=Notes"),
    get<unknown[]>("/admin/resources/pending?category=QP"),
    get<unknown[]>("/events/pending"),
    isAmbassador.value
      ? Promise.resolve([])
      : get<unknown[]>("/admin/reports"),
  ]);
  if (syllabus.status === "fulfilled") pendingSyllabus.value = syllabus.value.length;
  if (notes.status === "fulfilled") pendingNotes.value = notes.value.length;
  if (qps.status === "fulfilled") pendingQPs.value = qps.value.length;
  if (events.status === "fulfilled") pendingEvents.value = events.value.length;
  if (reports.status === "fulfilled") pendingReports.value = reports.value.length;
  loading.value = false;
});

const modules = computed(() => {
  const items = [
    {
      label: "Syllabus",
      description: "Review and publish curricula",
      to: "/moderation/syllabus",
      icon: "i-heroicons-book-open",
      count: pendingSyllabus.value,
    },
    {
      label: "Notes",
      description: "Review pending notes",
      to: "/moderation/notes",
      icon: "i-heroicons-document-text",
      count: pendingNotes.value,
    },
    {
      label: "Question Papers",
      description: "Review pending question papers",
      to: "/moderation/question-papers",
      icon: "i-heroicons-academic-cap",
      count: pendingQPs.value,
    },
    {
      label: "Events",
      description: "Review pending events",
      to: "/moderation/events",
      icon: "i-heroicons-calendar-days",
      count: pendingEvents.value,
    },
  ];
  if (isAmbassador.value) return items;
  return [
    ...items,
    {
      label: "Reports",
      description: "Resolve flagged content",
      to: "/reports",
      icon: "i-heroicons-flag",
      count: pendingReports.value,
    },
    {
      label: "Ambassadors",
      description: "Promote users to ambassador",
      to: "/ambassadors",
      icon: "i-heroicons-academic-cap",
    },
    {
      label: "CMS",
      description: "Edit site content",
      to: "/cms",
      icon: "i-heroicons-pencil-square",
    },
  ];
});
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-1">Moderation</h1>
    <p class="text-sm text-gray-500 mb-6">
      Review and approve submitted content before it goes live.
    </p>

    <div v-if="loading" class="text-gray-400 text-sm mb-6">
      Loading pending counts…
    </div>

    <ModuleHub :items="modules" />
  </div>
</template>
