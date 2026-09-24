/// <p>Makes and removes the OAuth 2.0 objects the OAuth 2.0 tabs are read against on a throwaway
/// instance: server descriptions <parameter>ISSUERA</parameter> and <parameter>ISSUERB</parameter>,
/// client configurations <parameter>CLIENTA</parameter> on A and <parameter>CLIENTB</parameter> on B,
/// resource server <parameter>RESOURCE</parameter> on A, an authorization server configuration when
/// none exists, and the <code>resource</code> server client <parameter>REGISTRATION</parameter>.
/// <method>CreateDisposable</method> adds the objects a delete test removes: client configuration
/// <parameter>CLIENTDELETE</parameter> on A and two server clients sharing the name
/// <parameter>REGISTRATIONDELETE</parameter>.</p>
/// <p><b>A pre-existing authorization server configuration is used as it is</b>, never modified and
/// never deleted: <method>Remove</method> deletes the configuration only when
/// <method>Create</method> recorded making it, and every other object only by its probe name.
/// Saving a configuration creates the vendor's <code>/oauth2</code> web application, which removal
/// leaves in place.</p>
/// <p>The vendor calls run in <code>%SYS</code>, reached by explicit save and restore (AD-16); the
/// record lives in <code>^OcuPilotTest("OAuthProbe")</code> in the caller's namespace. The client
/// configurations use the demo fixture's SSL/TLS configuration <parameter>SSLCONFIG</parameter>,
/// so the instance needs the demo. Callers run on a throwaway only: the objects are instance
/// security configuration.</p>
Class OcuPilot.Test.OAuthProbe Extends %RegisteredObject
{

/// <p>Server description A's issuer.</p>
Parameter ISSUERA = "https://ocupilottest.invalid/a";

/// <p>Server description B's issuer.</p>
Parameter ISSUERB = "https://ocupilottest.invalid/b";

/// <p>The client configuration on A.</p>
Parameter CLIENTA = "OcuPilotTestA";

/// <p>The client configuration on B.</p>
Parameter CLIENTB = "OcuPilotTestB";

/// <p>The resource server on A.</p>
Parameter RESOURCE = "OcuPilotTestResource";

/// <p>The server client's name.</p>
Parameter REGISTRATION = "OcuPilotTestRegistration";

/// <p>The disposable client configuration on A, which a delete test removes.</p>
Parameter CLIENTDELETE = "OcuPilotTestDelete";

/// <p>The name the two disposable server clients share: the vendor keys a server client by its
/// client id, and a name is not unique.</p>
Parameter REGISTRATIONDELETE = "OcuPilotTestDeleteRegistration";

/// <p>The demo fixture's SSL/TLS configuration the client configurations and descriptions name.</p>
Parameter SSLCONFIG = "OcuPilotDemoTLS";

/// <p>Make every probe object that does not already exist. Returns the first vendor failure, with
/// what was made before it left in place for <method>Remove</method>.</p>
ClassMethod Create() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tMadeServer = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefA = ..EnsureServerDefinition(..#ISSUERA, .tSC)
        If $$$ISERR(tSC) Quit
        Set tDefB = ..EnsureServerDefinition(..#ISSUERB, .tSC)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsureClient(..#CLIENTA, tDefA)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsureClient(..#CLIENTB, tDefB)
        If $$$ISERR(tSC) Quit
        If '##class(OAuth2.ResourceServer).Exists(..#RESOURCE, .tExisting, .tExistsSC) {
            Set tResource = ##class(OAuth2.ResourceServer).%New()
            Set tResource.Name = ..#RESOURCE
            Set tResource.ServerDefinition = tDefA
            Set tResource.Audiences = $ListBuild("https://ocupilottest.invalid/resource")
            Set tSC = tResource.%Save()
            If $$$ISERR(tSC) Quit
        }
        If '##class(OAuth2.Server.Configuration).%ExistsId("singleton") {
            Set tServer = ##class(OAuth2.Server.Configuration).%New()
            Set tServer.IssuerEndpoint.Host = "localhost"
            Set tServer.CustomizationNamespace = "%SYS"
            Set tServer.CustomizationRoles = "%DB_IRISSYS"
            Do tServer.SupportedScopes.SetAt("OpenID", "openid")
            Do tServer.SupportedScopes.SetAt("Profile", "profile")
            Set tServer.Metadata."grant_types_supported" = $ListBuild("authorization_code", "client_credentials")
            Set tSC = tServer.%Save()
            If $$$ISERR(tSC) Quit
            Set tMadeServer = 1
        }
        If ..RegistrationId() = "" {
            Set tRegistration = ##class(OAuth2.Server.Client).%New()
            Set tRegistration.Name = ..#REGISTRATION
            Set tRegistration.ClientType = "resource"
            Set tSC = tRegistration.%Save()
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If tMadeServer Set ^OcuPilotTest("OAuthProbe", "server") = 1
    Quit tSC
}

/// <p>Delete every probe object that exists, the disposable ones
/// (<method>RemoveDisposable</method>) first, and the authorization server configuration only when
/// <method>Create</method> recorded making it. Every vendor failure is carried in the status; one
/// failure does not stop the others.</p>
ClassMethod Remove() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tRemoveServer = ''$Get(^OcuPilotTest("OAuthProbe", "server"))
    Set tServerGone = 0
    Set tSC = ..RemoveDisposable()
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRegistrationId = ..RegistrationId()
        If tRegistrationId '= "" Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Server.Client).DeleteId(tRegistrationId))
        If tRemoveServer && ##class(OAuth2.Server.Configuration).%ExistsId("singleton") {
            Set tDeleteSC = ##class(OAuth2.Server.Configuration).Delete()
            Set tSC = $$$ADDSC(tSC, tDeleteSC)
            Set tServerGone = $$$ISOK(tDeleteSC)
        }
        If ##class(OAuth2.ResourceServer).Exists(..#RESOURCE, .tExisting, .tExistsSC) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ResourceServer).Delete(..#RESOURCE))
        For tClient = ..#CLIENTA, ..#CLIENTB {
            If ##class(OAuth2.Client).%ExistsId(tClient) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Client).DeleteId(tClient))
        }
        For tIssuer = ..#ISSUERA, ..#ISSUERB {
            Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(tIssuer, .tOpenSC)
            If $IsObject(tDefinition) {
                Set tId = tDefinition.%Id()
                Set tDefinition = ""
                Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ServerDefinition).DeleteId(tId))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    If tServerGone || 'tRemoveServer Kill ^OcuPilotTest("OAuthProbe")
    Quit tSC
}

/// <p>Make the disposable objects a delete test removes, each only if absent: client configuration
/// <parameter>CLIENTDELETE</parameter> on server description A, and server clients until two share
/// the name <parameter>REGISTRATIONDELETE</parameter>. <b>Caller contract:</b> <method>Create</method>
/// has made description A. <method>Remove</method> deletes whatever of them survives.</p>
ClassMethod CreateDisposable() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefA = ##class(OAuth2.ServerDefinition).OpenByIssuer(..#ISSUERA, .tOpenSC)
        If '$IsObject(tDefA) {
            Set tSC = $$$ERROR($$$GeneralError, "server description " _ ..#ISSUERA _ " does not exist, so the disposable client configuration has nothing to be made on")
            Quit
        }
        Set tSC = ..EnsureClient(..#CLIENTDELETE, tDefA)
        If $$$ISERR(tSC) Quit
        For tI = ($ListLength(..IdsNamed(..#REGISTRATIONDELETE)) + 1):1:2 {
            Set tRegistration = ##class(OAuth2.Server.Client).%New()
            Set tRegistration.Name = ..#REGISTRATIONDELETE
            Set tRegistration.ClientType = "resource"
            Set tSC = tRegistration.%Save()
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete whichever of <method>CreateDisposable</method>'s objects still exist. Every vendor
/// failure is carried in the status; one failure does not stop the others.</p>
ClassMethod RemoveDisposable() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ..IdsNamed(..#REGISTRATIONDELETE)
        For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Server.Client).DeleteId($List(tIds, tI)))
        If ##class(OAuth2.Client).%ExistsId(..#CLIENTDELETE) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Client).DeleteId(..#CLIENTDELETE))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The client ids of the server clients named <parameter>REGISTRATIONDELETE</parameter>, as a
/// <class>%List</class> in id order.</p>
ClassMethod DisposableRegistrationIds() As %List
{
    Set tOrigNS = $NAMESPACE
    Set tIds = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ..IdsNamed(..#REGISTRATIONDELETE)
    } Catch {
        Set tIds = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tIds
}

/// <p>Whether client configuration <parameter>CLIENTDELETE</parameter> exists.</p>
ClassMethod DisposableClientExists() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(OAuth2.Client).%ExistsId(..#CLIENTDELETE)
    } Catch {
        Set tExists = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>Set client configuration <parameter>CLIENTDELETE</parameter>'s <code>DefaultScope</code> to
/// <var>pScope</var>, as a change made out of band.</p>
ClassMethod ChangeDisposableClientScope(pScope As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Client).%OpenId(..#CLIENTDELETE, , .tSC)
        If '$IsObject(tClient) Quit
        Set tClient.DefaultScope = pScope
        Set tSC = tClient.%Save()
        Set tClient = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether <method>Create</method> made the authorization server configuration, as recorded in the
/// caller's namespace.</p>
ClassMethod MadeServer() As %Boolean
{
    Quit ''$Get(^OcuPilotTest("OAuthProbe", "server"))
}

/// <p>The server client <parameter>REGISTRATION</parameter>'s id, or <code>""</code>.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod RegistrationId() As %String [ Private ]
{
    Set tId = ""
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM OAuth2_Server.Client WHERE %EXACT(Name) = ?", ..#REGISTRATION)
    If (tResult.%SQLCODE = 0) && tResult.%Next() Set tId = tResult.%GetData(1)
    Quit tId
}

/// <p>The client ids of the server clients named <var>pName</var>, in id order.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod IdsNamed(pName As %String) As %List [ Private ]
{
    Set tIds = ""
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OAuth2_Server.Client WHERE %EXACT(Name) = ? ORDER BY ID", pName)
    If tResult.%SQLCODE '= 0 Quit ""
    While tResult.%Next() {
        Set tIds = tIds _ $ListBuild(tResult.%GetData(1))
    }
    Quit tIds
}

/// <p>The server description at <var>pIssuer</var>, made when it does not exist, with the
/// authorization and token endpoints a description needs. <b>Caller contract:</b>
/// <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod EnsureServerDefinition(pIssuer As %String, Output pSC As %Status) As %RegisteredObject [ Private ]
{
    Set pSC = $$$OK
    Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tOpenSC)
    If $IsObject(tDefinition) Quit tDefinition
    Set tDefinition = ##class(OAuth2.ServerDefinition).%New()
    Set tDefinition.IssuerEndpoint = pIssuer
    Set tDefinition.SSLConfiguration = ..#SSLCONFIG
    Set tDefinition.Metadata."authorization_endpoint" = pIssuer _ "/authorize"
    Set tDefinition.Metadata."token_endpoint" = pIssuer _ "/token"
    Set pSC = tDefinition.%Save()
    If $$$ISERR(pSC) Quit ""
    Quit tDefinition
}

/// <p>Make client configuration <var>pName</var> on <var>pDefinition</var> when it does not exist.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> is <code>%SYS</code>.</p>
ClassMethod EnsureClient(pName As %String, pDefinition As %RegisteredObject) As %Status [ Private ]
{
    If ##class(OAuth2.Client).%ExistsId(pName) Quit $$$OK
    Set tClient = ##class(OAuth2.Client).%New()
    Set tClient.ApplicationName = pName
    Set tClient.ClientType = "confidential"
    Set tClient.SSLConfiguration = ..#SSLCONFIG
    Set tClient.ServerDefinition = pDefinition
    Set tClient.RedirectionEndpoint.Host = "localhost"
    Quit tClient.%Save()
}

}
