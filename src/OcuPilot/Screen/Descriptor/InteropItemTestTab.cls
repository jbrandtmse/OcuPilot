/// <p>Interoperability's Test tab of a production item (Story 20.6): the request classes the item takes and the fields of each that
/// a test can set, read through <class>OcuPilot.Port.InteropPort</class> (the host class's own message list, and the class dictionary
/// for the subclasses and fields) and rendered by the shared page
/// under the item's tab strip, with the Test action that sends one request built from them (AD-5, AD-29, AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production
/// items: its one criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. A business service takes no test request, so its
/// tab lists none. A field whose name the credential pattern matches is listed with <code>Secret</code> true and no test sends a
/// value for it (AD-35). It does not refresh (AD-43).</p>
/// <p><b>Its pairs</b> are the classic Testing Service page's (AD-8, AD-44): the Interoperability menu's <code>%Ens_Portal:USE</code>
/// and <code>%Ens_TestingService:USE</code>. Its one action, Test, is the screen's caller of
/// <class>OcuPilot.Screen.Tool.InteropItemTestSend</class> (AD-53), posted to this screen with the item as its target. It is declared
/// as the primary action and as the one row action the route admits, so the command bar draws it once, with no row selected; the
/// page's own dialog builds the request from the rows and sends it.</p>
Class OcuPilot.Screen.Descriptor.InteropItemTestTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/test",
  "area": "interoperability",
  "labelKey": "interopItemTestLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_TestingService", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_TestingService", "permission": "USE"}],
  "entityType": "production-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "composite", "parts": ["RequestClass", "Field"]},
  "primaryAction": {"id": "test", "selfProtection": ""},
  "rowActions": [{"id": "test", "selfProtection": ""}],
  "context": {"fields": ["RequestClass", "Kind", "Field", "Type", "Required", "Secret"], "secretFields": []},
  "emptyStateKey": "interopItemTestEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemTestPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemTestPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemTestPrompt3"}
  ],
  "classicPage": "EnsPortal.TestingService",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "ItemTest", "type": "LIST"},
    "fields": ["Production", "Item", "RequestClass", "Kind", "Field", "Type", "Required", "MaxLength", "Values", "Secret"],
    "filter": ["RequestClass", "Field", "Type"],
    "sort": {"fields": ["RequestClass", "Field"], "default": "RequestClass", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "RequestClass", "labelKey": "interopTestColumnRequestClass", "kind": "identifier"},
      {"field": "Field", "labelKey": "explorerSqlColumnField", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Required", "labelKey": "openApiRequired", "kind": "status"},
      {"field": "MaxLength", "labelKey": "explorerSqlColumnMaxLength", "kind": "number"},
      {"field": "Values", "labelKey": "interopTestColumnValues", "kind": "text"},
      {"field": "Secret", "labelKey": "interopTestColumnSecret", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopItemTestEmptyAgent"
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 7, "labelKey": "serverFlagTest"},
  "toolIdentifier": "interop.itemtest"
}
}

}
