/// <p>Pins the shape AD-10's prohibited set refuses <b>by</b> (Story 5.5): the reviewed-few field
/// rule (DW-1345, DW-1346), the one permitted authentication change out of the whole
/// <code>AutheEnabled</code> mask (DW-1346), OcuPilot's own applications under every spelling the
/// instance resolves to one of them (DW-1347, DW-1352), the diff
/// scoping that keeps a third party's change from being answered as the agent's (DW-1351), the
/// fingerprint gate's own cover of the stored payload, which is what keeps that scoping from
/// letting an unscoped payload through, and the mint's own stream writes, which are what keep a
/// row with no diff from existing at all (DW-1353, DW-1354).</p>
/// <p><b>Why a property this build does not carry is in here.</b> Each of the three highs is about a
/// family of vendor properties, not about the members that happen to exist today, so the test that
/// makes the claim falsifiable puts an invented property with the same effect in front of the set
/// and expects a refusal. A set that enumerated names would pass every other leg here and fail
/// those.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, the compiled tool
/// registry and an account holding <code>%All</code>. It writes OcuPilot's own state -- proposal
/// and turn rows, and one <class>OcuPilot.Kernel.State.WebApp</class> record for the probe path,
/// all removed by <method>OnAfterOneTest</method> -- and every port call is
/// <class>OcuPilot.Test.ProposalFixture</class>'s, so <b>no write reaches the instance's own
/// configuration</b>.</p>
Class OcuPilot.Test.ProhibitedByEffect Extends %UnitTest.TestCase
{

/// <p>The shipped set with the port replaced, which also carries the shared builders.</p>
Parameter SET = "OcuPilot.Test.ProhibitedFixture";

Parameter SHIPPEDSET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter TOOL = "webapp.list.update";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.WebAppUpdate";

Parameter FIELDLISTS = "OcuPilot.Screen.Tool.FieldLists";

/// <p>A path that is neither OcuPilot's own nor one the instance carries.</p>
Parameter TARGET = "/csp/ocupilotprobebyeffect";

/// <p>The path install's own record is written for, so the recorded half of the serving-path read is
/// driven. Removed in <method>OnAfterOneTest</method> whether or not the test that writes it
/// finished, since a surviving record changes the next run's answers.</p>
Parameter RECORDEDPATH = "/csp/ocupilotprobebyeffectrecorded";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SET)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders("")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#RECORDEDPATH), "install's record of the probe path is removed")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>The target every predicate is driven against, with <var>pExtra</var>'s further members on
/// it.</p>
Method Target(pPath As %String = {..#TARGET}, ByRef pExtra) As %String
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "%Development", "Probe.Dispatch", "", 1, "before", .pExtra)
}

/// <p>Ask the set about <var>pPayload</var> and a diff naming <var>pFields</var> against the armed
/// target <var>pFresh</var>.</p>
Method Ask(pFresh As %String, pPayload As %String, pFields As %String, Output pProhibits As %Boolean, Output pCode As %String, pPath As %String = {..#TARGET}) As %Status
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).Ask(pFresh, pPayload, ##class(OcuPilot.Test.ProhibitedFixture).Diff(pFields), pPath, "web-application", .pProhibits, .pCode)
}

/// <p>Seed one completed turn and one live proposal carrying <var>pPayload</var> and a diff naming
/// <var>pFields</var> against <var>pPath</var>, for the running account.</p>
/// <p><var>pDiff</var> replaces that diff verbatim where it is not <code>""</code>, which is how a
/// row proposing nothing is seeded, and <var>pFingerprint</var> is the digest the row carries: the
/// default <code>0</code> matches no target, so a test that needs the confirm to reach the gates
/// behind the fingerprint passes the digest the confirm will re-compute.</p>
Method Seed(pPayload As %String, pFields As %String, pPath As %String = {..#TARGET}, pDiff As %String = "", pFingerprint As %String = "0", Output pToken As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tRef = ##class(OcuPilot.Test.ProhibitedFixture).Reference(pPath)
    Do $$$AssertNotEquals(tRef, "", "the target reference is built")
    If tRef = "" Quit ""
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = pFingerprint
    Set tValues("arguments") = "{}"
    Set tValues("payload") = pPayload
    Set tValues("diff") = $Select(pDiff '= "": pDiff, 1: ##class(OcuPilot.Test.ProhibitedFixture).Diff(pFields))
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .pToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>Confirm <var>pKey</var> through the shipped transition, with the armed set in the seam.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .tResult, .pHttp, .pCode, .tDetail)
}

/// <p>DW-1345 and DW-1346: a changed field the release has not reviewed is refused whatever it is
/// called -- every member of the two families the review named, two properties this build's own
/// endpoint does not carry at all, and one whose value is an array.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// answer the whole admitted field list, or delete the reviewed-few loop from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- this goes red on every
/// leg.</p>
Method TestAFieldTheReleaseHasNotReviewedIsRefused()
{
    ; What answers at the URL, then how a caller gets in, then two invented properties with each of
    ; those effects. The last two are the load-bearing legs: they are refused by the rule's shape
    ; rather than by having been listed anywhere.
    Set tFields = $ListBuild($ListBuild("DispatchClass", "string", "Probe.Dispatch", "Probe.Other"))
    Set tFields = tFields _ $ListBuild($ListBuild("EventClass", "string", "", "Probe.Event"))
    Set tFields = tFields _ $ListBuild($ListBuild("SuperClass", "string", "", "Probe.Super"))
    Set tFields = tFields _ $ListBuild($ListBuild("Package", "string", "", "Probe"))
    Set tFields = tFields _ $ListBuild($ListBuild("Path", "string", "/usr/probe/", "/usr/other/"))
    Set tFields = tFields _ $ListBuild($ListBuild("NameSpace", "string", "HSCUSTOM", "USER"))
    Set tFields = tFields _ $ListBuild($ListBuild("LoginPage", "string", "", "/csp/probe/login.csp"))
    Set tFields = tFields _ $ListBuild($ListBuild("ErrorPage", "string", "", "/csp/probe/error.csp"))
    Set tFields = tFields _ $ListBuild($ListBuild("ChangePasswordPage", "string", "", "/csp/probe/pw.csp"))
    Set tFields = tFields _ $ListBuild($ListBuild("PermittedClasses", "string", "", "Probe.*"))
    Set tFields = tFields _ $ListBuild($ListBuild("ServeFiles", "string", 0, 1))
    Set tFields = tFields _ $ListBuild($ListBuild("WSGIAppName", "string", "", "probe"))
    Set tFields = tFields _ $ListBuild($ListBuild("TwoFactorEnabled", "boolean", 1, 0))
    Set tFields = tFields _ $ListBuild($ListBuild("CSRFToken", "boolean", 1, 0))
    Set tFields = tFields _ $ListBuild($ListBuild("JWTAuthEnabled", "boolean", 0, 1))
    Set tFields = tFields _ $ListBuild($ListBuild("UseCookies", "string", 2, 0))
    Set tFields = tFields _ $ListBuild($ListBuild("SessionScope", "string", 0, 1))
    Set tFields = tFields _ $ListBuild($ListBuild("CorsCredentialsAllowed", "boolean", 0, 1))
    Set tFields = tFields _ $ListBuild($ListBuild("GroupById", "string", "", "%ISCMgtPortal"))
    Set tFields = tFields _ $ListBuild($ListBuild("Timeout", "string", 900, 86400))
    Set tFields = tFields _ $ListBuild($ListBuild("HandlerClass", "string", "Probe.Handler", "Probe.OtherHandler"))
    Set tFields = tFields _ $ListBuild($ListBuild("PasswordlessEnabled", "boolean", 0, 1))

    Set tSettable = $ClassMethod(..#TOOLCLASS, "SettableFields")
    Set tExpected = $Parameter(..#SHIPPEDSET, "UNCOVEREDFIELD")
    For tI = 1:1:$ListLength(tFields) {
        Set tRow = $List(tFields, tI)
        Set tName = $List(tRow, 1)
        Set tType = $List(tRow, 2)
        Kill tBefore, tAfter
        Set tBefore(tName) = $ListBuild($List(tRow, 3), tType)
        Set tAfter(tName) = $ListBuild($List(tRow, 4), tType)
        Set tSC = ..Ask(..Target(..#TARGET, .tBefore), ..Target(..#TARGET, .tAfter), tName, .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for " _ tName)
        Do $$$AssertEquals(tProhibits, 1, "changing " _ tName _ " is refused")
        ; DispatchClass and MatchRoles carry a sentence of their own; everything else here is
        ; refused for not being one of the few the release reviewed.
        If tName '= "DispatchClass" {
            Do $$$AssertEquals(tCode, tExpected, "as a setting the release has not reviewed")
        } Else {
            Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "DISPATCH"), "with the dispatch code")
        }
        Do $$$AssertEquals($ListFind(tSettable, tName), 0, "and the shipped tool admits no " _ tName)
    }

    ; The two invented names are invented: this build's own field list carries neither, so the two
    ; legs above are about the rule's shape and not about a name somebody remembered to add.
    Set tSource = ""
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, ..#FIELDLISTS, .tSource)
    Do $$$AssertStatusOK(tSC, "the generated field lists read back")
    Do $$$AssertEquals(tSource [ """path"":""HandlerClass""", 0, "no endpoint on this build publishes a HandlerClass field")
    Do $$$AssertEquals(tSource [ """path"":""PasswordlessEnabled""", 0, "nor a PasswordlessEnabled one")

    ; And it reaches a caller as the ordinary 403 the other codes do.
    Kill tBefore, tAfter
    Set tBefore("NameSpace") = $ListBuild("HSCUSTOM", "string")
    Set tAfter("NameSpace") = $ListBuild("USER", "string")
    Set tKey = ..Seed(..Target(..#TARGET, .tAfter), "NameSpace")
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Target(..#TARGET, .tBefore))
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, tExpected, "with the unreviewed-setting code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tCode), "", "carrying a written sentence")

    ; An array-valued property, which is the shape the rendered comparison handles least obviously
    ; and what MatchRoles and CorsAllowlist are on the real endpoint.
    Set tLive = ##class(%DynamicAbstractObject).%FromJSON(..Target())
    Do tLive.%Set("CorsAllowlist", ["https://one.example"])
    Set tProposed = ##class(%DynamicAbstractObject).%FromJSON(..Target())
    Do tProposed.%Set("CorsAllowlist", ["https://one.example", "https://two.example"])
    Set tSC = ..Ask(tLive.%ToJSON(), tProposed.%ToJSON(), "CorsAllowlist", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers an array-valued property")
    Do $$$AssertEquals(tProhibits, 1, "extending CorsAllowlist is refused")
    Do $$$AssertEquals(tCode, tExpected, "as a setting the release has not reviewed")
}

/// <p>DW-1346: <code>AutheEnabled</code> carries strength modifiers as well as mechanisms, so the
/// only change to it the release permits is clearing the unauthenticated bit and nothing else --
/// adding a bit, clearing another bit, clearing the mask, and a value that is not a non-negative
/// whole number are all refused, whichever bit it is and whichever direction a subset test would
/// have called it.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.ClearsUnauthenticatedOnly</method>
/// answer the subset reading it replaced -- permitted iff the payload sets no bit the target does
/// not -- and two legs go red, because that reading permits both turning two-factor password
/// authentication off and leaving no way in at all.</p>
Method TestOnlyClearingUnauthenticatedAccessIsProposable()
{
    Set tExpected = $Parameter(..#SHIPPEDSET, "UNAUTHENTICATED")
    ; before, after, whether it is refused, and what it is.
    Set tCases = $ListBuild($ListBuild(32, 96, 1, "adding unauthenticated access to a password application"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 8192, 1, "swapping password for delegated authentication"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 16384, 1, "swapping password for a login token"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 1056, 1, "adding a bit this build does not define"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 0, 1, "leaving no way in at all"))
    Set tCases = tCases _ $ListBuild($ListBuild(64, 96, 1, "adding password authentication to an unauthenticated application"))
    Set tCases = tCases _ $ListBuild($ListBuild(2097184, 32, 1, "turning two-factor password authentication off"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 2097184, 1, "turning two-factor password authentication on"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, 32.5, 1, "a value with a fractional part"))
    Set tCases = tCases _ $ListBuild($ListBuild(32, "public", 1, "a payload value that is not a number"))
    Set tCases = tCases _ $ListBuild($ListBuild("public", 32, 1, "a target value that is not a number"))
    Set tCases = tCases _ $ListBuild($ListBuild(96, 32, 0, "requiring a password where none was required"))
    Set tCases = tCases _ $ListBuild($ListBuild(2097248, 2097184, 0, "requiring a password while keeping two-factor"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..Ask(..Masked($List(tCase, 1)), ..Masked($List(tCase, 2)), "AutheEnabled", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers " _ $List(tCase, 4))
        Do $$$AssertEquals(tProhibits, $List(tCase, 3), $List(tCase, 4) _ ": code was '" _ tCode _ "'")
        If $List(tCase, 3) Do $$$AssertEquals(tCode, tExpected, "with the authentication code")
    }
}

/// <p>The target as <method>Target</method> builds it with <code>AutheEnabled</code> reading
/// <var>pValue</var>, carried in the JSON type the value spells -- a number where it is one, a
/// string otherwise, which is how a value the vendor's own read could not have answered is put in
/// front of the predicate without making the object unparseable.</p>
Method Masked(pValue As %RawString) As %String
{
    Kill tExtra
    Set tExtra("AutheEnabled") = $ListBuild(pValue, $Select($IsValidNum(pValue): "number", 1: "string"))
    Quit ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1, "before", .tExtra)
}

/// <p>DW-1347: a web application OcuPilot itself is served by is not the agent's to change at all
/// -- the path and the namespace break it as completely as the enabled flag, and AD-38 makes an
/// unreachable OcuPilot an instance nobody can repair through OcuPilot. Driven for every path the
/// install roster declares and for one only install's own record names, and an application that is
/// not OcuPilot's may still be disabled.</p>
/// <p>DW-1352: driven for each of those paths as the instance also resolves it -- re-cased, and
/// with trailing slashes -- because the id a proposal carries is the model's spelling and the
/// vendor endpoint answers the same application for every one of them.</p>
/// <p>Mutations: make <method>OcuPilot.Kernel.Proposal.Prohibited.ServesOcuPilot</method> answer
/// 0, drop its <class>OcuPilot.Kernel.State.WebApp</class> lookup, and compare both sides raw
/// again instead of through <method>OcuPilot.Kernel.Proposal.Prohibited.NormalizedPath</method> --
/// the first reddens every leg, the second the recorded one alone, the third the spellings alone.</p>
Method TestAChangeToOcuPilotsOwnApplicationIsRefused()
{
    Set tExpected = $Parameter(..#SHIPPEDSET, "SERVINGPATH")
    Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
    Do $$$AssertNotEquals(tKeys, "", "the roster declares its application keys")
    For tI = 1:1:$Length(tKeys, ",") {
        Set tAppSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
        Do $$$AssertStatusOK(tAppSC, "the roster reads application " _ $Piece(tKeys, ",", tI))
        If $$$ISERR(tAppSC) Continue
        ; The roster spells its paths the way the instance resolves them, which is what makes a
        ; lookup of install's own record by the normalized path the same question.
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedPath(tApp.path), tApp.path, tApp.path _ " is already spelled the way the instance resolves it")
        Do ..OwnPath(tApp.path, tExpected)
        ; DW-1352: the instance resolves each of these to that same application, so the set must
        ; read each of them as OcuPilot's own -- otherwise the write reaches the application the
        ; predicate said was somebody else's.
        Do ..OwnSpelling($ZConvert(tApp.path, "U"), tExpected)
        Do ..OwnSpelling(tApp.path _ "/", tExpected)
        Do ..OwnSpelling($ZConvert(tApp.path, "U") _ "///", tExpected)
    }

    ; The recorded half: a path the roster does not declare but install's own record does. The
    ; roster loop above returns before that lookup, so nothing else here reaches it.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#RECORDEDPATH), "no record of the probe path survives from an earlier run")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#RECORDEDPATH, "created"), "install's record of the probe path is written")
    ; OnAfterOneTest removes it, so a failure between the write and the removal cannot leave a
    ; record behind and change the next run's serving-path answers.
    Do ..OwnPath(..#RECORDEDPATH, tExpected)
    Do ..OwnSpelling($ZConvert(..#RECORDEDPATH, "U"), tExpected)
    Do ..OwnSpelling(..#RECORDEDPATH _ "/", tExpected)

    ; An application that is not OcuPilot's: disabling it, and renaming it, are both proposable.
    Set tSC = ..Ask(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 0), "Enabled", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for an application that is not OcuPilot's")
    Do $$$AssertEquals(tProhibits, 0, "disabling that one is not prohibited, code was '" _ tCode _ "'")
    Set tSC = ..Ask(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1, "after"), "Description", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "and answers its description")
    Do $$$AssertEquals(tProhibits, 0, "which is proposable, code was '" _ tCode _ "'")

    ; Over the confirm, so the refusal is the ordinary 403 with the set's own sentence.
    Set tServing = "/api/ocupilot"
    Set tKey = ..Seed(##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 0), "Enabled", tServing)
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 1))
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, tExpected, "with the serving-path code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
}

/// <p>Four changes to the application at <var>pPath</var>, one of them a field the set would
/// otherwise permit, each refused <var>pExpected</var>.</p>
Method OwnPath(pPath As %String, pExpected As %String)
{
    Set tFresh = ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1)
    Set tCases = $ListBuild($ListBuild("Enabled", ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 0)))
    Set tCases = tCases _ $ListBuild($ListBuild("Description", ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1, "after")))
    ; AC5 (Story 5.8): clearing the resource of a serving path is refused for the same reason
    ; disabling it is, and under the same code -- the serving-path predicate runs before the
    ; resource one, so the refusal names what is actually wrong with the proposal. It needs its own
    ; fresh read, because the one above already carries no resource and clearing it would be no
    ; change at all.
    Set tResourced = ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "%Development", "OcuPilot.Api.Router", "", 1)
    Set tCleared = ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1)
    Set tSC = ..Ask(tResourced, tCleared, "Resource", .tProhibits, .tCode, pPath)
    Do $$$AssertStatusOK(tSC, "the set answers Resource on " _ pPath)
    Do $$$AssertEquals(tProhibits, 1, pPath _ " is one of OcuPilot's own, so clearing its resource is not proposable")
    Do $$$AssertEquals(tCode, pExpected, "with the serving-path code, not the resource one")

    Kill tNamespace, tPath
    Set tNamespace("NameSpace") = $ListBuild("USER", "string")
    Set tPath("Path") = $ListBuild("/usr/elsewhere/", "string")
    Set tCases = tCases _ $ListBuild($ListBuild("NameSpace", ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tNamespace)))
    Set tCases = tCases _ $ListBuild($ListBuild("Path", ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tPath)))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..Ask(tFresh, $List(tCase, 2), $List(tCase, 1), .tProhibits, .tCode, pPath)
        Do $$$AssertStatusOK(tSC, "the set answers " _ $List(tCase, 1) _ " on " _ pPath)
        Do $$$AssertEquals(tProhibits, 1, pPath _ " is one of OcuPilot's own, so its " _ $List(tCase, 1) _ " is not proposable")
        Do $$$AssertEquals(tCode, pExpected, "with the serving-path code")
    }
}

/// <p>Disabling the application at <var>pPath</var> is refused <var>pExpected</var> -- one case,
/// driven for a spelling of a roster or recorded path that the instance resolves to that same
/// application (DW-1352).</p>
Method OwnSpelling(pPath As %String, pExpected As %String)
{
    Set tFresh = ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 1)
    Set tPayload = ##class(OcuPilot.Test.ProhibitedFixture).App(pPath, 32, "", "OcuPilot.Api.Router", "", 0)
    Set tSC = ..Ask(tFresh, tPayload, "Enabled", .tProhibits, .tCode, pPath)
    Do $$$AssertStatusOK(tSC, "the set answers the spelling " _ pPath)
    Do $$$AssertEquals(tProhibits, 1, pPath _ " names one of OcuPilot's own, so disabling it is not proposable")
    Do $$$AssertEquals(tCode, pExpected, "with the serving-path code")
}

/// <p>DW-1351: the verdict is about what the proposal changes. A field a third party moved after
/// the mint is not the agent's change, so the set is silent and the fingerprint gate answers 409
/// and closes the row -- where a payload-against-live comparison alone would answer 403 for a
/// change nobody proposed, and leave the row live.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.Changed</method> ignore the diff
/// and compare every member of the payload against the target -- this goes red.</p>
Method TestAProposalIsJudgedOnWhatItChanges()
{
    ; The mint read a target with no resource and proposed a description; an operator has given it
    ; %Development since. The stored payload still carries "", which would drop it -- and that is
    ; the fingerprint gate's refusal, not the prohibited set's.
    Set tMinted = ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "", "Probe.Dispatch", "", 1, "after")
    Set tLive = ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1)
    Set tSC = ..Ask(tLive, tMinted, "Description", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers")
    Do $$$AssertEquals(tProhibits, 0, "a resource the proposal never touched is not the agent's change, code was '" _ tCode _ "'")

    Set tKey = ..Seed(tMinted, "Description")
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tLive)
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "by the fingerprint gate, which is the truthful answer")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "target-changed", "and the row closes with the reason the card renders, rather than staying live")

    ; The same payload against the same live target, minted from a diff that does name the resource:
    ; now it is the agent's change, and the set refuses it.
    Set tSC = ..Ask(tLive, tMinted, "Description,Resource", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the proposal that did ask for it")
    Do $$$AssertEquals(tProhibits, 1, "which is refused")
    Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "AUTHORIZATION"), "as a dropped resource")

    ; A field the diff names whose value the instance already holds changes nothing.
    Set tSC = ..Ask(tMinted, tMinted, "Resource,DispatchClass", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a diff whose fields the target already reads")
    Do $$$AssertEquals(tProhibits, 0, "and nothing is prohibited, code was '" _ tCode _ "'")

    ; The key the set reads a diff row's field name under is the key a real mint writes, so renaming
    ; it in the mint reddens a test rather than silently disarming the scoping above.
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(##class(%DynamicAbstractObject).%FromJSON(tLive), {"Description": "after"}, $ClassMethod(..#TOOLCLASS, "IdArgument"), $ClassMethod(..#TOOLCLASS, "SettableFields"), .tPayload, .tMintDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over the live read")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    Do $$$AssertEquals(tMintDiff.%Size(), 1, "and records the one changed field")
    Do $$$AssertEquals(tMintDiff.%Get(0).%Get("field"), "Description", "under the key Changed() reads")

    ; DW-1354, the producer half: the mint records a row for every field its own merge moved, so a
    ; payload that changes something cannot be stored beside a diff that names nothing. With the
    ; mint the only producer of a stored row (DW-1353), that is what leaves the diff scoping above
    ; nothing unscoped to be silent about.
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(##class(%DynamicAbstractObject).%FromJSON(tLive), {"Description": "after", "Enabled": false}, $ClassMethod(..#TOOLCLASS, "IdArgument"), $ClassMethod(..#TOOLCLASS, "SettableFields"), .tPayload, .tBothDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over two changed arguments")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    Do $$$AssertEquals(tBothDiff.%Size(), 2, "and names both of the fields it moved")
    Set tNamed = ""
    Set tIterator = tBothDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tNamed = tNamed _ $ListBuild(tRow.%Get("field"))
    }
    Do $$$AssertNotEquals($ListFind(tNamed, "Description"), 0, "the description among them")
    Do $$$AssertNotEquals($ListFind(tNamed, "Enabled"), 0, "and the enabled flag")
}

/// <p>DW-1353: the mint takes the status of each of its three stream writes and saves no row on a
/// failure, so a row whose diff never landed does not exist. That is the other half of DW-1354's
/// argument -- with no producer of a row whose payload changes something while its diff names
/// nothing, such a row is reachable only by a direct write into OcuPilot's protected storage, which
/// AD-9 and AD-33 put outside the threat model.</p>
/// <p><b>Why half of this is read from the source.</b> A global stream refuses no write for any
/// input a caller can hand the mint -- probed on <code>ocupilot-ci</code>: a file stream aimed at an
/// unwritable path and <class>%Stream.NullCharacter</class> both answer <code>$$$OK</code>, and
/// <class>%Stream.Object</class> is abstract -- so the failure is unreachable and only the shape of
/// the call can be pinned. The round trip below is what pins that the three writes still store what
/// they were handed.</p>
/// <p>Mutations: write one of the three streams with a bare <code>Do</code> again, or drop the
/// <code>If $$$ISERR(tSC) Quit</code> behind one -- that field's source leg goes red; delete one of
/// the three writes outright -- the round trip goes red.</p>
Method TestAMintChecksEachStreamWriteOrStoresNoRow()
{
    Set tText = ""
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Kernel.State.Propose", .tText)
    Do $$$AssertStatusOK(tSC, "the proposal store's source reads back")
    If $$$ISERR(tSC) Quit
    For tField = "Arguments", "Payload", "Diff" {
        Set tCall = "Set tSC = tRow." _ tField _ ".Write("
        Do $$$AssertEquals(tText [ tCall, 1, "the mint takes the status of its " _ tField _ " write")
        Do $$$AssertEquals(tText [ ("Do tRow." _ tField _ ".Write("), 0, "and writes it through no unchecked Do")
        Do $$$AssertEquals($Piece($Piece(tText, tCall, 2), $Char(10), 2) [ "If $$$ISERR(tSC) Quit", 1, "quitting on a failed " _ tField _ " write before the row is saved")
    }

    ; The round trip: the three texts a mint is handed are the three the store reads back, so a
    ; write that was dropped rather than mis-checked reddens here.
    Set tDiff = ##class(OcuPilot.Test.ProhibitedFixture).Diff("Description")
    Set tKey = ..Seed(..Target(), "", ..#TARGET, tDiff, "0", .tToken)
    If tKey = "" Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByToken(tToken, .tFound, .tStored)
    Do $$$AssertStatusOK(tSC, "the minted row reads back by its token")
    Do $$$AssertEquals(tFound, 1, "and is found")
    Do $$$AssertEquals($Get(tStored("arguments")), "{}", "with the arguments it was handed")
    Do $$$AssertEquals($Get(tStored("payload")), ..Target(), "the payload it was handed")
    Do $$$AssertEquals($Get(tStored("diff")), tDiff, "and the diff it was handed")
}

/// <p>AD-6: the diff scopes the set, so the gate behind it covers the payload the port would be
/// sent. A row whose stored payload weakens the live target while its diff names nothing -- or
/// cannot be read at all -- is refused 409 <code>PROPOSAL.TARGETCHANGED</code> and closed, so no
/// route reaches the port with a payload its own fingerprint does not cover.</p>
/// <p><b>One case is refused earlier, and by a stronger rule</b> (AD-53, Story 7.1): a row against
/// one of OcuPilot's own applications is refused 403 <code>PROHIBITED.SERVINGPATH</code> whatever
/// its diff says, because that predicate is over the target rather than over the payload's shape.
/// It is kept here as the case that says so: the set is silent on a row that proposes nothing
/// <b>except</b> on the applications AD-38 protects.</p>
/// <p>Mutation: drop the stored-payload comparison from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- the three 409 legs go
/// red and each of those confirms succeeds and writes.</p>
Method TestARowWhosePayloadItsFingerprintDoesNotCoverIsRefused()
{
    Set tServing = "/api/ocupilot"
    Set tLive = ..Target()
    Kill tHere, tElsewhere
    Set tHere("NameSpace") = $ListBuild("HSCUSTOM", "string")
    Set tElsewhere("NameSpace") = $ListBuild("USER", "string")
    Set tServingLive = ##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tHere)
    ; the live target, the payload the row stores against it, the row's diff, its path, what it is,
    ; the HTTP status it earns and the code with it.
    Set tChanged = ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED
    Set tServingCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH")
    Set tCases = $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Other", "", 1), "[]", ..#TARGET, "a repointed dispatch class behind an empty diff", 409, tChanged))
    Set tCases = tCases _ $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 96, "%Development", "Probe.Dispatch", "", 1), "[]", ..#TARGET, "unauthenticated access behind an empty diff", 409, tChanged))
    Set tCases = tCases _ $ListBuild($ListBuild(tServingLive, ##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tElsewhere), "[]", tServing, "OcuPilot's own namespace repointed behind an empty diff", 403, tServingCode))
    Set tCases = tCases _ $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Other", "", 1), "not json", ..#TARGET, "a repointed dispatch class behind a diff nobody can read", 409, tChanged))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 5)
        Set tDigest = ##class(OcuPilot.Test.ProhibitedFixture).Digest($List(tCase, 1))
        Do $$$AssertNotEquals(tDigest, "", "the digest the confirm will re-compute is taken for " _ tLabel)
        If tDigest = "" Continue
        Set tKey = ..Seed($List(tCase, 2), "", $List(tCase, 4), $List(tCase, 3), tDigest)
        If tKey = "" Continue
        Do ##class(OcuPilot.Test.ProposalFixture).Arm($List(tCase, 1))
        Set tSC = ..Confirm(tKey, .tHttp, .tCode)
        Do $$$AssertStatusNotOK(tSC, "the confirm of " _ tLabel _ " is refused")
        ; 409 rather than 403 is the point on three of the four: the set is silent on a row that
        ; proposes nothing, and the fingerprint gate is what refuses the payload behind it. The
        ; fourth is OcuPilot's own application, which the set refuses over the target itself.
        Do $$$AssertEquals(tHttp, $List(tCase, 6), "at " _ $List(tCase, 6) _ ", code was '" _ tCode _ "'")
        Do $$$AssertEquals(tCode, $List(tCase, 7), "with the code that refusal carries")
        If $List(tCase, 6) = 409 {
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "target-changed", "and the row closes rather than staying live")
        } Else {
            ; A prohibited refusal leaves the row live: nothing about the target moved, so there is
            ; nothing to close it over (AD-10, AD-6).
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and a prohibited row is left live rather than closed")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing at the port")
    }
}

/// <p>AD-10 as amended 2026-09-23 (DW-1486): each account predicate -- <code>_SYSTEM</code>, the
/// signed-in account, a service account and the last <code>%All</code> holder -- refuses each
/// removal effect with its own code: a bodyless delete, a disable, and a <code>Roles</code> delta
/// that strips <code>%All</code>. An ordinary account is permitted all three, and a role change on
/// <code>_SYSTEM</code> that keeps <code>%All</code> is permitted too, so neither the predicates nor
/// the effect terms can pass by refusing everything.</p>
/// <p>Every leg goes through the shipped <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// with the target armed on <class>OcuPilot.Test.ProposalFixture</class>, so nothing reaches the
/// instance. The census is armed: answered "last" for the last-holder legs, and deterministic
/// otherwise.</p>
/// <p>Mutations (Rule 19): remove any one arm from <method>OcuPilot.Kernel.Proposal.Prohibited.User</method>,
/// or any one term from <method>OcuPilot.Kernel.Proposal.Prohibited.RemovesAdministration</method>
/// -- the legs of that arm, or of that effect, go red.</p>
Method TestEveryAccountArmRefusesEveryRemovalEffect()
{
    Set tSet = "OcuPilot.Test.ProhibitedFixture"
    Set tUpdate = "permissions.users.update"
    Set tDelete = "permissions.users.delete"
    Set tFixture = "OcuPilot.Test.ProposalFixture"
    Set tSystem = $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNTNAME")
    Set tService = $List($ClassMethod(..#SHIPPEDSET, "ServiceAccounts"), 1)
    Set tHolder = "OcuPilotProbeByEffectLastHolder"
    Set tOrdinary = "OcuPilotProbeByEffectOrdinary"
    ; The signed-in account must not be _SYSTEM or the service account the leg names, or the
    ; first-hit-wins order would answer its code for the wrong row.
    Do $$$AssertNotEquals($ZConvert($Username, "L"), $ZConvert(tSystem, "L"), "the runner is not _SYSTEM, so the two arms are separable")
    Do $$$AssertNotEquals($ZConvert($Username, "L"), $ZConvert(tService, "L"), "and not " _ tService)
    Set tLegs = $ListBuild($ListBuild(tSystem, "SYSTEMACCOUNT", 0), $ListBuild($Username, "CURRENTUSER", 0), $ListBuild(tService, "SERVICEACCOUNT", 0), $ListBuild(tHolder, "LASTALLHOLDER", 1))
    Set tRefused = 0
    For tI = 1:1:$ListLength(tLegs) {
        Set tLeg = $List(tLegs, tI)
        Set tName = $List(tLeg, 1)
        Set tExpected = $Parameter(..#SHIPPEDSET, $List(tLeg, 2))
        Do $ClassMethod(tFixture, "ArmLastAllHolder", $Select($List(tLeg, 3): 1, 1: ""))
        Set tFresh = $ClassMethod(tSet, "UserObject", tName, 1, "%All")
        For tEffect = "delete", "disable", "strip" {
            If tEffect = "delete" {
                Set tSC = $ClassMethod(tSet, "Ask", tFresh, tFresh, $ClassMethod(tSet, "Diff", "Enabled,FullName,Roles"), tName, "user", .tProhibits, .tCode, tDelete)
            } ElseIf tEffect = "disable" {
                Set tSC = $ClassMethod(tSet, "Ask", tFresh, $ClassMethod(tSet, "UserObject", tName, 0, "%All"), $ClassMethod(tSet, "Diff", "Enabled"), tName, "user", .tProhibits, .tCode, tUpdate)
            } Else {
                Set tSC = $ClassMethod(tSet, "Ask", tFresh, $ClassMethod(tSet, "UserObject", tName, 1, "%SQL"), $ClassMethod(tSet, "Diff", "Roles"), tName, "user", .tProhibits, .tCode, tUpdate)
            }
            Do $$$AssertStatusOK(tSC, tName _ " / " _ tEffect _ ": the set answers: " _ $System.Status.GetErrorText(tSC))
            Do $$$AssertEquals(tCode, tExpected, tName _ " / " _ tEffect _ ": refused with " _ tExpected)
            If tProhibits && (tCode = tExpected) Set tRefused = tRefused + 1
        }
    }
    Do $$$AssertEquals(tRefused, 12, "all twelve legs were refused with their own code")

    ; The controls: an ordinary account holding %All, with the census answering that another holder
    ; exists, is permitted every effect; and _SYSTEM may gain an ordinary role that keeps %All.
    Do $ClassMethod(tFixture, "ArmLastAllHolder", "")
    ; The other holder is a real, enabled, signable account the census lists: _SYSTEM.
    Do $ClassMethod(tFixture, "ArmAllHolders", tOrdinary _ "," _ tSystem)
    Set tFresh = $ClassMethod(tSet, "UserObject", tOrdinary, 1, "%All")
    Set tSC = $ClassMethod(tSet, "Ask", tFresh, tFresh, $ClassMethod(tSet, "Diff", "Enabled,FullName,Roles"), tOrdinary, "user", .tProhibits, .tCode, tDelete)
    Do $$$AssertStatusOK(tSC, "the ordinary delete is answered")
    Do $$$AssertEquals(tProhibits, 0, "an ordinary account's delete is permitted, code was '" _ tCode _ "'")
    Set tSC = $ClassMethod(tSet, "Ask", tFresh, $ClassMethod(tSet, "UserObject", tOrdinary, 0, "%All"), $ClassMethod(tSet, "Diff", "Enabled"), tOrdinary, "user", .tProhibits, .tCode, tUpdate)
    Do $$$AssertEquals(tProhibits, 0, "and its disable, code was '" _ tCode _ "'")
    Set tSC = $ClassMethod(tSet, "Ask", tFresh, $ClassMethod(tSet, "UserObject", tOrdinary, 1, "%SQL"), $ClassMethod(tSet, "Diff", "Roles"), tOrdinary, "user", .tProhibits, .tCode, tUpdate)
    Do $$$AssertEquals(tProhibits, 0, "and its %All strip, code was '" _ tCode _ "'")
    Do $ClassMethod(tFixture, "ArmAllHolders", "")
    Set tSC = $ClassMethod(tSet, "Ask", $ClassMethod(tSet, "UserObject", tSystem, 1, "%All"), $ClassMethod(tSet, "UserObject", tSystem, 1, "%All,%SQL"), $ClassMethod(tSet, "Diff", "Roles"), tSystem, "user", .tProhibits, .tCode, tUpdate)
    Do $$$AssertStatusOK(tSC, "the _SYSTEM role add is answered")
    Do $$$AssertEquals(tProhibits, 0, "a role change on _SYSTEM that keeps %All removes nothing, code was '" _ tCode _ "'")
}

}
