/// <p>Screen permissions' Add (AD-51, AD-53, AD-64, Story 20.15): add one pair to a screen's required
/// permissions. <class>OcuPilot.Port.ScreenAccessPort</class> applies it over the stored set read at the
/// write, so a concurrent change to another pair survives (AD-56 (ii)). The Change permissions dialog sends
/// the pair as <parameter>ARGUMENT</parameter>.</p>
Class OcuPilot.Screen.Tool.ScreenAccessAddPair Extends OcuPilot.Screen.Tool.ScreenAccessAction
{

Parameter TOOLNAME = "agent.screenpermissions.addpair";

Parameter DESCRIPTION = "Propose adding one required permission to a screen: a resource and READ, WRITE or USE, written resource:permission. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the screen as the Screen permissions list reports it. A screen's set holds at most 8 pairs, each on a resource this instance defines. Lowering the permissions a screen requires lets more accounts open it; the instance still checks what they do there.";

Parameter CHANGEACTION = "updated";

/// <p>The row action the list's Add carries out (AD-53).</p>
Parameter SCREENACTIONS = "add-pair";

/// <p>The dialog sends the pair as this tool's one value (AD-56 (ii)).</p>
Parameter SCREENVALUES = "add-pair=Pair";

/// <p>The one argument: the pair to add.</p>
Parameter ARGUMENT = "Pair";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The identifying property described, and <parameter>ARGUMENT</parameter> added, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#ARGUMENT, {"type": "string", "description": "The pair to add, written resource:permission, where the permission is READ, WRITE or USE and the resource is one this instance defines, such as %Admin_Secure:USE."})
    Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The pair under the port's add key, from the call's arguments or the stored payload.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#ARGUMENT) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.ScreenAccessPort).#ADDKEY) = pPayload.%Get(..#ARGUMENT)
}

/// <p>The dialog's pair as this tool's argument; the port judges its shape.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

}
