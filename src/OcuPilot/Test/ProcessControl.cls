/// <p>Pins Story 5.12's two writes (AD-51, AD-6, AD-10, AD-13, AD-34): the bodyless
/// <code>SUSPEND</code> and <code>RESUME</code>, their diffs taken from the fresh <code>GET</code>,
/// the declared fingerprint subject in both directions, and AD-10's two target predicates.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, <code>%Admin_Operate:USE</code>
/// and <code>%DB_IRISSYS:READ</code>, an account holding <code>%All</code>, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PRINCIPALVARIABLE</parameter> reading
/// <code>1</code>. It suspends a real process and creates one principal, so
/// <method>OnBeforeAllTests</method> refuses anywhere either does not; only
/// <file>scripts/ci-throwaway.sh</file> sets them.</p>
/// <p><b>It acts on one process, and that process is its own.</b>
/// <method>StartProbeProcess</method> <code>JOB</code>s <method>ProbeWait</method>, which signs in
/// as <parameter>PRINCIPALUSER</parameter> and waits; nothing here reads or writes a daemon, the
/// Task Manager, a Work Queue worker or <code>WRTDMN</code>. The probe is resumed and terminated in
/// a frame of its own on every exit path, and <method>OnAfterAllTests</method> asserts that none
/// survives.</p>
Class OcuPilot.Test.ProcessControl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PROCESS_CONTROL";

/// <p>The second variable this class needs: it creates and deletes an IRIS account so the probe
/// process has an owner that is not the confirming user.</p>
Parameter PRINCIPALVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SUSPENDTOOL = "OcuPilot.Screen.Tool.ProcessSuspend";

Parameter RESUMETOOL = "OcuPilot.Screen.Tool.ProcessResume";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>A pid no process carries, so the fixture legs' own reads of the instance answer 404 and the
/// shipped prohibited set is silent about a target it cannot find.</p>
Parameter ABSENTPID = "999999999";

/// <p>The probe process's owner, and a password long and mixed enough for the instance's own
/// policy. The account is created by <method>OnBeforeAllTests</method> and deleted by
/// <method>OnAfterAllTests</method>; nothing about the value needs to be secret.</p>
Parameter PRINCIPALUSER = "OcuPilotProbeProcessOwner";

Parameter PRINCIPALPASSWORD = "OcuPilotPr0beProcessPass9Aa";

/// <p>How long <method>ProbeWait</method> waits before ending itself, so a run that aborted cannot
/// leave a process waiting for ever.</p>
Parameter PROBESECONDS As %Integer = 900;

/// <p>The <code>JobType</code> the instance gives a <code>JOB</code>ed process, measured on
/// <code>ocupilot-ci</code> 2026-09-22: <code>APPMODE</code>, which
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ProcessJobTypes</method> admits. It is the
/// allow-list's non-vacuity floor -- a predicate that refused every kind would redden the legs
/// below rather than read green.</p>
Parameter PROBEJOBTYPE = 2;

/// <p>The Task Manager's and a Work Queue worker's <code>JobType</code>, both of which the vendor
/// reports <code>CanBeSuspended</code> for, and a value <file>%syPidtab.inc</file> names nothing
/// at.</p>
Parameter TASKMANAGERJOBTYPE = 36;

Parameter WORKQUEUEJOBTYPE = 59;

Parameter UNNAMEDJOBTYPE = 9999;

/// <p>The fresh <code>GET</code> answers the fixture port gives. They carry the two subject fields,
/// the two the prohibited set reads, and one counter that is in neither -- which is what makes both
/// directions of the fingerprint measurable.</p>
Parameter FRESHRUNNING = "{""Pid"":999999999,""State"":""RUN"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":1678}";

Parameter FRESHSUSPENDED = "{""Pid"":999999999,""State"":""SUSP"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":1678}";

/// <p>The same running process a moment later: the counter has moved and nothing in the declared
/// subject has.</p>
Parameter FRESHCOUNTERMOVED = "{""Pid"":999999999,""State"":""RUN"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":6004249}";

/// <p>The probe process's pid for this run. Prefix deliberately not "Test" -- see
/// .claude/rules/objectscript-testing.md.</p>
Property PreparedPid As %String;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessControl suspends a real process on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was suspended. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessControl creates and deletes an IRIS account on this instance and runs on a throwaway container only. " _ ..#PRINCIPALVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ..EnsureProbeOwner()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPid = ..StartProbeProcess()
    If ..PreparedPid = "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessControl could not start its own probe process")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ..StopProbeProcess(..PreparedPid)
    Set tResult = $$$OK
    If ..ProcessState(..PreparedPid) '= "" {
        Set tResult = $$$ERROR($$$GeneralError, "OcuPilot.Test.ProcessControl left its probe process running")
    }
    Do ..RemoveProbeOwner()
    Quit tResult
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Report a probe process left suspended as a failure of this teardown rather than of the next
/// method, on the reading taken <b>before</b> anything is repaired.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tBefore = ..ProcessState(..PreparedPid)
    If tBefore [ "SUSP" Do ..ResumeProcess(..PreparedPid)
    Do $$$AssertTrue('(tBefore [ "SUSP"), "the method left its probe process running itself, so this teardown had nothing to repair")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AC1 -- the mint reads the process with the tool's own <code>GET</code>, answers exactly one
/// state row <code>State: Running -&gt; Suspended</code>, carries the tool's own destructive
/// declaration onto the stored row, and discloses nothing as unchanged because nothing will be
/// sent (AD-51).</p>
/// <p>Mutation (Rule 19): drop the <code>StateDiff</code> push in
/// <class>OcuPilot.Screen.Tool.ProcessSuspend</class> -- the one-row assertion goes red. Set that
/// class's <parameter>DESTRUCTIVE</parameter> to <code>1</code> -- the stored-flag assertion goes
/// red, which is what holds the flag to the tool's declaration rather than to the column's
/// default.</p>
Method TestTheMintAnswersOneStateRowFromTheProcessGet()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "GET", "the fresh read is the endpoint's one single-object read")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), ..#ABSENTPID, "keyed by the vendor's own query parameter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing was written by the mint")

    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "the card carries exactly one row")
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals(tRow.%Get("field"), "State", "labelled with the state the action moves")
    Do $$$AssertEquals(tRow.%Get("before"), "Running", "moving from Running")
    Do $$$AssertEquals(tRow.%Get("after"), "Suspended", "to Suspended")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and no field is sent unchanged, because no body is sent at all")

    Set tKey = tProposal.%Get("proposalId")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive"), 0, "the stored row carries the tool's own declaration: a suspend is not destructive")
    Set tStoredSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tStored)
    Do $$$AssertStatusOK(tStoredSC, "the stored row reads back")
    Set tRows = ##class(OcuPilot.Kernel.Proposal.Disclosure).Rows($Parameter(..#SUSPENDTOOL, "TOOLNAME"), $Get(tStored("payload")), $Get(tStored("diff")))
    Do $$$AssertEquals(tRows.%Size(), 0, "and the unchanged-field disclosure is empty")

    ; AD-35: the stored payload is the declared subject and not the 50-key read, so the process's
    ; own variable table is not a payload OcuPilot keeps.
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tStored("payload")))
    Do $$$AssertEquals(tPayload.%Get("CommandsExecuted"), "", "the stored payload carries nothing outside the declared fingerprint subject")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tPayload.%Get("State"), tPayload.%GetTypeOf("State")), "RUN", "and carries the subject's own fields")
}

/// <p>AC2 -- each direction refuses a target that is not in the state its action moves it out of,
/// at the mint, before anything is stored.</p>
/// <p>Mutation (Rule 19): remove the already-suspended arm from
/// <method>OcuPilot.Screen.Tool.ProcessSuspend.StateDiff</method>, or the not-suspended arm from
/// <class>OcuPilot.Screen.Tool.ProcessResume</class>'s -- the matching half goes red.</p>
Method TestEachDirectionRefusesTheWrongStateAtTheMint()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "suspending an already-suspended process is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.%Get("detail").%Get("problem"), 1: "") [ "already suspended", "naming that it is already suspended")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#RESUMETOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "resuming a process that is not suspended is refused, which the vendor's own RunResume does not do")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.%Get("detail").%Get("problem"), 1: "") [ "not suspended", "naming that it is not suspended")

    ; A read that carried no state at all refuses both ways: a process whose state nobody
    ; established is not one to act on.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Pid"":999999999}")
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a read carrying no State is refused by the suspend")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400, not as an internal failure later in the mint")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.%Get("detail").%Get("problem"), 1: "") [ "did not report that process's state", "naming the state it could not read")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Pid"":999999999}")
    Set tSC = ..MintFor(..#RESUMETOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "and by the resume")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400, not as an internal failure later in the mint")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.%Get("detail").%Get("problem"), 1: "") [ "only a suspended process can be resumed", "naming that only a suspended process can be resumed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tBefore, "and no proposal row exists for any of them")
}

/// <p>AC1's write half -- the confirmed write is the vendor's <code>SUSPEND</code>, carrying the
/// <code>id</code> query parameter and <b>no body</b>, and the ledger row names no field.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Confirm.ToolSendsBody</method>
/// answer 1 -- the empty-body assertion goes red and the port receives a payload nobody
/// reviewed.</p>
Method TestTheConfirmedWriteIsABodylessSuspendCarryingTheId()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "one write reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "SUSPEND", "as the vendor's own suspend request type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), ..#ABSENTPID, "carrying the process's id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "and no body at all")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "fields"), "", "so the ledger row records no field name")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-51's declared subject, in <b>both</b> directions: a process whose <code>State</code> moved
/// under the proposal is refused, and one whose <code>CommandsExecuted</code> moved -- a counter
/// outside the subject -- is not. The second half is the whole reason the subject is declared: a
/// digest over the whole read would refuse every confirm against a working process.</p>
/// <p>Mutation (Rule 19): empty
/// <parameter>OcuPilot.Screen.Tool.ProcessSuspend.FINGERPRINTSUBJECT</parameter> -- the
/// counter-moved half goes red, because the digest then covers the counter too.</p>
Method TestTheFingerprintCoversTheDeclaredSubjectAndNothingElse()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")

    ; Somebody else suspended it in the window: a subject field moved.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "with the moved-target code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "the row is closed")

    ; The other direction: the process did what processes do, and the confirm still runs.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tSecond, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "a second proposal mints")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHCOUNTERMOVED)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "a counter moving between the mint and the confirm does not refuse the write (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "and the suspend is issued")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-13, AD-34 -- two spellings of one pid build one target key, so the second proposal is the
/// first's sibling: confirming one cancels the other.</p>
/// <p>Mutation (Rule 19): drop <code>process:integer</code> from
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -- the two keys differ and the sibling
/// cancel leaves the first proposal live.</p>
Method TestTwoSpellingsOfOnePidAreOneTarget()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, "0" _ ..#ABSENTPID, .tFirst, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the first proposal mints from the padded spelling")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPENDTOOL, ..#ABSENTPID, .tSecond, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "and a second from the plain one")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tFirst.%Get("target").%Get("id"), ..#ABSENTPID, "the recorded target is the canonical spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "TargetRef"), ##class(OcuPilot.Test.ProposalFixture).Field(tSecond.%Get("proposalId"), "TargetRef"), "and both rows carry one target reference")

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "confirming one of them succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "and its sibling on the same target is cancelled in the same transition")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-10's <code>process</code> branch: no field of a process is one this release has reviewed,
/// so a proposal carrying any changed field is refused, while the action's own state row -- which
/// changes no field of the payload -- is not.</p>
/// <p><b>The refusing arm is reached by arming the predicate's input</b>, not by replacing the
/// method: both process tools admit no field, so no call through them can carry one.</p>
/// <p>Mutation (Rule 19): remove <code>process</code> from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- both legs are refused
/// <code>UNCOVERED</code>, including the one that should pass.</p>
Method TestAChangedFieldOnAProcessProposalIsRefused()
{
    Do $$$AssertEquals($ListLength($ClassMethod(..#SET, "PermittedChangeFields", "process")), 0, "no field of a process is one this release has reviewed")
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "CoveredTypes"), "process") > 0, "and the type is covered, so a process write is not refused wholesale")

    Set tPid = ..PreparedPid
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tPid, .tRef)
    Do $$$AssertStatusOK(tSC, "the process reference builds")
    If $$$ISERR(tSC) Quit
    Set tFresh = ..FreshRead(tPid)
    Do $$$AssertTrue($IsObject(tFresh), "the probe process reads fresh through the shipped port")
    If '$IsObject(tFresh) Quit

    Set tStateDiff = "[{""field"":""State"",""before"":""Running"",""after"":""Suspended""}]"
    Set tSC = $ClassMethod(..#SET, "Prohibits", $Parameter(..#SUSPENDTOOL, "TOOLNAME"), tRef, tFresh.%ToJSON(), tStateDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the suspend's own shape")
    Do $$$AssertEquals(tProhibits, 0, "which is prohibited by nothing, code was '" _ $Get(tCode) _ "'")

    Set tMoved = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tMoved.%Set("Routine", "OcuPilotProbeMovedRoutine", "string")
    Set tMovedDiff = "[{""field"":""Routine"",""before"":""x"",""after"":""OcuPilotProbeMovedRoutine""}]"
    Set tSC = $ClassMethod(..#SET, "Prohibits", $Parameter(..#SUSPENDTOOL, "TOOLNAME"), tRef, tMoved.%ToJSON(), tMovedDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the armed input")
    Do $$$AssertEquals(tProhibits, 1, "a changed field on a process proposal is refused")
    Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, "UNCOVEREDFIELD"), "as a field nobody has reviewed")
}

/// <p>AC3 as narrowed 2026-09-22 (AD-7, AD-10) -- one predicate, both arms: the job serving the
/// confirmation and the job of a <b>running</b> turn, whoever owns it. A process the confirming
/// user owns which is neither is <b>permitted</b>, which is the half the broad reading refused and
/// the half an administrator suspending their own runaway job depends on.</p>
/// <p>The turn arm is armed at its input -- a running turn row whose <code>JobId</code> is the pid
/// under test and whose owner is another account -- not by replacing the predicate.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotProcess</method> answer 0 -- the three
/// refusing legs go red while the two permitted legs stay green. Drop the
/// <code>State = 'running'</code> clause from
/// <method>OcuPilot.Kernel.State.Turn.GuardedIsTurnJob</method> -- the finished-turn leg goes
/// red.</p>
Method TestOcuPilotsOwnProcessesAreRefusedAndTheUsersOthersAreNot()
{
    Set tOwnJob = {}
    Do tOwnJob.%Set("Pid", $Job, "string")
    Do tOwnJob.%Set("State", "RUN", "string")
    Do tOwnJob.%Set("JobType", ..#PROBEJOBTYPE, "number")
    Do tOwnJob.%Set("UserName", "OcuPilotProbeSomebodyElse", "string")
    Do $$$AssertEquals(..Verdict(tOwnJob), $Parameter(..#SET, "OCUPILOTPROCESS"), "the job serving the confirmation is refused, whoever owns it")

    ; A turn another account is running, in the job whose pid this read carries.
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PRINCIPALUSER, "running", .tRunning, ..#ABSENTPID)
    Do $$$AssertStatusOK(tSC, "a running turn is seeded against that pid")
    If $$$ISERR(tSC) Quit
    Set tTurnJob = {}
    Do tTurnJob.%Set("Pid", ..#ABSENTPID, "string")
    Do tTurnJob.%Set("State", "RUN", "string")
    Do tTurnJob.%Set("JobType", ..#PROBEJOBTYPE, "number")
    Do tTurnJob.%Set("UserName", ..#PRINCIPALUSER, "string")
    Do $$$AssertEquals(..Verdict(tTurnJob), $Parameter(..#SET, "OCUPILOTPROCESS"), "and so is another user's turn job, which $Job alone would miss (DW-1477)")

    ; The same pid once that turn has ended: a pid is reusable, so only a running turn refuses.
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SetTurnState(tRunning, "completed"), "the turn is moved to a terminal state")
    Do $$$AssertEquals(..Verdict(tTurnJob), "", "a finished turn's pid refuses nothing, so a reused pid is not somebody else's turn")

    ; The half the narrowing restores: a live process the confirming user owns, which is neither.
    Set tOwnUser = {}
    Do tOwnUser.%Set("Pid", ..PreparedPid, "string")
    Do tOwnUser.%Set("State", "RUN", "string")
    Do tOwnUser.%Set("JobType", ..#PROBEJOBTYPE, "number")
    Do tOwnUser.%Set("UserName", $Username, "string")
    Do $$$AssertTrue(..PreparedPid '= $Job, "the probe process is not this job, which is what makes the leg below about ownership alone")
    Do $$$AssertEquals(..Verdict(tOwnUser), "", "a process the confirming user owns, which is neither this job nor a turn job, is permitted")

    Set tNoPid = {}
    Do tNoPid.%Set("State", "RUN", "string")
    Do tNoPid.%Set("JobType", ..#PROBEJOBTYPE, "number")
    Do tNoPid.%Set("UserName", ..#PRINCIPALUSER, "string")
    Do $$$AssertEquals(..Verdict(tNoPid), $Parameter(..#SET, "OCUPILOTPROCESS"), "and a read answering no pid fails closed")
}

/// <p>AC4 -- an IRIS system process is refused, by an allow-list over <code>JobType</code> that
/// fails closed on a value <file>%syPidtab.inc</file> does not name. The Task Manager and a Work
/// Queue worker are both refused although the vendor reports them suspendable.</p>
/// <p>Mutation (Rule 19): add <code>36</code> to
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ProcessJobTypes</method> -- the Task Manager leg
/// goes red; empty that list -- the allow-list floor below goes red, which is the direction a
/// predicate that refuses everything would otherwise pass.</p>
Method TestAnIrisSystemProcessIsRefused()
{
    Set tKinds = $ListBuild(..#TASKMANAGERJOBTYPE, ..#WORKQUEUEJOBTYPE, ..#UNNAMEDJOBTYPE)
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        Set tRead = {}
        Do tRead.%Set("Pid", ..#ABSENTPID, "string")
        Do tRead.%Set("State", "RUN", "string")
        Do tRead.%Set("JobType", tKind, "number")
        Do tRead.%Set("UserName", ..#PRINCIPALUSER, "string")
        Do $$$AssertEquals(..Verdict(tRead), $Parameter(..#SET, "SYSTEMPROCESS"), "JobType " _ tKind _ " is refused as an IRIS system process")
    }

    ; A read answering no JobType at all fails closed too.
    Set tNoKind = {}
    Do tNoKind.%Set("Pid", ..#ABSENTPID, "string")
    Do tNoKind.%Set("State", "RUN", "string")
    Do tNoKind.%Set("UserName", ..#PRINCIPALUSER, "string")
    Do $$$AssertEquals(..Verdict(tNoKind), $Parameter(..#SET, "SYSTEMPROCESS"), "and so is a read that answers no JobType")

    ; The allow-list's floor, measured rather than assumed: this instance gives a JOBed process
    ; PROBEJOBTYPE, and the shipped list admits it -- so a predicate refusing every kind could not
    ; read green here.
    Set tActual = ..JobTypeOf(..PreparedPid)
    Do $$$AssertEquals(tActual, ..#PROBEJOBTYPE, "the probe process this class started carries the JobType this instance gives a JOBed process")
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "ProcessJobTypes"), tActual) > 0, "which the allow-list admits, so at least one kind passes it")
    Set tAdmitted = {}
    Do tAdmitted.%Set("Pid", ..#ABSENTPID, "string")
    Do tAdmitted.%Set("State", "RUN", "string")
    Do tAdmitted.%Set("JobType", tActual, "number")
    Do tAdmitted.%Set("UserName", ..#PRINCIPALUSER, "string")
    Do $$$AssertEquals(..Verdict(tAdmitted), "", "and a process of that kind is not refused")
}

/// <p>AC3 as narrowed 2026-09-22 -- the <b>permitted</b> half through the shipped entry point:
/// a live process the confirming user owns, which is neither this job nor a turn job, is not
/// refused by <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>. That is the use the
/// narrowing exists to restore, and the predicate-level leg above cannot see a refusal added
/// elsewhere in the process branch.</p>
/// <p>The target is a second probe process this method starts and stops in its own frame. It does
/// <b>not</b> sign in, so it inherits the confirming user, which the leg reads back from the
/// instance rather than assuming -- a probe owned by anybody else would make the assertion vacuous.
/// Nothing is suspended: the set only reads and answers.</p>
/// <p>Mutation (Rule 19): re-add the ownership arm to
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotProcess</method> (refuse a target whose
/// <code>UserName</code> is <code>$Username</code>) -- this goes red while every refusing leg in
/// the class stays green.</p>
Method TestTheShippedProhibitsPermitsAProcessTheConfirmingUserOwns()
{
    Set tPid = ..StartOwnedProbeProcess()
    Do $$$AssertNotEquals(tPid, "", "a second probe process, started without signing in, is running")
    If tPid = "" Quit
    Try {
        Do $$$AssertEquals(..UserNameOf(tPid), $Username, "the instance reports it as owned by the confirming user, which is what this leg is about")
        Do $$$AssertNotEquals(tPid, $Job, "and it is not this job, so the permitted answer cannot come from that arm")
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedIsTurnJob(tPid, .tTurnJob)
        Do $$$AssertStatusOK(tSC, "the turn-state read answers for it")
        Do $$$AssertEquals(+$Get(tTurnJob), 0, "and no running turn claims that pid, so it is not a turn job either")
        Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "ProcessJobTypes"), ..JobTypeOf(tPid)) > 0, "its JobType is one the allow-list admits, so a refusal here could only be the ownership one")

        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tPid, .tRef)
        Do $$$AssertStatusOK(tSC, "the reference to pid " _ tPid _ " builds")
        If $$$ISERR(tSC) Quit
        Set tFresh = ..FreshRead(tPid)
        Do $$$AssertTrue($IsObject(tFresh), "and it reads fresh through the shipped port")
        If '$IsObject(tFresh) Quit
        Set tStateDiff = "[{""field"":""State"",""before"":""Running"",""after"":""Suspended""}]"
        Set tSC = $ClassMethod(..#SET, "Prohibits", $Parameter(..#SUSPENDTOOL, "TOOLNAME"), tRef, tFresh.%ToJSON(), tStateDiff, .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for it: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals(tProhibits, 0, "a process the confirming user owns which is neither is permitted, code was '" _ $Get(tCode) _ "'")
        Do $$$AssertEquals($Get(tCode), "", "and carries no refusal code")
        Do $$$AssertTrue('(..ProcessState(tPid) [ "SUSP"), "and asking the question suspended nothing: pid " _ tPid _ " reads '" _ ..ProcessState(tPid) _ "'")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the permitted leg raised")
    }
    ; Its own frame: a raise above skips the method's tail, and a probe left running would outlive
    ; the class that started it.
    Do ..StopProbeProcess(tPid)
    Do $$$AssertEquals(..ProcessState(tPid), "", "and the second probe process is gone")
}

/// <p>AC3 -- both AD-10 refusals through the <b>shipped</b> entry point, which is what the write
/// transition calls: <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> parses the
/// reference, re-reads the target through the port and dispatches to the process branch, so the
/// order the two predicates are evaluated in is the set's own and not this class's.</p>
/// <p>Both targets are live pids, because the set reads the target itself: the confirming job, and
/// a process discovered by <method>SystemPid</method> rather than named. A run that finds no such
/// process fails. Nothing is written, suspended or resumed -- the set only reads and answers.</p>
/// <p>Mutation (Rule 19): delete either refusing branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Process</method> -- the matching leg here goes red
/// while the predicate-level legs above stay green.</p>
Method TestTheShippedProhibitsRefusesTheOwnJobAndASystemProcess()
{
    Set tTool = $Parameter(..#SUSPENDTOOL, "TOOLNAME")
    Set tStateDiff = "[{""field"":""State"",""before"":""Running"",""after"":""Suspended""}]"

    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, $Job, .tOwnRef)
    Do $$$AssertStatusOK(tSC, "the reference to the confirming job builds")
    If $$$ISERR(tSC) Quit
    Set tOwnFresh = ..FreshRead($Job)
    Do $$$AssertTrue($IsObject(tOwnFresh), "and the confirming job reads fresh through the shipped port")
    If '$IsObject(tOwnFresh) Quit
    Set tSC = $ClassMethod(..#SET, "Prohibits", tTool, tOwnRef, tOwnFresh.%ToJSON(), tStateDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for it: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 1, "suspending the confirming caller's own process is refused")
    Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, "OCUPILOTPROCESS"), "as a process OcuPilot is itself running in")

    Set tSystemPid = ..SystemPid()
    Do $$$AssertNotEquals(tSystemPid, "", "this instance carries a process whose JobType the allow-list does not admit and whose owner is not the confirming user")
    If tSystemPid = "" Quit
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tSystemPid, .tSystemRef)
    Do $$$AssertStatusOK(tSC, "the reference to pid " _ tSystemPid _ " builds")
    If $$$ISERR(tSC) Quit
    Set tSystemFresh = ..FreshRead(tSystemPid)
    Do $$$AssertTrue($IsObject(tSystemFresh), "and it reads fresh through the shipped port")
    If '$IsObject(tSystemFresh) Quit
    Set tSC = $ClassMethod(..#SET, "Prohibits", tTool, tSystemRef, tSystemFresh.%ToJSON(), tStateDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for it: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 1, "suspending an IRIS system process is refused")
    Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, "SYSTEMPROCESS"), "as a process of a kind nobody has reviewed")
    Do $$$AssertTrue('(..ProcessState(tSystemPid) [ "SUSP"), "and asking the question suspended nothing: pid " _ tSystemPid _ " reads '" _ ..ProcessState(tSystemPid) _ "'")
}

/// <p>AC1, AC6 -- the whole write against this instance through the shipped mint, port, prohibited
/// set, marker and ledger: the probe process reads suspended afterwards, the ledger row reads
/// marked, one agent-write marker carries the proposal id and the scoped
/// <code>(process, instance, pid)</code> target, and the resume puts it back.</p>
/// <p>Mutation (Rule 19): skip the marker emission in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- the marker row and the marked
/// ledger row both go red.</p>
Method TestTheRealSuspendAndResumeAreMarkedAndAttributedToTheCaller()
{
    Set tPid = ..PreparedPid
    Do $$$AssertNotEquals(tPid, "", "the probe process exists")
    If tPid = "" Quit
    Do $$$AssertTrue('(..ProcessState(tPid) [ "SUSP"), "and starts running, so the suspend has something to change")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Set tSC = ..RealMint(..#SUSPENDTOOL, tPid, tTurn, .tProposal)
        Do $$$AssertStatusOK(tSC, "the suspend proposal mints against the instance: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tKey = tProposal.%Get("proposalId")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
        If $$$ISERR(tSC) Quit

        Do $$$AssertTrue(..ProcessState(tPid) [ "SUSP", "the process reads suspended on the instance: state was '" _ ..ProcessState(tPid) _ "'")
        Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "the answer reports the marker landed")
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "auditMarked"), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the ledger row reads marked")

        Set tRows = ##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, tKey, .tData)
        Do $$$AssertEquals(tRows, 1, "the audit database holds one agent-write marker carrying this proposal's id")
        Set tMarkerData = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Set tMarkerTarget = ""
        If $IsObject(tMarkerData) && (tMarkerData.%GetTypeOf("target") = "object") Set tMarkerTarget = tMarkerData.%Get("target").%ToJSON()
        Do $$$AssertEquals($Select($IsObject(tMarkerData): tMarkerData.%Get("tool"), 1: ""), $Parameter(..#SUSPENDTOOL, "TOOLNAME"), "naming the tool")
        Do $$$AssertTrue(tMarkerTarget [ "process", "and the scoped target triple: " _ tMarkerTarget)
        Do $$$AssertTrue(tMarkerTarget [ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, "with its instance scope: " _ tMarkerTarget)
        Do $$$AssertTrue(tMarkerTarget [ tPid, "and its pid: " _ tMarkerTarget)
        Do $$$AssertEquals($Select($IsObject(tMarkerData): tMarkerData.%Get("actor"), 1: ""), $Username, "and the user who confirmed it")

        ; The other direction through the same path, which is what puts the probe back.
        Set tSC = ..RealMint(..#RESUMETOOL, tPid, tTurn, .tResumeProposal)
        Do $$$AssertStatusOK(tSC, "the resume proposal mints against the suspended process: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tResumeProposal.%Get("proposalId"), "", $Username, .tResumeResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "and its confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
        Do $$$AssertTrue('(..ProcessState(tPid) [ "SUSP"), "so the process is running again: state was '" _ ..ProcessState(tPid) _ "'")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the real suspend raised")
    }
    ; Its own frame: a raise above skips the method's tail, and a suspended probe would stop every
    ; later method reading it.
    Do ..ResumeProcess(tPid)
    Do $$$AssertTrue('(..ProcessState(tPid) [ "SUSP"), "and the probe process is running again")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>The verdict the shipped prohibited set reaches for the process <var>pRead</var> describes,
/// as its <code>PROHIBITED.*</code> code or <code>""</code> -- asked of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Process</method>'s two predicates through the
/// methods that read them, so the predicate under test is the shipped one.</p>
ClassMethod Verdict(pRead As %DynamicObject) As %String
{
    If $ClassMethod(..#SET, "IsOcuPilotProcess", pRead) Quit $Parameter(..#SET, "OCUPILOTPROCESS")
    If '$ClassMethod(..#SET, "IsActionableJobType", pRead) Quit $Parameter(..#SET, "SYSTEMPROCESS")
    Quit ""
}

/// <p>Mint one proposal for <var>pTool</var> and <var>pId</var> through <parameter>MINT</parameter>,
/// whose one replaced seam is the port.</p>
Method MintFor(pTool As %String, pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String = "") As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Mint one proposal for <var>pTool</var> and <var>pId</var> through the <b>shipped</b> mint, so
/// the port, the fresh read and the fingerprint are the instance's own.</p>
Method RealMint(pTool As %String, pId As %String, pTurnKey As %String, Output pProposal As %DynamicObject) As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Process <var>pPid</var> as the shipped port's own <code>GET</code> answers it, or
/// <code>""</code>.</p>
ClassMethod FreshRead(pPid As %String) As %DynamicObject
{
    Set tFresh = ""
    Try {
        Kill tQuery
        Set tQuery("id") = pPid
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If $IsObject(tAnswer) Set tFresh = tAnswer
    } Catch ex {
        Set tFresh = ""
    }
    Quit tFresh
}

/// <p>The account the probe process runs as, created if it is absent. It holds no role: the probe
/// only has to be owned by somebody who is not the confirming user.</p>
ClassMethod EnsureProbeOwner() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PRINCIPALUSER, "", ..#PRINCIPALPASSWORD, "OcuPilot process control probe owner (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ProcessControl; deleted in OnAfterAllTests")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the probe owner account.</p>
ClassMethod RemoveProbeOwner()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#PRINCIPALUSER)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p><code>JOB</code> this class's own probe process and answer its pid, or <code>""</code> when
/// the instance reports no such process a moment later.</p>
ClassMethod StartProbeProcess() As %String
{
    Set tPid = ""
    Try {
        Job ##class(OcuPilot.Test.ProcessControl).ProbeWait()
        Set tPid = $ZChild
        If 'tPid Set tPid = ""
        If tPid = "" Quit
        For tI = 1:1:50 {
            If ..ProcessState(tPid) '= "" Quit
            Hang 0.1
        }
        ; Read again after a pause: a probe that started and ended at once would otherwise be
        ; answered as a running process, and every leg reading it would fail for that reason
        ; rather than for its own.
        Hang 2
        If ..ProcessState(tPid) = "" Set tPid = ""
    } Catch ex {
        Set tPid = ""
    }
    Quit tPid
}

/// <p>The probe process's own body: sign in as <parameter>PRINCIPALUSER</parameter> so the process
/// this class acts on is owned by somebody other than the confirming user, then wait.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>StartProbeProcess</method> and by
/// nothing else. It ends on its own after <parameter>PROBESECONDS</parameter> whatever happens to
/// the class that started it, so a run that aborted cannot leave a process waiting for ever;
/// <method>StopProbeProcess</method> is the ordinary end.</p>
/// <p><code>$System.Security.Login</code> is used here for what it is -- switching this process's
/// own user context -- and never to validate a credential.</p>
/// <p><b>It touches nothing after the sign-in.</b> The account holds no role, so a global read
/// would raise <code>&lt;PROTECT&gt;</code> and end the process seconds after it started -- which
/// is a probe that is gone by the time anything reads it. <code>Hang</code> and the two class
/// parameters are compiled in and need no privilege, so the wait is the whole body.</p>
ClassMethod ProbeWait()
{
    Try {
        Do $System.Security.Login(..#PRINCIPALUSER, ..#PRINCIPALPASSWORD)
    } Catch ex {
    }
    Try {
        Hang ..#PROBESECONDS
    } Catch ex {
    }
    Quit
}

/// <p>Process <var>pPid</var>'s <code>State</code> as <code>%SYS.ProcessQuery</code> holds it, or
/// <code>""</code> when the instance carries no such process.</p>
ClassMethod ProcessState(pPid As %String) As %String
{
    If pPid = "" Quit ""
    Set tState = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM %SYS.ProcessQuery WHERE Pid = ?", pPid)
        If tRS.%Next() Set tState = tRS.%Get("State")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tState = ""
    }
    Quit tState
}

/// <p><code>JOB</code> a probe process that signs in as nobody, so it inherits the confirming
/// user, and answer its pid or <code>""</code>. The caller stops it with
/// <method>StopProbeProcess</method>.</p>
ClassMethod StartOwnedProbeProcess() As %String
{
    Set tPid = ""
    Try {
        Job ##class(OcuPilot.Test.ProcessControl).OwnedProbeWait()
        Set tPid = $ZChild
        If 'tPid Set tPid = ""
        If tPid = "" Quit
        For tI = 1:1:50 {
            If ..ProcessState(tPid) '= "" Quit
            Hang 0.1
        }
        Hang 2
        If ..ProcessState(tPid) = "" Set tPid = ""
    } Catch ex {
        Set tPid = ""
    }
    Quit tPid
}

/// <p>The owned probe's body: wait, and nothing else. It signs in as nobody, which is what leaves
/// the process owned by the user that <code>JOB</code>ed it.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>StartOwnedProbeProcess</method> and by
/// nothing else. It ends on its own after <parameter>PROBESECONDS</parameter>, so a run that
/// aborted cannot leave a process waiting for ever.</p>
ClassMethod OwnedProbeWait()
{
    Try {
        Hang ..#PROBESECONDS
    } Catch ex {
    }
    Quit
}

/// <p>Process <var>pPid</var>'s <code>UserName</code> as <class>%SYS.ProcessQuery</class> holds
/// it, or <code>""</code> when the instance carries no such process.</p>
ClassMethod UserNameOf(pPid As %String) As %String
{
    If pPid = "" Quit ""
    Set tUser = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT UserName FROM %SYS.ProcessQuery WHERE Pid = ?", pPid)
        If tRS.%Next() Set tUser = tRS.%Get("UserName")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tUser = ""
    }
    Quit tUser
}

/// <p>Process <var>pPid</var>'s <code>JobType</code>, or <code>-1</code> when the instance carries
/// no such process.</p>
ClassMethod JobTypeOf(pPid As %String) As %Integer
{
    If pPid = "" Quit -1
    Set tType = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT JobType FROM %SYS.ProcessQuery WHERE Pid = ?", pPid)
        If tRS.%Next() Set tType = +tRS.%Get("JobType")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tType = -1
    }
    Quit tType
}

/// <p>A live pid on this instance that <method>OcuPilot.Kernel.Proposal.Prohibited.Process</method>
/// refuses as a system process -- one whose <code>JobType</code> the shipped allow-list does not
/// admit, which the confirming user does not own, and which the shipped port still reads -- or
/// <code>""</code> when the instance carries none.</p>
/// <p>The lowest pids first, which are the instance's own long-lived daemons, so the pid this
/// answers is still there when the caller asks about it. The allow-list and the account identity
/// rule are read from the set itself rather than restated here, which is why the rows are read in
/// <code>%SYS</code> and judged after the namespace is back: neither the set nor the port answers
/// there.</p>
ClassMethod SystemPid() As %String
{
    Set tFound = ""
    Set tRows = 0
    Kill tRow
    Set tAdmitted = $ClassMethod(..#SET, "ProcessJobTypes")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid, JobType, UserName FROM %SYS.ProcessQuery ORDER BY Pid")
        While tRS.%Next() {
            Set tRows = tRows + 1
            Set tRow(tRows) = $ListBuild(tRS.%Get("Pid"), tRS.%Get("JobType"), tRS.%Get("UserName"))
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = 0
    }
    Set tCaller = $ClassMethod(..#SET, "NormalizedUser", $Username)
    For tI = 1:1:tRows {
        Set tPid = $List(tRow(tI), 1)
        If tPid = $Job Continue
        If $ListFind(tAdmitted, +$List(tRow(tI), 2)) Continue
        If $ClassMethod(..#SET, "NormalizedUser", $List(tRow(tI), 3)) = tCaller Continue
        Set tFresh = ..FreshRead(tPid)
        If '$IsObject(tFresh) Continue
        If $ListFind(tAdmitted, +tFresh.%Get("JobType")) Continue
        Set tFound = tPid
        Quit
    }
    Quit tFound
}

/// <p>Resume process <var>pPid</var> if the instance reports it suspended, doing nothing
/// otherwise.</p>
ClassMethod ResumeProcess(pPid As %String)
{
    If pPid = "" Quit
    If '(..ProcessState(pPid) [ "SUSP") Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProcess = ##class(SYS.Process).%OpenId(pPid)
        If $IsObject(tProcess) Do tProcess.Resume()
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    For tI = 1:1:50 {
        If '(..ProcessState(pPid) [ "SUSP") Quit
        Hang 0.1
    }
}

/// <p>End the probe process: resume it if it is suspended, then terminate it and wait for the
/// instance to stop reporting it. Nothing here touches a process this class did not start.</p>
ClassMethod StopProbeProcess(pPid As %String)
{
    If pPid = "" Quit
    Do ..ResumeProcess(pPid)
    If ..ProcessState(pPid) = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProcess = ##class(SYS.Process).%OpenId(pPid)
        If $IsObject(tProcess) Do tProcess.Terminate()
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    For tI = 1:1:100 {
        If ..ProcessState(pPid) = "" Quit
        Hang 0.1
    }
}

}
