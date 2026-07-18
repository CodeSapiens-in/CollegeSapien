<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface EventItem {
  id: string;
  eventName: string;
  location: string;
  communityName: string;
  communityLogo?: string;
  eventLink: string;
  eventDate: string;
  createdBy?: string;
}

const { get, patch } = useApi();

const events = ref<EventItem[]>([]);
const loading = ref(true);
const pendingReject = ref<EventItem | null>(null);
const rejectReason = ref("");
const actionInFlight = ref<Set<string>>(new Set());
const snack = ref("");
const editing = ref<Map<string, EventItem>>(new Map());

const fetchPending = async () => {
  loading.value = true;
  events.value = await get<EventItem[]>("/events/pending");
  loading.value = false;
};

onMounted(fetchPending);

const startEdit = (event: EventItem) => {
  editing.value.set(event.id, { ...event });
};

const cancelEdit = (id: string) => {
  editing.value.delete(id);
};

const approve = async (id: string) => {
  actionInFlight.value.add(id);
  try {
    const edited = editing.value.get(id);
    const body = edited
      ? {
          eventName: edited.eventName,
          location: edited.location,
          communityName: edited.communityName,
          communityLogo: edited.communityLogo,
          eventLink: edited.eventLink,
          eventDate: edited.eventDate,
        }
      : {};
    await patch(`/events/${id}/approve`, body);
    events.value = events.value.filter((e) => e.id !== id);
    editing.value.delete(id);
    snack.value = "Event approved.";
  } catch (err) {
    console.error("Failed to approve event", err);
  }
  actionInFlight.value.delete(id);
};

const reject = async () => {
  if (!pendingReject.value) return;
  const id = pendingReject.value.id;
  actionInFlight.value.add(id);
  try {
    await patch(
      `/events/${id}/reject`,
      rejectReason.value ? { reason: rejectReason.value } : {},
    );
    events.value = events.value.filter((e) => e.id !== id);
    snack.value = "Event rejected.";
  } catch (err) {
    console.error("Failed to reject event", err);
  }
  pendingReject.value = null;
  rejectReason.value = "";
  actionInFlight.value.delete(id);
};
</script>

<template>
  <div>
    <div class="flex items-center justify-between gap-3 flex-wrap mb-6">
      <h1 class="text-xl font-bold text-gray-900">Events Moderation</h1>
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

    <div v-if="loading" class="text-gray-400 text-sm p-4">Loading…</div>

    <div
      v-else-if="events.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No pending events. 🎉
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="event in events"
        :key="event.id"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <!-- Header: name + badge -->
        <div class="flex items-start justify-between gap-2 mb-3">
          <div class="font-semibold text-gray-900 text-sm">
            {{ event.eventName }}
          </div>
          <span
            class="text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded-full shrink-0"
            >Pending</span
          >
        </div>

        <!-- Metadata (read-only) -->
        <div
          v-if="!editing.has(event.id)"
          class="text-xs text-gray-500 space-y-1 mb-3"
        >
          <div class="flex items-center gap-1">
            <Icon
              v-if="event.communityLogo"
              name="i-heroicons-photo"
              class="w-3.5 h-3.5"
            />
            {{ event.communityName }}
          </div>
          <div>{{ event.location }}</div>
          <div>{{ event.eventDate }}</div>
        </div>

        <!-- Edit form -->
        <div v-else class="space-y-2 mb-3">
          <input
            v-model="editing.get(event.id)!.eventName"
            placeholder="Event name"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
          <input
            v-model="editing.get(event.id)!.communityName"
            placeholder="Community"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
          <input
            v-model="editing.get(event.id)!.communityLogo"
            placeholder="Community logo URL"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
          <input
            v-model="editing.get(event.id)!.location"
            placeholder="Location"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
          <input
            v-model="editing.get(event.id)!.eventDate"
            placeholder="Event date"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
          <input
            v-model="editing.get(event.id)!.eventLink"
            placeholder="Event link"
            class="w-full px-2 py-1 text-xs border border-gray-300 rounded"
          />
        </div>

        <!-- Actions -->
        <div class="flex gap-2 flex-wrap">
          <a
            :href="event.eventLink"
            target="_blank"
            rel="noopener noreferrer"
            class="px-3 py-1.5 text-xs font-medium border border-blue-300 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-1"
          >
            <Icon
              name="i-heroicons-arrow-top-right-on-square"
              class="w-3.5 h-3.5"
            />
            Open Link
          </a>
          <button
            v-if="!editing.has(event.id)"
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            @click="startEdit(event)"
          >
            Edit
          </button>
          <button
            v-else
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            @click="cancelEdit(event.id)"
          >
            Cancel edit
          </button>
          <button
            :disabled="actionInFlight.has(event.id)"
            class="px-3 py-1.5 text-xs font-medium bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
            @click="approve(event.id)"
          >
            Approve
          </button>
          <button
            :disabled="actionInFlight.has(event.id)"
            class="px-3 py-1.5 text-xs font-medium border border-red-300 text-red-600 rounded-lg hover:bg-red-50 disabled:opacity-60 transition-colors"
            @click="
              pendingReject = event;
              rejectReason = '';
            "
          >
            Reject
          </button>
        </div>
      </div>
    </div>

    <!-- Reject modal -->
    <Modal v-if="pendingReject" @close="pendingReject = null">
      <div class="p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-2">Reject event</h3>
        <p class="text-sm text-gray-500 mb-3">{{ pendingReject.eventName }}</p>
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
            Reject
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
