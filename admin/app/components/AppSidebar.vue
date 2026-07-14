<script setup lang="ts">
const route = useRoute();
const authStore = useAuthStore();
const { isOpen, isDesktop, close } = useSidebar();

watch(
  () => route.path,
  () => close(),
);

const isAmbassador = computed(() => authStore.user?.role === "ambassador");

const nav = computed(() => {
  const allItems = [
    { label: "Dashboard", to: "/", icon: "i-heroicons-squares-2x2" },
    { label: "Users", to: "/users", icon: "i-heroicons-users" },
    {
      label: "Colleges",
      to: "/colleges",
      icon: "i-heroicons-building-library",
    },
    { label: "Resources", to: "/resources", icon: "i-heroicons-document-text" },
    { label: "Syllabus", to: "/syllabus", icon: "i-heroicons-book-open" },
    {
      label: "Moderation",
      to: "/moderation",
      icon: "i-heroicons-shield-check",
    },
    { label: "Events", to: "/events", icon: "i-heroicons-calendar-days" },
    { label: "Reports", to: "/reports", icon: "i-heroicons-flag" },
    {
      label: "Ambassadors",
      to: "/ambassadors",
      icon: "i-heroicons-academic-cap",
    },
    { label: "CMS", to: "/cms", icon: "i-heroicons-pencil-square" },
  ];
  if (isAmbassador.value) {
    return allItems.filter((item) =>
      ["Syllabus", "Resources", "Events"].includes(item.label),
    );
  }
  return allItems;
});

const isActive = (to: string) =>
  to === "/" ? route.path === "/" : route.path.startsWith(to);
</script>

<template>
  <div
    v-if="!isDesktop && isOpen"
    class="fixed inset-0 z-40 bg-black/40 lg:hidden"
    @click="close"
  />

  <aside
    class="fixed inset-y-0 left-0 z-50 w-56 min-h-screen bg-gray-950 flex flex-col transition-transform duration-200 ease-in-out lg:static lg:translate-x-0"
    :class="isOpen ? 'translate-x-0' : '-translate-x-full'"
  >
    <div
      class="px-5 py-6 border-b border-gray-800 flex items-center justify-between"
    >
      <div>
        <span class="text-white font-bold text-lg tracking-tight"
          >CodeSapiens</span
        >
        <span class="block text-gray-400 text-xs mt-0.5">Admin Panel</span>
      </div>
      <button
        class="lg:hidden p-1 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800"
        @click="close"
      >
        <Icon name="i-heroicons-x-mark" class="w-5 h-5" />
      </button>
    </div>

    <nav class="flex-1 px-3 py-4 flex flex-col gap-1">
      <NuxtLink
        v-for="item in nav"
        :key="item.to"
        :to="item.to"
        class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors"
        :class="
          isActive(item.to)
            ? 'bg-yellow-400 text-gray-900'
            : 'text-gray-400 hover:text-white hover:bg-gray-800'
        "
      >
        <Icon :name="item.icon" class="w-4.5 h-4.5 shrink-0" />
        {{ item.label }}
      </NuxtLink>
    </nav>
  </aside>
</template>
