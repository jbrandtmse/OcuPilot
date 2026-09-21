/// <p>Pins AD-10's prohibited set (Story 5.5): the named predicates, the fail-closed refusals
/// around them, the fields that are absent from the tool set, and the set's single home. The
/// by-effect shape behind them -- the reviewed-few field rule, the widening rule, OcuPilot's own
/// applications and the diff scoping -- is <class>OcuPilot.Test.ProhibitedByEffect</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, the compiled tool
/// registry and an account holding <code>%All</code>. Every port call is
/// <class>OcuPilot.Test.ProposalFixture</class>'s -- the confirm's and the set's alike -- so
/// <b>nothing here writes to the instance</b> and no principal is created. The over-the-wire leg
/// against a real web application is <class>OcuPilot.Test.ProhibitedRoute</class>'s, which is armed
/// for a throwaway container.</p>
/// <p>Every row it seeds hangs off a turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method>
/// created, which is what <method>OnAfterOneTest</method> removes them by.</p>
Class OcuPilot.Test.Prohibited Extends %UnitTest.TestCase
{

/// <p>The shipped set with the port replaced, so the shipped predicates run against an armed
/// target. It carries the suite's shared builders too.</p>
Parameter SET = "OcuPilot.Test.ProhibitedFixture";

Parameter SHIPPEDSET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter TOOL = "webapp.list.update";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.WebAppUpdate";

/// <p>A path that is neither OcuPilot's own nor one the instance carries. The port is the fixture,
/// so nothing resolves it either way.</p>
Parameter TARGET = "/csp/ocupilotprobeprohibited";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    ; The confirm asks the seam for a class; this fixture subclass runs the shipped predicates
    ; against the armed target rather than against the instance.
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SET)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>The target every predicate is driven against: password authentication, a resource, a dispatch
/// class, no roles, enabled.</p>
Method Target() As %String
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1)
}

/// <p>The same property set as a payload the mint would have produced -- a copy of the target with
/// one reviewed field changed -- which is not prohibited by itself.</p>
Method Payload() As %String
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1, "after")
}

/// <p>The diff a payload changing <var>pFields</var> (comma-separated) was minted with.</p>
Method Diff(pFields As %String) As %String
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).Diff(pFields)
}

/// <p>Ask the set directly about <var>pPayload</var> and its diff against the armed target
/// <var>pFresh</var>.</p>
Method Ask(pFresh As %String, pPayload As %String, pFields As %String, Output pProhibits As %Boolean, Output pCode As %String, pPath As %String = {..#TARGET}, pType As %String = "web-application") As %Status
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).Ask(pFresh, pPayload, ..Diff(pFields), pPath, pType, .pProhibits, .pCode)
}

/// <p>Seed one completed turn and one live proposal carrying <var>pPayload</var> and a diff naming
/// <var>pFields</var> against <var>pPath</var> of type <var>pType</var>, for the running account,
/// and answer the proposal's id.</p>
Method Seed(pPayload As %String, pFields As %String, pPath As %String = {..#TARGET}, pType As %String = "web-application") As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tRef = ##class(OcuPilot.Test.ProhibitedFixture).Reference(pPath, pType)
    Do $$$AssertNotEquals(tRef, "", "the target reference is built")
    If tRef = "" Quit ""
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = pPayload
    Set tValues("diff") = ..Diff(pFields)
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

/// <p>Drive <var>pPayload</var> and its diff against <var>pFresh</var> through the shipped confirm
/// and assert the refusal it earns: 403 with <var>pExpected</var>, the row still live, nothing at
/// the port.</p>
Method Refused(pFresh As %String, pPayload As %String, pFields As %String, pExpected As %String, pPath As %String = {..#TARGET})
{
    Set tKey = ..Seed(pPayload, pFields, pPath)
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(pFresh)
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, pExpected, "with " _ pExpected)
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row stays live")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
}

/// <p>Matrix row 1, DW-1207: a payload that lets the target be reached without signing in is
/// refused at the write.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> answer
/// <code>pProhibits = 0</code> for the <code>AutheEnabled</code> predicate -- this goes red.</p>
Method TestAWeakenedAuthenticationIsRefused()
{
    Do ..Refused(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 96, "%Development", "Probe.Dispatch", "", 1, "after"), "AutheEnabled", $Parameter(..#SHIPPEDSET, "UNAUTHENTICATED"))
}

/// <p>Matrix row 2, DW-1207: a payload that clears a resource the target holds is refused.</p>
Method TestADroppedAuthorizationResourceIsRefused()
{
    Do ..Refused(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "", "Probe.Dispatch", "", 1, "after"), "Resource", $Parameter(..#SHIPPEDSET, "AUTHORIZATION"))
}

/// <p>Matrix row 3, DW-1207: a payload naming a different dispatch class is refused at the write,
/// whichever route minted it -- the tool's own exclusion is the other half.</p>
Method TestARepointedDispatchClassIsRefused()
{
    Do ..Refused(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Other", "", 1, "after"), "DispatchClass", $Parameter(..#SHIPPEDSET, "DISPATCH"))
}

/// <p>Matrix row 4: a payload changing the roles the application grants is refused.</p>
Method TestAChangedRoleGrantIsRefused()
{
    Do ..Refused(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", ":%All", 1, "after"), "MatchRoles", $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT"))
}

/// <p>Matrix row 6: an entity type the set evaluates no predicates for is refused wholesale, and so
/// is a reference that cannot be parsed at all. The user predicates Story 5.9 added are
/// <class>OcuPilot.Test.UserUpdate</class>'s, so <code>user</code> is no longer one of the types
/// named here.</p>
/// <p>Mutation: answer <code>pProhibits = 0</code> in the uncovered arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- this goes red.</p>
Method TestAnUncoveredEntityTypeIsRefusedWholesale()
{
    Set tUncovered = $ListBuild("task", "process", "role", "resource", "service", "database")
    For tI = 1:1:$ListLength(tUncovered) {
        Set tType = $List(tUncovered, tI)
        Set tSC = ..Ask(..Target(), ..Payload(), "Description", .tProhibits, .tCode, "probe-id", tType)
        Do $$$AssertStatusOK(tSC, "the set answers for " _ tType)
        Do $$$AssertEquals(tProhibits, 1, tType _ " is refused")
        Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "UNCOVERED"), "as uncovered")
    }
    Set tSC = $ClassMethod(..#SET, "Prohibits", ..#TOOL, "this is not a reference key", ..Payload(), ..Diff("Description"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "an unparseable reference is answered, not raised")
    Do $$$AssertEquals(tProhibits, 1, "and refused")
    Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "UNCOVERED"), "as uncovered")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes()), "web-application,user,auditing-configuration", "Release 1 covers exactly three entity types")

    ; The refusal reaches a caller as a 403 with the set's own code, not as an error.
    Set tKey = ..Seed(..Payload(), "Description", "probe-id", "task")
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Target())
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "UNCOVERED"), "with the uncovered code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")
}

/// <p>Matrix row 7: a hardening change is not prohibited, and the confirm carries on to the gates
/// behind the set -- here the fingerprint, which the seeded digest does not match.</p>
Method TestAHardeningChangeIsNotProhibited()
{
    ; Resource "" -> %Development.
    Set tSC = ..Ask(##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "", "Probe.Dispatch", "", 1), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1), "Resource", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the resource case")
    Do $$$AssertEquals(tProhibits, 0, "giving a resource is not prohibited, code was '" _ tCode _ "'")

    ; AutheEnabled 96 -> 32: the way in the target allows is narrowed, not widened.
    Set tSC = ..Ask(##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 96, "%Development", "Probe.Dispatch", "", 1), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 1), "AutheEnabled", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the authentication case")
    Do $$$AssertEquals(tProhibits, 0, "requiring a password is not prohibited, code was '" _ tCode _ "'")

    ; Enabled false -> true on an application that is not OcuPilot's own.
    Set tSC = ..Ask(##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", "", 0), ..Payload(), "Enabled,Description", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the enable case")
    Do $$$AssertEquals(tProhibits, 0, "enabling it is not prohibited, code was '" _ tCode _ "'")

    Set tKey = ..Seed(..Payload(), "Description")
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Target())
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is still refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "by the fingerprint gate behind the set, not by the set")
    Do $$$AssertEquals(tHttp, 409, "at 409")
}

/// <p>Matrix rows 8 and 9: a target the instance no longer holds is not prohibited -- the
/// fingerprint gate refuses it -- while a target the port could not read at all is an error status,
/// which the confirm renders 500 with no write. Both shapes of unreadable are driven: a read that
/// answered no object, and a read that failed at a status other than 404.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.Target</method> read every failed
/// read as absence -- the failed-read leg goes red and the missing leg does not.</p>
Method TestAnUnreadableTargetFailsClosedAndAMissingOneDoesNot()
{
    Set tRef = ##class(OcuPilot.Test.ProhibitedFixture).Reference(..#TARGET)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = $ClassMethod(..#SET, "Prohibits", ..#TOOL, tRef, ..Payload(), ..Diff("Description"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "a target that is gone is answered, not raised")
    Do $$$AssertEquals(tProhibits, 0, "and is not prohibited")

    Set tKey = ..Seed(..Payload(), "Description")
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Confirm(tKey, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "by the fingerprint gate")
    Do $$$AssertEquals(tHttp, 409, "at 409")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmEmpty()
    Set tSC = $ClassMethod(..#SET, "Prohibits", ..#TOOL, tRef, ..Payload(), ..Diff("Description"), .tProhibits, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a read that answered no target is an error status")
    Do $$$AssertEquals(tProhibits, 0, "with no verdict")
    Do $$$AssertEquals(tCode, "", "and no code")

    Set tSecond = ..Seed(..Payload(), "Description")
    If tSecond = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmEmpty()
    Set tSC = ..Confirm(tSecond, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#INTERNAL, "with the internal code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no write went out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "State"), "live", "the row stays live")

    ; The read itself faults, at a status that is not 404: the non-absence branch of the read.
    Do ##class(OcuPilot.Test.ProposalFixture).ArmReadFault(500)
    Set tSC = $ClassMethod(..#SET, "Prohibits", ..#TOOL, tRef, ..Payload(), ..Diff("Description"), .tProhibits, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a read that failed is an error status")
    Do $$$AssertEquals(tProhibits, 0, "with no verdict")
    Do $$$AssertEquals(tCode, "", "and no code")

    Set tThird = ..Seed(..Payload(), "Description")
    If tThird = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmReadFault(500)
    Set tSC = ..Confirm(tThird, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#INTERNAL, "with the internal code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no write went out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tThird, "State"), "live", "the row stays live")
}

/// <p>AC3 and AC4's first half, DW-1207: every field the set calls always-prohibited for a tool's
/// entity type is absent from that tool's advertised schema and settable list, nothing the tool
/// does admit is outside the set's reviewed few, and the model asking for an excluded one is
/// refused before any proposal exists.</p>
/// <p>Mutations: add a field to
/// <parameter>OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS</parameter> that
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> does not name, add
/// one to <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> alone, make
/// the tool declare <code>DispatchClass</code> a secret argument, declare an unreviewed field such
/// as <code>EventClass</code> a secret argument, or put a settable field in the descriptor's
/// <method>FingerprintExcludes</method> -- each goes red. Dropping
/// <code>DispatchClass</code> from
/// <method>OcuPilot.Screen.Tool.WebAppUpdate.ExcludedFields</method> does not: the positive list is
/// what admits a field now, and the exclusions are belt and braces over it.</p>
Method TestNoWriteToolAdmitsAnAlwaysProhibitedField()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Set tWrites = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        Set tClass = tEntry.%Get("class")
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tType = ""
        If tDescriptor '= "" Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
        Set tAlways = ##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedFields(tType)
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSecrets = $ClassMethod(tClass, "SecretArguments", "", .tSecretsDeclared)
        Do $$$AssertEquals(tSecretsDeclared, 1, tEntry.%Get("name") _ " declares its secret arguments")
        For tI = 1:1:$ListLength(tAlways) {
            Set tField = $List(tAlways, tI)
            Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf(tField), "unassigned", tEntry.%Get("name") _ " does not advertise " _ tField)
            Do $$$AssertEquals($ListFind(tSettable, tField), 0, "and cannot set it")
            ; The confirm merges a declared secret's supplied value over the stored payload after
            ; the prohibited verdict is reached, so a tool must not declare one of these a secret.
            Do $$$AssertEquals($ListFind(tSecrets, tField), 0, "and does not declare it a secret argument")
        }
        ; The other half of AD-10's title, and the one that covers a field nobody has named: a tool
        ; advertises nothing outside the set's reviewed few, so a vendor property added to the
        ; endpoint's template reaches no schema until the set has a predicate for it.
        Set tPermitted = ##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields(tType)
        Do $$$AssertTrue($ListLength(tSettable) > 0, tEntry.%Get("name") _ " admits at least one field")
        For tI = 1:1:$ListLength(tSettable) {
            Set tField = $List(tSettable, tI)
            Do $$$AssertTrue($ListFind(tPermitted, tField) > 0, tEntry.%Get("name") _ " admits '" _ tField _ "', which the prohibited set has reviewed for " _ tType)
        }
        ; The converse, so the two lists are asserted equal rather than one-way: a name added to the
        ; set's reviewed few alone reddens here, and so does a PERMITTEDFIELDS spelling the tool's
        ; own $ListFromString does not trim, since the untrimmed name admits nothing.
        For tI = 1:1:$ListLength(tPermitted) {
            Set tField = $List(tPermitted, tI)
            Do $$$AssertTrue($ListFind(tSettable, tField) > 0, tEntry.%Get("name") _ " advertises '" _ tField _ "', which the prohibited set has reviewed for " _ tType)
        }
        ; And the two lists cannot overlap: a field whose every change is prohibited is never one of
        ; the reviewed few.
        For tI = 1:1:$ListLength(tAlways) {
            Do $$$AssertEquals($ListFind(tPermitted, $List(tAlways, tI)), 0, $List(tAlways, tI) _ " is not among the fields the set permits a change to for " _ tType)
        }
        ; Every declared secret is one of the reviewed few, not merely not always-prohibited. The
        ; confirm merges a supplied secret's value over the stored payload AFTER the prohibited
        ; verdict is reached, so a name the set has no predicate for, declared secret, would reach
        ; the vendor body unevaluated and unadvertised -- past the reviewed-few floor above, which
        ; reads the settable list a secret is not on.
        For tI = 1:1:$ListLength(tSecrets) {
            Set tField = $List(tSecrets, tI)
            Do $$$AssertTrue($ListFind(tPermitted, tField) > 0, tEntry.%Get("name") _ " declares '" _ tField _ "' secret, and the prohibited set has reviewed it for " _ tType)
        }
        ; And no field the tool can set is excluded from the fingerprint. AD-6's exclusions are for
        ; properties the endpoint itself moves as a side effect; an excluded field the tool can set
        ; may differ between the stored payload and the live target with neither digest noticing,
        ; and the set is scoped to the diff, so a diff that does not name it makes it invisible to
        ; both gates.
        Set tExcludes = ""
        If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
        For tI = 1:1:$ListLength(tExcludes) {
            Set tField = $List(tExcludes, tI)
            Do $$$AssertEquals($ListFind(tSettable, tField), 0, tEntry.%Get("name") _ " excludes '" _ tField _ "' from the fingerprint, so it must not be a field the tool can set")
        }
    }
    Do $$$AssertTrue(tWrites > 0, "there is at least one registered write tool to check")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedFields("web-application")), 2, "two web-application fields carry an always-prohibited predicate of their own")

    ; A real application, so "and mints nothing" is an observation: a tool that admitted the field
    ; would read this target through the shipped port and mint a row for the running account.
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertTrue(tBefore > -1, "the running account's proposal rows are counted")
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "/csp/sys", "DispatchClass": "Some.Other.Class"}, 200, .tResult, .tHttp, .tFault)
    ; Read before anything is asserted, so a call that was not refused is still counted rather
    ; than raising on the absent fault and leaving this unanswered.
    Set tAfter = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertStatusNotOK(tSC, "a call asking for a dispatch change is refused")
    Do $$$AssertEquals(tAfter, tBefore, "and no proposal was minted for this account")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
}

/// <p>AC3: every registered write tool's entity type has predicates here, so the next story's tool
/// cannot ship without adding them.</p>
/// <p>Mutations: register a write tool over an entity type the set does not evaluate, and make the
/// registry report every tool <code>read</code> -- the first reddens the emptiness, the second the
/// floor under it.</p>
Method TestNoRegisteredWriteToolHasAnUncoveredEntityType()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).UncoveredWriteTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry is read")
    Do $$$AssertEquals($ListLength(tTools), 0, "no registered write tool has an entity type the set does not evaluate: " _ $ListToString(tTools))

    ; An empty answer means "every write tool is covered" only if there were write tools to read.
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tAll)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Set tWrites = 0
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) && (tEntry.%Get("kind") = "write") Set tWrites = tWrites + 1
    }
    Do $$$AssertTrue(tWrites > 0, "and there was at least one registered write tool to inspect")
}

/// <p>AC5, AD-10: the verdict is reached before the restraint verdict and turns on no governance
/// state -- the Release 1 gate allows the tool and the write is refused anyway.</p>
/// <p>Mutation: remove the prohibited call from
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- this goes red.</p>
Method TestGovernanceCannotEnableAProhibitedWrite()
{
    Set tSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide(..#TOOL, "write", $Username, {}, .tDecision)
    Do $$$AssertStatusOK(tSC, "the governance gate answers")
    Do $$$AssertEquals($Get(tDecision("allowed")), 1, "and allows this tool")

    Do ..Refused(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "", "Probe.Dispatch", "", 1, "after"), "Resource", $Parameter(..#SHIPPEDSET, "AUTHORIZATION"))

    Set tSource = ""
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, ..#SHIPPEDSET, .tSource)
    Do $$$AssertStatusOK(tSC, "the set's source reads back")
    Do $$$AssertEquals(tSource [ "OcuPilot.Kernel.Governance", 0, "the set names no governance class")
    Do $$$AssertEquals(tSource [ "OcuPilot.Screen.Descriptor", 0, "no screen descriptor")
    Do $$$AssertEquals(tSource [ "OcuPilot.Area.", 0, "and no slice")

    Set tConfirm = ""
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Kernel.Proposal.Confirm", .tConfirm)
    Do $$$AssertStatusOK(tSC, "the confirm's source reads back")
    Set tBody = $Piece($Piece(tConfirm, "ClassMethod Transition", 2), "ClassMethod ChannelProblem", 1)
    ; $Find answers 0 for a needle that is absent, so both offsets are read before they are
    ; compared: a transition that asks neither must not read as "in the right order".
    Set tAsked = $Find(tBody, "..ProhibitedClassName()")
    Set tRestrained = $Find(tBody, "OcuPilot.Kernel.Restraint")
    Do $$$AssertTrue(tAsked > 0, "the transition asks the prohibited seam")
    Do $$$AssertTrue(tRestrained > 0, "and reaches the restraint verdict")
    Do $$$AssertTrue(tAsked < tRestrained, "with the set asked first")
}

/// <p>AC2 and AC6: the set is the only class that spells a <code>PROHIBITED.</code> code or writes
/// one of its sentences, every code is well formed, and the resolver the confirm handler asks
/// first answers each of them.</p>
/// <p>Mutation: remove one code's sentence from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>, or copy a code into another
/// class -- this goes red.</p>
Method TestTheSetHasOneHomeAndOneSentencePerCode()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).PortClass(), "OcuPilot.Port.AdminPort", "the shipped set reads its target through the shipped port")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RegistryClass(), "OcuPilot.Screen.Tool.Registry", "and resolves the tool through the shipped registry")

    Set tCodes = ##class(OcuPilot.Kernel.Proposal.Prohibited).Codes()
    Do $$$AssertEquals($ListLength(tCodes), 10, "the set declares ten codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), tCode _ " matches the machine-code pattern")
        Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a written sentence")
        ; The resolver OcuPilot.Api.Confirm asks first, so this is the sentence the handler renders.
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tCode), tReason, "which the proposal resolver delegates here for")
    }

    Set tSC = ..Sources(.tSources)
    Do $$$AssertStatusOK(tSC, "every OcuPilot class's source reads back: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Set tOffenders = ""
    Set tName = ""
    For {
        Set tName = $Order(tSources(tName))
        If tName = "" Quit
        If tName = ..#SHIPPEDSET Continue
        If $Extract(tName, 1, 14) = "OcuPilot.Test." Continue
        Set tText = tSources(tName)
        For tP = 2:1:$Length(tText, "PROHIBITED.") {
            If $Extract($Piece(tText, "PROHIBITED.", tP), 1)?1U Set tOffenders = tOffenders _ $ListBuild(tName)
        }
    }
    Do $$$AssertEquals($ListLength(tOffenders), 0, "no class outside the set and the tests spells a PROHIBITED. code: " _ $ListToString(tOffenders))

    For tI = 1:1:$ListLength(tCodes) {
        Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($List(tCodes, tI))
        Set tSeen = 0
        Set tName = ""
        For {
            Set tName = $Order(tSources(tName))
            If tName = "" Quit
            Set tSeen = tSeen + ($Length(tSources(tName), tReason) - 1)
        }
        Do $$$AssertEquals(tSeen, 1, "the sentence for " _ $List(tCodes, tI) _ " is written exactly once in the tree")
    }
}

/// <p>The UDL source of every <package>OcuPilot</package> class, as
/// <var>pSources(&lt;class name&gt;)</var>.</p>
/// <p><b>A class whose text could not be read is an error, never a class with no match</b>: a
/// failed lookup scored as a negative result is how a search of this shape undercounts. A sweep
/// that read implausibly few classes is an error for the same reason.</p>
Method Sources(Output pSources) As %Status
{
    Kill pSources
    Set tSC = $$$OK
    Try {
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ? ORDER BY Name")
        If $$$ISERR(tSC) Quit
        Set tRS = tStatement.%Execute("OcuPilot.")
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the class list could not be read: SQLCODE=" _ tRS.%SQLCODE)
            Quit
        }
        Set tCount = 0
        While tRS.%Next() {
            Set tName = tRS.%Get("Name")
            Set tText = ""
            Set tTextSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, tName, .tText)
            If $$$ISERR(tTextSC) {
                Set tSC = $$$ERROR($$$GeneralError, "the source of " _ tName _ " could not be read: " _ $System.Status.GetErrorText(tTextSC))
                Quit
            }
            Set pSources(tName) = tText
            Set tCount = tCount + 1
        }
        If $$$ISERR(tSC) Quit
        If tCount < 100 Set tSC = $$$ERROR($$$GeneralError, "only " _ tCount _ " OcuPilot classes were read, which is not this tree")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pSources
    Quit tSC
}

}
