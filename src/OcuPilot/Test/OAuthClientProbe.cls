/// <p>Makes, reads and removes the OAuth 2.0 client configurations and server descriptions Story
/// 12.5's tests write against on a throwaway instance: clients whose name begins
/// <parameter>PREFIX</parameter> and descriptions whose issuer's host is
/// <parameter>HOST</parameter>. Nothing else is touched, and everything is removed by exact name.</p>
/// <p>The vendor calls run in <code>%SYS</code> by explicit save and restore (AD-16). A stored secret
/// is read back as its length alone. The SSL/TLS configuration and the X.509 credential are the demo
/// fixture's, so the instance needs the demo. A registered probe client is removed with the issuer
/// fixture running, because the vendor's delete asks its registration URI to delete it too.</p>
Class OcuPilot.Test.OAuthClientProbe Extends %RegisteredObject
{

/// <p>What every probe client's application name begins with.</p>
Parameter PREFIX = "OcuPilotProbe125";

/// <p>The host every probe description's issuer names.</p>
Parameter HOST = "ocupilotprobe125.invalid";

/// <p>The demo fixture's SSL/TLS configuration and X.509 credential, which holds a private key.</p>
Parameter SSLCONFIG = "OcuPilotDemoTLS";

Parameter CREDENTIAL = "OcuPilotDemoCert";

/// <p>The redirect URL a probe client carries.</p>
Parameter REDIRECT = "https://localhost:57773/csp/sys/oauth2";

/// <p>A probe client name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>A probe issuer: an https URL on <parameter>HOST</parameter> with path <var>pSuffix</var>.</p>
ClassMethod Issuer(pSuffix As %String) As %String
{
    Quit "https://" _ ..#HOST _ "/" _ pSuffix
}

/// <p>A synthetic secret unique to this call, shaped like no real key.</p>
ClassMethod Secret(pTag As %String) As %String
{
    Quit "ocupilot" _ pTag _ "probe000" _ $Job _ $Translate($Piece($ZTimeStamp, ",", 2), ".", "")
}

/// <p>Make description <var>pIssuer</var> through the vendor class, publishing
/// <var>pRegistrationEndpoint</var> when given and holding <var>pToken</var> as its initial access
/// token, and answer its ID in <var>pId</var>.</p>
ClassMethod AddServer(pIssuer As %String, Output pId As %String, pRegistrationEndpoint As %String = "", pToken As %String = "") As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).%New()
        Set tDefinition.IssuerEndpoint = pIssuer
        Set tDefinition.SSLConfiguration = ..#SSLCONFIG
        Set tMetadata = {}
        Do tMetadata.%Set("authorization_endpoint", pIssuer _ "/authorize", "string")
        Do tMetadata.%Set("token_endpoint", pIssuer _ "/token", "string")
        If pRegistrationEndpoint '= "" Do tMetadata.%Set("registration_endpoint", pRegistrationEndpoint, "string")
        Do tDefinition.Metadata.ImportJSON(tMetadata)
        If pToken '= "" Set tDefinition.InitialAccessToken = pToken
        Set tSC = tDefinition.%Save()
        If $$$ISOK(tSC) Set pId = tDefinition.%Id()
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make client <var>pName</var> through the vendor class against description <var>pServerId</var>,
/// of type <var>pType</var>, with <var>pSettings</var>'s <code>ClientId</code>,
/// <code>ClientCredentials</code>, <code>Description</code> and <code>Metadata</code> members applied.
/// The vendor sets its own algorithm defaults.</p>
ClassMethod AddClient(pName As %String, pServerId As %String, pType As %String = "confidential", pSettings As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Client).%New()
        Set tClient.ApplicationName = pName
        Set tClient.ClientType = pType
        Set tClient.SSLConfiguration = ..#SSLCONFIG
        Set tClient.ServerDefinition = ##class(OAuth2.ServerDefinition).%OpenId(pServerId)
        If pType '= "resource" {
            Set tClient.RedirectionEndpoint.Host = "localhost"
            Set tClient.RedirectionEndpoint.Port = 57773
            Set tClient.RedirectionEndpoint.Prefix = "csp/sys/oauth2"
            Set tClient.RedirectionEndpoint.UseSSL = 1
        }
        If $IsObject(pSettings) {
            For tField = "ClientId", "ClientCredentials", "Description" {
                If pSettings.%GetTypeOf(tField) = "string" Set $Property(tClient, tField) = pSettings.%Get(tField)
            }
            If pSettings.%GetTypeOf("Metadata") = "object" Do tClient.Metadata.ImportJSON(pSettings.%Get("Metadata"))
        }
        Set tSC = tClient.%Save()
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Client <var>pName</var> as stored: <code>{ClientType, Description, Enabled, ClientId,
/// ClientCredentials, SSLConfiguration, JWTInterval, Metadata, SecretLength, PasswordLength,
/// TokenLength, PublicJWKS}</code>, or <code>""</code>. <code>Metadata</code> is the vendor's export
/// without its two secret members, and each secret is answered as its length alone.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Client).%OpenId(pName)
        If $IsObject(tClient) {
            Set tStored = {}
            For tField = "ClientType", "Description", "ClientId", "ClientCredentials", "SSLConfiguration", "PublicJWKS" {
                Do tStored.%Set(tField, $Property(tClient, tField), "string")
            }
            Do tStored.%Set("Enabled", tClient.Enabled, "boolean")
            Do tStored.%Set("JWTInterval", tClient.JWTInterval, "number")
            Set tMetadata = ##class(%DynamicAbstractObject).%FromJSON(tClient.Metadata.ExportJSON(0))
            Do tStored.%Set("TokenLength", $Length(tClient.Metadata."registration_access_token"), "number")
            Do tMetadata.%Remove("client_secret")
            Do tMetadata.%Remove("registration_access_token")
            Do tStored.%Set("Metadata", tMetadata)
            Do tStored.%Set("SecretLength", $Length(tClient.ClientSecret), "number")
            Do tStored.%Set("PasswordLength", $Length(tClient.ClientPassword), "number")
        }
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>The length of description <var>pIssuer</var>'s initial access token, or -1 when it is absent.</p>
ClassMethod ServerTokenLength(pIssuer As %String) As %Integer
{
    Set tLength = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tSC)
        If $IsObject(tDefinition) Set tLength = $Length(tDefinition.InitialAccessToken)
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tLength
}

/// <p>Whether client <var>pName</var> exists.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Set tHolds = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = ##class(OAuth2.Client).%ExistsId(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>How many probe clients the instance holds.</p>
ClassMethod Count() As %Integer
{
    Quit $ListLength(..ProbeClients())
}

/// <p>Remove every probe client, then every description whose issuer's host is
/// <parameter>HOST</parameter>. <var>pRemaining</var> is how many of either survive.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRemaining = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tClients = ..ProbeClients()
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tClients) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Client).DeleteId($List(tClients, tI)))
        For tPass = 1, 2 {
            Set tIds = ""
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, IssuerEndpoint FROM OAuth2.ServerDefinition")
            While tResult.%Next() {
                If $Piece($Piece($Piece($Piece(tResult.%GetData(2), "://", 2), "/", 1), "?", 1), "#", 1) = ..#HOST Set tIds = tIds _ $ListBuild(tResult.%GetData(1))
            }
            If tPass = 2 {
                Set pRemaining = $ListLength(tIds)
                Quit
            }
            For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ServerDefinition).DeleteId($List(tIds, tI)))
        }
        Set $NAMESPACE = tOrigNS
        Set pRemaining = pRemaining + $ListLength(..ProbeClients())
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>The probe clients' names, as a <class>%List</class>.</p>
ClassMethod ProbeClients() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ApplicationName) FROM OAuth2.Client WHERE %EXACT(ApplicationName) %STARTSWITH ?", ..#PREFIX)
        While tResult.%Next() { Set tNames = tNames _ $ListBuild(tResult.%GetData(1)) }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>The vendor's own OAuth 2.0 audit rows since <var>pSince</var> whose description names
/// <var>pName</var>, as their descriptions joined with <code>|</code>; <code>-1</code> when the read
/// failed. The event data is not read.</p>
ClassMethod VendorRows(pSince As %String, pName As %String) As %String
{
    Quit ##class(OcuPilot.Test.OAuthServerProbe).VendorRows(pSince, pName)
}

}
