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

/// <p>A fixed throwaway password for <parameter>PRINCIPALUSER</parameter>: the account is
/// recreated by <method>EnsureLeastPrivilegedPrincipal</method> at the start of the one test that
/// uses it and removed at the end, so nothing about this value needs to be secret or unique across
/// runs -- only long and mixed enough to satisfy the instance's own password policy.</p>
Parameter PRINCIPALPASSWORD = "OcuPilotAc5ProbePassword9Aa";

/// <p>The role, and the user holding only it, that
/// <method>TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal</method> creates and
/// removes: exactly the write's two required pairs (<class>OcuPilot.Screen.Descriptor.WebAppList</class>'s
/// own, DW-1208) and nothing else. Dedicated names, never <class>OcuPilot.Test.TurnWireFixture</class>'s
/// shared role -- that role's resources are that fixture's own concern, and overwriting them here
/// would leave a later class in the sweep holding the wrong grant.</p>
Parameter PRINCIPALROLE = "OcuPilotProbeProhibitedRouteRole";

Parameter PRINCIPALUSER = "OcuPilotProbeProhibitedRouteUser";

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
    Do ..RemoveLeastPrivilegedPrincipal()
    ; Defensive: TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal removes this record
    ; itself, but a failure between writing it and removing it would otherwise leave TARGET marked
    ; OcuPilot's own for every later test in this class.
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
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

/// <p>POST the confirm route for <var>pKey</var> as <var>pUser</var> -- the least-privileged leg's
/// own confirming call, never the test account.</p>
Method CallAs(pKey As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", pUser, pPassword, .pStatus, .pBody, .pHeaders, "", "application/json")
}

/// <p>The resource that guards read access to the install namespace's own code database --
/// <class>OcuPilot.Test.TurnWireFixture.Resources</class>'s "clears the router's floor" resource,
/// needed here for the same underlying reason: reaching <class>OcuPilot.Api.Router</class> at all
/// over HTTP requires it, independently of and beneath <method>OcuPilot.Kernel.Proposal.Confirm</method>'s
/// own declared pairs. A principal that holds DW-1208's two pairs but not this one is refused a
/// bare 403 with no envelope before the confirm route's own code ever runs -- measured while
/// writing this test, which is why it is granted explicitly rather than assumed to come free with
/// the write's own pairs.</p>
Method CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
    } Catch ex {
        Set tResource = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

/// <p>Create or reset <parameter>PRINCIPALUSER</parameter> holding <parameter>PRINCIPALROLE</parameter>
/// with exactly <var>pResources</var>, and <var>pPassword</var>. A dedicated principal rather than
/// <class>OcuPilot.Test.TurnWireFixture</class>'s, per <parameter>PRINCIPALROLE</parameter>'s own
/// doc comment.</p>
Method EnsureLeastPrivilegedPrincipal(pPassword As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE, .tR, .tRS) {
            Kill tProps
            Set tProps("Resources") = pResources
            Set tProps("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#PRINCIPALROLE, .tProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, "OcuPilot AC5 least-privileged probe (throwaway)", pResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PRINCIPALUSER, ..#PRINCIPALROLE, pPassword, "OcuPilot AC5 least-privileged probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ProhibitedRoute")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove <parameter>PRINCIPALUSER</parameter> when the instance holds it. The role is left in
/// place, the same convention <class>OcuPilot.Test.TurnWireFixture.DeletePrincipal</class> follows
/// for its own role.</p>
Method RemoveLeastPrivilegedPrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Seed one completed turn and one live proposal owned by <var>pUser</var> against
/// <var>pTarget</var>, exactly as <method>Seed</method> does for <parameter>TARGET</parameter> and
/// the test account -- the two are parameterized here so the least-privileged leg can mint and
/// confirm as the same principal (<method>OcuPilot.Kernel.Proposal.Write.ClaimById</method> refuses
/// a confirm from anyone but the row's own minting user).</p>
/// <p><b>Mint-shaped only:</b> unlike <method>Seed</method>, there is no hand-seeded fallback for a
/// field the tool cannot set -- every caller here passes a field the tool's settable list carries,
/// so <method>Minted</method> always answers a real diff row.</p>
Method SeedForPrincipal(pUser As %String, pTarget As %String, pFresh As %DynamicObject, pField As %String, pValue As %RawString, pType As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded for the least-privileged principal")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pTarget, .tRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    If $$$ISERR(tSC) Quit ""

    Set tArgs = {}
    Do tArgs.%Set(pField, pValue, pType)
    Set tSC = ..Minted(pFresh, tArgs, .tPayload, .tDiff, .tFingerprint, .tUnchanged)
    If $$$ISERR(tSC) Quit ""

    Kill tValues
    Set tValues("user") = pUser
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
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded for the least-privileged principal")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
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

/// <p>Story 5.8's residual: the pairs-before-prohibited reorder that fixed DW-1208 (a caller short
/// a pair reaching <method>Prohibited.Target</method>'s live port read and being answered a generic
/// internal error instead of <code>AUTH.NOPRIVILEGE</code>) is pinned as <code>%All</code> at the
/// unit tier (<class>OcuPilot.Test.ProposalConfirm</class>'s two
/// <method>TestThePrivilegeGateAnswersBefore...</method> methods) and as a real least-privileged
/// principal at the browser tier, but only against <code>/csp/myapp</code>
/// (<file>ui/browser/proposal-demo.browser-spec.mjs</file>'s AC4 leg). AC5's own serving-path
/// refusal reads live state through that same <method>Target</method> call, and had never been
/// measured for a caller who is not <code>%All</code>: the over-the-wire legs in this class run
/// as <code>%All</code> (this class's own header), and
/// <method>OcuPilot.Test.ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused</method>
/// replaces the port with a fixture and never asks a real privilege question at all. So nobody had
/// proven that a holder of exactly the write's two pairs reaches
/// <code>PROHIBITED.SERVINGPATH</code> for one of OcuPilot's own applications, rather than the same
/// internal error DW-1208 named for a different gate.</p>
/// <p><b>Drives this class's own probe application, not the instance's real API or shell
/// application.</b> Install's own "recorded" table -- the same mechanism
/// <method>OcuPilot.Test.ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused</method>
/// exercises for its <parameter>RECORDEDPATH</parameter> leg -- marks <parameter>TARGET</parameter>
/// as OcuPilot's own for exactly the span of this test, so the serving-path predicate fires over
/// the real HTTP/port path (needed to reach the privilege gate this test is actually about) without
/// any write ever reaching the instance's own live-serving applications. The record is removed
/// before this method returns and again, defensively, in <method>OnAfterOneTest</method>.</p>
/// <p>Reads only past the record itself: disabling the (recorded) probe application is refused
/// before the port <code>PUT</code> is ever reached, so nothing here writes to it, and the
/// application is read back afterwards to confirm that. The principal's grant is checked on the
/// instance rather than assumed (Rule 19).</p>
/// <p>Mutation (Rule 19): drop the <method>DeleteByPath</method>/<method>GuardedRecord</method>
/// pair -- with <parameter>TARGET</parameter> never recorded, this leg's own proposal reaches the
/// same <code>AUTHORIZATION</code>/<code>UNAUTHENTICATED</code>/<code>DISPATCH</code> family
/// <method>Weakened</method>'s legs pin instead of <code>SERVINGPATH</code>, which reddens the code
/// assertion. The order fix itself is pinned by
/// <method>OcuPilot.Test.ProposalConfirm.TestThePrivilegeGateAnswersBeforeTheProhibitedSet</method>
/// and is <b>not</b> what this test falsifies: this principal holds the pair
/// <method>Target</method>'s own read requires, so that read succeeds regardless of gate order, and
/// this test pins that the fix generalizes to AC5's refusal for a caller who is not
/// <code>%All</code>, not the order itself.</p>
Method TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, "%Admin_Secure:U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "the least-privileged principal is created")
    If $$$ISERR(tSC) Quit

    ; Measured, not assumed: the principal holds exactly the write's two pairs and not the
    ; permission DW-1208 replaced.
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 1, "the principal holds %Admin_Secure:USE")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and %DB_IRISSYS:READ")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "WRITE"), 0, "and not the WRITE permission DW-1208 replaced")

    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#TARGET, "created"), "the probe application is recorded as OcuPilot's own for this leg")

    Set tBefore = ..Snapshot(.tFresh)
    If tBefore '= "" {
        Set tKey = ..SeedForPrincipal(..#PRINCIPALUSER, ..#TARGET, tFresh, "Enabled", 0, "boolean")
        If tKey '= "" {
            Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
            Do $$$AssertStatusOK(tSC, "the request completes")
            Do $$$AssertEquals(tStatus, 403, "and is refused -- not a 500 from the live read, not a 401: " _ tBody)
            Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tEnvelope.%Get("code"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH"), "with the serving-path code, not AUTH.NOPRIVILEGE and not an internal error")
            Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
            Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "the probe application on the instance is what it was")
        }
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET), "the temporary record is removed")
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
