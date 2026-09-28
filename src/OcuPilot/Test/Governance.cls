/// <p>Pins the governance policy's kernel (AD-22, AD-40, AD-10, Story 14.2): the cascade and its
/// three layers, the no-cache read, the <code>tool:action</code> key, the shipped dispatcher refusing
/// a disabled key with the tool still advertised and its ledger row written, a confirm refused when
/// the key was disabled after the mint while the draft still closes the row, and a prohibited
/// effect keeping its own refusal under the <code>full</code> preset.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%All</code>, and a throwaway armed with <code>OCUPILOT_ALLOW_PRINCIPALS</code> for the web
/// application <class>OcuPilot.Test.ProposalFixture</class> creates and removes. Every test starts
/// from no stored policy and puts the policy it found back afterwards, asserting the restore.</p>
Class OcuPilot.Test.Governance Extends %UnitTest.TestCase
{

Parameter TOOL = "webapp.list.update";

Parameter CREATE = "webapp.list.create";

Parameter PURGE = "security.auditing.purge";

Parameter ACTIONTOOL = "OcuPilot.Test.GovernanceActionTool";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The target the fixture port answers for; nothing on the instance carries it.</p>
Parameter FIXTURETARGET = "/csp/ocupilotprobegovernance";

Parameter FIXTUREFRESH = "{""Name"":""/csp/ocupilotprobegovernance"",""Description"":""before"",""Enabled"":true}";

/// <p>OcuPilot's own API, which the prohibited leg proposes to repoint.</p>
Parameter OWNAPP = "/api/ocupilot";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.GovernanceFixture).FailGate(0)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and reads back as it was")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p><var>pKey</var> resolved for <var>pKind</var>, as <code>&lt;enabled&gt;|&lt;source&gt;</code>.</p>
ClassMethod Resolved(pKey As %String, pKind As %String = "write") As %String
{
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(pKey, pKind, .tEnabled, .tSource)
    If $$$ISERR(tSC) Quit "error"
    Quit ''tEnabled _ "|" _ tSource
}

/// <p>Store <var>pPreset</var> with one setting, <var>pKey</var> = <var>pSetting</var>
/// (<code>""</code> for none).</p>
Method Store(pPreset As %String, pKey As %String = "", pSetting As %String = "")
{
    Kill tSettings
    If pKey '= "" Set tSettings(pKey) = pSetting
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply(pPreset, .tSettings), "the policy is stored: preset '" _ pPreset _ "', " _ pKey _ " " _ pSetting)
}

/// <p>Matrix row 1 and AC2: with no stored policy every registered write key is enabled by the
/// baseline except the purge, which the baseline disables.</p>
Method TestTheDefaultEnablesEveryWriteButThePurge()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Policy).WriteKeys(.tKeys), "the write keys are read")
    Set tWrong = ""
    Set tCount = 0
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        Set tCount = tCount + 1
        Set tExpected = $Select(tKey = ..#PURGE: "0|baseline", 1: "1|baseline")
        If ..Resolved(tKey) '= tExpected Set tWrong = tWrong _ $ListBuild(tKey _ "=" _ ..Resolved(tKey))
    }
    Do $$$AssertTrue(tCount > 0, "there are write keys to resolve (" _ tCount _ ")")
    Do $$$AssertEquals($ListToString(tWrong, ", "), "", "each resolves enabled by the baseline, the purge disabled")
    Do $$$AssertEquals(..Resolved(..#PURGE), "0|baseline", "the purge's source is the baseline")
}

/// <p>Matrix rows 2 to 4 and AC3: the first layer holding a value decides, and an explicit false is
/// a value. A setting of disabled wins over <code>full</code>; <code>read-only</code> disables a
/// write the baseline enables; a setting of enabled wins over <code>read-only</code>.</p>
/// <p>Mutation (Rule 19): resolve "any layer's false wins" in place of the first non-null layer ->
/// the setting-over-read-only leg goes red.</p>
Method TestTheFirstLayerHoldingAValueDecides()
{
    Do ..Store("full", ..#TOOL, "disabled")
    Do $$$AssertEquals(..Resolved(..#TOOL), "0|setting", "a setting of disabled wins over full")
    Do $$$AssertEquals(..Resolved(..#CREATE), "1|preset", "while full enables a key with no setting")

    Do ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do ..Store("read-only")
    Do $$$AssertEquals(..Resolved(..#TOOL), "0|preset", "read-only disables a write the baseline enables")

    Do ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do ..Store("read-only", ..#PURGE, "enabled")
    Do $$$AssertEquals(..Resolved(..#PURGE), "1|setting", "a setting of enabled wins over read-only and the baseline's false")
    Do $$$AssertEquals(..Resolved(..#TOOL), "0|preset", "and the preset still decides every other write")
}

/// <p>Matrix row 3 and AC4: under <code>read-only</code> a read is allowed, and a call whose kind is
/// neither read nor write is denied, as it is under every layer.</p>
/// <p>Mutation (Rule 19): read an unclassified kind as a read -> the unclassified legs go red.</p>
Method TestAnUnclassifiableKindIsDenied()
{
    Do ..Store("read-only")
    Do $$$AssertEquals(..Resolved("logs.errors.read", "read"), "1|", "a read is allowed under read-only")
    Do $$$AssertEquals(..Resolved(..#TOOL, ""), "0|", "a call of no kind is denied")
    Do $$$AssertEquals(..Resolved(..#TOOL, "other"), "0|", "and so is a kind outside the vocabulary")
    Do ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do ..Store("full", ..#TOOL, "enabled")
    Do $$$AssertEquals(..Resolved(..#TOOL, ""), "0|", "even where full and the key's own setting would enable it")
    Kill tDecision
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(..#TOOL, "", $Username, {}, .tDecision), "the gate decides")
    Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), "0|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "and the gate refuses it with the governance code")
}

/// <p>The matrix's unreadable store at the resolver itself: a store read that fails is an error
/// with the key disabled and no layer named, never a fall-through to the preset or the baseline.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Governance.Policy.Resolve</method> goes on to the
/// cascade after a failed read -> this goes red, the key resolving enabled by the baseline.</p>
Method TestAnUnreadableStoreResolvesTheKeyDisabled()
{
    Set tSC = ##class(OcuPilot.Test.GovernanceStoreProbe).Resolve(..#TOOL, "write", .tEnabled, .tSource)
    Do $$$AssertStatusNotOK(tSC, "a store that cannot be read is an error")
    Do $$$AssertEquals(''tEnabled _ "|" _ tSource, "0|", "and the key the baseline enables resolves disabled, no layer deciding")
}

/// <p>A stored key's setting is changed in place, and <code>inherit</code> removes its row, so the
/// baseline decides again.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Policy.GuardedApply</method> skips the
/// delete for <code>inherit</code> -> the inherit leg goes red.</p>
Method TestAStoredKeyIsChangedInPlaceAndInheritRemovesIt()
{
    Do ..Store("", ..#TOOL, "disabled")
    Do ..Store("", ..#TOOL, "enabled")
    Do $$$AssertEquals(..Resolved(..#TOOL), "1|setting", "a stored disabled is changed to enabled")
    Do ..Store("", ..#TOOL, "disabled")
    Do $$$AssertEquals(..Resolved(..#TOOL), "0|setting", "and back to disabled")
    Do ..Store("", ..#TOOL, "inherit")
    Do $$$AssertEquals(..Resolved(..#TOOL), "1|baseline", "inherit hands the key back to the baseline")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows), "the stored rows are read")
    Do $$$AssertEquals($Data(tRows(..#TOOL)), 0, "and leaves no row for the key")
}

/// <p>The system prompt tells the model what a governance denial means and not to call the tool
/// again (AD-22).</p>
/// <p>Mutation (Rule 19): delete the sentence from
/// <parameter>OcuPilot.Kernel.Agent.Prompt.BUILTIN</parameter> -> this goes red.</p>
Method TestThePromptSaysWhatAGovernanceDenialMeans()
{
    Set tPrompt = ##class(OcuPilot.Kernel.Agent.Prompt).Builtin()
    Do $$$AssertTrue(tPrompt [ "When a tool answers GOVERNANCE.DISABLED, say that the tool is disabled by policy on this instance", "the prompt names the governance code and what to say")
    Do $$$AssertTrue(tPrompt [ "and do not call it again.", "and tells the model not to call the tool again")
}

/// <p>No cache: a setting stored and then removed changes the next resolution each time.</p>
Method TestEveryResolutionReadsTheStore()
{
    Do $$$AssertEquals(..Resolved(..#TOOL), "1|baseline", "enabled with nothing stored")
    Do ..Store("", ..#TOOL, "disabled")
    Do $$$AssertEquals(..Resolved(..#TOOL), "0|setting", "disabled the moment the setting is stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the policy is cleared")
    Do $$$AssertEquals(..Resolved(..#TOOL), "1|baseline", "and enabled again the moment it is removed")
}

/// <p>AC11: a tool declaring its governance action yields one <code>tool:value</code> key per
/// member of the argument's enum, a call's key is the value it sends, and a setting on one action
/// governs that action alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Governance.Policy.KeyFor</method> ignores the
/// declaration -> the key and the per-action legs go red.</p>
Method TestAnActionKeyGovernsThatActionAlone()
{
    Set tClass = ..#ACTIONTOOL
    Set tName = $Parameter(tClass, "TOOLNAME")
    Set tEntry = {"kind": "write", "descriptor": ""}
    Do tEntry.%Set("name", tName, "string")
    Do tEntry.%Set("class", tClass, "string")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Governance.Policy).KeysOf(tEntry)), tName _ ":start," _ tName _ ":stop", "its keys are one per action")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Policy).KeyFor(tClass, tName, {"Action": "start"}), tName _ ":start", "a call's key is the action it sends")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Policy).KeyFor(tClass, tName, {}), tName _ ":", "and a call that sends none names no listed key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Policy).KeyFor("OcuPilot.Screen.Tool.WebAppUpdate", ..#TOOL, {"Action": "start"}), ..#TOOL, "a tool declaring no action is keyed by its name")
    Do ..Store("", tName _ ":start", "enabled")
    Do $$$AssertEquals(..Resolved(tName _ ":start"), "1|setting", "the enabled action resolves enabled")
    Do $$$AssertEquals(..Resolved(tName _ ":stop"), "0|baseline", "the other stays disabled, no baseline listing it")
}

/// <p>AC5, AC8 and the integration leg on the dispatcher: with the key disabled in the real store,
/// the shipped <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method> answers
/// <code>{"code":"GOVERNANCE.DISABLED"}</code>, mints nothing, records the call's ledger row with
/// that code, and the tool stays in the provider list, the dispatch lookup and the screen context's
/// <code>tools</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Governance.Gate.Decide</method> answers allowed
/// -> the result leg goes red.</p>
Method TestADisabledKeyIsRefusedAtDispatchAndStaysAdvertised()
{
    Do ..Store("", ..#TOOL, "disabled")
    ; A real target, so an allowed call would mint: "nothing is minted" then turns on the gate alone.
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget(, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe application is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tWire = ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL)
    Set tUse = {"type": "tool_use", "id": "toolu_governed", "input": {"Description": "probe", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Get("input").%Set("Name", ##class(OcuPilot.Test.ProposalFixture).#WRITETARGET, "string")
    Do tUse.%Set("name", tWire, "string")
    Set tProposalsBefore = ..ProposalsFor(tTurnKey)
    ; The turn marker a real turn carries, so a proposal minted here would name its turn (AD-40).
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tAnswer = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
    Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", "the call is refused with the governance code alone")
    Do $$$AssertEquals(..ProposalsFor(tTurnKey), tProposalsBefore, "and nothing is minted")
    Do $$$AssertEquals(..LedgerCode(tTurnKey, ..#TOOL), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the call's ledger row is written with that code")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)

    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tProvider), "the provider tool list builds")
    Set tListed = ""
    For tI = 1:1:+$Get(tProvider) Set tListed = tListed _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertTrue($ListFind(tListed, tWire) > 0, "the disabled tool is still advertised to the provider")
    Do ##class(OcuPilot.Screen.Tool.Registry).ResolveWire(tWire, .tByWire)
    Do $$$AssertTrue($IsObject($Get(tByWire)), "and still resolves in the dispatch lookup")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#SCREEN, .tTools), "the screen's context tools build")
    Do $$$AssertTrue($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "") [ tWire, "and the screen context still carries it")
}

/// <p>AC6, AC7 and the integration leg on the confirm: a proposal minted while its key was enabled
/// is refused 403 <code>GOVERNANCE.DISABLED</code> once the key is disabled -- by the shipped
/// <method>OcuPilot.Kernel.Proposal.Confirm.Confirm</method> against the real target, and by the
/// fixture confirm whose port records every call -- before the claim and the port call: the row
/// stays live, its token unspent, and the port records no write. The draft still closes the row
/// <code>canceled</code>/<code>draft</code>.</p>
/// <p>Mutation (Rule 19): remove the governance block from
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -> both confirm legs go red.</p>
Method TestADisableAfterTheMintRefusesTheConfirmAndTheDraftStillCloses()
{
    ; The fixture confirm: the port is the fixture, so a call reaching it is counted.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FIXTUREFRESH)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {"Description": "after"}
    Do tArgs.%Set("Name", ..#FIXTURETARGET, "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#FIXTURETARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "the proposal mints while the key is enabled")
    If '$IsObject($Get(tProposal)) Quit
    Set tFixtureKey = tProposal.%Get("proposalId")
    Do ..Store("", ..#TOOL, "disabled")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tFixtureKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the fixture confirm is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "403 with the governance code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the port records no write")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFixtureKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tFixtureKey, "Burned"), "live|0", "the row stays live and its token unspent")

    ; The shipped confirm, against a real web application.
    Do ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Set tTarget = ##class(OcuPilot.Test.ProposalFixture).#WRITETARGET
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget(, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe application is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tKey = ..SeedReal(tTarget, "changed by the governance probe")
    If tKey = "" Quit
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description")
    Do ..Store("", ..#TOOL, "disabled")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the shipped confirm is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "403 with the governance code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), "live|0", "the row stays live and its token unspent")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description"), tBefore, "and the application is unchanged")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tKey, $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the draft is taken: " _ $Get(tCode))
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "canceled|draft", "and the row closes canceled, reason draft")
}

/// <p>Refusal precedence at the confirm (AD-10, AD-22): with the key disabled <b>and</b> the
/// prohibited set armed to refuse, the prohibited set answers, so governance never masks a
/// prohibited effect's own code.</p>
/// <p>Mutation (Rule 19): move the governance block above the shared gates in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -> this goes red naming
/// <code>GOVERNANCE.DISABLED</code>.</p>
Method TestAProhibitedEffectAnswersBeforeADisabledKey()
{
    Set tKey = ..MintFixture()
    If tKey = "" Quit
    Do ..Store("", ..#TOOL, "disabled")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.ProposalFixture")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "403|AGENT.PROHIBITED", "with the prohibited set's code, not the governance one")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the port records no write")
}

/// <p>Refusal precedence at the confirm (AD-22, AD-30): with the key disabled <b>and</b> enforced
/// read-only on, the governance gate answers, and the restraint verdict is never the one named.</p>
/// <p>Mutation (Rule 19): move the governance block below the restraint verdict in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -> this goes red naming a restraint
/// code.</p>
Method TestADisabledKeyAnswersBeforeTheRestraintVerdict()
{
    Set tKey = ..MintFixture()
    If tKey = "" Quit
    Do ..Store("", ..#TOOL, "disabled")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tPrior), "the switches are read before the change")
    Kill tValues
    Set tValues("enforcedReadOnly") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "enforced read-only is turned on after the mint")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Kill tRestore
    Set tRestore("enforcedReadOnly") = ''$Get(tPrior("enforcedReadOnly"))
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRestore), "and is put back as it was")
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tCode, "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "with the governance code, not a restraint one")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row stays live")
}

/// <p>The matrix's unreadable store (fail closed): a governance gate that cannot decide refuses the
/// confirm 500 with the generic internal code, before the claim and the port call, and the row
/// stays live.</p>
/// <p>Mutation (Rule 19): read a gate error as allowed in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -> this goes red.</p>
Method TestAGateThatCannotDecideFailsTheConfirmClosed()
{
    Set tKey = ..MintFixture()
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.GovernanceFixture).FailGate(1)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do ##class(OcuPilot.Test.GovernanceFixture).FailGate(0)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 500, "at 500: " _ $Get(tCode))
    Do $$$AssertNotEquals(tCode, ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "an internal failure, not a policy denial")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the port records no write")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), "live|0", "the row stays live and its token unspent")
}

/// <p>Arm the fixture port and mint one live <parameter>TOOL</parameter> proposal against
/// <parameter>FIXTURETARGET</parameter> while its key is enabled, answering its id or
/// <code>""</code>.</p>
Method MintFixture() As %String
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FIXTUREFRESH)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tArgs = {"Description": "after"}
    Do tArgs.%Set("Name", ..#FIXTURETARGET, "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#FIXTURETARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "the proposal mints while the key is enabled")
    If '$IsObject($Get(tProposal)) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>AC9, AD-10: under <code>full</code> with the key's own setting enabled, a proposal whose
/// effect is prohibited -- repointing OcuPilot's own API -- is still refused with its
/// <code>PROHIBITED.*</code> code, and the row stays live.</p>
Method TestAProhibitedEffectStandsUnderFullWithTheKeyEnabled()
{
    Do ..Store("full", ..#TOOL, "enabled")
    Do $$$AssertEquals(..Resolved(..#TOOL), "1|setting", "the key resolves enabled")
    Kill tQuery
    Set tQuery("name") = ..#OWNAPP
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own API reads")
    If $$$ISERR(tSC) Quit
    Set tBefore = tFresh.%Get("DispatchClass")
    Do tFresh.%Set("DispatchClass", "OcuPilot.Test.Governance", "string")
    Set tDiff = [{"field": "DispatchClass", "after": "OcuPilot.Test.Governance"}]
    Do tDiff.%Get(0).%Set("before", tBefore, "string")
    Set tKey = ..Seed(..#OWNAPP, tFresh.%ToJSON(), tDiff.%ToJSON(), "{}")
    If tKey = "" Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ "|" _ $Extract(tCode, 1, 11), "403|PROHIBITED.", "with the prohibited set's own code: " _ tCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row stays live")
}

/// <p>Seed a live <parameter>TOOL</parameter> proposal against the real web application
/// <var>pTarget</var>, changing its description to <var>pDescription</var>, and answer its id.</p>
Method SeedReal(pTarget As %String, pDescription As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pTarget
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the application reads")
    If $$$ISERR(tSC) Quit ""
    Set tDiff = [{"field": "Description", "after": (pDescription)}]
    Do tDiff.%Get(0).%Set("before", tFresh.%Get("Description"), "string")
    Do tFresh.%Set("Description", pDescription, "string")
    Set tArgs = {"Description": (pDescription)}
    Do tArgs.%Set("Name", pTarget, "string")
    Quit ..Seed(pTarget, tFresh.%ToJSON(), tDiff.%ToJSON(), tArgs.%ToJSON())
}

/// <p>Seed one live <parameter>TOOL</parameter> proposal against web application <var>pId</var>
/// with the stored payload, diff and arguments, and answer its id.</p>
Method Seed(pId As %String, pPayload As %String, pDiff As %String, pArguments As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pId, .tTargetRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = pArguments
    Set tValues("payload") = pPayload
    Set tValues("diff") = pDiff
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>How many stored proposals turn <var>pTurnKey</var> minted, or <code>-1</code>.</p>
ClassMethod ProposalsFor(pTurnKey As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%Get("N")
}

/// <p>The code of turn <var>pTurnKey</var>'s ledger row for tool <var>pName</var>, or
/// <code>""</code>.</p>
ClassMethod LedgerCode(pTurnKey As %String, pName As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Code FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Name) = ?", pTurnKey, pName)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

}
