/**
 * OpenAPI (Swagger) documentation for admin routes.
 * Extracted from admin.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/admin/assign-role:
 *   post:
 *     summary: Assign a role to a user (SuperAdmin only)
 *     description: Assigns roles like `moderator` or `superadmin`. Can be scoped to a `collegeId`.
 *     tags: [Admin]
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
 *               uid:
 *                 type: string
 *                 example: "user_id_123"
 *               role:
 *                 type: string
 *                 enum: [user, moderator, admin, superadmin]
 *                 example: "moderator"
 *               collegeId:
 *                 type: string
 *                 example: "col_123"
 *             required:
 *               - uid
 *               - role
 *     responses:
 *       200:
 *         description: Role assigned successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Role moderator assigned to user user_id_123"
 */

/**
 * @openapi
 * /api/v1/admin/users:
 *   get:
 *     summary: List all users (SuperAdmin only)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: A list of users.
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                   email:
 *                     type: string
 *                   name:
 *                     type: string
 */

/**
 * @openapi
 * /api/v1/admin/reports:
 *   get:
 *     summary: Get pending reports (Moderator/Admin/SuperAdmin)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     responses:
 *       200:
 *         description: A list of pending reports.
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                   resourceId:
 *                     type: string
 *                   reason:
 *                     type: string
 *                   type:
 *                     type: string
 *                   status:
 *                     type: string
 *                     example: "pending"
 */

/**
 * @openapi
 * /api/v1/admin/reports/{id}/resolve:
 *   patch:
 *     summary: Resolve a report (Moderator/Admin/SuperAdmin)
 *     description: Take action on a pending report. delete_resource archives the
 *       resource and resolves pending reports for it.
 *     tags: [Admin]
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
 *               action:
 *                 type: string
 *                 enum: [dismiss, ban_user, delete_resource]
 *                 example: "delete_resource"
 *             required:
 *               - action
 *     responses:
 *       200:
 *         description: Report resolved.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Report resolved with action: delete_resource"
 */

/**
 * @openapi
 * /api/v1/admin/resources/{id}:
 *   delete:
 *     summary: Archive a resource (Moderator/Admin/SuperAdmin)
 *     description: Reject and archive a resource by ID.
 *     tags: [Admin]
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
 *         description: Resource deleted.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Resource rejected and archived"
 */

/**
 * @openapi
 * /api/v1/admin/resources/pending:
 *   get:
 *     summary: List resources pending moderation (Moderator/Admin/SuperAdmin)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *         appCheck: []
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [Notes, QP]
 *     responses:
 *       200:
 *         description: List of pending resources.
 */

/**
 * @openapi
 * /api/v1/admin/resources/{id}/approve:
 *   patch:
 *     summary: Approve a pending resource (Moderator/Admin/SuperAdmin)
 *     tags: [Admin]
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
 *         description: Resource approved.
 */

/**
 * @openapi
 * /api/v1/admin/resources/{id}/reject:
 *   patch:
 *     summary: Reject and archive a pending resource (Moderator/Admin/SuperAdmin)
 *     tags: [Admin]
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
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason:
 *                 type: string
 *                 example: "Spam upload"
 *     responses:
 *       200:
 *         description: Resource rejected and archived.
 */
