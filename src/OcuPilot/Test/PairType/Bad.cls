/// <p>Fixture descriptor whose privilege set declares a pair whose <code>resource</code> is a
/// number, so the registry's refusal of a half that is not a string can be demonstrated.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Pair.Bad</class> does: two malformed fixtures in one package would race to
/// be the first problem reported.</p>
Class OcuPilot.Test.PairType.Bad Extends OcuPilot.Screen.Descriptor.Base
{

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set pObject = {}
    Do pObject.%Set("route", "permissions/pairtype")
    Do pObject.%Set("area", "permissions")
    Do pObject.%Set("labelKey", "navAreaPermissions")
    Do pObject.%Set("sideBarPosition", 1, "number")
    Do pObject.%Set("archetype", "list")
    Do pObject.%Set("built", 1, "boolean")
    ; A resource that is a number: both halves are present, and the half is not a string.
    Do pObject.%Set("privileges", [{"resource": 5, "permission": "USE"}])
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
    Do pObject.%Set("toolIdentifier", "test.pairtypepair")
    Quit $$$OK
}

}
