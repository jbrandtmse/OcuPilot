/// <p>Test-only helper for Story 18.40's classes: creates and removes the SSL/TLS configurations they name, by exact name
/// and only ever one it made itself. A probe carries no certificate, key or trusted-certificates file: a verifying client
/// trusts <code>%OSCertificateStore</code>, a client that does not verify names no CA, and the server's cipher list needs
/// no certificate.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. The classes that call it
/// are armed by <code>OCUPILOT_ALLOW_SSL_CONFIG</code>.</p>
Class OcuPilot.Test.EgressSslProbe Extends %RegisteredObject
{

/// <p>The description every probe carries, which is how one is recognised as this helper's own before it is deleted.</p>
Parameter MARKER = "OcuPilot egress probe";

/// <p>The five shapes <method>Ensure</method> makes.</p>
Parameter VERIFIED = "verified";

Parameter WEAK = "weak";

Parameter NOVERIFY = "noverify";

Parameter DISABLED = "disabled";

Parameter SERVER = "server";

/// <p>Create the configuration <var>pName</var> of shape <var>pKind</var>, deleting it first when it is this helper's own
/// and refusing when it is anybody else's: a client requiring the server's certificate (<code>verified</code>), a client
/// that does not (<code>noverify</code>), a verifying client that is disabled (<code>disabled</code>), or an enabled server
/// with <code>VerifyPeer</code> 1 (<code>server</code>), which only its <code>Type</code> keeps from qualifying; or a client
/// requiring the server's certificate whose minimum TLS version is 1.1 (8), below the floor every provider call holds
/// (<code>weak</code>). A client's minimum TLS version is otherwise 1.2 (16), set here rather than left to the vendor's
/// default, which the call-time check reads.</p>
ClassMethod Ensure(pName As %String, pKind As %String = {..#VERIFIED}) As %Status
{
    Set tSC = ..Remove(pName)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Description") = ..#MARKER
        Set tProps("Type") = (pKind = ..#SERVER)
        Set tProps("Enabled") = (pKind '= ..#DISABLED)
        Set tProps("VerifyPeer") = (pKind '= ..#NOVERIFY)
        If tProps("VerifyPeer") = 1 Set tProps("CAFile") = "%OSCertificateStore"
        Set tProps("TLSMinVersion") = $Select(pKind = ..#WEAK: 8, 1: 16)
        If pKind = ..#SERVER {
            Set tProps("Ciphersuites") = ""
            Set tProps("CipherList") = "ADH:@SECLEVEL=0"
            Set tProps("TLSMinVersion") = 8
            Set tProps("TLSMaxVersion") = 16
        }
        Set tSC = ##class(Security.SSLConfigs).Create(pName, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the configuration <var>pName</var> when its description says it is this helper's own; one that is anybody
/// else's is an error and is left alone, and an absent one is no error.</p>
ClassMethod Remove(pName As %String) As %Status
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

/// <p>Whether the configuration <var>pName</var> exists on this instance.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.SSLConfigs).Exists(pName, .tConfig)
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tExists
}

/// <p>Change <var>pName</var> the way the classic portal does -- the vendor's own <code>Modify</code>, outside every
/// OcuPilot path -- setting <var>pProps</var>'s properties.</p>
ClassMethod Modify(pName As %String, ByRef pProps) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.SSLConfigs).Modify(pName, .pProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
