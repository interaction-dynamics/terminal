export default function AuthLayout({ children }: React.PropsWithChildren) {
  return (
    <div className="flex flex-1 items-center justify-center min-h-[calc(100vh-8rem)]">
      {children}
    </div>
  );
}
