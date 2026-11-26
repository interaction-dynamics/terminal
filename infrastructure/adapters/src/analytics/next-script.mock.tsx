import type { ReactNode } from 'react';

/** Renders `next/script` as a plain tag so a contract test can read what would load. */
export default function Script({ src, children }: { src?: string; children?: ReactNode }) {
  return <script data-src={src}>{children}</script>;
}
