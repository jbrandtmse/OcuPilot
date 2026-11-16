/// <p>User DDL mappings' New mapping (AD-55, AD-54, Story 21.13): <code>POST /config/ddl-mappings</code> adds one user DDL mapping to this
/// instance through <class>OcuPilot.Screen.Tool.DdlUserMappingCreate</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a mapping belongs to the instance, so the member is the name alone
/// (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the mapping's name, its absence read, the
/// prohibited set, the port's create and the read-back are the superclass's.</p>
/// <p>The rules over the fields are <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s (<method>Violations</method>). The body's
/// members are <code>Name</code> and <code>Value</code>, the datatype; any other member is 400 <code>PORT.FIELD.UNEXPECTED</code>.</p>
Class OcuPilot.Area.OsMgmt.DdlMappingSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the create through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.DdlUserMappingCreate";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DdlUserMappingList";

/// <p>Empty: a DDL mapping has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

/// <p>The member that holds the datatype.</p>
Parameter VALUEMEMBER = "Value";

/// <p>The codes and the sentence of an empty name and of a taken one, pinned equal to <class>OcuPilot.Api.ConfigError</class>'s.</p>
Parameter NAMEEMPTYCODE = "CONFIG.MAPPING.NAME";

Parameter TAKENCODE = "CONFIG.MAPPING.TAKEN";

Parameter TAKENREASON = "This instance already holds a user DDL mapping of that name.";

/// <p>The rules over the mapping: a datatype that is not a string is <code>PORT.FIELD.SHAPE</code>; the name is judged by
/// <method>OcuPilot.Area.OsMgmt.ConfigSettingRules.NameCode</method> and the datatype by <code>ValueHolds</code>
/// (<code>CONFIG.MAPPING.NAME</code>, <code>CONFIG.SETTING.VALUE</code>).</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tNameCode = ##class(OcuPilot.Area.OsMgmt.ConfigSettingRules).NameCode(pName)
    If tNameCode '= "" Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMEMEMBER, tNameCode)
    Set tType = pFields.%GetTypeOf(..#VALUEMEMBER)
    If tType = "string" {
        If '##class(OcuPilot.Area.OsMgmt.ConfigSettingRules).ValueHolds(##class(OcuPilot.Port.ConfigPort).DatatypeLimits(), pFields.%Get(..#VALUEMEMBER)) {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#VALUEMEMBER, ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE)
        }
    } Else {
        Set pViolations($Increment(pViolations)) = $ListBuild(..#VALUEMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    }
    Quit $$$OK
}

}
