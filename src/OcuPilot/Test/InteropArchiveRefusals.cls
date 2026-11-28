/// <p>Pins Story 24.16 Batch 4's archive refusals end to end against back-dated probe messages in <code>HSCUSTOM</code>, archived into <code>USER</code> (AD-6, AD-8, AD-39, AD-62): a
/// run while the vendor's lock is held by a child job this class starts and ends is 409 <code>INTEROP.ARCHIVE.RUNNING</code>; a target that is unset, not listed or the namespace itself
/// is 409 <code>NOTARGET</code>; a stored class other than the vendor's is 409 <code>CLASS</code>; a namespace holding more messages than the cap is 409 <code>TOOMANY</code> and one
/// at the cap runs; a target that already holds an id the run would move is 409 <code>TAKEN</code> and keeps its message; each from the port, the person's Run archive and the agent's
/// mint, before any vendor call and with nothing moved. A run during which the vendor logs an error for a message, or answers an error status, or raises, is 500
/// <code>INTERNAL</code>, never 200, records a row that did not complete, and leaves the error list naming the message; no log line carries a vendor text, each is written in the namespace
/// the call came from, and the lock is free on every exit, a vendor that was cut short with an extra hold on it included. The gate runs as real principals in a child process, each
/// refused by name before any vendor call.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropArchiveCase</class> needs, and <parameter>ARMINGVARIABLE</parameter>, because it creates and deletes users
/// and roles named <code>OcuP2416a*</code>, and lists HSCUSTOM in <code>^%SYS("Ensemble","InstalledNamespace")</code> for one test. It removes every probe, principal, role and list entry it
/// creates and ends the lock-holding job it starts.</p>
Class OcuPilot.Test.InteropArchiveRefusals Extends OcuPilot.Test.InteropArchiveCase
{

Parameter CAPSEAM = "OcuPilot.Test.InteropArchiveCapSeam";

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The principals, each <code>&lt;user&gt;:&lt;its pairs&gt;</code>, separated by <code>;</code>: every one holds the pairs to run the vendor's code from the install namespace.</p>
Parameter PRINCIPALS = "OcuP2416aExact:%Development:U,%Ens_Portal:U,%Ens_ArchiveManager:RW,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2416aNoWrite:%Development:U,%Ens_Portal:U,%Ens_ArchiveManager:R,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2416aDbRead:%Development:U,%Ens_Portal:U,%Ens_ArchiveManager:RW,%DB_HSCUSTOM:R,%DB_USER:RW;OcuP2416aTargetRead:%Development:U,%Ens_Portal:U,%Ens_ArchiveManager:RW,%DB_HSCUSTOM:RW,%DB_USER:R;OcuP2416aTargetWrite:%Development:U,%Ens_Portal:U,%Ens_ArchiveManager:RW,%DB_HSCUSTOM:RW,%DB_USER:W";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;type&gt;|&lt;endpoint&gt;</code>.</p>
Parameter LEGS = "history|LIST|Archive,state|ARCHIVESTATE|Archive,run|ARCHIVE|Archive,settings|LIST|ArchiveSettings,set|SETTINGSET|ArchiveSettings";

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
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2416a" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

/// <p>Start the child job that holds the vendor's lock of the source until told to stop, and wait until it does; answer <code>1</code> when it holds it.</p>
ClassMethod StartHolder() As %Boolean
{
    Kill ^IRIS.Temp.OcuProbe2416ArcHold
    Job ##class(OcuPilot.Test.InteropArchiveFixture).HoldLock(..#SOURCE)::10
    If '$Test Quit 0
    For tI = 1:1:100 {
        If $Get(^IRIS.Temp.OcuProbe2416ArcHold) = 1 Quit
        Hang 0.1
    }
    Quit ($Get(^IRIS.Temp.OcuProbe2416ArcHold) = 1)
}

/// <p>Tell the holder to stop and wait until it has let go.</p>
ClassMethod StopHolder() As %Boolean
{
    Set ^IRIS.Temp.OcuProbe2416ArcHold = "stop"
    For tI = 1:1:100 {
        If $Get(^IRIS.Temp.OcuProbe2416ArcHold) = 2 Quit
        Hang 0.1
    }
    Quit ($Get(^IRIS.Temp.OcuProbe2416ArcHold) = 2)
}

/// <p>The three callers' answer to a run the namespace refuses with <var>pCode</var>: the port's, the person's Run archive's and the agent's mint's, each by the same code and the published
/// sentence, <var>pWhere</var> naming the state.</p>
Method AssertRefusedByAllThree(pCode As %String, pWhere As %String)
{
    Set tReason = ##class(OcuPilot.Api.InteropError).ReasonFor(pCode)
    Do $$$AssertEquals(..RunVerdict(.tFault), "409 " _ pCode, pWhere _ ": the port refuses the run")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), tReason, pWhere _ ": with the published sentence")
    Set tText = ..ActRun(.tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: tText), pCode _ " " _ tReason, pWhere _ ": the person's Run archive is refused with it")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Do $$$AssertEquals(..MintRun(.tMintReason, .tProposal, .tTurn), pCode, pWhere _ ": the agent's mint is refused with it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC3: a run while the vendor's lock is held by another process is 409 <code>INTEROP.ARCHIVE.RUNNING</code> from the port, the person's Run archive and the agent's mint, with
/// the published sentence, and moves nothing; the state read says a run is running; once the holder lets go the run goes ahead and the lock is free after it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveTake</method> answer <code>1</code> whatever the lock holds -- the port's leg goes red, answered 500 by the vendor's
/// own lock wait.</p>
Method TestARunWhileTheLockIsHeldIsRefusedAndMovesNothing()
{
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged")
    Do $$$AssertTrue(..StartHolder(), "the lock-holding job starts and holds the vendor's lock")
    Do ..AssertRefusedByAllThree(##class(OcuPilot.Api.InteropError).#ARCHIVERUNNING, "a running archive")
    Do ..Verdict("Archive", "ARCHIVESTATE", .tState)
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.Running, 1: ""), 1, "the state read says a run is running")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "|" _ ..OldIds(.tIds) _ "," _ tIds("current"), "nothing was moved")
    Do $$$AssertTrue(..StopHolder(), "the holder lets go and ends")
    Do $$$AssertEquals(..RunVerdict(), "200 ", "and the run then goes ahead")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), ..OldIds(.tIds), "moving the old messages")
    Do $$$AssertTrue('$ClassMethod(..#FIXTURE, "LockHeld", ..#SOURCE), "and letting go of the lock when it has run")
}

/// <p>AC3: a run with no target stored, one stored that the classic page does not list and one naming the namespace itself are 409 <code>INTEROP.ARCHIVE.NOTARGET</code>; a stored class
/// other than the vendor's is 409 <code>INTEROP.ARCHIVE.CLASS</code>, judged first and with no code of that class run; each from all three callers, with nothing moved and the history
/// still reading no run.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveRefusal</method> skip the class test -- the class leg goes red.</p>
Method TestNoTargetAndAClassOtherThanTheVendorsAreRefused()
{
    Do $$$AssertTrue(..Arrange(.tIds), "the probe messages are arranged")
    Set tNotarget = ##class(OcuPilot.Api.InteropError).#ARCHIVENOTARGET
    Do ..Settings("<absent>")
    Do ..AssertRefusedByAllThree(tNotarget, "no target stored")
    Do ..Settings("NOPE")
    Do ..AssertRefusedByAllThree(tNotarget, "a target the classic page does not list")
    Do ..Settings(..#SOURCE)
    Do ..AssertRefusedByAllThree(tNotarget, "the namespace itself")
    Do ..Settings(..#TARGET, ..#RUNDAYS, "User.Probe.Archiver")
    Do ..AssertRefusedByAllThree(##class(OcuPilot.Api.InteropError).#ARCHIVECLASS, "a class of its own")
    Do ..Settings("<absent>", ..#RUNDAYS, "User.Probe.Archiver")
    Do $$$AssertEquals(..RunVerdict(.tFault), "409 " _ ##class(OcuPilot.Api.InteropError).#ARCHIVECLASS, "the class is judged before the target")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "|" _ ..OldIds(.tIds) _ "," _ tIds("current"), "nothing was moved")
    Do $$$AssertEquals(..HistoryValue("Total messages processed") _ "|" _ ..HistoryValue("Archive start time"), "0|", "and no run was recorded: no vendor code ran")
}

/// <p>AC3: a namespace holding exactly the cap's number of headers runs, and one holding one more is refused whole, 409 <code>INTEROP.ARCHIVE.TOOMANY</code>, from all three callers, with
/// nothing moved. The cap is lowered to three by <class>OcuPilot.Test.InteropArchiveCapSeam</class>; the shipped one is five thousand, a named limit, and the shipped port's own judgment
/// passes five thousand headers and refuses five thousand and one.</p>
/// <p>Mutation (Rule 19): change the compare in <method>OcuPilot.Port.InteropPort.ArchiveRefusal</method> from <code>&gt;</code> to <code>&gt;=</code> -- the at-the-cap legs go red; drop
/// the cap's line from it -- the one-over legs go red.</p>
Method TestTheCapRunsAtTheCapAndRefusesOneOver()
{
    Do ..Settings()
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AllHeaders", ..#SOURCE), 0, "HSCUSTOM holds no header of its own, so the probes are all there is")
    Do $$$AssertEquals($Parameter(..#PORT, "ARCHIVEMAXMESSAGES"), 5000, "the shipped cap is five thousand")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ArchiveRefusal", ..#SOURCE, 0, "Ens.Archive.Manager", ..#TARGET, 5000), "", "the shipped port takes five thousand headers")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ArchiveRefusal", ..#SOURCE, 0, "Ens.Archive.Manager", ..#TARGET, 5001), ##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY, "and refuses five thousand and one")
    For tI = 1:1:3 {
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Cap" _ tI) > 0, "probe " _ tI _ " is stored")
    }
    Do $$$AssertEquals(..RunVerdict(.tFault, ..#CAPSEAM), "200 ", "three headers, at the cap, run")
    Do $$$AssertEquals($Length($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), ",") _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "3|", "and all three are in USER")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do ..Settings()
    For tI = 1:1:4 {
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Over" _ tI) > 0, "probe " _ tI _ " is stored")
    }
    Do $$$AssertEquals(..RunVerdict(.tFault, ..#CAPSEAM), "409 " _ ##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY, "four headers, one over, are refused whole")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), ##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $Length($ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), ","), "|4", "and nothing was moved")
    Do ..Verdict("Archive", "ARCHIVESTATE", .tState, .tStateFault, , , ##class(OcuPilot.Port.InteropPort).#TYPEARCHIVE, , ..#CAPSEAM)
    Do $$$AssertEquals($Select($IsObject($Get(tStateFault)): tStateFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY, "the review is refused with it too")
    Do $$$AssertEquals(..RunVerdict(), "200 ", "and the shipped port, whose cap is five thousand, runs the same four")
}

/// <p>AC3: a target that already holds a header with the id of a back-dated message is 409 <code>INTEROP.ARCHIVE.TAKEN</code>: nothing is moved, and the target's own message is as it
/// was, which the vendor would have overwritten without a word (measured).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveTaken</method> answer no id -- this goes red: the target's message is overwritten.</p>
Method TestATargetHoldingAMovingIdIsRefusedAndKeepsItsMessage()
{
    Do ..Settings()
    Set tOld = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Old")
    Set tOther = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "none", "Other")
    Do $$$AssertTrue((tOld > 0) && (tOther > 0), "two back-dated probes are stored")
    Set tHeld = $ClassMethod(..#FIXTURE, "StoreWithId", ..#TARGET, tOther, "Taken", 0)
    Do $$$AssertEquals(tHeld, tOther, "USER holds a message of the id of the second")
    Set tTaken = ##class(OcuPilot.Api.InteropError).#ARCHIVETAKEN
    Do $$$AssertEquals(..RunVerdict(.tFault), "409 " _ tTaken, "the port refuses the run")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), ##class(OcuPilot.Api.InteropError).ReasonFor(tTaken), "with the published sentence")
    Set tText = ..ActRun(.tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tText), tTaken, "and so does the person's Run archive")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), tOld _ "," _ tOther, "nothing left HSCUSTOM")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "SourceOf", ..#TARGET, tOther), tOther _ "|" _ $Parameter(..#FIXTURE, "MARKER") _ "SrcTaken", "and USER's own message was not overwritten")
}

/// <p>AC4: a message the vendor logs an error for makes the run partial: the others are moved, the answer is 500 <code>INTERNAL</code> from the port, the person's Run archive and the
/// agent's confirm, never 200, the audit row reads that the run did not complete and counts the error, and the Archive errors list names the message.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveRun</method> ignore the vendor's error count -- this goes red.</p>
Method TestAMessageTheVendorLogsAnErrorForMakesTheRunPartial()
{
    Do ..Settings()
    Set tGood = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Good")
    Set tBroken = $ClassMethod(..#FIXTURE, "StoreBroken", ..#SOURCE, "Broken")
    Do $$$AssertTrue((tGood > 0) && (tBroken > 0), "a good probe and one naming a body class that does not exist are stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..RunVerdict(.tFault), "500 INTERNAL", "the port answers 500: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..OwnRows(tSince, "interop-archive", .tData), 1, "the run is recorded")
    Do $$$AssertTrue((tData [ """completed"":false") && (tData [ """errors"":1") && (tData [ """archived"":1"), "as one that did not complete, with its error and the message it did archive: " _ tData)
    Do $$$AssertEquals(..ErrorIds(.tCount) _ "|" _ tCount, tBroken _ "|1", "the error list names the message the vendor could not archive")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), tGood, "the good message was moved")
    Do ..Verdict("ArchiveErrors", "LIST", .tRows)
    Do $$$AssertTrue($IsObject($Get(tRows)) && (tRows.%Size() = 1) && (tRows.%Get(0).Description [ "OcuProbe2416.NoSuchBodyClass"), "and the description is the vendor's text, as it gave it")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do ..Settings()
    Set tGood = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Good")
    Set tBroken = $ClassMethod(..#FIXTURE, "StoreBroken", ..#SOURCE, "Broken")
    Set tText = ..ActRun(.tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tText), "INTERNAL", "the person's Run archive answers 500 INTERNAL: " _ tText)
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Do ..Settings()
    Set tGood = $ClassMethod(..#FIXTURE, "Store", ..#SOURCE, "xml", "Good")
    Set tBroken = $ClassMethod(..#FIXTURE, "StoreBroken", ..#SOURCE, "Broken")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Try {
        Do $$$AssertEquals(..MintRun(.tReason, .tProposal, .tTurn), "minted", "the agent's run mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tStatus, 500, "the agent's confirm answers 500, never 200: " _ $Extract($Get(tRaw), 1, 300))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC4: the error list is capped by a named limit (<parameter>OcuPilot.Port.InteropPort.ARCHIVEERRORSMAX</parameter>, two under <class>OcuPilot.Test.InteropArchiveCapSeam</class>), and a
/// caller's <code>maxRows</code> cuts it further; three errors read as three on the shipped port.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListArchiveErrors</method> ignore its cap -- this goes red; answer the error's number as text -- the number leg goes
/// red.</p>
Method TestTheErrorListIsCappedAtItsNamedLimit()
{
    Do $ClassMethod(..#FIXTURE, "SeedErrors", ..#SOURCE, 3)
    Do ..ErrorIds(.tCount)
    Do $$$AssertEquals(tCount, 3, "the shipped port lists the three errors")
    Do ..Verdict("ArchiveErrors", "LIST", .tListed)
    Do $$$AssertEquals($Select($IsObject($Get(tListed)) && (tListed.%Size() > 0): tListed.%GetTypeOf(0) _ "|" _ tListed.%Get(0).%GetTypeOf("ErrorNumber"), 1: ""), "object|number", "each error's number is a number, so the list sorts 2 before 10")
    Do ..ErrorIds(.tCapped, ..#CAPSEAM)
    Do $$$AssertEquals(tCapped, 2, "the lowered cap lists two")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("maxRows") = 1
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ArchiveErrors", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), "200|1", "and a maxRows of one lists one")
    Set tQuery("maxRows") = "0"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ArchiveErrors", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and a maxRows that is not above zero is refused")
}

/// <p>AC3, AC4: a vendor that answers an error status, raises, is cut short with one more hold on its lock, or whose target read raises, is a 500 <code>INTERNAL</code> from the port and never
/// a 200; no line the port logs carries the vendor's text, and each is written in the namespace the call came from, not the one the port had switched to; the audit row of a run the
/// vendor answered with an error reads that it did not complete; the lock is free after each, the extra hold included.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveVendorStatus</method> answer the status it was given -- the status and fault legs go red; remove the loop of
/// <method>OcuPilot.Port.InteropPort.ArchiveRelease</method> -- the lock leg goes red; log the fault inside the Catch of <method>OcuPilot.Port.InteropPort.ArchiveTaken</method> before the
/// namespace is restored -- the target leg goes red.</p>
Method TestAFailedVendorRunIsA500LogsNoVendorTextAndLeavesTheLockFree()
{
    Set tMarker = $Parameter(..#SEAM, "MARKER")
    Do ..Settings()
    For tMode = "status", "fault", "lock", "target" {
        Do $$$AssertTrue(..Arrange(.tIds), tMode _ ": the probe messages are arranged")
        Set ^IRIS.Temp.OcuProbe2416ArcMode = tMode
        Do $ClassMethod(..#SEAM, "ClearLog")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tVerdict = ..RunVerdict(.tFault, ..#SEAM)
        Do $$$AssertEquals(tVerdict, "500 INTERNAL", tMode _ ": the run answers 500")
        Do $$$AssertTrue('$ClassMethod(..#FIXTURE, "LockHeld", ..#SOURCE), tMode _ ": the lock is free after it")
        Set tLog = $ClassMethod(..#SEAM, "LoggedText")
        Do $$$AssertTrue(tLog '= "", tMode _ ": the failure is logged")
        Do $$$AssertTrue(tLog '[ tMarker, tMode _ ": the log carries no vendor text: " _ tLog)
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ tMarker), tMode _ ": and neither does the envelope")
        Set tLoggedIn = $ClassMethod(..#SEAM, "LoggedIn")
        Do $$$AssertTrue((tLoggedIn '= "") && ($Translate($Replace(tLoggedIn, ..#SOURCE, ""), ",") = ""), tMode _ ": every line is written in the namespace the call came from: " _ tLoggedIn)
        If tMode = "target" {
            Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416ArcMode("targetIn")), ..#TARGET, "target: the fault was raised while the target was switched to")
            Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), "", "target: and nothing was moved")
        } Else {
            Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416ArcMode("ranIn")), ..#SOURCE, tMode _ ": the vendor call ran in the source namespace")
        }
        If tMode = "status" Do $$$AssertEquals(..OwnRows(tSince, "interop-archive", .tData), 1, "status: an error status is still audited")
        If tMode = "status" Do $$$AssertTrue(tData [ """completed"":false", "status: and the row says the run did not complete: " _ tData)
        Kill ^IRIS.Temp.OcuProbe2416ArcMode
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Do ..Settings()
    }
}

/// <p>AC5, AD-52: a run is taken in the namespace it archives, not in the one the call comes from. With HSCUSTOM listed beside USER for this test alone, a run of USER into HSCUSTOM,
/// called from HSCUSTOM, holds USER's archive lock when it reaches the vendor and calls the vendor in USER; the vendor answers an error, so nothing moves.</p>
/// <p>Mutation (Rule 19): drop the namespace switch around <method>OcuPilot.Port.InteropPort.VendorArchive</method> in <method>OcuPilot.Port.InteropPort.ArchiveRun</method> -- the
/// vendor leg goes red; drop it from <method>OcuPilot.Port.InteropPort.ArchiveTake</method> -- the lock leg goes red.</p>
Method TestARunIsTakenInTheNamespaceItArchives()
{
    Set tListed = $Data(^%SYS("Ensemble", "InstalledNamespace", ..#SOURCE))
    Try {
        If 'tListed Set ^%SYS("Ensemble", "InstalledNamespace", ..#SOURCE) = ""
        Do $ClassMethod(..#FIXTURE, "PutSettings", ..#TARGET, ..#SOURCE, "<absent>", ..#RUNDAYS)
        Set ^IRIS.Temp.OcuProbe2416ArcMode = "status"
        Do $$$AssertEquals(..RunVerdict(.tFault, ..#SEAM, ..#TARGET), "500 INTERNAL", "a run of USER that the vendor answers with an error is a 500")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416ArcMode("ranIn")), ..#TARGET, "the vendor was called in USER, the namespace archived, not in HSCUSTOM, the one the call came from")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416ArcMode("heldHere")), 1, "and this process held USER's archive lock when it called")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg raised")
    }
    If 'tListed Kill ^%SYS("Ensemble", "InstalledNamespace", ..#SOURCE)
    Do $$$AssertEquals($Data(^%SYS("Ensemble", "InstalledNamespace", ..#SOURCE)), tListed, "HSCUSTOM's place in the list is as it was")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var> and run each of <parameter>LEGS</parameter> through <class>OcuPilot.Port.InteropPort</class>, then
/// signal <code>{loggedIn, "&lt;leg&gt;": {http, code, failedPair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tSpec = $Piece(..#LEGS, ",", tI)
            Set tName = $Piece(tSpec, "|", 1)
            Set tType = $Piece(tSpec, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = ..#SOURCE
            Set tBody = ""
            If tType = "ARCHIVE" Set tQuery("id") = ..#SOURCE
            If tType = "SETTINGSET" {
                Set tQuery("id") = ..#DAYSNAME
                Set tBody = {"Value": "90"}
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = $ClassMethod(..#PORT, "Invoke", $Piece(tSpec, "|", 3), tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tName, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropArchiveRefusals).Probe($Job, pUser)::10
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

/// <p>AC3: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged: a caller without <code>%Ens_ArchiveManager:WRITE</code> reads and is
/// refused the run and the set naming it; one who cannot write HSCUSTOM's database is refused both naming it; one who cannot write USER's database is refused the run
/// naming that pair and sets; the principals holding every pair, or WRITE on USER alone, run. A refused run moved nothing and a refused set stored nothing.</p>
/// <p>Mutation (Rule 19): drop the target's pairs from <method>OcuPilot.Port.InteropPort.ArchiveRun</method> -- the <code>OcuP2416aTargetRead</code> leg goes red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tOk = "200||"
    Set tManager = "403|" _ tDeny _ "|%Ens_ArchiveManager:WRITE"
    Set tSource = "403|" _ tDeny _ "|%DB_HSCUSTOM:WRITE"
    Set tTargetWrite = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tExpected("OcuP2416aExact") = $ListBuild(tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2416aNoWrite") = $ListBuild(tOk, tOk, tManager, tOk, tManager)
    Set tExpected("OcuP2416aDbRead") = $ListBuild(tOk, tOk, tSource, tOk, tSource)
    Set tExpected("OcuP2416aTargetRead") = $ListBuild(tOk, tOk, tTargetWrite, tOk, tOk)
    ; WRITE on a database admits its reads too (measured), so a principal holding WRITE on USER alone runs, as the vendor needs nothing more.
    Set tExpected("OcuP2416aTargetWrite") = $ListBuild(tOk, tOk, tOk, tOk, tOk)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Do ..Settings()
        Do $$$AssertTrue(..Arrange(.tIds), tUser _ ": the probe messages are arranged")
        Set tOut = ..ProbeAs(tUser)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tRan = 0
        Set tSet = 0
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If (tLegName = "run") && (tGot = tOk) Set tRan = 1
            If (tLegName = "set") && (tGot = tOk) Set tSet = 1
        }
        If 'tRan Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), "", tUser _ ": a refused run moved nothing")
        If tRan Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET), ..OldIds(.tIds), tUser _ ": an admitted run moved the old messages")
        If 'tSet Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|<absent>|" _ ..#RUNDAYS, tUser _ ": a refused set stored nothing")
        If tSet Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|Ens.Archive.Manager|90", tUser _ ": an admitted set stored what it sent")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

}
