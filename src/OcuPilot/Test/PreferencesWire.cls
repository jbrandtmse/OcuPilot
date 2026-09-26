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
/// <p>It runs only where <parameter>ARMINGVARIABLE</parameter> reads <code>1</code>, because it
/// clears that account's lists on the instance it runs against.</p>
Class OcuPilot.Test.PreferencesWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ACCOUNT_PREFERENCES";

/// <p>The route under test, from the origin root.</p>
Parameter PREFERENCESPATH = "/api/ocupilot/account/preferences";

/// <p>Refuse to run at all unless this instance is armed for clearing an account's preferences.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PreferencesWire clears the test account's favorites, recents and remembered views on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was cleared. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

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
    Do $$$AssertEquals(..Count("views"), 0, "nor a remembered table view")
    Do $$$AssertEquals(..Count("refreshRates"), 0, "nor a remembered refresh rate")
    Do $$$AssertEquals(..Count("shell"), 0, "nor a remembered piece of shell chrome")
    Quit $$$OK
}

/// <p>Remove both lists of the account the requests authenticate as, through the store rather than
/// over the wire, so teardown cannot be defeated by the very refusal a test is exercising. The
/// account is the one the requests carry, never the process running them: the two need not be the
/// same, and clearing the wrong one would leave every row this class wrote behind.</p>
ClassMethod Clear() As %Status
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tKinds = $ListBuild("favorite", "recent", ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW, ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL)
    Set tSC = $$$OK
    For tI = 1:1:$ListLength(tKinds) {
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedClear(tUser, $List(tKinds, tI))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
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

/// <p>The JSON body for one membership write. Built here so no test method spells the three member
/// names twice.</p>
ClassMethod Payload(pKind As %String, pAction As %String, pRoute As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("kind", pKind, "string")
    Do tBody.%Set("action", pAction, "string")
    If pAction '= "clear" Do tBody.%Set("route", pRoute, "string")
    Quit tBody.%ToJSON()
}

/// <p>The JSON body for one value write: <var>pKeyMember</var> is <code>route</code> for a
/// screen-scoped kind and <code>name</code> for a shell one.</p>
ClassMethod ValuePayload(pKind As %String, pKeyMember As %String, pKey As %String, pValue As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("kind", pKind, "string")
    Do tBody.%Set("action", "set", "string")
    Do tBody.%Set(pKeyMember, pKey, "string")
    Do tBody.%Set("value", pValue, "string")
    Quit tBody.%ToJSON()
}

/// <p>The one entry <var>pList</var> carries for <var>pKey</var> under <var>pKeyMember</var>, as
/// its <code>value</code>; <code>""</code> when the list holds no such entry.</p>
ClassMethod ValueFor(pAnswer As %DynamicObject, pList As %String, pKeyMember As %String, pKey As %String) As %String
{
    Set tOut = ""
    If '$IsObject(pAnswer) Quit tOut
    Set tArray = pAnswer.%Get(pList)
    If '$IsObject(tArray) Quit tOut
    Set tIterator = tArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get(pKeyMember) = pKey Set tOut = tEntry.value
    }
    Quit tOut
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
    Do $$$AssertEquals(tAnswer.%GetTypeOf("views"), "array", "and a views array")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("refreshRates"), "array", "and a refreshRates array")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("shell"), "array", "and a shell array")
    Do $$$AssertEquals(tAnswer.favorites.%Size(), 0, "all empty")
    Do $$$AssertEquals(tAnswer.recents.%Size(), 0, "on a clean account")
    Do $$$AssertEquals(tAnswer.views.%Size(), 0, "including the three Story 15.5 added")
    Do $$$AssertEquals(tAnswer.refreshRates.%Size(), 0, "each of which answers an empty array")
    Do $$$AssertEquals(tAnswer.shell.%Size(), 0, "rather than being absent")
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

/// <p><b>The three value kinds round-trip over the wire</b> (Story 15.5): a set answers 200 with
/// the body the read would answer, a second set of the same key replaces the value rather than
/// adding an entry, and a screen-scoped kind carries <code>route</code> while a shell one carries
/// <code>name</code>.</p>
/// <p>Mutation: drop the <code>set</code> arm from
/// <method>OcuPilot.Api.Preferences.Apply</method> -- every value assertion goes red. Drop
/// <code>views</code> from <method>OcuPilot.Api.Preferences.Body</method> -- the first one
/// does.</p>
Method TestAValuePreferenceRoundTripsOverTheWire()
{
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) >= 1, "the instance declares a built screen")
    If $ListLength(tRoutes) < 1 Quit
    Set tRoute = $List(tRoutes, 1)
    Set tView = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tRate = ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH
    Set tShell = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL
    Set tMember = ##class(OcuPilot.Kernel.State.Pref).#SHELLPANELWIDTH

    Set tSC = ..Call("POST", ..ValuePayload(tView, "route", tRoute, "{""sort"":""Name""}"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the set completes")
    Do $$$AssertEquals(tStatus, 200, "and is applied: " _ tBody)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "views", "route", tRoute), "{""sort"":""Name""}", "answering the value the read would answer")

    Set tSC = ..Call("POST", ..ValuePayload(tView, "route", tRoute, "{""sort"":""Time""}"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a second set replaces it")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.views.%Size(), 1, "without adding an entry")
    Do $$$AssertEquals(..ValueFor(tAnswer, "views", "route", tRoute), "{""sort"":""Time""}", "and answers the newer value")

    Set tSC = ..Call("POST", ..ValuePayload(tRate, "route", tRoute, "30"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a rate is remembered for the same screen")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "refreshRates", "route", tRoute), "30", "under its own kind")
    Do $$$AssertEquals(tAnswer.views.%Size(), 1, "leaving the view alone")

    Set tSC = ..Call("POST", ..ValuePayload(tShell, "name", tMember, "432"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a shell member is remembered: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "shell", "name", tMember), "432", "keyed by name rather than by route")
    Do $$$AssertEquals(tAnswer.favorites.%Size(), 0, "and no membership list moved")
    Do $$$AssertEquals(tAnswer.recents.%Size(), 0, "on either kind")

    Set tTheme = ##class(OcuPilot.Kernel.State.Pref).#SHELLTHEME
    Set tSC = ..Call("POST", ..ValuePayload(tShell, "name", tTheme, "dark"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the theme is remembered: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "shell", "name", tTheme), "dark", "as the value it was set to")
    Do $$$AssertEquals(..ValueFor(tAnswer, "shell", "name", tMember), "432", "beside the other shell member")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#PREFERENCESPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "shell", "name", tTheme), "dark", "and a later read answers it")
    Set tSC = ..Call("POST", ..ValuePayload(tShell, "name", tTheme, "light"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the theme is set back: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "shell", "name", tTheme), "light", "and a second set replaces it")
}

/// <p><b>The value refusals each answer 422 with a published sentence</b> (AD-39): a
/// value that is empty or over-long, a shell member outside the closed set, a screen-scoped
/// value naming a route no built screen declares, and a theme outside its fixed set (Story
/// 15.6).</p>
/// <p>Mutation: delete any arm added to
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- the <code>reason</code> serializes
/// empty and the matching leg goes red.</p>
Method TestTheValueRefusalsCarryTheirPublishedSentences()
{
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) >= 1, "the instance declares a built screen")
    If $ListLength(tRoutes) < 1 Quit
    Set tRoute = $List(tRoutes, 1)
    Set tView = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tShell = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL
    Set tLong = ""
    For tI = 1:1:(##class(OcuPilot.Kernel.State.Pref).#VALUEMAXLENGTH + 10) {
        Set tLong = tLong _ "x"
    }

    Set tCases = 5
    Set tCases(1) = $ListBuild(..ValuePayload(tView, "route", tRoute, ""), ##class(OcuPilot.Api.Error).#PREFERENCESVALUE, "value", ##class(OcuPilot.Api.Error).#REASONPREFERENCESVALUE)
    Set tCases(2) = $ListBuild(..ValuePayload(tView, "route", tRoute, tLong), ##class(OcuPilot.Api.Error).#PREFERENCESVALUE, "value", ##class(OcuPilot.Api.Error).#REASONPREFERENCESVALUE)
    Set tCases(3) = $ListBuild(..ValuePayload(tShell, "name", "anything", "1"), ##class(OcuPilot.Api.Error).#PREFERENCESNAME, "name", ##class(OcuPilot.Api.Error).#REASONPREFERENCESNAME)
    Set tCases(4) = $ListBuild(..ValuePayload(tView, "route", "no-such-area/no-such-screen", "1"), ##class(OcuPilot.Api.Error).#PREFERENCESROUTE, "route", ##class(OcuPilot.Api.Error).#REASONPREFERENCESROUTE)
    Set tCases(5) = $ListBuild(..ValuePayload(tShell, "name", ##class(OcuPilot.Kernel.State.Pref).#SHELLTHEME, "purple"), ##class(OcuPilot.Api.Error).#PREFERENCESCHOICE, "value", ##class(OcuPilot.Api.Error).#REASONPREFERENCESCHOICE)

    For tI = 1:1:tCases {
        Set tSent = $List(tCases(tI), 1)
        Set tCode = $List(tCases(tI), 2)
        Set tField = $List(tCases(tI), 3)
        Set tReason = $List(tCases(tI), 4)
        Set tSC = ..Call("POST", tSent, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes for case " _ tI)
        Do $$$AssertEquals(tStatus, 422, "and is refused for case " _ tI _ ": " _ tBody)
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json for case " _ tI)
        Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope for case " _ tI)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug for case " _ tI)
        Do $$$AssertEquals(tFault.code, tCode, "with the published code for case " _ tI)
        Do $$$AssertNotEquals(tFault.reason, "", "and a non-empty reason for case " _ tI)
        Do $$$AssertEquals(tFault.reason, tReason, "the sentence written once on the server for case " _ tI)
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, tField, "on the field the caller can correct for case " _ tI)
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).reason, tReason, "carried on the violation too for case " _ tI)
    }
    Do $$$AssertEquals(..Count("views"), 0, "and nothing was written")
    Do $$$AssertEquals(..Count("shell"), 0, "on either kind")
}

/// <p><b>The widened grammar still refuses everything outside it</b>, 422 before anything is
/// written. Nine shapes, in the order <var>tBodies</var> sends them: a membership kind carrying a
/// value; a membership kind carrying a name; a membership kind taking <code>set</code>; a value
/// kind taking <code>add</code>; a <code>set</code> with no value at all; a screen-scoped kind
/// carrying a name; a shell kind carrying a route; a value-kind <code>clear</code> carrying a key;
/// and a value that is not a string.</p>
/// <p>Mutation: delete any one of the kind-and-action checks in
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the matching leg goes red.</p>
Method TestTheWidenedGrammarRefusesAMemberTheKindDoesNotTake()
{
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) >= 1, "the instance declares a built screen")
    If $ListLength(tRoutes) < 1 Quit
    Set tRoute = $List(tRoutes, 1)
    Set tBodies = $ListBuild("{""kind"":""favorite"",""action"":""add"",""route"":""" _ tRoute _ """,""value"":""1""}", "{""kind"":""favorite"",""action"":""add"",""name"":""sideBarOpen""}", "{""kind"":""favorite"",""action"":""set"",""route"":""" _ tRoute _ """,""value"":""1""}", "{""kind"":""view"",""action"":""add"",""route"":""" _ tRoute _ """}", "{""kind"":""view"",""action"":""set"",""route"":""" _ tRoute _ """}", "{""kind"":""view"",""action"":""set"",""name"":""sideBarOpen"",""value"":""1""}", "{""kind"":""shell"",""action"":""set"",""route"":""" _ tRoute _ """,""value"":""1""}", "{""kind"":""view"",""action"":""clear"",""route"":""" _ tRoute _ """}", "{""kind"":""shell"",""action"":""set"",""name"":""sideBarOpen"",""value"":1}")
    For tI = 1:1:$ListLength(tBodies) {
        Set tSent = $List(tBodies, tI)
        Set tSC = ..Call("POST", tSent, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes: " _ tSent)
        Do $$$AssertEquals(tStatus, 422, "refused: " _ tSent _ " -> " _ tBody)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PREFERENCESBODY, "with the body code: " _ tSent)
        Do $$$AssertEquals(tFault.%IsDefined("detail"), 0, "and no violations list, because no field was reached: " _ tSent)
    }
    Do $$$AssertEquals(..Count("favorites"), 0, "and nothing was written")
    Do $$$AssertEquals(..Count("views"), 0, "on any kind")
    Do $$$AssertEquals(..Count("shell"), 0, "at all")
}

/// <p><b>A clear empties any kind</b>, including the three that keep one row per key: forgetting
/// everything a kind remembers is the same operation whatever the rows mean, and it is the one
/// action a value kind takes beside <code>set</code>.</p>
/// <p>Mutation: refuse <code>clear</code> for a value kind in
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the clear answers 422 and this goes
/// red.</p>
Method TestAClearEmptiesAValueKindToo()
{
    Set tRoutes = ..BuiltRoutes()
    Do $$$AssertTrue($ListLength(tRoutes) >= 1, "the instance declares a built screen")
    If $ListLength(tRoutes) < 1 Quit
    Set tRoute = $List(tRoutes, 1)
    Set tView = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tShell = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL

    Do ..Call("POST", ..ValuePayload(tView, "route", tRoute, "{""sort"":""Name""}"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a view is remembered: " _ tBody)
    Do ..Call("POST", ..ValuePayload(tShell, "name", ##class(OcuPilot.Kernel.State.Pref).#SHELLSIDEBAROPEN, "0"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and a shell member: " _ tBody)
    Do $$$AssertEquals(..Count("views"), 1, "both are held")
    Do $$$AssertEquals(..Count("shell"), 1, "on their own kinds")

    Set tSC = ..Call("POST", ..Payload(tView, "clear"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the clear completes")
    Do $$$AssertEquals(tStatus, 200, "and empties the views: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.views.%Size(), 0, "leaving none")
    Do $$$AssertEquals(tAnswer.shell.%Size(), 1, "and the other kind alone")

    Set tSC = ..Call("POST", ..Payload(tShell, "clear"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the shell kind clears too: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.shell.%Size(), 0, "leaving nothing")
}

/// <p><b>Home's rate is remembered under <code>home</code>, and only as a rate</b> (Story 16.18,
/// AD-43): Home's route is empty, so the refresh kind alone takes
/// <parameter>OcuPilot.Kernel.State.Pref.HOMEREFRESHNAME</parameter> in its place. A favorite or a
/// view keyed by that name is still refused as a route no built screen declares.</p>
/// <p>Mutation: drop the <method>OcuPilot.Api.Preferences.IsHomeRefresh</method> test from
/// <method>OcuPilot.Api.Preferences.HandleUpdate</method> -- the rate is refused 422 and the first
/// leg goes red; widen it to every kind -- the favorite answers 200 and the second leg goes red.</p>
Method TestHomesRateIsRememberedUnderItsOwnName()
{
    Set tHome = ##class(OcuPilot.Kernel.State.Pref).#HOMEREFRESHNAME
    Set tRate = ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH
    Set tSC = ..Call("POST", ..ValuePayload(tRate, "route", tHome, "0"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the set completes")
    Do $$$AssertEquals(tStatus, 200, "Home's rate is accepted: " _ tBody)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(..ValueFor(tAnswer, "refreshRates", "route", tHome), "0", "and answered under its own name")

    For tCase = $ListBuild(..Payload("favorite", "add", tHome), "a favorite"), $ListBuild(..ValuePayload(##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW, "route", tHome, "{}"), "a view") {
        Set tSC = ..Call("POST", $List(tCase, 1), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, $List(tCase, 2) _ ": the request completes")
        Do $$$AssertEquals(tStatus, 422, $List(tCase, 2) _ " named home is refused: " _ tBody)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PREFERENCESROUTE, $List(tCase, 2) _ ": as a route no built screen declares")
    }
    Do $$$AssertEquals(..Count("favorites"), 0, "and no favorite was written")
    Do $$$AssertEquals(..Count("views"), 0, "nor a view")
}

}
