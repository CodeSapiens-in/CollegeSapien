<script setup lang="ts">
interface Resource {
  id: string;
  name: string;
  category: string;
  uploaderName?: string;
  uploadedBy?: string;
  collegeId?: string;
  createdAt?: string;
  fileUrl?: string;
}

const props = defineProps<{
  category: "Notes" | "QP";
}>();

const { get, patch, delete: apiDelete } = useApi();
const authStore = useAuthStore();
const isAmbassador = computed(() => authStore.user?.role === "ambassador");

const tab = ref<"approved" | "archived">("approved");
const resourceList = ref<Resource[]>([]);
const resourcesLoading = ref(false);
const actionInFlight = ref<Set<string>>(new Set());
const snack = ref("");

const fetchResources = async () => {
  resourcesLoading.value = true;
  try {
    const endpoint =
      tab.value === "approved"
        ? "/admin/resources/approved"
        : "/admin/resources/archived";
    resourceList.value = await get<Resource[]>(
      `${endpoint}?category=${props.category}`,
    );
  } catch (err) {
    console.error("Failed to load resources", err);
    resourceList.value = [];
  }
  resourcesLoading.value = false;
};

const archive = async (id: string) => {
  if (isAmbassador.value) {
    alert("Ambassadors do not have permission to archive resources.");
    return;
  }
  actionInFlight.value.add(id);
  try {
    await apiDelete(`/admin/resources/${id}`);
    resourceList.value = resourceList.value.filter((r) => r.id !== id);
    snack.value = "Resource archived.";
  } catch (err) {
    console.error("Failed to archive resource", err);
  }
  actionInFlight.value.delete(id);
};

const unarchive = async (id: string) => {
  actionInFlight.value.add(id);
  try {
    await patch(`/admin/resources/${id}/unarchive`);
    resourceList.value = resourceList.value.filter((r) => r.id !== id);
    snack.value = "Resource restored to approved.";
  } catch (err) {
    console.error("Failed to unarchive resource", err);
  }
  actionInFlight.value.delete(id);
};

onMounted(fetchResources);
watch(tab, fetchResources);
</script>

<template>
  <div>
    <div
      v-if="snack"
      class="mb-4 text-sm text-green-700 bg-green-50 border border-green-200 rounded-lg px-4 py-2 flex justify-between"
    >
      {{ snack }}
      <button @click="snack = ''">
        <Icon name="i-heroicons-x-mark" class="w-4 h-4" />
      </button>
    </div>

    <div class="mb-4 flex rounded-lg bg-gray-100 p-1 gap-1 w-fit text-sm">
      <button
        class="px-4 py-2 transition-colors border-none rounded-lg"
        :class="
          tab === 'approved'
            ? 'bg-yellow-400 text-gray-900 font-medium'
            : 'bg-white text-gray-600 hover:bg-gray-50'
        "
        @click="tab = 'approved'"
      >
        Approved
      </button>
      <button
        class="px-4 py-2 transition-colors border-none rounded-lg"
        :class="
          tab === 'archived'
            ? 'bg-yellow-400 text-gray-900 font-medium'
            : 'bg-white text-gray-600 hover:bg-gray-50'
        "
        @click="tab = 'archived'"
      >
        Archived
      </button>
    </div>

    <div v-if="resourcesLoading" class="text-gray-400 text-sm p-4">
      Loading…
    </div>

    <div
      v-else-if="resourceList.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No {{ tab }} resources.
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="resource in resourceList"
        :key="resource.id"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <div class="flex items-start justify-between gap-2 mb-3">
          <div>
            <div class="font-semibold text-gray-900 text-sm">
              {{ resource.name }}
            </div>
            <div class="text-xs text-gray-500 mt-0.5">
              By {{ resource.uploaderName ?? resource.uploadedBy }}
            </div>
          </div>
          <span
            class="text-xs px-2 py-0.5 rounded-full shrink-0"
            :class="
              tab === 'approved'
                ? 'bg-green-100 text-green-800'
                : 'bg-gray-100 text-gray-600'
            "
            >{{ tab === "approved" ? "Approved" : "Archived" }}</span
          >
        </div>

        <div class="flex gap-2">
          <a
            v-if="resource.fileUrl"
            :href="resource.fileUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="px-3 py-1.5 text-xs font-medium border border-blue-300 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-1"
          >
            <Icon
              name="i-heroicons-arrow-top-right-on-square"
              class="w-3.5 h-3.5"
            />
            Open File
          </a>
          <button
            v-if="tab === 'approved' && !isAmbassador"
            :disabled="actionInFlight.has(resource.id)"
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 disabled:opacity-60 transition-colors"
            @click="archive(resource.id)"
          >
            Archive
          </button>
          <button
            v-else-if="tab === 'archived'"
            :disabled="actionInFlight.has(resource.id)"
            class="px-3 py-1.5 text-xs font-medium bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
            @click="unarchive(resource.id)"
          >
            Restore
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
