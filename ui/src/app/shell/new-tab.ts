/**
 * Opens `href` in a new tab that has no opener (AD-47, Story 20.32): the one `window.open` call in the
 * client. A tab opened without `noopener` starts with a copy of this tab's token pair, which `noopener`
 * and `noreferrer` sever (AD-28), so the feature string is not optional.
 *
 * **Call it synchronously, from the person's own click or key press.** A browser blocks a tab opened
 * from a timer or after an `await` as a popup (inference), so a caller resolves the address before the
 * gesture, never during it. The address is the instance's, answered on the navigation map
 * (`NavigationService.screenHref`); nothing here composes or checks one.
 */
export function openInNewTab(href: string): void {
  window.open(href, '_blank', 'noopener,noreferrer');
}
