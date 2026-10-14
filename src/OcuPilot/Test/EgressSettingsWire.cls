/// <p>Pins Story 18.40's provider connection over the wire (AD-32, AD-34, AD-39, AD-42): <code>GET</code> and
/// <code>PUT /agent/switches/egress</code> through the shipped router as the suite's own privileged account. The proxy
/// rules and their field violations, a cleared proxy, a named configuration stored only as an enabled client that
/// requires the server's certificate, OcuPilot's own and none stored as <code>""</code>, a stale version, a busy target,
/// the audit row, and a saved connection reaching the request <class>OcuPilot.Test.ProviderPortProbe</class>'s stub
/// records. The refusals of a principal without OcuPilot's administrative resource, and of one without the SSL/TLS
/// form's pairs, are <class>OcuPilot.Test.AgentWireSecurity</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes SSL/TLS configurations by
/// exact name. Every leg restores the egress row to none and removes its probe configurations; it never touches
/// OcuPilot's own provider configuration.</p>
Class OcuPilot.Test.EgressSettingsWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter ROUTE = "/api/ocupilot/agent/switches/egress";

Parameter OWN = "OcuPilotProvider";

/// <p>The probe configurations <class>OcuPilot.Test.EgressSslProbe</class> makes: a verifying client, a client that does
/// not verify, a disabled verifying client and a server.</p>
Parameter VERIFIED = "OcuPilotProbeEgressVerified";

Parameter NOVERIFY = "OcuPilotProbeEgressNoVerify";

Parameter DISABLED = "OcuPilotProbeEgressDisabled";

Parameter SERVER = "OcuPilotProbeEgressServer";

Parameter ABSENT = "OcuPilotProbeEgressAbsent";

/// <p>A proxy host (RFC 5737 TEST-NET-1) that classifies public.</p>
Parameter PUBLICPROXY = "192.0.2.10";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EgressSettingsWire creates and deletes SSL/TLS configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbes()
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    Quit ..RemoveProbes()
}

/// <p>Create the four probe configurations afresh.</p>
Method EnsureProbes() As %Status
{
    Set tSC = $$$OK
    For tCase = $ListBuild(..#VERIFIED, "verified"), $ListBuild(..#NOVERIFY, "noverify"), $ListBuild(..#DISABLED, "disabled"), $ListBuild(..#SERVER, "server") {
        Set tSC = ##class(OcuPilot.Test.EgressSslProbe).Ensure($List(tCase, 1), $List(tCase, 2))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Delete the four probe configurations.</p>
Method RemoveProbes() As %Status
{
    Set tSC = $$$OK
    For tName = ..#VERIFIED, ..#NOVERIFY, ..#DISABLED, ..#SERVER {
        Set tOne = ##class(OcuPilot.Test.EgressSslProbe).Remove(tName)
        If $$$ISERR(tOne) Set tSC = tOne
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "the egress row this method wrote is removed")
    Do $$$AssertEquals(..RowCount(), 0, "and none survives it")
    Quit $$$OK
}

/// <p><b>C1.</b> A proxy saved through the route is served back by the read, by the same route a second time, and by the
/// instance's own settings; the save answers the stored truth with a version that moved; the three keys are all the read
/// carries; and the timeout, the attempt bound and the two proxy TLS flags keep the values the row held. A bare IPv6
/// address and a name that does not resolve are stored. Each save writes one audit row under the security event, naming
/// both sides of each field it changed (C5).</p>
/// <p>Mutation (Rule 19): store no <code>proxyPort</code> in <method>OcuPilot.Api.Switches.HandleEgressUpdate</method>
/// -- the port assertions here, and the Integration leg, go red. Drop the <code>LogChange</code> call there -- the audit
/// legs go red.</p>
Method TestAProxySavedThroughTheRouteIsServedBackAndAudited()
{
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals(tStatus _ " " _ tRead.%ToJSON(), "200 {""proxyServer"":"""",""proxyPort"":0,""sslConfiguration"":"""",""rowVersion"":0}", "a clean instance reads the defaults, in the four keys the screen takes")

    Set tSeed("timeoutSeconds") = 45
    Set tSeed("maxAttempts") = 2
    Set tSeed("proxyHttps") = 1
    Set tSeed("proxyTunnel") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tSeed), "a row holding the values the route never sets is written")
    Do ..Get(.tStatus, .tRead)
    Set tVersion = tRead.rowVersion
    Do $$$AssertEquals(tVersion, 1, "at version 1")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Put({"proxyServer": (..#PUBLICPROXY), "proxyPort": 3128}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer _ " " _ tAnswer.proxyPort _ " '" _ tAnswer.sslConfiguration _ "' " _ tAnswer.rowVersion, "200 " _ ..#PUBLICPROXY _ " 3128 '' " _ (tVersion + 1), "the save answers what is stored, at the next version")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("proxyPort") _ " " _ tAnswer.%GetTypeOf("rowVersion"), "number number", "the port and the version arrive as JSON numbers")
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals(tRead.proxyServer _ " " _ tRead.proxyPort, ..#PUBLICPROXY _ " 3128", "the read answers it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).Resolve(.tStored), "and the instance's own settings")
    Do $$$AssertEquals(tStored("proxyServer") _ " " _ tStored("proxyPort"), ..#PUBLICPROXY _ " 3128", "hold it")
    Do $$$AssertEquals(tStored("timeoutSeconds") _ " " _ tStored("maxAttempts") _ " " _ tStored("proxyHttps") _ " " _ tStored("proxyTunnel"), "45 2 1 1", "while the timeout, the attempt bound and the two proxy TLS flags keep their stored values")

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, "instance", "egress", .tRows)
    Do $$$AssertEquals(tRows, 1, "one audit row records the save under the security event: " _ tRows)
    Do $$$AssertTrue(tData [ """proxyServer"":{""old"":"""",""new"":""" _ ..#PUBLICPROXY _ """}", "naming the proxy before and after: " _ tData)
    Do $$$AssertTrue(tData [ """proxyPort"":{""old"":""0"",""new"":""3128""}", "and the port before and after")
    Do $$$AssertTrue(tData [ """securityChange"":true", "flagged a security change")
    Do $$$AssertTrue(tData [ ("""actor"":""" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ """"), "by the caller of the request")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 0, "instance", "egress", .tOther), "", "and nothing under the configuration event")

    Do ..Put({"proxyServer": "2001:db8::10", "proxyPort": 8080}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer _ " " _ tAnswer.proxyPort, "200 2001:db8::10 8080", "a bare IPv6 address is stored")
    Do ..Put({"proxyServer": "64:ff9b::192.0.2.33", "proxyPort": 8080}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer, "200 64:ff9b::192.0.2.33", "and one that ends in a dotted IPv4 address")
    Do ..Put({"proxyServer": "proxy.ocupilot-probe.invalid", "proxyPort": 3128}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer, "200 proxy.ocupilot-probe.invalid", "and a name that resolves to nothing, as an endpoint is")
    Do ..Put({"proxyPort": 3129}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer _ " " _ tAnswer.proxyPort, "200 proxy.ocupilot-probe.invalid 3129", "a key the body omits keeps its value")
}

/// <p>Every proxy rule in the matrix is a 422 on the field it names, in OcuPilot's own sentence quoting nothing sent, and
/// stores nothing: the row's version and values are as they were.</p>
/// <p>Mutation (Rule 19): drop the address judgement from <method>OcuPilot.Kernel.SwitchRules.ValidateEgress</method>
/// -- the loopback, link-local, <code>localhost</code> and own-address legs go red; drop the group-count floor from
/// <method>OcuPilot.Kernel.SwitchRules.ProxyHostShaped</method> -- the <code>cafe:3128</code> leg goes red.</p>
Method TestEveryProxyRefusalIsAFieldViolationAndStoresNothing()
{
    Do ..Put({"proxyServer": "proxy.ocupilot-probe.invalid"}, .tStatus, .tAnswer)
    Set tFirst = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("detail") = "object"): tAnswer.detail.violations.%Get(0), 1: "")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tFirst): tFirst.field _ " " _ tFirst.code, 1: ""), "422 proxyPort EGRESS.PROXYPORT", "a proxy with no stored port and none sent is refused on the port")
    Do ..Put({"proxyServer": (..#PUBLICPROXY), "proxyPort": 3128}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a proxy is stored first")
    Set tVersion = tAnswer.rowVersion
    Set tLong = $Translate($Justify("", 254), " ", "h")
    Set tCases = ""
    For tHost = "http://evil.ocupilot-probe.invalid", "evil.ocupilot-probe.invalid/path", "evil.ocupilot-probe.invalid:3128", "user@evil.ocupilot-probe.invalid", "evil ocupilot-probe", "[2001:db8::1]", tLong, "192.0.2.10:3128", "cafe:3128", "12345::1", "1:2:3:4:5:6:7:8:9:a", "1.2:3::4", "::1.2.3" {
        Set tCases = tCases _ $ListBuild($ListBuild(tHost, 3128, "proxyServer", "EGRESS.PROXYHOST"))
    }
    For tPort = 0, 65536, -1, 3128.5 {
        Set tCases = tCases _ $ListBuild($ListBuild("proxy.ocupilot-probe.invalid", tPort, "proxyPort", "EGRESS.PROXYPORT"))
    }
    For tHost = "127.0.0.1", "localhost", "169.254.169.254", "::1" {
        Set tCases = tCases _ $ListBuild($ListBuild(tHost, 3128, "proxyServer", "EGRESS.PROXYADDRESS"))
    }
    Set tInstance = ##class(OcuPilot.Test.ProviderProxy).InstanceAddress()
    Do $$$AssertTrue(tInstance '= "", "this instance reports an interface address, so its own address is one of the proxies judged")
    If tInstance '= "" Set tCases = tCases _ $ListBuild($ListBuild(tInstance, 3128, "proxyServer", "EGRESS.PROXYADDRESS"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBody = {"proxyServer": ($List(tCase, 1))}
        If $List(tCase, 2) '= "" Do tBody.%Set("proxyPort", $List(tCase, 2), "number")
        Do ..Put(tBody, .tStatus, .tAnswer, .tText)
        Set tFirst = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("detail") = "object"): tAnswer.detail.violations.%Get(0), 1: "")
        Set tSaw = $Select($IsObject(tFirst): tFirst.field _ " " _ tFirst.code, 1: "")
        Do $$$AssertEquals(tStatus _ " " _ tSaw, "422 " _ $List(tCase, 3) _ " " _ $List(tCase, 4), $Extract($List(tCase, 1), 1, 30) _ " " _ $List(tCase, 2) _ " is refused on its field")
        Do $$$AssertEquals($Select($IsObject(tFirst): tFirst.reason, 1: ""), ##class(OcuPilot.Api.EgressError).ReasonFor($List(tCase, 4)), "with the published sentence")
        Do $$$AssertEquals(tText [ $List(tCase, 1), 0, "which quotes nothing the caller sent")
    }
    Do $$$AssertEquals(tVersion _ " " _ ..Stored(), tVersion _ " " _ ..#PUBLICPROXY _ " 3128", "and none of them changed the row")
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals(tRead.rowVersion, tVersion, "or its version")
    Do ..Put({"proxyServer": 5}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.proxyServer, "200 " _ ..#PUBLICPROXY, "a proxy that is not a JSON string is ignored, as a switch field is")
    Do ..Put("[]", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 400, "and a body that is not an object is a bad body")
}

/// <p>An empty <code>proxyServer</code> clears the proxy and stores port 0, whatever port the body carries, and keeps the
/// configuration name.</p>
/// <p>Mutation (Rule 19): drop the port 0 for an empty proxy from <method>OcuPilot.Api.Switches.EgressMerge</method> --
/// this goes red.</p>
Method TestAClearedProxyStoresAnEmptyServerAndPortZero()
{
    Do ..Put({"proxyServer": (..#PUBLICPROXY), "proxyPort": 3128, "sslConfiguration": (..#VERIFIED)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.sslConfiguration, "200 " _ ..#VERIFIED, "a proxy and a configuration are stored")
    Do ..Put({"proxyServer": "", "proxyPort": 3128}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " '" _ tAnswer.proxyServer _ "' " _ tAnswer.proxyPort _ " " _ tAnswer.sslConfiguration, "200 '' 0 " _ ..#VERIFIED, "clearing it answers an empty server and port 0, and keeps the name")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).Resolve(.tStored), "the instance's settings are read")
    Do $$$AssertEquals(tStored("proxyServer") _ "|" _ tStored("proxyPort"), "|0", "and hold the same")
}

/// <p><b>C2.</b> A configuration is named only when it is an enabled client with <code>VerifyPeer</code> 1: a verifying
/// client is stored and read back by name; an absent name is <code>EGRESS.SSLABSENT</code>; a server, a disabled client
/// and a client that does not verify are <code>EGRESS.SSLUNVERIFIED</code>; each refusal is on
/// <code>sslConfiguration</code> and stores nothing. OcuPilot's own provider configuration and an empty name are stored
/// as <code>""</code>, which clears a name.</p>
/// <p>Mutation (Rule 19): drop the <code>VerifyPeer</code> rule from
/// <method>OcuPilot.Kernel.SwitchRules.EnabledVerifyingClient</method> -- the client that does not verify is stored and
/// the unverified leg goes red.</p>
Method TestAConfigurationIsNamedOnlyAsAnEnabledClientThatVerifiesThePeer()
{
    Do ..Put({"sslConfiguration": (..#VERIFIED)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.sslConfiguration, "200 " _ ..#VERIFIED, "a verifying client is named")
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals(tRead.sslConfiguration, ..#VERIFIED, "and the read answers it")
    Set tVersion = tRead.rowVersion

    For tCase = $ListBuild(..#ABSENT, "EGRESS.SSLABSENT"), $ListBuild(..#SERVER, "EGRESS.SSLUNVERIFIED"), $ListBuild(..#DISABLED, "EGRESS.SSLUNVERIFIED"), $ListBuild(..#NOVERIFY, "EGRESS.SSLUNVERIFIED"), $ListBuild($Translate($Justify("", 65), " ", "n"), "EGRESS.SSLABSENT") {
        Do ..Put({"sslConfiguration": ($List(tCase, 1))}, .tStatus, .tAnswer)
        Set tFirst = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("detail") = "object"): tAnswer.detail.violations.%Get(0), 1: "")
        Set tSaw = $Select($IsObject(tFirst): tFirst.field _ " " _ tFirst.code, 1: "")
        Do $$$AssertEquals(tStatus _ " " _ tSaw, "422 sslConfiguration " _ $List(tCase, 2), $Extract($List(tCase, 1), 1, 40) _ " is refused on its field")
        Do $$$AssertEquals($Select($IsObject(tFirst): tFirst.reason, 1: ""), ##class(OcuPilot.Api.EgressError).ReasonFor($List(tCase, 2)), "with the published sentence")
    }
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals(tRead.sslConfiguration _ " " _ tRead.rowVersion, ..#VERIFIED _ " " _ tVersion, "and none of them changed the row")

    Do ..Put({"sslConfiguration": (..#OWN)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " '" _ tAnswer.sslConfiguration _ "'", "200 ''", "naming OcuPilot's own provider configuration clears the name")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).Resolve(.tStored), "the instance's settings are read")
    Do $$$AssertEquals(tStored("sslConfiguration"), ..#OWN, "and take the installer's configuration")
    Do ..Put({"sslConfiguration": (..#VERIFIED)}, .tStatus, .tAnswer)
    Do ..Put({"sslConfiguration": ""}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " '" _ tAnswer.sslConfiguration _ "'", "200 ''", "an empty name clears it too")
}

/// <p>A save carrying the version the screen read is refused <code>STATE.CONFLICT</code> once the row has moved, and
/// stores nothing; a save that names a configuration someone else holds is refused <code>WRITE.TARGETBUSY</code> after
/// the wait, and stores nothing.</p>
/// <p>Mutation (Rule 19): ignore the body's <code>rowVersion</code> in
/// <method>OcuPilot.Api.Switches.HandleEgressUpdate</method> -- the stale leg answers 200 and goes red; drop the hold
/// there -- the busy leg answers 200 and goes red.</p>
Method TestAStaleVersionAndABusyConfigurationAreRefusedAndStoreNothing()
{
    Do ..Get(.tStatus, .tRead)
    Set tRead0 = tRead.rowVersion
    Do ..Put({"proxyServer": (..#PUBLICPROXY), "proxyPort": 3128, "rowVersion": (tRead0)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.rowVersion, "200 " _ (tRead0 + 1), "a save carrying the version read is taken")
    Do ..Put({"proxyServer": "192.0.2.11", "proxyPort": 3128, "rowVersion": (tRead0)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "409 STATE.CONFLICT", "and the same version again is refused as stale")
    Do $$$AssertEquals(..Stored(), ..#PUBLICPROXY _ " 3128", "which stored nothing")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).TargetRefOf("OcuPilot.Screen.Descriptor.SslConfigList", ..#VERIFIED, .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey($Get(tRef))
    Do $$$AssertNotEquals(tLockKey, "", "the configuration names a lock")
    If tLockKey = "" Quit
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tAnswer = ""
    Try {
        Do ..Put({"sslConfiguration": (..#VERIFIED)}, .tStatus, .tAnswer)
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: tAnswer), "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held configuration is refused busy, with the published reason")
    Do ..Get(.tStatus, .tRead)
    Do $$$AssertEquals("'" _ tRead.sslConfiguration _ "'", "''", "and no name was stored")
}

/// <p><b>Integration.</b> A proxy and a probe configuration saved through the route reach the request the stub records
/// when <class>OcuPilot.Test.ProviderPortProbe</class> calls: the proxy and its port, the tunnel and the proxy TLS flag
/// the https call forces, the configuration and the server-identity check.</p>
/// <p>Mutation (Rule 19): store no <code>proxyPort</code> in <method>OcuPilot.Api.Switches.HandleEgressUpdate</method>
/// -- the port assertion here goes red beside the read's.</p>
Method TestASavedConnectionReachesTheRequestTheProviderPortBuilds()
{
    Do ..Put({"proxyServer": (..#PUBLICPROXY), "proxyPort": 3128, "sslConfiguration": (..#VERIFIED)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the connection is saved through the route")
    Set tPort = "OcuPilot.Test.ProviderPortProbe"
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("probe-local-abcdefghijklmnop")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn""}")
    Kill tValues, tMessages
    Set tValues("provider") = "probe-local"
    Set tValues("model") = "probe-local-model-1"
    Set tValues("endpointUrl") = "https://192.0.2.1/v1/messages"
    Set tValues("markedLocal") = 0
    Set tValues("credType") = "env"
    Set tValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tValues("maxTokens") = 4000
    Set tValues("temperature") = 0
    Set tMessages = 1, tMessages(1, "role") = "user", tMessages(1, "content") = "probe"
    Set tSC = $ClassMethod(tPort, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertTrue('$IsObject(tFault), "and is not refused: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the call reached the transport")
    Set tRecorded = ""
    For tKey = "proxyServer", "proxyPort", "proxyTunnel", "proxyHttps", "sslConfiguration", "sslCheckServerIdentity" {
        Set tRecorded = tRecorded _ ##class(OcuPilot.Test.ProviderStub).Recorded(tKey) _ "|"
    }
    Do $$$AssertEquals(tRecorded, ..#PUBLICPROXY _ "|3128|1|1|" _ ..#VERIFIED _ "|1|", "the request carries the proxy, its port, the tunnel and TLS flags, the configuration and the identity check")
    Do $ClassMethod(tPort, "Reset")
}

/// <p>The proxy and the configuration name the instance holds, as <code>host port</code>.</p>
ClassMethod Stored() As %String
{
    Do ##class(OcuPilot.Kernel.State.Egress).Resolve(.tStored)
    Quit tStored("proxyServer") _ " " _ tStored("proxyPort")
}

/// <p>The number of rows the egress table holds.</p>
ClassMethod RowCount() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Egress")
    If tRS.%SQLCODE < 0 Quit -1
    Do tRS.%Next()
    Quit tRS.%GetData(1)
}

/// <p><code>GET</code> the route as the suite's own credentials, <var>pAnswer</var> the parsed body.</p>
ClassMethod Get(Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pText As %String)
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#ROUTE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pText)
    Set pAnswer = $Select($ZStrip(pText, "<>W") '= "": ##class(%DynamicAbstractObject).%FromJSON(pText), 1: "")
}

/// <p><code>PUT</code> <var>pBody</var> (an object, or JSON text) to the route as the suite's own credentials.</p>
ClassMethod Put(pBody, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pText As %String)
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", ..#ROUTE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pText, , tText, "application/json")
    Set pAnswer = $Select($ZStrip(pText, "<>W") '= "": ##class(%DynamicAbstractObject).%FromJSON(pText), 1: "")
}

}
