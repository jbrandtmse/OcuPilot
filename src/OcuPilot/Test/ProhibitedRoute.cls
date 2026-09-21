/// <p>The prohibited set over HTTP, against a <b>real</b> web application (Story 5.5, AD-10,
/// AD-39): the shipped <class>OcuPilot.Kernel.Proposal.Confirm</class>, the shipped
/// <class>OcuPilot.Port.AdminPort</class>, and the instance's own record of the target read back
/// afterwards.</p>
/// <p>It also pins the set's idea of which spellings of a path name one application against the
/// instance's own resolution (DW-1352), which is the one claim in that predicate that no fixture
/// can answer.</p>
/// <p><b>What it needs from the environment:</b> the OcuPilot web application reachable on this
/// instance's own web-server port, the applications the install roster declares, an account
/// holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not, because this class creates and
/// deletes a web application; only <file>scripts/ci-throwaway.sh</file> sets it.</p>
/// <p><b>It writes nothing it did not create.</b> The probe application is
/// <method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method>'s, which refuses to adopt one
/// it did not make, and every test here asserts that the confirm left it byte for byte as it
/// was.</p>
Class OcuPilot.Test.ProhibitedRoute Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Parameter TOOL = "webapp.list.update";

/// <p>The probe application's path, <class>OcuPilot.Test.ProposalFixture</class>'s own.</p>
Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>The resource the probe application is guarded by while this class runs, so the dropped-
/// authorization predicate has something to drop. A standard IRIS resource, never a new one.</p>
Parameter GUARDRESOURCE = "%Development";

/// <p>Create the probe application and guard it, or refuse to run at all.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProhibitedRoute creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace, .tCreated)
    If $$$ISERR(tSC) Quit tSC
    Quit ..Guard(..#GUARDRESOURCE)
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Set the probe application's guarding resource to <var>pResource</var>. Only ever called for
/// <parameter>TARGET</parameter>, which this suite created.</p>
Method Guard(pResource As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Resource") = pResource
        Set tSC = ##class(Security.Applications).Modify(..#TARGET, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe application as the shipped port answers it now, in <var>pFresh</var>, and its
/// complete property set as one comparable string -- the whole object the vendor's own
/// <code>GET</code> renders, so "byte-for-byte what they were" is compared property for
/// property rather than over a chosen few.</p>
Method Snapshot(Output pFresh As %DynamicObject) As %String
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe application reads back through the port")
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit ""
    Set pFresh = tFresh
    Quit tFresh.%ToJSON()
}

/// <p>Seed one completed turn and one live proposal whose payload is the target as the instance
/// holds it now, with <var>pField</var> set to <var>pValue</var> -- the complete property set AD-4
/// requires, with exactly one property weakened.</p>
/// <p><b>A field the shipped tool can set is seeded exactly as a mint stores it</b>: one
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> over one real argument supplies the
/// payload, the diff and the unchanged count, and the fingerprint is that payload's own digest.
/// That is the relationship <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> writes, so both
/// digests <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> compares match and
/// the set is the only gate left between this row and the vendor write -- which is what lets the
/// clauses below asserting the application did not move fail when the set is removed.</p>
/// <p>A field the tool cannot set has no mint-shaped row at all: the tool refuses it 400 before a
/// proposal exists. Such a leg is seeded by hand, and because its stored payload carries the
/// weakened value it cannot digest to the fingerprint the fresh read produces, so the gate behind
/// the set refuses it once the set is removed -- its mutation reddens the 403 and the code, never
/// the untouched-application clause.</p>
Method Seed(pFresh As %DynamicObject, pField As %String, pValue As %RawString, pType As %String) As %String
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", ..#TARGET, .tRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    If $$$ISERR(tSC) Quit ""

    Set tArgs = {}
    Do tArgs.%Set(pField, pValue, pType)
    Set tSC = ..Minted(pFresh, tArgs, .tPayload, .tDiff, .tFingerprint, .tUnchanged)
    If $$$ISERR(tSC) Quit ""
    If tDiff = "[]" {
        ; The shipped merge moved nothing, so this field is outside the tool's settable list and no
        ; mint produces a row for it. Seed the weakened payload by hand against the fresh read's
        ; own digest.
        Set tHand = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Do tHand.%Set(pField, pValue, pType)
        Set tPayload = tHand.%ToJSON()
        Set tDiff = ##class(OcuPilot.Test.ProhibitedFixture).Diff(pField)
        Set tFingerprint = ..Digest(pFresh)
        Set tUnchanged = 0
        Set tArgs = {}
    }

    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tArgs.%ToJSON()
    Set tValues("payload") = tPayload
    Set tValues("diff") = tDiff
    Set tValues("unchangedCount") = tUnchanged
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>The row a mint would have stored for <var>pArgs</var> against <var>pFresh</var>, built with
/// the shipped methods <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> itself uses: the merge's
/// payload and diff as JSON, that payload's digest under the descriptor's own exclusions, and the
/// merge's unchanged count.</p>
/// <p><var>pDiff</var> reads <code>[]</code> when the merge moved nothing, which is the answer for
/// an argument naming a field the tool's settable list does not carry.</p>
Method Minted(pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %String, Output pDiff As %String, Output pFingerprint As %String, Output pUnchanged As %Integer) As %Status
{
    Set pPayload = ""
    Set pDiff = ""
    Set pFingerprint = ""
    Set pUnchanged = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the write tool resolves")
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tTool) Quit $$$ERROR($$$GeneralError, "the write tool " _ ..#TOOL _ " resolved to no entry")
    Set tClass = tTool.%Get("class")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tMerged, .tRows, .tCount, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over the fresh read")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    If $$$ISERR(tSC) Quit tSC
    Set tExcludes = ""
    Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
    If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tMerged, tExcludes, .pFingerprint)
    Do $$$AssertStatusOK(tSC, "and the digest is taken")
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertNotEquals(pFingerprint, "", "which is not empty")
    Set pPayload = tMerged.%ToJSON()
    Set pDiff = tRows.%ToJSON()
    Set pUnchanged = tCount
    Quit tSC
}

/// <p>The digest the shipped confirm re-computes for <var>pFresh</var> with no argument applied:
/// the fresh read merged and hashed through the same shipped methods
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> calls.</p>
/// <p>It is the fingerprint of a hand-seeded leg only, and it is deliberately not the digest of
/// that leg's stored payload -- which is why the stored-payload half of the fingerprint gate
/// refuses such a row the moment the set stops answering first.</p>
Method Digest(pFresh As %DynamicObject) As %String
{
    Set tSC = ..Minted(pFresh, {}, .tPayload, .tDiff, .tFingerprint, .tUnchanged)
    If $$$ISERR(tSC) Quit ""
    Quit tFingerprint
}

/// <p>POST the confirm route for <var>pKey</var> as the test account.</p>
Method Call(pKey As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders, "", "application/json")
}

/// <p>Seed a proposal weakening <var>pField</var>, confirm it over HTTP, and assert the 403 it
/// earns, the sentence beside the code, and that the application on the instance did not move.</p>
Method Weakened(pField As %String, pValue As %RawString, pType As %String, pExpected As %String)
{
    Set tBefore = ..Snapshot(.tFresh)
    If tBefore = "" Quit
    Set tKey = ..Seed(tFresh, pField, pValue, pType)
    If tKey = "" Quit

    Set tSC = ..Call(tKey, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(tBody [ "}{", 0, "in exactly one envelope")
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), pExpected, "carrying " _ pExpected)
    Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
    Do $$$AssertEquals(tEnvelope.%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(pExpected), "with the set's own written sentence rendered beside it")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
    Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "the application's properties on the instance are what they were")
}

/// <p>The integration acceptance criterion: a stored proposal that would drop a real probe web
/// application's resource is refused 403 <code>PROHIBITED.AUTHORIZATION</code> over the wire, and
/// the application on the instance is untouched.</p>
/// <p>Mutation: point <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method> back at
/// <code>""</code>, or remove the prohibited call from
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method>. This row is mint-shaped, so
/// either mutation carries it past the fingerprint gate and into the vendor write: the 403, the
/// code, the row's live state, the unspent token <b>and</b> the untouched-application clause all
/// redden together.</p>
/// <p>AC5 (Story 5.8), AD-10: <b>the registry advertises no delete verb for a web application at
/// all.</b> A prohibited action is absent from the tool set, not gated within it, so the question
/// is what is registered -- deleting a web application is never proposable because there is
/// nothing to propose it with.</p>
/// <p>Asked of every registered tool rather than of one name: a delete could arrive under any
/// verb, and the shape that would make it reachable is a <code>write</code>-kind tool on this
/// screen's identifier that is not the one update this release reviewed.</p>
/// <p>Mutation (Rule 19): add a second <code>write</code> tool under the
/// <code>webapp.list</code> identifier and recompile the package -- this goes red naming it.</p>
Method TestNoDeleteVerbIsAdvertisedForAWebApplication()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists its tools")
    Set tIdentifier = $ClassMethod("OcuPilot.Screen.Descriptor.WebAppList", "ToolIdentifier")
    Do $$$AssertNotEquals(tIdentifier, "", "the web applications screen declares a tool identifier")
    Set tSeen = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If $Piece(tTool.%Get("name"), ".", 1, 2) '= tIdentifier Continue
        Set tSeen = tSeen + 1
        If tTool.%Get("kind") '= "write" Continue
        Do $$$AssertEquals(tTool.%Get("name"), ..#TOOL, "the only write verb on " _ tIdentifier _ " is the reviewed update, not '" _ tTool.%Get("name") _ "'")
    }
    Do $$$AssertTrue(tSeen > 0, "the registry carries tools on " _ tIdentifier _ " at all, so this assertion ran over something")
}

Method TestADroppedResourceIsRefusedOverTheWire()
{
    Do ..Weakened("Resource", "", "string", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "AUTHORIZATION"))
}

/// <p>DW-1207's second field against the same real application: adding the unauthenticated bit to
/// a probe application the fixture created reading 32.</p>
/// <p>Mutation: as above, and with the same reach -- <code>AutheEnabled</code> is one of the
/// fields the tool admits, so this row is mint-shaped too and the untouched-application clause is
/// load-bearing.</p>
Method TestAWeakenedAuthenticationIsRefusedOverTheWire()
{
    Do ..Weakened("AutheEnabled", 96, "number", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNAUTHENTICATED"))
}

/// <p>Repointing the dispatch class is refused at the write as well as being absent from the tool
/// set, so a proposal that reached confirm by any other route is still refused.</p>
/// <p>Mutation: as above, but this row is hand-seeded -- the tool cannot set
/// <code>DispatchClass</code>, so no mint produces one and its stored payload cannot digest to its
/// fingerprint. Removing the set therefore reddens the 403, the code and the live-row clauses, and
/// the row is refused 409 <code>PROPOSAL.TARGETCHANGED</code> by the gate behind the set rather
/// than reaching the port -- so the untouched-application clause stays green here by construction
/// and is not what this leg pins.</p>
Method TestARepointedDispatchClassIsRefusedOverTheWire()
{
    Do ..Weakened("DispatchClass", "OcuPilot.Api.Router", "string", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "DISPATCH"))
}

/// <p>DW-1352: the set normalizes a web application's name exactly as far as this instance
/// resolves it. For every path the install roster declares, a spelling the shipped port's own
/// <code>GET</code> answers that same application for must normalize to it, and one the port
/// answers nothing for must not -- so a re-cased or slash-suffixed id cannot reach OcuPilot's own
/// API through the endpoint while the serving-path predicate reads the target as somebody
/// else's.</p>
/// <p>The instance is the authority here, not a remembered rule: each leg asks the port and the set
/// the same question and compares the two answers, so a build that normalized differently reddens
/// this rather than passing silently.</p>
/// <p><b>It reads only:</b> no proposal is seeded, no application is modified, and the probe
/// application plays no part.</p>
/// <p>Mutations: drop the trailing-slash loop from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.NormalizedPath</method>, or make it strip a leading
/// slash as well -- the first goes red on the slash-suffixed spellings and the second on the
/// leading-slash-less one, because in each case the set and the instance disagree.</p>
Method TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt()
{
    Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
    Do $$$AssertNotEquals(tKeys, "", "the roster declares its application keys")
    For tI = 1:1:$Length(tKeys, ",") {
        Set tSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
        Do $$$AssertStatusOK(tSC, "the roster reads application " _ $Piece(tKeys, ",", tI))
        If $$$ISERR(tSC) Continue
        Set tPath = tApp.path
        Set tCanonical = ..Read(tPath)
        Do $$$AssertNotEquals(tCanonical, "", tPath _ " reads back through the port, so the comparison below has an answer to compare with")
        If tCanonical = "" Continue
        ; Three spellings this build resolves and three it does not, so the agreement is asserted
        ; in both directions rather than only where the set says yes.
        Set tForms = $ListBuild($ZConvert(tPath, "U"), tPath _ "/", $ZConvert(tPath, "U") _ "///")
        Set tForms = tForms _ $ListBuild($Extract(tPath, 2, $Length(tPath)), "/" _ tPath, tPath _ " ")
        For tJ = 1:1:$ListLength(tForms) {
            Set tForm = $List(tForms, tJ)
            Set tResolves = (..Read(tForm) = tCanonical)
            Set tNormalizes = (##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedPath(tForm) = ##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedPath(tPath))
            Do $$$AssertEquals(tNormalizes, tResolves, "the set and the instance agree about '" _ tForm _ "', which the instance resolves to " _ tPath _ ": " _ tResolves)
        }
    }
}

/// <p>The application at <var>pPath</var> as the shipped port's own <code>GET</code> renders it, or
/// <code>""</code> where the instance resolves none. Quiet on purpose: a refusal is one of the two
/// answers this question has, not a failure.</p>
Method Read(pPath As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pPath
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit ""
    Quit tFresh.%ToJSON()
}

}
