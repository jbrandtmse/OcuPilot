/// <p>Pins Story 5.10's write: the auditing tool's own declarations, the singleton target key, the
/// warning predicate over every shape the payload accepts, the prohibited branch, the demo
/// sequence that turns this instance's auditing off and back on through the shipped confirm path,
/// and the vendor's own change rows for that sequence -- the one correlation direction AD-15 as
/// amended says survives.</p>
/// <p><b>What it needs from the environment:</b> <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, OcuPilot's protected state, and
/// <parameter>ARMINGVARIABLE</parameter> set to 1. <b>It turns this instance's auditing off</b>, so
/// the arming variable is the barrier: unarmed, <method>OnBeforeAllTests</method> refuses before
/// <class>%UnitTest.Manager</class> enumerates a single method and nothing runs.</p>
/// <p><b>Auditing is restored on every exit path.</b> Each method that turns it off restores it in
/// a frame of its own after <code>Try</code>/<code>Catch</code> -- a raise skips a method's tail --
/// and <method>OnAfterOneTest</method> restores it again and <b>asserts the restore worked</b>, so
/// a method that aborted between the disable and the re-enable cannot leave every later class in
/// the sweep silently unaudited.</p>
Class OcuPilot.Test.AuditingUpdate Extends %UnitTest.TestCase
{

/// <p>The variable <file>scripts/ci-throwaway.sh</file> sets and nothing else does. This class
/// turns the instance's own auditing off, which is the widest effect any test in this suite has:
/// while it is off nothing on the instance is audited at all.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_TOGGLE";

Parameter TOOL = "OcuPilot.Screen.Tool.AuditingUpdate";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The fresh read the fixture port answers for the non-destructive methods: the endpoint's own
/// one-property shape, with auditing on.</p>
Parameter FRESH = "{""Enabled"":true}";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditingUpdate turns this instance's auditing off and runs only where " _ ..#ARMINGVARIABLE _ " is 1 (scripts/ci-throwaway.sh)")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Restore auditing and the recorded marking fact whatever a method did, then report a failed
/// restore as a failure of this teardown rather than of the next class to run.</p>
/// <p><b>The assertion is on the reading taken BEFORE this teardown repairs anything</b> (AC7).
/// A method that turns auditing off restores it in a frame of its own, so a reading of 0 here says
/// that frame did not run -- and a reading taken after the repair would be 1 whether it ran or not,
/// which is the assertion that cannot fail. The repair still happens, because the next class must
/// not inherit an unaudited instance; what is asserted is that it had nothing to do.</p>
/// <p>A failed repair is held rather than returned at once, so the fixture removal below runs on
/// that path too: an unaudited instance and a leaked probe proposal in the same teardown would
/// otherwise reach every later method.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tBefore = ..AuditEnabled()
    Do ..RestoreAuditing()
    Set tEnabled = ..AuditEnabled()
    Set tResult = $$$OK
    If tEnabled '= 1 Set tResult = $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditingUpdate left this instance's auditing off (AuditEnabled = " _ tEnabled _ ")")
    Do $$$AssertEquals(tBefore, 1, "the method restored auditing itself, so this teardown had nothing to repair")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit tResult
}

/// <p>The instance-wide <code>AuditEnabled</code> setting, or <code>-1</code> when it could not be
/// read -- never <code>0</code>, which would read as "off" and let a restore be skipped.</p>
ClassMethod AuditEnabled() As %Integer
{
    Set tValue = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
        If $$$ISOK(tSC) Set tValue = +$Get(tProps("AuditEnabled"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

/// <p>Turn auditing on again, and record the marking fact the panel banner reads, <b>only when the
/// instance is actually in the wrong state</b> -- so this is a repair rather than a write every
/// teardown makes.</p>
ClassMethod RestoreAuditing()
{
    Set tOrigNS = $NAMESPACE
    Try {
        If ..AuditEnabled() '= 1 {
            Set $NAMESPACE = "%SYS"
            Kill tProps
            Set tProps("AuditEnabled") = 1
            Do ##class(Security.System).Modify("SYSTEM", .tProps)
            Set $NAMESPACE = tOrigNS
        }
        If ..AuditEnabled() = 1 Do ##class(OcuPilot.Kernel.Audit.Event).RecordMarking(1)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>AC5, AC6, AC7 -- the demo sequence, against this instance, through the shipped confirm path:
/// the disable's marker is dropped and <b>the drop is recorded</b>, the re-enable's marker lands,
/// and the unaudited window is one write wide and legible on the ledger rows.</p>
/// <p><b>Why the marker cannot land</b> (AD-15 as amended 2026-09-21): it is emitted at one site
/// after the write reads OK, and by then the database that would record it is closed. What is
/// asserted is therefore the <i>record</i> of the drop -- a not-marked ledger row and the recorded
/// marking fact the panel banner reads -- and the bracketing, which is pinned as a <b>pair</b>: one
/// marked row plus one unmarked row does not distinguish a one-write gap from an unbounded one, so
/// the sequence runs twice and the window between two marked rows is asserted to hold exactly one
/// unmarked row.</p>
/// <p>Mutation (Rule 19): with <code>$System.Security.Audit</code> answering 0, skip the ledger
/// finalize's not-marked value or the <method>OcuPilot.Kernel.Audit.Event.RecordMarking</method>
/// call in <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- the drop-is-recorded
/// legs go red. Make the re-enable's marker drop too -- the paired one-unmarked-row-between-two-
/// marked-ones leg goes red while every single-row leg still passes.</p>
Method TestTheDisableDropsItsMarkerRecordsTheDropAndIsBracketedByTheReEnable()
{
    Do $$$AssertEquals(..AuditEnabled(), 1, "the instance starts audited, so the disable has something to change")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Do $$$AssertEquals(..RealWrite(tTurn, 0), 0, "the confirmed disable turns auditing off")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "and the recorded fact the panel banner reads says writes are not being marked")
        Do $$$AssertEquals(..RealWrite(tTurn, 1), 1, "the confirmed re-enable turns it back on")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "and clears the banner fact")
        Do $$$AssertEquals(..RealWrite(tTurn, 0), 0, "the sequence runs a second time so the window has a marked row on both sides")
        Do $$$AssertEquals(..RealWrite(tTurn, 1), 1, "and closes again")

        Set tMarks = ..LedgerMarks(tTurn)
        Do $$$AssertEquals(tMarks, "not-marked,marked,not-marked,marked", "the ledger reads the four writes in order: each disable not marked, each re-enable marked -- got '" _ tMarks _ "'")
        Do $$$AssertEquals(..UnmarkedBetweenMarked(tMarks), 1, "and the window between two marked rows holds exactly one unmarked row, so the gap is one write wide")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the demo sequence raised")
    }
    ; Its own frame: a raise above skips the method's tail, and this instance must not be left
    ; unaudited for the rest of the sweep whatever happened (Install/Smoke.cls's restore pattern).
    Do ..RestoreAuditing()
    Do $$$AssertEquals(..AuditEnabled(), 1, "and the instance is audited again")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Mint and confirm one real auditing write setting <code>Enabled</code> to <var>pEnabled</var>
/// on turn <var>pTurnKey</var>, through the <b>shipped</b> mint, port, prohibited set, marker and
/// ledger, and answer what the instance's own setting reads afterwards.</p>
Method RealWrite(pTurnKey As %String, pEnabled As %Boolean) As %Integer
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, "string")
    Do tArgs.%Set($Parameter(..#TOOL, "PERMITTEDFIELDS"), ''pEnabled, "boolean")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"))
    Do $$$AssertStatusOK(tSC, "the proposal mints for Enabled = " _ ''pEnabled _ ": " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit -1
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "and its diff carries the one field")
    Set tKey = tProposal.%Get("proposalId")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ "): " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit -1
    Do $$$AssertEquals(tResult.%Get("auditMarked"), ''pEnabled, "the answer's auditMarked is the emission's own: false for the write that closed the channel, true once it is open")
    Quit ..AuditEnabled()
}

/// <p>The <code>auditMarked</code> value of every ledger row of turn <var>pTurnKey</var>, in
/// sequence order, comma-separated.</p>
ClassMethod LedgerMarks(pTurnKey As %String) As %String
{
    Quit ..LedgerColumn(pTurnKey, "auditMarked")
}

/// <p>The <var>pField</var> value of every <code>write</code> ledger row of turn
/// <var>pTurnKey</var>, in sequence order, comma-separated. <var>pField</var> is a key
/// <method>OcuPilot.Kernel.State.Ledger.GuardedRow</method> answers.</p>
ClassMethod LedgerColumn(pTurnKey As %String, pField As %String) As %String
{
    Kill tBySeq
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedIdsForWindow($Username, "", pTurnKey, 50, .tIds, .tProblem)
    If $$$ISERR(tSC) Quit "the ledger could not be read: " _ $System.Status.GetErrorText(tSC)
    Set tI = ""
    For {
        Set tI = $Order(tIds(tI))
        If tI = "" Quit
        If $$$ISERR(##class(OcuPilot.Kernel.State.Ledger).GuardedRow(tIds(tI), .tRow)) Continue
        If $Get(tRow("kind")) '= "write" Continue
        Set tBySeq(+$Get(tRow("seq"))) = $Get(tRow(pField))
    }
    Set tText = ""
    Set tSeq = ""
    For {
        Set tSeq = $Order(tBySeq(tSeq))
        If tSeq = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tBySeq(tSeq)
    }
    Quit tText
}

/// <p>How many unmarked rows lie strictly between the first and the last <code>marked</code> row of
/// <var>pMarks</var>, or <code>-1</code> when fewer than two rows are marked.</p>
/// <p>It is what makes the bracketing one assertion rather than two: a sequence with one marked row
/// answers <code>-1</code>, so "the gap is one write wide" cannot pass on a half-observed
/// window.</p>
ClassMethod UnmarkedBetweenMarked(pMarks As %String) As %Integer
{
    Set tFirst = 0
    Set tLast = 0
    Set tTotal = $Length(pMarks, ",")
    For tI = 1:1:tTotal {
        If $Piece(pMarks, ",", tI) '= $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES") Continue
        If tFirst = 0 Set tFirst = tI
        Set tLast = tI
    }
    If (tFirst = 0) || (tLast = tFirst) Quit -1
    Set tCount = 0
    For tI = tFirst + 1:1:tLast - 1 {
        If $Piece(pMarks, ",", tI) = $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDNO") Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>AC5, AD-15 as amended: the direction that <b>survives</b> for this one write -- ledger to
/// audit by timestamp -- is the vendor's own change rows, so they are asserted rather than
/// described. Over the real confirmed sequence: the disable's <code>SystemChange</code> and
/// <code>AuditChange</code> rows are in the audit database, and the ledger's not-marked row and
/// the marked row that follows it bracket them, which is what makes an operator holding the
/// not-marked row able to find the instance's own record of the same change.</p>
/// <p><b>The re-enable leaves no <code>SystemChange</code> row at all</b>, and that is the same
/// physical constraint the amendment names for OcuPilot's marker: the vendor emits it before
/// auditing is back, so it is dropped. Its <code>AuditChange</code> "started" row lands once the
/// channel is open, and the stop and the restart bound the unaudited window the not-marked ledger
/// row records.</p>
/// <p>Mutation (Rule 19): take <var>tSince</var> after the sequence rather than before it, or point
/// the <code>SystemChange</code> text at a phrase no row carries -- the row counts read 0 and every
/// assertion here goes red. The claim is about the vendor's rows, so the falsification is on the
/// window, not on OcuPilot code.</p>
Method TestTheVendorsOwnRowsRecordTheChangeTheMarkerCouldNot()
{
    Do $$$AssertEquals(..AuditEnabled(), 1, "the instance starts audited, so the disable has something to change")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Do $$$AssertEquals(..RealWrite(tTurn, 0), 0, "the confirmed disable turns auditing off")
        Do $$$AssertEquals(..RealWrite(tTurn, 1), 1, "and the confirmed re-enable turns it back on")

        Do $$$AssertEquals(..LedgerMarks(tTurn), "not-marked,marked", "the ledger reads the two writes in order: the disable not marked, the re-enable marked")
        Set tStamps = ..LedgerColumn(tTurn, "loggedAt")
        Set tDroppedAt = $Piece(tStamps, ",", 1)
        Set tMarkedAt = $Piece(tStamps, ",", 2)
        Do $$$AssertNotEquals(tDroppedAt, "", "the not-marked row carries the moment it was opened")
        Do $$$AssertNotEquals(tMarkedAt, "", "and so does the marked row that closes the window")

        Set tSystem = ..VendorRows(tSince, "SystemChange", "Audit enabled modified", .tSystemAt)
        Do $$$AssertEquals(tSystem, 1, "the audit database holds exactly one SystemChange row for this window -- the disable's, written while auditing was still on; the re-enable's is emitted before the channel reopens and is dropped, which is the constraint AD-15's amendment names")
        Set tStopped = ..VendorRows(tSince, "AuditChange", "stopped", .tStoppedAt)
        Do $$$AssertEquals(tStopped, 1, "and one AuditChange row recording that auditing stopped")
        Set tStarted = ..VendorRows(tSince, "AuditChange", "Auditing started", .tStartedAt)
        Do $$$AssertEquals(tStarted, 1, "and one recording that it started again")

        ; Ledger to audit by timestamp: the window the two ledger rows open and close holds the
        ; disable's vendor rows, and the restart lands at or after the row that closed it.
        Do $$$AssertTrue((tSystemAt ]] tDroppedAt) || (tSystemAt = tDroppedAt), "the SystemChange row is at or after the not-marked row's own moment: ledger " _ tDroppedAt _ ", audit " _ tSystemAt)
        Do $$$AssertTrue((tMarkedAt ]] tStoppedAt) || (tMarkedAt = tStoppedAt), "and the stop is at or before the marked row that closes the window: audit " _ tStoppedAt _ ", ledger " _ tMarkedAt)
        Do $$$AssertTrue((tStartedAt ]] tMarkedAt) || (tStartedAt = tMarkedAt), "while the restart is at or after that row, so the stop and the restart bound the unaudited window the not-marked row records: audit " _ tStartedAt _ ", ledger " _ tMarkedAt)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the sequence raised")
    }
    ; Its own frame, for the reason the sequence above gives.
    Do ..RestoreAuditing()
    Do $$$AssertEquals(..AuditEnabled(), 1, "and the instance is audited again")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>How many rows the audit database holds under the <b>vendor's</b> own
/// <code>%System</code>/<code>%Security</code>/<var>pEvent</var> since <var>pSince</var> whose
/// <code>EventData</code> carries <var>pText</var>, with the last such row's UTC timestamp in
/// <var>pStamp</var>, in the ISO-8601 spelling a ledger row carries. <code>-1</code> when the read
/// itself failed.</p>
/// <p>Bounded by <code>UTCTimeStamp</code> and <code>%NOINDEX</code>-ed on the event predicates for
/// the reason <method>OcuPilot.Test.AuditEvent.RowsCarrying</method> is (DW-85). Separate from that
/// reader because the source and type here are the vendor's, not OcuPilot's. The stamp is converted
/// after the namespace is restored: an <code>OcuPilot</code> class reference evaluated in
/// <code>%SYS</code> raises <code>&lt;CLASS DOES NOT EXIST&gt;</code>.</p>
ClassMethod VendorRows(pSince As %String, pEvent As %String, pText As %String, Output pStamp As %String) As %Integer
{
    Set pStamp = ""
    Set tRaw = ""
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT UTCTimeStamp, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, "%System", "%Security", pEvent)
        If tRS.%SQLCODE < 0 {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRows = 0
        While tRS.%Next() {
            If tRS.%Get("EventData") '[ pText Continue
            Set tRows = tRows + 1
            Set tRaw = tRS.%Get("UTCTimeStamp")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    If tRaw '= "" Set pStamp = ##class(OcuPilot.Test.AuditMarker).Iso(tRaw)
    Quit tRows
}

/// <p>AC2, DW-1226: the warning asks the question the payload asks, over every shape the payload
/// can carry -- so a value that turns auditing off cannot reach a card with no warning above it.</p>
/// <p>The four shapes are driven at the predicate and again through a real mint, because the
/// defect was that the predicate had a type gate of its own: <code>0</code> and
/// <code>"false"</code> coerced to false in the payload while the card said nothing.</p>
/// <p>Mutation (Rule 19): restore the <code>%GetTypeOf(Enabled) = "boolean"</code> gate in
/// <method>OcuPilot.Kernel.Proposal.Mint.WarnsAuditingOff</method> -- the <code>0</code>,
/// <code>"false"</code> and null legs below go red.</p>
Method TestTheWarningAsksTheQuestionThePayloadAsks()
{
    Set tTool = $Parameter(..#TOOL, "TOOLNAME")
    Set tField = $Parameter("OcuPilot.Kernel.Proposal.Mint", "AUDITINGFIELD")
    Set tScope = ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE
    Set tType = $ClassMethod(..#SCREEN, "PrimaryEntityType")

    Set tBoolean = {}
    Do tBoolean.%Set(tField, 0, "boolean")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, tBoolean), 1, "boolean false warns")
    Set tNumber = {}
    Do tNumber.%Set(tField, 0, "number")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, tNumber), 1, "the number 0 warns, as the payload coerces it")
    Set tWord = {}
    Do tWord.%Set(tField, "false", "string")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, tWord), 1, "the string 'false' warns")
    Set tNull = {}
    Do tNull.%Set(tField, "", "null")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, tNull), 1, "and a JSON null warns, because the payload will not carry it as 'auditing stays on'")

    Set tOn = {}
    Do tOn.%Set(tField, 1, "boolean")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, tOn), 0, "turning auditing on does not warn")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).WarnsAuditingOff(tTool, tType, tScope, {}), 0, "and an absent field does not")

    ; The same shapes through a real mint over the endpoint's own one-property read. The tool's own
    ; schema admits only a JSON boolean, so these reach the mint the way a fixture or a later tool
    ; would: through Mint itself, which is where the predicate and the merge must agree.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Do $$$AssertEquals(..MintedWarning(tNumber, .tMintedZero), 1, "the number 0 mints")
    Do $$$AssertEquals(tMintedZero, 1, "and its card carries the warning")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Do $$$AssertEquals(..MintedWarning(tWord, .tMintedWord), 1, "the string 'false' mints")
    Do $$$AssertEquals(tMintedWord, 1, "and its card carries the warning")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    ; Exactly 0, never -1: 0 is the merge's own refusal and -1 is an arrangement that broke, so
    ; this leg cannot pass because the turn failed to seed.
    Do $$$AssertEquals(..MintedWarning(tNull, .tMintedNull), 0, "a JSON null mints nothing: the merge refuses a value the payload cannot carry")
}

/// <p>Mint <var>pArgs</var> through the fixture port directly (not through the tool's schema, which
/// admits a JSON boolean alone) and answer 1 when a row was stored, with its stored
/// <code>auditWarning</code> in <var>pWarning</var>.</p>
/// <p><b><code>0</code> means the mint refused.</b> An arrangement that failed -- the turn not
/// seeded, the stored row not readable -- answers <code>-1</code> and asserts its own cause, so a
/// caller asserting <code>0</code> is asserting the merge's own refusal rather than accepting any
/// breakage as one. The two are the same value in the obvious spelling, which is what makes a leg
/// that expects a refusal pass for the wrong reason. The one residue is a mint that reports OK
/// and whose row then reads back absent, which answers <code>0</code> as well; no path in this
/// class reaches it, because the key comes from that same mint.</p>
Method MintedWarning(pArgs As %DynamicObject, Output pWarning As %Boolean) As %Integer
{
    Set pWarning = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit -1
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, $ClassMethod(..#TOOL, "IdArgument"), $ListBuild($Parameter(..#TOOL, "PERMITTEDFIELDS")))
    If $$$ISERR(tSC) Quit 0
    Set tKey = tProposal.%Get("proposalId")
    Set tReadSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tRow)
    Do $$$AssertStatusOK(tReadSC, "the stored row reads back: " _ $System.Status.GetErrorText(tReadSC))
    If $$$ISERR(tReadSC) Quit -1
    Set pWarning = ''$Get(tRow("auditWarning"))
    Quit ''tFound
}

/// <p>AC1, AC4, DW-1244: the tool declares its own name, its one settable field, its
/// <code>USE</code> pair and its destructive flag, and the kernel's warning predicate is keyed on
/// the shipped tool rather than on a constant nobody compares.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.AuditingUpdate.WRITEPERMISSION</parameter>
/// back to <code>"WRITE"</code> -- the pair assertion goes red; answer 0 from
/// <method>OcuPilot.Screen.Tool.Write.Destructive</method> -- the destructive assertion goes red.</p>
Method TestTheToolsDeclarationsAreItsOwn()
{
    Do $$$AssertEquals($Parameter(..#TOOL, "TOOLNAME"), $Parameter("OcuPilot.Kernel.Proposal.Mint", "AUDITINGTOOL"), "the kernel's warning predicate names this tool")
    Do $$$AssertEquals($Parameter(..#TOOL, "PERMITTEDFIELDS"), $Parameter("OcuPilot.Kernel.Proposal.Mint", "AUDITINGFIELD"), "and the field it reads is this tool's one settable field")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "SettableFields")), "Enabled", "the merge may set exactly that field")
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Kernel.Proposal.Prohibited", "PermittedChangeFields", $ClassMethod(..#SCREEN, "PrimaryEntityType"))), "Enabled", "which is the one field the prohibited set has reviewed")
    Do $$$AssertEquals($Parameter(..#TOOL, "WRITEPERMISSION"), "USE", "the write's own permission is USE, never WRITE (AD-8 as amended)")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Destructive"), 1, "the tool declares its write destructive")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.WebAppUpdate", "Destructive"), 0, "while a tool that is not says so")

    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "the pair set resolves")
    Do $$$AssertEquals($ListLength(tPairs), 2, "to the screen's own two pairs and nothing else: " _ ..PairText(tPairs))
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) > 0, "including %Admin_Secure:USE")

    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Enabled"), "object", "the schema advertises Enabled")
    Do $$$AssertEquals(tProperties.%Get("Enabled").%Get("type"), "boolean", "as a boolean")
    Do $$$AssertTrue(tProperties.%Get($ClassMethod(..#TOOL, "IdArgument")).%Get("description") [ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, "and the id property names the one id the target carries")
}

/// <p><var>pPairs</var> as <code>resource:permission</code>, comma-separated, for a message.</p>
ClassMethod PairText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>AC4's one-lock half, AD-13 as amended and AD-34: every spelling of the singleton id builds
/// one reference key, so two proposals against it are siblings -- one lock, and confirming one
/// cancels the other.</p>
/// <p>Mutation (Rule 19): answer the id verbatim for the <code>singleton</code> rule in
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> -- the two spellings become two keys and
/// the sibling-cancel leg goes red.</p>
Method TestEverySpellingOfTheSingletonIsOneTargetKey()
{
    Set tType = $ClassMethod(..#SCREEN, "PrimaryEntityType")
    Set tCanonical = ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
    For tSpelling = "SYSTEM", "system", "System", "anything at all", "" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, tSpelling), tCanonical, "'" _ tSpelling _ "' canonicalizes to " _ tCanonical)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(tType, ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, "system", .tLower), "a key builds from a lower-case spelling")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(tType, ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, "SYSTEM", .tUpper), "and from the canonical one")
    Do $$$AssertEquals(tLower, tUpper, "and the two are one key")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tFirst = ..MintFor("system")
    If tFirst = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSecond = ..MintFor("SYSTEM")
    If tSecond = "" Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst, "TargetRef"), ##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "TargetRef"), "both proposals name one target")

    ; Cancelling the second closes it; the first is its sibling on that one target, so a later
    ; confirm of either finds one row's worth of state rather than two.
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Cancel(tSecond, $Username, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the second proposal cancels: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "State"), "canceled", "and its row is closed")
}

/// <p>Mint one auditing proposal for the id spelling <var>pSpelling</var> through the fixture port,
/// and answer its id.</p>
Method MintFor(pSpelling As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), pSpelling, "string")
    Do tArgs.%Set("Enabled", 0, "boolean")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pSpelling, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"))
    Do $$$AssertStatusOK(tSC, "the proposal mints for '" _ pSpelling _ "': " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>AD-10: the prohibited set covers this type, permits a change to <code>Enabled</code> in both
/// directions, and refuses every other field of the object it has not reviewed.</p>
/// <p><b>The unreviewed-field refusal is unreachable in production, and that is the point.</b> The
/// endpoint's own <code>GET</code> answers one property, and
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> refuses an argument naming a property the
/// fresh read does not carry -- so no minted payload can name a second field. The refusal is the
/// fail-closed guard for a property a later IRIS build adds to this endpoint, which is why it is
/// driven from a payload here rather than from a proposal.</p>
/// <p>Mutation (Rule 19): remove the auditing type from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- every leg here goes
/// red with <code>PROHIBITED.UNCOVERED</code>, and
/// <method>OcuPilot.Test.Prohibited.TestNoRegisteredWriteToolHasAnUncoveredEntityType</method> goes
/// red beside it.</p>
Method TestTheProhibitedBranchPermitsEnabledAndRefusesEveryOtherField()
{
    Set tType = $ClassMethod(..#SCREEN, "PrimaryEntityType")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), tType) > 0, "the set covers this entity type")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Kernel.Proposal.Prohibited).Codes()), 15, "the set declares fifteen codes, and this write earned none of them: Story 5.10 added no code, Story 5.12's two are a process's, Story 5.14's is an account's, Story 8.3's is a role's and Story 8.4's is a resource's")

    ; The SHIPPED set, so its target is re-read through the shipped port from the real endpoint --
    ; no fixture stands in for the object the predicate judges.
    Set tRef = ..TargetRef()
    Do $$$AssertEquals(..AuditEnabled(), 1, "the instance is audited, so turning it off is a real change to judge")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, "{""Enabled"":false}", ..Diff("Enabled"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for a change to Enabled: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 0, "and permits it: turning auditing off is not an effect AD-10 forbids")
    ; The other direction is not asserted here as a value, because against an audited instance it
    ; changes nothing and the answer would be vacuous. The re-enable is confirmed for real by
    ; TestTheDisableDropsItsMarkerRecordsTheDropAndIsBracketedByTheReEnable, which passes this set.

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, "{""Enabled"":true,""AuditEncrypt"":false}", ..Diff("AuditEncrypt"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for a field it has not reviewed")
    Do $$$AssertEquals(tProhibits, 1, "and refuses it")
    Do $$$AssertEquals(tCode, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNCOVEREDFIELD"), "as an unreviewed field")
}

/// <p>The canonical reference key of this story's one target.</p>
ClassMethod TargetRef() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod("OcuPilot.Screen.Descriptor.AuditingConfig", "PrimaryEntityType"), ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, .tRef)
    Quit tRef
}

/// <p>A stored diff naming <var>pField</var>, the shape the mint stores.</p>
ClassMethod Diff(pField As %String) As %String
{
    Quit "[{""field"":""" _ pField _ """,""before"":""true"",""after"":""false""}]"
}

}
