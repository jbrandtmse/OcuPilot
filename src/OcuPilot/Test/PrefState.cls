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
    Do $$$AssertEquals(..Rows(..#PROBEUSER, ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW), 0, "nor a remembered table view")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH), 0, "nor a remembered refresh rate")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL), 0, "nor a remembered piece of shell chrome")
    Quit $$$OK
}

/// <p>Remove both probe users' rows of every kind this store holds.</p>
ClassMethod Reset() As %Status
{
    Set tKinds = $ListBuild("favorite", "recent", ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW, ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL)
    Set tUsers = $ListBuild(..#PROBEUSER, ..#PROBEUSERTWO)
    Set tSC = $$$OK
    For tU = 1:1:$ListLength(tUsers) {
        For tK = 1:1:$ListLength(tKinds) {
            Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear($List(tUsers, tU), $List(tKinds, tK))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>The values <var>pUser</var>'s <var>pKind</var> rows answer, comma-joined as
/// <code>key=value</code> in the order the store returned them.</p>
ClassMethod ValueList(pUser As %String, pKind As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, pKind, .tRows)
    If $$$ISERR(tSC) Quit "<error>"
    Set tOut = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.route _ "=" _ tRow.value
    }
    Quit tOut
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
        ; Separated past a whole second deliberately, which is the case a stamp of any resolution
        ; orders. It is the weaker of the two: with these Hangs the assertion below cannot tell
        ; ORDER BY UpdatedAt DESC from ORDER BY ID DESC, so the sub-second sibling
        ; TestARevisitInsideOneSecondStillMovesToTheFront is what pins the ordering column. The
        ; two are kept apart rather than merged so the second-boundary case stays covered.
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

/// <p><b>The value column holds a value of the declared length</b>, the way the route column holds
/// a route: a property's <code>MAXLEN</code> cannot read a parameter, so the two numbers are held
/// equal here.</p>
Method TestTheValueColumnMatchesTheDeclaredValueCap()
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId("OcuPilot.Kernel.State.Pref||Value")
    Do $$$AssertTrue($IsObject(tProperty), "the Value property is compiled")
    If '$IsObject(tProperty) Quit
    Do $$$AssertEquals(+tProperty.Parameters.GetAt("MAXLEN"), ##class(OcuPilot.Kernel.State.Pref).#VALUEMAXLENGTH, "and its MAXLEN is the declared value cap")
}

/// <p><b>A value round-trips through <method>Text</method> and is keyed by the same triple.</b> A
/// second set of the same key replaces the value rather than adding a row, and the same key under
/// another kind is a different row.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.State.Pref.GuardedSetValue</method> skip the
/// assignment to <property>Value</property> -- the value reads back empty and this goes red.</p>
Method TestAValueRoundTripsAndIsKeyedByTheSameTriple()
{
    Set tView = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tRate = ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tView, "logs/alerts", "sort=Name"), "a view is remembered")
    Do $$$AssertEquals(..ValueList(..#PROBEUSER, tView), "logs/alerts=sort=Name", "and reads back verbatim")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tView), 1, "as one row")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tView, "logs/alerts", "sort=Time"), "setting it again replaces the value")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tView), 1, "without adding a row")
    Do $$$AssertEquals(..ValueList(..#PROBEUSER, tView), "logs/alerts=sort=Time", "and answers the newer value")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tRate, "logs/alerts", "30"), "the same route under another kind is a row of its own")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tRate), 1, "which exists")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tView), 1, "and leaves the view alone")
    Do $$$AssertEquals(..RouteList(..#PROBEUSER, "favorite"), "", "no membership row was written")
}

/// <p><b>A membership row reads its value as the safe default.</b> The two membership kinds never
/// write <property>Value</property>, so a favorite reads back with an empty one -- which is also
/// what every row written before the column existed reads, the reason this did not move
/// <code>SCHEMAVERSION</code>.</p>
Method TestAMembershipRowReadsAnEmptyValue()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tAtLimit), "a screen is pinned")
    Do $$$AssertEquals(..ValueList(..#PROBEUSER, "favorite"), "logs/alerts=", "and its value reads empty")
}

/// <p><b>The three value kinds are never trimmed.</b> Each holds one row per key rather than a
/// bounded list, so more rows than <parameter>OcuPilot.Kernel.State.Pref.RECENTMAX</parameter>
/// survive, and trimming the recents list leaves them untouched.</p>
Method TestTheValueKindsAreNotTrimmed()
{
    Set tView = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tKeep = ##class(OcuPilot.Kernel.State.Pref).#RECENTMAX
    Set tRows = tKeep + 2
    For tI = 1:1:tRows {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tView, "probe/view" _ tI, "maxRows=" _ tI), "view " _ tI _ " is remembered")
    }
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tView), tRows, "every one is held")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedTrim(..#PROBEUSER, "recent", tKeep), "trimming the recents list")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tView), tRows, "leaves the views where they are")
}

/// <p><b>A unique-index violation is recognized as one</b> (DW-1327), which is what lets the three
/// create paths answer their documented outcome instead of a 500. The violation is produced here
/// by saving a second row on a key the store already holds -- the same status a create losing the
/// race receives.</p>
/// <p>The interleaving itself is not reproducible inside one process; what is pinned is the
/// detector against the real error and the outcome the caller sees.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.State.Base.IsDuplicateKey</method> answer 0 -- the
/// first assertion goes red.</p>
Method TestADuplicateKeyIsRecognizedAndAnswersTheDocumentedOutcome()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tAtLimit), "the row is created once")

    Set tClash = ##class(OcuPilot.Kernel.State.Pref).%New()
    Set tClash.UserName = ..#PROBEUSER
    Set tClash.Kind = "favorite"
    Set tClash.Name = "logs/alerts"
    Set tClash.UpdatedAt = "2026-09-20T00:00:00.000000Z"
    Set tSaved = ##class(OcuPilot.Kernel.State.Pref).GuardedSave(tClash)
    Set tClash = ""
    Do $$$AssertStatusNotOK(tSaved, "a second row on the same key is refused by the unique index")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Base).IsDuplicateKey(tSaved), "and is recognized as a duplicate key rather than as a write failure")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Base).IsDuplicateKey($$$OK), "success is never a duplicate key")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedAdd(..#PROBEUSER, "favorite", "logs/alerts", 20, .tAgain), "and the caller's own add answers the documented no-op")
    Do $$$AssertEquals(tAgain, 0, "without reporting the limit")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, "favorite"), 1, "leaving one row")
}

/// <p><b>A value write that loses the conditional save is refused, not swallowed.</b> A lost visit
/// leaves the caller's outcome already true (<method>GuardedTouch</method>); a lost value write
/// leaves a value the caller did not ask for, so the refusal reaches the handler, which renders
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter>.</p>
/// <p>The race is produced without a second process, on
/// <method>TestALostVisitRaceIsSwallowedRatherThanRaised</method>'s mechanism: a reference held
/// here carries a <property>RowVersion</property> the stored row does not, so the conditional
/// <code>UPDATE</code> matches nothing.</p>
/// <p>Mutation: swallow the stale save in
/// <method>OcuPilot.Kernel.State.Pref.GuardedSetValue</method> -- this goes red.</p>
Method TestALostValueWriteIsRefusedRatherThanSwallowed()
{
    Set tShell = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL
    Set tMember = ##class(OcuPilot.Kernel.State.Pref).#SHELLSIDEBAROPEN
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tShell, tMember, "1"), "the member is remembered once")

    Set tId = ..RowId(..#PROBEUSER, tShell, tMember)
    Do $$$AssertNotEquals(tId, "", "and its id is found")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedOpenId(tId, .tHeld), "the row opens")
    Do $$$AssertTrue($IsObject(tHeld), "as an object")
    If '$IsObject(tHeld) Quit
    Set tHeld.RowVersion = 9999

    Set tRaced = ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#PROBEUSER, tShell, tMember, "0")
    Set tHeld = ""
    Do $$$AssertStatusNotOK(tRaced, "the losing write is refused")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Base).IsStaleSave(tRaced), "as a stale save, which the handler renders as a conflict")
    Do $$$AssertEquals(..Rows(..#PROBEUSER, tShell), 1, "and no second row was written")
}

/// <p><b>A shell member is one of a closed set.</b> The store owns that vocabulary, so the handler
/// and the store cannot disagree about what shell chrome this instance remembers.</p>
Method TestTheShellMemberSetIsClosed()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Pref).IsShellMember(##class(OcuPilot.Kernel.State.Pref).#SHELLSIDEBAROPEN), "the side bar's open state is a member")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Pref).IsShellMember(##class(OcuPilot.Kernel.State.Pref).#SHELLPANELWIDTH), "so is the panel's width")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Pref).IsShellMember(##class(OcuPilot.Kernel.State.Pref).#SHELLTHEME), "so is the theme")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Pref).IsShellMember("anything"), "and nothing else is")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Pref).IsShellMember(""), "including the empty name")
}

/// <p><b>The theme takes one of two values.</b> The store owns that vocabulary beside the member,
/// so the handler refuses anything else before a write.</p>
Method TestTheThemeValueSetIsClosed()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Pref).#SHELLTHEME, "theme", "the member is named theme on the wire")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Pref).IsThemeValue(##class(OcuPilot.Kernel.State.Pref).#THEMELIGHT), "light is a theme")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.State.Pref).IsThemeValue(##class(OcuPilot.Kernel.State.Pref).#THEMEDARK), "so is dark")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Pref).#THEMELIGHT, "light", "spelled as the client sends it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Pref).#THEMEDARK, "dark", "both of them")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Pref).IsThemeValue("purple"), "and nothing else is")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Pref).IsThemeValue("Dark"), "matched exactly, not by case")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.State.Pref).IsThemeValue(""), "including the empty value")
}

}
