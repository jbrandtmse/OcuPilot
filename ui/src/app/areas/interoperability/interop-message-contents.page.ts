import { ChangeDetectionStrategy, Component } from '@angular/core';

import { DetailPage } from '../../shell/detail-page';
import { InteropMessageContents } from './interop-message-contents';

/**
 * Interoperability's message Contents tab (Story 20.9, AD-5): the detail page, the message's tab strip over the shared list page,
 * with `InteropMessageContents` drawing the rows as one block of text in place of the table. Binding, refresh and the id-change
 * re-read are the list page's; this page names the body and nothing else.
 */
@Component({
  selector: 'app-interop-message-contents-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage],
  // The height chain every page host carries, so the block keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page [body]="contents" />`,
})
export class InteropMessageContentsPage {
  protected readonly contents = InteropMessageContents;
}
