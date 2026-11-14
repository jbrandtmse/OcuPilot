# Exclusion register

OcuPilot does not build some of the portal features its catalog lists. The catalog marks them tier P4,
"long tail, excluded by default", and gives a one-phrase reason in each row. This register records,
row by row, why a feature was left out, what would have to become true before it could be built, and
how to tell that it has. A request to build one is then answered against evidence rather than against
a blank.

It is read by the builder, and by whoever picks a row up. Nothing here schedules work: a row is picked
up only when someone asks for it by name and its gate has cleared.

The register follows two planning documents and a test holds it equal to both:

- the feature catalog, `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md`,
  whose P4 rows are exactly the rows below;
- the stage extract, `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md`,
  whose "Stage 5" holds the groups. The product requirements and the epics call the same stage
  Stage 6, and the epics give the groups the wording used for the headings below.

`ui/tools/exclusion-register.test.mjs` fails when a P4 row is missing from the register, when a row
here is no longer P4, when a row sits under a different group than the extract puts it in, or when a
row is incomplete. Promoting a row in the catalog therefore means removing it here and from the
extract's Stage 5 in the same change.

Checks marked with a date were read on the development instance named slot B (IRIS for Health
Community 2026.2, build 221U, which has the `HSSYS` namespace), read only, in the `HSCUSTOM`
namespace, on 2026-11-14. A statement marked `(inference)` was
not confirmed against the instance or the source.

## Gate kinds

| Kind | What clears it |
| --- | --- |
| `license` | A license the instance holds. A runnable check says whether it does. |
| `edition` | The product edition or add-on the vendor tests for. A runnable check says whether it is present. |
| `platform` | The operating system the vendor tests for. A runnable check says which one the instance runs on. |
| `deprecation` | An owner decision to support a feature the vendor has deprecated. |
| `dependency` | Something outside OcuPilot that does not exist yet. |
| `vendor-page` | The vendor's page or class is live on a menu of a supported release. |
| `not-applicable` | Only an amendment to the architecture makes the row apply. |
| `demand` | Nothing beyond a recorded request that names the row. |

## The register

### License-gated sharding

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| SA-50 | Enable sharding | Needs a sharding license, which Community Edition lacks. | `license` | The instance holds a sharding license. This row is backed by the admin-v2 API, so it needs no new API once the license is there; the architecture reaches that API only through its single port (AD-27). | `$$Sharding^%SYS.LICENSE` returns 1. The vendor's portal menu evaluates it and disables the Sharding entry without it (`%CSP.UI.Portal.Application`, lines 146 to 148). Slot B read 0 on 2026-11-14. |
| SA-51 | Configure node-level sharding | Needs a sharding license. | `license` | The instance holds a sharding license. | `$$Sharding^%SYS.LICENSE` returns 1. The vendor's portal menu evaluates it and disables the Sharding entry without it (`%CSP.UI.Portal.Application`, lines 146 to 148). Slot B read 0 on 2026-11-14. |
| SA-52 | Configure namespace-level sharding | Needs a sharding license. | `license` | The instance holds a sharding license. | `$$Sharding^%SYS.LICENSE` returns 1. The vendor's portal menu evaluates it and disables the Sharding entry without it (`%CSP.UI.Portal.Application`, lines 146 to 148). Slot B read 0 on 2026-11-14. |

### Edition-gated HealthShare, Message Bank, Enterprise and ITK pages

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| SS-40 | HealthShare security module embed | Exists only on HealthShare, and is on no portal menu. | `edition` | The `HSSYS` namespace exists, which is when the vendor creates the `/ui/security-config` application. Even where it exists the page is on no menu, so a request is still needed. | `##class(%SYS.Namespace).Exists("HSSYS")` returns 1. The vendor's installer evaluates it (`HS.HC.Security.Installer`, line 13). Slot B read 1 and the application enabled on 2026-11-14, so it is cleared on IRIS for Health. A plain IRIS instance was not observed (inference: it has no `HSSYS`). |
| IO-71 | Agents page | Belongs to the Hub and IMT extension only. | `edition` | The Hub extension is installed. | `$Data(^EnsLib.Hub)` is non-zero. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, line 226). Slot B read 0 on 2026-11-14. That the Hub menu links to the Agents page was not confirmed (inference). |
| IO-74 | Generate DTL | Exists only on HealthShare. | `edition` | The HealthShare class that serves the page is present. | `##class(%Dictionary.ClassDefinition).%ExistsId("HS.InteropTools.HL7.GenerateDTL.UI.List")` returns 1. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, line 90). Slot B read 1 on 2026-11-14, so it is cleared on IRIS for Health. |
| IO-75 | Enterprise systems list | Part of the Enterprise systems feature. | `demand` | The vendor checks nothing: the menu lists the page on every instance (`EnsPortal.Application`, line 79). Only a recorded request is needed. | A request names IO-75. No instance check applies. |
| IO-76 | Message Bank link | Message Bank only. | `edition` | A Message Bank server exists for this instance to link to. The vendor menu offers the Message Bank entries only where the instance is not itself a bank (`$Data(^Ens.MsgBankSvr)` is 0, `EnsPortal.Application`, lines 66, 82 and 113). | `##class(EnsPortal.FindMsgBank).GetBankLink()` returns a URL, which it does once a bank's web server, port and namespace are stored. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 114 to 124). Slot B read an empty link, and `$Data(^Ens.MsgBankSvr)` 0, on 2026-11-14, so no bank is linked there. |
| IO-77 | Enterprise Message Bank | Message Bank only. | `edition` | A Message Bank server exists for this instance to link to. The vendor menu offers the Message Bank entries only where the instance is not itself a bank (`$Data(^Ens.MsgBankSvr)` is 0, `EnsPortal.Application`, lines 66, 82 and 113). | `##class(EnsPortal.FindMsgBank).GetBankLink()` returns a URL, which it does once a bank's web server, port and namespace are stored. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 114 to 124). Slot B read an empty link, and `$Data(^Ens.MsgBankSvr)` 0, on 2026-11-14, so no bank is linked there. |
| IO-78 | Banked messages | Message Bank only. | `edition` | The instance is itself a Message Bank. | `$Data(^Ens.MsgBankSvr)` is non-zero. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 66 and 100 to 102). Slot B read 0 on 2026-11-14. |
| IO-79 | Banked events | Message Bank only; goes with IO-78. | `edition` | The instance is itself a Message Bank, as for IO-78. | `$Data(^Ens.MsgBankSvr)` is non-zero. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 66 and 100 to 102). Slot B read 0 on 2026-11-14. |
| IO-80 | Enterprise messages | Part of the Enterprise systems feature. | `edition` | The instance monitors enterprise clients. | `$Data(^Ens.Enterprise.MonitorClientD)\10` is true. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 67, 104 and 144). Slot B read 0 on 2026-11-14. |
| IO-81 | Enterprise monitor | Part of the Enterprise systems feature; goes with IO-80. | `edition` | The instance monitors enterprise clients, as for IO-80. | `$Data(^Ens.Enterprise.MonitorClientD)\10` is true. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, lines 67, 104 and 144). Slot B read 0 on 2026-11-14. |
| IO-90 | ITK setup pages | The ITK package is absent from the instance. | `edition` | The ITK setup package is installed. | `##class(%Dictionary.PackageDefinition).%ExistsId("ITK.Setup")` returns 1. The vendor's interoperability menu evaluates it (`EnsPortal.Application`, line 217). Slot B read 0 on 2026-11-14. |

### Deprecated shadowing and text analytics

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| LG-13 | Shadow data-source error log | Shadowing is deprecated. | `deprecation` | The deprecated feature is shadowing. An owner decision to support shadowing despite its deprecation clears it. | The owner decision to support shadowing is recorded. |
| SA-59 | Shadow server settings | Shadowing is deprecated. | `deprecation` | The deprecated feature is shadowing. An owner decision to support shadowing despite its deprecation clears it. | The owner decision to support shadowing is recorded. |
| SO-18 | System as shadow server | Shadowing is deprecated. | `deprecation` | The deprecated feature is shadowing. An owner decision to support shadowing despite its deprecation clears it. | The owner decision to support shadowing is recorded. |
| SO-19 | System as data source | Shadowing is deprecated. | `deprecation` | The deprecated feature is shadowing. An owner decision to support shadowing despite its deprecation clears it. | The owner decision to support shadowing is recorded. |
| AN-18 | Text Analytics: Domain Architect | iKnow Text Analytics is deprecated. | `deprecation` | The deprecated feature is iKnow Text Analytics. An owner decision to support it despite its deprecation clears it. | The owner decision to support iKnow Text Analytics is recorded. |
| AN-19 | Text Analytics: Domain Explorer | iKnow Text Analytics is deprecated. | `deprecation` | The deprecated feature is iKnow Text Analytics. An owner decision to support it despite its deprecation clears it. | The owner decision to support iKnow Text Analytics is recorded. |
| AN-20 | Text Analytics: Indexing Results | iKnow Text Analytics is deprecated. | `deprecation` | The deprecated feature is iKnow Text Analytics. An owner decision to support it despite its deprecation clears it. | The owner decision to support iKnow Text Analytics is recorded. |
| AN-21 | Text Analytics: Model Builder | iKnow Text Analytics is deprecated. | `deprecation` | The deprecated feature is iKnow Text Analytics. An owner decision to support it despite its deprecation clears it. | The owner decision to support iKnow Text Analytics is recorded. |
| AN-22 | Text Analytics: Model Tester | iKnow Text Analytics is deprecated. | `deprecation` | The deprecated feature is iKnow Text Analytics. An owner decision to support it despite its deprecation clears it. | The owner decision to support iKnow Text Analytics is recorded. |

### Zen Reports, InterSystems Reports and cluster settings

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| SA-53 | Cluster settings | Cluster settings. | `demand` | A recorded request names SA-53. | A request names SA-53. No instance check applies. |
| SA-54 | InterSystems Reports server definitions | InterSystems Reports server definitions. | `demand` | A recorded request names SA-54. | A request names SA-54. No instance check applies. |
| SA-55 | Zen Reports render servers | Zen Reports. | `demand` | A recorded request names SA-55. | A request names SA-55. No instance check applies. |
| SA-56 | Zen Reports print servers | Zen Reports; goes with SA-55. | `demand` | A recorded request names SA-56. | A request names SA-56. No instance check applies. |
| SA-57 | Zen Reports Excel servers | Zen Reports; goes with SA-55. | `demand` | A recorded request names SA-57. | A request names SA-57. No instance check applies. |
| SA-58 | Zen Reports settings | Zen Reports; goes with SA-55. | `demand` | A recorded request names SA-58. | A request names SA-58. No instance check applies. |

### Low-usage device sub-pages and Windows-only pages

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| WA-17 | Client applications | The portal lists it only on Windows. | `platform` | The instance runs on Windows. | `$zversion(1)` returns 2, which is the vendor's `$$$ISWINDOWS` macro (`%sySite.inc`, line 17). The vendor's portal menu evaluates it (`%CSP.UI.Portal.Application`, line 291). Slot B read 3 on 2026-11-14, so it is not Windows. |
| OS-31 | IO settings | Low usage. | `demand` | A recorded request names OS-31. This row is backed by the admin-v2 API, so it needs no new API; the architecture reaches that API only through its single port (AD-27). | A request names OS-31. No instance check applies. |
| OS-32 | Device subtypes list and edit | Low usage. | `demand` | A recorded request names OS-32. This row is backed by the admin-v2 API, so it needs no new API; the architecture reaches that API only through its single port (AD-27). | A request names OS-32. No instance check applies. |
| OS-33 | Magnetic tape devices | Low usage. | `demand` | A recorded request names OS-33. | A request names OS-33. No instance check applies. |
| OS-34 | Telnet settings | Low usage, on the Windows branch of the device settings. | `platform` | The instance runs on Windows. The menu lists the page on every platform (`%CSP.UI.Portal.Application`, line 236), and the page disables its fields off Windows (`%CSP.UI.Portal.Config.Telnet`, lines 29 and 52). | `$zversion(1)` returns 2, which is the vendor's `$$$isWINDOWS` macro (`%occOptions.inc`, line 16). The vendor's Telnet page evaluates it (`%CSP.UI.Portal.Config.Telnet`, lines 29 and 52). Slot B read 3 on 2026-11-14, so it is not Windows. |

### Non-HL7 EDI schema authoring, DICOM, PubSub and adapter dialogs

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| IO-72 | Legacy rule log | Legacy, from before 2012, and on no menu. | `vendor-page` | The vendor's page is live on a menu of a supported release. | The legacy rule log appears on the interoperability menu of a supported release. |
| IO-73 | SAP JCo configuration dialog and SFTP append test dialog | Adapter-specific dialogs. | `demand` | A recorded request names IO-73. | A request names IO-73. No instance check applies. |
| IO-82 | Publish and Subscribe | PubSub. | `demand` | A recorded request names IO-82. | A request names IO-82. No instance check applies. |
| IO-83 | DICOM settings | DICOM. | `demand` | A recorded request names IO-83. | A request names IO-83. The vendor menu lists the page only where the DICOM package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("DICOM")`, `EnsPortal.Application`, line 183). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-84 | DICOM abstract syntax list | DICOM. | `demand` | A recorded request names IO-84. | A request names IO-84. The vendor menu lists the page only where the DICOM package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("DICOM")`, `EnsPortal.Application`, line 183). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-85 | DICOM dictionary | DICOM. | `demand` | A recorded request names IO-85. | A request names IO-85. The vendor menu lists the page only where the DICOM package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("DICOM")`, `EnsPortal.Application`, line 183). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-86 | ASC X12 schema import, export and delete | Authoring of non-HL7 EDI schemas. | `demand` | A recorded request names IO-86. | A request names IO-86. The vendor menu lists the page only where the X12 package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("X12")`, `EnsPortal.Application`, line 169). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-87 | ASTM schema import, export and delete | Authoring of non-HL7 EDI schemas. | `demand` | A recorded request names IO-87. | A request names IO-87. The vendor menu lists the page only where the ASTM package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("ASTM")`, `EnsPortal.Application`, line 176). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-88 | UN/EDIFACT schema structures | Authoring of non-HL7 EDI schemas. | `demand` | A recorded request names IO-88. | A request names IO-88. The vendor menu lists the page only where the SEF package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("SEF")`, `EnsPortal.Application`, line 198). Slot B read 1 on 2026-11-14, so the menu lists it there. |
| IO-89 | XML schema structures | Authoring of non-HL7 EDI schemas. | `demand` | A recorded request names IO-89. | A request names IO-89. The vendor menu lists the page only where the XML package is installed (`##class(%Library.InteroperabilityMgr).IsPackageInstalled("XML")`, `EnsPortal.Application`, line 204). Slot B read 1 on 2026-11-14, so the menu lists it there. |

### Full applications linked rather than rebuilt

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| AN-23 | Architect, Analyzer and User Portal rebuilt as OcuPilot screens | These are full applications, so OcuPilot links to them instead. The Architect, Analyzer and User Portal links ship (Story 20.32; the three link screens were compiled on slot B on 2026-11-14). Rebuilding them stays excluded. | `demand` | A recorded request that the links cannot answer. | A request names AN-23 and says what the links do not do. |
| EX-55 | FileMan mapping wizard | A legacy wizard specific to VA. | `demand` | A recorded request names EX-55. No OcuPilot link exists yet; the classic portal serves it. | A request names EX-55. No instance check applies. |
| EX-56 | WebStress tool | WebStress. | `demand` | A recorded request names EX-56. No OcuPilot link exists yet; the classic portal serves it. | A request names EX-56. No instance check applies. |
| EX-57 | UnitTest Portal | UnitTest Portal. | `demand` | A recorded request names EX-57. No OcuPilot link exists yet; the classic portal serves it. | A request names EX-57. No instance check applies. |

### Dead references, dead placeholders and cosmetic items

| ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
| --- | --- | --- | --- | --- | --- |
| SH-29 | Tips panel ("Did you know?") | Cosmetic, with no value to an operator. | `demand` | A recorded request names SH-29. | A request names SH-29. No instance check applies. |
| SA-60 | Provider pages | On no menu, and one page points at a class that does not exist. | `vendor-page` | The vendor's pages are live on a menu of a supported release. | The provider pages appear on the System Administration menu of a supported release. |
| SA-61 | FileMan conversion settings | Its menu entry is commented out. | `vendor-page` | The vendor's page is live on a menu of a supported release. | The FileMan conversion page appears on a menu of a supported release. |
| SA-62 | Dead references | The classes it names do not exist. | `vendor-page` | Each class the catalog row names exists on a supported release. | `##class(%Dictionary.CompiledClass).%ExistsId("<name>")` returns 1 for each class the catalog row names, on a supported release. |
| AN-24 | Worksheet builder, caption editor, Visual Reporting and other analytics pages | On no menu, and some of it is dead code. | `vendor-page` | The vendor's page is live on a menu of a supported release. | The page appears on the Analytics menu of a supported release. |
| DT-12 | Debugger session and terminal tools | A placeholder with no implementation behind it. | `dependency` | A debugger implementation exists. The harvested tool is a placeholder. | A debugger tool exists that does more than return a placeholder answer. |
| EX-58 | Data browser connection status and disconnect | OcuPilot runs in the instance it administers, so there is no connection to show (AD-1, AD-2). | `not-applicable` | Only an amendment to the architecture that lets OcuPilot administer a different instance makes the row apply. | An architecture decision lets OcuPilot connect to another instance. |
| PK-26 | IRIS AI Hub integration for the confirm step | Depends on an early-access product, which Community Edition does not include. | `dependency` | IRIS AI Hub is available outside early access on Community Edition. | The vendor lists IRIS AI Hub as generally available for Community Edition. |
