import { describe, expect, it } from 'vitest';

import { exportFileName, fill } from './term-list-list.page';

/** The Term lists page's two helpers (Story 24.10): the status lines' placeholder fill and the file name an export to this browser is saved under. */
describe('the Term lists page helpers', () => {
  it('fills each placeholder once, in one pass, and leaves a value that looks like a placeholder or a pattern as it is', () => {
    // Mutation (Rule 19): fill with `String.prototype.replace` of the first placeholder only -> the second assertion goes red.
    expect(fill('Copied <name> to <new>.', { name: 'A', new: 'B' })).toBe('Copied A to B.');
    expect(fill('Exported <name>.', { name: '<new> $& $1' })).toBe('Exported <new> $& $1.');
    expect(fill('Exported <name>.', {})).toBe('Exported <name>.');
  });

  it('saves a list as its name with .csv, each character a file name cannot hold made an underscore', () => {
    // Mutation (Rule 19): keep `/` in the name -> the second assertion goes red.
    expect(exportFileName('Probe.List')).toBe('Probe.List.csv');
    expect(exportFileName('a/b:c*d')).toBe('a_b_c_d.csv');
    expect(exportFileName('')).toBe('term-list.csv');
  });
});
