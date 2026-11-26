export * from './i18n';

const rightToLeftLocales = new Set([
  'ar',
  'arc',
  'dv',
  'fa',
  'ha',
  'he',
  'khw',
  'ks',
  'ku',
  'ps',
  'ur',
  'yi',
]);

const isRTL = (locale: string) => rightToLeftLocales.has(locale);

export function dir(locale: string) {
  return isRTL(locale) ? 'rtl' : 'ltr';
}
