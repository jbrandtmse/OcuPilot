/// <p>Pins <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method>, the sweep of the turns and proposals a
/// test seeded for the running account: a key whose removal fails is kept while every other key is swept, the
/// failure is the answer's status, a later sweep removes what the failed one could not, a key whose delete
/// reported a failure is kept even when its rows are gone, the remaining count holds the proposals and the
/// turns that survive, and a count that cannot be read, of proposals or of turns, is an error and -1 that
/// leaves every other key swept.</p>
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

/// <p>Seed two completed turns with one proposal each, and answer in <var>pFirst</var> the key the sweep reaches
/// first and in <var>pLast</var> the one it reaches last; <code>0</code> when either seeding failed.</p>
Method SeedPair(Output pFirst As %String, Output pLast As %String) As %Boolean
{
    Set tOne = ..Seed("/csp/ocupilotsweeppairone")
    Set tTwo = ..Seed("/csp/ocupilotsweeppairtwo")
    If (tOne = "") || (tTwo = "") Quit 0
    Set pFirst = $Select(tTwo ] tOne: tOne, 1: tTwo)
    Set pLast = $Select(pFirst = tOne: tTwo, 1: tOne)
    Quit 1
}

/// <p>The rows that name the turn key <var>pTurnKey</var>, as <code>proposals turns</code>.</p>
ClassMethod Rows(pTurnKey As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "ProposalCountForTurn", pTurnKey) _ " " _ $ClassMethod(..#FIXTURE, "TurnCountForTurn", pTurnKey)
}

/// <p>Two seeded keys, the proposal delete of one of them failing: the sweep answers an error and still
/// sweeps the other key; it still deletes the failed key's turn and counts the one proposal the failed delete
/// kept, and the superclass's own sweep, run after, removes it and answers 0. The sweep takes keys in
/// collating order, and the failing key is the one it reaches first in one pass and the one it reaches last
/// in the other.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> clears its record of every
/// key once its loop ends -- the failed key's rows survive the second sweep and this goes red; it skips a key's
/// turn delete once its proposal delete failed -- the failed key's turn survives and this goes red.</p>
Method TestAFailedKeyIsKeptAndTheOthersAreSwept()
{
    For tPosition = 1, 2 {
        If '..SeedPair(.tReachedFirst, .tReachedLast) Quit
        Set tFailed = $Select(tPosition = 1: tReachedFirst, 1: tReachedLast)
        Set tOther = $Select(tPosition = 1: tReachedLast, 1: tReachedFirst)
        Set tLabel = "the failed key is reached " _ $Select(tPosition = 1: "first", 1: "last") _ ": "
        Do $ClassMethod(..#PROBE, "ArmFault", tFailed, $Parameter(..#PROBE, "FAIL"))
        Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
        Do $$$AssertStatusNotOK(tSC, tLabel _ "the sweep answers the error")
        Do $$$AssertEquals(..Rows(tOther), "0 0", tLabel _ "the other key's rows are gone")
        Do $$$AssertEquals(..Rows(tFailed), "1 0", tLabel _ "the failed key's proposal survives and its turn is gone")
        Do $$$AssertEquals(tRemaining, 1, tLabel _ "the count holds the one proposal the failed key kept")
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

/// <p>A key whose proposal delete ran and then reported a failure is kept although none of its rows remain:
/// the sweep answers the error and counts 0, and the superclass's own sweep, run after, forgets the key.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> forgets a key without
/// asking whether its removal succeeded -- the key is gone after the first sweep and this goes red.</p>
Method TestAKeyWhoseDeleteReportedAFailureIsKeptEvenWithItsRowsGone()
{
    Set tKey = ..Seed("/csp/ocupilotsweepfailafter")
    If tKey = "" Quit
    Do $ClassMethod(..#PROBE, "ArmFault", tKey, $Parameter(..#PROBE, "FAILAFTER"))
    Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
    Do $$$AssertStatusNotOK(tSC, "the sweep answers the error the delete reported")
    Do $$$AssertEquals(..Rows(tKey), "0 0", "the key's rows are gone")
    Do $$$AssertEquals(tRemaining, 0, "and the count is 0")
    Do $$$AssertEquals($Data(^||OcuPilotProposalFixtureTurns(tKey)), 1, "yet the key is kept, since its removal did not succeed")
    Do $ClassMethod(..#PROBE, "Disarm")
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tAfter)
    Do $$$AssertStatusOK(tSC, "the superclass's sweep then succeeds")
    Do $$$AssertEquals(tAfter _ " " _ $Data(^||OcuPilotProposalFixtureTurns(tKey)), "0 0", "and forgets the key")
}

/// <p>A count that cannot be read, of the proposals or of the turns, is an error and -1 whichever key it is
/// and wherever the sweep reaches it, and the key whose count could not be read is kept while the other key
/// is swept: the superclass's own sweep, run after, forgets the kept key and answers 0.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Test.ProposalFixture.RemoveSeeded</method> ends its loop at a key
/// whose count could not be read -- the unreadable key reached first leaves the other key unswept and this goes
/// red; it does not ask whether the turn count could be read -- the turn legs answer success and this goes
/// red; it adds an unreadable count into its total as a number -- the sweep answers success and this goes
/// red.</p>
Method TestAnUnreadableCountKeepsItsKeyAndSweepsTheOtherKey()
{
    For tMode = $Parameter(..#PROBE, "UNREADABLE"), $Parameter(..#PROBE, "UNREADABLETURN") {
        For tPosition = 1, 2 {
            If '..SeedPair(.tFirst, .tLast) Quit
            Set tUnreadable = $Select(tPosition = 1: tFirst, 1: tLast)
            Set tOther = $Select(tPosition = 1: tLast, 1: tFirst)
            Set tLabel = tMode _ " key reached " _ $Select(tPosition = 1: "first", 1: "last") _ ": "
            Do $ClassMethod(..#PROBE, "ArmFault", tUnreadable, tMode)
            Set tSC = $ClassMethod(..#PROBE, "RemoveSeeded", .tRemaining)
            Do $$$AssertStatusNotOK(tSC, tLabel _ "the sweep answers the error")
            Do $$$AssertEquals(tRemaining, -1, tLabel _ "and the count is -1")
            Do $$$AssertEquals(..Rows(tOther), "0 0", tLabel _ "the other key's rows are gone")
            Do $$$AssertEquals($Data(^||OcuPilotProposalFixtureTurns(tUnreadable)) _ $Data(^||OcuPilotProposalFixtureTurns(tOther)), "10", tLabel _ "the unreadable key is kept and the other forgotten")
            Do $ClassMethod(..#PROBE, "Disarm")
            Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tAfter)
            Do $$$AssertStatusOK(tSC, tLabel _ "the superclass's sweep then succeeds")
            Do $$$AssertEquals(tAfter _ " " _ ..Rows(tUnreadable) _ " " _ $Data(^||OcuPilotProposalFixtureTurns(tUnreadable)), "0 0 0 0", tLabel _ "with nothing surviving and the key forgotten")
        }
    }
}

}
