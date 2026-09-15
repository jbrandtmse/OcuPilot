/// <p>Fixture descriptor naming an entity type the kernel enum does not hold, so the registry's
/// refusal (AD-14) can be demonstrated on the instance.</p>
/// <p><b>It supplies its declaration through the overridable seam rather than an
/// <code>XData Declaration</code> block</b>, and that is the whole point of the class. The same
/// value fails the build in <file>scripts/check-objectscript.py</file>, which reads XData
/// bodies, and again in <file>ui/tools/screen-mirror.mjs</file>, which reads them off disk --
/// so a checked-in block carrying it could not be committed at all. Declaring it here keeps
/// the tree clean while still driving the third refusal, the one that runs on a live
/// instance.</p>
Class OcuPilot.Test.Bad.Unknown Extends OcuPilot.Screen.Descriptor.Base
{

/// <p>The value no vocabulary holds. Named so the test asserts against this rather than
/// against a second copy of the string.</p>
Parameter BADTYPE = "not-an-entity-type";

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set pObject = {}
    Do pObject.%Set("route", "permissions/nowhere")
    Do pObject.%Set("area", "permissions")
    Do pObject.%Set("labelKey", "navAreaPermissions")
    Do pObject.%Set("sideBarPosition", 1, "number")
    Do pObject.%Set("archetype", "list")
    Do pObject.%Set("built", 1, "boolean")
    Do pObject.%Set("privileges", [])
    Do pObject.%Set("entityType", ..#BADTYPE)
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
    Do pObject.%Set("toolIdentifier", "test.unknown")
    Quit $$$OK
}

}
