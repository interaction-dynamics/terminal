import { render } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { findTranslation } from './findTranslation';

const messages = {
  common: {
    greeting: { hello: 'Hello {{name}}, welcome to {{place}}!' },
    terms: 'Read the {{terms}} first',
    pair: '{{first}} and {{second}}',
  },
};

describe('findTranslation', () => {
  it('resolves a nested key and returns a plain string when every argument is a string', () => {
    expect(
      findTranslation('greeting.hello', messages, 'common', { name: 'Ada', place: 'Ship It' }),
    ).toBe('Hello Ada, welcome to Ship It!');
  });

  it('renders React element arguments in place', () => {
    const { container } = render(
      <>{findTranslation('terms', messages, 'common', { terms: <strong>terms</strong> })}</>,
    );

    expect(container.innerHTML).toBe('Read the <strong>terms</strong> first');
  });

  it('renders several element arguments without key collisions', () => {
    const { container } = render(
      <>{findTranslation('pair', messages, 'common', { first: <b>one</b>, second: <i>two</i> })}</>,
    );

    expect(container.innerHTML).toBe('<b>one</b> and <i>two</i>');
  });
});
