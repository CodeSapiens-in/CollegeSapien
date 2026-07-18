import { z } from 'zod';

export const EventSchema = z.object({
  id: z.string().optional(),
  eventName: z.string().min(2),
  location: z.string().min(2),
  communityName: z.string().min(2),
  communityLogo: z.string().url().or(z.literal('')).optional().default(''),
  eventLink: z.string().url(),
  eventDate: z.string().min(4), // Expecting YYYY-MM-DD or human readable date
  status: z.enum(['pending_moderation', 'approved', 'rejected']).default('pending_moderation'),
  createdBy: z.string().optional(),
  createdAt: z.any().optional(),
  updatedAt: z.any().optional(),
  deletedAt: z.any().optional().nullable(),
});

export type Event = z.infer<typeof EventSchema>;

// Fields an admin may correct while approving a pending event
export const EventEditSchema = EventSchema.pick({
  eventName: true,
  location: true,
  communityName: true,
  communityLogo: true,
  eventLink: true,
  eventDate: true,
}).partial();
