/// <p>Pins the kernel's one system-global predicate for global mappings (AD-10, AD-53):
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsSystemGlobalMapping</method> and the effect
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> answers from it. A name
/// beginning with <code>%</code>, or whose global part begins with <code>:</code> (an empty low end,
/// read as <code>%</code>) or <code>*</code>, reaches the <code>%</code> globals; a removal and a
/// routine mapping carry no effect.</p>
/// <p><b>What it needs from the environment:</b> nothing. It builds composite ids only and writes
/// nothing.</p>
Class OcuPilot.Test.MappingSystemGlobal Extends %UnitTest.TestCase
{

Parameter KERNEL = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter EFFECT = "MAPPING.SYSTEMGLOBAL";

/// <p>The namespace the composite ids name; no such namespace is created.</p>
Parameter NS = "OCUPROBE1817A";

/// <p>Each name that reaches the <code>%</code> globals answers 1 and the system-global effect, on a
/// create and a change alike.</p>
/// <p>Mutation (Rule 19): remove the <code>:</code>/<code>*</code> line from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsSystemGlobalMapping</method> -> the <code>:A</code>,
/// <code>:</code>, <code>*</code> and <code>*X</code> legs go red.</p>
Method TestANameReachingThePercentGlobalsCarriesTheEffect()
{
    For tName = "%X", "%X(""a"")", ":A", ":", "*", "*X" {
        Set tId = $ClassMethod(..#PROBE, "Id", ..#NS, tName)
        Do $$$AssertEquals($ClassMethod(..#KERNEL, "IsSystemGlobalMapping", tId), 1, tName _ ": reaches the % globals")
        Set tSC = $ClassMethod(..#KERNEL, "WeakensByEffect", "global-mapping", {}, {}, .tEffect, tId, 0)
        Do $$$AssertStatusOK(tSC, tName _ ": the effect is answered")
        Do $$$AssertEquals(tEffect, ..#EFFECT, tName _ ": carries the system-global effect")
    }
}

/// <p>A name that does not reach the <code>%</code> globals answers 0 and no effect: a range or
/// pattern beginning with a letter, and a subscript beginning with <code>%</code> or <code>:</code>
/// under an ordinary global.</p>
Method TestANameNotReachingThePercentGlobalsCarriesNone()
{
    For tName = "A:", "A:Z", "X*", "G(""%a"")", "G("":"")" {
        Set tId = $ClassMethod(..#PROBE, "Id", ..#NS, tName)
        Do $$$AssertEquals($ClassMethod(..#KERNEL, "IsSystemGlobalMapping", tId), 0, tName _ ": does not reach the % globals")
        Set tSC = $ClassMethod(..#KERNEL, "WeakensByEffect", "global-mapping", {}, {}, .tEffect, tId, 0)
        Do $$$AssertStatusOK(tSC, tName _ ": the effect is answered")
        Do $$$AssertEquals(tEffect, "", tName _ ": carries no effect")
    }
}

/// <p>A removal of a reaching name shadows nothing, and a routine mapping of the same shape names no
/// global: neither carries the effect.</p>
Method TestARemovalAndARoutineMappingCarryNone()
{
    Set tId = $ClassMethod(..#PROBE, "Id", ..#NS, ":A")
    Set tSC = $ClassMethod(..#KERNEL, "WeakensByEffect", "global-mapping", {}, {}, .tEffect, tId, 1)
    Do $$$AssertStatusOK(tSC, "the removal's effect is answered")
    Do $$$AssertEquals(tEffect, "", ":A removed: carries no effect")
    Set tSC = $ClassMethod(..#KERNEL, "WeakensByEffect", "routine-mapping", {}, {}, .tEffect, tId, 0)
    Do $$$AssertStatusOK(tSC, "the routine mapping's effect is answered")
    Do $$$AssertEquals(tEffect, "", ":A as a routine mapping: carries no effect")
}

}
