import type { Post } from '@ship-it/entities';

/** Port for reading published content. */
export interface ContentClient {
  fetchPosts: () => Promise<Post[]>;
  fetchOnePost: (slug: string) => Promise<Post | null>;
  RichText: (props: { content: unknown }) => React.ReactNode;
}
