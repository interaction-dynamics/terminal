import * as provider from './blank';
import type { ContentClient } from './interfaces';

export type { ContentClient } from './interfaces';

// To use a CMS, add an adapter that implements ContentClient and swap this provider.
export const { fetchPosts, fetchOnePost, RichText }: ContentClient = provider;
