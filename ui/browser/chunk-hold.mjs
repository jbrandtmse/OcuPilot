/**
 * Holds the shell's lazily loaded page chunks, so a spec can observe a create form's hand-off to its
 * editor while the editor's page code is still unloaded (DW-2372).
 *
 * `holdChunks` turns request interception on for `page`; nothing is held until `armed` is set, and
 * `release` lets every held request through. A held request is one for a `chunk-*.js` file under the
 * shell's own path, which is how every lazily loaded page reaches the browser.
 */

import assert from 'node:assert/strict';

const SHELL_PATH = '/ocupilot/';
const CHUNK_RE = /\/chunk-[^/]+\.js$/;

/** The control object: `armed`, the `held` requests, and `release()`. */
export async function holdChunks(page) {
  const control = {
    armed: false,
    held: [],
    release: async () => {
      control.armed = false;
      const held = control.held.splice(0);
      await Promise.all(held.map((request) => request.continue()));
    },
  };
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    const { pathname } = new URL(request.url());
    if (control.armed && pathname.startsWith(SHELL_PATH) && CHUNK_RE.test(pathname)) {
      control.held.push(request);
      return;
    }
    void request.continue();
  });
  return control;
}

/**
 * Press Save with the chunk requests held, and assert what the person sees while the editor's page
 * code is unloaded: the create's POST has answered, a chunk request is waiting, the form's own bar
 * shows no Saved status and the route is still the create form's. Then release the chunks.
 * Answers the number of chunk requests that were held, which is at least one.
 *
 * `save` presses Save; `postSuffix` is the path the create posts to.
 */
export async function saveWithChunksHeld(page, control, config, save, postSuffix) {
  const route = new URL(page.url()).pathname;
  control.armed = true;
  const posted = page.waitForResponse(
    (response) => response.request().method() === 'POST' && new URL(response.url()).pathname.endsWith(postSuffix),
    { timeout: config.navigationTimeoutMs }
  );
  await save();
  const answer = await posted;
  assert.ok(answer.ok(), `the create was accepted (HTTP ${answer.status()})`);
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (control.held.length === 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.ok(control.held.length > 0, "the hand-off asked for the editor's page code, and it is held");
  // Frames and the store's own notification have gone by: a Saved status drawn now would be shown.
  await new Promise((resolve) => setTimeout(resolve, 600));
  const statuses = await page.$$eval('.ocu-form-bar-status [role="status"]', (nodes) => nodes.map((node) => node.textContent.trim()));
  assert.deepEqual(statuses, [], "no Saved status shows while the editor's page code is held");
  assert.equal(new URL(page.url()).pathname, route, 'and the form has not handed off yet');
  const held = control.held.length;
  await control.release();
  return held;
}
