/// <p>AC4 -- what <code>GET /agent/context</code> projects for a marked-local definition on the
/// shipped <code>compatible</code> row: the provider key, the endpoint's host, and
/// <code>leavesInstance</code> <b>false</b>, with an outbound proxy configured and without.</p>
/// <p><b>Pinned at the route body rather than in a browser.</b> The chip renders
/// <code>leavesInstance === true</code>, so the client shows no pill for anything else; what makes
/// AC4 true is the server's answer, and that answer is
/// <method>OcuPilot.Port.ProviderPort.ResolveEndpoint</method> followed by
/// <method>OcuPilot.Kernel.Egress.LeavesInstance</method>, both reached through the shipped
/// projection (<class>OcuPilot.Test.ContextProbe</class>).</p>
/// <p><b>Read-only and opens no socket.</b> Nothing here calls a provider. It writes one agent
/// definition and the instance's one outbound-settings row, removing both in
/// <method>OnAfterOneTest</method>; every address named is a loopback or a
/// documentation-reserved literal (RFC 5737), and none is connected to.</p>
Class OcuPilot.Test.EgressLocal Extends %UnitTest.TestCase
{

/// <p>The projection under test, through the subclass that exposes it.</p>
Parameter PROBE = "OcuPilot.Test.ContextProbe";

/// <p>The shipped provider key this class drives -- the one row that allows local.</p>
Parameter PROVIDERKEY = "compatible";

/// <p>The loopback endpoint the definition names. Never called.</p>
Parameter LOCALENDPOINT = "http://127.0.0.1:11434/v1";

/// <p>The host that endpoint's authority carries, which the projection reports.</p>
Parameter LOCALHOST = "127.0.0.1";

/// <p>A proxy host (RFC 5737 TEST-NET-1) that classifies public, so a projection that counted it
/// would answer <code>leavesInstance</code> true.</p>
Parameter PUBLICPROXY = "192.0.2.10";

/// <p>The user the projection is read for. Its sharing choice is not what this class asserts.</p>
Parameter PROBEUSER = "_SYSTEM";

Property PreparedDefinitionId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = ""
    Quit $$$OK
}

/// <p>Store one enabled, default, marked-local definition on the shipped row, and clear the
/// instance's outbound settings so each method states its own proxy.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedDefinitionId = ""
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Local" _ ..#PROVIDERKEY
    Set tRow.Provider = ..#PROVIDERKEY
    Set tRow.Model = "llama-3.3-70b-instruct"
    Set tRow.EndpointUrl = ..#LOCALENDPOINT
    Set tRow.MarkedLocal = 1
    Set tRow.CredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE
    Set tRow.EnvVarName = ""
    Set tRow.CredentialName = ""
    Set tRow.Enabled = 1
    Set tRow.ConnectionVerified = 1
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tRow.%Id()
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedDefinitionId)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
}

/// <p>Leave no definition and no outbound-settings row for the next method, or the next class, to
/// read.</p>
Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "no outbound settings row survives this method")
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "the probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Store <var>pProxy</var> as the instance's outbound proxy.</p>
Method StoreProxy(pProxy As %String)
{
    Set tStored("proxyServer") = pProxy
    Set tStored("proxyPort") = 3128
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "the proxy " _ pProxy _ " is stored")
}

/// <p>The status body, asserted readable.</p>
Method StatusBody() As %DynamicObject
{
    Set tSC = $ClassMethod(..#PROBE, "StatusBody", ..#PROBEUSER, .tBody)
    Do $$$AssertStatusOK(tSC, "the context status projects")
    Do $$$AssertTrue($IsObject(tBody), "and answers a body")
    Quit tBody
}

/// <p>AC4 -- the projection names the provider and the endpoint's host, and answers
/// <code>leavesInstance</code> false, <b>whether or not an outbound proxy is configured</b>. The
/// second leg is the one DW-441 is about: the call bypasses the proxy, so a projection that judged
/// the proxy would say the data leaves while the request it describes never goes near it.</p>
/// <p><b>The two halves of that answer are pinned separately, and the last leg is why.</b> The
/// projection is false for a marked-local definition on either of two grounds --
/// <method>OcuPilot.Port.ProviderPort.ResolveEndpoint</method> reports no proxy for such a
/// definition, and <method>OcuPilot.Kernel.Egress.LeavesInstance</method> reads the flag before the
/// proxy -- so the first two legs pass with either one in place and can pin neither. The last leg
/// asks the policy directly, with a proxy host it cannot have been given by the resolver.</p>
/// <p>mutation: restore <method>OcuPilot.Kernel.Egress.LeavesInstance</method>'s original order,
/// testing the proxy host before <var>pMarkedLocal</var> -- red on the direct leg alone; remove
/// <method>OcuPilot.Port.ProviderPort.ResolveEndpoint</method>'s marked-local proxy blanking as
/// well and the with-a-proxy projection leg reddens too.</p>
Method TestAMarkedLocalDefinitionAnswersLeavesInstanceFalseEvenWithAProxyConfigured()
{
    Set tBody = ..StatusBody()
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.provider, ..#PROVIDERKEY, "the enabled default's provider key, with no proxy configured")
    Do $$$AssertEquals(tBody.endpointHost, ..#LOCALHOST, "and its endpoint's host")
    Do $$$AssertEquals(tBody.%GetTypeOf("leavesInstance"), "boolean", "leavesInstance is a JSON boolean rather than null, so a definition was resolved")
    Do $$$AssertEquals(tBody.leavesInstance, 0, "and answers false for a marked-local endpoint")

    Do ..StoreProxy(..#PUBLICPROXY)
    Set tProxied = ..StatusBody()
    If '$IsObject(tProxied) Quit
    Do $$$AssertEquals(tProxied.provider, ..#PROVIDERKEY, "the same provider with a public proxy configured")
    Do $$$AssertEquals(tProxied.endpointHost, ..#LOCALHOST, "and the same host")
    Do $$$AssertEquals(tProxied.leavesInstance, 0, "and still false: a marked-local call does not go through the proxy, so the proxy is not a destination of this call")

    ; The policy asked directly, with the proxy host the resolver no longer reports: this is the
    ; assertion the order in LeavesInstance is what makes true.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance(..#LOCALHOST, 1, ..#PUBLICPROXY), 0, "and the policy itself answers false for a marked-local host handed a public proxy, the declaration being read before the proxy")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance(..#LOCALHOST, 0, ..#PUBLICPROXY), 1, "while the same host unmarked, behind the same proxy, leaves -- so the flag is what decides and not the proxy being ignored")
}

/// <p>The control, and the other half of the mutation above: the <b>same</b> public proxy behind a
/// definition that is <i>not</i> marked local does make the projection answer
/// <code>leavesInstance</code> true. Without it, a <code>LeavesInstance</code> that ignored the
/// proxy entirely would look identical to one that reads the flag first.</p>
Method TestAnUnmarkedDefinitionBehindAPublicProxyStillLeaves()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tRow)
    Do $$$AssertStatusOK(tSC, "the prepared definition opens")
    If '$IsObject(tRow) Quit
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    ; A private endpoint rather than the loopback one, because unmarking local would otherwise make
    ; the address itself refusable; what this leg is about is the proxy.
    Set tRow.EndpointUrl = "https://10.0.0.5/v1"
    Set tRow.MarkedLocal = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot), "it is unmarked and repointed at a private endpoint")
    Set tRow = ""
    ; The security-field change disabled it, as it must; the projection reads only an enabled
    ; default.
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1), "re-enabled after the security-field edit")

    Set tDirect = ..StatusBody()
    If '$IsObject(tDirect) Quit
    Do $$$AssertEquals(tDirect.leavesInstance, 0, "with no proxy, a private endpoint does not leave the instance")

    Do ..StoreProxy(..#PUBLICPROXY)
    Set tProxied = ..StatusBody()
    If '$IsObject(tProxied) Quit
    Do $$$AssertEquals(tProxied.leavesInstance, 1, "and behind a public proxy it does, which is what shows the proxy is still judged for a call that goes through one")
}

}
