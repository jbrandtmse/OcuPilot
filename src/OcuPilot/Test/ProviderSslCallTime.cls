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
/// installer's values in <method>OnAfterOneTest</method> whatever the leg did.</p>
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
    Do $$$AssertEquals(..OwnReads(), "0 1 1 %OSCertificateStore", "OcuPilot's own provider configuration reads the installer's values again")
    Quit $$$OK
}

/// <p>A configuration the egress row names that is changed on the classic portal to stop requiring the server's
/// certificate, to be disabled or to become a server, refuses the next call -- <code>PROVIDER.TLS</code> at 503, the
/// sentence naming it and the remedy -- and the transport is not entered; set back, the call goes through. OcuPilot's
/// own provider configuration is refused the same, with the restart remedy.</p>
/// <p>Mutation (Rule 19): skip the <code>SslConfigurationState</code> check in
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- every refused leg reaches the stub and goes red; drop the
/// <code>Type</code> condition from <code>SslConfigurationState</code> -- the <code>Type</code> leg alone goes red.</p>
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
    Do ..RefusedThenRestored("Type", .tChange, .tBack)

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
    Do $$$AssertTrue(..Reason(tFault) [ "clear the name on Switches", "and the remedy: " _ ..Reason(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and the transport is not entered")
}

/// <p>Change the probe the egress row names with <var>pChange</var> outside OcuPilot, assert the next call is refused
/// <code>PROVIDER.TLS</code> at 503 naming the probe and the remedy without entering the transport, then set it back with
/// <var>pBack</var> and assert the call is not refused. <var>pLabel</var> names the leg in the messages; both arrays are
/// consumed.</p>
Method RefusedThenRestored(pLabel As %String, ByRef pChange, ByRef pBack)
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.EgressSslProbe).Modify(..#PROBE, .pChange), "the probe's " _ pLabel _ " is changed outside OcuPilot")
    Set tBefore = ##class(OcuPilot.Test.ProviderStub).Calls()
    Set tFault = ..Call(.tHttpStatus)
    Do $$$AssertEquals(..Said(tFault) _ " " _ tHttpStatus, "PROVIDER.TLS 503", pLabel _ ": the call is refused")
    Do $$$AssertTrue((..Reason(tFault) [ ..#PROBE) && (..Reason(tFault) [ "Re-enable peer verification") && (..Reason(tFault) [ "Switches"), "naming the configuration and the remedy: " _ ..Reason(tFault))
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
    Do ##class(OcuPilot.Test.EgressSslProbe).Modify(##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, .tProps)
}

/// <p>OcuPilot's own provider configuration's <code>Type</code>, <code>VerifyPeer</code>, <code>Enabled</code> and
/// <code>CAFile</code>, space-separated.</p>
ClassMethod OwnReads() As %String
{
    Set tOut = ""
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(tOwn, .tConfig) Set tOut = tConfig.Type _ " " _ tConfig.VerifyPeer _ " " _ tConfig.Enabled _ " " _ tConfig.CAFile
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOut
}

}
