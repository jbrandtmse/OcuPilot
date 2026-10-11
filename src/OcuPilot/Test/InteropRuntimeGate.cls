/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the queue and job actions and the five tools' pairs against real principals
/// (AD-8, AD-29, AD-44, AD-62, Story 20.23): a principal missing one pair -- the Interoperability menu's <code>%Ens_Portal:USE</code>,
/// the screen's <code>:READ</code>, the action's own pair (<code>%Ens_Queues:WRITE</code>, <code>%Ens_Jobs:WRITE</code> or
/// <code>%Ens_MessageSuspend:USE</code>), or the namespace's database -- is refused 403 naming that pair through the port, at the mint and
/// confirm (<method>OcuPilot.Kernel.Proposal.Operation.Gate</method>, which both call) and on the screen action routes, before any vendor
/// call; a principal holding exactly a tool's pairs completes its action, the forced stop included; and a principal who holds READ but not
/// WRITE on the database, past the port's gate, is refused by the vendor itself, <code>PORT.ACCESSDENIED</code>, with nothing changed.</p>
/// <p>Three families of principal, each with one holding exactly its pairs and one missing each pair: <code>Q</code> (queue aborts, the
/// Queues and Queue messages endpoints), <code>JA</code> (a job's abort and stop) and <code>JS</code> (a job's suspend).</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes identity.
/// The route legs are HTTP requests signed in as the principal.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in <code>USER</code></b>
/// (<class>OcuPilot.Test.ProductionProbe</class>) and creates eighteen users and roles named <code>OcuP2023*</code>. Each principal also
/// holds READ on the install namespace's code database and <code>%Development:USE</code>, as every caller of a route must. The probe and the
/// principals are removed after the last test. One class per run.</p>
Class OcuPilot.Test.InteropRuntimeGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter ITEMGATE = "OcuPilot.Test.InteropItemGate";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter JOBS = "OcuPilot.Test.InteropJobActions";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter RETRYNAME = "OcuPilotProbeRetry";

/// <p>The families, <code>&lt;family&gt;|&lt;read pair&gt;|&lt;own pair&gt;|&lt;role grant of the read pair&gt;|&lt;role grant of the own pair&gt;|&lt;tools&gt;</code>,
/// separated by <code>;</code>. A read pair and an own pair on one resource are one grant in the exact role.</p>
Parameter FAMILIES = "Q|%Ens_Queues:READ|%Ens_Queues:WRITE|%Ens_Queues:R|%Ens_Queues:W|InteropQueueMessageAbort,InteropQueueAbort;JA|%Ens_Jobs:READ|%Ens_Jobs:WRITE|%Ens_Jobs:R|%Ens_Jobs:W|InteropJobAbort,InteropJobStop;JS|%Ens_Jobs:READ|%Ens_MessageSuspend:USE|%Ens_Jobs:R|%Ens_MessageSuspend:U|InteropJobSuspend";

/// <p>The variants of each family's principal: one holding exactly its pairs, and one missing each pair in turn (the database is missing
/// from <code>NoDb</code>, and only readable for <code>DbR</code>).</p>
Parameter VARIANTS = "Ex,NoPortal,NoRead,NoOwn,NoDb,DbR";

/// <p>The legs a missing-pair principal runs, <code>&lt;endpoint&gt;|&lt;type&gt;</code>, per family: every read and write of the family
/// against ids that name nothing, so an admitted read answers 404 and a refused call is refused before any lookup.</p>
Parameter LEGS = "Q=Queues|QUEUE|OcuP2023None,Queues|ABORTQUEUE|OcuP2023None,QueueItems|ENTRY|1,QueueItems|ABORTMESSAGE|1;JA=Jobs|JOB|1,Jobs|ABORTJOB|1,Jobs|STOPJOB|1;JS=Jobs|JOB|1,Jobs|SUSPENDJOB|1";

/// <p>The screen action each family's routes are posted, <code>&lt;family&gt;=&lt;route&gt;|&lt;action&gt;</code> pairs, separated by <code>,</code>.</p>
Parameter ROUTES = "Q=interop.queuemessages|abort,interop.queues|abort;JA=interop.jobs|abort,interop.jobs|stop;JS=interop.jobs|suspend";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropRuntimeGate compiles and runs a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP2023Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = ..EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tFamily = 1:1:$Length(..#FAMILIES, ";") {
            For tVariant = 1:1:$Length(..#VARIANTS, ",") {
                Set tUser = ..UserOf($Piece($Piece(..#FAMILIES, ";", tFamily), "|", 1), $Piece(..#VARIANTS, ",", tVariant))
                If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
                If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
                If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropRuntimeGate left the principal or role of " _ tUser))
            }
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
    Do $ClassMethod(..#SEAM, "Disarm")
    Quit $ClassMethod(..#PROBE, "Settle")
}

/// <p>The fake gate is cleared, the proposals removed and the probe stopped, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>The user of family <var>pFamily</var>'s variant <var>pVariant</var>.</p>
ClassMethod UserOf(pFamily As %String, pVariant As %String) As %String
{
    Quit "OcuP2023" _ pFamily _ pVariant
}

/// <p>Piece <var>pAt</var> of family <var>pFamily</var>'s entry in <parameter>FAMILIES</parameter>.</p>
ClassMethod FamilyPiece(pFamily As %String, pAt As %Integer) As %String
{
    For tI = 1:1:$Length(..#FAMILIES, ";") {
        If $Piece($Piece(..#FAMILIES, ";", tI), "|", 1) = pFamily Quit
    }
    Quit $Piece($Piece(..#FAMILIES, ";", tI), "|", pAt)
}

/// <p>The pair a family's variant is refused on, or <code>""</code> when it is admitted: the Interoperability menu's, then the screen's
/// read, then (for a write) the action's own, then the database's.</p>
ClassMethod Expected(pFamily As %String, pVariant As %String, pWrite As %Boolean) As %String
{
    If pVariant = "NoPortal" Quit "%Ens_Portal:USE"
    If pVariant = "NoRead" Quit ..FamilyPiece(pFamily, 2)
    If pVariant = "NoOwn" Quit $Select(pWrite: ..FamilyPiece(pFamily, 3), 1: "")
    If pVariant = "NoDb" Quit $Select(pWrite: "%DB_USER:WRITE", 1: "%DB_USER:READ")
    If pVariant = "DbR" Quit $Select(pWrite: "%DB_USER:WRITE", 1: "")
    Quit ""
}

/// <p>The pair a tool or a route fails on for a family's variant: <method>Expected</method> for a write, except that the tool's database
/// pair is WRITE alone, and a route's namespace entry asks READ first.</p>
ClassMethod ExpectedTool(pFamily As %String, pVariant As %String, pRoute As %Boolean) As %String
{
    If (pVariant = "NoDb") && pRoute Quit "%DB_USER:READ"
    If (pVariant = "NoDb") || (pVariant = "DbR") Quit "%DB_USER:WRITE"
    Quit ..Expected(pFamily, pVariant, 1)
}

/// <p>The role grants of family <var>pFamily</var>'s variant <var>pVariant</var>, as <code>Security.Roles.Create</code> takes them, less the
/// install namespace's code database READ, which <method>EnsurePrincipals</method> adds.</p>
ClassMethod Grants(pFamily As %String, pVariant As %String) As %String
{
    Set tRead = ..FamilyPiece(pFamily, 4)
    Set tOwn = ..FamilyPiece(pFamily, 5)
    Set tBoth = $Select($Piece(tRead, ":", 1) = $Piece(tOwn, ":", 1): $Piece(tRead, ":", 1) _ ":RW", 1: tRead _ "," _ tOwn)
    Set tGrants = "%Development:U"
    If pVariant '= "NoPortal" Set tGrants = tGrants _ ",%Ens_Portal:U"
    Set tGrants = tGrants _ "," _ $Case(pVariant, "NoRead": tOwn, "NoOwn": tRead, : tBoth)
    If pVariant '= "NoDb" Set tGrants = tGrants _ ",%DB_USER:" _ $Select(pVariant = "DbR": "R", 1: "RW")
    Quit tGrants
}

/// <p>Create each principal with a role of its own holding its grants and READ on the install namespace's code database, then read the
/// decisive grants back.</p>
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
        Set $NAMESPACE = "%SYS"
        For tFamily = 1:1:$Length(..#FAMILIES, ";") {
            Set tName = $Piece($Piece(..#FAMILIES, ";", tFamily), "|", 1)
            For tVariant = 1:1:$Length(..#VARIANTS, ",") {
                Set tUser = ..UserOf(tName, $Piece(..#VARIANTS, ",", tVariant))
                Set tRole = tUser _ "Role"
                If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
                If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
                Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the queue and job actions' gate (throwaway)", tHome _ ":R," _ ..Grants(tName, $Piece(..#VARIANTS, ",", tVariant)), "")
                If $$$ISERR(tSC) Quit
                Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot queue and job gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropRuntimeGate; deleted in OnAfterAllTests")
                If $$$ISERR(tSC) Quit
            }
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("QEx", "%Ens_Queues", "WRITE", 1), $ListBuild("QNoOwn", "%Ens_Queues", "WRITE", 0), $ListBuild("QNoRead", "%Ens_Queues", "READ", 0), $ListBuild("JAEx", "%Ens_Jobs", "WRITE", 1), $ListBuild("JANoOwn", "%Ens_Jobs", "WRITE", 0), $ListBuild("JSEx", "%Ens_MessageSuspend", "USE", 1), $ListBuild("JSNoOwn", "%Ens_MessageSuspend", "USE", 0), $ListBuild("JSNoRead", "%Ens_Jobs", "READ", 0), $ListBuild("QDbR", "%DB_USER", "WRITE", 0), $ListBuild("QDbR", "%DB_USER", "READ", 1), $ListBuild("QNoDb", "%DB_USER", "READ", 0), $ListBuild("QNoPortal", "%Ens_Portal", "USE", 0) {
            If $SYSTEM.Security.CheckUserPermission("OcuP2023" _ $List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal OcuP2023" _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The legs of family <var>pFamily</var>, as <parameter>LEGS</parameter> names them.</p>
ClassMethod LegsOf(pFamily As %String) As %String
{
    For tI = 1:1:$Length(..#LEGS, ";") {
        If $Piece($Piece(..#LEGS, ";", tI), "=", 1) = pFamily Quit
    }
    Quit $Piece($Piece(..#LEGS, ";", tI), "=", 2)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>. <var>pLegs</var> is the legs it runs, <code>endpoint|type|id</code> comma-separated; with <var>pPast</var> 1 it
/// runs them through the fake gate, which holds every pair, so the vendor's own answer is the one that comes back.</p>
ClassMethod ProbeAs(pUser As %String, pLegs As %String, pTools As %String, pPast As %Boolean = 0) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropRuntimeGate).Probe($Job, pUser, ..#NAMESPACE, pLegs, pTools, pPast)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 240)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 240 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <var>pLegs</var> through
/// <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> (or, with <var>pPast</var>, through
/// <class>OcuPilot.Test.InteropItemSeam</class> holding every pair), evaluate each of <var>pTools</var>' pairs for a request scoped to
/// <var>pNamespace</var>, and signal <code>{loggedIn, username, "&lt;endpoint&gt;|&lt;type&gt;|&lt;id&gt;": {http, code, failedPair},
/// tools: {&lt;tool&gt;: failed pair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pLegs As %String, pTools As %String, pPast As %Boolean)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tClass = $Select(pPast: ..#SEAM, 1: ..#PORT)
        If pPast {
            For tPair = "%Ens_Portal:USE", "%Ens_Queues:READ", "%Ens_Queues:WRITE", "%Ens_Jobs:READ", "%Ens_Jobs:WRITE", "%Ens_MessageSuspend:USE", "%DB_USER:READ", "%DB_USER:WRITE" {
                Do ##class(OcuPilot.Test.ScreenGate).Hold($Piece(tPair, ":", 1), $Piece(tPair, ":", 2))
            }
        }
        For tI = 1:1:$Length(pLegs, ",") {
            Set tLegName = $Piece(pLegs, ",", tI)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("id") = $Piece(tLegName, "|", 3)
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = $ClassMethod(tClass, "Invoke", $Piece(tLegName, "|", 1), $Piece(tLegName, "|", 2), .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tLegName, tLeg)
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tTools = {}
        For tI = 1:1:$Length(pTools, ",") {
            Set tTool = $Piece(pTools, ",", tI)
            If tTool = "" Continue
            Set tPairs = $ClassMethod("OcuPilot.Screen.Tool." _ tTool, "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tTools.%Set(tTool, tFailed)
        }
        Do tOut.%Set("tools", tTools)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>One leg of a probe as <code>http code failedPair</code>, <code>absent</code> when the probe did not run it.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get(pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get(pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>Whether a leg whose text is <var>pText</var> is a refusal naming <var>pPair</var> (403 <code>AUTH.NOPRIVILEGE</code>), or, when
/// <var>pPair</var> is empty, was admitted: answered something other than 403.</p>
ClassMethod Matches(pText As %String, pPair As %String) As %Boolean
{
    If pPair = "" Quit ($Piece(pText, " ", 1) '= 403) && ($Piece(pText, " ", 1) '= "absent")
    Quit pText = ("403 AUTH.NOPRIVILEGE " _ pPair)
}

/// <p>AC6: each missing-pair principal's legs are refused naming the pair <method>Expected</method> says, 403 <code>AUTH.NOPRIVILEGE</code>, or
/// admitted (past the gate, an id that names nothing answers 404); each of the family's tools fails on the first pair the principal lacks, in
/// the order screen pairs, the action's own, the database's write; and the mint and the confirm, which both ask
/// <method>OcuPilot.Kernel.Proposal.Operation.Gate</method>, refuse the principal naming that pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Jobs:WRITE</code> from <parameter>OcuPilot.Port.InteropPort.JOBWRITEPAIR</parameter> -- the <code>NoOwn</code>
/// rows of <code>JA</code> go red at the port; drop the own pair from <method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method> -- the
/// tool and mint rows of every family go red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePortTheToolsAndTheMint()
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tFamily = 1:1:$Length(..#FAMILIES, ";") {
        Set tName = $Piece($Piece(..#FAMILIES, ";", tFamily), "|", 1)
        Set tTools = $Piece($Piece(..#FAMILIES, ";", tFamily), "|", 6)
        For tVariant = 2:1:$Length(..#VARIANTS, ",") {
            Set tKind = $Piece(..#VARIANTS, ",", tVariant)
            Set tUser = ..UserOf(tName, tKind)
            Set tLegs = ..LegsOf(tName)
            Set tProbe = ..ProbeAs(tUser, tLegs, tTools)
            Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
            For tLeg = 1:1:$Length(tLegs, ",") {
                Set tLegName = $Piece(tLegs, ",", tLeg)
                Set tWrite = ($Piece(tLegName, "|", 2) '= "QUEUE") && ($Piece(tLegName, "|", 2) '= "ENTRY") && ($Piece(tLegName, "|", 2) '= "JOB")
                Set tWanted = ..Expected(tName, tKind, tWrite)
                Do $$$AssertTrue(..Matches(..LegText(tProbe, tLegName), tWanted), tUser _ ": " _ tLegName _ " is " _ $Select(tWanted = "": "admitted", 1: "refused naming " _ tWanted) _ ", not " _ ..LegText(tProbe, tLegName))
            }
            Set tWanted = ..ExpectedTool(tName, tKind, 0)
            For tTool = 1:1:$Length(tTools, ",") {
                Set tToolName = $Piece(tTools, ",", tTool)
                Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tToolName), 1: "absent"), tWanted, tUser _ ": " _ tToolName _ " fails on " _ tWanted)
                Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter("OcuPilot.Screen.Tool." _ tToolName, "TOOLNAME"), .tRegistered)
                Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tRegistered, "x", "", "", "{""" _ $ClassMethod("OcuPilot.Screen.Tool." _ tToolName, "IdArgument") _ """:""1""}", tUser, "", "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
                Do $$$AssertStatusOK(tGateSC, tUser _ ": the mint's and the confirm's gate answers for " _ tToolName)
                Do $$$AssertEquals(tRefused _ "|" _ tGateHttp _ "|" _ tGateCode _ "|" _ $Select($IsObject(tGateDetail): tGateDetail.%Get("failedPair"), 1: ""), "1|403|AUTH.NOPRIVILEGE|" _ tWanted, tUser _ ": the mint and the confirm refuse " _ tToolName _ " naming " _ tWanted)
            }
        }
    }
}

/// <p>AC6: on the screen action routes each missing-pair principal is refused naming the pair its tool needs -- before the target is read,
/// so a target that names nothing is still refused for the privilege and not as absent -- and a principal without READ on the namespace's
/// database is refused at the namespace entry naming <code>%DB_USER:READ</code>.</p>
/// <p>Mutation (Rule 19): drop the own pair from <method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method> -- the <code>NoOwn</code> route rows go
/// red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tFamily = 1:1:$Length(..#FAMILIES, ";") {
        Set tName = $Piece($Piece(..#FAMILIES, ";", tFamily), "|", 1)
        Set tRoutes = ""
        For tI = 1:1:$Length(..#ROUTES, ";") {
            If $Piece($Piece(..#ROUTES, ";", tI), "=", 1) = tName Set tRoutes = $Piece($Piece(..#ROUTES, ";", tI), "=", 2)
        }
        For tVariant = 2:1:$Length(..#VARIANTS, ",") {
            Set tKind = $Piece(..#VARIANTS, ",", tVariant)
            Set tUser = ..UserOf(tName, tKind)
            For tRoute = 1:1:$Length(tRoutes, ",") {
                Set tEntry = $Piece(tRoutes, ",", tRoute)
                Set tRequest = {"action": ($Piece(tEntry, "|", 2))}
                Do tRequest.%Set("id", "1", "string")
                Kill tExtra
                Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/screens/" _ $Piece(tEntry, "|", 1) _ "/action?ns=" _ ..#NAMESPACE, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json", .tExtra, 90)
                Set tPair = $ClassMethod(..#ITEMGATE, "FailedPair", tRaw)
                Do $$$AssertEquals(tStatus _ " " _ tPair, "403 " _ ..ExpectedTool(tName, tKind, 1), tUser _ ": " _ tEntry _ " is refused naming the pair: " _ $Extract($Get(tRaw), 1, 200))
            }
        }
    }
}

/// <p>AC6: a principal holding exactly the queue family's pairs reads a queue and an entry and aborts one message and then the queue's others
/// through the port, and the instance shows it: both waiting headers read Aborted, the message the operation holds does not.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Queues:WRITE</code> from <parameter>OcuPilot.Port.InteropPort.QUEUEWRITEPAIR</parameter> -- the missing-pair rows
/// of <method>TestEachMissingPairIsRefusedByNameThroughThePortTheToolsAndTheMint</method> go red, the exact principal still passing.</p>
Method TestAPrincipalHoldingExactlyTheQueuePairsAbortsMessages()
{
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(tIds, ",", 1)
    Set tFirst = $Piece(tIds, ",", 2)
    Set tSecond = $Piece(tIds, ",", 3)
    Set tLegs = "Queues|QUEUE|" _ ..#OPNAME _ ",QueueItems|ENTRY|" _ tFirst _ ",QueueItems|ABORTMESSAGE|" _ tFirst _ ",Queues|ABORTQUEUE|" _ ..#OPNAME
    Set tProbe = ..ProbeAs(..UserOf("Q", "Ex"), tLegs, "InteropQueueMessageAbort,InteropQueueAbort")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..UserOf("Q", "Ex"), "the probe ran as the principal: " _ tProbe.%ToJSON())
    For tLeg = 1:1:$Length(tLegs, ",") {
        Do $$$AssertEquals(..LegText(tProbe, $Piece(tLegs, ",", tLeg)), "200  ", $Piece(tLegs, ",", tLeg) _ " is admitted and completes")
    }
    Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.InteropQueueMessageAbort _ tProbe.tools.InteropQueueAbort, 1: "absent"), "", "and both tools' pairs are held")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "HeaderStatus", tFirst) _ "|" _ $ClassMethod(..#QUEUES, "HeaderStatus", tSecond), "7|7", "both waiting headers read Aborted")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "HeaderStatus", tHeld) '= 7, 1, "and the held message does not")
}

/// <p>AC6, AC4: a principal holding exactly a job's abort and stop pairs aborts the message of the job that is retrying, and stops the
/// operation's job while it is hung on a message, which takes the production's whole wait and forces it: the call answers, the retried
/// message reads Aborted, the hung job's message is back on its queue, and the job is gone.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Jobs:WRITE</code> from <parameter>OcuPilot.Port.InteropPort.JOBWRITEPAIR</parameter> -- the missing-pair rows go red.</p>
Method TestAPrincipalHoldingExactlyTheJobAbortPairsAbortsAndStops()
{
    Set tRetry = ..ArmHungAndRetrying(.tMessage, .tHeldJob, .tHeld)
    Do $$$AssertNotEquals(tRetry, "", "the production has a hung job and a retrying job")
    If tRetry = "" Quit
    Set tLegs = "Jobs|JOB|" _ tRetry _ ",Jobs|ABORTJOB|" _ tRetry _ ",Jobs|STOPJOB|" _ tHeldJob
    Set tProbe = ..ProbeAs(..UserOf("JA", "Ex"), tLegs, "InteropJobAbort,InteropJobStop")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..UserOf("JA", "Ex"), "the probe ran as the principal: " _ tProbe.%ToJSON())
    For tLeg = 1:1:$Length(tLegs, ",") {
        Do $$$AssertEquals(..LegText(tProbe, $Piece(tLegs, ",", tLeg)), "200  ", $Piece(tLegs, ",", tLeg) _ " is admitted and completes")
    }
    Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.InteropJobAbort _ tProbe.tools.InteropJobStop, 1: "absent"), "", "and both tools' pairs are held")
    Do $$$AssertTrue($ClassMethod(..#JOBS, "WaitStatus", tMessage, 7) >= 0, "the retried message reads Aborted")
    Do $$$AssertEquals($ClassMethod(..#READ, "QueueCount"), 1, "the hung job's message is back on the operation's queue")
    Set tGone = '$ClassMethod("OcuPilot.Test.InteropJobStop", "Listed", tHeldJob)
    Do $$$AssertEquals(tGone, 1, "and the hung job is gone from the Jobs list")
}

/// <p>AC6: a principal holding exactly the suspend pairs, which are not the abort's, suspends the message of the job that is retrying.</p>
/// <p>Mutation (Rule 19): give <code>SUSPENDJOB</code> <parameter>JOBWRITEPAIR</parameter> in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the exact
/// principal is refused naming <code>%Ens_Jobs:WRITE</code> and this goes red.</p>
Method TestAPrincipalHoldingExactlyTheSuspendPairsSuspends()
{
    Set tJobs = ..#JOBS
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the probe is put back as declared")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRetryItem", ..#RETRYNAME, 2, 300), "a retrying operation is stored")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe production starts")
    Hang 3
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Send", ..#RETRYNAME), "a message is sent to it")
    For tTry = 1:1:30 {
        Set tRow = $ClassMethod(tJobs, "JobOf", ..#RETRYNAME)
        If $IsObject(tRow) && (tRow.Status = "Retry") Quit
        Hang 0.5
    }
    Set tRow = $ClassMethod(tJobs, "JobOf", ..#RETRYNAME)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Status = "Retry"), "its job reads Retry")
    If '$IsObject(tRow) Quit
    Set tLegs = "Jobs|JOB|" _ tRow.Job _ ",Jobs|SUSPENDJOB|" _ tRow.Job
    Set tProbe = ..ProbeAs(..UserOf("JS", "Ex"), tLegs, "InteropJobSuspend")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..UserOf("JS", "Ex"), "the probe ran as the principal: " _ tProbe.%ToJSON())
    For tLeg = 1:1:$Length(tLegs, ",") {
        Do $$$AssertEquals(..LegText(tProbe, $Piece(tLegs, ",", tLeg)), "200  ", $Piece(tLegs, ",", tLeg) _ " is admitted and completes")
    }
    Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.InteropJobSuspend, 1: "absent"), "", "and the tool's pairs are held")
    Do $$$AssertTrue($ClassMethod(tJobs, "WaitStatus", tRow.ActiveMessage, 5) >= 0, "the message reads Suspended")
    Set tAbort = ..ProbeAs(..UserOf("JS", "Ex"), "Jobs|ABORTJOB|" _ tRow.Job, "")
    Do $$$AssertTrue(..Matches(..LegText(tAbort, "Jobs|ABORTJOB|" _ tRow.Job), "%Ens_Jobs:WRITE"), "and it is refused the abort, whose pair it does not hold: " _ ..LegText(tAbort, "Jobs|ABORTJOB|" _ tRow.Job))
}

/// <p>Bring the probe to the state the abort and stop principal needs: the plain operation hung on one message and the retrying operation
/// retrying another. Answers the retrying job's process id, with its message in <var>pMessage</var>, the hung job's process id in
/// <var>pHungJob</var> and its message in <var>pHeld</var>; <code>""</code> when the state was not reached.</p>
Method ArmHungAndRetrying(Output pMessage As %String, Output pHungJob As %String, Output pHeld As %String) As %String
{
    Set pMessage = ""
    Set pHungJob = ""
    Set pHeld = ""
    Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SetHang", 600)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddRetryItem", ..#RETRYNAME, 2, 300)
    If $$$ISERR(tSC) Quit ""
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Hang 3
    Set tSC = $ClassMethod(..#PROBE, "Send")
    Set tSC = $ClassMethod(..#PROBE, "Send", ..#RETRYNAME)
    For tTry = 1:1:30 {
        Set tRetry = $ClassMethod(..#JOBS, "JobOf", ..#RETRYNAME)
        Set tHung = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
        If $IsObject(tRetry) && (tRetry.Status = "Retry") && $IsObject(tHung) && (tHung.ActiveMessage '= "") Quit
        Hang 0.5
    }
    If '$IsObject(tRetry) || (tRetry.Status '= "Retry") || '$IsObject(tHung) || (tHung.ActiveMessage = "") Quit ""
    Set pMessage = tRetry.ActiveMessage
    Set pHungJob = tHung.Job
    Set pHeld = tHung.ActiveMessage
    Quit tRetry.Job
}

/// <p>AC6: a principal who holds every pair but only READ on the namespace's database, let past the port's gate by the fake gate, is refused
/// by the vendor itself -- <code>&lt;PROTECT&gt;</code> on the instance's queue and job globals -- which the port answers 403
/// <code>PORT.ACCESSDENIED</code>; nothing is aborted or requested.</p>
/// <p>Mutation (Rule 19): map a vendor protect refusal to 500 in <method>OcuPilot.Port.InteropPort.Statused</method> -- the three legs go red.</p>
Method TestAPrincipalWithOnlyReadOnTheDatabaseIsRefusedByTheVendorPastTheGate()
{
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe holds one message and has two waiting")
    Set tFirst = $Piece(tIds, ",", 2)
    Set tProbe = ..ProbeAs(..UserOf("Q", "DbR"), "QueueItems|ABORTMESSAGE|" _ tFirst, "", 1)
    Do $$$AssertEquals(..LegText(tProbe, "QueueItems|ABORTMESSAGE|" _ tFirst), "403 PORT.ACCESSDENIED ", "the vendor refuses the abort of a message: " _ tProbe.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "HeaderStatus", tFirst) '= 7, 1, "and the message is not aborted")
    Do $$$AssertEquals($ClassMethod(..#READ, "QueueCount"), 2, "the queue still holds both waiting messages")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe is stopped")
    Set tRetry = ..ArmHungAndRetrying(.tMessage, .tHungJob, .tHeld)
    Do $$$AssertNotEquals(tRetry, "", "the production has a retrying job")
    If tRetry = "" Quit
    Set tAbort = ..ProbeAs(..UserOf("JA", "DbR"), "Jobs|ABORTJOB|" _ tRetry, "", 1)
    Do $$$AssertEquals(..LegText(tAbort, "Jobs|ABORTJOB|" _ tRetry), "403 PORT.ACCESSDENIED ", "the vendor refuses the abort of a job's message: " _ tAbort.%ToJSON())
    Set tSuspend = ..ProbeAs(..UserOf("JS", "DbR"), "Jobs|SUSPENDJOB|" _ tRetry, "", 1)
    Do $$$AssertEquals(..LegText(tSuspend, "Jobs|SUSPENDJOB|" _ tRetry), "403 PORT.ACCESSDENIED ", "and of its suspend: " _ tSuspend.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#JOBS, "RequestNodes"), 0, "and no request was left for the job")
}

}
