Include %occErrors

/// <p>Unit tests for <class>OcuPilot.Kernel.State.Convo</class> and
/// <class>OcuPilot.Kernel.State.Entry</class> (Story 4.5): the per-conversation lock protocol,
/// ownership, the entry cap, and the history bound. Spawn-free and safe on the dev instance --
/// nothing here spawns a job, arms a principal, or reaches over HTTP.</p>
/// <p><b>Why no test induces a real lock timeout.</b> IRIS locks are re-entrant per process: the
/// same process cannot block itself by re-locking a row it already holds, so a genuine lock
/// conflict needs a second process, which this class deliberately does not spawn. Instead
/// <method>TestLockConflictIsClassifiedDifferentlyFromAPersistenceFailure</method> pins
/// <method>OcuPilot.Kernel.State.Base.IsLockConflict</method> -- the exact predicate
/// <method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method> uses to set
/// <var>pLockConflict</var> -- directly against a status built with the real error code
/// (<parameter>$$$LockFailedToAcquireExclusive</parameter>, 5803) and against an unrelated one, so
/// the classification itself is proven correct without contention.</p>
/// <p>The reference <code>^OcuPilot.Kernel.State.BaseD(&lt;id&gt;)</code> that
/// <method>TestLoadOrCreateLocksTheRowUntilTheReferenceIsDropped</method> reads is
/// <class>OcuPilot.Kernel.State.Convo</class>'s and every other <package>OcuPilot.Kernel.State</package>
/// class's shared physical storage global (verified live against the compiled class's own
/// generated code, and against <code>^$LOCK</code> read back with the row's own id) -- an
/// implementation detail of the compiler's storage default, not something this class or
/// <class>OcuPilot.Kernel.State.Base</class> ever names.</p>
Class OcuPilot.Test.Convo Extends %UnitTest.TestCase
{

/// <p>Both branches of <method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method> answer an OREF
/// at concurrency 4, with an <code>$$$OK</code> status and no lock conflict; the load branch's
/// answer is the same row the create branch minted.</p>
Method TestLoadOrCreateReturnsAnOrefAtConcurrencyFourFromBothBranches()
{
    Set tUser = "OcuPilotProbeConvoUser"
    Set tCreated = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tCreateStatus, .tCreateConflict)
    Do $$$AssertStatusOK(tCreateStatus, "create answers OK")
    Do $$$AssertTrue($IsObject(tCreated), "create answers an OREF")
    Do $$$AssertEquals(tCreateConflict, 0, "create reports no lock conflict")
    If $IsObject(tCreated) Do $$$AssertEquals(tCreated.%Concurrency, 4, "create's OREF is at concurrency 4")
    Set tKey = $Select($IsObject(tCreated): tCreated.ConvKey, 1: "")
    Set tCreated = ""

    Set tLoaded = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(tKey, tUser, 5, .tLoadStatus, .tLoadConflict)
    Do $$$AssertStatusOK(tLoadStatus, "load answers OK")
    Do $$$AssertTrue($IsObject(tLoaded), "load answers an OREF")
    Do $$$AssertEquals(tLoadConflict, 0, "load reports no lock conflict")
    If $IsObject(tLoaded) {
        Do $$$AssertEquals(tLoaded.%Concurrency, 4, "load's OREF is at concurrency 4")
        Do $$$AssertEquals(tLoaded.ConvKey, tKey, "load answers the row create minted")
    }
    Set tLoaded = ""
    If tKey '= "" Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p>While <method>LoadOrCreate</method>'s OREF is held, <code>^$LOCK</code> shows this process's
/// <code>$JOB</code> as an owner of the row's own storage reference; dropping the OREF clears it.</p>
Method TestLoadOrCreateLocksTheRowUntilTheReferenceIsDropped()
{
    Set tUser = "OcuPilotProbeConvoUser"
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tStatus, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "the conversation opened")
    If '$IsObject(tConvo) Quit
    Set tId = tConvo.%Id()
    Set tGlobalRef = $Name(^OcuPilot.Kernel.State.BaseD(tId))
    Do $$$AssertTrue($Data(^$LOCK(tGlobalRef, $Job)) > 0, "this job owns the row's lock")
    Set tKey = tConvo.ConvKey
    Set tConvo = ""
    Do $$$AssertEquals($Data(^$LOCK(tGlobalRef)), 0, "dropping the reference clears the lock")
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p><method>OcuPilot.Kernel.State.Base.IsLockConflict</method> answers 1 for IRIS's own
/// lock-timeout status and 0 for any other failure -- the classification
/// <method>LoadOrCreate</method>'s <var>pLockConflict</var> is built from.</p>
Method TestLockConflictIsClassifiedDifferentlyFromAPersistenceFailure()
{
    Set tTimeoutStatus = $$$ERROR($$$LockFailedToAcquireExclusive, "OcuPilot.Kernel.State.Convo")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Base).IsLockConflict(tTimeoutStatus), "a real lock-timeout status is a lock conflict")
    Set tOtherStatus = $$$ERROR($$$GeneralError, "a persistence problem, not a lock")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Base).IsLockConflict(tOtherStatus), "an unrelated failure is not")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Base).IsLockConflict($$$OK), "an OK status is not a conflict")
}

/// <p>An id naming no conversation is a persistence-style failure, never a lock conflict.</p>
Method TestAnUnknownIdIsAPersistenceFailureNotALockConflict()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("0123456789abcdef0123456789abcdef", "OcuPilotProbeConvoUser", 5, .tStatus, .tConflict)
    Do $$$AssertTrue('$IsObject(tConvo), "an unknown id answers no OREF")
    Do $$$AssertStatusNotOK(tStatus, "with an error status")
    Do $$$AssertEquals(tConflict, 0, "and no lock conflict")
}

/// <p><method>OcuPilot.Kernel.State.Convo.GuardedOwner</method> matches the creating user exactly
/// and answers not-found for any other user or an unknown id.</p>
Method TestGuardedOwnerMatchesExactly()
{
    Set tUser = "OcuPilotProbeConvoOwner"
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tStatus, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "the conversation opened")
    Set tKey = $Select($IsObject(tConvo): tConvo.ConvKey, 1: "")
    Set tConvo = ""
    If tKey = "" Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedOwner(tKey, tUser, .tOwned), "the owner check completes")
    Do $$$AssertTrue(tOwned, "the creating user owns it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedOwner(tKey, "OcuPilotProbeConvoOwnerOTHER", .tOtherOwned), "the foreign check completes")
    Do $$$AssertTrue('tOtherOwned, "another user does not own it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedOwner("0123456789abcdef0123456789abcdef", tUser, .tUnknownOwned), "the unknown-id check completes")
    Do $$$AssertTrue('tUnknownOwned, "an unknown id owns to nobody")
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p><method>OcuPilot.Kernel.State.Convo.AppendEntry</method> re-caps a step array longer than
/// <parameter>OcuPilot.Kernel.Agent.Limits.MAXSTEPS</parameter> defensively, even though its own
/// caller (<method>OcuPilot.Kernel.State.Step.GuardedRows</method>) never hands it more.</p>
Method TestAppendEntryCapsAnOverLongStepArray()
{
    Set tUser = "OcuPilotProbeConvoUser"
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tStatus, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "the conversation opened")
    If '$IsObject(tConvo) Quit
    Set tKey = tConvo.ConvKey
    Set tMax = +$Parameter("OcuPilot.Kernel.Agent.Limits", "MAXSTEPS")
    Set tSteps = []
    For tI = 1:1:tMax + 5 {
        Set tStep = {}
        Do tStep.%Set("seq", tI, "number")
        Do tSteps.%Push(tStep)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "many steps", "completed", "done", "", 0, tSteps, 0, "OcuPilot.Kernel.Agent.Limits"), "append completes")
    Set tConvo = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows), "the rows read back")
    Do $$$AssertEquals(tRows.%Size(), 1, "one entry was appended")
    Do $$$AssertEquals(tRows.%Get(0).steps.%Size(), tMax, "capped to the step limit even though the caller sent more")
    Do $$$AssertEquals(tRows.%Get(0).stepsDropped, 5, "the trimmed count is added to stepsDropped, not silently discarded")
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p><method>OcuPilot.Kernel.State.Convo.HistoryMessages</method> skips a turn with no reply,
/// contributes a completed turn's message then its reply, and drops the oldest whole turns from
/// the front until the total fits -- never a partial turn.</p>
Method TestHistoryDropsOldestTurn()
{
    Set tUser = "OcuPilotProbeConvoUser"
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tStatus, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "the conversation opened")
    If '$IsObject(tConvo) Quit
    Set tKey = tConvo.ConvKey

    ; Turn 1: 10 + 10 = 20 characters, completed with a reply.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, ..TR(1,"0123456789"), "completed", ..TR(1,"0123456789"), "", 0, [], 0, "OcuPilot.Kernel.Agent.Limits"), "turn 1 appends")
    ; Turn 2: stopped, no reply -- must never appear in history.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "stopped turn", "stopped", "", "TURN.STOPPED", 3, [], 0, "OcuPilot.Kernel.Agent.Limits"), "turn 2 appends")
    ; Turn 3: 10 + 10 = 20 characters, completed with a reply.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, ..TR(3,"0123456789"), "completed", ..TR(3,"0123456789"), "", 0, [], 0, "OcuPilot.Kernel.Agent.Limits"), "turn 3 appends")

    ; A budget of 25 fits turn 3 (20 chars) but not both turn 1 and turn 3 (40 chars): the
    ; oldest whole turn (1) is dropped, never truncated into a partial message.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).HistoryMessages(tConvo, 25, .tMessages), "history bound completes")
    Do $$$AssertEquals(tMessages.%Size(), 2, "only turn 3's pair survives the 25-character bound")
    Do $$$AssertEquals(tMessages.%Get(0).role _ "|" _ tMessages.%Get(0).content, "user|" _ ..TR(3,"0123456789"), "turn 3's message, not turn 1's")
    Do $$$AssertEquals(tMessages.%Get(1).role _ "|" _ tMessages.%Get(1).content, "assistant|" _ ..TR(3,"0123456789"), "then turn 3's reply")

    ; A generous budget keeps both completed turns, oldest first, and still skips the stopped one.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).HistoryMessages(tConvo, 1000, .tAllMessages), "the wide bound completes")
    Do $$$AssertEquals(tAllMessages.%Size(), 4, "both completed turns, no stopped turn")
    Do $$$AssertEquals(tAllMessages.%Get(0).content, ..TR(1,"0123456789"), "oldest first")
    Do $$$AssertEquals(tAllMessages.%Get(2).content, ..TR(3,"0123456789"), "then the newer turn")

    Set tConvo = ""
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p>A repeated character run of length 10, so a test fixture reads as data rather than as a
/// second literal to keep in sync with itself.</p>
ClassMethod TR(pSeed As %Integer, pDigits As %String) As %String [ Private ]
{
    Quit $Translate($Justify("", 10), " ", $Extract(pDigits, (pSeed # $Length(pDigits)) + 1))
}

}
