/// <p>Pins the conversation read (<code>GET /conversation/:id</code>) over HTTP (AD-12, AD-37,
/// AD-39): a restore whose JSON exceeds one ObjectScript string answers 200 with every turn in one
/// envelope (ten entries of about 420 KB of step text, one carrying a non-ASCII character that must
/// round-trip); each turn carries its own proposals by the entry's <code>seq</code> across a gap
/// retention left; and a proposal store the read cannot parse degrades to empty
/// <code>proposals</code> rather than failing the read, and is logged.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and the suite's HTTP
/// account owning the conversations it seeds. Each test creates one conversation and removes it
/// again, with the proposals it seeded under GUID-suffixed turn keys. Each unreadable-store read
/// makes the product log one error line to the manager directory's <file>messages.log</file>,
/// which the log leg reads and nothing removes.</p>
Class OcuPilot.Test.ConversationRestore Extends %UnitTest.TestCase
{

/// <p>Entries seeded.</p>
Parameter ENTRIES = 10;

/// <p>Characters of step text per entry.</p>
Parameter STEPCHARS = 420000;

/// <p>The conversation seeded, which <method>OnAfterOneTest</method> removes.</p>
Property SeededKey As %String;

/// <p>The turn keys whose proposals the test seeded, as a <code>$ListBuild</code> list, which
/// <method>OnAfterOneTest</method> removes the proposals of.</p>
Property SeededTurns As %String;

/// <p>The limits class every append names.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The helper whose <method>LineCount</method> and <method>LinesAfter</method> read the manager
/// directory's <file>messages.log</file>.</p>
Parameter LOGPROBE = "OcuPilot.Test.EcpProbe";

/// <p>The file the console log is written to, in the manager directory.</p>
Parameter LOGFILE = "messages.log";

/// <p>The message <method>OcuPilot.Api.Conversation.AttachProposals</method> logs when the
/// proposal read fails.</p>
Parameter PROPOSALSLOGGED = "a conversation's proposals could not be read";

/// <p>How many times the log leg reads the console log for the line, and how long it waits
/// between reads: up to five seconds in all.</p>
Parameter LOGTRIES = 25;

Parameter LOGPOLLSECONDS = 0.2;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SeededKey = ""
    Set ..SeededTurns = ""
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = $$$OK
    If ..SeededKey '= "" {
        Set tSC = ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(..SeededKey)
        Set ..SeededKey = ""
    }
    For tI = 1:1:$ListLength(..SeededTurns) {
        Set tTurnSC = ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn($List(..SeededTurns, tI))
        If $$$ISOK(tSC) Set tSC = tTurnSC
    }
    Set ..SeededTurns = ""
    Quit tSC
}

/// <p>A conversation owned by the HTTP account, created and remembered for
/// <method>OnAfterOneTest</method>; its key, or <code>""</code>.</p>
Method NewConversation() As %String
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ##class(OcuPilot.Test.Http).GetTestUsername(), 5, .tStatus, .tConflict)
    Do $$$AssertStatusOK(tStatus, "a conversation is created")
    If '$IsObject(tConvo) Quit ""
    Set tKey = tConvo.ConvKey
    Set tConvo = ""
    Set ..SeededKey = tKey
    Quit tKey
}

/// <p>A turn key no other run shares, remembered so <method>OnAfterOneTest</method> removes the
/// proposals seeded under it.</p>
Method NewTurnKey() As %String
{
    Set tKey = "probe-restore-" _ $Translate($System.Util.CreateGUID(), "-", "")
    Set ..SeededTurns = ..SeededTurns _ $ListBuild(tKey)
    Quit tKey
}

/// <p>Append one entry to <var>pConvKey</var> that records turn <var>pTurnKey</var> and the
/// definition <var>pDefinitionId</var>, answering <code>message <var>pOrdinal</var></code>.</p>
Method Append(pConvKey As %String, pOrdinal As %Integer, pTurnKey As %String, pDefinitionId As %String = "")
{
    Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedAppend(pConvKey, "message " _ pOrdinal, "done", "reply " _ pOrdinal, "", 0, "[]", 0, ..#LIMITS, pTurnKey, "", "", pDefinitionId)
    Do $$$AssertStatusOK(tSC, "entry " _ pOrdinal _ " is appended")
}

/// <p>Seed one live proposal of the HTTP account in conversation <var>pConvKey</var>, minted by
/// turn <var>pTurnKey</var> and naming <var>pTargetRef</var> (a well-formed target by default);
/// its id, or <code>""</code>.</p>
Method SeedProposal(pConvKey As %String, pTurnKey As %String, pTargetRef As %String = "") As %String
{
    Set tSC = $$$OK
    If pTargetRef = "" Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotproberestore", .pTargetRef)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(##class(OcuPilot.Test.Http).GetTestUsername(), pConvKey, pTurnKey, pTargetRef, .tKey)
    Do $$$AssertStatusOK(tSC, "a proposal is seeded on " _ pTurnKey)
    Quit $Select($$$ISOK(tSC): tKey, 1: "")
}

/// <p>Read conversation <var>pConvKey</var> as the HTTP account and answer its parsed body, or
/// <code>""</code> when the read was not a 200; the status and the JSON content type are asserted
/// here, so a caller that gets <code>""</code> has already failed one.</p>
Method Read(pConvKey As %String) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/conversation/" _ pConvKey, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers 200: " _ $Extract(tText, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    If tStatus '= 200 Quit ""
    Quit ##class(%DynamicAbstractObject).%FromJSON(tText)
}

/// <p>A restore of ten large entries answers 200, one envelope, ten turns, the non-ASCII character
/// intact.</p>
/// <p>Mutation (Rule 19): write <code>pData.%ToJSON()</code> as one string in
/// <method>OcuPilot.Api.Response.JSON</method> -> the status is 500.</p>
Method TestALargeConversationRestoresInOneEnvelope()
{
    Set tKey = ..NewConversation()
    If tKey = "" Quit
    Set tText = $Extract($Justify("", ..#STEPCHARS), 1, ..#STEPCHARS - 1) _ $Char(233)
    Set tText = $Translate(tText, " ", "x")
    Set tSteps = "[{""seq"":1,""kind"":""tool"",""name"":""probe"",""text"":""" _ tText _ """}]"
    For tI = 1:1:..#ENTRIES {
        Set tAppendSC = ##class(OcuPilot.Kernel.State.Entry).GuardedAppend(tKey, "message " _ tI, "done", "reply " _ tI, "", 0, tSteps, 0, ..#LIMITS)
        Do $$$AssertStatusOK(tAppendSC, "entry " _ tI _ " is appended")
    }
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(OcuPilot.Test.Http).GetTestServer()
    Set tReq.Port = ##class(OcuPilot.Test.Http).GetTestPort()
    Set tReq.Username = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tReq.Password = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tReq.Timeout = 120
    Set tGetSC = tReq.Get("/api/ocupilot/conversation/" _ tKey)
    Do $$$AssertStatusOK(tGetSC, "the request completes")
    Set tHttpStatus = tReq.HttpResponse.StatusCode
    Do $$$AssertEquals(tHttpStatus, 200, "the restore answers 200")
    If tHttpStatus '= 200 Quit
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tReq.HttpResponse.Data)
    Do $$$AssertEquals(tBody.turns.%Size(), ..#ENTRIES, "every turn is in the one envelope")
    Set tLastText = tBody.turns.%Get(..#ENTRIES - 1).steps.%Get(0).text
    Do $$$AssertEquals($Length(tLastText), ..#STEPCHARS, "the last turn's step text keeps its length")
    Do $$$AssertEquals($Extract(tLastText, *), $Char(233), "and its non-ASCII character round-trips")
}

/// <p>A conversation whose seq-1 entry retention removed still gives each turn its own proposals:
/// the turn at seq 2 carries only the proposal minted by its own turn, and the turn at seq 3 only
/// its own. The three entries are appended, then the marked first one is purged through
/// <method>OcuPilot.Kernel.State.Entry.GuardedPurge</method> by a cutoff that names only its
/// marker definition id, so the conversation's remaining entries are seq 2 and seq 3 while the
/// array positions are 0 and 1.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Api.Conversation.AttachProposals</method> read the
/// turn key by position, <code>tKeys(tI + 1)</code> for <code>tKeys(+tTurn.%Get("seq"))</code> --
/// this goes red.</p>
Method TestARetentionGapStillAttachesEachTurnsOwnProposals()
{
    Set tKey = ..NewConversation()
    If tKey = "" Quit
    Set tMarker = "gap" _ $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 24)
    Set tTurn1 = ..NewTurnKey()
    Set tTurn2 = ..NewTurnKey()
    Set tTurn3 = ..NewTurnKey()
    Do ..Append(tKey, 1, tTurn1, tMarker)
    Do ..Append(tKey, 2, tTurn2)
    Do ..Append(tKey, 3, tTurn3)
    Set tCutoffs(tMarker) = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() + 60
    Set tPurgeSC = ##class(OcuPilot.Kernel.State.Entry).GuardedPurge(.tCutoffs, .tRemoved)
    Do $$$AssertStatusOK(tPurgeSC, "retention runs")
    Do $$$AssertEquals(tRemoved, 1, "and removes exactly the marked first entry")
    Set tProposal2 = ..SeedProposal(tKey, tTurn2)
    Set tProposal3 = ..SeedProposal(tKey, tTurn3)
    If (tProposal2 = "") || (tProposal3 = "") Quit

    Set tBody = ..Read(tKey)
    If '$IsObject(tBody) Quit
    Set tTurns = tBody.%Get("turns")
    Do $$$AssertEquals(tTurns.%Size(), 2, "two turns remain")
    If tTurns.%Size() '= 2 Quit
    Do $$$AssertEquals(tTurns.%Get(0).%Get("seq") _ "|" _ tTurns.%Get(1).%Get("seq"), "2|3", "at seq 2 and seq 3, with no seq 1")
    Set tFirst = tTurns.%Get(0).%Get("proposals")
    Set tSecond = tTurns.%Get(1).%Get("proposals")
    Do $$$AssertEquals(tFirst.%Size(), 1, "seq 2 carries exactly one proposal")
    Do $$$AssertEquals(tSecond.%Size(), 1, "and so does seq 3")
    Do $$$AssertEquals($Select(tFirst.%Size(): tFirst.%Get(0).%Get("proposalId"), 1: ""), tProposal2, "seq 2 carries its own turn's proposal")
    Do $$$AssertEquals($Select(tSecond.%Size(): tSecond.%Get(0).%Get("proposalId"), 1: ""), tProposal3, "and seq 3 its own")
}

/// <p>A conversation whose proposal store cannot be read answers 200 with every turn's messages
/// intact and an empty <code>proposals</code> array on each. The store fails for real: one of the
/// two proposals names a target reference
/// <method>OcuPilot.Kernel.EntityRef.Parse</method> refuses, which fails the wire projection of
/// the whole conversation's proposals.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Api.Conversation.AttachProposals</method> change
/// <code>Kill tByTurn</code> to <code>Quit</code> in the proposal-read failure branch -- this goes
/// red: no turn carries a <code>proposals</code> key.</p>
Method TestAnUnreadableProposalStoreDegradesToEmptyProposals()
{
    Set tKey = ..NewConversation()
    If tKey = "" Quit
    Set tTurn1 = ..NewTurnKey()
    Set tTurn2 = ..NewTurnKey()
    Do ..Append(tKey, 1, tTurn1)
    Do ..Append(tKey, 2, tTurn2)
    Set tValid = ..SeedProposal(tKey, tTurn1)
    Set tUnparseable = ..SeedProposal(tKey, tTurn2, "probe-unparseable")
    If (tValid = "") || (tUnparseable = "") Quit

    Set tBody = ..Read(tKey)
    If '$IsObject(tBody) Quit
    Set tTurns = tBody.%Get("turns")
    Do $$$AssertEquals(tTurns.%Size(), 2, "both turns are read")
    If tTurns.%Size() '= 2 Quit
    For tI = 0:1:1 {
        Set tTurn = tTurns.%Get(tI)
        Do $$$AssertEquals(tTurn.%Get("message"), "message " _ (tI + 1), "turn " _ (tI + 1) _ " keeps its message")
        Set tProposals = tTurn.%Get("proposals")
        Do $$$AssertEquals(tTurn.%GetTypeOf("proposals"), "array", "turn " _ (tI + 1) _ " carries a proposals array")
        Do $$$AssertEquals($Select($IsObject(tProposals): tProposals.%Size(), 1: -1), 0, "which is empty, the valid proposal included")
    }
}

/// <p>The same unreadable proposal store is logged: the read still answers 200, and exactly one new
/// <file>messages.log</file> line records that the conversation's proposals could not be read, as
/// an error from the <code>turn</code> subsystem carrying the raw reason
/// <method>OcuPilot.Kernel.EntityRef.Parse</method> gave.</p>
/// <p><b>The target reference carries a GUID-suffixed entity type, which that reason echoes.</b>
/// The console log folds a line identical to the one before it into a later
/// <code>(repeated n times)</code> line, so a failure whose text is the same on every run would
/// vanish from this leg whenever another test had just logged it. The marker makes the line unique to
/// this request and ties it to this seed. The log is the instance's console log, so the leg compares
/// the file's line count before and after the one request and polls for the line briefly.</p>
/// <p>Mutation (Rule 19): delete the <method>OcuPilot.Kernel.Fault.LogRaw</method> call in
/// <method>OcuPilot.Api.Conversation.AttachProposals</method>'s proposal-read failure branch --
/// this goes red: no line carries the marker, while the read still answers 200.</p>
Method TestAnUnreadableProposalStoreIsLogged()
{
    Set tKey = ..NewConversation()
    If tKey = "" Quit
    Set tTurn = ..NewTurnKey()
    Do ..Append(tKey, 1, tTurn)
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR)
    Set tMarker = "probe-unparseable-" _ $Translate($System.Util.CreateGUID(), "-", "")
    If ..SeedProposal(tKey, tTurn, tMarker _ tSeparator _ "instance" _ tSeparator _ "/csp/ocupilotproberestore") = "" Quit
    Set tFrom = $ClassMethod(..#LOGPROBE, "LineCount", ..#LOGFILE)
    Do $$$AssertTrue(tFrom > 0, "the console log is readable: " _ tFrom)
    If tFrom < 1 Quit

    Set tBody = ..Read(tKey)
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("turns").%Size(), 1, "the one turn is read")

    Set tCount = 0
    For tTry = 1:1:..#LOGTRIES {
        Set tLines = $ClassMethod(..#LOGPROBE, "LinesAfter", ..#LOGFILE, tFrom)
        Set tCount = 0
        Set tLogged = ""
        Set tIterator = tLines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            If tLine [ tMarker {
                Set tCount = tCount + 1
                If tLogged = "" Set tLogged = tLine
            }
        }
        If tCount Quit
        Hang ..#LOGPOLLSECONDS
    }
    Do $$$AssertEquals(tCount, 1, "exactly one new console log line carries this request's marker, of " _ tLines.%Size() _ " new")
    Do $$$AssertTrue(tLogged [ "[OcuPilot]", "it is an OcuPilot line: " _ $Extract(tLogged, 1, 300))
    Do $$$AssertTrue(tLogged [ """subsystem"":""turn""", "from the turn subsystem")
    Do $$$AssertTrue(tLogged [ """level"":""error""", "at error level")
    Do $$$AssertTrue(tLogged [ ..#PROPOSALSLOGGED, "saying the conversation's proposals could not be read")
    Do $$$AssertTrue(tLogged [ ("entity type '" _ tMarker _ "'"), "and carrying the raw reason the target reference was refused")
}

}
