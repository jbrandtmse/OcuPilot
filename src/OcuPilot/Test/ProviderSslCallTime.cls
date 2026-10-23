/// <p>Pins Story 18.40's call-time check (AD-32): a provider call is made only through a TLS
/// configuration that is, at that call, an enabled client requiring the server's certificate -- the one the egress row
/// names, else OcuPilot's own -- however the configuration came to be otherwise. The configuration is changed outside
/// every OcuPilot path (the vendor's own <code>Modify</code>, as the classic portal does), the call is refused
/// <code>PROVIDER.TLS</code> naming the configuration and its remedy, and the transport is never entered; changed back,
/// the next call goes through.</p>
/// <p>Driven in process through <class>OcuPilot.Test.ProviderPortProbe</class>, whose adapter is
/// <class>OcuPilot.Test.ProviderStub</class>, so no socket is opened. The caller holds <code>%All</code>; the same refusal
/// for callers who cannot read <class>Security.SSLConfigs</class> is <class>OcuPilot.Test.ProviderSslCallers</class>'s.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes an SSL/TLS configuration and briefly changes OcuPilot's own, which every leg restores to the
/// installer's values in <method>OnAfterOneTest</method> whatever the leg did, and the class restores again in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.ProviderSslCallTime Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter PROBE = "OcuPilotProbeCallTime";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProviderSslCallTime creates and deletes an SSL/TLS configuration and briefly changes OcuPilot's own on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Restore OcuPilot's own provider configuration, remove the egress row and the probe once more when the class ends,
/// whatever a leg left, on an armed instance only.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do ..RestoreOwn()
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    Quit ##class(OcuPilot.Test.EgressSslProbe).Remove(..#PROBE)
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ..RestoreOwn()
    Quit ##class(OcuPilot.Test.EgressSslProbe).Ensure(..#PROBE)
}

Method OnAfterOneTest() As %Status
{
    Do ..RestoreOwn()
    Do $ClassMethod(..#PORT, "Reset")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "the egress row this method wrote is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Remove(..#PROBE), "the probe configuration is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.EgressSslProbe).Exists(..#PROBE), 0, "and none survives")
    Do $$$AssertEquals(..OwnReads(), "0 1 1 %OSCertificateStore 16", "OcuPilot's own provider configuration reads the installer's values again")
    Quit $$$OK
}

/// <p>A configuration the egress row names that is changed on the classic portal to stop requiring the server's
/// certificate, to be disabled, to become a server or to allow a protocol older than TLS 1.2 (Story 18.47), refuses the next
/// call -- <code>PROVIDER.TLS</code> at 503, the sentence naming it and the remedy -- and the transport is not entered; set
/// back, the call goes through, and a floor of TLS 1.3 is never refused. OcuPilot's own provider configuration is refused
/// the same, with the restart remedy.</p>
/// <p>Mutation (Rule 19): skip the <code>SslConfigurationState</code> check in
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- every refused leg reaches the stub and goes red; drop the
/// <code>Type</code> condition from <code>SslConfigurationState</code> -- the <code>Type</code> leg alone goes red, because the
/// server it sets has a floor below TLS 1.2 and would otherwise be refused with the floor's sentence; drop the
/// <code>TLSMinVersion</code> comparison from it -- the floor legs alone go red.</p>
Method TestAConfigurationChangedOutsideOcuPilotIsRefusedBeforeAnythingIsSent()
{
    Set tValues("sslConfiguration") = ..#PROBE
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues), "the egress row names the probe")
    Do $$$AssertEquals(..Call(), "", "the call through the verifying probe is not refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and reaches the transport")

    Set tChange("VerifyPeer") = 0
    Set tBack("VerifyPeer") = 1
    Do ..RefusedThenRestored("VerifyPeer", .tChange, .tBack)
    Set tChange("Enabled") = 0
    Set tBack("Enabled") = 1
    Do ..RefusedThenRestored("Enabled", .tChange, .tBack)
    ; A server that is enabled and requires a client certificate is still not a client.
    Set tChange("Type") = 1
    Set tChange("Ciphersuites") = ""
    Set tChange("CipherList") = "ADH:@SECLEVEL=0"
    Set tChange("TLSMinVersion") = 8
    Set tChange("TLSMaxVersion") = 16
    Set tBack("Type") = 0
    ; The server leg emptied the TLS 1.3 suites and lowered the protocol range; the vendor's own values go back with the type.
    Set tBack("Ciphersuites") = "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
    Set tBack("CipherList") = "ALL:!aNULL:!eNULL:!EXP:!SSLv2"
    Set tBack("TLSMinVersion") = 16
    Set tBack("TLSMaxVersion") = 32
    Do ..RefusedThenRestored("Type", .tChange, .tBack, "no longer an enabled client")
    ; A client that verifies but allows TLS 1.1 is refused with its own sentence; a floor of TLS 1.3 is not refused.
    Set tChange("TLSMinVersion") = 8
    Set tBack("TLSMinVersion") = 16
    Do ..RefusedThenRestored("TLSMinVersion", .tChange, .tBack, "older than TLS 1.2")
    Set tHigh("TLSMinVersion") = 32
    Set tReset("TLSMinVersion") = 16
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .tHigh), "the probe's floor is raised to TLS 1.3")
    Do $$$AssertEquals(..Call(), "", "and a floor above TLS 1.2 is not refused")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .tReset), "set back")

    Do ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tProps("VerifyPeer") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(tOwn, .tProps), "OcuPilot's own provider configuration is set to not verify outside OcuPilot")
    Set tBefore = ##class(OcuPilot.Test.ProviderStub).Calls()
    Set tFault = ..Call(.tHttpStatus)
    Do $$$AssertEquals(..Said(tFault) _ " " _ tHttpStatus, "PROVIDER.TLS 503", "the call is refused")
    Do $$$AssertTrue((..Reason(tFault) [ tOwn) && (..Reason(tFault) [ "Restart the instance"), "naming it and the restart remedy: " _ ..Reason(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), tBefore, "and the transport is not entered")
    Do ..RestoreOwn()
    Do $$$AssertEquals(..Call(), "", "restored, the next call is not refused")
    Kill tProps
    Set tProps("TLSMinVersion") = 8
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(tOwn, .tProps), "OcuPilot's own provider configuration is given a floor of TLS 1.1 outside OcuPilot")
    Set tBefore = ##class(OcuPilot.Test.ProviderStub).Calls()
    Set tFault = ..Call(.tHttpStatus)
    Do $$$AssertEquals(..Said(tFault) _ " " _ tHttpStatus, "PROVIDER.TLS 503", "the call is refused")
    Do $$$AssertTrue((..Reason(tFault) [ tOwn) && (..Reason(tFault) [ "older than TLS 1.2") && (..Reason(tFault) [ "Restart the instance") && '(..Reason(tFault) [ "Switches"), "naming it, the protocol and the restart remedy: " _ ..Reason(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), tBefore, "and the transport is not entered")
    Do ..RestoreOwn()
    Do $$$AssertEquals(..Call(), "", "restored, the next call is not refused")
}

/// <p>A name that no configuration holds is refused <code>PROVIDER.TLS</code> as absent, with the configuration named and its
/// remedy, and no claim that it was ever verifying.</p>
/// <p>Mutation (Rule 19): build the absent refusal's sentence as the unverified one, with
/// <method>OcuPilot.Kernel.Provider.Base.TlsReason</method>'s <code>unverified</code> state, in
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- this goes red; drop <code>REMEDYTLSABSENT</code> from the absent
/// sentence in <method>OcuPilot.Kernel.Provider.Base.TlsReason</method> -- the remedy assertion alone goes red.</p>
Method TestAnAbsentConfigurationIsRefusedAsAbsent()
{
    Set tValues("sslConfiguration") = "OcuPilotProbeCallTimeAbsent"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues), "the egress row names a configuration no one holds")
    Set tFault = ..Call(.tHttpStatus)
    Do $$$AssertEquals(..Said(tFault) _ " " _ tHttpStatus, "PROVIDER.TLS 503", "the call is refused")
    Do $$$AssertTrue((..Reason(tFault) [ "is not present") && (..Reason(tFault) [ "OcuPilotProbeCallTimeAbsent"), "as absent, naming it: " _ ..Reason(tFault))
    Do $$$AssertTrue((..Reason(tFault) [ "Clear the name on Switches") && (..Reason(tFault) [ "classic portal"), "and the remedy: " _ ..Reason(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and the transport is not entered")
}

/// <p>A turn's poll shows <code>PROVIDER.TLS</code>'s one sentence (<method>OcuPilot.Api.Error.ReasonForTurnError</method>),
/// which names every cause, an unreadable configuration and a protocol floor below TLS 1.2 included, and where the
/// configuration and its remedy are named.
/// OcuPilot's own provider configuration, absent, takes the restart remedy and not the Switches one.</p>
/// <p>Mutation (Rule 19): drop "or could not be read" from <code>PROVIDER.TLS</code>'s sentence in
/// <method>OcuPilot.Kernel.Provider.Base.ReasonFor</method> -- the turn leg goes red, as does dropping "allows a protocol
/// older than TLS 1.2" from it, which the floor assertion alone fails; answer <code>REMEDYTLSABSENT</code>
/// for OcuPilot's own name in <method>OcuPilot.Kernel.Provider.Base.TlsReason</method> -- the own-absent leg goes red.</p>
Method TestATurnNamesEveryCauseAndAnAbsentOwnConfigurationTheRestart()
{
    Set tTurn = ##class(OcuPilot.Api.Error).ReasonForTurnError(##class(OcuPilot.Api.Error).#PROVIDERTLS)
    Do $$$AssertTrue((tTurn [ "could not be read") && (tTurn [ "Test connection"), "a turn's sentence names the unreadable cause and where the remedy is named: " _ tTurn)
    Do $$$AssertTrue(tTurn [ "allows a protocol older than TLS 1.2", "and the floor below TLS 1.2: " _ tTurn)
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tAbsent = ##class(OcuPilot.Kernel.Provider.Base).TlsReason(##class(OcuPilot.Port.ProviderPort).#TLSABSENT, tOwn, tOwn)
    Do $$$AssertTrue((tAbsent [ tOwn) && (tAbsent [ "Restart the instance") && '(tAbsent [ "Switches"), "OcuPilot's own, absent, names the restart and not Switches: " _ tAbsent)
}

/// <p>Change the probe the egress row names with <var>pChange</var> outside OcuPilot, assert the next call is refused
/// <code>PROVIDER.TLS</code> at 503 naming the probe and the remedy without entering the transport, then set it back with
/// <var>pBack</var> and assert the call is not refused. <var>pLabel</var> names the leg in the messages; both arrays are
/// consumed. <var>pSentence</var>, when given, is text the refusal's reason must also carry.</p>
Method RefusedThenRestored(pLabel As %String, ByRef pChange, ByRef pBack, pSentence As %String = "")
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .pChange), "the probe's " _ pLabel _ " is changed outside OcuPilot")
    Set tBefore = ##class(OcuPilot.Test.ProviderStub).Calls()
    Set tFault = ..Call(.tHttpStatus)
    Do $$$AssertEquals(..Said(tFault) _ " " _ tHttpStatus, "PROVIDER.TLS 503", pLabel _ ": the call is refused")
    Do $$$AssertTrue((..Reason(tFault) [ ..#PROBE) && (..Reason(tFault) [ "Clear the name on Switches") && (..Reason(tFault) [ "classic portal") && (..Reason(tFault) [ pSentence), "naming the configuration and the remedy: " _ ..Reason(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), tBefore, "and the transport is not entered")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .pBack), "set back")
    Do $$$AssertEquals(..Call(), "", pLabel _ ": the next call is not refused")
    Kill pChange, pBack
}

/// <p>One draft call through the probe port with the real configuration check, answering the fault, or <code>""</code>
/// when the call was not refused; the HTTP status in <var>pHttpStatus</var>.</p>
ClassMethod Call(Output pHttpStatus As %Integer) As %DynamicObject
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn""}")
    Kill tValues, tMessages
    Set tValues("provider") = "probe-local"
    Set tValues("model") = "probe-local-model-1"
    Set tValues("endpointUrl") = ..#PUBLICENDPOINT
    Set tValues("markedLocal") = 0
    Set tValues("credType") = "env"
    Set tValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tValues("maxTokens") = 4000
    Set tValues("temperature") = 0
    Set tMessages = 1, tMessages(1, "role") = "user", tMessages(1, "content") = "probe"
    Set tSC = $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .pHttpStatus, .tFault)
    Quit $Select($IsObject(tFault): tFault, 1: "")
}

/// <p>The code <var>pFault</var> carries, or <code>""</code> when the call was not refused.</p>
ClassMethod Said(pFault) As %String
{
    Quit $Select($IsObject(pFault): pFault.code, 1: "")
}

/// <p>The reason <var>pFault</var> carries, or <code>""</code> when the call was not refused.</p>
ClassMethod Reason(pFault) As %String
{
    Quit $Select($IsObject(pFault): pFault.reason, 1: "")
}

/// <p>Set OcuPilot's own provider configuration to the installer's values, whatever a leg left it.</p>
ClassMethod RestoreOwn()
{
    Set tProps("Type") = 0
    Set tProps("VerifyPeer") = 1
    Set tProps("Enabled") = 1
    Set tProps("CAFile") = "%OSCertificateStore"
    Set tProps("TLSMinVersion") = 16
    Set tProps("CipherList") = "ALL:!aNULL:!eNULL:!EXP:!SSLv2"
    Do ##class(OcuPilot.Test.EgressSslProbe).Modify(##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, .tProps)
}

/// <p>OcuPilot's own provider configuration's <code>Type</code>, <code>VerifyPeer</code>, <code>Enabled</code>,
/// <code>CAFile</code> and <code>TLSMinVersion</code>, space-separated.</p>
ClassMethod OwnReads() As %String
{
    Set tOut = ""
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(tOwn, .tConfig) Set tOut = tConfig.Type _ " " _ tConfig.VerifyPeer _ " " _ tConfig.Enabled _ " " _ tConfig.CAFile _ " " _ tConfig.TLSMinVersion
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOut
}

}
