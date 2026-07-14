/**
 * OpenAPI (Swagger) documentation for timetable routes.
 * Extracted from timetable.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/timetable:
 *   post:
 *     summary: Upload/Update user timetable
 *     description: Overwrites the current user's timetable in Firestore.
 *     tags: [Timetable]
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
 *               subjects:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "sub_123"
 *                     name:
 *                       type: string
 *                       example: "Data Structures"
 *                     code:
 *                       type: string
 *                       example: "CS8391"
 *                     classes:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           day:
 *                             type: string
 *                             enum: [MON, TUE, WED, THU, FRI, SAT, SUN]
 *                             example: "MON"
 *                           startTime:
 *                             type: string
 *                             example: "09:00"
 *                           endTime:
 *                             type: string
 *                             example: "10:00"
 *                           room:
 *                             type: string
 *                             example: "A-101"
 *                           type:
 *                             type: string
 *                             enum: [CORE, LAB, BREAK]
 *                             example: "CORE"
 *     responses:
 *       200:
 *         description: Timetable updated successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Timetable updated successfully"
 *       400:
 *         description: Validation error.
 */

/**
 * @openapi
 * /api/v1/timetable/parse:
 *   post:
 *     summary: Parse timetable image using Gemini
 *     description: Uses Gemini Vision to extract a structured timetable from an image.
 *     tags: [Timetable]
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
 *               imageBase64:
 *                 type: string
 *                 example: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
 *             required:
 *               - imageBase64
 *     responses:
 *       200:
 *         description: Parsed timetable.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 subjects:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                         example: "Data Structures"
 *                       code:
 *                         type: string
 *                         example: "CS8391"
 *                       classes:
 *                         type: array
 *                         items:
 *                           type: object
 *                           properties:
 *                             day:
 *                               type: string
 *                               example: "MON"
 *                             startTime:
 *                               type: string
 *                               example: "09:00"
 *                             endTime:
 *                               type: string
 *                               example: "10:00"
 *                             type:
 *                               type: string
 *                               example: "CORE"
 *       500:
 *         description: Parsing error.
 */

/**
 * @openapi
 * /api/v1/timetable:
 *   get:
 *     summary: Get user timetable
 *     description: Retrieves the current user's timetable.
 *     tags: [Timetable]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: User timetable retrieved.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 subjects:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       name:
 *                         type: string
 *                       code:
 *                         type: string
 *                       classes:
 *                         type: array
 *                         items:
 *                           type: object
 *                           properties:
 *                             day:
 *                               type: string
 *                             startTime:
 *                               type: string
 *                             endTime:
 *                               type: string
 *                             room:
 *                               type: string
 *                             type:
 *                               type: string
 *       404:
 *         description: Timetable not found.
 */

/**
 * @openapi
 * /api/v1/timetable:
 *   delete:
 *     summary: Delete user timetable
 *     description: Deletes the current user's timetable for their active semester.
 *     tags: [Timetable]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: Timetable deleted.
 *       404:
 *         description: Timetable not found.
 */
