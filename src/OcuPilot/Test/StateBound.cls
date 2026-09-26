/// <p>The bounded-where guard (AD-21, <method>OcuPilot.Kernel.State.Base.BoundedWhere</method>): its
/// three modes, its refusals, and a cutoff bound as a parameter and never written into the text.</p>
/// <p><b>Live-safe</b>: the guard runs no SQL and touches nothing.</p>
Class OcuPilot.Test.StateBound Extends %UnitTest.TestCase
{

Parameter STORE = "OcuPilot.Kernel.State.Agent";

/// <p>UTC timestamp <var>pCutoff</var>, <code>YYYY-MM-DDTHH:MM:SSZ</code>, as seconds since the
/// <code>$Horolog</code> epoch.</p>
ClassMethod CutoffSeconds(pCutoff As %String) As %Integer
{
    Set tH = $ZDateTimeH($Translate($Extract(pCutoff, 1, 19), "T", " "), 3, 1)
    Quit ($Piece(tH, ",", 1) * 86400) + $Piece(tH, ",", 2)
}

/// <p>Now, UTC, as seconds since the <code>$Horolog</code> epoch, to the whole second.</p>
ClassMethod NowSeconds() As %Integer
{
    Set tNow = $ZTimeStamp
    Quit ($Piece(tNow, ",", 1) * 86400) + ($Piece(tNow, ",", 2) \ 1)
}

/// <p>Window 0 is the last 24 hours and 1 to 720 that many: the fragment leads with the time column's
/// predicate and binds the cutoff in the form OcuPilot's time columns store, which is never in the
/// text; predicates follow in parentheses, joined by <code>AND</code>.</p>
/// <p>Mutation: the cutoff written into the fragment instead of bound -> this goes red.</p>
Method TestAWindowBindsItsCutoff()
{
    For tCase = "0|24", "1|1", "720|720", "48|48" {
        Set tParams = ""
        Set tBefore = ..NowSeconds()
        Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", $Piece(tCase, "|", 1), "t.CreatedAt", .tParams, .tProblem, "%EXACT(UserName) = ?", "", "Kind = ?")
        Set tAfter = ..NowSeconds()
        Do $$$AssertEquals(tProblem, "", "window " _ $Piece(tCase, "|", 1) _ ": admitted")
        Do $$$AssertEquals(tFragment, "t.CreatedAt > ? AND (%EXACT(UserName) = ?) AND (Kind = ?)", "window " _ $Piece(tCase, "|", 1) _ ": the time predicate leads, the empty predicate is skipped")
        Do $$$AssertEquals($IsObject(tParams) && (tParams.%Size() = 1), 1, "window " _ $Piece(tCase, "|", 1) _ ": one value is bound")
        If '$IsObject(tParams) || (tParams.%Size() '= 1) Continue
        Set tCutoff = tParams.%Get(0)
        Do $$$AssertTrue($Match(tCutoff, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"), "window " _ $Piece(tCase, "|", 1) _ ": the cutoff is an ISO-8601 UTC timestamp, as the time columns store: " _ tCutoff)
        Set tSeconds = ..CutoffSeconds(tCutoff)
        Set tHours = $Piece(tCase, "|", 2)
        Do $$$AssertTrue((tSeconds >= (tBefore - (tHours * 3600))) && (tSeconds <= (tAfter - (tHours * 3600))), "window " _ $Piece(tCase, "|", 1) _ ": the cutoff is " _ tHours _ " hours before now")
        Do $$$AssertEquals(tFragment [ $Extract(tCutoff, 1, 10), 0, "window " _ $Piece(tCase, "|", 1) _ ": and the cutoff is not in the text")
        Do $$$AssertEquals(tFragment [ "'", 0, "window " _ $Piece(tCase, "|", 1) _ ": nor any quoted value")
    }

    Set tParams = ["first"]
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", 0, "TimeLogged", .tParams, .tProblem)
    Do $$$AssertEquals(tFragment _ "|" _ tParams.%Size() _ "|" _ tParams.%Get(0), "TimeLogged > ?|2|first", "a window with no predicate, appended after the caller's own values")

    Set tParams = ""
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", 1, "CreatedAt", .tParams, .tProblem, "Kind = ? OR Kind = ?")
    Do $$$AssertEquals(tFragment, "CreatedAt > ? AND (Kind = ? OR Kind = ?)", "an OR inside a predicate stays inside the window")
}

/// <p>Window -1 is keyed: no time predicate and no bound value, and at least one predicate.</p>
Method TestAKeyedReadEmitsNoTimePredicate()
{
    Set tParams = ""
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", -1, "", .tParams, .tProblem, "%EXACT(TurnKey) = ?")
    Do $$$AssertEquals(tFragment _ "|" _ tProblem _ "|" _ tParams.%Size(), "(%EXACT(TurnKey) = ?)||0", "the keyed predicate alone, nothing bound")
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", -1, "CreatedAt", .tParams, .tProblem)
    Do $$$AssertEquals(tFragment, "", "a keyed read with no predicate is refused")
    Do $$$AssertTrue(tProblem [ "keyed predicate", "naming what bounds it: " _ tProblem)
}

/// <p>Every other window, and a time column that is not a column name, is refused naming the bound
/// and binds nothing.</p>
/// <p>Mutation: the 720 check removed -> this goes red.</p>
Method TestAWindowOutsideTheBoundIsRefused()
{
    For tWindow = "721", "100000", "-2", "2.5", "", "abc", "01", " 5" {
        Set tParams = ""
        Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", tWindow, "CreatedAt", .tParams, .tProblem, "Kind = ?")
        Do $$$AssertEquals(tFragment, "", "window '" _ tWindow _ "' is refused")
        Do $$$AssertTrue((tProblem [ "720") && (tProblem [ "-1"), "window '" _ tWindow _ "': naming the bound: " _ tProblem)
        Do $$$AssertEquals(tParams.%Size(), 0, "window '" _ tWindow _ "': and binds nothing")
    }
    For tColumn = "", "Created At", "t.CreatedAt; DROP", "1Created", "a.b.c", "CreatedAt--" {
        Set tParams = ""
        Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", 24, tColumn, .tParams, .tProblem)
        Do $$$AssertEquals(tFragment _ "|" _ tParams.%Size(), "|0", "column '" _ tColumn _ "' is refused and binds nothing")
        Do $$$AssertTrue(tProblem [ "column", "column '" _ tColumn _ "': naming the rule: " _ tProblem)
    }
}

}
