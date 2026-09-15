/// <p>Fixture descriptor whose privilege set declares a pair with no <code>permission</code>, so
/// the registry's refusal can be demonstrated.</p>
/// <p>A pair missing either half is dropped by
/// <method>OcuPilot.Screen.Area.PairsFrom</method> rather than carried, which is correct there --
/// it is what lets an area declare an empty set. The consequence one package up is that a
/// descriptor which misspells <code>permission</code> declares a gate and ships ungated, so
/// <method>OcuPilot.Screen.Registry.Validate</method> refuses it instead.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Bad.Unknown</class> does: two malformed fixtures in one package would
/// race to be the first problem reported, and each test would stop pinning the refusal it
/// names.</p>
Class OcuPilot.Test.Pair.Bad Extends OcuPilot.Screen.Descriptor.Base
{

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set pObject = {}
    Do pObject.%Set("route", "permissions/malformed")
    Do pObject.%Set("area", "permissions")
    Do pObject.%Set("labelKey", "navAreaPermissions")
    Do pObject.%Set("sideBarPosition", 1, "number")
    Do pObject.%Set("archetype", "list")
    Do pObject.%Set("built", 1, "boolean")
    ; The misspelling this fixture exists for: "permissions" is not "permission".
    Do pObject.%Set("privileges", [{"resource": "%Admin_Secure", "permissions": "USE"}])
    Do pObject.%Set("entityType", "user")
    Do pObject.%Set("secondaryEntityTypes", [])
    Do pObject.%Set("scope", "instance")
    Do pObject.%Set("parentScope", "")
    Do pObject.%Set("id", {"kind": "none", "parts": []})
    Do pObject.%Set("context", {"fields": [], "secretFields": []})
    Do pObject.%Set("primaryAction", {"id": "", "selfProtection": ""})
    Do pObject.%Set("rowActions", [])
    Do pObject.%Set("emptyStateKey", "")
    Do pObject.%Set("commandAliases", [])
    Do pObject.%Set("classicPage", "")
    Do pObject.%Set("classicLinkExemption", {"exempt": false, "reason": ""})
    Do pObject.%Set("toolIdentifier", "test.malformedpair")
    Quit $$$OK
}

}
