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

interface UploadRowError {
  fileName?: string;
  error: string;
}

interface UploadConflict {
  fileName?: string;
  collegeCode: string;
  courseCode: string;
  regulation: string;
  existsIn: "pending" | "approved" | "both";
}

const { get, post, patch, delete: apiDelete } = useApi();
const authStore = useAuthStore();
const isAmbassador = computed(() => authStore.user?.role === "ambassador");

const colleges = ref<CollegeOption[]>([]);
const snack = ref("");
const uploadErrors = ref<UploadRowError[]>([]);
const uploading = ref(false);
const isDragOver = ref(false);

const pending = ref<CurriculumRecord[]>([]);
const approved = ref<CurriculumRecord[]>([]);
const loadingPending = ref(true);
const loadingApproved = ref(true);

const pendingUploadItems = ref<{ fileName: string; data: any }[]>([]);
const uploadConflicts = ref<UploadConflict[]>([]);
const confirmingOverwrite = ref(false);

const selectedPending = ref<Set<string>>(new Set());
const batchInFlight = ref(false);
const singleInFlight = ref<Set<string>>(new Set());

const activeTab = ref<"pending" | "approved">("approved");
const detailItem = ref<CurriculumRecord | null>(null);
const savingEdit = ref(false);
const showGuideModal = ref(false);

const filterCollegeCode = ref("");
const filterCourseCode = ref("");
const filterRegulation = ref("");

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

const buildQuery = (params: Record<string, string>) => {
  const entries = Object.entries(params).filter(([, v]) => v);
  if (entries.length === 0) return "";
  return `?${entries.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join("&")}`;
};

const fetchPending = async () => {
  loadingPending.value = true;
  try {
    pending.value = await get<CurriculumRecord[]>(
      `/curriculum/pending${buildQuery({
        collegeCode: filterCollegeCode.value,
        courseCode: filterCourseCode.value,
        regulation: filterRegulation.value,
      })}`,
    );
  } catch (err) {
    console.error("Failed to load pending curricula", err);
  }
  loadingPending.value = false;
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
  await Promise.all([fetchPending(), fetchApproved()]);
});

watch([filterCollegeCode, filterCourseCode, filterRegulation], () => {
  fetchPending();
  fetchApproved();
});

const readFileAsText = (file: File): Promise<string> =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error);
    reader.readAsText(file);
  });

const parseCSV = (text: string): any => {
  const lines: string[] = [];
  let currentLine = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const nextChar = text[i + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        currentLine += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "\n" || char === "\r") {
      if (inQuotes) {
        currentLine += char;
      } else {
        if (char === "\r" && nextChar === "\n") {
          i++;
        }
        lines.push(currentLine);
        currentLine = "";
      }
    } else {
      currentLine += char;
    }
  }
  if (currentLine) {
    lines.push(currentLine);
  }

  if (lines.length < 2) {
    throw new Error("CSV must contain a header and at least one data row");
  }

  const splitLine = (line: string): string[] => {
    const result: string[] = [];
    let current = "";
    let inside = false;
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      if (char === '"') {
        inside = !inside;
      } else if (char === "," && !inside) {
        result.push(current.trim());
        current = "";
      } else {
        current += char;
      }
    }
    result.push(current.trim());
    return result;
  };

  const headers = splitLine(lines[0]);
  const expectedHeaders = [
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

  const indices: Record<string, number> = {};
  expectedHeaders.forEach((h) => {
    indices[h] = headers.findIndex(
      (header) =>
        header.trim().toLowerCase().replace(/[-_]/g, "") ===
        h.replace(/[-_]/g, ""),
    );
  });

  if (
    indices["college_code"] === -1 ||
    indices["course_code"] === -1 ||
    indices["regulation"] === -1
  ) {
    throw new Error(
      "Missing required headers: college_code, course_code, regulation",
    );
  }

  const firstDataRow = splitLine(lines[1]);
  const getValue = (row: string[], field: string) => {
    const idx = indices[field];
    return idx !== -1 && idx < row.length ? row[idx] : "";
  };

  const college = getValue(firstDataRow, "college");
  const college_code = getValue(firstDataRow, "college_code");
  const course = getValue(firstDataRow, "course");
  const course_code = getValue(firstDataRow, "course_code");
  const regulation = getValue(firstDataRow, "regulation");

  if (!college_code || !course_code || !regulation) {
    throw new Error(
      "First row must have non-empty college_code, course_code, and regulation",
    );
  }

  const subjects: any[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;
    const row = splitLine(line);
    const subject_name = getValue(row, "subject_name");
    if (!subject_name) continue;

    const semStr = getValue(row, "semester");
    const semVal = semStr ? Number(semStr) : null;
    const creditsStr = getValue(row, "credits");
    const creditsVal = creditsStr ? Number(creditsStr) : null;

    subjects.push({
      semester: Number.isNaN(semVal) ? null : semVal,
      subject_code: getValue(row, "subject_code") || "",
      subject_name: subject_name,
      credits: Number.isNaN(creditsVal) ? null : creditsVal,
      category: getValue(row, "category") || "",
      elective_type: getValue(row, "elective_type") || null,
      record_type: getValue(row, "record_type") || "core",
    });
  }

  return {
    college,
    college_code,
    course,
    course_code,
    regulation,
    subjects,
  };
};

const handleFiles = async (fileList: FileList | null) => {
  if (!fileList || fileList.length === 0) return;
  uploading.value = true;
  uploadErrors.value = [];

  const items: { fileName: string; data: unknown }[] = [];
  for (const file of Array.from(fileList)) {
    try {
      const text = await readFileAsText(file);
      let data: any;
      if (file.name.endsWith(".csv")) {
        data = parseCSV(text);
      } else {
        data = JSON.parse(text);
      }

      if (
        !data?.college_code ||
        !data?.course_code ||
        !data?.regulation ||
        !Array.isArray(data?.subjects)
      ) {
        uploadErrors.value.push({
          fileName: file.name,
          error: "Missing college_code, course_code, regulation, or subjects[]",
        });
        continue;
      }
      items.push({ fileName: file.name, data });
    } catch (err: any) {
      uploadErrors.value.push({
        fileName: file.name,
        error: err.message || "Invalid file content",
      });
    }
  }

  if (items.length > 0) {
    await submitItems(items, []);
  }

  uploading.value = false;
};

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

  const csvContent = "\ufeff" + rows.join("\r\n");
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

const handleDeleteCurriculum = async (id: string) => {
  if (isAmbassador.value) {
    alert("Ambassadors do not have permission to delete curricula.");
    return;
  }
  if (
    !confirm(
      "Are you sure you want to delete this curriculum? This action is permanent and cannot be undone.",
    )
  )
    return;
  try {
    await apiDelete(`/curriculum/admin/${id}`);
    approved.value = approved.value.filter((item) => item.id !== id);
    detailItem.value = null;
    snack.value = "Curriculum deleted successfully.";
  } catch (err) {
    console.error("Failed to delete curriculum", err);
    snack.value = "Failed to delete curriculum.";
  }
};

type UploadResult =
  | {
      fileName?: string;
      id: string;
      collegeCode: string;
      courseCode: string;
      regulation: string;
      subjectCount: number;
    }
  | { fileName?: string; error: unknown }
  | (UploadConflict & { conflict: true });

const submitItems = async (
  items: { fileName: string; data: unknown }[],
  overwriteKeys: string[],
) => {
  try {
    const res = await post<{ results: UploadResult[] }>("/curriculum/pending", {
      items,
      overwriteKeys,
    });

    const failures = res.results.filter(
      (r): r is { fileName?: string; error: unknown } => "error" in r,
    );
    const conflicts = res.results.filter(
      (r): r is UploadConflict & { conflict: true } => "conflict" in r,
    );

    if (failures.length > 0) {
      uploadErrors.value.push(
        ...failures.map((f) => ({
          fileName: f.fileName,
          error: JSON.stringify(f.error),
        })),
      );
    }

    if (conflicts.length > 0) {
      pendingUploadItems.value = items;
      uploadConflicts.value = conflicts;
      return;
    }

    const successCount = res.results.length - failures.length;
    if (successCount > 0) {
      snack.value = `${successCount} file(s) uploaded for review.`;
    }
    await fetchPending();
  } catch (err) {
    console.error("Upload failed", err);
    uploadErrors.value.push({ error: "Upload request failed." });
  }
};

const conflictExistsInLabel = (existsIn: UploadConflict["existsIn"]) => {
  if (existsIn === "both") return "pending review and already approved";
  if (existsIn === "approved") return "already approved";
  return "pending review";
};

const confirmOverwrite = async () => {
  confirmingOverwrite.value = true;
  const overwriteKeys = uploadConflicts.value.map(
    (c) => `${c.collegeCode}|${c.courseCode}|${c.regulation}`,
  );
  const items = pendingUploadItems.value;
  uploadConflicts.value = [];
  pendingUploadItems.value = [];
  await submitItems(items, overwriteKeys);
  confirmingOverwrite.value = false;
};

const cancelOverwrite = () => {
  uploadConflicts.value = [];
  pendingUploadItems.value = [];
};

const onDrop = (e: DragEvent) => {
  isDragOver.value = false;
  handleFiles(e.dataTransfer?.files ?? null);
};

const onFileInput = (e: Event) => {
  const target = e.target as HTMLInputElement;
  handleFiles(target.files);
  target.value = "";
};

const toggleSelected = (id: string) => {
  if (selectedPending.value.has(id)) selectedPending.value.delete(id);
  else selectedPending.value.add(id);
};

const approveIds = async (ids: string[]) => {
  if (ids.length === 0) return;
  batchInFlight.value = true;
  try {
    const res = await post<{ approved: string[]; failed: unknown[] }>(
      "/curriculum/pending/approve",
      { ids },
    );
    pending.value = pending.value.filter((p) => !res.approved.includes(p.id));
    res.approved.forEach((id) => selectedPending.value.delete(id));
    snack.value = `${res.approved.length} curriculum(s) approved.`;
    await fetchApproved();
  } catch (err) {
    console.error("Approve failed", err);
  }
  batchInFlight.value = false;
};

const rejectIds = async (ids: string[]) => {
  if (ids.length === 0) return;
  batchInFlight.value = true;
  try {
    await post("/curriculum/pending/reject", { ids });
    pending.value = pending.value.filter((p) => !ids.includes(p.id));
    ids.forEach((id) => selectedPending.value.delete(id));
    snack.value = `${ids.length} curriculum(s) rejected.`;
  } catch (err) {
    console.error("Reject failed", err);
  }
  batchInFlight.value = false;
};

const approveOne = async (id: string) => {
  singleInFlight.value.add(id);
  await approveIds([id]);
  singleInFlight.value.delete(id);
  if (detailItem.value?.id === id) detailItem.value = null;
};

const rejectOne = async (id: string) => {
  singleInFlight.value.add(id);
  await rejectIds([id]);
  singleInFlight.value.delete(id);
  if (detailItem.value?.id === id) detailItem.value = null;
};

const availableRegulations = computed(() => {
  const regs = new Set<string>();
  [...pending.value, ...approved.value].forEach((c) => regs.add(c.regulation));
  return [...regs].sort();
});

const handleSaveEdit = async (payload: {
  id: string;
  status: "pending" | "approved";
  college: string;
  collegeCode: string;
  course: string;
  courseCode: string;
  regulation: string;
  subjects: CurriculumSubject[];
}) => {
  savingEdit.value = true;
  const path =
    payload.status === "pending"
      ? `/curriculum/pending/${payload.id}`
      : `/curriculum/admin/${payload.id}`;
  try {
    const updated = await patch<CurriculumRecord>(path, {
      college: payload.college,
      collegeCode: payload.collegeCode,
      course: payload.course,
      courseCode: payload.courseCode,
      regulation: payload.regulation,
      subjects: payload.subjects,
    });

    const list = payload.status === "pending" ? pending : approved;
    const idx = list.value.findIndex((c) => c.id === payload.id);
    if (idx !== -1) {
      if (updated.id !== payload.id) list.value.splice(idx, 1);
      else list.value[idx] = updated;
    }
    if (updated.id !== payload.id) list.value.push(updated);

    detailItem.value = updated;
    snack.value = "Curriculum updated.";
  } catch (err) {
    console.error("Failed to save curriculum edit", err);
    snack.value = "Failed to save changes.";
  }
  savingEdit.value = false;
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
    <div class="mb-6 flex justify-between items-start">
      <div>
        <h1 class="text-xl font-bold text-gray-900">Syllabus Moderation</h1>
        <p class="text-sm text-gray-500 mt-0.5">
          Upload curriculum JSON or CSV files, review, and publish to the app.
        </p>
      </div>
      <button
        class="inline-flex items-center gap-1.5 px-3 py-1.5 border border-yellow-400 text-yellow-800 bg-yellow-50 hover:bg-yellow-100 font-medium rounded-lg transition-colors text-xs"
        @click="showGuideModal = true"
      >
        <Icon name="i-heroicons-question-mark-circle" class="w-4 h-4" />
        Upload Guide
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

    <!-- Upload zone -->
    <div
      class="mb-6 bg-white rounded-xl border-2 border-dashed p-6 sm:p-8 text-center transition-colors"
      :class="isDragOver ? 'border-yellow-400 bg-yellow-50' : 'border-gray-200'"
      @dragover.prevent="isDragOver = true"
      @dragleave.prevent="isDragOver = false"
      @drop.prevent="onDrop"
    >
      <Icon
        name="i-heroicons-arrow-up-tray"
        class="w-8 h-8 mx-auto text-gray-400 mb-2"
      />
      <p class="text-sm text-gray-600 mb-3">
        Drag &amp; drop one or more curriculum JSON or CSV files here, or
      </p>
      <label
        class="inline-flex items-center gap-2 px-4 py-2 bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 transition-colors text-sm cursor-pointer"
      >
        <Icon name="i-heroicons-folder-open" class="w-4 h-4" />
        Browse files
        <input
          type="file"
          accept="application/json, text/csv"
          multiple
          class="hidden"
          @change="onFileInput"
        />
      </label>
      <p v-if="uploading" class="text-xs text-gray-400 mt-3">Uploading…</p>
    </div>

    <div
      v-if="uploadErrors.length > 0"
      class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4 text-sm text-red-700"
    >
      <div class="font-medium mb-1">Some files failed to parse:</div>
      <ul class="list-disc list-inside space-y-0.5">
        <li v-for="(e, idx) in uploadErrors" :key="idx">
          {{ e.fileName ?? "Unknown file" }}: {{ e.error }}
        </li>
      </ul>
    </div>

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

    <!-- Tabs -->
    <div class="flex gap-1 mb-4 border-b border-gray-200">
      <button
        class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
        :class="
          activeTab === 'approved'
            ? 'border-yellow-400 text-gray-900'
            : 'border-transparent text-gray-400 hover:text-gray-600'
        "
        @click="activeTab = 'approved'"
      >
        Approved ({{ approved.length }})
      </button>
      <button
        class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
        :class="
          activeTab === 'pending'
            ? 'border-yellow-400 text-gray-900'
            : 'border-transparent text-gray-400 hover:text-gray-600'
        "
        @click="activeTab = 'pending'"
      >
        Pending review ({{ pending.length }})
      </button>
    </div>

    <!-- Pending table -->
    <div v-if="activeTab === 'pending'">
      <div
        v-if="selectedPending.size > 0"
        class="mb-3 flex items-center gap-2 flex-wrap"
      >
        <span class="text-sm text-gray-600"
          >{{ selectedPending.size }} selected</span
        >
        <button
          v-if="!isAmbassador"
          :disabled="batchInFlight"
          class="px-3 py-1.5 text-xs font-medium bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
          @click="approveIds([...selectedPending])"
        >
          Approve selected
        </button>
        <button
          :disabled="batchInFlight"
          class="px-3 py-1.5 text-xs font-medium border border-red-300 text-red-600 rounded-lg hover:bg-red-50 disabled:opacity-60 transition-colors"
          @click="rejectIds([...selectedPending])"
        >
          Reject selected
        </button>
      </div>

      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div v-if="loadingPending" class="p-4 text-sm text-gray-400">
          Loading…
        </div>
        <div
          v-else-if="pending.length === 0"
          class="p-8 text-center text-gray-500 text-sm"
        >
          No pending uploads.
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-gray-400 border-b border-gray-100">
                <th class="py-2 px-4 font-medium w-8"></th>
                <th class="py-2 px-4 font-medium">File</th>
                <th class="py-2 px-4 font-medium">College</th>
                <th class="py-2 px-4 font-medium">Course</th>
                <th class="py-2 px-4 font-medium">Regulation</th>
                <th class="py-2 px-4 font-medium">Subjects</th>
                <th class="py-2 px-4 font-medium w-20">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in pending"
                :key="row.id"
                class="border-b border-gray-50 hover:bg-gray-50 cursor-pointer"
                @click="detailItem = row"
              >
                <td class="py-2 px-4" @click.stop>
                  <input
                    type="checkbox"
                    :checked="selectedPending.has(row.id)"
                    @change="toggleSelected(row.id)"
                  />
                </td>
                <td class="py-2 px-4 text-gray-500">
                  {{ row.fileName ?? "—" }}
                </td>
                <td class="py-2 px-4 text-gray-900">{{ row.college }}</td>
                <td class="py-2 px-4 text-gray-900">{{ row.course }}</td>
                <td class="py-2 px-4 text-gray-500">{{ row.regulation }}</td>
                <td class="py-2 px-4 text-gray-500">
                  {{ row.subjects.length }}
                </td>
                <td class="py-2 px-4" @click.stop>
                  <button
                    class="p-1.5 border border-gray-300 text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors flex items-center justify-center"
                    title="View Details"
                    @click="detailItem = row"
                  >
                    <Icon name="i-heroicons-eye" class="w-4 h-4" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Approved table -->
    <div v-else>
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div v-if="loadingApproved" class="p-4 text-sm text-gray-400">
          Loading…
        </div>
        <div
          v-else-if="approved.length === 0"
          class="p-8 text-center text-gray-500 text-sm"
        >
          No approved curricula yet.
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
    </div>

    <ConfirmModal
      v-if="uploadConflicts.length > 0"
      title="Overwrite existing curricula?"
      :message="`${uploadConflicts.length} file(s) match a college/course/regulation that already exists:\n\n${uploadConflicts
        .map(
          (c) =>
            `• ${c.fileName ?? 'Unknown file'} — ${c.collegeCode}/${c.courseCode}/${c.regulation} (${conflictExistsInLabel(c.existsIn)})`,
        )
        .join('\n')}\n\nOverwrite the pending entries with the uploaded files?`"
      confirm-label="Overwrite"
      danger
      @confirm="confirmOverwrite"
      @cancel="cancelOverwrite"
    />

    <SyllabusCurriculumDetail
      v-if="detailItem"
      :curriculum="detailItem"
      :action-in-flight="singleInFlight.has(detailItem.id)"
      :saving-edit="savingEdit"
      @close="detailItem = null"
      @approve="approveOne"
      @reject="rejectOne"
      @save="handleSaveEdit"
      @delete="handleDeleteCurriculum"
    />

    <!-- Guide Modal -->
    <Modal
      v-if="showGuideModal"
      max-width="max-w-2xl"
      z-index="z-[60]"
      @close="showGuideModal = false"
    >
      <div class="p-6 flex flex-col">
        <div
          class="flex justify-between items-center pb-3 border-b border-gray-100 mb-4"
        >
          <h3
            class="text-base font-semibold text-gray-950 flex items-center gap-1.5"
          >
            <Icon
              name="i-heroicons-information-circle"
              class="w-5 h-5 text-yellow-500"
            />
            Syllabus CSV &amp; JSON Upload Guide
          </h3>
          <button
            class="text-gray-400 hover:text-gray-600"
            @click="showGuideModal = false"
          >
            <Icon name="i-heroicons-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-4 text-xs text-gray-600 overflow-y-auto pr-1">
          <div>
            <h4 class="font-bold text-gray-800 text-sm mb-1">
              1. How to Upload your College Syllabus
            </h4>
            <p>
              To add or update a curriculum, you can drag &amp; drop or browse a
              <strong>JSON</strong> or <strong>CSV</strong> file. Once uploaded,
              the syllabus goes to the <strong>Pending review</strong> tab.
              After checking its details, an admin can approve and publish it to
              the app.
            </p>
          </div>

          <div>
            <h4 class="font-bold text-gray-800 text-sm mb-1">
              2. Creating the CSV Template
            </h4>
            <p class="mb-1">
              You can create the syllabus spreadsheet using Microsoft Excel,
              Google Sheets, or any CSV editor. Ensure the file has a header row
              with the following 12 columns (order does not matter):
            </p>
            <div
              class="bg-gray-50 border border-gray-100 rounded-lg p-2 font-mono text-[10px] break-all select-all"
            >
              college,college_code,course,course_code,regulation,semester,subject_code,subject_name,credits,category,elective_type,record_type
            </div>
          </div>

          <div>
            <h4 class="font-bold text-gray-800 text-sm mb-1">
              3. Field Explanations (12 Columns)
            </h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-1.5">
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">college</div>
                <div class="mt-0.5">
                  Full name of the college (e.g.,
                  <code>Anna University Affiliated</code>). Replicated on all
                  rows.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">college_code</div>
                <div class="mt-0.5">
                  Short code for the college (e.g., <code>AUA</code>).
                  Replicated on all rows.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">course</div>
                <div class="mt-0.5">
                  Full name of the branch/course (e.g.,
                  <code>Information Technology</code>).
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">course_code</div>
                <div class="mt-0.5">
                  Branch short code (e.g., <code>IT</code>). Replicated on all
                  rows.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">regulation</div>
                <div class="mt-0.5">
                  Curriculum regulation (e.g., <code>R2025</code>). Replicated
                  on all rows.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">semester</div>
                <div class="mt-0.5">
                  Numeric semester (e.g., <code>5</code>). Leave blank/empty for
                  elective option pools.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">subject_code</div>
                <div class="mt-0.5">
                  Subject alphanumeric code (e.g., <code>IT25201</code>). Can be
                  left empty.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">subject_name</div>
                <div class="mt-0.5">
                  The display name of the subject. (Required for every subject
                  row).
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">credits</div>
                <div class="mt-0.5">
                  Credits associated (e.g. <code>3</code>). Can be left empty.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">category</div>
                <div class="mt-0.5">
                  Category (e.g. <code>HUMANITY</code>,
                  <code>PROGRAMMING</code>, <code>SD</code>). For
                  <strong>elective option</strong> rows, this holds the stream
                  name.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">elective_type</div>
                <div class="mt-0.5">
                  For electives and options, matches pools (e.g.
                  <code>Programme Elective, Honours Elective</code>). Otherwise
                  empty.
                </div>
              </div>
              <div class="p-2 border border-gray-100 rounded-lg">
                <div class="font-semibold text-gray-800">record_type</div>
                <div class="mt-0.5">
                  Categorization. Must be one of:
                  <code>core: The core subject</code>,
                  <code>elective: An elective subject</code>, or
                  <code>option: An elective option to choose from</code>.
                </div>
              </div>
            </div>
          </div>

          <div>
            <h4 class="font-bold text-gray-800 text-sm mb-1">
              4. Downloading Reference Samples
            </h4>
            <p>
              To see an example or obtain a starting template, you can download
              the CSV file of other colleges/regulations from the
              <strong>Approved</strong> list below by clicking their
              corresponding <strong>Download CSV</strong> action.
            </p>
          </div>
        </div>

        <div class="flex justify-end gap-2 pt-4 border-t border-gray-100 mt-5">
          <button
            class="px-4 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 transition-colors"
            @click="showGuideModal = false"
          >
            Got it, thanks!
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
