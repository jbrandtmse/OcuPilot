/// <p>What the term list editor's six write tools share (AD-6, AD-51, AD-52, AD-53, AD-65, Story 24.2): a write of one term list or one
/// entry of the request's namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Term lists and Entries
/// screens' own actions and the agent's proposal and confirmation. It extends <class>OcuPilot.Screen.Tool.AnalyticsAction</class>, whose
/// pairs and port query it keeps, and differs by the global it needs WRITE on (<parameter>DESTINATIONGLOBAL</parameter>), its screen, its
/// reads and its classic page.</p>
/// <p><b>The fresh read is the port's <code>TERMLIST</code></b>, composed for the action at the mint and at a screen action
/// (<method>PortQuery</method>): an add reads absent, and the others refuse by the port's own codes when the target is not there. The
/// confirm's re-read carries the reviewed state, so a target that moved closes the proposal through the fingerprint.</p>
/// <p><b>It declares</b> the screen's own pairs, WRITE on the resource guarding the database <code>^DeepSee.TermList</code> maps to, READ on
/// the routines database and the custom resource of the classic Term List Manager, each refused by name before any port call. The vendor
/// checks none of them.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListAction Extends OcuPilot.Screen.Tool.AnalyticsAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsTermListList";

Parameter DESTINATIONGLOBAL = "^DeepSee.TermList";

Parameter CLASSICPAGES = "%DeepSee.UI.TermListManager";

/// <p>The fresh read: one term list.</p>
Parameter READTYPE = "TERMLIST";

Parameter READANSWERS = "Name,Caption,Description,Pattern,SubjectArea,Fields,HideValue,Modified,Namespace";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Modified";

Parameter STATEFIELD = "";

/// <p>The consequence of a delete and of a remove, published once (EXPERIENCE.md's Fixed strings).</p>
Parameter CONSEQUENCECODE;

/// <p>The removal rows the card shows.</p>
Parameter REMOVALROWS = "";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTTERMLISTS
}

/// <p>The term list's name, which the rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The title the card gives the target: the fresh read's name, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..IdArgument()) = "string") Quit pFresh.%Get(..IdArgument())
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..IdArgument()) = "string") Quit pArgs.%Get(..IdArgument())
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

/// <p>The answer reaches the screen as the port's row: no output lines.</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Quit ""
}

/// <p>The rules over the call as one sentence naming each field and its published sentence, appended to <var>pProblem</var>: the port's
/// shape rules (<method>OcuPilot.Port.AnalyticsPort.TermListViolations</method>) over the list <var>pName</var> and entry <var>pKey</var>,
/// then the rules that need the instance's state (<method>OcuPilot.Port.AnalyticsPort.StateProblem</method>).</p>
ClassMethod RuleProblem(pType As %String, pName As %String, pKey As %String, pArgs As %DynamicObject, ByRef pProblem As %String, pChecksState As %Boolean = 1) As %Status
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit $$$OK
    Set tSC = $ClassMethod(..#PORTCLASS, "TermListViolations", pType, pName, pKey, pArgs, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    If (pProblem '= "") || 'pChecksState Quit $$$OK
    Set pProblem = $ClassMethod(..#PORTCLASS, "StateProblem", ..ArgumentNamespace(pArgs), pType, pName, pArgs)
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live
/// (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The JSON array text <var>pText</var> as an array in <var>pArray</var>, and <code>""</code>; or the sentence that refuses the
/// text, with <var>pArray</var> <code>""</code>. A screen action's values are strings, so a list travels as JSON text.</p>
ClassMethod ArrayFromText(pText As %String, pName As %String, Output pArray) As %String
{
    Set pArray = ""
    Try {
        Set tValue = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tValue) && tValue.%IsA("%Library.DynamicArray") Set pArray = tValue
    } Catch {
        Set pArray = ""
    }
    If $IsObject(pArray) Quit ""
    Quit "'" _ pName _ "' is a JSON array"
}

}
