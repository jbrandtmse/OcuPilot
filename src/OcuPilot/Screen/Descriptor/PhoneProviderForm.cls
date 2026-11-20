/// <p>The mobile phone provider editor: one provider, created or edited here, rendered by its own <code>form-page</code>
/// (AD-5, Story 21.10). Its Save and the agent's confirmed <code>security.phoneproviders.create</code> and
/// <code>security.phoneproviders.update</code> are two callers of one tool each (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.PhoneProviderList</class>'s Create and a row's name cell, at that list's route with
/// <code>/edit</code> appended. It declares no <code>read</code>: its form read is <code>GET /phone-provider/form</code>
/// (<class>OcuPilot.Area.Security.PhoneProviderRules</class>).</p>
/// <p><b>Its pairs are the list's own</b>, which hold for every operation (AD-8). Its classic key is the classic provider
/// editor (AD-44).</p>
Class OcuPilot.Screen.Descriptor.PhoneProviderForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/phone-providers/edit",
  "area": "security",
  "labelKey": "aboutPhoneProvider",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "phone-provider",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "phoneProviderListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.PhoneProvider",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.phoneproviderform"
}
}

}
