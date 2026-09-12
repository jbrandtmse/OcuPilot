import { provideZonelessChangeDetection } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import { App } from './app/app';
import { routes } from './app/app.routes';

// Zoneless, standalone bootstrap (AD-19). The router is what makes the static
// handler's deep-link fallback useful: the server answers `index.html` for
// `/ocupilot/<area>/<screen>/<id>`, and this is what then resolves that URL to a
// selection with the address unchanged. No chrome, no tokens, no API service --
// Stories 1.9 and 1.10 own everything above it.
bootstrapApplication(App, {
  providers: [provideZonelessChangeDetection(), provideRouter(routes)],
}).catch((err) => console.error(err));
