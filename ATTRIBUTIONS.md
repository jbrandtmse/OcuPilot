# Attributions

Third-party material redistributed inside OcuPilot, and where each license travels.

## Fonts

Both families are vendored — OcuPilot reaches no CDN for a font or for anything else (NFR-10,
AD-47) — so each is redistributed and each carries its license with it.

| Family | Faces shipped | Copyright | License |
| --- | --- | --- | --- |
| Inter | Regular, Medium, SemiBold | Copyright 2020 The Inter Project Authors (<https://github.com/rsms/inter>) | SIL Open Font License 1.1 |
| JetBrains Mono | Regular, SemiBold | Copyright 2020 The JetBrains Mono Project Authors (<https://github.com/JetBrains/JetBrainsMono>) | SIL Open Font License 1.1 |

The full license texts are `ui/src/assets/fonts/Inter-OFL.txt` and
`ui/src/assets/fonts/JetBrainsMono-OFL.txt`. They are copied into the built bundle beside the
`woff2` faces themselves — `angular.json`'s `assets` entry puts them in
`dist/ocupilot-ui/browser/media/`, the same directory the hashed faces land in — so a copy of
the Font Software never travels without its notice, which is what SIL OFL 1.1 section 2
requires. The IPM module copies that whole directory
(`module.xml`'s `<FileCopy Name="ui/dist/ocupilot-ui/browser/">`), so the packaged distribution
carries them too.

Neither family is modified, and neither is sold on its own. Renaming would be required only if a
face were modified, which OcuPilot does not do.

## npm dependencies

Licenses for the JavaScript and TypeScript dependencies are extracted by the build into
`dist/ocupilot-ui/3rdpartylicenses.txt`. That file sits one directory above the served root and
covers the npm tree only — it names neither font, which is why the fonts are handled above.

**It is generated and it is not distributed, and that is an open gap, not a decision.**
`module.xml`'s `<FileCopy Name="ui/dist/ocupilot-ui/browser/">` copies the served root, so
neither the installed bundle nor the IPM package carries the file; the shipped `main-*.js` is
minified third-party code whose licenses mostly require their notice to accompany a
redistribution. The fonts half of this document is closed; this half is recorded as
**DW-217** in `_bmad-output/implementation-artifacts/deferred-work.md` and is the owner's
call at the Epic 1 decision sheet — the fix is either an `assets` entry that lands the file
inside `browser/` or a second `<FileCopy>`, and either changes what ships.

## InterSystems material

`irislib/`, `irissys/`, `irisui/` and `irisdocs/` are read-only reference exports taken from the
IRIS container and the official documentation. They are gitignored, are never loaded or
modified, and are not redistributed — see
[.claude/rules/reference-folders.md](.claude/rules/reference-folders.md).

Handler bodies harvested from the four sibling projects keep their call sites but never their
names; the harvest plans are under
`_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/`.
