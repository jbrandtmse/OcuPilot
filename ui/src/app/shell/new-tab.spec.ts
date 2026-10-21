import { afterEach, describe, expect, it, vi } from 'vitest';

import { openInNewTab } from './new-tab';

/**
 * `openInNewTab` is the one `window.open` call in the client (AD-47, Story 20.32): a new tab with no opener and no
 * referrer, so the tab does not start with a copy of this tab's token pair (AD-28).
 */
describe('openInNewTab', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  // Mutation (Rule 19): drop `noopener,noreferrer` from the feature string in `new-tab.ts` -> this goes red.
  it('opens the address in a new tab with noopener and noreferrer, once', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    openInNewTab('/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER');
    expect(open).toHaveBeenCalledTimes(1);
    expect(open).toHaveBeenCalledWith('/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER', '_blank', 'noopener,noreferrer');
  });
});
