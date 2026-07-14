/**
 * OpenAPI (Swagger) documentation for auth routes.
 * Extracted from auth.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/auth/signup:
 *   post:
 *     tags: [Auth]
 *     summary: Legacy signup/profile creation
 *     description: |
 *       Creates a Firestore user profile for an already-authenticated Firebase user.
 *
 *       The user's `uid`, `email`, and `email_verified` values are read from the Firebase ID token in
 *       `Authorization: Bearer <token>`. The backend does not trust an email supplied in the JSON body.
 *
 *       Prefer `POST /api/v1/auth/sync` followed by `POST /api/v1/auth/onboard` for the Flutter app.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 readOnly: true
 *                 description: Derived from the Firebase ID token, not accepted from the request body.
 *                 example: "student@college.edu"
 *               name:
 *                 type: string
 *                 example: "John Doe"
 *               collegeId:
 *                 type: string
 *                 description: Preferred college identifier from `GET /api/v1/colleges`.
 *                 example: "college_doc_id"
 *               collegeName:
 *                 type: string
 *                 description: Legacy lookup fallback. Prefer `collegeId`.
 *                 example: "Anna University"
 *               department:
 *                 type: string
 *                 example: "Computer Science"
 *               semester:
 *                 type: integer
 *                 example: 1
 *               attendanceThreshold:
 *                 type: integer
 *                 minimum: 50
 *                 maximum: 100
 *                 default: 75
 *             required:
 *               - name
 *             oneOf:
 *               - required: [collegeId]
 *               - required: [collegeName]
 *     responses:
 *       201:
 *         description: Signup initiated or completed successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Signup initiated. Verification link sent to email via SES."
 *                 user:
 *                   type: object
 *                   properties:
 *                     uid:
 *                       type: string
 *                     email:
 *                       type: string
 *                     name:
 *                       type: string
 *                     collegeName:
 *                       type: string
 *                     collegeId:
 *                       type: string
 *                     department:
 *                       type: string
 *                     semester:
 *                       type: integer
 *                     isVerified:
 *                       type: boolean
 *       400:
 *         description: Validation error or college not found.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "College not found in our directory"
 *       401:
 *         description: Unauthorized. Missing or invalid token.
 *       403:
 *         description: Email domain not whitelisted.
 */

/**
 * @openapi
 * /api/v1/auth/sync:
 *   post:
 *     tags: [Auth]
 *     summary: Sync Firebase Auth user with API profile
 *     description: |
 *       Reads the Firebase ID token, synchronizes verification/last-login state, and tells the app
 *       whether onboarding is still required.
 *
 *       No request body is required. `email` comes from the Firebase ID token.
 *
 *       When onboarding is already complete, the response also bundles the user's current-semester
 *       attendance summary, timetable, and saved syllabus subjects — the same data
 *       `GET /attendance/summary`, `GET /timetable`, and `GET /syllabus/subjects/:semester` return —
 *       so the app can hydrate its home screen from this single call instead of four.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     parameters:
 *       - in: query
 *         name: timezoneOffsetMinutes
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Client timezone offset in minutes, used to compute the attendance summary's elapsed-day boundaries (same semantics as `GET /attendance/summary`).
 *     responses:
 *       200:
 *         description: Auth/profile sync result.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Profile synchronized"
 *                 onboardingRequired:
 *                   type: boolean
 *                   example: false
 *                 auth:
 *                   type: object
 *                   properties:
 *                     uid:
 *                       type: string
 *                     email:
 *                       type: string
 *                       format: email
 *                     emailVerified:
 *                       type: boolean
 *                     role:
 *                       type: string
 *                       enum: [user, moderator, superadmin]
 *                     collegeId:
 *                       type: string
 *                       nullable: true
 *                 user:
 *                   type: object
 *                   nullable: true
 *                   properties:
 *                     uid:
 *                       type: string
 *                     email:
 *                       type: string
 *                       format: email
 *                     name:
 *                       type: string
 *                     collegeId:
 *                       type: string
 *                     collegeName:
 *                       type: string
 *                     department:
 *                       type: string
 *                     semester:
 *                       type: integer
 *                     role:
 *                       type: string
 *                     isVerified:
 *                       type: boolean
 *                 attendanceSummary:
 *                   type: array
 *                   description: Present (possibly empty) once onboarding is complete. Same shape as `GET /attendance/summary`.
 *                   items:
 *                     type: object
 *                 timetable:
 *                   type: object
 *                   nullable: true
 *                   description: Present once onboarding is complete, null if no timetable is saved yet. Same shape as `GET /timetable`.
 *                   properties:
 *                     subjects:
 *                       type: array
 *                       items:
 *                         type: object
 *                 savedSubjects:
 *                   type: object
 *                   nullable: true
 *                   description: Present once onboarding is complete, null if no subjects are saved yet. Same shape as `GET /syllabus/subjects/:semester`.
 *       401:
 *         description: Unauthorized. Missing or invalid token.
 */

/**
 * @openapi
 * /api/v1/auth/onboard:
 *   post:
 *     tags: [Auth]
 *     summary: Complete or update student onboarding
 *     description: |
 *       Creates/updates the authenticated student's Firestore profile after Firebase email verification.
 *       `uid` and `email` are derived from the Firebase ID token, not from request body fields.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 readOnly: true
 *                 description: Derived from the Firebase ID token, not accepted from the request body.
 *                 example: "student@college.edu"
 *               name:
 *                 type: string
 *                 minLength: 2
 *                 example: "John Doe"
 *               collegeId:
 *                 type: string
 *                 description: Preferred college identifier from `GET /api/v1/colleges`.
 *                 example: "college_doc_id"
 *               collegeName:
 *                 type: string
 *                 description: Legacy lookup fallback. Prefer `collegeId`.
 *                 example: "Anna University"
 *               department:
 *                 type: string
 *                 example: "Computer Science"
 *               semester:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 10
 *                 example: 3
 *               attendanceThreshold:
 *                 type: integer
 *                 minimum: 50
 *                 maximum: 100
 *                 default: 75
 *             required:
 *               - name
 *               - department
 *               - semester
 *             oneOf:
 *               - required: [collegeId]
 *               - required: [collegeName]
 *     responses:
 *       200:
 *         description: Existing onboarding profile updated.
 *       201:
 *         description: Onboarding completed.
 *       400:
 *         description: Validation error or unknown college.
 *       401:
 *         description: Unauthorized. Missing or invalid token.
 *       403:
 *         description: Email not verified or college email domain mismatch.
 */

/**
 * @openapi
 * /api/v1/auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: Login user
 *     description: |
 *       Authenticates the user session.
 *       **No Request Body Required**.
 *       Pass the Firebase ID Token in the `Authorization: Bearer <token>` header. If the user just verified their email via the link, this endpoint synchronizes the `isVerified` status in Firestore. Issues a secure `__session` cookie for subsequent requests.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: Login successful.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Login successful"
 *                 user:
 *                   type: object
 *                   properties:
 *                     uid:
 *                       type: string
 *                     email:
 *                       type: string
 *                     name:
 *                       type: string
 *                     isVerified:
 *                       type: boolean
 *       401:
 *         description: Unauthorized. Missing or invalid token.
 *       403:
 *         description: Email not verified.
 *       404:
 *         description: User profile not found (Needs signup).
 */

/**
 * @openapi
 * /api/v1/auth/logout:
 *   post:
 *     tags: [Auth]
 *     summary: Logout user
 *     description: Clears the `__session` cookie.
 *     responses:
 *       200:
 *         description: Logged out successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Logged out successfully"
 */

/**
 * @openapi
 * /api/v1/auth/me:
 *   get:
 *     tags: [Auth]
 *     summary: Get current user profile
 *     description: Retrieves the authenticated user's profile from Firestore.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: User profile data.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 uid:
 *                   type: string
 *                 email:
 *                   type: string
 *                 name:
 *                   type: string
 *                 collegeName:
 *                   type: string
 *                 department:
 *                   type: string
 *                 semester:
 *                   type: integer
 *                 role:
 *                   type: string
 *                 isVerified:
 *                   type: boolean
 *       401:
 *         description: Unauthorized.
 *       404:
 *         description: User not found.
 */

/**
 * @openapi
 * /api/v1/auth/me:
 *   patch:
 *     tags: [Auth]
 *     summary: Update user profile
 *     description: Updates fields in the authenticated user's profile. All fields are optional.
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: "John Doe"
 *               semester:
 *                 type: integer
 *                 example: 3
 *               attendanceThreshold:
 *                 type: integer
 *                 example: 80
 *     responses:
 *       200:
 *         description: Profile updated.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Profile updated"
 *       400:
 *         description: Validation error.
 *       401:
 *         description: Unauthorized.
 */
