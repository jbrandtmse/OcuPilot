/// <p>Pins Story 21.14's NLS configured defaults read, the locale-format switch's seams and the gate (AC1; AD-4, AD-22, AD-29, AD-36, AD-53, AD-59): NLS
/// configured defaults read through <class>OcuPilot.Port.ConfigPort</class> and the screens' own read executor answers twenty rows, each the
/// vendor's configured table (<code>%SYS.NLS.Table</code>) else the current locale's, with its <code>Source</code>; a table row is refused at the
/// mint and at the port before any vendor call; the locale-format switch reaches the node and the reload through the port's seams and its copy-out
/// script; and every read and write is refused to a caller short of a pair.</p>
/// <p><b>Live-safe:</b> it reads, changes no default, and stores a governance policy only to restore it. <b>What it needs from the environment:</b>
/// OcuPilot installed and serving.</p>
Class OcuPilot.Test.NlsDefaultRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.NlsDefaultList";

Parameter TOOL = "OcuPilot.Screen.Tool.NlsDefaultSet";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The nineteen categories and the property of the current locale each inherits (<code>CSP</code> has none), as the vendor's classic page
/// reads them.</p>
Parameter CATEGORIES = "Process=TranZCVT,IRISTerminal=TranProgrammer,OtherTerminal=TranTerminal,File=TranSequential,Magtape=TranMagTape,TCPIP=TranTCP,DSMDDP=TranDDP,DTMDCP=TranDTMDCP,SystemCall=TranSystemCall,Printer=TranPrinter,PatternMatch=PatternTable,Identifier=IdentifierTable,Uppercase=UpperCaseTable,Lowercase=LowerCaseTable,Titlecase=TitleCaseTable,Accent=AccentTable,Collation=CollationTable,XYAction=XYTable,CSP=";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Hold every pair the port's two sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The screen's read of the NLS configured defaults through the shipped executor, answering its result object.</p>
ClassMethod Read(Output pHttp As %Integer) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, "", .tResult, .pHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p>The rows of <var>pResult</var> by name, in <var>pRows</var>; the count.</p>
ClassMethod RowsByName(pResult As %DynamicObject, Output pRows) As %Integer
{
    Kill pRows
    If '$IsObject(pResult) Quit 0
    Set tIterator = pResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows(tRow.%Get("Name")) = tRow
    }
    Quit pResult.%Get("rows").%Size()
}

/// <p>What the vendor itself answers for every category, in <var>pExpected</var> as <code>name = $ListBuild(value, source)</code>: the configured table
/// of <code>%SYS.NLS.Table("Config")</code> while one is set, else the current locale's own property read through its <code>Get</code>
/// (<code>CSP</code> else <code>UTF8</code>). Read in <code>%SYS</code>, independently of the port.</p>
ClassMethod Expected(Output pExpected) As %Status
{
    Kill pExpected
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tConfig = ##class(%SYS.NLS.Table).%New("Config")
        Kill tProps
        Set tSC = ##class(Config.NLS.Locales).Get($Get(^%SYS("LOCALE", "CURRENT")), .tProps)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$Length(..#CATEGORIES, ",") {
            Set tName = $Piece($Piece(..#CATEGORIES, ",", tI), "=", 1)
            Set tProperty = $Piece($Piece(..#CATEGORIES, ",", tI), "=", 2)
            Set tConfigured = $Property(tConfig, tName)
            If tConfigured '= "" {
                Set pExpected(tName) = $ListBuild(tConfigured, "config")
            } Else {
                Set pExpected(tName) = $ListBuild($Select(tProperty = "": "UTF8", 1: $Get(tProps(tProperty))), "locale")
            }
        }
        Set pExpected("LocaleFormat") = $ListBuild(''$Get(^SYS("NLS", "Config", "LocaleFormat")), $Select($Data(^SYS("NLS", "Config", "LocaleFormat")): "config", 1: "locale"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p><b>AC1.</b> The screen's read answers twenty rows, one per category and the locale-format switch, each holding the vendor's configured table
/// else the current locale's and saying which it is, and the port's own list answers the same rows. A table row is read only, with no restart and no
/// purge; the switch is a boolean and the one row the screen's Set value may change.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>CollectNls</code> answers the locale's table even when a configured one
/// is set -> <method>TestAConfiguredTableWinsOverTheLocalesAndSaysConfig</method> goes red; <code>NLSCATEGORIES</code> loses <code>DSMDDP</code> ->
/// the count assertion goes red.</p>
Method TestEveryRowIsTheVendorsConfiguredTableElseTheLocalesWithItsSource()
{
    Do $$$AssertStatusOK(..Expected(.tExpected), "the vendor's own answer is read")
    Set tResult = ..Read(.tHttp)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Set tCount = ..RowsByName(tResult, .tRows)
    Do $$$AssertEquals(tCount, 20, "nineteen categories and the locale-format switch")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "nothing is truncated")
    Set tName = ""
    For {
        Set tName = $Order(tExpected(tName))
        If tName = "" Quit
        If '$Data(tRows(tName)) {
            Do $$$AssertTrue(0, tName _ ": the screen lists it")
            Continue
        }
        Set tRow = tRows(tName)
        Do $$$AssertEquals(tRow.%Get("Value") _ "|" _ tRow.%Get("Source"), $List(tExpected(tName), 1) _ "|" _ $List(tExpected(tName), 2), tName _ ": its value and its source are the vendor's")
        If tName = "LocaleFormat" {
            Do $$$AssertEquals(tRow.%Get("Kind") _ "|" _ tRow.%Get("ReadOnly") _ "|" _ tRow.%Get("Restart") _ "|" _ tRow.%Get("Purges"), "boolean|0|0|0", "the switch is a boolean the screen may change")
        } Else {
            Do $$$AssertEquals(tRow.%Get("ReadOnly") _ "|" _ tRow.%Get("Restart") _ "|" _ tRow.%Get("Purges") _ "|" _ tRow.%Get("Accepts"), "1|0|0|" _ ##class(OcuPilot.Api.ConfigError).#ACCEPTSREADONLY, tName _ ": a table row is shown and never changed")
        }
    }
    Do ..HoldAll()
    Set tSC = $ClassMethod(..#SEAM, "Rows", "NLSDefaults", 1000, .tPortRows, .tPortHttp, .tPortFault)
    Set tOk = $$$ISOK(tSC) && (tPortRows.%Size() = tCount)
    Set tIterator = tPortRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPortRow) {
        If ##class(OcuPilot.Test.LicenseKey).Keys(tPortRow) '= "Accepts,Kind,Name,Purges,ReadOnly,Restart,Source,Value" Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "the port answers the same rows, each exactly its eight members")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals($Parameter(..#PORT, "NLSCATEGORIES"), ..#CATEGORIES, "the port's category map is the one this test pins")
}

/// <p>A read of one name answers its row, and a name the endpoint does not list, written in another letter case or empty is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>. The other endpoints' rows carry no <code>Source</code>.</p>
/// <p>Mutation (Rule 19): <code>BuildRow</code> writes <code>Source</code> for every row -> the startup row assertion goes red.</p>
Method TestAGetAnswersOneRowAndOtherEndpointsCarryNoSource()
{
    Kill tQuery
    Set tQuery("name") = "Collation"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "NLSDefaults", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tRow)): tRow.%Get("Name") _ "|" _ tRow.%IsDefined("Source"), 1: ""), "200|Collation|1", "a listed name answers its row with its source")
    For tName = "collation", "", "NoSuchDefault" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "NLSDefaults", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404|CONFIG.SETTING.NOTFOUND", "'" _ tName _ "' is not a default")
    }
    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Startup", "LIST", .tQuery, "", .tStartup, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tStartup)): tStartup.%Get(0).%IsDefined("Source"), 1: -1), 0, "a startup row carries no source")
}

/// <p><b>AC1.</b> A table row's set is refused <code>CONFIG.SETTING.READONLY</code> before any vendor call at the port, and at the agent's mint with
/// the published sentence; a value the switch does not accept is refused <code>CONFIG.SETTING.VALUE</code>, and a name the list does not hold
/// <code>CONFIG.SETTING.NOTFOUND</code>. No node is written and no locale reloaded.</p>
/// <p>Mutation (Rule 19): <code>IsNls</code> rows read <code>ReadOnly</code> 0 -> the refusal rows go red.</p>
Method TestATableRowIsRefusedAtThePortAndTheMintBeforeAnyVendorCall()
{
    Do ..HoldAll()
    For tCase = $ListBuild("Accent", "Unicode", 409, "CONFIG.SETTING.READONLY"), $ListBuild("CSP", "UTF8", 409, "CONFIG.SETTING.READONLY"), $ListBuild("LocaleFormat", "2", 400, "CONFIG.SETTING.VALUE"), $ListBuild("LocaleFormat", "", 400, "CONFIG.SETTING.VALUE"), $ListBuild("Nothing", "1", 404, "CONFIG.SETTING.NOTFOUND") {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 1)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "NLSDefaults", "SET", .tQuery, {"Value": ($List(tCase, 2))}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 1) _ " set to '" _ $List(tCase, 2) _ "' is refused")
        Set tArgs = {"Name": ($List(tCase, 1))}
        Do tArgs.%Set("Value", $List(tCase, 2), "string")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, $List(tCase, 1), tArgs, .tProposal, .tMintHttp, .tProblem)
        Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tProblem), "0|" _ $Select($List(tCase, 4) = "CONFIG.SETTING.NOTFOUND": "'" _ $List(tCase, 1) _ "' is not present on this instance", 1: ##class(OcuPilot.Api.ConfigError).ReasonFor($List(tCase, 4))), $List(tCase, 1) _ ": the mint refuses it in the published sentence (an absent name in the sibling mints' own)")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies"), "", "no node was written")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Reloads"), 0, "and no locale was reloaded")
}

/// <p><b>AC1.</b> A set of the switch reaches the node seam with the value and nothing else (the port reloads nothing itself), and the reload
/// the set tool owes runs through the reload seam only when the value moved, always when no value before the write is known, never for a table row,
/// and a reload that fails is 500 <code>INTERNAL</code>, logged, after the write.</p>
/// <p>Mutation (Rule 19): <code>ReloadAfterSet</code> reloads whatever the setting reads -> the unchanged row goes red; <code>Apply</code> sends the
/// node of the SQL Shell for an NLS name -> the seam row goes red.</p>
Method TestTheSwitchReachesTheNodeSeamAndTheReloadRunsOnlyWhenItMoved()
{
    Do ..HoldAll()
    Kill tQuery
    Set tQuery("name") = "LocaleFormat"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "NLSDefaults", "SET", .tQuery, {"Value": "1"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Modifies") _ "|" _ $ClassMethod(..#SEAM, "Reloads") _ "|" _ tOut.%Get("Name") _ "|" _ tOut.%Get("Value"), "200|NLS|LocaleFormat|1|0|LocaleFormat|1", "the set reaches the node seam with the value and reloads nothing itself")
    Set tNow = $Select(..NodeValue() = 1: 1, 1: 0)
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "LocaleFormat", tNow, 1, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#SEAM, "Reloads"), "1|0", "a value that reads as it did before the write reloads nothing")
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "LocaleFormat", 'tNow, 1, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#SEAM, "Reloads"), "1|1", "a value that moved reloads the current locale once")
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "LocaleFormat", "", 0, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#SEAM, "Reloads"), "1|2", "with no value before the write known, it reloads")
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "Accent", "", 0, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#SEAM, "Reloads"), "1|2", "a table row owes no reload")
    Do $ClassMethod(..#SEAM, "ReloadFails")
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "LocaleFormat", "", 0, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Faults"), "1|500|INTERNAL|INTERNAL|error", "a reload that fails is 500 INTERNAL and the raw status is logged")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = $ClassMethod(..#SEAM, "ReloadAfterSet", "NLSDefaults", "LocaleFormat", "", 0, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, "the reload is gated like the write: a caller holding no pair is refused")
}

/// <p>The node's value as the vendor's own global holds it, or <code>""</code>.</p>
ClassMethod NodeValue() As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValue = $Get(^SYS("NLS", "Config", "LocaleFormat"))
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p><b>AD-59.</b> The copy-out script of the switch's set is the node set with literal subscripts and the value as a string literal, followed by
/// the reload step, which the tool drops when the draft's diff shows the value unchanged; a table row renders no script.</p>
/// <p>Mutation (Rule 19): <code>Snippet</code> renders a variable subscript -> the literal assertion goes red.</p>
Method TestTheCopyOutScriptSetsTheNodeWithLiteralSubscriptsAndReloads()
{
    Kill tQuery
    Set tQuery("name") = "LocaleFormat"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "NLSDefaults", "SET", .tQuery, {"Value": "1"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "the set renders one step")
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).%Get("text"), 1: ""), " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set ^SYS(""NLS"", ""Config"", ""LocaleFormat"") = ""1""", "the step sets the node with literal subscripts and the value as a literal")
    Set tReload = $ClassMethod(..#PORT, "ReloadSteps", "NLSDefaults", "LocaleFormat")
    Do $$$AssertEquals($Select(tReload.%Size() = 1: tReload.%Get(0).%Get("text"), 1: ""), " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tSC = ##class(Config.NLS.Locales).Reload()", "the reload step calls the vendor's Reload")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReloadSteps", "NLSDefaults", "Accent").%Size(), 0, "a table row owes no reload step")
    Set tAfter = $ClassMethod(..#TOOL, "SnippetAfter", "NLSDefaults", "name", "LocaleFormat", {}, {"diff": ["Value"]})
    Do $$$AssertEquals(tAfter.%Size(), 1, "a diff that moved the value keeps the reload step")
    Set tAfter = $ClassMethod(..#TOOL, "SnippetAfter", "NLSDefaults", "name", "LocaleFormat", {}, {"diff": []})
    Do $$$AssertEquals(tAfter.%Size(), 0, "and one that left it unchanged drops it")
    Set tQuery("name") = "Accent"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "NLSDefaults", "SET", .tQuery, {"Value": "x"}).%Size(), 0, "a table row renders no script")
}

/// <p>AC1, AD-29. A caller holding no pair is refused a read naming the first, one holding the read pairs is admitted a read and refused a write
/// naming <code>%DB_IRISSYS:WRITE</code>, each before any vendor call.</p>
/// <p>Mutation (Rule 19): <code>Admit</code> answers OK without evaluating the pairs -> the denial rows go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "NLSDefaults", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%Admin_Manage:USE", "a caller holding no pair is refused the read naming the first pair")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "NLSDefaults", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding the read pairs reads")
    Set tQuery("name") = "LocaleFormat"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "NLSDefaults", "SET", .tQuery, {"Value": "1"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "403|%DB_IRISSYS:WRITE|", "and is refused the write naming the write pair, with nothing sent")
}

/// <p>AC1, AD-5, AD-44, AD-53. The screen declares the classic page, the config source's <code>NLSDefaults</code> endpoint, OS management's thirty-sixth
/// side-bar position and the classic pages' pairs; its tool declares its name, its one screen action, its port, that it is a merge write that is
/// not destructive, the reload consequence and the page it replaces; and the three set keys the baseline lists are enabled.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.nlsdefaults.set</code> set <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the key
/// assertion goes red.</p>
Method TestTheScreenAndToolDeclareTheirPageActionAndKey()
{
    Set tClass = ..#SCREEN
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition") _ "|" _ $ClassMethod(tClass, "ClassicPage"), "os-management/nls-defaults|os-management|36|%CSP.UI.Portal.NLSConfigDefs", "its route, area, position and classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.NLSConfigDefs", "O", "URL")), "%CSP.UI.Portal.NLSConfigDefs", "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "nls-default|set", "its entity type and its one action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "config|NLSDefaults|LIST", "it reads through the config port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "it requires the classic page's pairs and not the write pair")
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), "osmgmt.nlsdefaults.set|set|" _ ..#PORT _ "|NLSDefaults", "the tool's name, action, port and endpoint")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), "%CSP.UI.Portal.NLS", "the classic page it replaces")
    Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody") _ ''$ClassMethod(tTool, "Destructive") _ $ListToString($ClassMethod(tTool, "ReadBackFields")), "10Value", "a merge write that is not destructive and reads its value back")
    Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {"Name": "LocaleFormat"}) _ "|" _ $Parameter(tTool, "RELOADCODE"), ##class(OcuPilot.Api.ConfigError).#NLSRELOAD _ "|" _ ##class(OcuPilot.Api.ConfigError).#NLSRELOAD, "its card states the reload consequence, pinned to the error class's")
    Do $$$AssertEquals(##class(OcuPilot.Api.ConfigError).ReasonFor(##class(OcuPilot.Api.ConfigError).#NLSRELOAD), "Changing this reloads the current locale, so new processes take its date, time and number formats.", "and its sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("osmgmt.nlsdefaults.set"), "1|baseline", "the key ships enabled by the baseline")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).IsKnown("nls-default"), 1, "the entity type is declared")
}

}
