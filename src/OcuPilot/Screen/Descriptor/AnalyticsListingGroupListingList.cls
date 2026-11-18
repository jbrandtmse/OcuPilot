/// <p>Analytics' Listings: the listings one listing group holds, with each one's type, fields and data connector, read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>,
/// endpoint <code>ListingGroupListings</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.11). A listing's SQL is answered only to a holder of
/// <code>%DeepSee_ListingGroupSQL:USE</code> and is empty for everyone else.</p>
/// <p><b>It is a sub-resource of the Listing groups list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>analytics/listing-groups</code> and is reached from that
/// list's name cell. Its one declared criterion, <code>listinggroup</code>, is the route id, required as a single-object read's is (AD-36); a group that does not exist reads no rows.</p>
/// <p><b>Its id is the composite <code>[ListingGroup, Name]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the Listing groups list's; it offers no action and does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/listing-groups/listings",
  "area": "analytics",
  "labelKey": "analyticsListingGroupListingsLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_ListingGroup", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_ListingGroup", "permission": "USE"}],
  "entityType": "listing-group-listing",
  "secondaryEntityTypes": ["listing-group"],
  "scope": "namespace",
  "parentScope": "analytics/listing-groups",
  "id": {"kind": "composite", "parts": ["ListingGroup", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ListingGroup", "Name", "DisplayName", "Type", "Fields", "OrderBy", "Joins", "Formats", "Source", "Resource", "SelectMode", "Disabled", "Description", "SQL"], "secretFields": []},
  "emptyStateKey": "analyticsListingGroupListingsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsListingGroupListingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsListingGroupListingsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsListingGroupListingsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ListingGroupManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "listing",
    "source": {"port": "analytics", "endpoint": "ListingGroupListings", "type": "LIST"},
    "fields": ["ListingGroup", "Name", "DisplayName", "Type", "Fields", "OrderBy", "Joins", "Formats", "Source", "Resource", "SelectMode", "Disabled", "Description", "SQL"],
    "filter": ["Name", "DisplayName", "Type", "Fields", "Source"],
    "sort": {"fields": ["Name", "DisplayName", "Type", "Source"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "listinggroup", "labelKey": "analyticsListingGroupCriterion", "kind": "text", "maxLength": 255, "hint": "One listing group, spelled as analytics.listinggroups.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Fields", "labelKey": "explorerSqlTabFields", "kind": "text"},
      {"field": "Source", "labelKey": "analyticsColumnDataConnector", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.listinggrouplistings"
}
}

}
