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

/// <p>OcuPilot's own API path from the install roster, which the set treats as serving OcuPilot
/// with no install record. The port is the fixture, so nothing is written to it.</p>
Parameter OWNPATH = "/api/ocupilot";

/// <p>The target every predicate is driven against, at <parameter>OWNPATH</parameter>.</p>
Method OwnTarget() As %String
{
    Quit ##class(OcuPilot.Test.ProhibitedFixture).App(..#OWNPATH, 32, "%Development", "Probe.Dispatch", "", 1)
}

/// <p>A payload weakening one field is permitted on an application that is not OcuPilot's own
/// (AD-10 as amended 2026-09-24) and refused with <var>pExpected</var> on OcuPilot's own.
/// <var>pAuthe</var>, <var>pResource</var> and <var>pDispatch</var> are the payload's values.</p>
Method Weakening(pAuthe As %Integer, pResource As %String, pDispatch As %String, pField As %String, pExpected As %String)
{
    Set tSC = ..Ask(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, pAuthe, pResource, pDispatch, "", 1, "after"), pField, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the change on another application")
    Do $$$AssertEquals(tProhibits, 0, pField _ ": permitted on an application that is not OcuPilot's own, code was '" _ tCode _ "'")
    Do ..Refused(..OwnTarget(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#OWNPATH, pAuthe, pResource, pDispatch, "", 1, "after"), pField, pExpected, ..#OWNPATH)
}

/// <p>Adding the unauthenticated bit: permitted elsewhere, <code>UNAUTHENTICATED</code> on
/// OcuPilot's own.</p>
/// <p>Mutation: delete the unauthenticated arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- the own leg answers
/// <code>SERVINGPATH</code> and goes red.</p>
Method TestAWeakenedAuthenticationIsRefusedOnlyOnOcuPilotsOwn()
{
    Do ..Weakening(96, "%Development", "Probe.Dispatch", "AutheEnabled", $Parameter(..#SHIPPEDSET, "UNAUTHENTICATED"))
}

/// <p>Clearing a resource the target holds: permitted elsewhere, <code>AUTHORIZATION</code> on
/// OcuPilot's own.</p>
Method TestADroppedAuthorizationResourceIsRefusedOnlyOnOcuPilotsOwn()
{
    Do ..Weakening(32, "", "Probe.Dispatch", "Resource", $Parameter(..#SHIPPEDSET, "AUTHORIZATION"))
}

/// <p>Naming a different dispatch class: permitted elsewhere, <code>DISPATCH</code> on OcuPilot's
/// own.</p>
Method TestARepointedDispatchClassIsRefusedOnlyOnOcuPilotsOwn()
{
    Do ..Weakening(32, "%Development", "Probe.Other", "DispatchClass", $Parameter(..#SHIPPEDSET, "DISPATCH"))
}

/// <p>Matrix row 4, AD-10: a payload changing an application's roles is refused
/// <code>PRIVILEGEGRANT</code> on one of OcuPilot's own applications, ahead of the serving-path
/// refusal every other change to one earns, and permitted on any other application.</p>
/// <p>Mutation: drop the application-roles leg from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- the own-application half
/// goes red, answered <code>SERVINGPATH</code> instead.</p>
Method TestAChangedRoleGrantIsRefusedOnOcuPilotsOwnApplication()
{
    Set tServing = ..#OWNPATH
    Set tSC = ..Ask(##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "%Development", "Probe.Dispatch", "", 1), ##class(OcuPilot.Test.ProhibitedFixture).App(tServing, 32, "%Development", "Probe.Dispatch", ":%All", 1), "MatchRoles", .tProhibits, .tCode, tServing)
    Do $$$AssertStatusOK(tSC, "the set answers a role change on OcuPilot's own application")
    Do $$$AssertEquals(tProhibits, 1, "which is prohibited")
    Do $$$AssertEquals(tCode, $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT"), "as a privilege grant on OcuPilot's own application")
    Set tSC = ..Ask(..Target(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#TARGET, 32, "%Development", "Probe.Dispatch", ":%All", 1, "after"), "MatchRoles", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a role change on another application")
    Do $$$AssertEquals(tProhibits, 0, "which is permitted, code was '" _ tCode _ "'")
}

/// <p>Matrix row 6: an entity type the set evaluates no predicates for is refused wholesale, and so
/// is a reference that cannot be parsed at all. A type whose predicates have landed leaves this
/// list in the story that lands them -- <code>user</code> in Story 5.9
/// (<class>OcuPilot.Test.UserUpdate</class>), <code>task</code> in Story 5.11
/// (<class>OcuPilot.Test.TaskResume</class>), <code>process</code> in Story 5.12
/// (<class>OcuPilot.Test.ProcessControl</class>), <code>application-error</code> in Story 5.13
/// (<class>OcuPilot.Test.ErrorDelete</class>), <code>resource</code> in Story 8.4
/// (<class>OcuPilot.Test.ResourceDelete</class>), <code>service</code> in Story 9.9
/// (<class>OcuPilot.Test.ServiceUpdate</class>).</p>
/// <p>Mutation: answer <code>pProhibits = 0</code> in the uncovered arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- this goes red.</p>
Method TestAnUncoveredEntityTypeIsRefusedWholesale()
{
    Set tUncovered = $ListBuild("lock", "database")
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
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes()), "web-application,user,auditing-configuration,task,process,application-error,role,resource,x509-credential,wallet-secret,device,oauth2-client-configuration,oauth2-server-client,audit-event,audit-user-event,ssl-configuration,service,ldap-configuration", "Release 1 covers exactly eighteen entity types -- the service and the LDAP configuration since Story 9.9, the SSL/TLS configuration since Story 9.5, the two audit event types since Story 7.11 and the create and import types since Epic 8")

    ; The refusal reaches a caller as a 403 with the set's own code, not as an error.
    Set tKey = ..Seed(..Payload(), "Description", "probe-id", "lock")
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

/// <p>AC3 and AC4's first half: every field the set calls always-prohibited for a tool's entity type
/// is absent from that tool's advertised schema and settable list, nothing the tool does admit is
/// outside the set's reviewed few, and the model asking for an unadvertised field -- a web
/// application's <code>Path</code> -- is refused before any proposal exists.</p>
/// <p>No entity type declares an always-prohibited field since AD-10's 2026-09-24 amendment, so the
/// per-tool legs over that list run for no tool; the web-application emptiness is asserted below
/// rather than assumed, and the legs run again for the first type that declares one.</p>
/// <p>Mutations: add a field to
/// <parameter>OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS</parameter> that
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> does not name, add
/// one to <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> alone, declare
/// an unreviewed field such as <code>EventClass</code> a secret argument, or put a settable field in
/// the descriptor's <method>FingerprintExcludes</method> -- each goes red.</p>
Method TestNoWriteToolAdmitsAnAlwaysProhibitedField()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    If $$$ISERR(tSC) Quit
    Set tWrites = 0
    ; The types a body-sending tool of either kind writes, so an action-style tool on a type that
    ; also has one (a resource's delete beside its edit) is not held to an empty reviewed list.
    Kill tBodyTypes
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        If '$ClassMethod(tEntry.%Get("class"), "SendsBody") Continue
        Set tBodyDescriptor = $Parameter(tEntry.%Get("class"), "DESCRIPTORCLASS")
        If tBodyDescriptor '= "" Set tBodyTypes(''$ClassMethod(tEntry.%Get("class"), "Creates"), $ClassMethod(tBodyDescriptor, "PrimaryEntityType")) = ""
    }
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        Set tClass = tEntry.%Get("class")
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tType = ""
        If tDescriptor '= "" Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
        ; AD-54: "what may a change touch" and "what may a create set" are different questions,
        ; so a create tool is held to the create lists. Which pair applies is the tool's own
        ; declaration, never a name this test knows.
        Set tCreates = ''$ClassMethod(tClass, "Creates")
        Set tAlways = $Select(tCreates: ##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedCreateFields(tType), 1: ##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedFields(tType))
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
        ; AD-3: a wrapper secret one of the screen's tools authors -- Security.User's POST
        ; Password -- is no field of the endpoint's template, so no predicate reviews it and the
        ; reviewed-few floor below is asked about the declared secrets that are fields.
        Set tDeclaredSecrets = tSecrets
        Set tSecrets = ..WithoutAuthoredSecrets(tDescriptor, tSecrets)
        ; The other half of AD-10's title, and the one that covers a field nobody has named: a tool
        ; advertises nothing outside the set's reviewed few, so a vendor property added to the
        ; endpoint's template reaches no schema until the set has a predicate for it.
        Set tPermitted = $Select(tCreates: ##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields(tType), 1: ##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields(tType))
        ; An action-style write sends no body (AD-51), so it admits no field by construction and
        ; the floor under it is that emptiness. A body-sending write still has to admit something
        ; -- a merge tool that admitted nothing would pass the loops below having checked nothing.
        ;
        ; **The reviewed few belong to the entity type, not to the tool** (Story 7.1). Two writes
        ; over one type ship on this build -- a merge and an action -- so "the set reviews no field
        ; of this type" is no longer the same claim as "this tool admits none", and asserting the
        ; first of an action write would refuse the second write the type acquires. What is
        ; asserted of an action write is its own emptiness; the reviewed-few equality below is the
        ; body-sending tools' own.
        Set tSendsBody = ''$ClassMethod(tClass, "SendsBody")
        If 'tSendsBody {
            Do $$$AssertEquals($ListLength(tSettable), 0, tEntry.%Get("name") _ " sends no body, so it admits no field")
            For tI = 1:1:$ListLength(tPermitted) {
                Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf($List(tPermitted, tI)), "unassigned", tEntry.%Get("name") _ " advertises none of its type's reviewed few either, and not '" _ $List(tPermitted, tI) _ "'")
            }
        } Else {
            Do $$$AssertTrue($ListLength(tSettable) > 0, tEntry.%Get("name") _ " admits at least one field")
            For tI = 1:1:$ListLength(tSettable) {
                Set tField = $List(tSettable, tI)
                Do $$$AssertTrue($ListFind(tPermitted, tField) > 0, tEntry.%Get("name") _ " admits '" _ tField _ "', which the prohibited set has reviewed for " _ tType)
            }
            ; The converse, so the two lists are asserted equal rather than one-way: a name added to
            ; the set's reviewed few alone reddens here, and so does a PERMITTEDFIELDS spelling the
            ; tool's own $ListFromString does not trim, since the untrimmed name admits nothing.
            For tI = 1:1:$ListLength(tPermitted) {
                Set tField = $List(tPermitted, tI)
                Do $$$AssertTrue($ListFind(tSettable, tField) > 0, tEntry.%Get("name") _ " advertises '" _ tField _ "', which the prohibited set has reviewed for " _ tType)
            }
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
        ; An action-style write sends no merge body, so a supplied secret reaches the vendor only
        ; where its SECRETBODY names it, and each such name is a declared secret (AD-51, AD-56 (i)).
        If 'tSendsBody {
            Set tBodyNames = $ClassMethod(tClass, "SecretBodyNames")
            For tI = 1:1:$ListLength(tBodyNames) {
                Do $$$AssertTrue($ListFind(tDeclaredSecrets, $List(tBodyNames, tI)) > 0, tEntry.%Get("name") _ " sends '" _ $List(tBodyNames, tI) _ "' as its body, which the screen declares secret")
            }
            Set tSupplied = {}
            For tI = 1:1:$ListLength(tDeclaredSecrets) {
                Do tSupplied.%Set($List(tDeclaredSecrets, tI), "probe", "string")
            }
            Set tSent = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, tDeclaredSecrets)
            If tBodyNames = "" Do $$$AssertEquals(tSent, "", tEntry.%Get("name") _ " sends no body, so no declared secret reaches its write")
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
    ; AD-10 as amended 2026-09-24: every web-application refusal is a predicate over the target --
    ; OcuPilot's own applications -- so no web-application field is prohibited by name on either
    ; kind of write, and a change may repoint any other application.
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedFields("web-application")), "", "no web-application field is prohibited on a change by name")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).AlwaysProhibitedCreateFields("web-application"), "", "nor on a create")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("web-application"), "MatchRoles") > 0, "a create may set application roles")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("web-application"), "DispatchClass") > 0, "a change may set the dispatch class")
    Do $$$AssertEquals($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("web-application"), "Path"), 0, "and no change names a path (AD-21)")

    ; A real application, so "and mints nothing" is an observation: a tool that admitted the field
    ; would read this target through the shipped port and mint a row for the running account.
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertTrue(tBefore > -1, "the running account's proposal rows are counted")
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "/csp/sys", "Path": "/tmp/elsewhere/"}, 200, .tResult, .tHttp, .tFault)
    ; Read before anything is asserted, so a call that was not refused is still counted rather
    ; than raising on the absent fault and leaving this unanswered.
    Set tAfter = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertStatusNotOK(tSC, "a call asking for a path change is refused")
    Do $$$AssertEquals(tAfter, tBefore, "and no proposal was minted for this account")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
}

/// <p>Story 8.1, AD-54: the create predicates. A create's target is <b>correctly</b> absent, so the
/// absent-target early-out that answers "not prohibited" for every other kind does not apply to
/// one -- and the effects AD-10 names for a create are refused over the payload's own keys rather
/// than over a diff against a live target that is not there. Application roles are refused on
/// OcuPilot's own paths alone (AD-10), and permitted anywhere else.</p>
/// <p>Mutations: make
/// <method>OcuPilot.Kernel.Proposal.Prohibited.CreatesOf</method> answer 0 -> the refusal legs go
/// red, because the early-out then answers first. Make
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> answer
/// <code>SERVINGPATH</code> whatever an own-path create sets, and the own-path role leg goes red.
/// Add <code>EventClass</code> to
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> and the
/// unreviewed-field leg goes red.</p>
Method TestACreateIsRefusedAtOcuPilotsOwnPathForRolesAndForAnUnreviewedField()
{
    Set tCreateTool = "webapp.list.create"
    Set tPlain = ..CreatePayload("")
    Set tExpectedServing = $Parameter(..#SHIPPEDSET, "SERVINGPATH")
    Set tExpectedGrant = $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT")
    Set tExpectedField = $Parameter(..#SHIPPEDSET, "UNCOVEREDFIELD")

    ; A create at a path nobody holds and that is not OcuPilot's own: permitted, which is the
    ; floor under the three refusals below.
    Set tSC = ..AskCreate(tPlain, ..#TARGET, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create at an ordinary path")
    Do $$$AssertEquals(tProhibits, 0, "which is not prohibited")
    Do $$$AssertEquals(tCode, "", "and carries no code")

    ; AD-10, AD-38: creating a second application at the address that serves OcuPilot is the same
    ; harm as changing the first, and the same predicate refuses it.
    Set tSC = ..AskCreate(tPlain, "/api/ocupilot", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create at OcuPilot's own path")
    Do $$$AssertEquals(tProhibits, 1, "which is prohibited")
    Do $$$AssertEquals(tCode, tExpectedServing, "on the serving-path predicate")

    ; A path beneath OcuPilot's own would answer the requests OcuPilot serves there.
    Set tSC = ..AskCreate(tPlain, "/api/ocupilot/agent", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create beneath OcuPilot's own path")
    Do $$$AssertEquals(tProhibits, 1, "which is prohibited")
    Do $$$AssertEquals(tCode, tExpectedServing, "on the serving-path predicate as well")

    ; AD-10: application roles on one of OcuPilot's own applications would run every OcuPilot
    ; request with them, so a create beneath OcuPilot's own path that sets them is refused on its
    ; own code rather than the serving-path one; anywhere else they are a create's to set.
    Set tSC = ..AskCreate(..CreatePayload("MatchRoles"), "/api/ocupilot/agent", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create at OcuPilot's own path carrying application roles")
    Do $$$AssertEquals(tProhibits, 1, "which is prohibited")
    Do $$$AssertEquals(tCode, tExpectedGrant, "as a privilege grant on OcuPilot's own application")
    Set tSC = ..AskCreate(..CreatePayload("MatchRoles"), ..#TARGET, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create carrying application roles elsewhere")
    Do $$$AssertEquals(tProhibits, 0, "which is not prohibited")
    Do $$$AssertEquals(tCode, "", "and carries no code")

    ; The reviewed-few rule, over the create list rather than the change list.
    Set tSC = ..AskCreate(..CreatePayload("EventClass"), ..#TARGET, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create carrying an unreviewed field")
    Do $$$AssertEquals(tProhibits, 1, "which is prohibited")
    Do $$$AssertEquals(tCode, tExpectedField, "as a field this release has not reviewed for a create")

    ; And a field the create list DOES name is permitted although the change list does not name it,
    ; which is AD-54's one asymmetry driven through the set rather than read off the two lists.
    Set tSC = ..AskCreate(..CreatePayload("DispatchClass"), ..#TARGET, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a create naming a dispatch class")
    Do $$$AssertEquals(tProhibits, 0, "which is not prohibited, because a create repoints nothing")
    Do $$$AssertEquals(tCode, "", "and carries no code")
}

/// <p>A composed create payload: the namespace and the authentication mask every create carries,
/// plus <var>pExtra</var> (comma-separated) set to a probe value.</p>
/// <p>It is shaped the way <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> shapes one --
/// the caller's own arguments and nothing else -- because that is what the create predicates
/// sweep.</p>
Method CreatePayload(pExtra As %String) As %String
{
    Set tObject = {}
    Do tObject.%Set("NameSpace", $Namespace, "string")
    Do tObject.%Set("AutheEnabled", 32, "number")
    For tI = 1:1:$Length(pExtra, ",") {
        Set tField = $Piece(pExtra, ",", tI)
        If tField '= "" Do tObject.%Set(tField, "probe", "string")
    }
    Quit tObject.%ToJSON()
}

/// <p>Ask the set about a create of <var>pPath</var> carrying <var>pPayload</var>, with the port
/// answering 404 for that name -- which is a create's own precondition.</p>
/// <p>The diff is <method>OcuPilot.Kernel.Proposal.Mint.Compose</method>'s: one row per supplied
/// field. The set reads the payload rather than the diff for a create, and the diff is passed
/// anyway so the call is the one the confirm makes.</p>
Method AskCreate(pPayload As %String, pPath As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmReadFault(404)
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pPayload)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tArgs, "Name", $ClassMethod("OcuPilot.Screen.Tool.WebAppCreate", "SettableFields"), .tComposed, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped compose runs over the create's arguments")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#SET, "Prohibits", "webapp.list.create", ##class(OcuPilot.Test.ProhibitedFixture).Reference(pPath), pPayload, tDiff.%ToJSON(), .pProhibits, .pCode)
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

    Do ..Refused(..OwnTarget(), ##class(OcuPilot.Test.ProhibitedFixture).App(..#OWNPATH, 32, "", "Probe.Dispatch", "", 1, "after"), "Resource", $Parameter(..#SHIPPEDSET, "AUTHORIZATION"), ..#OWNPATH)

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

/// <p>Story 9.3 (AD-10, DW-1598): a role change may touch exactly its description, its escalation
/// flag, its granted roles and its resource grants; any other changed field is refused
/// <code>PROHIBITED.UNCOVEREDFIELD</code> with the caller-neutral sentence, and a description change
/// on a role that is not OcuPilot's own passes the set.</p>
/// <p>Mutation (Rule 19): drop <code>EscalationOnly</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>'s role list -- the list
/// leg and the flag leg go red.</p>
Method TestARoleChangeTouchesItsReviewedFourAndNothingElse()
{
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("role")), "Description,EscalationOnly,GrantedRoles,Resources", "a role change may touch its reviewed four")
    Set tFresh = "{""Description"":""before"",""GrantedRoles"":[],""EscalationOnly"":false,""Resources"":[]}"
    Set tSC = ##class(OcuPilot.Test.ProhibitedFixture).Ask(tFresh, "{""Description"":""after"",""GrantedRoles"":[],""EscalationOnly"":true,""Resources"":[]}", ##class(OcuPilot.Test.ProhibitedFixture).Diff("Description,EscalationOnly"), "OcuPilotProbeRoleSet", "role", .tProhibits, .tCode, "permissions.roles.update")
    Do $$$AssertStatusOK(tSC, "the set answers a reviewed change")
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "the description and the flag of a role not OcuPilot's own may change")
    Set tSC = ##class(OcuPilot.Test.ProhibitedFixture).Ask(tFresh, "{""Description"":""before"",""GrantedRoles"":[],""EscalationOnly"":false,""Resources"":[],""Foo"":""x""}", ##class(OcuPilot.Test.ProhibitedFixture).Diff("Foo"), "OcuPilotProbeRoleSet", "role", .tProhibits, .tCode, "permissions.roles.update")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD, "an unreviewed field is refused")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELDREASON, "with the caller-neutral sentence")
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
    Do $$$AssertEquals($ListLength(tCodes), 18, "the set declares eighteen codes")
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

/// <p><var>pSecrets</var> minus every name a write tool of descriptor <var>pDescriptor</var>'s
/// screen authors as a <code>secret</code> wrapper field in
/// <class>OcuPilot.Screen.Tool.ToolFields</class> (a row marked <code>authored</code>): a name the
/// endpoint's template does not carry, which the confirm merges into the body and the vendor reads
/// only as its wrapper's outer key.</p>
ClassMethod WithoutAuthoredSecrets(pDescriptor As %String, pSecrets As %List) As %List
{
    Set tIdentifier = ""
    If pDescriptor '= "" Set tIdentifier = $ClassMethod(pDescriptor, "ToolIdentifier")
    If tIdentifier = "" Quit pSecrets
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    If '$IsObject(tXData) Quit pSecrets
    Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    Kill tAuthored
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tName, .tEntry) {
        If $Piece(tName, ".", 1, 2) '= tIdentifier Continue
        Set tFields = tEntry.%Get("fields").%GetIterator()
        While tFields.%GetNext(.tIndex, .tField) {
            If (tField.%Get("authored") = 1) && (tField.%Get("class") = "secret") Set tAuthored(tField.%Get("path")) = ""
        }
    }
    Set tOut = ""
    For tI = 1:1:$ListLength(pSecrets) {
        If $Data(tAuthored($List(pSecrets, tI))) Continue
        Set tOut = tOut _ $ListBuild($List(pSecrets, tI))
    }
    Quit tOut
}

}
