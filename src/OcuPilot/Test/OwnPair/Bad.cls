/// <p>Fixture descriptor that declares <code>%Ens_EventLog:USE</code> its own while its privileges
/// carry only <code>%Admin_Operate:USE</code>, so the registry's refusal of an own pair a screen
/// does not require can be demonstrated through <method>OcuPilot.Screen.Registry.Validate</method>
/// (AD-8). Area <code>logs</code> does not declare the pair either, so without that refusal the
/// own declaration would be what let an unrequired pair past the area's coverage check.</p>
/// <p>It declares no read, for the reason <class>OcuPilot.Test.AreaPair.Bad</class> gives.</p>
Class OcuPilot.Test.OwnPair.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/unowned",
  "area": "logs",
  "labelKey": "navAreaLogs",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_EventLog", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "logs.unowned"
}
}

}
