/// <p>The base of the table maintenance writes (Story 21.25, AD-6, AD-10, AD-21, AD-51, AD-52, AD-53, AD-58): an action-style write over one SQL
/// table, or one of its indices, through <class>OcuPilot.Port.SqlPort</class>'s <code>Tables</code> endpoint, which runs in the confirm or action
/// request and never in a job (AD-7). Two callers reach each: the table tab's page action or the indices tab's row action, through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation.</p>
/// <p><b>It sends no body.</b> The port makes one vendor call with the table's class, resolved through the caller's own information schema, and
/// the declared values alone. The fresh read is the port's <code>TABLESTATS</code>: the table's class, its extent size, whether that size is
/// collected or fixed, when it was collected and whether it has fixed statistics. The fingerprint covers
/// <parameter>FINGERPRINTSUBJECT</parameter>, which names the namespace so that a confirm reaches the namespace the proposal read
/// (<method>OcuPilot.Screen.Tool.SqlStatementAction.PortQuery</method>); a table whose statistics changed after its proposal is closed
/// target-changed.</p>
/// <p><b>A table of OcuPilot's own is refused for both callers before any write</b> by the kernel's table arm
/// (<class>OcuPilot.Kernel.Proposal.Prohibited</class>).</p>
/// <p><b>Its card shows no state row:</b> a maintenance write moves no field a person reviewed, so the card states its consequence alone.</p>
Class OcuPilot.Screen.Tool.SqlTableAction Extends OcuPilot.Screen.Tool.SqlStatementAction [ Abstract ]
{

/// <p>The port-composed fresh read: the table's statistics.</p>
Parameter READTYPE = "TABLESTATS";

Parameter READANSWERS = "Namespace,Table,Class,ExtentSize,StatsKind,CollectedAt,HasFixed";

/// <p>The namespace and the statistics a table write was reviewed against: a table whose statistics moved under a proposal is not the table the person
/// reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,ExtentSize,StatsKind,CollectedAt,HasFixed";

Parameter PRECONDITIONFIELD = "StatsKind";

/// <p>The classic pages whose operations these writes perform: the SQL page's Rebuild menu and its Tune Table window (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.Home,%CSP.UI.Portal.SQL.TuneTable";

Parameter IDDESCRIPTION = "The table to change, as Schema.Table, as this namespace's SQL tables list reports it in its Table column.";

/// <p>The table, as <code>Schema.Table</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Table"
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTTABLES
}

/// <p>Why <var>pId</var> is not a table this tool acts on, or <code>""</code>: a name with a dot, within the table bound
/// (<parameter>OcuPilot.Port.AtelierPort.MAXTABLE</parameter>) and holding no control character, which is the shape the port resolves.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If '$IsObject(pId) && ..TableShaped(pId) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one table as Schema.Table, as this namespace's SQL tables list reports it"
}

/// <p>No state row: <var>pRows</var> is empty. A fresh read that does not meet the precondition (<method>Holds</method>) is <var>pProblem</var>, the
/// sentence <method>RefusalCode</method> names, for both callers.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || '..Holds(pFresh) Set pProblem = ##class(OcuPilot.Port.SqlPort).ReasonFor(..RefusalCode(pFresh))
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The SQL name the kernel's own-name refusal judges before the state precondition is read (<method>RefusedBeforeState</method>): the table, as
/// <code>Schema.Table</code>, <var>pIdValue</var> names. An index tool answers its composite id's table.</p>
ClassMethod NameOf(pIdValue As %String) As %String
{
    Quit pIdValue
}

/// <p>Whether <method>NameOf</method> names a schema and not a table.</p>
ClassMethod NamesSchema() As %Boolean
{
    Quit 0
}

/// <p>A table or schema in one of OcuPilot's own schemas is refused <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTTABLE</parameter> before the
/// precondition is read, 403 for both callers, so a precondition that does not hold never answers in its place (AD-10).</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).RefusesOwnSqlName(..NameOf(pIdValue), ..NamesSchema(), .pCode)
}

/// <p>Whether <var>pName</var> has the shape of a table name, <code>Schema.Table</code>.</p>
ClassMethod TableShaped(pName As %String) As %Boolean
{
    Quit (pName [ ".") && ($Length(pName) <= $Parameter("OcuPilot.Port.AtelierPort", "MAXTABLE")) && ($ZStrip(pName, "*C") = pName)
}

}
