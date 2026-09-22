/// <p>The three branches of <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> that
/// normalise an internal failure to <code>$$$OK</code> (AD-11 rule 3, AD-39): a registry that cannot
/// be read, a gate that cannot decide, and a <code>Directive</code> that errors without a fault
/// code. Each is a <b>refusal</b>, not a turn failure -- the status is OK, the call answers an error
/// result carrying <code>TOOL.UNAVAILABLE</code>, the fault reaches the log, and nothing is
/// announced.</p>
/// <p>Without that normalisation <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> reads
/// the error status and abandons the whole turn, so one unreadable registry read would end a
/// conversation that had already done useful work.</p>
/// <p>Driven through <class>OcuPilot.Test.ToolDispatchProbe</class>, whose seams are switches and
/// whose <method>LogFault</method> records rather than writes. <b>Live-safe</b>: it spawns nothing,
/// writes no row and reads only the fixture registries.</p>
Class OcuPilot.Test.ToolDispatchClientFault Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The registry whose <method>ListTools</method> already fails, so
/// <method>OcuPilot.Screen.Tool.Registry.ResolveWire</method> answers an error status.</p>
Parameter BADREGISTRY = "OcuPilot.Test.BadFulfilment.Registry";

/// <p>The registry holding the tool whose <code>Directive</code> errors with no fault code.</p>
Parameter FAULTREGISTRY = "OcuPilot.Test.ClientCallFault.Registry";

Parameter FAULTWIRE = "probe_clientfault_read";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

/// <p>Resolve one client-fulfilled call to wire name <var>pWire</var> through the probe, and answer
/// the refusal shape as <code>&lt;status OK&gt;|&lt;pending&gt;|&lt;is_error&gt;|&lt;content&gt;</code>
/// -- one string, so a single assertion says which part of the shape moved.</p>
ClassMethod Refusal(pWire As %String) As %String
{
    Set tBlock = {"id": "toolu_clientfault"}
    Do tBlock.%Set("name", pWire, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tSC = $ClassMethod(..#PROBE, "ResolveClientCall", $Username, tBlock, ..#LIMITS, .tPending, .tToolName, .tRoute, .tEntityId, .tTarget, .tArguments, .tArgTrunc, .tIsError, .tContent, .tReason, .tFailedPair, "probeclientfaultturn")
    Quit $System.Status.IsOK(tSC) _ "|" _ +$Get(tPending) _ "|" _ +$Get(tIsError) _ "|" _ $Get(tContent)
}

/// <p>The refusal shape every branch here answers: an OK status, nothing pending, an error result
/// carrying <code>TOOL.UNAVAILABLE</code> alone.</p>
ClassMethod Expected() As %String
{
    Quit "1|0|1|" _ "{""code"":""" _ ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE _ """}"
}

/// <p>A registry whose list cannot be built is a refusal, logged, with no route resolved.</p>
/// <p>Mutation (Rule 19): delete the <code>Set tSC = $$$OK</code> from
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method>'s registry branch -- the
/// refusal becomes a turn failure and this goes red on the status.</p>
Method TestARegistryThatCannotBeReadIsARefusalNotATurnFailure()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#BADREGISTRY)
    Do $$$AssertEquals(..Refusal("probe_badfulfilment_write"), ..Expected(), "an unreadable registry is one unavailable tool result")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "could not resolve its registry | " _ ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE, "and the registry fault reached the log: " _ $ClassMethod(..#PROBE, "Logged"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate"), 0, "with no gate asked")
}

/// <p>A gate that cannot decide is the same refusal, logged, and reaches no pair check.</p>
/// <p>Mutation (Rule 19): delete the <code>Set tSC = $$$OK</code> from that method's gate branch --
/// this goes red on the status.</p>
Method TestAGateThatCannotDecideIsARefusalNotATurnFailure()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#FAULTREGISTRY)
    Do $ClassMethod(..#PROBE, "FailGate")
    Do $$$AssertEquals(..Refusal(..#FAULTWIRE), ..Expected(), "a gate that cannot decide is one unavailable tool result")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate"), 1, "the gate was asked once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "pair"), 0, "and no pair was checked after it failed")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "governance gate could not decide", "and the gate fault reached the log: " _ $ClassMethod(..#PROBE, "Logged"))
}

/// <p>A <code>Directive</code> that errors <b>without</b> a fault code is the same refusal: the
/// resolver's <code>Else</code> leg logs it and normalises, and no announcement survives -- there is
/// nothing in the answer the model could read as a route.</p>
/// <p>Every shipped <code>Directive</code> that refuses carries a code, so this leg is only
/// reachable through a fixture; unnormalised it would fail the turn on a tool's own bug.</p>
/// <p>Mutation (Rule 19): delete the <code>Set tSC = $$$OK</code> from that method's
/// <code>Else</code> leg -- this goes red on the status.</p>
Method TestADirectiveThatFailsWithNoFaultCodeIsARefusalNotATurnFailure()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#FAULTREGISTRY)
    Set tBlock = {"id": "toolu_clientfault"}
    Do tBlock.%Set("name", ..#FAULTWIRE, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tSC = $ClassMethod(..#PROBE, "ResolveClientCall", $Username, tBlock, ..#LIMITS, .tPending, .tToolName, .tRoute, .tEntityId, .tTarget, .tArguments, .tArgTrunc, .tIsError, .tContent, .tReason, .tFailedPair, "probeclientfaultturn")
    Do $$$AssertStatusOK(tSC, "the dispatcher's own status is OK: the tool refused, the dispatcher did not fail")
    Do $$$AssertEquals(+$Get(tPending) _ "|" _ +$Get(tIsError), "0|1", "nothing is pending and the result is an error")
    Do $$$AssertEquals($Get(tContent), "{""code"":""" _ ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE _ """}", "carrying TOOL.UNAVAILABLE alone: " _ $Get(tContent))
    Do $$$AssertEquals($Get(tRoute) _ "|" _ $Get(tEntityId), "|", "with no route and no entity for the model to read")
    Do $$$AssertEquals($Get(tToolName), "probe.clientfault.read", "recorded under the canonical name the tool resolved to")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "failed inside Directive | " _ ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE, "and the directive's fault reached the log: " _ $ClassMethod(..#PROBE, "Logged"))
}

}
