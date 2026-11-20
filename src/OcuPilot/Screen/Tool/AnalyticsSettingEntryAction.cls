/// <p>What the Run-time variables and User-defined icons tabs' six write tools share (AD-6, AD-13, AD-51, AD-52, AD-53, AD-65, Story 24.13, Batch 3): a write of one run-time variable or icon of the request's
/// namespace, by its exact name, through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the tab's own actions and the agent's proposal and confirmation. It is
/// <class>OcuPilot.Screen.Tool.AnalyticsAction</class> with the endpoint's own global as its destination: the write needs WRITE on the database that global maps to, READ on the routines database and the
/// custom resource of the classic Settings page, each refused by name before any port call. The vendor checks none of them.</p>
/// <p><b>The target is the name</b>, kept exactly (AD-13); a name differing only in case is another name, and a name is never changed (a rename is a remove and an add). <b>The fresh read is the port's
/// single-row read of the endpoint</b>, composed for the action at the mint and at a screen action (<method>PortQuery</method>): an add reads absent, and a change or a removal is refused 404 when the name
/// is not there. The shape of every member and a variable's expression are judged by the port (<method>RuleProblem</method>), so the agent is refused what the person is refused. The expression is text: it is
/// checked for syntax and never run.</p>
Class OcuPilot.Screen.Tool.AnalyticsSettingEntryAction Extends OcuPilot.Screen.Tool.AnalyticsAction [ Abstract ]
{

Parameter CLASSICPAGES = "%DeepSee.UI.Settings";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Namespace";

Parameter STATEFIELD = "";

/// <p>The removal rows the card shows.</p>
Parameter REMOVALROWS = "";

/// <p>The members the write names, comma-separated, besides the name: the variable's three, or the icon's path.</p>
Parameter ENTRYMEMBERS;

/// <p>The query parameter the port reads the target's name under.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#IDKEY
}

/// <p>The name, which the tab's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The title the card gives the target: the fresh read's name, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the caller must hold: the screen's own pairs, WRITE on the database <parameter>DESTINATIONGLOBAL</parameter> maps to, READ on the routines database and the custom resource of the classic
/// Settings page (AD-8, AD-44, AD-65). <var>pResolved</var> is 0 when a database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).WritePairs(..#DESCRIPTORCLASS, ..#DESTINATIONGLOBAL, ..#CLASSICPAGES, .pResolved)
}

/// <p>The answer reaches the screen as the port's row: no output lines.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Quit ""
}

/// <p>No state rows: a merge's card shows what it moves, and a removal's rows come from <method>RemovalRows</method>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    If ..#REMOVALROWS = "" Quit tSC
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Namespace") '= "string") {
            Set pProblem = "this instance did not report the target, and a target whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The rules over the call as one sentence naming the member and its published sentence, appended to <var>pProblem</var>: the port's shape rules and, for an expression, its syntax check
/// (<method>OcuPilot.Port.AnalyticsPort.SettingEntryProblem</method>). A removal breaks none.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, ByRef pProblem As %String) As %Status
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit $$$OK
    Set tProblem = $ClassMethod(..#PORTCLASS, "SettingEntryProblem", ..ArgumentNamespace(pArgs), ..Endpoint(), ..#WRITETYPE, pIdValue, pArgs)
    If tProblem '= "" Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ tProblem
    Quit $$$OK
}

/// <p>The rules over the call (<method>RuleProblem</method>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The merge over the fresh read, with <code>Was</code>, the members the target held, added to the payload as one JSON text: the digest a confirm recomputes then covers it, so a target changed since the review
/// closes the proposal as moved even when the change set the member to the value the proposal sets. The port reads only the members <parameter>ENTRYMEMBERS</parameter> names.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) || '$IsObject(pFresh) Quit tSC
    Set tWas = {}
    Set tMembers = $ListFromString(..#ENTRYMEMBERS)
    For tAt = 1:1:$ListLength(tMembers) {
        If pFresh.%GetTypeOf($List(tMembers, tAt)) = "string" Do tWas.%Set($List(tMembers, tAt), pFresh.%Get($List(tMembers, tAt)), "string")
    }
    Do pPayload.%Set("Was", tWas.%ToJSON(), "string")
    Quit tSC
}

/// <p>The text of a screen action's value as the argument it is: <var>pValues</var>' member <var>pName</var> when it is a string, set on <var>pArgs</var>.</p>
ClassMethod CarryText(pValues As %DynamicObject, pArgs As %DynamicObject, pName As %String)
{
    If $IsObject(pValues) && (pValues.%GetTypeOf(pName) = "string") Do pArgs.%Set(pName, pValues.%Get(pName), "string")
}

/// <p>The dialog's values as this tool's arguments: each member <parameter>ENTRYMEMBERS</parameter> names, as text as sent; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tMembers = $ListFromString(..#ENTRYMEMBERS)
    For tAt = 1:1:$ListLength(tMembers) {
        Do ..CarryText(pValues, pArgs, $List(tMembers, tAt))
    }
    Quit $$$OK
}

/// <p>The fields as the rows the input schema is derived from (AD-3): the name when <var>pWithName</var>, then each member of <parameter>ENTRYMEMBERS</parameter>, as text.</p>
ClassMethod EntryFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set tMembers = $ListFromString(..#ENTRYMEMBERS)
    For tAt = 1:1:$ListLength(tMembers) {
        Set pRows($Increment(pRows)) = $ListBuild($List(tMembers, tAt), "string", 0)
    }
    Quit $$$OK
}

}
