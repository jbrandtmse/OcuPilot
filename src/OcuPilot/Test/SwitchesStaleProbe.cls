/// <p>Test-only <class>OcuPilot.Api.Switches</class> subclass that stands where a second
/// administrator would: it lets the inherited <method>OcuPilot.Api.Switches.HandleUpdate</method>
/// read the switch row and its version, then writes the row itself, then lets the handler save.</p>
/// <p><b>It replaces no seam the handler added for a test.</b> The interleave point is
/// <method>OcuPilot.Api.Switches.MergeBody</method>, which is ordinary production code called
/// between the read and the save; this class calls the shipped one through <code>##super</code> and
/// then makes one ordinary switch write. Everything the refusal depends on -- the version read, the
/// validation, the conditional save and the 409 -- is the inherited body.</p>
/// <p><b>Why a class of its own rather than a switch on
/// <class>OcuPilot.Test.SwitchesProbe</class>.</b> That probe is selected by other methods for its
/// log capture, and a conflict armed there would be a conflict they all met. This one is reachable
/// only through <class>OcuPilot.Test.RouterFixture</class>'s own route, which nothing else
/// calls.</p>
/// <p>The window it exploits is real and is the one the conditional write closes: a handler that
/// reads, does work, then writes. It cannot be produced over a socket, because it opens and closes
/// inside one request and OcuPilot publishes no version token a second request could carry.</p>
Class OcuPilot.Test.SwitchesStaleProbe Extends OcuPilot.Api.Switches
{

/// <p>The reason the interleaving write stores, so the losing save is identifiable by the value
/// that survived it rather than only by the status it answered.</p>
Parameter OTHERREASON = "Written by the other administrator";

/// <p>The shipped merge, then one ordinary switch write -- which moves the row past the version
/// the handler read a few lines earlier.</p>
ClassMethod MergeBody(pBody As %DynamicObject, ByRef pValues)
{
    Do ##super(pBody, .pValues)
    Kill tOther
    Set tOther("killSwitch") = 1
    Set tOther("killSwitchReason") = ..#OTHERREASON
    Do ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tOther)
}

}
