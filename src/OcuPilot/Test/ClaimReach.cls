/// <p>Pins which shipped classes name the proposal claim (AD-6, AD-34, AD-40): the
/// claim is <method>OcuPilot.Kernel.Proposal.Write.Claim</method> and <method>ClaimById</method>,
/// and <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> beneath them, and the
/// only shipped class that names them is <class>OcuPilot.Kernel.Proposal.Confirm</class>, which
/// only the confirm handler and the install smoke check call.</p>
/// <p>Each token is read over every compiled shipped class with
/// <method>OcuPilot.Test.AsTheUser.SitesNaming</method>, which reports a class whose source it
/// cannot read rather than scoring it as no match. The rows that name a site are the scan's
/// positive control: a scan that found nothing would fail them, so the empty rows are a
/// measurement. A call spelled as a static call and one spelled by a quoted class name are asked
/// separately, since a path to the claim can be written either way; a name assembled at run time is
/// outside what a source scan sees.</p>
/// <p><b>What it needs from the environment:</b> the shipped classes compiled on the instance. It
/// writes nothing.</p>
Class OcuPilot.Test.ClaimReach Extends %UnitTest.TestCase
{

/// <p>The confirm path's class: the one shipped class that names the claim.</p>
Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

/// <p>Only the confirm path names the claim, and only the confirm handler and the install smoke
/// check name the confirm path.</p>
/// <p>Mutation (Rule 19): add <code>If 0 Do ##class(OcuPilot.Kernel.Proposal.Write).ClaimById("",
/// "", .tR, .tC)</code> to a <class>OcuPilot.Kernel.Proposal.Caller</class> method -- this goes red
/// on its first token.</p>
Method TestOnlyTheConfirmPathNamesTheClaim()
{
    ; Each row is the token and the comma-separated classes expected to name it, in name order.
    Set tCases($Increment(tCases)) = $ListBuild("Proposal.Write).Claim", ..#CONFIRM)
    Set tCases($Increment(tCases)) = $ListBuild("""OcuPilot.Kernel.Proposal.Write""", "")
    Set tCases($Increment(tCases)) = $ListBuild("""GuardedClaimAndClose""", ..#CONFIRM)
    Set tCases($Increment(tCases)) = $ListBuild(").GuardedClaimAndClose(", "")
    Set tCases($Increment(tCases)) = $ListBuild("Kernel.Proposal.Confirm)", "OcuPilot.Api.Confirm,OcuPilot.Install.Smoke")
    Set tCases($Increment(tCases)) = $ListBuild("""OcuPilot.Kernel.Proposal.Confirm""", "")
    For tI = 1:1:tCases {
        Set tToken = $List(tCases(tI), 1)
        Set tSites = ##class(OcuPilot.Test.AsTheUser).SitesNaming(tToken)
        Do $$$AssertEquals(tSites, $List(tCases(tI), 2), "the shipped classes naming <" _ tToken _ "> are exactly the expected ones: " _ tSites)
    }
}

}
