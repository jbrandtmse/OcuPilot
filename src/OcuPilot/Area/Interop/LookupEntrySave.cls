/// <p>Lookup tables' Add (AD-55, AD-54, Story 20.5): <code>POST /interop/lookup-entries</code> adds one entry to a lookup table of
/// the request's namespace through <class>OcuPilot.Screen.Tool.InteropLookupEntryAdd</class>, the tool the agent's mint and confirm
/// read, and creates the table when it is absent -- the New table dialog and the entries list's Add dialog both post here. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the table as the parent and the key as the member: the order of the
/// Save, its hold on the entry's composite id, its absence read, the prohibited set, the port's add and the read-back are
/// the superclass's.</p>
/// <p>A table is never "held" before its first entry, so the parent check passes (<method>ParentHeld</method>), and the rules over
/// the fields are <method>OcuPilot.Port.InteropPort.LookupViolations</method>'s (<method>Violations</method>). The body's members
/// are <code>Table</code>, <code>Key</code> and, optionally, <code>Value</code>.</p>
Class OcuPilot.Area.Interop.LookupEntrySave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropLookupEntryAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropLookupEntryList";

/// <p>The body members that identify the entry: its table and its key.</p>
Parameter PRODUCTIONMEMBER = "Table";

Parameter NAMEMEMBER = "Key";

Parameter PARENTEMPTYCODE = "INTEROP.LOOKUP.TABLENAME";

Parameter NAMEEMPTYCODE = "INTEROP.LOOKUP.KEY";

Parameter TAKENCODE = "INTEROP.LOOKUP.TAKEN";

Parameter TAKENREASON = "This lookup table already holds an entry with that key.";

/// <p>1: a lookup table is created by its first entry, so a table the namespace does not hold yet is no refusal.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit 1
}

/// <p>The rules over the entry: a <code>Value</code> that is not a string is <code>PORT.FIELD.SHAPE</code>, then the port's
/// <method>OcuPilot.Port.InteropPort.LookupViolations</method> over the table, the key and the value.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tValue = ""
    Set tType = pFields.%GetTypeOf("Value")
    If tType = "string" {
        Set tValue = pFields.%Get("Value")
    } ElseIf tType '= "unassigned" {
        Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    }
    Set tSC = $ClassMethod(..PortClass(), "LookupViolations", pParent, pName, tValue, .tFieldViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tFieldViolations {
        Set pViolations($Increment(pViolations)) = tFieldViolations(tI)
    }
    Quit $$$OK
}

}
