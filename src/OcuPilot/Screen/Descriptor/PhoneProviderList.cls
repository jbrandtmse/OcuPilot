/// <p>The mobile phone providers list: every business this instance offers a user for two-factor text messages, each with
/// the DNS name of its SMTP-to-SMS gateway, read through <class>OcuPilot.Port.PhoneProviderPort</class> (source kind
/// <code>phone</code>, endpoint <code>PhoneProviders</code>) and rendered by the <code>list</code> archetype's page from
/// the declared <code>table</code> (AD-5, AD-29, AD-36, Story 21.10). It is Security's fifteenth side-bar entry.</p>
/// <p><b>Its id is the provider's name, kept exactly</b> (AD-13): the vendor finds a provider by its exact name. It
/// declares no <code>rowGet</code>; the editor reads through its own form route
/// (<class>OcuPilot.Area.Security.PhoneProviderRules</class>).</p>
/// <p>Its Create opens <class>OcuPilot.Screen.Descriptor.PhoneProviderForm</class>, as does a row's name cell; its row
/// action Delete is the screen's caller of <class>OcuPilot.Screen.Tool.PhoneProviderDelete</class> (AD-53).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: a principal holding
/// exactly the two listed, created, changed and deleted a provider (AD-8, measured at Story 21.10's plan). The classic page
/// is <code>%CSP.UI.Portal.PhoneProviders</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.PhoneProviderList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/phone-providers",
  "area": "security",
  "labelKey": "phoneProviderListLabel",
  "sideBarPosition": 15,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "phone-provider",
  "entityLabelKey": "aboutPhoneProvider",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "SMSGateway"], "secretFields": []},
  "emptyStateKey": "phoneProviderListEmpty",
  "commandAliases": ["mobile phone providers", "phone providers"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.PhoneProviders",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "mobile phone provider",
    "source": {"port": "phone", "endpoint": "PhoneProviders", "type": "LIST"},
    "fields": ["Name", "SMSGateway"],
    "filter": ["Name", "SMSGateway"],
    "sort": {"fields": ["Name", "SMSGateway"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "SMSGateway", "labelKey": "phoneProviderColumnGateway", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "phoneProviderListEmptyAgent"
  },
  "toolIdentifier": "security.phoneproviders"
}
}

}
