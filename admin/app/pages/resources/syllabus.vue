<script setup lang="ts">
definePageMeta({ layout: "admin", middleware: "auth" });

interface CollegeOption {
  id: string;
  name: string;
  code: string;
}

interface CurriculumSubject {
  semester: number | null;
  subject_code?: string;
  subject_name: string;
  credits?: number | null;
  category?: string;
  elective_type?: string | null;
  record_type?: string;
}

interface CurriculumRecord {
  id: string;
  collegeCode: string;
  courseCode: string;
  regulation: string;
  college: string;
  course: string;
  status: "pending" | "approved";
  fileName?: string | null;
  subjects: CurriculumSubject[];
}

const { get } = useApi();

const colleges = ref<CollegeOption[]>([]);
const approved = ref<CurriculumRecord[]>([]);
const loadingApproved = ref(true);
const detailItem = ref<CurriculumRecord | null>(null);

const filterCollegeCode = ref("");
const filterCourseCode = ref("");
const filterRegulation = ref("");

const buildQuery = (params: Record<string, string>) => {
  const entries = Object.entries(params).filter(([, v]) => v);
  if (entries.length === 0) return "";
  return `?${entries.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join("&")}`;
};

const fetchApproved = async () => {
  loadingApproved.value = true;
  try {
    approved.value = await get<CurriculumRecord[]>(
      `/curriculum/admin${buildQuery({
        collegeCode: filterCollegeCode.value,
        courseCode: filterCourseCode.value,
        regulation: filterRegulation.value,
      })}`,
    );
  } catch (err) {
    console.error("Failed to load approved curricula", err);
  }
  loadingApproved.value = false;
};

onMounted(async () => {
  try {
    colleges.value = await get<CollegeOption[]>("/colleges");
  } catch (err) {
    console.error("Failed to load colleges", err);
  }
  await fetchApproved();
});

watch([filterCollegeCode, filterCourseCode, filterRegulation], fetchApproved);

const availableRegulations = computed(() => {
  const regs = new Set<string>();
  approved.value.forEach((c) => regs.add(c.regulation));
  return [...regs].sort();
});

const approvedPage = ref(1);
const approvedPageSize = ref(25);
const paginatedApproved = computed(() => {
  const start = (approvedPage.value - 1) * approvedPageSize.value;
  return approved.value.slice(start, start + approvedPageSize.value);
});
watch(approved, () => {
  approvedPage.value = 1;
});
watch(approvedPageSize, () => {
  approvedPage.value = 1;
});

const downloadCSV = (item: CurriculumRecord) => {
  const headers = [
    "college",
    "college_code",
    "course",
    "course_code",
    "regulation",
    "semester",
    "subject_code",
    "subject_name",
    "credits",
    "category",
    "elective_type",
    "record_type",
  ];

  const csvEscape = (val: unknown) => {
    if (val === null || val === undefined) return '""';
    const str = String(val);
    if (
      str.includes(",") ||
      str.includes('"') ||
      str.includes("\n") ||
      str.includes("\r")
    ) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const rows = [headers.join(",")];
  item.subjects.forEach((s) => {
    const row = [
      csvEscape(item.college),
      csvEscape(item.collegeCode),
      csvEscape(item.course),
      csvEscape(item.courseCode),
      csvEscape(item.regulation),
      csvEscape(s.semester),
      csvEscape(s.subject_code),
      csvEscape(s.subject_name),
      csvEscape(s.credits),
      csvEscape(s.category),
      csvEscape(s.elective_type),
      csvEscape(s.record_type),
    ];
    rows.push(row.join(","));
  });

  const csvContent = "﻿" + rows.join("\r\n");
  const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.setAttribute("href", url);
  link.setAttribute(
    "download",
    `${item.collegeCode}_${item.courseCode}_${item.regulation}.csv`,
  );
  link.style.visibility = "hidden";
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
};
</script>

<template>
  <div>
    <NuxtLink
      to="/resources"
      class="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-1 mb-2"
    >
      <Icon name="i-heroicons-arrow-left" class="w-3.5 h-3.5" />
      Resources
    </NuxtLink>
    <h1 class="text-xl font-bold text-gray-900 mb-6">Syllabus</h1>

    <!-- Filters -->
    <div class="mb-4 flex flex-wrap gap-3">
      <select
        v-model="filterCollegeCode"
        class="flex-1 min-w-[140px] px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none"
      >
        <option value="">All colleges</option>
        <option v-for="c in colleges" :key="c.id" :value="c.code">
          {{ c.name }}
        </option>
      </select>
      <select
        v-model="filterCourseCode"
        class="flex-1 min-w-[140px] px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none"
      >
        <option value="">All departments</option>
        <option v-for="d in departments" :key="d.code" :value="d.code">
          {{ d.name }}
        </option>
      </select>
      <select
        v-model="filterRegulation"
        class="flex-1 min-w-[140px] px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none"
      >
        <option value="">All regulations</option>
        <option v-for="r in availableRegulations" :key="r" :value="r">
          {{ r }}
        </option>
      </select>
    </div>

    <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div v-if="loadingApproved" class="p-4 text-sm text-gray-400">
        Loading…
      </div>
      <div
        v-else-if="approved.length === 0"
        class="p-8 text-center text-gray-500 text-sm"
      >
        No published curricula yet.
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-400 border-b border-gray-100">
              <th class="py-2 px-4 font-medium">College</th>
              <th class="py-2 px-4 font-medium">Course</th>
              <th class="py-2 px-4 font-medium">Regulation</th>
              <th class="py-2 px-4 font-medium">Subjects</th>
              <th class="py-2 px-4 font-medium w-28">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in paginatedApproved"
              :key="row.id"
              class="border-b border-gray-50 hover:bg-gray-50 cursor-pointer"
              @click="detailItem = row"
            >
              <td class="py-2 px-4 text-gray-900">{{ row.college }}</td>
              <td class="py-2 px-4 text-gray-900">{{ row.course }}</td>
              <td class="py-2 px-4 text-gray-500">{{ row.regulation }}</td>
              <td class="py-2 px-4 text-gray-500">
                {{ row.subjects.length }}
              </td>
              <td class="py-2 px-4 flex gap-2" @click.stop>
                <button
                  class="p-1.5 border border-gray-300 text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors flex items-center justify-center"
                  title="View Details"
                  @click="detailItem = row"
                >
                  <Icon name="i-heroicons-eye" class="w-4 h-4" />
                </button>
                <button
                  class="p-1.5 border border-yellow-300 text-yellow-600 bg-yellow-50 hover:bg-yellow-100 rounded-lg transition-colors flex items-center justify-center"
                  title="Download CSV"
                  @click="downloadCSV(row)"
                >
                  <Icon name="i-heroicons-arrow-down-tray" class="w-4 h-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <Pagination
        v-if="approved.length > 0"
        :page="approvedPage"
        :page-size="approvedPageSize"
        :total="approved.length"
        :page-size-options="[10, 25, 50, 100]"
        @update:page="approvedPage = $event"
        @update:page-size="approvedPageSize = $event"
      />
    </div>

    <SyllabusCurriculumDetail
      v-if="detailItem"
      :curriculum="detailItem"
      read-only
      @close="detailItem = null"
    />
  </div>
</template>
