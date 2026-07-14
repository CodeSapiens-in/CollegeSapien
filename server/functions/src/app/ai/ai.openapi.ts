/**
 * OpenAPI (Swagger) documentation for ai routes.
 * Extracted from ai.route.ts so the route file stays readable.
 * Picked up by swagger-jsdoc via the `apis` glob in src/shared/docs/swagger.ts.
 */

/**
 * @openapi
 * /api/v1/ai/roast-resume:
 *   post:
 *     summary: Gemini Tanglish Roast
 *     description: Sends resume text to Gemini to generate a funny, Tanglish roast.
 *     tags: [AI]
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
 *               resumeText:
 *                 type: string
 *                 example: "I am a proactive student with knowledge of HTML, CSS..."
 *             required:
 *               - resumeText
 *     responses:
 *       200:
 *         description: Resume roast generated.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 roast:
 *                   type: string
 *                   example: "Dai, HTML CSS vechu proactive nu solriya! Padida thambi..."
 *       400:
 *         description: Bad request.
 */

/**
 * @openapi
 * /api/v1/ai/meme-it:
 *   post:
 *     summary: Gemini Tanglish Meme description
 *     description: Converts profile content or achievements into a funny Tamil meme description.
 *     tags: [AI]
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
 *               content:
 *                 type: string
 *                 example: "Just won first place in a national hackathon!"
 *             required:
 *               - content
 *     responses:
 *       200:
 *         description: Meme description generated.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 memeDescription:
 *                   type: string
 *                   example: "(Vadivelu template) En intha aanantham..."
 *       400:
 *         description: Bad request.
 */
