import { z } from 'zod';

// Waitlist quiz: 6 interest areas x 5 prompts, ids R1..C5, each answered 0/1/2.
export const WAITLIST_AREAS = ['R', 'I', 'A', 'S', 'E', 'C'] as const;
export const WAITLIST_QUESTION_IDS = WAITLIST_AREAS.flatMap(a => [1, 2, 3, 4, 5].map(n => `${a}${n}`));

export const WaitlistSchema = z.strictObject({
  email: z.string().trim().toLowerCase().max(254).pipe(z.email()),
  consent: z.literal(true),
  company: z.string().max(200).optional(), // honeypot
  // Optional: people may join without taking the quiz.
  answers: z.strictObject(
    Object.fromEntries(WAITLIST_QUESTION_IDS.map(id => [id, z.number().int().min(0).max(2)]))
  ).nullish(),
});

export const scoreAnswers = (answers: Record<string, number>) =>
  Object.fromEntries(
    WAITLIST_AREAS.map(a => [a, [1, 2, 3, 4, 5].reduce((sum, n) => sum + answers[`${a}${n}`], 0)])
  ) as Record<(typeof WAITLIST_AREAS)[number], number>;
