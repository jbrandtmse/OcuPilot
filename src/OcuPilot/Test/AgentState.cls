/// <p>AC4, AC5 and AC7 -- the agent definition's own invariants, driven against the state class on
/// a live instance: exactly one default marker, enforced by the unique index rather than by
/// convention; DW-20's promotion rules on every path that can leave the marker stranded; the
/// security-change disable; and a credential reference that names nothing still reading back.</p>
/// <p>Every method starts from an instance holding <b>no</b> definitions, which
/// <method>OnBeforeOneTest</method> establishes and each method asserts rather than assumes -- the
/// promotion rules are about creation order, so a definition left behind by something else would
/// make the results mean something different.</p>
Class OcuPilot.Test.AgentState Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>Whether <method>OnBeforeOneTest</method> found the instance holding no agent definitions at
/// all once the probe rows were cleared. Prefix deliberately does not begin with "Test" -- see
/// <file>.claude/rules/objectscript-testing.md</file>.</p>
Property PreparedInstanceEmpty As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedInstanceEmpty = 0
    Quit $$$OK
}

/// <p>Clear any probe definition a previous method left, then record whether the instance holds
/// no definitions at all.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedList(.tIds)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedInstanceEmpty = (tRemaining = 0) && (+$Get(tIds) = 0)
    Quit $$$OK
}

/// <p>Remove every definition this class created and assert none survives.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>The marker on definition <var>pId</var>, read from the stored row.</p>
ClassMethod MarkOf(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit "unreadable"
    Quit tRow.DefaultMark
}

/// <p>Create one probe definition and return its id, asserting the create succeeded.</p>
Method MakeDefinition(pSuffix As %String, pEnabled As %Boolean, pVerified As %Boolean) As %String
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ pSuffix, pEnabled, pVerified, .tRow)
    Do $$$AssertStatusOK(tSC, "definition " _ pSuffix _ " is created")
    If $$$ISERR(tSC) Quit ""
    Quit tRow.%Id()
}

/// <p>AC4 -- the first definition on an instance takes the marker without a separate act, and a
/// second one does not take it from it.</p>
Method TestTheFirstDefinitionTakesTheMarkerAndASecondDoesNot()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Do $$$AssertEquals(..MarkOf(tA), "1", "the first definition takes the default marker")
    Set tB = ..MakeDefinition("B", 1, 1)
    Do $$$AssertEquals(..MarkOf(tB), "", "the second does not take it")
    Do $$$AssertEquals(..MarkOf(tA), "1", "and the first still carries it")

    Set tSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tResolved)
    Do $$$AssertStatusOK(tSC, "the default resolves")
    Do $$$AssertEquals(tResolved, tA, "to the marked, enabled definition")
}

/// <p>AC4 -- a second marker is refused by the <b>storage layer</b>, not by a convention every
/// future caller has to remember. The save that sets it comes back
/// <code>ERROR #5808: Key not unique</code> on <code>DefaultIdx</code>.</p>
/// <p>Mutation: drop <code>[ Unique ]</code> from <code>Index DefaultIdx</code> in
/// <class>OcuPilot.Kernel.State.Agent</class> -- this goes red, because the save it expects to
/// fail succeeds.</p>
Method TestASecondMarkerIsRefusedByTheUniqueIndex()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tB = ..MakeDefinition("B", 1, 1)
    Do $$$AssertEquals(..MarkOf(tA), "1", "the first definition carries the marker")

    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tB, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the second definition opens")
    Set tRow.DefaultMark = "1"
    Set tSaveSC = ##class(OcuPilot.Kernel.State.Agent).GuardedSave(tRow)
    Set tRow = ""
    Do $$$AssertStatusNotOK(tSaveSC, "a second definition carrying the marker is refused")
    Do $$$AssertTrue($System.Status.GetErrorText(tSaveSC) [ "5808", "by the unique index, as #5808: " _ $System.Status.GetErrorText(tSaveSC))
    Do $$$AssertEquals(..MarkOf(tB), "", "and the second definition still carries no marker")

    ; Repeated empty markers are accepted, which is what makes "" usable as "not the default":
    ; a unique index that refused them could hold only one definition in total.
    Set tC = ..MakeDefinition("C", 0, 0)
    Do $$$AssertEquals(..MarkOf(tC), "", "a third unmarked definition saves alongside the second")
}

/// <p>The name index collates the way IRIS SQL compares strings, which is case-insensitively, so
/// a name differing from a stored one only in case is the duplicate <code>NameIdx</code> refuses.
/// That is what lets the duplicate rule answer first, with a field the caller can act on, rather
/// than leaving the save to fail with <code>#5808</code>
/// (<method>OcuPilot.Kernel.State.Agent.GuardedByName</method>).</p>
/// <p>Mutation: drop <code>[ Unique ]</code> from <code>Index NameIdx</code> -- this goes red,
/// because the save it expects to fail succeeds.</p>
Method TestANameDifferingOnlyInCaseIsRefusedByTheNameIndex()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tName = ..#PROBEPREFIX _ "Case"
    Do $$$AssertNotEquals(..MakeDefinition("Case", 0, 0), "", "a definition to collide with is created")

    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition($ZConvert(tName, "U"), 0, 0, .tRow)
    Set tRow = ""
    Do $$$AssertStatusNotOK(tSC, "the same name in another case is refused")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "5808", "by the unique index, as #5808: " _ $System.Status.GetErrorText(tSC))
}

/// <p>AC4 -- moving the marker clears the old one <b>before</b> setting the new one, inside one
/// transaction. Setting before clearing collides with <code>DefaultIdx</code> and raises
/// <code>#5808</code> on a legitimate request, so a success here is the order.</p>
Method TestSetDefaultClearsTheOldMarkerBeforeSettingTheNew()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tB = ..MakeDefinition("B", 1, 1)

    Set tSC = ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(tB)
    Do $$$AssertStatusOK(tSC, "the marker moves to the second definition: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(..MarkOf(tA), "", "the old marker is cleared")
    Do $$$AssertEquals(..MarkOf(tB), "1", "and the new one is set")

    ; Moving it to the definition that already holds it is a no-op, not a self-collision.
    Set tAgain = ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(tB)
    Do $$$AssertStatusOK(tAgain, "setting the default to the definition that already holds it succeeds")
    Do $$$AssertEquals(..MarkOf(tB), "1", "and leaves it marked")
}

/// <p>AC4 / DW-20 -- deleting the marked definition moves the marker to the lowest-id
/// <b>enabled</b> definition.</p>
Method TestDeletingTheDefaultPromotesTheLowestIdEnabledPeer()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tB = ..MakeDefinition("B", 1, 1)
    Set tC = ..MakeDefinition("C", 1, 1)
    Do $$$AssertEquals(..MarkOf(tA), "1", "the first definition carries the marker")

    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tA)
    Do $$$AssertStatusOK(tSC, "the marked definition is deleted")
    Do $$$AssertEquals(..MarkOf(tB), "1", "the marker moves to the lowest-id enabled peer")
    Do $$$AssertEquals(..MarkOf(tC), "", "and not to the later one")
}

/// <p>AC4 / DW-20 -- when no peer is enabled, deleting the marked definition still leaves exactly
/// one marked: the lowest-id remaining definition takes it, so "exactly one is marked while any
/// exists" holds.</p>
Method TestDeletingTheDefaultWithNoEnabledPeerPromotesTheLowestIdRemaining()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tB = ..MakeDefinition("B", 0, 0)
    Set tC = ..MakeDefinition("C", 0, 0)
    Do $$$AssertEquals(..MarkOf(tA), "1", "the first definition carries the marker")

    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tA)
    Do $$$AssertStatusOK(tSC, "the marked definition is deleted")
    Do $$$AssertEquals(..MarkOf(tB), "1", "the marker falls back to the lowest-id remaining definition")
    Do $$$AssertEquals(..MarkOf(tC), "", "and not to the later one")

    Set tResolveSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tResolved)
    Do $$$AssertStatusOK(tResolveSC, "the default resolves without failing")
    Do $$$AssertEquals(tResolved, "", "to the empty configuration-empty answer, because the marked definition is disabled")
}

/// <p>AC4 -- deleting the last definition leaves no marker at all. "Exactly one is marked" holds
/// only while one exists; an instance with no definitions is not a broken invariant.</p>
Method TestDeletingTheLastDefinitionLeavesNoMarker()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tA)
    Do $$$AssertStatusOK(tSC, "the only definition is deleted")

    Set tListSC = ##class(OcuPilot.Kernel.State.Agent).GuardedList(.tIds)
    Do $$$AssertStatusOK(tListSC, "the list reads")
    Do $$$AssertEquals(+$Get(tIds), 0, "and holds nothing")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tResolved), "the default resolves without failing")
    Do $$$AssertEquals(tResolved, "", "to nothing")
}

/// <p>AC4 / DW-20 -- disabling the marked definition moves the marker to the lowest-id enabled
/// peer; with no enabled peer it stays where it is and the default resolves to <code>""</code>,
/// which is the configuration-empty state rather than a failure.</p>
Method TestDisablingTheDefaultPromotesAnEnabledPeerOrLeavesTheMarker()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)
    Set tB = ..MakeDefinition("B", 1, 1)
    Do ..Disable(tA)
    Do $$$AssertEquals(..MarkOf(tA), "", "disabling the marked definition clears its marker")
    Do $$$AssertEquals(..MarkOf(tB), "1", "and the enabled peer takes it")

    Do ..Disable(tB)
    Do $$$AssertEquals(..MarkOf(tB), "1", "with no enabled peer the marker stays where it is")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tResolved), "the default resolves without failing")
    Do $$$AssertEquals(tResolved, "", "and answers the empty configuration-empty state")
}

/// <p>Disable definition <var>pId</var> through the production update path.</p>
Method Disable(pId As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    Do $$$AssertStatusOK(tSC, "the definition to disable opens")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.Enabled = 0
    Set tUpdateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Do $$$AssertStatusOK(tUpdateSC, "the definition is disabled")
}

/// <p>AC5 -- a save that changes any of the five security-relevant fields clears both
/// <property>ConnectionVerified</property> and <property>Enabled</property>; a save that changes
/// only the model leaves both alone.</p>
/// <p>All five are exercised one at a time, so a field quietly dropped from
/// <method>OcuPilot.Kernel.State.Agent.SecurityFields</method> is caught rather than covered by
/// its neighbours.</p>
/// <p>Mutation: remove <code>EndpointUrl</code> from that list -- the endpoint leg goes red, the
/// definition staying enabled and verified.</p>
Method TestASecurityChangeDisablesAndAModelChangeDoesNot()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tA = ..MakeDefinition("A", 1, 1)

    Do ..ApplyChange(tA, "Model", "claude-sonnet-5")
    Do $$$AssertEquals(..FlagsOf(tA), "1|1", "a model change leaves the definition enabled and verified")

    Do ..ApplyChange(tA, "EndpointUrl", "https://other.example.com/v1")
    Do $$$AssertEquals(..FlagsOf(tA), "0|0", "an endpoint change disables it and clears its verification")

    Do ..ReEnable(tA)
    Do ..ApplyChange(tA, "Provider", "anthropic-probe")
    Do $$$AssertEquals(..FlagsOf(tA), "0|0", "a provider change does too")

    Do ..ReEnable(tA)
    Do ..ApplyChange(tA, "CredType", "creds")
    Do $$$AssertEquals(..FlagsOf(tA), "0|0", "a credential-type change does too")

    Do ..ReEnable(tA)
    Do ..ApplyChange(tA, "CredentialName", "OcuPilotAnthropic")
    Do $$$AssertEquals(..FlagsOf(tA), "0|0", "a credential-name change does too")

    Do ..ReEnable(tA)
    Do ..ApplyChange(tA, "EnvVarName", "OTHER_KEY_NAME")
    Do $$$AssertEquals(..FlagsOf(tA), "0|0", "and an environment-variable change does too")
}

/// <p><code>Enabled|ConnectionVerified</code> for definition <var>pId</var>, read from the stored
/// row.</p>
ClassMethod FlagsOf(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit "unreadable"
    Quit tRow.Enabled _ "|" _ tRow.ConnectionVerified
}

/// <p>Change one property of definition <var>pId</var> through the production update path, the
/// security snapshot taken before the change as the caller contract requires.</p>
Method ApplyChange(pId As %String, pProperty As %String, pValue As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    Do $$$AssertStatusOK(tSC, "the definition to change opens")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set $Property(tRow, pProperty) = pValue
    Set tUpdateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Do $$$AssertStatusOK(tUpdateSC, "the change to " _ pProperty _ " saves")
}

/// <p>Put definition <var>pId</var> back to enabled and verified, so the next leg starts from the
/// state the disable rule is about.</p>
Method ReEnable(pId As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    Do $$$AssertStatusOK(tSC, "the definition to re-enable opens")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.ConnectionVerified = 1
    Set tRow.Enabled = 1
    Set tUpdateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Do $$$AssertStatusOK(tUpdateSC, "the definition is enabled and verified again")
    Do $$$AssertEquals(..FlagsOf(pId), "1|1", "and reads back that way, so the next leg starts from the state the rule is about")
}

/// <p>AC7 (AD-37) -- a stored credential reference is <b>weak</b>: a name that resolves to nothing
/// on this instance reads back verbatim through both the list and the single read, and neither
/// fails. Resolution is Story 3.3's ladder and the "no longer present" rendering is Story
/// 3.5's.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.State.Agent.GuardedList</method> fail the read when a
/// credential reference does not resolve -- this goes red.</p>
Method TestACredentialReferenceThatNamesNothingStillReadsBack()
{
    Do $$$AssertTrue(..PreparedInstanceEmpty, "the instance holds no agent definitions before this method")
    Set tAbsent = "OcuPilotNoSuchCredentialZZZTMPPROBE"
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ "Weak"
    Set tRow.Provider = "anthropic"
    Set tRow.Model = "claude-opus-5"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "creds"
    Set tRow.CredentialName = tAbsent
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, "a definition whose credential reference names nothing is saved")
    Set tId = tRow.%Id()
    Set tRow = ""

    ; The reference really is unresolvable, checked rather than assumed -- but only where the
    ; credential store exists at all, since the rung that reads it needs an interoperability-enabled
    ; namespace (Story 3.3) and this claim must not turn into a class-does-not-exist failure.
    If ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Config.Credentials") {
        Do $$$AssertTrue('$ClassMethod("Ens.Config.Credentials", "%ExistsId", tAbsent), "the instance genuinely holds no credential by that name")
    }

    Set tListSC = ##class(OcuPilot.Kernel.State.Agent).GuardedList(.tIds)
    Do $$$AssertStatusOK(tListSC, "the list reads without failing")
    Do $$$AssertEquals(+$Get(tIds), 1, "and returns the definition")

    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tReopened)
    Do $$$AssertStatusOK(tOpenSC, "the single read succeeds too")
    Do $$$AssertEquals(tReopened.CredentialName, tAbsent, "and the reference comes back verbatim, never resolved and never blanked")
}

}
