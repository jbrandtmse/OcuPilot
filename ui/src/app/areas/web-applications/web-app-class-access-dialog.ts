import { ChangeDetectionStrategy, Component, inject, input, output, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The two access types the instance accepts, in the order the select offers them (`PctAccessPort.ALLOWTYPES`). */
export const ALLOW_TYPES: readonly string[] = ['AllowClass', 'AllowPrefix'];

/** The path the create posts to (Story 18.10, `OcuPilot.Area.WebApp.PctAccessSave`). */
export const PCT_ACCESS_SAVE_PATH = '/api/ocupilot/web-app/pct-access';

/** The application name the "Apply to all applications" choice sends (`PctAccessPort`). */
export const ALL_APPLICATIONS = 'all-applications';

/** How many class-access dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Add a percent-class access entry to a web application (Story 18.10): the allow type, the class or
 * package name and whether it allows access, with "Apply to all applications" choosing the
 * instance-wide entry. Add posts to `POST /web-app/pct-access`; a refusal is the envelope's own
 * sentence, shown on the dialog with the fields kept for another try, and a success closes it.
 */
@Component({
  selector: 'app-web-app-class-access-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.webAppPctAccessDialogTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closed.emit()">
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="typeId">{{ STRINGS.webAppPctAccessColumnAllowType }}</label>
        <select class="ocu-field-input" [id]="typeId" (change)="allowType.set($any($event.target).value)">
          @for (option of allowTypes; track option) {
            <option [value]="option" [selected]="option === allowType()">{{ option }}</option>
          }
        </select>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="classId">{{ STRINGS.webAppPctAccessClassField }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          maxlength="256"
          [id]="classId"
          [value]="className()"
          (input)="className.set($any($event.target).value)"
        />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label"><input type="checkbox" [checked]="allowAccess()" (change)="allowAccess.set($any($event.target).checked)" /> {{ STRINGS.webAppPctAccessColumnAllowAccess }}</label>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label"><input type="checkbox" [checked]="allApplications()" (change)="allApplications.set($any($event.target).checked)" /> {{ STRINGS.webAppPctAccessAllApplications }}</label>
      </div>
    </div>
    @if (hasRefusal) {
      <p class="ocu-broadcast-refusal" role="alert">{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" [attr.aria-disabled]="busy() ? 'true' : null" (click)="submit()">
      {{ STRINGS.webAppPctAccessAdd }}
    </button>
  </app-dialog>`,
})
export class WebAppClassAccessDialog {
  private readonly api = inject(ApiService);

  /** The web application the entry is added to, as the editor names it. */
  readonly application = input.required<string>();

  /** Raised once the instance has applied the entry. */
  readonly added = output<void>();

  /** Raised when the dialog is dismissed. */
  readonly closed = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly allowTypes = ALLOW_TYPES;

  private readonly instance = ++dialogCount;

  protected readonly typeId = `ocu-pct-type-${this.instance}`;

  protected readonly classId = `ocu-pct-class-${this.instance}`;

  protected readonly allowType = signal(ALLOW_TYPES[0]);

  protected readonly className = signal('');

  protected readonly allowAccess = signal(true);

  protected readonly allApplications = signal(false);

  protected readonly busy = signal(false);

  protected readonly refusal = signal('');

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  /** Posts the entry. Nothing is sent while a send is in flight, so one Add is one request. */
  protected async submit(): Promise<void> {
    if (this.busy()) return;
    this.busy.set(true);
    this.refusal.set('');
    const name = this.allApplications() ? ALL_APPLICATIONS : this.application();
    const result = await this.api.requestJson<unknown>(PCT_ACCESS_SAVE_PATH, {
      method: 'POST',
      body: JSON.stringify({
        Name: name,
        AllowType: this.allowType(),
        Class: this.className().trim(),
        AllowAccess: this.allowAccess(),
      }),
    });
    this.busy.set(false);
    if (result.kind === 'ok') {
      this.added.emit();
      return;
    }
    this.refusal.set(result.kind === 'error' && typeof result.reason === 'string' ? result.reason : STRINGS.connectivityServerFault);
  }
}
