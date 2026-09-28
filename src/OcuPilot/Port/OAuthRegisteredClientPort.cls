/// <p>The OAuth 2.0 server client description port (AD-51, AD-52): <class>OcuPilot.Port.AdminPort</class>
/// with <parameter>CLIENTENDPOINT</parameter>'s calls shaped here, behind the endpoint's own gate and
/// this port's <parameter>GATEPAIRS</parameter>.</p>
/// <p><b>No answer carries a secret member.</b> The vendor's <code>GET</code> never answers
/// <code>ClientSecret</code>, and answers <code>Metadata.client_secret</code> and
/// <code>Metadata.registration_access_token</code> unmasked when they are set (measured); every
/// answer this port gives has <parameter>SECRETMEMBERS</parameter> removed (<method>Stripped</method>),
/// and a <code>POST</code> or <code>PUT</code> body carrying one is refused before the vendor.</p>
/// <p><b><code>POST</code></b> answers the new client's id as <parameter>CREATEDFIELD</parameter>,
/// read from the 201's <code>Location</code> header, which the vendor writes as
/// <code>.../client?clientId=&lt;id&gt;</code>. A vendor 500 on a <code>POST</code> or <code>PUT</code>
/// is named (<method>Named</method>): a grant type the authorization server does not support, a
/// credential the instance does not hold, and a missing authorization server configuration; any
/// other is <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTVALIDATION</parameter>, the vendor's text
/// logged alone.</p>
/// <p><b><parameter>SECRETTYPE</parameter></b> takes <code>{ClientSecret}</code> alone, non-empty:
/// the vendor stores an empty or null one, which clears the stored secret.</p>
/// <p><b><parameter>JWKSTYPE</parameter> and <parameter>REFRESHTYPE</parameter> are this port's
/// own</b> (AD-27, Story 12.8's case): the admin API has no JWKS type for a server client, so after
/// the gate they read and refresh the client's public key set through
/// <parameter>CLIENTCLASS</parameter> in <code>%SYS</code> (AD-16). The read answers
/// <code>{JwksUri, ClientCredentials, PublicKeys}</code>, the last the number of keys the stored
/// public key set holds; it never reads the symmetric key set, which derives from the secret. The
/// refresh fetches from the stored <code>jwks_uri</code> through OcuPilot's own client SSL/TLS
/// configuration for an <code>https</code> URL and none for <code>http</code> (AD-32).</p>
Class OcuPilot.Port.OAuthRegisteredClientPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port shapes, and the query parameter it names a client by.</p>
Parameter CLIENTENDPOINT = "Security.OAuth2.ServerClients";

Parameter IDQUERY = "clientId";

/// <p>The <code>Metadata</code> members no answer carries and no body may send.</p>
Parameter SECRETMEMBERS = "client_secret,registration_access_token";

Parameter METADATAFIELD = "Metadata";

/// <p>The member of a <code>POST</code>'s answer this port sets to the new client's id.</p>
Parameter CREATEDFIELD = "ClientId";

/// <p>The vendor's secret write and the one secret it takes.</p>
Parameter SECRETTYPE = "SECRET";

Parameter SECRETFIELD = "ClientSecret";

/// <p>The read and the write this port carries out itself, each taking no caller body.</p>
Parameter JWKSTYPE = "JWKS";

Parameter REFRESHTYPE = "REFRESHJWKS";

Parameter COMPOSEDTYPES = "Security.OAuth2.ServerClients/JWKS,Security.OAuth2.ServerClients/REFRESHJWKS";

/// <p>The vendor class the key set is read and refreshed through.</p>
Parameter CLIENTCLASS = "OAuth2.Server.Client";

/// <p>The metadata member holding the key set's URL, and the <code>JWKSTYPE</code> read's fields.</p>
Parameter JWKSMEMBER = "jwks_uri";

Parameter JWKSFIELDS = "JwksUri,ClientCredentials,PublicKeys";

/// <p>The pairs every <parameter>CLIENTENDPOINT</parameter> call through this port requires, in the
/// order a refusal names the first one missing (AD-29): the server client descriptions tab's own set.
/// The vendor endpoint's <code>ResourcesOR()</code> is <code>%Admin_OAuth2_Registration</code>, and
/// the vendor class reads the system database.</p>
Parameter GATEPAIRS = "%Admin_OAuth2_Registration:USE,%DB_IRISSYS:READ";

/// <p>The admin port's call, with <parameter>CLIENTENDPOINT</parameter>'s <code>GET</code>,
/// <code>LIST</code>, <code>POST</code>, <code>PUT</code>, <code>DELETE</code>,
/// <parameter>SECRETTYPE</parameter>, <parameter>JWKSTYPE</parameter> and
/// <parameter>REFRESHTYPE</parameter> shaped here; any other endpoint or type is the admin port's own
/// call.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s; the client is <code>pQuery("clientId")</code>,
/// and neither <var>pQuery</var> nor <var>pBody</var> is modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#CLIENTENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If '$ListFind($ListBuild("GET", "LIST", "POST", "PUT", "DELETE", ..#SECRETTYPE, ..#JWKSTYPE, ..#REFRESHTYPE), pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRefused = ..RefusedPair()
    If tRefused '= "" Quit ..GateRefusal(tRefused, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Try {
        If (pType = "GET") || (pType = "LIST") {
            Set tSC = ..Vendor(pEndpoint, pType, .pQuery, "", .tAnswer, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) Set pResult = ..Stripped($Get(tAnswer))
            Quit
        }
        If (pType = "POST") || (pType = "PUT") {
            Set tSC = ..SendWrite(pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#SECRETTYPE {
            Set tSC = ..ChangeSecret(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If ($IsObject(pBody) || (pBody '= "")) && ($ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) || (pType = "DELETE")) {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a bodyless type takes no caller body"), pFault.code)
            Quit
        }
        If pType = ..#JWKSTYPE {
            Set tSC = ..KeySetState($Get(pQuery(..#IDQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#REFRESHTYPE {
            Set tSC = ..RefreshKeySet($Get(pQuery(..#IDQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Vendor(pEndpoint, "DELETE", .pQuery, "", .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The admin port's own call, unshaped.</p>
ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's own call, unshaped, with the answer's <code>Location</code> header in
/// <var>pLocation</var>.</p>
ClassMethod VendorLocated(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Port.AdminPort).InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>A copy of <var>pAnswer</var> with <parameter>SECRETMEMBERS</parameter> removed from its
/// <code>Metadata</code>, and from each row's when it is an array; anything else is answered as it
/// is.</p>
ClassMethod Stripped(pAnswer) As %DynamicAbstractObject
{
    If '$IsObject(pAnswer) Quit pAnswer
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pAnswer.%ToJSON())
    If tCopy.%IsA("%Library.DynamicArray") {
        Set tIterator = tCopy.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) Do ..StripMembers(tRow)
        }
        Quit tCopy
    }
    Do ..StripMembers(tCopy)
    Quit tCopy
}

/// <p>Remove <parameter>SECRETMEMBERS</parameter> from <var>pObject</var>'s <code>Metadata</code>.</p>
ClassMethod StripMembers(pObject) [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit
    If pObject.%GetTypeOf(..#METADATAFIELD) '= "object" Quit
    Set tMetadata = pObject.%Get(..#METADATAFIELD)
    For tI = 1:1:$Length(..#SECRETMEMBERS, ",") Do tMetadata.%Remove($Piece(..#SECRETMEMBERS, ",", tI))
}

/// <p>Whether <var>pBody</var>'s <code>Metadata</code> carries a member of
/// <parameter>SECRETMEMBERS</parameter>.</p>
ClassMethod CarriesSecret(pBody) As %Boolean
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    If pBody.%GetTypeOf(..#SECRETFIELD) '= "unassigned" Quit 1
    If pBody.%GetTypeOf(..#METADATAFIELD) '= "object" Quit 0
    Set tCarries = 0
    For tI = 1:1:$Length(..#SECRETMEMBERS, ",") {
        If pBody.%Get(..#METADATAFIELD).%GetTypeOf($Piece(..#SECRETMEMBERS, ",", tI)) '= "unassigned" Set tCarries = 1
    }
    Quit tCarries
}

/// <p>A <code>POST</code> or <code>PUT</code> (<var>pType</var>): a body carrying a secret is refused
/// as a caller fault and nothing is sent; the vendor's write; its answer stripped, a create's with the
/// new id set; a vendor 500 named.</p>
ClassMethod SendWrite(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..CarriesSecret(pBody) {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#CLIENTENDPOINT _ " " _ pType _ " was given a secret in its body", $$$ERROR($$$GeneralError, "a client's secret travels only through its secret type"), pFault.code)
        Quit tSC
    }
    If pType = "POST" {
        Set tSC = ..VendorLocated(..#CLIENTENDPOINT, pType, .pQuery, pBody, .tAnswer, .pHttpStatus, .pFault, .tLocation)
    } Else {
        Set tSC = ..Vendor(..#CLIENTENDPOINT, pType, .pQuery, pBody, .tAnswer, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Quit ..Named(tSC, .pHttpStatus, .pFault)
    Set pResult = ..Stripped($Get(tAnswer))
    If pType '= "POST" Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Set pResult = {}
    Set tId = ..LocatedId($Get(tLocation))
    If tId '= "" Do pResult.%Set(..#CREATEDFIELD, tId, "string")
    Quit tSC
}

/// <p>The client id a create's <code>Location</code> <var>pLocation</var> names in its
/// <parameter>IDQUERY</parameter> query parameter, decoded, or <code>""</code>.</p>
ClassMethod LocatedId(pLocation As %String) As %String
{
    Set tQuery = $Piece(pLocation, "?", 2, *)
    For tI = 1:1:$Length(tQuery, "&") {
        Set tPart = $Piece(tQuery, "&", tI)
        If $Piece(tPart, "=", 1) '= ..#IDQUERY Continue
        Quit
    }
    If $Piece($Get(tPart), "=", 1) '= ..#IDQUERY Quit ""
    Quit $ZConvert($Piece(tPart, "=", 2, *), "I", "URL")
}

/// <p>A failed write <var>pSC</var>, named: at a vendor 500 the violation rows the admin port read off
/// the vendor's status decide it (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>) -- no
/// authorization server configuration is a 422 of its own, a grant type or a credential is a
/// violation on its field, and anything else is
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTVALIDATION</parameter>. Any other status is answered
/// as it is.</p>
ClassMethod Named(pSC As %Status, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    If +$Get(pHttpStatus) '= 500 Quit pSC
    Set tRows = ""
    If $IsObject($Get(pFault)) && (pFault.%GetTypeOf("detail") = "object") Set tRows = pFault.%Get("detail").%Get("violations")
    Set (tField, tCode) = ""
    If $IsObject(tRows) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            If tRow.%Get("code") = ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTCONFIGABSENT {
                Set tCode = tRow.%Get("code")
                Set tField = ""
                Quit
            }
            If (tCode = "") && ($Piece(tRow.%Get("code"), ".", 1) = "OAUTH") {
                Set tField = tRow.%Get("field")
                Set tCode = tRow.%Get("code")
            }
        }
    }
    If tCode = ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTCONFIGABSENT Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTCONFIGABSENT, .pHttpStatus, .pFault)
    If (tCode '= "") && (tField '= "") Quit ..Violation(tField, tCode, .pHttpStatus, .pFault)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTVALIDATION, .pHttpStatus, .pFault)
}

/// <p>The secret write: <var>pBody</var> must carry <parameter>SECRETFIELD</parameter> and no other
/// key. A key outside it is refused as a caller fault; a missing or empty secret is 422
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTNOSECRET</parameter> with nothing sent.</p>
ClassMethod ChangeSecret(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSecret = ""
    Set tStray = 0
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If tKey '= ..#SECRETFIELD Set tStray = 1 Quit
            If pBody.%GetTypeOf(tKey) = "string" Set tSecret = tValue
        }
    } ElseIf pBody '= "" {
        Set tStray = 1
    }
    Kill tValue
    If tStray {
        Set tSecret = ""
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#CLIENTENDPOINT _ " " _ ..#SECRETTYPE _ " was given a key other than its one secret", $$$ERROR($$$GeneralError, "a secret body carries only " _ ..#SECRETFIELD), pFault.code)
        Quit tSC
    }
    If tSecret = "" Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTNOSECRET, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTNOSECRET, .pHttpStatus, .pFault)
    Set tVendor = {}
    Do tVendor.%Set(..#SECRETFIELD, tSecret, "string")
    Set tSecret = ""
    Set tSC = ..Vendor(..#CLIENTENDPOINT, ..#SECRETTYPE, .pQuery, tVendor, .pResult, .pHttpStatus, .pFault)
    Set tVendor = ""
    If $$$ISERR(tSC) Quit ..Named(tSC, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>The <parameter>JWKSTYPE</parameter> read of client <var>pClientId</var> (class description), or
/// 404 when the instance holds no such client.</p>
ClassMethod KeySetState(pClientId As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tClient = ..OpenClient(pClientId, .tOpenSC)
        If '$IsObject(tClient) {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(..#CLIENTENDPOINT, 404, tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tUri = ""
        If $IsObject(tClient.Metadata) Set tUri = $Property(tClient.Metadata, ..#JWKSMEMBER)
        Set tCredentials = tClient.ClientCredentials
        Set tKeys = ..KeyCount(tClient.PublicJWKS)
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
        Set pResult = {}
        Do pResult.%Set("JwksUri", tUri, "string")
        Do pResult.%Set("ClientCredentials", tCredentials, "string")
        Do pResult.%Set("PublicKeys", tKeys, "number")
        Set pHttpStatus = 200
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResult = ""
        Set tSC = ..Fail(..#CLIENTENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The number of keys the key set <var>pJwks</var> holds, as its JSON text; 0 for an empty or
/// unreadable one.</p>
ClassMethod KeyCount(pJwks As %String) As %Integer
{
    If pJwks = "" Quit 0
    Set tCount = 0
    Try {
        Set tSet = ##class(%DynamicAbstractObject).%FromJSON(pJwks)
        If $IsObject(tSet) && (tSet.%GetTypeOf("keys") = "array") Set tCount = tSet.%Get("keys").%Size()
    } Catch {
        Set tCount = 0
    }
    Quit tCount
}

/// <p>The <parameter>REFRESHTYPE</parameter> write for client <var>pClientId</var> (class
/// description). An absent client is 404; a client with no JWKS URL is 409
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTJWKSNOURI</parameter> and one whose URL is neither
/// <code>https</code> nor <code>http</code> 422 <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTJWKSSCHEME</parameter>,
/// each with nothing fetched; a fetch that fails is 422
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTJWKSFETCH</parameter>, the vendor's text logged
/// alone. On success <var>pResult</var> is <code>{}</code>.</p>
ClassMethod RefreshKeySet(pClientId As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        ; Resolved here, in the caller's namespace, where the class that names it is compiled.
        Set tHttpsSsl = ..SslConfiguration()
        Set $NAMESPACE = "%SYS"
        Set tClient = ..OpenClient(pClientId, .tOpenSC)
        If '$IsObject(tClient) {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(..#CLIENTENDPOINT, 404, tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tUri = ""
        If $IsObject(tClient.Metadata) Set tUri = $Property(tClient.Metadata, ..#JWKSMEMBER)
        If tUri = "" {
            Set tClient = ""
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTJWKSNOURI, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTJWKSNOURI, .pHttpStatus, .pFault)
            Quit
        }
        Set tScheme = $ZConvert($Piece(tUri, "://", 1), "L")
        If '$ListFind($ListBuild("https", "http"), tScheme) || '(tUri [ "://") {
            Set tClient = ""
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTJWKSSCHEME, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTJWKSSCHEME, .pHttpStatus, .pFault)
            Quit
        }
        Set tFetchSC = $$$OK
        Do ..Fetch(tClient, $Select(tScheme = "https": tHttpsSsl, 1: ""), .tFetchSC)
        Set tClient = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tFetchSC) {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTJWKSFETCH, $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTJWKSFETCH, "{url}", tUri), .pHttpStatus, .pFault)
            Do ..LogFault(..#CLIENTENDPOINT _ " " _ ..#REFRESHTYPE _ " could not fetch the key set", tFetchSC, pFault.code)
            Quit
        }
        Set pResult = {}
        Set pHttpStatus = 200
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResult = ""
        Set tSC = ..Fail(..#CLIENTENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The client <var>pClientId</var> through <parameter>CLIENTCLASS</parameter>'s own
/// <code>Open</code>, or <code>""</code> with <var>pSC</var> saying why. Runs in
/// <code>%SYS</code>.</p>
ClassMethod OpenClient(pClientId As %String, Output pSC As %Status) As %RegisteredObject [ Private ]
{
    Set pSC = $$$OK
    If pClientId = "" Quit ""
    Set tClient = $ClassMethod(..#CLIENTCLASS, "Open", pClientId, .pSC)
    If '$IsObject(tClient) Quit ""
    Quit tClient
}

/// <p>Fetch <var>pClient</var>'s key set from its JWKS URL through SSL/TLS configuration
/// <var>pSsl</var> (<code>""</code> for none) and store it: the vendor's own
/// <code>RefreshJWKS</code>, forced and saved. <var>pSC</var> is its status. Runs in
/// <code>%SYS</code>. Overridable so a fixture can observe the configuration a fetch is given;
/// production never overrides it.</p>
ClassMethod Fetch(pClient As %RegisteredObject, pSsl As %String, Output pSC As %Status)
{
    Set pSC = $$$OK
    Do pClient.RefreshJWKS(pSsl, 1, 1, .pSC)
}

/// <p>The SSL/TLS configuration an <code>https</code> key set is fetched through: the client
/// configuration OcuPilot's installer creates and keeps (AD-32), resolved at call time.</p>
ClassMethod SslConfiguration() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
}

/// <p>The first pair of <parameter>GATEPAIRS</parameter> the caller does not hold, or
/// <code>""</code>. Each pair is asked through the admin port's <method>HoldsPair</method>.</p>
ClassMethod RefusedPair() As %String
{
    Set tRefused = ""
    For tI = 1:1:$Length(..#GATEPAIRS, ",") {
        Set tPair = $Piece(..#GATEPAIRS, ",", tI)
        If '..HoldsPair(tPair) Set tRefused = tPair Quit
    }
    Quit tRefused
}

/// <p>The 403 a caller without pair <var>pPair</var> is answered before any vendor call, with the pair
/// in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A 422 <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTVALIDATION</parameter> fault carrying one
/// violation of <var>pCode</var> on <var>pField</var> (AD-39).</p>
ClassMethod Violation(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tRow)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTVALIDATION, .pHttpStatus, .pFault, tDetail)
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for
/// <parameter>REFRESHTYPE</parameter>, which this port carries out through
/// <parameter>CLIENTCLASS</parameter>, and the admin port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#CLIENTENDPOINT) && (pType = ..#REFRESHTYPE) Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59): <parameter>SECRETTYPE</parameter>
/// is the vendor call with <parameter>SECRETFIELD</parameter> alone, and
/// <parameter>REFRESHTYPE</parameter> the <code>RefreshJWKS</code> call
/// <method>RefreshKeySet</method> makes, through the TLS configuration it names for an
/// <code>https</code> key-set URI. Every other call is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#CLIENTENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    If pType = ..#REFRESHTYPE {
        Set tClient = ..Literal($Get(pQuery(..#IDQUERY)))
        Set tSteps = []
        Do tSteps.%Push(..ObjectScriptStep($ListBuild("Set tClient = ##class(" _ ..#CLIENTCLASS _ ").Open(" _ tClient _ ", .tSC)", "Set tUri = $Select($IsObject(tClient) && $IsObject(tClient.Metadata): $Property(tClient.Metadata, " _ ..Literal(..#JWKSMEMBER) _ "), 1: """")", "If tUri '= """" Do tClient.RefreshJWKS($Select($ZConvert($Piece(tUri, ""://"", 1), ""L"") = ""https"": " _ ..Literal(..SslConfiguration()) _ ", 1: """"), 1, 1, .tSC)", "Do $System.Status.DisplayError(tSC)")))
        Quit tSteps
    }
    If pType = ..#SECRETTYPE {
        Set tBody = {}
        Do tBody.%Set(..#SECRETFIELD, ..Scalar(pBody, ..#SECRETFIELD), "string")
        Quit ##super(pEndpoint, pType, .pQuery, tBody, pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
