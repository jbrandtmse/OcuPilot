/// <p>Pins <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method>, the sweep of the turns and proposals a
/// test seeded for the running account: a key whose removal fails is kept while every other key is swept, the
/// failure is the answer's status, a later sweep removes what the failed one could not, the remaining count
/// holds the proposals and the turns that survive, and a count that cannot be read is an error and -1.</p>
/// <p>The failures are driven through <class>OcuPilot.Test.ProposalFixtureFaultProbe</class>, which breaks one
/// armed delete; the sweep that tears each test down is the superclass's own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and the suite account's right to write the
/// kernel's turn and proposal tables. It is not armed. It seeds its own turns and proposals, sweeps the keys any
/// earlier test left in this process before each test, and removes its own after each test.</p>
Class OcuPilot.Test.ProposalFixtureSweep Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.ProposalFixture";

Parameter PROBE = "OcuPilot.Test.ProposalFixtureFaultProbe";

/// <p>The conversation the seeded proposals name.</p>
Parameter CONVERSATION = "probe-sweep-conversation";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Disarm")
    Quit $ClassMethod(..#FIXTURE, "RemoveSeeded", .tLeft)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RemoveSeeded", .tRemaining), "the seeded rows are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Seed a completed turn and one proposal it minted, for the running account, naming <var>pTarget</var>;
/// answer the turn's key, or <code>""</code> when either seeding failed.</p>
Method Seed(pTarget As %String) As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "SeedTurn", $Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = $ClassMethod(..#FIXTURE, "SeedMinimal", $Username, ..#CONVERSATION, tTurnKey, pTarget, .tProposalKey)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tTurnKey
}

/// <p>The rows that name the turn key <var>pTurnKey</var>, as <code>proposals turns</code>.</p>
ClassMethod Rows(pTurnKey As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "ProposalCountForTurn", pTurnKey) _ " " _ $ClassMethod(..#FIXTURE, "TurnCountForTurn", pTurnKey)
}

/// <p>Two seeded keys, the proposal delete of one of them failing: the sweep answers an error and still
/// sweeps the other key; it counts what the failed key kept, and the superclass's own sweep, run after,
/// removes it and answers 0. The sweep takes keys in collating order, and the failing key is the one it
/// reaches first in one pass and the one it reaches last in the other.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> clears its record of every
/// key once its loop ends -- the failed key's rows survive the second sweep and this goes red.</p>
Method TestAFailedKeyIsKeptAndTheOthersAreSwept()
{
    For tPosition = 1, 2 {
        Set tOne = ..Seed("/csp/ocupilotsweepone")
        Set tTwo = ..Seed("/csp/ocupilotsweeptwo")
        If (tOne = "") || (tTwo = "") Quit
        Set tReachedFirst = $Select(tTwo ] tOne: tOne, 1: tTwo)
        Set tReachedLast = $Select(tReachedFirst = tOne: tTwo, 1: tOne)
        Set tFailed = $Select(tPosition = 1: tReachedFirst, 1: tReachedLast)
        Set tOther = $Select(tPosition = 1: tReachedLast, 1: tReachedFirst)
        Set tLabel = "the failed key is reached " _ $Select(tPosition = 1: "first", 1: "last") _ ": "
        Do $ClassMethod(..#PROBE, "ArmFault", tFailed, $Parameter(..#PROBE, "FAIL"))
        Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
        Do $$$AssertStatusNotOK(tSC, tLabel _ "the sweep answers the error")
        Do $$$AssertEquals(..Rows(tOther), "0 0", tLabel _ "the other key's rows are gone")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ProposalCountForTurn", tFailed), 1, tLabel _ "the failed key's proposal survives")
        Set tKept = ..Rows(tFailed)
        Do $$$AssertEquals(tRemaining, $Piece(tKept, " ", 1) + $Piece(tKept, " ", 2), tLabel _ "the count holds what the failed key kept")
        Do $ClassMethod(..#PROBE, "Disarm")
        Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tAfter)
        Do $$$AssertStatusOK(tSC, tLabel _ "the superclass's sweep then succeeds")
        Do $$$AssertEquals(tAfter, 0, tLabel _ "with nothing surviving")
        Do $$$AssertEquals(..Rows(tFailed), "0 0", tLabel _ "the failed key's rows are gone")
    }
}

/// <p>A turn that survives its delete is counted: the sweep answers success, the count is 1, and the superclass's
/// own sweep, run after, removes the turn.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> counts proposals alone --
/// the count reads 0 and this goes red.</p>
Method TestASurvivingTurnIsCounted()
{
    Set tKey = ..Seed("/csp/ocupilotsweepturn")
    If tKey = "" Quit
    Do $ClassMethod(..#PROBE, "ArmFault", tKey, $Parameter(..#PROBE, "KEEPTURN"))
    Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every delete the sweep ran succeeded")
    Do $$$AssertEquals(..Rows(tKey), "0 1", "the proposal is gone and the turn survives")
    Do $$$AssertEquals(tRemaining, 1, "the count holds the surviving turn")
    Do $ClassMethod(..#PROBE, "Disarm")
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tAfter)
    Do $$$AssertStatusOK(tSC, "the superclass's sweep then succeeds")
    Do $$$AssertEquals(tAfter _ " " _ ..Rows(tKey), "0 0 0", "and the turn is gone")
}

/// <p>A proposal count that cannot be read is an error and a remaining count of -1, and the key is kept, since
/// the sweep cannot say that no rows remain: the superclass's own sweep, run after, forgets it and answers 0.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> adds an unreadable count
/// into its total as a number -- the sweep answers success and this goes red.</p>
Method TestAnUnreadableCountIsAnErrorAndKeepsTheKey()
{
    Set tKey = ..Seed("/csp/ocupilotsweepunreadable")
    If tKey = "" Quit
    Do $ClassMethod(..#PROBE, "ArmFault", tKey, $Parameter(..#PROBE, "UNREADABLE"))
    Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
    Do $$$AssertStatusNotOK(tSC, "the sweep answers the error")
    Do $$$AssertEquals(tRemaining, -1, "and the count is -1")
    Do $$$AssertEquals($Data(^||OcuPilotProposalFixtureTurns(tKey)), 1, "the key is kept")
    Do $ClassMethod(..#PROBE, "Disarm")
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tAfter)
    Do $$$AssertStatusOK(tSC, "the superclass's sweep then succeeds")
    Do $$$AssertEquals(tAfter _ " " _ ..Rows(tKey) _ " " _ $Data(^||OcuPilotProposalFixtureTurns(tKey)), "0 0 0 0", "and forgets the key with nothing surviving")
}

}
