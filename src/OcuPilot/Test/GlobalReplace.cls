/// <p>Pins Story 21.18's find and replace on both callers (AC1 to AC5; AD-6, AD-10, AD-34, AD-36, AD-51, AD-53, AD-58): a person's review and confirmed
/// replace and the agent's confirmed proposal replacing every occurrence in the plain-text values of the test's own global and nothing else, with the
/// case rule; a global that moved after the review or the mint written by neither caller, and a recorded node that moved rolled back whole; a global
/// over 20,000 nodes, a replaced value over 32,767 characters, a replace that changes nothing and the <code>%SYS</code> namespace refused on both callers; text of
/// the wrong shape refused before anything is read; the card and the tool's answer holding counts and no value or subscript; and the kernel's globals arm
/// refusing a protected replace before any write, on both callers for a global stored in a system database.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account. Each test makes
/// its own global <code>^ZZOcuRep&lt;pid&gt;</code> in <code>HSCUSTOM</code> and kills it, and snapshots the stored governance policy before and puts it
/// back after. The name-stem test names its global in lower case, which the install namespace stores in its own database, not OcuPilot's. The system
/// database test makes the <code>%</code> copy of the test's global, which the namespace stores in the system database, and kills it; no other global of a
/// protected database is written.</p>
Class OcuPilot.Test.GlobalReplace Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.GlobalPort";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerGlobalReplace";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter LISTSCREEN = "explorer.globals";

Parameter NAMESPACE = "HSCUSTOM";

/// <p>The name of the test's own global, without <code>^</code>.</p>
Property PreparedName As %String;

/// <p>Text that is in a value and in a subscript of the test's global, which no answer may carry.</p>
Property PreparedMarker As %String;

Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedName = ""
    Set ..PreparedMarker = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedName = "ZZOcuRep" _ $Job
    Set ..PreparedMarker = "Zq" _ $Job _ "m"
    Do ..Remove()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove()
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
    Do ##class(OcuPilot.Test.GlobalReplaceMoveSeam).Reset()
    Kill ^||OcuPilotDatabaseWritePort
    Kill ^||OcuPilotGlobalReplace
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Kill the test's global and its <code>%</code> copy.</p>
Method Remove()
{
    Set tRoot = "^" _ ..PreparedName
    Kill @tRoot
    Set tPercent = "^%" _ $Translate(..PreparedName, "%")
    Kill @tPercent
    Set tProbe = "^" _ ..PreparedName _ "Probe"
    Kill @tProbe
}

/// <p>The test's global: three plain-text nodes holding <code>abc</code> (five occurrences, one value and one subscript carrying the marker), one holding it
/// in other case, one holding none, a <code>$ListBuild</code> node and a node with a tab beside <code>abc</code>, which no replace changes, and a node whose
/// subscript is <code>abc</code>, which is never searched.</p>
Method Make()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = ..PreparedMarker _ " abc and abc"
    Set @tRoot@(2) = "xAbCy"
    Set @tRoot@(3) = "xabcx"
    Set @tRoot@(4) = "nothing here"
    Set @tRoot@(5) = $ListBuild("abc", 2)
    Set @tRoot@(6) = "tab" _ $Char(9) _ "abc"
    Set @tRoot@("abc") = "keep"
    Set @tRoot@("mk" _ ..PreparedMarker) = "abc abc"
}

/// <p>Every node of the test's global and its value, in order, as one text, for a before and after comparison.</p>
Method Snapshot() As %String
{
    Set tText = ""
    Set tRoot = "^" _ ..PreparedName
    Set tNext = $Query(@tRoot)
    While tNext '= "" {
        Set tText = tText _ tNext _ "=" _ $Get(@tNext) _ $Char(10)
        Set tNext = $Query(@tNext)
    }
    Quit tText
}

/// <p><code>POST</code> <var>pPath</var> with <var>pBody</var> as the suite's account: the HTTP status and the answer.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", pPath, .tStatus, .pAnswer, pBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The values of a replace as the screen sends them.</p>
ClassMethod ValuesOf(pFind As %String, pReplace As %String, pMatchCase As %Boolean, pReviewed As %String = "") As %DynamicObject
{
    Set tValues = {"Find": (pFind), "Replace": (pReplace), "MatchCase": ($Select(pMatchCase: "true", 1: "false"))}
    If pReviewed '= "" Do tValues.%Set("Reviewed", pReviewed, "string")
    Quit tValues
}

/// <p>The review of a replace over HTTP (<code>POST /screens/explorer.globals/dryrun</code>).</p>
Method Review(pFind As %String, pReplace As %String, pMatchCase As %Boolean, Output pAnswer As %DynamicObject, pNamespace As %String = {..#NAMESPACE}) As %Integer
{
    Quit ..Post("/screens/" _ ..#LISTSCREEN _ "/dryrun?ns=" _ pNamespace, {"action": "replace", "id": (..PreparedName), "values": (..ValuesOf(pFind, pReplace, pMatchCase))}, .pAnswer)
}

/// <p>The person's confirmed replace over HTTP, carrying <var>pReviewed</var>, the digest its review answered.</p>
Method Replace(pFind As %String, pReplace As %String, pMatchCase As %Boolean, pReviewed As %String, Output pAnswer As %DynamicObject, pNamespace As %String = {..#NAMESPACE}) As %Integer
{
    Quit ..Post("/screens/" _ ..#LISTSCREEN _ "/action?ns=" _ pNamespace, {"action": "replace", "id": (..PreparedName), "values": (..ValuesOf(pFind, pReplace, pMatchCase, pReviewed))}, .pAnswer)
}

/// <p>The status and refusal code an answer carries, as <code>status code</code>.</p>
ClassMethod Verdict(pStatus As %Integer, pAnswer As %DynamicObject) As %String
{
    Quit pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The rows of a review or a card, as <code>field=after</code> joined by <code>|</code>.</p>
ClassMethod RowText(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit "(none)"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tRow.field _ "=" _ tRow.after
    }
    Quit tText
}

/// <p>Enable the agent's key for the replace tool through its stored setting.</p>
Method EnableKey()
{
    Kill tSettings
    Set tSettings($Parameter(..#TOOL, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled through its stored setting")
}

/// <p>The agent's proposal for the test's global from <var>pArgs</var>, minted by the tool's own mint class over a completed turn.</p>
Method MintAgent(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tClass = ..#TOOL
    Set ^||OcuPilotDatabaseWritePort = $Parameter(tClass, "PORTCLASS")
    Set tSC = $ClassMethod($ClassMethod(tClass, "MintClass"), "Mint", $Parameter(tClass, "DESCRIPTORCLASS"), $Parameter(tClass, "TOOLNAME"), $Username, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .pFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), ..PreparedName, "Name", $ClassMethod(tClass, "SettableFields"), tClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    Quit tSC
}

/// <p>The agent's arguments for the test's global.</p>
Method AgentArgs(pFind As %String = "abc", pReplace As %String = "xyz") As %DynamicObject
{
    Quit {"Name": (..PreparedName), "Find": (pFind), "Replace": (pReplace)}
}

/// <p>The tool declares what the story rules: name, port, endpoint, the read type its review is composed by and the write type, who reaches it, that it
/// is destructive, reviewed, bodyless and composes its read from its values, the screen values, the pairs, the consequence, the key shipping disabled, the
/// port's composed types, and the ruled sentences and statuses of its refusals.</p>
/// <p>Mutation (Rule 19): set <code>DRYRUN</code> 0 on the tool -> the declaration assertion goes red.</p>
Method TestTheToolDeclaresItsWritePathAndItsRefusals()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), "explorer.globals.replace|" _ ..#PORT _ "|Globals|REPLACE|REPLACEALL", "name, port, endpoint and request types")
    Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ $Parameter(tTool, "DRYRUN") _ $Parameter(tTool, "READSVALUES"), "11011", "advertised, destructive, bodyless, reviewed and composed from its values")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionValueNames", "replace")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionOptionalNames", "replace")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionEmptyNames", "replace")), "replace|Find,Replace,MatchCase,Reviewed|Reviewed|Replace", "its row action, the values it sends, the one it may leave out and the one that may be empty")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")) _ "|" _ $ClassMethod(tTool, "Consequence", {}) _ "|" _ $Parameter(tTool, "CLASSICPAGES"), "Find,Replace,MatchCase,Reviewed|GLOBAL.REPLACE|%cspapp.exp.utilexpfindreplace", "its arguments, consequence and classic page")
    Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($Parameter(tTool, "TOOLNAME"), .tListed)
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($Parameter(tTool, "TOOLNAME"), "write", .tEnabled, .tSource)
    Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 0", "its key is in the baseline and ships disabled")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter(..#PORT, "COMPOSEDTYPES")), "Globals/REPLACE") && $ListFind($ListFromString($Parameter(..#PORT, "COMPOSEDTYPES")), "Globals/REPLACEALL"), "the port composes both types")
    For tCase = $ListBuild("GLOBAL.REPLACE.NOCHANGE", "No plain-text value in this global holds that text, so nothing would change.", 409), $ListBuild("GLOBAL.REPLACE.TOOLARGE", "This global is too large to replace in here: it holds more than 20,000 nodes, or a replaced value would be longer than 32,767 characters.", 409), $ListBuild("GLOBAL.REPLACE.REVIEWCHANGED", "This global changed after the replace was reviewed, so nothing was replaced. Review the replace again.", 409), $ListBuild("GLOBAL.REPLACE.SYSNAMESPACE", "Find and replace is not available in the %SYS namespace.", 409), $ListBuild("GLOBAL.REPLACE", "Replacing changes every value the review counts. This cannot be undone.", 0) {
        Do $$$AssertEquals(##class(OcuPilot.Api.GlobalError).ReasonFor($List(tCase, 1)) _ "|" _ ##class(OcuPilot.Api.GlobalError).HttpStatusFor($List(tCase, 1)), $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": its ruled sentence and status")
    }
    Do $$$AssertEquals(##class(OcuPilot.Port.GlobalPort).SnippetForm("Globals", "REPLACEALL") _ "|" _ ##class(OcuPilot.Port.GlobalPort).SnippetForm("Globals", "REPLACE"), "objectscript|", "the write has an ObjectScript script form and its read has none")
}

/// <p>The test's global after the port's own replace (<code>REPLACE</code>, then <code>REPLACEALL</code> at the digest it answered), or after the rendered
/// script of that replace when <var>pScript</var>: made fresh, its root holding <code>root abc</code>, a node of five <code>a</code> (a find may overlap
/// itself), then every node as one text.</p>
Method AfterReplace(pFind As %String, pReplace As %String, pMatchCase As %String, pScript As %Boolean, Output pText As %String) As %String
{
    Do ..Remove()
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot = "root abc"
    Set @tRoot@(7) = "aaaaa"
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = pFind
    Set tQuery("replace") = pReplace
    If pMatchCase '= "" Set tQuery("matchCase") = pMatchCase
    If pScript Quit ..RunScript(.tQuery, .pText) _ @tRoot _ $Char(10) _ ..Snapshot()
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACE", .tQuery, "", .tFresh, .tHttp, .tFault)
    Set tQuery("digest") = $Select($IsObject($Get(tFresh)): tFresh.Digest, 1: "")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACEALL", .tQuery, "", .tDone, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tDone)): "", 1: "invoke failed " _ $Get(tHttp)) _ @tRoot _ $Char(10) _ ..Snapshot()
}

/// <p>Render the script of <var>pQuery</var>'s replace and run it, one line at a time as a terminal would, in the current namespace restored after. The
/// answer is the error the script raised, or <code>""</code>; <var>pText</var> is the script. The script's own variables are killed after it, so
/// none outlives the call, and the locals of this method are named so none collides with them.</p>
Method RunScript(ByRef pQuery, Output pText As %String) As %String
{
    Set zSteps = $ClassMethod(..#PORT, "Snippet", "Globals", "REPLACEALL", .pQuery)
    Set pText = zSteps.%Get(0).text
    Set zNamespace = $NAMESPACE
    Set zError = ""
    Try {
        For zI = 1:1:$Length(pText, $Char(10)) {
            Set zLine = $Piece(pText, $Char(10), zI)
            Xecute zLine
        }
    } Catch zEx {
        Set zError = zEx.Name
    }
    Set $NAMESPACE = zNamespace
    Xecute "Kill tRoot, tFind, tReplace, tMatchCase, tNeedle, tNext, tLevel, tValue, tOut, tHay, tNew, tFrom, tHits, tAt, tEx"
    Quit zError _ $Select($TLevel = 0: "", 1: "open transaction")
}

/// <p>AC1 and AD-59: the replace's script form makes the change the port's own replace makes -- the same nodes, in the same way, and no others. On a fresh
/// copy of the test's global (its root included) the rendered script, run line by line, leaves every node as <code>REPLACE</code> then <code>REPLACEALL</code>
/// leave it, with the case matched (the flag left out and given), and without matching case. The plain-text nodes holding the text change; the other-case
/// node (with the case matched), the <code>$ListBuild</code> node, the node with a control character and the node whose subscript holds the text do not. The
/// script opens no block it does not close on its line.</p>
/// <p>Mutation (Rule 19): make <code>OcuPilot.Port.GlobalPort.SnippetForm</code> answer <code>""</code> for <code>REPLACEALL</code> again -> this
/// test and the declaration assertion above go red; step the find's search past one character instead of its length in the script -> the overlap leg
/// goes red.</p>
Method TestTheScriptFormMakesTheSameChangeAsTheWrite()
{
    For tLeg = $ListBuild("abc", "xyz", ""), $ListBuild("abc", "xyz", "1"), $ListBuild("ABC", "xyz", "0"), $ListBuild("b", "", ""), $ListBuild("a", "aa", ""), $ListBuild("aa", "Z", "") {
        Set tWrite = ..AfterReplace($List(tLeg, 1), $List(tLeg, 2), $List(tLeg, 3), 0)
        Set tScript = ..AfterReplace($List(tLeg, 1), $List(tLeg, 2), $List(tLeg, 3), 1, .tText)
        Set tName = $List(tLeg, 1) _ ">" _ $List(tLeg, 2) _ " case " _ $Select($List(tLeg, 3) = "": "default", 1: $List(tLeg, 3))
        Do $$$AssertEquals(tScript, tWrite, tName _ ": the script leaves every node as the port's replace does")
        Do $$$AssertTrue($Extract(tWrite, 1, 13) '= "invoke failed", tName _ ": and the write was made")
    }
    Set tScript = ..AfterReplace("aa", "Z", "", 1, .tText)
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(@tRoot@(7), "ZZa", "occurrences are replaced left to right without overlap")
    Set tScript = ..AfterReplace("abc", "xyz", "", 1, .tText)
    Do $$$AssertEquals($Piece(tScript, $Char(10), 1), "root xyz", "the root is replaced too")
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(@tRoot@(1) _ "|" _ @tRoot@(2) _ "|" _ @tRoot@(3) _ "|" _ @tRoot@(4) _ "|" _ (@tRoot@(5) = $ListBuild("abc", 2)) _ "|" _ @tRoot@(6) _ "|" _ @tRoot@("abc"), ..PreparedMarker _ " xyz and xyz|xAbCy|xxyzx|nothing here|1|tab" _ $Char(9) _ "abc|keep", "with the case matched only the plain-text values change")
    Set tScript = ..AfterReplace("ABC", "xyz", "0", 1, .tText)
    Do $$$AssertEquals(@tRoot@(2) _ "|" _ @tRoot@(3) _ "|" _ (@tRoot@(5) = $ListBuild("abc", 2)) _ "|" _ @tRoot@(6), "xxyzy|xxyzx|1|tab" _ $Char(9) _ "abc", "and without it the other-case value changes too, the list and control character values still do not")
    Do $$$AssertTrue($Length(tText, "{") = $Length(tText, "}"), "every block the script opens it closes")
    For tI = 1:1:$Length(tText, $Char(10)) {
        Set tLine = $Piece(tText, $Char(10), tI)
        Do $$$AssertEquals($Length(tLine, "{"), $Length(tLine, "}"), "line " _ tI _ " closes every block it opens")
    }
}

/// <p>AD-59: the script is one transaction. A replacement that makes a later value longer than a string can be raises an error after an earlier node was
/// set; the script raises it, no node holds a replaced value and no transaction is left open.</p>
/// <p>Mutation (Rule 19): drop the rollback loop from the <code>Catch</code> of <code>OcuPilot.Port.GlobalPort.ReplaceScript</code> -> this test goes red.</p>
Method TestTheScriptRollsBackWhenItFails()
{
    Set tProbe = "^" _ ..PreparedName _ "Probe"
    Kill @tProbe
    Set @tProbe@(1) = "a"
    Set @tProbe@(2) = $Translate($Justify("", 4000), " ", "a")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName _ "Probe"
    Set tQuery("find") = "a"
    Set tQuery("replace") = $Translate($Justify("", 1000), " ", "b")
    Set tError = ..RunScript(.tQuery, .tText)
    Do $$$AssertTrue((tError '= "") && (tError '[ "open transaction"), "the script raises the error and leaves no transaction open: " _ tError)
    Do $$$AssertEquals(@tProbe@(1) _ "|" _ $Length(@tProbe@(2)), "a|4000", "and neither node holds a replaced value, the one set before the error included")
    Kill @tProbe
}

/// <p>AD-59: nothing the replace's query carries runs as code. A find holding a double quote and the spelling of a call, which as code would count and
/// match another value, matches only the node holding that very text; the call is never made; a find and a value holding a tab are rendered with the control
/// character spelled and match nothing; and no raw control character, but the line feeds, is in the script.</p>
/// <p>Mutation (Rule 19): render the find without doubling its quotes in <code>OcuPilot.Port.GlobalPort.Literal</code> -> the call runs and this test goes red.</p>
Method TestTheScriptRunsNothingTheQueryCarries()
{
    Set tRoot = "^" _ ..PreparedName
    Set tProbe = "^" _ ..PreparedName _ "Probe"
    Kill @tProbe
    Set tFind = "q""_$Increment(" _ tProbe _ ")_""q"
    Set @tRoot@(1) = "1" _ tFind _ "2"
    Set @tRoot@(2) = "1q1q2"
    Set @tRoot@(3) = "tab" _ $Char(9) _ "abc"
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = tFind
    Set tQuery("replace") = "R"
    Set tError = ..RunScript(.tQuery, .tText)
    Do $$$AssertEquals(tError, "", "the script runs without error")
    Do $$$AssertEquals(@tRoot@(1) _ "|" _ @tRoot@(2), "1R2|1q1q2", "only the node holding the find text as text changes")
    Do $$$AssertEquals($Data(@tProbe), 0, "and the call in the find text was never made")
    Set tQuery("find") = $Char(9) _ "abc"
    Set tQuery("replace") = "X" _ $Char(0) _ "Y"
    Set tError = ..RunScript(.tQuery, .tText)
    Do $$$AssertEquals(tError _ "|" _ @tRoot@(3), "|tab" _ $Char(9) _ "abc", "a find with a control character changes no value, the one holding a control character included")
    Do $$$AssertEquals($Translate(tText, $Char(10)), $ZStrip($Translate(tText, $Char(10)), "*C"), "no raw control character but the line feeds is in the script")
    Do $$$AssertTrue(tText [ "$Char(9)_""abc""", "the control characters are spelled")
    Kill @tProbe
}

/// <p>AC1. A person reviews a replace and the review states the counts over the node page's own rows -- three nodes and five occurrences -- and a digest, changing
/// nothing; the confirmed replace, carrying that digest, sets every occurrence in the plain-text values and changes no other node (the other-case value, the
/// <code>$ListBuild</code> value, the value with a tab, the node whose subscript holds the text and the node holding none), answers with its verb and target, and
/// reads back as an action.</p>
/// <p>Mutation (Rule 19): skip the plain-text check in <method>OcuPilot.Port.GlobalPort.Candidate</method> -> the <code>$ListBuild</code> and tab nodes change and the
/// counts and values go red.</p>
Method TestAPersonReviewsAndReplaces()
{
    Do ..Make()
    Set tBefore = ..Snapshot()
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Do $$$AssertEquals(tStatus _ " " _ ..RowText($Select($IsObject($Get(tReview)): tReview.rows, 1: "")), "200 Find=abc|Replace=xyz|MatchCase=true|Nodes=3|Occurrences=5", "the review states the texts and the counts: " _ $Select($IsObject($Get(tReview)): tReview.%ToJSON(), 1: ""))
    Set tDigest = $Select($IsObject($Get(tReview)) && $IsObject(tReview.review): tReview.review.Digest, 1: "")
    Do $$$AssertTrue($Match(tDigest, "^[0-9a-f]{64}$") > 0, "and a digest")
    Do $$$AssertEquals(..Snapshot(), tBefore, "the review changes nothing")
    Do $$$AssertTrue($IsObject(tReview) && (tReview.%ToJSON() '[ ..PreparedMarker), "and carries no value and no subscript")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = "abc"
    Set tQuery("replace") = "xyz"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACE", .tQuery, "", .tFresh, .tHttp, .tFault)
    Set tHome = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^" _ ..PreparedName), "^", 2)
    Set tLocations = $Select($IsObject($Get(tFresh)) && $IsObject(tFresh.Locations): tFresh.Locations.%ToJSON(), 1: "(none)")
    Do $$$AssertEquals(tLocations, [(tHome)].%ToJSON(), "the port's fresh read names the directory the changing nodes are stored in")
    Set tStatus = ..Replace("abc", "xyz", 1, tDigest, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "200|updated|global|" _ ..PreparedName, "the replace is answered with its verb and target: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(@tRoot@(1) _ "|" _ @tRoot@(3) _ "|" _ @tRoot@("mk" _ ..PreparedMarker), ..PreparedMarker _ " xyz and xyz|xxyzx|xyz xyz", "every occurrence in the three nodes is replaced")
    Do $$$AssertEquals(@tRoot@(2) _ "|" _ @tRoot@(4) _ "|" _ (@tRoot@(5) = $ListBuild("abc", 2)) _ "|" _ @tRoot@(6) _ "|" _ @tRoot@("abc"), "xAbCy|nothing here|1|tab" _ $Char(9) _ "abc|keep", "no other node changes")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer), "nothingSent", "and its read-back is the action's: no value was sent")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ ..PreparedMarker), "the answer carries no value and no subscript")
}

/// <p>AC1, the case rule. Without matching case the review counts the node holding the text in other case, and the replace puts the replacement where the
/// original characters were.</p>
/// <p>Mutation (Rule 19): compare the texts as they are in <method>OcuPilot.Port.GlobalPort.Replaced</method> -> the counts and the value go red.</p>
Method TestMatchCaseFalseReplacesTheOriginalCharacters()
{
    Do ..Make()
    Set tStatus = ..Review("ABC", "xyz", 0, .tReview)
    Do $$$AssertEquals(tStatus _ " " _ ..RowText($Select($IsObject($Get(tReview)): tReview.rows, 1: "")), "200 Find=ABC|Replace=xyz|MatchCase=false|Nodes=4|Occurrences=6", "the review counts the other-case node as well")
    Set tStatus = ..Replace("ABC", "xyz", 0, tReview.review.Digest, .tAnswer)
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(tStatus _ "|" _ @tRoot@(2) _ "|" _ @tRoot@(3), "200|xxyzy|xxyzx", "the replacement stands where the original characters were")
    Set tStatus = ..Review("ABC", "xyz", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "409 GLOBAL.REPLACE.NOCHANGE", "and with the case matched nothing holds the text")
}

/// <p>AC1, wide characters. A value holding characters above U+00FF beside the text is counted, reviewed and replaced with the other characters kept in
/// place, with and without matching case.</p>
/// <p>Mutation (Rule 19): lower-case only the find text in <method>OcuPilot.Port.GlobalPort.Replaced</method> -> the case-insensitive leg goes red.</p>
Method TestWideCharactersAreKeptInPlace()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = $Char(304) _ "ABC" _ $Char(20013) _ "abc" _ $Char(8364)
    Set tStatus = ..Review("abc", "x", 0, .tReview)
    Do $$$AssertEquals(tStatus _ " " _ ..RowText($Select($IsObject($Get(tReview)): tReview.rows, 1: "")), "200 Find=abc|Replace=x|MatchCase=false|Nodes=1|Occurrences=2", "both occurrences are counted")
    Set tStatus = ..Replace("abc", "x", 0, tReview.review.Digest, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ (@tRoot@(1) = ($Char(304) _ "x" _ $Char(20013) _ "x" _ $Char(8364))), "200|1", "and the characters around them are kept")
}

/// <p>AC2. With the key enabled the agent's proposal is minted by the tool's mint class, and its card rows are the five counts and texts and carry no value or
/// subscript; confirming it replaces the values and the confirm's answer carries none. With the default baseline governance refuses the proposal.</p>
/// <p>Mutation (Rule 19): add a changing node's reference to the rows of <method>OcuPilot.Screen.Tool.ExplorerGlobalReplace.StateDiff</method> -> the rows and the
/// no-subscript assertions go red.</p>
Method TestTheAgentProposesAndAPersonConfirms()
{
    Do ..Make()
    Set tTool = $Parameter(..#TOOL, "TOOLNAME")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide(tTool, "write", $Username, {"Name": (..PreparedName)}, .tDecision)
    Do $$$AssertEquals($Select($$$ISOK(tSC): +$Get(tDecision("allowed")), 1: -1), 0, "with the default baseline governance refuses the agent's proposal")
    Do ..EnableKey()
    Set tBefore = ..Snapshot()
    Do $$$AssertStatusOK(..MintAgent(..AgentArgs(), .tProposal, .tHttp, .tFault), "the proposal is minted: " _ tHttp)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..RowText(tProposal.changed), "Find=abc|Replace=xyz|MatchCase=true|Nodes=3|Occurrences=5", "its card states the texts and the counts: " _ tProposal.%ToJSON())
    Do $$$AssertTrue((tProposal.%ToJSON() '[ ..PreparedMarker) && (tProposal.%ToJSON() '[ "keep") && (tProposal.%ToJSON() '[ "Locations") && (tProposal.%ToJSON() '[ "Digest"), "and no value, no subscript, no directory and no digest")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id, "global|" _ ..PreparedName, "it names the global")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing is replaced by the mint")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "200 ", "the confirm replaces: " _ tConfirm)
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(@tRoot@(1) _ "|" _ @tRoot@(3), ..PreparedMarker _ " xyz and xyz|xxyzx", "the values are replaced")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)), "nothingSent", "and the confirm's read-back is the action's")
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.%ToJSON() '[ ..PreparedMarker), "the confirm's answer carries no value and no subscript")
}

/// <p>AC3. A person's replace whose global moved after the review is 409 <code>GLOBAL.REPLACE.REVIEWCHANGED</code> and writes nothing; so is the agent's
/// confirm of a proposal whose global moved after the mint, which is not written either; and a recorded node that moved between the walk and the transaction
/// rolls every earlier node back and writes nothing, which the port answers 409 <code>GLOBAL.REPLACE.REVIEWCHANGED</code>
/// (<class>OcuPilot.Test.GlobalReplaceMoveSeam</class>); and an error inside the transaction rolls back the node set before it.</p>
/// <p>Mutation (Rule 19): drop the per-node old-value check in <method>OcuPilot.Port.GlobalPort.VendorReplaceApply</method> -> the rollback leg goes red; drop the
/// digest comparison in <method>OcuPilot.Port.GlobalPort.ReplacingRun</method> -> the person's leg goes red; shorten the tool's <code>FINGERPRINTSUBJECT</code> to its
/// name, texts and namespace -> the agent's legs go red; drop the stale refusal in <method>OcuPilot.Port.GlobalPort.ReplacingRun</method> -> the seam's leg goes
/// red; drop the rollback loop from <method>OcuPilot.Port.GlobalPort.VendorReplaceApply</method>'s <code>Catch</code> -> the error leg goes red.</p>
Method TestAMovedGlobalIsNotWrittenOnEitherCaller()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Set tDigest = $Select($IsObject($Get(tReview)) && $IsObject(tReview.review): tReview.review.Digest, 1: "")
    Set @tRoot@(3) = "xabcx moved"
    Set tMoved = ..Snapshot()
    Set tStatus = ..Replace("abc", "xyz", 1, tDigest, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "409 GLOBAL.REPLACE.REVIEWCHANGED", "a person's replace of a global that moved after the review is refused")
    Do $$$AssertEquals(..Snapshot(), tMoved, "and nothing is written")
    Do ..EnableKey()
    Do $$$AssertStatusOK(..MintAgent(..AgentArgs(), .tProposal, .tHttp, .tFault), "the agent's proposal is minted: " _ tHttp)
    If $IsObject($Get(tProposal)) {
        Set @tRoot@(7) = "abc late"
        Set tLate = ..Snapshot()
        Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
        Do $$$AssertEquals(tConfirm, "409 PROPOSAL.TARGETCHANGED", "the confirm of a proposal whose global moved after the mint is refused as target-changed")
        Do $$$AssertEquals(..Snapshot(), tLate, "and nothing is written")
    }
    Kill @tRoot@(7)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(..MintAgent(..AgentArgs(), .tProposal, .tHttp, .tFault), "a second proposal is minted: " _ tHttp)
    If $IsObject($Get(tProposal)) {
        Set @tRoot@(3) = "xabcy"
        Set tLate = ..Snapshot()
        Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
        Do $$$AssertEquals(tConfirm, "409 PROPOSAL.TARGETCHANGED", "a value that moved without changing either count is refused the same way: " _ tConfirm)
        Do $$$AssertEquals(..Snapshot(), tLate, "and nothing is written")
    }
    Set @tRoot@(3) = "xabcx"
    Do ##class(OcuPilot.Port.GlobalPort).VendorReplaceScan(..#NAMESPACE, ..PreparedName, "abc", "xyz", 1, 1, 20000, 32767, "", .tNodes, .tOccurrences, .tOver, .tLocations, .tStream, .tCaught)
    Do $$$AssertEquals(tNodes _ "|" _ tOver, "3|0", "the walk records the three nodes the replace would change")
    Set tHome = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^" _ ..PreparedName), "^", 2)
    Do $$$AssertEquals($ListToString($Get(tLocations)), tHome, "and, reading each node's destination, the directory they are stored in")
    Set tRecorded = $Order(^||OcuPilotGlobalReplace(""), -1)
    Set tLast = $List(^||OcuPilotGlobalReplace(tRecorded), 1)
    Set tBefore = ..Snapshot()
    Set @tLast = "moved after the walk"
    Set tMoved = ..Snapshot()
    Do ##class(OcuPilot.Port.GlobalPort).VendorReplaceApply(..#NAMESPACE, .tStale, .tCaught)
    Do $$$AssertEquals(tStale _ "|" _ ..Snapshot(), 1 _ "|" _ tMoved, "a recorded node that moved rolls every earlier one back and writes nothing")
    Do $$$AssertEquals($TLevel, 0, "and no transaction is left open")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = "abc"
    Set tQuery("replace") = "xyz"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACE", .tQuery, "", .tFresh, .tHttp, .tFault)
    Set tQuery("digest") = $Select($IsObject($Get(tFresh)): tFresh.Digest, 1: "")
    Do ##class(OcuPilot.Test.GlobalReplaceMoveSeam).Arm("moved before the transaction")
    Set tSC = ##class(OcuPilot.Test.GlobalReplaceMoveSeam).Invoke("Globals", "REPLACEALL", .tQuery, "", .tResult, .tHttp, .tFault)
    Do ##class(OcuPilot.Test.GlobalReplaceMoveSeam).Reset()
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ "|" _ @tRoot@(1) _ "|" _ @tRoot@(3) _ "|" _ $TLevel, "409|GLOBAL.REPLACE.REVIEWCHANGED|" _ ..PreparedMarker _ " abc and abc|moved before the transaction|0", "a node that moves between the walk and the transaction is answered REVIEWCHANGED through the port, with the node set before it rolled back")
    Kill ^||OcuPilotGlobalReplace
    Set ^||OcuPilotGlobalReplace(1) = $ListBuild("^" _ ..PreparedName _ "(1)", @tRoot@(1), "set before the failure")
    Set ^||OcuPilotGlobalReplace(2) = $ListBuild("^" _ ..PreparedName _ "(", "x", "y")
    Set tBefore = ..Snapshot()
    Do ##class(OcuPilot.Port.GlobalPort).VendorReplaceApply(..#NAMESPACE, .tStale, .tCaught)
    Do $$$AssertEquals($IsObject(tCaught) _ "|" _ (..Snapshot() = tBefore) _ "|" _ $TLevel, "1|1|0", "an error inside the transaction rolls back the node set before it and leaves no transaction open")
}

/// <p>AC4. A global of 20,001 nodes is 409 <code>GLOBAL.REPLACE.TOOLARGE</code> to the person and to the agent's mint, and one of 20,000 is reviewed; a replaced
/// value over 32,767 characters is the same refusal, and one of exactly 32,767 is reviewed; a replace that changes nothing, because the text is absent or equals
/// its replacement, is 409 <code>GLOBAL.REPLACE.NOCHANGE</code> to the person and to the agent's mint; a global that holds nothing is 404
/// <code>GLOBAL.NOTFOUND</code>; and the <code>%SYS</code> namespace is 409 <code>GLOBAL.REPLACE.SYSNAMESPACE</code>, over HTTP and at the port. Nothing is
/// written or minted by any.</p>
/// <p>Mutation (Rule 19): raise <parameter>REPLACESCAN</parameter> past 20,001 in <class>OcuPilot.Port.GlobalPort</class> -> the 20,001-node legs go red;
/// compare the replaced value's length with <code>'&lt;</code> in <method>OcuPilot.Port.GlobalPort.VendorReplaceScan</method> -> the 32,767 leg goes red.</p>
Method TestARefusedReplaceWritesNothing()
{
    Set tRoot = "^" _ ..PreparedName
    For tI = 1:1:20001 Set @tRoot@(tI) = "abc"
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "409 GLOBAL.REPLACE.TOOLARGE", "a global of 20,001 nodes is too large")
    Do ..EnableKey()
    Set tSC = ..MintAgent(..AgentArgs(), .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "0|409|GLOBAL.REPLACE.TOOLARGE", "and the agent's proposal of it is refused with nothing minted")
    Kill @tRoot@(20001)
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Do $$$AssertEquals(tStatus _ " " _ ..RowText($Select($IsObject($Get(tReview)): tReview.rows, 1: "")), "200 Find=abc|Replace=xyz|MatchCase=true|Nodes=20000|Occurrences=20000", "and one of 20,000 is reviewed")
    Kill @tRoot
    Set @tRoot@(1) = $Translate($Justify("", 32000), " ", "x") _ "abc"
    Set tStatus = ..Review("abc", $Translate($Justify("", 1000), " ", "y"), 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview) _ "|" _ $Length(@tRoot@(1)), "409 GLOBAL.REPLACE.TOOLARGE|32003", "a replaced value over 32,767 characters is too large, and the value is as it was")
    Set tStatus = ..Review("abc", $Translate($Justify("", 767), " ", "y"), 1, .tReview)
    Do $$$AssertEquals(tStatus, 200, "and a replaced value of exactly 32,767 characters is reviewed")
    Kill @tRoot
    Do ..Make()
    Set tBefore = ..Snapshot()
    Set tStatus = ..Review("zzz", "xyz", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "409 GLOBAL.REPLACE.NOCHANGE", "text no plain-text value holds changes nothing")
    Set tStatus = ..Review("abc", "abc", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "409 GLOBAL.REPLACE.NOCHANGE", "and neither does a replacement equal to the text")
    Set tStatus = ..Replace("zzz", "xyz", 1, "", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "409 GLOBAL.REPLACE.NOCHANGE", "the replace itself is refused the same way")
    Set tSC = ..MintAgent(..AgentArgs("zzz"), .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "0|409|GLOBAL.REPLACE.NOCHANGE", "and so is the agent's proposal, with nothing minted")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing is written")
    Do ..Remove()
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "404 GLOBAL.NOTFOUND", "a global that holds nothing is not found")
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = "abc"
    Set tQuery("replace") = "xyz"
    For tType = "REPLACE", "REPLACEALL" {
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409|GLOBAL.REPLACE.SYSNAMESPACE", tType _ " in %SYS is refused at the port")
    }
    Set tStatus = ..Review("abc", "xyz", 1, .tReview, "%SYS")
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "409 GLOBAL.REPLACE.SYSNAMESPACE", "and over HTTP")
}

/// <p>Text of the wrong shape is refused before anything is read: a find or a replacement with a control character, or over 1,000 characters, is 400
/// <code>GLOBAL.VALUE.SHAPE</code>, an empty find is refused by the route and by the port, a case flag that is not <code>1</code> or <code>0</code> is 400
/// <code>PORT.VALIDATION</code>, and the agent's mint refuses the same arguments <code>TOOL.ARGUMENTS</code> with nothing minted. A replacement may be empty.</p>
/// <p>Mutation (Rule 19): drop the control-character test in <method>OcuPilot.Port.GlobalPort.TextValid</method> -> the control-character rows go red.</p>
Method TestTextOfTheWrongShapeIsRefusedBeforeAnythingIsRead()
{
    Do ..Make()
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild("a" _ $Char(1), "x"), $ListBuild($Translate($Justify("", 1001), " ", "a"), "x"), $ListBuild("abc", "x" _ $Char(10)), $ListBuild("abc", $Translate($Justify("", 1001), " ", "x")) {
        Set tStatus = ..Review($List(tCase, 1), $List(tCase, 2), 1, .tReview)
        Do $$$AssertEquals(..Verdict(tStatus, tReview), "400 GLOBAL.VALUE.SHAPE", "a text with a control character or over 1,000 characters is refused: " _ $Length($List(tCase, 1)) _ "/" _ $Length($List(tCase, 2)))
    }
    Set tStatus = ..Review("", "x", 1, .tReview)
    Do $$$AssertEquals(..Verdict(tStatus, tReview), "400 TOOL.ARGUMENTS", "an empty find is refused by the route")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = ..PreparedName
    Set tQuery("find") = ""
    Set tQuery("replace") = "x"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400|GLOBAL.VALUE.SHAPE", "and by the port")
    Set tQuery("find") = "abc"
    Set tQuery("matchCase") = "2"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "REPLACE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400|PORT.VALIDATION", "a case flag that is not 1 or 0 is refused")
    Set tStatus = ..Review("abc", "", 1, .tReview)
    Do $$$AssertEquals(tStatus _ " " _ ..RowText($Select($IsObject($Get(tReview)): tReview.rows, 1: "")), "200 Find=abc|Replace=|MatchCase=true|Nodes=3|Occurrences=5", "an empty replacement is a replacement")
    Do ..EnableKey()
    For tCase = $ListBuild("", "x"), $ListBuild("a" _ $Char(1), "x"), $ListBuild($Translate($Justify("", 1001), " ", "a"), "x"), $ListBuild("abc", "x" _ $Char(1)) {
        Set tSC = ..MintAgent(..AgentArgs($List(tCase, 1), $List(tCase, 2)), .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ $IsObject($Get(tProposal)) _ "|" _ tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1|0|400|TOOL.ARGUMENTS", "the agent's mint refuses it TOOL.ARGUMENTS with nothing minted: " _ $Length($List(tCase, 1)) _ "/" _ $Length($List(tCase, 2)))
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing is written")
}

/// <p>The kernel's globals arm judges a replace by the nodes it would change, read again as the write reads them (<class>OcuPilot.Test.GlobalLocationSeam</class>
/// answers where they are stored): a name beginning with an OcuPilot stem, in any case, a changing node stored in OcuPilot's own database or a system
/// database, and a code global stored in the install namespace's routines database are refused before any write; a global stored elsewhere is permitted; a
/// read that fails refuses; and a read the port refuses with a 4xx is not judged, because the write is refused the same way.</p>
/// <p>Mutation (Rule 19): drop the <code>Locations</code> check from the replace branch of <method>OcuPilot.Kernel.Proposal.Prohibited.Global</method> (the
/// <code>ProtectedLocation</code> call) -> the directory rows go red.</p>
Method TestTheArmRefusesAProtectedReplaceBeforeAnyWrite()
{
    Set tHome = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE), "^", 2)
    Set tOwn = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^OcuPilotTurnSignal"), "^", 2)
    Set tSystem = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^%ZZNever"), "^", 2)
    Set tUser = $Piece(##class(%SYS.Namespace).GetGlobalDest("USER"), "^", 2)
    Do $$$AssertTrue((tHome '= "") && (tOwn '= "") && (tSystem '= "") && (tUser '= "") && (tOwn '= tHome) && (tSystem '= tHome), "the directories the cases name are distinct")
    Set tRefused = "1 PROHIBITED.PROTECTEDGLOBAL"
    Set tCode = "1 PROHIBITED.OCUPILOTCODE"
    Set tPermitted = "0 "
    For tCase = $ListBuild($ListBuild(tHome), "ZZOcuRepX", "abc", tPermitted, "a global stored in the install namespace's database is permitted"), $ListBuild($ListBuild(tHome), "ocupilotZ", "abc", tRefused, "a name beginning with ocupilot is refused"), $ListBuild($ListBuild(tHome), "OCUPILOTZ", "abc", tRefused, "in any case"), $ListBuild($ListBuild(tHome, tOwn), "ZZOcuRepX", "abc", tRefused, "a changing node stored in OcuPilot's database is refused"), $ListBuild($ListBuild(tSystem), "ZZOcuRepX", "abc", tRefused, "and one stored in a system database"), $ListBuild($ListBuild(tHome, tSystem), "ZZOcuRepX", "abc", tRefused, "among others"), $ListBuild($ListBuild(tHome), "oddDEF", "abc", tCode, "a code global is refused whole"), $ListBuild($ListBuild(tUser), "oddDEF", "abc", tPermitted, "unless it is not the install namespace's code"), $ListBuild($ListBuild(tHome), "ZZOcuRepX", "", tPermitted, "a read the port refuses is not judged") {
        Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($List(tCase, 1))
        Do $$$AssertEquals(..Arm($List(tCase, 2), $List(tCase, 3)), $List(tCase, 4), $List(tCase, 5) _ ": " _ $List(tCase, 2))
    }
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild(tHome), 1)
    Do $$$AssertEquals(..Arm("ZZOcuRepX", "abc"), "error", "a read that fails refuses the write")
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
}

/// <p>AC5, on both callers. A global whose name begins with an OcuPilot stem, here in lower case, is refused <code>PROHIBITED.PROTECTEDGLOBAL</code> with the
/// published sentence before any write: the person's replace after its review and the agent's mint or confirm with its key on. The test's own global, named
/// so, is not changed.</p>
/// <p>Mutation (Rule 19): skip the globals arm in <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -> both legs go red.</p>
Method TestAnOcuPilotNamedGlobalIsNotReplacedOnEitherCaller()
{
    Set ..PreparedName = "ocupilotzzrep" _ $Job
    Do ..AssertRefusedOnEitherCaller()
}

/// <p>AC5, on both callers, for a changing node stored in a system database: the <code>%</code> copy of the test's global, which the namespace stores in the
/// system database, is refused <code>PROHIBITED.PROTECTEDGLOBAL</code> before any write, the arm reading where the changing nodes are stored from the
/// payload each caller's write carries.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ReplaceLocations</method> answer every read as one the port refused -> both legs go
/// red.</p>
Method TestAGlobalStoredInASystemDatabaseIsNotReplacedOnEitherCaller()
{
    Set ..PreparedName = "%ZZOcuRep" _ $Job
    Set tStored = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^" _ ..PreparedName), "^", 2)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GlobalProhibited).DirectoriesOf(.tProtected), "the protected directories are read")
    Do $$$AssertTrue((tStored '= "") && ($ListFind($Get(tProtected), tStored) > 0), "the global is stored in a protected database: " _ tStored)
    Do ..AssertRefusedOnEitherCaller()
}

/// <p>Make the test's global, then assert that the person's replace after its review and the agent's proposal with its key on are refused
/// <code>PROHIBITED.PROTECTEDGLOBAL</code> with the published sentence, and that nothing of the global changes.</p>
Method AssertRefusedOnEitherCaller()
{
    Do ..Make()
    Set tBefore = ..Snapshot()
    Set tSentence = ##class(OcuPilot.Kernel.Proposal.Prohibited).#PROTECTEDGLOBALREASON
    Set tStatus = ..Review("abc", "xyz", 1, .tReview)
    Set tDigest = $Select($IsObject($Get(tReview)) && $IsObject(tReview.review): tReview.review.Digest, 1: "")
    Set tStatus = ..Replace("abc", "xyz", 1, tDigest, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.reason, 1: ""), "403 PROHIBITED.PROTECTEDGLOBAL|" _ tSentence, "the person's replace is refused with the published sentence")
    Do ..EnableKey()
    Set tSC = ..MintAgent(..AgentArgs(), .tProposal, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject($Get(tProposal)) {
        Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
        Do $$$AssertEquals(tConfirm, "403 PROHIBITED.PROTECTEDGLOBAL", "the agent's proposal is refused at its confirm")
    } Else {
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403|PROHIBITED.PROTECTEDGLOBAL", "or at its mint")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing is changed")
}

/// <p>The arm's answer for the replace tool over global <var>pName</var> with find <var>pFind</var>, as <code>prohibits code</code>, or <code>error</code>,
/// asked of <class>OcuPilot.Test.GlobalProhibited</class>, whose reads answer what the location seam was armed with.</p>
ClassMethod Arm(pName As %String, pFind As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("global", ..#NAMESPACE, pName, .tRef)
    If $$$ISERR(tSC) Quit "key: " _ $System.Status.GetErrorText(tSC)
    Set tPayload = {"Name": (pName), "Find": (pFind), "Replace": "x", "MatchCase": true, "Namespace": (..#NAMESPACE)}
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tPayload.%ToJSON(), "[]", .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit "error"
    Quit tProhibits _ " " _ tCode
}

}
