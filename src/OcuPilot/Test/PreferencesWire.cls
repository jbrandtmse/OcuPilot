/// <p><code>GET</code> and <code>POST /account/preferences</code> over HTTP (Story 15.2, AD-50):
/// every row of the story's I/O matrix the instance owns, asserted on status, content type and
/// body shape through the shipped router rather than by calling the handler in process.</p>
/// <p><b>The caller is the suite's own HTTP account, and this class owns that account's preference
/// rows for the length of the run.</b> The route answers for <code>$Username</code> and no other,
/// so there is no second principal to write as; <method>OnBeforeOneTest</method> and
/// <method>OnAfterOneTest</method> clear the lists of the account the requests authenticate as --
/// <method>OcuPilot.Test.Http.GetTestUsername</method>'s, which is the one the handler sees and
/// need not be the process running the suite -- and the teardown asserts neither survives.</p>
/// <p>Three of the matrix's rows are the client's and are pinned in
/// <file>ui/tools/account-preferences.test.mjs</file> and the component specs instead: a stored
/// route that no longer resolves to a built screen, a favorite the caller may no longer open, and
/// an instance that did not answer.</p>
Class OcuPilot.Test.PreferencesWire Extends %UnitTest.TestCase
{

/// <p>The route under test, from the origin root.</p>
Parameter PREFERENCESPATH = "/api/ocupilot/account/preferences";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(..Clear(), "both of the calling account's lists are cleared")
    Do $$$AssertEquals(..Count("favorites"), 0, "and no favorite this class wrote survives")
    Do $$$AssertEquals(..Count("recents"), 0, "nor a recent item")
    Quit $$$OK
}

/// <p>Remove both lists of the account the requests authenticate as, through the store rather than
/// over the wire, so teardown cannot be defeated by the very refusal a test is exercising. The
/// account is the one the requests carry, never the process running them: the two need not be the
/// same, and clearing the wrong one would leave every row this class wrote behind.</p>
ClassMethod Clear() As %Status
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear(tUser, "favorite")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedClear(tUser, "recent")
}

/// <p>How many entries <var>pList</var> holds, read over the wire, or <code>-1</code> when the
/// read did not answer.</p>
ClassMethod Count(pList As %String) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#PREFERENCESPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit -1
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Quit tAnswer.%Get(pList).%Size()
}

/// <p>Every built screen's route, longest list first, as a <class>%List</class>. Read from the
/// registry rather than written down: the routes a test may store are exactly the routes the
/// handler admits, and a second copy of them here would drift.</p>
ClassMethod BuiltRoutes() As %List
{
    Set tOut = ""
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    If $$$ISERR(tSC) Quit tOut
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        If '$ClassMethod(tClass, "IsBuilt") Continue
        Set tRoute = $ClassMethod(tClass, "Route")
        If tRoute = "" Continue
        Set tOut = tOut _ $ListBuild(tRoute)
    }
    Quit tOut
}

/// <p>One request to the route as the suite's own credentials, with <var>pBody</var> sent verbatim
/// as <code>application/json</code>.</p>
ClassMethod Call(pMethod As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#PREFERENCESPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>The JSON body for one write. Built here so no test method spells the three member names
/// twice.</p>
ClassMethod Payload(pKind As %String, pAction As %String, pRoute As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("kind", pKind, "string")
    Do tBody.%Set("action", pAction, "string")
    If pAction '= "clear" Do tBody.%Set("route", pRoute, "string")
    Quit tBody.%ToJSON()
}

/// <p>The routes <var>pList</var> carries, comma-joined in the order the instance answered.</p>
ClassMethod Routes(pAnswer As %DynamicObject, pList As %String) As %String
{
    Set tOut = ""
    If '$IsObject(pAnswer) Quit tOut
    Set tArray = pAnswer.%Get(pList)
    If '$IsObject(tArray) Quit tOut
    Set tIterator = tArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tEntry.route
    }
    Quit tOut
}

/// <p><b>The read answers two arrays on a clean account</b>, each empty, and writes nothing.</p>
Method TestTheReadAnswersTwoEmptyListsOnACleanAccount()
{
    Set tSC = ..Call("GET", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("favorites"), "array", "carrying a favorites array")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("recents"), "array", "and a recents array")
    Do $$$AssertEquals(tAnswer.favorites.%Size(), 0, "both empty")
    Do $$$AssertEquals(tAnswer.recents.%Size(), 0, "on a clean account")
}

/// <p><b>Adding, re-adding, removing and clearing a favorite</b> each answer 200 with the body the
/// read would answer.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Preferences.HandleUpdate</method> answer
/// <code>{}</code> instead of re-rendering the read -- every assertion on the answered list goes
/// red.</p>
Method TestAFavoriteRoundTripsOverTheWire()
{
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) >= 2, "the instance declares at least two built screens")
    If $ListLength(tRoutes) < 2 Quit
    Set tFirst = $List(tRoutes, 1)
    Set tSecond = $List(tRoutes, 2)

    Set tSC = ..Call("POST", ..Payload("favorite", "add", tFirst), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the add completes")
    Do $$$AssertEquals(tStatus, 200, "and is applied: " _ tBody)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..Routes(tAnswer, "favorites"), tFirst, "answering the list the read would answer")

    Set tSC = ..Call("POST", ..Payload("favorite", "add", tFirst), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a second add of the same route is a no-op that still answers 200")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..Routes(tAnswer, "favorites"), tFirst, "leaving one entry")

    Set tSC = ..Call("POST", ..Payload("favorite", "add", tSecond), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a second screen is pinned")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..Routes(tAnswer, "favorites"), tFirst _ "," _ tSecond, "oldest first")

    Set tSC = ..Call("POST", ..Payload("favorite", "remove", tFirst), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "one is removed")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..Routes(tAnswer, "favorites"), tSecond, "leaving the other")

    Set tSC = ..Call("POST", ..Payload("favorite", "remove", tFirst), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "removing one the account does not hold is a no-op answering 200")

    Set tSC = ..Call("POST", ..Payload("favorite", "clear"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list is cleared")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.favorites.%Size(), 0, "leaving nothing")
}

/// <p><b>Registering a visit re-orders the recents list and trims it</b> to the declared maximum,
/// newest first.</p>
/// <p>Mutation: delete the <method>OcuPilot.Kernel.State.Pref.GuardedTrim</method> call in
/// <method>OcuPilot.Api.Preferences.Apply</method> -- the list keeps every visit and this goes
/// red.</p>
Method TestRegisteringVisitsOrdersAndTrimsTheRecentsList()
{
    Set tKeep = ##class(OcuPilot.Kernel.State.Pref).#RECENTMAX
    Set tRoutes = ..BuiltRoutes()
    Set tVisits = tKeep + 2
    Do $$$AssertTrue($ListLength(tRoutes) >= tVisits, "the instance declares enough built screens to overrun the cap")
    If $ListLength(tRoutes) < tVisits Quit

    For tI = 1:1:tVisits {
        Set tSC = ..Call("POST", ..Payload("recent", "add", $List(tRoutes, tI)), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "visit " _ tI _ " completes")
        Do $$$AssertEquals(tStatus, 200, "and is registered: " _ tBody)
    }
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.recents.%Size(), tKeep, "the list is capped at the declared maximum")

    Set tExpected = ""
    For tI = tVisits:-1:(tVisits - tKeep + 1) {
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ $List(tRoutes, tI)
    }
    Do $$$AssertEquals(..Routes(tAnswer, "recents"), tExpected, "newest first, the oldest visits dropped")

    Set tSC = ..Call("POST", ..Payload("recent", "clear"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list clears")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.recents.%Size(), 0, "leaving nothing")
}

/// <p><b>The twenty-first favorite is refused by the instance</b>, not by the client alone: 422
/// under the validation slug, with one violation on <code>route</code>.</p>
/// <p>Mutation: raise <parameter>OcuPilot.Kernel.State.Pref.FAVORITEMAX</parameter>, or delete the
/// <code>pAtLimit</code> branch in <method>OcuPilot.Kernel.State.Pref.GuardedAdd</method> -- the
/// add answers 200 and this goes red.</p>
Method TestTheFavoriteAfterTheLastIsRefusedByTheInstance()
{
    Set tMax = ##class(OcuPilot.Kernel.State.Pref).#FAVORITEMAX
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) > tMax, "the instance declares more built screens than the favorites cap")
    If $ListLength(tRoutes) '> tMax Quit

    For tI = 1:1:tMax {
        Set tSC = ..Call("POST", ..Payload("favorite", "add", $List(tRoutes, tI)), .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, "favorite " _ tI _ " is stored: " _ tBody)
    }
    Set tSC = ..Call("POST", ..Payload("favorite", "add", $List(tRoutes, tMax + 1)), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "and the add is refused: " _ tBody)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug")
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PREFERENCESLIMIT, "with the limit code")
    Do $$$AssertTrue($IsObject(tFault.detail), "carrying a detail object")
    If '$IsObject(tFault.detail) Quit
    Do $$$AssertEquals(tFault.detail.violations.%Size(), 1, "with one violation")
    Set tViolation = tFault.detail.violations.%Get(0)
    Do $$$AssertEquals(tViolation.field, "route", "on the field the caller can correct")
    Do $$$AssertEquals(tViolation.code, ##class(OcuPilot.Api.Error).#PREFERENCESLIMIT, "with the published code")
    Do $$$AssertEquals(tViolation.reason, ##class(OcuPilot.Api.Error).#REASONPREFERENCESLIMIT, "and the sentence written once on the server")
    Do $$$AssertEquals(..Count("favorites"), tMax, "and nothing was written")
}

/// <p><b>A route that is not a built screen's is refused</b>, whatever shape it takes: unknown,
/// empty, or longer than the declared route cap.</p>
/// <p>A <b>remove</b> is not gated the same way: it takes any string, so a row whose screen stopped
/// resolving stays removable.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Preferences.IsBuiltRoute</method> answer 1
/// unconditionally -- the adds succeed and this goes red. Ask it of the remove as well -- the
/// remove is refused 422 and the last leg goes red.</p>
Method TestAnUnknownRouteIsRefusedBeforeAnythingIsWritten()
{
    Set tLong = ""
    For tI = 1:1:60 {
        Set tLong = tLong _ "abcdefghij"
    }
    Set tCandidates = $ListBuild("no-such-area/no-such-screen", "", tLong, "agent/definitions/edit/../..")
    For tI = 1:1:$ListLength(tCandidates) {
        Set tRoute = $List(tCandidates, tI)
        Set tSC = ..Call("POST", ..Payload("favorite", "add", tRoute), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes for candidate " _ tI)
        Do $$$AssertEquals(tStatus, 422, "and the route is refused for candidate " _ tI _ ": " _ tBody)
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json for candidate " _ tI)
        Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope for candidate " _ tI)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug for candidate " _ tI)
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PREFERENCESROUTE, "with the route code for candidate " _ tI)
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "route", "on the route field for candidate " _ tI)
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).reason, ##class(OcuPilot.Api.Error).#REASONPREFERENCESROUTE, "with the server's own sentence for candidate " _ tI)
    }
    Do $$$AssertEquals(..Count("favorites"), 0, "and nothing was written")

    ; A remove names no route the registry has to know: a row whose screen stopped resolving is
    ; dropped from the client's rendering (AD-37), so refusing its remove would strand it.
    Set tSC = ..Call("POST", ..Payload("favorite", "remove", "no-such-area/no-such-screen"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the remove completes")
    Do $$$AssertEquals(tStatus, 200, "and a remove of a route no built screen declares is a no-op answering 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.favorites.%Size(), 0, "leaving the list as it was")
}

/// <p><b>A malformed body is one 422 naming the members and no value</b>, before anything is
/// written -- not JSON, not an object, an extra member, a missing member, a member of the wrong
/// type, or a value outside its enum.</p>
/// <p>Mutation: delete the <code>tExtra</code> test, or either enum check, from
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the matching leg goes red.</p>
Method TestAMalformedBodyIsOneRefusalNamingNoValue()
{
    Set tBodies = $ListBuild("not json at all", "[]", "{}", "{""kind"":""favorite""}", "{""action"":""add"",""route"":""logs/alerts""}", "{""kind"":""favorite"",""action"":""add"",""route"":1}", "{""kind"":""bookmark"",""action"":""add"",""route"":""logs/alerts""}", "{""kind"":""favorite"",""action"":""toggle"",""route"":""logs/alerts""}", "{""kind"":""favorite"",""action"":""clear"",""route"":""logs/alerts""}", "{""kind"":""favorite"",""action"":""add"",""route"":""logs/alerts"",""user"":""_SYSTEM""}")
    For tI = 1:1:$ListLength(tBodies) {
        Set tSent = $List(tBodies, tI)
        Set tSC = ..Call("POST", tSent, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes: " _ tSent)
        Do $$$AssertEquals(tStatus, 422, "refused: " _ tSent)
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json: " _ tSent)
        Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope: " _ tSent)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug: " _ tSent)
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PREFERENCESBODY, "with the body code: " _ tSent)
        Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.Error).#REASONPREFERENCESBODY, "and the published sentence: " _ tSent)
        Do $$$AssertEquals(tFault.%IsDefined("detail"), 0, "and no violations list, because no field was reached: " _ tSent)
        ; "Naming no value" is the half the assertions above cannot see: each of these bodies
        ; carries an offending value the envelope must not echo back (AD-35), and a handler that
        ; quoted it would satisfy every assertion before this one.
        Do $$$AssertEquals((tBody [ "bookmark") + (tBody [ "toggle") + (tBody [ "_SYSTEM"), 0, "and the refusal echoes no value the caller sent: " _ tSent _ " -> " _ tBody)
    }
    Do $$$AssertEquals(..Count("favorites"), 0, "and nothing was written")
    Do $$$AssertEquals(..Count("recents"), 0, "on either list")
}

}
