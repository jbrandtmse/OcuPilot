/**
 * The client's own source read as text, for the static guards under `ui/tools`: a walk over the
 * scanned files, and comments blanked so that a match keeps its line number. Shared by
 * `api.test.mjs` (the credential-channel and frame bans) and `vendor-frame.test.mjs` (the frame
 * address's one source).
 */

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const SCAN_EXTENSIONS = new Set(['.ts', '.html', '.scss', '.json', '.js', '.mjs']);
const PRUNE = new Set(['node_modules', 'dist', '.angular']);

/** Call `onFile(fullPath, text)` for every scanned file under `dir`, skipping dependency and build trees. */
export function walkSource(dir, onFile) {
  for (const entry of readdirSync(dir)) {
    if (PRUNE.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      walkSource(full, onFile);
      continue;
    }
    if (!SCAN_EXTENSIONS.has(entry.slice(entry.lastIndexOf('.')))) continue;
    onFile(full, readFileSync(full, 'utf8'));
  }
}

// Comments are prose: a rule list and a module header may NAME a forbidden API or path in order to
// explain it, and failing a guard on an explanation would leave no way to write one. `client-lint.mjs`
// applies the same treatment.
const COMMENT_RE = /\/\*[\s\S]*?\*\/|(?:^|(?<=[\s;{}(]))\/\/[^\n]*/g;

/** `text` with every comment replaced by spaces, line breaks kept, so offsets and lines still match. */
export function blankComments(text) {
  return text.replace(COMMENT_RE, (m) => m.replace(/[^\n]/g, ' '));
}
