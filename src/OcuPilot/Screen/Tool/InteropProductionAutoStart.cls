/// <p>Interoperability's auto-start (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.3): choose the production the namespace starts with
/// the instance and its startup priority, or stop starting any, as the classic Auto-Start Production page does. A namespace starts at
/// most one production, so turning it on for one replaces the production set before, and the card shows that production's change from
/// Yes to No. Name the production as the Productions list reports it; give <code>AutoStart</code> <code>1</code> to start it with the
/// instance or <code>0</code> to stop, and a <code>StartupPriority</code> only with <code>1</code>. Turning it on with no priority sets
/// 0, and the card shows that row.</p>
/// <p>Two callers reach it: the Productions row action Start with the instance through <class>OcuPilot.Api.ScreenAction</class>, whose dialog
/// sends the checkbox and the priority, and the agent's proposal and confirmation. Its read, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.InteropStartupAction</class>'s, and its read-back compares <code>AutoStart</code> and
/// <code>StartupPriority</code>.</p>
Class OcuPilot.Screen.Tool.InteropProductionAutoStart Extends OcuPilot.Screen.Tool.InteropStartupAction
{

Parameter TOOLNAME = "interop.productions.autostart";

Parameter DESCRIPTION = "Propose setting which production of the namespace the user is working in starts when the instance starts, and at which startup priority, or stopping that. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. AutoStart is 1 to start it with the instance or 0 to stop starting it; StartupPriority is an optional whole number of at most nine digits, given only with 1 (higher priorities start first). A namespace starts at most one production with the instance, so turning it on replaces any production set before. A production already set that way is refused.";

Parameter WRITETYPE = "AUTOSTART";

Parameter WRITERESOURCE = "%Ens_ProductionConfig";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "EnsPortal.AutoStartProduction";

Parameter SCREENACTIONS = "autostart";

Parameter SCREENVALUES = "autostart=AutoStart:StartupPriority";

Parameter SCREENOPTIONAL = "autostart=StartupPriority";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "AutoStart,StartupPriority";

Parameter CONSEQUENCECODE = "INTEROP.AUTOSTART";

/// <p>The label of the card's row for the production this one replaces: <code>AutoStartOther</code> is a state of the namespace and no
/// property the tool sets, so the prohibited set leaves it outside its sweep (<method>OcuPilot.Kernel.Proposal.Prohibited.SkippedFields</method>).</p>
Parameter STATEFIELD = "AutoStartOther";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#AUTOSTARTFIELD, ..#PRIORITYFIELD)
}

ClassMethod RequiredFields() As %List
{
    Quit $ListBuild(..#AUTOSTARTFIELD)
}

ClassMethod FieldDescription(pField As %String) As %String
{
    If pField = ..#AUTOSTARTFIELD Quit "1 to start this production when the instance starts, 0 to stop starting it. Turning it on replaces any production of the namespace set to start before."
    Quit "The startup priority, a whole number of at most nine digits with a minus sign if negative; higher priorities start first. Give it only with AutoStart 1. Left out, 0 is used."
}

/// <p>The claim that this production starts with the instance, which the card shows as Yes and No, and, when it replaces another, that
/// production's own change to No. The merge's payload carries a priority only while the production starts with the instance: turning it
/// off leaves none, so the read-back compares none, and turning it on with no priority sets 0, which the card shows as a row.
/// <var>pUnchanged</var> counts the payload properties the write sends untouched.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Try {
        Set tIterator = pDiff.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("field") = ..#AUTOSTARTFIELD {
                Do tRow.%Set("before", $Select(tRow.%Get("before") = "1": "Yes", 1: "No"), "string")
                Do tRow.%Set("after", $Select(tRow.%Get("after") = "1": "Yes", 1: "No"), "string")
            }
        }
        If pPayload.%Get(..#AUTOSTARTFIELD) = "0" {
            If pPayload.%GetTypeOf(..#PRIORITYFIELD) '= "unassigned" {
                ; Counted untouched only when the arguments left the priority as the read had it.
                If pPayload.%Get(..#PRIORITYFIELD) = pFresh.%Get(..#PRIORITYFIELD) Set pUnchanged = pUnchanged - 1
                Do pPayload.%Remove(..#PRIORITYFIELD)
            }
        } ElseIf (pPayload.%Get(..#AUTOSTARTFIELD) = "1") && (pFresh.%Get(..#AUTOSTARTFIELD) = "0") {
            If pPayload.%Get(..#PRIORITYFIELD) = "" {
                Do pPayload.%Set(..#PRIORITYFIELD, "0", "string")
                Set tRow = {}
                Do tRow.%Set("field", ..#PRIORITYFIELD, "string")
                Do tRow.%Set("before", "", "string")
                Do tRow.%Set("after", "0", "string")
                Do pDiff.%Push(tRow)
                Set pUnchanged = pUnchanged - 1
            }
            If pFresh.%Get("AutoStartOther") '= "" {
                Set tRow = {}
                Do tRow.%Set("field", "AutoStartOther", "string")
                Do tRow.%Set("before", "Yes", "string")
                Do tRow.%Set("after", "No", "string")
                Do pDiff.%Push(tRow)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The dialog's values as this tool's arguments over the fresh read: turning auto-start off carries an empty priority, so the
/// production's stored one leaves the body, and turning it on for a production that does not start with the instance carries priority 0
/// when the dialog gave none. The kernel's own merge then reads back what the write left.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || '$IsObject(pFresh) || '$IsObject(pArgs) Quit tSC
    If (pArgs.%Get(..#AUTOSTARTFIELD) = "0") && (pArgs.%GetTypeOf(..#PRIORITYFIELD) = "unassigned") {
        Do pArgs.%Set(..#PRIORITYFIELD, "", "string")
    } ElseIf (pArgs.%Get(..#AUTOSTARTFIELD) = "1") && (pFresh.%Get(..#AUTOSTARTFIELD) = "0") && (pArgs.%GetTypeOf(..#PRIORITYFIELD) = "unassigned") {
        Do pArgs.%Set(..#PRIORITYFIELD, "0", "string")
    }
    Quit tSC
}

/// <p>The replacement consequence when the payload turns auto-start on for a production while another is set, else none.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%Get(..#AUTOSTARTFIELD) = "1") && (pPayload.%Get("AutoStartOther") '= "") Quit ..#CONSEQUENCECODE
    Quit ""
}

/// <p>A priority beside <code>AutoStart</code> <code>0</code>, as the published sentence.</p>
ClassMethod ExtraProblem(ByRef pValues) As %String
{
    If ($Get(pValues(..#AUTOSTARTFIELD)) = "0") && ($Get(pValues(..#PRIORITYFIELD)) '= "") Quit $ClassMethod(..#PORTCLASS, "ReasonFor", "INTEROP.STARTUP.NOPRIORITY")
    Quit ""
}

}
