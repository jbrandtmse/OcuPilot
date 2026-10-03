/// <p>Pins Story 18.19's journal record list (AD-21, AD-26, AD-36): Journal records and
/// <code>osmgmt.journalrecords.read</code> answer one read of the eight fields at the cap, from twice
/// the cap plus two asked; Next records continues in both orders, the read tool's too under a context
/// cap in reverse order; the filter keeps its column's
/// matches and an empty value sends no match key; a filter, offset or address outside its shape is
/// refused before any vendor call on the screen, the tool and the port; a principal who cannot read a
/// database lists none of its rows; no record value reaches the tool or the screen's read; and a read
/// still running at the async bound is refused <code>PORT.TIMEOUT</code>.</p>
/// <p>It seeds its own records: <method>OnBeforeAllTests</method> creates the probe database and 30
/// journaled sets in it (<method>OcuPilot.Test.JournalProbe.SeedProbeDatabase</method>) and a probe
/// principal, and <method>OnAfterAllTests</method> removes them and the task rows that principal
/// queued; the records stay in the journal file. It needs journaling on, a caller holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>DATABASEVARIABLE</parameter> reading <code>1</code>.</p>
Class OcuPilot.Test.JournalRecords Extends %UnitTest.TestCase
{

/// <p>The variable that arms the probe principal, set by <file>scripts/ci-throwaway.sh</file>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The variable that arms the probe database, set by <file>scripts/ci-throwaway.sh</file>.</p>
Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.JournalRecordList";

Parameter COUNTPORT = "OcuPilot.Test.JournalCountPort";

Parameter READFIXTURE = "OcuPilot.Test.JournalReadFixture";

Parameter TOOLFIXTURE = "OcuPilot.Test.JournalRecordToolFixture";

/// <p>The probe principal: Journal records' two pairs and no read on the probe database.</p>
Parameter PRINCIPAL = "OCUPROBE185RU:OCUPROBE185RUR:%Admin_Operate:U;%DB_IRISSYS:R";

/// <p>A comparison that is code, which no caller may send; harmless if it ever ran.</p>
Parameter INJECTION = "=1) x ""set ^||OcuInjected185=1"" //";

/// <p>A value no refusal may echo.</p>
Parameter ECHOVALUE = "OcuEchoed185";

Parameter FIELDS = "[""Address"",""TimeStamp"",""ProcessID"",""TypeName"",""ExtTypeName"",""InTransaction"",""GlobalNode"",""DatabaseName""]";

/// <p>The journal file the seeded records are in.</p>
Property PreparedFile As %String;

/// <p>That file's offset just before the seeded records, so a list from it reads this run's records
/// and none an earlier run left in the file.</p>
Property PreparedOffset As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFile = ""
    Set ..PreparedOffset = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalRecords creates a probe database, journaled records in it and a probe principal, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "SeedProbeDatabase", 1, .tFile, 30, .tOffset)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFile = tFile
    Set ..PreparedOffset = tOffset
    Quit $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(..#PRINCIPAL, ":", 1), $Piece(..#PRINCIPAL, ":", 2), $Translate($Piece(..#PRINCIPAL, ":", 3, *), ";", ","))
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveProbeTaskRows", .tRemoved)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>The probe filter's criteria over the seeded file, from this run's first record, with
/// <var>pExtra</var>'s members; a member <code>""</code> removes the criterion.</p>
Method Criteria(Output pCriteria, pExtra As %DynamicObject = "")
{
    Kill pCriteria
    Set pCriteria("file") = ..PreparedFile
    Set pCriteria("offset") = ..PreparedOffset
    Set pCriteria("value") = $Parameter(..#PROBE, "PROBEGLOBAL")
    If '$IsObject(pExtra) Quit
    Set tIterator = pExtra.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set pCriteria(tName) = tValue
        If tValue = "" Kill pCriteria(tName)
    }
}

/// <p>The read tool's arguments for the probe filter from this run's first record, at most
/// <var>pMax</var> rows.</p>
Method ToolArgs(pMax As %Integer) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("file", ..PreparedFile, "string")
    Do tArgs.%Set("offset", ..PreparedOffset, "string")
    Do tArgs.%Set("value", $Parameter(..#PROBE, "PROBEGLOBAL"), "string")
    Do tArgs.%Set("maxRows", pMax, "number")
    Quit tArgs
}

/// <p>The rows' <code>Address</code>es, in order, joined by spaces.</p>
ClassMethod Addresses(pRows As %DynamicArray) As %String
{
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tRow.%Get("Address")
    }
    Quit tOut
}

/// <p>The highest and lowest <code>Address</code> of <var>pRows</var>.</p>
ClassMethod Bounds(pRows As %DynamicArray, Output pLow As %Integer, Output pHigh As %Integer)
{
    Set pLow = ""
    Set pHigh = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tAddress = tRow.%Get("Address")
        If (pLow = "") || (tAddress < pLow) Set pLow = tAddress
        If (pHigh = "") || (tAddress > pHigh) Set pHigh = tAddress
    }
}

/// <p>The code of a fault, or <code>""</code>.</p>
ClassMethod Code(pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    Quit pFault.%Get("code")
}

/// <p>AC1, AC2: Journal records and its read tool answer the same ten probe rows at cap 10, the read
/// truncated and every row carrying exactly the eight fields, the first ten seeded in order; the
/// answer names the file it read.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.HALVEDROWTYPES</parameter> -&gt;
/// six rows, not truncated, and this goes red.</p>
Method TestTheScreenAndItsToolReadTheCapThroughOneRead()
{
    Do ..Criteria(.tCriteria)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 10, .tScreen, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen reads: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tRows = tScreen.%Get("rows")
    Do $$$AssertEquals(tRows.%Size() _ " " _ ''tScreen.%Get("truncated"), "10 1", "ten rows of the cap, truncated")
    Do $$$AssertEquals(tScreen.%Get("fields").%ToJSON(), ..#FIELDS, "the eight declared fields")
    Do $$$AssertEquals(tScreen.%Get("criteria").%Get("file"), ..PreparedFile, "and the answer names the file it read")
    Set tProbeDirectory = ##class(OcuPilot.Test.JournalProbe).DirectoryFor($Parameter(..#PROBE, "PROBESUFFIX"))
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = ""
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "Address,TimeStamp,ProcessID,TypeName,ExtTypeName,InTransaction,GlobalNode,DatabaseName", "row " _ (tIndex + 1) _ " carries exactly the eight fields")
        Do $$$AssertEquals(tRow.%Get("GlobalNode") _ " " _ tRow.%Get("DatabaseName"), "^OcuProbe185(" _ (tIndex + 1) _ ") " _ tProbeDirectory, "row " _ (tIndex + 1) _ " is the seeded record in order")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, ..ToolArgs(10), 1000, .tView, .tViewHttp, .tViewFault)
    Do $$$AssertStatusOK(tSC, "the read tool reads: " _ $Select($IsObject($Get(tViewFault)): tViewFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tView.%Get("rows").%ToJSON(), tRows.%ToJSON(), "the tool's rows are the screen's")
    Do $$$AssertEquals(''tView.%Get("truncated"), 1, "and truncated too")
}

/// <p>AC2: Next records continues from the page's own rows: in file order from its highest
/// <code>Address</code> plus 1, the next ten probe rows; in reverse order from its lowest minus 1, the
/// ten before; none repeated in either.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.JournalRecordRules</method> remove
/// <code>initialOffset</code> whatever it holds -&gt; the second page repeats the first and this goes
/// red.</p>
Method TestNextRecordsContinuesInBothOrders()
{
    For tOrder = "0", "1" {
        ; Order 1 reads from the file's end, where this run's records are the last probe records.
        Do ..Criteria(.tCriteria, {"order": (tOrder), "offset": ($Select(tOrder = "0": ..PreparedOffset, 1: ""))})
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 10, .tFirst, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tSC, "order " _ tOrder _ "'s first page reads")
        If $$$ISERR(tSC) Quit
        Do ..Bounds(tFirst.%Get("rows"), .tLow, .tHigh)
        Set tNext = $Select(tOrder = "0": tHigh + 1, 1: tLow - 1)
        Do ..Criteria(.tCriteria, {"order": (tOrder), "offset": (tNext)})
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 10, .tSecond, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tSC, "order " _ tOrder _ "'s next page reads")
        If $$$ISERR(tSC) Quit
        Set tRows = tSecond.%Get("rows")
        Do $$$AssertEquals(tRows.%Size(), 10, "order " _ tOrder _ "'s next page holds the next ten")
        Do ..Bounds(tRows, .tNextLow, .tNextHigh)
        If tOrder = "0" {
            Do $$$AssertTrue(tNextLow > tHigh, "every row comes after the first page's highest: " _ ..Addresses(tRows) _ " after " _ tHigh)
            Do $$$AssertEquals(tRows.%Get(0).%Get("GlobalNode"), "^OcuProbe185(11)", "starting at the eleventh")
        } Else {
            Do $$$AssertTrue(tNextHigh < tLow, "every row comes before the first page's lowest: " _ ..Addresses(tRows) _ " before " _ tLow)
            Do $$$AssertEquals(tRows.%Get(0).%Get("GlobalNode"), "^OcuProbe185(20)", "starting at the twentieth")
        }
        Set tRepeated = 0
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If (" " _ ..Addresses(tFirst.%Get("rows")) _ " ") [ (" " _ tRow.%Get("Address") _ " ") Set tRepeated = tRepeated + 1
        }
        Do $$$AssertEquals(tRepeated, 0, "order " _ tOrder _ ": no row repeated")
    }
}

/// <p>AC2, the read tool in reverse order: its <code>order</code> hint tells the caller to send
/// <code>direction</code> <code>desc</code> with order 1, and with it a context cap below the rows read
/// keeps the newest ten, and the offset hint's next page continues at the twentieth, none skipped or
/// repeated.</p>
/// <p>Mutation (Rule 19): drop the direction clause from the descriptor's <code>order</code> hint
/// -&gt; this goes red on the hint.</p>
Method TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tDeclaration.read.criteria.fields.%Get(2).hint [ "with 1, also send direction desc", "the order hint names the direction to send with order 1")
    Set tArgs = {"file": (..PreparedFile), "value": ($Parameter(..#PROBE, "PROBEGLOBAL")), "order": "1", "direction": "desc", "maxRows": 20}
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, tArgs, 10, .tFirst, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool reads in reverse order")
    If $$$ISERR(tSC) Quit
    Set tRows = tFirst.%Get("rows")
    Do $$$AssertEquals(tRows.%Size() _ " " _ ''tFirst.%Get("truncated") _ " " _ tRows.%Get(0).%Get("GlobalNode"), "10 1 ^OcuProbe185(30)", "the context cap keeps the ten newest, newest first")
    Do ..Bounds(tRows, .tLow, .tHigh)
    Do tArgs.%Set("offset", (tLow - 1) _ "", "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, tArgs, 10, .tSecond, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and its next page reads")
    If $$$ISERR(tSC) Quit
    Do ..Bounds(tSecond.%Get("rows"), .tNextLow, .tNextHigh)
    Do $$$AssertEquals(tSecond.%Get("rows").%Get(0).%Get("GlobalNode"), "^OcuProbe185(20)", "the next page starts at the twentieth, none skipped")
    Do $$$AssertTrue(tNextHigh < tLow, "and repeats none: " _ ..Addresses(tSecond.%Get("rows")) _ " before " _ tLow)
}

/// <p>The filter keeps its column's matches: <code>GlobalNode</code> <code>=</code> one seeded node
/// answers that one row, and <code>DatabaseName</code> <code>[</code> the probe directory answers only
/// rows on it.</p>
Method TestTheFilterKeepsItsColumnsMatches()
{
    Do ..Criteria(.tCriteria, {"operator": "=", "value": "^OcuProbe185(3)"})
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 10, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "an equals filter reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRead.%Get("rows").%Size() _ " " _ tRead.%Get("rows").%Get(0).%Get("GlobalNode"), "1 ^OcuProbe185(3)", "the one seeded node")
    Set tDirectory = ##class(OcuPilot.Test.JournalProbe).DirectoryFor($Parameter(..#PROBE, "PROBESUFFIX"))
    Do ..Criteria(.tCriteria, {"column": "DatabaseName", "value": "ocuprobe185d"})
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 40, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a database filter reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tRead.%Get("rows").%Size() >= 30, "it finds the seeded records at least: " _ tRead.%Get("rows").%Size())
    Set tIterator = tRead.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("DatabaseName") '= tDirectory Do $$$AssertEquals(tRow.%Get("DatabaseName"), tDirectory, "every row is on the probe database")
    }
}

/// <p>AC3: a filter with an empty value is sent with no match key -- the column and comparison take
/// their defaults, the value none -- and lists records of every global; a direct port call with a
/// column and a comparison and no value sends none either. AC2: the read at cap 10 asks the vendor
/// for 22 rows.</p>
/// <p>Mutation (Rule 19): drop the empty-value removal from
/// <method>OcuPilot.Port.AdminPort.JournalRecordRules</method> -&gt; the vendor is sent the column and
/// comparison and this goes red; empty <parameter>OcuPilot.Port.AdminPort.HALVEDROWTYPES</parameter>
/// -&gt; the vendor is asked 11 rows and this goes red.</p>
Method TestAnEmptyValueSendsNoMatchKey()
{
    Set tPort = ..#COUNTPORT
    Do $ClassMethod(tPort, "Reset")
    Kill tCriteria
    Set tCriteria("file") = ..PreparedFile
    Set tSC = $ClassMethod(..#READFIXTURE, "Execute", ..#SCREEN, 10, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read with no value reads")
    Set tSent = $ClassMethod(tPort, "SentKeys", "journal/record")
    Set tSentRows = $ClassMethod(tPort, "SentValue", "journal/record", "maxRows")
    Do $ClassMethod(tPort, "Reset")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tSent, "file,maxRows,reverse", "the vendor is sent no match key")
    Do $$$AssertEquals(tSentRows, 22, "and is asked twice the cap plus two rows, 22 for the cap of 10 (AD-26)")
    Do $$$AssertEquals(tRead.%Get("criteria").%Get("column") _ " " _ tRead.%Get("criteria").%Get("operator") _ " " _ tRead.%Get("criteria").%Get("value"), "GlobalNode [ ", "while the defaults are applied and echoed")
    Set tOther = 0
    Set tIterator = tRead.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '(tRow.%Get("GlobalNode") [ $Parameter(..#PROBE, "PROBEGLOBAL")) Set tOther = 1
    }
    Do $$$AssertTrue(tOther, "and it lists records of other globals")
    Kill tQuery
    Set tQuery("file") = ..PreparedFile
    Set tQuery("maxRows") = 4
    Set tQuery("matchColumnName") = "GlobalNode"
    Set tQuery("matchOperator") = "["
    Set tQuery("matchValue") = ""
    Set tSC = $ClassMethod(tPort, "Invoke", "Journal.Record", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tSent = $ClassMethod(tPort, "SentKeys", "journal/record")
    Do $ClassMethod(tPort, "Reset")
    Do $$$AssertStatusOK(tSC, "a direct call with no value reads")
    Do $$$AssertEquals(tSent, "file,maxRows", "and sends no match key either")
}

/// <p>AC3: a comparison that is code, a column outside the eight, a value with no column or no
/// comparison, and an offset or address that is not a whole number, or is above the highest address
/// a journal file holds, are refused before any vendor call: on the screen 400
/// <code>READ.CRITERION</code> for the closed choices, on the tool 400 <code>TOOL.ARGUMENTS</code>,
/// and on the port, the screen's offset and the tool's 400 <code>JOURNAL.FILTER.SHAPE</code> or
/// <code>JOURNAL.OFFSET.SHAPE</code>, the guard's list read included; no refusal echoes the value.</p>
/// <p>Mutation (Rule 19): drop the comparison check from
/// <method>OcuPilot.Port.AdminPort.JournalRecordRules</method> -&gt; the port leg's injection reaches
/// the vendor and goes red; drop the digit check -&gt; the offset legs go red; drop the
/// <parameter>OcuPilot.Port.AdminPort.JOURNALMAXADDRESS</parameter> bound -&gt; the two cases above it
/// go red.</p>
Method TestInjectionAndShapeAreRefusedBeforeAnyVendorCall()
{
    Set tPort = ..#COUNTPORT
    For tCase = "operator:" _ ..#INJECTION, "column:NewValue" {
        Do $ClassMethod(tPort, "Reset")
        Do ..Criteria(.tCriteria)
        Set tCriteria($Piece(tCase, ":", 1)) = $Piece(tCase, ":", 2, *)
        Set tSC = $ClassMethod(..#READFIXTURE, "Execute", ..#SCREEN, 10, .tRead, .tHttp, .tFault, .tCriteria)
        Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 READ.CRITERION 0", "the screen refuses " _ $Piece(tCase, ":", 1) _ " outside its options before any vendor call")
        Do $ClassMethod(tPort, "Reset")
        Set tArgs = {"file": (..PreparedFile), "value": "x"}
        Do tArgs.%Set($Piece(tCase, ":", 1), $Piece(tCase, ":", 2, *), "string")
        Set tSC = $ClassMethod(..#TOOLFIXTURE, "View", ..#SCREEN, tArgs, 1000, .tView, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 TOOL.ARGUMENTS 0", "the tool refuses it through its schema before any vendor call")
    }
    Set tShape = $Parameter("OcuPilot.Api.JournalError", "FILTERSHAPE")
    Set tOffset = $Parameter("OcuPilot.Api.JournalError", "OFFSETSHAPE")
    ; Each case is column, comparison, value: the comparison may itself hold the delimiter a string
    ; would use, so the cases are lists.
    Set tCases = $ListBuild($ListBuild("GlobalNode", ..#INJECTION, ..#ECHOVALUE), $ListBuild("NewValue", "[", ..#ECHOVALUE), $ListBuild("GlobalNode", "", ..#ECHOVALUE), $ListBuild("", "[", ..#ECHOVALUE))
    Set tPointer = 0
    While $ListNext(tCases, tPointer, tCase) {
        Do $ClassMethod(tPort, "Reset")
        Kill tQuery
        Set tQuery("file") = ..PreparedFile
        Set tQuery("maxRows") = 4
        Set tQuery("matchColumnName") = $List(tCase, 1)
        Set tQuery("matchOperator") = $List(tCase, 2)
        Set tQuery("matchValue") = $List(tCase, 3)
        Set tSC = $ClassMethod(tPort, "Invoke", "Journal.Record", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 " _ tShape _ " 0", "the port refuses column '" _ $List(tCase, 1) _ "' with comparison '" _ $List(tCase, 2) _ "' before any vendor call")
        Do $$$AssertTrue($IsObject($Get(tFault)) && '(tFault.%ToJSON() [ ..#ECHOVALUE) && '(tFault.%ToJSON() [ "OcuInjected185"), "and echoes nothing it was sent")
    }
    For tCase = "LIST|initialOffset|12a", "GET|address|-1", "GET|address|", "LIST|initialOffset|4294967296", "GET|address|99999999999999999999" {
        Do $ClassMethod(tPort, "Reset")
        Kill tQuery
        Set tQuery("file") = ..PreparedFile
        Set tQuery($Piece(tCase, "|", 2)) = $Piece(tCase, "|", 3)
        Set tSC = $ClassMethod(tPort, "Invoke", "Journal.Record", $Piece(tCase, "|", 1), .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 " _ tOffset _ " 0", "the port refuses " _ $Piece(tCase, "|", 2) _ " '" _ $Piece(tCase, "|", 3) _ "' before any vendor call")
    }
    Do $ClassMethod(tPort, "Reset")
    Do ..Criteria(.tCriteria, {"offset": "12a"})
    Set tSC = $ClassMethod(..#READFIXTURE, "Execute", ..#SCREEN, 10, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 " _ tOffset _ " 0", "and the screen's offset meets the port's refusal, before any vendor call")
    Do $ClassMethod(tPort, "Reset")
    Set tSC = $ClassMethod(..#TOOLFIXTURE, "View", ..#SCREEN, {"file": (..PreparedFile), "offset": "12a"}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault) _ " " _ $ClassMethod(tPort, "Calls"), "400 " _ tOffset _ " 0", "and so does the tool's, before any vendor call")
    Do $ClassMethod(tPort, "Reset")
}

/// <p>AC4: a principal holding Journal records' pairs and no read on the probe database lists none of
/// its rows, filtered to them or not; the vendor's list skips each one. It still lists a record on a
/// database it can read (<method>OcuPilot.Test.JournalProbe.SetReadable</method>), so the empty probe
/// list is a skip and not a refusal.</p>
/// <p>Mutation (Rule 19): grant the principal <code>%DB_OCUPROBE185D:R</code> -&gt; the probe rows are
/// listed and this goes red.</p>
Method TestAPrincipalWhoCannotReadADatabaseListsNoneOfItsRows()
{
    Set tDirectory = ##class(OcuPilot.Test.JournalProbe).DirectoryFor($Parameter(..#PROBE, "PROBESUFFIX"))
    Set tProbe = {"file": (..PreparedFile), "initialOffset": (..PreparedOffset), "maxRows": 22, "matchColumnName": "GlobalNode", "matchOperator": "[", "matchValue": ($Parameter(..#PROBE, "PROBEGLOBAL"))}
    Set tSC = ##class(OcuPilot.Test.JournalProbe).SetReadable(.tNode)
    Do $$$AssertStatusOK(tSC, "a record the principal can read is written")
    If $$$ISERR(tSC) Quit
    Set tReadable = {"file": (..PreparedFile), "initialOffset": (..PreparedOffset), "maxRows": 22, "matchColumnName": "GlobalNode", "matchOperator": "=", "matchValue": (tNode)}
    Set tPlan = [{"endpoint": "Journal.Record", "type": "LIST", "query": (tProbe)}, {"endpoint": "Journal.Record", "type": "LIST", "query": {"file": (..PreparedFile), "initialOffset": (..PreparedOffset), "maxRows": 200}}, {"endpoint": "Journal.Record", "type": "LIST", "query": (tReadable)}]
    Set tAnswer = $ClassMethod(..#PROBE, "RunAs", $Piece(..#PRINCIPAL, ":", 1), tPlan)
    Do ##class(OcuPilot.Test.JournalProbe).KillReadable()
    Do $$$AssertEquals(tAnswer.%Get("error"), "", "the principal's plan ran")
    If tAnswer.%Get("error") '= "" Quit
    Set tFiltered = tAnswer.%Get("steps").%Get(0)
    Do $$$AssertEquals(tFiltered.%Get("http") _ " " _ $Select($IsObject(tFiltered.%Get("result")): tFiltered.%Get("result").%Size(), 1: "none"), "200 0", "the probe filter lists no probe row: " _ tFiltered.%ToJSON())
    Set tAll = tAnswer.%Get("steps").%Get(1)
    Do $$$AssertEquals(tAll.%Get("http"), 200, "the unfiltered list reads")
    Set tSeen = 0
    If $IsObject(tAll.%Get("result")) {
        Set tIterator = tAll.%Get("result").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("DatabaseName") = tDirectory Set tSeen = tSeen + 1
        }
    }
    Do $$$AssertEquals(tSeen, 0, "and lists no row of the probe database either")
    Set tOwn = tAnswer.%Get("steps").%Get(2)
    Set tFirst = $Select($IsObject(tOwn.%Get("result")) && (tOwn.%Get("result").%Size() > 0): tOwn.%Get("result").%Get(0), 1: "")
    Do $$$AssertEquals(tOwn.%Get("http") _ " " _ $Select($IsObject(tFirst): tFirst.%Get("GlobalNode") _ " " _ tFirst.%Get("TypeName"), 1: "none"), "200 " _ tNode _ " SET", "while it lists the record on a database it can read: " _ tOwn.%ToJSON())
}

/// <p>AC6: no seeded value -- the marker every value starts with, or the markup value -- reaches the
/// read tool's result or the screen's read answer, over every seeded row.</p>
/// <p>Mutation (Rule 19): give the descriptor's read <code>SetKill.NewValue</code> and a
/// <code>rowGet</code> merging it, with the detail <code>GET</code> reading the newest file -&gt; the
/// marker assertions go red.</p>
Method TestNoRecordValueReachesTheToolOrTheScreenRead()
{
    Do ..Criteria(.tCriteria)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 40, .tScreen, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen reads every seeded row")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tScreen.%Get("rows").%Size(), 30, "all thirty")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, ..ToolArgs(40), 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and so does the tool")
    If $$$ISERR(tSC) Quit
    For tText = tScreen.%ToJSON(), tView.%ToJSON() {
        Do $$$AssertTrue('(tText [ $Parameter(..#PROBE, "PROBEMARKER")), "no answer carries the value marker")
        Do $$$AssertTrue('(tText [ $Parameter(..#PROBE, "PROBEMARKUP")), "nor the markup value")
    }
}

/// <p>The read tool called with no argument reads the newest listed file, and answers the rows a call
/// naming that file does; its echo reads the omitted file as empty (named limit 4).</p>
Method TestAToolCallWithNoArgumentReadsTheNewestFile()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, {}, 1000, .tEmpty, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "{} reads: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tEmpty.%Get("criteria").%Get("file"), "", "its echo reads the omitted file as empty")
    Set tNewest = ##class(OcuPilot.Test.JournalProbe).Newest()
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, {"maxRows": 10}, 1000, .tOmitted, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an omitted file reads")
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, {"file": (tNewest), "maxRows": 10}, 1000, .tNamed, .tHttp, .tFault))
    Do $$$AssertStatusOK(tSC, "and so does the newest file named")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tOmitted.%Get("rows").%Size() > 0, "the newest file answers records")
    Do $$$AssertEquals(..Addresses(tOmitted.%Get("rows")), ..Addresses(tNamed.%Get("rows")), "the same first records of the newest file")
}

/// <p>A record list still running at the port's async bound is refused whole, 503
/// <code>PORT.TIMEOUT</code>, with no partial row (named limit 2). <class>OcuPilot.Test.PortFixture</class>
/// answers every poll <code>Running</code> with the bound lowered to one second, so the vendor's own
/// task is queued and runs; the row it leaves is removed once it has ended.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.AwaitTask</method> answer 200 at the
/// bound instead of refusing -&gt; this goes red.</p>
Method TestAScanPastTheBoundIsRefusedTimeout()
{
    Set tFixture = "OcuPilot.Test.PortFixture"
    Do $ClassMethod(tFixture, "Clear")
    Set tBefore = $ClassMethod(tFixture, "TaskGuids")
    Do $ClassMethod(tFixture, "SetCannedAnswer", {"State": "Running", "TaskName": "", "FailureReason": "", "Result": {}}.%ToJSON())
    Do $ClassMethod(tFixture, "SetAsyncTimeout", 1)
    Do ..Criteria(.tCriteria)
    Set tRead = ""
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#SCREEN, 10, .tRead, .tHttp, .tFault, .tCriteria)
    Do $ClassMethod(tFixture, "Clear")
    Set tRemoved = ..RemoveOwnNewTaskRows(tBefore)
    Do $$$AssertStatusNotOK(tSC, "the read past the bound is refused")
    Do $$$AssertEquals($Get(tHttp) _ " " _ ..Code(.tFault), "503 PORT.TIMEOUT", "as 503 PORT.TIMEOUT")
    Do $$$AssertEquals(tRead, "", "with no partial row")
    Do $$$AssertEquals(tRemoved, 1, "and the one task row it queued is removed once it ends")
}

/// <p>Delete, as objects in <code>%SYS</code> (AD-37), each async task row the calling user queued
/// since <var>pBefore</var> (a <method>OcuPilot.Test.PortFixture.TaskGuids</method> list) once it has
/// ended, waiting at most <var>pWaitSeconds</var>; a row still running then is left to the retention
/// sweep. Answers how many were deleted.</p>
ClassMethod RemoveOwnNewTaskRows(pBefore As %List, pWaitSeconds As %Integer = 60) As %Integer
{
    Set tTaskClass = $Parameter("OcuPilot.Port.AdminPort", "ASYNCTASKCLASS")
    Set tTerminal = $ListBuild($Parameter(tTaskClass, "STATEFINISHED"), $Parameter(tTaskClass, "STATEFAILED"), $Parameter(tTaskClass, "STATECANCELED"))
    Set tUser = $Username
    Set tRemoved = 0
    Set tStart = $ZHorolog
    Set tOrigNS = $NAMESPACE
    Try {
        For {
            Set tPending = 0
            Set tGuids = ##class(OcuPilot.Test.PortFixture).TaskGuids()
            Set $NAMESPACE = "%SYS"
            Set tPointer = 0
            While $ListNext(tGuids, tPointer, tGuid) {
                If $ListFind(pBefore, tGuid) Continue
                Set tRow = $ClassMethod(tTaskClass, "%OpenId", tGuid)
                If '$IsObject(tRow) Continue
                Set tOwn = (tRow.Username = tUser)
                Set tEnded = ''$ListFind(tTerminal, tRow.State)
                Set tRow = ""
                If 'tOwn Continue
                If 'tEnded {
                    Set tPending = 1
                    Continue
                }
                If $$$ISOK($ClassMethod(tTaskClass, "%DeleteId", tGuid)) Set tRemoved = tRemoved + 1
            }
            Set $NAMESPACE = tOrigNS
            If 'tPending || (($ZHorolog - tStart) >= pWaitSeconds) Quit
            Hang 0.5
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRemoved
}

}
