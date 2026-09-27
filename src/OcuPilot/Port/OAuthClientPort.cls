/// <p>The OAuth 2.0 client configuration port (AD-52): <class>OcuPilot.Port.AdminPort</class> with
/// <parameter>CLIENTENDPOINT</parameter>'s reads stripped of their secrets and its writes shaped
/// here. Every call is the admin port's own, behind the endpoint's own gate; no vendor class
/// completes an operation (AD-27), and the one vendor class read is the credential check
/// (<method>CredentialUsable</method>).</p>
/// <p><b>No read returns a secret</b> (AD-35). The vendor's <code>GET</code> and <code>PUT</code>
/// answer <code>Metadata.client_secret</code> and <code>Metadata.registration_access_token</code> in
/// plain text; <parameter>SECRETMEMBERS</parameter> are removed from each <code>GET</code> and
/// <code>PUT</code> answer before a caller sees it. The other writes answer the vendor's empty
/// object, which carries neither.</p>
/// <p><b><code>PUT</code></b> refuses a <code>ClientCredentials</code> the caller cannot use or that
/// has no private key on its field, after its gated fresh read and before the vendor's write (the
/// vendor answers 500). The body's
/// <code>Metadata</code> never carries a <parameter>SECRETMEMBERS</parameter> member, and carries each
/// <parameter>MANAGEDMEMBERS</parameter> member as this port's own fresh read has it, whatever the
/// caller sent: an argument cannot clear a registration. When the vendor saves a registered client
/// and then fails to update its registration it answers 500 with the change stored; a re-read that
/// finds every sent field stored answers 200 with <code>registrationNotUpdated</code>. Any other 500
/// is <parameter>OcuPilot.Api.Error.OAUTHCLIENTVALIDATION</parameter>, the vendor's text logged
/// alone.</p>
/// <p><b><parameter>SECRETSTYPE</parameter></b> takes the flat declared secrets
/// <parameter>SECRETNAMES</parameter> and sends the vendor's own shape, the registration access token
/// nested under <code>Metadata</code>. A body with none is refused: the vendor saves on an empty
/// one.</p>
/// <p><b><parameter>REGISTRATIONTYPE</parameter></b> is a read this port answers itself:
/// <code>{ClientId, RegistrationClientUri, ServerDefinition, RegistrationEndpoint}</code>, the last
/// from the client's server description. <b><parameter>REGISTERTYPE</parameter></b> is refused by
/// name on a client that is registered or whose description has no registration endpoint, and
/// <b><parameter>ROTATETYPE</parameter></b> on a client whose keys come from its X.509 credential,
/// for which the vendor answers 200 and changes nothing.</p>
Class OcuPilot.Port.OAuthClientPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port shapes.</p>
Parameter CLIENTENDPOINT = "Security.OAuth2.Client.ClientConfiguration";

/// <p>The server description endpoint the registration read looks its endpoint up through.</p>
Parameter SERVERENDPOINT = "Security.OAuth2.Client.ServerDefinition";

/// <p>The vendor's query parameters for a client and a server description.</p>
Parameter CLIENTQUERY = "applicationName";

Parameter SERVERQUERY = "serverId";

/// <p>The metadata members no answer carries and no body sends.</p>
Parameter SECRETMEMBERS = "client_secret,registration_access_token";

/// <p>The metadata members a body carries as the fresh read has them: the four a registration
/// manages, and <code>jwks</code>, which the vendor manages and whose empty form it refuses.</p>
Parameter MANAGEDMEMBERS = "client_id,registration_client_uri,client_id_issued_at,client_secret_expires_at,jwks";

/// <p>The member that says a client is registered.</p>
Parameter REGISTRATIONURIMEMBER = "registration_client_uri";

/// <p>The vendor's secret write, the flat declared secrets it takes, and the vendor's metadata
/// member the registration access token is nested as.</p>
Parameter SECRETSTYPE = "CHANGESECRET";

Parameter SECRETNAMES = "ClientSecret,ClientPassword,RegistrationAccessToken";

Parameter TOKENNAME = "RegistrationAccessToken";

Parameter TOKENMEMBER = "registration_access_token";

/// <p>The read this port answers itself, and the two action writes it refuses by name.</p>
Parameter REGISTRATIONTYPE = "REGISTRATION";

Parameter REGISTERTYPE = "REGISTERCLIENT";

Parameter ROTATETYPE = "ROTATEKEYS";

/// <p>The admin port's call, with <parameter>CLIENTENDPOINT</parameter> shaped here.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s; <var>pQuery</var> and <var>pBody</var> are not
/// modified. A successful <code>PUT</code> of a registered client whose registration could not be
/// updated answers 200 with <code>registrationNotUpdated</code>, a sentence, on <var>pResult</var>.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#CLIENTENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If pType = "GET" {
            Set tSC = ##super(pEndpoint, "GET", .pQuery, "", .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) Set pResult = ..Stripped(pResult)
            Quit
        }
        If pType = "PUT" {
            Set tSC = ..Put(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#SECRETSTYPE {
            Set tSC = ..ChangeSecrets(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#REGISTRATIONTYPE {
            Set tSC = ..Registration(.pQuery, .pResult, .pHttpStatus, .pFault, .tIssuer)
            Quit
        }
        If pType = ..#REGISTERTYPE {
            Set tSC = ..Register(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#ROTATETYPE {
            Set tSC = ##super(pEndpoint, "GET", .pQuery, "", .tRead, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If $IsObject(tRead) && (..Text(tRead, "ClientCredentials") '= "") {
                Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHCLIENTKEYSFROMCREDENTIALS, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTKEYSFROMCREDENTIALS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The admin port's own call, unshaped: what every helper below reaches the vendor through.</p>
ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>A copy of <var>pRead</var> with no <parameter>SECRETMEMBERS</parameter> member in its
/// <code>Metadata</code>; anything that is not an object is answered as it is.</p>
ClassMethod Stripped(pRead) As %DynamicAbstractObject
{
    If '$IsObject(pRead) || 'pRead.%IsA("%Library.DynamicObject") Quit pRead
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pRead.%ToJSON())
    If tCopy.%GetTypeOf("Metadata") = "object" {
        For tI = 1:1:$Length(..#SECRETMEMBERS, ",") Do tCopy.%Get("Metadata").%Remove($Piece(..#SECRETMEMBERS, ",", tI))
    }
    Quit tCopy
}

/// <p>Whether the calling process can use the X.509 credential <var>pAlias</var> and it holds a
/// private key, which the vendor's save requires of a client's credentials. The caller's namespace
/// is unchanged on return (AD-16).</p>
ClassMethod CredentialUsable(pAlias As %String) As %Boolean
{
    If pAlias = "" Quit 0
    Set tUsable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCredential = ##class(%SYS.X509Credentials).GetByAlias(pAlias)
        Set tUsable = $IsObject(tCredential) && tCredential.HasPrivateKey
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tUsable = 0
    }
    Quit tUsable
}

/// <p>The <code>PUT</code> this port sends: a fresh read, the credential check, the body's metadata
/// shaped over the read, the vendor's write, and the registered-client case (class description).</p>
ClassMethod Put(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Vendor(..#CLIENTENDPOINT, "PUT", .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    ; The fresh read the managed members are taken from, and which says whether the client is
    ; registered. A 404 is a create, which has neither. It is the vendor's, so a caller without the
    ; endpoint's resource is refused by the endpoint's own gate before the credential is looked at.
    Set tReadSC = ..Vendor(..#CLIENTENDPOINT, "GET", .pQuery, "", .tFresh, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
        Set pHttpStatus = tReadHttp
        Set pFault = tReadFault
        Quit tReadSC
    }
    If $$$ISERR(tReadSC) Set tFresh = ""
    If (tBody.%GetTypeOf("ClientCredentials") = "string") && (tBody.%Get("ClientCredentials") '= "") && '..CredentialUsable(tBody.%Get("ClientCredentials")) {
        Quit ..Violation("ClientCredentials", ##class(OcuPilot.Api.Error).#OAUTHCLIENTCREDENTIALSABSENT, .pHttpStatus, .pFault)
    }
    Set tFreshMetadata = ""
    If $IsObject(tFresh) && (tFresh.%GetTypeOf("Metadata") = "object") Set tFreshMetadata = tFresh.%Get("Metadata")
    If tBody.%GetTypeOf("Metadata") = "object" {
        Set tMetadata = tBody.%Get("Metadata")
        For tI = 1:1:$Length(..#SECRETMEMBERS, ",") Do tMetadata.%Remove($Piece(..#SECRETMEMBERS, ",", tI))
        For tI = 1:1:$Length(..#MANAGEDMEMBERS, ",") {
            Set tMember = $Piece(..#MANAGEDMEMBERS, ",", tI)
            Set tType = $Select($IsObject(tFreshMetadata): tFreshMetadata.%GetTypeOf(tMember), 1: "unassigned")
            If (tType = "unassigned") || (tType = "null") {
                Do tMetadata.%Remove(tMember)
            } ElseIf (tType = "object") || (tType = "array") {
                Do tMetadata.%Set(tMember, ##class(%DynamicAbstractObject).%FromJSON(tFreshMetadata.%Get(tMember).%ToJSON()))
            } Else {
                Do tMetadata.%Set(tMember, tFreshMetadata.%Get(tMember), tType)
            }
        }
    }
    Set tRegistered = $IsObject(tFreshMetadata) && (..Text(tFreshMetadata, ..#REGISTRATIONURIMEMBER) '= "")
    Set tSC = ..Vendor(..#CLIENTENDPOINT, "PUT", .pQuery, tBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) {
        Set pResult = ..Stripped(pResult)
        Quit tSC
    }
    If +pHttpStatus '= 500 Quit tSC
    If tRegistered {
        ; The vendor saves first and then updates the registration; a 500 here may be a stored
        ; change whose registration update failed.
        Set tAfterSC = ..Vendor(..#CLIENTENDPOINT, "GET", .pQuery, "", .tAfter, .tAfterHttp, .tAfterFault)
        If $$$ISOK(tAfterSC) && ..SentStored(tBody, tAfter) {
            Set pResult = ..Stripped(tAfter)
            Do pResult.%Set("registrationNotUpdated", ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTRATIONNOTUPDATED, "string")
            Set pHttpStatus = 200
            Set pFault = ""
            Quit $$$OK
        }
    }
    Set tDetail = ""
    If $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") Set tDetail = pFault.%Get("detail")
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTVALIDATION, .pHttpStatus, .pFault, tDetail)
}

/// <p>Whether the re-read <var>pRead</var> holds every field <var>pSent</var> carried: each top-level
/// value, and each <code>Metadata</code> member, an empty one read as absent or empty. A scope is
/// compared with its whitespace collapsed, as the vendor stores it, and a redirect URL with any
/// trailing slash removed.</p>
ClassMethod SentStored(pSent As %DynamicObject, pRead) As %Boolean [ Private ]
{
    If '$IsObject(pRead) || 'pRead.%IsA("%Library.DynamicObject") Quit 0
    Set tHolds = 1
    Set tIterator = pSent.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = "Metadata" {
            Set tReadMetadata = $Select(pRead.%GetTypeOf("Metadata") = "object": pRead.%Get("Metadata"), 1: {})
            If '$IsObject(tValue) Continue
            Set tMembers = tValue.%GetIterator()
            While tMembers.%GetNext(.tMember, .tMemberValue) {
                If '..MatchesRead(tValue, tMember, tReadMetadata) Set tHolds = 0
            }
            Continue
        }
        If (tKey = "JWTInterval") && (..Text(pSent, tKey) = "") Continue
        If tKey = "DefaultScope" {
            If ..Words(..Text(pSent, tKey)) '= ..Words(..Text(pRead, tKey)) Set tHolds = 0
            Continue
        }
        If tKey = "RedirectionEndpoint" {
            If ..Unslashed(..Text(pSent, tKey)) '= ..Unslashed(..Text(pRead, tKey)) Set tHolds = 0
            Continue
        }
        If '..MatchesRead(pSent, tKey, pRead) Set tHolds = 0
    }
    Quit tHolds
}

/// <p>Whether <var>pRead</var>'s <var>pKey</var> equals <var>pSent</var>'s: arrays and objects by
/// their JSON, an empty form against an absent or empty value, anything else by its text.</p>
ClassMethod MatchesRead(pSent As %DynamicObject, pKey As %String, pRead As %DynamicObject) As %Boolean [ Private ]
{
    Set tSentType = pSent.%GetTypeOf(pKey)
    Set tReadType = pRead.%GetTypeOf(pKey)
    If (tSentType = "array") || (tSentType = "object") {
        Set tSentJson = pSent.%Get(pKey).%ToJSON()
        If (tSentJson = "[]") || (tSentJson = "{}") Quit (tReadType = "unassigned") || (tReadType = "null") || ((tReadType = tSentType) && (pRead.%Get(pKey).%Size() = 0))
        Quit ((tReadType = "array") || (tReadType = "object")) && (tSentJson = pRead.%Get(pKey).%ToJSON())
    }
    Set tSent = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pSent.%Get(pKey), tSentType)
    Set tRead = $Select((tReadType = "unassigned") || (tReadType = "null"): "", 1: ##class(OcuPilot.Kernel.Proposal.Mint).Display(pRead.%Get(pKey), tReadType))
    Quit tSent = tRead
}

/// <p>The secrets write: <var>pBody</var>'s flat <parameter>SECRETNAMES</parameter> in the vendor's
/// own shape. A key outside them is refused as a caller fault; a body with no non-empty secret is
/// 422 <parameter>OcuPilot.Api.Error.OAUTHCLIENTNOSECRET</parameter> with nothing sent.</p>
ClassMethod ChangeSecrets(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tVendor = {}
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind($ListFromString(..#SECRETNAMES), tKey) {
                Set tVendor = ""
                Quit
            }
            If (pBody.%GetTypeOf(tKey) '= "string") || (tValue = "") Continue
            If tKey = ..#TOKENNAME {
                Set tNested = {}
                Do tNested.%Set(..#TOKENMEMBER, tValue, "string")
                Do tVendor.%Set("Metadata", tNested)
            } Else {
                Do tVendor.%Set(tKey, tValue, "string")
            }
        }
    } ElseIf pBody '= "" {
        Set tVendor = ""
    }
    If '$IsObject(tVendor) {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#CLIENTENDPOINT _ " " _ ..#SECRETSTYPE _ " was given a key outside its declared secrets", $$$ERROR($$$GeneralError, "a secrets body carries only " _ ..#SECRETNAMES), pFault.code)
        Quit tSC
    }
    If tVendor.%Size() = 0 Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHCLIENTNOSECRET, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTNOSECRET, .pHttpStatus, .pFault)
    Set tSC = ..Vendor(..#CLIENTENDPOINT, ..#SECRETSTYPE, .pQuery, tVendor, .pResult, .pHttpStatus, .pFault)
    Set tVendor = ""
    Quit tSC
}

/// <p>The <parameter>REGISTRATIONTYPE</parameter> read: <code>{ClientId, RegistrationClientUri,
/// ServerDefinition, RegistrationEndpoint}</code>, with the description's issuer in
/// <var>pIssuer</var>. An absent client is the vendor's 404.</p>
ClassMethod Registration(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pIssuer As %String) As %Status [ Private ]
{
    Set pResult = ""
    Set pIssuer = ""
    Set tSC = ..Vendor(..#CLIENTENDPOINT, "GET", .pQuery, "", .tRead, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRead) || 'tRead.%IsA("%Library.DynamicObject") Quit ..Fail(..#CLIENTENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tMetadata = $Select(tRead.%GetTypeOf("Metadata") = "object": tRead.%Get("Metadata"), 1: {})
    Set tEndpoint = ""
    Set tServerId = ..Text(tRead, "ServerDefinition")
    If tServerId '= "" {
        Kill tServerQuery
        Set tServerQuery(..#SERVERQUERY) = tServerId
        Set tServerSC = ..Vendor(..#SERVERENDPOINT, "GET", .tServerQuery, "", .tServer, .tServerHttp, .tServerFault)
        If $$$ISERR(tServerSC) && (+$Get(tServerHttp) '= 404) {
            Set pHttpStatus = tServerHttp
            Set pFault = tServerFault
            Quit tServerSC
        }
        If $$$ISOK(tServerSC) && $IsObject(tServer) {
            Set pIssuer = ..Text(tServer, "IssuerEndpoint")
            If tServer.%GetTypeOf("Metadata") = "object" Set tEndpoint = ..Text(tServer.%Get("Metadata"), "registration_endpoint")
        }
    }
    Set pResult = {}
    Do pResult.%Set("ClientId", ..Text(tRead, "ClientId"), "string")
    Do pResult.%Set("RegistrationClientUri", ..Text(tMetadata, ..#REGISTRATIONURIMEMBER), "string")
    Do pResult.%Set("ServerDefinition", tServerId, "string")
    Do pResult.%Set("RegistrationEndpoint", tEndpoint, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The registration write, refused by name on a registered client or a description with no
/// registration endpoint before anything is sent. A vendor failure is
/// <parameter>OcuPilot.Api.Error.OAUTHCLIENTREGISTRATIONFAILED</parameter> naming the issuer, the
/// vendor's text logged alone.</p>
ClassMethod Register(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..Registration(.pQuery, .tState, .pHttpStatus, .pFault, .tIssuer)
    If $$$ISERR(tSC) Quit tSC
    If (tState.%Get("ClientId") '= "") || (tState.%Get("RegistrationClientUri") '= "") {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHCLIENTREGISTERED, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTERED, .pHttpStatus, .pFault)
    }
    If tState.%Get("RegistrationEndpoint") = "" {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHCLIENTNOREGISTRATIONENDPOINT, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTNOREGISTRATIONENDPOINT, .pHttpStatus, .pFault)
    }
    Set tSC = ..Vendor(..#CLIENTENDPOINT, ..#REGISTERTYPE, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    ; The vendor refuses a description with no endpoint (#8881) with the same 500 as a failed
    ; registration, and its text reaches the log alone; a re-read tells the two apart.
    Set tStateSC = ..Registration(.pQuery, .tAfter, .tAfterHttp, .tAfterFault, .tAfterIssuer)
    If $$$ISOK(tStateSC) && (tAfter.%Get("RegistrationEndpoint") = "") {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHCLIENTNOREGISTRATIONENDPOINT, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTNOREGISTRATIONENDPOINT, .pHttpStatus, .pFault)
    }
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHCLIENTREGISTRATIONFAILED, $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTRATIONFAILED, "{issuer}", $Select(tIssuer = "": tState.%Get("RegistrationEndpoint"), 1: tIssuer)), .pHttpStatus, .pFault)
}

/// <p>A 422 <parameter>OcuPilot.Api.Error.OAUTHCLIENTVALIDATION</parameter> fault carrying one
/// violation of <var>pCode</var> on <var>pField</var> (AD-39).</p>
ClassMethod Violation(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tRow)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTVALIDATION, .pHttpStatus, .pFault, tDetail)
}

/// <p><var>pObject</var>'s <var>pKey</var> as text: absent, null, an object or an array as
/// <code>""</code>.</p>
ClassMethod Text(pObject, pKey As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pKey)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pKey)
}

/// <p><var>pText</var> with its whitespace runs collapsed to one space and trimmed.</p>
ClassMethod Words(pText As %String) As %String [ Private ]
{
    Quit $ZStrip(pText, "<=>W")
}

/// <p><var>pUrl</var> without a trailing slash.</p>
ClassMethod Unslashed(pUrl As %String) As %String [ Private ]
{
    If $Extract(pUrl, *) = "/" Quit $Extract(pUrl, 1, *-1)
    Quit pUrl
}

/// <p>The admin port's answer: every write of this port is the vendor's own route.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59): <code>PUT</code> sends the body
/// with the secret <code>Metadata</code> members <parameter>SECRETMEMBERS</parameter> removed -- the
/// managed members are the stored read's, as the port takes them from the fresh one -- and
/// <parameter>SECRETSTYPE</parameter> sends each non-empty declared secret, the registration access
/// token under <code>Metadata</code>. Every other call is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#CLIENTENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    If (pType = "PUT") && $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
        If tBody.%GetTypeOf("Metadata") = "object" {
            For tI = 1:1:$Length(..#SECRETMEMBERS, ",") Do tBody.%Get("Metadata").%Remove($Piece(..#SECRETMEMBERS, ",", tI))
        }
        Quit ##super(pEndpoint, pType, .pQuery, tBody, pContext)
    }
    If pType = ..#SECRETSTYPE {
        Set tVendor = {}
        If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
            Set tIterator = pBody.%GetIterator()
            While tIterator.%GetNext(.tKey, .tValue) {
                If '$ListFind($ListFromString(..#SECRETNAMES), tKey) || $IsObject(tValue) || (tValue = "") Continue
                If tKey = ..#TOKENNAME {
                    Set tNested = {}
                    Do tNested.%Set(..#TOKENMEMBER, tValue, "string")
                    Do tVendor.%Set("Metadata", tNested)
                } Else {
                    Do tVendor.%Set(tKey, tValue, "string")
                }
            }
        }
        Quit ##super(pEndpoint, pType, .pQuery, tVendor, pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
