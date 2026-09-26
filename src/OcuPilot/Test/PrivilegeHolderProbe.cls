/// <p>A declared answer to "does this user hold this pair", for
/// <method>OcuPilot.Kernel.Proposal.Operation.MissingPair</method>'s holder seam: every pair is held
/// except one on the resource <parameter>NOTHELD</parameter>. <class>OcuPilot.Test.ProposalPrivilege</class>
/// drives the privilege line's missing pair with it, because the suite runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PrivilegeHolderProbe Extends %RegisteredObject
{

/// <p>The one resource this probe says nobody holds.</p>
Parameter NOTHELD = "OcuPilotProbeNotHeld";

ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Quit (pResource '= ..#NOTHELD)
}

}
