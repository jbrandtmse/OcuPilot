/// <p>Pins Story 20.23's declarations with no production started (AD-5, AD-8, AD-22, AD-44, AD-51, AD-59, AD-62): the five screens'
/// row actions and empty states, the five queue and job tools (names, request types, destructiveness, governance keys, pairs,
/// classic pages, fingerprint subjects, codes), <class>OcuPilot.Port.InteropPort</class>'s <code>Serves</code>, <code>Pairs</code>,
/// <code>RuntimeRefusal</code> and <code>QueueDigest</code>, every new code resolving to its sentence, the copy-out script of each
/// write, and where the job tools' shared members live.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and an interoperability-enabled <code>USER</code> namespace, whose
/// globals database the tools' pairs name. It starts nothing and creates no principal.</p>
Class OcuPilot.Test.InteropRuntimeDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

/// <p>The five tools, <code>&lt;class&gt;|&lt;tool&gt;|&lt;read type&gt;|&lt;write type&gt;|&lt;action&gt;|&lt;destructive&gt;|&lt;change action&gt;|&lt;consequence&gt;|&lt;baseline&gt;|&lt;endpoint&gt;|&lt;id argument&gt;|&lt;descriptor&gt;</code>,
/// separated by <code>;</code>.</p>
Parameter TOOLS = "InteropQueueMessageAbort|interop.queuemessages.abort|ENTRY|ABORTMESSAGE|abort|1|updated|INTEROP.MESSAGE.ABORT|0|QueueItems|MessageId|InteropQueueMessageList;InteropQueueAbort|interop.queues.abort|QUEUE|ABORTQUEUE|abort|1|updated|INTEROP.QUEUE.ABORT|0|Queues|Name|InteropQueueList;InteropJobAbort|interop.jobs.abort|JOB|ABORTJOB|abort|1|updated|INTEROP.JOB.ABORT|0|Jobs|Job|InteropJobList;InteropJobSuspend|interop.jobs.suspend|JOB|SUSPENDJOB|suspend|0|updated|INTEROP.JOB.SUSPEND|1|Jobs|Job|InteropJobList;InteropJobStop|interop.jobs.stop|JOB|STOPJOB|stop|0|deleted|INTEROP.JOB.STOP|1|Jobs|Job|InteropJobList";

/// <p>What each tool declares beyond that, <code>&lt;class&gt;|&lt;fingerprint subject&gt;|&lt;precondition field&gt;|&lt;state field&gt;|&lt;state marker&gt;|&lt;classic pages&gt;|&lt;precondition codes&gt;|&lt;own pair&gt;</code>,
/// separated by <code>;</code>.</p>
Parameter DECLARED = "InteropQueueMessageAbort|Queue,Priority,Index,Namespace|Index|Status|Status|EnsPortal.ProductionConfig|INTEROP.NAMESPACE,PORT.NOTFOUND|%Ens_Queues:WRITE;InteropQueueAbort|Entries,Digest,Namespace|Entries|Count|Entries|EnsPortal.ProductionConfig|INTEROP.QUEUE.EMPTY,INTEROP.NAMESPACE|%Ens_Queues:WRITE;InteropJobAbort|Host,Status,ActiveMessage,Dead,Namespace|Status|ActiveMessage|Status|EnsPortal.ProductionConfig,EnsPortal.Queues|INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE|%Ens_Jobs:WRITE;InteropJobSuspend|Host,Status,ActiveMessage,Dead,Namespace|Status|ActiveMessage|Status|EnsPortal.ProductionConfig,EnsPortal.Queues|INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE|%Ens_MessageSuspend:USE;InteropJobStop|Host,Dead,Namespace|Dead|Status|Status|EnsPortal.ProductionConfig|INTEROP.JOB.DEAD,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE|%Ens_Jobs:WRITE";

/// <p>The five screens that gain row actions, <code>&lt;class&gt;|&lt;row actions&gt;|&lt;empty agent key&gt;</code>.</p>
Parameter SCREENS = "InteropQueueList|abort|interopQueuesEmptyAgent;InteropQueueMessageList|abort|interopQueueMessagesEmptyAgent;InteropItemQueueTab|abort|interopQueueMessagesEmptyAgent;InteropJobList|abort,suspend,stop|interopJobsEmptyAgent;InteropItemJobTab|abort,suspend,stop|interopJobsEmptyAgent";

/// <p>The shared members <class>OcuPilot.Screen.Tool.InteropJobAction</class> holds and its three leaves do not.</p>
Parameter SHAREDMETHODS = "Endpoint,IdArgument,TargetName,InputSchema,StateDiff";

Parameter SHAREDPARAMETERS = "DESCRIPTORCLASS,READTYPE,READANSWERS,STATEMARKER";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The five screens declare their row actions in order, no primary action, the agent-inviting empty state and no next step,
/// and the registry accepts the roster with them.</p>
/// <p>Mutation (Rule 19): empty the <code>rowActions</code> of <class>OcuPilot.Screen.Descriptor.InteropJobList</class> -- this
/// and <method>OcuPilot.Test.InteropHostDescriptor.TestTheNineDeclarationsRegister</method> go red.</p>
Method TestTheFiveScreensOfferTheirActions()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tEntry = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tEntry, "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration reads")
        If '$IsObject($Get(tDeclaration)) Continue
        Set tActions = ""
        Set tIterator = tDeclaration.rowActions.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAction) {
            Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id _ ":" _ tAction.selfProtection
        }
        Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tActions, "|" _ $Replace($Piece(tEntry, "|", 2), ",", ":,") _ ":", tClass _ ": no primary action, and its row actions with no self-protection rule")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "|" _ $Piece(tEntry, "|", 3), tClass _ ": the empty state invites the agent and offers no next step")
    }
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertEquals($Get(tProblem), "", "the registry accepts the roster with the five screens' actions")
}

/// <p>Each tool declares what the spec names: its name, request types, screen action, destructiveness, change action,
/// consequence code, endpoint, id argument and descriptor, no body, one advertised write registered as such, the governance key
/// shipped as the baseline lists it (the three aborts disabled, suspend and stop enabled), its fingerprint subject passing the
/// adequacy rule, its precondition codes, and the pair that is its own.</p>
/// <p>Mutation (Rule 19): ship <code>interop.jobs.abort</code> as <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the key leg and <method>OcuPilot.Test.GovernanceBaseline</method> go red;
/// make <class>OcuPilot.Screen.Tool.InteropJobStop</class> destructive -- its destructive leg goes red.</p>
Method TestTheFiveToolsDeclareWhatTheSpecNames()
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tClassName = $Piece(tRow, "|", 1)
        Set tTool = "OcuPilot.Screen.Tool." _ tClassName
        Set tDeclared = ..DeclaredFor(tClassName)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")), $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 5), tTool _ ": name, request types and screen action")
        Do $$$AssertEquals($ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "IdArgument") _ "|" _ $ClassMethod(tTool, "IdParam"), $Piece(tRow, "|", 6) _ "|" _ $Piece(tRow, "|", 7) _ "|0|OcuPilot.Port.InteropPort|" _ $Piece(tRow, "|", 10) _ "|" _ $Piece(tRow, "|", 11) _ "|id", tTool _ ": destructiveness, change event, no body, port, endpoint and ids")
        Do $$$AssertEquals($Parameter(tTool, "DESCRIPTORCLASS"), "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 12), tTool _ ": its screen")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}, 0, ""), $Piece(tRow, "|", 8), tTool _ ": its consequence code")
        Set tListed = 0
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($Piece(tRow, "|", 2), .tListed)
        Do $$$AssertEquals(tListed _ "|" _ tValue, "1|" _ $Piece(tRow, "|", 9), tTool _ ": its governance key ships " _ $Select($Piece(tRow, "|", 9): "enabled", 1: "disabled"))
        Do $$$AssertEquals($Parameter(tTool, "ADVERTISED") _ "|" _ $Parameter(tTool, "KIND"), "1|write", tTool _ " is an advertised write")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", tTool _ " passes the subject's adequacy rule")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")) _ "|" _ $ClassMethod(tTool, "PreconditionField") _ "|" _ $ClassMethod(tTool, "StateField") _ "|" _ $Parameter(tTool, "STATEMARKER"), $Piece(tDeclared, "|", 2) _ "|" _ $Piece(tDeclared, "|", 3) _ "|" _ $Piece(tDeclared, "|", 4) _ "|" _ $Piece(tDeclared, "|", 5), tTool _ ": its subject, precondition field, state row and state marker")
        Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), $Piece(tDeclared, "|", 6), tTool _ ": the classic pages it performs")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "PreconditionCodes")), $Piece(tDeclared, "|", 7), tTool _ ": its precondition codes")
        Do $$$AssertEquals($Parameter(tTool, "WRITERESOURCE") _ ":" _ $Parameter(tTool, "WRITEPERMISSION"), $Piece(tDeclared, "|", 8), tTool _ ": the pair that is its own")
        Do $$$AssertEquals($Length($Parameter(tTool, "DESCRIPTION")) > 200, 1, tTool _ ": its description says what it proposes, how to name the target and what is refused")
        Do $$$AssertTrue($Parameter(tTool, "DESCRIPTION") [ "changes nothing by itself", tTool _ ": it says it only proposes")
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""" _ $Piece(tRow, "|", 11) _ """]", tTool _ " requires the target alone")
    }
}

/// <p>The pair set of each tool, in <code>USER</code>: the screen's two, the tool's own, WRITE on the namespace's globals database,
/// then the custom resource of each classic page the tool declares (none assigned), each pair once.</p>
/// <p>Mutation (Rule 19): drop the own pair from <method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method> -- this and
/// <method>OcuPilot.Test.InteropRuntimeGate.TestEachMissingPairIsRefusedByNameThroughTheToolsAndRoutes</method> go red.</p>
Method TestTheToolPairsAreTheScreensPlusTheOwnPairAndTheDatabase()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tResource, .tReadOnly)
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Set tScreen = $Select($Piece(tRow, "|", 10) = "Jobs": "%Ens_Portal:USE,%Ens_Jobs:READ", 1: "%Ens_Portal:USE,%Ens_Queues:READ")
        Do $$$AssertEquals(tResolved _ "|" _ tText, "1|" _ tScreen _ "," _ $Piece(..DeclaredFor($Piece(tRow, "|", 1)), "|", 8) _ "," _ tResource _ ":WRITE", $Parameter(tTool, "TOOLNAME") _ "'s pairs")
    }
}

/// <p>What the port serves: <code>LIST</code> on every runtime endpoint, and beyond it Queues the queue read and abort, QueueItems
/// the entry read and abort, Jobs the job read and the three job writes; none serves another endpoint's type or a production,
/// item or setting type. The write set is <code>IsRuntimeWrite</code>'s.</p>
/// <p>Mutation (Rule 19): drop <code>STOPJOB</code> from the Jobs branch of <method>OcuPilot.Port.InteropPort.Serves</method> -- this
/// goes red.</p>
Method TestThePortServesEachEndpointsTypes()
{
    Set tTypes = $ListBuild("LIST", "QUEUE", "ENTRY", "JOB", "ABORTQUEUE", "ABORTMESSAGE", "ABORTJOB", "SUSPENDJOB", "STOPJOB", "STATE", "START", "ITEM", "ENABLE", "SETTING", "SET")
    Set tServed("Queues") = $ListBuild("LIST", "QUEUE", "ABORTQUEUE")
    Set tServed("QueueItems") = $ListBuild("LIST", "ENTRY", "ABORTMESSAGE")
    Set tServed("Jobs") = $ListBuild("LIST", "JOB", "ABORTJOB", "SUSPENDJOB", "STOPJOB")
    Set tEndpoint = ""
    For {
        Set tEndpoint = $Order(tServed(tEndpoint))
        If tEndpoint = "" Quit
        For tI = 1:1:$ListLength(tTypes) {
            Set tType = $List(tTypes, tI)
            Do $$$AssertEquals(''$ClassMethod(..#PORT, "Serves", tEndpoint, tType), ''$ListFind(tServed(tEndpoint), tType), tEndpoint _ " " _ tType)
        }
    }
    For tEndpoint = "Monitor", "ItemStatus", "ItemQueue", "ItemLog", "ItemMessages", "ItemJobs" {
        For tType = "QUEUE", "ENTRY", "JOB", "ABORTQUEUE", "ABORTMESSAGE", "ABORTJOB", "SUSPENDJOB", "STOPJOB" {
            Do $$$AssertEquals($ClassMethod(..#PORT, "Serves", tEndpoint, tType), 0, tEndpoint _ " serves no " _ tType)
        }
    }
    Do $$$AssertEquals(..Text($ListBuild("ABORTQUEUE", "ABORTMESSAGE", "ABORTJOB", "SUSPENDJOB", "STOPJOB", "START", "ENABLE", "SET", "QUEUE", "LIST"), "IsRuntimeWrite"), "1,1,1,1,1,0,0,0,0,0", "IsRuntimeWrite names exactly the five")
}

/// <p>A typed read or write in a namespace that runs no interoperability (<code>%SYS</code>) is refused 409
/// <code>INTEROP.NAMESPACE</code> at the port's gate, for each of the three reads and five writes, before any vendor class is called.</p>
/// <p>Mutation (Rule 19): drop the <code>INTEROP.NAMESPACE</code> refusal from <method>OcuPilot.Port.InteropPort.Admit</method> (the port and
/// its descendants recompiled) -- this goes red.</p>
Method TestATypedCallInANamespaceWithoutInteroperabilityIsRefused()
{
    Set tCases = $ListBuild("Queues|QUEUE", "Queues|ABORTQUEUE", "QueueItems|ENTRY", "QueueItems|ABORTMESSAGE", "Jobs|JOB", "Jobs|ABORTJOB", "Jobs|SUSPENDJOB", "Jobs|STOPJOB")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Kill tQuery
        Set tQuery("namespace") = "%SYS"
        Set tQuery("id") = "1"
        Set tSC = $ClassMethod(..#PORT, "Invoke", $Piece(tCase, "|", 1), $Piece(tCase, "|", 2), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ $Parameter(..#ERROR, "NAMESPACE"), $Piece(tCase, "|", 2) _ " in a namespace that runs no interoperability is refused")
    }
}

/// <p>An action key the endpoint does not serve is 501 <code>PORT.NOTIMPLEMENTED</code>, whatever the read type: a job read composed for a
/// queue abort, a queue read composed for a job stop, and a key that is no write at all. The check comes before any vendor class is called.</p>
/// <p>Mutation (Rule 19): drop the 501 refusal from <method>OcuPilot.Port.InteropPort.InvokeTyped</method> (the port and its descendants
/// recompiled) -- this goes red.</p>
Method TestAnActionKeyTheEndpointDoesNotServeIsNotImplemented()
{
    Set tCases = $ListBuild("Jobs|JOB|ABORTQUEUE", "Jobs|JOB|LIST", "Queues|QUEUE|STOPJOB", "QueueItems|ENTRY|ABORTJOB")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = "1"
        Set tQuery("action") = $Piece(tCase, "|", 3)
        Set tSC = $ClassMethod(..#PORT, "Invoke", $Piece(tCase, "|", 1), $Piece(tCase, "|", 2), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "501 PORT.NOTIMPLEMENTED", $Piece(tCase, "|", 2) _ " composed for " _ $Piece(tCase, "|", 3) _ " is not implemented")
    }
}

/// <p>The queue abort's write is given the digest its proposal was reviewed with: the composer the confirm and the screen action ask
/// (<method>OcuPilot.Kernel.Proposal.Operation.Query</method>) puts the stored payload's <code>Digest</code> under
/// <parameter>OcuPilot.Port.InteropPort.DIGESTKEY</parameter>, and a payload with none adds none (a person's call carries none). The
/// read answers that field.</p>
/// <p>Mutation (Rule 19): delete the line of <method>OcuPilot.Screen.Tool.InteropQueueAbort.PortQuery</method> that sets the digest key --
/// the first leg goes red.</p>
Method TestTheQueueAbortWriteIsGivenTheReviewedDigest()
{
    Set tTool = "OcuPilot.Screen.Tool.InteropQueueAbort"
    Set tIdKey = $Parameter(..#PORT, "IDKEY")
    Set tDigestKey = $Parameter(..#PORT, "DIGESTKEY")
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tTool, tIdKey, "q", {"Name": "q", "Entries": 2, "Digest": "abc123"}.%ToJSON(), .tQuery)
    Do $$$AssertEquals($Get(tQuery(tDigestKey)) _ "|" _ $Get(tQuery(tIdKey)), "abc123|q", "the reviewed digest is sent with the queue's name")
    Kill tQuery
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tTool, tIdKey, "q", {"Name": "q"}.%ToJSON(), .tQuery)
    Do $$$AssertEquals($Data(tQuery(tDigestKey)), 0, "a payload carrying no digest sends none")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter(tTool, "READANSWERS")), "Digest") > 0, "and the read answers the digest the payload keeps")
}

/// <p>The port's pairs for each type: the endpoint's two, then the type's own pair after them, and the reads add none.</p>
/// <p>Mutation (Rule 19): give <code>SUSPENDJOB</code> <parameter>JOBWRITEPAIR</parameter> in <method>OcuPilot.Port.InteropPort.Pairs</method>
/// -- this goes red.</p>
Method TestThePortsPairsAddTheTypesOwnPair()
{
    For tCase = $ListBuild("Queues", "LIST", "%Ens_Portal:USE,%Ens_Queues:READ"), $ListBuild("Queues", "QUEUE", "%Ens_Portal:USE,%Ens_Queues:READ"), $ListBuild("Queues", "ABORTQUEUE", "%Ens_Portal:USE,%Ens_Queues:READ,%Ens_Queues:WRITE"),
        $ListBuild("QueueItems", "ENTRY", "%Ens_Portal:USE,%Ens_Queues:READ"), $ListBuild("QueueItems", "ABORTMESSAGE", "%Ens_Portal:USE,%Ens_Queues:READ,%Ens_Queues:WRITE"),
        $ListBuild("Jobs", "JOB", "%Ens_Portal:USE,%Ens_Jobs:READ"), $ListBuild("Jobs", "ABORTJOB", "%Ens_Portal:USE,%Ens_Jobs:READ,%Ens_Jobs:WRITE"), $ListBuild("Jobs", "SUSPENDJOB", "%Ens_Portal:USE,%Ens_Jobs:READ,%Ens_MessageSuspend:USE"), $ListBuild("Jobs", "STOPJOB", "%Ens_Portal:USE,%Ens_Jobs:READ,%Ens_Jobs:WRITE") {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", $List(tCase, 1), $List(tCase, 2))
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Do $$$AssertEquals(tText, $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2))
    }
}

/// <p><method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> over its matrix: an empty queue; a job no process holds, for the
/// three job writes; an abort or suspend of a job that is not retrying (any status but Retry, or no message), a dead job being
/// refused as dead first; a stop that needs no retry; and no refusal for a message abort or a read.</p>
/// <p>Mutation (Rule 19): drop the <code>NOTRETRYING</code> line, then the <code>QUEUEEMPTY</code> line, then the <code>DEAD</code> line
/// from <method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> -- the matching rows go red, and so do the integration legs.</p>
Method TestTheRuntimeRefusalMatrix()
{
    Set tE = ..#ERROR
    ; type, dead, status, active message, entries, expected
    For tCase = $ListBuild("ABORTQUEUE", 0, "", "", 0, $Parameter(tE, "QUEUEEMPTY")), $ListBuild("ABORTQUEUE", 0, "", "", 1, ""), $ListBuild("ABORTQUEUE", 0, "", "", 10000, ""),
        $ListBuild("ABORTJOB", 1, "Retry", "41", 0, $Parameter(tE, "JOBDEAD")), $ListBuild("ABORTJOB", 0, "Retry", "41", 0, ""), $ListBuild("ABORTJOB", 0, "OK", "41", 0, $Parameter(tE, "JOBNOTRETRYING")), $ListBuild("ABORTJOB", 0, "Retry", "", 0, $Parameter(tE, "JOBNOTRETRYING")), $ListBuild("ABORTJOB", 0, "", "", 0, $Parameter(tE, "JOBNOTRETRYING")), $ListBuild("ABORTJOB", 1, "OK", "", 0, $Parameter(tE, "JOBDEAD")),
        $ListBuild("SUSPENDJOB", 1, "Retry", "41", 0, $Parameter(tE, "JOBDEAD")), $ListBuild("SUSPENDJOB", 0, "Retry", "41", 0, ""), $ListBuild("SUSPENDJOB", 0, "OK", "41", 0, $Parameter(tE, "JOBNOTRETRYING")), $ListBuild("SUSPENDJOB", 0, "Retry", "", 0, $Parameter(tE, "JOBNOTRETRYING")),
        $ListBuild("STOPJOB", 1, "OK", "", 0, $Parameter(tE, "JOBDEAD")), $ListBuild("STOPJOB", 0, "OK", "", 0, ""), $ListBuild("STOPJOB", 0, "Retry", "41", 0, ""), $ListBuild("STOPJOB", 0, "", "", 0, ""),
        $ListBuild("ABORTMESSAGE", 1, "OK", "", 0, ""), $ListBuild("QUEUE", 0, "", "", 0, ""), $ListBuild("JOB", 1, "OK", "", 0, "") {
        Set tCode = $ClassMethod(..#PORT, "RuntimeRefusal", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), $List(tCase, 5))
        Do $$$AssertEquals(tCode, $List(tCase, 6), $List(tCase, 1) _ " (dead " _ $List(tCase, 2) _ ", status '" _ $List(tCase, 3) _ "', message '" _ $List(tCase, 4) _ "', entries " _ $List(tCase, 5) _ ")")
    }
    Set tRow = {"Dead": true, "Status": "Retry", "ActiveMessage": "41", "Entries": 0}
    Do $$$AssertEquals($ClassMethod(..#PORT, "RowRefusal", "ABORTJOB", tRow), $Parameter(tE, "JOBDEAD"), "RowRefusal reads the fields of a row")
    Do $$$AssertEquals($ClassMethod(..#PORT, "RowRefusal", "ABORTQUEUE", {"Entries": 0}), $Parameter(tE, "QUEUEEMPTY"), "and an entry count of a queue row")
    Do $$$AssertEquals($ClassMethod(..#PORT, "RowRefusal", "ABORTQUEUE", ""), "", "and no row refuses nothing")
}

/// <p><method>OcuPilot.Port.InteropPort.QueueDigest</method> is a lower-case SHA-256 hex over the ordered
/// <code>priority:index:messageId</code> lines: the same entries in the same order give the same digest, another order, another
/// message and another index each give another, and no entry gives the digest of the empty text.</p>
/// <p>Mutation (Rule 19): sort the entries inside <method>OcuPilot.Port.InteropPort.QueueDigest</method> -- the order leg goes red.</p>
Method TestTheQueueDigestFollowsTheOrderedEntries()
{
    Set tA(1) = $ListBuild(6, 1, "10")
    Set tA(2) = $ListBuild(6, 2, "11")
    Set tA = 2
    Set tB(1) = $ListBuild(6, 2, "11")
    Set tB(2) = $ListBuild(6, 1, "10")
    Set tB = 2
    Set tC(1) = $ListBuild(6, 1, "10")
    Set tC(2) = $ListBuild(6, 2, "12")
    Set tC = 2
    Set tD(1) = $ListBuild(6, 1, "10")
    Set tD(2) = $ListBuild(6, 3, "11")
    Set tD = 2
    Set tCopy(1) = $ListBuild(6, 1, "10", "extra", "fields")
    Set tCopy(2) = $ListBuild(6, 2, "11")
    Set tCopy = 2
    Set tDigest = $ClassMethod(..#PORT, "QueueDigest", .tA)
    Do $$$AssertTrue($Match(tDigest, "^[0-9a-f]{64}$"), "a lower-case SHA-256 hex: " _ tDigest)
    Do $$$AssertEquals($ClassMethod(..#PORT, "QueueDigest", .tCopy), tDigest, "the same entries give the same digest, whatever else their elements carry")
    Do $$$AssertNotEquals($ClassMethod(..#PORT, "QueueDigest", .tB), tDigest, "the same entries in another order give another")
    Do $$$AssertNotEquals($ClassMethod(..#PORT, "QueueDigest", .tC), tDigest, "another message gives another")
    Do $$$AssertNotEquals($ClassMethod(..#PORT, "QueueDigest", .tD), tDigest, "and another index")
    Kill tNone
    Set tNone = 0
    Do $$$AssertEquals($ClassMethod(..#PORT, "QueueDigest", .tNone), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "no entry gives the digest of the empty text")
}

/// <p>Every new code resolves to its sentence through <method>OcuPilot.Api.InteropError.ReasonFor</method> and through
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>, is listed in <code>Codes</code> (the five refusals, through
/// <code>RuntimeCodes</code>) or <code>ConsequenceCodes</code> (the five consequences), and the abort-all sentence states
/// <parameter>OcuPilot.Port.InteropPort.ABORTMAX</parameter>.</p>
/// <p>Mutation (Rule 19): drop <code>INTEROP.JOB.DEAD</code> from <method>OcuPilot.Api.InteropError.ReasonFor</method> -- the dead-job row
/// goes red.</p>
Method TestEveryNewCodeResolvesToItsSentence()
{
    Set tE = ..#ERROR
    For tName = "QUEUEEMPTY", "QUEUECHANGED", "JOBDEAD", "JOBNOTRETRYING", "JOBNOTSTOPPED", "MESSAGEABORT", "QUEUEABORT", "JOBABORT", "JOBSUSPEND", "JOBSTOP" {
        Set tCode = $Parameter(tE, tName)
        Set tReason = $Parameter(tE, "REASON" _ tName)
        Do $$$AssertTrue((tCode [ "INTEROP.") && (tReason '= ""), tName _ ": a code and a sentence")
        Do $$$AssertEquals($ClassMethod(tE, "ReasonFor", tCode), tReason, tCode _ ": ReasonFor answers the sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": ReasonForViolation answers it too")
        Do $$$AssertTrue('$Find($ZConvert(tReason, "L"), "agent"), tCode _ ": the sentence names no caller")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(tE, "RuntimeCodes")), "INTEROP.QUEUE.EMPTY,INTEROP.QUEUE.CHANGED,INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.JOB.NOTSTOPPED", "RuntimeCodes names the five refusals")
    Do $$$AssertTrue($ListFind($ClassMethod(tE, "Codes"), "INTEROP.QUEUE.CHANGED") && $ListFind($ClassMethod(tE, "Codes"), "INTEROP.JOB.NOTSTOPPED"), "Codes lists them")
    Do $$$AssertTrue($ListFind($ClassMethod(tE, "ConsequenceCodes"), "INTEROP.MESSAGE.ABORT") && $ListFind($ClassMethod(tE, "ConsequenceCodes"), "INTEROP.JOB.STOP"), "ConsequenceCodes lists the five consequences")
    Do $$$AssertTrue($ListFind($ClassMethod(tE, "ConsequenceCodes"), "INTEROP.QUEUE.EMPTY") = 0, "and none of the refusals")
    Do $$$AssertTrue($Parameter(tE, "REASONQUEUEABORT") [ ("up to the first " _ $FNumber($Parameter(..#PORT, "ABORTMAX"), ",") _ ","), "the abort-all sentence states ABORTMAX")
}

/// <p>The copy-out script of each write (AD-59): the port gives each one an <code>objectscript</code> form; the script switches to the
/// namespace the query names, renders the reviewed values as string literals, calls the vendor's own method, opens no block it does
/// not close on the same line, and names neither <code>AbortQueue</code> nor <code>Enumerate</code>; a stop caps the production's
/// timeout at <parameter>OcuPilot.Port.InteropPort.STOPSECONDS</parameter> and forces; and a read has no form.</p>
/// <p>Mutation (Rule 19): pass <code>0</code> for the force argument in the stop branch of <method>OcuPilot.Port.InteropPort.RuntimeSnippet</method>
/// -- the stop row goes red.</p>
Method TestEachWritesScriptRendersItsVendorCall()
{
    Set tContext = {"payload": {"Queue": "OcuPilotProbeOp", "Priority": 6, "Index": 2, "Namespace": "USER"}}
    For tCase = $ListBuild("QueueItems", "ABORTMESSAGE", "131", "Ens.Queue).AbortItem(""OcuPilotProbeOp"", ""6"", ""2"")"), $ListBuild("Queues", "ABORTQUEUE", "OcuPilotProbeOp", "Ens.Queue:EnumerateItem"), $ListBuild("Jobs", "ABORTJOB", "4242", "Ens.Job).AbortOperation(""4242"")"), $ListBuild("Jobs", "SUSPENDJOB", "4242", "Ens.Job).SuspendOperation(""4242"")"), $ListBuild("Jobs", "STOPJOB", "4242", "Ens.Job).Stop(""4242"", tTimeout, 1)") {
        Set tEndpoint = $List(tCase, 1)
        Set tType = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", tEndpoint, tType), "objectscript", tType _ " has an ObjectScript form")
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = $List(tCase, 3)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", tEndpoint, tType, .tQuery, "", tContext)
        Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", tType _ ": one ObjectScript step")
        Set tText = tSteps.%Get(0).text
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 4)), tType _ ": it switches to the namespace and calls the vendor: " _ tText)
        Do $$$AssertTrue((tText '[ "AbortQueue") && (tText '[ "Enumerate()"), tType _ ": it calls neither AbortQueue nor Enumerate")
        Set tOpen = 0
        For tLine = 1:1:$Length(tText, $Char(10)) {
            Set tOne = $Piece(tText, $Char(10), tLine)
            If $Length(tOne, "{") '= $Length(tOne, "}") Set tOpen = 1
        }
        Do $$$AssertEquals(tOpen, 0, tType _ ": no line opens a block it does not close")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "4242"
    Set tStopSteps = $ClassMethod(..#PORT, "Snippet", "Jobs", "STOPJOB", .tQuery, "", tContext)
    Set tText = tStopSteps.%Get(0).text
    Do $$$AssertTrue((tText [ ("If tTimeout > " _ $Parameter(..#PORT, "STOPSECONDS") _ " Set tTimeout = " _ $Parameter(..#PORT, "STOPSECONDS"))) && (tText [ "GetRunningProductionUpdateTimeout()"), "a stop's script caps the production's timeout")
    Set tQuery("id") = "o""ne" _ $Char(9) _ "queue"
    Set tQuoteSteps = $ClassMethod(..#PORT, "Snippet", "Queues", "ABORTQUEUE", .tQuery, "", tContext)
    Set tText = tQuoteSteps.%Get(0).text
    Do $$$AssertTrue(tText [ "Execute(""o""""ne""_$Char(9)_""queue"")", "a queue name with a quote and a tab is rendered as a literal, not as code: " _ tText)
    For tType = "LIST", "QUEUE", "ENTRY", "JOB" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Queues", tType), "", tType _ " has no script form")
    }
}

/// <p>Where the shared members live (Rule 31): the job tools' three leaves hold none of the shared methods or parameters, which
/// <class>OcuPilot.Screen.Tool.InteropJobAction</class> holds once, and every tool extends
/// <class>OcuPilot.Screen.Tool.InteropAction</class>.</p>
/// <p>Mutation (Rule 19): copy <code>StateDiff</code> into <class>OcuPilot.Screen.Tool.InteropJobStop</class> -- this goes red.</p>
Method TestTheJobToolsShareOneBase()
{
    Set tBase = "OcuPilot.Screen.Tool.InteropJobAction"
    For tMethod = 1:1:$Length(..#SHAREDMETHODS, ",") {
        Set tName = $Piece(..#SHAREDMETHODS, ",", tMethod)
        Do $$$AssertTrue(##class(%Dictionary.MethodDefinition).%ExistsId(tBase _ "||" _ tName), tBase _ " holds " _ tName)
        For tLeaf = "InteropJobAbort", "InteropJobSuspend", "InteropJobStop" {
            Do $$$AssertEquals(##class(%Dictionary.MethodDefinition).%ExistsId("OcuPilot.Screen.Tool." _ tLeaf _ "||" _ tName), 0, tLeaf _ " does not repeat " _ tName)
        }
    }
    For tParameter = 1:1:$Length(..#SHAREDPARAMETERS, ",") {
        Set tName = $Piece(..#SHAREDPARAMETERS, ",", tParameter)
        Do $$$AssertTrue(##class(%Dictionary.ParameterDefinition).%ExistsId(tBase _ "||" _ tName), tBase _ " declares " _ tName)
        For tLeaf = "InteropJobAbort", "InteropJobSuspend", "InteropJobStop" {
            Do $$$AssertEquals(##class(%Dictionary.ParameterDefinition).%ExistsId("OcuPilot.Screen.Tool." _ tLeaf _ "||" _ tName), 0, tLeaf _ " does not redeclare " _ tName)
        }
    }
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece($Piece(..#TOOLS, ";", tI), "|", 1)
        Do $$$AssertTrue($ClassMethod(tTool, "%Extends", "OcuPilot.Screen.Tool.InteropAction"), tTool _ " extends the Interoperability action base")
    }
    For tLeaf = "InteropJobAbort", "InteropJobSuspend", "InteropJobStop" {
        Do $$$AssertTrue($ClassMethod("OcuPilot.Screen.Tool." _ tLeaf, "%Extends", tBase), tLeaf _ " extends the job base")
    }
}

/// <p>Each tool resolves through the tool registry by its name as an advertised write answered by its own class; the three entity
/// types the targets name are in the closed vocabulary and covered by the prohibited set.</p>
Method TestEachToolIsRegisteredAndItsTargetTypeIsCovered()
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Piece(tRow, "|", 2), .tTool)
        Do $$$AssertStatusOK(tSC, $Piece(tRow, "|", 2) _ " resolves")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.kind _ "|" _ tTool.class _ "|" _ tTool.advertised, "write|OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1) _ "|1", $Piece(tRow, "|", 2) _ " is an advertised write, answered by its class")
    }
    For tType = "interop-queue", "interop-message", "interop-job" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tType), tType _ " is a declared entity type")
        Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), tType) > 0, tType _ " is covered by the prohibited set")
    }
}

/// <p>The declared half of <parameter>DECLARED</parameter> for <var>pClass</var>.</p>
ClassMethod DeclaredFor(pClass As %String) As %String
{
    For tI = 1:1:$Length(..#DECLARED, ";") {
        If $Piece($Piece(..#DECLARED, ";", tI), "|", 1) = pClass Quit
    }
    Quit $Piece(..#DECLARED, ";", tI)
}

/// <p>The answers of the port's boolean method <var>pMethod</var> for each type in <var>pTypes</var>, comma-separated.</p>
ClassMethod Text(pTypes As %List, pMethod As %String) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pTypes) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ (''$ClassMethod(..#PORT, pMethod, $List(pTypes, tI)))
    }
    Quit tText
}

}
