/// <p>Interoperability's Lookup tables: the lookup tables the route's namespace holds, with the time each was last changed, read
/// through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>LookupTables</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story
/// 20.5). A rule or a transformation reads a table through the vendor's <code>Lookup()</code>.</p>
/// <p><b>A table's name opens its entries</b>: <code>interoperability/lookup-tables/entries/&lt;table&gt;</code> declares this
/// list's route as its <code>parentScope</code>. <code>secondaryEntityTypes</code> names <code>lookup-entry</code>, so an entry
/// added, changed or removed on the entries list re-reads this one (AD-14): a table's last entry takes the table with it.</p>
/// <p><b>Its id is the table's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its primary action</b> New table opens the entry dialog in its New table mode: <b>a table is created by adding its first
/// entry</b>, so the dialog asks for a name, a key and a value and posts the same add the entries list's Add does (AD-54, AD-55).
/// <b>Its row action</b> Delete types the table's name and removes the table and every entry in it
/// (<class>OcuPilot.Screen.Tool.InteropLookupTableDelete</class>, AD-53); its governance key ships disabled (AD-22).</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_LookupTables:READ</code>;
/// the delete adds <code>%Ens_LookupTables:WRITE</code> and WRITE on the namespace's globals database, which the port checks
/// before any vendor call (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropLookupTableList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/lookup-tables",
  "area": "interoperability",
  "labelKey": "interopLookupTablesLabel",
  "sideBarPosition": 8,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_LookupTables", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_LookupTables", "permission": "READ"}],
  "entityType": "lookup-table",
  "secondaryEntityTypes": ["lookup-entry"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "export", "selfProtection": ""}, {"id": "export-browser", "selfProtection": ""}, {"id": "import", "selfProtection": ""}, {"id": "import-local", "selfProtection": ""}],
  "context": {"fields": ["Name", "Modified"], "secretFields": []},
  "emptyStateKey": "interopLookupTablesEmpty",
  "commandAliases": ["lookup tables", "lookup table"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopLookupTablesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopLookupTablesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopLookupTablesPrompt3"}
  ],
  "classicPage": "EnsPortal.LookupSettings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "lookup table",
    "source": {"port": "interop", "endpoint": "LookupTables", "type": "LIST"},
    "fields": ["Name", "Modified"],
    "filter": ["Name"],
    "sort": {"fields": ["Name", "Modified"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Modified", "labelKey": "explorerColumnModified", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopLookupTablesEmptyAgent"
  },
  "toolIdentifier": "interop.lookuptables"
}
}

}
