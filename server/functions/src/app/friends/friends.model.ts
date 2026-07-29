import { z } from 'zod';

export const FriendRequestSchema = z.object({
  fromUid: z.string(),
  toUid: z.string(),
  status: z.enum(['pending', 'accepted', 'rejected']).default('pending'),
  createdAt: z.any().optional(),
  updatedAt: z.any().optional(),
});

export type FriendRequest = z.infer<typeof FriendRequestSchema>;

export const AddFriendSchema = z.object({
  email: z.string().email(),
});
