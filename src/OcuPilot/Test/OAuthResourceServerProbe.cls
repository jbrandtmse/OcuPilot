/// <p>Makes, reads and removes the OAuth 2.0 resource servers, service mappings and server descriptions
/// Story 12.6's tests write against on a throwaway instance: servers whose name begins
/// <parameter>PREFIX</parameter>, mappings any of them holds, and descriptions whose issuer's host is
/// <parameter>HOST</parameter>. Nothing else is touched, and everything is removed by exact name.</p>
/// <p>The vendor calls run in <code>%SYS</code> by explicit save and restore (AD-16). A stored secret or
/// credential setting is read back as its length alone. The SSL/TLS configuration is the demo
/// fixture's, so the instance needs the demo.</p>
Class OcuPilot.Test.OAuthResourceServerProbe Extends %RegisteredObject
{

/// <p>What every probe server's name begins with.</p>
Parameter PREFIX = "OcuPilotProbe126";

/// <p>The host every probe description's issuer names.</p>
Parameter HOST = "ocupilotprobe126.invalid";

/// <p>The demo fixture's SSL/TLS configuration.</p>
Parameter SSLCONFIG = "OcuPilotDemoTLS";

/// <p>The two mapping services, the probe authenticator and its namespace.</p>
Parameter WEBGATEWAY = "%Service_WebGateway";

Parameter BINDINGS = "%Service_Bindings";

Parameter AUTHENTICATOR = "OcuPilot.Test.OAuthProbeAuthenticator";

/// <p>A probe server name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
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

/// <p>The namespace this class runs in, where the probe authenticator is compiled.</p>
ClassMethod Namespace() As %String
{
    Quit $NAMESPACE
}

/// <p>Make description <var>pIssuer</var> through the vendor class.</p>
ClassMethod AddServer(pIssuer As %String) As %Status
{
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
        Do tDefinition.Metadata.ImportJSON(tMetadata)
        Set tSC = tDefinition.%Save()
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make server <var>pName</var> through the vendor class, trusting description <var>pIssuer</var>,
/// with the audiences in <var>pAudiences</var> (a <class>%List</class>) and <var>pSettings</var>'s
/// <code>Description</code>, <code>ClientId</code>, <code>ClientSecret</code>,
/// <code>ScopeRequiredToConnect</code> and <code>Authenticator</code> (an object, set whole).</p>
ClassMethod AddResource(pName As %String, pIssuer As %String, pAudiences As %List, pSettings As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tServer = ##class(OAuth2.ResourceServer).%New()
        Set tServer.Name = pName
        Set tServer.ServerDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tOpenSC)
        Set tServer.Audiences = pAudiences
        If $IsObject(pSettings) {
            For tField = "Description", "ClientId", "ClientSecret", "ScopeRequiredToConnect" {
                If pSettings.%GetTypeOf(tField) = "string" Set $Property(tServer, tField) = pSettings.%Get(tField)
            }
            If pSettings.%GetTypeOf("Authenticator") = "object" Set tServer.Authenticator = pSettings.%Get("Authenticator")
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

/// <p>Map <var>pService</var>'s <var>pKey</var> to server <var>pName</var> through the vendor class,
/// creating the mapping or moving it.</p>
ClassMethod Map(pService As %String, pKey As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tServer = ##class(OAuth2.ResourceServer).%OpenId(pName)
        If ##class(OAuth2.ResourceServer.Mapping).Exists(pService, pKey) {
            Set tSC = ##class(OAuth2.ResourceServer.Mapping).Modify(pService, pKey, tServer)
        } Else {
            Set tSC = ##class(OAuth2.ResourceServer.Mapping).Create(pService, pKey, tServer)
        }
        Set tServer = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Server <var>pName</var> as stored: its template fields, <code>Audiences</code> as an array,
/// <code>Authenticator</code> as the vendor serializes it with <code>ApiKey</code> replaced by
/// <code>ApiKeyLength</code>, and <code>SecretLength</code>; or <code>""</code>.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tServer = ##class(OAuth2.ResourceServer).%OpenId(pName)
        If $IsObject(tServer) {
            Set tStored = {}
            For tField = "Description", "ScopeRequiredToConnect", "ClientId", "IntrospectionAuthMethod" Do tStored.%Set(tField, $Property(tServer, tField), "string")
            For tField = "Enabled", "AccessTokenIsJWT", "AlwaysCallIntrospection", "UseOIDC" Do tStored.%Set(tField, $Property(tServer, tField), "boolean")
            Do tStored.%Set("IssuerEndpoint", tServer.IssuerEndpoint, "string")
            Set tAudiences = []
            For tI = 1:1:$ListLength(tServer.Audiences) Do tAudiences.%Push($List(tServer.Audiences, tI))
            Do tStored.%Set("Audiences", tAudiences)
            Set tAuthenticator = ##class(%DynamicAbstractObject).%FromJSON(tServer.Authenticator.Serialize())
            If tAuthenticator.%GetTypeOf("ApiKey") '= "unassigned" {
                Do tAuthenticator.%Set("ApiKeyLength", $Length(tAuthenticator.%Get("ApiKey")), "number")
                Do tAuthenticator.%Remove("ApiKey")
            }
            Do tStored.%Set("Authenticator", tAuthenticator)
            Do tStored.%Set("SecretLength", $Length(tServer.ClientSecret), "number")
        }
        Set tServer = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>Whether server <var>pName</var> exists.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Set tHolds = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = ##class(OAuth2.ResourceServer).%ExistsId(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>The server that holds <var>pService</var>'s <var>pKey</var>, or <code>""</code>.</p>
ClassMethod Holder(pService As %String, pKey As %String) As %String
{
    Set tHolder = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(OAuth2.ResourceServer.Mapping).Exists(pService, pKey, .tMapping) Set tHolder = tMapping.Resource.Name
        Set tMapping = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolder
}

/// <p>Server <var>pName</var>'s mappings as <code>&lt;service&gt;/&lt;key&gt;</code>, sorted,
/// comma-separated.</p>
ClassMethod MappingsOf(pName As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Service, %EXACT(Key) FROM OAuth2_ResourceServer.Mapping WHERE %EXACT(Resource) = ?", pName)
        While tResult.%Next() { Set tSorted(tResult.%GetData(1) _ "/" _ tResult.%GetData(2)) = "" }
        Set $NAMESPACE = tOrigNS
        Set tKey = ""
        For {
            Set tKey = $Order(tSorted(tKey))
            If tKey = "" Quit
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tOut = "-1"
    }
    Quit tOut
}

/// <p>How many probe servers the instance holds.</p>
ClassMethod Count() As %Integer
{
    Quit $ListLength(..ProbeServers())
}

/// <p>Remove every probe server, which removes its mappings, then every description whose issuer's
/// host is <parameter>HOST</parameter>. <var>pRemaining</var> is how many of either survive.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRemaining = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tServers = ..ProbeServers()
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tServers) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ResourceServer).Delete($List(tServers, tI)))
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
        Set pRemaining = pRemaining + $ListLength(..ProbeServers())
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>The probe servers' names, as a <class>%List</class>.</p>
ClassMethod ProbeServers() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(Name) FROM OAuth2.ResourceServer WHERE %EXACT(Name) %STARTSWITH ?", ..#PREFIX)
        While tResult.%Next() { Set tNames = tNames _ $ListBuild(tResult.%GetData(1)) }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>The port's read type <var>pType</var> for server <var>pName</var>, as the shipped port answers
/// it, or <code>""</code>.</p>
ClassMethod Read(pName As %String, pType As %String = "GET") As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.OAuthResourceServerPort).Invoke("Security.OAuth2.ResourceServer", pType, .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Quit tRead
}

}
