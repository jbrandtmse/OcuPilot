/// <p>Pins Story 16.6's broadcast against real terminal sessions (AD-8, AD-10, AD-15, AD-51, AD-53):
/// the Processes read reporting a receiver checkable and a <code>JOB</code>ed process not, the
/// screen's Broadcast reaching two receivers once each, a set holding a <code>JOB</code>ed or an ended
/// pid refused whole with nothing delivered, a principal holding the screen's three pairs
/// broadcasting, the agent's mint naming the count and its confirm delivering the message with
/// the marker, the screen refusing a bad set and a bad message, and a confirm after a recipient
/// ended refused as a moved target.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s test account, the test session holding
/// <code>%System_CallOut:USE</code> to start receivers with <code>$ZF(-100)</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes
/// one user and one role. Every message it sends goes to a terminal session it started itself
/// (<method>Receiver</method>); each test ends every process it started and deletes their output
/// files.</p>
Class OcuPilot.Test.ProcessBroadcastLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter TOOL = "OcuPilot.Screen.Tool.ProcessBroadcast";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The global a receiver records its own process id under while it waits, with the tag its
/// starter gave it as the node's value.</p>
Parameter RECEIVERGLOBAL = "^OcuPilotTestBroadcast";

/// <p>How long a receiver waits, in seconds, if nothing ends it first.</p>
Parameter RECEIVERSECONDS = 60;

/// <p>A pid no process on this build carries.</p>
Parameter ABSENTPID = 999999999;

/// <p>The purpose-built principal holding the install namespace's code read and the Processes
/// screen's three pairs, and nothing else.</p>
Parameter PAIRSUSER = "OcuPilotBroadcastPairs";

Parameter PAIRSROLE = "OcuPilotBroadcastPairsRole";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The pids this test started, each with its output file, as <code>$ListBuild(pid, file)</code>
/// entries; its teardown ends every one and deletes every file.</p>
Property PreparedStarted As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedStarted = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessBroadcastLive creates and deletes a user and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotBcst" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipal()
}

/// <p>Remove the principal and its role; a failing status when either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PAIRSUSER) Do ##class(Security.Users).Delete(..#PAIRSUSER)
        If ##class(Security.Roles).Exists(..#PAIRSROLE) Do ##class(Security.Roles).Delete(..#PAIRSROLE)
        If ##class(Security.Users).Exists(..#PAIRSUSER) || ##class(Security.Roles).Exists(..#PAIRSROLE) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessBroadcastLive left a throwaway principal on the instance")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedStarted = ""
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>End every process this test started and delete its output files, then assert none is still
/// running.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$ListLength(..PreparedStarted) {
        Set tEntry = $List(..PreparedStarted, tI)
        Set tPid = $List(tEntry, 1)
        Set tFile = $List(tEntry, 2)
        If tPid '= "" Do $SYSTEM.Process.Terminate(tPid)
        If tPid '= "" Kill @..#RECEIVERGLOBAL@(tPid)
        If tFile '= "" {
            Do ##class(%File).Delete(tFile)
            Do ##class(%File).Delete(tFile _ ".err")
        }
    }
    Hang 0.5
    For tI = 1:1:$ListLength(..PreparedStarted) {
        Set tPid = $List($List(..PreparedStarted, tI), 1)
        If tPid '= "" Do $$$AssertTrue('..Running(tPid), "process " _ tPid _ " this test started has ended")
    }
    Set ..PreparedStarted = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>A terminal session that waits: it records <code>$Job</code> under
/// <parameter>RECEIVERGLOBAL</parameter> with <var>pTag</var> as the node's value, which is how its
/// starter finds its pid (<method>PidTagged</method>), and hangs for <var>pSeconds</var>. It writes
/// nothing, so its output holds only what is broadcast to it.</p>
ClassMethod Receiver(pSeconds As %Integer = 60, pTag As %String = "")
{
    Set @..#RECEIVERGLOBAL@($Job) = pTag
    Hang pSeconds
    Kill @..#RECEIVERGLOBAL@($Job)
}

/// <p>AC1, AD-24: the Processes read reports a receiver's <code>CanReceiveBroadcast</code> true and
/// a <code>JOB</code>ed process's false, so only the receiver's row is checkable.</p>
Method TestTheReadReportsAReceiverAndNotAJobbedProcess()
{
    Do $$$AssertStatusOK(..Start(.tReceiver, .tFile), "a receiver starts")
    Do $$$AssertStatusOK(..StartJob(.tJobbed), "and a JOBed process")
    If (tReceiver = "") || (tJobbed = "") Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.processes/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the Processes read answers")
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tBody = "" }
    If '$IsObject(tBody) Quit
    Kill tFlag
    Set tIterator = tBody.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFlag(tRow.%Get("Pid")) = tRow.%GetTypeOf("CanReceiveBroadcast") _ ":" _ tRow.%Get("CanReceiveBroadcast")
    }
    Do $$$AssertEquals($Get(tFlag(tReceiver)), "boolean:1", "the receiver's row reads CanReceiveBroadcast true")
    Do $$$AssertEquals($Get(tFlag(tJobbed)), "boolean:0", "and the JOBed process's reads false")
}

/// <p>AC1, AD-53: the screen's Broadcast over two checked receivers answers 200 with the canonical
/// set as its target, and each receiver's terminal shows the message once.</p>
/// <p>Mutation (Rule 19): drop the last member from
/// <method>OcuPilot.Port.ProcessPort.BroadcastBody</method>'s <code>PidList</code> -- the second
/// receiver sees nothing and goes red.</p>
Method TestTheScreenActionSendsToTwoReceivers()
{
    Do $$$AssertStatusOK(..Start(.tFirst, .tFirstFile), "a first receiver starts")
    Do $$$AssertStatusOK(..Start(.tSecond, .tSecondFile), "and a second")
    If (tFirst = "") || (tSecond = "") Quit
    Set tToken = ..Token()
    Set tSC = ..Act(tSecond _ ", " _ tFirst, tToken, "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the Broadcast answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    If $IsObject(tBody) Do $$$AssertEquals(tBody.%Get("target").%Get("id"), ##class(OcuPilot.Kernel.EntityRef).NormalizedId("process", tFirst _ "," _ tSecond), "naming the canonical set")
    Do $$$AssertEquals(..Delivered(tFirstFile, tToken, 5), 1, "the first receiver shows the message once")
    Do $$$AssertEquals(..Delivered(tSecondFile, tToken, 5), 1, "and so does the second")
}

/// <p>AC3: a set holding a <code>JOB</code>ed pid, or a pid no process carries, is refused 409
/// <code>PROCESS.BROADCAST.RECIPIENT</code> with the published sentence, and the receiver in the same
/// set is sent nothing.</p>
/// <p>Mutation (Rule 19): skip the recipient re-check in
/// <method>OcuPilot.Port.ProcessPort.Invoke</method> -- the vendor sends to the receiver and both legs
/// go red.</p>
Method TestASetHoldingAnIneligiblePidSendsNothing()
{
    Do $$$AssertStatusOK(..Start(.tReceiver, .tFile), "a receiver starts")
    Do $$$AssertStatusOK(..StartJob(.tJobbed), "and a JOBed process")
    If (tReceiver = "") || (tJobbed = "") Quit
    For tOther = tJobbed, ..#ABSENTPID {
        Set tToken = ..Token()
        Set tSC = ..Act(tReceiver _ "," _ tOther, tToken, "", "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ $Select($IsObject(tBody): tBody.%Get("reason"), 1: ""), "409 " _ ##class(OcuPilot.Api.Error).#PROCESSBROADCASTRECIPIENT _ " " _ ##class(OcuPilot.Api.Error).#REASONPROCESSBROADCASTRECIPIENT, "a set with " _ $Select(tOther = tJobbed: "a JOBed", 1: "an ended") _ " pid is refused with the published sentence")
        Do $$$AssertEquals(..Delivered(tFile, tToken, 2), 0, "and the receiver is sent nothing")
    }
}

/// <p>AD-8, AD-29: a principal holding the screen's three pairs and nothing else broadcasts to a
/// receiver.</p>
Method TestAThreePairsPrincipalBroadcasts()
{
    Do $$$AssertStatusOK(..Start(.tReceiver, .tFile), "a receiver starts")
    If tReceiver = "" Quit
    Set tToken = ..Token()
    Set tSC = ..Act(tReceiver, tToken, ..#PAIRSUSER, ..PreparedPassword, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the three-pair principal's Broadcast answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertEquals(..Delivered(tFile, tToken, 5), 1, "and the receiver shows the message")
}

/// <p>AC1, AD-15: the agent's mint names the canonical set, the message and the count, and its
/// confirm delivers the message once to each receiver and lands the agent marker.</p>
Method TestTheAgentsConfirmDeliversWithTheMarker()
{
    Do $$$AssertStatusOK(..Start(.tFirst, .tFirstFile), "a first receiver starts")
    Do $$$AssertStatusOK(..Start(.tSecond, .tSecondFile), "and a second")
    If (tFirst = "") || (tSecond = "") Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tToken = ..Token()
    Set tIds = tSecond _ ", " _ tFirst
    Set tArgs = {}
    Do tArgs.%Set("Pids", tIds, "string")
    Do tArgs.%Set("Message", tToken, "string")
    Set tSC = $ClassMethod($ClassMethod(..#TOOL, "MintClass"), "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), tIds, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the broadcast mints: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tCanonical = ##class(OcuPilot.Kernel.EntityRef).NormalizedId("process", tIds)
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), tCanonical, "the target is the canonical set")
    Kill tRow
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChange) { Set tRow(tChange.%Get("field")) = tChange.%Get("after") }
    Do $$$AssertEquals($Get(tRow("Message")), tToken, "the card carries the message")
    Do $$$AssertEquals($Get(tRow("Recipients")), "2 processes: " _ $Replace(tCanonical, ",", ", "), "and names the count and the pids")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm sends it: " _ $Get(tCode))
    Do $$$AssertEquals(..Delivered(tFirstFile, tToken, 5), 1, "the first receiver shows the message once")
    Do $$$AssertEquals(..Delivered(tSecondFile, tToken, 5), 1, "and so does the second")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurn, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC4 and the bad-set row at the screen's route: a set that is not process ids, a zero and
/// twenty-one pids are 400 <code>PORT.VALIDATION</code>, and a message holding a tab is 400
/// <code>TOOL.ARGUMENTS</code> with the receiver sent nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>\p{Cc}</code> check from
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.MessageProblem</method> -- the tab is delivered and
/// the message leg goes red.</p>
Method TestTheScreenRefusesABadSetAndABadMessage()
{
    Do $$$AssertStatusOK(..Start(.tReceiver, .tFile), "a receiver starts")
    If tReceiver = "" Quit
    Set tTwentyOne = ""
    For tI = 1:1:21 Set tTwentyOne = tTwentyOne _ $Select(tI = 1: "", 1: ",") _ (tReceiver + tI)
    For tBad = "abc", "0", tTwentyOne {
        Set tSC = ..Act(tBad, ..Token(), "", "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION, "the set '" _ tBad _ "' is refused")
    }
    ; The vendor frames what it is given, so a delivered tab would read ***<token><TAB>x***.
    Set tMessage = ..Token() _ $Char(9) _ "x"
    Set tSC = ..Act(tReceiver, tMessage, "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "a message holding a tab is refused")
    Do $$$AssertEquals(..Delivered(tFile, tMessage, 2), 0, "and the receiver is sent nothing")
}

/// <p>The moved row, AD-6: a recipient that ends between the agent's mint and its confirm refuses the
/// confirm with <code>PROPOSAL.TARGETCHANGED</code>, and the recipient still running is sent
/// nothing.</p>
Method TestAConfirmAfterARecipientEndedIsRefused()
{
    Do $$$AssertStatusOK(..Start(.tFirst, .tFirstFile), "a first receiver starts")
    Do $$$AssertStatusOK(..Start(.tSecond, .tSecondFile), "and a second")
    If (tFirst = "") || (tSecond = "") Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tToken = ..Token()
    Set tIds = tFirst _ "," _ tSecond
    Set tArgs = {}
    Do tArgs.%Set("Pids", tIds, "string")
    Do tArgs.%Set("Message", tToken, "string")
    Set tSC = $ClassMethod($ClassMethod(..#TOOL, "MintClass"), "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), tIds, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the broadcast mints")
    If $$$ISERR(tSC) Quit
    Do $SYSTEM.Process.Terminate(tSecond)
    For tTry = 1:1:50 {
        If '..Running(tSecond) Quit
        Hang 0.1
    }
    Do $$$AssertTrue('..Running(tSecond), "the second receiver has ended")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target")
    Do $$$AssertEquals(..Delivered(tFirstFile, tToken, 2), 0, "and the receiver still running is sent nothing")
}

/// <p>Start one receiver as its own terminal session, through <code>$ZF(-100)</code>, and answer
/// its pid once it has recorded it, with the file its output goes to.</p>
Method Start(Output pPid As %String, Output pFile As %String) As %Status
{
    Set pPid = ""
    Set pFile = ##class(%File).TempFilename("out")
    Set ..PreparedStarted = ..PreparedStarted _ $ListBuild($ListBuild("", pFile))
    ; This job and the millisecond of the day: no two receivers this class starts share a tag.
    Set tTag = ($Job * 100000000) + ($Piece($ZTimeStamp, ",", 2) * 1000 \ 1)
    Set tRC = $ZF(-100, "/ASYNC /STDOUT=""" _ pFile _ """ /STDERR=""" _ pFile _ ".err""", $System.Util.BinaryDirectory() _ "iris", "session", ##class(%SYS.System).GetInstanceName(), "-U", $NAMESPACE, "##class(" _ $ClassName() _ ").Receiver(" _ ..#RECEIVERSECONDS _ "," _ tTag _ ")")
    If tRC '= 0 Quit $$$ERROR($$$GeneralError, "the receiver could not be started: " _ tRC)
    For tTry = 1:1:100 {
        Set pPid = ..PidTagged(tTag)
        If pPid '= "" Quit
        Hang 0.1
    }
    If pPid = "" Quit $$$ERROR($$$GeneralError, "the receiver recorded no pid")
    Set ..PreparedStarted = $List(..PreparedStarted, 1, *-1) _ $ListBuild($ListBuild(pPid, pFile))
    Quit $$$OK
}

/// <p>Start one <code>JOB</code>ed process, which no broadcast can reach, and answer its pid.</p>
Method StartJob(Output pPid As %String) As %Status
{
    Set pPid = ""
    Job ##class(OcuPilot.Test.ProcessBroadcastLive).Receiver(..#RECEIVERSECONDS)::5
    If '$Test Quit $$$ERROR($$$GeneralError, "the JOBed process did not start")
    Set pPid = $ZChild
    Set ..PreparedStarted = ..PreparedStarted _ $ListBuild($ListBuild(pPid, ""))
    Quit $$$OK
}

/// <p>How many times <var>pFile</var> shows <var>pToken</var> framed as a broadcast, once the text
/// has arrived or <var>pSeconds</var> have passed.</p>
Method Delivered(pFile As %String, pToken As %String, pSeconds As %Numeric) As %Integer
{
    Set tNeedle = "***" _ pToken _ "***"
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Set tCount = $Length(..FileText(pFile), tNeedle) - 1
        If (tCount > 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.1
    }
    ; Give a second delivery the vendor's own few milliseconds to land before counting.
    If tCount > 0 Hang 0.5
    Quit $Length(..FileText(pFile), tNeedle) - 1
}

/// <p>The pid of the receiver whose node under <parameter>RECEIVERGLOBAL</parameter> holds
/// <var>pTag</var>, or <code>""</code>.</p>
ClassMethod PidTagged(pTag As %String) As %String
{
    Set tPid = ""
    For {
        Set tPid = $Order(@..#RECEIVERGLOBAL@(tPid), 1, tValue)
        If (tPid = "") || (tValue = pTag) Quit
    }
    Quit tPid
}

/// <p>What <var>pFile</var> holds now, or <code>""</code>.</p>
ClassMethod FileText(pFile As %String) As %String
{
    If '##class(%File).Exists(pFile) Quit ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(pFile)) Quit ""
    Set tText = tStream.Read(100000)
    Set tStream = ""
    Quit tText
}

/// <p>Whether a process <var>pPid</var> is running.</p>
ClassMethod Running(pPid As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("id") = pPid
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Quit $$$ISOK(tSC) && $IsObject($Get(tAnswer))
}

/// <p>A message no earlier run sent.</p>
ClassMethod Token() As %String
{
    Quit "OcuBcast" _ $Translate($ZTimeStamp, ",.", "")
}

/// <p>One Broadcast over Processes' screen-action route to the pid set <var>pIds</var> with message
/// <var>pMessage</var>, as <var>pUser</var> or, when it is empty, the test account; the HTTP status
/// and the parsed envelope.</p>
Method Act(pIds As %String, pMessage As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set pPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {"action": "broadcast"}
    Do tRequest.%Set("id", pIds, "string")
    Set tValues = {}
    Do tValues.%Set("Message", pMessage, "string")
    Do tRequest.%Set("values", tValues)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.processes/action", pUser, pPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>Create <parameter>PAIRSUSER</parameter> holding <parameter>PAIRSROLE</parameter>: the Processes
/// screen's three pairs and the install namespace's code database read, then read the grants
/// back.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        If ##class(Security.Users).Exists(..#PAIRSUSER) Do ##class(Security.Users).Delete(..#PAIRSUSER)
        If ##class(Security.Roles).Exists(..#PAIRSROLE) Do ##class(Security.Roles).Delete(..#PAIRSROLE)
        Set tSC = ##class(Security.Roles).Create(..#PAIRSROLE, "OcuPilot test: the broadcast's three pairs (throwaway)", tCode _ ",%Admin_Operate:U,%Admin_Manage:U,%DB_IRISSYS:R", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#PAIRSUSER, ..#PAIRSROLE, ..PreparedPassword, "OcuPilot broadcast test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ProcessBroadcastLive; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#PAIRSUSER, "%Admin_Operate", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PAIRSUSER, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PAIRSUSER, "%DB_IRISSYS", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PAIRSUSER, "%DB_IRISSYS", "WRITE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#PAIRSUSER, "%Admin_Secure", "USE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as declared")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
