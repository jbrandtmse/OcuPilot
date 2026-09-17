/// <p>Makes and removes the OAuth 2.0 objects the OAuth 2.0 tabs are read against on a throwaway
/// instance: server descriptions <parameter>ISSUERA</parameter> and <parameter>ISSUERB</parameter>,
/// client configurations <parameter>CLIENTA</parameter> on A and <parameter>CLIENTB</parameter> on B,
/// resource server <parameter>RESOURCE</parameter> on A, an authorization server configuration when
/// none exists, and the <code>resource</code> server client <parameter>REGISTRATION</parameter>.</p>
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

/// <p>Delete every probe object that exists, and the authorization server configuration only when
/// <method>Create</method> recorded making it. Every vendor failure is carried in the status; one
/// failure does not stop the others.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tRemoveServer = ''$Get(^OcuPilotTest("OAuthProbe", "server"))
    Set tServerGone = 0
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
