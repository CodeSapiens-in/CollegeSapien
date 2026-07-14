/**
 * OpenAPI (Swagger) documentation for attendance routes.
 * Extracted from attendance.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/attendance:
 *   post:
 *     summary: Upsert attendance for a specific day/subject
 *     description: Marks or updates attendance for a subject on a given date.
 *     tags: [Attendance]
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
 *               subjectId:
 *                 type: string
 *                 example: "sub_123"
 *               date:
 *                 type: string
 *                 format: date
 *                 example: "2024-01-15T00:00:00.000Z"
 *               status:
 *                 type: string
 *                 enum: [Present, Absent, Leave, None]
 *                 example: "Present"
 *             required:
 *               - subjectId
 *               - date
 *               - status
 *     responses:
 *       201:
 *         description: Attendance updated successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Attendance updated successfully"
 *       200:
 *         description: Attendance reset (status None).
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Attendance reset"
 *       400:
 *         description: Validation error.
 */

/**
 * @openapi
 * /api/v1/attendance/sync:
 *   post:
 *     summary: Bulk update/correction of past attendance
 *     description: Synchronize multiple attendance records at once.
 *     tags: [Attendance]
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
 *               updates:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     subjectId:
 *                       type: string
 *                       example: "sub_123"
 *                     date:
 *                       type: string
 *                       format: date
 *                       example: "2024-01-15T00:00:00.000Z"
 *                     status:
 *                       type: string
 *                       enum: [Present, Absent, Leave, None]
 *                       example: "Absent"
 *                   required:
 *                     - subjectId
 *                     - date
 *                     - status
 *             required:
 *               - updates
 *     responses:
 *       200:
 *         description: Bulk attendance synced successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Bulk attendance synced"
 *       400:
 *         description: Missing data.
 */

/**
 * @openapi
 * /api/v1/attendance/summary:
 *   get:
 *     summary: Returns percentage and Safe to Skip metrics for current semester
 *     description: Retrieves the overall attendance summary per subject.
 *     tags: [Attendance]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: Attendance summary.
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   subjectId:
 *                     type: string
 *                     example: "sub_123"
 *                   subjectName:
 *                     type: string
 *                     example: "Data Structures"
 *                   subjectCode:
 *                     type: string
 *                     example: "CS8391"
 *                   attended:
 *                     type: integer
 *                     example: 30
 *                   absent:
 *                     type: integer
 *                     example: 5
 *                   total:
 *                     type: integer
 *                     example: 35
 *                   percentage:
 *                     type: number
 *                     example: 85.71
 *                   safeToSkip:
 *                     type: integer
 *                     example: 5
 *                   requiredToReachThreshold:
 *                     type: integer
 *                     example: 0
 *       500:
 *         description: Internal server error.
 */
