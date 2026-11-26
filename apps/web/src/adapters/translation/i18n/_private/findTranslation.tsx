import React from 'react';
import type { Parameters } from '../../_types/parameters';
import type { Translations } from '../../_types/translations';

type Part = { key: string; text: string } | { key: string; argName: string };

const splitByArgs = (str: string, parameters: Parameters): Part[] => {
  let tempStr = str;

  const parts: Part[] = [];

  Object.keys(parameters).forEach((argName) => {
    const placeholder = `{{${argName}}}`;

    const index = tempStr.indexOf(placeholder);

    if (index === -1) return;

    // Each argument name is a distinct object key, so it gives each part a stable React key.
    parts.push({ key: `text-before-${argName}`, text: tempStr.substring(0, index) });
    parts.push({ key: `arg-${argName}`, argName });

    tempStr = tempStr.substring(index + placeholder.length);
  });

  parts.push({ key: 'text-end', text: tempStr });

  return parts;
};

const replaceArgs = (str: string, parameters: Parameters) => {
  const result = splitByArgs(str, parameters).map((part) => ({
    key: part.key,
    value: 'text' in part ? part.text : (parameters[part.argName] ?? ''),
  }));

  const strings = result.map(({ value }) => value).filter((value) => typeof value === 'string');

  if (strings.length === result.length) {
    return strings.join('');
  }

  return (
    <>
      {result.map(({ key, value }) => (
        <React.Fragment key={key}>{value}</React.Fragment>
      ))}
    </>
  );
};

export const findTranslation = (
  key: string,
  messages: Translations,
  namespace: string,
  parameters: Parameters = {},
): React.ReactNode | string => {
  const keys = key.split('.');

  const translations = messages[namespace];

  try {
    const str = keys.reduce<Translations | string | undefined>((acc, segment) => {
      if (typeof acc === 'string') return acc;

      if (acc === undefined || !(segment in acc)) {
        throw new Error(`Impossible to find translation ${segment} in namespace ${namespace}`);
      }

      return acc[segment];
    }, translations);

    if (typeof str !== 'string') {
      throw new Error(`Translation ${key} in namespace ${namespace} is not a string`);
    }

    return replaceArgs(str, parameters);
  } catch (error) {
    console.error(error);
    return key;
  }
};
