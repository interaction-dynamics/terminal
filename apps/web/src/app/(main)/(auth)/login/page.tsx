import { Terminal } from 'lucide-react';
import { LoginForm } from '@/adapters/authentication';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { getProductName } from '@/config/project';

export default function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ redirect_url?: string }>;
}) {
  return (
    <div className="w-full max-w-sm px-4">
      <div className="flex justify-center mb-8">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-foreground rounded-lg flex items-center justify-center">
            <Terminal className="w-4 h-4 text-background" />
          </div>
          <span className="text-xl font-bold">{getProductName()}</span>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-xl">Sign in</CardTitle>
          <CardDescription>Enter your email to sign in</CardDescription>
        </CardHeader>
        <CardContent>
          <LoginFormWithParams searchParams={searchParams} />
        </CardContent>
      </Card>
    </div>
  );
}

async function LoginFormWithParams({
  searchParams,
}: {
  searchParams: Promise<{ redirect_url?: string }>;
}) {
  const { redirect_url } = await searchParams;
  return <LoginForm redirectTo={redirect_url ?? '/dashboard'} />;
}
