/// <p>Pins Story 21.19's Security advisor read, gate and declarations (AC1, AC6; AD-8, AD-13, AD-29, AD-36, AD-44): the port and the screen answer one row
/// per recommendation the classic page's own <code>GetRecommendations</code> lists, in its order and capped; a type's general row, an element with a slash
/// and a type or code the rosters do not name read as the port says; every read and write is refused to a caller short of a pair before the page is read;
/// and the screen, its tools and its keys declare their pages, pairs and actions.</p>
/// <p><b>Live-safe:</b> it reads, changes no ignore flag, and stores a governance policy only to restore it. <b>What it needs from the environment:</b>
/// OcuPilot installed and serving.</p>
Class OcuPilot.Test.AdvisorRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.AdvisorPort";

Parameter SEAM = "OcuPilot.Test.AdvisorSeam";

Parameter ENDPOINT = "SecurityAdvisor";

Parameter LIST = "OcuPilot.Screen.Descriptor.SecurityAdvisorList";

Parameter IGNORE = "OcuPilot.Screen.Tool.SecurityAdvisorIgnore";

Parameter UNIGNORE = "OcuPilot.Screen.Tool.SecurityAdvisorUnignore";

/// <p>The pane's seven types, in the order the port's area roster names them.</p>
Parameter TYPES = "Auditing,Services,Roles,Users,AppsCSP,AppsRoutine,AppsExecutable";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>The composite id of the recommendation <var>pType</var>, <var>pElement</var>, <var>pCode</var>.</p>
ClassMethod Id(pType As %String, pElement As %String, pCode As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pType, pElement, pCode))
}

/// <p>The Security area's screen verdicts <var>pJson</var> as a principal's navigation map answers them, with the Security advisor added as Security's
/// last listed screen, after Mobile phone providers. It declares the same first two pairs, so a principal denied one of them carries the phone
/// providers' verdict; one holding both is denied on the third, <code>%DB_IRISSYS:WRITE</code>, which none of the map's principals holds. A map with no
/// Mobile phone providers entry is answered as it is.</p>
ClassMethod WithAdvisor(pJson As %String) As %String
{
    Set tMark = "{""route"":""security/phone-providers"",""labelKey"":""phoneProviderListLabel"",""sideBarPosition"":15,"
    If pJson '[ tMark Quit pJson
    Set tVerdict = $Piece($Piece(pJson, tMark, 2), "}", 1)
    If tVerdict = """allowed"":true" Set tVerdict = """allowed"":false,""failedPair"":""%DB_IRISSYS:WRITE"""
    Set tAdvisor = ",{""route"":""security/advisor"",""labelKey"":""securityAdvisorLabel"",""sideBarPosition"":16," _ tVerdict _ "}"
    Quit $Extract(pJson, 1, *-1) _ tAdvisor _ "]"
}

/// <p>The port's call <var>pType</var> of <var>pClass</var> on <var>pEndpoint</var> with the query keys <var>pKey</var> and <var>pValue</var>.</p>
ClassMethod Call(pClass As %String, pType As %String, pKey As %String, pValue As %String, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    If pKey '= "" Set tQuery(pKey) = pValue
    Quit $ClassMethod(pClass, "Invoke", ..#ENDPOINT, pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The fault code of <var>pFault</var>, <code>""</code> when it is not an object.</p>
ClassMethod CodeOf(pFault As %DynamicObject) As %String
{
    Quit $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The failed pair of <var>pFault</var>'s detail, or <code>""</code>.</p>
ClassMethod PairOf(pFault As %DynamicObject) As %String
{
    Quit $Select($IsObject(pFault) && $IsObject(pFault.%Get("detail")): pFault.detail.%Get("failedPair"), 1: "")
}

/// <p>The row <var>pRow</var> as the pane's line spells it, <code>type|element|code|ignored</code>.</p>
ClassMethod LineOf(pRow As %DynamicObject) As %String
{
    Quit pRow.%Get("Type") _ "|" _ pRow.%Get("Element") _ "|" _ pRow.%Get("Code") _ "|" _ ''pRow.%Get("Ignored")
}

/// <p>The value <var>pKey</var> maps to in the roster parameter <var>pRoster</var> of the port, <code>key=value</code> entries joined by
/// <code>|</code>, or <code>""</code> when it names none.</p>
ClassMethod Rostered(pRoster As %String, pKey As %String) As %String
{
    Set tRoster = $Parameter(..#PORT, pRoster)
    For tI = 1:1:$Length(tRoster, "|") {
        Set tEntry = $Piece(tRoster, "|", tI)
        If $Piece(tEntry, "=", 1) = pKey Quit
    }
    If $Piece(tEntry, "=", 1) '= pKey Quit ""
    Quit $Piece(tEntry, "=", 2, *)
}

/// <p><b>AC1.</b> The port answers one row per recommendation the page's own <code>GetRecommendations</code> lists, in the page's order, each
/// <code>{Type, Area, Element, Code, Recommendation, Ignored}</code> with the area and the sentence its rosters publish and <code>Ignored</code> a
/// boolean; the screen's read answers the same rows.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.AdvisorPort</class>'s <code>Recommendations</code> drops the elements whose name is a single space -> the count
/// and the sequence assertions go red.</p>
Method TestTheRowsAreThePanesRecommendationsInItsOrder()
{
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Do $$$AssertTrue(tCount > 0, "the page lists recommendations to read: " _ tCount)
    Set tSC = ..Call(..#PORT, "LIST", "maxRows", tCount + 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list answers")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertEquals(tRows.%Size(), tCount, "one row per recommendation")
    Set tBad = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ..LineOf(tRow) '= $Get(tPane(tIndex + 1)) Set tBad = tBad _ " " _ (tIndex + 1)
        If ##class(OcuPilot.Test.LicenseKey).Keys(tRow) '= "Area,Code,Element,Ignored,Recommendation,Type" Set tBad = tBad _ " keys" _ (tIndex + 1)
        If tRow.%GetTypeOf("Ignored") '= "boolean" Set tBad = tBad _ " boolean" _ (tIndex + 1)
        If tRow.%Get("Area") '= $Select(..Rostered("ADVISORAREAS", tRow.%Get("Type")) '= "": ..Rostered("ADVISORAREAS", tRow.%Get("Type")), 1: tRow.%Get("Type")) Set tBad = tBad _ " area" _ (tIndex + 1)
        If tRow.%Get("Code") = $Parameter(..#PORT, "PUBLICROLESCODE") {
            If tRow.%Get("Recommendation") '= $ClassMethod(..#SEAM, "PaneRoles") Set tBad = tBad _ " roles" _ (tIndex + 1)
        } ElseIf tRow.%Get("Recommendation") '= $Select(..Rostered("ADVISORTEXTS", tRow.%Get("Code")) '= "": ..Rostered("ADVISORTEXTS", tRow.%Get("Code")), 1: tRow.%Get("Code")) {
            Set tBad = tBad _ " text" _ (tIndex + 1)
        }
    }
    Do $$$AssertEquals(tBad, "", "each row is the page's line in the page's order, with exactly its six members, a boolean flag, and the area and sentence its rosters publish")
    Set tResult = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tScreen, .tScreenHttp, .tScreenFault)
    Do $$$AssertTrue($IsObject($Get(tScreen)), "the screen's read answers (" _ $Get(tScreenHttp) _ ")")
    If '$IsObject($Get(tScreen)) Quit
    Set tShown = tScreen.%Get("rows").%Size()
    Do $$$AssertEquals(tShown, $Select(tScreen.%Get("truncated"): tShown, 1: tCount), "the screen answers every recommendation unless it reports a cut")
    Do $$$AssertEquals(..LineOf(tScreen.%Get("rows").%Get(0)), $Get(tPane(1)), "and starts with the page's first")
}

/// <p><b>AC1.</b> A list is capped by <code>maxRows</code>: the first rows in the page's order, and an empty cap is the default; a cap that is not a whole number
/// above zero is a 500.</p>
/// <p>Mutation (Rule 19): <code>Rows</code> ignores its cap -> the two-row assertion goes red.</p>
Method TestAListIsCappedByMaxRowsAndTakesTheFirstRowsInOrder()
{
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Do $$$AssertTrue(tCount > 2, "the page lists enough recommendations to cap")
    Set tSC = ..Call(..#PORT, "LIST", "maxRows", 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "a cap of two answers two rows")
    Do $$$AssertEquals(..LineOf(tRows.%Get(0)) _ ";" _ ..LineOf(tRows.%Get(1)), tPane(1) _ ";" _ tPane(2), "which are the page's first two")
    Set tSC = ..Call(..#PORT, "LIST", "", "", .tAll, .tAllHttp, .tAllFault)
    Do $$$AssertEquals(tAllHttp _ "|" _ tAll.%Size(), "200|" _ $Select(tCount > 1000: 1000, 1: tCount), "no cap reads up to the default of one thousand")
    For tBadCap = "0", "x", "-1", "1.5" {
        Set tSC = ..Call(..#PORT, "LIST", "maxRows", tBadCap, .tNone, .tBadHttp, .tBadFault)
        Do $$$AssertEquals(tBadHttp _ "|" _ ..CodeOf(tBadFault), "500|" _ $Parameter("OcuPilot.Api.Error", "INTERNAL"), "a cap of '" _ tBadCap _ "' is refused")
    }
}

/// <p><b>AC1, AD-36.</b> The screen's read honors its cap: a cap below the recommendation count answers exactly that many rows and reports the cut, and a cap
/// above it answers every row and reports none.</p>
/// <p>Mutation (Rule 19): the advisor branch of <class>OcuPilot.Screen.Read</class>'s <code>Execute</code> asks the port for <code>tMax</code> rows in place of
/// <code>tMax + 1</code> -> the cut is never reported and the first assertion goes red.</p>
Method TestTheScreenReadReportsACutAtItsCap()
{
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Do $$$AssertTrue(tCount > 2, "the page lists enough recommendations to cap")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 2, .tCut, .tCutHttp, .tCutFault)
    Do $$$AssertTrue($IsObject($Get(tCut)), "a capped read answers (" _ $Get(tCutHttp) _ ")")
    If $IsObject($Get(tCut)) {
        Do $$$AssertEquals(tCut.%Get("rows").%Size() _ "|" _ ''tCut.%Get("truncated"), "2|1", "a cap of two answers two rows and says it cut")
    }
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, tCount + 5, .tWhole, .tWholeHttp, .tWholeFault)
    Do $$$AssertTrue($IsObject($Get(tWhole)), "a read capped above the count answers (" _ $Get(tWholeHttp) _ ")")
    If $IsObject($Get(tWhole)) {
        Do $$$AssertEquals(tWhole.%Get("rows").%Size() _ "|" _ ''tWhole.%Get("truncated"), tCount _ "|0", "a cap above the count answers every row and reports no cut")
    }
}

/// <p><b>AD-36.</b> An advisor read source is refused when it names another endpoint or a request type other than the list, or declares a per-row, per-parent,
/// fixed-query or parts member.</p>
/// <p>Mutation (Rule 19): the advisor arm of <class>OcuPilot.Screen.Registry</class>'s <code>ReadProblem</code> accepts any <code>type</code> -> the type
/// assertion goes red.</p>
Method TestAnAdvisorReadSourceIsRefusedWhenItDeclaresAnythingButTheWholeList()
{
    Do $$$AssertStatusOK($ClassMethod(..#LIST, "DeclarationJson", .tDeclaration), "the list's declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(..Variant(tDeclaration, "", "")), "", "the declared source is accepted")
    Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(..Variant(tDeclaration, "endpoint", "Other"))
    Do $$$AssertTrue(tProblem [ "is not the advisor port's endpoint", "another endpoint is refused by the advisor arm: " _ tProblem)
    Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(..Variant(tDeclaration, "type", "GET"))
    Do $$$AssertTrue(tProblem [ "is declared on an advisor source", "another request type is refused by the advisor arm: " _ tProblem)
    For tKey = "rowGet", "forEach", "query", "parts" {
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(..Variant(tDeclaration, tKey, "x"))
        Do $$$AssertTrue(tProblem [ ("read.source." _ tKey _ " is declared on an advisor source"), "a declared " _ tKey _ " is refused by the advisor arm: " _ tProblem)
    }
}

/// <p>A copy of the declaration <var>pDeclaration</var> whose read source holds <var>pValue</var> at <var>pKey</var>; the copy is the declaration itself when
/// <var>pKey</var> is empty.</p>
ClassMethod Variant(pDeclaration As %DynamicObject, pKey As %String, pValue As %String) As %DynamicObject
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pDeclaration.%ToJSON())
    If pKey '= "" Do tCopy.read.source.%Set(pKey, pValue)
    Quit tCopy
}

/// <p><b>AD-13, AC1.</b> Armed with rows the page may hold: a type's general row (an element of one space), an element with slashes, a type and a code the
/// rosters do not name, and rows given out of order. The list answers them in type, element, code order, a known type and code as their published
/// words and an unknown one as itself; a row is read by its composite id, the single space and the slashes kept; a malformed id and an absent row are 404
/// <code>PORT.NOTFOUND</code>.</p>
/// <p>Mutation (Rule 19): <code>Find</code> trims its element -> the general row's read goes red.</p>
Method TestTheGeneralRowAnUnknownCodeAndASlashElementReadAsThePortSaysTheyDo()
{
    Do $ClassMethod(..#SEAM, "Arm", [["Users", "bob", "UserNotUsed", 0], ["Roles", " ", "AuditCount", 1], ["AppsCSP", "/api/admin", "AppIsPublic", 0], ["Mystery", "x", "NoSuchCode", 1], ["Roles", " ", "MGRCount", 0]])
    Set tSC = ..Call(..#SEAM, "LIST", "", "", .tRows, .tHttp, .tFault)
    Set tOrder = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOrder = tOrder _ $Select(tOrder = "": "", 1: ";") _ ..LineOf(tRow)
    }
    Do $$$AssertEquals(tOrder, "AppsCSP|/api/admin|AppIsPublic|0;Mystery|x|NoSuchCode|1;Roles| |AuditCount|1;Roles| |MGRCount|0;Users|bob|UserNotUsed|0", "type, then element, then code")
    Set tSC = ..Call(..#SEAM, "ROW", "id", ..Id("Mystery", "x", "NoSuchCode"), .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRow.%Get("Area") _ "|" _ tRow.%Get("Recommendation"), "200|Mystery|NoSuchCode", "an unknown type and code answer themselves")
    Set tSC = ..Call(..#SEAM, "ROW", "id", ..Id("Roles", " ", "AuditCount"), .tGeneral, .tGeneralHttp, .tGeneralFault)
    Do $$$AssertEquals(tGeneralHttp _ "|" _ tGeneral.%Get("Area") _ "|" _ tGeneral.%Get("Element") _ "|" _ tGeneral.%Get("Recommendation") _ "|" _ tGeneral.%Get("Ignored"), "200|Roles| |READ and WRITE privilege to the audit database should be restricted|1", "a type's general row keeps its single space, and its sentence is the published one")
    Set tSC = ..Call(..#SEAM, "ROW", "id", ..Id("AppsCSP", "/api/admin", "AppIsPublic"), .tSlash, .tSlashHttp, .tSlashFault)
    Do $$$AssertEquals(tSlashHttp _ "|" _ tSlash.%Get("Area") _ "|" _ tSlash.%Get("Element"), "200|Web applications|/api/admin", "an element with slashes round-trips and its area is the published one")
    For tId = ..Id("Roles", "", "AuditCount"), ..Id("Roles", "  ", "AuditCount"), ..Id("Roles", " ", "NoSuchCode"), "Roles", "", ..Id("Roles", " ", "AuditCount") _ $Char(1) _ "x" {
        Set tSC = ..Call(..#SEAM, "ROW", "id", tId, .tNone, .tAbsentHttp, .tAbsentFault)
        Do $$$AssertEquals(tAbsentHttp _ "|" _ ..CodeOf(tAbsentFault), "404|PORT.NOTFOUND", "'" _ $Translate(tId, $Char(1), "/") _ "' names no row")
    }
}

/// <p><b>AC1.</b> The page's second line under the <code>_PUBLIC</code> roles sentence reads the roles <code>_PUBLIC</code> holds, not its code, while
/// the sentence above it reads as published; with no roles to read it answers its code, as an unknown code does.</p>
/// <p>Mutation (Rule 19): <code>Listed</code> skips <method>OcuPilot.Port.AdvisorPort.PublicRoles</method> -> the roles row goes red.</p>
Method TestThePublicRolesLineReadsTheRolesPublicHolds()
{
    Set tCode = $Parameter(..#PORT, "PUBLICROLESCODE")
    Do $ClassMethod(..#SEAM, "Arm", [["Users", " ", "PUBLICRolesList", 0], ["Users", " ", (tCode), 0]])
    Do $ClassMethod(..#SEAM, "ArmPublicRoles", "%Developer,%Operator")
    Set tSC = ..Call(..#SEAM, "LIST", "", "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "the list answers both lines")
    Do $$$AssertEquals(tRows.%Get(0).%Get("Recommendation"), ..Rostered("ADVISORTEXTS", "PUBLICRolesList"), "the sentence reads as published")
    Do $$$AssertEquals(tRows.%Get(1).%Get("Code") _ "|" _ tRows.%Get(1).%Get("Recommendation"), tCode _ "|%Developer,%Operator", "the second line reads the roles")
    Do $ClassMethod(..#SEAM, "ArmPublicRoles", "")
    Set tSC = ..Call(..#SEAM, "ROW", "id", ..Id("Users", " ", tCode), .tRow, .tRowHttp, .tRowFault)
    Do $$$AssertEquals(tRowHttp _ "|" _ tRow.%Get("Recommendation"), "200|" _ tCode, "with no roles to read it answers its code")
}

/// <p><b>AC6, AD-29.</b> Every read and every write is refused to a caller short of a pair, naming the first pair it lacks, and the page is read for none of
/// them: <code>Calls</code> stays empty. A caller holding all three reads.</p>
/// <p>Mutation (Rule 19): <code>Gate</code> returns success before it checks the pairs -> the refusal rows go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfAPairBeforeThePageIsRead()
{
    Do $ClassMethod(..#SEAM, "Arm", [["Roles", " ", "AuditCount", 0]])
    Set tId = ..Id("Roles", " ", "AuditCount")
    For tPair = "%Admin_Secure:USE", "%DB_IRISSYS:READ", "%DB_IRISSYS:WRITE" {
        Do $ClassMethod(..#SEAM, "DenyPair", tPair)
        For tType = "LIST", "ROW", "IGNORE", "UNIGNORE" {
            Set tSC = ..Call(..#SEAM, tType, "id", tId, .tOut, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ ..CodeOf(tFault) _ "|" _ ..PairOf(tFault) _ "|" _ $IsObject($Get(tOut)), "403|PORT.ACCESSDENIED|" _ tPair _ "|0", tType _ " by a caller lacking " _ tPair _ " is refused naming it")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and the page was neither read nor written")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", [["Roles", " ", "AuditCount", 0]])
    Set tSC = ..Call(..#SEAM, "LIST", "", "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|1", "a caller holding all three pairs reads")
    Set tSC = ..Call(..#SEAM, "PURGE", "id", tId, .tNone, .tOtherHttp, .tOtherFault)
    Do $$$AssertEquals(tOtherHttp _ "|" _ ..CodeOf(tOtherFault), "501|PORT.NOTIMPLEMENTED", "another request type is not implemented")
    Do $ClassMethod(..#SEAM, "Clear")
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, {"extra": 1}, .tBodyOut, .tBodyHttp, .tBodyFault)
    Do $$$AssertEquals(tBodyHttp, 500, "a caller's body is refused")
}

/// <p><b>AC1.</b> The rosters hold the pane's seven types and its thirty-nine sentences, and every code and type the instance lists now is one of them, so the
/// screen publishes words for each row it reads.</p>
/// <p>Mutation (Rule 19): drop an entry from <parameter>ADVISORTEXTS</parameter> -> the entry count or the listed-code assertion goes red.</p>
Method TestTheRostersNameTheSevenTypesAndEverySentenceTheInstanceLists()
{
    Set tAreas = $Parameter(..#PORT, "ADVISORAREAS")
    Set tTexts = $Parameter(..#PORT, "ADVISORTEXTS")
    Do $$$AssertEquals($Length(tAreas, "|"), 7, "seven areas")
    Do $$$AssertEquals($Length(tTexts, "|"), 39, "thirty-nine sentences")
    Set tKeys = ""
    For tI = 1:1:7 Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ $Piece($Piece(tAreas, "|", tI), "=", 1)
    Do $$$AssertEquals(tKeys, ..#TYPES, "the areas are the pane's types, in order")
    Set tEmpty = ""
    For tI = 1:1:39 {
        If $Piece($Piece(tTexts, "|", tI), "=", 2, *) = "" Set tEmpty = tEmpty _ " " _ tI
    }
    Do $$$AssertEquals(tEmpty, "", "every code carries a sentence")
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Set tUnknown = ""
    For tI = 1:1:tCount {
        Set tType = $Piece(tPane(tI), "|", 1)
        Set tCode = $Piece(tPane(tI), "|", 3)
        If ..Rostered("ADVISORAREAS", tType) = "" Set tUnknown = tUnknown _ " type " _ tType
        If (tCode '= $Parameter(..#PORT, "PUBLICROLESCODE")) && (..Rostered("ADVISORTEXTS", tCode) = "") Set tUnknown = tUnknown _ " code " _ tCode
    }
    Do $$$AssertEquals(tUnknown, "", "every type and code the instance lists now is on the rosters")
    Do $$$AssertEquals(..Rostered("ADVISORTEXTS", "PUBLICHasRoles"), "_PUBLIC user should not have roles", "a sentence names the _PUBLIC user as the instance does")
}

/// <p><b>AC1, AC6, AD-5, AD-44, AD-51, AD-53.</b> The list declares the classic advisor page, the Security area, the next free position, the advisor read
/// source and the three pairs the page raises without; each tool declares its port, endpoint, request types and kind, the screen's action, and the two
/// 409s as its precondition codes; the two keys ship enabled.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.SecurityAdvisorUnignore</class> declares <code>WRITETYPE</code> <code>IGNORE</code> -> the type
/// assertion goes red.</p>
Method TestTheScreenAndToolsDeclareTheirPagePairsActionsAndKeys()
{
    Set tClass = ..#LIST
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the list's declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), "security/advisor|security|16", "its route, area and side-bar position")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.sec.utilsyssecurityadvisor", "its classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "security-recommendation|ignore,unignore", "its entity type and its two row actions")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "advisor|SecurityAdvisor|LIST", "it reads through the advisor port")
    Do $$$AssertEquals(tDeclaration.id.parts.%Get(0) _ "|" _ tDeclaration.id.parts.%Get(1) _ "|" _ tDeclaration.id.parts.%Get(2) _ "|" _ tDeclaration.toolIdentifier, "Type|Element|Code|security.advisor", "its id is the type, the element and the code")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertEquals($ListLength(tPairs) _ "|" _ ''$ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) _ ''$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) _ ''$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "3|111", "it requires the three pairs the port gates on")
    Do $$$AssertEquals($Parameter(..#PORT, "PAIRS"), "%Admin_Secure:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE", "which are the port's own, in the order it reports them")
    For tTool = ..#IGNORE, ..#UNIGNORE {
        Do $$$AssertEquals($ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "IdParam") _ "|" _ $Parameter(tTool, "READTYPE") _ "|" _ $ClassMethod(tTool, "SendsBody") _ "|" _ ''$ClassMethod(tTool, "Destructive"), ..#PORT _ "|SecurityAdvisor|id|ROW|0|0", tTool _ ": its port, endpoint, id parameter, read type, no body and not destructive")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "PreconditionCodes")), "ADVISOR.IGNORED,ADVISOR.NOTIGNORED", tTool _ ": the port's two 409s are its precondition codes")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")) _ "|" _ $Parameter(tTool, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(tTool, "PRECONDITIONFIELD"), "|Ignored|Ignored", tTool _ ": no settable field, and the flag is its fingerprint and precondition")
        Do $$$AssertEquals($ClassMethod(tTool, "MintClass"), "OcuPilot.Screen.Tool.SecurityAdvisorMint", tTool _ ": the composite mint")
    }
    Do $$$AssertEquals($Parameter(..#IGNORE, "TOOLNAME") _ "|" _ $Parameter(..#IGNORE, "WRITETYPE") _ "|" _ $ListToString($ClassMethod(..#IGNORE, "ScreenActionIds")), "security.advisor.ignore|IGNORE|ignore", "the ignore tool's name, request type and screen action")
    Do $$$AssertEquals($Parameter(..#UNIGNORE, "TOOLNAME") _ "|" _ $Parameter(..#UNIGNORE, "WRITETYPE") _ "|" _ $ListToString($ClassMethod(..#UNIGNORE, "ScreenActionIds")), "security.advisor.unignore|UNIGNORE|unignore", "and the stop-ignoring tool's")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("security.advisor.ignore"), "1|baseline", "the ignore key ships enabled")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("security.advisor.unignore"), "1|baseline", "and so does the stop-ignoring key")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Api.AdvisorError", "ReasonFor", "ADVISOR.IGNORED") _ "|" _ $ClassMethod("OcuPilot.Api.Error", "ReasonForToolCode", "ADVISOR.NOTIGNORED"), "This recommendation is already ignored.|This recommendation is not ignored.", "the two refusals carry their published sentences, through the one writer")
}

}
