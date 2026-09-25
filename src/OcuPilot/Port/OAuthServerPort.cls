/// <p>The OAuth 2.0 server description port (AD-52): <class>OcuPilot.Port.AdminPort</class> with
/// <parameter>SERVERENDPOINT</parameter> addressed by its issuer, plus the two calls the admin API
/// cannot carry (AD-27, Story 12.4's two named cases).</p>
/// <p><b>Identity.</b> OcuPilot's id for a server description is its issuer endpoint (AD-13), and
/// the vendor keys it by an integer <code>serverId</code>. Every request that names a description
/// carries <parameter>ISSUERQUERY</parameter>; this port reads the endpoint's own
/// <code>LIST</code>, finds the one row whose <code>IssuerEndpoint</code> equals it exactly, and
/// sends the vendor's <code>serverId</code>. No row is a 404. <code>GET</code> adds the row's
/// <code>ID</code>, <code>ClientCount</code> and <code>ResourceCount</code> to the answer, and
/// <code>PUT</code> removes them again, because the vendor's body schema refuses them.</p>
/// <p><b>What it refuses before the vendor is called.</b> A <code>DELETE</code> of a description a
/// client configuration uses (<parameter>OcuPilot.Api.Error.OAUTHSERVERINUSE</parameter>; the
/// vendor refuses it too, with a 500). A body naming an X.509 credential the caller cannot use, which
/// the vendor's own save refuses with a 500 (#8886): the same
/// <code>%SYS.X509Credentials.GetByAlias</code> check is read first and answered on the field. A
/// <code>PUT</code> that renames a description to an issuer another already carries, which the
/// vendor refuses with a 500; the vendor's own 409 for a duplicate <code>POST</code> is answered on
/// the field too.</p>
/// <p><b>The two named AD-27 cases</b>, each after the endpoint's own
/// <parameter>GATERESOURCE</parameter> gate and in <code>%SYS</code> by save and restore (AD-16).
/// <method>Discover</method> calls <code>OAuth2.ServerDefinition.GetServerMetadata</code>, which
/// fetches <code>&lt;issuer&gt;/.well-known/openid-configuration</code> and saves nothing; the admin
/// API's only discovery path saves at once. <parameter>REFRESHTYPE</parameter> calls
/// <code>RefreshJWKS(1,1)</code> on the stored description, because the admin API has no such
/// request type. <parameter>JWKSTYPE</parameter> is the read that write is fingerprinted over.</p>
/// <p>Every other request is the admin port's own call, unchanged.</p>
Class OcuPilot.Port.OAuthServerPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port addresses by issuer.</p>
Parameter SERVERENDPOINT = "Security.OAuth2.Client.ServerDefinition";

/// <p>The query parameter a caller names a description by: its issuer endpoint.</p>
Parameter ISSUERQUERY = "issuer";

/// <p>The vendor's own query parameter for a description.</p>
Parameter VENDORQUERY = "serverId";

/// <p>The fields the <code>LIST</code> row adds to a <code>GET</code>, which a <code>PUT</code>
/// body never carries.</p>
Parameter ROWFIELDS = "ID,ClientCount,ResourceCount";

/// <p>The read this port answers itself: a description's JWKS URL, SSL/TLS configuration and
/// server credentials.</p>
Parameter JWKSTYPE = "JWKS";

/// <p>The write this port carries out itself: refresh the stored key set from the JWKS URL.</p>
Parameter REFRESHTYPE = "REFRESHJWKS";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pair this port carries out
/// itself rather than through the vendor endpoint, with no caller body.</p>
Parameter COMPOSEDTYPES = "Security.OAuth2.Client.ServerDefinition/REFRESHJWKS";

/// <p>The vendor endpoint's own <code>ResourcesOR()</code> resource, checked at <code>USE</code>
/// before either named case.</p>
Parameter GATERESOURCE = "%Admin_OAuth2_Client";

/// <p>The vendor class the two named cases are completed through.</p>
Parameter DEFINITIONCLASS = "OAuth2.ServerDefinition";

/// <p>The admin port's call, with <parameter>SERVERENDPOINT</parameter> addressed by issuer and the
/// two named cases carried out here.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. For <parameter>SERVERENDPOINT</parameter>,
/// <code>GET</code>, <code>PUT</code>, <code>DELETE</code>, <code>TOKEN</code>,
/// <parameter>JWKSTYPE</parameter> and <parameter>REFRESHTYPE</parameter> read the issuer from
/// <code>pQuery("issuer")</code>; <code>POST</code> sends it as the body's
/// <code>IssuerEndpoint</code>. <var>pQuery</var> and <var>pBody</var> are not modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#SERVERENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If '$ListFind($ListBuild("GET", "POST", "PUT", "DELETE", "TOKEN", ..#JWKSTYPE, ..#REFRESHTYPE), pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tIssuer = $Get(pQuery(..#ISSUERQUERY))
        If pType = "POST" {
            If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") {
                Set tSC = ##super(pEndpoint, "POST", , pBody, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tBody = ..VendorBody(pBody)
            If tIssuer '= "" Do tBody.%Set("IssuerEndpoint", tIssuer, "string")
            If '..CredentialOk(tBody) {
                Set tSC = ..Violation("ServerCredentials", ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSABSENT, .pHttpStatus, .pFault)
                Quit
            }
            Kill tNone
            Set tSC = ##super(pEndpoint, "POST", .tNone, tBody, .pResult, .pHttpStatus, .pFault)
            ; The vendor's own 409 for an issuer another description carries, answered on its field.
            If $$$ISERR(tSC) && (+pHttpStatus = 409) Set tSC = ..Violation("IssuerEndpoint", ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTTAKEN, .pHttpStatus, .pFault)
            Quit
        }

        ; The refresh is refused on its own pair before anything is read or fetched.
        If (pType = ..#REFRESHTYPE) && '..HoldsResource(..#GATERESOURCE) {
            Set tSC = ..GateRefusal(.pHttpStatus, .pFault)
            Quit
        }

        ; Every other type names a description by issuer: resolve it through the endpoint's LIST.
        If tIssuer = "" {
            Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        Kill tNone
        Set tSC = ##super(pEndpoint, "LIST", .tNone, "", .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tRow = ..Matching(tRows, tIssuer)
        If '$IsObject(tRow) {
            Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        Kill tQuery
        Merge tQuery = pQuery
        Kill tQuery(..#ISSUERQUERY)
        Set tQuery(..#VENDORQUERY) = tRow.%Get("ID")

        If pType = "GET" {
            Set tSC = ##super(pEndpoint, "GET", .tQuery, "", .pResult, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") {
                Set pResult = ""
                Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
                Quit
            }
            For tI = 1:1:$Length(..#ROWFIELDS, ",") {
                Set tField = $Piece(..#ROWFIELDS, ",", tI)
                Do pResult.%Set(tField, tRow.%Get(tField), "number")
            }
            Quit
        }
        If pType = "PUT" {
            If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") {
                Set tSC = ##super(pEndpoint, "PUT", .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tBody = ..VendorBody(pBody)
            ; A rename onto an issuer another description carries: the vendor answers it 500.
            If (tBody.%GetTypeOf("IssuerEndpoint") = "string") && (tBody.%Get("IssuerEndpoint") '= tIssuer) && $IsObject(..Matching(tRows, tBody.%Get("IssuerEndpoint"))) {
                Set tSC = ..Violation("IssuerEndpoint", ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTTAKEN, .pHttpStatus, .pFault)
                Quit
            }
            If '..CredentialOk(tBody) {
                Set tSC = ..Violation("ServerCredentials", ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSABSENT, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ##super(pEndpoint, "PUT", .tQuery, tBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = "DELETE" {
            ; The vendor refuses it too, with a 500 that names nothing (#5823).
            If +tRow.%Get("ClientCount") > 0 {
                Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHSERVERINUSE, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERINUSE, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ##super(pEndpoint, "DELETE", .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = "TOKEN" {
            Set tSC = ##super(pEndpoint, "TOKEN", .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        ; JWKSTYPE and REFRESHTYPE both start from the vendor's own GET.
        If (pType = ..#REFRESHTYPE) && ($IsObject(pBody) || (pBody '= "")) {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit
        }
        Set tSC = ##super(pEndpoint, "GET", .tQuery, "", .tRead, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tState = ..KeySetState($Get(tRead))
        If '$IsObject(tState) {
            Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#JWKSTYPE {
            Set pResult = tState
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..RefreshKeySet(tQuery(..#VENDORQUERY), tState.%Get("JwksUri"), .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Fetch the discovery document <var>pIssuer</var> publishes, through <var>pSSL</var>, and
/// answer its members in <var>pMetadata</var> (AD-27, Story 12.4). Nothing is saved.</p>
/// <p><b>Caller contract:</b> an error status carries <var>pHttpStatus</var> and <var>pFault</var>:
/// 403 naming <parameter>GATERESOURCE</parameter> for a caller without it, 400 for an empty issuer,
/// and 422 with one of the four <code>OAUTH.DISCOVERY.*</code> codes otherwise, its sentence filled
/// and <code>detail.cause</code> one of <code>unreachable</code>, <code>status</code>,
/// <code>content</code> or <code>issuer</code>. The vendor's own text goes to the log alone.</p>
/// <p>Must not be called from an escalated frame (AD-9). The caller's namespace is unchanged on
/// return (AD-16).</p>
ClassMethod Discover(pIssuer As %String, pSSL As %String, Output pMetadata As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pMetadata = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If '..HoldsResource(..#GATERESOURCE) {
            Set tSC = ..GateRefusal(.pHttpStatus, .pFault)
            Quit
        }
        If pIssuer = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "The discovery was not given an issuer endpoint", .pHttpStatus, .pFault)
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tVendorSC = $ClassMethod(..#DEFINITIONCLASS, "GetServerMetadata", pIssuer, pSSL, .tMetadata)
        Set tExported = ""
        If $$$ISOK(tVendorSC) && $IsObject($Get(tMetadata)) Set tExported = tMetadata.ExportJSON(0)
        Set tMetadata = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tVendorSC) {
            Set tSC = ..DiscoveryFault(pIssuer, tVendorSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pMetadata = ##class(%DynamicAbstractObject).%FromJSON($Select(tExported = "": "{}", 1: tExported))
        Set pHttpStatus = 200
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pMetadata = ""
        Set tSC = ..Fail(..#SERVERENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process can use the X.509 credential <var>pAlias</var>, asked of
/// <code>%SYS.X509Credentials.GetByAlias</code>, the check the vendor's own save makes (it refuses
/// with #8886 otherwise). The caller's namespace is unchanged on return.</p>
ClassMethod CredentialUsable(pAlias As %String) As %Boolean
{
    If pAlias = "" Quit 0
    Set tUsable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCredential = ##class(%SYS.X509Credentials).GetByAlias(pAlias)
        Set tUsable = $IsObject(tCredential)
        Set tCredential = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tUsable = 0
    }
    Quit tUsable
}

/// <p>The row of <var>pRows</var> whose <code>IssuerEndpoint</code> equals <var>pIssuer</var>
/// exactly, or <code>""</code>.</p>
ClassMethod Matching(pRows, pIssuer As %String) As %DynamicObject
{
    Set tFound = ""
    If '$IsObject(pRows) || 'pRows.%IsA("%Library.DynamicArray") Quit tFound
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Continue
        If tEntry.%GetTypeOf("IssuerEndpoint") '= "string" Continue
        If tEntry.%Get("IssuerEndpoint") '= pIssuer Continue
        Set tFound = tEntry
        Quit
    }
    Quit tFound
}

/// <p>A copy of <var>pBody</var> without the <parameter>ROWFIELDS</parameter> this port's
/// <code>GET</code> adds, which the vendor's body schema refuses. Which fields a body carries is the
/// write tool's derived list (AD-3), applied before the port is called.</p>
ClassMethod VendorBody(pBody As %DynamicObject) As %DynamicObject
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    For tI = 1:1:$Length(..#ROWFIELDS, ",") Do tBody.%Remove($Piece(..#ROWFIELDS, ",", tI))
    Quit tBody
}

/// <p>Whether <var>pBody</var>'s <code>ServerCredentials</code> is empty, absent, or a credential
/// the caller can use (<method>CredentialUsable</method>).</p>
ClassMethod CredentialOk(pBody As %DynamicObject) As %Boolean [ Private ]
{
    If pBody.%GetTypeOf("ServerCredentials") '= "string" Quit 1
    If pBody.%Get("ServerCredentials") = "" Quit 1
    Quit ..CredentialUsable(pBody.%Get("ServerCredentials"))
}

/// <p>A 422 <parameter>OcuPilot.Api.Error.OAUTHVALIDATION</parameter> fault carrying one violation
/// of <var>pCode</var> on <var>pField</var> (AD-39).</p>
ClassMethod Violation(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tRow)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHVALIDATION, .pHttpStatus, .pFault, tDetail)
}

/// <p>The 403 a caller without <parameter>GATERESOURCE</parameter> at <code>USE</code> is answered
/// before either named case: the admin port's own mapping of 403, with the pair in
/// <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", ..#GATERESOURCE _ ":USE", "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The <parameter>JWKSTYPE</parameter> read from the vendor's own <code>GET</code> answer
/// <var>pRead</var>: <code>{JwksUri, SSLConfiguration, ServerCredentials}</code>, or
/// <code>""</code> when <var>pRead</var> is no object.</p>
ClassMethod KeySetState(pRead) As %DynamicObject
{
    If '$IsObject(pRead) || 'pRead.%IsA("%Library.DynamicObject") Quit ""
    Set tUri = ""
    If pRead.%GetTypeOf("Metadata") = "object" {
        If pRead.%Get("Metadata").%GetTypeOf("jwks_uri") = "string" Set tUri = pRead.%Get("Metadata").%Get("jwks_uri")
    }
    Set tState = {}
    Do tState.%Set("JwksUri", tUri, "string")
    Do tState.%Set("SSLConfiguration", pRead.%Get("SSLConfiguration"), "string")
    Do tState.%Set("ServerCredentials", pRead.%Get("ServerCredentials"), "string")
    Quit tState
}

/// <p>Refresh description <var>pServerId</var>'s stored key set from <var>pUri</var>, its JWKS URL,
/// through <code>OAuth2.ServerDefinition.RefreshJWKS(1,1)</code> (AD-27). The caller has applied the
/// endpoint's own gate. An empty <var>pUri</var> is refused 409
/// <parameter>OcuPilot.Api.Error.OAUTHNOJWKSURI</parameter> with nothing fetched; a fetch that
/// fails is 422 <parameter>OcuPilot.Api.Error.OAUTHJWKSFAILED</parameter> with nothing stored, the
/// vendor's text logged alone. On success <var>pResult</var> is <code>{}</code>.</p>
/// <p>The vendor clears <code>ServerCredentials</code> when the key set it fetched differs from the
/// stored one, and saves nothing when it is the same.</p>
ClassMethod RefreshKeySet(pServerId As %String, pUri As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If pUri = "" {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHNOJWKSURI, ##class(OcuPilot.Api.Error).#REASONOAUTHNOJWKSURI, .pHttpStatus, .pFault)
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tOpenSC = $$$OK
        Set tDefinition = $ClassMethod(..#DEFINITIONCLASS, "Open", pServerId, .tOpenSC)
        If '$IsObject(tDefinition) {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(..#SERVERENDPOINT, 404, tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tRefreshSC = $$$OK
        Do tDefinition.RefreshJWKS(1, 1, .tRefreshSC)
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tRefreshSC) {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHJWKSFAILED, $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHJWKSFAILED, "{url}", pUri), .pHttpStatus, .pFault)
            Do ..LogFault(..#SERVERENDPOINT _ " " _ ..#REFRESHTYPE _ " could not fetch the key set", tRefreshSC, pFault.code)
            Quit
        }
        Set pResult = {}
        Set pHttpStatus = 200
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResult = ""
        Set tSC = ..Fail(..#SERVERENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The 422 a failed discovery of <var>pIssuer</var> answers, from the vendor's status
/// <var>pVendorSC</var>: the cause, its code and its sentence with the issuer, the HTTP status or the
/// issuer claim filled in. The vendor's text is logged and not carried.</p>
ClassMethod DiscoveryFault(pIssuer As %String, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCause = ..DiscoveryCause(pVendorSC, .tValue)
    If tCause = "status" {
        Set tCode = ##class(OcuPilot.Api.Error).#OAUTHDISCOVERYSTATUS
        Set tReason = $Replace($Replace(##class(OcuPilot.Api.Error).#REASONOAUTHDISCOVERYSTATUS, "{issuer}", pIssuer), "{status}", tValue)
    } ElseIf tCause = "content" {
        Set tCode = ##class(OcuPilot.Api.Error).#OAUTHDISCOVERYCONTENT
        Set tReason = $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHDISCOVERYCONTENT, "{issuer}", pIssuer)
    } ElseIf tCause = "issuer" {
        Set tCode = ##class(OcuPilot.Api.Error).#OAUTHDISCOVERYISSUER
        Set tReason = $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHDISCOVERYISSUER, "{claim}", tValue)
    } Else {
        Set tCode = ##class(OcuPilot.Api.Error).#OAUTHDISCOVERYUNREACHABLE
        Set tReason = $Replace(##class(OcuPilot.Api.Error).#REASONOAUTHDISCOVERYUNREACHABLE, "{issuer}", pIssuer)
    }
    Set tDetail = {}
    Do tDetail.%Set("cause", tCause, "string")
    Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, tReason, .pHttpStatus, .pFault, tDetail)
    Do ..LogFault(..#SERVERENDPOINT _ " discovery of " _ pIssuer _ " failed", pVendorSC, tCode)
    Quit tSC
}

/// <p>Which of the four causes <var>pVendorSC</var> reports -- <code>status</code>,
/// <code>content</code>, <code>issuer</code> or <code>unreachable</code> -- with the HTTP status or
/// the issuer claim in <var>pValue</var>. The vendor reports every document it rejects as error
/// #8880 whose one parameter is the reason <code>GetServerMetadata</code> composed; anything else
/// failed before a document arrived.</p>
ClassMethod DiscoveryCause(pVendorSC As %Status, Output pValue As %String) As %String
{
    Set pValue = ""
    Set tCause = "unreachable"
    Try {
        Do $System.Status.DecomposeStatus(pVendorSC, .tErrors, "-d")
        For tI = 1:1:+$Get(tErrors) {
            Set tCode = $Get(tErrors(tI, "code"))
            If tCode = 8880 {
                Set tParam = $Get(tErrors(tI, "param", 1))
                If $Extract(tParam, 1, 23) = "Unexpected status code=" {
                    Set tCause = "status"
                    Set pValue = +$Extract(tParam, 24, *)
                } ElseIf $Extract(tParam, 1, 25) = "Unexpected issuer claim: " {
                    Set tCause = "issuer"
                    Set pValue = $Extract(tParam, 26, *)
                } Else {
                    Set tCause = "content"
                }
                Quit
            }
            ; A document that arrived and could not be parsed as JSON.
            If (tCode = 5035) || (tCode = 5002) || ($Get(tErrors(tI)) [ "%FromJSON") {
                Set tCause = "content"
                Quit
            }
        }
    } Catch {
        Set tCause = "unreachable"
    }
    Quit tCause
}

}
