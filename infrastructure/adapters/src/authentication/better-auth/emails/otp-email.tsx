import {
  Body,
  Container,
  Head,
  Html,
  Preview,
  Section,
  Tailwind,
  Text,
} from '@react-email/components';

interface OTPEmailProps {
  otp: string;
  type: 'sign-in' | 'email-verification' | 'forget-password' | 'change-email';
}

const titles: Record<OTPEmailProps['type'], string> = {
  'sign-in': 'Sign in to Ship It',
  'email-verification': 'Verify your email',
  'forget-password': 'Reset your password',
  'change-email': 'Confirm email change',
};

const descriptions: Record<OTPEmailProps['type'], string> = {
  'sign-in': 'Enter this code to sign in to your account.',
  'email-verification': 'Enter this code to verify your email address.',
  'forget-password': 'Enter this code to reset your password.',
  'change-email': 'Enter this code to confirm your new email address.',
};

export function OTPEmail({ otp, type }: OTPEmailProps) {
  return (
    <Tailwind>
      <Html lang="en" className="bg-black">
        <Head />
        <Preview>Your verification code: {otp}</Preview>
        <Body className="bg-black font-sans">
          <Container className="bg-black mx-auto max-w-[560px] px-5 py-10">
            <Section className="rounded-xl bg-[#111111] px-10 py-12">
              <Text className="m-0 mb-4 text-[28px] font-bold leading-tight text-white">
                {titles[type]}
              </Text>
              <Text className="m-0 mb-6 text-base leading-relaxed text-neutral-400">
                {descriptions[type]}
              </Text>
              <Section className="mb-6 rounded-lg bg-[#222222] px-6 py-4 text-center">
                <Text className="m-0 font-mono text-[36px] font-bold tracking-[0.3em] text-white">
                  {otp}
                </Text>
              </Section>
              <Text className="m-0 text-sm leading-relaxed text-neutral-500">
                This code expires in 5 minutes. If you didn't request this, you can safely ignore
                this email.
              </Text>
            </Section>
          </Container>
        </Body>
      </Html>
    </Tailwind>
  );
}
