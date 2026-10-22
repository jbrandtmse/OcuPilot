/// <p>Pins the agent's MDX read, <code>analytics.mdxquery.read</code> (Story 20.35, AD-7, AD-21, AD-24, AD-36, AD-60, AD-65), against the probe cubes
/// in <code>USER</code>: a SELECT answers its labels and cells as the vendor's own result set gives them, the label column first; a typed
/// DRILLTHROUGH and a cell's drill answer the vendor's listing within its cap; a listing column named like a credential reads
/// <code>[redacted]</code>; CREATE, DROP and three axes are refused by their codes with no background run reserved; a syntax error answers
/// the vendor's text, cut at the port's cell bound when it is longer; a namespace without analytics and a read-only cache are refused before any vendor call; and every spelling of a
/// construct that runs server-side code or SQL (<code>%SEARCH</code>, <code>%SQLRESTRICT</code>, <code>RETURN</code>, <code>%ORDER</code>
/// and <code>%PARM</code>, through comments, literals and single-quoted spans), a text the lexer refuses, and a statement whose
/// variable-resolved text holds one are refused 422 <code>ANALYTICS.MDX.SQL</code> before anything runs, the first two before a prepare,
/// each splice node left undefined.</p>
/// <p>The refusal legs run through <class>OcuPilot.Test.AnalyticsMdxReadFixture</class>, whose port counts what it is asked to prepare.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// <class>OcuPilot.Test.AnalyticsProbe</class> turns analytics on for <code>USER</code> and writes cubes there. The probe is removed after the
/// last test, with the splice nodes 351 to 358, and <method>OcuPilot.Test.AnalyticsProbe.Gone</method> is asserted.</p>
Class OcuPilot.Test.AnalyticsMdxRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.AnalyticsMdxRead";

Parameter FIXTURE = "OcuPilot.Test.AnalyticsMdxReadFixture";

Parameter RECORDER = "OcuPilot.Test.AnalyticsPortRecorder";

Parameter VENDOR = "OcuPilot.Test.AnalyticsMdx";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter NAMESPACE = "USER";

/// <p>Five categories on rows and the Amount measure on columns, over the Visits cube.</p>
Parameter VISITS = "SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]";

/// <p>The grid cube's two-by-two crossjoin: rows <code>1 / 0</code> and <code>2 / 0</code> hold 4 and 8.</p>
Parameter CROSSJOIN = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxRead turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxRead left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#RECORDER, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#RECORDER, "Reset")
    Quit $$$OK
}

/// <p>The read <var>pTool</var> gives <var>pArgs</var> with the scope set to <var>pNamespace</var>, as the running account.</p>
ClassMethod Read(pTool As %String, pArgs As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pFault, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Quit $ClassMethod(pTool, "View", "", pArgs, 200, .pResult, .pHttp, .pFault)
}

/// <p>How a call ended: <code>http code</code> for a refusal, <code>200 outcome</code> otherwise.</p>
ClassMethod Said(pSC As %Status, pResult, pHttp As %Integer, pFault) As %String
{
    If $$$ISERR(pSC) Quit +pHttp _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
    Quit pHttp _ " " _ $Select($IsObject(pResult): pResult.%Get("outcome"), 1: "")
}

/// <p>Run <var>pStatement</var> through <var>pTool</var> and say how it ended.</p>
Method Ends(pTool As %String, pStatement As %String, Output pResult, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Set tSC = ..Read(pTool, {"statement": (pStatement)}, .pResult, .tHttp, .tFault, pNamespace)
    Quit ..Said(tSC, .pResult, tHttp, .tFault)
}

/// <p>A cells result as <code>C=&lt;headers&gt;;R=&lt;label&gt;:&lt;cells&gt;;...</code>, headers and cells joined with <code>|</code> and
/// <code>,</code>: the shape <method>OcuPilot.Test.AnalyticsMdx.VendorCells</method> gives the vendor's own answer. The first column and
/// each row's first member are the label column.</p>
ClassMethod FlattenCells(pResult As %DynamicObject) As %String
{
    If '$IsObject(pResult) || (pResult.%Get("outcome") '= "cells") Quit "not cells"
    Set tOut = "C="
    Set tIterator = pResult.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tHeader) {
        If tIndex > 0 Set tOut = tOut _ $Select(tIndex = 1: "", 1: "|") _ tHeader
    }
    Set tRows = pResult.rows.%GetIterator()
    While tRows.%GetNext(.tRowIndex, .tRow) {
        Set tOut = tOut _ ";R=" _ tRow.%Get(0) _ ":"
        For tCell = 1:1:tRow.%Size() - 1 {
            Set tOut = tOut _ $Select(tCell = 1: "", 1: ",") _ tRow.%Get(tCell)
        }
    }
    Quit tOut
}

/// <p>The keys of <var>pObject</var>, comma-joined in the order they were set.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>How many background runs of this account the store holds.</p>
ClassMethod Runs() As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", $Username)
    Quit $Select(tResult.%Next(): +tResult.%GetData(1), 1: -1)
}

/// <p>AC1: a SELECT answers the vendor's labels and values, label for label and value for value, for a members set on rows, a crossjoin and a
/// statement with no rows axis; its first column is the label column; its fields are the contract's, in order and typed; and it conforms to the
/// tool's result schema.</p>
/// <p>Mutation (Rule 19): drop the label column from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.Projected</method> -- the first column and
/// each row's label go missing and this goes red.</p>
Method TestACellsReadIsTheVendorsLabelsAndValues()
{
    Set tEnd = ..Ends(..#TOOL, ..#VISITS, .tResult)
    Do $$$AssertEquals(tEnd, "200 cells", "the Visits members set runs")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(..FlattenCells(tResult), $ClassMethod(..#VENDOR, "VendorCells", ..#VISITS), "and is the vendor's: " _ ..FlattenCells(tResult))
    Do $$$AssertEquals(tResult.columns.%Get(0) _ "|" _ tResult.columns.%Get(1), "|Amount", "its first column is the label column, empty")
    Do $$$AssertEquals(..Keys(tResult), "namespace,outcome,cube,columns,rows,rowsAvailable,columnsAvailable,truncated", "its fields, in order")
    Do $$$AssertEquals(tResult.namespace _ " " _ $ZConvert(tResult.cube, "U") _ " " _ tResult.rowsAvailable _ " " _ tResult.columnsAvailable _ " " _ tResult.truncated _ " " _ tResult.rows.%Size(), "USER OCUPILOTPROBEVISITS 5 1 0 5", "the namespace, cube, counts and the uncut flag")
    Do $$$AssertEquals(tResult.rows.%Get(0).%GetTypeOf(0) _ " " _ tResult.rows.%Get(0).%GetTypeOf(1), "string string", "every row member is text")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.AnalyticsMdxRead).ResultSchema(), tResult, .tProblem), "the answer conforms to the tool's result schema: " _ $Get(tProblem))
    Do $$$AssertEquals(..Ends(..#TOOL, ..#CROSSJOIN, .tCross), "200 cells", "a crossjoin runs")
    Do $$$AssertEquals(..FlattenCells(tCross), "C=Amount;R=1 / 0:4;R=2 / 0:8", "and its labels read outer to inner")
    Set tNoRows = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"
    Do $$$AssertEquals(..Ends(..#TOOL, tNoRows, .tOne), "200 cells", "a statement with no rows axis runs")
    Do $$$AssertEquals(..FlattenCells(tOne), "C=Amount;R=:2475000", "and answers one row labeled with the empty text")
    Do $$$AssertEquals(..FlattenCells(tOne), $ClassMethod(..#VENDOR, "VendorCells", tNoRows), "which is the vendor's")
}

/// <p>AC1: a statement over a plug-in's cells (<code>%KPI("%DeepSee.Median", ...)</code>) reads the computed values, not the vendor's
/// <code>@Computing 0.00%</code> placeholder, because the run waits for the vendor to finish computing them.</p>
/// <p>Mutation (Rule 19): drop the pending branch from <method>OcuPilot.Port.AnalyticsPort.MdxStatus</method> -- the cells read the placeholder and this
/// goes red.</p>
Method TestAPlugInsCellsAreReadComputed()
{
    Set tMedian = "SELECT %KPI(""%DeepSee.Median"",""MEDIAN"",1,""%measure"",""Amount"",""%CONTEXT"") ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]"
    Do $$$AssertEquals(..Ends(..#TOOL, tMedian, .tResult), "200 cells", "the statement runs")
    If '$IsObject(tResult) Quit
    Do $$$AssertTrue(..FlattenCells(tResult) '[ "@Computing", "no cell reads the placeholder: " _ ..FlattenCells(tResult))
    Do $$$AssertEquals(..FlattenCells(tResult), $ClassMethod(..#VENDOR, "VendorCells", tMedian), "and the answer is the vendor's own computed one")
}

/// <p>AC2: a typed DRILLTHROUGH answers its listing as columns and rows of text, at most 1,000, and says when the source holds more: the grid's
/// 50,000 rows are cut at 1,000 and flagged, the Visits cube's exactly 1,000 are not, and a MAXROWS below the cap is the statement's own.</p>
/// <p>Mutation (Rule 19): drop the row the start reads past the cap from <method>OcuPilot.Port.AnalyticsPort.MdxStart</method> -- the grid
/// listing reads exactly the cap and is not flagged, and this goes red.</p>
Method TestATypedDrillThroughAnswersItsListingWithinTheCap()
{
    Do $$$AssertEquals(..Ends(..#TOOL, "DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid]", .tGrid), "200 rows", "the grid's listing is read")
    Do $$$AssertEquals(tGrid.rows.%Size() _ " " _ tGrid.truncated _ " " _ tGrid.columns.%Get(0) _ tGrid.columns.%Get(1) _ tGrid.columns.%Get(2), "1000 1 SubSub2Amount", "cut at 1,000 rows, flagged, with the listing's own column names")
    Do $$$AssertEquals(..Keys(tGrid), "namespace,outcome,columns,rows,truncated,redactedColumns", "its fields, in order")
    Do $$$AssertEquals(tGrid.rows.%Get(0).%GetTypeOf(0), "string", "its cells are text")
    Do $$$AssertEquals(..Ends(..#TOOL, "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]", .tVisits), "200 rows", "the Visits listing is read")
    Do $$$AssertEquals(tVisits.rows.%Size() _ " " _ tVisits.truncated, "1000 0", "its exactly 1,000 rows are not flagged")
    Do $$$AssertEquals(..Ends(..#TOOL, "DRILLTHROUGH MAXROWS 5 SELECT FROM [OcuPilotProbeGrid]", .tFive), "200 rows", "a MAXROWS is read")
    Do $$$AssertEquals(tFive.rows.%Size(), 5, "and kept")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.AnalyticsMdxRead).ResultSchema(), tFive, .tProblem), "the listing conforms to the tool's result schema: " _ $Get(tProblem))
}

/// <p>AC2: a cell named by <code>drill</code> answers the vendor's listing for that cell; a position past the answer's axes, and a drill of a
/// DRILLTHROUGH statement, are refused 400 <code>ANALYTICS.MDX.INPUT</code>.</p>
/// <p>Mutation (Rule 19): ignore <code>drill</code> in <method>OcuPilot.Port.AnalyticsPort.MdxRun</method> (pass an empty row) -- the cell's
/// cells come back instead of its listing and this goes red.</p>
Method TestACellDrillIsTheVendorsListingForThatCell()
{
    Set tSC = ..Read(..#TOOL, {"statement": (..#CROSSJOIN), "drill": {"row": 2, "column": 1}}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "200 rows", "the drill answers a listing")
    If '$IsObject(tResult) Quit
    Set tExpected = $ClassMethod(..#VENDOR, "VendorDrill", ..#CROSSJOIN, 2, 1, .tText)
    Do $$$AssertEquals($ClassMethod(..#VENDOR, "FlattenRows", tResult), tExpected, "the listing for cell (2, 1) is the vendor's for: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#VENDOR, "FlattenRows", tResult), "2,0,2;2,0,2;2,0,2;2,0,2", "the four facts of Sub 2 and Sub2 0")
    For tCase = $ListBuild(3, 1), $ListBuild(1, 2) {
        Set tSC = ..Read(..#TOOL, {"statement": (..#CROSSJOIN), "drill": {"row": ($List(tCase, 1)), "column": ($List(tCase, 2))}}, .tPast, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tSC, .tPast, tHttp, .tFault), "400 ANALYTICS.MDX.INPUT", "cell (" _ $List(tCase, 1) _ ", " _ $List(tCase, 2) _ ") is past the answer's axes")
    }
    Set tSC = ..Read(..#TOOL, {"statement": "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]", "drill": {"row": 1, "column": 1}}, .tTyped, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tTyped, tHttp, .tFault), "400 ANALYTICS.MDX.INPUT", "a drill of a DRILLTHROUGH, whose answer has no cells, is refused")
}

/// <p>AC2, AD-36: a listing column whose name the credential pattern matches reads <code>[redacted]</code> in every cell and is named in
/// <code>redactedColumns</code>, and a credential value in a text cell of another column is masked; the other cells are as they were.</p>
/// <p>Mutation (Rule 19): drop the <code>RedactedColumns</code> call from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.Projected</method> -- the
/// password cells read their values and this goes red.</p>
Method TestAListingColumnNamedLikeACredentialIsRedacted()
{
    Set tAnswer = {"outcome": "rows", "truncated": false}
    Do tAnswer.%Set("columns", ["Name", "Password", "Note"])
    Do tAnswer.%Set("rows", [["a", "s3cr3t-one", "CREATE USER x IDENTIFY BY 'hunter22'"], ["b", "s3cr3t-two", "plain"]])
    Set tResult = $ClassMethod(..#TOOL, "Projected", "USER", tAnswer)
    Do $$$AssertEquals(tResult.redactedColumns.%ToJSON(), "[""Password""]", "the credential-named column is listed")
    Do $$$AssertEquals(tResult.rows.%Get(0).%Get(1) _ " " _ tResult.rows.%Get(1).%Get(1), "[redacted] [redacted]", "its cells read [redacted]")
    Do $$$AssertEquals(tResult.rows.%Get(0).%Get(0) _ " " _ tResult.rows.%Get(1).%Get(2), "a plain", "the other columns are as they were")
    Do $$$AssertTrue(tResult.%ToJSON() '[ "s3cr3t", "no value of the column is anywhere in the answer")
    Do $$$AssertTrue(tResult.rows.%Get(0).%Get(2) '[ "hunter22", "and a credential value in a text cell is masked: " _ tResult.rows.%Get(0).%Get(2))
}

/// <p>AC5: CREATE, DROP and a statement of three axes are refused by their codes, 422, and no background run is reserved for them or for a
/// run that succeeds.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> accept CREATE -- the first leg goes red.</p>
Method TestCreateDropAndThreeAxesAreRefusedAndNoRunIsReserved()
{
    Set tBefore = ..Runs()
    For tCase = $ListBuild("CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'", "422 ANALYTICS.MDX.KIND"), $ListBuild("DROP MEMBER [OcuPilotProbeVisits].[Measures].[X]", "422 ANALYTICS.MDX.KIND"), $ListBuild("SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1, [Seen].[H1].[Year].Members ON 2 FROM [OcuPilotProbeVisits]", "422 ANALYTICS.MDX.AXES") {
        Do $$$AssertEquals(..Ends(..#TOOL, $List(tCase, 1), .tResult), $List(tCase, 2), $Extract($List(tCase, 1), 1, 40))
    }
    Do $$$AssertEquals(..Ends(..#TOOL, ..#VISITS, .tOk), "200 cells", "a SELECT runs")
    Do $$$AssertEquals(..Runs(), tBefore, "and no background run of this account was reserved by any of them")
}

/// <p>AC1: a statement the vendor will not prepare is an <code>error</code> outcome carrying the vendor's text, at most 1,000 characters, and no
/// rows.</p>
/// <p>Mutation (Rule 19): ignore the error answer <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> returns in
/// <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the read runs a result set that was never prepared, answers a fault and this goes red.</p>
Method TestASyntaxErrorAnswersTheVendorsText()
{
    Do $$$AssertEquals(..Ends(..#TOOL, "SELEKT FROM [OcuPilotProbeVisits]", .tResult), "200 error", "a syntax error is an outcome, not a fault")
    If '$IsObject(tResult) Quit
    Do $$$AssertTrue((tResult.message [ "Unknown term at start of query: SELEKT") && ($Length(tResult.message) <= 1000), "with the vendor's text: " _ tResult.message)
    Do $$$AssertEquals(tResult.%GetTypeOf("rows"), "unassigned", "and no rows")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.AnalyticsMdxRead).ResultSchema(), tResult, .tProblem), "the error answer conforms to the tool's result schema: " _ $Get(tProblem))
}

/// <p>AC1: a vendor message longer than the port's cell bound is cut to exactly that bound and ends in an ellipsis: a first word of 1,500 characters is echoed
/// in the vendor's "Unknown term" text, which runs past 3,000 characters uncut.</p>
/// <p>Mutation (Rule 19): drop the cut from <method>OcuPilot.Port.AnalyticsPort.ErrorAnswer</method> (answer the vendor's whole text) -- the message runs past the
/// bound and this goes red.</p>
Method TestAVendorErrorLongerThanTheCellBoundIsCut()
{
    Set tMax = $Parameter(..#PORT, "MDXMAXCELL")
    Set tWord = $Translate($Justify("", tMax + 500), " ", "A")
    Do $$$AssertEquals(..Ends(..#TOOL, tWord _ " FROM [OcuPilotProbeVisits]", .tResult), "200 error", "a first word the vendor cannot read is an outcome, not a fault")
    If '$IsObject(tResult) Quit
    Do $$$AssertTrue($Extract(tResult.message, 1, 80) [ "Unknown term at start of query: AAAA", "the message is the vendor's: " _ $Extract(tResult.message, 1, 80))
    Do $$$AssertEquals($Length(tResult.message) _ " " _ ($Extract(tResult.message, *) = $Char(8230)), tMax _ " 1", "cut to the port's cell bound, ending in an ellipsis")
}

/// <p>AC6: a namespace that reports no analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>, and one whose analytics cache lives in a read-only
/// database 409 <code>ANALYTICS.MDX.READONLY</code>, each before any vendor call: the port was asked to prepare nothing.</p>
/// <p>Mutation (Rule 19): drop the read-only test from <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method> -- the HSLIB leg goes red.</p>
Method TestANamespaceWithoutAnalyticsOrWithAReadOnlyCacheIsRefusedBeforeAnyVendorCall()
{
    For tCase = $ListBuild("HSCUSTOM", "409 ANALYTICS.NAMESPACE"), $ListBuild("HSLIB", "409 ANALYTICS.MDX.READONLY") {
        Do $$$AssertEquals(..Ends(..#FIXTURE, ..#VISITS, .tResult, $List(tCase, 1)), $List(tCase, 2), $List(tCase, 1))
        Do $$$AssertEquals($ClassMethod(..#RECORDER, "Count"), 0, $List(tCase, 1) _ ": nothing was prepared")
    }
}

/// <p>The splice cases, each <code>[node, label, text]</code>: node 0 for a spelling whose text defines none. A <code>%SEARCH</code> spelling's
/// braces increment its own node, 351 to 356, and the <code>%PARM</code> value names 357.</p>
ClassMethod SplicedCases() As %DynamicArray
{
    Set tBase = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE "
    Set tBraces = ".&[ID > {$Increment(^OcuPilotProbeMdxSplice("
    Set tLF = $Char(10)
    Set tCases = []
    Do ..AddCase(tCases, 351, "mixed case %SEARCH", tBase _ "%SeArCh" _ tBraces _ "351))}]")
    Do ..AddCase(tCases, 352, "%SE/**/ARCH", tBase _ "%SE/**/ARCH" _ tBraces _ "352))}]")
    Do ..AddCase(tCases, 353, "%SEARCH split by a -- comment", tBase _ "%SE--" _ tLF _ "ARCH" _ tBraces _ "353))}]")
    Do ..AddCase(tCases, 354, "%SEARCH split by a // comment", tBase _ "%SE//" _ tLF _ "ARCH" _ tBraces _ "354))}]")
    Do ..AddCase(tCases, 355, "%SE/**/ARCH in a %MDX literal", tBase _ "%MDX(""SELECT %SE/**/ARCH" _ tBraces _ "355))}]"")")
    Do ..AddCase(tCases, 356, "%SE/**/ARCH in a WITH MEMBER span", "WITH MEMBER [Measures].[X] AS '%SE/**/ARCH" _ tBraces _ "356))}]' SELECT FROM [OcuPilotProbeVisits]")
    Do ..AddCase(tCases, 357, "%PARM value", "WITH %PARM P AS 'VALUE:{$Increment(^OcuPilotProbeMdxSplice(357))}' SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE @P")
    Do ..AddCase(tCases, 0, "mixed case %sqlRestrict", tBase _ "%sqlRestrict.&[1]")
    Do ..AddCase(tCases, 0, "%SQL/**/RESTRICT", tBase _ "%SQL/**/RESTRICT.&[1]")
    Do ..AddCase(tCases, 0, "mixed case ReTuRn", "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits] ReTuRn Amount")
    Do ..AddCase(tCases, 0, "RET/**/URN", "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits] RET/**/URN Amount")
    Do ..AddCase(tCases, 0, "mixed case %oRdEr BY", "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits] %oRdEr BY Amount")
    Do ..AddCase(tCases, 0, "%ORD/**/ER BY", "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits] %ORD/**/ER BY Amount")
    Do ..AddCase(tCases, 0, "mixed case %pArM", "WITH %pArM P AS 'VALUE:1' SELECT FROM [OcuPilotProbeVisits] WHERE @P")
    Do ..AddCase(tCases, 0, "%PA/**/RM", "WITH %PA/**/RM P AS 'VALUE:1' SELECT FROM [OcuPilotProbeVisits] WHERE @P")
    Quit tCases
}

/// <p>Append <code>[pNode, pLabel, pText]</code> to <var>pCases</var>.</p>
ClassMethod AddCase(pCases As %DynamicArray, pNode As %Integer, pLabel As %String, pText As %String)
{
    Set tCase = []
    Do tCase.%Push(pNode, "number")
    Do tCase.%Push(pLabel, "string")
    Do tCase.%Push(pText, "string")
    Do pCases.%Push(tCase)
}

/// <p>AC3: every spelling of the five constructs is refused 422 <code>ANALYTICS.MDX.SQL</code> before the statement is prepared: the port was
/// handed nothing, and each splice node its braces would define stays undefined.</p>
/// <p>Mutation (Rule 19): skip the <code>MdxConstructs</code> call in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the prepare
/// is recorded for each spelling and this goes red.</p>
Method TestEverySpellingOfAConstructIsRefusedBeforeAnythingIsPrepared()
{
    Set tCases = ..SplicedCases()
    For tI = 0:1:tCases.%Size() - 1 {
        Set tCase = tCases.%Get(tI)
        Set tNode = tCase.%Get(0)
        If tNode Kill ^|"USER"|OcuPilotProbeMdxSplice(tNode)
        Set tEnd = ..Ends(..#FIXTURE, tCase.%Get(2), .tResult)
        Do $$$AssertEquals(tEnd _ " " _ $ClassMethod(..#RECORDER, "Count"), "422 ANALYTICS.MDX.SQL 0", tCase.%Get(1) _ ": refused, and nothing was prepared")
        If tNode Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, tCase.%Get(1) _ ": node " _ tNode _ " is undefined")
    }
}

/// <p>AC3: a text the lexer refuses, and a blank one, are refused 422 <code>ANALYTICS.MDX.SQL</code> before a prepare: the detector fails closed.</p>
/// <p>Mutation (Rule 19): refuse on the names found only, not on a text the detector cannot read, in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method>
/// -- the unreadable and the blank statements are prepared and answer <code>error</code> outcomes, and this goes red.</p>
Method TestAnUnreadableOrBlankTextIsRefusedBeforeAnythingIsPrepared()
{
    Do $$$AssertEquals(..Ends(..#FIXTURE, "SELECT FROM [OcuPilotProbeVisits", .tResult) _ " " _ $ClassMethod(..#RECORDER, "Count"), "422 ANALYTICS.MDX.SQL 0", "an unterminated bracket is refused, and nothing was prepared")
    Do $$$AssertEquals(..Ends(..#FIXTURE, "SELECT FROM [OcuPilotProbeVisits] WHERE ""abc", .tResult) _ " " _ $ClassMethod(..#RECORDER, "Count"), "422 ANALYTICS.MDX.SQL 0", "so is an unterminated quote")
    Do $$$AssertEquals(..Ends(..#FIXTURE, "   " _ $Char(10), .tResult) _ " " _ $ClassMethod(..#RECORDER, "Count"), "422 ANALYTICS.MDX.SQL 0", "and so is a blank statement, and nothing was prepared")
}

/// <p>AC3: a statement that names no construct, whose pivot variable resolves to a <code>%SEARCH</code> expression, is prepared once, which executes
/// nothing, and is refused 422 <code>ANALYTICS.MDX.SQL</code> on its resolved text; the node its braces would define stays undefined.</p>
/// <p>Mutation (Rule 19): ignore <code>MdxPrepare</code>'s <code>ask</code> in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the
/// statement runs, node 358 is defined and no refusal is answered, and this goes red.</p>
Method TestAResolvedTextWithAConstructIsPreparedAndNeverRun()
{
    Set tNode = $Parameter(..#FIXTURE, "SPLICENODE")
    Kill ^|"USER"|OcuPilotProbeMdxSplice(tNode)
    Set tStatement = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE $variable.v"
    Do $$$AssertEquals($ClassMethod(..#PORT, "MdxConstructs", tStatement), 0, "the statement itself names no construct")
    Do $$$AssertEquals(..Ends(..#FIXTURE, tStatement, .tResult) _ " " _ $ClassMethod(..#RECORDER, "Count"), "422 ANALYTICS.MDX.SQL 1", "it is refused after one prepare")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "and node " _ tNode _ " is undefined")
    Do $ClassMethod(..#RECORDER, "Reset")
    Set tProductionEnd = ..Ends(..#TOOL, tStatement, .tProduction)
    Do $$$AssertTrue(tProductionEnd '[ "ANALYTICS.MDX.SQL", "the production tool hands the prepare no variable, so it is not refused as code: " _ tProductionEnd)
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "and the node is still undefined")
}

/// <p>AC3: a bracketed name that only looks like a construct is not one: <code>[%SE/**/ARCH]</code> keeps its comment inside its bracket, so the
/// detector finds none and the statement is prepared; a plain SELECT is prepared and runs.</p>
/// <p>Mutation (Rule 19): refuse any statement that holds <code>[%SE/**/ARCH]</code> as text, beside the detector, in
/// <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the statement is refused as code and this goes red.</p>
Method TestANameThatOnlyLooksLikeAConstructProceedsToPrepare()
{
    Set tNamed = "SELECT {[Measures].[Amount]} ON 0, {[%SE/**/ARCH]} ON 1 FROM [OcuPilotProbeVisits]"
    Do $$$AssertEquals($ClassMethod(..#PORT, "MdxConstructs", tNamed), 0, "the detector finds nothing in a bracketed name")
    Set tEnd = ..Ends(..#FIXTURE, tNamed, .tResult)
    Do $$$AssertTrue(tEnd '[ "ANALYTICS.MDX.SQL", "it is not refused as code: " _ tEnd)
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Count"), 1, "it is prepared")
    Do $ClassMethod(..#RECORDER, "Reset")
    Do $$$AssertEquals(..Ends(..#FIXTURE, ..#VISITS, .tPlain) _ " " _ $ClassMethod(..#RECORDER, "Count"), "200 cells 1", "a plain SELECT is prepared once and runs")
}

/// <p>AC7: the arguments are validated before anything else: a missing statement, an over-long one, a drill that lacks a position, names one
/// below 1 or above the port's cap, gives one that is not a whole number or not a number, and a stray key are 400 <code>TOOL.ARGUMENTS</code>;
/// nothing is prepared.</p>
/// <p>Mutation (Rule 19): skip the schema check in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the missing, over-long and stray-key
/// cases go red; skip <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.DrillProblem</method> -- the drill cases go red.</p>
Method TestTheArgumentsAreValidatedFirst()
{
    Set tCases = [{}, {"statement": ($Justify("", 100001))}, {"statement": "SELECT 1", "drill": {"row": 1}}, {"statement": "SELECT 1", "drill": {"row": 0, "column": 1}}, {"statement": "SELECT 1", "drill": {"row": 1, "column": 1, "extra": 1}}, {"statement": "SELECT 1", "drill": {"row": 1.5, "column": 1}}, {"statement": "SELECT 1", "drill": {"row": "1", "column": 1}}, {"statement": "SELECT 1", "drill": {"row": ($Parameter(..#PORT, "MDXMAXROWS") + 1), "column": 1}}, {"statement": "SELECT 1", "drill": {"row": 1, "column": ($Parameter(..#PORT, "MDXMAXCOLUMNS") + 1)}}, {"statement": "SELECT 1", "maxRows": 5}]
    For tI = 0:1:tCases.%Size() - 1 {
        Set tArgs = tCases.%Get(tI)
        Set tSC = ..Read(..#FIXTURE, tArgs, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tSC, .tResult, tHttp, .tFault), "400 TOOL.ARGUMENTS", $Extract(tArgs.%ToJSON(), 1, 60))
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Count"), 0, "and nothing was prepared")
}

/// <p>AC7: the tool is registered as a read tool bound to MDX query, MDX query's context lists it by its wire name, and a refusal's card sentence
/// is the published one.</p>
/// <p>Mutation (Rule 19): drop the <code>ANALYTICS.</code> branch from <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- the sentence leg goes
/// red.</p>
Method TestTheToolIsListedOnItsScreenAndItsRefusalHasASentence()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("analytics.mdxquery.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the tool")
    If $$$ISOK(tSC) && $IsObject($Get(tTool)) Do $$$AssertEquals(tTool.kind _ " " _ tTool.class, "read " _ ..#TOOL, "as a read tool with a class of its own")
    Set tDescriptor = "OcuPilot.Screen.Descriptor.AnalyticsMdxQuery"
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tDescriptor, .tTools), "MDX query's tools are listed")
    Set tListed = 0
    For tI = 0:1:tTools.%Size() - 1 {
        If tTools.%Get(tI) = "analytics_mdxquery_read" Set tListed = 1
    }
    Do $$$AssertTrue(tListed, "and they include analytics_mdxquery_read: " _ tTools.%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode("ANALYTICS.MDX.SQL"), ##class(OcuPilot.Api.AnalyticsError).#REASONMDXSQL, "the card's sentence for the refusal is the published one")
    Do $$$AssertNotEquals(##class(OcuPilot.Api.AnalyticsError).#REASONMDXSQL, "", "and it is not empty")
}

}
