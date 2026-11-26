import type { Post } from '@ship-it/entities';

export const fetchPosts = async (): Promise<Post[]> => [];

export const fetchOnePost = async (_slug: string): Promise<Post | null> => null;

export const RichText = (_props: { content: unknown }) => null;
