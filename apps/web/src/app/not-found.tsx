import './(main)/globals.css';
import { Geist } from 'next/font/google';
import { Search } from 'lucide-react';
import { ThemeProvider } from '@/components/theme-provider';
import { ErrorLayout } from '@/components/error-layout';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

export default function NotFound() {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      <div className={`${geistSans.variable} font-sans`}>
        <ErrorLayout
          title="Lost in Digital Space"
          icon={
            <Search
              className="w-16 h-16 text-primary animate-bounce"
              style={{ animationDuration: '3s' }}
            />
          }
          description="We've searched high and low, but couldn't find the page you requested. It might have moved to a new location, been renamed, or perhaps it never existed in the first place."
          error="Error Code: 404 - Page Not Found"
        />
      </div>
    </ThemeProvider>
  );
}
