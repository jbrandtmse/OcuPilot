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
/// shipped, so an address this subclass supplies is judged exactly as a resolved one would be. The
/// move of the single-record lookup inside that seam (DW-413) is what lets a probe's set be the
/// <i>whole</i> set for a host the instance's own resolver also answers for.</p>
/// <p>It also <b>counts</b> what it serves -- family lookups here, interface reads through
/// <method>OcuPilot.Kernel.Egress.InterfacesInfo</method> -- which is how DW-334's verdict cache is
/// observed: a cache is a claim about how often something is read, and only a count falsifies
/// it.</p>
/// <p><method>ArmInterfacesOnce</method> makes one interface read answer a description the test
/// chose, which is the only way to drive the answers this instance will not produce on demand: no
/// description at all, and a description naming an interface that carries no address.</p>
Class OcuPilot.Test.EgressProbe Extends OcuPilot.Kernel.Egress
{

/// <p>Answer <var>pAddresses</var> -- a comma-separated list -- for every host from now on, and
/// forget every cached verdict so a judgement reached before this call cannot mask the new
/// set.</p>
ClassMethod SetAddresses(pAddresses As %String)
{
    Set ^||OcuPilotEgressProbe("addresses") = pAddresses
    Do ..ClearJudgementCache()
}

/// <p>Answer the instance's own resolver again, forget the counts, and empty the judgement
/// cache.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEgressProbe
    Do ..ClearJudgementCache()
}

/// <p>How many family lookups this probe has served since the last <method>Clear</method>. Two per
/// classification that reaches the resolver, one per address family.</p>
ClassMethod MultiLookups() As %Integer
{
    Quit +$Get(^||OcuPilotEgressProbe("multiLookups"))
}

/// <p>How many times the instance's interface set has actually been read since the last
/// <method>Clear</method> -- the count DW-334's cache is about.</p>
ClassMethod InterfaceReads() As %Integer
{
    Quit +$Get(^||OcuPilotEgressProbe("interfaceReads"))
}

/// <p>Make the next <method>InterfacesInfo</method> call answer <var>pInfo</var> instead of the
/// instance's own read, standing in for a <code>$System.INetInfo.GetInterfacesInfo</code> answer
/// this probe cannot provoke for real -- nothing at all, or a description naming an interface that
/// carries no address. Consumed once; the call after it answers the instance's own read again.</p>
ClassMethod ArmInterfacesOnce(pInfo As %String = "")
{
    Set ^||OcuPilotEgressProbe("interfacesOnce") = pInfo
}

/// <p>Make the next <method>InterfacesInfo</method> call answer <code>""</code>, standing in for a
/// transient failure of the read. Consumed once.</p>
ClassMethod ArmEmptyInterfacesOnce()
{
    Do ..ArmInterfacesOnce("")
}

/// <p>Count the read and answer the instance's own, so the cache's effect is observed on the
/// shipped parse loop rather than on a stand-in for it -- unless
/// <method>ArmEmptyInterfacesOnce</method> armed this one call to answer nothing.</p>
ClassMethod InterfacesInfo() As %String
{
    Do $Increment(^||OcuPilotEgressProbe("interfaceReads"))
    ; $Data, not a truth test: "" is one of the answers this arms, and so is a description whose
    ; numeric value is 0.
    If $Data(^||OcuPilotEgressProbe("interfacesOnce")) {
        Set tArmed = ^||OcuPilotEgressProbe("interfacesOnce")
        Kill ^||OcuPilotEgressProbe("interfacesOnce")
        Quit tArmed
    }
    Quit ##super()
}

/// <p>The set the test supplied, as the <class>%List</class> the shipped lookup answers, or the
/// shipped lookup itself when the test supplied none.</p>
/// <p><b>The set is answered for address family 1 alone</b>, and an empty list for family 2. The
/// caller's own loop asks both and unions the answers, so a probe answering the same set twice
/// would pass whether or not that loop was still there; answering once means the union has to
/// carry it.</p>
ClassMethod MultiLookup(pHost As %String, pFamily As %Integer) As %List
{
    Do $Increment(^||OcuPilotEgressProbe("multiLookups"))
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
