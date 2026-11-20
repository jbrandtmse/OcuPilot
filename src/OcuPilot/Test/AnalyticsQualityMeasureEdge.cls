/// <p>Pins the edges of Story 24.12's read surface (AD-36, AD-65) against <code>USER</code>, with analytics on and the probe's quality measures saved and compiled through
/// <class>OcuPilot.Test.AnalyticsProbe</class>: a measure linked to a master that no longer exists is one row built from the vendor's list (the vendor reads no model for it) and holds
/// no groups or documentation; a measure whose subject area names no cube reads like any other; a criterion that is oversized, holds a quote, a control character, a character past
/// Latin-1 or a path, or names a deleted measure answers no rows and never an error; no such read makes a journaled write; and removing the edge measures leaves no class and no registry node.</p>
/// <p>The matrix of the other states is pinned by <class>OcuPilot.Test.AnalyticsQualityMeasureRead</class>, whose helpers this class calls, and the privilege pair by
/// <class>OcuPilot.Test.AnalyticsQualityMeasureGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the probe turns analytics on for <code>USER</code> and compiles classes there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter READ = "OcuPilot.Test.AnalyticsQualityMeasureRead";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

/// <p>The rows the probe's measures make: the compiled, refused, linked, no-area and dangling measures; the disabled one is no row.</p>
Parameter MEASURES = 5;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureEdge turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateQualityMeasures")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateEdgeQualityMeasures")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe and restore USER's flags; a failing status when anything of it, a quality measure included, is left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>One read of <var>pEndpoint</var> through the port, as <method>OcuPilot.Test.AnalyticsQualityMeasureRead.Read</method>: the rows, the HTTP status.</p>
ClassMethod Read(pEndpoint As %String, pMeasure As %String = "", Output pRows, Output pHttp As %Integer) As %Status
{
    Quit $ClassMethod(..#READ, "Read", pEndpoint, pMeasure, 100, .pRows, .pHttp, .tFault)
}

/// <p>What the vendor reads for <var>pName</var> in <code>USER</code>, as <code>&lt;model read&gt;|&lt;master class exists&gt;</code> (1 or 0 each): the model <code>%GetModel(name, , 1)</code> answers, and whether
/// the probe's deleted master class is still there.</p>
ClassMethod Vendor(pName As %String) As %String
{
    ; The probe's class is not visible in USER, so its class name is read first.
    Set tMasterClass = $Parameter(..#PROBE, "QMMASTERCLASS")
    Set tOrigNS = $NAMESPACE
    Set tAnswer = "error"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tModel = ##class(%DeepSee.QualityMeasure.Utils).%GetModel(pName, , 1)
        Set tAnswer = ''$IsObject(tModel) _ "|" _ ''##class(%Dictionary.ClassDefinition).%ExistsId(tMasterClass)
    } Catch ex {
        Set tAnswer = "error: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Assert that <var>pRow</var> carries, for each of <var>pFields</var>, the value of <var>pExpected</var>.</p>
Method AssertSame(pRow As %DynamicObject, pExpected As %DynamicObject, pFields As %String, pLabel As %String)
{
    If '$IsObject(pRow) {
        Do $$$AssertTrue(0, pLabel _ ": the row is present")
        Quit
    }
    For tI = 1:1:$Length(pFields, ",") {
        Set tField = $Piece(pFields, ",", tI)
        Do $$$AssertEquals(pRow.%Get(tField), pExpected.%Get(tField), pLabel _ ": " _ tField _ " equals the model's")
    }
}

/// <p>A measure linked to a master that was deleted: the vendor reads no model for it, so its row is built from the vendor's list alone -- the name's three parts, the caption the list holds, the
/// class and <code>Compiled</code> -- with every model field empty, <code>Groups</code> 0 and not published, and it has no element and no documentation row. Its presence breaks no other row,
/// and the Quality measures screen and the agent's read tool answer the same row.</p>
/// <p>Mutation (Rule 19): make the unreadable-model branch of the measures read in <method>OcuPilot.Port.AnalyticsPort.Collect</method> answer no row -- the dangling-row legs and the recount in <method>TestZRemovingTheEdgeMeasuresLeavesNothing</method> go red.</p>
Method TestADanglingLinkIsOneRowFromTheListAndHoldsNoGroups()
{
    Set tName = $Parameter(..#PROBE, "QMDANGLING")
    Do $$$AssertEquals(..Vendor(tName), "0|0", "the vendor reads no model for the dangling measure and its master class is gone")
    Set tSC = ..Read("QualityMeasures", "", .tRows, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "ProbeCount", tRows), "200|" _ ..#MEASURES, "the measures read answers the five probe measures")
    Set tRow = $ClassMethod(..#READ, "RowNamed", tRows, tName)
    If '$IsObject(tRow) {
        Do $$$AssertTrue(0, "the dangling measure is a row")
        Quit
    }
    Do $$$AssertEquals(tRow.Catalog _ "|" _ tRow.Set _ "|" _ tRow.Id _ "|" _ tRow.Caption _ "|" _ tRow.Class _ "|" _ tRow.Compiled _ "|" _ tRow.Groups, "OcuPilotProbe|Quality|Dangling|Follows a deleted master|" _ $Parameter(..#PROBE, "QMDANGLINGCLASS") _ "|1|0", "its row is the name's parts, the list's caption, its class and compile state")
    Do $$$AssertEquals(tRow.Description _ tRow.SubjectArea _ tRow.Expression _ tRow.LinkedTo _ tRow.Format _ tRow.Href _ tRow.Published, "0", "and no model field is invented")
    For tMeasure = $Parameter(..#PROBE, "QMCOMPILED"), $Parameter(..#PROBE, "QMLINKED"), $Parameter(..#PROBE, "QMREFUSED"), $Parameter(..#PROBE, "QMNOAREA") {
        Do $$$AssertTrue($IsObject($ClassMethod(..#READ, "RowNamed", tRows, tMeasure)), tMeasure _ " still reads beside it")
    }
    Do $$$AssertEquals($ClassMethod(..#READ, "RowNamed", tRows, $Parameter(..#PROBE, "QMMASTER")), "", "and the deleted master is no row")
    For tEndpoint = "QualityMeasureElements", "QualityMeasureMetas" {
        Set tSC = ..Read(tEndpoint, tName, .tNone, .tHttp)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "RowCount", tNone), "200|0", tEndpoint _ ": the dangling measure has no row")
    }
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasures/read?maxRows=100", "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the Quality measures screen reads")
    If $IsObject(tScreen) && $IsObject(tScreen.%Get("rows")) {
        Set tScreenRow = $ClassMethod(..#READ, "RowNamed", tScreen.rows, tName)
        Do $$$AssertTrue($IsObject(tScreenRow), "the screen carries the dangling row")
        If $IsObject(tScreenRow) Do $$$AssertEquals(tScreenRow.%ToJSON(), tRow.%ToJSON(), "and it is the port's row")
    }
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasures.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", "the agent's read tool answers: " _ tLeg.%ToJSON())
    If $IsObject(tLeg.%Get("rows")) Do $$$AssertEquals($ClassMethod(..#READ, "ProbeCount", tLeg.rows), ..#MEASURES, "with the same five probe rows")
}

/// <p>A measure whose subject area names no cube compiles and is a row like any other: every field equals the model's, the subject area as written, and its one group and element read.</p>
/// <p>Mutation (Rule 19): make the measures branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> read the subject area from the cube registry and answer empty for a cube that is not there -- the subject area leg goes red.</p>
Method TestAMeasureOverAMissingSubjectAreaReadsLikeAnyOther()
{
    Set tName = $Parameter(..#PROBE, "QMNOAREA")
    Set tFacts = $ClassMethod(..#READ, "Facts", tName)
    Do $$$AssertEquals(tFacts.%Get("error"), "", "the model reads, so the comparison below is never of two failed reads")
    Set tSC = ..Read("QualityMeasures", "", .tRows, .tHttp)
    Set tRow = $ClassMethod(..#READ, "RowNamed", tRows, tName)
    Do ..AssertSame(tRow, tFacts.measure, $Parameter(..#READ, "MEASUREFIELDS"), tName)
    If $IsObject(tRow) Do $$$AssertEquals(tRow.SubjectArea _ "|" _ tRow.Compiled _ "|" _ tRow.Groups, $Parameter(..#PROBE, "QMMISSINGAREA") _ "|1|1", "the subject area as written, compiled, one group")
    Set tSC = ..Read("QualityMeasureElements", tName, .tElements, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "RowCount", tElements) _ "|" _ $ClassMethod(..#READ, "Names", tElements), "200|1|One", "its one element reads")
    If $IsObject(tElements) && (tElements.%Size() = 1) Do ..AssertSame(tElements.%Get(0), tFacts.elements.%Get(0), $Parameter(..#READ, "ELEMENTFIELDS"), tName _ " element")
    Set tSC = ..Read("QualityMeasureMetas", tName, .tMetas, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "RowCount", tMetas), "200|0", "and it holds no documentation")
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasureelements/read?maxRows=100&qualitymeasure=" _ $ZConvert(tName, "O", "URL"), "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the Groups and elements screen reads it")
    If $IsObject(tScreen) && $IsObject(tScreen.%Get("rows")) Do $$$AssertEquals(tScreen.rows.%Size() _ "|" _ $ClassMethod(..#READ, "Names", tScreen.rows), "1|One", "with its one element")
}

/// <p>A criterion that names no measure answers 200 and no rows, whatever it holds: 752 characters (the screen's limit) and 3000, a double and a single quote, a closing parenthesis, a caret, a control character, a space, a
/// character past Latin-1, a path of many parts, a measure's name with a leading or a trailing character, and the name of the deleted master. A criterion that is not a measure's name is never a 500.</p>
/// <p>Mutation (Rule 19): drop the model-name check from the elements and documentation branches of <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the leg for the compiled measure's name followed by a slash goes red.</p>
Method TestAnOddCriterionNamesNoMeasure()
{
    Set tCompiled = $Parameter(..#PROBE, "QMCOMPILED")
    Set tCriteria = $ListBuild($Translate($Justify("", 752), " ", "a"), $Translate($Justify("", 3000), " ", "a"), tCompiled _ """", tCompiled _ "'", tCompiled _ ")", "^DeepSee.QMsrs", "a" _ $Char(10) _ "b", " ", $Char(8364), "a/b/c/d/e/f/g", "/" _ tCompiled, tCompiled _ " ", tCompiled _ "/", $Parameter(..#PROBE, "QMMASTER"))
    For tAt = 1:1:$ListLength(tCriteria) {
        For tEndpoint = "QualityMeasureElements", "QualityMeasureMetas" {
            Set tSC = ..Read(tEndpoint, $List(tCriteria, tAt), .tNone, .tHttp)
            Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "RowCount", tNone), "200|0", tEndpoint _ ": criterion " _ tAt _ " of " _ $ListLength(tCriteria) _ " names no measure")
        }
    }
    Set tSC = ..Read("QualityMeasureElements", tCompiled, .tFound, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "RowCount", tFound), "200|3", "while the measure's own name still reads its three elements, so the legs above can fail")
}

/// <p>AC4: none of the edge reads makes a journaled write in the calling process: the dangling and no-area measures' three reads, the measures read, and an oversized, a quoted and a deleted-master criterion. The records the
/// scan does not charge to them are the SQL engine's own, as in <method>OcuPilot.Test.AnalyticsQualityMeasureRead.TestAAReadsMakeNoJournaledWrite</method>, and the scan is proved able to see a write by a control write made in the same window.</p>
/// <p>Mutation (Rule 19): make the unreadable-model branch of the measures read in <method>OcuPilot.Port.AnalyticsPort.Collect</method> set a global node in <code>USER</code> -- the no-write leg goes red.</p>
Method TestAAEdgeReadsMakeNoJournaledWrite()
{
    ; The framework journals each assertion it records, so nothing is asserted until both scans are done.
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tAnswers = ..ReadEdges()
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tReadWrites)
    Set tReads = $Select(tTotal < 0: tTotal, 1: 0)
    Set tFirst = ""
    For tI = 1:1:tTotal {
        Set tRecord = tReadWrites(tI)
        If (tRecord '[ "]rINDEXSQL(") && (tRecord '[ "]%SYS(""sql"",") Set tReads = tReads + 1, tFirst = tFirst _ $Select(tFirst = "": "", 1: "; ") _ tRecord
    }
    Set ^|"USER"|OcuPilotProbeAnalyticsScan = 1
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tAllWrites)
    Kill ^|"USER"|OcuPilotProbeAnalyticsScan
    Set tSeen = 0
    For tI = 1:1:tTotal {
        If $Get(tAllWrites(tI)) [ "OcuPilotProbeAnalyticsScan" Set tSeen = tSeen + 1
    }
    Do $$$AssertEquals(tAnswers, "200|200,200,200,200,200|200,200,200,200,200", "the measures read and the elements and documentation reads of the edge names answer")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, tReads < 0: " (the journal rolled to another file)", 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan finds the control write made after them" _ $Select(tTotal < 0: " (the journal rolled to another file)", 1: " (records: " _ tTotal _ ")"))
}

/// <p>Every read the scan covers, answering the HTTP statuses as <code>measures|elements...|documentation...</code>.</p>
Method ReadEdges() As %String
{
    Set tSC = ..Read("QualityMeasures", "", .tRows, .tMeasuresHttp)
    Set tNames = $ListBuild($Parameter(..#PROBE, "QMDANGLING"), $Parameter(..#PROBE, "QMNOAREA"), $Translate($Justify("", 752), " ", "a"), $Parameter(..#PROBE, "QMCOMPILED") _ """", $Parameter(..#PROBE, "QMMASTER"))
    Set tElementsHttp = ""
    Set tMetasHttp = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tSC = ..Read("QualityMeasureElements", $List(tNames, tI), .tElements, .tHttp)
        Set tElementsHttp = tElementsHttp _ $Select(tElementsHttp = "": "", 1: ",") _ tHttp
        Set tSC = ..Read("QualityMeasureMetas", $List(tNames, tI), .tMetas, .tHttp)
        Set tMetasHttp = tMetasHttp _ $Select(tMetasHttp = "": "", 1: ",") _ tHttp
    }
    Quit tMeasuresHttp _ "|" _ tElementsHttp _ "|" _ tMetasHttp
}

/// <p>What the probe's quality measures leave in <code>USER</code>: any of their nine classes, and the registry nodes <method>OcuPilot.Test.AnalyticsProbe.Left</method> names for them.</p>
ClassMethod Left() As %String
{
    Set tClasses = ""
    For tParameter = "QMCOMPILEDCLASS", "QMREFUSEDCLASS", "QMLINKEDCLASS", "QMOFFCLASS", "QMTWINCLASS", "QMTWINLATECLASS", "QMNOAREACLASS", "QMMASTERCLASS", "QMDANGLINGCLASS" {
        Set tClasses = tClasses _ $ListBuild($Parameter(..#PROBE, tParameter))
    }
    Set tProbeLeft = $ClassMethod(..#PROBE, "Left")
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(tClasses) {
            If ##class(%Dictionary.ClassDefinition).%ExistsId($List(tClasses, tI)) Set tLeft = tLeft _ ",class " _ $List(tClasses, tI)
        }
    } Catch ex {
        Set tLeft = tLeft _ ",unreadable: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    For tI = 1:1:$Length(tProbeLeft, ",") {
        If $Piece(tProbeLeft, ",", tI) [ "quality measure" Set tLeft = tLeft _ "," _ $Piece(tProbeLeft, ",", tI)
    }
    Quit $Extract(tLeft, 2, *)
}

/// <p>AC6: removing the probe's quality measures deletes the edge measures' classes and registry nodes as well (a measure over a missing subject area registers under that name), so
/// <method>OcuPilot.Test.AnalyticsProbe.Left</method> names none; creating them again restores them.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.AnalyticsProbe.RemoveQualityMeasures</method> skip the no-area class -- this goes red naming it.</p>
Method TestZRemovingTheEdgeMeasuresLeavesNothing()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveQualityMeasures"), "the measures are removed")
    Do $$$AssertEquals(..Left(), "", "no class and no registry node of a probe measure remains: " _ ..Left())
    Set tSC = ..Read("QualityMeasures", "", .tRows, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "ProbeCount", tRows), "200|0", "and the measures read answers none of them")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateQualityMeasures"), "the measures are made again")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateEdgeQualityMeasures"), "and the edge measures too")
    Set tSC = ..Read("QualityMeasures", "", .tRows, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#READ, "ProbeCount", tRows), "200|" _ ..#MEASURES, "and the read answers them again")
}

}
