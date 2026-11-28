/// <p>Pins Story 24.17 Batch 2's proposals against the namespace they were read in (AD-6, AD-52): the agent's purge of a log, minted in <code>USER</code> and confirmed by a request scoped to
/// <code>HSCUSTOM</code>, acts in <code>USER</code> alone even when <code>HSCUSTOM</code> holds old probes of its own, which are as they were; and a person's Purge scoped to <code>HSCUSTOM</code>
/// acts there alone. Every confirm-time judgment, the fresh read, the days and the vendor call, runs in the proposal's namespace.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropLogPurgeCase</class> needs. It removes every probe it made from both namespaces.</p>
Class OcuPilot.Test.InteropLogPurgeElsewhere Extends OcuPilot.Test.InteropLogPurgeCase
{

/// <p>AC6: the agent's purge of each log, minted in USER and confirmed from HSCUSTOM, deletes USER's old probes and leaves HSCUSTOM's as they were, records its audit row for USER, and its read-back, taken
/// in USER, matches.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropPurgeRun.PortQuery</method> drop the namespace key -- the confirm reaches HSCUSTOM's probes and this goes red.</p>
Method TestThePurgeIsConfirmedInTheNamespaceItWasReadIn()
{
    Set tSC = ..EnableKeys(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purges' governance keys are turned on")
    Try {
        For tKind = "rule", "process" {
            Set tUserOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
            Set tHscOld = ..Probe(tKind, ..#OTHER, 7300, 1)
            Set tUserNew = ..Probe(tKind, ..#SOURCE, 0, 1)
            Do $$$AssertTrue((tUserOld > 0) && (tHscOld > 0) && (tUserNew > 0), tKind _ ": an old probe is stored in each namespace and a current one in USER")
            Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
            Do $$$AssertEquals(..Mint(tKind, 3650, .tReason, .tProposal, .tTurn), "minted", tKind _ ": the purge mints in USER: " _ tReason)
            If '$IsObject($Get(tProposal)) Continue
            Do $$$AssertEquals(tProposal.target.scope _ "|" _ tProposal.target.id, ..#SOURCE _ "|" _ ..#SOURCE, tKind _ ": its target is USER's log")
            Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHER)
            Do $$$AssertEquals(tStatus, 200, tKind _ ": the proposal confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
            Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tUserOld) _ ..Exists(tKind, ..#SOURCE, tUserNew), "01", tKind _ ": USER's old probe is gone and its current one stays")
            Do $$$AssertEquals(..Exists(tKind, ..#OTHER, tHscOld), 1, tKind _ ": and HSCUSTOM's old probe is as it was")
            Do $$$AssertEquals(..OwnRows(tKind, tSince, .tData), 1, tKind _ ": OcuPilot records one ConfigChange")
            Do $$$AssertTrue(tData [ """namespace"":""USER""", tKind _ ": naming USER: " _ tData)
            Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
            Do $ClassMethod(..#FIXTURE, "DropProbes")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC6: a person's Purge on a screen scoped to HSCUSTOM purges HSCUSTOM's log, and USER's old probe of the same kind is as it was.</p>
/// <p>Not a mutation pin of its own: AC6's pin is <method>TestThePurgeIsConfirmedInTheNamespaceItWasReadIn</method>.</p>
Method TestAPersonsPurgeScopedToAnotherNamespaceActsThereAlone()
{
    For tKind = "rule", "process" {
        Set tUserOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set tHscOld = ..Probe(tKind, ..#OTHER, 7300, 1)
        Do $$$AssertEquals(..Act(tKind, 3650, .tAnswer, ..#OTHER), "200 ", tKind _ ": the person's Purge scoped to HSCUSTOM answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals(..Exists(tKind, ..#OTHER, tHscOld) _ ..Exists(tKind, ..#SOURCE, tUserOld), "01", tKind _ ": HSCUSTOM's old probe is gone and USER's stays")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

}
