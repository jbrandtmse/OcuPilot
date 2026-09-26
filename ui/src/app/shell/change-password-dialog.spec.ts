import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../core/api';
import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { ChangePasswordDialog } from './change-password-dialog';

/**
 * The change-password dialog's rendered contract (Story 15.1): two masked, write-only fields with
 * labelled reveal toggles, the instance's own refusal wired to the field it names, and a dialog
 * that sends nothing it was not asked to.
 *
 * `dialog.spec.ts` owns the modal behaviour this wraps -- focus trap, initial focus, Escape,
 * focus return -- and `account-menu.spec.ts` owns the opener and the announcement. What is only
 * observable here is the form: the field wiring, the summary, and what reaches the wire.
 *
 * Mutations (Rule 19), each applied to `change-password-dialog.ts`, observed red here alone, and
 * reverted: drop the empty-field guard from `submit()` -> "an empty field is refused before the
 * request" red; render the refusal without `aria-describedby` -> "a refusal is wired to the field
 * it names" red; keep the values on the inputs after a success -> "a change clears both fields"
 * red; delete the `finished` re-check after the awaited `changePassword` call -> "dismissing
 * mid-flight" red, because the resolved `ok` outcome then re-emits `changed` and clears the
 * (already-removed) fields after the user had already dismissed the dialog.
 */

const CURRENT = 'theOldOne9Z';
const NEXT = 'theNewOne9Z';

function refusal(field: string, code: string, reason: string): JsonResult<unknown> {
  return {
    kind: 'error',
    status: 422,
    code: 'ACCOUNT.VALIDATION',
    reason: 'The password change was refused.',
    detail: { violations: [{ field, code, reason }] },
  };
}

describe('the change password dialog', () => {
  let fixture: ComponentFixture<ChangePasswordDialog>;
  let requests: { path: string; method: string; body: unknown }[];
  let answer: JsonResult<unknown>;
  let closes: number;
  let changes: number;
  /** What `requestJson` awaits before answering -- resolved by default, held open by one case. */
  let pending: Promise<void>;
  const planted: HTMLElement[] = [];

  const fields = (): HTMLInputElement[] => [
    ...fixture.nativeElement.querySelectorAll('input.ocu-field-input'),
  ];
  const toggles = (): HTMLButtonElement[] => [
    ...fixture.nativeElement.querySelectorAll('.ocu-reveal-toggle'),
  ];
  const action = (): HTMLButtonElement =>
    fixture.nativeElement.querySelector('.ocu-dialog-actions .ocu-button-primary');
  const cancel = (): HTMLButtonElement =>
    fixture.nativeElement.querySelector('.ocu-dialog-actions .ocu-button-secondary');
  const summary = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('.ocu-form-summary');
  const errors = (): HTMLElement[] => [
    ...fixture.nativeElement.querySelectorAll('.ocu-form-error'),
  ];

  async function submitWith(current: string, next: string): Promise<void> {
    fields()[0].value = current;
    fields()[1].value = next;
    action().click();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    requests = [];
    closes = 0;
    changes = 0;
    answer = { kind: 'ok', status: 200, body: {} };
    pending = Promise.resolve();
    const api = {
      requestJson: async (
        path: string,
        init: { method?: string; body?: string } = {}
      ): Promise<JsonResult<unknown>> => {
        requests.push({ path, method: init.method ?? 'GET', body: init.body });
        await pending;
        return answer;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    fixture = TestBed.createComponent(ChangePasswordDialog);
    fixture.componentInstance.closed.subscribe(() => {
      closes += 1;
    });
    fixture.componentInstance.changed.subscribe(() => {
      changes += 1;
    });
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('AC1: it is one dialog over two masked fields, both empty, each with a labelled reveal toggle', () => {
    expect(fixture.nativeElement.querySelectorAll('[role="dialog"]')).toHaveLength(1);
    expect(
      (fixture.nativeElement.querySelector('.ocu-dialog-title') as HTMLElement).textContent?.trim()
    ).toBe(STRINGS.accountChangePassword);
    expect(action().textContent?.trim()).toBe(STRINGS.accountChangePassword);
    expect(cancel().textContent?.trim()).toBe(STRINGS.actionCancel);

    const labels = [...fixture.nativeElement.querySelectorAll('.ocu-field-label')].map(
      (node: HTMLElement) => node.textContent?.trim()
    );
    expect(labels).toEqual([STRINGS.accountCurrentPasswordLabel, STRINGS.accountNewPasswordLabel]);

    for (const field of fields()) {
      expect(field.type).toBe('password');
      expect(field.value).toBe('');
      expect(field.getAttribute('aria-invalid')).toBe('false');
    }
    // Each label is bound to its own control, which is what makes the fields nameable at all.
    const labelFor = [...fixture.nativeElement.querySelectorAll('.ocu-field-label')].map(
      (node: HTMLElement) => node.getAttribute('for')
    );
    expect(labelFor).toEqual(fields().map((field) => field.id));
    for (const toggle of toggles()) {
      expect(toggle.getAttribute('aria-label')).toBe(STRINGS.accountShowPassword);
      expect(toggle.getAttribute('aria-pressed')).toBe('false');
    }
  });

  it('a reveal toggle unmasks its own field and takes the Hide name', () => {
    toggles()[1].click();
    fixture.detectChanges();
    expect(fields()[0].type).toBe('password');
    expect(fields()[1].type).toBe('text');
    expect(toggles()[1].getAttribute('aria-label')).toBe(STRINGS.accountHidePassword);
    expect(toggles()[1].getAttribute('aria-pressed')).toBe('true');
    expect(toggles()[0].getAttribute('aria-label')).toBe(STRINGS.accountShowPassword);
  });

  it('matrix "Empty field": an empty field is refused here, and no request is sent', async () => {
    await submitWith('', '');
    expect(requests).toEqual([]);
    expect(fields()[0].getAttribute('aria-invalid')).toBe('true');
    expect(fields()[1].getAttribute('aria-invalid')).toBe('true');
    expect(errors().map((node) => node.textContent?.trim())).toEqual([
      STRINGS.openApiRequired,
      STRINGS.openApiRequired,
    ]);
    expect(summary()).not.toBeNull();
  });

  it('AC2: a correct change sends the two members, clears both fields, and closes announcing itself', async () => {
    await submitWith(CURRENT, NEXT);
    expect(requests).toHaveLength(1);
    expect(requests[0].path).toBe('/api/ocupilot/account/password');
    expect(requests[0].method).toBe('POST');
    expect(JSON.parse(String(requests[0].body))).toEqual({
      currentPassword: CURRENT,
      newPassword: NEXT,
    });
    expect(changes).toBe(1);
    expect(closes).toBe(1);
    // Write-only: neither value survives the answer, on the controls or anywhere this renders.
    expect(fields().map((field) => field.value)).toEqual(['', '']);
    expect(fixture.nativeElement.textContent).not.toContain(CURRENT);
    expect(fixture.nativeElement.textContent).not.toContain(NEXT);
  });

  it('AC5: a wrong current password keeps the dialog open with the refusal on that field', async () => {
    answer = refusal(
      'currentPassword',
      'ACCOUNT.PASSWORD.CURRENT',
      'That is not the current password for this account. Enter it again.'
    );
    await submitWith(CURRENT, NEXT);

    expect(closes).toBe(0);
    expect(changes).toBe(0);
    expect(fields()[0].getAttribute('aria-invalid')).toBe('true');
    expect(fields()[1].getAttribute('aria-invalid')).toBe('false');
    const described = fields()[0].getAttribute('aria-describedby');
    expect(described).toBe(`${fields()[0].id}-reason`);
    expect((fixture.nativeElement.querySelector(`#${described}`) as HTMLElement).textContent?.trim()).toBe(
      'That is not the current password for this account. Enter it again.'
    );
  });

  it('AC4: a policy refusal renders the instance\'s own reason on newPassword, in a focused alert summary', async () => {
    const instanceText = 'Password does not match length or pattern requirements';
    answer = refusal('newPassword', 'ACCOUNT.PASSWORD.POLICY', instanceText);
    await submitWith(CURRENT, NEXT);

    expect(closes).toBe(0);
    const banner = summary();
    expect(banner).not.toBeNull();
    expect(banner?.getAttribute('role')).toBe('alert');
    expect(banner?.getAttribute('tabindex')).toBe('-1');
    expect(banner?.textContent).toContain(instanceText);
    expect(fields()[1].getAttribute('aria-invalid')).toBe('true');
    const described = fields()[1].getAttribute('aria-describedby');
    expect(described).toBe(`${fields()[1].id}-reason`);
    expect((fixture.nativeElement.querySelector(`#${described}`) as HTMLElement).textContent?.trim()).toBe(
      instanceText
    );
    // The client publishes no sentence for a policy the instance owns.
    expect(banner?.textContent).not.toContain('policy is');
  });

  it('a summary entry moves focus to the field it names', async () => {
    answer = refusal('newPassword', 'ACCOUNT.PASSWORD.POLICY', 'too short');
    await submitWith(CURRENT, NEXT);
    (summary()?.querySelector('button') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(document.activeElement).toBe(fields()[1]);
  });

  it('matrix "Malformed body" and "Any other failure": a refusal with no field keeps the dialog open and says so once', async () => {
    answer = { kind: 'error', status: 422, code: 'ACCOUNT.PASSWORD.BODY', reason: null, detail: null };
    await submitWith(CURRENT, NEXT);

    expect(closes).toBe(0);
    expect(changes).toBe(0);
    expect(summary()).toBeNull();
    const banners = [...fixture.nativeElement.querySelectorAll('.ocu-banner-warning')];
    expect(banners).toHaveLength(1);
    expect((banners[0] as HTMLElement).getAttribute('role')).toBe('alert');
    expect((banners[0] as HTMLElement).textContent?.trim()).toBe(STRINGS.connectivityServerFault);
  });

  it("an unreachable instance says so, rather than sending the reader to messages.log", async () => {
    // `panel.ts` and `fault-banner.ts` both pick between these two sentences off `classifyFault`,
    // so that the shell and an inline banner cannot disagree about which failure it was.
    answer = { kind: 'error', status: 0, code: null, reason: null, detail: null };
    await submitWith(CURRENT, NEXT);

    expect(closes).toBe(0);
    const banner = fixture.nativeElement.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner.textContent?.trim()).toBe(STRINGS.connectivityBannerUnreachable);
  });

  it("a refusal that named no field renders the server's own sentence, not a client one", async () => {
    // The server publishes every refusal sentence once (AD-39); the body refusal's is one of them,
    // and it reached the wire authored and asserted but unrendered until this case.
    const sentence = 'The body must carry exactly two members, the strings currentPassword and newPassword.';
    answer = { kind: 'error', status: 422, code: 'ACCOUNT.PASSWORD.BODY', reason: sentence, detail: null };
    await submitWith(CURRENT, NEXT);

    const banner = fixture.nativeElement.querySelector('.ocu-banner-warning') as HTMLElement;
    expect(banner.textContent?.trim()).toBe(sentence);
  });

  it('a refusal moves focus to the field it names, as the house form does', async () => {
    answer = refusal('newPassword', 'ACCOUNT.PASSWORD.POLICY', 'too short');
    await submitWith(CURRENT, NEXT);
    await fixture.whenStable();
    expect(document.activeElement).toBe(fields()[1]);
  });

  it('a second press while the first request is in flight sends one request, not two', async () => {
    // Two presses in one tick: `submit()` raises `busy` before it awaits, so the second returns
    // early. The action carries `aria-disabled` and nothing else, so this guard is the only thing
    // between a double-click and two password changes.
    fields()[0].value = CURRENT;
    fields()[1].value = NEXT;
    action().click();
    action().click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(requests).toHaveLength(1);
    expect(changes).toBe(1);
  });

  it('dismissing the dialog while the change is still in flight applies nothing and does not re-emit', async () => {
    // The request is still awaited when Cancel fires: nothing here is a guess about timing --
    // `pending` only resolves when this test releases it, after the dismissal has already run.
    let release = (): void => {};
    pending = new Promise((resolve) => {
      release = resolve;
    });
    fields()[0].value = CURRENT;
    fields()[1].value = NEXT;
    action().click();
    cancel().click();
    fixture.detectChanges();
    expect(closes).toBe(1);
    expect(changes).toBe(0);

    // The instance's answer -- an applied change -- arrives after the user already dismissed the
    // dialog. Without the `finished` re-check, this `ok` outcome re-emits `changed` (an
    // announcement for a dialog no longer open) and touches the two field elements again.
    // `pending` resolving only starts that chain -- `requestJson`, then `changePassword`, then
    // `submit()`'s own continuation each add a further microtask hop, so a real macrotask boundary
    // (not another microtask-only wait) is what guarantees every hop has run before the assertion.
    release();
    await new Promise<void>((resolve) => setTimeout(resolve, 0));
    await fixture.whenStable();
    fixture.detectChanges();
    expect(closes).toBe(1);
    expect(changes).toBe(0);
  });

  it('DW-1291: Enter in either field submits, as the house credential form does', async () => {
    // A refusal, so the dialog is still open for the second press; a 200 would close it after the
    // first and the second iteration would prove nothing.
    answer = refusal('currentPassword', 'ACCOUNT.PASSWORD.CURRENT', 'not the current one');
    for (const index of [0, 1]) {
      requests = [];
      fields()[0].value = CURRENT;
      fields()[1].value = NEXT;
      fields()[index].dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true })
      );
      await fixture.whenStable();
      fixture.detectChanges();
      expect(requests).toHaveLength(1);
      expect(JSON.parse(String(requests[0].body))).toEqual({
        currentPassword: CURRENT,
        newPassword: NEXT,
      });
    }
    expect(closes).toBe(0);
  });

  it('AC8: Cancel closes it with nothing sent and no value retained', () => {
    fields()[0].value = CURRENT;
    fields()[1].value = NEXT;
    cancel().click();
    fixture.detectChanges();

    expect(requests).toEqual([]);
    expect(closes).toBe(1);
    expect(changes).toBe(0);
  });

  it('AC6: no password value is rendered anywhere, on any path', async () => {
    answer = refusal('newPassword', 'ACCOUNT.PASSWORD.POLICY', 'too short');
    await submitWith(CURRENT, NEXT);
    // First that the two values are where this case thinks they are: without it every assertion
    // below passes against a dialog that was never given either password.
    expect(fields().map((field) => field.value)).toEqual([CURRENT, NEXT]);
    // `textContent` covers the summary, the field reasons and the labels.
    expect(fixture.nativeElement.textContent).not.toContain(CURRENT);
    expect(fixture.nativeElement.textContent).not.toContain(NEXT);
    // A value held on an input's `value` *property* is not reflected into the `value` attribute, so
    // `outerHTML` alone cannot fail. The attribute is where an echo would land, and it is asserted
    // directly rather than left implied.
    expect(fields().map((field) => field.getAttribute('value'))).toEqual([null, null]);
    expect(fixture.nativeElement.outerHTML).not.toContain(CURRENT);
    expect(fixture.nativeElement.outerHTML).not.toContain(NEXT);
  });
});
