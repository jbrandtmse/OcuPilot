/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s data browser save rules with no SQL object (Story
/// 19.8): every refusal of a save's shape (<method>OcuPilot.Port.SqlPort.SaveChanges</method>), every
/// column rule (<method>OcuPilot.Port.SqlPort.ChangeProblem</method>), the statements composed for an
/// update, an insert and a delete with the guard each kind takes and the order values bind in
/// (<method>OcuPilot.Port.SqlPort.SaveComposed</method>), which columns a save may change and set, how
/// the instance's answer becomes each row's outcome, the script a save renders with no value in it, and
/// <class>OcuPilot.Screen.Tool.ExplorerSqlDataSave</class>'s declarations and value parsing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It creates nothing.</p>
Class OcuPilot.Test.SqlSave Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlDataSave";

/// <p>A plan of the shape <method>OcuPilot.Port.SqlPort.BrowsePlan</method> answers, for a table keyed
/// by <code>Code</code> and <code>Part</code>.</p>
ClassMethod Plan() As %DynamicObject
{
    Quit {
        "table": {"schema": "Probe", "name": "Ta\"ble", "type": "table"},
        "key": ["Code", "Part"],
        "columns": [
            {"name": "Code", "kind": "text", "key": true, "identity": false, "generated": false},
            {"name": "Name", "kind": "text", "key": false, "identity": false, "generated": false},
            {"name": "Num", "kind": "number", "key": false, "identity": false, "generated": false},
            {"name": "Born", "kind": "date", "key": false, "identity": false, "generated": false},
            {"name": "Part", "kind": "number", "key": true, "identity": false, "generated": false},
            {"name": "Seq", "kind": "number", "key": false, "identity": true, "generated": false},
            {"name": "Calc", "kind": "text", "key": false, "identity": false, "generated": true},
            {"name": "Memo", "kind": "stream", "key": false, "identity": false, "generated": false},
            {"name": "Blob", "kind": "binary", "key": false, "identity": false, "generated": false}
        ]
    }
}

/// <p>Matrix row Bad shape: text that is not a JSON array, holds no change or more than 100, or runs
/// past 1,000,000 characters; a change that is not an object, names an unknown operation or carries a
/// member its operation does not; a key that is not an object of strings; values that are empty, hold
/// a number or a value of 32,768 characters; a name with a control character, or named twice ignoring
/// case -- each is refused with a sentence that carries no value. Each operation's own shape is
/// accepted, a <code>null</code> value and an empty string among them.</p>
/// <p>Mutation (Rule 19): accept 101 changes in <method>OcuPilot.Port.SqlPort.SaveChanges</method> --
/// the 101 leg goes red.</p>
Method TestSaveChangesRefusesEachShape()
{
    Set tLong = $Translate($Justify("", 32768), " ", "v")
    Set tMany = []
    For tI = 1:1:101 Do tMany.%Push({"op": "delete", "key": {"Code": "x"}})
    Set tWide = []
    Do tWide.%Push({"op": "insert", "values": {"Name": ($Translate($Justify("", 32000), " ", "w"))}})
    For tI = 1:1:31 Do tWide.%Push(tWide.%Get(0))
    For tCase = $ListBuild("", "empty text"), $ListBuild("{", "text that is not JSON"), $ListBuild("{}", "an object"), $ListBuild("[]", "no change"), $ListBuild(tMany.%ToJSON(), "101 changes"), $ListBuild(tWide.%ToJSON(), "over 1,000,000 characters"), $ListBuild("[1]", "a change that is not an object"), $ListBuild("[{""op"":""merge"",""values"":{""Name"":""x""}}]", "an unknown op"), $ListBuild("[{""values"":{""Name"":""x""}}]", "no op"), $ListBuild("[{""op"":""insert"",""values"":{""Name"":""x""},""key"":{""Code"":""a""}}]", "an insert carrying a key"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""values"":{""Name"":""x""}}]", "an update with no original"), $ListBuild("[{""op"":""delete"",""key"":{""Code"":1}}]", "a key value that is a number"), $ListBuild("[{""op"":""delete"",""key"":{""Code"":null}}]", "a key value that is null"), $ListBuild("[{""op"":""delete"",""key"":{}}]", "an empty key"), $ListBuild("[{""op"":""insert"",""values"":{}}]", "empty values"), $ListBuild("[{""op"":""insert"",""values"":{""Name"":5}}]", "a value that is a number"), $ListBuild("[{""op"":""insert"",""values"":{""Name"":""" _ tLong _ """}}]", "a value of 32,768 characters"), $ListBuild("[{""op"":""update"",""key"":{""Code"":""a""},""original"":{""Name"":true},""values"":{""Name"":""x""}}]", "a value read that is a boolean"), $ListBuild("[{""op"":""insert"",""values"":{""Na\u0001me"":""x""}}]", "a name with a control character"), $ListBuild("[{""op"":""insert"",""values"":{""Name"":""x"",""NAME"":""y""}}]", "a name twice ignoring case") {
        Set tOk = $ClassMethod(..#PORT, "SaveChanges", $List(tCase, 1), .tChanges, .tProblem)
        Do $$$AssertTrue('tOk && (tProblem '= "") && '$IsObject(tChanges), $List(tCase, 2) _ " is refused: " _ tProblem)
        Do $$$AssertTrue((tProblem '[ "vvvv") && (tProblem '[ "wwww"), $List(tCase, 2) _ ": the sentence carries no value")
    }
    Set tText = "[{""op"":""update"",""key"":{""Code"":""a"",""Part"":""1""},""original"":{""Name"":null,""Num"":""1.5""},""values"":{""Name"":"""",""Num"":null}},{""op"":""insert"",""values"":{""Code"":""z"",""Name"":""zed""}},{""op"":""delete"",""key"":{""Code"":""b"",""Part"":""2""}}]"
    Set tOk = $ClassMethod(..#PORT, "SaveChanges", tText, .tChanges, .tProblem)
    Do $$$AssertTrue(tOk && (tProblem = ""), "each operation's own shape is accepted: " _ tProblem)
    Do $$$AssertEquals($Select($IsObject(tChanges): tChanges.%Size(), 1: 0), 3, "as three changes")
}

/// <p>Matrix row Bad changes: a key member missing or extra, a key, identity, generated, stream, binary
/// or unlisted column among an update's values, values read naming other columns than the values set,
/// and an identity among an insert's values are each refused; an insert may set a key column, and a
/// delete names exactly the key.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.SqlPort.Editable</method> admit a generated column
/// -- the generated leg goes red.</p>
Method TestChangeProblemHoldsTheColumnRules()
{
    Set tPlan = ..Plan()
    Set tUpdate = "{""op"":""update"",""key"":{""Code"":""a"",""Part"":""1""},""original"":{""%1"":""o""},""values"":{""%1"":""n""}}"
    For tCase = $ListBuild("{""op"":""delete"",""key"":{""Code"":""a""}}", "a key member missing"), $ListBuild("{""op"":""delete"",""key"":{""Code"":""a"",""Part"":""1"",""Name"":""x""}}", "a key member extra"), $ListBuild($Replace(tUpdate, "%1", "Code"), "a key column among the values"), $ListBuild($Replace(tUpdate, "%1", "Seq"), "an identity column"), $ListBuild($Replace(tUpdate, "%1", "Calc"), "a generated column"), $ListBuild($Replace(tUpdate, "%1", "Memo"), "a stream column"), $ListBuild($Replace(tUpdate, "%1", "Blob"), "a binary column"), $ListBuild($Replace(tUpdate, "%1", "Nope"), "an unlisted column"), $ListBuild($Replace(tUpdate, "%1", "name"), "a column in another case"), $ListBuild("{""op"":""update"",""key"":{""Code"":""a"",""Part"":""1""},""original"":{""Num"":""1""},""values"":{""Name"":""n""}}", "values read naming another column"), $ListBuild("{""op"":""update"",""key"":{""Code"":""a"",""Part"":""1""},""original"":{""Name"":""o"",""Num"":""1""},""values"":{""Name"":""n""}}", "values read naming an extra column"), $ListBuild("{""op"":""insert"",""values"":{""Seq"":""9"",""Name"":""n""}}", "an identity among an insert's values") {
        Set tProblem = $ClassMethod(..#PORT, "ChangeProblem", tPlan, ##class(%DynamicArray).%FromJSON("[" _ $List(tCase, 1) _ "]"))
        Do $$$AssertTrue(tProblem '= "", $List(tCase, 2) _ " is refused: " _ tProblem)
    }
    For tCase = $ListBuild($Replace(tUpdate, "%1", "Name"), "an update of an editable column"), $ListBuild("{""op"":""insert"",""values"":{""Code"":""z"",""Part"":""3"",""Name"":""zed""}}", "an insert setting the key"), $ListBuild("{""op"":""delete"",""key"":{""Part"":""1"",""Code"":""a""}}", "a delete naming the key in another order") {
        Set tProblem = $ClassMethod(..#PORT, "ChangeProblem", tPlan, ##class(%DynamicArray).%FromJSON("[" _ $List(tCase, 1) _ "]"))
        Do $$$AssertEquals(tProblem, "", $List(tCase, 2) _ " passes")
    }
}

/// <p>Which columns a save may change and set: not a key, identity, generated, stream or binary column
/// on an existing row; a key column on a new one.</p>
Method TestEditableAndInsertable()
{
    Set tOut = ""
    Set tIterator = ..Plan().columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tOut = tOut _ tColumn.name _ "=" _ $ClassMethod(..#PORT, "Editable", tColumn) _ $ClassMethod(..#PORT, "Insertable", tColumn) _ " "
    }
    Do $$$AssertEquals(tOut, "Code=01 Name=11 Num=11 Born=11 Part=01 Seq=00 Calc=00 Memo=00 Blob=00 ", "editable, then insertable, per column")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Editable", "") _ $ClassMethod(..#PORT, "Insertable", ""), "00", "and nothing for no column")
}

/// <p>The update's text: its SET in the plan's column order, its key in the plan's key order, and a
/// guard term per changed column -- <code>%EXACT</code> for text, <code>=</code> for another kind and
/// <code>IS NULL</code> for a NULL read, which binds nothing -- every identifier delimited with
/// <code>"</code> doubled; its values the new values, the keys, then the values read, a
/// <code>null</code> binding <code>""</code> and an empty string <code>$Char(0)</code>. The insert and
/// the delete take their own shapes and statement types.</p>
/// <p>Mutation (Rule 19): compose a text column's guard with <code>=</code> in
/// <method>OcuPilot.Port.SqlPort.SaveComposed</method> -- this goes red (and the live case-only leg).</p>
Method TestSaveComposedTheThreeStatements()
{
    Set tPlan = ..Plan()
    Set tChange = {"op": "update", "key": {"Part": "1", "Code": "a"}, "original": {"Born": "2026-10-01", "Name": "abc", "Num": null}, "values": {"Num": "2.5", "Name": "", "Born": null}}
    Set tComposed = $ClassMethod(..#PORT, "SaveComposed", tPlan, tChange)
    Do $$$AssertEquals(tComposed.text, "UPDATE ""Probe"".""Ta""""ble"" SET ""Name"" = ?, ""Num"" = ?, ""Born"" = ? WHERE ""Code"" = ? AND ""Part"" = ? AND %EXACT(""Name"") = ? AND ""Num"" IS NULL AND ""Born"" = ?", "the update's text")
    Do $$$AssertEquals(tComposed.type, 3, "an UPDATE")
    Do $$$AssertEquals(tComposed.values.%ToJSON(), "[""\u0000"",""2.5"","""",""a"",""1"",""abc"",""2026-10-01""]", "its values in order: empty as $Char(0), null as """"")
    Do $$$AssertEquals(tComposed.columns.%ToJSON(), "[""Name"",""Num"",""Born"",""Code"",""Part"",""Name"",""Born""]", "and the column each binds for")
    Set tComposed = $ClassMethod(..#PORT, "SaveComposed", tPlan, {"op": "insert", "values": {"Name": "zed", "Code": "z", "Num": null}})
    Do $$$AssertEquals(tComposed.text _ " " _ tComposed.type _ " " _ tComposed.values.%ToJSON(), "INSERT INTO ""Probe"".""Ta""""ble"" (""Code"", ""Name"", ""Num"") VALUES (?, ?, ?) 2 [""z"",""zed"",""""]", "the insert")
    Set tComposed = $ClassMethod(..#PORT, "SaveComposed", tPlan, {"op": "delete", "key": {"Part": "2", "Code": "b"}})
    Do $$$AssertEquals(tComposed.text _ " " _ tComposed.type _ " " _ tComposed.values.%ToJSON(), "DELETE FROM ""Probe"".""Ta""""ble"" WHERE ""Code"" = ? AND ""Part"" = ? 4 [""b"",""2""]", "the delete")
}

/// <p>Each row's outcome is the instance's: a row count of 1 or more is <code>saved</code>; an update
/// that matched none <code>changed</code> and a delete <code>gone</code>; SQLCODE -99
/// <code>refused</code>; any other SQL error <code>error</code> with its SQLCODE and message; the row
/// the budget interrupted <code>stopped</code> with the budget's seconds; a run that could not be made
/// <code>error</code> with no SQLCODE.</p>
/// <p>Mutation (Rule 19): answer <code>saved</code> whenever the SQLCODE is 0 or more in
/// <method>OcuPilot.Port.SqlPort.SaveOutcome</method> -- the changed and gone legs go red.</p>
Method TestTheOutcomeIsTheInstances()
{
    Set tOk = $$$OK
    For tCase = $ListBuild("update", "{""sqlcode"":0,""rowCount"":1}", "{""index"":7,""outcome"":""saved"",""rowCount"":1}"), $ListBuild("update", "{""sqlcode"":100,""rowCount"":0}", "{""index"":7,""outcome"":""changed"",""rowCount"":0}"), $ListBuild("delete", "{""sqlcode"":100,""rowCount"":0}", "{""index"":7,""outcome"":""gone"",""rowCount"":0}"), $ListBuild("insert", "{""sqlcode"":0,""rowCount"":1}", "{""index"":7,""outcome"":""saved"",""rowCount"":1}"), $ListBuild("update", "{""sqlcode"":-99,""message"":""m"",""rowCount"":0}", "{""index"":7,""outcome"":""refused"",""sqlcode"":-99}"), $ListBuild("insert", "{""sqlcode"":-120,""message"":""dup"",""rowCount"":0}", "{""index"":7,""outcome"":""error"",""sqlcode"":-120,""message"":""dup""}"), $ListBuild("update", "{""stopped"":true,""sqlcode"":-415}", "{""index"":7,""outcome"":""stopped"",""seconds"":2}"), $ListBuild("update", "{""rolledBack"":true,""sqlcode"":0}", "{""index"":7,""outcome"":""error"",""sqlcode"":null,""message"":""""}") {
        Set tResult = $ClassMethod(..#PORT, "SaveOutcome", "USER", 7, $List(tCase, 1), "", 2, tOk, ##class(%DynamicObject).%FromJSON($List(tCase, 2)))
        Do $$$AssertEquals(tResult.%ToJSON(), $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2))
    }
    Set tResult = $ClassMethod(..#PORT, "SaveOutcome", "USER", 7, "update", "", 2, $$$ERROR($$$GeneralError, "the run raised <PROBE>"), "")
    Do $$$AssertEquals(tResult.%ToJSON(), "{""index"":7,""outcome"":""error"",""sqlcode"":null,""message"":""""}", "a run that could not be made")
}

/// <p>The save's script (AD-59): one ObjectScript step per save, each change prepared with privilege
/// checks on and executed with each value as its column's placeholder, never a row value; changes that
/// do not read render the namespace line alone; the form is the run's.</p>
Method TestTheScriptRendersNoValue()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "SqlData", "RUN") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "SqlData", "PLAN"), "objectscript|", "the save has a script form and its plan none")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("schema") = "Probe"
    Set tQuery("table") = "Edit"
    Set tQuery("changes") = "[{""op"":""update"",""key"":{""Code"":""OcuProbe198Key""},""original"":{""Name"":""OcuProbe198Read""},""values"":{""Name"":""OcuProbe198New""}},{""op"":""delete"",""key"":{""Code"":""OcuProbe198Gone""}}]"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "SqlData", "RUN", .tQuery)
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step")
    Set tText = $Select(tSteps.%Size(): tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "%Prepare(""UPDATE """"Probe"""".""""Edit"""" SET """"Name"""" = ? WHERE """"Code"""" = ? AND %EXACT(""""Name"""") = ?"", 1)", "the update prepared with privilege checks on: " _ tText)
    Do $$$AssertTrue(tText [ "%Execute(""<Name>"", ""<Code>"", ""<Name>"")", "its values as placeholders")
    Do $$$AssertTrue(tText [ "DELETE FROM", "and the delete")
    Do $$$AssertTrue(tText '[ "OcuProbe198", "and no row value")
    Set tQuery("changes") = "OcuProbe198NotJson"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "SqlData", "RUN", .tQuery)
    Do $$$AssertEquals($Select(tSteps.%Size(): tSteps.%Get(0).text, 1: ""), " Set $NAMESPACE = ""USER""", "changes that do not read render the namespace line alone")
}

/// <p>The save's tool declares the write path: the console's port and the save endpoint, unadvertised,
/// a plan read and a run write sending no body, destructive, its three screen values, a fingerprint
/// over the plan and the values saved, no classic page of its own, and its screen's pairs alone.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSqlDataSave.ADVERTISED</parameter> 1
/// -- this goes red.</p>
Method TestTheToolDeclaresItsWritePath()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME"), "explorer.sqldata.save", "its name")
    Do $$$AssertEquals($ClassMethod(tTool, "PortClass") _ " " _ $ClassMethod(tTool, "Endpoint"), ..#PORT _ " SqlData", "its port and endpoint")
    Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "SendsBody") _ $ClassMethod(tTool, "Destructive"), "001", "unadvertised, bodyless and destructive")
    Do $$$AssertEquals($ClassMethod(tTool, "ReadType") _ " " _ $ClassMethod(tTool, "WriteType") _ " " _ $ClassMethod(tTool, "ChangeAction"), "PLAN RUN updated", "a plan read and a run write")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionValueNames", "save")), "schema,table,changes", "its three screen values")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")), "Namespace,Kind,Tables,statement,schema,table,changes", "its fingerprint subject")
    Do $$$AssertEquals($ClassMethod(tTool, "PreconditionField") _ " " _ $Parameter(tTool, "CLASSICPAGES"), "Kind ", "the plan's kind as its precondition, and no classic page of its own")
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    Set tScreen = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tTool, "DESCRIPTORCLASS"), .tScreenResolved)
    Do $$$AssertTrue(tResolved && tScreenResolved && (tPairs = tScreen), "and its screen's pairs alone")
    Do $$$AssertTrue($ListFind($ListFromString(##class(OcuPilot.Port.SqlPort).#COMPOSEDTYPES), "SqlData/RUN"), "the port composes it")
}

/// <p>AD-56 (ii): the screen's three values become the tool's arguments -- the schema and table as
/// names, the changes parsed from JSON array text -- and add the table's delimited name as the
/// statement the prohibited set judges; any other spelling is refused; the payload carries them back
/// to the port's query.</p>
Method TestTheScreenValuesAreParsedAndBounded()
{
    Set tTool = ..#TOOL
    Set tSC = $ClassMethod(tTool, "ScreenActionDelta", "save", {"schema": "Ocu\"Probe", "table": "Edit", "changes": "[{\"op\":\"delete\",\"key\":{\"Code\":\"b\"}}]"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem, "", "well-formed values are accepted")
    Do $$$AssertEquals($Select($IsObject($Get(tArgs)): tArgs.%ToJSON(), 1: ""), "{""statement"":""\""Ocu\""\""Probe\"".\""Edit\"""",""schema"":""Ocu\""Probe"",""table"":""Edit"",""changes"":[{""op"":""delete"",""key"":{""Code"":""b""}}]}", "as the tool's arguments, the statement the table's delimited name")
    For tCase = $ListBuild("{""schema"":"""",""table"":""Edit"",""changes"":""[]""}", "an empty schema"), $ListBuild("{""schema"":""OcuProbe198"",""table"":""E\u0001"",""changes"":""[{\""op\"":\""delete\"",\""key\"":{\""Code\"":\""b\""}}]""}", "a table with a control character"), $ListBuild("{""schema"":""OcuProbe198"",""table"":""Edit"",""changes"":""[]""}", "no change"), $ListBuild("{""schema"":""OcuProbe198"",""table"":""Edit"",""changes"":""{""}", "changes that are not JSON") {
        Set tSC = $ClassMethod(tTool, "ScreenActionDelta", "save", ##class(%DynamicObject).%FromJSON($List(tCase, 1)), {}, .tArgs, .tProblem)
        Do $$$AssertTrue((tProblem '= "") && (tArgs.%Size() = 0), $List(tCase, 2) _ " is refused: " _ tProblem)
    }
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", {"Namespace": "USER", "Kind": "table", "statement": "\"OcuProbe198\".\"Edit\"", "schema": "OcuProbe198", "table": "Edit", "changes": [{"op": "delete", "key": {"Code": "b"}}]}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("namespace")) _ "|" _ $Get(tQuery("schema")) _ "|" _ $Get(tQuery("table")) _ "|" _ $Get(tQuery("changes")) _ "|" _ $Data(tQuery("statement")), "USER|OcuProbe198|Edit|[{""op"":""delete"",""key"":{""Code"":""b""}}]|0", "the payload carries the save to the port's query")
}

/// <p>The port serves the save's plan and write and nothing else on its endpoint: the console's guard
/// type there, an unknown type and a wrong target are refused before any call.</p>
Method TestTheSaveEndpointServesItsTwoTypes()
{
    For tCase = $ListBuild("GUARD", "sql", "501 PORT.NOTIMPLEMENTED"), $ListBuild("MERGE", "sql", "501 PORT.NOTIMPLEMENTED"), $ListBuild("RUN", "other", "404 PORT.NOTFOUND") {
        Kill tQuery
        Set tQuery("id") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#PORT, "Invoke", "SqlData", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Select($$$ISERR(tSC): tHttp _ " " _ tFault.%Get("code"), 1: "served"), $List(tCase, 3), $List(tCase, 1) _ " on " _ $List(tCase, 2))
    }
}

}
