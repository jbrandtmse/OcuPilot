/// <p>Story 18.45's discovery tool, <code>shell.tools.find</code> (AD-5, AD-24, AD-53), on its own:
/// what it ranks, what it never names, how it bounds its answer and what it refuses. The ranking
/// is read over the production listing; the unadvertised and self-exclusion legs run over
/// <class>OcuPilot.Test.ScopeTool.Registry</class>, whose listing holds an unadvertised tool.</p>
/// <p><b>Live-safe</b>: it spawns nothing, opens no socket and stores nothing.</p>
Class OcuPilot.Test.ToolsFind Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ToolsFind";

Parameter FIXTURE = "OcuPilot.Test.ScopeTool.Find";

/// <p>The tool's <code>View</code> over class <var>pClass</var> for the JSON arguments
/// <var>pArgsJson</var>: the status in <var>pSC</var>, the HTTP status in <var>pHttp</var>, the
/// result or <code>""</code>, and the fault in <var>pFault</var>.</p>
ClassMethod Find(pClass As %String, pArgsJson As %String, Output pSC As %Status, Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set pSC = $ClassMethod(pClass, "View", "", ##class(%DynamicAbstractObject).%FromJSON(pArgsJson), 200, .tResult, .pHttp, .pFault)
    Quit tResult
}

/// <p>The wire names of <var>pResult</var>'s rows, comma-separated.</p>
ClassMethod Names(pResult As %DynamicObject) As %String
{
    Set tNames = ""
    If '$IsObject(pResult) Quit "(no result)"
    Set tIterator = pResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.name
    }
    Quit tNames
}

/// <p>The tool is a registered, advertised read with no privilege pair and no secret argument, and
/// says what it is for in the sentence the prompt relies on.</p>
Method TestTheToolIsARegisteredReadThatDeclaresNoPair()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve("shell.tools.find", .tTool), "the registry resolves the tool")
    Do $$$AssertTrue($IsObject(tTool), "it is registered")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.kind _ "|" _ tTool.class _ "|" _ tTool.descriptor _ "|" _ tTool.fulfilment, "read|" _ ..#TOOL _ "||instance", "a read with a class of its own, answered in the instance")
    Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
    Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tPairs), "1|0", "its requirement is read, and it declares no pair")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tDeclared)) _ "|" _ tDeclared, "0|1", "it declares no secret argument")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).DescriptionOf(tTool), "Search the tools you were not given at the start of this turn by what they do; a tool found can be called from your next step.", "and its description")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tAdvertised), "the registry advertises")
    Set tAdvertisedHere = 0
    For tI = 1:1:+$Get(tAdvertised) If tAdvertised(tI, "name") = "shell_tools_find" Set tAdvertisedHere = 1
    Do $$$AssertTrue(tAdvertisedHere, "and the provider array carries it under its wire name")
}

/// <p>The query "permissions users read" ranks <code>permissions_users_read</code> first over the
/// production listing, never names the discovery tool itself, and names no tool twice.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ToolsFind.View</method> ranks by name alone, not by score
/// -> this goes red.</p>
Method TestAQueryRanksTheMatchingToolFirst()
{
    Set tResult = ..Find(..#TOOL, "{""query"":""permissions users read""}", .tSC, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the search runs")
    Do $$$AssertEquals(tHttp, 200, "and answers 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.query, "permissions users read", "the answer echoes the query")
    Do $$$AssertEquals($Piece(..Names(tResult), ",", 1), "permissions_users_read", "the tool that names all three words is first: " _ ..Names(tResult))
    Do $$$AssertEquals(tResult.rows.%Size(), 8, "and eight rows are named by default")
    Do $$$AssertTrue(tResult.rowsAvailable > 8, "more matched than are named: " _ tResult.rowsAvailable)
    Do $$$AssertEquals(tResult.truncated, 1, "so the answer is marked truncated")
    Set tFirst = tResult.rows.%Get(0)
    Do $$$AssertTrue(tFirst.description [ "permissions.users", "a row carries the tool's description: " _ tFirst.description)
    Set tNames = ..Names(tResult)
    Do $$$AssertEquals($Length(tNames, ","), 8, "each row has a name")
    Kill tSeen
    Set tDuplicates = 0
    For tI = 1:1:$Length(tNames, ",") {
        If $Data(tSeen($Piece(tNames, ",", tI))) Set tDuplicates = tDuplicates + 1
        Set tSeen($Piece(tNames, ",", tI)) = ""
    }
    Do $$$AssertEquals(tDuplicates, 0, "no tool is named twice")
    Set tSelf = ..Find(..#TOOL, "{""query"":""shell tools find search""}", .tSC, .tHttp, .tFault)
    Do $$$AssertTrue((","_..Names(tSelf)_",") '[ ",shell_tools_find,", "a query that matches the tool itself never names it: " _ ..Names(tSelf))
}

/// <p><code>limit</code> bounds the rows and <code>rowsAvailable</code> does not move with it.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ToolsFind.View</method> reports <code>rowsAvailable</code>
/// as the rows named -> this goes red.</p>
Method TestTheLimitBoundsTheRowsAndNotTheCount()
{
    Set tTwo = ..Find(..#TOOL, "{""query"":""users read"",""limit"":2}", .tSC, .tHttp, .tFault)
    Set tTwenty = ..Find(..#TOOL, "{""query"":""users read"",""limit"":20}", .tSC20, .tHttp20, .tFault20)
    Do $$$AssertTrue($IsObject(tTwo) && $IsObject(tTwenty), "both searches answer")
    If '$IsObject(tTwo) || '$IsObject(tTwenty) Quit
    Do $$$AssertEquals(tTwo.rows.%Size() _ "|" _ tTwenty.rows.%Size(), "2|20", "a limit of 2 names two and a limit of 20 names twenty")
    Do $$$AssertEquals(tTwo.rowsAvailable, tTwenty.rowsAvailable, "the count of matches does not depend on the limit")
    Do $$$AssertTrue(tTwo.rowsAvailable > 20, "and exceeds the largest limit: " _ tTwo.rowsAvailable)
    Do $$$AssertEquals(tTwo.truncated _ "|" _ tTwenty.truncated, "1|1", "both are marked truncated")
    Do $$$AssertEquals($Piece(..Names(tTwenty), ",", 1, 2), ..Names(tTwo), "the two rows are the first two of the twenty")
    Set tNarrow = ..Find(..#TOOL, "{""query"":""sqladminprivileges"",""limit"":20}", .tSCN, .tHttpN, .tFaultN)
    Do $$$AssertTrue($IsObject(tNarrow) && (tNarrow.rows.%Size() > 0), "a narrow query finds a tool")
    If '$IsObject(tNarrow) Quit
    Do $$$AssertEquals(tNarrow.rows.%Size(), $Select(tNarrow.rowsAvailable < 20: tNarrow.rowsAvailable, 1: 20), "it names every match up to the limit")
    Do $$$AssertEquals(tNarrow.truncated, ''(tNarrow.rowsAvailable > tNarrow.rows.%Size()), "and is truncated exactly when more matched than are named")
}

/// <p>A word only a tool's description carries still finds it, and the score ranks, not the order of the
/// names: over <class>OcuPilot.Test.ScopeTool.Registry</class>, "discovery" appears in one advertised
/// tool's description alone, and "late counts" scores the tool whose name has "late" and whose
/// description has "counts" 3, ahead of the two tools whose descriptions alone have "counts", 1 each,
/// by name.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ToolsFind.Score</method> drops the description branch
/// -> this goes red on both legs.</p>
Method TestADescriptionAloneFindsATool()
{
    Set tByDescription = ..Find(..#FIXTURE, "{""query"":""discovery""}", .tSC, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the description search runs")
    If '$IsObject(tByDescription) Quit
    Do $$$AssertEquals(..Names(tByDescription) _ "|" _ tByDescription.rowsAvailable, "probe_found_read|1", "a word only a description carries finds that tool, and not the unadvertised one that carries it too")
    Set tRanked = ..Find(..#FIXTURE, "{""query"":""late counts""}", .tSC, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the ranked search runs")
    If '$IsObject(tRanked) Quit
    Do $$$AssertEquals(..Names(tRanked), "zprobe_late_read,probe_found_read,shell_probe_read", "the name hit and the description hit outrank two description hits, which follow by name")
}

/// <p>A query that matches nothing is an ordinary empty answer.</p>
Method TestAQueryThatMatchesNothingAnswersNoRows()
{
    Set tResult = ..Find(..#TOOL, "{""query"":""zzqqxx wwvvuu""}", .tSC, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the search runs")
    Do $$$AssertEquals(tHttp, 200, "and answers 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%ToJSON() _ "|" _ tResult.rowsAvailable _ "|" _ tResult.truncated, "[]|0|0", "no rows, none available, nothing truncated")
}

/// <p>A query with no searchable word, a missing query, a query past 200 characters and a limit
/// outside 1 to 20 are each refused <code>TOOL.ARGUMENTS</code>.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ToolsFind.View</method> searches an empty word list
/// -> this goes red on the no-word leg.</p>
Method TestAnUnsearchableQueryIsRefused()
{
    Set tLong = $Translate($Justify("", 201), " ", "a")
    For tCase = "{""query"":""a b !! 7""}", "{""query"":""""}", "{}", "{""query"":""" _ tLong _ """}", "{""query"":""users"",""limit"":0}", "{""query"":""users"",""limit"":21}", "{""query"":""users"",""limit"":2.5}", "{""query"":""users"",""extra"":1}" {
        Set tResult = ..Find(..#TOOL, tCase, .tSC, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $Extract(tCase, 1, 40) _ " is refused")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: "") _ "|" _ tHttp _ "|" _ tResult, "TOOL.ARGUMENTS|400|", $Extract(tCase, 1, 40) _ ": TOOL.ARGUMENTS, 400, no result")
    }
}

/// <p>The words a query is scored on: lower-case runs of two or more letters or digits, the first
/// ten.</p>
Method TestTheQueryIsCutIntoWords()
{
    Set tWords = ##class(OcuPilot.Screen.Tool.ToolsFind).Words("Permissions, USERS; read-only a b 7x x9 ab")
    Do $$$AssertEquals($ListToString(tWords, "|"), "permissions|users|read|only|7x|x9|ab", "case folds, a separator ends a run, a one-character run is dropped")
    Set tMany = ##class(OcuPilot.Screen.Tool.ToolsFind).Words("aa bb cc dd ee ff gg hh ii jj kk ll")
    Do $$$AssertEquals($ListLength(tMany) _ "|" _ $List(tMany, 10), "10|jj", "only the first ten are scored")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.ToolsFind).Words("! ? a"), "", "a query with no word has none")
}

/// <p>An unadvertised tool (AD-53) is listed but never found, and a tool that is found is the one
/// the query names.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.ToolsFind.View</method> skips the
/// <code>IsAdvertised</code> check -> this goes red on the unadvertised leg.</p>
Method TestAnUnadvertisedToolIsNeverFound()
{
    Set tSC = ##class(OcuPilot.Test.ScopeTool.Registry).ListTools(.tList)
    Do $$$AssertStatusOK(tSC, "the fixture registry lists")
    Set tHidden = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.name = "probe.hidden.read" Set tHidden = tEntry
    }
    Do $$$AssertTrue($IsObject(tHidden), "the listing holds the hidden tool")
    If '$IsObject(tHidden) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tHidden), 0, "and it is not advertised")
    Set tResult = ..Find(..#FIXTURE, "{""query"":""hidden advertised""}", .tSC, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the search runs")
    Do $$$AssertEquals(..Names(tResult) _ "|" _ tResult.rowsAvailable, "|0", "no tool is found for words only the hidden tool carries")
    Set tFound = ..Find(..#FIXTURE, "{""query"":""found""}", .tSC, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tFound), "probe_found_read", "the advertised tool the query names is found, under its wire name")
    Set tAll = ..Find(..#FIXTURE, "{""query"":""probe fixture tool read""}", .tSC, .tHttp, .tFault)
    Do $$$AssertEquals($Length(..Names(tAll), ",") _ "|" _ ((","_..Names(tAll)_",") '[ ",probe_hidden_read,") _ "|" _ ((","_..Names(tAll)_",") '[ ",shell_tools_find,"), "3|1|1", "a broad query names the other fixture tools, never the hidden one or the search itself: " _ ..Names(tAll))
}

}
