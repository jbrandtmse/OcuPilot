/// <p>Pins the turns-an-hour bound at the reserve (AD-41, Story 14.6), through
/// <method>OcuPilot.Kernel.State.Turn.GuardedReserve</method> for a probe user name the instance
/// does not hold, and the switch that stores the limit: the default, under and at the limit, a
/// lowered limit, a start older than the window, a busy user at the limit, the rounded retry time,
/// the stored value's range and the write-time rules.</p>
/// <p>It creates no principal and spawns no job. Start records are seeded straight into
/// <code>^OcuPilotTurnStarts</code>, which the suite's own account can write. After every method the
/// probe user's turns and start records are removed by exact key and the switch row is reset.</p>
Class OcuPilot.Test.TurnHourLimit Extends %UnitTest.TestCase
{

/// <p>A user name the instance does not hold (a weak reference, AD-37).</p>
Parameter PROBEUSER = "OcuPilotProbeHourLimit";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter LOSTCODE = "TURN.ABANDONED.JOBLOST";

/// <p>The turn keys this method reserved, removed after it.</p>
Property Reserved [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ..Clean()
    Quit ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ..Clean()
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(..#PROBEUSER), 0, "no probe turn survives the method")
    Do $$$AssertEquals(..NodeCount(), 0, "and no probe start record")
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row is removed, so no limit is left set")
    Quit $$$OK
}

/// <p>Remove every turn this method reserved, by key, and the probe user's start records.</p>
Method Clean()
{
    Set tKey = $Order(..Reserved(""))
    While tKey '= "" {
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey)
        Set tKey = $Order(..Reserved(tKey))
    }
    Kill ..Reserved
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts(..#PROBEUSER)
}

/// <p>Reserve for the probe user under <var>pLimit</var> turns an hour.</p>
Method Reserve(pLimit As %Integer, Output pKey As %String, Output pBusy As %Boolean, Output pLimited As %Boolean, Output pRetry As %Integer) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(..#PROBEUSER, "", ..#LOSTCODE, ..#LIMITS, .pKey, .pBusy, .tSweep, pLimit, .pLimited, .pRetry)
    If $Get(pKey) '= "" Set ..Reserved(pKey) = ""
    Quit tSC
}

/// <p>Seed one start record at <var>pSeconds</var> (<method>OcuPilot.Kernel.State.Turn.NowSeconds</method>
/// units).</p>
Method Seed(pSeconds As %Integer, pKey As %String)
{
    Set ^OcuPilotTurnStarts(..#PROBEUSER, pSeconds, pKey) = ""
}

/// <p>How many start records the probe user holds.</p>
ClassMethod NodeCount() As %Integer
{
    Set tCount = 0
    Set tSeconds = $Order(^OcuPilotTurnStarts(..#PROBEUSER, ""))
    While tSeconds '= "" {
        Set tKey = $Order(^OcuPilotTurnStarts(..#PROBEUSER, tSeconds, ""))
        While tKey '= "" {
            Set tCount = tCount + 1
            Set tKey = $Order(^OcuPilotTurnStarts(..#PROBEUSER, tSeconds, tKey))
        }
        Set tSeconds = $Order(^OcuPilotTurnStarts(..#PROBEUSER, tSeconds))
    }
    Quit tCount
}

/// <p>Whether a start record exists for turn <var>pKey</var>.</p>
ClassMethod Recorded(pKey As %String) As %Boolean
{
    If pKey = "" Quit 0
    Set tSeconds = $Order(^OcuPilotTurnStarts(..#PROBEUSER, ""))
    While tSeconds '= "" {
        If $Data(^OcuPilotTurnStarts(..#PROBEUSER, tSeconds, pKey)) Quit
        Set tSeconds = $Order(^OcuPilotTurnStarts(..#PROBEUSER, tSeconds))
    }
    Quit tSeconds '= ""
}

/// <p>AC2: with no switch row the limit reads 0, and a user with five starts in the window is
/// reserved as before, the start still recorded.</p>
/// <p>Mutation (Rule 19): <code>DEFAULTTURNSPERHOUR = 1</code> -- the reserve is refused and this
/// goes red.</p>
Method TestNoLimitByDefaultRefusesNothingAndStillRecords()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues), "the switches resolve")
    Do $$$AssertEquals(tValues("turnsPerHour"), 0, "with no row, turns an hour reads 0")
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    For tI = 1:1:5 Do ..Seed(tNow - (tI * 60), "seed" _ tI)
    Do $$$AssertStatusOK(..Reserve(tValues("turnsPerHour"), .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tBusy _ "|" _ tLimited, "0|0", "and is neither busy nor limited")
    Do $$$AssertTrue(tKey '= "", "a turn is reserved")
    Do $$$AssertTrue(..Recorded(tKey), "and its start is recorded")
    Do $$$AssertEquals(..NodeCount(), 6, "beside the five already counted")
}

/// <p>Under the limit: n=3 with two starts in the window reserves, and a third record is
/// written.</p>
Method TestUnderTheLimitReservesAndRecords()
{
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Do ..Seed(tNow - 600, "seed1")
    Do ..Seed(tNow - 300, "seed2")
    Do $$$AssertStatusOK(..Reserve(3, .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tLimited, 0, "two of three is not the limit")
    Do $$$AssertTrue(tKey '= "", "a turn is reserved")
    Do $$$AssertEquals(..NodeCount(), 3, "and a third start is recorded")
}

/// <p>At the limit: n=3 with three starts in the window is refused, nothing is reserved or
/// recorded, and the retry time is the oldest start plus the window, rounded up to the next whole
/// minute -- unchanged when it already falls on a minute.</p>
/// <p>Mutation (Rule 19): remove the count check in <method>OcuPilot.Kernel.State.Turn.GuardedReserve</method>
/// -- the refusal assertions go red. Drop the minute round-up -- the retry assertion goes red.</p>
Method TestAtTheLimitIsRefusedWithTheRetryRoundedUp()
{
    Set tWindow = $Parameter(..#LIMITS, "TURNLIMITWINDOWSECONDS")
    Do $$$AssertEquals(tWindow, 3600, "the window is an hour")
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tBase = tNow - 1200
    Set tOldest = tBase - (tBase # 60) + 1
    Do ..Seed(tOldest, "seed1")
    Do ..Seed(tNow - 300, "seed2")
    Do ..Seed(tNow - 30, "seed3")
    Do $$$AssertStatusOK(..Reserve(3, .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tBusy _ "|" _ tLimited, "0|1", "and is refused for the limit, not as busy")
    Do $$$AssertEquals(tKey, "", "no turn key is minted")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(..#PROBEUSER), 0, "no row is inserted")
    Do $$$AssertEquals(..NodeCount(), 3, "and no start is recorded")
    Do $$$AssertEquals(tRetry, tOldest + 3600 + 59, "the retry is the oldest start's hour, rounded up to the next minute")
    Do $$$AssertEquals(tRetry # 60, 0, "on a whole minute")
    Set tIso = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(tRetry)
    Do $$$AssertTrue($Match(tIso, "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:00Z$"), "as ISO-8601 UTC: " _ tIso)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Turn).SecondsOf(tIso), tRetry, "which reads back to the same second")

    Do ..Clean()
    Set tOnMinute = tBase - (tBase # 60)
    Do ..Seed(tOnMinute, "seed1")
    Do ..Seed(tNow - 30, "seed2")
    Do $$$AssertStatusOK(..Reserve(2, .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tLimited, 1, "two of two is the limit")
    Do $$$AssertEquals(tRetry, tOnMinute + 3600, "and a retry already on a minute is not moved")
}

/// <p>A lowered limit: n=2 with five starts in the window is refused, and the retry comes from the
/// fourth-oldest start, the one whose ageing out leaves one start under the limit.</p>
Method TestALoweredLimitRetriesFromTheFourthOldest()
{
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tBase = tNow - 1800
    Set tStart = tBase - (tBase # 60)
    For tI = 1:1:5 Do ..Seed(tStart + (tI * 120), "seed" _ tI)
    Do $$$AssertStatusOK(..Reserve(2, .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tLimited, 1, "five of two is refused")
    Do $$$AssertEquals(tRetry, tStart + (4 * 120) + 3600, "with the fourth-oldest start's hour")
    Do $$$AssertEquals(..NodeCount(), 5, "and nothing recorded")
}

/// <p>Aged out: a start at or before the window's start is pruned at the reserve and not counted,
/// so n=1 reserves.</p>
/// <p>Mutation (Rule 19): stop pruning in <method>OcuPilot.Kernel.State.Base.GuardedTurnStartsPrune</method>
/// -- the two old starts are counted, the reserve is refused and this goes red.</p>
Method TestAStartOlderThanTheWindowIsPrunedAndNotCounted()
{
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Do ..Seed(tNow - 4000, "old1")
    Do ..Seed(tNow - 3600, "old2")
    Do $$$AssertStatusOK(..Reserve(1, .tKey, .tBusy, .tLimited, .tRetry), "the reserve completes")
    Do $$$AssertEquals(tLimited, 0, "starts an hour old or more do not count")
    Do $$$AssertTrue(tKey '= "", "a turn is reserved")
    Do $$$AssertEquals(..NodeCount(), 1, "the old starts are pruned and the new one recorded")
    Do $$$AssertTrue(..Recorded(tKey), "under the new turn's key")
}

/// <p>Busy and at the limit: a user whose queued turn is still live is refused busy, never for the
/// limit, and nothing more is reserved.</p>
Method TestABusyUserAtTheLimitIsRefusedBusy()
{
    Do $$$AssertStatusOK(..Reserve(0, .tFirst, .tBusy, .tLimited, .tRetry), "a first turn is reserved and left queued")
    Do $$$AssertTrue(tFirst '= "", "with a key")
    Do $$$AssertStatusOK(..Reserve(1, .tKey, .tBusy, .tLimited, .tRetry), "the second reserve completes")
    Do $$$AssertEquals(tBusy _ "|" _ tLimited, "1|0", "and is refused as busy first")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(..#PROBEUSER), 1, "one turn stands")
    Do $$$AssertEquals(..NodeCount(), 1, "with its one start")
}

/// <p><method>OcuPilot.Kernel.State.Switch.Resolve</method> answers a stored limit in range, and
/// reads an out-of-range or empty stored value as 0.</p>
Method TestTheSwitchReadsTurnsPerHourAndClampsAStoredValue()
{
    For tCase = "3|3", "10000|10000", "0|0", "10001|0", "-1|0" {
        Kill tValues
        Set tValues("turnsPerHour") = $Piece(tCase, "|")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), $Piece(tCase, "|") _ ": stored")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tRead), "and resolved")
        Do $$$AssertEquals(tRead("turnsPerHour"), $Piece(tCase, "|", 2), $Piece(tCase, "|") _ ": reads " _ $Piece(tCase, "|", 2))
    }
    &sql(UPDATE OcuPilot_Kernel_State.SwitchState SET TurnsPerHour = NULL)
    Do $$$AssertEquals(SQLCODE, 0, "an empty stored value is written")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tRead), "and resolved")
    Do $$$AssertEquals(tRead("turnsPerHour"), 0, "an empty stored value reads 0")
}

/// <p>The write-time rules: turns an hour is a whole number from 0 to 10,000, and turns running at
/// once is 1; each applies only when present.</p>
Method TestTheRulesRefuseAnOutOfRangeLimitAndAnyOtherConcurrentValue()
{
    Set tCode = ##class(OcuPilot.Api.Error).#AGENTSWITCHTURNSPERHOUR
    For tCase = "-1|1", "10001|1", "1.5|1", "|1", "0|0", "10000|0", "3|0" {
        Kill tValues
        Set tValues("contextRowCap") = 200
        Set tValues("turnsPerHour") = $Piece(tCase, "|")
        Set tCount = ##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations)
        Do $$$AssertEquals(tCount, $Piece(tCase, "|", 2), $Piece(tCase, "|") _ ": " _ $Piece(tCase, "|", 2) _ " violation")
        If tCount Do $$$AssertEquals($List(tViolations(1), 1) _ "|" _ $List(tViolations(1), 2), "turnsPerHour|" _ tCode, "on its own field and code")
    }
    Set tCode = ##class(OcuPilot.Api.Error).#AGENTSWITCHCONCURRENTTURNS
    For tCase = "2|1", "0|1", "|1", "1|0" {
        Kill tValues
        Set tValues("contextRowCap") = 200
        Set tValues("concurrentTurns") = $Piece(tCase, "|")
        Set tCount = ##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations)
        Do $$$AssertEquals(tCount, $Piece(tCase, "|", 2), "concurrent " _ $Piece(tCase, "|") _ ": " _ $Piece(tCase, "|", 2) _ " violation")
        If tCount Do $$$AssertEquals($List(tViolations(1), 1) _ "|" _ $List(tViolations(1), 2), "concurrentTurns|" _ tCode, "on its own field and code")
    }
    Kill tValues
    Set tValues("contextRowCap") = 200
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations), 0, "neither rule applies when its value is absent")
}

}
