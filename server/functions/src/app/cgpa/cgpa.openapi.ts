/**
 * OpenAPI (Swagger) documentation for cgpa routes.
 * Extracted from cgpa.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/cgpa/calculate:
 *   post:
 *     summary: Parse grade sheet image via Gemini
 *     description: Upload a base64 encoded image of a grade sheet to calculate CGPA.
 *     tags: [CGPA]
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
 *         description: CGPA calculation results.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 gpa:
 *                   type: number
 *                   example: 8.5
 *                 cgpa:
 *                   type: number
 *                   example: 8.7
 *                 subjects:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                         example: "Data Structures"
 *                       grade:
 *                         type: string
 *                         example: "A"
 *                       credits:
 *                         type: integer
 *                         example: 3
 *       400:
 *         description: Bad request.
 *       500:
 *         description: Parsing or internal error.
 */

/**
 * @openapi
 * /api/v1/cgpa/predict:
 *   post:
 *     summary: Calculate required external marks based on internals
 *     description: Determines how many marks are needed in external exams to achieve a specific target grade.
 *     tags: [CGPA]
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
 *               internalMarks:
 *                 type: number
 *                 example: 35
 *               maxInternalMarks:
 *                 type: number
 *                 default: 40
 *                 example: 40
 *               targetGrade:
 *                 type: string
 *                 enum: [O, A+, A, B+, B]
 *                 example: "O"
 *             required:
 *               - subjectId
 *               - internalMarks
 *               - targetGrade
 *     responses:
 *       200:
 *         description: Prediction results.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 targetGrade:
 *                   type: string
 *                   example: "O"
 *                 internalMarks:
 *                   type: number
 *                   example: 35
 *                 maxInternalMarks:
 *                   type: number
 *                   example: 40
 *                 requiredInExternalOutOf100:
 *                   type: integer
 *                   example: 94
 *                 message:
 *                   type: string
 *                   example: "You need 94 out of 100 in external to get O. Semma target!"
 *       400:
 *         description: Validation error.
 */
