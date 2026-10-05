/**
 * When a cut-cell tooltip shows (DW-2028, Story 19.8): after the pointer has rested on a cell for
 * `--ocu-motion-tooltip-delay`, and, for the active cell, in the frame after the move's own scroll
 * events. The shared data table keeps its own copy of these inline; Data browser's grid takes them
 * from here, since an area screen arms no timer of its own. It is not auto-refresh (AD-43): it reads
 * nothing and writes no store.
 */

/** `--ocu-motion-tooltip-delay` in milliseconds: 300 unless reduced motion zeroes it. */
export function tooltipDelayMs(): number {
  const raw = getComputedStyle(document.documentElement).getPropertyValue('--ocu-motion-tooltip-delay').trim();
  const value = parseFloat(raw);
  if (!Number.isFinite(value)) return 300;
  return raw.endsWith('ms') ? value : raw.endsWith('s') ? value * 1000 : value;
}

/** Run `callback` once the tooltip delay has passed; the answer cancels it. */
export function afterTooltipDelay(callback: () => void): () => void {
  const handle = setTimeout(callback, tooltipDelayMs());
  return () => clearTimeout(handle);
}

/** Run `callback` in the next frame, after that frame's scroll events have been dispatched. */
export function nextFrame(callback: () => void): void {
  if (typeof requestAnimationFrame === 'function') requestAnimationFrame(() => callback());
  else setTimeout(callback, 0);
}
