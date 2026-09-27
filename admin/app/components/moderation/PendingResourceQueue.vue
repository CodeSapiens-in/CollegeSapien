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
  mimeType?: string;
  fileName?: string;
  sizeBytes?: number;
  department?: string;
  semester?: number;
  subjectName?: string;
  keywords?: string[];
  aiSuggestedCategory?: string | null;
  aiSpamFlag?: boolean;
}

const props = defineProps<{
  category: "Notes" | "QP";
}>();

const formatFileSize = (bytes?: number) => {
  if (!bytes) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const fileTypeLabel = (mime?: string) => {
  if (!mime) return "File";
  if (mime === "application/pdf") return "PDF";
  if (mime.startsWith("image/")) return "Image";
  return "File";
};

const { get, patch, delete: apiDelete } = useApi();

const resources = ref<Resource[]>([]);
const loading = ref(true);
const pendingReject = ref<Resource | null>(null);
const rejectReason = ref("");
const actionInFlight = ref<Set<string>>(new Set());
const snack = ref("");

const fetchPending = async () => {
  loading.value = true;
  resources.value = await get<Resource[]>(
    `/admin/resources/pending?category=${props.category}`,
  );
  loading.value = false;
};

onMounted(fetchPending);

const approve = async (id: string) => {
  actionInFlight.value.add(id);
  try {
    await patch(`/admin/resources/${id}/approve`);
    resources.value = resources.value.filter((r) => r.id !== id);
    snack.value = "Resource approved.";
  } catch (err) {
    console.error("Failed to approve resource", err);
  }
  actionInFlight.value.delete(id);
};

const reject = async () => {
  if (!pendingReject.value) return;
  const id = pendingReject.value.id;
  actionInFlight.value.add(id);
  try {
    await patch(
      `/admin/resources/${id}/reject`,
      rejectReason.value ? { reason: rejectReason.value } : {},
    );
    resources.value = resources.value.filter((r) => r.id !== id);
    snack.value = "Resource rejected and archived.";
  } catch (err) {
    console.error("Failed to reject resource", err);
  }
  pendingReject.value = null;
  rejectReason.value = "";
  actionInFlight.value.delete(id);
};

const archive = async (id: string) => {
  actionInFlight.value.add(id);
  try {
    await apiDelete(`/admin/resources/${id}`);
    resources.value = resources.value.filter((r) => r.id !== id);
    snack.value = "Resource archived.";
  } catch (err) {
    console.error("Failed to archive resource", err);
  }
  actionInFlight.value.delete(id);
};
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

    <div v-if="loading" class="text-gray-400 text-sm p-4">Loading…</div>

    <div
      v-else-if="resources.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No pending resources. 🎉
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="resource in resources"
        :key="resource.id"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <!-- Header: name + badges -->
        <div class="flex items-start justify-between gap-2 mb-3">
          <div class="font-semibold text-gray-900 text-sm">
            {{ resource.name }}
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span
              v-if="resource.aiSpamFlag"
              class="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full"
              >AI: Spam</span
            >
            <span
              class="text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded-full"
              >Pending</span
            >
          </div>
        </div>

        <!-- Metadata -->
        <div class="text-xs text-gray-500 space-y-1 mb-3">
          <div>
            {{ resource.category }}
            <span v-if="resource.department"> · {{ resource.department }}</span>
            <span v-if="resource.semester"> · Sem {{ resource.semester }}</span>
          </div>
          <div v-if="resource.subjectName">{{ resource.subjectName }}</div>
          <div>By {{ resource.uploaderName ?? resource.uploadedBy }}</div>
          <div
            v-if="resource.fileName || resource.sizeBytes"
            class="flex items-center gap-1 text-gray-400"
          >
            <Icon name="i-heroicons-document" class="w-3.5 h-3.5" />
            <span>{{
              resource.fileName ?? fileTypeLabel(resource.mimeType)
            }}</span>
            <span v-if="resource.sizeBytes">
              · {{ formatFileSize(resource.sizeBytes) }}</span
            >
          </div>
        </div>

        <!-- AI analysis -->
        <div
          v-if="
            resource.aiSuggestedCategory &&
            resource.aiSuggestedCategory !== resource.category
          "
          class="text-xs text-amber-600 mb-3"
        >
          AI suggests: {{ resource.aiSuggestedCategory }} (mismatch)
        </div>

        <!-- Keywords -->
        <div v-if="resource.keywords?.length" class="flex flex-wrap gap-1 mb-3">
          <span
            v-for="kw in resource.keywords"
            :key="kw"
            class="text-xs bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded"
            >{{ kw }}</span
          >
        </div>

        <!-- Actions -->
        <div class="flex gap-2 flex-wrap">
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
            :disabled="actionInFlight.has(resource.id)"
            class="px-3 py-1.5 text-xs font-medium bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
            @click="approve(resource.id)"
          >
            Approve
          </button>
          <button
            :disabled="actionInFlight.has(resource.id)"
            class="px-3 py-1.5 text-xs font-medium border border-red-300 text-red-600 rounded-lg hover:bg-red-50 disabled:opacity-60 transition-colors"
            @click="
              pendingReject = resource;
              rejectReason = '';
            "
          >
            Reject
          </button>
          <button
            :disabled="actionInFlight.has(resource.id)"
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 disabled:opacity-60 transition-colors"
            @click="archive(resource.id)"
          >
            Archive
          </button>
        </div>
      </div>
    </div>

    <!-- Reject modal -->
    <Modal v-if="pendingReject" @close="pendingReject = null">
      <div class="p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-2">
          Reject resource
        </h3>
        <p class="text-sm text-gray-500 mb-3">{{ pendingReject.name }}</p>
        <textarea
          v-model="rejectReason"
          placeholder="Reason (optional)"
          rows="3"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm resize-none focus:outline-none mb-4"
        />
        <div class="flex justify-end gap-2">
          <button
            class="px-4 py-2 text-sm border border-gray-300 rounded-lg"
            @click="pendingReject = null"
          >
            Cancel
          </button>
          <button
            class="px-4 py-2 text-sm bg-red-600 text-white font-medium rounded-lg hover:bg-red-700"
            @click="reject"
          >
            Reject & Archive
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
