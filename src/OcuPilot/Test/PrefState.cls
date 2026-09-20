/// <p>The per-user preferences store (<class>OcuPilot.Kernel.State.Pref</class>, Story 15.2,
/// AD-50). What is pinned here is the key contract -- one row per
/// <code>(UserName, Kind, Name)</code>, per-user isolation, the two caps and the two orders -- and
/// the weak reference (AD-37): a user the instance does not hold and a route no screen declares
/// are both legitimate rows that read back verbatim.</p>
/// <p><b>It needs nothing of the environment but the protected database.</b> It creates no IRIS
/// principal and no route, so it carries no arming guard
/// (<class>OcuPilot.Test.SwitchFixture</class>'s precedent) and runs on a development instance.
/// Every row it writes is removed in <method>OnAfterOneTest</method>, which then asserts none
/// survives -- and it removes only its own probe users' rows, never the whole table, because a
/// real account's favorites live in the same one.</p>
Class OcuPilot.Test.PrefState Extends %UnitTest.TestCase
{

/// <p>The probe account this class writes most of its rows for. Not an account the instance
/// holds: the user is a weak reference, which is what makes that safe.</p>
Parameter PROBEUSER As %String = "OcuPilotProbePrefOne";

/// <p>A second probe account, for the isolation leg.</p>
Parameter PROBEUSERTWO As %String = "OcuPilotProbePrefTwo";

/// <p>A route no screen declares. The store stores it; dropping it from a rendered list is the
/// client's job (AD-37).</p>
Parameter GHOSTROUTE As %String = "ocupilot-probe/no-such-screen";

Method OnBeforeOneTest() As %Status
{
    Do ..Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(..Reset(), "every row this class wrote is removed")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 0, "and no favorite of the first probe user survives")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), 0, "nor a recent of it")
    Do $$$AssertEquals(..Rows(..#PROBEUSERTWO, "favorite"), 0, "nor a favorite of the second")
    Do $$$AssertEquals(..Rows(..#PROBEUSERTWO, "recent"), 0, "nor a recent of it")
    Quit $$$OK
}

/// <p>Remove both probe users' rows of both kinds.</p>
ClassMethod Reset() As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear(..#PROBEUSER, "favorite")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear(..#PROBEUSER, "recent")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear(..#PROBEUSERTWO, "favorite")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedClear(..#PROBEUSERTWO, "recent")
}

/// <p>How many rows <var>pUser</var> holds of <var>pKind</var>, or -1 when the count failed.</p>
ClassMethod Rows(pUser As %String, pKind As %String) As %Integer
{
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedCountForUser(pUser, pKind, .tCount)
    If $$$ISERR(tSC) Quit -1
    Quit +tCount
}

/// <p>The routes <var>pUser</var>'s <var>pKind</var> list answers, comma-joined in the order the
/// store returned them.</p>
ClassMethod RouteList(pUser As %String, pKind As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, pKind, .tRows)
    If $$$ISERR(tSC) Quit "<error>"
    Set tOut = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.route
    }
    Quit tOut
}

/// <p>The id of one row, read with ordinary SQL as the suite's own privileged account -- the
/// fixture idiom <class>OcuPilot.Test.SwitchFixture</class> uses to look into the protected
/// database without going through the store. <code>""</code> when no row matches.</p>
ClassMethod RowId(pUser As %String, pKind As %String, pName As %String) As %String
{
    Set tId = ""
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Pref WHERE UserName = ? AND Kind = ? AND Name = ?", pUser, pKind, pName)
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tId = tRS.%GetData(1)
    } Catch ex {
        Set tId = ""
    }
    Quit tId
}

/// <p><b>The route column holds a route of the declared length</b>: a property's
/// <code>MAXLEN</code> cannot read a parameter, so the two numbers are held equal here rather than
/// by the compiler -- the idiom <class>OcuPilot.Test.Ledger</class> established.</p>
Method TestTheRouteColumnMatchesTheDeclaredRouteCap()
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId("OcuPilot.Kernel.State.Pref||Name")
    Do $$$AssertTrue($IsObject(tProperty), "the Name property is compiled")
    If '$IsObject(tProperty) Quit
    Do $$$AssertEquals(+tProperty.Parameters.GetAt("MAXLEN"), ##class(OcuPilot.Kernel.State.Pref).#ROUTEMAXLENGTH, "and its MAXLEN is the declared route cap")
}

/// <p><b>One user's preferences are not another's.</b> The key carries the user name, so a row
/// written for one account is absent from every other account's list.</p>
/// <p>Mutation: drop <code>UserName = ?</code> from
/// <method>OcuPilot.Kernel.State.Pref.IdsForUser</method>'s statements -- this goes red on the
/// second user's count.</p>
Method TestPerUserIsolation()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tAtLimit), "the first user pins a screen")
    Do $$$AssertEquals(tAtLimit, 0, "and is not at the limit")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 1, "the first user holds it")
    Do $$$AssertEquals(..Rows(..#PROBEUSERTWO, "favorite"), 0, "and the second user holds nothing")
    Do $$$AssertEquals(..RouteList(..#PROBEUSERTWO, "favorite"), "", "whose list is empty, which is an ordinary answer")
}

/// <p><b>One row per <code>(user, kind, name)</code>.</b> A second add of the same route is a
/// no-op that still answers success, and the same route under the other kind is a different
/// row.</p>
/// <p>Mutation: delete <index>PrefUserKindNameIdx</index>'s <code>Unique</code> keyword and drop
/// the existing-row branch from <method>OcuPilot.Kernel.State.Pref.GuardedAdd</method> -- the
/// count goes to 2 and this goes red.</p>
Method TestTheKeyHoldsOneRowPerUserKindAndName()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tFirst), "the screen is pinned")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tSecond), "and pinning it again succeeds")
    Do $$$AssertEquals(tSecond, 0, "without reporting the limit")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 1, "leaving one row")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "logs/alerts"), "the same route is visited")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), 1, "which is a row of its own kind")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 1, "and leaves the favorite alone")
}

/// <p><b>Both halves of the key are weak references</b> (AD-37): a user name the instance does not
/// hold and a route no screen declares are a legitimate row that reads back verbatim and fails no
/// read.</p>
Method TestAGhostUserAndAGhostRouteRoundTrip()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", ..#GHOSTROUTE, 20, .tAtLimit), "a route no screen declares is stored")
    Do $$$AssertEquals(..RouteList(..#PROBEUSER, "favorite"), ..#GHOSTROUTE, "and reads back verbatim")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedRemove(..#PROBEUSER, "favorite", ..#GHOSTROUTE), "and can be removed by the same key")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 0, "leaving nothing")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedRemove(..#PROBEUSER, "favorite", "never-stored"), "removing a row the user does not hold is an ordinary answer")
}

/// <p><b>Favorites are bounded on the instance, not by the client.</b> The twenty-first is refused
/// and nothing is written; an add of a route already held is still a no-op at the bound.</p>
/// <p>Mutation: delete the <code>pAtLimit</code> branch from
/// <method>OcuPilot.Kernel.State.Pref.GuardedAdd</method> -- the refusal disappears and this goes
/// red on both the flag and the count.</p>
Method TestFavoritesAreRefusedAtTheDeclaredMaximum()
{
    Set tMax = ##class(OcuPilot.Kernel.State.Pref).#FAVORITEMAX
    For tI = 1:1:tMax {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "probe/screen" _ tI, tMax, .tAtLimit), "favorite " _ tI _ " is stored")
        Do $$$AssertEquals(tAtLimit, 0, "without reporting the limit at " _ tI)
    }
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), tMax, "the account holds the maximum")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "probe/one-too-many", tMax, .tOver), "the next add answers rather than failing")
    Do $$$AssertEquals(tOver, 1, "and reports the limit")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), tMax, "having written nothing")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "probe/screen1", tMax, .tHeld), "re-adding one already held is still a no-op at the bound")
    Do $$$AssertEquals(tHeld, 0, "rather than a refusal")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedClear(..#PROBEUSER, "favorite"), "clearing removes them all")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 0, "leaving none")
}

/// <p><b>Recents read newest-first and the store trims the oldest.</b> Twelve visits leave the ten
/// newest, in visit order, most recent first.</p>
/// <p>Mutation: change <method>OcuPilot.Kernel.State.Pref.IdsForUser</method>'s recent branch to
/// <code>ORDER BY ID</code> -- the order assertion goes red. Delete the
/// <method>OcuPilot.Kernel.State.Pref.GuardedTrim</method> call in
/// <method>OcuPilot.Api.Preferences.Apply</method>, or the loop in
/// <method>OcuPilot.Kernel.State.Pref.GuardedTrim</method> -- the count assertion goes red.</p>
Method TestRecentsReadNewestFirstAndTrimToTheDeclaredMaximum()
{
    Set tKeep = ##class(OcuPilot.Kernel.State.Pref).#RECENTMAX
    Set tVisits = tKeep + 2
    For tI = 1:1:tVisits {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/visit" _ tI), "visit " _ tI _ " is registered")
        ; The order column is a one-second ISO stamp, so the visits are separated far enough apart
        ; for "newest first" to be a fact about the data rather than about insertion order.
        Hang 1.1
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTrim(..#PROBEUSER, "recent", tKeep), "the list is trimmed")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), tKeep, "to the declared maximum")

    Set tExpected = ""
    For tI = tVisits:-1:(tVisits - tKeep + 1) {
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ "probe/visit" _ tI
    }
    Do $$$AssertEquals(..RouteList(..#PROBEUSER, "recent"), tExpected, "newest first, oldest dropped")

    ; A revisit moves an old route back to the front rather than adding a second row.
    Hang 1.1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/visit" _ (tVisits - 1)), "an earlier screen is visited again")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), tKeep, "which adds no row")
    Do $$$AssertEquals($Piece(..RouteList(..#PROBEUSER, "recent"), ",", 1), "probe/visit" _ (tVisits - 1), "and moves it to the front")
}

/// <p><b>Two visits inside one second still order.</b> The recorder fires on every arrival, which
/// is routinely sub-second, so A then B then A again with no wait must leave A at the front --
/// the acceptance criterion's "the just-visited screen moves to the front", not "unless it was
/// quick".</p>
/// <p>Mutation: lower <method>OcuPilot.Kernel.State.Pref.Stamp</method>'s precision -- at whole
/// seconds, and at milliseconds too, the three stamps tie,
/// <method>OcuPilot.Kernel.State.Pref.IdsForUser</method> falls back to row-creation order, and
/// this goes red on the front route.</p>
Method TestARevisitInsideOneSecondStillMovesToTheFront()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/quickA"), "A is visited")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/quickB"), "then B")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/quickA"), "then A again, with no wait between them")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), 2, "which leaves two rows")
    Do $$$AssertEquals(..RouteList(..#PROBEUSER, "recent"), "probe/quickA,probe/quickB", "A back at the front")
}

/// <p><b>Favorites read oldest-first</b>, which is the order they were pinned in.</p>
Method TestFavoritesReadOldestFirst()
{
    For tI = 1:1:3 {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "probe/pinned" _ tI, 20, .tAtLimit), "favorite " _ tI _ " is pinned")
    }
    Do $$$AssertEquals(..RouteList(..#PROBEUSER, "favorite"), "probe/pinned1,probe/pinned2,probe/pinned3", "in the order they were pinned")
}

/// <p><b>A visit that loses the conditional write is not a failure.</b> Another tab registering the
/// same visit first makes the caller's outcome already true, so the stale save is swallowed
/// (<class>OcuPilot.Kernel.State.Nav</class>'s precedent) rather than surfaced.</p>
/// <p>The race is produced without a second process: <method>%OpenId</method> hands back an object
/// that is still in memory rather than re-reading it (<file>.claude/rules/objectscript-basics.md</file>),
/// so a reference held here with a <property>RowVersion</property> the stored row does not carry is
/// what <method>OcuPilot.Kernel.State.Pref.GuardedTouch</method> opens, and its conditional
/// <code>UPDATE</code> matches nothing.</p>
/// <p>Mutation: delete the <code>IsStaleSave</code> line from
/// <method>OcuPilot.Kernel.State.Pref.GuardedTouch</method> -- the refusal propagates and this goes
/// red.</p>
Method TestALostVisitRaceIsSwallowedRatherThanRaised()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/raced"), "the visit is registered once")
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(..#PROBEUSER, "recent", .tRows)
    Do $$$AssertStatusOK(tSC, "the row reads back")
    Do $$$AssertEquals(tRows.%Size(), 1, "as one row")

    Set tId = ..RowId(..#PROBEUSER, "recent", "probe/raced")
    Do $$$AssertNotEquals(tId, "", "and its id is found")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedOpenId(tId, .tHeld), "the row opens")
    Do $$$AssertTrue($IsObject(tHeld), "as an object")
    If '$IsObject(tHeld) Quit
    Set tHeld.RowVersion = 9999

    Set tRaced = ##class(OcuPilot.Kernel.State.Pref).GuardedTouch(..#PROBEUSER, "recent", "probe/raced")
    Set tHeld = ""
    Do $$$AssertStatusOK(tRaced, "the losing visit answers success, because the outcome it asked for is already true")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "recent"), 1, "and no second row was written")
}

}
