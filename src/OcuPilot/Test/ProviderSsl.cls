/// <p><b>AC3's installer half.</b> Install creates the outbound TLS configuration AD-32 names, with
/// the three properties that decide whether an HTTPS call verifies anything, and repairs those
/// properties when it finds them drifted rather than adopting whatever is there.</p>
/// <p><b>It creates a security object on the instance, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>).
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does not
/// arm it. Everything it creates belongs to the disposable <code>"probe"</code> profile and is
/// removed again by the uninstall each method ends with.</p>
/// <p><b>The assertion is a read-back through the vendor's own API</b>, not the installer's report:
/// a status is not evidence that the security database holds what was asked for, which is the same
/// discipline the installer's own step applies to itself.</p>
Class OcuPilot.Test.ProviderSsl Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

/// <p>The disposable profile every object here belongs to.</p>
Parameter PROFILE = "probe";

/// <p>The configuration name that profile derives, which the installer derives the same way.</p>
Parameter CONFIGNAME = "OcuPilotProviderProbe";

/// <p>Refuse to run at all unless this instance is armed for a security-object write.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProviderSsl creates a TLS configuration in this instance's own security database and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Remove the probe profile's objects before each method, so each starts from an instance that
/// holds none of them.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 1)
    Quit $$$OK
}

/// <p>Remove them again afterwards, so nothing this class created survives it.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall(..#PROFILE, 1)
    Do $$$AssertStatusOK(tSC, "the probe profile's objects are removed")
    Do $$$AssertEquals(..Exists(..#CONFIGNAME), 0, "and the TLS configuration this class created is gone")
    Quit $$$OK
}

/// <p>The configuration name the installer derives from
/// <parameter>OcuPilot.Kernel.State.Base.SSLCONFIG</parameter> for the probe profile, read here so
/// the two derivations are held equal rather than left to agree by eye.</p>
Method TestTheProbeNameIsDerivedFromTheOneParameter()
{
    Do $$$AssertEquals(..#CONFIGNAME, ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG _ "Probe", "the probe configuration's name is the kernel parameter with the profile suffix")
}

/// <p><b>AC3</b> -- a clean instance with no configuration gets one, client-typed, requiring the
/// server's certificate and trusting the operating system's own store.</p>
/// <p>Mutation: change <code>EnsureSslConfiguration</code>'s <code>VerifyPeer</code> to 0 -- the
/// read-back assertion goes red, and install itself fails, because the step reads the configuration
/// back and refuses what did not take.</p>
Method TestInstallCreatesTheConfiguration()
{
    Do $$$AssertEquals(..Exists(..#CONFIGNAME), 0, "the instance holds no such configuration before install")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "a probe install runs every step")
    Do $$$AssertEquals(..Exists(..#CONFIGNAME), 1, "and the TLS configuration now exists")
    Do ..AssertProperties("after a first install")
}

/// <p><b>AC3's call-time read, as the port actually makes it.</b> Every provider test answers the
/// TLS question from a switch on <class>OcuPilot.Test.ProviderPortProbe</class>, so the shipped
/// <method>OcuPilot.Port.ProviderPort.SslConfigurationMissing</method> -- the one piece of this
/// story that enters <code>%SYS</code> at call time -- runs in none of them. This class is already
/// armed to create a configuration on a throwaway, so it is where that method can be asked about a
/// real one.</p>
/// <p>The namespace is asserted on both paths: a method that answered correctly and left the
/// caller in <code>%SYS</code> would pass every other assertion in the suite and break the next
/// thing the calling process touched (AD-16).</p>
/// <p>Mutation: invert the shipped body's test, or delete the restore on its success path -- the
/// first two legs, or the namespace legs, go red.</p>
Method TestThePortsOwnTlsReadAnswersTheInstance()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "the probe install creates the configuration")
    Set tNs = $Namespace
    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).SslConfigurationMissing(..#CONFIGNAME), 0, "the port's own read finds a configuration this instance holds")
    Do $$$AssertEquals($Namespace, tNs, "and leaves the caller's namespace where it found it")
    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).SslConfigurationMissing(..#CONFIGNAME _ "NoSuchConfiguration"), 1, "and reports one it does not")
    Do $$$AssertEquals($Namespace, tNs, "restoring the namespace on that path too")
    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).SslConfigurationMissing(""), 0, "an empty name asks nothing, which is the marked-local plain-HTTP path")
}

/// <p>AD-17 -- install is safe to repeat: a second run finds the configuration correct and leaves
/// it as it is.</p>
Method TestARepeatInstallLeavesItAlone()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "the first probe install runs")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "and a second one runs over it")
    Do ..AssertProperties("after a repeat install")
}

/// <p><b>AC3's repair half</b> -- a configuration whose verification has been turned off, or whose
/// trust store has been repointed, is repaired by the next install rather than adopted.</p>
/// <p>A configuration that verifies no peer is one that encrypts to anybody, so finding one is not
/// a reason to leave it.</p>
Method TestInstallRepairsADriftedConfiguration()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "the probe install creates the configuration")
    Set tDrift("VerifyPeer") = 0
    Set tDrift("CAFile") = ""
    Do $$$AssertStatusOK(..Modify(..#CONFIGNAME, .tDrift), "the configuration is then drifted by hand")
    Do $$$AssertEquals(..Property(..#CONFIGNAME, "VerifyPeer"), 0, "so it verifies no peer")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(..#PROFILE), "and a further install runs over the drift")
    Do ..AssertProperties("after the drift was repaired")
}

/// <p>Assert the three properties AD-32 names, read back through the vendor's own API.</p>
/// <p><b>The expected values are literals, and that is load-bearing.</b> Comparing the
/// configuration against <parameter>OcuPilot.Install.Installer.SSLVERIFYPEER</parameter> cannot
/// fail: changing the installer's parameter moves the expectation with it, so a run that created a
/// configuration verifying nothing would still be green. Measured, not reasoned about -- that
/// mutation was applied on a throwaway and this class stayed green until these became literals.
/// The vendor's own scale is in <file>irissys/Security/SSLConfigs.cls</file>: <code>Type</code> 0 is
/// client, and for a client <code>VerifyPeer</code> 1 is "require the server's certificate".</p>
Method AssertProperties(pWhen As %String)
{
    Do $$$AssertEquals(..Property(..#CONFIGNAME, "Type"), 0, pWhen _ ": the configuration is client-typed")
    Do $$$AssertEquals(..Property(..#CONFIGNAME, "VerifyPeer"), 1, pWhen _ ": it requires the server's certificate rather than continuing when verification fails")
    Do $$$AssertEquals(..Property(..#CONFIGNAME, "CAFile"), "%OSCertificateStore", pWhen _ ": and trusts the operating system's own certificate store")
    Do $$$AssertEquals(..Property(..#CONFIGNAME, "Enabled"), 1, pWhen _ ": and is enabled")
}

/// <p>The installer's three parameters spell exactly what AD-32 asks for. Held against the same
/// literals <method>AssertProperties</method> uses, so the parameters cannot be changed to
/// something else without a red test -- which is the other half of not comparing a value against
/// its own source.</p>
Method TestTheInstallersPropertiesAreTheOnesAD32Names()
{
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).#SSLTYPECLIENT, 0, "the installer creates a client-typed configuration")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).#SSLVERIFYPEER, 1, "requiring the server's certificate")
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).#SSLCAFILE, "%OSCertificateStore", "and trusting the operating system's own certificate store")
}

/// <p>Whether <var>pName</var> is a TLS configuration on this instance.</p>
/// <p><class>Security.SSLConfigs</class> exists only in <code>%SYS</code>, so this enters that
/// namespace once by explicit save and restore, with the restore as the first line of the
/// <code>Catch</code> (AD-16), and dispatches to no <code>OcuPilot</code> class inside the
/// window.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tExists = ''##class(Security.SSLConfigs).Exists(pName, .tConfig, .tStatus)
        Set tConfig = ""
        Set $Namespace = tOrigNS
    } Catch ex {
        Set $Namespace = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>One property of <var>pName</var>, read back through the vendor's own <code>Get</code>, or
/// <code>""</code>.</p>
ClassMethod Property(pName As %String, pProperty As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tSC = ##class(Security.SSLConfigs).Get(pName, .tProps)
        If $$$ISOK(tSC) Set tValue = $Get(tProps(pProperty))
        Set $Namespace = tOrigNS
    } Catch ex {
        Set $Namespace = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Drift <var>pName</var> by hand, so the repair path has something to repair.</p>
ClassMethod Modify(pName As %String, ByRef pProps) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tSC = ##class(Security.SSLConfigs).Modify(pName, .pProps)
        Set $Namespace = tOrigNS
    } Catch ex {
        Set $Namespace = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
