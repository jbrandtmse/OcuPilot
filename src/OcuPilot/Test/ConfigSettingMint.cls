/// <p>Pins Story 21.3's agent-side halves that the other three classes leave to the port (AC1, AC2, AC3; AD-29, AD-55): every refusal row of
/// <class>OcuPilot.Test.ConfigSettingRules</class>'s matrix asked again at the set tools' mint, each setting the screens show and never
/// change refused at both callers (the port through <class>OcuPilot.Test.ConfigGateSeam</class>, which records the vendor call it never
/// makes, and the mint), and each restart statement checked against the source it names: the vendor's own
/// <code>NoRestartOnActivate</code> for a memory setting, the classic value editor's own list for compatibility, and the product's
/// startup list, with the card's consequence for each.</p>
/// <p><b>Live-safe:</b> no setting is changed and the vendor is never called to write; the only writes are the proposal rows a mint stores,
/// which the test removes. <b>What it needs from the environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.ConfigSettingMint Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter RULES = "OcuPilot.Test.ConfigSettingRules";

/// <p>The start of the sentence the mint answers for a value the setting already holds, which the rules have admitted by then.</p>
Parameter NOCHANGE = "nothing would change";

/// <p>Endpoint, set tool, vendor class.</p>
Parameter TOOLS = "Startup|OcuPilot.Screen.Tool.StartupSettingSet|Config.Startup;Memory|OcuPilot.Screen.Tool.MemorySettingSet|Config.config;Compatibility|OcuPilot.Screen.Tool.CompatibilitySettingSet|Config.Miscellaneous";

/// <p>The settings each endpoint shows and never changes: the four network settings of the default superserver and the web server, and
/// every path. The roster of the read-only half; <method>TestEveryReadOnlyRowIsRefusedAtBothCallers</method> derives the rest from it.</p>
Parameter READONLYROSTER = "Startup|DefaultPort,DefaultPortBindAddress,TempDirectory,WebServer,WebServerPort,WebServerURLPrefix;Memory|ConsoleFile,LibPath,Path,PythonPath,PythonRuntimeLibrary,VMSConsoleTerminal;Compatibility|";

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
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>The set tool class of <var>pEndpoint</var>.</p>
ClassMethod ToolOf(pEndpoint As %String) As %String
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = $Piece(..#TOOLS, ";", tI)
        If $Piece(tTool, "|", 1) = pEndpoint Quit
    }
    Quit $Piece(tTool, "|", 2)
}

/// <p>The agent's mint of <var>pEndpoint</var>'s tool for <var>pName</var> and <var>pValue</var>: the proposal in <var>pProposal</var>, the
/// refusal sentence in <var>pProblem</var>.</p>
ClassMethod MintOf(pEndpoint As %String, pName As %String, pValue As %String, Output pProposal As %DynamicObject, Output pProblem As %String)
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Do tArgs.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..ToolOf(pEndpoint), pName, tArgs, .pProposal, .tHttp, .pProblem)
}

/// <p>Hold every pair a set names, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The rows of <var>pEndpoint</var> as the port reads them, in <var>pRows</var> keyed by name; the count answered.</p>
ClassMethod Read(pEndpoint As %String, Output pRows) As %Integer
{
    Kill pRows
    Do ..HoldAll()
    Set tSC = $ClassMethod(..#SEAM, "Rows", pEndpoint, 1000, .tRows, .tHttp, .tFault)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows(tRow.%Get("Name")) = tRow
    }
    Quit tRows.%Size()
}

/// <p>The settings of <var>pClass</var> whose compiled property is the vendor's path type, comma-joined, read in <code>%SYS</code>.</p>
ClassMethod PathProperties(pClass As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT Name FROM %Dictionary.CompiledProperty WHERE parent = ? AND RuntimeType = ? ORDER BY Name")
        If $$$ISOK(tSC) {
            Set tRS = tStmt.%Execute(pClass, $Parameter(..#PORT, "PATHTYPE"))
            While tRS.%Next() {
                Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRS.%GetData(1)
            }
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p><b>AC1.</b> Every row of the rules matrix is asked at the tools' mint: a value a setting does not accept, a setting shown and never
/// changed and a name the class does not list mint nothing and are answered in the published sentence (the sibling mints' sentence for an
/// absent name), and a value the setting accepts mints a proposal (or, for the value the setting already holds, is answered that nothing would change).</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s <code>WriteProblem</code> sets no problem for a refused
/// code -> the refusal rows go red.</p>
Method TestEveryRulesMatrixRowIsAskedAtTheMint()
{
    Set tRows = $Parameter(..#RULES, "ROWS")
    Do $$$AssertTrue($Length(tRows, ";") > 40, "the matrix is not empty")
    For tI = 1:1:$Length(tRows, ";") {
        Set tRow = $Piece(tRows, ";", tI)
        Set tEndpoint = $Piece(tRow, "|", 1)
        Set tName = $Piece(tRow, "|", 2)
        Set tValue = $Piece(tRow, "|", 3)
        Set tExpected = $Piece(tRow, "|", 4)
        Do ..MintOf(tEndpoint, tName, tValue, .tProposal, .tProblem)
        Set tLabel = tEndpoint _ " " _ tName _ " '" _ tValue _ "'"
        If tExpected = "ok" {
            Do $$$AssertTrue($IsObject(tProposal) || (tProblem [ ..#NOCHANGE), tLabel _ ": a value the setting accepts passes the rules, and mints unless it is the value the setting holds: " _ tProblem)
            Continue
        }
        Set tSentence = $Select(tExpected = "CONFIG.SETTING.NOTFOUND": "'" _ tName _ "' is not present on this instance", 1: $ClassMethod(..#ERROR, "ReasonFor", tExpected))
        Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ tSentence, tLabel _ ": mints nothing and is answered " _ tExpected)
    }
}

/// <p><b>AC3.</b> The read-only rows are exactly the roster (the four network settings, and every path), every property the vendor types as a
/// path is among them, and each is refused 409 <code>CONFIG.SETTING.READONLY</code> at the port with no vendor call and at the mint with the
/// published sentence, whatever value is sent.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>READONLY</code> loses <code>WebServerPort</code> -> the roster
/// assertion and both refusals for that setting go red. The port's refusal is asked of the seam, which sends nothing, never of the shipped
/// port.</p>
Method TestEveryReadOnlyRowIsRefusedAtBothCallers()
{
    Set tRoster = ..#READONLYROSTER
    For tI = 1:1:$Length(tRoster, ";") {
        Set tCase = $Piece(tRoster, ";", tI)
        Set tEndpoint = $Piece(tCase, "|", 1)
        Set tCount = ..Read(tEndpoint, .tRows)
        Do $$$AssertTrue(tCount > 0, tEndpoint _ ": the read answers rows")
        Set tDerived = ""
        Set tName = ""
        For {
            Set tName = $Order(tRows(tName))
            If tName = "" Quit
            If tRows(tName).ReadOnly Set tDerived = tDerived _ $Select(tDerived = "": "", 1: ",") _ tName
        }
        Do $$$AssertEquals(tDerived, $Piece(tCase, "|", 2), tEndpoint _ ": the read-only rows are the roster")
        Set tVendor = $ClassMethod(..#PORT, "VendorClass", tEndpoint)
        For tPath = 1:1:$Length(..PathProperties(tVendor), ",") {
            Set tPathName = $Piece(..PathProperties(tVendor), ",", tPath)
            If tPathName = "" Continue
            Do $$$AssertTrue($Data(tRows(tPathName)) '= 0 && tRows(tPathName).ReadOnly || ($Data(tRows(tPathName)) = 0), tEndpoint _ ": the path-typed " _ tPathName _ " is not settable")
        }
        For tJ = 1:1:$Length($Piece(tCase, "|", 2), ",") {
            Set tSetting = $Piece($Piece(tCase, "|", 2), ",", tJ)
            If tSetting = "" Continue
            For tValue = "x", "1", "" {
                Do $ClassMethod(..#SEAM, "Reset")
                Do ..HoldAll()
                Kill tQuery
                Set tQuery("name") = tSetting
                Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "SET", .tQuery, {"Value": (tValue)}, .tOut, .tHttp, .tFault)
                Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
                Set tSent = $ClassMethod(..#SEAM, "Modifies")
                Do ##class(OcuPilot.Test.ScreenGate).Reset()
                Do $$$AssertEquals(tHttp _ "|" _ tCode _ "|" _ tSent, "409|CONFIG.SETTING.READONLY|", tSetting _ " '" _ tValue _ "' is refused at the port and nothing reaches the vendor")
                Do ..MintOf(tEndpoint, tSetting, tValue, .tProposal, .tProblem)
                Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", "CONFIG.SETTING.READONLY"), tSetting _ " '" _ tValue _ "' is refused at the mint")
            }
        }
    }
}

/// <p><b>AC2.</b> A setting's restart flag and its card's consequence come from the source the setting names. Memory: every row's flag is
/// the opposite of the vendor's <code>NoRestartOnActivate</code>. Compatibility: the flagged rows are exactly the classic value editor's
/// own <code>RESTARTREQUIREDLIST</code>, read from the instance. Startup: the flagged rows are the product's list of vendor-stated
/// restarts. A mint states <code>CONFIG.SETTING.RESTART</code> for a flagged setting the tools may set and nothing for one that is not
/// flagged.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>RESTARTCOMPATIBILITY</code> emptied -> the compatibility
/// source assertion and the <code>NullSubscripts</code> card assertion go red.</p>
Method TestEachRestartStatementIsItsVendorSourceAndTheCardStatesIt()
{
    Do ..Read("Memory", .tMemory)
    Set tOk = 1
    Set tName = ""
    For {
        Set tName = $Order(tMemory(tName))
        If tName = "" Quit
        If tMemory(tName).Restart '= '##class(OcuPilot.Test.ConfigSettingRead).NoRestart(tName) Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "every memory row's restart flag is the vendor's NoRestartOnActivate, inverted")
    Do ..Read("Compatibility", .tCompat)
    Set tFlagged = ""
    Set tName = ""
    For {
        Set tName = $Order(tCompat(tName))
        If tName = "" Quit
        If tCompat(tName).Restart Set tFlagged = tFlagged _ $Select(tFlagged = "": "", 1: ",") _ tName
    }
    Set tEditorList = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tEditorList = $Parameter("%CSP.UI.Portal.Config.ValueEditor", "RESTARTREQUIREDLIST")
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tEditorList '= "", "the classic value editor names its restart-required settings on this instance")
    Do $$$AssertEquals(tFlagged, tEditorList, "the compatibility rows that state a restart are the classic value editor's own list")
    Do ..Read("Startup", .tStartup)
    Set tFlagged = ""
    Set tName = ""
    For {
        Set tName = $Order(tStartup(tName))
        If tName = "" Quit
        If tStartup(tName).Restart Set tFlagged = tFlagged _ $Select(tFlagged = "": "", 1: ",") _ tName
    }
    Set tExpected = ""
    Set tName = ""
    For {
        Set tName = $Order(tStartup(tName))
        If tName = "" Quit
        If $ListFind($ListFromString($Parameter(..#PORT, "RESTARTSTARTUP")), tName) Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tFlagged, tExpected, "the startup rows that state a restart are the product's vendor-sourced list, each of which is a row")
    Do $$$AssertEquals($Length(tFlagged, ","), $Length($Parameter(..#PORT, "RESTARTSTARTUP"), ","), "and none of that list is missing from the read")
    For tCase = $ListBuild("Memory", "errlog", "501", "CONFIG.SETTING.RESTART"), $ListBuild("Memory", "history", "501", ""), $ListBuild("Startup", "ErrorPurge", "1", "CONFIG.SETTING.RESTART"), $ListBuild("Startup", "ShutdownTimeout", "301", ""), $ListBuild("Compatibility", "NullSubscripts", "1", "CONFIG.SETTING.RESTART"), $ListBuild("Compatibility", "LineRecall", "0", ""), $ListBuild("Compatibility", "Undefined", "2", "") {
        Do ..MintOf($List(tCase, 1), $List(tCase, 2), ##class(OcuPilot.Test.ConfigSettingRead).Unlike($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) _ "", .tProposal, .tProblem)
        Do $$$AssertTrue($IsObject(tProposal), $List(tCase, 2) _ ": mints: " _ tProblem)
        If '$IsObject(tProposal) Continue
        Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), $List(tCase, 4), $List(tCase, 2) _ ": the card states " _ $Select($List(tCase, 4) = "": "no consequence", 1: "the restart consequence"))
    }
}

/// <p><b>AC1, AC3.</b> The gate each screen declares to the route: the three read pairs and not the write pair, with
/// <code>%Admin_Secure:USE</code> required of Compatibility alone, and the port's write set naming <code>%DB_IRISSYS:WRITE</code> and
/// the compatibility pair.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.CompatibilitySettingList</class> declares no own pair -> the compatibility
/// assertion goes red.</p>
Method TestTheRouteAsksCompatibilityForItsOwnPairAndTheWritePairsNameTheWritePermission()
{
    For tCase = $ListBuild("StartupSettingList", 0), $ListBuild("MemorySettingList", 0), $ListBuild("CompatibilitySettingList", 1) {
        Set tClass = "OcuPilot.Screen.Descriptor." _ $List(tCase, 1)
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertEquals(''$ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")), $List(tCase, 2), $List(tCase, 1) _ ": %Admin_Secure:USE is " _ $Select($List(tCase, 2): "", 1: "not ") _ "required")
        Do $$$AssertEquals(''$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), 0, $List(tCase, 1) _ ": and the write pair is not asked of a read")
    }
    Do $$$AssertTrue($Parameter(..#PORT, "WRITEPAIRS") [ "%DB_IRISSYS:WRITE", "the port's write set names %DB_IRISSYS:WRITE")
    Do $$$AssertTrue($Parameter(..#PORT, "PAIRS") '[ "%DB_IRISSYS:WRITE", "and its read set does not")
    Do $$$AssertEquals($Parameter(..#PORT, "COMPATIBILITYPAIRS"), "%Admin_Secure:USE", "Compatibility's own pair is %Admin_Secure:USE")
}

}
