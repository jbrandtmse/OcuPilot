/// <p>Interoperability's Business partners: the organizations and applications a production connects to, which the classic Business
/// Partners page keeps as informational data, with both contacts of each, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>BusinessPartners</code>) and
/// rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 20.5).</p>
/// <p><b>It is read-only</b>: Story 20.5 ships the list alone, and saving or removing a partner is a later story, so it declares
/// no primary action and no row action and names <code>emptyNextKey</code> rather than an invitation to the agent
/// (<method>OcuPilot.Screen.Registry.TableProblem</method>). The partner's name, description and contacts are untrusted content
/// (AD-11, AD-60).</p>
/// <p><b>Its id is the partner's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the
/// Productions list's, which are the classic page's: <code>%Ens_Portal:USE</code> and, as its own,
/// <code>%Ens_ProductionConfig:READ</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropBusinessPartnerList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/business-partners",
  "area": "interoperability",
  "labelKey": "interopBusinessPartnersLabel",
  "sideBarPosition": 9,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "business-partner",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Description", "PrimaryContact", "PrimaryEmail", "PrimaryPhone"], "secretFields": []},
  "emptyStateKey": "interopBusinessPartnersEmpty",
  "commandAliases": ["business partners", "business partner"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopBusinessPartnersPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopBusinessPartnersPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopBusinessPartnersPrompt3"}
  ],
  "classicPage": "EnsPortal.BusinessPartners",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "business partner",
    "source": {"port": "interop", "endpoint": "BusinessPartners", "type": "LIST"},
    "fields": ["Name", "Description", "PrimaryContact", "PrimaryTitle", "PrimaryEmail", "PrimaryPhone", "PrimaryMobile", "PrimaryNotes", "AlternativeContact", "AlternativeTitle", "AlternativeEmail", "AlternativePhone", "AlternativeMobile", "AlternativeNotes"],
    "filter": ["Name", "Description", "PrimaryContact"],
    "sort": {"fields": ["Name", "Description", "PrimaryContact"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "PrimaryContact", "labelKey": "interopPartnerColumnContact", "kind": "text"},
      {"field": "PrimaryPhone", "labelKey": "interopPartnerColumnPhone", "kind": "text"},
      {"field": "PrimaryEmail", "labelKey": "userFieldEmail", "kind": "text"}
    ],
    "emptyNextKey": "interopBusinessPartnersEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.businesspartners"
}
}

}
