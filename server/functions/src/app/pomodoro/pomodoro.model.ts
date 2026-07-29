import { z } from 'zod';

export const PomodoroTimerSchema = z.object({
  purpose: z.string().min(2).max(80),
});

export const PomodoroMembersSchema = z.object({
  addUids: z.array(z.string()).min(1).max(50),
});

export const PomodoroSessionSchema = z.object({
  mode: z.enum(['focus', 'short_break', 'long_break']),
  durationSec: z
    .number()
    .int()
    .min(60)
    .max(4 * 60 * 60),
});
