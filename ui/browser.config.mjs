/**
 * The headless-browser harness's configuration (Story 1.17, DW-159's harness half).
 *
 * **What this harness is for, and what it is not.** jsdom renders nothing: it has no layout, no
 * paint and no real navigation, so every `*.spec.ts` in `src/` can assert that an element exists
 * and none of them can assert that it has a size, that a deep link resolves through the server's
 * own fallback, or that a cookie a classic-portal login minted is presented on the next request.
 * Those three are what the one spec beside this file asserts, and they are exactly the
 * assertions the shell's own acceptance criteria rest on.
 *
 * **It runs against a throwaway container, never the live one.** The default origin is the
 * throwaway's published web port (52776), not 52774. A run pointed at 52774 would be driving the
 * owner's instance, signing in to it and minting sessions on it, which is what
 * `scripts/ci-throwaway.sh` exists to make unnecessary.
 *
 * **The browser is a dev dependency and reaches no shipped byte** (NFR-10). `puppeteer` is
 * pinned to an exact version in `devDependencies`; nothing in `src/` imports it, and
 * `ui/tools/build-output.test.mjs` asserts over what the build actually emits.
 */

/** The origin the spec drives. Never the live container's 52774 -- see this file's header. */
export const DEFAULT_ORIGIN = 'http://localhost:52776';

/** The shell's own path, the one the install roster declares. */
export const SHELL_PATH = '/ocupilot/';

/** A client route no file exists for: the deep link the server answers with `index.html`. */
export const DEEP_LINK_PATH = '/ocupilot/namespaces';

/** The classic portal's login form, which is what mints the browser-id cookie (AD-28). */
export const CLASSIC_LOGIN_PATH = '/csp/sys/UtilHome.csp';

/** The readiness endpoint, used to refuse to run at all against an instance that is not ready. */
export const READINESS_PATH = '/api/ocupilot/readiness/';

/**
 * The run's settings, resolved from the environment so CI and a developer's own machine differ
 * only in what they export.
 *
 * `OCUPILOT_BROWSER_EXECUTABLE` exists because the browser binary is not always the one
 * `puppeteer` downloaded: a CI runner may cache it elsewhere, and a developer may have a
 * compatible Chrome already installed. It is an override, never a default -- unset, the pinned
 * download is what runs, which is what "pinned to an exact version" has to mean.
 */
export function browserConfig(env = process.env) {
  return {
    origin: env.OCUPILOT_BROWSER_ORIGIN ?? DEFAULT_ORIGIN,
    username: env.OCUPILOT_BROWSER_USER ?? '_SYSTEM',
    password: env.OCUPILOT_BROWSER_PASSWORD ?? 'SYS',
    executablePath: env.OCUPILOT_BROWSER_EXECUTABLE ?? '',
    // Wide enough that the rail and the side bar are both laid out: the shell collapses the
    // side bar below its own breakpoint, and a spec that asserted a non-zero width at a phone
    // width would be asserting the collapse rather than the layout.
    viewport: { width: 1440, height: 900 },
    navigationTimeoutMs: 30000,
  };
}

/** The launch options, so the spec states none of its own. */
export function launchOptions(config) {
  const options = {
    headless: true,
    // CI runs as root in a container, where Chrome's own sandbox cannot start. The browser is
    // driving one instance this job created and nothing else.
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
    defaultViewport: config.viewport,
  };
  if (config.executablePath !== '') options.executablePath = config.executablePath;
  return options;
}
