/**
 * `highlight.js` ships no per-language `.d.ts` under `lib/languages/*` -- only the top-level
 * package declares types. Without this, importing e.g. `highlight.js/lib/languages/sql` raises
 * TS7016 ("could not find a declaration file") the moment its type is consumed. Verified against
 * `highlight.js` 11.11.2: this one ambient wildcard declaration is clean where the per-module
 * imports are not (Story 4.6).
 *
 * Both `tsconfig.app.json` and `tsconfig.spec.json` include `src/**\/*.d.ts`, so no tsconfig edit
 * accompanies this file.
 */
declare module 'highlight.js/lib/languages/*' {
  import type { LanguageFn } from 'highlight.js';

  const language: LanguageFn;
  export default language;
}
