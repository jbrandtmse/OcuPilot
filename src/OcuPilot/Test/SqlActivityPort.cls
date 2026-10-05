/// <p>Pins <class>OcuPilot.Port.SqlActivityPort</class> as the suite's own account (AD-29, AD-35,
/// AD-36, Story 19.10): a probe statement running in <code>USER</code> is a row of the port, the
/// screen's read and the read tool, slowest first, cut at the cap, with the reading process's own
/// statement left out and the probe's bound value in no answer; a statement's text is shaped and cut at
/// 1,024 characters; a remote server is told apart; a vendor fault fails the read and is logged; the
/// gate refuses before any statement is prepared; and the vendor surface the port names is pinned.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace. It starts probe jobs
/// through <class>OcuPilot.Test.SqlActivityProbe</class>, each a read-only statement it stops and reads
/// back stopped after every method; it creates nothing else.</p>
Class OcuPilot.Test.SqlActivityPort Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlActivityProbe";

Parameter PORT = "OcuPilot.Port.SqlActivityPort";

Parameter SEAM = "OcuPilot.Test.SqlActivitySeam";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SqlActivityList";

Parameter NAMESPACE = "USER";

/// <p>The columns <parameter>OcuPilot.Port.SqlActivityPort.CURRENTSTATEMENTS</parameter> names, each
/// a column of the vendor's table.</p>
Parameter COLUMNS = "Server,ProcessID,UserName,Namespace,Parent,QueryRunType,ParentType,ExecutionDuration,ExecutionStart,SQLStatementID,StatementIndexHash,CallerName,CachedQuery,CurrentWorkerCount,TP_NestingLevel";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SqlActivitySeam).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>Every probe job this method started is stopped and read back gone.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SqlActivitySeam).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "every probe job is stopped")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Running"), 0, "and none is left running")
    Quit $$$OK
}

/// <p>A fresh probe literal or value carrying <var>pPrefix</var>.</p>
ClassMethod Fresh(pPrefix As %String) As %String
{
    Quit pPrefix _ (10000000 + $Random(90000000))
}

/// <p>One port call through <var>pClass</var>, a list cut at <var>pMax</var> rows, as <code>http
/// code</code>.</p>
ClassMethod Call(Output pRows, pMax As %String = 100, pClass As %String = {..#PORT}, pEndpoint As %String = "CurrentStatements", pType As %String = "LIST", pBody As %DynamicAbstractObject = "", Output pFault) As %String
{
    Kill tQuery
    If pMax '= "" Set tQuery("maxRows") = pMax
    Set pFault = ""
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, pType, .tQuery, pBody, .pRows, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The row of <var>pRows</var> whose <code>ProcessID</code> is <var>pPid</var>, or
/// <code>""</code>.</p>
ClassMethod RowOf(pRows, pPid As %Integer) As %DynamicObject
{
    If '$IsObject($Get(pRows)) Quit ""
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("ProcessID") = pPid Set tFound = tRow
    }
    Quit tFound
}

/// <p>AC1: a probe running in <code>USER</code> inside one open transaction is a row with its
/// namespace, its run type, an elapsed time above zero, this instance's server and the suite's account,
/// not remote, and every other field equal to the vendor's own column for that process; the suite's own
/// text is shown with the probe's literal; the reading process's own statement is not a row; and the
/// screen's declared read and its read tool answer the same probe row.</p>
/// <p>Mutation (Rule 19): drop the <code>$Job</code> filter from
/// <method>OcuPilot.Port.SqlActivityPort.Rows</method> -- the own-row leg goes red; set no
/// <code>Namespace</code> there -- the namespace leg goes red; read <code>Routine</code> from the
/// <code>CachedQuery</code> column, or <code>TransactionLevel</code> as 0 -- the vendor-column leg goes
/// red.</p>
Method TestTheProbeIsARowAndTheReaderIsNot()
{
    Set tLiteral = ..Fresh("OcuSeedPort1910")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, tLiteral, ..Fresh("OcuSecretProbe1910"), .tPid, 1), "a probe statement runs in USER, inside one open transaction")
    Do $$$AssertEquals(..Call(.tRows), "200 ", "the port answers")
    Set tRow = ..RowOf(.tRows, tPid)
    Do $$$AssertTrue($IsObject(tRow), "the probe is a row")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.Namespace _ "|" _ tRow.RunType _ "|" _ tRow.UserName _ "|" _ tRow.Server _ "|" _ tRow.%Get("Remote"), ..#NAMESPACE _ "|DynamicStatement|" _ $Username _ "|" _ $ClassMethod(..#PORT, "LocalServer") _ "|0", "in USER, a dynamic statement, the suite's account on this instance")
    Do $$$AssertTrue((tRow.Elapsed > 0) && (tRow.CachedQuery '= "") && (tRow.StatementHash '= "") && (tRow.Started '= "") && (tRow.TransactionLevel = 1), "with an elapsed time, a cached query, a hash, a start time and its transaction: " _ tRow.%ToJSON())
    Set tVendor = ##class(%SQL.Statement).%ExecDirect(, "SELECT SQLStatementID, StatementIndexHash, CallerName, CachedQuery, CurrentWorkerCount, TP_NestingLevel, ExecutionStart FROM INFORMATION_SCHEMA.CURRENT_STATEMENTS WHERE ProcessID = ?", tPid)
    Do $$$AssertTrue(tVendor.%Next(), "the vendor lists the probe")
    Do $$$AssertEquals(tRow.StatementId _ "|" _ tRow.StatementHash _ "|" _ tRow.Routine _ "|" _ tRow.CachedQuery _ "|" _ tRow.Workers _ "|" _ tRow.TransactionLevel _ "|" _ tRow.Started, tVendor.%GetData(1) _ "|" _ tVendor.%GetData(2) _ "|" _ tVendor.%GetData(3) _ "|" _ tVendor.%GetData(4) _ "|" _ (+tVendor.%GetData(5)) _ "|" _ (+tVendor.%GetData(6)) _ "|" _ tVendor.%GetData(7), "each field is the vendor's own column")
    Do $$$AssertTrue(tRow.Statement [ tLiteral, "the suite's own statement's text is shown, carrying its literal")
    Do $$$AssertTrue('$IsObject(..RowOf(.tRows, $Job)), "the reading process's own statement is not a row")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the screen's read answers")
    Set tScreenRow = ..RowOf($Select($IsObject($Get(tAnswer)): tAnswer.rows, 1: ""), tPid)
    Do $$$AssertTrue($IsObject(tScreenRow) && (tScreenRow.Namespace = ..#NAMESPACE) && (tScreenRow.Statement [ tLiteral), "the screen's read answers the probe row")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.sqlactivity.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the read tool answers")
    Set tToolRow = ..RowOf($Select($IsObject($Get(tResult)): tResult.rows, 1: ""), tPid)
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Namespace = ..#NAMESPACE) && (tToolRow.Statement [ tLiteral), "the read tool answers the probe row")
}

/// <p>AC1 and AD-36: rows come slowest first, so of two probes the one started first precedes the
/// other; a cap of one answers one row, and the screen's read under a cap of one reports it
/// truncated.</p>
/// <p>Mutation (Rule 19): drop <code>DESC</code> from
/// <parameter>OcuPilot.Port.SqlActivityPort.CURRENTSTATEMENTS</parameter> -- the order legs go red;
/// drop the cut from <method>OcuPilot.Port.SqlActivityPort.Rows</method> -- the cap leg goes red.</p>
Method TestRowsComeSlowestFirstAndCutAtTheCap()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedFirst1910"), ..Fresh("OcuSecretProbe1910"), .tFirst), "a first probe runs")
    Hang 1
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedSecond1910"), ..Fresh("OcuSecretProbe1910"), .tSecond), "a second probe runs")
    Do $$$AssertEquals(..Call(.tRows), "200 ", "the port answers")
    Set tOrder = ""
    Set tSorted = 1
    Set tPrevious = ""
    Set tIterator = $Select($IsObject($Get(tRows)): tRows.%GetIterator(), 1: [].%GetIterator())
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tPrevious '= "") && (tRow.Elapsed > tPrevious) Set tSorted = 0
        Set tPrevious = tRow.Elapsed
        If (tRow.ProcessID = tFirst) || (tRow.ProcessID = tSecond) Set tOrder = tOrder _ $ListBuild(tRow.ProcessID)
    }
    Do $$$AssertTrue(tSorted, "every row's elapsed time is at least the next one's")
    Do $$$AssertEquals($ListToString(tOrder), tFirst _ "," _ tSecond, "the probe running longer comes first")
    Do $$$AssertEquals(..Call(.tCut, 1) _ "|" _ $Select($IsObject($Get(tCut)): tCut.%Size(), 1: ""), "200 |1", "a cap of one answers one row")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1, .tCapped, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tCapped)): tCapped.rows.%Size() _ "|" _ tCapped.truncated, 1: ""), "1|1", "the screen's read under a cap of one answers one row and reports it truncated")
}

/// <p>AC4: the probe binds a secret-shaped value, which the vendor holds in its
/// <code>Parameters</code>; the value is in no field of the port's answer, the screen's read or the
/// read tool's result, and no answer carries a <code>Parameters</code> field.</p>
/// <p>Mutation (Rule 19): add <code>Parameters</code> to
/// <parameter>OcuPilot.Port.SqlActivityPort.CURRENTSTATEMENTS</parameter> and to the row -- the port
/// leg goes red.</p>
Method TestTheBoundValueIsInNoAnswer()
{
    Set tValue = ..Fresh("OcuSecretProbe1910")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedBound1910"), tValue, .tPid), "a probe binding the value runs")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Parameters FROM INFORMATION_SCHEMA.CURRENT_STATEMENTS WHERE ProcessID = ?", tPid)
    Do $$$AssertTrue(tRS.%Next() && ($ListToString(tRS.%GetData(1)) [ tValue), "the vendor holds the bound value in Parameters")
    Do $$$AssertEquals(..Call(.tRows), "200 ", "the port answers")
    Set tText = $Select($IsObject($Get(tRows)): tRows.%ToJSON(), 1: "")
    Do $$$AssertTrue($IsObject(..RowOf(.tRows, tPid)), "the probe is a row")
    Do $$$AssertTrue((tText '[ tValue) && (tText '[ """Parameters"""), "the port's answer carries neither the value nor a Parameters field")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the screen's read answers")
    Do $$$AssertTrue($IsObject($Get(tAnswer)) && $IsObject(..RowOf(tAnswer.rows, tPid)), "with the probe's row")
    Do $$$AssertTrue($IsObject($Get(tAnswer)) && (tAnswer.%ToJSON() '[ tValue), "the screen's read carries no value")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.sqlactivity.read", .tTool, 1)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the read tool answers")
    Do $$$AssertTrue($IsObject($Get(tResult)) && $IsObject(..RowOf(tResult.rows, tPid)), "with the probe's row")
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.%ToJSON() '[ tValue), "the read tool's result carries no value")
}

/// <p>AC3: a statement's text is stripped of surrounding white space and control characters, kept
/// whole at 1,024 characters and cut to its first 1,021 and <code>...</code> above; a text the vendor
/// answers through the port is shaped the same way.</p>
/// <p>Mutation (Rule 19): drop the cut from <method>OcuPilot.Port.SqlActivityPort.Shape</method> --
/// the length legs go red.</p>
Method TestTheTextIsCutAbove1024()
{
    Set tPort = ..#PORT
    Set t1024 = $Translate($Justify("", 1024), " ", "a")
    Do $$$AssertEquals($ClassMethod(tPort, "Shape", " " _ $Char(9, 10) _ "SELECT 1 " _ $Char(13)), "SELECT 1", "white space and control characters around the text are stripped")
    Do $$$AssertEquals($ClassMethod(tPort, "Shape", t1024), t1024, "1,024 characters are kept whole")
    Set tCut = $ClassMethod(tPort, "Shape", t1024 _ "b")
    Do $$$AssertEquals($Length(tCut) _ "|" _ $Extract(tCut, 1022, *), "1024|...", "1,025 are cut to 1,021 and ...")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedCut1910"), ..Fresh("OcuSecretProbe1910"), .tPid), "a probe runs")
    Do $ClassMethod(..#SEAM, "Arm", "text", "SELECT " _ $Translate($Justify("", 2000), " ", "x"))
    Do $$$AssertEquals(..Call(.tRows, 100, ..#SEAM), "200 ", "the port answers the armed text")
    Set tRow = ..RowOf(.tRows, tPid)
    Do $$$AssertEquals($Select($IsObject(tRow): $Length(tRow.Statement) _ "|" _ $Extract(tRow.Statement, 1, 7) _ "|" _ $Extract(tRow.Statement, 1022, *), 1: ""), "1024|SELECT |...", "the probe's long text is cut")
}

/// <p>AC5: a server is remote when it differs from this instance's, ignoring case, and a row served
/// from another server reads <code>Remote</code> true.</p>
/// <p>Mutation (Rule 19): answer 0 from <method>OcuPilot.Port.SqlActivityPort.IsRemote</method> -- the
/// remote legs go red; set the row's <code>Remote</code> to 0 in
/// <method>OcuPilot.Port.SqlActivityPort.Rows</method> -- the row leg goes red.</p>
Method TestIsRemote()
{
    Set tPort = ..#PORT
    Set tLocal = $ClassMethod(tPort, "LocalServer")
    Do $$$AssertEquals(tLocal, $ZU(110) _ ":" _ $Get(^%SYS("SSPort")), "this instance's server is its host and superserver port")
    Do $$$AssertEquals($ClassMethod(tPort, "IsRemote", tLocal), 0, "this instance's own server is local")
    Do $$$AssertEquals($ClassMethod(tPort, "IsRemote", $ZConvert(tLocal, "L")), 0, "in any case")
    Do $$$AssertEquals($ClassMethod(tPort, "IsRemote", "otherhost:1972", "thishost:1972"), 1, "another host is remote")
    Do $$$AssertEquals($ClassMethod(tPort, "IsRemote", "thishost:1973", "THISHOST:1972"), 1, "and so is another port")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedRemote1910"), ..Fresh("OcuSecretProbe1910"), .tPid), "a probe runs")
    Do $ClassMethod(..#SEAM, "Arm", "local", "ocuotherhost1910:1")
    Do $$$AssertEquals(..Call(.tRows, 100, ..#SEAM), "200 ", "the port answers as though this instance were another")
    Set tRow = ..RowOf(.tRows, tPid)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.%Get("Remote") = 1), "and the probe's row, served from another server, reads remote")
}

/// <p>AC3: the text pre-check requires READ on both of a namespace's databases where they differ, and a
/// namespace whose routines resource does not resolve answers no text.</p>
/// <p>Mutation (Rule 19): drop the globals database's pair from
/// <method>OcuPilot.Port.SqlActivityPort.MayReadText</method> -- the routines-only leg goes red.</p>
Method TestTheTextPreCheckNeedsBothDatabases()
{
    Set tSeam = ..#SEAM
    Do $ClassMethod(tSeam, "Arm", "gate", 1)
    Do $ClassMethod(tSeam, "Arm", "resources", "%DB_OCUPROBECODE1910,%DB_OCUPROBEDATA1910")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_OCUPROBECODE1910", "READ")
    Do $$$AssertEquals($ClassMethod(tSeam, "MayRead", "OCUSPLIT1910"), 0, "READ on the routines database alone admits no text")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_OCUPROBEDATA1910", "READ")
    Do $$$AssertEquals($ClassMethod(tSeam, "MayRead", "OCUSPLIT1910"), 0, "nor READ on the globals database alone")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_OCUPROBECODE1910", "READ")
    Do $$$AssertEquals($ClassMethod(tSeam, "MayRead", "OCUSPLIT1910"), 1, "READ on both does")
    Do $ClassMethod(tSeam, "Arm", "resources", ",%DB_OCUPROBEDATA1910")
    Do $$$AssertEquals($ClassMethod(tSeam, "MayRead", "OCUSPLIT1910"), 0, "and a routines resource that does not resolve admits no text")
}

/// <p>A vendor answer of #921 is a withheld text, <code>""</code>, at 200; any other vendor error, or a
/// throw, fails the whole read 500 <code>INTERNAL</code> with no rows, its text logged and not sent.</p>
/// <p>Mutation (Rule 19): map #921 to a failure in
/// <method>OcuPilot.Port.SqlActivityPort.StatementText</method> -- the withheld leg goes red; answer
/// <code>""</code> for a throw from <method>OcuPilot.Port.SqlActivityPort.Text</method> -- the throw leg
/// goes red.</p>
Method TestAVendorFaultFailsTheRead()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..Fresh("OcuSeedFault1910"), ..Fresh("OcuSecretProbe1910"), .tPid), "a probe runs")
    Do $ClassMethod(..#SEAM, "Arm", "status", $$$ERROR(921))
    Do $$$AssertEquals(..Call(.tRows, 100, ..#SEAM), "200 ", "a withheld text answers the rows")
    Set tRow = ..RowOf(.tRows, tPid)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Statement = ""), "with the text empty")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "status", $$$ERROR($$$GeneralError, "OcuVendorText1910"))
    Do $$$AssertEquals(..Call(.tRows, 100, ..#SEAM, , , , .tFault), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "another vendor error fails the read")
    Do $$$AssertEquals($Get(tRows), "", "with no rows")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ "OcuVendorText1910"), "the vendor's text is not sent")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "log") _ "|" _ $ClassMethod(..#SEAM, "LoggedCode", 1), "1|" _ ##class(OcuPilot.Api.Error).#INTERNAL, "and is logged once")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText", 1) [ "OcuVendorText1910", "with the vendor's text")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "throw", 1)
    Do $$$AssertEquals(..Call(.tRows, 100, ..#SEAM, , , , .tFault), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a vendor call that throws fails the read")
    Do $$$AssertEquals($Get(tRows), "", "with no rows")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ "OcuVendorThrow1910"), "the thrown text is not sent")
    Do $$$AssertTrue(($ClassMethod(..#SEAM, "Count", "log") = 1) && ($ClassMethod(..#SEAM, "LoggedText", 1) [ "OcuVendorThrow1910"), "and is logged once")
}

/// <p>AC2: a caller missing a pair is refused 403 <code>PORT.ACCESSDENIED</code> naming it, before any
/// statement is prepared; another endpoint or type is 501, a body 500 and a cap of the wrong shape
/// 400, none preparing a statement.</p>
/// <p>Mutation (Rule 19): call <method>OcuPilot.Port.SqlActivityPort.Rows</method> before the gate --
/// the prepared count goes red.</p>
Method TestTheGateRefusesBeforeAnyStatement()
{
    Set tSeam = ..#SEAM
    Do $ClassMethod(tSeam, "Arm", "gate", 1)
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do $$$AssertEquals(..Call(.tRows, 100, tSeam, , , , .tFault) _ " " _ $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " %Admin_Operate:USE", "a caller without %Admin_Operate:USE is refused naming it")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do $$$AssertEquals(..Call(.tRows, 100, tSeam, , , , .tFault) _ " " _ $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " %DB_IRISSYS:READ", "a caller without %DB_IRISSYS:READ is refused naming it")
    Do $$$AssertEquals($ClassMethod(tSeam, "Count", "rows"), 0, "and no statement was prepared")
    Do $ClassMethod(tSeam, "Clear")
    Do $$$AssertEquals(..Call(.tRows, 100, tSeam, "Statements"), "501 " _ ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "another endpoint is not implemented")
    Do $$$AssertEquals(..Call(.tRows, 100, tSeam, , "GET"), "501 " _ ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "nor another type")
    Do $$$AssertEquals(..Call(.tRows, 100, tSeam, , , {"x": 1}), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a body is refused")
    Do $$$AssertEquals(..Call(.tRows, 0, tSeam), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION, "a cap of zero is refused")
    Do $$$AssertEquals($ClassMethod(tSeam, "Count", "rows"), 0, "none prepared a statement")
}

/// <p>The vendor surface the port names: every column its statement selects is a column of
/// <code>INFORMATION.SCHEMA.CURRENTSTATEMENTS</code>, the statement selects neither
/// <code>Parameters</code> nor <code>GetSQLStatement</code>, and <code>GetSQLStatement</code> keeps
/// the signature <method>OcuPilot.Port.SqlActivityPort.Text</method> calls.</p>
Method TestTheVendorSurface()
{
    Set tColumns = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT SqlFieldName FROM %Dictionary.CompiledProperty WHERE parent = 'INFORMATION.SCHEMA.CURRENTSTATEMENTS'")
    While tRS.%Next() {
        Set tColumns = tColumns _ $ListBuild(tRS.%GetData(1))
    }
    For tI = 1:1:$Length(..#COLUMNS, ",") {
        Set tColumn = $Piece(..#COLUMNS, ",", tI)
        Do $$$AssertTrue($ListFind(tColumns, tColumn) > 0, tColumn _ " is a column of the vendor's table")
        Do $$$AssertTrue($Locate($Parameter(..#PORT, "CURRENTSTATEMENTS"), "\b" _ tColumn _ "\b") > 0, "and the port's statement names it as a whole word")
    }
    Set tStatement = $ZConvert($Parameter(..#PORT, "CURRENTSTATEMENTS"), "U")
    Do $$$AssertTrue((tStatement '[ "PARAMETERS") && (tStatement '[ "GETSQLSTATEMENT") && (tStatement '[ "?"), "the statement selects no Parameters, calls no GetSQLStatement and binds nothing")
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("INFORMATION.SCHEMA.CURRENTSTATEMENTS||GetSQLStatement")
    Do $$$AssertTrue($IsObject(tMethod), "the vendor's GetSQLStatement is compiled")
    If '$IsObject(tMethod) Quit
    Do $$$AssertEquals(tMethod.ClassMethod _ "|" _ tMethod.SqlProc _ "|" _ tMethod.ReturnType _ "|" _ $Piece(tMethod.FormalSpec, ",", 1, 3), "1|1|%Library.String|ns:%String="""",hash:%String="""",*tSC=""""", "a public class method answering a string from a namespace, a hash and an output status")
}

}
