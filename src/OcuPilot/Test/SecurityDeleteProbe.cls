/// <p>Test-only helper for <file>ui/browser/security-deletes.browser-spec.mjs</file> and
/// <file>ui/browser/ssl-editor.browser-spec.mjs</file>: creates and removes, by exact name, one probe
/// X.509 credential, one probe wallet secret and one probe SSL/TLS configuration, and answers whether
/// each exists. The credential is a certificate alone, made at run time by the instance's own OpenSSL
/// in a directory <class>OcuPilot.Test.X509Material</class> deletes before this returns, so no key
/// material outlives the call. The wallet secret lives in <class>OcuPilot.Test.WalletProbe</class>'s
/// collection. An SSL/TLS configuration whose description does not begin with
/// <parameter>MARKER</parameter> is somebody else's and is never deleted.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Its
/// callers run only against a throwaway instance.</p>
Class OcuPilot.Test.SecurityDeleteProbe Extends %RegisteredObject
{

Parameter X509ALIAS = "OcuPilotProbe95X509";

/// <p>The probe secret's name after the probe collection.</p>
Parameter SECRETPART = "Del95";

Parameter SSLNAME = "OcuPilotProbe95Delete";

/// <p>The description every probe SSL/TLS configuration this class makes carries.</p>
Parameter MARKER = "OcuPilot 9.5 browser probe";

/// <p>The probe secret's full name.</p>
ClassMethod SecretName() As %String
{
    Quit $Parameter("OcuPilot.Test.WalletProbe", "COLLECTION") _ "." _ ..#SECRETPART
}

/// <p>Create the three probes afresh, removing this class's own first.</p>
ClassMethod Create() As %Status
{
    Set tSC = ..Remove()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..CreateCredential()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.WalletProbe).EnsureCollection(.tCreated)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.WalletProbe).AddKeyValue(..SecretName(), {"Secret": "OcuPilotProbe95Browser", "Usage": 5, "RequireTLS": false, "AllowedHosts": ["h"]})
    If $$$ISERR(tSC) Quit tSC
    Quit ..CreateSsl(..#SSLNAME)
}

/// <p>Create a client SSL/TLS configuration named <var>pName</var> carrying
/// <parameter>MARKER</parameter>, refusing when a configuration of that name already exists.</p>
ClassMethod CreateSsl(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(pName) {
            Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ pName _ " already exists, and this helper will not adopt it")
        } Else {
            Set tProps("Type") = 0
            Set tProps("VerifyPeer") = 0
            Set tProps("Enabled") = 1
            Set tProps("Description") = ..#MARKER
            Set tSC = ##class(Security.SSLConfigs).Create(pName, .tProps)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the SSL/TLS configuration <var>pName</var> when its description begins with
/// <parameter>MARKER</parameter>; one that is anybody else's is an error and is left alone.</p>
ClassMethod RemoveSsl(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(pName, .tConfig) {
            If $Extract(tConfig.Description, 1, $Length(..#MARKER)) '= ..#MARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ pName _ " is not this helper's own, so it was left alone")
            } Else {
                Set tConfig = ""
                Set tSC = ##class(Security.SSLConfigs).Delete(pName)
            }
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the three probes by exact name, and the wallet probe collection.</p>
ClassMethod Remove() As %Status
{
    Set tSC = ..RemoveSsl(..#SSLNAME)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(%SYS.X509Credentials).Exists(..#X509ALIAS) {
            Set tDeleteSC = ##class(%SYS.X509Credentials).Delete(..#X509ALIAS)
            If $$$ISERR(tDeleteSC) Set tSC = $$$ADDSC(tSC, tDeleteSC)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set tWalletSC = ##class(OcuPilot.Test.WalletProbe).Remove(.tRemaining)
    If $$$ISERR(tWalletSC) Set tSC = $$$ADDSC(tSC, tWalletSC)
    Quit tSC
}

/// <p>Whether the probe named by <var>pKind</var> -- <code>x509</code>, <code>secret</code> or
/// <code>ssl</code> -- exists, as <code>1</code> or <code>0</code>.</p>
ClassMethod Exists(pKind As %String) As %Boolean
{
    If pKind = "secret" Quit ##class(OcuPilot.Test.WalletProbe).Holds(..SecretName())
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pKind = "x509" Set tExists = ''##class(%SYS.X509Credentials).Exists(..#X509ALIAS)
        If pKind = "ssl" Set tExists = ''##class(Security.SSLConfigs).Exists(..#SSLNAME)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Save the probe credential from a certificate made now; the directory holding it and its key
/// is deleted before this returns, whatever the outcome.</p>
ClassMethod CreateCredential() As %Status [ Private ]
{
    Set tMaterial = "OcuPilot.Test.X509Material"
    Set tDirectory = ##class(%File).NormalizeDirectory($Parameter(tMaterial, "PREFIX") _ "95-" _ $Job _ "-" _ $Random(1000000000), ##class(%SYS.System).TempDirectory())
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If '##class(%File).CreateDirectoryChain(tDirectory, .tReturn) {
            Set tSC = $$$ERROR($$$GeneralError, "could not create " _ tDirectory _ " (" _ $Get(tReturn) _ ")")
            Quit
        }
        Set tSC = $ClassMethod(tMaterial, "Run", tDirectory, "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", tDirectory _ "key.pem", "-out", tDirectory _ "cert.pem", "-days", 36500, "-subj", "/CN=OcuPilot 9.5 Delete Probe")
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = "%SYS"
        Set tCredential = ##class(%SYS.X509Credentials).%New()
        Set tCredential.Alias = ..#X509ALIAS
        Set tSC = tCredential.LoadCertificate(tDirectory _ "cert.pem")
        If $$$ISOK(tSC) Set tSC = tCredential.%Save()
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set tDiscardSC = $ClassMethod(tMaterial, "Discard", tDirectory)
    If $$$ISERR(tDiscardSC) Set tSC = $$$ADDSC(tSC, tDiscardSC)
    Quit tSC
}

}
