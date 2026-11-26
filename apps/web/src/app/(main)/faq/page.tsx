import { getTranslations } from '@/adapters/translation';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';

export default async function FaqPage() {
  const { locale, t } = await getTranslations('faq');

  // A template-literal import is typed `any`; describe the shape of the FAQ JSON files.
  const { faq } = (await import(`../../../content/json/faq.${locale}.json`)) as {
    faq: Array<{ question: string; answer: string }>;
  };

  return (
    <div className="w-full max-w-3xl mx-auto py-12 px-4">
      <div className="text-center mb-10">
        <h2 className="text-3xl font-bold tracking-tight">{t('title')}</h2>
        <p className="mt-4 text-muted-foreground">{t('description')}</p>
      </div>
      <Accordion type="single" collapsible className="w-full">
        {faq.map((item) => (
          <AccordionItem value={item.question} key={item.question}>
            <AccordionTrigger className="text-left">{item.question}</AccordionTrigger>
            <AccordionContent>{item.answer}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}
