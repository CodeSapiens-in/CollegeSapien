<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface College {
  id: string;
  name: string;
  code: string;
  city?: string;
  domains?: string[];
}

const { get, post, put, delete: apiDelete } = useApi();

const colleges = ref<College[]>([]);
const loading = ref(true);
const selectedCollege = ref<College | null>(null);

const search = ref("");
const page = ref(1);
const pageSize = ref(10);

const formMode = ref<"idle" | "create" | "edit">("idle");
const formName = ref("");
const formCode = ref("");
const formCity = ref("");
const formDomains = ref<string[]>([]);
const formDomainInput = ref("");
const formSaving = ref(false);
const formError = ref("");

const pendingDelete = ref<College | null>(null);
const deleteInFlight = ref(false);

const snack = ref("");

onMounted(async () => {
  try {
    colleges.value = await get<College[]>("/colleges");
  } catch (err) {
    console.error("Failed to load colleges", err);
  }
  loading.value = false;
});

const filteredColleges = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return colleges.value;
  return colleges.value.filter(
    (c) =>
      c.name.toLowerCase().includes(q) ||
      c.code.toLowerCase().includes(q) ||
      (c.city ?? "").toLowerCase().includes(q),
  );
});

const paginatedColleges = computed(() => {
  const start = (page.value - 1) * pageSize.value;
  return filteredColleges.value.slice(start, start + pageSize.value);
});

watch([search, colleges], () => {
  page.value = 1;
});
watch(pageSize, () => {
  page.value = 1;
});

const openCreate = () => {
  selectedCollege.value = null;
  formName.value = "";
  formCode.value = "";
  formCity.value = "";
  formDomains.value = [];
  formDomainInput.value = "";
  formError.value = "";
  formMode.value = "create";
};

const openEdit = (college: College) => {
  selectedCollege.value = college;
  formName.value = college.name;
  formCode.value = college.code;
  formCity.value = college.city ?? "";
  formDomains.value = [...(college.domains ?? [])];
  formDomainInput.value = "";
  formError.value = "";
  formMode.value = "edit";
};

const cancelForm = () => {
  formMode.value = "idle";
  selectedCollege.value = null;
};

const addDomain = () => {
  const d = formDomainInput.value.trim().toLowerCase();
  if (d && !formDomains.value.includes(d)) formDomains.value.push(d);
  formDomainInput.value = "";
};

const removeDomain = (d: string) => {
  formDomains.value = formDomains.value.filter((x) => x !== d);
};

const saveCollege = async () => {
  formError.value = "";
  if (!formName.value.trim() || !formCode.value.trim()) {
    formError.value = "Name and code are required.";
    return;
  }
  formSaving.value = true;
  const body: Record<string, unknown> = {
    name: formName.value.trim(),
    code: formCode.value.trim().toUpperCase(),
    ...(formCity.value.trim() ? { city: formCity.value.trim() } : {}),
    ...(formDomains.value.length ? { domains: formDomains.value } : {}),
  };
  try {
    if (formMode.value === "create") {
      const res = await post<{ id: string }>("/colleges", body);
      colleges.value.push({ id: res.id, ...body } as College);
      snack.value = "College created.";
    } else if (selectedCollege.value) {
      await put(`/colleges/${selectedCollege.value.id}`, body);
      const idx = colleges.value.findIndex(
        (c) => c.id === selectedCollege.value!.id,
      );
      if (idx !== -1)
        colleges.value[idx] = {
          id: selectedCollege.value.id,
          ...body,
        } as College;
      snack.value = "College updated.";
    }
    formMode.value = "idle";
    selectedCollege.value = null;
  } catch {
    formError.value = "Save failed. Check that you have superadmin access.";
  }
  formSaving.value = false;
};

const confirmDelete = async () => {
  if (!pendingDelete.value) return;
  deleteInFlight.value = true;
  try {
    await apiDelete(`/colleges/${pendingDelete.value.id}`);
    colleges.value = colleges.value.filter(
      (c) => c.id !== pendingDelete.value!.id,
    );
    if (selectedCollege.value?.id === pendingDelete.value.id) {
      selectedCollege.value = null;
      formMode.value = "idle";
    }
    snack.value = "College deleted.";
  } catch {
    snack.value = "Delete failed.";
  }
  pendingDelete.value = null;
  deleteInFlight.value = false;
};
</script>

<template>
  <div>
    <NuxtLink
      to="/colleges"
      class="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1 mb-2"
    >
      <Icon name="i-heroicons-arrow-left" class="w-3.5 h-3.5" />
      Colleges & Departments
    </NuxtLink>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-900">Colleges</h1>
      <button
        class="inline-flex items-center gap-2 px-4 py-2 bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 transition-colors text-sm"
        @click="openCreate"
      >
        <Icon name="i-heroicons-plus" class="w-4 h-4" />
        Add College
      </button>
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

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <!-- College list -->
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-100">
          <div class="text-sm font-medium text-gray-700 mb-2">
            All Colleges ({{ filteredColleges.length }})
          </div>
          <div class="relative">
            <Icon
              name="i-heroicons-magnifying-glass"
              class="w-4 h-4 text-gray-400 absolute left-2.5 top-1/2 -translate-y-1/2"
            />
            <input
              v-model="search"
              type="text"
              placeholder="Search colleges…"
              class="w-full pl-8 pr-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
            />
          </div>
        </div>
        <div class="max-h-96 overflow-y-auto lg:max-h-none lg:overflow-visible">
          <div v-if="loading" class="p-4 text-sm text-gray-400">Loading…</div>
          <div
            v-for="college in paginatedColleges"
            :key="college.id"
            class="px-4 py-3 border-b border-gray-50 cursor-pointer hover:bg-gray-50 transition-colors group"
            :class="
              selectedCollege?.id === college.id
                ? 'bg-yellow-50 border-l-2 border-l-yellow-400'
                : ''
            "
            @click="openEdit(college)"
          >
            <div class="flex items-center justify-between gap-2">
              <div class="min-w-0">
                <div class="font-medium text-gray-900 text-sm truncate">
                  {{ college.name }}
                </div>
                <div class="text-xs text-gray-500 mt-0.5">
                  {{ college.code }} · {{ college.city ?? "No city" }}
                </div>
              </div>
              <button
                class="shrink-0 p-1 text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-opacity"
                title="Delete"
                @click.stop="pendingDelete = college"
              >
                <Icon name="i-heroicons-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
          <div
            v-if="!loading && filteredColleges.length === 0"
            class="p-4 text-sm text-gray-400"
          >
            No colleges found.
          </div>
        </div>
        <Pagination
          v-if="filteredColleges.length > 0"
          :page="page"
          :page-size="pageSize"
          :total="filteredColleges.length"
          :page-size-options="[10, 25, 50, 100]"
          @update:page="page = $event"
          @update:page-size="pageSize = $event"
        />
      </div>

      <!-- Detail / form panel -->
      <div class="md:col-span-2 bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div v-if="formMode === 'idle'" class="p-8 text-center text-gray-400 text-sm">
          Select a college to edit, or click <strong class="text-gray-600">Add College</strong>.
        </div>
        <template v-else>
          <div class="px-6 py-4 border-b border-gray-100 text-sm font-medium text-gray-700">
            {{ formMode === "create" ? "New College" : `Edit - ${selectedCollege?.name}` }}
          </div>

          <div class="flex flex-col p-6 space-y-4">
            <div v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg p-3">
              {{ formError }}
            </div>

            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">Name *</label>
              <input
                v-model="formName"
                type="text"
                placeholder="e.g. SSN College of Engineering"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">Code *</label>
              <input
                v-model="formCode"
                type="text"
                placeholder="e.g. SSN"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">City</label>
              <input
                v-model="formCity"
                type="text"
                placeholder="e.g. Chennai"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">Email Domains</label>
              <div class="flex gap-2 mb-2">
                <input
                  v-model="formDomainInput"
                  type="text"
                  placeholder="e.g. ssn.edu.in"
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
                  @keydown.enter.prevent="addDomain"
                />
                <button
                  type="button"
                  class="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors"
                  @click="addDomain"
                >
                  Add
                </button>
              </div>
              <div class="flex flex-wrap gap-2">
                <span
                  v-for="d in formDomains"
                  :key="d"
                  class="inline-flex items-center gap-1 px-2 py-1 bg-yellow-100 text-yellow-900 rounded-md text-xs"
                >
                  {{ d }}
                  <button @click="removeDomain(d)">
                    <Icon name="i-heroicons-x-mark" class="w-3 h-3" />
                  </button>
                </span>
                <span v-if="formDomains.length === 0" class="text-xs text-gray-400">No domains added</span>
              </div>
            </div>

            <div class="flex justify-end gap-2 pt-2">
              <button
                class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                @click="cancelForm"
              >
                Cancel
              </button>
              <button
                :disabled="formSaving"
                class="px-4 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 disabled:opacity-60 transition-colors"
                @click="saveCollege"
              >
                {{ formSaving ? "Saving…" : (formMode === "create" ? "Create" : "Save Changes") }}
              </button>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- Delete College confirm modal -->
    <Modal v-if="pendingDelete" @close="pendingDelete = null">
      <div class="p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-2">
          Delete college?
        </h3>
        <p class="text-sm text-gray-500 mb-4">
          <strong>{{ pendingDelete.name }}</strong> will be soft-deleted. This
          cannot be undone from the admin panel.
        </p>
        <div class="flex justify-end gap-2">
          <button
            class="px-4 py-2 text-sm border border-gray-300 rounded-lg"
            @click="pendingDelete = null"
          >
            Cancel
          </button>
          <button
            :disabled="deleteInFlight"
            class="px-4 py-2 text-sm bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 disabled:opacity-60"
            @click="confirmDelete"
          >
            {{ deleteInFlight ? "Deleting…" : "Delete" }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
