// Pins that the users route constants are declared once in the client under these names: the
// create form's store owns them and the editor's store imports them (DW-2260). A copy under another
// name is not caught here.
//
// Mutation (Rule 19): re-declare `USERS_PATH` or `USERS_FORM_PATH` in `user-editor.store.ts` -> red.

import assert from 'node:assert/strict';
import { relative } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { blankComments, walkSource } from './source-scan.mjs';

const SRC = fileURLToPath(new URL('../src', import.meta.url));

const declarations = (name) => {
  const pattern = new RegExp(`\\bconst ${name}\\s*[:=]`);
  const files = [];
  walkSource(SRC, (full, text) => {
    if (full.endsWith('.ts') && !full.endsWith('.spec.ts') && pattern.test(blankComments(text))) {
      files.push(relative(SRC, full));
    }
  });
  return files;
};

for (const name of ['USERS_PATH', 'USERS_FORM_PATH']) {
  test(`${name} is declared once in the client sources`, () => {
    assert.deepEqual(declarations(name), ['app/areas/permissions/user-create-form.store.ts']);
  });
}
