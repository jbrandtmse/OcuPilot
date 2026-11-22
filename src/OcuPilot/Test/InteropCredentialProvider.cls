/// <p>Pins Story 24.15's self-protection end to end (AD-10, AD-35, AD-62): while an enabled agent definition of the <code>creds</code> rung names a
/// credential in <code>CredentialName</code>, the agent's remove and password change of that credential are refused
/// <code>PROHIBITED.PROVIDERCREDENTIAL</code> when proposed, with nothing stored, in OcuPilot's own namespace; the same credential through the screen is
/// not refused, nor is a credential no enabled definition names, a credential of that name in another namespace, the agent's edit of the provider's
/// credential or its add of another, or a credential only a disabled definition names; and a definition renamed to another credential moves the
/// refusal with it, because the definitions are read at each proposal.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces (the install namespace
/// is the process's own), the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It creates probe agent
/// definitions named <code>OcuPilotProbeAgent*</code>, never the default and enabled only inside the test that needs one, and removes every
/// definition, credential and password node it creates.</p>
Class OcuPilot.Test.InteropCredentialProvider Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter AGENTS = "OcuPilot.Test.AgentFixture";

/// <p>The credential the probe definition names, and the one it is renamed to.</p>
Parameter PROVIDED = "OcuProbe2415P";

Parameter OTHER = "OcuProbe2415Q";

/// <p>The probe definitions' names.</p>
Parameter DEFINITION = "OcuPilotProbeAgent2415";

Parameter PASSWORD = "OcuPwProvider2415x";

Parameter OWN = "HSCUSTOM";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropCredentialProvider writes probe credentials and agent definitions on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do $ClassMethod(..#AGENTS, "RemoveProbeDefinitions", .tRemaining)
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#AGENTS, "RemoveProbeDefinitions", .tRemaining)
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#AGENTS, "RemoveProbeDefinitions", .tRemaining)
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#AGENTS, "RemoveProbeDefinitions", .tRemaining), "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe credentials are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415") + $ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415", ..#OWN), 0, "and none survives, with its password node, in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemainingTurns), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Create the probe definition <var>pSuffix</var> on the <code>creds</code> rung naming <var>pCredential</var>, enabled when <var>pEnabled</var>;
/// its id. Written directly, for the reason <class>OcuPilot.Test.AgentFixture</class> gives: the API refuses an enable while unverified.</p>
Method Provider(pSuffix As %String, pCredential As %String, pEnabled As %Boolean = 1) As %String
{
    Set tSC = $ClassMethod(..#AGENTS, "CreateDefinition", ..#DEFINITION _ pSuffix, 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the probe definition is created")
    If $$$ISERR(tSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertStatusOK(..Repoint(tId, pCredential, pEnabled), pSuffix _ ": and names " _ pCredential)
    Quit tId
}

/// <p>Make definition <var>pId</var> a <code>creds</code> definition naming <var>pCredential</var>, enabled when <var>pEnabled</var>. A change of
/// the credential disables a definition, so it is made while disabled and the flags are set after it.</p>
Method Repoint(pId As %String, pCredential As %String, pEnabled As %Boolean) As %Status
{
    Set tSC = $ClassMethod(..#AGENTS, "SetFlags", pId, 0, 0)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.CredType = "creds"
    Set tRow.EnvVarName = ""
    Set tRow.CredentialName = pCredential
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#AGENTS, "SetFlags", pId, pEnabled, pEnabled)
}

/// <p>The agent's call of <var>pTool</var> (a class name) for <var>pArgs</var> in <var>pNamespace</var>, as the HTTP account on a seeded turn, with
/// the process acting for that turn when <var>pAsTurn</var>: the mint's answer, as <code>status code</code>; the proposal in <var>pProposal</var>, its
/// refusal in <var>pFault</var> and the turn in <var>pTurn</var>.</p>
ClassMethod MintIn(pTool As %String, pArgs As %DynamicObject, pNamespace As %String, Output pProposal, Output pFault, Output pTurn, pAsTurn As %Boolean = 1) As %String
{
    Set pProposal = ""
    Set pFault = ""
    Set tClass = "OcuPilot.Screen.Tool." _ pTool
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit "no turn"
    If pAsTurn Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Do pArgs.%Set("rationale", "probe", "string")
    Do pArgs.%Set("expectedImpact", "probe", "string")
    Set tIdArgument = $ClassMethod(tClass, "IdArgument")
    Set tSC = $ClassMethod($ClassMethod(tClass, "MintClass"), "Mint", $Parameter(tClass, "DESCRIPTORCLASS"), $Parameter(tClass, "TOOLNAME"), tUser, "", pTurn, pArgs, $ClassMethod(tClass, "LimitsClass"), .pProposal, .tHttp, .pFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pArgs.%Get(tIdArgument), tIdArgument, $ClassMethod(tClass, "SettableFields"), $ClassMethod(tClass, "ToolClass"))
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>One person's row action on the Credentials screen in <var>pNamespace</var> as <code>status code</code>.</p>
ClassMethod ActIn(pNamespace As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "") As %String
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/interop.credentials/action?ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json", .tExtra, 120)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tCode = "" }
    Quit tStatus _ " " _ tCode
}

/// <p>Binding 1, AC4: the agent's remove of the credential an enabled <code>creds</code> definition names, in OcuPilot's own namespace, is refused when
/// proposed: 403 <code>PROHIBITED.PROVIDERCREDENTIAL</code> with the published sentence, no proposal stored, and the credential untouched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropCredentialRemove.RefusedBeforeState</method> answer 0 -- this goes red.</p>
Method TestTheAgentsRemoveOfTheProvidersCredentialIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#PROVIDED, "provider", "", ..#PASSWORD, ..#OWN), "the provider's credential is held in the install namespace")
    Do ..Provider("A", ..#PROVIDED)
    Set tVerdict = ..MintIn("InteropCredentialRemove", {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tVerdict, "403 PROHIBITED.PROVIDERCREDENTIAL", "the remove is refused when proposed")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("reason"), 1: ""), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.PROVIDERCREDENTIAL"), "with the ruled sentence")
    Do $$$AssertTrue('$IsObject(tProposal), "no proposal came back")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tTurn), 0, "and none is stored")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#PROVIDED, ..#OWN), "provider||1", "the credential and its password are untouched")
}

/// <p>Binding 2, AC4: the agent's password change of that credential is refused the same way, with nothing stored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropCredentialPassword.RefusedBeforeState</method> answer 0 -- this goes red.</p>
Method TestTheAgentsPasswordChangeOfTheProvidersCredentialIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#PROVIDED, "provider", "", ..#PASSWORD, ..#OWN), "the provider's credential is held in the install namespace")
    Do ..Provider("A", ..#PROVIDED)
    Set tVerdict = ..MintIn("InteropCredentialPassword", {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tVerdict, "403 PROHIBITED.PROVIDERCREDENTIAL", "the password change is refused when proposed")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("reason"), 1: ""), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.PROVIDERCREDENTIAL"), "with the ruled sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tTurn), 0, "and no proposal is stored")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#PROVIDED, ..#OWN), "provider||1", "the credential and its password are untouched")
}

/// <p>Binding 3, AC4: the same credential through the screen is not refused: a person's Set password and Remove run in no turn and succeed.</p>
/// <p>Mutation (Rule 19): drop the <code>Caller.IsTurn()</code> condition from
/// <method>OcuPilot.Screen.Tool.InteropCredentialAction.RefusedForProvider</method> -- the person's legs go red.</p>
Method TestThePersonsChangeOfTheProvidersCredentialIsNotRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#PROVIDED, "provider", "", ..#PASSWORD, ..#OWN), "the provider's credential is held in the install namespace")
    Do ..Provider("A", ..#PROVIDED)
    Do $$$AssertEquals(..ActIn(..#OWN, "password", ..#PROVIDED, {"Password": "OcuPwPerson2415x"}), "200 ", "a person's Set password succeeds")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#PROVIDED, ..#OWN), "provider||1", "and the credential still holds a password")
    Do $$$AssertEquals(..ActIn(..#OWN, "remove", ..#PROVIDED), "200 ", "a person's Remove succeeds")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#PROVIDED, ..#OWN) _ "|" _ $ClassMethod(..#FIXTURE, "PasswordNode", ..#PROVIDED, ..#OWN), "<absent>|0", "and the credential and its password are gone")
}

/// <p>Binding 4, AC4: the refusal is exactly the provider's: a credential no enabled definition names, a credential only a disabled definition names, a
/// credential of the provider's name in another namespace, the agent's edit of the provider's own credential and its add of another are all proposed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ProviderCredential</method> answer 1 for any name -- the unnamed-credential
/// legs go red.</p>
Method TestOnlyTheProvidersOwnCredentialIsRefused()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#PROVIDED, "provider", "", ..#PASSWORD, ..#OWN), "the provider's credential is held in the install namespace")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#OTHER, "other", "", ..#PASSWORD, ..#OWN), "so is one no definition names")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#PROVIDED, "elsewhere", "", ..#PASSWORD, "USER"), "and one of the provider's name in USER")
    Do ..Provider("A", ..#PROVIDED)
    Do ..Provider("D", ..#OTHER, 0)
    For tTool = "InteropCredentialRemove", "InteropCredentialPassword" {
        Set tVerdict = ..MintIn(tTool, {"Name": (..#OTHER)}, ..#OWN, .tProposal, .tFault, .tTurn)
        Do $$$AssertEquals(tVerdict, "200 ", tTool _ ": a credential only a disabled definition names is proposed: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        Set tVerdict = ..MintIn(tTool, {"Name": (..#PROVIDED)}, "USER", .tProposal, .tFault, .tTurn)
        Do $$$AssertEquals(tVerdict, "200 ", tTool _ ": the provider's name in another namespace is proposed: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        Set tVerdict = ..MintIn(tTool, {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn, 0)
        Do $$$AssertEquals(tVerdict, "200 ", tTool _ ": the provider's credential is proposed when no turn is acting: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Set tVerdict = ..MintIn("InteropCredentialUpdate", {"Name": (..#PROVIDED), "Username": "renamed"}, ..#OWN, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tVerdict, "200 ", "the agent's edit of the provider's own user name is proposed: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tVerdict = ..MintIn("InteropCredentialAdd", {"Name": "OcuProbe2415N", "Username": "new"}, ..#OWN, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tVerdict, "200 ", "the agent's add of another credential is proposed: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tVerdict = ..MintIn("InteropCredentialRemove", {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tVerdict, "403 PROHIBITED.PROVIDERCREDENTIAL", "while the provider's own credential is still refused")
}

/// <p>Binding 5, AC4: the refusal follows the definition: renamed from one credential to another, the first is proposed and the second is refused,
/// because the definitions are read at each proposal.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ProviderCredential</method> read a value captured once per process -- the
/// renamed legs go red.</p>
Method TestARenamedProviderMovesTheRefusalWithIt()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#PROVIDED, "first", "", ..#PASSWORD, ..#OWN), "the first credential is held")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutCredential", ..#OTHER, "second", "", ..#PASSWORD, ..#OWN), "so is the second")
    Set tId = ..Provider("A", ..#PROVIDED)
    Do $$$AssertEquals(..MintIn("InteropCredentialRemove", {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn), "403 PROHIBITED.PROVIDERCREDENTIAL", "the first is refused while the definition names it")
    Do $$$AssertEquals(..MintIn("InteropCredentialRemove", {"Name": (..#OTHER)}, ..#OWN, .tProposal, .tFault, .tTurn), "200 ", "and the second is proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(..Repoint(tId, ..#OTHER, 1), "the definition is renamed to the second credential")
    Do $$$AssertEquals(..MintIn("InteropCredentialRemove", {"Name": (..#PROVIDED)}, ..#OWN, .tProposal, .tFault, .tTurn), "200 ", "the first is now proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..MintIn("InteropCredentialRemove", {"Name": (..#OTHER)}, ..#OWN, .tProposal, .tFault, .tTurn), "403 PROHIBITED.PROVIDERCREDENTIAL", "and the second is refused")
    Do $$$AssertEquals(..MintIn("InteropCredentialPassword", {"Name": (..#OTHER)}, ..#OWN, .tProposal, .tFault, .tTurn), "403 PROHIBITED.PROVIDERCREDENTIAL", "for a password change as well")
}

/// <p>AC4: a read of the definitions that fails refuses, so a question the instance cannot answer is never passed
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ProviderCredential</method>).</p>
/// <p>Mutation (Rule 19): make the method answer 0 when the read fails -- this goes red.</p>
Method TestAFailedReadOfTheDefinitionsRefuses()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ProviderCredential(""), 0, "an empty name names nothing and is answered without a query")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ProviderCredential("OcuProbe2415Z"), 0, "a name no enabled definition names is not the provider's")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropCredentialSeam).ProviderCredential("OcuProbe2415Z"), 1, "a read that fails answers that the name is the provider's")
}

}
