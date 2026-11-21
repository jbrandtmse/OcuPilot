/// <p>System default settings' New default setting (AD-55, AD-54, Story 24.15): <code>POST /interop/default-settings</code> adds one system
/// default setting to the request's namespace through <class>OcuPilot.Screen.Tool.InteropDefaultSettingAdd</class>, the tool the agent's mint
/// and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the production as the parent, the setting's name as the
/// member, and the item and the host class as parts of the id between them: the order of the Save, its hold on the setting's composite id,
/// its absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's members are
/// <code>Production</code>, <code>Item</code>, <code>HostClass</code>, <code>Setting</code> and, optionally, <code>Value</code>,
/// <code>Description</code> and <code>Deployable</code>.</p>
/// <p>A production need not be held, since a default setting may name one the namespace does not have yet or <code>*</code>
/// (<method>ParentHeld</method>), and the rules over the key and the fields are
/// <method>OcuPilot.Port.InteropPort.DefaultSettingViolations</method>'s (<method>Violations</method>).</p>
Class OcuPilot.Area.Interop.DefaultSettingSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropDefaultSettingAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropDefaultSettingList";

/// <p>The body members that identify the setting: its production and its name. The item and the host class are the id's two middle parts.</p>
Parameter PRODUCTIONMEMBER = "Production";

Parameter NAMEMEMBER = "Setting";

Parameter ITEMMEMBER = "Item";

Parameter HOSTCLASSMEMBER = "HostClass";

Parameter PARENTEMPTYCODE = "INTEROP.DEFAULTSETTING.KEY";

Parameter NAMEEMPTYCODE = "INTEROP.DEFAULTSETTING.KEY";

Parameter TAKENCODE = "INTEROP.DEFAULTSETTING.TAKEN";

Parameter TAKENREASON = "This namespace already has a default setting for that production, item, host class and setting.";

/// <p>1: a default setting names the production by text and is not read from it, so a production the namespace does not hold is no refusal.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit 1
}

/// <p>The body's member <var>pName</var> as a string, <code>""</code> when it is not one.</p>
ClassMethod MemberOf(pFields As %DynamicObject, pName As %String) As %String [ Private ]
{
    Quit $Select($IsObject(pFields) && (pFields.%GetTypeOf(pName) = "string"): pFields.%Get(pName), 1: "")
}

/// <p>The composite id <code>[Production, Item, HostClass, Setting]</code>, <code>""</code> when a part is empty or carries the separator
/// character; the item and the host class are <var>pFields</var>' <code>Item</code> and <code>HostClass</code>.</p>
ClassMethod IdOf(pProduction As %String, pName As %String, pFields As %DynamicObject = "") As %String
{
    Set tParts = $ListBuild(pProduction, ..MemberOf(pFields, ..#ITEMMEMBER), ..MemberOf(pFields, ..#HOSTCLASSMEMBER), pName)
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    Set tValid = 1
    For tI = 1:1:4 {
        If ($List(tParts, tI) = "") || ($List(tParts, tI) [ tSeparator) Set tValid = 0
    }
    If 'tValid Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite(tParts)
}

/// <p>The rules over the setting: the port's <method>OcuPilot.Port.InteropPort.DefaultSettingViolations</method> over the key, with the item
/// and the host class from <var>pFields</var>, and the value, the description and the flag.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "DefaultSettingViolations", pNamespace, pParent, ..MemberOf(pFields, ..#ITEMMEMBER), ..MemberOf(pFields, ..#HOSTCLASSMEMBER), pName, pFields, .pViolations, 1)
}

/// <p>The superclass's refusal of a body key the tool does not settle, with the item and the host class, which the id carries, left out.</p>
ClassMethod Unexpected(pToolClass As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    For tMember = ..#ITEMMEMBER, ..#HOSTCLASSMEMBER {
        If tArgs.%GetTypeOf(tMember) '= "unassigned" Do tArgs.%Remove(tMember)
    }
    Quit ##super(pToolClass, tArgs, .pHttpStatus, .pFault)
}

}
