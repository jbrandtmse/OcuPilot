/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the nine runtime reads and the nine screens' read routes
/// against real principals (AD-8, AD-29, AD-44, AD-62, Story 20.4): a principal holding every pair the reads name but one
/// is refused 403 naming that pair, before any vendor call, by every endpoint that requires it and admitted by every
/// endpoint that does not; and a principal holding exactly one endpoint's pairs and READ on <code>USER</code>'s database
/// reads its rows, the log and message reads included, though it holds no SQL privilege on the interoperability tables
/// (its own <code>%ExecDirect</code> on them is refused, so the port's <code>%ExecDirectNoPriv</code> is what reads them
/// after its gate).</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never
/// changes identity. The screen legs are HTTP requests signed in as the principal.</p>
/// <p>It reads a leg and a refusal's failed pair through <class>OcuPilot.Test.InteropItemGate</class>, as
/// <class>OcuPilot.Test.InteropSettingGate</class> does, but builds its own principals and runs its own
/// <method>ProbeAs</method> and <method>Probe</method>: the nine reads need a principal missing each single pair and one
/// holding exactly each endpoint's pairs, where that class's six principals are the item writes' pairs, and its probe
/// runs the item writes' legs where this one's runs the nine reads, counts their rows and tries the principal's own
/// SQL.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), hangs its operation and sends it three messages,
/// and creates eighteen users and roles named <code>OcuP204*</code>, and drops <code>USER</code>'s cached queries in one
/// test. The probe and the principals are removed after the last test. One class per run.</p>
Class OcuPilot.Test.InteropHostGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter ITEMGATE = "OcuPilot.Test.InteropItemGate";

Parameter DESCRIPTOR = "OcuPilot.Test.InteropHostDescriptor";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

/// <p>The endpoints, in the order a probe runs them, and each one's screen route.</p>
Parameter ENDPOINTS = "Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs";

Parameter SCREENS = "Monitor=interop.monitor;ItemStatus=interop.itemstatus;Queues=interop.queues;QueueItems=interop.queuemessages;ItemQueue=interop.itemqueue;ItemLog=interop.itemlog;ItemMessages=interop.itemmessages;Jobs=interop.jobs;ItemJobs=interop.itemjobs";

/// <p>The database pair every read ends with, after the endpoint's own.</p>
Parameter DATABASEPAIR = "%DB_USER:READ";

/// <p>The pairs the principals are built from, one per pair any endpoint names, plus <parameter>DATABASEPAIR</parameter>.</p>
Parameter UNIVERSE = "%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_Dashboard:USE,%Ens_Queues:READ,%Ens_Jobs:READ,%Ens_EventLog:USE,%Ens_MessageHeader:USE,%DB_USER:READ";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostGate compiles a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP204Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#READ, "ArmProbe", .tIds)
    If $$$ISOK(tSC) Set tSC = ..EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tCount = ..PrincipalCount()
    For tI = 1:1:tCount {
        Set tUsers(tI) = ..UserAt(tI)
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:tCount {
            Set tUser = tUsers(tI)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The pairs of <parameter>UNIVERSE</parameter>, as a <class>%List</class>.</p>
ClassMethod Universe() As %List
{
    Quit $ListFromString(..#UNIVERSE, ",")
}

/// <p>The pairs <var>pEndpoint</var> requires, in the order the gate evaluates them: its own, then the database's.</p>
ClassMethod PairsOf(pEndpoint As %String) As %List
{
    Quit $ListFromString($ClassMethod(..#DESCRIPTOR, "PairsOf", pEndpoint) _ "," _ ..#DATABASEPAIR, ",")
}

/// <p>How many principals there are: the one holding every pair, one missing each pair, and one holding exactly each
/// endpoint's pairs.</p>
ClassMethod PrincipalCount() As %Integer
{
    Quit 1 + $ListLength(..Universe()) + $Length(..#ENDPOINTS, ",")
}

/// <p>The user at position <var>pAt</var>: <code>OcuP204Full</code>, then <code>OcuP204No&lt;n&gt;</code> for the pair at
/// position n of <parameter>UNIVERSE</parameter>, then <code>OcuP204Ex&lt;n&gt;</code> for the endpoint at position n.</p>
ClassMethod UserAt(pAt As %Integer) As %String
{
    Set tPairs = $ListLength(..Universe())
    If pAt = 1 Quit "OcuP204Full"
    If pAt <= (1 + tPairs) Quit "OcuP204No" _ (pAt - 1)
    Quit "OcuP204Ex" _ (pAt - 1 - tPairs)
}

/// <p>The pairs the principal at position <var>pAt</var> holds, as a <class>%List</class>.</p>
ClassMethod HeldBy(pAt As %Integer) As %List
{
    Set tUniverse = ..Universe()
    Set tPairs = $ListLength(tUniverse)
    If pAt = 1 Quit tUniverse
    If pAt <= (1 + tPairs) {
        Set tHeld = ""
        For tI = 1:1:tPairs {
            If tI '= (pAt - 1) Set tHeld = tHeld _ $ListBuild($List(tUniverse, tI))
        }
        Quit tHeld
    }
    Quit ..PairsOf($Piece(..#ENDPOINTS, ",", pAt - 1 - tPairs))
}

/// <p>What the endpoint <var>pEndpoint</var> answers a principal that holds <var>pHeld</var> (a pair list), as
/// <code>200</code> or <code>403 &lt;the first pair it lacks&gt;</code>: the gate names the first of the endpoint's pairs
/// the principal lacks, the database's last.</p>
ClassMethod ExpectedFor(pEndpoint As %String, pHeld As %List) As %String
{
    Set tPairs = ..PairsOf(pEndpoint)
    Set tMissing = ""
    For tI = 1:1:$ListLength(tPairs) {
        If '$ListFind(pHeld, $List(tPairs, tI)) {
            Set tMissing = $List(tPairs, tI)
            Quit
        }
    }
    Quit $Select(tMissing = "": "200", 1: "403 " _ tMissing)
}

/// <p>AC4: every principal's nine port legs are admitted or refused naming the pair
/// <method>ExpectedFor</method> says -- the one it lacks, in the order the gate evaluates the endpoint's pairs, the
/// database's last -- with 403 <code>AUTH.NOPRIVILEGE</code> on a refusal, before any vendor call; the principal holding
/// every pair reads all nine.</p>
/// <p>Mutation (Rule 19): drop each endpoint's own pair in turn from <method>OcuPilot.Port.InteropPort.Pairs</method>
/// (<code>%Ens_Dashboard:USE</code> from Monitor, <code>%Ens_Queues:READ</code> from the queue reads,
/// <code>%Ens_Jobs:READ</code> from the job reads, <code>%Ens_EventLog:USE</code> from ItemLog,
/// <code>%Ens_MessageHeader:USE</code> from ItemMessages) -- that pair's principal reaches the vendor and its leg goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    For tAt = 1:1:..PrincipalCount() {
        Set tUser = ..UserAt(tAt)
        If $Extract(tUser, 1, 9) = "OcuP204Ex" Continue
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        For tJ = 1:1:$Length(..#ENDPOINTS, ",") {
            Set tEndpoint = $Piece(..#ENDPOINTS, ",", tJ)
            Set tExpected = ..ExpectedFor(tEndpoint, ..HeldBy(tAt))
            Do $$$AssertEquals($ClassMethod(..#ITEMGATE, "LegText", tProbe.%Get("legs"), tEndpoint), $Select(tExpected = "200": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ $Piece(tExpected, " ", 2)), tUser _ ": " _ tEndpoint)
        }
    }
}

/// <p>AC4: a principal holding exactly one endpoint's pairs and READ on <code>USER</code>'s database reads that
/// endpoint's rows -- the Log and Messages tabs' included, though its own <code>%ExecDirect</code> on
/// <code>Ens.MessageHeader</code> and <code>Ens_Util.Log</code> is refused -- and is admitted to exactly the endpoints
/// whose pairs it holds.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.SqlRows</method> use <code>%ExecDirect</code> -- the two
/// SQL endpoints' exact principals are answered 500 and their legs go red.</p>
Method TestAPrincipalHoldingExactlyAnEndpointsPairsReadsItsRows()
{
    For tAt = (2 + $ListLength(..Universe())):1:..PrincipalCount() {
        Set tUser = ..UserAt(tAt)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tOwn = $Piece(..#ENDPOINTS, ",", tAt - 1 - $ListLength(..Universe()))
        Do $$$AssertTrue(tProbe.%Get("rows").%Get(tOwn) > 0, tUser _ ": " _ tOwn _ " answers rows: " _ tProbe.%Get("rows").%Get(tOwn))
        For tJ = 1:1:$Length(..#ENDPOINTS, ",") {
            Set tEndpoint = $Piece(..#ENDPOINTS, ",", tJ)
            Set tExpected = ..ExpectedFor(tEndpoint, ..HeldBy(tAt))
            Do $$$AssertEquals($ClassMethod(..#ITEMGATE, "LegText", tProbe.%Get("legs"), tEndpoint), $Select(tExpected = "200": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ $Piece(tExpected, " ", 2)), tUser _ ": " _ tEndpoint)
        }
        Do $$$AssertTrue(tProbe.%Get("headerSql") < 0, tUser _ ": it holds no SQL privilege on the message headers (SQLCODE " _ tProbe.%Get("headerSql") _ ")")
        Do $$$AssertTrue(tProbe.%Get("logSql") < 0, tUser _ ": nor on the event log (SQLCODE " _ tProbe.%Get("logSql") _ ")")
    }
}

/// <p>AC4: with the namespace's cached queries dropped, the principal holding exactly the Log endpoint's pairs and the
/// one holding exactly the Messages endpoint's each read their rows on the first read, though neither holds SQL
/// privilege on the table. The test drops the cached queries itself before each read, so it depends on no earlier
/// read's having compiled the statement.</p>
/// <p>Mutation (Rule 19): put <parameter>OcuPilot.Port.InteropPort:MESSAGESQL</parameter> back to
/// <code>WHERE ID IN (SELECT TOP ? ID ... UNION SELECT TOP ? ID ...)</code>, with <method>ListItemMessages</method>'s
/// arguments, and recompile the port and its descendants -- the Messages principal's leg is answered 500 and goes red,
/// and the Log principal's stays green.</p>
Method TestAStatementDroppedFromTheCacheIsReadByAPrincipalWithNoSqlPrivilege()
{
    For tEndpoint = "ItemLog", "ItemMessages" {
        Set tUser = ..UserAt(1 + $ListLength(..Universe()) + $ListFind($ListFromString(..#ENDPOINTS, ","), tEndpoint))
        Do $$$AssertStatusOK(..DropCachedQueries(), tEndpoint _ ": the cached queries are dropped")
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Do $$$AssertTrue((tProbe.%Get("headerSql") < 0) && (tProbe.%Get("logSql") < 0), tUser _ ": it holds no SQL privilege on the message headers or the event log: " _ tProbe.%ToJSON())
        Do $$$AssertEquals($ClassMethod(..#ITEMGATE, "LegText", tProbe.%Get("legs"), tEndpoint), "200  ", tUser _ ": " _ tEndpoint _ " is admitted on its first read")
        Do $$$AssertTrue(tProbe.%Get("rows").%Get(tEndpoint) > 0, tUser _ ": " _ tEndpoint _ " answers rows: " _ tProbe.%Get("rows").%Get(tEndpoint))
    }
}

/// <p>Drop every cached query in <parameter>NAMESPACE</parameter>, so that the next statement is compiled afresh.</p>
ClassMethod DropCachedQueries() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $SYSTEM.SQL.PurgeQueries()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>AC4: on the screens' read routes each principal is refused naming the pair its screen's read needs, in the order the
/// gate evaluates the pairs -- the screen's own pairs, then the namespace's database, which the route refuses first as
/// <code>NS.DENIED</code> naming the same pair -- and the principal holding exactly the pairs reads the screen's rows.</p>
/// <p>Mutation (Rule 19): drop one screen's own pair from its descriptor -- that screen's refusal for that pair goes red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tAt = 1:1:..PrincipalCount() {
        Set tUser = ..UserAt(tAt)
        For tJ = 1:1:$Length(..#ENDPOINTS, ",") {
            Set tEndpoint = $Piece(..#ENDPOINTS, ",", tJ)
            Set tExpected = ..ExpectedFor(tEndpoint, ..HeldBy(tAt))
            If ($Extract(tUser, 1, 9) = "OcuP204Ex") && (tExpected = "200") && (tEndpoint '= $Piece(..#ENDPOINTS, ",", tAt - 1 - $ListLength(..Universe()))) Continue
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ ..ScreenOf(tEndpoint) _ "/read?ns=" _ ..#NAMESPACE _ ..Criterion(tEndpoint) _ "&maxRows=50", tUser, ..PreparedPassword, .tStatus, .tRaw)
            If tExpected = "200" {
                Do $$$AssertEquals(tStatus _ " " _ $Select(..RowCount(tRaw) > 0: "rows", 1: "none"), "200 rows", tUser _ ": " _ tEndpoint _ "'s screen is read: " _ $Get(tRaw))
            } Else {
                Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#ITEMGATE, "FailedPair", tRaw), "403 " _ $Piece(tExpected, " ", 2), tUser _ ": " _ tEndpoint _ "'s screen is refused naming the pair: " _ $Get(tRaw))
            }
        }
    }
}

/// <p>The screen route of <var>pEndpoint</var>, from <parameter>SCREENS</parameter>.</p>
ClassMethod ScreenOf(pEndpoint As %String) As %String
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        If $Piece(tEntry, "=", 1) = pEndpoint Quit
    }
    Quit $Piece(tEntry, "=", 2)
}

/// <p>The query text that names the probe's item or queue for <var>pEndpoint</var>, or <code>""</code>; the item in the
/// vendor's <code>Production||Name</code> spelling, URL-encoded.</p>
ClassMethod Criterion(pEndpoint As %String) As %String
{
    If pEndpoint = "QueueItems" Quit "&queue=" _ ..#OPNAME
    If $ListFind($ClassMethod("OcuPilot.Port.InteropPort", "ItemEndpoints"), pEndpoint) Quit "&item=" _ $ZConvert(..#PRODUCTION _ "||" _ ..#OPNAME, "O", "URL")
    Quit ""
}

/// <p>The number of rows a read answer (raw JSON) holds.</p>
ClassMethod RowCount(pRaw) As %Integer
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit 0
    Quit tBody.rows.%Size()
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object
/// carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropHostGate).Probe($Job, pUser)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of
/// <parameter>ENDPOINTS</parameter> through <class>OcuPilot.Port.InteropPort</class> in <parameter>NAMESPACE</parameter>
/// against the probe's item and queue, try the principal's own <code>%ExecDirect</code> on the message headers and the
/// event log, and signal <code>{loggedIn, username, legs: {&lt;endpoint&gt;: {http, code, failedPair}}, rows:
/// {&lt;endpoint&gt;: count}, headerSql, logSql}</code> to process <var>pParent</var>, or <code>{error}</code> when
/// something raised. It runs in its own process so the login never touches the test's own identity.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tLegs = {}
        Set tRows = {}
        For tI = 1:1:$Length(..#ENDPOINTS, ",") {
            Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
            Kill tQuery
            Set tQuery("namespace") = ..#NAMESPACE
            Set tQuery("maxRows") = 50
            If $ListFind($ClassMethod("OcuPilot.Port.InteropPort", "ItemEndpoints"), tEndpoint) Set tQuery("item") = ..#PRODUCTION _ "||" _ ..#OPNAME
            If tEndpoint = "QueueItems" Set tQuery("queue") = ..#OPNAME
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tLegs.%Set(tEndpoint, tLeg)
            Do tRows.%Set(tEndpoint, $Select($IsObject($Get(tResult)): tResult.%Size(), 1: 0), "number")
        }
        Do tOut.%Set("legs", tLegs)
        Do tOut.%Set("rows", tRows)
        ; The principal's own SQL, which only a principal that can reach the namespace's database is asked.
        Do tOut.%Set("headerSql", 0, "number")
        Do tOut.%Set("logSql", 0, "number")
        Try {
            Set $NAMESPACE = ..#NAMESPACE
            Set tHeader = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM Ens.MessageHeader")
            Do tOut.%Set("headerSql", +tHeader.%SQLCODE, "number")
            Set tLog = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM Ens_Util.Log")
            Do tOut.%Set("logSql", +tLog.%SQLCODE, "number")
        } Catch {
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create each principal with a role of its own holding its pairs, <code>%Development:USE</code> and READ on the
/// install namespace's code database (as every caller of a route must), then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        ; Everything this class names is read before the switch: its own methods do not resolve in %SYS.
        Set tCount = ..PrincipalCount()
        For tAt = 1:1:tCount {
            Set tUsers(tAt) = ..UserAt(tAt)
            Set tHeld = ..HeldBy(tAt)
            Set tGrants(tAt) = tHome _ ":R,%Development:U"
            For tI = 1:1:$ListLength(tHeld) {
                Set tPair = $List(tHeld, tI)
                Set tGrants(tAt) = tGrants(tAt) _ "," _ $Piece(tPair, ":", 1) _ ":" _ $Extract($Piece(tPair, ":", 2), 1)
            }
        }
        Set $NAMESPACE = "%SYS"
        For tAt = 1:1:tCount {
            Set tUser = tUsers(tAt)
            Set tRole = tUser _ "Role"
            Set tGrant = tGrants(tAt)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the runtime reads' gate (throwaway)", tGrant, "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot runtime read gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropHostGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tAt = 1:1:..PrincipalCount() {
            Set tHeld = ..HeldBy(tAt)
            For tI = 1:1:$ListLength(..Universe()) {
                Set tPair = $List(..Universe(), tI)
                Set tWanted = ''$ListFind(tHeld, tPair)
                Set tPermission = $Piece(tPair, ":", 2)
                If $SYSTEM.Security.CheckUserPermission(..UserAt(tAt), $Piece(tPair, ":", 1), tPermission) '= tWanted {
                    Set tSC = $$$ERROR($$$GeneralError, "the principal " _ ..UserAt(tAt) _ "'s " _ tPair _ " did not read back as declared")
                    Quit
                }
            }
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
