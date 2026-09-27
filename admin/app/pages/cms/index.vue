<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface CmsEntry {
  key: string;
  label: string;
  value: string;
  type: "string" | "markdown" | "boolean";
}

const { get, put } = useApi();
const authStore = useAuthStore();

const entries = ref<CmsEntry[]>([]);
const loading = ref(true);
const editing = ref<Record<string, string>>({});
const saving = ref<Set<string>>(new Set());
const snack = ref("");
const error = ref("");

onMounted(async () => {
  try {
    entries.value = await get<CmsEntry[]>("/admin/cms");
    entries.value.forEach((e) => {
      editing.value[e.key] = e.value;
    });
  } catch (e: unknown) {
    console.error("Failed to load CMS entries", e);
    error.value =
      "CMS endpoint not yet available — add GET /admin/cms to the API.";
  }
  loading.value = false;
});

const save = async (entry: CmsEntry) => {
  saving.value.add(entry.key);
  try {
    await put(`/admin/cms/${entry.key}`, { value: editing.value[entry.key] });
    entry.value = editing.value[entry.key] ?? entry.value;
    snack.value = `${entry.label} updated.`;
  } catch (err) {
    console.error("Failed to update CMS entry", err);
  }
  saving.value.delete(entry.key);
};
</script>

<template>
  <div>
    <NuxtLink
      to="/moderation"
      class="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1 mb-2"
    >
      <Icon name="i-heroicons-arrow-left" class="w-3.5 h-3.5" />
      Moderation
    </NuxtLink>
    <div class="mb-6">
      <h1 class="text-xl font-bold text-gray-900">CMS</h1>
      <p class="text-sm text-gray-500 mt-0.5">Edit app content and copy</p>
    </div>

    <div
      v-if="snack"
      class="mb-4 text-sm text-green-700 bg-green-50 border border-green-200 rounded-lg px-4 py-2 flex justify-between"
    >
      {{ snack }}
      <button @click="snack = ''">
        <Icon name="i-heroicons-x-mark" class="w-4 h-4" />
      </button>
    </div>

    <div v-if="loading" class="text-gray-400 text-sm">Loading…</div>
    <div
      v-else-if="error"
      class="text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-4 text-sm"
    >
      {{ error }}
    </div>

    <div
      v-else-if="entries.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No CMS entries. Seed the <code>app_content</code> Firestore collection
      first.
    </div>

    <div v-else class="flex flex-col gap-4">
      <div
        v-for="entry in entries"
        :key="entry.key"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <div class="flex items-center gap-2 mb-3">
          <span class="font-semibold text-gray-900 text-sm">{{
            entry.label
          }}</span>
          <code
            class="text-xs text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded"
            >{{ entry.key }}</code
          >
          <code
            class="text-xs text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded"
            >{{ entry.type }}</code
          >
        </div>

        <template v-if="entry.type === 'boolean'">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="editing[entry.key]"
              type="checkbox"
              :true-value="'true'"
              :false-value="'false'"
              class="w-4 h-4"
            />
            <span class="text-sm text-gray-700">{{
              editing[entry.key] === "true" ? "Enabled" : "Disabled"
            }}</span>
          </label>
        </template>
        <template v-else-if="entry.type === 'markdown'">
          <textarea
            v-model="editing[entry.key]"
            rows="5"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm resize-y focus:outline-none focus:ring-2 focus:ring-yellow-400 font-mono"
          />
        </template>
        <template v-else>
          <input
            v-model="editing[entry.key]"
            class="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
          />
        </template>

        <div v-if="authStore.isSuperAdmin" class="flex justify-end mt-3">
          <button
            :disabled="saving.has(entry.key)"
            class="px-4 py-1.5 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 disabled:opacity-60 transition-colors"
            @click="save(entry)"
          >
            {{ saving.has(entry.key) ? "Saving…" : "Save" }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
