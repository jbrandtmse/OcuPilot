/// <p>SQL troubleshooting reports' Generate report (Story 21.29, AD-6, AD-21, AD-51, AD-53, AD-58): write the XML report of every query the caller can see
/// saved for a support case, to a server file or to this browser. Two callers reach it: the page's own actions, <code>generate</code>, which names the file
/// by its two values, and <code>generate-browser</code>, which names none and answers the report's lines for the page to save; and the agent's proposal and
/// confirmation, which always names a server file. A case with no saved query is refused at the fresh read, for both callers, before anything is called.</p>
/// <p><b>The file is named by <code>root</code> and <code>path</code></b>, an allowed directory and a relative name under it (AD-21's sixth case), resolved by
/// <class>OcuPilot.Port.PathPort</class> as an overwriting file whose overwrite the port declares, never a caller value; a missing directory is refused. The
/// vendor receives only a temporary file OcuPilot names. A file already at the name is replaced (<method>Consequence</method>). The report's lines answered to
/// the screen are its output alone and are never stored or logged (AD-39).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlReportGenerate Extends OcuPilot.Screen.Tool.SqlReportAction
{

Parameter TOOLNAME = "explorer.sqlreports.generate";

Parameter DESCRIPTION = "Propose writing the troubleshooting report of one InterSystems support case to a file on the server, as the classic Generate Report page does: the XML holding every query saved for the case that the user can see, with its plan, the definitions of the classes it reads and its compiled code. Send the literal '*' as the target and the case number as WRCNumber. Name the file by `root`, an allowed directory exactly as this instance's Allowed directories screen lists it, and `path`, the file's name relative to root. A file already at that name is replaced. It changes nothing by itself: it answers a proposal the user reviews and confirms. A case with no saved query is refused.";

Parameter WRITETYPE = "GENERATE";

/// <p>The classic pages whose operation this write performs (AD-44): the report generator and its generate dialog, whose custom resource also gates it.</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.QButtons.ReportGenerator,%CSP.UI.Portal.Dialog.SQLReportGenerator";

/// <p>The report to a server file, whose two values are the file, and the report to this browser, which admits none.</p>
Parameter SCREENACTIONS = "generate,generate-browser";

Parameter SCREENVALUES = "generate=WRCNumber:root:path,generate-browser=WRCNumber";

Parameter VALUENAMES = "WRCNumber,root,path";

Parameter VALUEDESCRIPTIONS = "WRCNumber=The support case number InterSystems support gave you: digits only, a whole number of up to 9 digits.|root=An allowed directory on the server, exactly as this instance's Allowed directories screen lists it. Any other value is refused.|path=The file's name relative to root: up to eight names separated by '/', each starting with a letter or digit and holding only letters, digits, dots, underscores and dashes. Never a full path.";

/// <p>The case as reviewed and the file. The file is in the subject because the stored payload is narrowed to it.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,WRCNumber,Saved,root,path";

Parameter STATEFIELD = "WRCNumber";

Parameter PRECONDITIONFIELD = "Saved";

Parameter REFUSALCODE = "EXPLORER.SQLREPORT.NOROWS";

Parameter CONSEQUENCECODE = "EXPLORER.SQLREPORT.GENERATE";

/// <p>The action that names no file and answers the report's lines.</p>
Parameter BROWSERACTION = "generate-browser";

/// <p>A case with at least one query the caller can see saved.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (+pFresh.%Get("Saved") > 0)
}

/// <p>The report produced for the case: its number moving from nothing to the case.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, .pRows, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || (pRows.%Size() '= 1) Quit tSC
    Do pRows.%Get(0).%Set("before", "", "string")
    Do pRows.%Get(0).%Set("after", pFresh.%Get("WRCNumber"), "string")
    Quit $$$OK
}

/// <p><code>root</code> and <code>path</code> are each a non-empty string, whose shape and place are the port's to judge (AD-55); the case number is the
/// port's own.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    If (pName = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY) && (pValue = "") Quit "'root' names an allowed directory and cannot be empty"
    If (pName = ##class(OcuPilot.Port.AtelierPort).#PATHKEY) && (pValue = "") Quit "'path' names the file under root and cannot be empty"
    If (pName = ##class(OcuPilot.Port.AtelierPort).#ROOTKEY) || (pName = ##class(OcuPilot.Port.AtelierPort).#PATHKEY) Quit ""
    Quit ##super(pName, pValue)
}

/// <p>PathPort's pairs, beside the write's own, when <var>pArgs</var> names a server file by a non-empty <code>root</code> (AD-21's sixth case, AD-29).</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, pArgs, .pResolved)
    Set tFile = ##class(OcuPilot.Screen.Tool.ExplorerExport).FilePairs(pArgs, .tFileResolved)
    If 'tFileResolved Set pResolved = 0
    For tI = 1:1:$ListLength(tFile) {
        If '$ListFind(tPairs, $List(tFile, tI)) Set tPairs = tPairs _ $ListBuild($List(tFile, tI))
    }
    Quit tPairs
}

/// <p>The screen's values as this tool's arguments, unresolved, so the write's own <code>PATH.*</code> refusal reaches the field it is about (AD-56 (ii)):
/// the case number alone for <parameter>BROWSERACTION</parameter>, and the file's two names beside it for the other.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    If pActionId '= ..#BROWSERACTION Quit ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    Set pArgs = {}
    Set pProblem = ..IdProblem($Select($IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string"): pValues.%Get(..IdArgument()), 1: ""))
    If pProblem '= "" Quit $$$OK
    Set tWrc = ##class(OcuPilot.Port.SqlPort).#WRCKEY
    Set tText = $Select($IsObject(pValues) && (pValues.%GetTypeOf(tWrc) = "string"): pValues.%Get(tWrc), 1: "")
    Set pProblem = ..ValueProblem(tWrc, tText)
    If pProblem '= "" Quit $$$OK
    Do pArgs.%Set(tWrc, tText, "string")
    Quit $$$OK
}

/// <p>What the screen shows of the report the port answered <var>pWritten</var> for: the <code>lines</code> of a report to this browser, or the
/// <code>root</code> and <code>path</code> of the file written. Never stored, logged or put on the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tOutput = {}
    If pWritten.%GetTypeOf("lines") = "array" {
        Do tOutput.%Set("lines", pWritten.%Get("lines"))
    } Else {
        Do tOutput.%Set(##class(OcuPilot.Port.AtelierPort).#ROOTKEY, pWritten.%Get(##class(OcuPilot.Port.AtelierPort).#ROOTKEY), "string")
        Do tOutput.%Set(##class(OcuPilot.Port.AtelierPort).#PATHKEY, pWritten.%Get(##class(OcuPilot.Port.AtelierPort).#PATHKEY), "string")
    }
    Quit tOutput
}

/// <p><parameter>CONSEQUENCECODE</parameter> when the payload names a server file (a file already at the name is replaced), else none: a report to this
/// browser writes no file.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf(##class(OcuPilot.Port.AtelierPort).#ROOTKEY) = "string") && (pPayload.%Get(##class(OcuPilot.Port.AtelierPort).#ROOTKEY) '= "") Quit ..#CONSEQUENCECODE
    Quit ""
}

}
