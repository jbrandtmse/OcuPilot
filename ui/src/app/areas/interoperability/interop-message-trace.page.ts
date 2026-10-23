import { ChangeDetectionStrategy, Component } from '@angular/core';

import { DetailPage } from '../../shell/detail-page';
import { InteropMessageTrace } from './interop-message-trace';

/**
 * Interoperability's message Trace tab (Story 20.30, AD-5): the detail page, the message's tab strip over the shared list page,
 * with `InteropMessageTrace` drawing the rows as a sequence diagram in place of the table. Binding, refresh and the id-change
 * re-read are the list page's; this page names the body and nothing else.
 */
@Component({
  selector: 'app-interop-message-trace-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage],
  // The height chain every page host carries, so the diagram keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page [body]="trace" />`,
})
export class InteropMessageTracePage {
  protected readonly trace = InteropMessageTrace;
}
