<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface User {
  id: string;
  uid?: string;
  name: string;
  email: string;
  role: string;
  collegeId?: string;
  collegeName?: string;
  isVerified?: boolean;
  createdAt?: string;
}

const { get } = useApi();

const users = ref<User[]>([]);
const loading = ref(true);
const search = ref("");
const roleFilter = ref("all");
const page = ref(1);
const pageSize = ref(25);

onMounted(async () => {
  users.value = await get<User[]>("/admin/users");
  loading.value = false;
});

const filtered = computed(() =>
  users.value.filter((u) => {
    const q = search.value.toLowerCase();
    const matchSearch =
      !q ||
      u.name.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q);
    const matchRole = roleFilter.value === "all" || u.role === roleFilter.value;
    return matchSearch && matchRole;
  }),
);

watch([search, roleFilter, pageSize], () => {
  page.value = 1;
});

const totalPages = computed(() =>
  Math.max(1, Math.ceil(filtered.value.length / pageSize.value)),
);

const paginated = computed(() => {
  const start = (page.value - 1) * pageSize.value;
  return filtered.value.slice(start, start + pageSize.value);
});
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-6">Users</h1>

    <div class="bg-white rounded-xl border border-gray-200">
      <div class="p-4 border-b border-gray-100 flex gap-3 flex-wrap">
        <input
          v-model="search"
          placeholder="Search by name or email…"
          class="w-full sm:flex-1 sm:min-w-48 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
        />
        <select
          v-model="roleFilter"
          class="w-full sm:w-auto px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none"
        >
          <option value="all">All roles</option>
          <option value="user">User</option>
          <option value="moderator">Moderator</option>
          <option value="admin">Admin</option>
          <option value="superadmin">Superadmin</option>
        </select>
      </div>

      <div v-if="loading" class="p-8 text-center text-gray-400 text-sm">
        Loading…
      </div>
      <div
        v-else-if="filtered.length === 0"
        class="p-8 text-center text-gray-400 text-sm"
      >
        No users found.
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-gray-500 border-b border-gray-100">
              <th class="px-4 py-3 text-left font-medium">Name</th>
              <th class="px-4 py-3 text-left font-medium">Email</th>
              <th class="px-4 py-3 text-left font-medium">Role</th>
              <th class="px-4 py-3 text-left font-medium">College</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="user in paginated"
              :key="user.id"
              class="border-b border-gray-50 hover:bg-gray-50 cursor-pointer"
              @click="navigateTo(`/users/${user.id}`)"
            >
              <td class="px-4 py-3 font-medium text-gray-900">{{ user.name }}</td>
              <td class="px-4 py-3 text-gray-600">{{ user.email }}</td>
              <td class="px-4 py-3"><RoleBadge :role="user.role" /></td>
              <td class="px-4 py-3 text-gray-500">
                {{ user.collegeName ?? user.collegeId ?? "—" }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div
        class="px-4 py-3 border-t border-gray-100 flex items-center justify-between flex-wrap gap-3"
      >
        <div class="text-xs text-gray-400">
          {{ filtered.length }} of {{ users.length }} users
        </div>
        <div class="flex items-center gap-3 text-xs text-gray-500">
          <label class="flex items-center gap-1">
            Page size
            <select
              v-model.number="pageSize"
              class="px-2 py-1 border border-gray-300 rounded-lg focus:outline-none"
            >
              <option :value="10">10</option>
              <option :value="25">25</option>
              <option :value="50">50</option>
              <option :value="100">100</option>
            </select>
          </label>
          <div class="flex items-center gap-2">
            <button
              class="px-2 py-1 border border-gray-300 rounded-lg disabled:opacity-40"
              :disabled="page <= 1"
              @click="page--"
            >
              Prev
            </button>
            <span>Page {{ page }} of {{ totalPages }}</span>
            <button
              class="px-2 py-1 border border-gray-300 rounded-lg disabled:opacity-40"
              :disabled="page >= totalPages"
              @click="page++"
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
