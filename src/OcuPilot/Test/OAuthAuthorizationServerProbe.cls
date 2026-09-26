/// <p>Makes, reads and removes the OAuth 2.0 authorization server objects Story 12.7's tests write
/// against on a throwaway instance: the one configuration, clients registered with it whose name
/// begins <parameter>PREFIX</parameter>, and X.509 credentials whose alias begins it. Removing the
/// configuration removes every registered client with it; the vendor's <code>/oauth2</code> web
/// application is left as it is.</p>
/// <p>The vendor calls run in <code>%SYS</code> by explicit save and restore (AD-16). A stored key
/// password is read back as its length alone. The credentials copy the demo fixture's, so the instance
/// needs the demo.</p>
Class OcuPilot.Test.OAuthAuthorizationServerProbe Extends %RegisteredObject
{

/// <p>What every probe client's name and credential's alias begins with.</p>
Parameter PREFIX = "OcuPilotProbe127";

/// <p>The host every probe issuer names.</p>
Parameter HOST = "ocupilotprobe127.invalid";

/// <p>The demo fixture's credential the probe credentials copy.</p>
Parameter DEMOCREDENTIAL = "OcuPilotDemoCert";

Parameter ENDPOINT = "Security.OAuth2.Server";

Parameter PORT = "OcuPilot.Port.OAuthAuthorizationServerPort";

/// <p>A probe issuer: an https URL on <parameter>HOST</parameter> with path <var>pSuffix</var>.</p>
ClassMethod Issuer(pSuffix As %String = "probe") As %String
{
    Quit "https://" _ ..#HOST _ "/" _ pSuffix
}

/// <p>A probe name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>A synthetic password unique to this call, shaped like no real one.</p>
ClassMethod Secret(pTag As %String) As %String
{
    Quit "ocupilot" _ pTag _ "probe000" _ $Job _ $Translate($Piece($ZTimeStamp, ",", 2), ".", "")
}

/// <p>Make the configuration through the vendor class: issuer <method>Issuer</method>, scopes
/// <code>openid</code> and <code>profile</code>, role <code>%DB_IRISSYS</code> in <code>%SYS</code>,
/// grant types authorization code and client credentials, a description and a documentation URL.
/// <var>pSettings</var> may set <code>Description</code>, <code>ServerCredentials</code>,
/// <code>ServerPassword</code> and <code>AccessTokenInterval</code>.</p>
ClassMethod Seed(pSettings As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tServer = ##class(OAuth2.Server.Configuration).%New()
        Set tEndpoint = ##class(OAuth2.Endpoint).MakeFromServerURL(..Issuer())
        Set tServer.IssuerEndpoint.Host = tEndpoint.Host
        Set tServer.IssuerEndpoint.Prefix = tEndpoint.Prefix
        Set tServer.Description = "seeded"
        Set tServer.CustomizationNamespace = "%SYS"
        Set tServer.CustomizationRoles = "%DB_IRISSYS"
        Do tServer.SupportedScopes.SetAt("OpenID", "openid")
        Do tServer.SupportedScopes.SetAt("Profile", "profile")
        Set tServer.Metadata."grant_types_supported" = $ListBuild("authorization_code", "client_credentials", "refresh_token")
        Set tServer.Metadata."service_documentation" = "https://" _ ..#HOST _ "/docs"
        If $IsObject(pSettings) {
            For tField = "Description", "ServerCredentials", "ServerPassword", "AccessTokenInterval" {
                If pSettings.%GetTypeOf(tField) '= "unassigned" Set $Property(tServer, tField) = pSettings.%Get(tField)
            }
        }
        Set tSC = tServer.%Save()
        Set tServer = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Register client <var>pName</var> with the configuration, its id in <var>pClientId</var>.</p>
ClassMethod SeedClient(pName As %String, Output pClientId As %String) As %Status
{
    Set pClientId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Server.Client).%New()
        Set tClient.Name = pName
        Set tClient.ClientType = "resource"
        Set tSC = tClient.%Save()
        If $$$ISOK(tSC) Set pClientId = tClient.ClientId
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove registered client <var>pClientId</var>.</p>
ClassMethod RemoveClient(pClientId As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(OAuth2.Server.Client).DeleteId(pClientId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make X.509 credential <var>pAlias</var> from the demo fixture's certificate, with its private key
/// when <var>pWithKey</var> is 1 and without it otherwise.</p>
ClassMethod AddCredential(pAlias As %String, pWithKey As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDemo = ##class(%SYS.X509Credentials).GetByAlias(..#DEMOCREDENTIAL)
        If '$IsObject(tDemo) {
            Set tSC = $$$ERROR($$$GeneralError, "the demo fixture's credential " _ ..#DEMOCREDENTIAL _ " is absent")
            Quit
        }
        Set tCredential = ##class(%SYS.X509Credentials).%New()
        Set tCredential.Alias = pAlias
        Set tCredential.Certificate = tDemo.Certificate
        If pWithKey Set tCredential.PrivateKey = tDemo.PrivateKey
        Set tDemo = ""
        Set tSC = tCredential.%Save()
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The configuration as stored, or <code>""</code>: its template fields as text, the scopes and
/// roles as sorted comma-separated names, the grant types and the metadata members the editor sets,
/// <code>PasswordLength</code> and <code>KeyCount</code>.</p>
ClassMethod Stored() As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tServer = ##class(OAuth2.Server.Configuration).Open(.tOpenSC)
        If $IsObject(tServer) {
            ; The configuration stays in memory once this process opens it; read what is stored.
            Do tServer.%Reload()
            If $IsObject(tServer.Metadata) Do tServer.Metadata.%Reload()
            Set tStored = {}
            Do tStored.%Set("IssuerEndpoint", tServer.IssuerEndpoint.GetServerURL(), "string")
            For tField = "Description", "ReturnRefreshToken", "DefaultScope", "CustomizationNamespace", "AuthenticateClass", "SessionClass", "ValidateUserClass", "GenerateTokenClass", "RevokeTokenClass", "ServerCredentials", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "SSLConfiguration" {
                Do tStored.%Set(tField, $Property(tServer, tField), "string")
            }
            For tField = "AccessTokenInterval", "AuthorizationCodeInterval", "RefreshTokenInterval", "SessionInterval", "ClientSecretInterval" {
                Do tStored.%Set(tField, +$Property(tServer, tField), "number")
            }
            For tField = "AllowUnsupportedScope", "SupportSession", "AudRequired", "AllowPublicClientRefresh", "ForcePKCEForPublicClients", "ForcePKCEForConfidentialClients" {
                Do tStored.%Set(tField, ''$Property(tServer, tField), "boolean")
            }
            Set tScopes = ""
            Set tKey = tServer.SupportedScopes.Next("")
            While tKey '= "" {
                Set tScopes = tScopes _ $Select(tScopes = "": "", 1: ",") _ tKey
                Set tKey = tServer.SupportedScopes.Next(tKey)
            }
            Do tStored.%Set("SupportedScopes", tScopes, "string")
            Do tStored.%Set("CustomizationRoles", tServer.CustomizationRoles, "string")
            Do tStored.%Set("GrantTypes", $ListToString(tServer.Metadata."grant_types_supported"), "string")
            For tMember = "service_documentation", "op_policy_uri", "op_tos_uri" {
                Do tStored.%Set(tMember, $Property(tServer.Metadata, tMember), "string")
            }
            For tMember = "frontchannel_logout_supported", "frontchannel_logout_session_supported" {
                Do tStored.%Set(tMember, ''$Property(tServer.Metadata, tMember), "boolean")
            }
            Do tStored.%Set("PasswordLength", $Length(tServer.ServerPassword), "number")
            Do tStored.%Set("KeyCount", ..KeysIn(tServer.PublicJWKS), "number")
        }
        Set tServer = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>How many keys JWKS text <var>pJwks</var> holds, or 0.</p>
ClassMethod KeysIn(pJwks As %String) As %Integer
{
    If pJwks = "" Quit 0
    Set tCount = 0
    Try {
        Set tKeys = ##class(%DynamicAbstractObject).%FromJSON(pJwks).%Get("keys")
        If $IsObject(tKeys) Set tCount = tKeys.%Size()
    } Catch {
        Set tCount = 0
    }
    Quit tCount
}

/// <p>Whether the instance holds the configuration.</p>
ClassMethod Holds() As %Boolean
{
    Set tHolds = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = ##class(OAuth2.Server.Configuration).%ExistsId("singleton")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>How many clients are registered with the instance's authorization server, or -1.</p>
ClassMethod ClientCount() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OAuth2_Server.Client")
        If tRS.%Next() Set tCount = tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove the configuration, which removes every client registered with it, and every probe
/// credential. <var>pRemaining</var> is how many of the three kinds survive.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRemaining = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(OAuth2.Server.Configuration).%ExistsId("singleton") Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Server.Configuration).Delete())
        Set tAliases = ..ProbeCredentials()
        For tI = 1:1:$ListLength(tAliases) Set tSC = $$$ADDSC(tSC, ##class(%SYS.X509Credentials).Delete($List(tAliases, tI)))
        Set $NAMESPACE = tOrigNS
        Set pRemaining = ..Holds() + $ListLength(..ProbeCredentials()) + $Select(..ClientCount() > 0: ..ClientCount(), 1: 0)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>The probe credentials' aliases, as a <class>%List</class>.</p>
ClassMethod ProbeCredentials() As %List
{
    Set tAliases = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(Alias) AS Alias FROM %SYS.X509Credentials WHERE %EXACT(Alias) %STARTSWITH ?", ..#PREFIX)
        While tRS.%Next() { Set tAliases = tAliases _ $ListBuild(tRS.%Get("Alias")) }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tAliases
}

/// <p>The configuration as the shipped port's <code>GET</code> answers it, or <code>""</code>.</p>
ClassMethod Read() As %DynamicObject
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Quit tRead
}

/// <p>A create's complete body: the classic page's defaults with the probe issuer, the two scopes and
/// the role <code>%DB_IRISSYS</code>, and <var>pPatch</var>'s fields set over them.</p>
ClassMethod Body(pPatch As %DynamicObject = "") As %DynamicObject
{
    Set tBody = {"SupportedScopes": [{"Scope": "openid", "Description": "OpenID"}, {"Scope": "profile", "Description": "Profile"}], "CustomizationRoles": ["%DB_IRISSYS"]}
    Do tBody.%Set("IssuerEndpoint", ..Issuer(), "string")
    If '$IsObject(pPatch) Quit tBody
    Set tIterator = pPatch.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tType = pPatch.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tBody.%Set(tKey, tValue)
        } Else {
            Do tBody.%Set(tKey, tValue, tType)
        }
    }
    Quit tBody
}

}
