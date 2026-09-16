/// <p>Test-only <class>OcuPilot.Kernel.Egress</class> subclass whose resolver answers a set the
/// test chose, instead of this instance's own.</p>
/// <p>It exists for one branch: <method>OcuPilot.Kernel.Egress.Classify</method> ranks every
/// address a host resolves to and reports the <b>worst</b> kind, which is what makes a name whose
/// records mix a public and a loopback answer a refusal rather than a coin toss. No name this
/// instance can resolve answers two different kinds, so without a seam the ranking is code with no
/// case either way -- and a change from "worst wins" to "first wins" would ship green.</p>
/// <p><b>Only <method>OcuPilot.Kernel.Egress.MultiLookup</method> is replaced</b> (DW-338). It
/// used to be <method>Addresses</method>, which replaced the union loop, the address-family loop
/// and the single-form fallback along with the lookup -- so the method a production call actually
/// runs was the one method no test executed. Overriding the lookup alone leaves that body, the
/// canonicalisation, the range tests, the instance-address read and the ranking above them all
/// shipped, so an address this subclass supplies is judged exactly as a resolved one would be.</p>
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

/// <p>The set the test supplied, as the <class>%List</class> the shipped lookup answers, or the
/// shipped lookup itself when the test supplied none.</p>
/// <p><b>The set is answered for address family 1 alone</b>, and an empty list for family 2. The
/// caller's own loop asks both and unions the answers, so a probe answering the same set twice
/// would pass whether or not that loop was still there; answering once means the union has to
/// carry it.</p>
ClassMethod MultiLookup(pHost As %String, pFamily As %Integer) As %List
{
    Set tList = $Get(^||OcuPilotEgressProbe("addresses"))
    If tList = "" Quit ##super(pHost, pFamily)
    If pFamily '= 1 Quit ""
    Set tAnswer = ""
    For tI = 1:1:$Length(tList, ",") {
        Set tAddress = $Piece(tList, ",", tI)
        If tAddress '= "" Set tAnswer = tAnswer _ $ListBuild(tAddress)
    }
    Quit tAnswer
}

}
