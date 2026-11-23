/// <p>Pins Story 24.16 Batch 4's archive run end to end against back-dated probe messages in <code>HSCUSTOM</code>, archived into <code>USER</code> (AD-6, AD-7, AD-14, AD-15, AD-22,
/// AD-51, AD-53, AD-58, AD-59, AD-62): a person's Run archive and the agent's confirmed proposal each move, through the vendor's <code>Ens.Archive.Manager.DoArchive</code>, every
/// message older than the days, whatever its status, into the target under its own message id with its body as text (an HL7 message as its segments, an object that writes XML as its
/// XML, a stream or no body as its class name and id, which the vendor measured), delete it from the source and keep the one made now. The history reads the run's five counts and
/// the error list reads none. The vendor audits no run, so OcuPilot's own <code>ConfigChange</code> is the record, naming both namespaces, the days and the counts. With 0 days
/// everything up to the end of today is moved. A setting changed after the mint closes the agent's proposal as moved, the history is always eight rows, and the script form renders
/// the guarded run and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropArchiveCase</class> needs. Every probe is back-dated 7,300 days and every run is given 3,650, so
/// nothing but a probe is old enough to move.</p>
Class OcuPilot.Test.InteropArchiveControl Extends OcuPilot.Test.InteropArchiveCase
{

/// <p>What the archived copy of each probe kind holds in the target, as the vendor measured it: its body class, and the text it saved.</p>
Method AssertLanded(ByRef pIds, pWhere As %String)
{
    Set tFx = ..#FIXTURE
    Set tTarget = ..#TARGET
    Do $$$AssertEquals($ClassMethod(tFx, "HeaderIds", tTarget), ..OldIds(.pIds), pWhere _ ": each back-dated probe is in USER under its own message id")
    Do $$$AssertEquals($ClassMethod(tFx, "HeaderIds", ..#SOURCE), pIds("current"), pWhere _ ": and only the one made now is left in HSCUSTOM")
    Set tHl7 = $ClassMethod(tFx, "BodyOf", tTarget, pIds("hl7"))
    Do $$$AssertTrue(($Piece(tHl7, "|", 1) = "Ens.Archive.MessageBody") && ($Piece(tHl7, "|", 3, *) [ $ClassMethod(tFx, "Hl7Text")), pWhere _ ": the HL7 message is saved as its segments")
    Set tXml = $ClassMethod(tFx, "BodyOf", tTarget, pIds("xml"))
    Do $$$AssertTrue(($Piece(tXml, "|", 1) = "Ens.Archive.MessageBody") && ($Piece(tXml, "|", 3, *) [ "<StringRequest>") && ($Piece(tXml, "|", 3, *) [ $ClassMethod(tFx, "XmlText")), pWhere _ ": the object that writes XML is saved as its XML")
    Set tChars = $ClassMethod(tFx, "BodyOf", tTarget, pIds("chars"))
    Do $$$AssertTrue(($Piece(tChars, "|", 1) = "Ens.Archive.MessageBody") && ($Piece(tChars, "|", 3, *) [ "%Stream.GlobalCharacter::") && ($Piece(tChars, "|", 3, *) '[ $Parameter(tFx, "SENTINEL")), pWhere _ ": a stream is kept as its class name and id alone")
    Do $$$AssertTrue($Piece($ClassMethod(tFx, "BodyOf", tTarget, pIds("none")), "|", 3, *) [ "::", pWhere _ ": a message with no body is kept as the empty class name and id")
    Do $$$AssertTrue($Piece($ClassMethod(tFx, "BodyOf", tTarget, pIds("queued")), "|", 3, *) [ "::", pWhere _ ": a Queued message is moved like the others")
    Do $$$AssertEquals($ClassMethod(tFx, "BodyOf", ..#SOURCE, pIds("hl7")) _ "|" _ $ClassMethod(tFx, "BodyOf", ..#SOURCE, pIds("xml")), "<none>|<none>", pWhere _ ": the moved headers are gone from HSCUSTOM")
    Do $$$AssertTrue($Piece($ClassMethod(tFx, "BodyOf", ..#SOURCE, pIds("current")), "|", 3, *) [ $ClassMethod(tFx, "XmlText"), pWhere _ ": and the one made now keeps its body")
    Do $$$AssertEquals($ClassMethod(tFx, "BodiesLeft"), 1, pWhere _ ": no moved body is left in HSCUSTOM, and the current one is")
    Do $$$AssertEquals(..HistoryValue("Total messages processed") _ "," _ ..HistoryValue("Total messages archived") _ "," _ ..HistoryValue("Total message headers deleted") _ "," _ ..HistoryValue("Total message bodies deleted") _ "," _ ..HistoryValue("Total number of errors"), "6,5,5,3,0", pWhere _ ": the history reads the run's five counts")
    Do $$$AssertTrue((..HistoryValue("Archive start time") '= "") && (..HistoryValue("Archive stop time") '= "") && (..HistoryValue("Archive status") = "idle"), pWhere _ ": with its times, and the status idle")
    Do $$$AssertEquals(..ErrorIds(.tErrors) _ "|" _ tErrors, "|0", pWhere _ ": and the error list reads no error")
}

/// <p>The three screens are declared as the plan places them, and the Archive manager's one row action is Run archive.</p>
/// <p>Mutation (Rule 19): change the Archive manager screen's row action id to <code>run</code> -- this goes red.</p>
Method TestTheRunIsDeclaredAsTheRowActionOfTheArchiveManager()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropArchiveList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.rowActions.%Get(0).id, "|1|archive", "its one action is the row action Run archive, which the action route admits")
    Do $$$AssertEquals(tDeclaration.classicPage, "EnsPortal.ArchiveManager", "its classic page")
    Set tRun = "OcuPilot.Screen.Tool.InteropArchiveRun"
    Do $$$AssertEquals($Parameter(tRun, "TOOLNAME") _ "|" _ $Parameter(tRun, "DESTRUCTIVE") _ "|" _ $Parameter(tRun, "WRITETYPE"), "interop.archive.run|1|ARCHIVE", "the tool is destructive")
    Do $$$AssertEquals($Parameter(tRun, "FINGERPRINTSUBJECT"), "Target,DaysToArchive,Classname,Namespace,Running", "and fingerprints what the run will use")
}

/// <p>The Archive errors screen is declared as the plan places it: in the Interoperability area at side bar 21, read-only with no action and no entity type, over the classic page's own
/// <code>%Ens_ArchiveManager:READ</code> beside the portal.</p>
/// <p>Mutation (Rule 19): give the Archive errors screen a row action -- this goes red.</p>
Method TestTheErrorsScreenIsDeclaredReadOnly()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropArchiveErrorList).DeclarationJson(.tErrors)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tErrors)) Quit
    Do $$$AssertEquals(tErrors.route _ "|" _ tErrors.sideBarPosition _ "|" _ tErrors.entityType _ "|" _ tErrors.rowActions.%Size() _ "|" _ tErrors.toolIdentifier, "interoperability/archive-errors|21||0|interop.archiveerrors", "its route, place, no entity type, no action and tool identifier")
    Do $$$AssertEquals(tErrors.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ArchiveManager"",""permission"":""READ""}]", "its pairs are the classic page's")
}

/// <p>AC2: a person's Run archive and the agent's confirmed proposal each move the back-dated probes of every body kind into USER under their own ids, with their bodies as
/// the vendor saves them, delete them from HSCUSTOM and keep the one made now; the Archive manager reads the run's counts and the Archive errors list reads none. Each records one
/// <code>ConfigChange</code> naming both namespaces, the days, the counts and that the run completed; the vendor records none. The state read before the run counts what it would move
/// (the vendor's own rule, which the moved ids equal). The agent's card is destructive, states the run's consequence and ships behind a key that is off; its confirm is marked and
/// ledgered once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveRun</method> answer 200 without calling <method>OcuPilot.Port.InteropPort.VendorArchive</method> -- this goes
/// red.</p>
Method TestARunFromEitherCallerMovesTheOldMessagesIntoTheTarget()
{
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged")
    Do ..Verdict("Archive", "ARCHIVESTATE", .tState)
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.Target _ "|" _ tState.Classname _ "|" _ tState.DaysToArchive _ "|" _ tState.Running _ "|" _ tState.Total _ "|" _ tState.ToArchive, 1: ""), ..#TARGET _ "|Ens.Archive.Manager|3650|0|6|5", "the state read names what the run would use and move, by the vendor's own rule")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..ActRun(.tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Run archive answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "updated|interop-archive", "publishing the updated event for the archive")
    Do ..AssertLanded(.tIds, "the person's run")
    Do $$$AssertEquals(..OwnRows(tSince, "interop-archive", .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ ..#SOURCE) && (tData [ """target"":""USER""") && (tData [ """daysToArchive"":3650") && (tData [ """processed"":6") && (tData [ """archived"":5") && (tData [ """headersDeleted"":5") && (tData [ """bodiesDeleted"":3") && (tData [ """errors"":0") && (tData [ """completed"":true"), "naming both namespaces, the days, the five counts and that the run completed: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, "Archive"), 0, "and the vendor records none")
    Do ..Verdict("Archive", "ARCHIVESTATE", .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.Total _ "|" _ tAfter.ToArchive, 1: ""), "1|0", "the state read now counts the one message left and none to move")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged again, from nothing, for the agent's run")
    Do ..Settings()
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..MintRun(.tReason, .tProposal, .tTurn), "minted", "the agent's run mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-archive|" _ ..#SOURCE _ "|" _ ..#SOURCE, "the target is the namespace")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.ARCHIVE.RUN|1", "its consequence says what a run moves, and it is destructive")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), "", "nothing is moved by the mint")
        Set tSC = ..Confirm(tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tConfirmStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action, 1: ""), "1|updated", "marked (AD-15)")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropItemControl).LedgerCount(tTurn, ..#RUNKEY), 1, "the confirmed write is in the ledger once")
        Do ..AssertLanded(.tIds, "the agent's run")
        Do $$$AssertEquals(..OwnRows(tSince, "interop-archive", .tData), 1, "OcuPilot records one ConfigChange for the agent's run")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: with 0 days a message made now is moved, because everything up to the end of today goes, and a message dated tomorrow stays.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveCutoff</method> keep the days it is given plus one -- this goes red.</p>
Method TestZeroDaysMovesEverythingUpToTheEndOfToday()
{
    Do ..Settings(..#TARGET, 0)
    Set tOld = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Old")
    Set tNow = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Now", 0)
    Set tTomorrow = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Tomorrow", -1)
    Do $$$AssertTrue((tOld > 0) && (tNow > 0) && (tTomorrow > 0), "three probes are arranged: back-dated, made now and dated tomorrow")
    Do $$$AssertEquals(..RunVerdict(), "200 ", "the run answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), tOld _ "," _ tNow, "the old message and the one made now are in USER")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), tTomorrow, "and the one dated tomorrow is the one left")
}

/// <p>AC2, AC3: a setting changed after the agent's run was minted closes the confirm target-changed, and nothing is moved.</p>
/// <p>Mutation (Rule 19): drop <code>DaysToArchive</code> from <parameter>OcuPilot.Screen.Tool.InteropArchiveRun.FINGERPRINTSUBJECT</parameter> -- this goes red.</p>
Method TestASettingChangedAfterTheMintClosesTheConfirmTargetChanged()
{
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Try {
        Do $$$AssertEquals(..MintRun(.tReason, .tProposal, .tTurn), "minted", "the agent's run mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do ..Settings(..#TARGET, 3000)
        Set tSC = ..Confirm(tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tConfirmStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "|" _ ..OldIds(.tIds) _ "," _ tIds("current"), "and nothing was moved")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: before any run the history is the classic page's eight rows, in its order, so Run archive is reachable on a fresh namespace; reading the history and the state writes
/// nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListArchiveHistory</method> answer no row when no run is recorded -- this goes red.</p>
Method TestTheHistoryIsAlwaysTheEightRowsAndReadingItWritesNothing()
{
    Do ..Verdict("Archive", "LIST", .tRows)
    Set tNames = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: "|") _ tRow.Name
        }
    }
    Do $$$AssertEquals(tNames, "Archive start time|Archive stop time|Total messages processed|Total messages archived|Total message headers deleted|Total message bodies deleted|Total number of errors|Archive status", "eight rows, in the classic page's order")
    Do $$$AssertEquals(..HistoryValue("Total messages processed") _ "|" _ ..HistoryValue("Archive status") _ "|" _ ..HistoryValue("Archive start time"), "0|idle|", "none has run: no times, no counts, idle")
    Do ..Verdict("Archive", "ARCHIVESTATE", .tState)
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.Target _ "|" _ tState.Classname _ "|" _ tState.DaysToArchive _ "|" _ tState.Running, 1: ""), "|Ens.Archive.Manager|30|0", "the state read answers the vendor's defaults")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveTrees"), ..#EMPTYTREES, "and neither wrote a node")
}

/// <p>AC2: the script form of the run names the namespace, reads the three settings, guards each refusal in one line, takes the vendor's lock at once, calls
/// <code>Ens.Archive.Manager.DoArchive</code> while it is held and lets it go, and runs nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveSnippet</method> drop the lock line -- this goes red.</p>
Method TestTheScriptFormRendersTheGuardedRunAndRunsNothing()
{
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged")
    Kill tScript
    Set tScript("namespace") = ..#SOURCE
    Set tScript("id") = ..#SOURCE
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Archive", "ARCHIVE", .tScript, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step is rendered")
    Set tText = ..StepText(tSteps)
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""HSCUSTOM""", "it names the namespace: " _ tText)
    Do $$$AssertTrue(tText [ "GetArchiveParameters(.tTarget, .tClass, .tDays)", "it reads the three settings: " _ tText)
    For tCode = "ARCHIVECLASS", "ARCHIVENOTARGET", "ARCHIVETOOMANY", "ARCHIVETAKEN", "ARCHIVERUNNING" {
        Set tReason = ##class(OcuPilot.Api.InteropError).ReasonFor($Parameter("OcuPilot.Api.InteropError", tCode))
        Do $$$AssertTrue(tText [ tReason, tCode _ " is a guard line: " _ tText)
    }
    Do $$$AssertTrue(tText [ "Lock +^Ens.ArchiveManager(""lock""):0", "it takes the vendor's lock at once: " _ tText)
    Do $$$AssertTrue(tText [ "Set tSC = ##class(Ens.Archive.Manager).DoArchive()", "and calls the vendor's run: " _ tText)
    Do $$$AssertTrue(tText [ "Lock -^Ens.ArchiveManager(""lock"")", "and lets the lock go: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "|" _ ..OldIds(.tIds) _ "," _ tIds("current"), "no draft moved a message")
}

}
