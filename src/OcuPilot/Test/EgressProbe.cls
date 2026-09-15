/// <p>Test-only <class>OcuPilot.Kernel.Egress</class> subclass whose resolver answers a set the
/// test chose, instead of this instance's own.</p>
/// <p>It exists for one branch: <method>OcuPilot.Kernel.Egress.Classify</method> ranks every
/// address a host resolves to and reports the <b>worst</b> kind, which is what makes a name whose
/// records mix a public and a loopback answer a refusal rather than a coin toss. No name this
/// instance can resolve answers two different kinds, so without a seam the ranking is code with no
/// case either way -- and a change from "worst wins" to "first wins" would ship green.</p>
/// <p>Only <method>Addresses</method> is replaced. The canonicalisation, the range tests, the
/// instance-address read and the ranking above it are the shipped ones, so an address this
/// subclass supplies is judged exactly as a resolved one would be.</p>
Class OcuPilot.Test.EgressProbe Extends OcuPilot.Kernel.Egress
{

/// <p>Answer <var>pAddresses</var> -- a comma-separated list -- for every host from now on.</p>
ClassMethod SetAddresses(pAddresses As %String)
{
    Set ^||OcuPilotEgressProbe("addresses") = pAddresses
}

/// <p>Answer the instance's own resolver again.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEgressProbe
}

/// <p>The set the test supplied, or the shipped lookup when it supplied none.</p>
ClassMethod Addresses(pHost As %String, Output pAddresses)
{
    Set tList = $Get(^||OcuPilotEgressProbe("addresses"))
    If tList = "" Quit ##super(pHost, .pAddresses)
    Kill pAddresses
    For tI = 1:1:$Length(tList, ",") {
        Set tAddress = $Piece(tList, ",", tI)
        If tAddress '= "" Set pAddresses(tAddress) = ""
    }
}

}
