<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface Report {
  id: string;
  resourceId: string;
  reason: string;
  type: string;
  reportedBy: string;
  collegeId?: string;
  status: string;
}

const { get, patch } = useApi();

const reports = ref<Report[]>([]);
const loading = ref(true);
const actionInFlight = ref<Set<string>>(new Set());
const snack = ref("");
const confirmAction = ref<{ report: Report; action: string } | null>(null);

onMounted(async () => {
  reports.value = await get<Report[]>("/admin/reports");
  loading.value = false;
});

const resolve = async (report: Report, action: string) => {
  actionInFlight.value.add(report.id);
  try {
    await patch(`/admin/reports/${report.id}/resolve`, { action });
    reports.value = reports.value.filter((r) => r.id !== report.id);
    snack.value = `Report resolved: ${action.replace("_", " ")}.`;
  } catch (err) {
    console.error("Failed to resolve report", err);
  }
  actionInFlight.value.delete(report.id);
  confirmAction.value = null;
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
    <h1 class="text-xl font-bold text-gray-900 mb-6">Reports</h1>

    <div
      v-if="snack"
      class="mb-4 text-sm text-green-700 bg-green-50 border border-green-200 rounded-lg px-4 py-2 flex justify-between"
    >
      {{ snack }}
      <button @click="snack = ''">
        <Icon name="i-heroicons-x-mark" class="w-4 h-4" />
      </button>
    </div>

    <div v-if="loading" class="text-gray-400 text-sm p-4">Loading…</div>

    <div
      v-else-if="reports.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No pending reports. 🎉
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="report in reports"
        :key="report.id"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <div class="mb-3">
          <div class="font-semibold text-gray-900 text-sm">
            {{ report.reason }}
          </div>
          <div class="text-xs text-gray-500 mt-0.5">
            {{ report.type }} · Resource: {{ report.resourceId }}
          </div>
          <div class="text-xs text-gray-400 mt-0.5">
            Reporter: {{ report.reportedBy }}
          </div>
        </div>

        <div class="flex gap-2 flex-wrap">
          <button
            :disabled="actionInFlight.has(report.id)"
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 disabled:opacity-60 transition-colors"
            @click="resolve(report, 'dismiss')"
          >
            Dismiss
          </button>
          <button
            :disabled="actionInFlight.has(report.id)"
            class="px-3 py-1.5 text-xs font-medium border border-red-300 text-red-600 rounded-lg hover:bg-red-50 disabled:opacity-60 transition-colors"
            @click="confirmAction = { report, action: 'delete_resource' }"
          >
            Delete Resource
          </button>
          <button
            :disabled="actionInFlight.has(report.id)"
            class="px-3 py-1.5 text-xs font-medium bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-60 transition-colors"
            @click="confirmAction = { report, action: 'ban_user' }"
          >
            Ban User
          </button>
        </div>
      </div>
    </div>

    <ConfirmModal
      v-if="confirmAction"
      :title="
        confirmAction.action === 'ban_user'
          ? 'Ban the uploader?'
          : 'Delete this resource?'
      "
      :message="
        confirmAction.action === 'ban_user'
          ? 'This will disable the uploader\'s Firebase Auth account.'
          : 'This will archive the resource and resolve all pending reports for it.'
      "
      :confirm-label="
        confirmAction.action === 'ban_user' ? 'Ban User' : 'Delete Resource'
      "
      danger
      @confirm="resolve(confirmAction!.report, confirmAction!.action)"
      @cancel="confirmAction = null"
    />
  </div>
</template>
