<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface College {
  id: string;
}
interface Department {
  id: string;
}

const { get } = useApi();
const collegeCount = ref(0);
const deptCount = ref(0);
const loading = ref(true);

onMounted(async () => {
  const [colleges, departments] = await Promise.allSettled([
    get<College[]>("/colleges"),
    get<Department[]>("/colleges/departments"),
  ]);
  if (colleges.status === "fulfilled") collegeCount.value = colleges.value.length;
  if (departments.status === "fulfilled") deptCount.value = departments.value.length;
  loading.value = false;
});

const modules = computed(() => [
  {
    label: "Colleges",
    description: `${collegeCount.value} colleges`,
    to: "/colleges/list",
    icon: "i-heroicons-building-library",
  },
  {
    label: "Departments",
    description: `${deptCount.value} departments`,
    to: "/colleges/departments",
    icon: "i-heroicons-rectangle-stack",
  },
]);
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-1">Colleges & Departments</h1>
    <p class="text-sm text-gray-500 mb-6">
      Manage the colleges and departments used across the platform.
    </p>

    <div v-if="loading" class="text-gray-400 text-sm mb-6">Loading…</div>

    <ModuleHub :items="modules" />
  </div>
</template>
