/// <p>Pins the shape AD-10's prohibited set refuses <b>by</b> (Story 5.5): the reviewed-few field
/// rule (DW-1345, DW-1346), the one permitted authentication change out of the whole
/// <code>AutheEnabled</code> mask (DW-1346), OcuPilot's own applications (DW-1347), the diff
/// scoping that keeps a third party's change from being answered as the agent's (DW-1351), and the
/// fingerprint gate's own cover of the stored payload, which is what keeps that scoping from
/// letting an unscoped payload through.</p>
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
Method Seed(pPayload As %String, pFields As %String, pPath As %String = {..#TARGET}, pDiff As %String = "", pFingerprint As %String = "0") As %String
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
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
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
/// <p>Mutations: make <method>OcuPilot.Kernel.Proposal.Prohibited.ServesOcuPilot</method> answer
/// 0, and drop its <class>OcuPilot.Kernel.State.WebApp</class> lookup -- the first reddens every
/// leg, the second the recorded one alone.</p>
Method TestAChangeToOcuPilotsOwnApplicationIsRefused()
{
    Set tExpected = $Parameter(..#SHIPPEDSET, "SERVINGPATH")
    Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
    Do $$$AssertNotEquals(tKeys, "", "the roster declares its application keys")
    For tI = 1:1:$Length(tKeys, ",") {
        Set tAppSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
        Do $$$AssertStatusOK(tAppSC, "the roster reads application " _ $Piece(tKeys, ",", tI))
        If $$$ISERR(tAppSC) Continue
        Do ..OwnPath(tApp.path, tExpected)
    }

    ; The recorded half: a path the roster does not declare but install's own record does. The
    ; roster loop above returns before that lookup, so nothing else here reaches it.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#RECORDEDPATH), "no record of the probe path survives from an earlier run")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#RECORDEDPATH, "created"), "install's record of the probe path is written")
    ; OnAfterOneTest removes it, so a failure between the write and the removal cannot leave a
    ; record behind and change the next run's serving-path answers.
    Do ..OwnPath(..#RECORDEDPATH, tExpected)

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
}

/// <p>AD-6: the diff scopes the set, so the gate behind it covers the payload the port would be
/// sent. A row whose stored payload weakens the live target while its diff names nothing -- or
/// cannot be read at all -- is refused 409 <code>PROPOSAL.TARGETCHANGED</code> and closed, so no
/// route reaches the port with a payload its own fingerprint does not cover.</p>
/// <p>Mutation: drop the stored-payload comparison from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- this goes red and each
/// confirm succeeds and writes.</p>
Method TestARowWhosePayloadItsFingerprintDoesNotCoverIsRefused()
{
    Set tServing = "/api/ocupilot"
    Set tLive = ..Target()
    Kill tHere, tElsewhere
    Set tHere("NameSpace") = $ListBuild("HSCUSTOM", "string")
    Set tElsewhere("NameSpace") = $ListBuild("USER", "string")
    Set tServingLive = ##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tHere)
    ; the live target, the payload the row stores against it, the row's diff, its path, and what it is.
    Set tCases = $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Other", "", 1), "[]", ..#TARGET, "a repointed dispatch class behind an empty diff"))
    Set tCases = tCases _ $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 96, "%Development", "Probe.Dispatch", "", 1), "[]", ..#TARGET, "unauthenticated access behind an empty diff"))
    Set tCases = tCases _ $ListBuild($ListBuild(tServingLive, ##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "", "OcuPilot.Api.Router", "", 1, "before", .tElsewhere), "[]", tServing, "OcuPilot's own namespace repointed behind an empty diff"))
    Set tCases = tCases _ $ListBuild($ListBuild(tLive, ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Other", "", 1), "not json", ..#TARGET, "a repointed dispatch class behind a diff nobody can read"))
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
        ; 409 rather than 403 is the point: the set is silent on a row that proposes nothing, and
        ; the fingerprint gate is what refuses the payload behind it.
        Do $$$AssertEquals(tHttp, 409, "at 409, code was '" _ tCode _ "'")
        Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "with the target-changed code")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "target-changed", "and the row closes rather than staying live")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing at the port")
    }
}

}
