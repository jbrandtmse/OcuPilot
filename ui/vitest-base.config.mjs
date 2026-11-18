// Settings for the component suite's vitest runner, loaded through `runnerConfig` in angular.json.
//
// Every test file runs in its own isolated module graph: a worker that carries the graph of every
// earlier file grows without bound, which a 2-CPU CI runner (one worker, all files) cannot absorb.
// `maxWorkers` keeps a small runner from oversubscribing its CPUs; `execArgv` caps each worker's
// heap so a worker that outgrows it fails the run, naming itself, instead of stalling it.
//
// Plain object, no imports: the Angular builder merges this file's `test` block into its own
// project configuration, and `ui/tools/angular-json.test.mjs` imports the file to pin the values.

/**
 * Names each test file as its worker begins it, so the file in flight at a hang or a crash is in
 * the log. A worker reports a file as queued before it imports it and as started only after the
 * import, so a worker that dies during the import is named by the first and not the second; a
 * file is printed once.
 */
const printed = new Set();
function printStart(testModule) {
  const file = testModule.relativeModuleId ?? testModule.moduleId;
  if (printed.has(file)) return;
  printed.add(file);
  console.log(`vitest start ${file}`);
}
const startReporter = {
  onTestModuleQueued: printStart,
  onTestModuleStart: printStart,
};

export default {
  test: {
    isolate: true,
    maxWorkers: 2,
    execArgv: ['--max-old-space-size=1536'],
    reporters: ['default', startReporter],
  },
};
