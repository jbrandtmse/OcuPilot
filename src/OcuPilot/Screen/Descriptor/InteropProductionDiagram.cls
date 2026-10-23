/// <p>The Configuration diagram screen: InterSystems' production configuration app, loaded from the instance in a frame and
/// signed in through the browser-level login (AD-63, Story 20.8). It is reached from a link on the production's Production
/// items screen and never listed (<code>sideBarPosition</code> 0), at <code>interoperability/productions/diagram/&lt;production&gt;</code>:
/// a <code>viewer (source)</code> screen that declares <code>parentScope</code> <code>interoperability/productions</code> and
/// the production class name, kept exactly, as its one id segment (AD-5, AD-13).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its page issues the Productions list's
/// declared read and draws the frame only for a row whose <code>Name</code> equals the route id (AD-5, a page may issue another
/// built screen's read). It is a <code>viewer (source)</code> and not a <code>detail</code>, because the client resolves a
/// list's detail screen before its child list and a detail would take the Productions name cell from Production items. The
/// app opens its sibling editors in new browser tabs, or as panels inside the frame, and OcuPilot leaves them as the vendor
/// built them; the page reaches nothing in the frame and declares no context field.</p>
/// <p><b>Its pairs</b> are the Productions list's: <code>%Ens_Portal:USE</code> and, as its own,
/// <code>%Ens_ProductionConfig:READ</code> (AD-8, AD-64). The classic page is <code>EnsPortal.ProductionConfig</code> (AD-44).
/// It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropProductionDiagram Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/diagram",
  "area": "interoperability",
  "labelKey": "interopProductionDiagramTitle",
  "sideBarPosition": 0,
  "archetype": "viewer (source)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "production",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "interopProductionDiagramEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopProductionDiagramPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopProductionDiagramPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopProductionDiagramPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "interop.productiondiagram"
}
}

}
