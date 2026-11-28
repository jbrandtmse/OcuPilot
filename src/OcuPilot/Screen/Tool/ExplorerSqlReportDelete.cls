/// <p>SQL troubleshooting reports' Delete (Story 21.29, AD-6, AD-51, AD-53, AD-58): remove one saved query, named by its id, from its support case's report. Two
/// callers reach it: the list's own Delete row action and the agent's proposal and confirmation. The vendor's removal takes the id alone and removes no other
/// row; no removal by case number is offered. A saved query that is gone is refused at the fresh read, for both callers, before anything is called. A removed
/// row does not come back, so its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlReportDelete Extends OcuPilot.Screen.Tool.SqlReportAction
{

Parameter TOOLNAME = "explorer.sqlreports.delete";

Parameter DESCRIPTION = "Propose removing one saved troubleshooting report query, named by the ID the SQL troubleshooting reports list shows. Only that row is removed. It changes nothing by itself: it answers a proposal the user reviews and confirms.";

Parameter READTYPE = "SAVEDQUERY";

Parameter READSVALUES As BOOLEAN = 0;

Parameter WRITETYPE = "DELETEQUERY";

Parameter SCREENACTIONS = "delete";

Parameter CHANGEACTION = "deleted";

Parameter READANSWERS = "Namespace,ID,WRCNumber";

Parameter FINGERPRINTSUBJECT = "Namespace,ID,WRCNumber";

Parameter STATEFIELD = "ID";

Parameter STATEAFTER = "";

Parameter PRECONDITIONFIELD = "ID";

Parameter CONSEQUENCECODE = "EXPLORER.SQLREPORT.DELETE";

Parameter IDDESCRIPTION = "The saved query to remove, named by the ID the SQL troubleshooting reports list shows.";

/// <p>The saved query's id.</p>
ClassMethod IdArgument() As %String
{
    Quit "ID"
}

/// <p>A saved query's id: a whole number.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If '$IsObject(pId) && $Match(pId, ##class(OcuPilot.Port.SqlPort).#REPORTIDPATTERN) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one saved query by the ID this namespace's SQL troubleshooting reports list shows"
}

}
