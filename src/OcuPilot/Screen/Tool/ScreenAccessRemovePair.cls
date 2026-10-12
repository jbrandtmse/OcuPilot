/// <p>Screen permissions' Remove (AD-51, AD-53, AD-64, Story 20.15): remove one pair from a screen's required
/// permissions, leaving at least one. <class>OcuPilot.Port.ScreenAccessPort</class> applies it over the
/// stored set read at the write (AD-56 (ii)).</p>
Class OcuPilot.Screen.Tool.ScreenAccessRemovePair Extends OcuPilot.Screen.Tool.ScreenAccessAction
{

Parameter TOOLNAME = "agent.screenpermissions.removepair";

Parameter DESCRIPTION = "Propose removing one required permission from a screen: a resource and READ, WRITE or USE, written resource:permission, as the Screen permissions list shows it. It changes nothing by itself: it answers a proposal the user reviews and confirms. A screen keeps at least one pair. Removing a pair lets more accounts open the screen; the instance still checks what they do there.";

Parameter CHANGEACTION = "updated";

/// <p>The row action the list's Remove carries out (AD-53).</p>
Parameter SCREENACTIONS = "remove-pair";

/// <p>The dialog sends the pair as this tool's one value (AD-56 (ii)).</p>
Parameter SCREENVALUES = "remove-pair=Pair";

/// <p>The one argument: the pair to remove.</p>
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
    Do tProperties.%Set(..#ARGUMENT, {"type": "string", "description": "The pair to remove, written resource:permission, exactly as the screen's required permissions list it, such as %Admin_Manage:USE."})
    Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The pair under the port's remove key, from the call's arguments or the stored payload.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#ARGUMENT) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.ScreenAccessPort).#REMOVEKEY) = pPayload.%Get(..#ARGUMENT)
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
