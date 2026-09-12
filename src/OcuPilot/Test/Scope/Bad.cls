/// <p>Fixture descriptor declaring a <code>scope</code> that is neither <code>namespace</code>
/// nor <code>instance</code>, so the registry's refusal can be demonstrated.</p>
/// <p>The two values are what <method>OcuPilot.Kernel.EntityRef.ScopeFor</method> resolves; a
/// third spelling yields <code>""</code> there, so a descriptor carrying one would build
/// references with no scope at all rather than fail anywhere visible.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Pair.Bad</class> does: two malformed fixtures in one package would race
/// to be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.Scope.Bad Extends OcuPilot.Screen.Descriptor.Base
{

/// <p>The value neither vocabulary holds. Named so the test asserts against this rather than
/// against a second copy of the string.</p>
Parameter BADSCOPE = "cluster";

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set pObject = {}
    Do pObject.%Set("route", "permissions/unscoped")
    Do pObject.%Set("area", "permissions")
    Do pObject.%Set("labelKey", "navAreaPermissions")
    Do pObject.%Set("sideBarPosition", 1, "number")
    Do pObject.%Set("archetype", "list")
    Do pObject.%Set("built", 1, "boolean")
    Do pObject.%Set("privileges", [])
    Do pObject.%Set("entityType", "user")
    Do pObject.%Set("secondaryEntityTypes", [])
    ; The declaration this fixture exists for.
    Do pObject.%Set("scope", ..#BADSCOPE)
    Do pObject.%Set("parentScope", "")
    Do pObject.%Set("id", {"kind": "none", "parts": []})
    Do pObject.%Set("context", {"fields": [], "secretFields": []})
    Do pObject.%Set("primaryAction", {"id": "", "selfProtection": ""})
    Do pObject.%Set("rowActions", [])
    Do pObject.%Set("emptyStateKey", "")
    Do pObject.%Set("commandAliases", [])
    Do pObject.%Set("classicPage", "")
    Do pObject.%Set("classicLinkExemption", {"exempt": false, "reason": ""})
    Do pObject.%Set("toolIdentifier", "test.badscope")
    Quit $$$OK
}

}
