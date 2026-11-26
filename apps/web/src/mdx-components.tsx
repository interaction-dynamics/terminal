import type { MDXComponents } from 'mdx/types';
import type { ComponentProps } from 'react';
import Image, { type ImageProps } from 'next/image';
import { Typography } from '@/components/typography';

export function useMDXComponents(components: MDXComponents): MDXComponents {
  return {
    h1: ({ children }) => <Typography variant="h1">{children}</Typography>,
    h2: ({ children }) => <Typography variant="h2">{children}</Typography>,
    h3: ({ children }) => <Typography variant="h3">{children}</Typography>,
    p: ({ children }) => <Typography variant="p">{children}</Typography>,
    // @types/mdx types `img` props via the global `JSX` namespace, which React 19 removed, so
    // they resolve to `any`; annotate them with React's own `<img>` props instead.
    img: ({ alt, ...props }: ComponentProps<'img'>) => (
      <Image
        sizes="100vw"
        style={{ width: '100%', height: 'auto' }}
        {...(props as ImageProps)}
        alt={alt ?? ''}
      />
    ),
    ...components,
  };
}
