/// <p>SQL troubleshooting reports' Save query (Story 21.29, AD-6, AD-7, AD-51, AD-53, AD-58): store one query under a support case, with its plan, the
/// definitions of the classes it reads and its compiled code, as the classic Generate Report page does. Two callers reach it: the page's own Save query
/// action, which sends the statement and the case number, and the agent's proposal and confirmation. Saving runs the statement once, without its values.</p>
/// <p><b>A statement that is not a query is refused at the fresh read</b>, for both callers, before anything is called, and so is a statement over
/// OcuPilot's own tables or one the instance would not prepare (<method>OcuPilot.Port.SqlPort.ReportGuard</method>). A save the instance answers with an
/// error status leaves no row.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlReportSave Extends OcuPilot.Screen.Tool.SqlReportAction
{

Parameter TOOLNAME = "explorer.sqlreports.save";

Parameter DESCRIPTION = "Propose saving one SQL query under an InterSystems support case, as the classic Generate Report page does: the instance runs the query once, without its values, and stores its plan, the definitions of the classes it reads and its compiled code, so a report can be generated for the case. Send the literal '*' as the target, the query as Statement and the case number as WRCNumber (digits only, up to 9). Only a query is saved. It changes nothing by itself: it answers a proposal the user reviews and confirms.";

Parameter WRITETYPE = "SAVEQUERY";

Parameter SCREENACTIONS = "save";

Parameter SCREENVALUES = "save=Statement:WRCNumber";

Parameter VALUENAMES = "Statement,WRCNumber";

Parameter VALUEDESCRIPTIONS = "Statement=One SQL query to save, 1 to 32,000 characters, as written, with a ? where each value goes. A statement that is not a query is refused.|WRCNumber=The support case number InterSystems support gave you: digits only, a whole number of up to 9 digits.";

/// <p>The case, how many queries it holds, and the statement's kind, type and tables as reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,WRCNumber,Saved,Kind,StatementType,Tables,Statement";

Parameter STATEFIELD = "Saved";

Parameter PRECONDITIONFIELD = "Saved";

Parameter REFUSALCODE = "EXPLORER.SQLREPORT.QUERYONLY";

Parameter CONSEQUENCECODE = "EXPLORER.SQLREPORT.SAVE";

/// <p>Only a query is saved.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%Get("Kind") = ##class(OcuPilot.Port.SqlPort).#KINDQUERY)
}

/// <p>The case's saved-query count moving up by one; a read that does not meet <method>Holds</method> is the query-only refusal (<method>RefusalCode</method>).</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, .pRows, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || (pRows.%Size() '= 1) Quit tSC
    Do pRows.%Get(0).%Set("after", +pFresh.%Get("Saved") + 1, "string")
    Quit $$$OK
}

}
