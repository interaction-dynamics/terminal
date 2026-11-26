import { Geist, Geist_Mono } from 'next/font/google';
import { ThemeProvider } from '@/components/theme-provider';

import './globals.css';
import type { Metadata } from 'next';
import { AnalyticsScript } from '@ship-it/adapters/analytics';
import { DevToolbar } from '@ship-it/adapters/dev-tools';
import { AuthenticationProvider } from '@/adapters/authentication';
import { ExperimentationProvider } from '@/adapters/experimentation';
import { WebVitals } from '@ship-it/adapters/monitoring/client';
import { dir, getLocale, TranslationProvider } from '@/adapters/translation';
import { env } from '@/config/env';
import { getProductDescription, getProductName } from '@/config/project';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: getProductName(),
  description: getProductDescription(),
};

export interface LocaleLayoutProps {
  children: React.ReactNode;
}

export default async function LocaleLayout({ children }: LocaleLayoutProps) {
  const locale = await getLocale();
  const shouldInjectToolbar = env.NODE_ENV === 'development';

  return (
    <AuthenticationProvider>
      <ExperimentationProvider>
        <html lang={locale} dir={dir(locale)} suppressHydrationWarning>
          <head>
            <AnalyticsScript />
          </head>
          <body className={`${geistSans.variable} ${geistMono.variable} antialiased `}>
            <WebVitals />
            <ThemeProvider
              attribute="class"
              defaultTheme="system"
              enableSystem
              disableTransitionOnChange
            >
              <TranslationProvider defaultNamespace="common">
                <div className="flex min-h-screen flex-col items-stretch">{children}</div>
              </TranslationProvider>
            </ThemeProvider>
            {shouldInjectToolbar && <DevToolbar />}
          </body>
        </html>
      </ExperimentationProvider>
    </AuthenticationProvider>
  );
}
