import { render, screen } from '@testing-library/react';
import type { ComponentType, ImgHTMLAttributes } from 'react';
import { describe, expect, it } from 'vitest';
import { useMDXComponents } from './mdx-components';

const MarkdownImage = useMDXComponents({}).img as ComponentType<
  ImgHTMLAttributes<HTMLImageElement>
>;

describe('useMDXComponents img', () => {
  it('keeps the alt text written by the author', () => {
    render(<MarkdownImage src="/diagram.png" width={100} height={100} alt="Request flow" />);

    expect(screen.getByRole('img', { name: 'Request flow' })).toBeInTheDocument();
  });

  it('treats an image without alt text as decorative', () => {
    const { container } = render(<MarkdownImage src="/diagram.png" width={100} height={100} />);

    expect(container.querySelector('img')).toHaveAttribute('alt', '');
  });
});
