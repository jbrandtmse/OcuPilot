/// <p>Interoperability's HL7 schemas: the HL7 schemas the route's namespace holds, standard ones first, with what each is based on, its description, whether the instance provides it and the
/// time it was last changed, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Hl7Schemas</code>) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.18 Batch 1). It is the classic HL7 v2.x Schema Structures page's own list and actions; the vendor's
/// Schema viewer stays the browser of a schema's contents (AD-63).</p>
/// <p><b>Its id is the schema's name</b>, the row's <code>Category</code>, kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its primary action</b> New HL7 schema opens the dialog that adds a custom schema (<class>OcuPilot.Area.Interop.Hl7SchemaSave</class>, AD-54, AD-55). <b>Its page action</b> Import
/// reads one schema from a server file or a file on the person's computer, and <b>its row actions</b> Export (to a server file or to this browser) and Delete write through
/// <class>OcuPilot.Screen.Tool.InteropHl7SchemaImport</class>, <class>OcuPilot.Screen.Tool.InteropHl7SchemaExport</class> and <class>OcuPilot.Screen.Tool.InteropHl7SchemaDelete</class> (AD-53);
/// the import's and the delete's governance keys ship disabled (AD-22). A standard schema is never changed or deleted.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_EDISchema:READ</code>; a write adds <code>%Ens_EDISchema:WRITE</code> and WRITE on the
/// namespace's globals database, which the port checks before any vendor call (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropHl7SchemaList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/hl7-schemas",
  "area": "interoperability",
  "labelKey": "interopHl7SchemasLabel",
  "sideBarPosition": 30,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_EDISchema", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_EDISchema", "permission": "READ"}],
  "entityType": "interop-hl7-schema",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "export", "selfProtection": ""}, {"id": "export-browser", "selfProtection": ""}, {"id": "import", "selfProtection": ""}, {"id": "import-local", "selfProtection": ""}],
  "context": {"fields": ["Category", "Base", "Standard", "Modified"], "secretFields": []},
  "emptyStateKey": "interopHl7SchemasEmpty",
  "commandAliases": ["hl7 schemas", "hl7 schema"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopHl7SchemasPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopHl7SchemasPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopHl7SchemasPrompt3"}
  ],
  "classicPage": "EnsPortal.HL7.SchemaMain",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "HL7 schema",
    "source": {"port": "interop", "endpoint": "Hl7Schemas", "type": "LIST"},
    "fields": ["Category", "Base", "Description", "Standard", "Modified"],
    "filter": ["Category", "Base", "Description"],
    "sort": {"fields": ["Category", "Base", "Standard", "Modified"], "default": "Category", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Category", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Base", "labelKey": "interopHl7ColumnBase", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Standard", "labelKey": "interopHl7ColumnStandard", "kind": "status"},
      {"field": "Modified", "labelKey": "analyticsColumnModified", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopHl7SchemasEmptyAgent"
  },
  "toolIdentifier": "interop.hl7schemas"
}
}

}
