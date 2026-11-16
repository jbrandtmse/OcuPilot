/// <p>Pins Story 21.12's Mirror monitor (AD-29, AD-36, AD-44): its read, its banner, the read tool and the screen's declaration through
/// <class>OcuPilot.Port.MirrorPort</class>, on the instance's own state read live and on the armed states of
/// <class>OcuPilot.Test.MirrorPortFixture</class>, and the port's refusal of a caller short of a pair before any vendor call.</p>
/// <p><b>Live-safe:</b> it reads, and writes nothing. <b>What it needs from the environment:</b> OcuPilot installed and serving; the
/// live tests derive their expectations from <code>$System.Mirror.IsMember()</code> and <code>$System.License.NoMirror()</code>.</p>
Class OcuPilot.Test.MirrorRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.MirrorPort";

Parameter SEAM = "OcuPilot.Test.MirrorPortFixture";

Parameter READER = "OcuPilot.Test.MirrorReadFixture";

Parameter MONITOR = "OcuPilot.Screen.Descriptor.MirrorMonitor";

Parameter FIELDS = "MemberName,CurrentRole,CurrentStatus,JournalLatency,DatabaseLatency";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

/// <p>Hold both pairs the port requires, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
}

/// <p>The Monitor's read through <var>pReader</var> (the shipped executor or the fixture's), answering its result object.</p>
ClassMethod Read(pReader As %String, pMaxRows As %String = "", Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set tSC = $ClassMethod(pReader, "Execute", ..#MONITOR, pMaxRows, .tResult, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p>The state the instance's own accessors give, as the port names it.</p>
ClassMethod LiveState() As %String
{
    Set tMember = +$System.Mirror.IsMember()
    Quit $Select(tMember = 1: "Failover", tMember = 2: "Async", $System.License.NoMirror(): "Unlicensed", 1: "NotMember")
}

/// <p><b>AC1.</b> The port's state, the screen's read and the read tool each show the state <code>IsMember()</code> and
/// <code>NoMirror()</code> give now: on an instance that is no member, no rows and the banner that state selects, and the empty
/// text the descriptor names.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.MirrorPort</class>'s <code>State</code> answers <code>NotMember</code> whatever
/// <code>NoMirror()</code> reads -> this goes red on an instance whose license does not allow mirroring.</p>
Method TestTheLiveStateIsTheInstancesOwn()
{
    Do ..HoldAll()
    Set tExpected = ..LiveState()
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "State", "GET", .tQuery, "", .tState, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the state reads")
    Do $$$AssertEquals(tState.%Get("State"), tExpected, "it names the state the instance's accessors give")
    If tExpected = "NotMember" || (tExpected = "Unlicensed") Do $$$AssertEquals(tState.%Get("MirrorName"), "", "an instance that is no member names no mirror")
    Set tResult = ..Read("OcuPilot.Screen.Read")
    Do $$$AssertTrue($IsObject(tResult), "the screen's read answers")
    If '$IsObject(tResult) Quit
    Set tBanner = $Case(tExpected, "NotMember": "mirrorNotMemberBanner", "Unlicensed": "mirrorUnlicensedBanner", : "")
    Do $$$AssertEquals(tResult.%Get("banner"), tBanner, "its banner is the one the state selects")
    If tExpected = "Failover" || (tExpected = "Async") Quit
    Do $$$AssertEquals(tResult.%Get("rows").%Size() _ "|" _ tResult.%Get("truncated"), "0|0", "an instance that is no member has no rows")
    Do $$$AssertEquals($ClassMethod(..#MONITOR, "EmptyStateKey"), "mirrorMonitorEmpty", "and the screen names the empty text")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.mirrormonitor.read", .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the read tool is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool answers")
    If '$IsObject($Get(tView)) Quit
    Do $$$AssertEquals(tView.rows.%Size(), tResult.%Get("rows").%Size(), "the tool answers the screen's rows")
    Do $$$AssertEquals(tView.fields.%ToJSON(), ..FieldsJson(), "and its five fields")
}

/// <p>The vendor query the port reads, unfixtured: its row specification lists each of the port's five fields, and a read on an
/// instance that is no member runs the query, which refuses, leaves the caller's namespace as it was and answers no rows.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.MirrorPort</class>'s <code>FIELDS</code> renames <code>CurrentStatus</code> to
/// <code>Status</code> -> the row-specification assertion goes red; <code>MemberRows</code> drops its namespace restore -> the
/// namespace assertion goes red.</p>
Method TestTheVendorQueryCarriesTheFieldsAndTheReadRestoresTheNamespace()
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tSpec = ""
    Set tQuery = ##class(%Dictionary.CompiledQuery).%OpenId("SYS.Mirror||MemberStatusList")
    If $IsObject(tQuery) Set tSpec = tQuery.Parameters.GetAt("ROWSPEC")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tSpec '= "", "the vendor query declares a row specification")
    Set tMissing = ""
    Set tFields = $Parameter(..#PORT, "FIELDS")
    Do $$$AssertEquals(tFields, ..#FIELDS, "the port's field list is the five this class pins")
    For tI = 1:1:$Length(tFields, ",") {
        Set tField = $Piece(tFields, ",", tI)
        If ("," _ tSpec _ ",") '[ ("," _ tField _ ":") Set tMissing = tMissing _ tField _ " "
    }
    Do $$$AssertEquals(tMissing, "", "each field the port reads is a column of that query")
    If +$System.Mirror.IsMember() '= 0 Quit
    Set tSC = $ClassMethod(..#PORT, "MemberRows", 10, .tRows)
    Do $$$AssertStatusNotOK(tSC, "the vendor query itself ran and refused an instance that is no member")
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "the read leaves the caller's namespace as it was")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 0, "and, on an instance that is no member, answers no rows")
}

/// <p>The Monitor's five fields as the JSON array a read answers them in.</p>
ClassMethod FieldsJson() As %String
{
    Quit ##class(%DynamicArray).%FromJSON("[""" _ $Replace(..#FIELDS, ",", """,""") _ """]").%ToJSON()
}

/// <p><b>AC2.</b> A failover and an async member answer their state, their mirror's name and their three rows with the five fields and no banner; a licensed
/// instance that is no member answers <code>NotMember</code> with no rows, and neither a non-member nor an unlicensed instance reaches
/// the vendor's member query.</p>
/// <p>Mutation (Rule 19): the row builder of <class>OcuPilot.Port.MirrorPort</class> drops <code>CurrentStatus</code> -> the field
/// assertion goes red.</p>
Method TestEachArmedStateAnswersItsRowsAndBanner()
{
    Do ..HoldAll()
    For tCase = $ListBuild(1, 0, 3, "Failover", ""), $ListBuild(2, 0, 3, "Async", ""), $ListBuild(0, 0, 0, "NotMember", "mirrorNotMemberBanner"), $ListBuild(0, 1, 0, "Unlicensed", "mirrorUnlicensedBanner") {
        Do $ClassMethod(..#SEAM, "Arm", $List(tCase, 1), $List(tCase, 2), 3)
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "State", "GET", .tQuery, "", .tState, .tHttp, .tFault)
        Do $$$AssertEquals(tState.%Get("State") _ "|" _ tState.%Get("MirrorName"), $List(tCase, 4) _ "|" _ $Select($List(tCase, 1) = 0: "", 1: $Parameter(..#SEAM, "ARMEDNAME")), $List(tCase, 4) _ ": the state, and the mirror's name on a member only")
        Set tResult = ..Read(..#READER)
        Do $$$AssertTrue($IsObject(tResult), $List(tCase, 4) _ ": the screen's read answers")
        If '$IsObject(tResult) Continue
        Do $$$AssertEquals(tResult.%Get("rows").%Size() _ "|" _ tResult.%Get("banner"), $List(tCase, 3) _ "|" _ $List(tCase, 5), $List(tCase, 4) _ ": its rows and banner")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Queries"), $Select($List(tCase, 3) = 0: 0, 1: 1), $List(tCase, 4) _ ": the vendor's member query ran only on a member")
        If $List(tCase, 3) > 0 {
            Set tRow = tResult.%Get("rows").%Get(0)
            Set tFields = ""
            For tI = 1:1:5 Set tFields = tFields _ $Select(tRow.%IsDefined($Piece(..#FIELDS, ",", tI)): 1, 1: 0)
            Do $$$AssertEquals(tFields, "11111", $List(tCase, 4) _ ": each row carries the five fields")
            Do $$$AssertEquals(tRow.%Get("MemberName") _ "|" _ tRow.%Get("CurrentRole") _ "|" _ tRow.%Get("CurrentStatus") _ "|" _ tRow.%Get("JournalLatency") _ "|" _ tRow.%Get("DatabaseLatency"), "Member1|Primary|Active|Caught up 1|Behind 1", $List(tCase, 4) _ ": and each field holds the vendor's value")
        }
    }
}

/// <p><b>AC2.</b> A member whose mirror holds more rows than the cap answers the cap and reports truncation; at the cap exactly it
/// reports none (AD-36).</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Read</class> asks the mirror port for the cap rather than the cap plus one -> the
/// truncation assertion goes red.</p>
Method TestARowCountPastTheCapReportsTruncation()
{
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "Arm", 1, 0, 5)
    Set tCut = ..Read(..#READER, 3)
    Do $$$AssertEquals(tCut.%Get("rows").%Size() _ "|" _ tCut.%Get("truncated"), "3|1", "five rows under a cap of three answer three and say so")
    Set tWhole = ..Read(..#READER, 5)
    Do $$$AssertEquals(tWhole.%Get("rows").%Size() _ "|" _ tWhole.%Get("truncated"), "5|0", "five rows under a cap of five answer five and say nothing")
}

/// <p><b>AC3.</b> A caller missing one of the port's pairs is refused 403 <code>AUTH.NOPRIVILEGE</code> naming the first it lacks, on
/// every endpoint and on the screens' own list call, before any vendor call: an armed member's query never runs.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.MirrorPort</class>'s <code>Admit</code> answers OK without evaluating the pairs -> the
/// denial assertions go red.</p>
Method TestEveryReadIsRefusedToACallerShortOfItsPairs()
{
    Do $ClassMethod(..#SEAM, "Arm", 1, 0, 3)
    For tHeld = "", "%Admin_Operate" {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        If tHeld '= "" Do ##class(OcuPilot.Test.ScreenGate).Hold(tHeld, "USE")
        Set tWant = $Select(tHeld = "": "%Admin_Operate:USE", 1: "%DB_IRISSYS:READ")
        For tCase = $ListBuild("Members", "LIST"), $ListBuild("State", "GET") {
            Kill tQuery
            Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tOut, .tHttp, .tFault)
            Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
            Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tOut), "403|AUTH.NOPRIVILEGE|" _ tWant _ "|0", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused naming " _ tWant)
        }
        Set tSC = $ClassMethod(..#SEAM, "Rows", "Members", 10, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 403, "the screens' own list call is gated too")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Queries"), 0, "and no vendor query ran")
}

/// <p>The port serves its two endpoints and nothing else: another endpoint, or a type the endpoint does not serve, is refused 501
/// <code>PORT.NOTIMPLEMENTED</code> after the gate, and a cap of the wrong shape 400 <code>PORT.VALIDATION</code>.</p>
/// <p>Mutation (Rule 19): <code>Serves</code> answers 1 for every write type -> the write-type assertion goes red.</p>
Method TestAnyOtherEndpointOrTypeIsNotImplemented()
{
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "Arm", 1, 0, 3)
    For tCase = $ListBuild("Members", "GET"), $ListBuild("State", "LIST"), $ListBuild("Nothing", "LIST"), $ListBuild("Members", "DELETE"), $ListBuild("State", "SET") {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "501|PORT.NOTIMPLEMENTED", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is not implemented")
    }
    Kill tQuery
    Set tQuery("maxRows") = "0"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Members", "LIST", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "400|PORT.VALIDATION", "a cap of zero is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Queries"), 0, "and no vendor query ran")
}

/// <p><b>AC1, AC3, AD-5, AD-44.</b> The screen declares the classic Mirror Monitor page, OS management's thirty-third position, no
/// entity and no action, the mirror source and its banner, and the pairs of the classic System Operation menu with the write pair as
/// its own, so a holder of the area's pairs without <code>%DB_IRISSYS:WRITE</code> finds it unavailable naming that pair.</p>
/// <p>Mutation (Rule 19): the declaration's <code>ownPrivileges</code> emptied -> the own-pair assertion goes red.</p>
Method TestTheScreenDeclaresItsPagePairsAndSource()
{
    Set tClass = ..#MONITOR
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), "os-management/mirror-monitor|os-management|33", "its route, area and side-bar position")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Mirror.Monitor", "its classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert($ClassMethod(tClass, "ClassicPage"), "O", "URL")), $ClassMethod(tClass, "ClassicPage"), "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "|", "it names no entity and no action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "mirror|Members|LIST", "it reads through the mirror port")
    Do $$$AssertEquals(tDeclaration.banner.source.port _ "|" _ tDeclaration.banner.source.endpoint _ "|" _ tDeclaration.banner.field, "mirror|State|State", "and its banner reads the state")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "its read and banner are the declared grammar")
    Do $$$AssertEquals($ListToString($List($ClassMethod(tClass, "OwnPrivilegePairs"), 1), ","), "%DB_IRISSYS,WRITE", "the write pair is the screen's own")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Operate", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "it requires the three pairs")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tFailed = ""
    Set tHeld = ##class(OcuPilot.Test.ScreenGate).EvaluateRequired(tPairs, .tFailed)
    Do $$$AssertEquals(tHeld _ "|" _ tFailed, "0|%DB_IRISSYS:WRITE", "a holder of the area's pairs is refused naming the write pair")
}

/// <p>The mirror source's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this block too: each case replaces the
/// Mirror monitor declaration's <code>read.source</code> and names the sentence the registry's read check answers, or
/// <code>null</code>.</p>
XData Cases
{
{
  "cases": [
    {"name": "a mirror LIST of Members is sound", "source": {"port": "mirror", "endpoint": "Members", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not serve", "source": {"port": "mirror", "endpoint": "Nothing", "type": "LIST"}, "expected": "read.source.endpoint 'Nothing' is not one of the mirror port's endpoints ('Members') (AD-29)"},
    {"name": "a type other than LIST", "source": {"port": "mirror", "endpoint": "Members", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a mirror source, which lists the instance's mirror members (AD-36)"},
    {"name": "rowGet", "source": {"port": "mirror", "endpoint": "Members", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Value"], "derived": []}}, "expected": "read.source.rowGet is declared on a mirror source, which answers its list whole (AD-36)"},
    {"name": "forEach", "source": {"port": "mirror", "endpoint": "Members", "type": "LIST", "forEach": ["Value"]}, "expected": "read.source.forEach is declared on a mirror source, which answers its list whole (AD-36)"},
    {"name": "query", "source": {"port": "mirror", "endpoint": "Members", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on a mirror source, which answers its list whole (AD-36)"},
    {"name": "parts", "source": {"port": "mirror", "endpoint": "Members", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a mirror source, which answers its list whole (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry, and the corpus refuses at least
/// five shapes.</p>
/// <p>Mutation (Rule 19): <code>ReadProblem</code>'s mirror arm admits any endpoint -> the endpoint case goes red.</p>
Method TestTheMirrorSourceRefusals()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Kill tDeclaration
        Do $ClassMethod(..#MONITOR, "DeclarationJson", .tDeclaration)
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 5, "the corpus refuses its shapes: " _ tRefusals)
}

}
