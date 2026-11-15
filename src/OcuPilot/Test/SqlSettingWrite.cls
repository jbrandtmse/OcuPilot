/// <p>Pins Story 21.4's four sets on both callers (AC1, AC2, AC3, AC4; AD-4, AD-6, AD-15, AD-53, AD-58): each screen's Set value through the screen's own
/// action route (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm (<class>OcuPilot.Test.LicenseProbe</class>), against the
/// real instance, over each backing source: <code>Config.SQL</code>, a SQL Shell node, a TSQL setting through <code>%SYSTEM.TSQL</code> and an ISQL
/// node. A set changes exactly the one setting, reads its value back, and purges the cached queries of every namespace only for a changed purge key; a
/// refused set changes and purges nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// class changes SQL settings, SQL Shell, TSQL and ISQL nodes and the governance policy, and purges the cached queries of every namespace. It reads every
/// setting before each test and puts each one it changed back, with each node family's defined state, on every path. A <code>USER</code> namespace is
/// needed: the purge assertions prepare a query in it.</p>
Class OcuPilot.Test.SqlSettingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the setting writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter WRITE = "OcuPilot.Test.ConfigSettingWrite";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

/// <p>The port the failed-purge and refusal cases run the callers through.</p>
Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

/// <p>The screen route whose SQL settings tool declares <parameter>SEAM</parameter>.</p>
Parameter SEAMACTION = "OcuPilot.Test.SeamSqlActionFixture";

/// <p>The namespace a purge assertion prepares its query in, which is not the one the port runs in.</p>
Parameter OTHERNS = "USER";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p><code>Config.SQL</code> as the test found it, as JSON.</p>
Property PreparedSettings As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>The SQL Shell, TSQL and ISQL nodes as the test found them, as one fingerprint.</p>
Property PreparedNodes As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSettingWrite changes this instance's SQL settings and nodes and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped config port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tSnapshot = $ClassMethod(..#WRITE, "Snapshot", "Config.SQL")
    If tSnapshot.%GetTypeOf("Config.SQL") '= "object" Quit $$$ERROR($$$GeneralError, "could not read Config.SQL, so no test changes a setting it could not put back")
    Set ..PreparedSettings = tSnapshot.%ToJSON()
    Set ..PreparedNodes = ..Nodes()
    Kill ^||OcuPilotSqlNodes
    For tI = 1:1:3 {
        Set tRoot = ..Root(tI)
        Set ^||OcuPilotSqlNodes(tI) = $Data(@tRoot)
        If ^||OcuPilotSqlNodes(tI) Merge ^||OcuPilotSqlNodes(tI, "tree") = @tRoot
    }
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do $$$AssertStatusOK($ClassMethod(..#WRITE, "Restore", ##class(%DynamicObject).%FromJSON(..PreparedSettings), "Config.SQL"), "every SQL setting the test changed is put back")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Snapshot", "Config.SQL").%ToJSON(), ..PreparedSettings, "and Config.SQL reads as before the test")
    For tI = 1:1:3 {
        Set tRoot = ..Root(tI)
        Kill @tRoot
        If $Get(^||OcuPilotSqlNodes(tI)) Merge @tRoot = ^||OcuPilotSqlNodes(tI, "tree")
    }
    Kill ^||OcuPilotSqlNodes
    Do $$$AssertEquals(..Nodes(), ..PreparedNodes, "the SQL Shell, TSQL and ISQL nodes read as before the test, each as defined or not as it was")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The reference of the node family <var>pIndex</var>, in the canonical form <code>$Query</code> answers: the SQL Shell's, TSQL's or ISQL's.</p>
ClassMethod Root(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: "^%SYS(""sql"",""shell"")", 2: "^%SYS(""tsql"")", : "^%SYS(""xsql"")")
}

/// <p>Every node of the three families, as one <code>$Data</code>-and-value fingerprint in subscript order, leaving out the node <var>pSkip</var> names
/// as <code>$Query</code> spells it; with a node left out the roots' own defined state is left out too.</p>
ClassMethod Nodes(pSkip As %String = "") As %String
{
    Set tOut = ""
    For tI = 1:1:3 {
        Set tRoot = ..Root(tI)
        If pSkip = "" Set tOut = tOut _ "[" _ $Data(@tRoot) _ "]"
        Set tRef = tRoot
        For {
            Set tRef = $Query(@tRef)
            If tRef = "" Quit
            If $Extract(tRef, 1, $Length(tRoot) - 1) '= $Extract(tRoot, 1, $Length(tRoot) - 1) Quit
            If tRef = pSkip Continue
            Set tOut = tOut _ tRef _ "=" _ $Get(@tRef) _ ";"
        }
    }
    Quit tOut
}

/// <p>The node <var>pName</var> of the SQL Shell (<code>1</code>), TSQL's <code>SET</code> branch (<code>2</code>) or ISQL (<code>3</code>) as stored, or
/// <code>(none)</code> while it is not defined.</p>
ClassMethod Node(pFamily As %Integer, pName As %String) As %String
{
    If pFamily = 1 Quit $Select($Data(^%SYS("sql", "shell", pName)) # 2: ^%SYS("sql", "shell", pName), 1: "(none)")
    If pFamily = 2 Quit $Select($Data(^%SYS("tsql", "SET", pName)) # 2: ^%SYS("tsql", "SET", pName), 1: "(none)")
    Quit $Select($Data(^%SYS("xsql", "informix", pName)) # 2: ^%SYS("xsql", "informix", pName), 1: "(none)")
}

/// <p>Prepare a query in <parameter>OTHERNS</parameter>, which caches one query class there, remember that class's name in the process-private
/// <code>^||SqlSettingWriteProbe</code>, and answer how many of the test's own cached query classes exist there: 1, or 0 when the prepare failed.</p>
ClassMethod Prepared() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#OTHERNS
    Set ^||SqlSettingWriteProbe = ""
    Set tStmt = ##class(%SQL.Statement).%New()
    Set tSC = tStmt.%Prepare("SELECT 1 AS SqlSettingWriteProbe FROM %Dictionary.ClassDefinition WHERE 1 = 0")
    If $$$ISOK(tSC) {
        Do tStmt.%GetImplementationDetails(.tClass)
        Set ^||SqlSettingWriteProbe = tClass
    }
    Set $NAMESPACE = tOrigNS
    Quit ..Cached()
}

/// <p>Whether the cached query class <method>Prepared</method> made in <parameter>OTHERNS</parameter> still exists: 1 or 0. Only that class is
/// counted, so a cached query class another test class left in the namespace, which the vendor purge does not remove, does not change the answer.</p>
ClassMethod Cached() As %Integer
{
    Set tClass = $Get(^||SqlSettingWriteProbe)
    If tClass = "" Quit 0
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#OTHERNS
    Set tCount = $Select($Data(^oddDEF(tClass)): 1, 1: 0)
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The screen action <code>set</code> through the action fixture, answering the HTTP status and the refusal code, comma-joined, and the parsed
/// envelope in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pName As %String, pValue As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tStatus = $ClassMethod(..#WRITE, "Act", pScreen, pName, pValue, .pAnswer)
    Quit tStatus _ "|" _ $ClassMethod(..#WRITE, "Code", pAnswer)
}

/// <p>One set on a family by both callers, with its read-back: the screen sets <var>pNew</var>, the agent puts <var>pFound</var> back and sets
/// <var>pNew</var> again, and the screen puts <var>pFound</var> back. Each step is asserted against the setting's own row and, where the family has
/// nodes, against the stored node by <var>pStoredNew</var> and <var>pStoredFound</var> (<code>""</code> to skip).</p>
Method RoundTrip(pEndpoint As %String, pScreen As %String, pTool As %String, pName As %String, pFound As %String, pNew As %String, pFamily As %Integer = 0, pStoredNew As %String = "", pStoredFound As %String = "")
{
    Set tLabel = pEndpoint _ " " _ pName
    Set tSkip = $Case(pFamily, 1: "^%SYS(""sql"",""shell"",""" _ pName _ """)", 2: "^%SYS(""tsql"",""SET"",""" _ pName _ """)", 3: "^%SYS(""xsql"",""informix"",""" _ pName _ """)", : "")
    Set tOthers = ..Nodes(tSkip)
    Set tStatus = ..Act(pScreen, pName, pNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", pEndpoint, pName), "200||matches|" _ pNew, tLabel _ ": the screen's Set value changes it and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    If pFamily Do $$$AssertEquals(..Node(pFamily, pName), pStoredNew, tLabel _ ": and the node holds its stored form")
    If pFamily Do $$$AssertEquals(..Nodes(tSkip), tOthers, tLabel _ ": and every other node of the three families reads as before")
    Set tOutcome = $ClassMethod(..#WRITE, "Agent", pTool, pName, pFound, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", pEndpoint, pName), "200 |matches|" _ pFound, tLabel _ ": the agent's confirmed proposal puts it back: " _ tOutcome)
    If pFamily Do $$$AssertEquals(..Node(pFamily, pName), pStoredFound, tLabel _ ": and the node holds the other stored form")
    If pFamily Do $$$AssertEquals(..Nodes(tSkip), tOthers, tLabel _ ": and the agent's set leaves every other node as it was")
    Set tOutcome = $ClassMethod(..#WRITE, "Agent", pTool, pName, pNew, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#WRITE, "ValueOf", pEndpoint, pName), "200 |" _ pNew, tLabel _ ": the agent's confirmed proposal changes it")
    Set tStatus = ..Act(pScreen, pName, pFound, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "ValueOf", pEndpoint, pName), "200||" _ pFound, tLabel _ ": the screen's Set value puts it back")
}

/// <p><b>AC1.</b> Each of the four screens' Set value and the agent's confirmed proposal change exactly one setting over its own backing source, in both
/// directions on both callers, with a read-back reading <code>matches</code>: <code>Config.SQL</code> (<code>SaveMAC</code>), a SQL Shell node written with
/// its stored code (<code>SelectMode</code> Display stores 2), a TSQL flag through <code>%SYSTEM.TSQL</code> with the stored dialect unchanged
/// (<code>ANSI_NULLS</code> ON), and an ISQL node (<code>DELIMIDENT</code> 1). Every other key of <code>Config.SQL</code> and every other node reads as
/// before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SHELLROSTER</code> maps <code>Display</code> to 1 -> the stored-form
/// assertion goes red.</p>
Method TestASetRoundTripsOverEachBackingSourceOnBothCallers()
{
    Set tBefore = $ClassMethod(..#WRITE, "Snapshot", "Config.SQL")
    Set tFound = $ClassMethod(..#WRITE, "ValueOf", "SQL", "SaveMAC")
    Do ..RoundTrip("SQL", "osmgmt.sqlsettings", "OcuPilot.Screen.Tool.SqlSettingSet", "SaveMAC", tFound, 'tFound)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Without", $ClassMethod(..#WRITE, "Snapshot", "Config.SQL"), "Config.SQL", "SaveMAC"), $ClassMethod(..#WRITE, "Without", tBefore, "Config.SQL", "SaveMAC"), "every other Config.SQL key reads as before")
    Set tStatus = ..Act("osmgmt.sqlshellsettings", "SelectMode", "Display", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Node(1, "SelectMode") _ "|" _ $ClassMethod(..#WRITE, "ValueOf", "SQLShell", "SelectMode"), "200||2|Display", "SelectMode Display is stored as the code 2 and reads back as Display")
    Set tStatus = ..Act("osmgmt.sqlshellsettings", "SelectMode", "Logical", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Node(1, "SelectMode"), "200||0", "and Logical as 0")
    Set tShown = $ClassMethod(..#WRITE, "ValueOf", "SQLShell", "SelectMode")
    Set tNew = $Select(tShown = "ODBC": "Display", 1: "ODBC")
    Do ..RoundTrip("SQLShell", "osmgmt.sqlshellsettings", "OcuPilot.Screen.Tool.SqlShellSettingSet", "SelectMode", tShown, tNew, 1, $Case(tNew, "Display": 2, : 1), $Case(tShown, "Logical": 0, "ODBC": 1, : 2))
    ; TSQL: the stored dialect is set first, and a flag set leaves it as it is.
    Set tStatus = ..Act("osmgmt.tsqlsettings", "DIALECT", "MSSQL", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", "TSQL", "DIALECT") _ "|" _ $Get(^%SYS("tsql", "DIALECT")), "200||matches|MSSQL|MSSQL", "the screen sets the TSQL dialect")
    Do ..RoundTrip("TSQL", "osmgmt.tsqlsettings", "OcuPilot.Screen.Tool.TsqlSettingSet", "ANSI_NULLS", "OFF", "ON", 2, "ON", "OFF")
    Do $$$AssertEquals($Get(^%SYS("tsql", "DIALECT")), "MSSQL", "a TSQL flag set leaves the stored dialect as it was")
    Kill ^%SYS("tsql")
    Set tStatus = ..Act("osmgmt.tsqlsettings", "CASEINSCOMPARE", "ON", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Get(^%SYS("tsql", "DIALECT")) _ "|" _ ..Node(2, "CASEINSCOMPARE"), "200||Sybase|ON", "with no dialect stored, a flag set stores the classic page's shown default beside it")
    Do ..RoundTrip("ISQL", "osmgmt.isqlsettings", "OcuPilot.Screen.Tool.IsqlSettingSet", "DELIMIDENT", 0, 1, 3, 1, 0)
    Set tStatus = ..Act("osmgmt.isqlsettings", "RESERVEDWORDPREFIX", "X_", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Node(3, "RESERVEDWORDPREFIX"), "200||X_", "a text ISQL setting is stored as typed")
    Set tStatus = ..Act("osmgmt.isqlsettings", "RESERVEDWORDPREFIX", "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", "ISQL", "RESERVEDWORDPREFIX") _ "|" _ ..Node(3, "RESERVEDWORDPREFIX"), "200||matches||", "and cleared to empty, which reads back empty")
}

/// <p><b>AC2.</b> A confirmed or saved change of one of the purge keys purges the cached queries of every namespace, from the screen and from the agent's
/// confirm alike, and leaves the caller in its own namespace; a change of any other key purges nothing.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>PURGESQL</code> loses <code>ParameterSampling</code> -> the screen's purge
/// assertion goes red.</p>
Method TestAChangedPurgeKeyPurgesEveryNamespaceAndAnotherKeyPurgesNothing()
{
    Do $$$AssertTrue(##class(%SYS.Namespace).Exists(..#OTHERNS), ..#OTHERNS _ " exists, so a query can be prepared in another namespace")
    Set tHome = $NAMESPACE
    Set tFound = $ClassMethod(..#WRITE, "ValueOf", "SQL", "ParameterSampling")
    Set tPrepared = ..Prepared()
    Do $$$AssertTrue(tPrepared > 0, "a query is cached in " _ ..#OTHERNS _ ": " _ tPrepared)
    Set tStatus = ..Act("osmgmt.sqlsettings", "ParameterSampling", 'tFound, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Cached() _ "|" _ ($NAMESPACE = tHome), "200||0|1", "the screen's change of ParameterSampling purges the cached queries of another namespace, and the caller stays where it was")
    Set tPrepared = ..Prepared()
    Do $$$AssertTrue(tPrepared > 0, "a query is cached again: " _ tPrepared)
    Set tOutcome = $ClassMethod(..#WRITE, "Agent", "OcuPilot.Screen.Tool.SqlSettingSet", "ParameterSampling", tFound, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Cached(), "200 |0", "the agent's confirmed change purges them too: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "CONFIG.SETTING.PURGE", "and its card states the purge")
    Set tOther = $ClassMethod(..#WRITE, "ValueOf", "SQL", "SaveMAC")
    Set tPrepared = ..Prepared()
    Do $$$AssertTrue(tPrepared > 0, "a query is cached again before a key that does not purge is changed: " _ tPrepared)
    Set tStatus = ..Act("osmgmt.sqlsettings", "SaveMAC", 'tOther, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ (..Cached() = tPrepared), "200||1", "a change of a key that does not purge leaves the cached queries")
}

/// <p><b>AC3.</b> A set that is refused changes nothing and purges nothing: at the screen's route an unknown setting is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>, a setting shown and never changed 409 <code>CONFIG.SETTING.READONLY</code> and a value the setting does not
/// accept 400 <code>CONFIG.SETTING.VALUE</code>; at the mint each is refused with its sentence. Every setting and node reads as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Api.ConfigError</class>'s <code>HttpStatusFor</code> answers 400 for <code>CONFIG.SETTING.NOTFOUND</code> -> the
/// 404 rows go red. A mutation that lets a read-only setting through is run against <class>OcuPilot.Test.SqlSettingRules</class>, whose seam sends
/// nothing, and never here.</p>
Method TestARefusedSetChangesAndPurgesNothingOnEitherCaller()
{
    Set tBefore = $ClassMethod(..#WRITE, "Snapshot", "Config.SQL").%ToJSON()
    Set tNodes = ..Nodes()
    Set tSchema = $ClassMethod(..#WRITE, "ValueOf", "SQL", "DefaultSchema")
    ; A read-only setting is sent the value it already holds, so a regressed read-only check is seen on the status and changes nothing.
    Set tDelimited = $ClassMethod(..#WRITE, "ValueOf", "SQL", "DelimitedIds")
    Set tEscape = $ClassMethod(..#WRITE, "ValueOf", "SQLShell", "EscapeCondition")
    Set tDisplayPath = $ClassMethod(..#WRITE, "ValueOf", "SQLShell", "DisplayPath")
    Set tTrace = $ClassMethod(..#WRITE, "ValueOf", "TSQL", "TRACE")
    Set tPrepared = ..Prepared()
    Do $$$AssertTrue(tPrepared > 0, "a query is cached in " _ ..#OTHERNS _ " before the refused sets: " _ tPrepared)
    For tCase = $ListBuild("osmgmt.sqlsettings", "NoSuchSetting", "1", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("osmgmt.sqlsettings", "DefaultSchema", tSchema, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.sqlsettings", "DelimitedIds", tDelimited, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.sqlsettings", "FastDistinct", "7", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.sqlshellsettings", "EscapeCondition", tEscape, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.sqlshellsettings", "DisplayPath", tDisplayPath, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.sqlshellsettings", "SelectMode", "2", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.tsqlsettings", "TRACE", tTrace, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.tsqlsettings", "ANSI_NULLS", "1", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.isqlsettings", "DELIMIDENT", "2", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.isqlsettings", "NoSuchNode", "1", "404|CONFIG.SETTING.NOTFOUND") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tAnswer)
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " '" _ $List(tCase, 3) _ "' is refused at the screen")
    }
    Set tReadOnly = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.READONLY")
    Set tValue = ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.VALUE")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Agent", "OcuPilot.Screen.Tool.SqlSettingSet", "DefaultSchema", tSchema, .tResult, .tProposal), "refused: " _ tReadOnly, "the mint refuses DefaultSchema")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Agent", "OcuPilot.Screen.Tool.SqlShellSettingSet", "SelectMode", "2", .tResult, .tProposal), "refused: " _ tValue, "the mint refuses a shell code in place of its name")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Agent", "OcuPilot.Screen.Tool.IsqlSettingSet", "NoSuchNode", "1", .tResult, .tProposal), "refused: 'NoSuchNode' is not present on this instance", "the mint refuses a name the family does not list")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Snapshot", "Config.SQL").%ToJSON() _ "|" _ ..Nodes() _ "|" _ (..Cached() = tPrepared), tBefore _ "|" _ tNodes _ "|1", "and Config.SQL, the nodes and the cached queries read as before")
}

/// <p><b>AC4.</b> With each key enabled by the baseline the agent's call for a set is dispatched, mints a proposal and its confirm changes the setting once,
/// with a read-back and one write-kind ledger row carrying the audit marker; the proposal's token is spent, so a second confirm is refused and changes
/// nothing more. With the key stored disabled the same call is refused at dispatch, while a person's Set value is not governed.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.isqlsettings.set</code> set <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// dispatch assertion goes red for that family.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarkerOnEachFamily()
{
    For tCase = $ListBuild("SQL", "osmgmt.sqlsettings", "SaveMAC"), $ListBuild("SQLShell", "osmgmt.sqlshellsettings", "EchoMode"), $ListBuild("TSQL", "osmgmt.tsqlsettings", "QUOTED_IDENTIFIER"), $ListBuild("ISQL", "osmgmt.isqlsettings", "FUNCTIONRETURNSSET") {
        Set tEndpoint = $List(tCase, 1)
        Set tKey = $List(tCase, 2) _ ".set"
        Set tName = $List(tCase, 3)
        Set tFound = $ClassMethod(..#WRITE, "ValueOf", tEndpoint, tName)
        Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike(tEndpoint, tName, tFound) _ ""
        Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
        Do tInput.%Set("Value", tNew, "string")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Dispatched", tKey, tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", tKey _ ": the baseline lets the call mint a proposal")
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", tEndpoint, tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ tNew _ "|matches", tKey _ ": its confirm changes the setting, with a read-back: " _ $Get(tCode))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, tKey _ ": one write-kind ledger row records it")
        Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), tKey _ ": and the agent's audit marker landed on it")
        Set tStatus = ..Act($List(tCase, 2), tName, tFound, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "ValueOf", tEndpoint, tName), "200||" _ tFound, tKey _ ": the setting is put back by the screen")
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
        Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", tEndpoint, tName), "1|" _ tFound, tKey _ ": a second confirm of the same proposal is refused and changes nothing")
        Kill tSettings
        Set tSettings(tKey) = "disabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), tKey _ " is stored disabled")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Dispatched", tKey, tInput, .tNone), "refused", tKey _ ": the same call is refused at dispatch")
        Set tStatus = ..Act($List(tCase, 2), tName, tNew, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "ValueOf", tEndpoint, tName), "200||" _ tNew, tKey _ ": while a person's Set value is not governed and still changes it (AD-22)")
        Set tStatus = ..Act($List(tCase, 2), tName, tFound, .tAnswer)
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    }
}

/// <p>The screen action <code>set</code> through the screen route whose SQL settings tool declares <parameter>SEAM</parameter>, answering the HTTP
/// status and the refusal code, comma-joined, with the parsed envelope in <var>pAnswer</var>.</p>
ClassMethod SeamAct(pName As %String, pValue As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tBody = {"action": "set"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set("Value", pValue, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#SEAMACTION, "Act", "osmgmt.sqlsettings", tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus _ "|" _ $ClassMethod(..#WRITE, "Code", pAnswer)
}

/// <p>Route both callers through the seam port with every pair the port's sets name held, so each write really reaches the instance and each
/// refusal is the vendor's own.</p>
ClassMethod ThroughSeam()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "WriteThrough")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
}

/// <p>The agent's confirm of a change of <code>FastDistinct</code> to <var>pNew</var> through the seam port whose purge fails and whose write really
/// reaches the instance, with the turn's key in <var>pTurnKey</var> and the confirm's answer in <var>pHttp</var> and <var>pCode</var>; answers whether
/// the confirm was refused as an error status.</p>
Method FailedPurgeConfirm(pNew As %String, Output pTurnKey As %String, Output pHttp As %Integer, Output pCode As %String) As %Boolean
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "PurgeFails")
    Do $ClassMethod(..#SEAM, "WriteThrough")
    Set tInput = {"Name": "FastDistinct", "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", pNew, "string")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Dispatched", "osmgmt.sqlsettings.set", tInput, .tProposalId, .pTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the agent's call mints a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .pHttp, .pCode, .tDetail)
    Quit $$$ISERR(tSC)
}

/// <p><b>AC2.</b> A purge that fails after a changed purge key is written is answered 500 <code>INTERNAL</code> to the person's Set value and to the
/// agent's confirm, and the setting stays changed on the instance after one attempt to purge; the agent's ledger row records the error.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>PurgeAfterSet</code> swallows a failed purge (answers OK) -> the status
/// assertions go red on both callers.</p>
Method TestAFailedPurgeAnswersInternalWithTheSettingChangedOnBothCallers()
{
    Do ..ThroughSeam()
    Do $ClassMethod(..#SEAM, "PurgeFails")
    Set tFound = $ClassMethod(..#WRITE, "ValueOf", "SQL", "FastDistinct")
    Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", "FastDistinct", tFound) _ ""
    Set tStatus = ..SeamAct("FastDistinct", tNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "ValueOf", "SQL", "FastDistinct") _ "|" _ $ClassMethod(..#SEAM, "Purges"), "500|INTERNAL|" _ tNew _ "|1", "the person's Set value is answered 500 INTERNAL, the setting stays changed and one purge was tried: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertStatusOK($ClassMethod(..#WRITE, "Restore", ##class(%DynamicObject).%FromJSON(..PreparedSettings), "Config.SQL"), "the setting is put back")
    Set tRefused = ..FailedPurgeConfirm(tNew, .tTurnKey, .tHttp, .tCode)
    Do $$$AssertEquals(tRefused _ "|" _ $Get(tHttp) _ "|" _ $Get(tCode) _ "|" _ $ClassMethod(..#WRITE, "ValueOf", "SQL", "FastDistinct") _ "|" _ $ClassMethod(..#SEAM, "Purges"), "1|500|INTERNAL|" _ tNew _ "|1", "the agent's confirm is answered 500 INTERNAL, the setting stays changed and one purge was tried")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records the confirm")
    Do $$$AssertEquals($Get(tRow("Status")) _ "|" _ $Get(tRow("Code")), "error|INTERNAL", "as an error with its code")
}

/// <p><b>AC2, AC4.</b> A change the agent's confirm wrote and whose purge then failed is still an agent write, so its ledger row carries the audit
/// marker (AD-15), as <class>OcuPilot.Kernel.Proposal.Confirm</class> does for a write whose follow-up failed.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SetValue</code> runs <code>PurgeAfterSet</code> itself, as part of the
/// write -> the marker assertion goes red.</p>
Method TestAFailedPurgeStillMarksTheAgentsWrite()
{
    Do ..ThroughSeam()
    Set tFound = $ClassMethod(..#WRITE, "ValueOf", "SQL", "FastDistinct")
    Set tNew = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("SQL", "FastDistinct", tFound) _ ""
    Do ..FailedPurgeConfirm(tNew, .tTurnKey, .tHttp, .tCode)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "ValueOf", "SQL", "FastDistinct"), tNew, "the write landed")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records the confirm")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the audit marker landed on it")
}

/// <p><b>AC1, AC3.</b> The port's own check of a vendor refusal: with a TSQL dialect the vendor does not know stored beside the settings, a flag value the
/// rules admit is refused by the real setter's answer, so both callers get 400 <code>CONFIG.SETTING.VALUE</code>, and neither the flag nor the stored
/// dialect changes.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>TSQLREFUSAL</code> reads <code>Invalidx</code> -> both refusals go red as the
/// set is answered 200.</p>
Method TestAVendorRefusalOfAnAdmittedTsqlValueIsAValueRefusalOnBothCallers()
{
    Kill ^%SYS("tsql")
    Set ^%SYS("tsql", "DIALECT") = "Oracle"
    Set tNodes = ..Nodes()
    Set tStatus = ..Act("osmgmt.tsqlsettings", "ANSI_NULLS", "ON", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Nodes(), "400|CONFIG.SETTING.VALUE|" _ tNodes, "the person's Set value of an admitted flag is refused with the vendor's answer and changes nothing: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Agent", "OcuPilot.Screen.Tool.TsqlSettingSet", "ANSI_NULLS", "ON", .tResult, .tProposal) _ "|" _ ..Nodes(), "400 CONFIG.SETTING.VALUE|" _ tNodes, "and so is the agent's confirm")
}

}
