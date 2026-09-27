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

const { get } = useApi();

const events = ref<EventItem[]>([]);
const loading = ref(true);
const loadError = ref("");

const fetchEvents = async () => {
  loading.value = true;
  loadError.value = "";
  try {
    events.value = await get<EventItem[]>("/events");
  } catch (err) {
    console.error("Failed to load events", err);
    loadError.value = "Couldn't load events. Please try again.";
  } finally {
    loading.value = false;
  }
};

onMounted(fetchEvents);
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-6">Events</h1>

    <div v-if="loading" class="text-gray-400 text-sm p-4">Loading…</div>

    <div
      v-else-if="loadError"
      class="bg-white rounded-xl border border-red-200 p-8 text-center text-sm"
    >
      <p class="text-red-600 mb-3">{{ loadError }}</p>
      <button
        class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
        @click="fetchEvents"
      >
        Retry
      </button>
    </div>

    <div
      v-else-if="events.length === 0"
      class="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500 text-sm"
    >
      No events yet.
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="event in events"
        :key="event.id"
        class="bg-white rounded-xl border border-gray-200 p-5"
      >
        <div class="font-semibold text-gray-900 text-sm mb-3">
          {{ event.eventName }}
        </div>

        <div class="text-xs text-gray-500 space-y-1 mb-3">
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

        <a
          :href="event.eventLink"
          target="_blank"
          rel="noopener noreferrer"
          class="px-3 py-1.5 text-xs font-medium border border-blue-300 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors inline-flex items-center gap-1"
        >
          <Icon
            name="i-heroicons-arrow-top-right-on-square"
            class="w-3.5 h-3.5"
          />
          Open Link
        </a>
      </div>
    </div>
  </div>
</template>
