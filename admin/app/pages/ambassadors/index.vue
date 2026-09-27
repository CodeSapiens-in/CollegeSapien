<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
  collegeId?: string;
  collegeName?: string;
}
interface College {
  id: string;
  name: string;
  code: string;
}

const { get, post } = useApi();
const authStore = useAuthStore();

const users = ref<User[]>([]);
const colleges = ref<College[]>([]);
const loading = ref(true);
const showPromoteModal = ref(false);
const selectedUser = ref<User | null>(null);
const selectedCollegeId = ref("");
const actionLoading = ref(false);
const snack = ref("");

const ambassadors = computed(() =>
  users.value.filter((u) => u.role === "ambassador"),
);

onMounted(async () => {
  const [allUsers, allColleges] = await Promise.allSettled([
    get<User[]>("/admin/users"),
    get<College[]>("/colleges"),
  ]);
  if (allUsers.status === "fulfilled") users.value = allUsers.value;
  if (allColleges.status === "fulfilled") colleges.value = allColleges.value;
  loading.value = false;
});

const openPromote = (user: User) => {
  selectedUser.value = user;
  selectedCollegeId.value = user.collegeId ?? "";
  showPromoteModal.value = true;
};

const promote = async () => {
  if (!selectedUser.value) return;
  actionLoading.value = true;
  try {
    await post("/admin/assign-role", {
      uid: selectedUser.value.id,
      role: "ambassador",
    });
    const idx = users.value.findIndex((u) => u.id === selectedUser.value!.id);
    if (idx !== -1) {
      users.value[idx]!.role = "ambassador";
      users.value[idx]!.collegeId = undefined;
    }
    snack.value = `${selectedUser.value.name} promoted to ambassador.`;
    showPromoteModal.value = false;
  } catch (err) {
    console.error("Failed to promote ambassador", err);
  }
  actionLoading.value = false;
};

const revoke = async (user: User) => {
  try {
    await post("/admin/assign-role", { uid: user.id, role: "user" });
    const idx = users.value.findIndex((u) => u.id === user.id);
    if (idx !== -1) users.value[idx]!.role = "user";
    snack.value = `${user.name} revoked from Ambassador role.`;
  } catch (err) {
    console.error("Failed to revoke ambassador", err);
  }
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
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-900">Campus Ambassadors</h1>
        <p class="text-sm text-gray-500 mt-0.5">
          Can upload freely; no moderation powers
        </p>
      </div>
      <button
        v-if="authStore.isSuperAdmin"
        class="px-3 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 transition-colors"
        @click="
          selectedUser = null;
          selectedCollegeId = '';
          showPromoteModal = true;
        "
      >
        Promote User
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

    <div v-if="loading" class="text-gray-400 text-sm">Loading…</div>
    <div
      v-else-if="ambassadors.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No campus ambassadors yet.
    </div>

    <div v-else class="bg-white rounded-xl border border-gray-200 overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-xs text-gray-500 border-b border-gray-100">
            <th class="px-4 py-3 text-left font-medium">Name</th>
            <th class="px-4 py-3 text-left font-medium">Email</th>
            <th class="px-4 py-3 text-left font-medium">College</th>
            <th
              v-if="authStore.isSuperAdmin"
              class="px-4 py-3 text-left font-medium"
            >
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="user in ambassadors"
            :key="user.id"
            class="border-b border-gray-50"
          >
            <td class="px-4 py-3 font-medium text-gray-900">{{ user.name }}</td>
            <td class="px-4 py-3 text-gray-600">{{ user.email }}</td>
            <td class="px-4 py-3 text-gray-500">
              {{ user.collegeName ?? user.collegeId ?? "—" }}
            </td>
            <td v-if="authStore.isSuperAdmin" class="px-4 py-3">
              <div class="flex gap-2">
                <button
                  class="text-xs px-2.5 py-1 border border-gray-300 rounded text-gray-600 hover:bg-gray-50"
                  @click="openPromote(user)"
                >
                  Edit
                </button>
                <button
                  class="text-xs px-2.5 py-1 border border-red-300 text-red-600 rounded hover:bg-red-50"
                  @click="revoke(user)"
                >
                  Revoke
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Promote modal -->
    <Modal v-if="showPromoteModal" @close="showPromoteModal = false">
      <div class="p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-4">
          {{ selectedUser ? `Edit ${selectedUser.name}` : "Promote a User" }}
        </h3>

        <template v-if="!selectedUser">
          <p class="text-xs text-gray-500 mb-2">
            Search users in the
            <NuxtLink to="/users" class="underline">Users page</NuxtLink> and
            click on a user to assign the ambassador role from their profile.
          </p>
        </template>

        <template v-else>
          <p class="text-sm text-gray-600 mb-3">{{ selectedUser.email }}</p>
          <p class="text-xs text-gray-500 mb-4">
            Ambassadors can upload freely and do not require college scope.
          </p>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm border border-gray-300 rounded-lg"
              @click="showPromoteModal = false"
            >
              Close
            </button>
            <button
              :disabled="actionLoading"
              class="px-4 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 disabled:opacity-60"
              @click="promote"
            >
              {{ actionLoading ? "Saving…" : "Confirm Ambassador" }}
            </button>
          </div>
        </template>
      </div>
    </Modal>
  </div>
</template>
