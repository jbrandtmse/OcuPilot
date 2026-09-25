/// <p>Makes, reads and removes the OAuth 2.0 objects Story 12.8's tests write against on a throwaway
/// instance: the authorization server configuration (through
/// <class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>) and the clients registered with it,
/// whose names begin <parameter>PREFIX</parameter>. Removing everything leaves no configuration and no
/// client; the vendor's <code>/oauth2</code> web application is left as it is.</p>
/// <p>The vendor calls run in <code>%SYS</code> by explicit save and restore (AD-16). A stored secret
/// is read back as its length, or compared, never answered.</p>
Class OcuPilot.Test.OAuthRegisteredClientProbe Extends %RegisteredObject
{

/// <p>What every probe client's name begins with.</p>
Parameter PREFIX = "OcuPilotProbe128";

/// <p>The host every probe redirect URL names, and a second one for the display-URL rule.</p>
Parameter HOST = "app.ocupilotprobe128.invalid";

Parameter OTHERHOST = "elsewhere.ocupilotprobe128.invalid";

/// <p>The authorization server's own key set, served inside the container, which an Update JWKS can
/// fetch with no internet.</p>
Parameter JWKSURL = "http://localhost:52773/oauth2/jwks";

Parameter ENDPOINT = "Security.OAuth2.ServerClients";

Parameter PORT = "OcuPilot.Port.OAuthRegisteredClientPort";

/// <p>The Story 12.7 probe, which makes and removes the configuration.</p>
Parameter SERVERPROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

/// <p>A probe name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>A probe redirect URL on <parameter>HOST</parameter> with path <var>pPath</var>.</p>
ClassMethod Url(pPath As %String = "cb") As %String
{
    Quit "https://" _ ..#HOST _ "/" _ pPath
}

/// <p>A synthetic secret unique to this call, shaped like no real one.</p>
ClassMethod Secret(pTag As %String) As %String
{
    Quit "ocupilot" _ pTag _ "probe000" _ $Job _ $Translate($Piece($ZTimeStamp, ",", 2), ".", "")
}

/// <p>Make the authorization server configuration, which supports the authorization code and client
/// credentials grants.</p>
ClassMethod Seed() As %Status
{
    Quit $ClassMethod(..#SERVERPROBE, "Seed")
}

/// <p>Register client <var>pName</var> through the vendor class, its id in <var>pClientId</var>: a
/// confidential client redirecting to <method>Url</method> with the authorization code grant and the
/// code response. <var>pSettings</var> may set <code>ClientType</code>, <code>Description</code>,
/// <code>LaunchURL</code>, <code>ClientSecret</code>, <code>RedirectURL</code> (an array) and, under
/// <code>Metadata</code>, any member of the vendor's metadata class.</p>
ClassMethod SeedClient(pName As %String, Output pClientId As %String, pSettings As %DynamicObject = "") As %Status
{
    Set pClientId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tRedirects = $ListBuild(..Url())
        Set tMembers = {}
        If $IsObject(pSettings) {
            If pSettings.%GetTypeOf("RedirectURL") = "array" {
                Set tRedirects = ""
                Set tIterator = pSettings.%Get("RedirectURL").%GetIterator()
                While tIterator.%GetNext(.tIndex, .tUrl) { Set tRedirects = tRedirects _ $ListBuild(tUrl) }
            }
            If pSettings.%GetTypeOf("Metadata") = "object" Set tMembers = pSettings.%Get("Metadata")
        }
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Server.Client).%New()
        Set tClient.Name = pName
        Set tClient.ClientType = "confidential"
        For tI = 1:1:$ListLength(tRedirects) Do tClient.RedirectURL.Insert($List(tRedirects, tI))
        Set tClient.Metadata."grant_types" = $ListBuild("authorization_code", "refresh_token")
        Set tClient.Metadata."response_types" = $ListBuild("code")
        If $IsObject(pSettings) {
            For tField = "ClientType", "Description", "LaunchURL", "ClientSecret" {
                If pSettings.%GetTypeOf(tField) = "string" Set $Property(tClient, tField) = pSettings.%Get(tField)
            }
        }
        Set tIterator = tMembers.%GetIterator()
        While tIterator.%GetNext(.tMember, .tValue) {
            If $IsObject(tValue) {
                Set tList = ""
                Set tItems = tValue.%GetIterator()
                While tItems.%GetNext(.tItemIndex, .tItem) { Set tList = tList _ $ListBuild(tItem) }
                Set $Property(tClient.Metadata, tMember) = tList
            } Else {
                Set $Property(tClient.Metadata, tMember) = tValue
            }
        }
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

/// <p>Set client <var>pClientId</var>'s metadata member <var>pMember</var> to <var>pValue</var> through
/// the vendor class, as a vendor write the admin API does not make.</p>
ClassMethod SetMember(pClientId As %String, pMember As %String, pValue As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Server.Client).%OpenId(pClientId, , .tSC)
        If $IsObject(tClient) {
            Set $Property(tClient.Metadata, pMember) = pValue
            Set tSC = tClient.%Save()
        }
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Client <var>pClientId</var> as stored, or <code>""</code>: its text fields, its redirect URLs
/// comma-separated, its metadata as the vendor exports it less the two secret members, those two and
/// the secret as <code>SecretLength</code>, <code>ClientSecretLength</code> and
/// <code>RegistrationTokenLength</code>, and <code>PublicKeys</code>.</p>
ClassMethod Stored(pClientId As %String) As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Server.Client).%OpenId(pClientId)
        If $IsObject(tClient) {
            Do tClient.%Reload()
            If $IsObject(tClient.Metadata) Do tClient.Metadata.%Reload()
            Set tStored = {}
            For tField = "Name", "Description", "ClientType", "LaunchURL", "DefaultScope", "ClientCredentials" {
                Do tStored.%Set(tField, $Property(tClient, tField), "string")
            }
            Set tUrls = ""
            For tI = 1:1:tClient.RedirectURL.Count() Set tUrls = tUrls _ $Select(tI = 1: "", 1: ",") _ tClient.RedirectURL.GetAt(tI)
            Do tStored.%Set("RedirectURL", tUrls, "string")
            Set tMetadata = ##class(%DynamicAbstractObject).%FromJSON(tClient.Metadata.ExportJSON())
            Do tStored.%Set("ClientSecretLength", $Length(tMetadata.%Get("client_secret")), "number")
            Do tStored.%Set("RegistrationTokenLength", $Length(tMetadata.%Get("registration_access_token")), "number")
            Do tMetadata.%Remove("client_secret")
            Do tMetadata.%Remove("registration_access_token")
            Do tStored.%Set("Metadata", tMetadata)
            Do tStored.%Set("SecretLength", $Length(tClient.ClientSecret), "number")
            Set tJwks = tClient.PublicJWKS
        }
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
        ; Counted here, where the class that counts is compiled.
        If $IsObject(tStored) Do tStored.%Set("PublicKeys", $ClassMethod(..#SERVERPROBE, "KeysIn", $Get(tJwks)), "number")
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>Whether client <var>pClientId</var>'s stored secret is <var>pSecret</var>.</p>
ClassMethod SecretIs(pClientId As %String, pSecret As %String) As %Boolean
{
    Set tIs = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ##class(OAuth2.Server.Client).%OpenId(pClientId)
        If $IsObject(tClient) {
            Do tClient.%Reload()
            Set tIs = (tClient.ClientSecret = pSecret)
        }
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tIs = 0
    }
    Quit tIs
}

/// <p>The client id of the one registered client named <var>pName</var>, or <code>""</code>.</p>
ClassMethod IdOf(pName As %String) As %String
{
    Set tId = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ClientId) AS ClientId FROM OAuth2_Server.Client WHERE %EXACT(Name) = ?", pName)
        If tRS.%Next() Set tId = tRS.%Get("ClientId")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tId
}

/// <p>How many clients are registered, or -1.</p>
ClassMethod ClientCount() As %Integer
{
    Quit $ClassMethod(..#SERVERPROBE, "ClientCount")
}

/// <p>Whether the instance holds an authorization server configuration.</p>
ClassMethod Holds() As %Boolean
{
    Quit $ClassMethod(..#SERVERPROBE, "Holds")
}

/// <p>Remove every registered client and the configuration. <var>pRemaining</var> is how many clients
/// and configurations survive.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRemaining = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ClientId) AS ClientId FROM OAuth2_Server.Client")
        While tRS.%Next() { Set tIds = tIds _ $ListBuild(tRS.%Get("ClientId")) }
        For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Server.Client).DeleteId($List(tIds, tI)))
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, $ClassMethod(..#SERVERPROBE, "RemoveAll", .tServerRemaining))
        Set pRemaining = tServerRemaining + $Select(..ClientCount() > 0: ..ClientCount(), 1: 0)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Client <var>pClientId</var> as the shipped port's <code>GET</code> answers it, or
/// <code>""</code>.</p>
ClassMethod Read(pClientId As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("clientId") = pClientId
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Quit tRead
}

/// <p>A create's body: a confidential client named <var>pName</var> redirecting to
/// <method>Url</method> with the authorization code grant and the code response, and <var>pPatch</var>'s
/// fields set over it.</p>
ClassMethod Body(pName As %String, pPatch As %DynamicObject = "") As %DynamicObject
{
    Set tBody = {"ClientType": "confidential", "Metadata": {"grant_types": ["authorization_code"], "response_types": ["code"]}}
    Do tBody.%Set("Name", pName, "string")
    Do tBody.%Set("RedirectURL", [(..Url())])
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
