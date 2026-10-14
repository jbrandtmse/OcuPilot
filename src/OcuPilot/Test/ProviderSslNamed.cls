/// <p>Pins Story 18.40's self-protection of the SSL/TLS configuration the egress row names (AD-10 as amended 2026-10-13):
/// <code>PROHIBITED.PROVIDERSSL</code> on a delete, a create under its name, and a change to its type, peer verification,
/// trusted certificates or enablement, from the SSL/TLS Save, the list's Delete and the agent's mint and confirm, with its
/// one published sentence; the configuration's other fields pass; once another is named, or none, it is refused nothing; a
/// failed read of the egress row refuses.</p>
/// <p>Every write goes to a port that records it and never sends it, or to the fixture's, so no leg changes the instance.
/// The probe configurations are made and removed by <class>OcuPilot.Test.EgressSslProbe</class>; the egress row is restored
/// to none after every leg.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and
/// deletes SSL/TLS configurations by exact name. <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.ProviderSslNamed Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

/// <p>The configuration the egress row names, another it can name instead, and a name no configuration holds.</p>
Parameter PROBE = "OcuPilotProbeEgressNamed";

Parameter OTHER = "OcuPilotProbeEgressOther";

Parameter FREE = "OcuPilotProbeEgressFree";

/// <p>The Save whose port records a <code>PUT</code> and never sends it, and the one whose port records every write.</p>
Parameter HELDSAVE = "OcuPilot.Test.SslSaveHeldFixture";

Parameter FIXTURESAVE = "OcuPilot.Test.SslSaveProposalFixture";

Parameter HELDPORT = "OcuPilot.Test.HeldPutPort";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter FAILFIXTURE = "OcuPilot.Test.ProhibitedEgressFailFixture";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SslUpdate";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.SslCreate";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProviderSslNamed creates and deletes SSL/TLS configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.EgressSslProbe).Ensure(..#PROBE)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.EgressSslProbe).Ensure(..#OTHER)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    Set tSC = ##class(OcuPilot.Test.EgressSslProbe).Remove(..#PROBE)
    Set tOther = ##class(OcuPilot.Test.EgressSslProbe).Remove(..#OTHER)
    Quit $Select($$$ISERR(tSC): tSC, 1: tOther)
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#HELDPORT, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "the egress row this method wrote is removed")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>With the egress row naming a name no configuration holds, a create under that name is refused
/// <code>PROHIBITED.PROVIDERSSL</code> with its sentence at the SSL/TLS Save and at the agent's confirm, whatever its
/// payload carries, and nothing is written; with the name cleared the same create is permitted at the Save.</p>
/// <p>Mutation (Rule 19): delete the <code>ProviderSsl</code> arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> -- both refused legs write and go red.</p>
Method TestACreateUnderTheNamedNameIsRefusedAtSaveAndAtConfirm()
{
    Do ..Name(..#FREE)
    Set tArgs = {"Name": (..#FREE), "Type": 0, "VerifyPeer": 0, "Enabled": true, "Description": "probe"}
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = $ClassMethod(..#FIXTURESAVE, "Create", ..#FREE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "the Save's create is refused as the provider configuration's")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "PROVIDERSSLREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")

    Set tProposal = ..Mint(..#CREATETOOL, ..#FREE, tArgs, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tProposal), "the agent's create is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tProposal) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "and its confirm is refused the same")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")

    Do ..Name("")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = $ClassMethod(..#FIXTURESAVE, "Create", ..#FREE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertTrue('$IsObject($Get(tFault)), "once the name is cleared the Save's create is not refused: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "and is written")
}

/// <p>A create under OcuPilot's own provider configuration's name is refused <code>PROHIBITED.PROVIDERSSL</code> at the
/// SSL/TLS Save and at the agent's confirm while the egress row names nothing, whatever its payload carries, and nothing is
/// written; the fixture answers the name absent, as it is after a delete outside OcuPilot.</p>
/// <p>Mutation (Rule 19): delete the own-name clause that follows the <code>ProviderSsl</code> arm in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> -- both legs write and go red.</p>
Method TestACreateUnderOcuPilotsOwnProviderNameIsRefused()
{
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tArgs = {"Name": (tOwn), "Type": 0, "VerifyPeer": 0, "Enabled": true, "Description": "probe"}
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = $ClassMethod(..#FIXTURESAVE, "Create", tOwn, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "the Save's create is refused as the provider configuration's")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "PROVIDERSSLREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")

    Set tProposal = ..Mint(..#CREATETOOL, tOwn, tArgs, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tProposal), "the agent's create is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tProposal) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "and its confirm is refused the same")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")
}

/// <p>With the egress row naming a configuration, a change to its peer verification or enablement at the Save, and its
/// Delete from the list, are refused <code>PROHIBITED.PROVIDERSSL</code> with the published sentence and nothing reaches
/// the port, while a change to its description passes the set and reaches the held port; a change to its type or
/// trusted certificates is refused by the set; an agent change minted before the naming is refused at its confirm, and one
/// asked after it is refused at the mint with the same sentence. Naming another configuration, or none, lifts every
/// refusal.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ProviderSsl</method> answer 0 -- every
/// refused leg reaches the port and goes red.</p>
Method TestTheNamedConfigurationRefusesItsFourFieldsAndItsDeleteOnBothCallers()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SslSave).Fresh(..#PROBE, .tFresh), "the probe reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Do ..Name(..#PROBE)
    For tBody = "{""VerifyPeer"":0}", "{""Enabled"":false}" {
        Do $ClassMethod(..#HELDPORT, "Clear")
        Set tSC = $ClassMethod(..#HELDSAVE, "Update", ..#PROBE, ##class(%DynamicObject).%FromJSON(tBody), .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "PROVIDERSSL"), tBody _ " is refused as the provider configuration's")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "PROVIDERSSLREASON"), tBody _ ": with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#HELDPORT, "WriteCount"), 0, tBody _ ": and nothing reaches the port")
    }
    Do $ClassMethod(..#HELDPORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", ..#PROBE, {"Description": "probe"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter(..#HELDPORT, "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, "a change to its description passes the set and reaches the held port")
    For tField = "Type", "CAFile" {
        Set tPayload = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
        If tField = "Type" Do tPayload.%Set("Type", 1, "number")
        If tField = "CAFile" Do tPayload.%Set("CAFile", "", "string")
        Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tFresh.%ToJSON(), tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff(tField), ..#PROBE, "ssl-configuration", .tProhibits, .tCode, $Parameter(..#UPDATETOOL, "TOOLNAME"))
        Do $$$AssertEquals(tCode, $Parameter(..#SET, "PROVIDERSSL"), "a change to its " _ tField _ " is refused as the provider configuration's")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.SslActionFixture).Act("security.ssl", {"action": "delete", "id": (..#PROBE)}, .tAnswer, .tStatus)
    Set tEnvelope = $Select(tAnswer '= "": ##class(%DynamicObject).%FromJSON(tAnswer), 1: {})
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("code"), "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "the list's Delete is refused as the provider configuration's")
    Do $$$AssertEquals(tEnvelope.%Get("reason"), $Parameter(..#SET, "PROVIDERSSLREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")

    Do ..Name("")
    Set tProposal = ..Mint(..#UPDATETOOL, ..#PROBE, {"VerifyPeer": 0}, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tProposal), "an agent change is minted while the configuration is not named: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tProposal) Quit
    Do ..Name(..#PROBE)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "PROVIDERSSL"), "and is refused at its confirm once it is named")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")
    Set tAfter = ..Mint(..#UPDATETOOL, ..#PROBE, {"VerifyPeer": 0}, .tHttp, .tFault)
    Do $$$AssertTrue('$IsObject(tAfter), "an agent change asked while it is named is not minted")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.problem, 1: ""), "'VerifyPeer': " _ $Parameter(..#SET, "PROVIDERSSLREASON"), "and is refused with the published sentence")

    For tNamed = ..#OTHER, "" {
        Do ..Name(tNamed)
        Do $ClassMethod(..#HELDPORT, "Clear")
        Set tSC = $ClassMethod(..#HELDSAVE, "Update", ..#PROBE, {"VerifyPeer": 0}, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter(..#HELDPORT, "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, "naming '" _ tNamed _ "' instead lifts the refusal: the change reaches the held port")
    }
}

/// <p>A read of the egress row that fails refuses the delete and the four fields of any SSL/TLS configuration, and a create
/// under any name, since the set cannot say the configuration is not the one calls go through; the shipped read, with no
/// row, refuses none of them.</p>
/// <p>Mutation (Rule 19): answer 0 for a failed read in <method>OcuPilot.Kernel.Proposal.Prohibited.ProviderSsl</method>
/// -- the failed-read legs go red.</p>
Method TestAFailedReadOfTheEgressRowRefuses()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SslSave).Fresh(..#PROBE, .tFresh), "the probe reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Set tPayload = ##class(%DynamicObject).%FromJSON(tFresh.%ToJSON())
    Do tPayload.%Set("VerifyPeer", 0, "number")
    For tSet = ..#FAILFIXTURE, ..#SETFIXTURE {
        Set tSC = $ClassMethod(tSet, "Ask", tFresh.%ToJSON(), tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("VerifyPeer"), ..#PROBE, "ssl-configuration", .tProhibits, .tCode, $Parameter(..#UPDATETOOL, "TOOLNAME"))
        Do $$$AssertStatusOK(tSC, tSet _ " answers")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select(tSet = ..#FAILFIXTURE: "1 " _ $Parameter(..#SET, "PROVIDERSSL"), 1: "0 "), tSet _ ": a change to peer verification is " _ $Select(tSet = ..#FAILFIXTURE: "refused when the read fails", 1: "permitted while no configuration is named"))
    }
    Do $$$AssertEquals($ClassMethod(..#FAILFIXTURE, "ProviderSsl", ..#FREE), 1, "a failed read answers 1 for a name no configuration holds")
}

/// <p><code>ProviderSsl</code> answers 1 for exactly the name the row stores, as the instance resolves a name -- in its own
/// case -- and 0 for any other name, for OcuPilot's own provider configuration, and while the row names none.</p>
/// <p>Mutation (Rule 19): compare the names case-blind in <method>OcuPilot.Kernel.Proposal.Prohibited.ProviderSsl</method>
/// -- this goes red.</p>
Method TestProviderSslAnswersExactlyTheNamedConfiguration()
{
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", ..#PROBE), 0, "no row: the probe is not named")
    Do ..Name(..#PROBE)
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", ..#PROBE), 1, "the stored name is")
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", $ZConvert(..#PROBE, "L")), 0, "compared exactly")
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", ..#OTHER), 0, "and another configuration is not")
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG), 0, "nor is OcuPilot's own, which the installer's refusal holds")
    Do ..Name(##class(OcuPilot.Kernel.State.Base).#SSLCONFIG)
    Do $$$AssertEquals($ClassMethod(..#SET, "ProviderSsl", ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG), 0, "even when the row stores it")
}

/// <p>Store <var>pName</var> as the egress row's configuration name, the route's checks bypassed: the name may be one no
/// configuration holds.</p>
ClassMethod Name(pName As %String)
{
    Set tValues("sslConfiguration") = pName
    Set tSC = ##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
}

/// <p>Mint tool <var>pTool</var>'s proposal for the target <var>pId</var> with <var>pArgs</var> through the fixture port,
/// answering it, or <code>""</code> with the refusal in <var>pHttpStatus</var> and <var>pFault</var>. The fixture's fresh
/// read answers the instance's own read of <var>pId</var> for a change, and nothing for a create.</p>
ClassMethod Mint(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    If pTool = ..#UPDATETOOL {
        Do ##class(OcuPilot.Test.SslSave).Fresh(pId, .tFresh)
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    }
    Do ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set tSC = ##class(OcuPilot.Test.ProposalMint).Mint("OcuPilot.Screen.Descriptor.SslConfigList", $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
    Quit $Select($$$ISOK(tSC) && $IsObject($Get(tProposal)): tProposal, 1: "")
}

}
