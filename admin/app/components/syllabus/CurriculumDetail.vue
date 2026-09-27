<script setup lang="ts">
interface CurriculumSubject {
  semester: number | null;
  subject_code?: string;
  subject_name: string;
  credits?: number | null;
  category?: string;
  elective_type?: string | null;
  record_type?: string;
}

interface Curriculum {
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

const props = defineProps<{
  curriculum: Curriculum;
  actionInFlight?: boolean;
  savingEdit?: boolean;
  readOnly?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  approve: [id: string];
  reject: [id: string];
  delete: [id: string];
  save: [
    payload: {
      id: string;
      status: "pending" | "approved";
      college: string;
      collegeCode: string;
      course: string;
      courseCode: string;
      regulation: string;
      subjects: CurriculumSubject[];
    },
  ];
}>();

const editMode = ref(false);
const authStore = useAuthStore();
const isAmbassador = computed(() => authStore.user?.role === "ambassador");
const editHeader = reactive({
  college: "",
  collegeCode: "",
  course: "",
  courseCode: "",
  regulation: "",
});
const editSubjects = ref<CurriculumSubject[]>([]);

const subjectModal = ref<{ subject: CurriculumSubject; index: number | null } | null>(
  null,
);

const startEdit = () => {
  editHeader.college = props.curriculum.college;
  editHeader.collegeCode = props.curriculum.collegeCode;
  editHeader.course = props.curriculum.course;
  editHeader.courseCode = props.curriculum.courseCode;
  editHeader.regulation = props.curriculum.regulation;
  editSubjects.value = props.curriculum.subjects.map((s) => ({ ...s }));
  editMode.value = true;
};

const cancelEdit = () => {
  editMode.value = false;
  subjectModal.value = null;
};

const saveEdit = () => {
  emit("save", {
    id: props.curriculum.id,
    status: props.curriculum.status,
    ...editHeader,
    subjects: editSubjects.value,
  });
};

watch(
  () => props.curriculum,
  () => {
    editMode.value = false;
  },
);

const displaySubjects = computed(() =>
  editMode.value ? editSubjects.value : props.curriculum.subjects,
);

const semesterGroups = computed(() => {
  const groups = new Map<number, { subject: CurriculumSubject; index: number }[]>();
  displaySubjects.value.forEach((s, index) => {
    if (s.record_type === "option") return;
    const sem = s.semester;
    if (sem === null) return;
    if (!groups.has(sem)) groups.set(sem, []);
    groups.get(sem)!.push({ subject: s, index });
  });
  return [...groups.entries()].sort((a, b) => a[0] - b[0]);
});

const optionGroups = computed(() => {
  const groups = new Map<string, { subject: CurriculumSubject; index: number }[]>();
  displaySubjects.value.forEach((s, index) => {
    if (s.record_type !== "option") return;
    const key = s.elective_type ?? "Elective Options";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push({ subject: s, index });
  });
  return [...groups.entries()];
});

const openAddSubject = (defaults: Partial<CurriculumSubject>) => {
  subjectModal.value = {
    index: null,
    subject: {
      semester: null,
      subject_name: "",
      subject_code: "",
      credits: null,
      category: "",
      elective_type: null,
      record_type: "core",
      ...defaults,
    },
  };
};

const openEditSubject = (index: number) => {
  subjectModal.value = { index, subject: { ...editSubjects.value[index] } };
};

const handleSubjectSave = (subject: CurriculumSubject) => {
  if (!subjectModal.value) return;
  if (subjectModal.value.index === null) {
    editSubjects.value.push(subject);
  } else {
    editSubjects.value[subjectModal.value.index] = subject;
  }
  subjectModal.value = null;
};

const deleteSubject = (index: number) => {
  editSubjects.value.splice(index, 1);
};

const handleDelete = () => {
  emit("delete", props.curriculum.id);
};
</script>

<template>
  <Modal max-width="max-w-3xl" @close="emit('close')">
      <div
        class="sticky top-0 bg-white px-6 py-4 border-b border-gray-100 flex items-start justify-between gap-4"
      >
        <div v-if="!editMode">
          <h3 class="text-base font-semibold text-gray-900">
            {{ curriculum.college }} · {{ curriculum.course }}
          </h3>
          <p class="text-sm text-gray-500 mt-0.5">
            {{ curriculum.collegeCode }} / {{ curriculum.courseCode }} /
            {{ curriculum.regulation }} ·
            {{ curriculum.subjects.length }} subjects
          </p>
        </div>
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-2 flex-1">
          <input
            v-model="editHeader.college"
            placeholder="College name"
            class="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
          />
          <input
            v-model="editHeader.collegeCode"
            placeholder="College code"
            class="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
          />
          <input
            v-model="editHeader.course"
            placeholder="Course name"
            class="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
          />
          <input
            v-model="editHeader.courseCode"
            placeholder="Course code"
            class="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400"
          />
          <input
            v-model="editHeader.regulation"
            placeholder="Regulation"
            class="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-yellow-400 col-span-2"
          />
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <button
            v-if="!editMode && !readOnly"
            class="px-3 py-1.5 text-xs font-medium border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 transition-colors"
            @click="startEdit"
          >
            Edit
          </button>
          <button
            v-if="!editMode && !readOnly && curriculum.status === 'approved' && !isAmbassador"
            class="px-3 py-1.5 text-xs font-medium border border-red-300 text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors flex items-center gap-1"
            title="Delete Curriculum"
            @click="handleDelete"
          >
            <Icon name="i-heroicons-trash" class="w-3.5 h-3.5" />
            Delete
          </button>
          <button
            class="p-1 text-gray-400 hover:text-gray-700"
            @click="editMode ? cancelEdit() : emit('close')"
          >
            <Icon name="i-heroicons-x-mark" class="w-5 h-5" />
          </button>
        </div>
      </div>

      <div class="p-6 space-y-6">
        <div
          v-for="[semester, rows] in semesterGroups"
          :key="`sem-${semester}`"
        >
          <div class="flex items-center justify-between mb-2">
            <h4 class="text-sm font-semibold text-gray-700">
              Semester {{ semester }}
            </h4>
            <button
              v-if="editMode"
              class="text-xs text-yellow-700 hover:text-yellow-800 font-medium"
              @click="
                openAddSubject({
                  semester: semester,
                  record_type: 'core',
                })
              "
            >
              + Add subject
            </button>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-xs">
              <thead>
                <tr class="text-left text-gray-400 border-b border-gray-100">
                  <th class="py-1.5 pr-2 font-medium">Code</th>
                  <th class="py-1.5 pr-2 font-medium">Name</th>
                  <th class="py-1.5 pr-2 font-medium">Credits</th>
                  <th class="py-1.5 pr-2 font-medium">Category</th>
                  <th v-if="editMode" class="py-1.5 pr-2 font-medium w-16"></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in rows"
                  :key="`${semester}-${row.index}`"
                  class="border-b border-gray-50"
                >
                  <td class="py-1.5 pr-2 text-gray-500">
                    {{ row.subject.subject_code || "—" }}
                  </td>
                  <td class="py-1.5 pr-2 text-gray-900">
                    {{ row.subject.subject_name }}
                    <span
                      v-if="row.subject.record_type === 'elective'"
                      class="ml-1 text-xs bg-blue-100 text-blue-700 px-1.5 py-0.5 rounded-full"
                      >Elective</span
                    >
                  </td>
                  <td class="py-1.5 pr-2 text-gray-500">
                    {{ row.subject.credits ?? "—" }}
                  </td>
                  <td class="py-1.5 pr-2 text-gray-500">
                    {{ row.subject.category || "—" }}
                  </td>
                  <td v-if="editMode" class="py-1.5 pr-2">
                    <div class="flex items-center gap-2">
                      <button
                        class="text-gray-400 hover:text-gray-700"
                        title="Edit"
                        @click="openEditSubject(row.index)"
                      >
                        <Icon name="i-heroicons-pencil-square" class="w-3.5 h-3.5" />
                      </button>
                      <button
                        class="text-gray-400 hover:text-red-500"
                        title="Delete"
                        @click="deleteSubject(row.index)"
                      >
                        <Icon name="i-heroicons-trash" class="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div v-for="[pool, rows] in optionGroups" :key="`pool-${pool}`">
          <div class="flex items-center justify-between mb-2">
            <h4 class="text-sm font-semibold text-gray-700">
              {{ pool }} — options
            </h4>
            <button
              v-if="editMode"
              class="text-xs text-yellow-700 hover:text-yellow-800 font-medium"
              @click="
                openAddSubject({
                  semester: null,
                  record_type: 'option',
                  elective_type: pool,
                })
              "
            >
              + Add option
            </button>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-xs">
              <thead>
                <tr class="text-left text-gray-400 border-b border-gray-100">
                  <th class="py-1.5 pr-2 font-medium">Name</th>
                  <th class="py-1.5 pr-2 font-medium">Category</th>
                  <th class="py-1.5 pr-2 font-medium">Credits</th>
                  <th v-if="editMode" class="py-1.5 pr-2 font-medium w-16"></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in rows"
                  :key="`${pool}-${row.index}`"
                  class="border-b border-gray-50"
                >
                  <td class="py-1.5 pr-2 text-gray-900">
                    {{ row.subject.subject_name }}
                  </td>
                  <td class="py-1.5 pr-2 text-gray-500">
                    {{ row.subject.category || "—" }}
                  </td>
                  <td class="py-1.5 pr-2 text-gray-500">
                    {{ row.subject.credits ?? "—" }}
                  </td>
                  <td v-if="editMode" class="py-1.5 pr-2">
                    <div class="flex items-center gap-2">
                      <button
                        class="text-gray-400 hover:text-gray-700"
                        title="Edit"
                        @click="openEditSubject(row.index)"
                      >
                        <Icon name="i-heroicons-pencil-square" class="w-3.5 h-3.5" />
                      </button>
                      <button
                        class="text-gray-400 hover:text-red-500"
                        title="Delete"
                        @click="deleteSubject(row.index)"
                      >
                        <Icon name="i-heroicons-trash" class="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <button
          v-if="editMode"
          class="text-xs text-yellow-700 hover:text-yellow-800 font-medium"
          @click="openAddSubject({})"
        >
          + Add subject to a new semester / pool
        </button>
      </div>

      <div
        class="sticky bottom-0 bg-white px-6 py-4 border-t border-gray-100 flex justify-end gap-2"
      >
        <template v-if="editMode">
          <button
            class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            @click="cancelEdit"
          >
            Cancel
          </button>
          <button
            :disabled="savingEdit"
            class="px-4 py-2 text-sm bg-yellow-400 text-gray-900 font-medium rounded-lg hover:bg-yellow-500 disabled:opacity-60 transition-colors"
            @click="saveEdit"
          >
            {{ savingEdit ? "Saving…" : "Save changes" }}
          </button>
        </template>
        <template v-else-if="curriculum.status === 'pending' && !readOnly">
          <button
            :disabled="actionInFlight"
            class="px-4 py-2 text-sm border border-red-300 text-red-600 rounded-lg hover:bg-red-50 disabled:opacity-60 transition-colors"
            @click="emit('reject', curriculum.id)"
          >
            Reject
          </button>
          <button
            v-if="!isAmbassador"
            :disabled="actionInFlight"
            class="px-4 py-2 text-sm bg-green-600 text-white font-medium rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
            @click="emit('approve', curriculum.id)"
          >
            Approve
          </button>
        </template>
      </div>
  </Modal>

  <SyllabusSubjectFormModal
    v-if="subjectModal"
    :subject="subjectModal.subject"
    :is-new="subjectModal.index === null"
    @save="handleSubjectSave"
    @cancel="subjectModal = null"
  />
</template>
