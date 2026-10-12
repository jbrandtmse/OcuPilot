/// <p>Interoperability's Lookup table entries: the keys and values one lookup table holds, in the vendor's subscript order, read
/// through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>LookupEntries</code>) and
/// rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 20.5).</p>
/// <p><b>It is a sub-resource of the Lookup tables list and never listed</b> (<code>sideBarPosition</code> 0): it declares
/// <code>parentScope</code> <code>interoperability/lookup-tables</code> and is reached from that list's name cell at
/// <code>interoperability/lookup-tables/entries/&lt;table&gt;</code>. Its one declared criterion, <code>table</code>, is the route
/// id, required as a single-object read's is (AD-36); the port answers the table on each row, so nothing is seeded.</p>
/// <p><b>Its id is the composite <code>[Table, Key]</code></b>, each part kept exactly (AD-13), and its scope is
/// <code>namespace</code>.</p>
/// <p><b>An entry whose key matches the credential pattern is listed with an empty value and <code>Secret</code> true</b>, by the
/// port, so the value never reaches the screen, the context, the read tool or the ledger (AD-35, AD-36); that is why
/// <code>secretFields</code> is empty here.</p>
/// <p><b>Its primary action</b> Add and <b>its row actions</b> Set value and Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.InteropLookupEntryAdd</class>, <class>OcuPilot.Screen.Tool.InteropLookupEntrySet</class> and
/// <class>OcuPilot.Screen.Tool.InteropLookupEntryRemove</class> (AD-53, AD-55); each is in effect at once, since the vendor's
/// <code>Lookup()</code> reads the table with no cache. Remove types the entry's key; removing a table's last entry removes the
/// table. Add and Set value open dialogs.</p>
/// <p><b>Its pairs</b> are the Lookup tables list's; the three tools add <code>%Ens_LookupTables:WRITE</code> and WRITE on the
/// namespace's globals database (AD-8, AD-62). It does not refresh (AD-43); a table's change event (an import or a delete)
/// re-reads it, through <code>secondaryEntityTypes</code> (AD-14).</p>
Class OcuPilot.Screen.Descriptor.InteropLookupEntryList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/lookup-tables/entries",
  "area": "interoperability",
  "labelKey": "interopLookupEntriesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_LookupTables", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_LookupTables", "permission": "READ"}],
  "entityType": "lookup-entry",
  "secondaryEntityTypes": ["lookup-table"],
  "scope": "namespace",
  "parentScope": "interoperability/lookup-tables",
  "id": {"kind": "composite", "parts": ["Table", "Key"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Table", "Key", "Value", "Secret"], "secretFields": []},
  "emptyStateKey": "interopLookupEntriesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopLookupEntriesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopLookupEntriesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopLookupEntriesPrompt3"}
  ],
  "classicPage": "EnsPortal.LookupSettings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "LookupEntries", "type": "LIST"},
    "fields": ["Table", "Key", "Value", "Secret"],
    "filter": ["Key", "Value"],
    "sort": {"fields": ["Key", "Value"], "default": "Key", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "table", "labelKey": "interopLookupEntriesCriterionTable", "kind": "text", "maxLength": 255, "hint": "One lookup table, spelled as interop.lookuptables.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Key", "labelKey": "interopLookupColumnKey", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Secret", "labelKey": "interopLookupColumnSecret", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopLookupEntriesEmptyAgent"
  },
  "toolIdentifier": "interop.lookupentries"
}
}

}
