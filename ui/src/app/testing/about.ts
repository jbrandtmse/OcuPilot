import { ABOUT_FIELDS, ABOUT_LINKS, About, type AboutField, type AboutLink } from '../core/about';
import type { ApiService } from '../core/api';
import { HelpLinks } from '../core/help';

/** One request a stubbed transport was asked for -- `testing/account-preferences.ts`'s shape. */
export interface StubbedAboutCall {
  readonly path: string;
  readonly method: string;
}

export type StubbedAbout = About & {
  readonly calls: readonly StubbedAboutCall[];
  /** Change what the next `load()` answers, so a spec can drive a degraded answer in place. */
  setLinks(links: Partial<Record<AboutLink, string>>): void;
  setFields(fields: Partial<Record<AboutField, string>>): void;
  /** Flip the transport after construction, so one store can answer and then stop answering. */
  setUnreachable(unreachable: boolean): void;
};

export type StubbedHelpLinks = HelpLinks & { readonly calls: readonly StubbedAboutCall[] };

/** What one stub answers, defaulted per member so a spec names only what it is about. */
export interface StubbedAboutSeed {
  readonly fields?: Partial<Record<AboutField, string>>;
  readonly links?: Partial<Record<AboutLink, string>>;
  /** When true the transport never answers, which is the store's unreachable branch. */
  readonly unreachable?: boolean;
}

/**
 * An `About` over a stubbed `GET /ui/about`, for the specs that mount something which injects it
 * without being about it, and for the ones that are -- mirrors `testing/account-preferences.ts`.
 *
 * The real class over a stubbed transport, so a spec that arranges "the instance says this"
 * arranges it the way the instance does, and the store's own parking and narrowing run unchanged.
 */
export function stubAbout(seed: StubbedAboutSeed = {}): StubbedAbout {
  const calls: StubbedAboutCall[] = [];
  const fields: Record<string, string> = {};
  for (const field of ABOUT_FIELDS) fields[field] = seed.fields?.[field] ?? `${field}-value`;
  const links: Record<string, string> = {};
  for (const link of ABOUT_LINKS) links[link] = seed.links?.[link] ?? `https://ocupilot.invalid/${link}`;

  let unreachable = seed.unreachable === true;
  const api = {
    requestJson: async (path: string, init: { method?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET' });
      if (unreachable) {
        return { kind: 'error', status: 0, code: null, reason: null, detail: null };
      }
      return { kind: 'ok', status: 200, body: { ...fields, links } };
    },
  };

  return Object.assign(new About({ api: api as unknown as ApiService }), {
    calls: calls as readonly StubbedAboutCall[],
    setLinks(next: Partial<Record<AboutLink, string>>) {
      for (const [key, value] of Object.entries(next)) links[key] = value;
    },
    setFields(next: Partial<Record<AboutField, string>>) {
      for (const [key, value] of Object.entries(next)) fields[key] = value;
    },
    setUnreachable(next: boolean) {
      unreachable = next;
    },
  });
}

/**
 * A `HelpLinks` over a stubbed `GET /ui/help`, answering `hrefs[route]` for a route it holds one
 * for and unavailable for every other -- which is what a classic page publishing no help address
 * answers.
 */
export function stubHelpLinks(hrefs: Readonly<Record<string, string>> = {}): StubbedHelpLinks {
  const calls: StubbedAboutCall[] = [];
  const api = {
    requestJson: async (path: string, init: { method?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET' });
      const route = decodeURIComponent(path.split('route=')[1] ?? '');
      const href = hrefs[route] ?? '';
      return { kind: 'ok', status: 200, body: { available: href !== '', href } };
    },
  };
  return Object.assign(new HelpLinks({ api: api as unknown as ApiService }), {
    calls: calls as readonly StubbedAboutCall[],
  });
}
