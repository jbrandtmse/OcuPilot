/// <p>Fixture descriptor that declares no read, and counts how often its declaration is read.</p>
/// <p>A screen with no read yields no read tool and no screen read. The count is what pins the
/// descriptor cache: every accessor run twice reads <method>DeclarationJson</method> once.</p>
Class OcuPilot.Test.Read.Readless Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/readless",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["namespace", "name"]},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "disable", "selfProtection": ""}],
  "emptyStateKey": "",
  "commandAliases": ["readless"],
  "classicPage": "OcuPilotTestClassicPageReadless",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "webapp.readless"
}
}

/// <p>How many times <method>DeclarationJson</method> has run in this process.</p>
ClassMethod ReadCount() As %Integer
{
    Quit +$Get(^||OcuPilotDeclarationReads)
}

/// <p>Reset <method>ReadCount</method> to zero.</p>
ClassMethod ResetReadCount()
{
    Kill ^||OcuPilotDeclarationReads
}

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set ^||OcuPilotDeclarationReads = $Get(^||OcuPilotDeclarationReads) + 1
    Quit ##super(.pObject)
}

}
