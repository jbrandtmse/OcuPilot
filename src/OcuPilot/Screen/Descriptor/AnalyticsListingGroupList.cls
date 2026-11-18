/// <p>Analytics' Listing groups: the listing groups the namespace holds and the caller may see, each with its caption, its target cubes, whether it is compiled and how many listings it holds,
/// read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>ListingGroups</code>) and rendered by the <code>list</code> archetype's page from
/// the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.11). A group the vendor's own resource check refuses the caller is absent, and so is a group whose definition the vendor cannot read.</p>
/// <p><b>A group's name opens its listings</b>: <code>analytics/listing-groups/listings/&lt;group&gt;</code> declares this list's route as its <code>parentScope</code>. <b>Its id is the group's name</b>,
/// kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its pairs</b> are the classic Listing Group Manager's view resource: <code>%DeepSee_Portal:USE</code> and, as its own, <code>%DeepSee_ListingGroup:USE</code>; the port also checks READ on
/// the namespace's databases before any vendor call (AD-8, AD-65). It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsListingGroupList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/listing-groups",
  "area": "analytics",
  "labelKey": "analyticsListingGroupsLabel",
  "sideBarPosition": 9,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_ListingGroup", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_ListingGroup", "permission": "USE"}],
  "entityType": "listing-group",
  "secondaryEntityTypes": ["listing-group-listing"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Caption", "Cubes", "Class", "Compiled", "Listings", "Disabled", "Description", "Resource", "DefaultResource"], "secretFields": []},
  "emptyStateKey": "analyticsListingGroupsEmpty",
  "commandAliases": ["listing groups", "listing group"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsListingGroupsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsListingGroupsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsListingGroupsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ListingGroupManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "listing group",
    "source": {"port": "analytics", "endpoint": "ListingGroups", "type": "LIST"},
    "fields": ["Name", "Caption", "Cubes", "Class", "Compiled", "Listings", "Disabled", "Description", "Resource", "DefaultResource"],
    "filter": ["Name", "Caption", "Cubes", "Class"],
    "sort": {"fields": ["Name", "Caption", "Cubes", "Class", "Compiled", "Listings"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Cubes", "labelKey": "analyticsColumnTargetCubes", "kind": "text"},
      {"field": "Compiled", "labelKey": "analyticsColumnCompiled", "kind": "status"},
      {"field": "Listings", "labelKey": "analyticsListingGroupListingsLabel", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.listinggroups"
}
}

}
