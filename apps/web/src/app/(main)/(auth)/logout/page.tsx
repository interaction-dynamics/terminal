import { LogOut, Terminal } from 'lucide-react';
import { signOut } from '@/adapters/authentication';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { getProductName } from '@/config/project';

export default function LogoutPage() {
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
          <CardTitle className="text-xl">Sign out</CardTitle>
          <CardDescription>Are you sure you want to sign out?</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            action={async () => {
              'use server';
              await signOut({ redirectTo: '/' });
            }}
          >
            <Button type="submit" variant="destructive" className="w-full gap-2">
              <LogOut size={16} />
              Sign out
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
