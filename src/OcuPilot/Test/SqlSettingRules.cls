/// <p>Pins Story 21.4's refusals and write shapes (AC1, AC2, AC3; AD-4, AD-29, AD-39, AD-55, AD-59): every refusal of the SQL, SQL Shell, TSQL
/// and ISQL sets, asked of the port through <class>OcuPilot.Test.ConfigGateSeam</class>, whose vendor calls are recorded and never made, and of
/// the agent's mint; the stored code each choice is written with; the dialect a TSQL flag set passes on; the purge of the cached queries
/// after a changed purge key, and a purge that fails; and the script each set renders.</p>
/// <p><b>Live-safe:</b> no setting is changed and no cached query is purged; the only write is a proposal row the mint stores and the test
/// removes. <b>What it needs from the environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.SqlSettingRules Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The matrix rows as <code>endpoint|setting|value|expected</code>, where expected is the refusal code or <code>ok</code>. A row whose value is
/// <code>LONG</code> sends 300 characters.</p>
Parameter ROWS = "SQL|SaveMAC|1|ok;SQL|SaveMAC|2|CONFIG.SETTING.VALUE;SQL|SaveMAC|x|CONFIG.SETTING.VALUE;SQL|SaveMAC||CONFIG.SETTING.VALUE;SQL|LockTimeout|32768|CONFIG.SETTING.VALUE;SQL|LockTimeout|-1|CONFIG.SETTING.VALUE;SQL|LockTimeout|0|ok;SQL|LockTimeout|32767|ok;SQL|TimePrecision|10|CONFIG.SETTING.VALUE;SQL|TimePrecision|9|ok;SQL|HNSWLIBMemoryLimit|-1|ok;SQL|HNSWLIBMemoryLimit|-2|CONFIG.SETTING.VALUE;SQL|HNSWLIBMemoryLimit|2147483648|CONFIG.SETTING.VALUE;SQL|HNSWLIBMemoryLimit|0|ok;SQL|LockThreshold|-5|CONFIG.SETTING.VALUE;SQL|LockThreshold|1000|ok;SQL|TODATEDefaultFormat|LONG|CONFIG.SETTING.VALUE;SQL|TODATEDefaultFormat|DD MON YYYY|ok;SQL|FastDistinct|0|ok;SQL|ParameterSampling|1|ok;SQL|DefaultSchema|Other|CONFIG.SETTING.READONLY;SQL|ExtrinsicFunctions|1|CONFIG.SETTING.READONLY;SQL|QueryProcedures|1|CONFIG.SETTING.READONLY;SQL|AllowRowIDUpdate|1|CONFIG.SETTING.READONLY;SQL|ECPSync|1|CONFIG.SETTING.READONLY;SQL|IdTrxFrom|x|CONFIG.SETTING.READONLY;SQL|IdTrxTo|x|CONFIG.SETTING.READONLY;SQL|DelimitedIds|0|CONFIG.SETTING.READONLY;SQL|Comment|0|CONFIG.SETTING.READONLY;SQL|ANSIPrecedence|0|CONFIG.SETTING.READONLY;SQL|NoSuchKey|1|CONFIG.SETTING.NOTFOUND;SQLShell|SelectMode|Display|ok;SQLShell|SelectMode|2|CONFIG.SETTING.VALUE;SQLShell|SelectMode|display|CONFIG.SETTING.VALUE;SQLShell|Dialect|MSSQL|ok;SQLShell|Dialect|Oracle|CONFIG.SETTING.VALUE;SQLShell|Path|SQLUser,Other|ok;SQLShell|Path|LONG|CONFIG.SETTING.VALUE;SQLShell|ColAlign|Header|ok;SQLShell|DisplayMode|CSV|ok;SQLShell|DisplayMode|CURRENTDEVICE|ok;SQLShell|DisplayTranslateTable|UTF8|ok;SQLShell|EchoMode|Off|ok;SQLShell|EchoMode|0|CONFIG.SETTING.VALUE;SQLShell|ExecuteMode|Deferred|ok;SQLShell|MessagesMode|Off|ok;SQLShell|CommandPrefix||ok;SQLShell|EscapeCondition|1|CONFIG.SETTING.READONLY;SQLShell|DisplayPath|x|CONFIG.SETTING.READONLY;SQLShell|DisplayFile|x|CONFIG.SETTING.READONLY;SQLShell|NoSuchNode|x|CONFIG.SETTING.NOTFOUND;TSQL|ANSI_NULLS|ON|ok;TSQL|ANSI_NULLS|on|CONFIG.SETTING.VALUE;TSQL|ANSI_NULLS|1|CONFIG.SETTING.VALUE;TSQL|CASEINSCOMPARE|ON|ok;TSQL|QUOTED_IDENTIFIER|OFF|ok;TSQL|DIALECT|MSSQL|ok;TSQL|DIALECT|Oracle|CONFIG.SETTING.VALUE;TSQL|DIALECT||CONFIG.SETTING.VALUE;TSQL|EQUAL_LITERAL_REPLACEMENT|ON|CONFIG.SETTING.READONLY;TSQL|OWNER_AS_SCHEMA|ON|CONFIG.SETTING.READONLY;TSQL|TRACE|ON|CONFIG.SETTING.READONLY;TSQL|NoSuchFlag|ON|CONFIG.SETTING.NOTFOUND;ISQL|DELIMIDENT|1|ok;ISQL|DELIMIDENT|2|CONFIG.SETTING.VALUE;ISQL|TRACE|0|ok;ISQL|FUNCTIONRETURNSSET|1|ok;ISQL|RESERVEDWORDPREFIX|X_|ok;ISQL|RESERVEDWORDPREFIX||ok;ISQL|RESERVEDWORDPREFIX|LONG|CONFIG.SETTING.VALUE;ISQL|NoSuchNode|1|CONFIG.SETTING.NOTFOUND";

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

/// <p>Hold every pair the port's sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>What the vendor call of the set of <var>pName</var> of <var>pEndpoint</var> to <var>pValue</var> records, in the seam's form, where
/// <var>pStored</var> is the code a roster node is written with.</p>
ClassMethod Recorded(pEndpoint As %String, pName As %String, pValue As %String, pStored As %String) As %String
{
    If pEndpoint = "SQL" Quit "Config.SQL|" _ pName _ "|" _ pValue
    If pEndpoint = "SQLShell" || (pEndpoint = "ISQL") Quit pEndpoint _ "|" _ pName _ "|" _ pStored
    Quit pEndpoint _ "|" _ pName _ "|" _ pValue
}

/// <p>The stored code the matrix expects each shell choice to be written with, by endpoint, setting and value, as the classic page writes it.</p>
ClassMethod StoredCode(pEndpoint As %String, pName As %String, pValue As %String) As %String
{
    If pEndpoint '= "SQLShell" Quit pValue
    If pName = "SelectMode" Quit $Case(pValue, "Logical": 0, "ODBC": 1, "Display": 2, : pValue)
    If pName = "ColAlign" Quit $Case(pValue, "Delimiter": 0, "Header": 1, "Data": 2, : pValue)
    If pName = "DisplayMode" Quit $Case(pValue, "CURRENTDEVICE": -1, "XML": 0, "HTML": 1, "PDF": 2, "TXT": 99, "CSV": 100, : pValue)
    If (pName = "EchoMode") || (pName = "MessagesMode") Quit $Case(pValue, "On": 1, "Off": 0, : pValue)
    If pName = "ExecuteMode" Quit $Case(pValue, "Immediate": 1, "Deferred": 0, : pValue)
    Quit pValue
}

/// <p><b>AC1, AC3.</b> Every row of the matrix at the port: a value the rules refuse, a setting shown and never changed and a name the family
/// does not list are each answered on the code and status <class>OcuPilot.Api.ConfigError</class> names with nothing sent, and a value the
/// rules pass is sent once, to the call its family makes, with a shell choice as its stored code.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SETTABLESQL</code> gains <code>DefaultSchema</code> -> the
/// <code>DefaultSchema</code> row goes red, with a vendor call recorded.</p>
Method TestEveryMatrixRowIsAnsweredOnItsCodeAndSendsNothingWhenRefused()
{
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "HoldDialect", "MSSQL")
    For tI = 1:1:$Length(..#ROWS, ";") {
        Set tRow = $Piece(..#ROWS, ";", tI)
        Set tEndpoint = $Piece(tRow, "|", 1)
        Set tName = $Piece(tRow, "|", 2)
        Set tValue = $Piece(tRow, "|", 3)
        If tValue = "LONG" Set tValue = $Translate($Justify("", 300), " ", "x")
        Set tExpected = $Piece(tRow, "|", 4)
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "HoldDialect", "MSSQL")
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "SET", .tQuery, {"Value": (tValue)}, .tOut, .tHttp, .tFault)
        Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Set tWanted = $Select(tExpected = "ok": "200|", 1: $ClassMethod(..#ERROR, "HttpStatusFor", tExpected) _ "|" _ tExpected)
        Set tSent = $ClassMethod(..#SEAM, "Modifies")
        Set tLabel = tEndpoint _ " " _ tName _ " '" _ $Extract(tValue, 1, 20) _ "'"
        Do $$$AssertEquals(tHttp _ "|" _ tCode, tWanted, tLabel _ ": " _ $Select(tExpected = "ok": "accepted", 1: tExpected))
        Set tSentWanted = $Select(tExpected = "ok": ..Recorded(tEndpoint, tName, tValue, ..StoredCode(tEndpoint, tName, tValue)), 1: "")
        If tEndpoint = "SQL" Set tSentWanted = $Select(tExpected = "ok": "Config.SQL|" _ tName _ "|" _ tValue, 1: "")
        Do $$$AssertEquals(tSent, tSentWanted, tLabel _ ": " _ $Select(tExpected = "ok": "sent once, with its stored form", 1: "nothing reached the vendor"))
    }
}

/// <p><b>AC1.</b> A TSQL flag set passes the dialect the instance stores, or <code>Sybase</code> when it stores none, as the classic page saves
/// its shown default; a dialect set passes no dialect; a vendor refusal of a value the rules passed is answered 400
/// <code>CONFIG.SETTING.VALUE</code>.</p>
/// <p>Mutation (Rule 19): the flag set passes <code>MSSQL</code> whatever the instance stores -> the stored-dialect assertion goes red.</p>
Method TestATsqlFlagPassesTheStoredDialectOrTheDefault()
{
    Do ..HoldAll()
    Kill tQuery
    Set tQuery("name") = "ANSI_NULLS"
    For tCase = $ListBuild("Sybase", "Sybase"), $ListBuild("MSSQL", "MSSQL"), $ListBuild("", "Sybase") {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "HoldDialect", $List(tCase, 1))
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "TSQL", "SET", .tQuery, {"Value": "ON"}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "DialectSent") _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "200|" _ $List(tCase, 2) _ "|TSQL|ANSI_NULLS|ON", "a flag set with '" _ $List(tCase, 1) _ "' stored passes " _ $List(tCase, 2))
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "HoldDialect", "MSSQL")
    Set tQuery("name") = "DIALECT"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "TSQL", "SET", .tQuery, {"Value": "Sybase"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "200|TSQL|DIALECT|Sybase", "a dialect set sends the dialect as its value")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Set tQuery("name") = "QUOTED_IDENTIFIER"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "TSQL", "SET", .tQuery, {"Value": "ON"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $IsObject($Get(tOut)), "400|CONFIG.SETTING.VALUE|0", "a setter refusal is answered as a value this setting does not accept, and answers no write")
}

/// <p><b>AC2.</b> After a write that changes one of the six purge keys the port purges the cached queries once; a write that leaves the value as it
/// was, and a write of any other key, purges none; a purge that fails answers 500 <code>INTERNAL</code> after the vendor call was made, so the
/// setting stays changed; a refused write purges none.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>PURGESQL</code> loses <code>ParameterSampling</code> -> the
/// <code>ParameterSampling</code> assertion goes red.</p>
Method TestAChangedPurgeKeyPurgesOnceAndAFailedPurgeIsInternal()
{
    Do ..HoldAll()
    For tName = "AdaptiveMode", "AutoParallel", "FastDistinct", "ODBCVarcharMaxlen", "ParameterSampling" {
        Set tFound = ##class(OcuPilot.Test.ConfigSettingWrite).ValueOf("SQL", tName)
        Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", tName, tFound)
        Do $ClassMethod(..#SEAM, "Reset")
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tNew _ "")}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Purges") _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "200|1|Config.SQL|" _ tName _ "|" _ tNew, tName _ ": a changed value is sent and purges once")
        Do $ClassMethod(..#SEAM, "Reset")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tFound _ "")}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Purges"), "200|0", tName _ ": the value it already holds purges none")
    }
    For tName = "SaveMAC", "IdKey", "LockTimeout", "TimePrecision" {
        Set tFound = ##class(OcuPilot.Test.ConfigSettingWrite).ValueOf("SQL", tName)
        Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", tName, tFound)
        Do $ClassMethod(..#SEAM, "Reset")
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tNew _ "")}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Purges"), "200|0", tName _ ": a changed value of a key that does not purge purges none")
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Set tFound = ##class(OcuPilot.Test.ConfigSettingWrite).ValueOf("SQL", "FastDistinct")
    Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", "FastDistinct", tFound)
    Kill tQuery
    Set tQuery("name") = "FastDistinct"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tNew _ "")}, .tOut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a changed purge key is written")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "PurgeFails")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tNew _ "")}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Modifies") _ "|" _ $ClassMethod(..#SEAM, "Purges"), "500|INTERNAL|Config.SQL|FastDistinct|" _ tNew _ "|1", "a purge that fails is answered as an internal fault after the setting was written")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": "7"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Modifies") _ "|" _ $ClassMethod(..#SEAM, "Purges"), "400||0", "a refused value purges none")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "SQL", "SET", .tQuery, {"Value": (tNew _ "")}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Purges"), "400|0", "and so does a vendor refusal")
}

/// <p><b>AC2, AC3.</b> The agent's mint asks the same rules: each family refuses a value it does not accept and a setting shown and never changed
/// with the published sentence, and a name the family does not list is refused; a value a setting accepts mints a proposal whose card states the
/// purge consequence for a purge key and none for any other.</p>
/// <p>Mutation (Rule 19): <code>ConfigSettingSet.Consequence</code> answers no purge code -> the purge-consequence assertion goes red.</p>
Method TestTheMintRefusesWhatThePortRefusesAndStatesThePurge()
{
    Set tValue = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.VALUE")
    Set tReadOnly = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.READONLY")
    For tCase = $ListBuild("SqlSettingSet", "SaveMAC", "2", tValue), $ListBuild("SqlSettingSet", "DefaultSchema", "Other", tReadOnly), $ListBuild("SqlSettingSet", "DelimitedIds", "0", tReadOnly), $ListBuild("SqlShellSettingSet", "SelectMode", "2", tValue), $ListBuild("SqlShellSettingSet", "EscapeCondition", "1", tReadOnly), $ListBuild("TsqlSettingSet", "ANSI_NULLS", "1", tValue), $ListBuild("TsqlSettingSet", "TRACE", "ON", tReadOnly), $ListBuild("IsqlSettingSet", "DELIMIDENT", "2", tValue), $ListBuild("SqlShellSettingSet", "NoSuchNode", "x", "'NoSuchNode' is not present on this instance") {
        Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool." _ $List(tCase, 1), $List(tCase, 2), {"Name": ($List(tCase, 2)), "Value": ($List(tCase, 3))}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ $Get(tProblem), "0|" _ $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " '" _ $List(tCase, 3) _ "' mints nothing and is answered with its sentence")
    }
    Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", "FastDistinct", "0") _ ""
    Set tArgs = {"Name": "FastDistinct"}
    Do tArgs.%Set("Value", tNew, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.SqlSettingSet", "FastDistinct", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)), 1, "a value a purge key accepts mints a proposal: " _ $Get(tProblem))
    If $IsObject($Get(tProposal)) Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "CONFIG.SETTING.PURGE", "whose card states the purge consequence")
    Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", "SaveMAC", "1") _ ""
    Set tArgs = {"Name": "SaveMAC"}
    Do tArgs.%Set("Value", tNew, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.SqlSettingSet", "SaveMAC", tArgs, .tOther, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tOther)), 1, "a value of a key that does not purge mints a proposal: " _ $Get(tProblem))
    If $IsObject($Get(tOther)) Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tOther), "", "whose card states no consequence")
}

/// <p>AD-29, AD-39. The purge consequence is a code with a sentence and no refusal status, the dispatch by prefix reaches it, and the tool's
/// consequence code is the one the class publishes.</p>
Method TestThePurgeConsequenceIsPublished()
{
    Set tCode = "CONFIG.SETTING.PURGE"
    Set tSentence = "Changing this setting purges the cached queries in every namespace."
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", tCode) _ "|" _ $ClassMethod(..#ERROR, "HttpStatusFor", tCode), tSentence _ "|0", "the code carries its sentence and no status")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode) _ "|" _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tSentence _ "|" _ tSentence, "and both dispatches reach it")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.ConfigSettingSet", "PURGECODE") _ "|" _ $Parameter(..#ERROR, "SETTINGPURGE"), tCode _ "|" _ tCode, "the set tool and the error class name the same code")
}

/// <p>AD-59. A SQL set renders as a script of the vendor's own <code>Get</code>, the one key and <code>Modify</code>, with the purge of the cached
/// queries for a purge key only; a shell or ISQL set as one node set to its stored code with literal subscripts; a TSQL set as its setter, with
/// the stored dialect or the default; a name outside the settable roster, and a hostile one, render none, and a read renders none.</p>
Method TestEachFamilyRendersItsSetAsAScript()
{
    Kill tQuery
    Set tQuery("name") = "FastDistinct"
    Set tText = $ClassMethod(..#PORT, "Snippet", "SQL", "SET", .tQuery, {"Value": "0"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tSC = ##class(Config.SQL).Get(.tProps)" _ $Char(10) _ " Set tProps(""FastDistinct"") = ""0""" _ $Char(10) _ " Set tSC = ##class(Config.SQL).Modify(.tProps)" _ $Char(10) _ " Set tSC = $SYSTEM.SQL.PurgeQueries({""allNamespace"": 1})", "a purge key's script ends with the purge")
    Set tQuery("name") = "SaveMAC"
    Set tText = $ClassMethod(..#PORT, "Snippet", "SQL", "SET", .tQuery, {"Value": "1"}).%Get(0).%Get("text")
    Do $$$AssertTrue((tText [ "Config.SQL).Modify(.tProps)") && (tText '[ "PurgeQueries"), "another key's script has no purge: " _ tText)
    Set tQuery("name") = "SelectMode"
    Set tText = $ClassMethod(..#PORT, "Snippet", "SQLShell", "SET", .tQuery, {"Value": "Display"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set ^%SYS(""sql"", ""shell"", ""SelectMode"") = ""2""", "a shell set is the node at its stored code")
    Set tQuery("name") = "RESERVEDWORDPREFIX"
    Set tText = $ClassMethod(..#PORT, "Snippet", "ISQL", "SET", .tQuery, {"Value": "x"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set ^%SYS(""xsql"", ""informix"", ""RESERVEDWORDPREFIX"") = ""x""", "an ISQL set is its node")
    Do $ClassMethod(..#SEAM, "HoldDialect", "MSSQL")
    Set tQuery("name") = "ANSI_NULLS"
    Set tText = $ClassMethod(..#SEAM, "Snippet", "TSQL", "SET", .tQuery, {"Value": "ON"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tPrevious = ##class(%SYSTEM.TSQL).SetAnsiNulls(""MSSQL"", ""ON"")", "a TSQL flag set names the stored dialect")
    Do $ClassMethod(..#SEAM, "HoldDialect", "")
    Set tText = $ClassMethod(..#SEAM, "Snippet", "TSQL", "SET", .tQuery, {"Value": "ON"}).%Get(0).%Get("text")
    Do $$$AssertTrue(tText [ "SetAnsiNulls(""Sybase"", ""ON"")", "and the default when none is stored: " _ tText)
    Set tQuery("name") = "DIALECT"
    Set tText = $ClassMethod(..#SEAM, "Snippet", "TSQL", "SET", .tQuery, {"Value": "MSSQL"}).%Get(0).%Get("text")
    Do $$$AssertTrue(tText [ "SetDialect(""MSSQL"")", "a dialect set names its setter: " _ tText)
    For tCase = $ListBuild("SQLShell", "EscapeCondition"), $ListBuild("SQLShell", "x"") Halt ;"), $ListBuild("TSQL", "TRACE"), $ListBuild("ISQL", "NoSuchNode") {
        Set tQuery("name") = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", $List(tCase, 1), "SET", .tQuery, {"Value": "x"}).%Size(), 0, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": a name that is not settable renders no script")
    }
    Set tRead = $ClassMethod(..#PORT, "Snippet", "SQLShell", "LIST", .tQuery)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "SQLShell", "LIST") _ "|" _ tRead.%Size(), "|0", "a read has no script form")
}

/// <p>The rosters hold exactly the names the classic pages and the vendor name, each settable or shown and never changed as Story 21.4 rules,
/// and a choice's stored code and shown name are each other's inverse.</p>
/// <p>Mutation (Rule 19): <code>SHELLROSTER</code> maps <code>Display</code> to 1 -> the stored-code assertion goes red.</p>
Method TestTheRostersAreTheFixedListsAndChoicesRoundTrip()
{
    Set tShell = ""
    Set tRoster = $ClassMethod(..#PORT, "RosterOf", "SQLShell")
    For tI = 1:1:$ListLength(tRoster) Set tShell = tShell _ $Select(tShell = "": "", 1: ",") _ $List($List(tRoster, tI), 1) _ ":" _ $List($List(tRoster, tI), 5)
    Do $$$AssertEquals(tShell, "SelectMode:1,Dialect:1,Path:1,ColAlign:1,CommandPrefix:1,DisplayMode:1,DisplayPath:0,DisplayFile:0,DisplayTranslateTable:1,EchoMode:1,ExecuteMode:1,MessagesMode:1,EscapeCondition:0", "the SQL Shell's thirteen nodes, three of them shown and never changed")
    Set tTsql = ""
    Set tRoster = $ClassMethod(..#PORT, "RosterOf", "TSQL")
    For tI = 1:1:$ListLength(tRoster) Set tTsql = tTsql _ $Select(tTsql = "": "", 1: ",") _ $List($List(tRoster, tI), 1) _ ":" _ $List($List(tRoster, tI), 5)
    Do $$$AssertEquals(tTsql, "DIALECT:1,ANSI_NULLS:1,CASEINSCOMPARE:1,QUOTED_IDENTIFIER:1,EQUAL_LITERAL_REPLACEMENT:0,OWNER_AS_SCHEMA:0,TRACE:0", "the seven TSQL settings, three of them shown and never changed")
    Set tIsql = ""
    Set tRoster = $ClassMethod(..#PORT, "RosterOf", "ISQL")
    For tI = 1:1:$ListLength(tRoster) Set tIsql = tIsql _ $Select(tIsql = "": "", 1: ",") _ $List($List(tRoster, tI), 1) _ ":" _ $List($List(tRoster, tI), 5)
    Do $$$AssertEquals(tIsql, "DELIMIDENT:1,TRACE:1,FUNCTIONRETURNSSET:1,RESERVEDWORDPREFIX:1", "the four ISQL settings, each settable")
    Set tEntry = $ClassMethod(..#PORT, "RosterEntry", "SQLShell", "SelectMode")
    Do $$$AssertEquals($ClassMethod(..#PORT, "StoredFor", tEntry, "Display") _ "|" _ $ClassMethod(..#PORT, "ShownFor", tEntry, 2), "2|Display", "SelectMode Display is stored as 2 and 2 is shown as Display")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ShownFor", tEntry, 7), 7, "a stored code no choice has is shown as stored")
    Set tEntry = $ClassMethod(..#PORT, "RosterEntry", "SQLShell", "DisplayMode")
    Do $$$AssertEquals($ClassMethod(..#PORT, "StoredFor", tEntry, "CURRENTDEVICE") _ "|" _ $ClassMethod(..#PORT, "ShownFor", tEntry, -1) _ "|" _ $ClassMethod(..#PORT, "StoredFor", tEntry, "CSV"), "-1|CURRENTDEVICE|100", "DisplayMode keeps its codes, including -1 and 100")
    Set tEntry = $ClassMethod(..#PORT, "RosterEntry", "SQLShell", "Dialect")
    Do $$$AssertEquals($ClassMethod(..#PORT, "StoredFor", tEntry, "MSSQL") _ "|" _ $ClassMethod(..#PORT, "ShownFor", tEntry, "Sybase"), "MSSQL|Sybase", "a choice with no stored code is stored as named")
    Do $$$AssertEquals($ClassMethod(..#PORT, "RosterEntry", "SQLShell", "selectmode"), "", "a roster name is compared exactly")
    Do $$$AssertEquals($ClassMethod(..#PORT, "RosterEntry", "SQL", "SaveMAC"), "", "and an endpoint with a class has no roster")
}

}
