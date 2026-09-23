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
/// <p>Mutation (Rule 19): change one word of
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGPATHREASON</parameter> and recompile --
/// this goes red naming both spellings.</p>
Method TestTheServingPathRefusalIsOneSentenceOnBothSurfaces()
{
    Set tServer = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH"))
    Do $$$AssertNotEquals(tServer, "", "the kernel answers a written sentence for the serving-path code")
    Do $$$AssertEquals(tServer, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATHREASON"), "which is the parameter that holds it, not a literal in the lookup")
    ; AD-53: "a kernel refusal reason that names 'the agent' is a defect once a screen caller
    ; shares the predicate". The two surfaces render one sentence, so it can name neither caller.
    Do $$$AssertEquals(($ZConvert(tServer, "L") [ "the agent"), 0, "and it names no caller: " _ tServer)
}

}

