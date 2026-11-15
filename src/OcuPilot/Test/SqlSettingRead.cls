/// <p>Pins Story 21.4's four reads, the gate and the governance defaults (AC1, AC2, AC3, AC4; AD-22, AD-29, AD-36): SQL settings, SQL Shell settings,
/// TSQL settings and ISQL settings read through <class>OcuPilot.Port.ConfigPort</class> and the screens' own read executor, each row carrying
/// the kind, the accepted values, the read-only, purge and restart flags the port derives, and every read and write refused to a caller short of
/// a pair before any vendor call. The four set keys ship enabled, and the agent's call mints while its key is enabled and is refused at dispatch
/// once it is not.</p>
/// <p><b>Live-safe:</b> it reads, changes no setting, and stores a governance policy only to restore it. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.SqlSettingRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

/// <p>Each screen: descriptor, route, side-bar position, classic page, entity type, port endpoint, set tool and tool name.</p>
Parameter SCREENS = "SqlSettingList|os-management/sql-settings|29|%CSP.UI.Portal.SQL.Configure.SQL|sql-setting|SQL|SqlSettingSet|osmgmt.sqlsettings.set;SqlShellSettingList|os-management/sql-shell-settings|30|%CSP.UI.Portal.SQL.Configure.SQL|sql-shell-setting|SQLShell|SqlShellSettingSet|osmgmt.sqlshellsettings.set;TsqlSettingList|os-management/tsql-settings|31|%CSP.UI.Portal.SQL.Configure.TSQL|tsql-setting|TSQL|TsqlSettingSet|osmgmt.tsqlsettings.set;IsqlSettingList|os-management/isql-settings|32|%CSP.UI.Portal.SQL.Configure.ISQL|isql-setting|ISQL|IsqlSettingSet|osmgmt.isqlsettings.set";

/// <p>The <code>Config.SQL</code> settings a row offers for change, and those that purge the cached queries, as the plan rules them.</p>
Parameter SETTABLE = "AdaptiveMode,AutoParallel,AutoStatsForEfficientSamplingTableOnly,AutoStatsForFixedStatsTable,AutoStatsForRemoteGlobalTable,ClientMaxIdleTime,DDLNo30,DDLNo201,DDLNo307,DDLNo311,DDLNo315,DDLNo324,DDLNo333,DisableNLSCollationMismatchLogging,FastDistinct,HNSWLIBMemoryLimit,IdKey,LockThreshold,LockTimeout,ODBCVarcharMaxlen,ParameterSampling,SaveMAC,TCPKeepAlive,TimePrecision,TODATEDefaultFormat";

Parameter PURGING = "AdaptiveMode,AutoParallel,DefaultSchema,FastDistinct,ODBCVarcharMaxlen,ParameterSampling";

/// <p>The SQL Shell's nodes with the default the shell itself uses while one is not defined (<code>%SQL.Shell</code>), and the TSQL and ISQL names.</p>
Parameter SHELLNODES = "ColAlign|0,CommandPrefix|,Dialect|IRIS,DisplayFile|,DisplayMode|-1,DisplayPath|,DisplayTranslateTable|UTF8,EchoMode|1,EscapeCondition|1,ExecuteMode|1,MessagesMode|1,Path|SQLUser,SelectMode|0";

Parameter TSQLNAMES = "ANSI_NULLS,CASEINSCOMPARE,DIALECT,EQUAL_LITERAL_REPLACEMENT,OWNER_AS_SCHEMA,QUOTED_IDENTIFIER,TRACE";

Parameter ISQLNODES = "DELIMIDENT|0,FUNCTIONRETURNSSET|1,RESERVEDWORDPREFIX|,TRACE|0";

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

/// <p>The shell node <var>pName</var> as the instance stores it, or its default; <code>^%SYS</code> is a percent global, so it reads the same from any namespace.</p>
ClassMethod ShellStored(pName As %String, pDefault As %String) As %String
{
    Quit $Get(^%SYS("sql", "shell", pName), pDefault)
}

/// <p>The choice the SQL Shell shows for the stored code <var>pStored</var> of <var>pName</var>, by the classic page's names, or the code
/// itself for a node that has no choices.</p>
ClassMethod ShellShown(pName As %String, pStored As %String) As %String
{
    If pName = "SelectMode" Quit $Case(pStored, 0: "Logical", 1: "ODBC", 2: "Display", : pStored)
    If pName = "ColAlign" Quit $Case(pStored, 0: "Delimiter", 1: "Header", 2: "Data", : pStored)
    If pName = "DisplayMode" Quit $Case(pStored, -1: "CURRENTDEVICE", 0: "XML", 1: "HTML", 2: "PDF", 99: "TXT", 100: "CSV", : pStored)
    If (pName = "EchoMode") || (pName = "MessagesMode") Quit $Case(pStored, 1: "On", 0: "Off", : pStored)
    If pName = "ExecuteMode" Quit $Case(pStored, 1: "Immediate", 0: "Deferred", : pStored)
    Quit pStored
}

/// <p>The TSQL setting <var>pName</var> as <code>%SYSTEM.TSQL</code> answers it: the flag is what follows the comma after the dialect.</p>
ClassMethod TsqlShown(pName As %String) As %String
{
    If pName = "DIALECT" Quit ##class(%SYSTEM.TSQL).GetDialect()
    If pName = "ANSI_NULLS" Quit $Piece(##class(%SYSTEM.TSQL).GetAnsiNulls(), ", ", 2)
    If pName = "CASEINSCOMPARE" Quit $Piece(##class(%SYSTEM.TSQL).GetCaseInsCompare(), ", ", 2)
    If pName = "QUOTED_IDENTIFIER" Quit $Piece(##class(%SYSTEM.TSQL).GetQuotedIdentifier(), ", ", 2)
    If pName = "EQUAL_LITERAL_REPLACEMENT" Quit $Piece(##class(%SYSTEM.TSQL).GetEqualLiteralReplacement(), ", ", 2)
    If pName = "OWNER_AS_SCHEMA" Quit ##class(%SYSTEM.TSQL).GetOwnerAsSchema()
    Quit ##class(%SYSTEM.TSQL).GetTrace()
}

/// <p>A read's rows as an array keyed by name, each the row object, in <var>pRows</var>; the count answered.</p>
ClassMethod RowsOf(pDescriptor As %String, Output pRows) As %Integer
{
    Kill pRows
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ pDescriptor, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit -1
    Quit ##class(OcuPilot.Test.ConfigSettingRead).RowsByName(tResult, .pRows)
}

/// <p>The names of <var>pRows</var> (a <code>RowsOf</code> array), comma-joined in order.</p>
ClassMethod Names(ByRef pRows) As %String
{
    Set tNames = ""
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName))
        If tName = "" Quit
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
    }
    Quit tNames
}

/// <p>The names of the comma-separated list <var>pNames</var>, in the order a subscript is read, comma-joined.</p>
ClassMethod Sorted(pNames As %String) As %String
{
    Kill tByName
    For tI = 1:1:$Length(pNames, ",") Set tByName($Piece(pNames, ",", tI)) = ""
    Set tSorted = ""
    Set tName = ""
    For {
        Set tName = $Order(tByName(tName))
        If tName = "" Quit
        Set tSorted = tSorted _ $Select(tSorted = "": "", 1: ",") _ tName
    }
    Quit tSorted
}

/// <p>How many rows of <var>pRows</var> (a <code>RowsOf</code> array) state a restart.</p>
ClassMethod Restarting(ByRef pRows) As %Integer
{
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pRows(tName))
        If tName = "" Quit
        If pRows(tName).Restart Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p><b>AC1.</b> The SQL settings answer one row per key <code>Config.SQL</code>'s own <code>Get</code> answers, valued as it answers them; the
/// SQL Shell, TSQL and ISQL settings answer their rosters, each valued as the node, or the shell's own default while it is not defined, or
/// <code>%SYSTEM.TSQL</code>'s getter says. Every port row carries exactly its seven members.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SHELLROSTER</code> loses its <code>Path</code> entry -> the shell's
/// name assertion goes red.</p>
Method TestEachReadAnswersItsSettingsAsTheInstanceHoldsThem()
{
    Set tCount = ..RowsOf("SqlSettingList", .tSql)
    Set tKeys = ##class(OcuPilot.Test.ConfigSettingRead).VendorKeys("Config.SQL")
    Do $$$AssertEquals(..Names(.tSql), tKeys, "SQL settings: one row per key Config.SQL answers")
    Do $$$AssertEquals(tCount, $Length(tKeys, ","), "SQL settings: " _ tCount _ " rows")
    Set tSame = 1
    Set tOrig = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tGet = ##class(Config.SQL).Get(.tProps)
    Set $NAMESPACE = tOrig
    Set tName = ""
    For {
        Set tName = $Order(tProps(tName))
        If tName = "" Quit
        If tSql(tName).Value '= tProps(tName) Set tSame = 0
    }
    Do $$$AssertEquals(tSame, 1, "SQL settings: every value is the one Config.SQL answers")
    Set tCount = ..RowsOf("SqlShellSettingList", .tShell)
    Set tExpected = ""
    For tI = 1:1:$Length(..#SHELLNODES, ",") Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ $Piece($Piece(..#SHELLNODES, ",", tI), "|", 1)
    Do $$$AssertEquals(..Names(.tShell), tExpected, "SQL Shell settings: the thirteen nodes the classic page writes")
    Set tSame = 1
    For tI = 1:1:$Length(..#SHELLNODES, ",") {
        Set tPair = $Piece(..#SHELLNODES, ",", tI)
        Set tName = $Piece(tPair, "|", 1)
        If tShell(tName).Value '= ..ShellShown(tName, ..ShellStored(tName, $Piece(tPair, "|", 2))) {
            Set tSame = 0
            Do $$$AssertEquals(tShell(tName).Value, ..ShellShown(tName, ..ShellStored(tName, $Piece(tPair, "|", 2))), "SQL Shell settings: " _ tName)
        }
    }
    Do $$$AssertEquals(tSame, 1, "SQL Shell settings: every value is the node as stored, or the shell's default, shown as its choice")
    Set tCount = ..RowsOf("TsqlSettingList", .tTsql)
    Do $$$AssertEquals(..Names(.tTsql), ..#TSQLNAMES, "TSQL settings: the seven settings")
    Set tSame = 1
    For tI = 1:1:$Length(..#TSQLNAMES, ",") {
        Set tName = $Piece(..#TSQLNAMES, ",", tI)
        If tTsql(tName).Value '= ..TsqlShown(tName) Set tSame = 0
    }
    Do $$$AssertEquals(tSame, 1, "TSQL settings: every value is the getter's answer")
    Set tCount = ..RowsOf("IsqlSettingList", .tIsql)
    Set tExpected = ""
    For tI = 1:1:$Length(..#ISQLNODES, ",") Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ $Piece($Piece(..#ISQLNODES, ",", tI), "|", 1)
    Do $$$AssertEquals(..Names(.tIsql), tExpected, "ISQL settings: the four nodes")
    Set tSame = 1
    For tI = 1:1:$Length(..#ISQLNODES, ",") {
        Set tPair = $Piece(..#ISQLNODES, ",", tI)
        Set tName = $Piece(tPair, "|", 1)
        If tIsql(tName).Value '= $Get(^%SYS("xsql", "informix", tName), $Piece(tPair, "|", 2)) Set tSame = 0
    }
    Do $$$AssertEquals(tSame, 1, "ISQL settings: every value is the node as stored, or its default")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEndpoint = $Piece($Piece(..#SCREENS, ";", tI), "|", 6)
        Set tSC = $ClassMethod(..#SEAM, "Rows", tEndpoint, 1000, .tRows, .tHttp, .tFault)
        Set tOk = $$$ISOK(tSC) && $IsObject($Get(tRows))
        If tOk {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If ##class(OcuPilot.Test.LicenseKey).Keys(tRow) '= "Accepts,Kind,Name,Purges,ReadOnly,Restart,Value" Set tOk = 0
            }
        }
        Do $$$AssertEquals(tOk, 1, tEndpoint _ ": the port answers rows of exactly their seven members")
    }
}

/// <p><b>AC1, AC2, AC3.</b> The flags: the SQL settings offer exactly the plan's twenty-five keys for change, mark exactly the six purge keys,
/// and every other key reads <code>ReadOnly</code>; the shell's <code>EscapeCondition</code>, <code>DisplayPath</code> and
/// <code>DisplayFile</code> and the three TSQL settings the classic page omits are shown and never changed; no row of any of the four states a
/// restart; and the kinds and accepted values are the matrix's.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SETTABLESQL</code> gains <code>DefaultSchema</code> -> the read-only
/// assertion goes red, and so does <class>OcuPilot.Test.SqlSettingRules</class>'s <code>DefaultSchema</code> row.</p>
Method TestTheFlagsAndKindsAreTheMatrixOnes()
{
    Do ..RowsOf("SqlSettingList", .tSql)
    Do ..RowsOf("SqlShellSettingList", .tShell)
    Do ..RowsOf("TsqlSettingList", .tTsql)
    Do ..RowsOf("IsqlSettingList", .tIsql)
    Set tOpen = ""
    Set tPurging = ""
    Set tName = ""
    For {
        Set tName = $Order(tSql(tName))
        If tName = "" Quit
        If 'tSql(tName).ReadOnly Set tOpen = tOpen _ $Select(tOpen = "": "", 1: ",") _ tName
        If tSql(tName).Purges Set tPurging = tPurging _ $Select(tPurging = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tOpen, ..Sorted(..#SETTABLE), "the SQL settings offer exactly the plan's twenty-five keys for change")
    Do $$$AssertEquals(tPurging, ..Sorted(..#PURGING), "and mark exactly the six that purge the cached queries")
    For tName = "DefaultSchema", "ExtrinsicFunctions", "QueryProcedures", "AllowRowIDUpdate", "ECPSync", "IdTrxFrom", "IdTrxTo", "DelimitedIds", "Comment", "ANSIPrecedence" {
        Do $$$AssertEquals(tSql(tName).ReadOnly _ "|" _ tSql(tName).Accepts, "1|Shown here and never changed here.", tName _ " is shown and never changed")
    }
    Do $$$AssertEquals(tSql("DefaultSchema").Purges, 1, "DefaultSchema is a purge key and still never set")
    Do $$$AssertEquals(tSql("HNSWLIBMemoryLimit").Kind _ "|" _ tSql("HNSWLIBMemoryLimit").Accepts, "integer|A whole number from 0 to 2147483647.", "HNSWLIBMemoryLimit states its range alone")
    Do $$$AssertEquals(tSql("LockTimeout").Accepts _ "|" _ tSql("TimePrecision").Accepts, "A whole number from 0 to 32767.|A whole number from 0 to 9.", "LockTimeout and TimePrecision read the dictionary's limits")
    Do $$$AssertEquals(tSql("TODATEDefaultFormat").Kind _ "|" _ tSql("TODATEDefaultFormat").Accepts, "text|Text of up to 32 characters.", "TODATEDefaultFormat reads its length")
    Do $$$AssertEquals(tSql("SaveMAC").Kind, "boolean", "SaveMAC is a boolean")
    For tName = "EscapeCondition", "DisplayPath", "DisplayFile" {
        Do $$$AssertEquals(tShell(tName).ReadOnly, 1, "the shell's " _ tName _ " is shown and never changed")
    }
    Set tOpen = ""
    Set tName = ""
    For {
        Set tName = $Order(tShell(tName))
        If tName = "" Quit
        If 'tShell(tName).ReadOnly Set tOpen = tOpen _ $Select(tOpen = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tOpen, "ColAlign,CommandPrefix,Dialect,DisplayMode,DisplayTranslateTable,EchoMode,ExecuteMode,MessagesMode,Path,SelectMode", "ten shell nodes are offered for change")
    Do $$$AssertEquals(tShell("SelectMode").Kind _ "|" _ tShell("SelectMode").Accepts, "choice|One of Logical, ODBC, Display.", "SelectMode offers the classic page's three names")
    Do $$$AssertEquals(tShell("DisplayMode").Accepts, "One of CURRENTDEVICE, XML, HTML, PDF, TXT, CSV.", "DisplayMode offers its six")
    For tName = "EQUAL_LITERAL_REPLACEMENT", "OWNER_AS_SCHEMA", "TRACE" {
        Do $$$AssertEquals(tTsql(tName).ReadOnly, 1, "TSQL " _ tName _ " is shown and never changed")
    }
    For tName = "ANSI_NULLS", "CASEINSCOMPARE", "DIALECT", "QUOTED_IDENTIFIER" {
        Do $$$AssertEquals(tTsql(tName).ReadOnly _ "|" _ tTsql(tName).Kind, "0|choice", "TSQL " _ tName _ " is offered for change as a choice")
    }
    Do $$$AssertEquals(tTsql("ANSI_NULLS").Accepts _ "|" _ tTsql("DIALECT").Accepts, "One of OFF, ON.|One of MSSQL, Sybase.", "and states its choices")
    Set tName = ""
    For {
        Set tName = $Order(tIsql(tName))
        If tName = "" Quit
        Do $$$AssertEquals(tIsql(tName).ReadOnly, 0, "ISQL " _ tName _ " is offered for change")
    }
    Do $$$AssertEquals(tIsql("DELIMIDENT").Kind _ "|" _ tIsql("RESERVEDWORDPREFIX").Kind, "boolean|text", "ISQL reads booleans and one text")
    Do $$$AssertEquals(..Restarting(.tSql) + ..Restarting(.tShell) + ..Restarting(.tTsql) + ..Restarting(.tIsql), 0, "no row of the four states a restart")
}

/// <p><b>AC1, AC3.</b> A <code>GET</code> answers the one row the list answers for the name, with the purge flag; a name the family does not list,
/// in any other case or empty, is 404 <code>CONFIG.SETTING.NOTFOUND</code>.</p>
Method TestAGetAnswersOneRowAndAnUnknownNameIsAbsent()
{
    For tCase = $ListBuild("SQL", "FastDistinct"), $ListBuild("SQLShell", "SelectMode"), $ListBuild("TSQL", "ANSI_NULLS"), $ListBuild("ISQL", "DELIMIDENT") {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#PORT, "Invoke", $List(tCase, 1), "GET", .tQuery, "", .tRow, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tRow.Name, "200|" _ $List(tCase, 2), $List(tCase, 1) _ ": a listed setting reads")
        Do $$$AssertEquals(tRow.Purges, $Select($List(tCase, 2) = "FastDistinct": 1, 1: 0), $List(tCase, 1) _ ": and carries its purge flag")
        For tName = "", "nosuchsetting", $ZConvert($List(tCase, 2), "L"), $List(tCase, 2) _ " " {
            Set tQuery("name") = tName
            Set tSC = $ClassMethod(..#PORT, "Invoke", $List(tCase, 1), "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|CONFIG.SETTING.NOTFOUND", $List(tCase, 1) _ ": '" _ tName _ "' is not a setting of it")
        }
    }
}

/// <p><b>AC1.</b> Every read of the four is refused to a caller short of a pair, naming the first one missing, and none asks for
/// <code>%Admin_Secure:USE</code>; every write is refused to a caller holding the read pairs, naming <code>%DB_IRISSYS:WRITE</code>, with nothing
/// sent.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Admit</code> answers OK without evaluating the pairs -> the denial
/// assertions go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    For tEndpoint = "SQL", "SQLShell", "TSQL", "ISQL" {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|%Admin_Manage:USE|0", tEndpoint _ ": a caller holding nothing is refused naming the first pair and answers no rows")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    For tEndpoint = "SQL", "SQLShell", "TSQL", "ISQL" {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": a caller holding the two read pairs reads it, without %Admin_Secure:USE")
    }
    For tCase = $ListBuild("SQL", "SaveMAC", "1"), $ListBuild("SQLShell", "SelectMode", "Display"), $ListBuild("TSQL", "ANSI_NULLS", "ON"), $ListBuild("ISQL", "DELIMIDENT", "1") {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), "SET", .tQuery, {"Value": ($List(tCase, 3))}, .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "403|%DB_IRISSYS:WRITE|", $List(tCase, 1) _ ": a set is refused naming the write pair, and nothing is sent")
    }
}

/// <p>AC1, AC3, AD-5, AD-44, AD-53. The four screens declare the classic pages, positions 29 to 32, the config read source and the read pairs
/// alone, and their tools declare their screen action, their port and endpoint, the classic page that the screen replaces and a merge write
/// that reads its value back.</p>
/// <p>Mutation (Rule 19): <code>IsqlSettingSet</code> declares no <code>CLASSICPAGES</code> -> the declaration assertion goes red.</p>
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
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(..#PORT, "ENDPOINTS")), $Piece(tScreen, "|", 6)) > 0, tClass _ ": the port names its endpoint")
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), tClass _ ": it requires the classic table's pairs and not the write pair")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "OwnPrivilegePairs")), 0, tClass _ ": and owns no pair")
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tScreen, "|", 7)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $Piece(tScreen, "|", 8) _ "|set|" _ ..#PORT _ "|" _ $Piece(tScreen, "|", 6), tTool _ ": its name, its screen action, its port and its endpoint")
        Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), $Piece(tScreen, "|", 4), tTool _ ": the classic page it replaces")
        Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody") _ ''$ClassMethod(tTool, "Destructive") _ $ListToString($ClassMethod(tTool, "ReadBackFields")), "10Value", tTool _ ": a merge write that is not destructive and reads its value back")
        Do $$$AssertEquals($Parameter(tTool, "READANSWERS"), "Name,Value,Kind,Accepts,Restart,ReadOnly,Purges", tTool _ ": its read answers name the purge flag")
    }
}

/// <p>AC4. The four keys ship enabled, so with none stored the agent's call mints a proposal for each tool, and with a key stored disabled that
/// call is refused <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.sqlsettings.set</code> set <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> ->
/// the baseline assertion and the minted assertion go red for that key.</p>
Method TestTheKeysShipEnabledAndADisabledKeyRefusesTheAgentAtDispatch()
{
    Set tRead = "OcuPilot.Test.ConfigSettingRead"
    For tCase = $ListBuild("osmgmt.sqlsettings.set", "SaveMAC", "1", "SQL"), $ListBuild("osmgmt.sqlshellsettings.set", "SelectMode", "Display", "SQLShell"), $ListBuild("osmgmt.tsqlsettings.set", "ANSI_NULLS", "ON", "TSQL"), $ListBuild("osmgmt.isqlsettings.set", "DELIMIDENT", "1", "ISQL") {
        Set tKey = $List(tCase, 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), "1|baseline", tKey _ " ships enabled by the baseline")
        Set tInput = {"Name": ($List(tCase, 2)), "rationale": "probe", "expectedImpact": "probe"}
        Do tInput.%Set("Value", $ClassMethod(tRead, "Unlike", $List(tCase, 4), $List(tCase, 2), $List(tCase, 3)) _ "", "string")
        Set tAnswer = $ClassMethod(tRead, "Dispatched", tKey, tInput, .tContent)
        Do $$$AssertEquals(tAnswer, "minted", tKey _ ": the agent's call mints a proposal under the baseline: " _ tContent)
        Kill tSettings
        Set tSettings(tKey) = "disabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), tKey _ " is stored disabled")
        Set tAnswer = $ClassMethod(tRead, "Dispatched", tKey, tInput, .tContent)
        Do $$$AssertEquals(tAnswer _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", tKey _ ": the same call is refused by the governance gate")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    }
}

}
