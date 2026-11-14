/// <p>Business partners' New business partner (AD-55, AD-54, Story 20.26): <code>POST /interop/business-partners</code> adds one
/// partner to the request's namespace through <class>OcuPilot.Screen.Tool.InteropPartnerAdd</class>, the tool the agent's mint and
/// confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a partner belongs to its namespace, so
/// the member is the name alone (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the
/// partner's name, its absence read, the prohibited set, the port's add and the read-back are the superclass's.</p>
/// <p>The rules over the fields are <method>OcuPilot.Port.InteropPort.PartnerViolations</method>'s (<method>Violations</method>).
/// The body's members are <code>Name</code> and, optionally, the thirteen fields of
/// <method>OcuPilot.Screen.Tool.InteropPartnerAdd.SettableFields</method>; any other member is 400
/// <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be changed through this route.</p>
Class OcuPilot.Area.Interop.PartnerSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropPartnerAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropBusinessPartnerList";

/// <p>Empty: a business partner has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.PARTNER.NAME";

Parameter TAKENCODE = "INTEROP.PARTNER.TAKEN";

Parameter TAKENREASON = "This namespace already holds a business partner of that name.";

/// <p>The rules over the partner: a field that is not a string is <code>PORT.FIELD.SHAPE</code>, then the port's
/// <method>OcuPilot.Port.InteropPort.PartnerViolations</method> over the name and the fields.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Kill tValues
    Set tNames = $ListFromString($Parameter(..#CREATETOOL, "FIELDS"))
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If tField = ..#NAMEMEMBER Continue
        Set tType = pFields.%GetTypeOf(tField)
        If tType = "string" {
            Set tValues(tField) = pFields.%Get(tField)
        } ElseIf tType '= "unassigned" {
            Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    Set tSC = $ClassMethod(..PortClass(), "PartnerViolations", pName, .tValues, .tFieldViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tFieldViolations {
        Set pViolations($Increment(pViolations)) = tFieldViolations(tI)
    }
    Quit $$$OK
}

}
