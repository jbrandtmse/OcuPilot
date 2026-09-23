/// <p>Pins Story 5.11's write (AD-51, AD-6, AD-10, AD-34, AD-36): the first action-style write --
/// a bodyless <code>RESUME</code> whose diff comes from the read, whose target is a task suspended
/// after an error, and whose every other gate is where it already was.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, <code>%Admin_Task:USE</code>
/// and <code>%DB_IRISSYS:READ</code>, a Task Manager it may create one task in, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not, because this class creates and
/// resumes a real task; only <file>scripts/ci-throwaway.sh</file> sets it. It creates its
/// own suspended task (<parameter>PROBETASKNAME</parameter>) and resumes only that one; the demo
/// fixture's task is read and never written, because a resumed demo task is the demo path gone.</p>
/// <p><b>The probe task is left suspended on every exit path</b>: each method that resumes it
/// restores the state in a frame of its own after <code>Try</code>/<code>Catch</code> -- a raise
/// skips a method's tail -- and <method>OnAfterOneTest</method> restores it again and asserts the
/// restore worked, so a method that aborted mid-write cannot leave a later method reading a task
/// that is no longer suspended. <method>OnAfterAllTests</method> deletes it.</p>
Class OcuPilot.Test.TaskResume Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskResume";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The task this class creates, suspends, resumes and deletes. Named with the probe prefix the
/// rest of the suite uses, so a leaked one is recognisable as a test's.</p>
Parameter PROBETASKNAME = "OcuPilotProbeResumeTask";

/// <p>The suspended-state value <code>%SYS.TaskSuper.Suspended</code> carries for "suspended,
/// leave the schedule alone", which is what a task suspended after an error reads.</p>
Parameter SUSPENDLEAVE = 1;

/// <p>The fresh <code>INFO</code> answer the fixture port gives for a suspended task: the eight
/// keys <code>RunInfo</code> writes, in its own order. <code>Status</code> here is the last run's
/// result, not a suspend state -- which is why the card's own <code>Status</code> row is a state
/// row and not a field of this object.</p>
Parameter FRESHSUSPENDED = "{""Type"":""User"",""Status"":""1"",""Error"":""probe error"",""LastSchedule"":"""",""LastStarted"":""2026-09-21 06:27:00"",""LastFinished"":""2026-09-21 06:27:00"",""NextScheduled"":""2026-09-21 06:26:48"",""Suspended"":true}";

/// <p>The same answer with the task running again, which is what a target somebody else resumed
/// reads as.</p>
Parameter FRESHRUNNING = "{""Type"":""User"",""Status"":""1"",""Error"":""probe error"",""LastSchedule"":"""",""LastStarted"":""2026-09-21 06:27:00"",""LastFinished"":""2026-09-21 06:27:00"",""NextScheduled"":""2026-09-21 06:26:48"",""Suspended"":false}";

/// <p>The probe task's id for this run. Prefix deliberately not "Test" -- see
/// .claude/rules/objectscript-testing.md.</p>
Property PreparedTaskId As %String;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskResume creates and resumes a task in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ..EnsureProbeTask(.tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTaskId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ..DeleteProbeTask(..PreparedTaskId)
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Restore the probe task's suspended state whatever a method did, and report a failed restore
/// as a failure of this teardown rather than of the next method.</p>
/// <p><b>The assertion is on the reading taken BEFORE this teardown repairs anything.</b> A method
/// that resumes the task restores it in a frame of its own, so a reading of 0 here says that frame
/// did not run -- and a reading taken after the repair would be 1 whether it ran or not.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tBefore = ..TaskSuspended(..PreparedTaskId)
    Do ..SuspendProbeTask(..PreparedTaskId)
    Set tResult = $$$OK
    If ..TaskSuspended(..PreparedTaskId) '= ..#SUSPENDLEAVE {
        Set tResult = $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskResume left its probe task running")
    }
    Do $$$AssertEquals(tBefore, ..#SUSPENDLEAVE, "the method left the probe task suspended itself, so this teardown had nothing to repair")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit tResult
}

/// <p>AC4 -- the mint reads the task with the tool's own <code>INFO</code>, answers exactly one
/// state row <code>Status: Suspended -&gt; Scheduled</code>, declares the write not destructive,
/// and discloses nothing as unchanged, because nothing will be sent (AD-51).</p>
/// <p>Mutation (Rule 19): drop the <code>StateDiff</code> push in
/// <class>OcuPilot.Screen.Tool.TaskResume</class> -- the one-row assertion goes red; make
/// <method>OcuPilot.Kernel.Proposal.Mint.ReadTypeOf</method> answer its own parameter -- the
/// <code>INFO</code> assertion goes red and the mint reads a GET that carries no state at all.</p>
Method TestTheMintAnswersOneStateRowFromTheInfoRead()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "INFO", "the fresh read is the tool's own request type, the only one that answers Suspended truthfully")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "41", "keyed by the vendor's own query parameter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing was written by the mint")

    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "the card carries exactly one row")
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals(tRow.%Get("field"), "Status", "labelled with the product's word for the state")
    Do $$$AssertEquals(tRow.%Get("before"), "Suspended", "moving from Suspended")
    Do $$$AssertEquals(tRow.%Get("after"), "Scheduled", "to Scheduled")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and no field is sent unchanged, because no body is sent at all")

    Set tKey = tProposal.%Get("proposalId")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive"), 0, "the stored row declares the write not destructive")
    Set tStoredSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tStored)
    Do $$$AssertStatusOK(tStoredSC, "the stored row reads back")
    Set tRows = ##class(OcuPilot.Kernel.Proposal.Disclosure).Rows($Parameter(..#TOOL, "TOOLNAME"), $Get(tStored("payload")), $Get(tStored("diff")))
    Do $$$AssertEquals(tRows.%Size(), 0, "and the unchanged-field disclosure is empty, so the caption's count and the rows behind it are one population")
}

/// <p>AC5 -- a task the instance reports as not suspended is refused at the mint, so the vendor's
/// own "this returns ok even if it is not suspended" is never reached.</p>
/// <p>Mutation (Rule 19): remove the not-suspended arm from
/// <method>OcuPilot.Screen.Tool.TaskResume.StateDiff</method> -- this goes red, minting a proposal
/// whose one row says a state changes that does not.</p>
Method TestATaskThatIsNotSuspendedIsRefusedAtTheMint()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the mint is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("detail").%Get("problem"), 1: ""), "this instance reports that task as not suspended, and only a suspended task can be resumed", "naming that the task is not suspended")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tBefore, "and no proposal row exists")

    ; A read that carried no suspended state at all refuses too: a value the tool cannot read must
    ; not become a proposal to resume something.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Type"":""User""}")
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a read carrying no Suspended property is refused too")
}

/// <p>AC7 -- the confirmed write is the vendor's <code>RESUME</code>, carrying the id query
/// parameter and <b>no body</b>, and the ledger row it finalises names no field.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Confirm.ToolSendsBody</method>
/// answer 1 -- the empty-body assertion goes red, and the port receives the fresh read as a
/// payload nobody reviewed.</p>
Method TestTheConfirmedWriteIsABodylessResumeCarryingTheId()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "one write reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "RESUME", "as the vendor's own resume request type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "41", "carrying the task's id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "and no body at all")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "fields"), "", "so the ledger row records no field name")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC6 -- a task another party resumed between the mint and the confirm is refused by the
/// fingerprint, the row closes, and nothing reaches the port.</p>
/// <p><code>Suspended</code> is the fingerprint's whole subject: the tool declares it, because it
/// is the field its own precondition reads (AD-51 as amended 2026-09-22, DW-1476).</p>
/// <p>Mutation (Rule 19): declare <code>FINGERPRINTSUBJECT</code> and
/// <code>PRECONDITIONFIELD</code> as <code>NextScheduled</code> on
/// <class>OcuPilot.Screen.Tool.TaskResume</class> -- a name the screen also declares, so the
/// registration guard still admits the tool -- and this goes red at the mint: the tool's own
/// precondition reads <parameter>PRECONDITIONFIELD</parameter>
/// (<method>OcuPilot.Screen.Tool.TaskResume.StateDiff</method>), so a subject that no longer names
/// <code>Suspended</code> takes the not-suspended refusal with it and no proposal is minted to
/// confirm.</p>
Method TestATaskResumedUnderALiveProposalIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")

    ; Somebody else resumed it in the window.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "with the moved-target code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "the row is closed, so the card offers only Re-propose")
}

/// <p>AC7's one-lock half (AD-13, AD-34) -- two spellings of one task id build one target key, so
/// the second proposal is the first's sibling: confirming one cancels the other.</p>
/// <p>Mutation (Rule 19): answer the id verbatim for the task rule in
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> -- the two keys differ and the sibling
/// cancel leaves the second proposal live.</p>
Method TestTwoSpellingsOfOneTaskIdAreOneTarget()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor("007", .tFirst, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the first proposal mints from the padded spelling")
    If $$$ISERR(tSC) Quit
    Set tSC = ..MintFor("7", .tSecond, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "and a second from the plain one")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tFirst.%Get("target").%Get("id"), "7", "the recorded target is the canonical spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "TargetRef"), ##class(OcuPilot.Test.ProposalFixture).Field(tSecond.%Get("proposalId"), "TargetRef"), "and both rows carry one target reference")

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "confirming one of them succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "and its sibling on the same target is cancelled in the same transition")
}

/// <p>The <code>task</code> branch of AD-10's set: no field of a task is one this release has
/// reviewed, so a proposal carrying any changed field is refused, while the resume's own state row
/// -- which changes no field of the payload -- is not.</p>
/// <p><b>The refusing arm is reached by arming the predicate's input</b>, not by replacing the
/// method: the resume tool admits no field, so no call through it can carry one (Stories 5.9 and
/// 5.10's lesson about a safety predicate whose refusing branch never runs).</p>
/// <p>Mutation (Rule 19): remove <code>task</code> from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- the refusal becomes
/// <code>UNCOVERED</code> and the resume's own no-change leg is refused wholesale. Drop the
/// state-field skip from <method>OcuPilot.Kernel.Proposal.Prohibited.Changed</method> -- the
/// moved-property leg is refused <code>UNCOVEREDFIELD</code> over a row nobody proposed.</p>
Method TestAChangedFieldOnATaskProposalIsRefused()
{
    Set tId = ..PreparedTaskId
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("task", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tId, .tRef)
    Do $$$AssertStatusOK(tSC, "the task reference builds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($ListLength($ClassMethod(..#SET, "PermittedChangeFields", "task")), 0, "no field of a task is one this release has reviewed")
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "CoveredTypes"), "task") > 0, "and the type is covered, so a task write is not refused wholesale")

    ; The set reads its target through the shipped port with the tool's own request type, so both
    ; halves below are judged against this instance's own INFO answer for the probe task.
    Kill tQuery
    Set tQuery($ClassMethod(..#TOOL, "IdParam")) = tId
    Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke($ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tReadSC, "the task reads fresh")
    If $$$ISERR(tReadSC) || '$IsObject(tFresh) Quit

    ; The resume's own shape: the payload is that fresh read and the target reads the same, so the
    ; set sees no changed field and refuses nothing -- the state row's label is not a field that
    ; moved.
    Set tDiff = "[{""field"":""Status"",""before"":""Suspended"",""after"":""Scheduled""}]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tFresh.%ToJSON(), tDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the resume's own shape")
    Do $$$AssertEquals(tProhibits, 0, "which is prohibited by nothing, code was '" _ $Get(tCode) _ "'")

    ; An armed input: a payload that really moves a field the instance holds otherwise, with the
    ; diff naming it. The resume tool admits no field, so arming the predicate's input is the only
    ; way its branch's refusing arm runs at all.
    Set tMovedPayload = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tMovedPayload.%Set("Type", "OcuPilotProbeMovedType", "string")
    Set tMoved = "[{""field"":""Type"",""before"":""User"",""after"":""OcuPilotProbeMovedType""}]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tMovedPayload.%ToJSON(), tMoved, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the armed input")
    Do $$$AssertEquals(tProhibits, 1, "a changed field on a task proposal is refused")
    Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, "UNCOVEREDFIELD"), "as a field nobody has reviewed")

    ; The state row's label spells a property Task.CRUD answers for its own reasons -- Status is
    ; the last run's result -- so the label and a moved property are armed together here: the one
    ; input on which reading the label as a field would refuse a change nobody proposed, ahead of
    ; the fingerprint gate that owns the moved-target answer.
    Do $$$AssertEquals($ClassMethod(..#TOOL, "StateField"), $Parameter(..#TOOL, "STATEFIELD"), "the tool declares its state row's label")
    Do $$$AssertTrue(tFresh.%IsDefined($ClassMethod(..#TOOL, "StateField")), "and the endpoint answers a property of that name, which is what makes the collision reachable")
    Set tMovedState = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tMovedState.%Set($ClassMethod(..#TOOL, "StateField"), "OcuPilotProbeMovedStatus", "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tMovedState.%ToJSON(), tDiff, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the resume's own row over a moved property of the same name")
    Do $$$AssertEquals(tProhibits, 0, "which is prohibited by nothing -- the row is a label, not a field, code was '" _ $Get(tCode) _ "'")
}

/// <p>AC7, AC8, AC9 -- the whole write against this instance, through the shipped mint, port,
/// prohibited set, marker and ledger: the probe task's own <code>INFO</code> reads
/// <code>Suspended</code> false afterwards, the ledger row reads marked, one OcuPilot agent-write
/// marker carries the proposal id and the scoped target, and the vendor's own task history records
/// the resume against the <b>caller</b> (measured on <code>ocupilot-ci</code>, 2026-09-21: a
/// resume row's <code>Username</code> is the caller's, not the task's <code>RunAsUser</code>).</p>
/// <p>Mutation (Rule 19): skip the marker emission in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- the marker row and the marked
/// ledger row both go red.</p>
Method TestTheRealResumeIsMarkedAndAttributedToTheCaller()
{
    Set tId = ..PreparedTaskId
    Do $$$AssertNotEquals(tId, "", "the probe task exists")
    If tId = "" Quit
    Do $$$AssertEquals(..TaskSuspended(tId), ..#SUSPENDLEAVE, "and starts suspended, so the resume has something to change")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tHistorySince = ..HistoryHighWater()
    ; AC9 reads the shipped tasks.history read, not only the vendor table, so the before reading
    ; is taken here and the claim below is the delta. It is a delta rather than a count because a
    ; probe task this class reused from an earlier run carries that run's rows, and the AC is
    ; about the row this confirm lands, not about how many stand beside it.
    Set tHistoryBefore = ..HistoryRowsForTask(tId)
    Do $$$AssertTrue(tHistoryBefore '< 0, "the shipped tasks.history read answers, so the delta below is a reading rather than a failure")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), tId, "string")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), tId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
        Do $$$AssertStatusOK(tSC, "the proposal mints against the instance: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tKey = tProposal.%Get("proposalId")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
        If $$$ISERR(tSC) Quit

        Do $$$AssertEquals(..TaskSuspended(tId), 0, "the task is no longer suspended on the instance")
        Do $$$AssertEquals(..InfoSuspended(tId), "false", "and the endpoint's own INFO answers Suspended false")
        Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "the answer reports the marker landed")
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "auditMarked"), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the ledger row reads marked")

        Set tRows = ##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, tKey, .tData)
        Do $$$AssertEquals(tRows, 1, "the audit database holds one agent-write marker carrying this proposal's id")
        Set tMarkerData = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Set tMarkerTarget = ""
        If $IsObject(tMarkerData) && (tMarkerData.%GetTypeOf("target") = "object") Set tMarkerTarget = tMarkerData.%Get("target").%ToJSON()
        Do $$$AssertEquals($Select($IsObject(tMarkerData): tMarkerData.%Get("tool"), 1: ""), $Parameter(..#TOOL, "TOOLNAME"), "naming the tool")
        Do $$$AssertTrue(tMarkerTarget [ "task", "and the scoped target triple: " _ tMarkerTarget)
        Do $$$AssertTrue(tMarkerTarget [ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, "with its instance scope: " _ tMarkerTarget)
        Do $$$AssertTrue(tMarkerTarget [ tId, "and its id: " _ tMarkerTarget)
        Do $$$AssertEquals($Select($IsObject(tMarkerData): tMarkerData.%Get("actor"), 1: ""), $Username, "and the user who confirmed it")

        Do $$$AssertEquals(..ResumeHistoryUser(tId, tHistorySince), $Username, "and the vendor's own task history attributes the resume to the caller")
        ; AC9's own surface: the existing tasks.history read, not the vendor table behind it. The
        ; row has to survive that read's field set, its cap and its sort to be the thing the AC
        ; promises a reader will see.
        Do $$$AssertTrue(..HistoryRowsForTask(tId) > tHistoryBefore, "and the shipped tasks.history read now answers that row, attributed to the caller")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the real resume raised")
    }
    ; Its own frame: a raise above skips the method's tail, and every later method in this class
    ; and the browser suite's own demo path need this task suspended again.
    Do ..SuspendProbeTask(tId)
    Do $$$AssertEquals(..TaskSuspended(tId), ..#SUSPENDLEAVE, "and the probe task is suspended again")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1, DW-269 -- the schedule list's declared read answers a suspended task's
/// <code>Suspended</code> as true, taken from the same endpoint's <code>INFO</code> per row, while
/// the vendor's own LIST answers false for that very task.</p>
/// <p>Both halves are asserted on <b>one</b> row, the probe task's, so the claim is about the
/// coercion rather than about two populations.</p>
/// <p>Mutation (Rule 19): drop the <code>rowGet</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -- the read's own answer becomes the
/// LIST's coerced false and this goes red.</p>
Method TestTheScheduleReadAnswersSuspendedTruthfully()
{
    Set tId = ..PreparedTaskId
    Do $$$AssertEquals(..TaskSuspended(tId), ..#SUSPENDLEAVE, "the probe task is suspended")
    Kill tCriteria
    Set tStarted = $ZHorolog
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 1000, .tAnswer, .tHttp, .tFault, .tCriteria)
    Set tElapsed = $ZHorolog - tStarted
    Do $$$AssertStatusOK(tSC, "the schedule list's declared read runs: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tElapsed < 2, "and stays inside NFR-1's two seconds with one INFO per row (" _ tElapsed _ "s)")

    Set tFound = ""
    Set tIterator = tAnswer.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If tRow.%Get("Id") '= tId Continue
        Set tFound = tRow
    }
    Do $$$AssertTrue($IsObject(tFound), "the probe task is one of the rows")
    If '$IsObject(tFound) Quit
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tFound.%Get("Suspended"), tFound.%GetTypeOf("Suspended")), "true", "and its Suspended reads true in the screen's own rows")

    ; The same task through the vendor's own LIST, which is the coercion DW-269 names.
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "LIST", .tQuery, "", .tList, .tListHttp, .tListFault)
    Do $$$AssertStatusOK(tSC, "the vendor LIST answers")
    If $$$ISERR(tSC) Quit
    Set tCoerced = ""
    ; The vendor answers a bare array of task objects, not an envelope with a named member.
    Set tListIterator = tList.%GetIterator()
    While tListIterator.%GetNext(.tListIndex, .tListRow) {
        If '$IsObject(tListRow) Continue
        If tListRow.%Get("Id") '= tId Continue
        Set tCoerced = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tListRow.%Get("Suspended"), tListRow.%GetTypeOf("Suspended"))
    }
    Do $$$AssertEquals(tCoerced, "false", "while the vendor's own LIST answers false for that same task, which is the coercion the detail call exists for")
}

/// <p>AC1, DW-269, DW-1459 -- the model's own <code>tasks.schedule.read</code> tool, not only the
/// screen's declared read, answers the probe task's <code>Suspended</code> as true.</p>
/// <p>Before this method, no leg anywhere in the tree called
/// <method>OcuPilot.Screen.Tool.Read.View</method> for this descriptor at all: the declaration was
/// pinned by <class>OcuPilot.Test.Descriptor</class>'s <code>ContextFields</code> assertion and the
/// screen's own rows by <method>TestTheScheduleReadAnswersSuspendedTruthfully</method> above, but
/// the tool the agent actually calls ran the projection for no suspended task anywhere. This closes
/// that gap directly, through the same tool method <class>OcuPilot.Test.TaskDetails</class> and
/// <class>OcuPilot.Test.TaskHistory</class> already use for their own screens.</p>
/// <p>Mutation (Rule 19): drop the <code>rowGet</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -- the tool's view answers the
/// vendor's coerced <code>false</code> for every row and this goes red, the same way
/// <method>TestTheScheduleReadAnswersSuspendedTruthfully</method>'s does, this time through the
/// tool's own <method>View</method> rather than the executor directly (AC1).</p>
Method TestTheReadToolsViewAnswersSuspendedTruthfully()
{
    Set tId = ..PreparedTaskId
    Do $$$AssertEquals(..TaskSuspended(tId), ..#SUSPENDLEAVE, "the probe task is suspended")

    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#SCREEN, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tasks.schedule.read tool's view answers: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(+tHttp, 200, "at 200")

    Set tFound = ""
    Set tIterator = tView.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If tRow.%Get("Id") '= tId Continue
        Set tFound = tRow
    }
    Do $$$AssertTrue($IsObject(tFound), "the probe task is one of the tool's own rows")
    If '$IsObject(tFound) Quit
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tFound.%Get("Suspended"), tFound.%GetTypeOf("Suspended")), "true", "and the tasks.schedule.read tool's own view -- the projection the model actually calls -- answers Suspended true for it, not only the screen's declared read")
}

/// <p>Mint one <code>tasks.schedule.resume</code> proposal for <var>pId</var> through
/// <parameter>MINT</parameter>, whose one replaced seam is the port.</p>
Method MintFor(pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String = "") As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>The id of this class's own suspended probe task, created if it is absent and left
/// <parameter>SUSPENDLEAVE</parameter> either way.</p>
/// <p><b>It is suspended by declaration, not by a failed run.</b> The demo fixture's task reaches
/// the state through <code>OcuPilot.Install.DemoTask</code>'s deliberate failure and the Task
/// Manager's own once-a-minute pass; this class needs the state rather than the route to it, and
/// waiting a minute per method for a daemon is a cost with no assertion behind it.</p>
ClassMethod EnsureProbeTask(Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = $NAMESPACE
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#PROBETASKNAME)
        While tRS.%Next() {
            Set pId = tRS.%Get("ID")
        }
        If pId = "" {
            Set tTask = ##class(%SYS.Task).%New()
            Set tTask.Name = ..#PROBETASKNAME
            Set tTask.Description = "OcuPilot.Test.TaskResume's own target: suspended, resumed and deleted by that class"
            Set tTask.NameSpace = tInstallNs
            Set tTask.TaskClass = "OcuPilot.Install.DemoTask"
            Set tTask.TimePeriod = 0
            Set tTask.TimePeriodEvery = 1
            Set tTask.DailyFrequency = 0
            Set tTask.DailyStartTime = 10800
            Set tTask.SuspendOnError = 1
            Set tTask.Expires = 0
            Set tTask.Suspended = ..#SUSPENDLEAVE
            Set tSC = tTask.%Save()
            If $$$ISOK(tSC) Set pId = tTask.%Id()
            Set tTask = ""
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        If pId = "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskResume could not create its probe task")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) && (pId '= "") Do ..SuspendProbeTask(pId)
    Quit tSC
}

/// <p>Put task <var>pId</var> back into the suspended state, doing nothing when it already is.</p>
ClassMethod SuspendProbeTask(pId As %String)
{
    If pId = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId)
        If $IsObject(tTask) && (+tTask.Suspended '= ..#SUSPENDLEAVE) {
            Set tTask.Suspended = ..#SUSPENDLEAVE
            Do tTask.%Save()
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Task <var>pId</var>'s <code>Suspended</code> value as the instance holds it, or
/// <code>-1</code> when it could not be read -- never <code>0</code>, which reads as "running" and
/// would let a restore be skipped.</p>
ClassMethod TaskSuspended(pId As %String) As %Integer
{
    If pId = "" Quit -1
    Set tValue = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId)
        If $IsObject(tTask) Set tValue = +tTask.Suspended
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

/// <p>Task <var>pId</var>'s <code>Suspended</code> as the endpoint's own <code>INFO</code> renders
/// it -- <code>true</code>, <code>false</code>, or <code>""</code> when the read failed.</p>
ClassMethod InfoSuspended(pId As %String) As %String
{
    Set tRendered = ""
    Try {
        Kill tQuery
        Set tQuery("id") = pId
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) Quit
        Set tRendered = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get("Suspended"), tFresh.%GetTypeOf("Suspended"))
    } Catch ex {
        Set tRendered = ""
    }
    Quit tRendered
}

/// <p>The highest <code>%SYS.Task.History</code> row id right now, so the read below is bounded to
/// rows this method's own write produced.</p>
ClassMethod HistoryHighWater() As %Integer
{
    Set tMax = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) AS M FROM %SYS_Task.History")
        If tRS.%Next() Set tMax = +tRS.%Get("M")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tMax = 0
    }
    Quit tMax
}

/// <p>How many rows the shipped <code>tasks.history</code> read answers for task <var>pId</var>
/// attributed to the calling user, searched by the probe task's own name so the read stays
/// inside its cap on an instance whose history is large.</p>
/// <p>It goes through <class>OcuPilot.Screen.Read</class> rather than the vendor table, because
/// that read's field set, cap and sort are what decide whether a reader sees the row at all -- a
/// SQL probe answers a different question.</p>
ClassMethod HistoryRowsForTask(pId As %String) As %Integer
{
    Set tRows = 0
    Try {
        Kill tCriteria
        Set tCriteria("search") = ..#PROBETASKNAME
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.TaskHistoryList", 1000, .tAnswer, .tHttp, .tFault, .tCriteria)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tAnswer) Quit
        Set tIterator = tAnswer.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            If tRow.%Get("TaskId") '= pId Continue
            If tRow.%Get("Username") '= $Username Continue
            Set tRows = tRows + 1
        }
    } Catch ex {
        Set tRows = -1
    }
    Quit tRows
}

/// <p>The user the vendor recorded against the most recent resume of task <var>pId</var> after row
/// <var>pSince</var>, or <code>""</code> when it recorded none.</p>
/// <p>The vendor writes one <code>%SYS.Task.History</code> row per resume, whose
/// <code>ExecuteCode</code> is <code>TASKMGR</code> and whose <code>Error</code> reads
/// <code>Resumed task</code>. Nothing here writes to that table -- it is the vendor's (AD-2,
/// AD-37).</p>
ClassMethod ResumeHistoryUser(pId As %String, pSince As %Integer) As %String
{
    Set tUser = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Username FROM %SYS_Task.History WHERE ID > ? AND Task = ? AND Error = 'Resumed task' ORDER BY ID", pSince, pId)
        While tRS.%Next() {
            Set tUser = tRS.%Get("Username")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tUser = ""
    }
    Quit tUser
}

/// <p>Delete this class's probe task.</p>
ClassMethod DeleteProbeTask(pId As %String)
{
    If pId = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(%SYS.Task).%DeleteId(pId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Story 7.5, AC2 and AD-53's agent caller: a real mint and confirm of
/// <code>tasks.ondemand.run</code> on <class>OcuPilot.Test.TaskRunFixture</class>'s probe task
/// answers <code>updated</code> with one marker and a marked ledger row; <code>INFO</code>
/// <code>NextScheduled</code> is set at once and this process holds no lock on the task; the run
/// lands in the task's history within one Task Manager pass, and the shipped
/// <code>tasks.taskhistory</code> read gains that row.</p>
/// <p>The wait is bounded at 180 s, so a lock held across the write reads red rather than
/// hanging. The probe is deleted in this method's own frame.</p>
Method TestTheAgentsRunIsConfirmedAndLandsInTheTasksHistory()
{
    Set tTool = "OcuPilot.Screen.Tool.TaskRun"
    Set tFixture = "OcuPilot.Test.TaskRunFixture"
    Set tSC = $ClassMethod(tFixture, "EnsureRunProbeTask", .tId)
    Do $$$AssertStatusOK(tSC, "the run probe task exists: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tTurn = ""
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tHistorySince = $ClassMethod(tFixture, "HistoryHighWater")
        Set tHistoryBefore = $ClassMethod(tFixture, "HistoryReadRows", tId)
        Do $$$AssertTrue(tHistoryBefore '< 0, "the shipped tasks.taskhistory read answers before the run")
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
        Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
        If $$$ISERR(tSC) Quit
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tTool, "IdArgument"), tId, "string")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tId, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
        Do $$$AssertStatusOK(tSC, "the run mints against the instance: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Do $$$AssertEquals(tProposal.%Get("changed").%Get(0).%Get("field"), "NextScheduled", "its card's row is the next run")
        Set tKey = tProposal.%Get("proposalId")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
        If $$$ISERR(tSC) Quit
        Do $$$AssertEquals(tResult.%Get("action"), "updated", "answering updated")
        Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "and marked")
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, tKey, .tData), 1, "one agent-write marker carries this proposal's id")
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "auditMarked"), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the ledger row reads marked")
        Do $$$AssertNotEquals($ClassMethod(tFixture, "InfoField", tId, "NextScheduled"), "", "INFO's NextScheduled is set at once")
        Do $$$AssertTrue($ClassMethod(tFixture, "NoLockHeld", tId), "and this process holds no lock on the task")
        Set tLanded = $ClassMethod(tFixture, "AwaitRun", tId, tHistorySince, 180, .tElapsed)
        Do $$$AssertTrue(tLanded, "a Success history row lands within 180 s (waited " _ $Get(tElapsed) _ " s)")
        Do $$$AssertTrue($ClassMethod(tFixture, "HistoryReadRows", tId) > tHistoryBefore, "and the shipped tasks.taskhistory read answers it")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the real run raised")
    }
    Do $ClassMethod(tFixture, "DeleteRunProbeTask")
    Do $$$AssertEquals($ClassMethod(tFixture, "ProbeCount"), 0, "and the run probe task is gone")
    If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Story 7.5, AC1 and AD-53's screen caller: <code>POST /screens/tasks.ondemand/action</code>
/// with <code>run</code> as the test account answers 200 with the <code>updated</code> triple, writes
/// no ledger row and emits no OcuPilot marker, and the run lands in the task's history within one
/// Task Manager pass. The probe is deleted in this method's own frame.</p>
Method TestTheScreenActionRunsTheTaskOverTheWire()
{
    Set tFixture = "OcuPilot.Test.TaskRunFixture"
    Set tSC = $ClassMethod(tFixture, "EnsureRunProbeTask", .tId)
    Do $$$AssertStatusOK(tSC, "the run probe task exists: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Try {
        Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tLedgerBefore = ##class(OcuPilot.Test.AuditingUpdate).LedgerCount(tUser)
        Do $$$AssertNotEquals(tLedgerBefore, -1, "the ledger reads before the write")
        Set tHistorySince = $ClassMethod(tFixture, "HistoryHighWater")
        Set tRequest = {}
        Do tRequest.%Set("action", "run", "string")
        Do tRequest.%Set("id", tId, "string")
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/tasks.ondemand/action", tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
        Do $$$AssertStatusOK(tSC, "the request completes")
        Do $$$AssertEquals(tStatus, 200, "the screen's run answers 200: " _ $Extract($Get(tBody), 1, 300))
        If tStatus = 200 {
            Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tAnswer.%Get("action"), "updated", "with the updated verb")
            Do $$$AssertEquals(tAnswer.%Get("target").%ToJSON(), "{""type"":""task"",""scope"":""instance"",""id"":""" _ tId _ """}", "and the task's triple")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerCount(tUser), tLedgerBefore, "no ledger row was written")
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).#EVENTAGENTWRITE, "tasks.ondemand.run", .tData), 0, "and no agent-write marker names the run tool")
        Set tLanded = $ClassMethod(tFixture, "AwaitRun", tId, tHistorySince, 180, .tElapsed)
        Do $$$AssertTrue(tLanded, "a Success history row lands within 180 s (waited " _ $Get(tElapsed) _ " s)")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the screen run raised")
    }
    Do $ClassMethod(tFixture, "DeleteRunProbeTask")
    Do $$$AssertEquals($ClassMethod(tFixture, "ProbeCount"), 0, "and the run probe task is gone")
}

}
