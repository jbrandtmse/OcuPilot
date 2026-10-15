import type { Router } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { followInAppLink } from './in-app-link';

/** A router that records the URLs it was asked to navigate to. */
function recorder(): { readonly router: Router; readonly urls: string[] } {
  const urls: string[] = [];
  const router = {
    navigateByUrl: (url: string): Promise<boolean> => {
      urls.push(url);
      return Promise.resolve(true);
    },
  } as unknown as Router;
  return { router, urls };
}

/** Follow `url` for a click carrying `init`, and answer what the click did. */
function follow(init: MouseEventInit): { readonly urls: string[]; readonly prevented: boolean } {
  const { router, urls } = recorder();
  const event = new MouseEvent('click', { bubbles: true, cancelable: true, ...init });
  followInAppLink(event, router, '/interoperability/messages/trace/41?ns=USER');
  return { urls, prevented: event.defaultPrevented };
}

/**
 * The one function a table's name cell, the session trace's arrows and the host test's trace link follow in-app links through:
 * a plain primary click navigates the router and keeps the browser from following the `href`; a click that carries a modifier or is
 * not the primary button is left to the browser.
 */
describe('followInAppLink', () => {
  // Mutation (Rule 19): drop the `preventDefault` -> the prevented leg goes red; drop the navigation -> the URL leg goes red.
  it('navigates the router on a plain primary click and stops the browser following the link', () => {
    const plain = follow({});
    expect(plain.urls).toEqual(['/interoperability/messages/trace/41?ns=USER']);
    expect(plain.prevented).toBe(true);
  });

  // Mutation (Rule 19): drop `event.ctrlKey ||` from the guard -> the Ctrl leg goes red, and likewise for each other term.
  it('leaves a Ctrl, Meta, Shift or Alt click, and a click of another button, to the browser', () => {
    for (const init of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }, { button: 2 }]) {
      const result = follow(init);
      expect(result.urls, JSON.stringify(init)).toEqual([]);
      expect(result.prevented, JSON.stringify(init)).toBe(false);
    }
  });
});
