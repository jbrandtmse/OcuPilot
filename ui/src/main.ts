import { provideZonelessChangeDetection } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';

import { App } from './app/app';

// Zoneless, standalone bootstrap (AD-19). No chrome, no tokens, no API service — this
// story only needs `ng build` to succeed; Stories 1.2 and 1.10 own everything above it.
bootstrapApplication(App, {
  providers: [provideZonelessChangeDetection()],
}).catch((err) => console.error(err));
