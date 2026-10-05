/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s data browser save on the instance (Story 19.8), over
/// <class>OcuPilot.Test.SqlSaveProbe</class>'s objects in <code>USER</code>, through the port's write
/// path way in: an update saved and a value changed since the read -- by case alone too -- answered
/// <code>changed</code>; every kind's value read by the data browser's own page comparing equal; NULL
/// guarded <code>IS NULL</code>, and NULL beside an empty string stored; an insert, and a delete answered
/// <code>gone</code> once its row is removed; the instance's own refusals; a view, a keyless table, a
/// table keyed only by a repeating ID column and a column grant leaving out the key refused before any
/// write, and an identity-keyed table saved; the column rules refused before any
/// write; the budget stopping a row and skipping the rest; a failed save's log lines carrying nothing of
/// the request; and, as real principals in child processes, the gate naming the missing pair, each
/// grant deciding its rows, and a text another account holds open still refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a <code>USER</code> namespace.
/// It creates and removes the probe objects, data included, and five principals, so it runs on a
/// throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <method>OcuPilot.Test.SqlConsoleProbe.Armed</method> reads 1. It reads the tail of
/// <code>messages.log</code>. The principals' password is generated for the run.</p>
Class OcuPilot.Test.SqlSaveLive Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlSaveProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

/// <p>The port with a two-second bound.</p>
Parameter FIXTURE = "OcuPilot.Test.SqlPortFixture";

/// <p>That port, able to answer every statement refused.</p>
Parameter SEAMS = "OcuPilot.Test.SqlBrowseFixture";

Parameter NAMESPACE = "USER";

Parameter EDIT = "OcuProbe198.Edit";

/// <p>The principals' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSaveLive creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe198" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "Fill")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p>The save of <var>pChanges</var> to <var>pTable</var> as this account, through <var>pPort</var>,
/// as one line (<method>OcuPilot.Test.SqlSaveProbe.Line</method>).</p>
Method Saved(pChanges As %DynamicArray, pTable As %String = {..#EDIT}, pPort As %String = {..#PORT}) As %String
{
    Quit $ClassMethod(..#PROBE, "Line", $ClassMethod(..#PROBE, "Save", ..#NAMESPACE, pTable, pChanges, pPort))
}

/// <p>Matrix rows Update and Concurrent change: an update whose value read still stands is saved with
/// row count 1; one whose value another session changed since the read -- by case alone, or wholly --
/// matches no row, answers <code>changed</code> and writes nothing.</p>
/// <p>Mutation (Rule 19): answer <code>saved</code> whenever the SQLCODE is 0 or more in
/// <method>OcuPilot.Port.SqlPort.SaveOutcome</method> -- the concurrent-change legs go red. Compose a
/// text column's guard with <code>=</code> in <method>OcuPilot.Port.SqlPort.SaveComposed</method> --
/// the case-only leg saves over the change and goes red.</p>
Method TestAnUpdateSavesAndAChangedValueIsNot()
{
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "abd"}}]), "saved 0:saved/1 saved=1 failed=0", "the update is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a"), "Name=abd|Note=<null>|Num=1.5", "and stored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Run", "UPDATE " _ ..#EDIT _ " SET Name = 'BEE' WHERE Code = 'b'"), 0, "another session changes b's name by case alone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Run", "UPDATE " _ ..#EDIT _ " SET Name = 'x' WHERE Code = 'c'"), 0, "and c's wholly")
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "b"}, "original": {"Name": "bee"}, "values": {"Name": "new"}}, {"op": "update", "key": {"Code": "c"}, "original": {"Name": "sea"}, "values": {"Name": "new"}}]), "saved 0:changed/0,1:changed/0 saved=0 failed=2", "each update over a changed value matches no row")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "b", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "c", "Name"), "Name=BEE Name=x", "and writes nothing")
}

/// <p>Matrix row Every kind: one row's NUMERIC, DOUBLE, DATE, TIMESTAMP, TIME, BIT and POSIXTIME
/// values, read by the data browser's own page in the ODBC form, each compare equal as the guard binds
/// them, so the update changing all seven is saved and stored.</p>
Method TestEveryKindComparesAsThePageReadIt()
{
    Set tRequest = ##class(OcuPilot.Test.SqlBrowseProbe).Request(..#EDIT, {"filters": {"Code": "a"}})
    Set tPage = ##class(OcuPilot.Test.SqlBrowseProbe).Browse(..#NAMESPACE, tRequest)
    If (tPage.%GetTypeOf("rows") '= "array") || (tPage.rows.%Size() '= 1) {
        Do $$$AssertTrue(0, "the page reads row a: " _ tPage.%ToJSON())
        Quit
    }
    Set tOriginal = {}
    Set tColumns = "Num,Dbl,Born,Stamp,Tm,Flag,Pt"
    Set tIterator = tPage.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        If $ListFind($ListFromString(tColumns), tColumn.name) Do tOriginal.%Set(tColumn.name, tPage.rows.%Get(0).%Get(tIndex), "string")
    }
    Do $$$AssertEquals(tOriginal.%Size(), 7, "the page read the seven values: " _ tOriginal.%ToJSON())
    Set tValues = {"Num": "2.25", "Dbl": "0.5", "Born": "2026-10-04", "Stamp": "2026-10-04 09:30:00", "Tm": "14:30:00", "Flag": "0", "Pt": "2026-10-04 10:11:12.5"}
    Set tChange = {"op": "update", "key": {"Code": "a"}}
    Do tChange.%Set("original", tOriginal)
    Do tChange.%Set("values", tValues)
    Do $$$AssertEquals(..Saved([(tChange)]), "saved 0:saved/1 saved=1 failed=0", "each value read compares equal, so the row is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", tColumns), "Num=2.25|Dbl=.5|Born=2026-10-04|Stamp=2026-10-04 09:30:00|Tm=14:30:00|Flag=0|Pt=2026-10-04 10:11:12.5", "and every new value is stored")
}

/// <p>Matrix row NULL / empty: a name read as NULL is guarded <code>IS NULL</code> and saved; then a
/// name set to <code>null</code> stores NULL and a note set to <code>""</code> stores an empty
/// string.</p>
Method TestNullIsGuardedAndStoredBesideEmpty()
{
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "e"}, "original": {"Name": null}, "values": {"Name": "eee"}}]), "saved 0:saved/1 saved=1 failed=0", "a NULL read is guarded IS NULL")
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "e"}, "original": {"Name": null}, "values": {"Name": "again"}}]), "saved 0:changed/0 saved=0 failed=1", "and no longer matches once the name is set")
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "e"}, "original": {"Name": "eee", "Note": "ne"}, "values": {"Name": null, "Note": ""}}]), "saved 0:saved/1 saved=1 failed=0", "a name to null and a note to empty")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "e"), "Name=<null>|Note=<empty>|Num=5", "store NULL beside an empty string")
}

/// <p>Matrix row Insert, delete: an insert is saved and stored; a delete of the same key twice in one
/// save is saved, then <code>gone</code>.</p>
Method TestAnInsertAndADeleteTwice()
{
    Do $$$AssertEquals(..Saved([{"op": "insert", "values": {"Code": "z", "Name": "zed"}}, {"op": "delete", "key": {"Code": "b"}}, {"op": "delete", "key": {"Code": "b"}}]), "saved 0:saved/1,1:saved/1,2:gone/0 saved=2 failed=1", "the insert, the delete, and the second delete gone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "z", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "b"), "Name=zed absent", "z added and b removed")
}

/// <p>Matrix row Instance refusal: a duplicate key answers <code>error</code> with the instance's
/// unique-check SQLCODE (-119 for this table's primary key) and a value past its column's precision
/// -105, each with the instance's message, beside a row that is saved,
/// since each row is its own statement.</p>
Method TestTheInstanceRefusesARowAndSavesTheNext()
{
    Set tAnswer = $ClassMethod(..#PROBE, "Save", ..#NAMESPACE, ..#EDIT, [{"op": "insert", "values": {"Code": "a", "Name": "dup"}}, {"op": "update", "key": {"Code": "b"}, "original": {"Num": "2"}, "values": {"Num": "12345.67"}}, {"op": "update", "key": {"Code": "c"}, "original": {"Name": "sea"}, "values": {"Name": "see"}}])
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Line", tAnswer), "saved 0:error/-119,1:error/-105,2:saved/1 saved=1 failed=2", "the duplicate and the precision refused, the third row saved")
    Do $$$AssertTrue($Select(tAnswer.%GetTypeOf("results") = "array": tAnswer.results.%Get(0).message '= "", 1: 0), "each refusal carries the instance's message")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "b", "Num") _ " " _ $ClassMethod(..#PROBE, "Row", "c", "Name"), "Name=abc Num=2 Name=see", "and only the third row changed")
}

/// <p>Matrix rows Column grant, Insert grant and Read only, as real principals: a column grant saves a
/// row changing its column and refuses, whole, a row also changing another; an insert grant saves an
/// insert of its columns and refuses one adding another, and any delete; a SELECT-only grant is refused
/// an update, an insert and a delete. Each refusal is SQLCODE -99 and writes nothing.</p>
Method TestEachGrantDecidesItsRows()
{
    Set tTable = ..#EDIT
    Set tUpdate = {"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "col"}}
    Set tBoth = {"op": "update", "key": {"Code": "b"}, "original": {"Name": "bee", "Num": "2"}, "values": {"Name": "col", "Num": "9"}}
    Set tLegs = []
    Do tLegs.%Push({"namespace": (..#NAMESPACE), "table": (tTable), "changes": [(tUpdate), (tBoth)]})
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "COLUSER"), tLegs.%ToJSON())
    Do $$$AssertEquals($Select($IsObject(tProbe): tProbe.%Get("username"), 1: ""), $Parameter(..#PROBE, "COLUSER"), "the probe ran as the principal: " _ $Select($IsObject(tProbe): tProbe.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "saved 0:saved/1,1:refused/-99 saved=1 failed=1", "UPDATE(Name) saves the name alone and refuses the row also changing Num")
    Set tLegs = [{"namespace": (..#NAMESPACE), "table": (tTable), "changes": [{"op": "insert", "values": {"Code": "i1", "Name": "ins"}}, {"op": "insert", "values": {"Code": "i2", "Name": "ins", "Num": "1"}}, {"op": "delete", "key": {"Code": "d"}}]}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "INSUSER"), tLegs.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "saved 0:saved/1,1:refused/-99,2:refused/-99 saved=1 failed=2", "INSERT(Code, Name) saves its insert and refuses one adding Num, and the delete")
    Set tLegs = [{"namespace": (..#NAMESPACE), "table": (tTable), "changes": [{"op": "update", "key": {"Code": "c"}, "original": {"Name": "sea"}, "values": {"Name": "ro"}}, {"op": "insert", "values": {"Code": "r1", "Name": "ro"}}, {"op": "delete", "key": {"Code": "f"}}]}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "ROUSER"), tLegs.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "saved 0:refused/-99,1:refused/-99,2:refused/-99 saved=0 failed=3", "SELECT alone is refused an update, an insert and a delete")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "b", "Name,Num") _ " " _ $ClassMethod(..#PROBE, "Row", "i1", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "i2") _ " " _ $ClassMethod(..#PROBE, "Row", "c", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "d", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "f", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "r1"), "Name=col Name=bee|Num=2 Name=ins absent Name=sea Name=dee Name=eff absent", "and only the admitted rows changed")
}

/// <p>Matrix row Held open: the composed update and delete, held prepared by this account, are still
/// refused SQLCODE -99 for a SELECT-only principal, and nothing changes.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in
/// <method>OcuPilot.Port.SqlPort.Executed</method> -- the principal's rows are saved and this goes
/// red.</p>
Method TestAHeldTextIsStillRefused()
{
    Set tRequest = ##class(OcuPilot.Test.SqlBrowseProbe).Request(..#EDIT)
    Set tSC = $ClassMethod(..#PORT, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "this account plans the table")
    If $$$ISERR(tSC) Quit
    Set tUpdate = {"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "held"}}
    Set tDelete = {"op": "delete", "key": {"Code": "f"}}
    Set tTexts = $ListBuild($ClassMethod(..#PORT, "SaveComposed", tPlan, tUpdate).text, $ClassMethod(..#PORT, "SaveComposed", tPlan, tDelete).text)
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlConsoleProbe).Hold(tTexts, .tHeld), 2, "this account holds both texts prepared")
    Set tLegs = [{"namespace": (..#NAMESPACE), "table": (..#EDIT), "changes": [(tUpdate), (tDelete)]}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "ROUSER"), tLegs.%ToJSON())
    Do ##class(OcuPilot.Test.SqlConsoleProbe).Release(.tHeld)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "saved 0:refused/-99,1:refused/-99 saved=0 failed=2", "the principal is refused -99 for each")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Name") _ " " _ $ClassMethod(..#PROBE, "Row", "f", "Name"), "Name=abc Name=eff", "and nothing changed")
}

/// <p>Matrix row Not writable: a view, a keyless table, a table keyed only by a column named ID that
/// repeats, and a column grant that leaves out the key are each refused 409
/// <code>EXPLORER.DATA.READONLY</code> before any write, while a table keyed by its identity column
/// saves.</p>
/// <p>Mutation (Rule 19): drop the key check from <method>OcuPilot.Port.SqlPort.Save</method> -- the
/// keyless leg runs its delete and goes red. Drop the <code>keyUnique</code> check -- the repeating ID's
/// delete removes both its rows and goes red.</p>
Method TestATableThatCannotBeWrittenIsRefused()
{
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Code": "a"}, "original": {"Name": "abc"}, "values": {"Name": "view"}}], "OcuProbe198.EditView"), "409 EXPLORER.DATA.READONLY ", "a view")
    Do $$$AssertEquals(..Saved([{"op": "delete", "key": {"N": "1"}}], "OcuProbe198.Comp"), "409 EXPLORER.DATA.READONLY ", "a keyless table")
    Do $$$AssertEquals(..Saved([{"op": "delete", "key": {"ID": "1"}}], "OcuProbe198.Dup"), "409 EXPLORER.DATA.READONLY ", "a table keyed only by a column named ID that repeats")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Value", "SELECT COUNT(*) FROM OcuProbe198.Dup WHERE ID = 1"), 2, "and both its rows stay")
    Set tPage = ""
    Set tSC = ##class(OcuPilot.Port.SqlPort).BrowsePlan(..#NAMESPACE, {"schema": "OcuProbe198", "table": "Dup"}, .tPlan, .tHttp, .tFault)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Port.SqlPort).BrowseRun(..#NAMESPACE, tPlan, .tPage, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tPage): tPage.key.%ToJSON() _ " " _ tPage.keyUnique, 1: $System.Status.GetErrorText(tSC)), "[""ID""] 0", "its page orders by ID and says no save may target it")
    Set tId = $ClassMethod(..#PROBE, "Value", "SELECT Id2 FROM OcuProbe198.Ident")
    Do $$$AssertEquals(..Saved([{"op": "update", "key": {"Id2": (tId _ "")}, "original": {"Name": "first"}, "values": {"Name": "renamed"}}], "OcuProbe198.Ident"), "saved 0:saved/1 saved=1 failed=0", "while a table keyed by its identity column saves")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Value", "SELECT Name FROM OcuProbe198.Ident"), "renamed", "and stores the row")
    Set tLegs = [{"namespace": (..#NAMESPACE), "table": "OcuProbe198.Pair", "changes": [{"op": "update", "key": {"A": "1", "B": "1"}, "original": {"Name": "one-one"}, "values": {"Name": "col"}}]}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "ROUSER"), tLegs.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "409 EXPLORER.DATA.READONLY ", "a column grant leaving out the key")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Name") _ " " _ $ClassMethod(..#PROBE, "Value", "SELECT COUNT(*) FROM OcuProbe198.Comp"), "Name=abc 1", "and nothing changed")
}

/// <p>Matrix rows Bad changes and Bad shape at the port: a key, identity, generated or stream column
/// among the values, a key member missing or extra, or values read naming other columns are refused 400
/// <code>EXPLORER.DATA.CHANGES</code>; an unknown operation is 400 <code>TOOL.ARGUMENTS</code>; each
/// before any write.</p>
Method TestBadChangesAreRefusedBeforeAnyWrite()
{
    For tCase = $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""original"":{""Code"":""a""},""values"":{""Code"":""k""}}]", ..#EDIT, "a key column"), $ListBuild("[{""op"":""insert"",""values"":{""Id2"":""9"",""Name"":""n""}}]", "OcuProbe198.Ident", "an identity column"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""original"":{""Shout"":""ABC""},""values"":{""Shout"":""X""}}]", ..#EDIT, "a computed column"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""original"":{""Memo"":""memo""},""values"":{""Memo"":""m""}}]", ..#EDIT, "a stream column"), $ListBuild("[{""op"":""delete"",""key"":{""Name"":""abc""}}]", ..#EDIT, "a key member missing"), $ListBuild("[{""op"":""delete"",""key"":{""Code"":""a"",""Name"":""abc""}}]", ..#EDIT, "a key member extra"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""original"":{""Note"":""""},""values"":{""Name"":""n""}}]", ..#EDIT, "values read naming another column") {
        Do $$$AssertEquals(..Saved($List(tCase, 1), $List(tCase, 2)), "400 EXPLORER.DATA.CHANGES ", $List(tCase, 3))
    }
    Do $$$AssertEquals(..Saved("[{""op"":""merge"",""values"":{""Name"":""n""}}]"), "400 TOOL.ARGUMENTS ", "an unknown operation")
    Do $$$AssertEquals(..Saved([{"op": "insert", "values": {"Name": "n"}}], "OcuProbe198.Nope"), "404 EXPLORER.DATA.NOTFOUND ", "an unknown table")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "a", "Code,Name,Shout") _ " " _ $ClassMethod(..#PROBE, "Value", "SELECT SUBSTRING(Memo, 1, 10) FROM " _ ..#EDIT _ " WHERE Code = 'a'"), "Code=a|Name=abc|Shout=ABC memo", "and nothing changed")
}

/// <p>Matrix row Bound: four rows whose every update waits a second, under a two-second budget -- the
/// first is saved, the second is interrupted, <code>stopped</code> and left unchanged, and the rest are
/// <code>skipped</code>.</p>
/// <p>Mutation (Rule 19): pass a bound of 0 to <method>OcuPilot.Port.SqlPort.Executed</method> in
/// <method>OcuPilot.Port.SqlPort.Save</method> -- every row runs to its end and this goes red.</p>
Method TestTheBudgetStopsARowAndSkipsTheRest()
{
    Set tChanges = []
    For tK = 1:1:4 Do tChanges.%Push({"op": "update", "key": {"K": (tK _ "")}, "original": {"Name": ("o" _ tK)}, "values": {"Name": ("n" _ tK)}})
    Set tStart = $ZHorolog
    Set tAnswer = $ClassMethod(..#PROBE, "Save", ..#NAMESPACE, "OcuProbe198.Slow", tChanges, ..#FIXTURE)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Line", tAnswer), "saved 0:saved/1,1:stopped,2:skipped,3:skipped saved=1 failed=3", "the first saved, the second stopped, the rest skipped")
    Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("results") = "array": tAnswer.results.%Get(1).%Get("seconds"), 1: ""), 2, "the stopped row names the budget")
    Do $$$AssertTrue(($ZHorolog - tStart) < 4, "within the budget")
    Set tRows = ""
    For tK = 1:1:4 Set tRows = tRows _ $ClassMethod(..#PROBE, "Value", "SELECT Name FROM OcuProbe198.Slow WHERE K = " _ tK) _ " "
    Do $$$AssertEquals(tRows, "n1 o2 o3 o4 ", "only the first row changed; the stopped row reads as it was")
}

/// <p>The gate (AD-29): without <code>%Development:USE</code> the save is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming the pair before any statement.</p>
Method TestTheGateNamesTheMissingPair()
{
    Set tLegs = [{"namespace": (..#NAMESPACE), "table": (..#EDIT), "changes": [{"op": "delete", "key": {"Code": "f"}}]}]
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "NODEVUSER"), tLegs.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "403 AUTH.NOPRIVILEGE %Development:USE", "without %Development:USE")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Row", "f", "Name"), "Name=eff", "and nothing changed")
}

/// <p>AC10: a save whose row the instance refuses with a message quoting its value, and a save whose
/// catalog read is refused, which logs its line, leave no log line carrying the table, the value or the
/// instance's answer (AD-39).</p>
/// <p>Mutation (Rule 19): log a row's message from <method>OcuPilot.Port.SqlPort.SaveOutcome</method>
/// -- this goes red.</p>
Method TestAFailedSaveLogsNothingOfTheRequest()
{
    Set tMark = "OcuProbe198Log" _ $Translate($ZTimeStamp, ",.", "")
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set tAnswer = $ClassMethod(..#PROBE, "Save", ..#NAMESPACE, ..#EDIT, [{"op": "insert", "values": {"Code": "a", "Name": (tMark)}}, {"op": "update", "key": {"Code": "b"}, "original": {"Num": "2"}, "values": {"Num": "12345678"}}])
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Line", tAnswer), "saved 0:error/-119,1:error/-105 saved=0 failed=2", "both rows are refused, each answered")
    Set ^||OcuProbe197Refused = tMark
    Set tAnswer = $ClassMethod(..#PROBE, "Save", ..#NAMESPACE, ..#EDIT, [{"op": "delete", "key": {"Code": (tMark)}}], ..#SEAMS)
    Kill ^||OcuProbe197Refused
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Line", tAnswer), "500 INTERNAL ", "a refused catalog read is refused 500")
    Set tLogged = 0
    Set tFound = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine [ """subsystem"":""sqlport""" Set tLogged = tLogged + 1
            If ($ZConvert(tLine, "U") [ "OCUPROBE198") || (tLine [ "12345678") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertTrue(tLogged >= 1, "the refused read wrote its log line: " _ tLogged)
    Do $$$AssertEquals(tFound, "", "and no line carries the table, a value or the instance's answer")
}

}
