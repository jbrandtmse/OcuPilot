/// <p>Interoperability's setting set (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 20.22): store a value for one
/// setting of one item of a production. It changes the stored configuration and the production class only; a running
/// production reads update pending until Productions' confirmed Update applies it. The value is the one the setting's
/// class validates (<code>&lt;Name&gt;IsValid</code>), and a server path is stored as that class validates it unless it
/// would name the manager directory or the directory OcuPilot serves its files from.</p>
/// <p>Two callers reach it: the Item settings row action Set value through <class>OcuPilot.Api.ScreenAction</class>,
/// whose dialog may send an empty value to clear one, and the agent's proposal and confirmation. It is a merge over
/// the setting's fresh read, so its card shows one <code>Value</code> row and its read-back compares the value
/// (<parameter>READBACKFIELDS</parameter>). Its state, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.InteropSettingAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropSettingSet Extends OcuPilot.Screen.Tool.InteropSettingAction
{

Parameter TOOLNAME = "interop.itemsettings.set";

Parameter DESCRIPTION = "Propose setting one setting of one item of a production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it, the item as that production's Production items list reports it, and the setting with its group (Core, Host or Adapter) and name as the item's Item settings list reports them. Value is the new value as text; an empty string clears it. The change is stored in the production's configuration; a running production applies it only when it is next updated or started. A value the setting's class refuses, a setting whose name holds a credential, a value a system default or service registry entry decides, a server path in the manager directory or the directory OcuPilot serves its files from, a name the production holds more than once and a namespace under source control are refused.";

Parameter WRITETYPE = "SET";

/// <p>The set sends a body: the setting's row with the new value (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

/// <p>The dialog sends the value as this tool's one value, which may be empty (AD-56 (ii)).</p>
Parameter SCREENVALUES = "set=Value";

Parameter SCREENEMPTY = "set=Value";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Value";

Parameter PRECONDITIONCODES = "INTEROP.SETTING.SECRET,INTEROP.SETTING.SUPPLIED,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The one argument: the new value.</p>
Parameter ARGUMENT = "Value";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The one field a set sends, a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild(..#ARGUMENT, "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the value described and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..#ARGUMENT) = "object" {
        Do tProperties.%Get(..#ARGUMENT).%Set("description", "The new value, as text, exactly as the setting stores it: a boolean setting takes 1 or 0. An empty string clears the value. Check the setting's Type and Default on the Item settings list first.", "string")
    }
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>No state rows: a merge's card shows the value it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and
/// a setting nobody established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's value as this tool's argument; the port judges it.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

/// <p>The rules over the call: <code>SECRET</code> on the name, then the port's
/// <method>OcuPilot.Port.InteropPort.SettingViolations</method> over the value, in the namespace the arguments carry,
/// else the request's (<method>ArgumentNamespace</method>), as one sentence naming each field and its published
/// sentence, or <code>""</code>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 4 Quit $$$OK
    Set tSC = $ClassMethod(..#PORTCLASS, "SettingViolations", ..ArgumentNamespace(pArgs), $List(tParts, 1), $List(tParts, 2), $List(tParts, 3), $List(tParts, 4), pArgs, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

}
