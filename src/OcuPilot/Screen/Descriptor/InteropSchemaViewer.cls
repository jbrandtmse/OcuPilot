/// <p>The Schema viewer screen: InterSystems' HL7 v2.x, ASC X12 and ASTM schema viewer, loaded from the instance in a frame
/// and signed in through the browser-level login (AD-63, Story 20.8). It is listed in the Interoperability area
/// (<code>sideBarPosition</code> 10), a <code>viewer (source)</code> screen with no id segment (AD-5).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36), and its page issues no request: the screen
/// gate decides whether it mounts, and the page draws the frame at once. The viewer opens on ASC X12 and the person chooses
/// the schema type in the viewer's own list, because the viewer overwrites its <code>&amp;ST</code> parameter before it reads
/// it, so a schema type cannot be chosen from the address (measured). The screen therefore sends no document parameter. The
/// page reaches nothing in the frame and declares no context field.</p>
/// <p><b>Its pairs</b> are the Interoperability menu's and, as its own, <code>%Ens_EDISchema:READ</code> (AD-8, AD-64),
/// which the vendor's schema reads check.</p>
/// <p><b>It replaces three classic pages</b> (AD-44): <code>EnsPortal.HL7.SchemaMain</code> as its
/// <code>classicPage</code>, and <code>EnsPortal.EDI.X12.SchemaMain</code> and <code>EnsPortal.EDI.ASTM.SchemaMain</code> in
/// <parameter>CLASSICPAGES</parameter>, because the one viewer shows all three families. A custom resource assigned to any of
/// the three gates the screen. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropSchemaViewer Extends OcuPilot.Screen.Descriptor.Base
{

Parameter CLASSICPAGES = "EnsPortal.EDI.X12.SchemaMain,EnsPortal.EDI.ASTM.SchemaMain";

XData Declaration
{
{
  "route": "interoperability/schema-viewer",
  "area": "interoperability",
  "labelKey": "interopSchemaViewerTitle",
  "sideBarPosition": 10,
  "archetype": "viewer (source)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_EDISchema", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_EDISchema", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["schema viewer", "hl7 schemas", "x12 schemas", "astm schemas"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopSchemaViewerPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopSchemaViewerPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopSchemaViewerPrompt3"}
  ],
  "classicPage": "EnsPortal.HL7.SchemaMain",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "interop.schemaviewer"
}
}

}
