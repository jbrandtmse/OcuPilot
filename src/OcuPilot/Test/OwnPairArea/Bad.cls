/// <p>Fixture descriptor that declares <code>%Admin_Operate:USE</code> both among its privileges
/// and as its own pair, while area <code>logs</code> already declares that pair, so the registry's
/// refusal of an own pair its area declares can be demonstrated through
/// <method>OcuPilot.Screen.Registry.Validate</method> (AD-8).</p>
/// <p>It declares no read, for the reason <class>OcuPilot.Test.AreaPair.Bad</class> gives, and lives
/// in a package of its own, with its own registry, so a roster carries exactly the one fault it
/// names, as <class>OcuPilot.Test.OwnPair.Bad</class> does.</p>
Class OcuPilot.Test.OwnPairArea.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/areaowned",
  "area": "logs",
  "labelKey": "navAreaLogs",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
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
  "toolIdentifier": "logs.areaowned"
}
}

}
