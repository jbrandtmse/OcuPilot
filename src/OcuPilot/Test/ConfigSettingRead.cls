/// <p>Pins Story 21.3's three reads, the gate and the governance defaults (AC1, AC3, AC4; AD-22, AD-29, AD-36): Startup settings, Memory
/// settings and Compatibility settings read through <class>OcuPilot.Port.ConfigPort</class> and the screens' own read executor, each row
/// carrying the kind, the accepted values and the restart and read-only flags the port derives, and every read and write refused to a
/// caller short of a pair before any vendor call. The three set keys ship enabled, and the agent's call mints while its key is enabled and
/// is refused at dispatch once it is not.</p>
/// <p><b>Live-safe:</b> it reads, changes no setting, and stores a governance policy only to restore it. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.ConfigSettingRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Each screen: descriptor, route, side-bar position, classic page, entity type, port endpoint, vendor class, set tool, tool name and
/// the classic pages the tool declares.</p>
Parameter SCREENS = "StartupSettingList|os-management/startup-settings|26|%CSP.UI.Portal.Config.Startup|startup-setting|Startup|Config.Startup|StartupSettingSet|osmgmt.startupsettings.set|%CSP.UI.Portal.MemoryStartup,%CSP.UI.Portal.Config.ValueEditor;MemorySettingList|os-management/memory-settings|27|%CSP.UI.Portal.Config.Memory|memory-setting|Memory|Config.config|MemorySettingSet|osmgmt.memorysettings.set|%CSP.UI.Portal.MemoryStartup,%CSP.UI.Portal.Config.ValueEditor;CompatibilitySettingList|os-management/compatibility-settings|28|%CSP.UI.Portal.Config.Compatibility|compatibility-setting|Compatibility|Config.Miscellaneous|CompatibilitySettingSet|osmgmt.compatibilitysettings.set|%CSP.UI.Portal.Config.ValueEditor";

/// <p>The settings no row lists.</p>
Parameter EXCLUDED = "EnableLongStrings,OsType,Platform,PageSizeAlt,ZaMode,globals2kb,pijdir,wijdir,PasswordHash";

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

/// <p>The config source's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this block too: each case replaces
/// the Startup settings declaration's <code>read.source</code> and names the sentence the registry's read check answers, or
/// <code>null</code>.</p>
XData Cases
{
{
  "cases": [
    {"name": "a config LIST of Startup is sound", "source": {"port": "config", "endpoint": "Startup", "type": "LIST"}, "expected": null},
    {"name": "so is Memory", "source": {"port": "config", "endpoint": "Memory", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not serve", "source": {"port": "config", "endpoint": "Nothing", "type": "LIST"}, "expected": "read.source.endpoint 'Nothing' is not one of the config port's endpoints ('Startup', 'Memory', 'Compatibility') (AD-29)"},
    {"name": "a type other than LIST", "source": {"port": "config", "endpoint": "Startup", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a config source, which lists the instance's startup, memory and compatibility settings (AD-36)"},
    {"name": "rowGet", "source": {"port": "config", "endpoint": "Startup", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Value"], "derived": []}}, "expected": "read.source.rowGet is declared on a config source, which answers its list whole (AD-36)"},
    {"name": "forEach", "source": {"port": "config", "endpoint": "Startup", "type": "LIST", "forEach": ["Value"]}, "expected": "read.source.forEach is declared on a config source, which answers its list whole (AD-36)"},
    {"name": "query", "source": {"port": "config", "endpoint": "Startup", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on a config source, which answers its list whole (AD-36)"},
    {"name": "parts", "source": {"port": "config", "endpoint": "Startup", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a config source, which answers its list whole (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry, and the corpus refuses at least
/// six shapes.</p>
/// <p>Mutation (Rule 19): <code>ReadProblem</code>'s config arm admits any endpoint -> the endpoint case goes red.</p>
Method TestTheConfigSourceRefusals()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Kill tDeclaration
        Do $ClassMethod("OcuPilot.Screen.Descriptor.StartupSettingList", "DeclarationJson", .tDeclaration)
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 6, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>The screen's read of <var>pDescriptor</var> through the shipped executor, answering its result object.</p>
ClassMethod Read(pDescriptor As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ pDescriptor, "", .tResult, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p>A read's rows as an array keyed by name, each the row object, in <var>pRows</var>; the count answered.</p>
ClassMethod RowsByName(pResult As %DynamicObject, Output pRows) As %Integer
{
    Kill pRows
    Set tCount = 0
    If '$IsObject(pResult) Quit 0
    Set tIterator = pResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows(tRow.%Get("Name")) = tRow
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The keys <var>pClass</var>'s own <code>Get</code> answers, comma-joined, in <code>%SYS</code>, with no product class called while there.</p>
ClassMethod VendorKeys(pClass As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = $ClassMethod(pClass, "Get", .tProps)
        Set tKey = ""
        For {
            Set tKey = $Order(tProps(tKey))
            If tKey = "" Quit
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>Whether the vendor says a change of the memory setting <var>pName</var> needs no restart, in <code>%SYS</code>.</p>
ClassMethod NoRestart(pName As %String) As %Boolean
{
    Set tNo = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNo = ''##class(Config.config).NoRestartOnActivate(pName)
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tNo
}

/// <p><b>AC1.</b> Each screen answers one row per key its vendor class's <code>Get</code> answers, less the classic table's exclusions and
/// <code>EnsembleAutoStart</code> on an instance without interoperability, each row carrying exactly <code>Name</code>,
/// <code>Value</code>, <code>Kind</code>, <code>Accepts</code>, <code>Restart</code> and <code>ReadOnly</code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>BuildRow</code> drops the <code>Restart</code> member -> the
/// port's member-list assertion goes red, and so do the restart assertions of
/// <method>TestTheKindsRestartAndReadOnlyFlagsAreTheMatrixOnes</method>.</p>
Method TestEachReadAnswersTheClassesKeysLessTheExclusions()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tScreen = $Piece(..#SCREENS, ";", tI)
        Set tResult = ..Read($Piece(tScreen, "|", 1), .tHttp, .tFault)
        Do $$$AssertTrue($IsObject(tResult), $Piece(tScreen, "|", 1) _ ": the read answers (" _ $Get(tHttp) _ ")")
        If '$IsObject(tResult) Continue
        Set tExpected = ""
        Set tKeys = ..VendorKeys($Piece(tScreen, "|", 7))
        For tJ = 1:1:$Length(tKeys, ",") {
            Set tKey = $Piece(tKeys, ",", tJ)
            If $ListFind($ListFromString(..#EXCLUDED), tKey) Continue
            If (tKey = "EnsembleAutoStart") && '##class(%Library.EnsembleMgr).IsEnsembleInstalled() Continue
            Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ tKey
        }
        Set tCount = ..RowsByName(tResult, .tRows)
        Set tNames = ""
        Set tName = ""
        For {
            Set tName = $Order(tRows(tName))
            If tName = "" Quit
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        }
        Do $$$AssertEquals(tNames, tExpected, $Piece(tScreen, "|", 1) _ ": one row per key the class answers, less the exclusions")
        Do $$$AssertEquals(tResult.%Get("truncated"), 0, $Piece(tScreen, "|", 1) _ ": nothing is truncated")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
        Set tSC = $ClassMethod(..#SEAM, "Rows", $Piece(tScreen, "|", 6), 1000, .tPortRows, .tPortHttp, .tPortFault)
        Set tOk = $$$ISOK(tSC) && (tPortRows.%Size() = tCount)
        Set tIterator = tPortRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPortRow) {
            If ##class(OcuPilot.Test.LicenseKey).Keys(tPortRow) '= "Accepts,Kind,Name,ReadOnly,Restart,Value" Set tOk = 0
        }
        Do $$$AssertEquals(tOk, 1, $Piece(tScreen, "|", 1) _ ": the port answers the same rows, each exactly its six members")
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
    }
}

/// <p><b>AC1 (AD-36).</b> A read capped below the class's key count answers exactly the cap and says it is truncated, through the
/// screens' read executor and the port's own <code>maxRows</code> query; a <code>maxRows</code> that is not a whole number above zero is
/// refused 400 <code>PORT.VALIDATION</code>. A text setting reads its length, a declared <code>SCREENEMPTY</code> lets the screen's Set
/// value send an empty value, and the value is the one value the action names.</p>
/// <p>Mutation (Rule 19): <code>Screen.Read</code>'s config branch asks the port for the cap rather than the cap plus one -> the
/// truncated assertion goes red; <code>SCREENEMPTY</code> on <class>OcuPilot.Screen.Tool.ConfigSettingSet</class> emptied -> the empty-names
/// assertion goes red.</p>
Method TestACappedReadSaysItIsTruncatedAndTheDeclarationsNameTheValue()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tScreen = $Piece(..#SCREENS, ";", tI)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ $Piece(tScreen, "|", 1), 5, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($Select($IsObject(tResult): tResult.%Get("rows").%Size() _ "|" _ tResult.%Get("truncated"), 1: "none"), "5|1", $Piece(tScreen, "|", 1) _ ": a read capped at five answers five rows and says it is truncated")
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tScreen, "|", 8)
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionEmptyNames", "set")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionValueNames", "set")), "Value|Value", tTool _ ": the screen's Set value may send an empty Value, and Value is its one value")
    }
    Kill tQuery
    Set tQuery("maxRows") = 3
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Startup", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1) _ "|" _ tHttp, "3|200", "the port's list stops at maxRows")
    For tBad = "0", "x", "-1", "1.5" {
        Kill tQuery
        Set tQuery("maxRows") = tBad
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Startup", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "a maxRows of " _ tBad _ " is refused")
    }
    Do ..RowsByName(..Read("StartupSettingList"), .tStartup)
    Do $$$AssertEquals(tStartup("SystemMode").Kind _ "|" _ tStartup("SystemMode").Accepts, "text|Text of up to 32 characters.", "a text setting reads its length")
}

/// <p><b>AC1, AC2, AC3.</b> The matrix's reads: the kind and range of <code>ShutdownTimeout</code>, the restart flag of every memory setting
/// equal to the vendor's own <code>NoRestartOnActivate</code> and of the startup and compatibility settings the vendor source names, the
/// read-only rows, and the choices of <code>Undefined</code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>READONLY</code> loses <code>DefaultPort</code> -> the read-only assertion
/// goes red; <code>RESTARTSTARTUP</code> loses <code>ErrorPurge</code> -> the restart assertion goes red.</p>
Method TestTheKindsRestartAndReadOnlyFlagsAreTheMatrixOnes()
{
    Do ..RowsByName(..Read("StartupSettingList"), .tStartup)
    Do ..RowsByName(..Read("MemorySettingList"), .tMemory)
    Do ..RowsByName(..Read("CompatibilitySettingList"), .tCompat)
    Set tRow = tStartup("ShutdownTimeout")
    Do $$$AssertEquals(tRow.Kind _ "|" _ tRow.Accepts _ "|" _ tRow.Restart _ "|" _ tRow.ReadOnly, "integer|A whole number from 120 to 100000.|0|0", "ShutdownTimeout reads an integer from 120 to 100000 and needs no restart")
    For tName = "ErrorPurge", "WebServer", "DefaultPort" {
        Set tRow = tStartup(tName)
        Do $$$AssertEquals(tRow.Restart, 1, tName _ " reads restart true, by the vendor's own source")
    }
    Set tRestart = ""
    Set tName = ""
    For {
        Set tName = $Order(tStartup(tName))
        If tName = "" Quit
        If tStartup(tName).Restart Set tRestart = tRestart _ $Select(tRestart = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tRestart, "DefaultPort,ErrorPurge,MaxIRISTempSizeAtStart,WebServer", "and no other startup setting states a restart")
    For tName = "DefaultPort", "DefaultPortBindAddress", "WebServer", "WebServerName", "WebServerPort", "WebServerProtocol", "TempDirectory", "WebServerURLPrefix" {
        Set tRow = tStartup(tName)
        Do $$$AssertEquals(tRow.ReadOnly _ "|" _ tRow.Accepts, "1|Shown here and never changed here.", tName _ " is shown and never changed")
    }
    Do $$$AssertEquals(tStartup("DBSizesAllowed").Kind, "blocksizes", "DBSizesAllowed reads block sizes")
    Set tOk = 1
    Set tName = ""
    For {
        Set tName = $Order(tMemory(tName))
        If tName = "" Quit
        If tMemory(tName).Restart '= '..NoRestart(tName) Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "every memory setting's restart flag is the opposite of the vendor's NoRestartOnActivate")
    Do $$$AssertEquals(tMemory("errlog").Restart _ "|" _ tMemory("history").Restart, "1|0", "errlog needs a restart and history does not")
    Do $$$AssertEquals(tMemory("errlog").Kind _ "|" _ tMemory("errlog").Accepts, "integer|A whole number of at least 10.", "errlog declares a minimum and no maximum, and reads that minimum alone")
    For tName = "globals4kb", "globals8kb", "globals16kb", "globals32kb", "globals64kb", "routines", "bbsiz" {
        Do $$$AssertTrue($Data(tMemory(tName)), tName _ " is a row here: no form owns it")
    }
    For tName = "ConsoleFile", "LibPath", "Path", "PythonPath", "PythonRuntimeLibrary", "VMSConsoleTerminal" {
        Do $$$AssertEquals(tMemory(tName).ReadOnly, 1, tName _ " is a path and is shown, never set")
    }
    Do $$$AssertEquals($Data(tMemory("globals2kb")) _ $Data(tMemory("pijdir")) _ $Data(tMemory("wijdir")), "000", "the excluded memory settings are not rows")
    Do $$$AssertEquals(tCompat("NullSubscripts").Restart, 1, "NullSubscripts states a restart")
    Do $$$AssertEquals(tCompat("Undefined").Kind _ "|" _ tCompat("Undefined").Accepts, "choice|One of 0, 1, 2.", "Undefined reads a choice of 0, 1 and 2")
    Do $$$AssertEquals($Data(tCompat("ZaMode")), 0, "ZaMode is not a row")
}

/// <p>AC1. A <code>GET</code> answers the one row the list answers for the name, and a name the class does not list, in any other case, is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>.</p>
Method TestAGetAnswersOneRowAndAnUnknownNameIsAbsent()
{
    Kill tQuery
    Set tQuery("name") = "ShutdownTimeout"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Startup", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a listed setting reads")
    Do ..RowsByName(..Read("StartupSettingList"), .tStartup)
    Do $$$AssertEquals(tRow.%ToJSON(), tStartup("ShutdownTimeout").%ToJSON(), "and is the row the list answers")
    For tName = "shutdowntimeout", "NoSuchSetting", "", "EnableLongStrings", "PasswordHash", "history" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Startup", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|CONFIG.SETTING.NOTFOUND", "'" _ tName _ "' is not a startup setting")
    }
}

/// <p>AC1. Every read is refused to a caller short of a pair, naming the first one missing, and Compatibility asks for
/// <code>%Admin_Secure:USE</code> beside the others while Startup does not.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Admit</code> answers OK without evaluating the pairs -> the denial
/// assertions go red.</p>
Method TestEveryReadIsRefusedToACallerShortOfItsPairs()
{
    For tEndpoint = "Startup", "Memory", "Compatibility" {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|AUTH.NOPRIVILEGE|%Admin_Manage:USE|0", tEndpoint _ ": a caller holding nothing is refused naming the first pair and answers no rows")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%DB_IRISSYS:READ", "a caller holding %Admin_Manage:USE alone is refused %DB_IRISSYS:READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding both read pairs reads the startup settings")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Memory", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "and the memory settings")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Compatibility", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|%Admin_Secure:USE|0", "but not the compatibility settings without %Admin_Secure:USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Compatibility", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "which a caller holding it reads")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Compatibility", 10, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the screens' own list call is gated by the same pairs")
}

/// <p>AC1. Every write is refused to a caller who holds the read pairs but not <code>%DB_IRISSYS:WRITE</code>, naming that pair, and the
/// compatibility write also to one without <code>%Admin_Secure:USE</code>, each before any vendor call.</p>
/// <p>Mutation (Rule 19): <code>WRITEPAIRS</code> without <code>%DB_IRISSYS:WRITE</code> -> every write row goes red.</p>
Method TestEveryWriteIsRefusedToACallerWithoutTheWritePair()
{
    Kill tQuery
    Set tQuery("name") = "ShutdownTimeout"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "SET", .tQuery, {"Value": "301"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%Admin_Manage:USE", "a caller holding no pair is refused the write naming the first read pair, which the write set holds too")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    For tCase = $ListBuild("Startup", "ShutdownTimeout", "301"), $ListBuild("Memory", "history", "501"), $ListBuild("Compatibility", "LineRecall", "0") {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), "SET", .tQuery, {"Value": ($List(tCase, 3))}, .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail, "403|AUTH.NOPRIVILEGE|%DB_IRISSYS:WRITE", $List(tCase, 1) _ ": a set is refused naming the write pair first")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tQuery("name") = "LineRecall"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Compatibility", "SET", .tQuery, {"Value": "0"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%Admin_Secure:USE", "a caller holding the write pair but not %Admin_Secure:USE is refused the compatibility write")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies"), "", "and nothing reached the vendor")
}

/// <p>AC1, AC3, AD-5, AD-44, AD-51, AD-53. The three screens declare the classic pages, positions 26 to 28, the config read source and their
/// pairs (Compatibility's <code>%Admin_Secure:USE</code> as its own), and the three tools declare their screen action, their port and the
/// classic pages that replace the Memory and Startup page and the value editor.</p>
/// <p>Mutation (Rule 19): <code>CompatibilitySettingSet</code> declares no <code>CLASSICPAGES</code> -> the declaration assertion goes red.</p>
Method TestTheScreensAndToolsDeclareTheirPagesPairsAndActions()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tScreen = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tScreen, "|", 1)
        Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), tClass _ ": the declaration parses")
        Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), $Piece(tScreen, "|", 2) _ "|os-management|" _ $Piece(tScreen, "|", 3), tClass _ ": its route, area and side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $Piece(tScreen, "|", 4), tClass _ ": its classic page")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert($Piece(tScreen, "|", 4), "O", "URL")), $Piece(tScreen, "|", 4), tClass _ ": which the portal's own resolver recognises (AD-44)")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), $Piece(tScreen, "|", 5) _ "|set", tClass _ ": its entity type and its one action")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "config|" _ $Piece(tScreen, "|", 6) _ "|LIST", tClass _ ": it reads through the config port")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read is the declared grammar")
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), tClass _ ": it requires the classic table's pairs and not the write pair")
        Set tOwn = $ClassMethod(tClass, "OwnPrivilegePairs")
        Do $$$AssertEquals($Select($Piece(tScreen, "|", 6) = "Compatibility": $ListToString($List(tOwn, 1), ","), 1: $ListLength(tOwn)), $Select($Piece(tScreen, "|", 6) = "Compatibility": "%Admin_Secure,USE", 1: 0), tClass _ ": Compatibility's own pair is %Admin_Secure:USE and the others own none")
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tScreen, "|", 8)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $Piece(tScreen, "|", 9) _ "|set|" _ ..#PORT _ "|" _ $Piece(tScreen, "|", 6), tTool _ ": its name, its screen action, its port and its endpoint")
        Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), $Piece(tScreen, "|", 10), tTool _ ": the classic pages it replaces")
        Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody") _ ''$ClassMethod(tTool, "Destructive") _ $ListToString($ClassMethod(tTool, "ReadBackFields")), "10Value", tTool _ ": a merge write that is not destructive and reads its value back")
    }
}

/// <p>AC4. The three keys ship enabled, so with none stored the agent's call mints a proposal for each tool, and with a key stored
/// disabled that call is refused <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.startupsettings.set</code> set <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> ->
/// the baseline assertion and the minted assertion go red for that key.</p>
Method TestTheKeysShipEnabledAndADisabledKeyRefusesTheAgentAtDispatch()
{
    For tCase = $ListBuild("osmgmt.startupsettings.set", "ShutdownTimeout", "301", "Startup"), $ListBuild("osmgmt.memorysettings.set", "history", "501", "Memory"), $ListBuild("osmgmt.compatibilitysettings.set", "LineRecall", "0", "Compatibility") {
        Set tKey = $List(tCase, 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), "1|baseline", tKey _ " ships enabled by the baseline")
        Set tInput = {"Name": ($List(tCase, 2)), "rationale": "probe", "expectedImpact": "probe"}
        Do tInput.%Set("Value", ..Unlike($List(tCase, 4), $List(tCase, 2), $List(tCase, 3)) _ "", "string")
        Set tAnswer = ..Dispatched(tKey, tInput, .tContent)
        Do $$$AssertEquals(tAnswer, "minted", tKey _ ": the agent's call mints a proposal under the baseline: " _ tContent)
        Kill tSettings
        Set tSettings(tKey) = "disabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), tKey _ " is stored disabled")
        Set tAnswer = ..Dispatched(tKey, tInput, .tContent)
        Do $$$AssertEquals(tAnswer _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", tKey _ ": the same call is refused by the governance gate")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    }
}

/// <p><var>pCandidate</var>, or, when the setting <var>pName</var> of <var>pEndpoint</var> already holds it, another value the setting
/// accepts, so a test that mints a change never depends on the value the instance happens to hold.</p>
ClassMethod Unlike(pEndpoint As %String, pName As %String, pCandidate As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.ConfigPort).Invoke(pEndpoint, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    If '$IsObject($Get(tRow)) || (tRow.%Get("Value") '= pCandidate) Quit pCandidate
    Set tLimits = ##class(OcuPilot.Port.ConfigPort).Limits(pEndpoint, pName)
    Set tKind = $ListGet(tLimits, 1)
    If tKind = "boolean" Quit 'pCandidate
    If tKind = "choice" {
        Set tChoices = $ListGet(tLimits, 4)
        For tI = 1:1:$ListLength(tChoices) If $List(tChoices, tI) '= pCandidate Quit
        Quit $List(tChoices, tI)
    }
    If ($ListGet(tLimits, 3) '= "") && ((pCandidate + 1) > $ListGet(tLimits, 3)) Quit pCandidate - 1
    Quit pCandidate + 1
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> or <code>refused</code>; the answer's content is in
/// <var>pContent</var>. A minted proposal is never confirmed.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pContent As %String) As %String
{
    Set pContent = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_config"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set pContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Quit $Select($IsObject(tParsed) && (tParsed.%Get("proposalId") '= ""): "minted", 1: "refused")
}

}
