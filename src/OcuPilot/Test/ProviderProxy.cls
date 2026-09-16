/// <p>DW-337 -- a configured proxy is judged by the address policy the endpoint is judged by, with
/// the definition's own marked-local flag and its row's local escape, and an https call always
/// CONNECT-tunnels through it (AD-32, AD-42).</p>
/// <p>Driven in process through <class>OcuPilot.Test.ProviderPortProbe</class>, whose catalog
/// names <class>OcuPilot.Test.ProviderStub</class> as the adapter, so <b>no socket is opened</b>:
/// a refused proxy is observed as a stub that was never entered, and a permitted one as the request
/// the stub recorded.</p>
/// <p>Every leg writes the instance's one outbound-settings row and <method>OnAfterOneTest</method>
/// removes it, asserting it is gone. Endpoints and permitted proxies are documentation-reserved
/// literals, which classify without a name lookup.</p>
Class OcuPilot.Test.ProviderProxy Extends %UnitTest.TestCase
{

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>A credential of the shape the <code>probe-local</code> row's prefix requires.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>An https endpoint (RFC 5737 TEST-NET-1) that classifies public.</p>
Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>A proxy host (RFC 5737 TEST-NET-1) that classifies public.</p>
Parameter PUBLICPROXY = "192.0.2.10";

/// <p>A bare IPv6 proxy literal (RFC 3849) that classifies public.</p>
Parameter PUBLICIPV6PROXY = "2001:db8::10";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "no outbound settings row survives this method")
    Do ##class(OcuPilot.Kernel.State.Egress).Resolve(.tSettings)
    Do $$$AssertEquals($Get(tSettings("proxyServer")), "", "and the shipped defaults, which name no proxy, are in force again")
    Quit $$$OK
}

/// <p>Store <var>pProxy</var> as the instance's proxy, with <var>pTunnel</var> and
/// <var>pHttps</var> as its stored tunnel and TLS flags.</p>
Method StoreProxy(pProxy As %String, pTunnel As %Boolean = 0, pHttps As %Boolean = 0)
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tStored("proxyServer") = pProxy
    Set tStored("proxyPort") = 3128
    Set tStored("proxyTunnel") = pTunnel
    Set tStored("proxyHttps") = pHttps
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "the proxy " _ pProxy _ " is stored")
}

/// <p>One draft call on provider row <var>pProvider</var> against <var>pEndpoint</var>.</p>
Method CallDraft(pProvider As %String, pEndpoint As %String, pMarkedLocal As %Boolean, Output pResponse, Output pHttpStatus, Output pFault) As %Status
{
    Kill tValues, tMessages
    Set tValues("provider") = pProvider
    Set tValues("model") = "probe-local-model-1"
    Set tValues("endpointUrl") = pEndpoint
    Set tValues("markedLocal") = pMarkedLocal
    Set tValues("credType") = "env"
    Set tValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tValues("maxTokens") = 4000
    Set tValues("temperature") = 0
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "probe"
    Quit $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .pResponse, .pHttpStatus, .pFault)
}

/// <p>An address this instance's own interfaces carry, or <code>""</code> when none can be
/// read.</p>
ClassMethod InstanceAddress() As %String
{
    Set tAddress = ""
    Try {
        Set tInfo = $System.INetInfo.GetInterfacesInfo()
        For tI = 1:1:$Length(tInfo, $Char(0)) {
            Set tInterface = $Piece(tInfo, $Char(0), tI)
            For tJ = 2:1:$Length(tInterface, $Char(1)) {
                Set tCandidate = $Piece($Piece(tInterface, $Char(1), tJ), "/", 1)
                If $Match(tCandidate, "^[0-9]{1,3}(\.[0-9]{1,3}){3}$") && ($Piece(tCandidate, ".", 1) '= 127) {
                    Set tAddress = tCandidate
                    Quit
                }
            }
            If tAddress '= "" Quit
        }
    } Catch ex {
        Set tAddress = ""
    }
    Quit tAddress
}

/// <p><b>A proxy the policy refuses is never called through</b>: loopback, link-local, a name that
/// resolves to nothing, and this instance's own address each answer <code>PROVIDER.EGRESS</code>
/// naming the proxy, before any socket, on a definition whose endpoint alone would be called.</p>
/// <p>Link-local has no escape here either, so marking the definition local on a row that allows
/// local does not open it.</p>
/// <p>Mutation: delete the proxy judgement from
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- the loopback leg goes red, the stub
/// entered once with the refused proxy on the request.</p>
Method TestAProxyThePolicyRefusesIsNeverCalledThrough()
{
    Set tProxies = $ListBuild("127.0.0.1", "169.254.169.254", "no-such-proxy-ocupilot.invalid")
    Set tInstance = ..InstanceAddress()
    Do $$$AssertTrue(tInstance '= "", "this instance reports an interface address, so its own address is one of the proxies judged")
    If tInstance '= "" Set tProxies = tProxies _ $ListBuild(tInstance)
    For tI = 1:1:$ListLength(tProxies) {
        Set tProxy = $List(tProxies, tI)
        Do ..StoreProxy(tProxy)
        Set tSC = ..CallDraft("probe-local", ..#PUBLICENDPOINT, 0, .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, tProxy _ ": the port returns $$$OK")
        Do $$$AssertTrue($IsObject(tFault), tProxy _ ": and a fault")
        If '$IsObject(tFault) Continue
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, tProxy _ ": the proxy is refused by the address policy (" _ tFault.%ToJSON() _ ")")
        Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Kernel.Provider.Base).#REASONPROXYEGRESS, tProxy _ ": with the reason that names the proxy rather than the endpoint")
        Do $$$AssertEquals(tHttpStatus, 502, tProxy _ ": answered as a gateway failure")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, tProxy _ ": and no socket was opened")
        Set tLogged = $Piece($ClassMethod(..#PORT, "Logged"), $Char(10), *)
        Do $$$AssertTrue(tLogged [ ("resolved address kind: " _ $List($ListBuild("loopback", "linklocal", "unresolvable", "instance"), tI)), tProxy _ ": and the kind it resolved to reaches the log: " _ tLogged)
    }

    Do ..StoreProxy("169.254.169.254")
    Set tMarkedSC = ..CallDraft("probe-local", ..#PUBLICENDPOINT, 1, .tMarkedResponse, .tMarkedStatus, .tMarkedFault)
    Do $$$AssertStatusOK(tMarkedSC, "a link-local proxy on a definition marked local returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tMarkedFault): tMarkedFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "and is still refused: link-local has no escape")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")
}

/// <p><b>The proxy is judged with the definition's own inputs</b>: the local escape that licenses a
/// loopback endpoint -- marked local, on a row that allows local -- licenses a loopback proxy, and
/// nothing wider. The same proxy is refused for the same row unmarked in the leg above.</p>
Method TestALoopbackProxyNeedsTheDefinitionsOwnLocalEscape()
{
    Do ..StoreProxy("127.0.0.1")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn""}")
    Set tSC = ..CallDraft("probe-local", ..#PUBLICENDPOINT, 1, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertTrue('$IsObject(tFault), "and the loopback proxy is permitted for a definition marked local on a row that allows local: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the call reached the transport")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyServer"), "127.0.0.1", "through the proxy that was judged")
}

/// <p><b>An https endpoint always CONNECT-tunnels through the proxy and negotiates TLS inside the
/// tunnel</b>, whatever the stored flags say, so the proxy never terminates the session that carries
/// the key. A plain-http endpoint has no session to protect and keeps both stored values.</p>
/// <p>Mutation: delete the <code>proxyTunnel</code> override from
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- the https leg goes red, recording 0; delete
/// the <code>proxyHttps</code> override and the same leg goes red on that flag.</p>
Method TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy()
{
    Do ..StoreProxy(..#PUBLICPROXY, 0, 0)
    Set tSC = ..CallDraft("probe-local", ..#PUBLICENDPOINT, 0, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the https call returns $$$OK")
    Do $$$AssertTrue('$IsObject(tFault), "and the public proxy is permitted: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyServer"), ..#PUBLICPROXY, "the request goes through the stored proxy")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyTunnel"), 1, "and tunnels, although the stored flag reads 0")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyHttps"), 1, "and negotiates TLS inside the tunnel, although that stored flag reads 0 too")

    Do ..StoreProxy(..#PUBLICPROXY, 1, 1)
    Set tPlainSC = ..CallDraft("probe-local", "http://127.0.0.1:11434/v1/messages", 1, .tPlainResponse, .tPlainStatus, .tPlainFault)
    Do $$$AssertStatusOK(tPlainSC, "the marked-local plain-http call returns $$$OK")
    Do $$$AssertTrue('$IsObject(tPlainFault), "and is permitted: " _ $Select($IsObject(tPlainFault): tPlainFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyTunnel"), 1, "keeping the stored tunnel flag, since there is no TLS session to protect")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyHttps"), 1, "and the stored TLS flag")
}

/// <p><b>A bare IPv6 proxy literal is judged as the whole address</b>, not as the text before its
/// first colon: a documentation-reserved literal (RFC 3849) classifies public and is called
/// through.</p>
Method TestABareIpv6ProxyIsJudgedAsOneAddress()
{
    Do ..StoreProxy(..#PUBLICIPV6PROXY)
    Set tSC = ..CallDraft("probe-local", ..#PUBLICENDPOINT, 0, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertTrue('$IsObject(tFault), "and the public IPv6 proxy is permitted: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: "") _ " " _ $ClassMethod(..#PORT, "Logged"))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the call reached the transport")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("proxyServer"), ..#PUBLICIPV6PROXY, "through the stored proxy, unchanged")
}

}
