<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface Department {
  id: string;
  name: string;
  code: string;
}

const { get, post, put, delete: apiDelete } = useApi();

const departments = ref<Department[]>([]);
const loadingDepts = ref(true);
const selectedDept = ref<Department | null>(null);

const search = ref("");
const page = ref(1);
const pageSize = ref(10);

const deptFormMode = ref<"idle" | "create" | "edit">("idle");
const deptFormName = ref("");
const deptFormCode = ref("");
const deptFormSaving = ref(false);
const deptFormError = ref("");

const pendingDeleteDept = ref<Department | null>(null);
const deleteDeptInFlight = ref(false);

const snack = ref("");

onMounted(async () => {
  try {
    departments.value = await get<Department[]>("/colleges/departments");
  } catch (err) {
    console.error("Failed to load departments", err);
  }
  loadingDepts.value = false;
});

const filteredDepartments = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return departments.value;
  return departments.value.filter(
    (d) => d.name.toLowerCase().includes(q) || d.code.toLowerCase().includes(q),
  );
});

const paginatedDepartments = computed(() => {
  const start = (page.value - 1) * pageSize.value;
  return filteredDepartments.value.slice(start, start + pageSize.value);
});

watch([search, departments], () => {
  page.value = 1;
});
watch(pageSize, () => {
  page.value = 1;
});

const openCreateDept = () => {
  selectedDept.value = null;
  deptFormName.value = "";
  deptFormCode.value = "";
  deptFormError.value = "";
  deptFormMode.value = "create";
};

const openEditDept = (dept: Department) => {
  selectedDept.value = dept;
  deptFormName.value = dept.name;
  deptFormCode.value = dept.code;
  deptFormError.value = "";
  deptFormMode.value = "edit";
};

const cancelDeptForm = () => {
  deptFormMode.value = "idle";
  selectedDept.value = null;
};

const saveDept = async () => {
  deptFormError.value = "";
  if (!deptFormName.value.trim() || !deptFormCode.value.trim()) {
    deptFormError.value = "Name and code are required.";
    return;
  }
  deptFormSaving.value = true;
  const body = {
    name: deptFormName.value.trim(),
    code: deptFormCode.value.trim().toUpperCase(),
  };
  try {
    if (deptFormMode.value === "create") {
      const res = await post<{ id: string }>("/colleges/departments", body);
      departments.value.push({ id: res.id, ...body });
      snack.value = "Department created.";
    } else if (selectedDept.value) {
      await put(`/colleges/departments/${selectedDept.value.id}`, body);
      const idx = departments.value.findIndex(
        (d) => d.id === selectedDept.value!.id,
      );
      if (idx !== -1)
        departments.value[idx] = {
          id: selectedDept.value.id,
          ...body,
        };
      snack.value = "Department updated.";
    }
    deptFormMode.value = "idle";
    selectedDept.value = null;
  } catch {
    deptFormError.value = "Save failed. Check that you have superadmin access.";
  }
  deptFormSaving.value = false;
};

const confirmDeleteDept = async () => {
  if (!pendingDeleteDept.value) return;
  deleteDeptInFlight.value = true;
  try {
    await apiDelete(`/colleges/departments/${pendingDeleteDept.value.id}`);
    departments.value = departments.value.filter(
      (d) => d.id !== pendingDeleteDept.value!.id,
    );
    if (selectedDept.value?.id === pendingDeleteDept.value.id) {
      selectedDept.value = null;
      deptFormMode.value = "idle";
    }
    snack.value = "Department deleted.";
  } catch {
    snack.value = "Delete failed.";
  }
  pendingDeleteDept.value = null;
  deleteDeptInFlight.value = false;
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
      <h1 class="text-xl font-bold text-gray-900">Departments</h1>
      <button
        class="inline-flex items-center gap-2 px-4 py-2 bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 transition-colors text-sm"
        @click="openCreateDept"
      >
        <Icon name="i-heroicons-plus" class="w-4 h-4" />
        Add Department
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
      <!-- Department list -->
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-100">
          <div class="text-sm font-medium text-gray-700 mb-2">
            All Departments ({{ filteredDepartments.length }})
          </div>
          <div class="relative">
            <Icon
              name="i-heroicons-magnifying-glass"
              class="w-4 h-4 text-gray-400 absolute left-2.5 top-1/2 -translate-y-1/2"
            />
            <input
              v-model="search"
              type="text"
              placeholder="Search departments…"
              class="w-full pl-8 pr-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
            />
          </div>
        </div>
        <div class="max-h-96 overflow-y-auto lg:max-h-none lg:overflow-visible">
          <div v-if="loadingDepts" class="p-4 text-sm text-gray-400">Loading…</div>
          <div
            v-for="dept in paginatedDepartments"
            :key="dept.id"
            class="px-4 py-3 border-b border-gray-50 cursor-pointer hover:bg-gray-50 transition-colors group"
            :class="
              selectedDept?.id === dept.id
                ? 'bg-yellow-50 border-l-2 border-l-yellow-400'
                : ''
            "
            @click="openEditDept(dept)"
          >
            <div class="flex items-center justify-between gap-2">
              <div class="min-w-0">
                <div class="font-medium text-gray-900 text-sm truncate">
                  {{ dept.name }}
                </div>
                <div class="text-xs text-gray-500 mt-0.5">
                  {{ dept.code }}
                </div>
              </div>
              <button
                class="shrink-0 p-1 text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-opacity"
                title="Delete"
                @click.stop="pendingDeleteDept = dept"
              >
                <Icon name="i-heroicons-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
          <div
            v-if="!loadingDepts && filteredDepartments.length === 0"
            class="p-4 text-sm text-gray-400"
          >
            No departments found.
          </div>
        </div>
        <Pagination
          v-if="filteredDepartments.length > 0"
          :page="page"
          :page-size="pageSize"
          :total="filteredDepartments.length"
          :page-size-options="[10, 25, 50, 100]"
          @update:page="page = $event"
          @update:page-size="pageSize = $event"
        />
      </div>

      <!-- Detail / form panel -->
      <div class="md:col-span-2 bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div v-if="deptFormMode === 'idle'" class="p-8 text-center text-gray-400 text-sm">
          Select a department to edit, or click <strong class="text-gray-600">Add Department</strong>.
        </div>
        <template v-else>
          <div class="px-6 py-4 border-b border-gray-100 text-sm font-medium text-gray-700">
            {{ deptFormMode === 'create' ? 'New Department' : `Edit - ${selectedDept?.name}` }}
          </div>
          <div class="flex flex-col p-6 space-y-4">
            <div v-if="deptFormError" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg p-3">
              {{ deptFormError }}
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">Name *</label>
              <input
                v-model="deptFormName"
                type="text"
                placeholder="e.g. Information Technology"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-600 mb-1">Code *</label>
              <input
                v-model="deptFormCode"
                type="text"
                placeholder="e.g. IT"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
              />
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button
                class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                @click="cancelDeptForm"
              >
                Cancel
              </button>
              <button
                :disabled="deptFormSaving"
                class="px-4 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 disabled:opacity-60 transition-colors"
                @click="saveDept"
              >
                {{ deptFormSaving ? 'Saving…' : (deptFormMode === 'create' ? 'Create' : 'Save Changes') }}
              </button>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- Delete Department Confirm Modal -->
    <Modal v-if="pendingDeleteDept" @close="pendingDeleteDept = null">
      <div class="p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-2">
          Delete department?
        </h3>
        <p class="text-sm text-gray-500 mb-4">
          <strong>{{ pendingDeleteDept.name }}</strong> will be soft-deleted. This
          cannot be undone from the admin panel.
        </p>
        <div class="flex justify-end gap-2">
          <button
            class="px-4 py-2 text-sm border border-gray-300 rounded-lg"
            @click="pendingDeleteDept = null"
          >
            Cancel
          </button>
          <button
            :disabled="deleteDeptInFlight"
            class="px-4 py-2 text-sm bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 disabled:opacity-60"
            @click="confirmDeleteDept"
          >
            {{ deleteDeptInFlight ? "Deleting…" : "Delete" }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
