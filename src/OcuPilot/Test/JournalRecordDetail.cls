/// <p>Pins Story 18.19's journal record detail route, <code>GET /journal/record</code> (AD-8, AD-21,
/// AD-36): it refuses a caller without Journal records' pairs by name with zero port calls; refuses an
/// address that is not a whole number and an unlisted file before the call for the record; answers a
/// seeded record's fields and values, each string cut at 1,000 characters and markup kept as text;
/// answers a record on a database the caller cannot read 404 <code>JOURNAL.RECORD.UNREADABLE</code>;
/// writes no value to <code>messages.log</code>; and no tool reaches it.</p>
/// <p>It seeds its own records (<method>OcuPilot.Test.JournalProbe.SeedProbeDatabase</method>) and two
/// probe principals in <method>OnBeforeAllTests</method>, and removes them, with the task rows a
/// principal queued, in <method>OnAfterAllTests</method>. It needs journaling on, a caller holding
/// <code>%All</code>, OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s test account,
/// and <parameter>ARMINGVARIABLE</parameter> and <parameter>DATABASEVARIABLE</parameter> reading
/// <code>1</code>.</p>
Class OcuPilot.Test.JournalRecordDetail Extends %UnitTest.TestCase
{

/// <p>The variable that arms the probe principals, set by <file>scripts/ci-throwaway.sh</file>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The variable that arms the probe database, set by <file>scripts/ci-throwaway.sh</file>.</p>
Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter FIXTURE = "OcuPilot.Test.JournalRecordDetailFixture";

Parameter COUNTPORT = "OcuPilot.Test.JournalCountPort";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.JournalRecordList";

/// <p>The route, relative to the API base.</p>
Parameter ROUTE = "/journal/record";

/// <p>The principals, each <code>user:role:resources</code> beyond the install namespace's code read:
/// Journal records' two pairs and no read on the probe database; and the system database's read
/// without <code>%Admin_Operate</code>.</p>
Parameter PRINCIPALS = "OCUPROBE185RD:OCUPROBE185RDR:%Admin_Operate:U;%DB_IRISSYS:R,OCUPROBE185RG:OCUPROBE185RGR:%DB_IRISSYS:R";

/// <p>A name no journal file list answers.</p>
Parameter FOREIGNFILE = "/tmp/x.001";

/// <p>The journal file the seeded records are in.</p>
Property PreparedFile As %String;

/// <p>Each seeded record's address, subscripted by its index.</p>
Property PreparedAddress [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFile = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalRecordDetail creates a probe database, journaled records in it and probe principals, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "SeedProbeDatabase", 1, .tFile, 30, .tOffset)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFile = tFile
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, *), ";", ","))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("file") = tFile
    Set tQuery("initialOffset") = tOffset
    Set tQuery("maxRows") = 40
    Set tQuery("matchColumnName") = "GlobalNode"
    Set tQuery("matchOperator") = "["
    Set tQuery("matchValue") = $Parameter(..#PROBE, "PROBEGLOBAL")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Journal.Record", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set ..PreparedAddress(+$Piece($Piece(tRow.%Get("GlobalNode"), "(", 2), ")", 1)) = tRow.%Get("Address")
    }
    If $Get(..PreparedAddress(30)) = "" Quit $$$ERROR($$$GeneralError, "the seeded records were not all listed: " _ tRows.%Size())
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveProbeTaskRows", .tRemoved)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>The route for <var>pFile</var> and <var>pAddress</var> in this process through
/// <parameter>FIXTURE</parameter>: <code>{status, body, calls}</code>.</p>
ClassMethod Route(pFile As %String, pAddress As %String) As %DynamicObject
{
    Quit $ClassMethod(..#PROBE, "RouteRead", pFile, pAddress)
}

/// <p>The code of a route answer's envelope, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("body")) Quit ""
    Quit pAnswer.%Get("body").%Get("code")
}

/// <p>The user name of <parameter>PRINCIPALS</parameter>' entry <var>pIndex</var>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>The one route step a probe principal ran, or an object carrying <code>error</code>.</p>
Method RouteAs(pUser As %String, pAddress As %String) As %DynamicObject
{
    Set tAnswer = $ClassMethod(..#PROBE, "RunAs", pUser, [{"route": "record", "file": (..PreparedFile), "address": (pAddress)}])
    If tAnswer.%Get("error") '= "" Quit tAnswer
    Quit tAnswer.%Get("steps").%Get(0)
}

/// <p>AC5: a caller without Journal records' <code>%Admin_Operate:USE</code> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming that pair, with zero port calls.</p>
/// <p>Mutation (Rule 19): remove the gate call from
/// <method>OcuPilot.Area.OsMgmt.JournalRecordDetail.HandleGet</method> -&gt; the port is called and
/// this goes red on its count.</p>
Method TestTheRouteRefusesACallerWithoutThePairsWithZeroPortCalls()
{
    Set tStep = ..RouteAs(..User(2), ..PreparedAddress(1))
    Do $$$AssertEquals(tStep.%Get("error"), "", "the principal's route ran")
    Set tDetail = $Select($IsObject(tStep.%Get("body")) && $IsObject(tStep.%Get("body").%Get("detail")): tStep.%Get("body").%Get("detail").%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tStep.%Get("status") _ " " _ ..Code(tStep) _ " " _ tDetail, "403 AUTH.NOPRIVILEGE %Admin_Operate:USE", "refused naming the pair: " _ tStep.%ToJSON())
    Do $$$AssertEquals(tStep.%Get("calls"), 0, "with zero port calls")
}

/// <p>AC3, AC5: an address that is not a whole number, or none, is refused 400
/// <code>JOURNAL.OFFSET.SHAPE</code> with zero port calls; an unlisted file 404
/// <code>JOURNAL.FILE.UNLISTED</code> after the guard's one list read, with no call for the record and
/// no echo of the name.</p>
/// <p>Mutation (Rule 19): drop the digit check from
/// <method>OcuPilot.Port.AdminPort.JournalRecordRules</method> -&gt; the address legs reach the vendor
/// and go red.</p>
Method TestTheAddressAndTheFileAreCheckedBeforeTheRecordIsRead()
{
    For tAddress = "-1", "12a", "" {
        Set tAnswer = ..Route(..PreparedFile, tAddress)
        Do $$$AssertEquals(tAnswer.%Get("status") _ " " _ ..Code(tAnswer) _ " " _ tAnswer.%Get("calls"), "400 JOURNAL.OFFSET.SHAPE 0", "address '" _ tAddress _ "' is refused before any port call")
    }
    Set tAnswer = ..Route(..#FOREIGNFILE, ..PreparedAddress(1))
    Do $$$AssertEquals(tAnswer.%Get("status") _ " " _ ..Code(tAnswer), "404 JOURNAL.FILE.UNLISTED", "an unlisted file is refused")
    Do $$$AssertEquals(tAnswer.%Get("calls"), 1, "after the guard's one list read, with no call for the record")
    Do $$$AssertTrue('(tAnswer.%ToJSON() [ ..#FOREIGNFILE), "and the refusal does not name the file")
}

/// <p>AC5: a seeded record answers its fields and values, flattened: a short value whole, the
/// 1,500-character value cut to 1,000 ending in U+2026, and the markup value verbatim; and a cut never
/// keeps half a surrogate pair.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.JournalRecordDetail.Cut</method> answer its
/// value whole -&gt; the long value's leg goes red; drop its surrogate step -&gt; the pair's leg goes
/// red.</p>
Method TestARecordAnswersItsFieldsAndValuesCutAtOneThousand()
{
    Set tDirectory = ##class(OcuPilot.Test.JournalProbe).DirectoryFor($Parameter(..#PROBE, "PROBESUFFIX"))
    Set tAnswer = ..Route(..PreparedFile, ..PreparedAddress(1))
    Do $$$AssertEquals(tAnswer.%Get("status"), 200, "a seeded record is answered: " _ $Extract(tAnswer.%ToJSON(), 1, 300))
    Set tRecord = $Select($IsObject(tAnswer.%Get("body")): tAnswer.%Get("body").%Get("record"), 1: "")
    If '$IsObject(tRecord) {
        Do $$$AssertTrue(0, "as {record}")
        Quit
    }
    Set tKeys = ""
    Set tIterator = tRecord.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "TypeName,ExtTypeName,PrevAddress,NextAddress,TimeStamp,InTransaction,ProcessID,JobID,RemoteSystemID,ECPSystemID,ClusterSequence,Collation,DatabaseName,GlobalNode,GlobalReference,MirrorDatabaseName,NewValue,NumberOfValues,OldValue", "the top-level fields and the set's members, flattened")
    Do $$$AssertEquals(tRecord.%Get("TypeName") _ " " _ tRecord.%Get("GlobalNode") _ " " _ tRecord.%Get("DatabaseName"), "SET ^OcuProbe185(1) " _ tDirectory, "the seeded set")
    Do $$$AssertEquals(tRecord.%Get("NewValue"), $Parameter(..#PROBE, "PROBEMARKER") _ 1, "with its new value")
    Do $$$AssertTrue(tRecord.%Get("GlobalReference") [ "OcuProbe185(1)", "and its global reference: " _ tRecord.%Get("GlobalReference"))
    Do $$$AssertEquals(tRecord.%GetTypeOf("InTransaction"), "boolean", "each value in the vendor's own type")
    Set tAnswer = ..Route(..PreparedFile, ..PreparedAddress(15))
    Set tValue = $Select($IsObject(tAnswer.%Get("body")) && $IsObject(tAnswer.%Get("body").%Get("record")): tAnswer.%Get("body").%Get("record").%Get("NewValue"), 1: "")
    Do $$$AssertEquals($Length(tValue) _ " " _ $Ascii($Extract(tValue, *)), "1000 8230", "the 1,500-character value is cut at 1,000, ending in U+2026")
    Do $$$AssertEquals($Extract(tValue, 1, 19), $Parameter(..#PROBE, "PROBEMARKER") _ 15, "and keeps its start")
    Set tAnswer = ..Route(..PreparedFile, ..PreparedAddress(16))
    Set tValue = $Select($IsObject(tAnswer.%Get("body")) && $IsObject(tAnswer.%Get("body").%Get("record")): tAnswer.%Get("body").%Get("record").%Get("NewValue"), 1: "")
    Do $$$AssertEquals(tValue, $Parameter(..#PROBE, "PROBEMARKUP"), "the markup value is answered as it is, text")
    Set tPaired = $Translate($Justify("", 998), " ", "a") _ $Char(55357, 56832) _ "bbb"
    Set tCut = ##class(OcuPilot.Area.OsMgmt.JournalRecordDetail).Cut(tPaired)
    Do $$$AssertEquals($Length(tCut) _ " " _ $Ascii($Extract(tCut, *)) _ " " _ $Ascii($Extract(tCut, * - 1)), "999 8230 97", "a cut that would keep half a surrogate pair keeps one character fewer")
}

/// <p>AC4: a principal holding Journal records' pairs and no read on the probe database is answered
/// 404 <code>JOURNAL.RECORD.UNREADABLE</code> for a seeded record, as for an address holding no
/// record, and 200 for a record on a database it can read
/// (<method>OcuPilot.Test.JournalProbe.SetReadable</method>).</p>
/// <p>Mutation (Rule 19): map the port's <code>PORT.NOTFOUND</code> to itself in
/// <method>OcuPilot.Area.OsMgmt.JournalRecordDetail.RenderRefusal</method> -&gt; this goes red on its
/// code.</p>
Method TestARecordOnAnUnreadableDatabaseIsRefusedUnreadable()
{
    Set tStep = ..RouteAs(..User(1), ..PreparedAddress(1))
    Do $$$AssertEquals(tStep.%Get("error"), "", "the principal's route ran")
    Do $$$AssertEquals(tStep.%Get("status") _ " " _ ..Code(tStep), "404 JOURNAL.RECORD.UNREADABLE", "a record on a database it cannot read: " _ tStep.%ToJSON())
    Do $$$AssertTrue('(tStep.%ToJSON() [ $Parameter(..#PROBE, "PROBEMARKER")), "and no value reaches it")
    Set tAnswer = ..Route(..PreparedFile, ..PreparedAddress(1) + 1)
    Do $$$AssertEquals(tAnswer.%Get("status") _ " " _ ..Code(tAnswer), "404 JOURNAL.RECORD.UNREADABLE", "as an address that holds no record is")
    Set tSC = ##class(OcuPilot.Test.JournalProbe).SetReadable(.tNode)
    Do $$$AssertStatusOK(tSC, "a record the principal can read is written")
    Kill tQuery
    Set tQuery("file") = ..PreparedFile
    Set tQuery("initialOffset") = ..PreparedAddress(30)
    Set tQuery("maxRows") = 10
    Set tQuery("matchColumnName") = "GlobalNode"
    Set tQuery("matchOperator") = "="
    Set tQuery("matchValue") = tNode
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Journal.Record", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tAddress = $Select($$$ISOK(tSC) && $IsObject($Get(tRows)) && (tRows.%Size() > 0): tRows.%Get(0).%Get("Address"), 1: "")
    Do $$$AssertTrue(tAddress '= "", "the readable record is listed")
    Set tStep = ..RouteAs(..User(1), tAddress)
    Do ##class(OcuPilot.Test.JournalProbe).KillReadable()
    Set tRecord = $Select($IsObject(tStep.%Get("body")) && $IsObject(tStep.%Get("body").%Get("record")): tStep.%Get("body").%Get("record"), 1: "")
    Do $$$AssertEquals(tStep.%Get("status") _ " " _ $Select($IsObject(tRecord): tRecord.%Get("GlobalNode"), 1: "none"), "200 " _ tNode, "while a record on a database it can read opens: " _ $Extract(tStep.%ToJSON(), 1, 300))
}

/// <p>AC5, AC6: over the wire the route answers 200 JSON <code>{record}</code> to the test account;
/// after the list, the read tool and the route have read seeded records, in process and over the wire,
/// no <code>messages.log</code> line carries a seeded value; and no tool reaches the route: Journal
/// records' one tool is its read, and no tool class names <code>Journal.Record</code> as its
/// endpoint.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.JournalRecordDetail.HandleGet</method> log
/// the record's new value -&gt; the log leg goes red.</p>
Method TestTheRouteAnswersOverTheWireLogsNoValueAndNoToolReachesIt()
{
    Set tFrom = $ClassMethod(..#PROBE, "LineCount", "messages.log")
    Do $$$AssertTrue(tFrom > 0, "messages.log is read: " _ tFrom)
    Kill tCriteria
    Set tCriteria("file") = ..PreparedFile
    Set tCriteria("offset") = ..PreparedAddress(1)
    Set tCriteria("value") = $Parameter(..#PROBE, "PROBEGLOBAL")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 40, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the list reads the seeded records")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, {"file": (..PreparedFile), "offset": (..PreparedAddress(1) _ ""), "value": ($Parameter(..#PROBE, "PROBEGLOBAL")), "maxRows": 40}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and so does the read tool")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ROUTE _ "?file=" _ $ZConvert(..PreparedFile, "O", "URL") _ "&address=" _ ..PreparedAddress(15)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request was sent")
    Do $$$AssertEquals(tStatus, 200, "the route answers over the wire: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tAnswer = ""
    }
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("record")) && (tAnswer.%Get("record").%Get("GlobalNode") = "^OcuProbe185(15)"), "as {record}, the seeded record")
    Do ..Route(..PreparedFile, ..PreparedAddress(16))
    Do ..RouteAs(..User(1), ..PreparedAddress(2))
    Set tLines = $ClassMethod(..#PROBE, "LinesAfter", "messages.log", tFrom)
    Set tCarried = 0
    Set tIterator = tLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If (tLine [ $Parameter(..#PROBE, "PROBEMARKER")) || (tLine [ $Parameter(..#PROBE, "PROBEMARKUP")) Set tCarried = tCarried + 1
    }
    Do $$$AssertEquals(tCarried, 0, "no messages.log line carries a seeded value, of " _ tLines.%Size() _ " new")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tools list")
    If $$$ISERR(tSC) Quit
    Set tOwn = ""
    Set tNamed = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If tTool.%Get("descriptor") = ..#SCREEN Set tOwn = tOwn _ $Select(tOwn = "": "", 1: ",") _ tTool.%Get("name")
        Set tClass = tTool.%Get("class")
        If tClass = ##class(OcuPilot.Screen.Tool.Registry).ReadToolClass() Continue
        If (tClass '= "") && ##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||Endpoint") && ($ClassMethod(tClass, "Endpoint") = "Journal.Record") Set tNamed = tNamed _ tTool.%Get("name") _ " "
    }
    Do $$$AssertEquals(tOwn, "osmgmt.journalrecords.read", "Journal records' one tool is its read")
    Do $$$AssertEquals(tNamed, "", "and no tool names Journal.Record as its endpoint")
}

}
