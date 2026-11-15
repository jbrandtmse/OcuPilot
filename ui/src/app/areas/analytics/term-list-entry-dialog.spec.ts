import { describe, expect, it } from 'vitest';

import { fieldNamesOf } from './term-list-dialog';
import { pairsOf } from './term-list-entry-dialog';

describe('the term list editor helpers (Story 24.2)', () => {
  it('reads each field value out of the row text, a value that holds the separator staying whole', () => {
    expect(pairsOf(['Region', 'Note'], 'Region: West; Note: a; b')).toEqual({ Region: 'West', Note: 'a; b' });
    expect(pairsOf(['Region', 'Note'], 'Region: ; Note: x')).toEqual({ Region: '', Note: 'x' });
    expect(pairsOf([], '')).toEqual({});
  });

  it('stops at a field the text does not carry in order, rather than guessing', () => {
    expect(pairsOf(['Region', 'Note'], 'Other: 1')).toEqual({});
  });

  it('takes the typed field names one per line and drops blank lines and padding', () => {
    expect(fieldNamesOf(' Region \n\nNote\n')).toEqual(['Region', 'Note']);
    expect(fieldNamesOf('')).toEqual([]);
  });
});
