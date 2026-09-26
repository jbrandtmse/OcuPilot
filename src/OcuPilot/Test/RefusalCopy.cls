/// <p>One refusal, two surfaces, one sentence (AD-39, AD-53). A self-protection rule is explained
/// twice -- by the row action the client draws refused before a click, and by the envelope the
/// instance returns after one -- and the two copies must not drift.</p>
/// <p><b>This class holds the instance's half</b>: that the kernel answers a written sentence for
/// <code>PROHIBITED.SERVINGPATH</code>, that the sentence is the parameter the client's copy is
/// compared against rather than a literal inside the lookup, and that it names no caller. The
/// comparison itself is <file>ui/tools/self-protection.test.mjs</file>'s, which reads both files
/// from the repository: neither the client source nor EXPERIENCE.md is mounted on a running
/// instance, so a comparison here could only ever skip, and a test that skips everywhere is a test
/// that cannot fail.</p>
/// <p>Reads only.</p>
Class OcuPilot.Test.RefusalCopy Extends %UnitTest.TestCase
{

/// <p>AD-53: the sentence the kernel returns for <code>PROHIBITED.SERVINGPATH</code> is byte for
/// byte the one the client draws on the row it refuses, and it names no caller -- the same
/// predicate refuses the agent and the screen alike.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>
/// answer a literal for the serving-path code instead of
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGPATHREASON</parameter>, with one word
/// changed, and recompile -- this goes red naming both spellings.</p>
Method TestTheServingPathRefusalIsOneSentenceOnBothSurfaces()
{
    Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH"))
    Do $$$AssertNotEquals(tServer, "", "the kernel answers a written sentence for the serving-path code")
    Do $$$AssertEquals(tServer, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATHREASON"), "which is the parameter that holds it, not a literal in the lookup")
    ; AD-53: "a kernel refusal reason that names 'the agent' is a defect once a screen caller
    ; shares the predicate". The two surfaces render one sentence, so it can name neither caller.
    Do $$$AssertEquals(($ZConvert(tServer, "L") [ "the agent"), 0, "and it names no caller: " _ tServer)
}

/// <p>AD-10 as amended, AD-53 (Story 7.2): each of the four account codes answers its own
/// parameter, and none names a caller -- the screen's row action and the agent's confirm are refused
/// by the one predicate. Story 9.1's service-account sign-in code (DW-1520) is the fifth.</p>
/// <p>Mutation (Rule 19): answer a literal for any one of the four codes in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>, or restore its agent-worded
/// sentence, and recompile -- that code's legs go red.</p>
Method TestEachAccountRefusalIsItsParameterAndNamesNoCaller()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCode = "SYSTEMACCOUNT", "CURRENTUSER", "SERVICEACCOUNT", "LASTALLHOLDER", "SERVICEACCOUNTSIGNIN" {
        Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(tClass, tCode))
        Do $$$AssertNotEquals(tServer, "", tCode _ ": the kernel answers a written sentence")
        Do $$$AssertEquals(tServer, $Parameter(tClass, tCode _ "REASON"), tCode _ ": which is its parameter, not a literal in the lookup")
        Do $$$AssertEquals(($ZConvert(tServer, "L") [ "the agent"), 0, tCode _ ": and it names no caller: " _ tServer)
    }
}

/// <p>AC7, AD-53 (Story 7.8, DW-1499): each of the two process codes answers its own parameter,
/// and neither names a caller -- the screen's Suspend, Resume and Terminate and the agent's confirm
/// are refused by the one predicate.</p>
/// <p>Mutation (Rule 19): restore the agent-worded literal for either code in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method> and recompile -- that code's legs
/// go red.</p>
Method TestEachProcessRefusalIsItsParameterAndNamesNoCaller()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCode = "OCUPILOTPROCESS", "SYSTEMPROCESS" {
        Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(tClass, tCode))
        Do $$$AssertNotEquals(tServer, "", tCode _ ": the kernel answers a written sentence")
        Do $$$AssertEquals(tServer, $Parameter(tClass, tCode _ "REASON"), tCode _ ": which is its parameter, not a literal in the lookup")
        Do $$$AssertEquals(($ZConvert(tServer, "L") [ "the agent"), 0, tCode _ ": and it names no caller: " _ tServer)
    }
}

/// <p>AD-10 as amended 2026-09-24, AD-53 (Story 9.2, DW-1502): each of the four codes refused on
/// OcuPilot's own web applications answers its own parameter, and none names a caller -- the
/// editor's Save and role actions and the agent's confirm are refused by the one predicate.
/// <code>PRIVILEGEGRANTREASON</code> is also pinned equal to the client's copy by
/// <file>ui/tools/self-protection.test.mjs</file>, because a role control draws it before a
/// click.</p>
/// <p>Mutation (Rule 19): answer a literal for any one of the four codes in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>, or restore its agent-worded
/// sentence, and recompile -- that code's legs go red.</p>
Method TestEachOwnApplicationRefusalIsItsParameterAndNamesNoCaller()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCode = "PRIVILEGEGRANT", "UNAUTHENTICATED", "AUTHORIZATION", "DISPATCH" {
        Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(tClass, tCode))
        Do $$$AssertNotEquals(tServer, "", tCode _ ": the kernel answers a written sentence")
        Do $$$AssertEquals(tServer, $Parameter(tClass, tCode _ "REASON"), tCode _ ": which is its parameter, not a literal in the lookup")
        Do $$$AssertEquals(($ZConvert(tServer, "L") [ "the agent"), 0, tCode _ ": and it names no caller: " _ tServer)
    }
}

/// <p>DW-1502: the credential-type refusal the agent definition form draws is the parameter
/// <file>ui/tools/self-protection.test.mjs</file> pins equal to the client's copy, so the violation
/// lookup answers that parameter rather than a literal of its own.</p>
/// <p>Mutation (Rule 19): answer a literal for the code in
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> and recompile -- this goes red.</p>
Method TestTheCredentialTypeRefusalIsItsParameter()
{
    Set tServer = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#AGENTCREDTYPEUNAVAILABLE)
    Do $$$AssertNotEquals(tServer, "", "the violation lookup answers a written sentence")
    Do $$$AssertEquals(tServer, ##class(OcuPilot.Api.Error).#REASONAGENTCREDTYPEUNAVAILABLE, "which is the parameter the client's copy is pinned to")
}

/// <p>DW-1598, AD-53 (Stories 9.3, 9.5): the unreviewed-field, own-role, own-resource and own SSL/TLS
/// configuration codes each answer their own parameter, published in EXPERIENCE.md's Fixed strings,
/// and none names a caller -- a screen's Save reaches each as well as the agent's confirm.</p>
/// <p>Mutation (Rule 19): restore the literal for <code>UNCOVEREDFIELD</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method> and recompile -- that code's legs go
/// red.</p>
Method TestEachKernelRefusalIsItsParameterAndNamesNoCaller()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCode = "UNCOVEREDFIELD", "OCUPILOTROLE", "OCUPILOTRESOURCE", "OCUPILOTSSL" {
        Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(tClass, tCode))
        Do $$$AssertNotEquals(tServer, "", tCode _ ": the kernel answers a written sentence")
        Do $$$AssertEquals(tServer, $Parameter(tClass, tCode _ "REASON"), tCode _ ": which is its parameter, not a literal in the lookup")
        Do $$$AssertEquals(($ZConvert(tServer, "L") [ "agent"), 0, tCode _ ": and it names no caller: " _ tServer)
    }
}

/// <p>AD-53 (Story 9.3, DW-1513, DW-1528): the predefined-role and system-resource delete refusals
/// are the violation lookup's own parameters, which <file>ui/tools/self-protection.test.mjs</file>
/// pins equal to the client's copy the row draws before a click.</p>
/// <p>Mutation (Rule 19): answer a literal for <code>RESOURCE.NAME.SYSTEM</code> in
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> and recompile -- its leg goes red.</p>
Method TestTheDeleteRefusalsAreTheirParameters()
{
    For tCase = $ListBuild("ROLENAMESYSTEM", "REASONROLENAMESYSTEM"), $ListBuild("RESOURCENAMESYSTEM", "REASONRESOURCENAMESYSTEM") {
        Set tServer = ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter("OcuPilot.Api.Error", $List(tCase, 1)))
        Do $$$AssertNotEquals(tServer, "", $List(tCase, 1) _ ": the violation lookup answers a written sentence")
        Do $$$AssertEquals(tServer, $Parameter("OcuPilot.Api.Error", $List(tCase, 2)), $List(tCase, 1) _ ": which is the parameter the client's copy is pinned to")
    }
}

/// <p>AD-10 as amended, AD-53 (Story 9.9): the serving-service code answers its own parameter and
/// names no caller -- the service form's Enabled drawn unavailable, the Save's envelope and the
/// agent's mint refusal are one sentence.</p>
/// <p>Mutation (Rule 19): answer a literal for <code>SERVINGSERVICE</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method> and recompile -- this goes
/// red.</p>
Method TestTheServingServiceRefusalIsItsParameterAndNamesNoCaller()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Prohibited"
    Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(tClass, "SERVINGSERVICE"))
    Do $$$AssertNotEquals(tServer, "", "the kernel answers a written sentence")
    Do $$$AssertEquals(tServer, $Parameter(tClass, "SERVINGSERVICEREASON"), "which is its parameter, not a literal in the lookup")
    Do $$$AssertEquals(($ZConvert(tServer, "L") [ "agent"), 0, "and it names no caller: " _ tServer)
}

}
