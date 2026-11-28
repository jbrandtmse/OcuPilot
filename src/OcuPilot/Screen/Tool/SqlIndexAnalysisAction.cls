/// <p>The base of the SQL index analyzer's writes (Story 21.27, AD-6, AD-7, AD-21, AD-51, AD-53, AD-56, AD-58): a gathering of the namespace's SQL
/// statements, one report over them, and the purge of both, through <class>OcuPilot.Port.SqlPort</class>'s <code>IndexAnalysis</code> endpoint. Two
/// callers reach each: the page's own action, through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. The target is
/// the literal <code>*</code>, the namespace's analysis, whose fresh read answers the statements it has gathered and each report's rows.</p>
/// <p><b>Its values are declared.</b> <code>Report</code> is one of the five report codes and each flag is <code>true</code> or <code>false</code>; the port
/// takes an absent flag as <code>true</code>, as the classic page's boxes start checked. Each value is judged by the port's own shape check
/// (<method>OcuPilot.Port.SqlPort.ValueProblem</method>), so the mint and the screen refuse what the port would, with the same published sentence.
/// The schema the classic page filters by is the list's filter and is never a write argument.</p>
/// <p><b>Its card shows no state row</b>, as a maintenance write's does not: a precondition that does not hold is refused with the sentence
/// <method>RefusalCode</method> names, for both callers, before anything is written. A report is not refused for its tables being OcuPilot's own: it
/// reads the statements the namespace holds and changes only the vendor's diagnostic rows (AD-10).</p>
Class OcuPilot.Screen.Tool.SqlIndexAnalysisAction Extends OcuPilot.Screen.Tool.SqlStatementAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlIndexAnalysis";

/// <p>The port-composed fresh read: the gathered statement count and each report's row count.</p>
Parameter READTYPE = "ANALYSIS";

Parameter READANSWERS = "Namespace,Statements,IndexUsage,TableScans,TempIndices,JoinIndices,OutlierIndices,Rows,Report,SkipSystem,SkipInserts,SkipIdKeys";

/// <p>The namespace and what its analysis holds, which the person reviewed: an analysis that was gathered, run or purged after the proposal is not the one
/// reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Statements,IndexUsage,TableScans,TempIndices,JoinIndices,OutlierIndices,Rows";

Parameter PRECONDITIONFIELD = "Statements";

/// <p>The classic page whose operations these writes perform (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.QButtons.IndexAnalyzer";

Parameter IDDESCRIPTION = "Send the literal '*': this acts on all of this namespace's index analysis.";

/// <p>The argument naming the target.</p>
ClassMethod IdArgument() As %String
{
    Quit "Target"
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTINDEXANALYSIS
}

/// <p>The literal <code>*</code> only.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ##class(OcuPilot.Port.SqlPort).#ALLID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ##class(OcuPilot.Port.SqlPort).#ALLID _ "': this acts on all of this namespace's index analysis"
}

/// <p>The report, as one of the five codes, is text; a flag is a boolean.</p>
ClassMethod ValueType(pName As %String) As %String
{
    Quit $Select(pName = ##class(OcuPilot.Port.SqlPort).#REPORTKEY: "string", 1: "boolean")
}

/// <p>The port's published sentence for <var>pValue</var> as <var>pName</var>, or <code>""</code>.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    Quit $ClassMethod("OcuPilot.Port.SqlPort", "ValueProblem", pName, pValue)
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

}
