/**
 * OpenAPI (Swagger) documentation for colleges routes.
 * Extracted from colleges.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/colleges:
 *   get:
 *     summary: List all colleges (public)
 *     description: Fetches a list of all active colleges. Used during onboarding. Requires App Check in production but no Firebase Auth token.
 *     tags: [Colleges]
 *     security:
 *       - appCheck: []
 *     responses:
 *       200:
 *         description: List of colleges.
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                     example: "col_123"
 *                   name:
 *                     type: string
 *                     example: "Anna University"
 *                   code:
 *                     type: string
 *                     example: "AU"
 */

/**
 * @openapi
 * /api/v1/colleges:
 *   post:
 *     summary: Create a college (Superadmin)
 *     tags: [Colleges]
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
 *                 example: "SSN College of Engineering"
 *               code:
 *                 type: string
 *                 example: "SSN"
 *               domains:
 *                 type: array
 *                 items:
 *                   type: string
 *                 example: ["ssn.edu.in"]
 *               city:
 *                 type: string
 *                 example: "Chennai"
 *             required:
 *               - name
 *               - code
 *     responses:
 *       201:
 *         description: College created.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "College created"
 *                 id:
 *                   type: string
 *                   example: "col_456"
 */

/**
 * @openapi
 * /api/v1/colleges/{id}:
 *   put:
 *     summary: Update a college (Superadmin)
 *     description: Update any of the fields for a college. All fields are optional.
 *     tags: [Colleges]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: "SSN College of Engineering"
 *               code:
 *                 type: string
 *                 example: "SSN"
 *               domains:
 *                 type: array
 *                 items:
 *                   type: string
 *                 example: ["ssn.edu.in"]
 *               city:
 *                 type: string
 *                 example: "Kalavakkam"
 *     responses:
 *       200:
 *         description: College updated successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "College updated"
 *       400:
 *         description: Validation error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Validation error message"
 */

/**
 * @openapi
 * /api/v1/colleges/{id}:
 *   delete:
 *     summary: Delete a college (Superadmin)
 *     description: Soft-deletes a college by setting deletedAt timestamp.
 *     tags: [Colleges]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: College deleted.
 */
