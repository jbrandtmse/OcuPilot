/// <p>Analytics' term list copy (AD-6, AD-10, AD-51, AD-53, AD-54, AD-65, Story 24.10): the classic Term List Manager's Save As, as a new list under a
/// new name with the source's header and every entry. Two callers reach it: the Term lists row action Copy term list, whose one value is the new
/// name, and the agent's proposal and confirmation.</p>
/// <p><b>It only creates.</b> A list of the new name, compared without regard to case, is refused <code>ANALYTICS.TERMLIST.TAKEN</code> before any
/// vendor call, the source's own name included; nothing is overwritten, which the classic Save As does after a confirm. The source is only read. The
/// copy is written through the editor's seams in one transaction (<method>OcuPilot.Port.AnalyticsPort.WriteWholeList</method>), so a failure leaves
/// no list.</p>
/// <p><b>The reviewed state</b> is the source's stamp and entry count and whether the new name is free: the fresh read composes them
/// (<code>COPYTARGET</code>), and the fingerprint holds them.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListCopy Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.copy";

Parameter DESCRIPTION = "Propose copying one term list to a new term list in the namespace the user is working in: the new list takes the source's caption, description, pattern, subject area, fields, hide-value flag and every entry, and the source is not changed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the source exactly as the Term lists list reports it in its Name column, and give the new list's name in `NewName`. A name the namespace already holds (compared without regard to case, so the source's own name is refused too), a name over the limits and a database that is read-only or not journaled are refused.";

/// <p>The fresh read: the source, with the new name's state, composed from the call's own values.</p>
Parameter READTYPE = "COPYTARGET";

Parameter READANSWERS = "Name,Modified,Entries,NewName,Present,Namespace";

Parameter SCREENACTIONS = "copy";

Parameter SCREENVALUES = "copy=NewName";

Parameter WRITETYPE = "COPY";

/// <p>The copy creates a list, so the change event is a creation.</p>
Parameter CHANGEACTION = "created";

/// <p>The source as reviewed and whether the new name was free.</p>
Parameter FINGERPRINTSUBJECT = "Name,Modified,Entries,NewName,Present,Namespace";

Parameter PRECONDITIONFIELD = "Modified";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.TAKEN,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

/// <p>The new list's name: the one argument beyond the source, reaching the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("NewName")
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The term list to copy, named exactly as this namespace's Term lists list reports it in its Name column. A list the namespace does not hold is refused.", "string")
    }
    Do tProperties.%Set("NewName", {"type": "string", "description": "The new term list's name: 1 to 255 characters with no control character. A name the namespace already holds is refused, compared without regard to case, so check the Term lists list first."})
    Do tSchema.%Get("required").%Push("NewName")
    Quit tSchema
}

/// <p>The new name must be a string that the editor's name rule admits (AD-55): the screen's save and the mint apply it alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf("NewName") '= "string") Quit $$$OK
    Quit ..RuleProblem(##class(OcuPilot.Port.AnalyticsPort).#TYPEADD, pArgs.%Get("NewName"), "", {}, .pProblem, 0)
}

/// <p>The screen's one value as this tool's argument.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf("NewName") = "string") Do pArgs.%Set("NewName", pValues.%Get("NewName"), "string")
    Quit $$$OK
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then the new name the payload holds, so
/// the mint, the confirm's re-read and its write all read one state (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf("NewName") = "string") && (pPayload.%Get("NewName") '= "") Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWNAMEKEY) = pPayload.%Get("NewName")
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>NewName</code> (the list the copy creates) and <code>Entries</code> (the entries it
/// holds). A read that answered no entry count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Entries") '= "number") || (pFresh.%GetTypeOf("NewName") '= "string") {
            Set pProblem = "this instance did not report the source's entries, and a source whose state is unknown is not one to copy"
            Quit
        }
        For tField = "NewName", "Entries" {
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", $Select(tField = "Entries": 0, 1: ""), "string")
            Do tRow.%Set("after", pFresh.%Get(tField), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The title the card gives the copy: the source's name, from the fresh read, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>The name of the list the confirmed copy <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
