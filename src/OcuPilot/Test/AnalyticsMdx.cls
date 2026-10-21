/// <p>Pins <class>OcuPilot.Port.AnalyticsPort</class>'s MDX calls (AD-65, Story 20.33) against the probe cubes in <code>USER</code>: the
/// cells answer equals the vendor's own labels and values, outer to inner, and every answer carries the contract's fields in its order; a
/// cell's drill-through equals the vendor's listing for the composed statement, and a position past its axis, a position of an axis the
/// vendor answered empty and a drill of a DRILLTHROUGH are refused; an empty axis lists no positions; a run writes none of
/// the user data, term lists, folders or folder items; a typed DRILLTHROUGH reads its listing to the cap and says when more
/// exist; the row, column, cell and total caps cut and say so; <method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method> finds each of
/// the five constructs in the vendor's tokens and in a string literal's, through each comment obfuscation measured, and fails closed;
/// <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> checks the variable-resolved text too and executes nothing; CREATE, DROP and
/// three axes are refused and a syntax error answers the vendor's text; and the gate names a namespace without analytics and one whose
/// cache database is read-only.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// <class>OcuPilot.Test.AnalyticsProbe</class> turns analytics on for <code>USER</code> and writes cubes there. The probe is removed after
/// the last test, with the splice nodes, and <method>OcuPilot.Test.AnalyticsProbe.Gone</method> is asserted.</p>
Class OcuPilot.Test.AnalyticsMdx Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter NAMESPACE = "USER";

/// <p>The grid cube's two-by-two crossjoin: rows <code>1 / 0</code> and <code>2 / 0</code> hold 4 and 8.</p>
Parameter CROSSJOIN = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdx turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdx left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Run <var>pMDX</var> through the port as this account, in <code>USER</code>: prepare, start, poll, answer; then, for a drill of
/// <var>pRow</var> and <var>pColumn</var>, the cell's listing. <var>pAnswer</var> is the statement's answer and
/// <var>pDrillAnswer</var> the listing's.</p>
Method RunMdx(pMDX As %String, Output pAnswer, pRow As %Integer = "", pColumn As %Integer = "", Output pDrillAnswer)
{
    Set pAnswer = ""
    Set pDrillAnswer = ""
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, pMDX, .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound)
    Do $$$AssertStatusOK(tSC, "the statement prepares")
    If $$$ISERR(tSC) Quit
    If $IsObject(tAnswer) {
        Set pAnswer = tAnswer
        Quit
    }
    Set tPending = $ClassMethod(..#PORT, "MdxStart", ..#NAMESPACE, tRS, .tCube, .tKey)
    Set pAnswer = ..Finished(tRS, tPending)
    If '$IsObject(pAnswer) || (pRow = "") {
        Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
        Quit
    }
    Set tSC = $ClassMethod(..#PORT, "MdxDrill", ..#NAMESPACE, tRS, pRow, pColumn, .tDrill, .tHttp, .tFault, .tDrillError)
    If $$$ISERR(tSC) {
        Set pDrillAnswer = $Get(tFault)
        Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
        Quit
    }
    Set tPending = $ClassMethod(..#PORT, "MdxStart", ..#NAMESPACE, tDrill, .tCube, .tKey)
    Set pDrillAnswer = ..Finished(tDrill, tPending)
    Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tDrill)
    Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
}

/// <p>The answer of the started result set <var>pRS</var> once the vendor reports it done, or an error answer.</p>
Method Finished(pRS, pStartStatus As %Status) As %DynamicObject
{
    If $$$ISERR(pStartStatus) Quit ##class(OcuPilot.Port.AnalyticsPort).ErrorAnswer(pStartStatus)
    Set tDeadline = $ZHorolog + 60
    For {
        Set tStatus = $ClassMethod(..#PORT, "MdxStatus", ..#NAMESPACE, pRS, .tError)
        If (tStatus = 100) || ($ZHorolog > tDeadline) Quit
        Hang 0.1
    }
    If $$$ISERR(tError) Quit ##class(OcuPilot.Port.AnalyticsPort).ErrorAnswer(tError)
    Set tSC = $ClassMethod(..#PORT, "MdxAnswer", ..#NAMESPACE, pRS, 1, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the answer is read")
    Quit tAnswer
}

/// <p>A cells answer as <code>C=&lt;headers&gt;;R=&lt;label&gt;:&lt;cells&gt;;...</code>, headers and cells joined with <code>|</code> and
/// <code>,</code>.</p>
ClassMethod Flatten(pAnswer As %DynamicObject) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%Get("outcome") '= "cells") Quit "not cells"
    Set tOut = "C="
    Set tIterator = pAnswer.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tHeader) {
        Set tOut = tOut _ $Select(tIndex = 0: "", 1: "|") _ tHeader
    }
    Set tRows = pAnswer.rows.%GetIterator()
    While tRows.%GetNext(.tRowIndex, .tRow) {
        Set tOut = tOut _ ";R=" _ tRow.label _ ":"
        Set tCells = tRow.cells.%GetIterator()
        While tCells.%GetNext(.tCellIndex, .tCell) {
            Set tOut = tOut _ $Select(tCellIndex = 0: "", 1: ",") _ tCell
        }
    }
    Quit tOut
}

/// <p>A listing answer's rows as <code>a,b,c;a,b,c;...</code>.</p>
ClassMethod FlattenRows(pAnswer As %DynamicObject) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%Get("outcome") '= "rows") Quit "not rows"
    Set tOut = ""
    Set tRows = pAnswer.rows.%GetIterator()
    While tRows.%GetNext(.tRowIndex, .tRow) {
        Set tLine = ""
        Set tCells = tRow.%GetIterator()
        While tCells.%GetNext(.tCellIndex, .tCell) {
            Set tLine = tLine _ $Select(tCellIndex = 0: "", 1: ",") _ tCell
        }
        Set tOut = tOut _ $Select(tRowIndex = 0: "", 1: ";") _ tLine
    }
    Quit tOut
}

/// <p>What the vendor itself answers for <var>pMDX</var>, read here with its own result set, in the shape <method>Flatten</method>
/// gives: each position's labels joined outer to inner (the vendor lists them innermost first).</p>
ClassMethod VendorCells(pMDX As %String) As %String
{
    Set tOut = "vendor failed"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tRS = ##class(%DeepSee.ResultSet).%New()
        Set tSC = tRS.%PrepareMDX(pMDX)
        If $$$ISOK(tSC) Set tSC = tRS.%Execute()
        If $$$ISOK(tSC) {
            Set tAxes = tRS.%GetAxisCount()
            Set tCols = tRS.%GetColumnCount()
            Set tRows = tRS.%GetRowCount()
            Set tOut = "C="
            For tC = 1:1:tCols {
                Set tLabel = ""
                If tAxes >= 1 {
                    Kill tL
                    Set tN = tRS.%GetOrdinalLabel(.tL, 1, tC)
                    For tI = tN:-1:1 Set tLabel = tLabel _ $Select(tLabel = "": "", 1: " / ") _ tL(tI)
                }
                Set tOut = tOut _ $Select(tC = 1: "", 1: "|") _ tLabel
            }
            For tR = 1:1:tRows {
                Set tLabel = ""
                If tAxes >= 2 {
                    Kill tL
                    Set tN = tRS.%GetOrdinalLabel(.tL, 2, tR)
                    For tI = tN:-1:1 Set tLabel = tLabel _ $Select(tLabel = "": "", 1: " / ") _ tL(tI)
                }
                Set tOut = tOut _ ";R=" _ tLabel _ ":"
                For tC = 1:1:tCols Set tOut = tOut _ $Select(tC = 1: "", 1: ",") _ tRS.%GetOrdinalValue(tC, tR)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "vendor raised " _ ex.Name
    }
    Quit tOut
}

/// <p>The text of the drill-through of cell (<var>pRow</var>, <var>pColumn</var>) of <var>pMDX</var>, composed here from the vendor's own
/// filters for that cell, and the rows the vendor answers for it, in the shape <method>FlattenRows</method> gives.</p>
ClassMethod VendorDrill(pMDX As %String, pRow As %Integer, pColumn As %Integer, Output pText As %String) As %String
{
    Set tOut = "vendor failed"
    Set pText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tRS = ##class(%DeepSee.ResultSet).%New()
        Set tSC = tRS.%PrepareMDX(pMDX)
        If $$$ISOK(tSC) Set tSC = tRS.%Execute()
        If $$$ISOK(tSC) Set tSC = tRS.%GetFiltersForCellRange(.tFilters, pRow, pColumn, pRow, pColumn, .tMeasure)
        If $$$ISOK(tSC) {
            Set pText = "DRILLTHROUGH MAXROWS 1000 SELECT FROM [" _ tRS.%GetCubeName() _ "]"
            For tSlot = 0, 1, 2 {
                If $Get(tFilters(tSlot)) '= "" Set pText = pText _ " %FILTER " _ tFilters(tSlot)
            }
            Set tDrill = ##class(%DeepSee.ResultSet).%New()
            Set tSC = tDrill.%PrepareMDX(pText)
            If $$$ISOK(tSC) Set tSC = tDrill.%Execute()
        }
        If $$$ISOK(tSC) {
            Set tSC = tDrill.%GetListingResultSet(.tSet)
            Set tOut = ""
            Set tN = 0
            While $$$ISOK(tSC) && tSet.%Next() {
                Set tN = tN + 1
                Set tOut = tOut _ $Select(tN = 1: "", 1: ";") _ tSet.%GetData(1) _ "," _ tSet.%GetData(2) _ "," _ tSet.%GetData(3)
            }
        }
        Set (tSet, tDrill, tRS) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "vendor raised " _ ex.Name
    }
    Quit tOut
}

/// <p>AC1: the cells answer is the vendor's, label for label and value for value, for a members set on rows and for a statement with no
/// rows axis, and a crossjoin's labels read outer to inner.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.MdxAnswer</method> join a position's labels innermost first -- the
/// crossjoin leg goes red.</p>
Method TestTheCellsAnswerEqualsTheVendorsLabelsAndValues()
{
    Set tVisits = "SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]"
    Do ..RunMdx(tVisits, .tAnswer)
    Do $$$AssertEquals(..Flatten(tAnswer), ..VendorCells(tVisits), "the Visits members set is the vendor's: " _ ..Flatten(tAnswer))
    Do $$$AssertEquals(tAnswer.rowsAvailable _ " " _ tAnswer.columnsAvailable _ " " _ tAnswer.truncated _ " " _ tAnswer.rows.%Size(), "5 1 0 5", "five rows of one column, none cut")
    Do ..RunMdx(..#CROSSJOIN, .tAnswer)
    Do $$$AssertEquals(..Flatten(tAnswer), "C=Amount;R=1 / 0:4;R=2 / 0:8", "a crossjoin's labels read outer to inner, as the grid's own facts give them")
    Do $$$AssertEquals(..Flatten(tAnswer), ..VendorCells(..#CROSSJOIN), "which is the vendor's, reversed from its innermost-first list")
    Set tNoRows = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"
    Do ..RunMdx(tNoRows, .tAnswer)
    Do $$$AssertEquals(..Flatten(tAnswer), "C=Amount;R=:2475000", "no rows axis answers one row with an empty label")
    Do $$$AssertEquals(..Flatten(tAnswer), ..VendorCells(tNoRows), "and is the vendor's")
}

/// <p>AC2: a cell's drill-through is the vendor's listing for the composed statement, and a position past its axis is refused 400
/// <code>ANALYTICS.MDX.INPUT</code>.</p>
/// <p>Mutation (Rule 19): compose the drill without the slicer's filter, <code>f(0)</code> -- the sliced statement's listing holds the rows of Sub 1
/// across every Sub2 and this goes red.</p>
Method TestACellsDrillThroughIsTheVendorsListingForThatCell()
{
    Do ..RunMdx(..#CROSSJOIN, .tAnswer, 2, 1, .tDrill)
    Set tExpected = ..VendorDrill(..#CROSSJOIN, 2, 1, .tText)
    Do $$$AssertEquals(..FlattenRows(tDrill), tExpected, "the listing for cell (2, 1) is the vendor's for: " _ tText)
    Do $$$AssertEquals(..FlattenRows(tDrill), "2,0,2;2,0,2;2,0,2;2,0,2", "the four facts of Sub 2 and Sub2 0")
    Do $$$AssertEquals(tDrill.columns.%Get(0) _ tDrill.columns.%Get(1) _ tDrill.columns.%Get(2), "SubSub2Amount", "with the listing's own column names")
    Set tSliced = "SELECT {[Measures].[Amount]} ON 0, {[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]} ON 1 FROM [OcuPilotProbeGrid] WHERE [Sub2].[H1].[Sub2].&[0]"
    Do ..RunMdx(tSliced, .tAnswer, 1, 1, .tSlicedDrill)
    Set tSlicedExpected = ..VendorDrill(tSliced, 1, 1, .tSlicedText)
    Do $$$AssertTrue(tSlicedText [ "%FILTER [SUB2].[H1].[SUB2].&[0]", "the vendor's filters for a statement with a slicer name the slicer: " _ tSlicedText)
    Do $$$AssertEquals(..FlattenRows(tSlicedDrill), tSlicedExpected, "the listing for a cell of a sliced statement is the vendor's for: " _ tSlicedText)
    Do $$$AssertEquals(..FlattenRows(tSlicedDrill), "1,0,1;1,0,1;1,0,1;1,0,1", "the four facts of Sub 1 within the slicer's Sub2 0, not the twenty-five of Sub 1")
    For tCase = $ListBuild(3, 1), $ListBuild(1, 2) {
        Do ..RunMdx(..#CROSSJOIN, .tAnswer, $List(tCase, 1), $List(tCase, 2), .tFault)
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: "none"), "ANALYTICS.MDX.INPUT", "cell (" _ $List(tCase, 1) _ ", " _ $List(tCase, 2) _ ") is past the answer's axes and is refused")
    }
}

/// <p>AC2, AC4: a typed DRILLTHROUGH reads the cube's default listing to <parameter>MDXMAXLISTINGROWS</parameter> rows and says when the
/// source holds more: the grid's 50,000 rows are cut at 1,000 and flagged, and the Visits cube's exactly 1,000 are not.</p>
/// <p>Mutation (Rule 19): drop the row the start reads past the cap from <method>OcuPilot.Port.AnalyticsPort.MdxStart</method> -- the grid
/// listing reads exactly the cap and is not flagged, and this goes red.</p>
Method TestATypedDrillThroughReadsToTheCapAndSaysWhenMoreExist()
{
    Do ..RunMdx("DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid]", .tAnswer)
    Do $$$AssertEquals(tAnswer.outcome _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.truncated, "rows 1000 1", "the grid's listing is cut at 1,000 rows and says so")
    Do ..RunMdx("DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]", .tAnswer)
    Do $$$AssertEquals(tAnswer.outcome _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.truncated, "rows 1000 0", "the Visits listing holds exactly 1,000 rows and says nothing was cut")
    Do ..RunMdx("DRILLTHROUGH MAXROWS 5 SELECT FROM [OcuPilotProbeGrid]", .tAnswer)
    Do $$$AssertEquals(tAnswer.outcome _ " " _ tAnswer.rows.%Size(), "rows 5", "a MAXROWS below the cap is the person's own and is kept")
}

/// <p>AC4: the row, column, cell and total caps each cut the answer and say so. The total leg stays under the row and cell caps, so its
/// cut is the total cap's alone, and the answer's JSON text is at most <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXANSWER</parameter>
/// characters, filled to within a row.</p>
/// <p>Mutation (Rule 19): do not apply <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXROWS</parameter> in
/// <method>OcuPilot.Port.AnalyticsPort.MdxAnswer</method> -- the row leg goes red; drop the total cap's <code>truncated</code> -- the total
/// leg goes red.</p>
Method TestTheRowColumnCellAndTotalCapsCutAndSaySo()
{
    Do ..RunMdx("SELECT {[Measures].[Amount]} ON 0, [Sub].[H1].[Sub].Members ON 1 FROM [OcuPilotProbeGrid]", .tAnswer)
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " of " _ tAnswer.rowsAvailable _ " " _ tAnswer.truncated, "1000 of 2000 1", "2,000 row positions answer 1,000 rows and say so")
    Do ..RunMdx("SELECT [Sub].[H1].[Sub].Members ON 0 FROM [OcuPilotProbeGrid]", .tAnswer)
    Do $$$AssertEquals(tAnswer.columns.%Size() _ " of " _ tAnswer.columnsAvailable _ " " _ tAnswer.truncated, "100 of 2000 1", "2,000 column positions answer 100 columns and say so")
    Set tLong = $Translate($Justify("", 1100), " ", "a")
    Set tCell = "WITH MEMBER [Measures].[Long] AS '""" _ tLong _ """' SELECT {[Measures].[Long]} ON 0, {[Sub].[H1].[Sub].&[1]} ON 1 FROM [OcuPilotProbeGrid]"
    Do ..RunMdx(tCell, .tAnswer)
    Set tValue = tAnswer.rows.%Get(0).cells.%Get(0)
    Do $$$AssertEquals($Length(tValue) _ " " _ ($Extract(tValue, *) = $Char(8230)) _ " " _ tAnswer.truncated, "1000 1 1", "a cell of 1,100 characters is cut at 1,000, ends in an ellipsis and the answer says so")
    Set tWide = "WITH MEMBER [Measures].[Long] AS '""" _ $Extract(tLong, 1, 1000) _ """' SELECT {[Measures].[Long]} ON 0, HEAD([Sub].[H1].[Sub].Members, 1000) ON 1 FROM [OcuPilotProbeGrid]"
    Do ..RunMdx(tWide, .tAnswer)
    Set tMax = ##class(OcuPilot.Port.AnalyticsPort).#MDXMAXANSWER
    Set tLength = $Length(tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.rowsAvailable _ " " _ (tAnswer.rows.%Size() < 1000) _ " " _ tAnswer.truncated, "1000 1 1", "1,000 rows of 1,000-character cells, under the row and cell caps, are cut by whole rows at the answer's cap and say so: " _ tAnswer.rows.%Size() _ " rows")
    Do $$$AssertTrue((tLength <= tMax) && (tLength > (tMax - 2000)), "and the answer's JSON text is at most 1,000,000 characters, filled to within a row: " _ tLength)
}

/// <p>AC1, AC2: an axis the vendor answers empty has no positions: a NON EMPTY rows set with nothing under the slicer answers no rows
/// beside its one column, as the vendor's axis sizes read. A drill names a cell the answer has, so position 1 of that empty answer is
/// refused, and so is any drill of a DRILLTHROUGH's result set, whose answer has no cells.</p>
/// <p>Mutation (Rule 19): count positions with the vendor's <code>%GetRowCount</code> and <code>%GetColumnCount</code>, which answer 1 for
/// an empty axis, in <method>OcuPilot.Port.AnalyticsPort.Positions</method> -- the empty answer reads one blank row and the drill runs.</p>
Method TestAnEmptyAxisHasNoPositionsAndADrillNamesACellTheAnswerHas()
{
    Set tEmpty = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY {[Sub].[H1].[Sub].&[0]} ON 1 FROM [OcuPilotProbeGrid] WHERE [Sub2].[H1].[Sub2].&[1]"
    Do ..RunMdx(tEmpty, .tAnswer, 1, 1, .tDrill)
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " of " _ tAnswer.rowsAvailable _ ", " _ tAnswer.columns.%Size() _ " of " _ tAnswer.columnsAvailable, "0 of 0, 1 of 1", "the empty rows axis lists no positions")
    Do $$$AssertEquals($Select($IsObject(tDrill): tDrill.%Get("code"), 1: "no refusal"), "ANALYTICS.MDX.INPUT", "and a drill of its position 1 is refused")
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, "DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]", .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound)
    Do $$$AssertStatusOK(tSC, "a DRILLTHROUGH prepares")
    Set tSC = $ClassMethod(..#PORT, "MdxDrill", ..#NAMESPACE, tRS, 1, 1, .tListing, .tHttp, .tFault, .tError)
    Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "no refusal"), "400 ANALYTICS.MDX.INPUT", "and a drill of its result set is refused")
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

/// <p>AC1, AC2: each answer carries the fields the contract names, in its order and of its types: a cells answer the cube, the headers and each
/// row's label and cells as text, the available counts and the seconds as numbers and the cut flag as a boolean; a listing its columns, its rows as
/// arrays of text, the cut flag and the seconds; and a statement the vendor will not prepare its text alone.</p>
/// <p>Mutation (Rule 19): leave the cube out of the cells answer in <method>OcuPilot.Port.AnalyticsPort.MdxAnswer</method> -- the first leg goes
/// red.</p>
Method TestTheAnswersCarryTheContractsFieldsInOrder()
{
    Do ..RunMdx("SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]", .tAnswer)
    Do $$$AssertEquals(..Keys(tAnswer), "outcome,cube,columns,rows,rowsAvailable,columnsAvailable,truncated,seconds", "a cells answer's fields, in order")
    Do $$$AssertEquals($ZConvert(tAnswer.cube, "U") _ " " _ tAnswer.%GetTypeOf("rowsAvailable") _ " " _ tAnswer.%GetTypeOf("columnsAvailable") _ " " _ tAnswer.%GetTypeOf("truncated") _ " " _ tAnswer.%GetTypeOf("seconds") _ " " _ tAnswer.seconds, "OCUPILOTPROBEVISITS number number boolean number 1", "its cube, its counts, its flag and its seconds, as typed")
    Set tRow = tAnswer.rows.%Get(0)
    Do $$$AssertEquals(..Keys(tRow) _ " " _ tRow.%GetTypeOf("label") _ " " _ tRow.%GetTypeOf("cells") _ " " _ tRow.cells.%GetTypeOf(0) _ " " _ tAnswer.columns.%GetTypeOf(0), "label,cells string array string string", "a row is a label and its cells, and a header is text")
    Do ..RunMdx("DRILLTHROUGH MAXROWS 5 SELECT FROM [OcuPilotProbeGrid]", .tListing)
    Do $$$AssertEquals(..Keys(tListing) _ " " _ tListing.%GetTypeOf("columns") _ " " _ tListing.%GetTypeOf("rows") _ " " _ tListing.rows.%GetTypeOf(0) _ " " _ tListing.rows.%Get(0).%GetTypeOf(0) _ " " _ tListing.%GetTypeOf("truncated") _ " " _ tListing.%GetTypeOf("seconds"), "outcome,columns,rows,truncated,seconds array array array string boolean number", "a listing's fields, in order, its rows arrays of text")
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, "SELEKT FROM [OcuPilotProbeVisits]", .tRS, .tError, .tHttp, .tFault, .tAsk, .tFound)
    Do $$$AssertEquals(..Keys(tError) _ " " _ tError.%GetTypeOf("message"), "outcome,message string", "an error answer is the outcome and the vendor's text")
}

/// <p>AC5: a run writes nothing of OcuPilot's own to the instance. The signed-in user's favorites, the probe's term list and the folder and folder item
/// globals are as they were after a cells query, a cell's drill-through, a typed DRILLTHROUGH, a refused CREATE and a statement the vendor will not
/// prepare. The vendor's own result cache and session nodes, which a query writes, are left out of the digest. The first leg proves the favorites
/// node holds something, so the comparison does not pass having read nothing.</p>
/// <p>Mutation (Rule 19): set a favorite for the signed-in user in <method>OcuPilot.Port.AnalyticsPort.MdxStart</method> -- the digest differs and this
/// goes red.</p>
Method TestAnMdxRunWritesNothingOfItsOwn()
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tFavorites = $Order(^DeepSee.UserPreferences($USERNAME, "favorite", ""))
    Set $NAMESPACE = tOrigNS
    Do $$$AssertNotEquals(tFavorites, "", "the signed-in user holds a favorite, so the favorites node is not empty")
    Set tBefore = ##class(OcuPilot.Test.AnalyticsPort).Snapshot(0)
    Do $$$AssertTrue($Extract(tBefore, 1, 5) '= "ERROR", "the snapshot before was taken: " _ tBefore)
    Do ..RunMdx(..#CROSSJOIN, .tAnswer, 2, 1, .tDrill)
    Do ..RunMdx("DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]", .tListing)
    Do $$$AssertEquals(tAnswer.outcome _ " " _ tDrill.outcome _ " " _ tListing.outcome, "cells rows rows", "the runs answered")
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, "CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'", .tRS, .tCreate, .tHttp, .tFault, .tAsk, .tFound)
    Do $$$AssertStatusNotOK(tSC, "a CREATE is refused")
    Do ..RunMdx("SELEKT FROM [OcuPilotProbeVisits]", .tError)
    Do $$$AssertEquals(##class(OcuPilot.Test.AnalyticsPort).Snapshot(0), tBefore, "none of the user data, term list, folder or folder item nodes changed")
}

/// <p>The detector's answer for <var>pText</var> as <code>&lt;1 or 0&gt;|&lt;the names found&gt;|&lt;unread&gt;</code>.</p>
ClassMethod Detect(pText As %String) As %String
{
    Set tAsk = $ClassMethod(..#PORT, "MdxConstructs", pText, .tFound, .tUnread)
    Quit tAsk _ "|" _ $ListToString($Get(tFound)) _ "|" _ tUnread
}

/// <p>AC10: the detector finds each of the five constructs in mixed case, lists them in <parameter>MDXCONSTRUCTS</parameter> order
/// whatever order the text names them in, and finds none in a plain SELECT.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method> the earlier four-word case-insensitive substring
/// test of the raw text -- the obfuscation and literal cases below go red, which is the red this class was written against.</p>
Method TestTheDetectorFindsEachConstructInMixedCaseAndNoneInAPlainSelect()
{
    Set tBase = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"
    Do $$$AssertEquals(..Detect(tBase), "0||0", "a plain SELECT holds none")
    For tCase = $ListBuild("%SeArCh", "%SEARCH"), $ListBuild("%sqlRestrict", "%SQLRESTRICT"), $ListBuild("ReTuRn", "RETURN"), $ListBuild("%oRdEr", "%ORDER"), $ListBuild("%pArM", "%PARM") {
        Do $$$AssertEquals(..Detect(tBase _ " " _ $List(tCase, 1)), "1|" _ $List(tCase, 2) _ "|0", $List(tCase, 1) _ " is found as " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(..Detect(tBase _ " %PARM %ORDER RETURN %SQLRESTRICT %SEARCH %ORDER"), "1|%SEARCH,%SQLRESTRICT,RETURN,%ORDER,%PARM|0", "all five, named in reverse and with a repeat, are listed once each in their own order")
}

/// <p>AC10: the detector finds each obfuscation the vendor's tokenizer reads through: a comment inside each of the five words, a word
/// split by a line comment, a word inside a double-quoted literal and inside a single-quoted span, and a braced <code>%PARM</code>.</p>
/// <p>Mutation (Rule 19): read no string literal's tokens in <method>OcuPilot.Port.AnalyticsPort.ScanTokens</method> -- the
/// <code>%MDX("...")</code> leg goes red.</p>
Method TestTheDetectorReadsThroughComments()
{
    Set tBase = "SELECT FROM [OcuPilotProbeGrid] "
    For tCase = $ListBuild("%SE/**/ARCH", "%SEARCH"), $ListBuild("%SQL/**/RESTRICT", "%SQLRESTRICT"), $ListBuild("RET/**/URN", "RETURN"), $ListBuild("%ORD/**/ER", "%ORDER"), $ListBuild("%PA/**/RM", "%PARM") {
        Do $$$AssertEquals(..Detect(tBase _ $List(tCase, 1)), "1|" _ $List(tCase, 2) _ "|0", "a comment inside " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(..Detect(tBase _ "%SE--" _ $Char(10) _ "ARCH"), "1|%SEARCH|0", "a line comment of dashes splits %SEARCH")
    Do $$$AssertEquals(..Detect(tBase _ "%SE//" _ $Char(10) _ "ARCH"), "1|%SEARCH|0", "a line comment of slashes splits %SEARCH")
    Do $$$AssertEquals(..Detect(tBase _ "WHERE %MDX(""SELECT %SE/**/ARCH x"")"), "1|%SEARCH|0", "%SE/**/ARCH inside a %MDX(""..."") literal")
    Do $$$AssertEquals(..Detect("WITH MEMBER [Measures].[X] AS '%SE/**/ARCH.&[1]' SELECT FROM [OcuPilotProbeGrid]"), "1|%SEARCH|0", "and inside a single-quoted WITH MEMBER expression")
    Do $$$AssertEquals(..Detect("WITH %PARM P AS 'VALUE:{$Increment(^OcuPilotProbeMdxSplice(9))}' SELECT FROM [OcuPilotProbeGrid]"), "1|%PARM|0", "a braced %PARM value")
    Set tNested = "SELECT 1"
    For tDepth = 1:1:3 Set tNested = """" _ $Replace("%MDX(" _ tNested _ ")", """", """""") _ """"
    Do $$$AssertEquals(..Detect("SELECT FROM [x] WHERE " _ $Replace(tNested, "SELECT 1", "RETURN")), "1|RETURN|0", "a word three literals deep is still read")
}

/// <p>AC10: a bracketed member is read as the parser reads it: <code>[%SEARCH]</code> and a member key named exactly <code>[RETURN]</code>
/// are found (the named false positive, on the fail-closed side), and <code>[%SE/**/ARCH]</code>, whose bracket keeps the comment, is
/// not.</p>
Method TestTheDetectorReadsBracketedMembersAsTheParserDoes()
{
    Set tBase = "SELECT FROM [OcuPilotProbeGrid] WHERE "
    Do $$$AssertEquals(..Detect(tBase _ "[%SEARCH].&[1]"), "1|%SEARCH|0", "[%SEARCH] is %SEARCH")
    Do $$$AssertEquals(..Detect(tBase _ "[Place].[H1].[RETURN]"), "1|RETURN|0", "a member named exactly [RETURN] is found")
    Do $$$AssertEquals(..Detect(tBase _ "[Place].[H1].[Return Policy]"), "0||0", "a longer member name is not")
    Do $$$AssertEquals(..Detect(tBase _ "[%SE/**/ARCH]"), "0||0", "[%SE/**/ARCH] keeps its comment inside its bracket and names nothing")
}

/// <p>AC10: the detector fails closed: an unterminated bracket or quote, a number the tokenizer refuses, a blank text and a literal nested
/// deeper than <parameter>MDXSTRINGDEPTH</parameter> each answer 1 with <code>unread</code> 1 and nothing found.</p>
/// <p>Mutation (Rule 19): answer 0 when a tokenize fails in <method>OcuPilot.Port.AnalyticsPort.ScanTokens</method> -- the first three
/// cases go red.</p>
Method TestTheDetectorFailsClosed()
{
    Set tBase = "SELECT FROM [OcuPilotProbeGrid]"
    Do $$$AssertEquals(..Detect("SELECT FROM [OcuPilotProbeGrid"), "1||1", "an unterminated bracket is unread")
    Do $$$AssertEquals(..Detect(tBase _ " WHERE ""abc"), "1||1", "an unterminated quote is unread")
    Do $$$AssertEquals(..Detect(tBase _ " WHERE 3rd"), "1||1", "3rd is unread")
    Do $$$AssertEquals(..Detect(""), "1||1", "a blank text is unread")
    Do $$$AssertEquals(..Detect("   " _ $Char(10)), "1||1", "and so is one of white space")
    Set tNested = "SELECT 1"
    For tDepth = 1:1:4 Set tNested = """" _ $Replace(tNested, """", """""") _ """"
    Do $$$AssertEquals(..Detect(tBase _ " WHERE " _ tNested), "1||1", "a literal nested four deep is deeper than the three levels read")
}

/// <p>AC10: <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> runs the detector on the variable-resolved text too and executes
/// nothing: a <code>$variable.v</code> handed a <code>%SEARCH</code> expression asks, naming it, and leaves the node undefined; handed
/// nothing, it does not.</p>
/// <p>Mutation (Rule 19): skip the check on the resolved text in <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> -- the asked leg
/// goes red.</p>
Method TestPrepareChecksTheResolvedTextAndExecutesNothing()
{
    Set tStatement = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid] WHERE $variable.v"
    Do $$$AssertEquals(..Detect(tStatement), "0||0", "the statement itself names no construct")
    Kill ^|"USER"|OcuPilotProbeMdxSplice(10)
    Set tVariables("v") = "%SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(10))}]"
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, tStatement, .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound, .tVariables)
    Do $$$AssertStatusOK(tSC, "the statement prepares with the variable")
    Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
    Do $$$AssertEquals($Get(tAsk) _ " " _ $ListToString($Get(tFound)), "1 %SEARCH", "and asks, naming %SEARCH")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(10)), 0, "the node its braces would increment is undefined")
    Kill tVariables
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, tStatement, .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound)
    Do $ClassMethod(..#PORT, "MdxRelease", ..#NAMESPACE, .tRS)
    Do $$$AssertEquals($Get(tAsk), 0, "handed no variable, it asks nothing: an empty text names no construct")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(10)), 0, "and the node is still undefined")
}

/// <p>AC5: CREATE, DROP and a statement of three axes are refused by their codes before anything runs, and a statement the vendor will
/// not prepare is answered with the vendor's own text, not refused.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> accept CREATE -- the first leg goes red.</p>
Method TestCreateDropAndThreeAxesAreRefusedAndASyntaxErrorAnswersTheVendorsText()
{
    For tCase = $ListBuild("CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'", "ANALYTICS.MDX.KIND", 422), $ListBuild("DROP MEMBER [OcuPilotProbeVisits].[Measures].[X]", "ANALYTICS.MDX.KIND", 422), $ListBuild("SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1, [Seen].[H1].[Year].Members ON 2 FROM [OcuPilotProbeVisits]", "ANALYTICS.MDX.AXES", 422) {
        Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, $List(tCase, 1), .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound)
        Do $$$AssertStatusNotOK(tSC, "refused: " _ $Extract($List(tCase, 1), 1, 40))
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $List(tCase, 3) _ " " _ $List(tCase, 2), "with its code")
    }
    Set tSC = $ClassMethod(..#PORT, "MdxPrepare", ..#NAMESPACE, "SELEKT FROM [OcuPilotProbeVisits]", .tRS, .tAnswer, .tHttp, .tFault, .tAsk, .tFound)
    Do $$$AssertStatusOK(tSC, "a syntax error is not a refusal")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.outcome = "error") && (tAnswer.message [ "Unknown term at start of query: SELEKT"), "it answers the vendor's text: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "no answer"))
}

/// <p>AC7: a namespace that reports no analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>, and one whose analytics cache lives in
/// a read-only database (<code>HSLIB</code>) 409 <code>ANALYTICS.MDX.READONLY</code>, each before any vendor call; the probe's own
/// namespace passes.</p>
/// <p>Mutation (Rule 19): drop the read-only test from <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method> -- the HSLIB leg goes red.</p>
Method TestTheGateNamesAMissingAnalyticsAndAReadOnlyCache()
{
    Set tSC = $ClassMethod(..#PORT, "MdxAdmit", ..#NAMESPACE, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "USER, where analytics is on and the cache database is writable, passes")
    For tCase = $ListBuild("HSCUSTOM", "ANALYTICS.NAMESPACE"), $ListBuild("HSLIB", "ANALYTICS.MDX.READONLY") {
        Set tSC = $ClassMethod(..#PORT, "MdxAdmit", $List(tCase, 1), .tHttp, .tFault)
        Do $$$AssertEquals($Select($$$ISERR(tSC): tHttp _ " " _ tFault.%Get("code"), 1: "allowed"), "409 " _ $List(tCase, 2), $List(tCase, 1) _ " is refused " _ $List(tCase, 2))
    }
}

}
