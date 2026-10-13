<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

const AREAS = ["R", "I", "A", "S", "E", "C"] as const;
const AREA_NAMES: Record<string, string> = {
  R: "Realistic", I: "Investigative", A: "Artistic",
  S: "Social", E: "Enterprising", C: "Conventional",
};

interface Entry {
  id: string;
  email: string;
  answers: Record<string, number> | null;
  scores: Record<string, number> | null;
  top: string[];
  createdAt: string | null;
  updatedAt: string | null;
}

const { get } = useApi();
const entries = ref<Entry[]>([]);
const loading = ref(true);
const loadError = ref("");
const search = ref("");
const quizOnly = ref(false);
const open = ref<string | null>(null);

onMounted(async () => {
  try {
    entries.value = await get<Entry[]>("/campus/waitlist");
  } catch {
    loadError.value = "Couldn't load the waitlist. Superadmin access is required.";
  } finally {
    loading.value = false;
  }
});

const filtered = computed(() => {
  const q = search.value.toLowerCase();
  return entries.value.filter(
    (e) => (!q || e.email.includes(q)) && (!quizOnly.value || e.scores),
  );
});

const day = (iso: string | null) => (iso ? iso.slice(0, 10) : "—");

const exportCsv = () => {
  const ids = AREAS.flatMap((a) => [1, 2, 3, 4, 5].map((n) => `${a}${n}`));
  const rows = [
    ["email", "joined", ...AREAS, "top", ...ids],
    ...filtered.value.map((e) => [
      e.email, day(e.createdAt),
      ...AREAS.map((a) => e.scores?.[a] ?? ""),
      e.top.join("+"),
      ...ids.map((id) => e.answers?.[id] ?? ""),
    ]),
  ];
  // Prefix risky leading characters so spreadsheet apps don't run emails as formulas.
  const cell = (v: unknown) => `"${String(v).replace(/^[=+\-@]/, "'$&").replace(/"/g, '""')}"`;
  const blob = new Blob([rows.map((r) => r.map(cell).join(",")).join("\n")], { type: "text/csv" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `campus-waitlist-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
};
</script>

<template>
  <div>
    <h1 class="text-xl font-bold text-gray-900 mb-6">Campus Waitlist</h1>

    <div class="bg-white rounded-xl border border-gray-200">
      <div class="p-4 border-b border-gray-100 flex gap-3 flex-wrap items-center">
        <input
          v-model="search"
          placeholder="Search by email…"
          class="w-full sm:flex-1 sm:min-w-48 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
        />
        <label class="flex items-center gap-2 text-sm text-gray-600">
          <input v-model="quizOnly" type="checkbox" /> Took the quiz
        </label>
        <button
          class="px-3 py-2 text-xs font-medium border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
          :disabled="!filtered.length"
          @click="exportCsv"
        >
          Export CSV
        </button>
      </div>

      <div v-if="loading" class="p-8 text-center text-gray-400 text-sm">Loading…</div>
      <div v-else-if="loadError" class="p-8 text-center text-red-600 text-sm">{{ loadError }}</div>
      <div v-else-if="!filtered.length" class="p-8 text-center text-gray-400 text-sm">
        No signups found.
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-gray-500 border-b border-gray-100">
              <th class="px-4 py-3 text-left font-medium">Email</th>
              <th class="px-4 py-3 text-left font-medium">Joined</th>
              <th v-for="a in AREAS" :key="a" class="px-2 py-3 text-center font-medium" :title="AREA_NAMES[a]">{{ a }}</th>
              <th class="px-4 py-3 text-left font-medium">Top</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="e in filtered" :key="e.id">
              <tr
                class="border-b border-gray-50 hover:bg-gray-50"
                :class="e.answers ? 'cursor-pointer' : ''"
                @click="e.answers && (open = open === e.id ? null : e.id)"
              >
                <td class="px-4 py-3 text-gray-900">{{ e.email }}</td>
                <td class="px-4 py-3 text-gray-500">{{ day(e.createdAt) }}</td>
                <td v-for="a in AREAS" :key="a" class="px-2 py-3 text-center text-gray-700">
                  {{ e.scores?.[a] ?? "—" }}
                </td>
                <td class="px-4 py-3 text-gray-500">{{ e.top.join(" + ") || "—" }}</td>
              </tr>
              <tr v-if="open === e.id && e.answers" class="bg-gray-50">
                <td :colspan="9" class="px-4 py-3">
                  <div class="grid grid-cols-6 gap-x-4 gap-y-1 text-xs text-gray-600 max-w-md">
                    <template v-for="a in AREAS" :key="a">
                      <div v-for="n in 5" :key="a + n" class="font-mono">
                        {{ a }}{{ n }}: <strong>{{ e.answers[a + n] }}</strong>
                      </div>
                    </template>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
      <div class="px-4 py-3 border-t border-gray-100 text-xs text-gray-400">
        {{ filtered.length }} of {{ entries.length }} signups · answers: 0 = Not for me, 1 = Maybe, 2 = I'd love it
      </div>
    </div>
  </div>
</template>
