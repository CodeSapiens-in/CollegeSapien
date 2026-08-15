# CollegeSapien

CollegeSapien is a unified monorepo for the Codesapiens academic platform. It includes the student mobile application, the administration dashboard, serverless backend cloud functions, and the public landing page.

---

## 📂 Repository Architecture

The codebase is organized into four main modules:

### 1. 📱 `app/` (Flutter Client App)
* **Description**: The cross-platform mobile and web client for students.
* **Deployment**: Active in production at [college.codesapiens.in](https://college.codesapiens.in) and available as a live Android app on the [Google Play Store](https://play.google.com/store/apps/details?id=com.collegesapien.app).
* **Target Platforms**: Android, iOS, and Web.
* **Key Features**:
  * **Dynamic Timetable**: Automated daily schedule tracking with classroom allocations.
  * **Smart Attendance Tracker**: Log absences, track attendance percentages, and set alerts for falling below thresholds (e.g., 75%).
  * **Academic Resources Hub**: Direct access to notes, question papers, and past university test archives.
  * **Syllabus Browser**: Choose regulation, course, and view semester-wise curriculum layout.
  * **Interactive CGPA Calculator**: Input grades and credits to estimate semester GPA and cumulative CGPA.
  * **Profile Sync**: User-facing onboarding and profile editing backed by secure Firebase Authentication.

### 2. 🛡️ `admin/` (Administration Portal)
* **Description**: Control center for admins and ambassadors to moderate data, approve curricula, and manage resources.
* **Deployment**: Active in production at [admin.codesapiens.in](https://admin.codesapiens.in).
* **Key Features**:
  * **Syllabus Uploader**: Supports drag-and-drop file uploads for JSON and CSV file types with automatic parsing and schema validation.
  * **Role-Based Access Control**:
    * **Superadmin**: Full management including approvals, deletions, and resource archival.
    * **Ambassador**: Restricted access to view, upload, and edit syllabus/resources. Cannot delete approved files, approve pending uploads, or archive resources.
  * **Unified Master Data Management**: Combined interface to register and edit Colleges and Departments in one tabbed dashboard.
  * **Curriculum Detail Sheet**: Edit headers, add/modify/delete subjects, and handle elective pools dynamically.
  * **CSV Exporter**: Single-click export of approved syllabus templates.

### 3. ⚡ `server/` (Backend Services)
* **Description**: Serverless API and business logic running on Firebase Cloud Functions.
* **Technology**: Node.js, Express, TypeScript, Zod.
* **Key Features**:
  * **RESTful API**: Serves endpoints under `/api/v1/` for authorization, resource moderation, colleges, and syllabus.
  * **Security with App Check**: Protects endpoints against unauthorized non-app requests.
  * **Combined Masters Cache**: Serves consolidated college and department lists in a single endpoint `/colleges/combined`, optimized for offline client-side caching.
  * **Firestore Integration**: Coordinates data models for curricula, colleges, and user profiles.

### 4. 🌐 `website/` (Landing Page)
* **Description**: The landing page for our community codesapiens.in with a little teaser game and details about our community

---

## 📊 Syllabus Data & CSV Structure

The platform stores academic curricula in `data/syllabus/` as `.csv` files. The CSV format is designed for easy editing via Excel or Google Sheets.

### CSV Layout Guidelines
Each row represents a single subject record. Common metadata fields (college, course, regulation, etc.) are repeated across every row to produce a self-contained flat file of 12 columns:

| Column Header | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| **`college`** | String | The full name of the university or college. | `Anna University Affiliated` |
| **`college_code`** | String | The short identifier for the college. | `AUA` |
| **`course`** | String | The name of the academic department/program. | `Information Technology` |
| **`course_code`** | String | The program code mirroring the department. | `IT` |
| **`regulation`** | String | The academic curriculum regulation code. | `R2025` |
| **`semester`** | Number | The semester index (values `1` to `8`). | `1` |
| **`subject_code`** | String | The alphanumeric subject code. | `MA25C01` |
| **`subject_name`** | String | The full title of the subject. | `Applied Calculus` |
| **`credits`** | Number | The academic credits weight of the course. | `4` |
| **`category`** | String | Course category (e.g. Basic Sciences `BS`, Professional Core `PC`, or the elective stream title like `Artificial Intelligence`). | `BS` |
| **`elective_type`** | String/Null | The name of the elective pool slot for `option` records, or `null` for `core` records. | `Professional Elective I` |
| **`record_type`** | String | Subject status: `'core'` (mandatory) or `'elective'` or `'option'` (choice from an elective pool). | `core` |

---

## 🛠️ Local Development Quickstart

### Prerequisites
* Node.js (Node 22+ for functions, Node 20+ for admin)
* pnpm 11+
* Flutter SDK >= 3.0.0
* Firebase CLI

### 1. Build and Run Server (Cloud Functions)
```bash
cd server/functions
pnpm install
pnpm build
pnpm serve
```

### 2. Start Admin Portal
```bash
cd admin
pnpm install
pnpm dev
```

### 3. Launch Mobile Client
```bash
cd app
flutter pub get
flutter run --dart-define=CODESAPIENS_API_BASE_URL=http://localhost:5001/collegesapiens/us-central1/api/api/v1
```
