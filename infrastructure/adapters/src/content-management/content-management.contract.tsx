import { Post } from '@ship-it/entities';
import { renderToStaticMarkup } from 'react-dom/server';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ContentClient } from './interfaces';

export interface ContentManagementContractHarness {
  /** Imports a fresh copy of the adapter. */
  load: () => Promise<ContentClient>;
  /**
   * Makes the mocked CMS publish these posts. Leave it out for an adapter that cannot hold
   * content, such as `blank`; the tests that need content are then skipped.
   */
  publish?: (posts: Post[]) => void;
}

const posts: Post[] = [
  {
    title: 'Shipping fast',
    slug: 'shipping-fast',
    content: 'Body',
    description: 'How we ship',
    date: '2026-01-01',
    categories: ['engineering'],
  },
  {
    title: 'Pricing update',
    slug: 'pricing-update',
    content: 'Body',
    description: 'New plans',
    date: '2026-02-01',
    categories: ['news'],
  },
];

/**
 * Behaviour every `ContentClient` must share so a CMS can replace another.
 * Call it from `<vendor>/<vendor>.contract.test.tsx` with the CMS SDK mocked.
 */
export function describeContentManagementContract(
  vendor: string,
  harness: ContentManagementContractHarness,
): void {
  describe(`${vendor} content management adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
    });

    it('returns posts that satisfy the Post entity', async () => {
      harness.publish?.(posts);
      const { fetchPosts } = await harness.load();

      expect(Post.array().safeParse(await fetchPosts()).success).toBe(true);
    });

    it('returns null for a slug that was never published', async () => {
      harness.publish?.(posts);
      const { fetchOnePost } = await harness.load();

      await expect(fetchOnePost('no-such-post')).resolves.toBeNull();
    });

    it('renders rich text without throwing, even when the content is empty', async () => {
      const { RichText } = await harness.load();

      expect(() => renderToStaticMarkup(<>{RichText({ content: undefined })}</>)).not.toThrow();
    });

    describe.skipIf(!harness.publish)('with published posts', () => {
      it('lists every published post', async () => {
        harness.publish?.(posts);
        const { fetchPosts } = await harness.load();

        await expect(fetchPosts()).resolves.toEqual(posts);
      });

      it('finds a post by its slug', async () => {
        harness.publish?.(posts);
        const { fetchOnePost } = await harness.load();

        await expect(fetchOnePost('pricing-update')).resolves.toEqual(posts[1]);
      });
    });
  });
}
