/// <p>The base of the SQL troubleshooting report writes (Story 21.29, AD-6, AD-7, AD-21, AD-51, AD-53, AD-56, AD-58): the save of a query for a support
/// case, the removal of one saved query, and the generation of a case's report, through <class>OcuPilot.Port.SqlPort</class>'s <code>Reports</code>
/// endpoint. Two callers reach each: the page's own action, through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and
/// confirmation.</p>
/// <p><b>Its values are declared</b> and judged by the port's own shape check (<method>OcuPilot.Port.SqlPort.ValueProblem</method>), so the mint and the
/// screen refuse what the port would, with the same published sentence. The statement reaches the vendor whole, as a value, and the case number is a whole
/// number of up to 9 digits. No caller text reaches SQL text, code or a path.</p>
/// <p><b>Its fresh read is composed from the values</b> (<parameter>READSVALUES</parameter>): the case's saved-query count and, for a statement, its guard
/// after the console's own checks, so the mint, a screen action and the confirm's re-read judge one state.</p>
Class OcuPilot.Screen.Tool.SqlReportAction Extends OcuPilot.Screen.Tool.SqlStatementAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlReports";

/// <p>The case read, composed from the declared values.</p>
Parameter READTYPE = "CASE";

Parameter READSVALUES As BOOLEAN = 1;

Parameter READANSWERS = "Namespace,WRCNumber,Saved,Kind,StatementType,Tables,Statement,root,path";

/// <p>The classic page whose operations these writes perform (AD-44): the report generator. Generate adds its dialog.</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.QButtons.ReportGenerator";

Parameter IDDESCRIPTION = "Send the literal '*': this acts on the support case the values name in this namespace.";

/// <p>The argument naming the target.</p>
ClassMethod IdArgument() As %String
{
    Quit "Target"
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTREPORTS
}

/// <p>The literal <code>*</code> only.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ##class(OcuPilot.Port.SqlPort).#ALLID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ##class(OcuPilot.Port.SqlPort).#ALLID _ "': this acts on the support case the values name"
}

/// <p>Every declared value is text here: the statement, the case number and a file's two names.</p>
ClassMethod ValueType(pName As %String) As %String
{
    Quit "string"
}

/// <p>The port's published sentence for <var>pValue</var> as <var>pName</var>, or <code>""</code>.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    Quit $ClassMethod("OcuPilot.Port.SqlPort", "ValueProblem", pName, pValue)
}

}
