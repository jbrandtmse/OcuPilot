import type { Router } from '@angular/router';

/**
 * Follow an in-app link a click activated (AD-20): a plain click navigates the router to `url`, as the browser would navigate to the
 * link's `href`; a click that carries Ctrl, Meta, Shift or Alt, or that is not the primary button, is left to the browser's own default
 * (a new tab, a new window, a download). The table's name cells, the session trace's arrows and the host test's trace link all follow
 * through this one function.
 */
export function followInAppLink(event: MouseEvent, router: Router, url: string): void {
  if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button !== 0) return;
  event.preventDefault();
  void router.navigateByUrl(url);
}
