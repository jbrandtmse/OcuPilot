/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the Settings endpoint and the setting routes against real
/// principals (AD-8, AD-29, AD-44, AD-62, Story 20.22): the six principals <class>OcuPilot.Test.InteropItemGate</class>
/// creates, each missing one pair, are refused naming that pair, 403, before any vendor call; a principal holding
/// exactly the item write's set lists, reads, sets and resets, the audit call included, and is refused
/// <code>PATH.SERVED</code> (not <code>&lt;PROTECT&gt;</code>) for a served-directory value, because the predicates read
/// the roster and the manager directory with no further pair; and a principal who holds READ but not WRITE on the
/// database, past the port's gate, is refused by the vendor itself, <code>PORT.ACCESSDENIED</code>.</p>
/// <p>The setting tools' own pairs are asserted beside the item tools' in
/// <class>OcuPilot.Test.InteropItemGate</class> and, for a split namespace, in
/// <class>OcuPilot.Test.InteropItemGateSplit</class>.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never
/// changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles a probe production in
/// <code>USER</code></b> and creates the six users and roles <class>OcuPilot.Test.InteropItemGate</class> names. They
/// and the probe are removed after the last test. One class per run.</p>
Class OcuPilot.Test.InteropSettingGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter ITEMGATE = "OcuPilot.Test.InteropItemGate";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter ITEM = "OcuPilotProbeOp";

Parameter SCREEN = "/screens/interop.itemsettings";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>. The set is followed by the reset,
/// so a principal admitted to all leaves the probe as it was.</p>
Parameter LEGS = "Settings|LIST,Settings|SETTING,Settings|SET,Settings|RESET";

/// <p>What each principal's four legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or empty when the leg
/// is admitted&gt;</code> per leg in <parameter>LEGS</parameter> order, separated by <code>,</code>.</p>
Parameter EXPECTED = "OcuP203Exact=,,,;OcuP203NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP203NoCfgRead=%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP203NoCfgWrite=,,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE;OcuP203NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE;OcuP203NoWrite=,,%DB_USER:WRITE,%DB_USER:WRITE";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The probe operation's stored settings and class text before the test, which no refused leg may change.</p>
Property PreparedBaseline As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedBaseline = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingGate compiles a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP2022Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit $$$ADDSC(tSC, ..OnAfterAllTests())
    Set tGate = $ClassMethod(..#ITEMGATE, "%New", "")
    Set tGate.PreparedPassword = ..PreparedPassword
    Set tSC = tGate.EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tPrincipals = $Parameter(..#ITEMGATE, "PRINCIPALS")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(tPrincipals, ";") {
            Set tUser = $Piece($Piece(tPrincipals, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    Set ..PreparedBaseline = ..Settings()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals(..Settings(), ..PreparedBaseline, "the probe operation's settings are as they began")
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The probe operation's stored settings, without the class text: a write that succeeds rewrites the class in the
/// vendor's own formatting, so only a refused one leaves the text as it was.</p>
ClassMethod Settings() As %String
{
    Quit $Piece($ClassMethod(..#CONTROL, "Snapshot"), "|", 1, 8)
}

/// <p>The expected failed pairs of <var>pUser</var>'s legs, as a <code>%List</code>.</p>
ClassMethod ExpectedFor(pUser As %String) As %List
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Quit $ListFromString($Piece(tEntry, "=", 2), ",")
}

/// <p>AC6: each principal's four port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says,
/// with 403 <code>AUTH.NOPRIVILEGE</code> on a refusal, before any vendor call; the exact principal's set and reset leave
/// the setting as it began, and a refused leg changes none.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <parameter>OcuPilot.Port.InteropPort.ITEMWRITEPAIRS</parameter> -- the missing-write principal's writes reach the vendor
/// and this goes red; drop <code>IsSettingWrite</code> from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the
/// missing-write rows go red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    Set tPrincipals = $Parameter(..#ITEMGATE, "PRINCIPALS")
    For tI = 1:1:$Length(tPrincipals, ";") {
        Set tUser = $Piece($Piece(tPrincipals, ";", tI), ":", 1)
        Set tBefore = ..Settings()
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tExpected = ..ExpectedFor(tUser)
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals(..LegText(tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted), tUser _ ": " _ tLeg)
        }
        Do $$$AssertEquals(..Settings(), tBefore, tUser _ ": the probe operation's stored settings are as they were")
    }
}

/// <p>AC6, AC9: the principal holding exactly the item write's pairs is refused <code>PATH.SERVED</code> for a value in
/// the served directory, not <code>&lt;PROTECT&gt;</code>: the predicates read the installer's roster and the manager
/// directory with no pair of their own. Its set and reset of an ordinary setting leave an audit record naming the
/// setting. The principal holding READ but not WRITE on the database, with the gate stood aside, is refused by the
/// vendor itself, 403 <code>PORT.ACCESSDENIED</code>, and nothing is stored.</p>
/// <p>Mutation (Rule 19): judge the path in the install namespace through an escalated frame -- not applicable; instead make
/// <method>OcuPilot.Port.InteropPort.LocationProblem</method> answer <code>""</code> -- the served row goes red.</p>
Method TestThePathRuleNeedsNoPairAndTheVendorRefusesAReadOnlyPrincipal()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tExact = ..ProbeAs("OcuP203Exact")
    Do $$$AssertEquals(tExact.%Get("error"), "", "the exact principal's probe ran: " _ tExact.%ToJSON())
    Do $$$AssertEquals(..LegText(tExact, "served"), "422 PATH.SERVED ", "a served-directory value is refused PATH.SERVED, by the predicates, and not PROTECT")
    Set tAudit = $ClassMethod(..#CONTROL, "SettingAudited", tSince)
    Do $$$AssertTrue((tAudit [ "setting set by OcuPilot, Host:InitSeconds") && (tAudit [ "setting reset by OcuPilot, Host:InitSeconds"), "the audit call ran as the principal and names the setting: " _ tAudit)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "ProbeDirectory"), "<none>", "nothing was stored for the served value")
    Set tReadOnly = ..ProbeAs("OcuP203NoWrite", 1)
    Do $$$AssertEquals(..LegText(tReadOnly, "protect"), "403 PORT.ACCESSDENIED ", "a principal with READ on the database only, past the gate, is refused by the vendor: " _ tReadOnly.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "InitSeconds"), "<none>", "and nothing was stored")
}

/// <p>AC6: on the screen routes each principal is refused naming the pair its read or action needs, before the setting is
/// read or written: the list's read and the Set value row action; a principal without READ on the namespace's database
/// is refused at the namespace entry, <code>NS.DENIED</code>; and the exact principal reads the list and sets and resets
/// a setting through the screen.</p>
/// <p>Mutation (Rule 19): the action rows are refused by either gate, so drop <code>%Ens_ProductionConfig:WRITE</code>
/// from both <method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method> and
/// <method>OcuPilot.Port.InteropPort.Pairs</method> (its <code>IsSettingWrite</code> term) -- the action rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tRead = tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&maxRows=100&item=" _ $ZConvert($ClassMethod(..#CONTROL, "ItemId"), "O", "URL")
    For tCase = $ListBuild("OcuP203NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP203NoRead", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tRead, $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the list is refused naming the pair: " _ $Get(tRaw))
    }
    Set tBefore = ..Settings()
    For tCase = $ListBuild("OcuP203NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP203NoCfgWrite", "%Ens_ProductionConfig:WRITE"), $ListBuild("OcuP203NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP203NoRead", "%DB_USER:READ") {
        Set tRequest = {"action": "set", "values": {"Value": "7"}}
        Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), "string")
        Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": Set value is refused naming the pair: " _ $Get(tRaw))
    }
    Do $$$AssertEquals(..Settings(), tBefore, "no refused request changed a setting")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tRead, "OcuP203Exact", ..PreparedPassword, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ ($Length(..RowNames(tRaw), ",") > 10), "200 1", "the exact principal reads the item's settings: " _ $Extract($Get(tRaw), 1, 200))
    Set tRequest = {"action": "set", "values": {"Value": "7"}}
    Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), "string")
    Do $$$AssertEquals(..Post(..#SCREEN _ "/action", tRequest, "OcuP203Exact", .tRaw), 200, "the exact principal's Set value is admitted: " _ $Get(tRaw))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Stored", "Host", "InitSeconds"), "7", "and stored it")
    Set tRequest = {"action": "reset"}
    Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", "Host", "InitSeconds"), "string")
    Do $$$AssertEquals(..Post(..#SCREEN _ "/action", tRequest, "OcuP203Exact", .tRaw), 200, "and its Reset to default: " _ $Get(tRaw))
}

/// <p><code>code failedPair</code> of a wire refusal (raw JSON), the pair <code>""</code> when it names none.</p>
ClassMethod FailedPair(pRaw) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("detail")) Quit ""
    Quit tBody.detail.%Get("failedPair")
}

/// <p>The names of a list read's rows (raw JSON), comma-separated.</p>
ClassMethod RowNames(pRaw) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit ""
    Set tText = ""
    Set tIterator = tBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.Name
    }
    Quit tText
}

/// <p><var>pBody</var> posted to <var>pPath</var> as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>; the
/// status, and the raw answer in <var>pRaw</var>.</p>
Method Post(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object
/// carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pProtect As %Boolean = 0) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropSettingGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION, pProtect)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>One leg of a probe as <code>http code failedPair</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get(pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get(pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>One port call of the probe, recorded as <code>{http, code, failedPair}</code> in <var>pOut</var> under
/// <var>pName</var>.</p>
ClassMethod Leg(pOut As %DynamicObject, pName As %String, pPort As %String, pType As %String, ByRef pQuery, pBody = "")
{
    Set tHttp = 0
    Set tFault = ""
    Kill tResult
    Set tSC = $ClassMethod(pPort, "Invoke", "Settings", pType, .pQuery, pBody, .tResult, .tHttp, .tFault)
    Set tLeg = {}
    Do tLeg.%Set("http", +tHttp, "number")
    If $IsObject(tFault) {
        Do tLeg.%Set("code", tFault.%Get("code"))
        If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
    }
    Do pOut.%Set(pName, tLeg)
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of
/// <parameter>LEGS</parameter> through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the
/// probe operation's <code>InitSeconds</code>, then a <code>served</code> leg (a set of <code>ProbeDirectory</code> to the
/// directory OcuPilot serves its files from) and, when <var>pProtect</var> is set, a <code>protect</code> leg (a set of
/// <code>InitSeconds</code> through the seam with every pair held by its fake gate, so only the vendor can refuse), and signal <code>{loggedIn,
/// username, "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised. It runs in its own process so the login never touches the test's own
/// identity.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pProduction As %String, pProtect As %Boolean = 0)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tPort = "OcuPilot.Port.InteropPort"
        Set tId = pProduction _ $Char(1) _ ..#ITEM _ $Char(1) _ "Host" _ $Char(1) _ "InitSeconds"
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece(..#LEGS, ",", tI)
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tBody = ""
            If tType = "LIST" {
                Set tQuery("item") = pProduction _ $Char(1) _ ..#ITEM
                Set tQuery("maxRows") = 5
            } Else {
                Set tQuery("id") = tId
                If tType = "SET" Set tBody = {"Value": "7"}
            }
            Do ..Leg(tOut, tLegName, tPort, tType, .tQuery, tBody)
        }
        Kill tQuery
        Set tQuery("namespace") = pNamespace
        Set tQuery("id") = pProduction _ $Char(1) _ ..#ITEM _ $Char(1) _ "Host" _ $Char(1) _ "ProbeDirectory"
        Do ..Leg(tOut, "served", tPort, "SET", .tQuery, {"Value": ($ClassMethod("OcuPilot.Port.PathPort", "ServedDirectory") _ "probe")})
        If 'pProtect Quit
        For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
            Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
        }
        Kill tQuery
        Set tQuery("namespace") = pNamespace
        Set tQuery("id") = tId
        Do ..Leg(tOut, "protect", "OcuPilot.Test.InteropSettingSeam", "SET", .tQuery, {"Value": "9"})
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
