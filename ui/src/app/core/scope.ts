/**
 * The namespace every read and write the shell makes executes against (AD-44).
 *
 * `?ns=` is data scope, not decoration: the route names a namespace, `ApiService` attaches the
 * resolved one to every call, and changing it re-fetches in place rather than re-routing. This
 * service is where "the resolved one" is decided, and it is framework-free so `node --test`
 * executes it.
 *
 * **The namespace is chosen from the set the user can read, never taken as a caller string**
 * (AD-21, AD-48). `GET /api/ocupilot/namespaces` answers that set, each entry carrying whether
 * the user may also write there and, when it may not and the reason is a privilege, the
 * `(resource, permission)` pair that failed.
 *
 * **The list read itself never carries `ns`.** It is the recovery channel: a stale or
 * hand-typed namespace the instance refuses must not be able to close the list that would fix it.
 * Nothing else is sent unscoped, and nothing is sent scoped at all until the list has arrived --
 * before then `namespace()` is `''` and `ApiService` attaches nothing, so the shell cannot spend
 * its first requests on a namespace it has not been told it may enter.
 *
 * **A requested namespace the list does not carry is verified once, and then given up on.** The
 * list says which namespaces the user may enter; it does not say why one is missing, because a
 * namespace the user cannot read is absent from it rather than listed as refused. So the one
 * request that can answer that question is made: the same read, scoped to the requested
 * namespace, whose refusal carries `NS.DENIED` and the failed pair (or `NS.UNKNOWN`, which has no
 * pair because no privilege would fix it). That is the request AC "DW-8" describes, it is made at
 * most once per requested name, and its answer is what `unresolved()` hands the switch to name.
 */

import type { ApiService } from './api';
// The `.ts` extension is what `node --test`'s resolver needs to follow a runtime import between
// two core modules, the same reason `navigation.ts` spells `screens.generated.ts` in full.
import { NAMESPACE_PARAM } from './navigation.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const NAMESPACES_PATH = '/api/ocupilot/namespaces';

/** One namespace the caller may enter, and whether it may also be written to. */
export interface NamespaceEntry {
  readonly name: string;
  readonly writable: boolean;
  /** `resource:permission`, or `''` when the refusal is the mount rather than a privilege. */
  readonly failedPair: string;
}

/** A requested namespace the list did not carry, and the reason when the instance gave one. */
export interface UnresolvedScope {
  readonly name: string;
  readonly failedPair: string;
}

export interface ScopeOptions {
  readonly api: ApiService;
}

/**
 * The namespaces the switch offers: those the user can read **and** write
 * (`epics.md:1397`, EXPERIENCE.md `:315`).
 *
 * A readable, non-writable namespace is still reported and is still honoured when a route is
 * already scoped to it (DW-7) -- it is simply not somewhere the switch sends anyone. Exported so
 * the rule is one function rather than a filter spelled inside a component.
 */
export function writableNamespaces(
  entries: readonly NamespaceEntry[]
): readonly NamespaceEntry[] {
  return entries.filter((entry) => entry.writable);
}

/**
 * `url` with its `ns` parameter set to `namespace` -- the path, the fragment and every other
 * query parameter untouched, and `ns` kept where it already was.
 *
 * A different operation from `navigation.ts`'s `withQuery`, which carries `ns` onto a *different*
 * route: this one changes the scope of the route the user is already on, which is what makes a
 * selection re-fetch in place instead of re-routing (AD-44). Each pair keeps its own spelling,
 * so nothing else on the URL is re-encoded on the way through.
 */
export function withNamespace(url: string, namespace: string): string {
  const hashCut = url.indexOf('#');
  const fragment = hashCut < 0 ? '' : url.slice(hashCut);
  const head = hashCut < 0 ? url : url.slice(0, hashCut);
  const queryCut = head.indexOf('?');
  const path = queryCut < 0 ? head : head.slice(0, queryCut);
  const pairs = queryCut < 0 ? [] : head.slice(queryCut + 1).split('&');
  const encoded = NAMESPACE_PARAM + '=' + encodeURIComponent(namespace);

  const next: string[] = [];
  let replaced = false;
  for (const pair of pairs) {
    if (pair === '') continue;
    if (pair.split('=')[0] !== NAMESPACE_PARAM) {
      next.push(pair);
      continue;
    }
    if (replaced) continue;
    replaced = true;
    if (namespace !== '') next.push(encoded);
  }
  if (!replaced && namespace !== '') next.push(encoded);

  const query = next.join('&');
  return path + (query === '' ? '' : '?' + query) + fragment;
}

/**
 * `namespace` in the spelling the instance itself uses, mirroring
 * `OcuPilot.Api.Router.CanonicalNamespace`.
 *
 * IRIS stores and returns an explicit namespace name uppercase whatever case it was input in, so
 * the server canonicalises `?ns=` before it resolves anything. Without the same rule here a route
 * spelled `?ns=user` reads as a namespace the roster (`USER`) does not carry, and the switch
 * replaces a scope the instance had already accepted -- moving the user off the namespace they
 * asked for and saying nothing. An implicit namespace is a directory path the roster drops and no
 * route is scoped to, so it does not match and is left alone.
 */
export function canonicalNamespace(namespace: string): string {
  return /^[A-Za-z%][A-Za-z0-9%_-]*$/.test(namespace) ? namespace.toUpperCase() : namespace;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

interface NamespaceWire {
  name?: unknown;
  writable?: unknown;
  failedPair?: unknown;
}

interface NamespacesWire {
  scope?: unknown;
  namespaces?: unknown;
}

export class ScopeService {
  private readonly api: ApiService;

  /** What the route asked for. `''` when it carries no `ns` at all. */
  private requestedNs = '';

  private entries: readonly NamespaceEntry[] = [];

  /** The namespace the instance said the unscoped read resolved to: the fallback target. */
  private echoedScope = '';

  private loadedOnce = false;

  private inFlight: Promise<void> | null = null;

  /** The one requested namespace a scoped read has refused, and the pair it named. */
  private deniedName = '';

  private deniedPair = '';

  /** Requested names already verified, so the one extra request is made at most once each. */
  private readonly verified = new Set<string>();

  /**
   * Bumped by `reset()`, and read across every `await` below. A list requested by one principal
   * must never be installed after another has taken the tab: sign-out clears the tab in place, so
   * a read started before it can still resume afterwards and reinstate the previous principal's
   * namespaces (AD-8). `NavigationService` and `InstanceService` carry the same counter for the
   * same reason.
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: ScopeOptions) {
    this.api = options.api;
  }

  /** Whether the list has been received at all. Nothing is scoped until it has. */
  loaded(): boolean {
    return this.loadedOnce;
  }

  /** The namespaces the caller may enter, readable-but-not-writable ones included. */
  namespaces(): readonly NamespaceEntry[] {
    return this.entries;
  }

  /** What the route asked for, whether or not the instance allows it. */
  requested(): string {
    return this.requestedNs;
  }

  /**
   * The scope every call carries: the requested namespace when the list allows it, otherwise the
   * one the instance itself resolved to. `''` until the list has arrived, which is what keeps a
   * bad `ns` from reaching the instance at all.
   */
  namespace(): string {
    if (!this.loadedOnce) return '';
    if (this.requestedNs !== '' && this.isListed(this.requestedNs)) return this.requestedNs;
    return this.echoedScope;
  }

  /**
   * The requested namespace the list rejected, with the pair the instance named when a scoped
   * read has already come back and named one. `null` while nothing is rejected -- including
   * before the list has arrived, when nothing has been rejected yet.
   *
   * Live, not remembered: this is what the switch decides whether to replace the URL on, and a
   * remembered rejection would make it replace a URL that is already correct.
   */
  unresolved(): UnresolvedScope | null {
    if (!this.loadedOnce) return null;
    if (this.requestedNs === '') return null;
    if (this.isListed(this.requestedNs)) return null;
    const failedPair = this.deniedName === this.requestedNs ? this.deniedPair : '';
    return { name: this.requestedNs, failedPair };
  }

  /**
   * The last namespace a scoped read refused over a privilege, and the pair it named -- the
   * sentence the shell owes the user for a scope it silently changed under them.
   *
   * Remembered rather than live, and that is the whole point: the refusal arrives from a request
   * made *because* the namespace was not in the list, and by the time it lands the switch has
   * already put the resolved scope in the URL, so `unresolved()` is `null` again. Cleared when
   * the user chooses a namespace themselves, and by `reset()`.
   */
  refusal(): UnresolvedScope | null {
    if (this.deniedName === '') return null;
    return { name: this.deniedName, failedPair: this.deniedPair };
  }

  /**
   * The route's own `ns`, reported by whoever watches the router. A repeat of the value already
   * held changes nothing and notifies nobody, so a router event per navigation does not re-fetch
   * a screen that has not moved.
   */
  setRequested(namespace: string): void {
    const canonical = canonicalNamespace(namespace);
    if (canonical === this.requestedNs) return;
    this.requestedNs = canonical;
    this.notify();
    this.verifyRequested();
  }

  /** Forget the refusal above: the user has answered it by choosing a namespace. */
  private clearRefusal(): void {
    if (this.deniedName === '') return;
    this.deniedName = '';
    this.deniedPair = '';
  }

  /**
   * The user's choice from the switch. Refused -- and nothing published -- unless it is one of
   * the namespaces the instance offered for writing: the namespace is chosen from the set the
   * user can read, never taken as a caller string (AD-21, AD-48), and that holds for a value the
   * client invents as much as for one a URL carries.
   */
  select(namespace: string): boolean {
    const canonical = canonicalNamespace(namespace);
    if (!writableNamespaces(this.entries).some((entry) => entry.name === canonical)) return false;
    this.clearRefusal();
    this.setRequested(canonical);
    this.notify();
    return true;
  }

  /**
   * Fetch the list. One request however many callers, for the reason `NavigationService.load()`
   * is single-flight.
   */
  load(): Promise<void> {
    const running = this.inFlight;
    if (running !== null) return running;
    let settle: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      settle = resolve;
    });
    this.inFlight = gate;
    void this.runLoad()
      .catch(() => undefined)
      .finally(() => {
        if (this.inFlight === gate) this.inFlight = null;
        settle();
      });
    return gate;
  }

  /**
   * Forget the list. The verdicts are about **this user** (AD-8), and sign-out clears the tab in
   * place without a reload, so a second principal must not inherit the first one's namespaces.
   */
  reset(): void {
    this.generation += 1;
    this.entries = [];
    this.echoedScope = '';
    this.loadedOnce = false;
    this.inFlight = null;
    this.deniedName = '';
    this.deniedPair = '';
    this.verified.clear();
    this.notify();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private isListed(namespace: string): boolean {
    return this.entries.some((entry) => entry.name === namespace);
  }

  private async runLoad(): Promise<void> {
    // `scope: null` and not merely "the scope happens to be empty": this read is the recovery
    // channel, and it must stay unscoped on every later call as well as the first.
    const generation = this.generation;
    const result = await this.api.requestJson<NamespacesWire>(NAMESPACES_PATH, { scope: null });
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') return;
    const body = result.body ?? {};
    const raw = Array.isArray(body.namespaces) ? body.namespaces : [];
    const entries: NamespaceEntry[] = [];
    for (const item of raw) {
      if (typeof item !== 'object' || item === null) continue;
      const entry = item as NamespaceWire;
      const name = asString(entry.name);
      if (name === '') continue;
      entries.push({
        name,
        writable: entry.writable === true,
        failedPair: asString(entry.failedPair),
      });
    }
    this.entries = entries;
    this.echoedScope = asString(body.scope);
    this.loadedOnce = true;
    this.notify();
    this.verifyRequested();
  }

  /**
   * Ask the instance why the requested namespace is not in the list, once. The list carries only
   * namespaces the caller may enter, so absence alone cannot tell "you may not read it" from "it
   * is not there" -- and only the first of those has a sentence to show.
   */
  private verifyRequested(): void {
    const namespace = this.requestedNs;
    if (namespace === '' || !this.loadedOnce) return;
    if (this.isListed(namespace)) return;
    if (this.verified.has(namespace)) return;
    this.verified.add(namespace);
    void this.runVerify(namespace);
  }

  private async runVerify(namespace: string): Promise<void> {
    const generation = this.generation;
    const result = await this.api.requestJson<unknown>(NAMESPACES_PATH, { scope: namespace });
    if (generation !== this.generation) return;
    if (result.kind !== 'error') return;
    const failedPair = asString(result.detail?.['failedPair']);
    // No pair means no privilege would have helped -- a namespace that does not exist -- and
    // EXPERIENCE.md publishes no sentence for that, so nothing is recorded and nothing is said.
    if (failedPair === '') return;
    // Recorded whatever the route has moved on to. By the time this lands the switch has already
    // put the resolved scope in the URL, which is exactly the change the user is owed a reason
    // for; discarding it because the route no longer names the refused namespace would throw
    // away the only answer there is.
    this.deniedName = namespace;
    this.deniedPair = failedPair;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}

/**
 * Run `onChange` whenever the **resolved** scope moves, and not when anything else about the
 * service does.
 *
 * This is the channel AD-44's "switching re-fetches rather than re-routing" travels on: its
 * consumer in this story is `NavigationService`, and Story 1.14's re-fetch framework and Epic 5's
 * context chip subscribe to the same one. Separate from `subscribe()` because the switch needs
 * every notification -- the list arriving, a refusal being named -- while a consumer re-reading
 * its data must only be woken when the scope it would read with is actually different.
 */
export function onScopeChange(scope: ScopeService, onChange: () => void): () => void {
  let last = scope.namespace();
  return scope.subscribe(() => {
    const next = scope.namespace();
    if (next === last) return;
    last = next;
    onChange();
  });
}
