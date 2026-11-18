/// <p>Analytics' quality measure copy (AD-6, AD-10, AD-51, AD-53, AD-54, AD-61, AD-65, Story 24.12): the classic Quality Measures Manager's Save As, as a new measure under a new name and in
/// a new class, with the source's groups, elements and documentation. Two callers reach it: the Quality measures row action Copy, whose values are the new name and the new class, and the
/// agent's proposal and confirmation.</p>
/// <p><b>It only creates, and it compiles.</b> A name or class in use is refused <code>ANALYTICS.QUALITYMEASURE.TAKEN</code> before anything is saved. The source is only read. It
/// follows <class>OcuPilot.Screen.Tool.AnalyticsListingGroupCopy</class>'s shape without the cubes a group copies into.</p>
/// <p><b>The reviewed state</b> is the source's version and group count and the new name and class: the fresh read composes them (<code>COPYTARGET</code>), and the fingerprint holds them.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureCopy Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction
{

Parameter TOOLNAME = "analytics.qualitymeasures.copy";

Parameter DESCRIPTION = "Propose copying one quality measure to a new quality measure in the namespace the user is working in: the new measure takes the source's caption, description, subject area, expression, groups, elements and documentation, and the source is not changed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the source as the Quality measures list reports it, and give the new measure's full name, catalog/set/id, in `NewName` and the new class in `NewClass`. The new class is saved and compiled. A name or class the namespace already holds and a class name that is malformed or begins with % or OcuPilot are refused.";

/// <p>The fresh read: the source, with the new name and class, composed from the call's own values.</p>
Parameter READTYPE = "COPYTARGET";

Parameter READANSWERS = "Name,Version,Groups,NewName,NewClass,Present,Namespace";

Parameter SCREENACTIONS = "copy";

Parameter SCREENVALUES = "copy=NewName:NewClass";

Parameter WRITETYPE = "COPY";

/// <p>The copy creates a measure, so the change event is a creation.</p>
Parameter CHANGEACTION = "created";

/// <p>The source as reviewed and the new name and class.</p>
Parameter FINGERPRINTSUBJECT = "Name,Version,Groups,NewName,NewClass,Present,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.TAKEN,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

/// <p>The new measure's name and class: the arguments beyond the source, reaching the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("NewName", "NewClass")
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The quality measure to copy, named as this namespace's Quality measures list reports it in its Name column. A measure the namespace does not hold is refused.", "string")
    }
    Do tProperties.%Set("NewName", {"type": "string", "description": "The new quality measure's full name, catalog/set/id: three parts, each 1 to 250 characters with no dot, slash or control character. A name the namespace already holds is refused, compared without regard to case."})
    Do tProperties.%Set("NewClass", {"type": "string", "description": "The new class that holds the copy: dotted letters and digits with a package, beginning with neither % nor OcuPilot. A class the namespace already holds is refused."})
    Do tSchema.%Get("required").%Push("NewName")
    Do tSchema.%Get("required").%Push("NewClass")
    Quit tSchema
}

/// <p>The screen's values as this tool's arguments.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tName = "NewName", "NewClass" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Quit $$$OK
}

/// <p>The new name and class the arguments carry, as the port's query members.</p>
ClassMethod ExtraQuery(pArgs As %DynamicObject, ByRef pQuery)
{
    If pArgs.%GetTypeOf("NewName") = "string" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWNAMEKEY) = pArgs.%Get("NewName")
    If pArgs.%GetTypeOf("NewClass") = "string" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NEWCLASSKEY) = pArgs.%Get("NewClass")
}

/// <p>The namespace and the action key (<method>OcuPilot.Screen.Tool.AnalyticsAction.PortQuery</method>), then the new name and class the payload holds, so the mint, the confirm's
/// re-read and its write all read one state (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Do ..ExtraQuery(pPayload, .pQuery)
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>NewName</code>, <code>NewClass</code> and <code>Groups</code> (the groups the copy holds).</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Groups") '= "number") || (pFresh.%GetTypeOf("NewName") '= "string") {
            Set pProblem = "this instance did not report the source's groups, and a source whose state is unknown is not one to copy"
            Quit
        }
        For tField = "NewName", "NewClass", "Groups" {
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", $Select(tField = "Groups": 0, 1: ""), "string")
            Do tRow.%Set("after", pFresh.%Get(tField), "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The name of the measure the confirmed copy <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
