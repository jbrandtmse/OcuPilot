import { ChangeDetectionStrategy, Component } from '@angular/core';

import { DetailPage } from '../../shell/detail-page';
import { EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE } from '../../shell/screen-action-handler';
import { registerRouteTargetActions } from './route-target-actions';

/**
 * A SQL schema's Tables tab (Story 21.25, AD-5): the shared detail page, with Tune all tables registered on it on the schema the route names
 * (`registerRouteTargetActions`). The handler's warning asks whether to clear values.
 */
@Component({
  selector: 'app-sql-schema-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage],
  // The height chain every page host carries, so the tab's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />`,
})
export class SqlSchemaPage {
  constructor() {
    registerRouteTargetActions(EXPLORER_SQL_SCHEMA, 'schema', [SQL_SCHEMA_TUNE]);
  }
}
