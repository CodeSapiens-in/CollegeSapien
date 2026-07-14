/**
 * OpenAPI (Swagger) documentation for curriculum routes.
 * Extracted from curriculum.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/curriculum:
 *   get:
 *     summary: Get curriculum subjects for a college/course, optionally pinned to a regulation
 *     description: Public endpoint. If regulation is omitted, the latest available regulation is returned along with all available regulations. Requires App Check in production but no Firebase Auth token.
 *     tags: [Curriculum]
 *     security:
 *       - appCheck: []
 *     parameters:
 *       - in: query
 *         name: collegeCode
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: courseCode
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: regulation
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Curriculum bundle.
 *       404:
 *         description: No curriculum found for the given college/course/regulation.
 */

/**
 * @openapi
 * /api/v1/curriculum/pending:
 *   post:
 *     summary: Upload one or more parsed curriculum JSON files for review (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *   get:
 *     summary: List pending curriculum uploads (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/pending/approve:
 *   post:
 *     summary: Approve a batch of pending curricula, moving them into the live collection (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/pending/reject:
 *   post:
 *     summary: Reject and discard a batch of pending curricula (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/pending/{id}:
 *   get:
 *     summary: Get a single pending curriculum upload by id (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/pending/{id}:
 *   patch:
 *     summary: Edit a pending curriculum upload's metadata and subjects (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/admin:
 *   get:
 *     summary: List approved curricula with optional filters (Admin)
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */

/**
 * @openapi
 * /api/v1/curriculum/admin/{id}:
 *   patch:
 *     summary: Edit an approved curriculum's metadata and subjects (Admin)
 *     description: If college/course/regulation change, the document is moved to a new id; fails with 409 if that id is already taken.
 *     tags: [Curriculum]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 */
