/// <p>The OAuth 2.0 resource server port (AD-51, AD-52): <class>OcuPilot.Port.AdminPort</class> with
/// <parameter>RESOURCEENDPOINT</parameter>'s reads and writes shaped here, and a resource server's
/// service mappings reached through <parameter>MAPPINGENDPOINT</parameter>. Every vendor call is the
/// admin port's own, behind the endpoint's own gate and this port's <parameter>GATEPAIRS</parameter>;
/// no vendor class completes an operation (AD-27).
/// The two vendor reads are the authenticator checks (<method>AuthenticatorUsable</method>,
/// <method>Authenticators</method>), which read the class dictionary in the authenticator's
/// namespace.</p>
/// <p><b>No read answers a credential.</b> The vendor's <code>GET</code> answers every setting its
/// authenticator's <code>DescribeSettings()</code> names; a setting whose name is a credential's
/// (Conventions, Secrets) is removed from each <code>GET</code> and <code>PUT</code> answer
/// (<method>Stripped</method>). The <code>GET</code> never answers <code>ClientSecret</code>.</p>
/// <p><b><code>PUT</code></b> refuses a credential-named setting its body sends
/// (<parameter>OcuPilot.Api.Error.OAUTHAUTHENTICATORSECRET</parameter>) and an authenticator the caller
/// cannot use, then fills each credential-named setting its body omits from the fresh unstripped
/// read when the authenticator's namespace and class are unchanged, because the vendor replaces the
/// authenticator whole. Any vendor 500 is <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERVALIDATION</parameter>,
/// the vendor's text logged alone.</p>
/// <p><b><parameter>SECRETSTYPE</parameter></b> takes <code>{ClientSecret}</code> alone, non-empty:
/// the vendor stores an empty one as the secret.</p>
/// <p><b>Three types are this port's own.</b> <parameter>MAPPINGSTYPE</parameter> reads a server's
/// service mappings: <code>{IssuerEndpoint, Mappings, Held, Service: "", Key: ""}</code>, where
/// <code>Mappings</code> lists this server's as <code>&lt;Service&gt;/&lt;key&gt;</code> and
/// <code>Held</code> maps every mapping on the instance to its server; the two empty fields are the
/// mapping tools' arguments. <parameter>ADDTYPE</parameter> and <parameter>REMOVETYPE</parameter> build
/// the mapping call from the <parameter>SERVICEQUERY</parameter> and <parameter>KEYQUERY</parameter>
/// query parameters (AD-51): an add creates the mapping or moves it from the server that holds it, and
/// a remove refuses a mapping this server does not hold. <parameter>AUTHENTICATORSTYPE</parameter>
/// answers the authenticator classes a namespace offers.</p>
Class OcuPilot.Port.OAuthResourceServerPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port shapes, and the mapping endpoint it reaches for it.</p>
Parameter RESOURCEENDPOINT = "Security.OAuth2.ResourceServer";

Parameter MAPPINGENDPOINT = "Security.OAuth2.ResourceServerMapping";

/// <p>The admin API writes this port issues on the vendor's behalf of its own action types
/// (<code>ADDMAPPING</code>, <code>REMOVEMAPPING</code>), each a
/// <parameter>MUTATINGTYPES</parameter> pair no tool names as its own write type.</p>
Parameter DELEGATEDTYPES = "Security.OAuth2.ResourceServerMapping/PUT,Security.OAuth2.ResourceServerMapping/DELETE";

/// <p>The vendor's query parameters: the server's name, a mapping's service and key.</p>
Parameter NAMEQUERY = "name";

Parameter SERVICEQUERY = "service";

Parameter KEYQUERY = "key";

/// <p>The query parameter <parameter>AUTHENTICATORSTYPE</parameter> reads a namespace from.</p>
Parameter NAMESPACEQUERY = "namespace";

/// <p>The two services a mapping may name, and the key that maps every application or namespace of
/// one.</p>
Parameter SERVICES = "%Service_WebGateway,%Service_Bindings";

Parameter DEFAULTKEY = "*";

/// <p>The vendor's secret write and the one secret it takes.</p>
Parameter SECRETSTYPE = "CHANGESECRET";

Parameter SECRETFIELD = "ClientSecret";

/// <p>The types this port answers itself.</p>
Parameter MAPPINGSTYPE = "MAPPINGS";

Parameter ADDTYPE = "ADDMAPPING";

Parameter REMOVETYPE = "REMOVEMAPPING";

Parameter AUTHENTICATORSTYPE = "AUTHENTICATORS";

/// <p>The two writes whose vendor call this port composes from the port query; each takes no caller
/// body (AD-51).</p>
Parameter COMPOSEDTYPES = "Security.OAuth2.ResourceServer/ADDMAPPING,Security.OAuth2.ResourceServer/REMOVEMAPPING";

/// <p>The body field holding the authenticator, its two identifying members, the class every
/// authenticator extends, and the one a namespace the caller cannot read offers.</p>
Parameter AUTHENTICATORFIELD = "Authenticator";

Parameter NAMESPACEMEMBER = "Namespace";

Parameter IMPLEMENTATIONMEMBER = "Implementation";

Parameter AUTHENTICATORBASE = "%OAuth2.ResourceServer.Authenticator";

Parameter DEFAULTIMPLEMENTATION = "%OAuth2.ResourceServer.SimpleAuthenticator";

Parameter DEFAULTNAMESPACE = "%SYS";

/// <p>The pairs every <parameter>RESOURCEENDPOINT</parameter> call through this port requires, in
/// the order a refusal names the first one missing (AD-29): the resource servers tab's own set. Both
/// vendor endpoints' <code>ResourcesOR()</code> names only <code>%Admin_Secure</code>, while the
/// vendor's resource server class resolves its issuer through
/// <code>OAuth2.ServerDefinition.OpenByIssuer</code>, which checks
/// <code>%Admin_OAuth2_Client</code>.</p>
Parameter GATEPAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ,%Admin_OAuth2_Client:USE";

/// <p>The admin port's call, with <parameter>RESOURCEENDPOINT</parameter> shaped here.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s; <var>pQuery</var> and <var>pBody</var> are not
/// modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#RESOURCEENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRefused = ..RefusedPair()
    If tRefused '= "" Quit ..GateRefusal(tRefused, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Try {
        If pType = "GET" {
            Set tSC = ..Vendor(pEndpoint, "GET", .pQuery, "", .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) Set pResult = ..Stripped(pResult)
            Quit
        }
        If pType = "PUT" {
            Set tSC = ..Put(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#SECRETSTYPE {
            Set tSC = ..ChangeSecret(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#MAPPINGSTYPE {
            Set tSC = ..Mappings($Get(pQuery(..#NAMEQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) && ($IsObject(pBody) || (pBody '= "")) {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit
        }
        If pType = ..#ADDTYPE {
            Set tSC = ..AddMapping($Get(pQuery(..#NAMEQUERY)), $Get(pQuery(..#SERVICEQUERY)), $Get(pQuery(..#KEYQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#REMOVETYPE {
            Set tSC = ..RemoveMapping($Get(pQuery(..#NAMEQUERY)), $Get(pQuery(..#SERVICEQUERY)), $Get(pQuery(..#KEYQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#AUTHENTICATORSTYPE {
            Set tSC = ..Authenticators($Get(pQuery(..#NAMESPACEQUERY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Vendor(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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

/// <p>A copy of <var>pRead</var> whose <code>Authenticator</code> carries no credential-named
/// setting; anything that is not an object is answered as it is.</p>
ClassMethod Stripped(pRead) As %DynamicAbstractObject
{
    If '$IsObject(pRead) || 'pRead.%IsA("%Library.DynamicObject") Quit pRead
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pRead.%ToJSON())
    If tCopy.%GetTypeOf(..#AUTHENTICATORFIELD) '= "object" Quit tCopy
    Set tAuthenticator = tCopy.%Get(..#AUTHENTICATORFIELD)
    Set tDrop = ..CredentialSettings(tAuthenticator)
    For tI = 1:1:$ListLength(tDrop) Do tAuthenticator.%Remove($List(tDrop, tI))
    Quit tCopy
}

/// <p>The members of authenticator object <var>pAuthenticator</var> whose name is a credential's, as
/// a <class>%List</class>.</p>
ClassMethod CredentialSettings(pAuthenticator As %DynamicObject) As %List
{
    Set tNames = ""
    If '$IsObject(pAuthenticator) Quit tNames
    Set tIterator = pAuthenticator.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = ..#NAMESPACEMEMBER) || (tKey = ..#IMPLEMENTATIONMEMBER) Continue
        If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tKey) Set tNames = tNames _ $ListBuild(tKey)
    }
    Quit tNames
}

/// <p>Whether authenticator objects <var>pOne</var> and <var>pOther</var> name the same namespace,
/// compared without regard to case, and the same class.</p>
ClassMethod SameAuthenticator(pOne, pOther) As %Boolean
{
    If '$IsObject(pOne) || '$IsObject(pOther) Quit 0
    If $ZConvert(..Text(pOne, ..#NAMESPACEMEMBER), "U") '= $ZConvert(..Text(pOther, ..#NAMESPACEMEMBER), "U") Quit 0
    Quit ..Text(pOne, ..#IMPLEMENTATIONMEMBER) = ..Text(pOther, ..#IMPLEMENTATIONMEMBER)
}

/// <p>Whether <var>pImplementation</var> is a compiled, concrete subclass of
/// <parameter>AUTHENTICATORBASE</parameter> visible in namespace <var>pNamespace</var>, with
/// <var>pCode</var> the violation code when it is not: the namespace's, when it does not exist or
/// the caller cannot enter it, and the class's otherwise. The caller's namespace is unchanged on
/// return (AD-16).</p>
ClassMethod AuthenticatorUsable(pNamespace As %String, pImplementation As %String, Output pCode As %String) As %Boolean
{
    Set pCode = ""
    Set tNamespace = $Select(pNamespace = "": ..#DEFAULTNAMESPACE, 1: pNamespace)
    If '$Match(tNamespace, "^[%A-Za-z][A-Za-z0-9_-]*$") || '##class(%SYS.Namespace).Exists(tNamespace) {
        Set pCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORNAMESPACE
        Quit 0
    }
    If '$Match(pImplementation, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
        Set pCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORIMPLEMENTATION
        Quit 0
    }
    Set tUsable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = tNamespace
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set pCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORNAMESPACE
    }
    If pCode '= "" Quit 0
    Try {
        Set tUsable = ..IsAuthenticatorClass(pImplementation)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tUsable = 0
    }
    If 'tUsable Set pCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORIMPLEMENTATION
    Quit tUsable
}

/// <p>Whether <var>pClass</var> is compiled in the current namespace, concrete, and extends
/// <parameter>AUTHENTICATORBASE</parameter>.</p>
ClassMethod IsAuthenticatorClass(pClass As %String) As %Boolean [ Private ]
{
    Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pClass, 0)
    If '$IsObject(tCompiled) Quit 0
    If tCompiled.Abstract Quit 0
    Set tCompiled = ""
    Quit ''$ClassMethod(pClass, "%Extends", ..#AUTHENTICATORBASE)
}

/// <p>The settings authenticator class <var>pClass</var> describes in namespace
/// <var>pNamespace</var>, less the credential-named ones, as <code>[{name, type, hint}]</code>, or
/// <code>""</code> when the class cannot be described there. The description is read in that
/// namespace and filtered once the caller's namespace is restored (AD-16).</p>
ClassMethod SettingsOf(pNamespace As %String, pClass As %String) As %DynamicArray
{
    Set tDescribed = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Select(pNamespace = "": ..#DEFAULTNAMESPACE, 1: pNamespace)
        If ..IsAuthenticatorClass(pClass) Set tDescribed = $ClassMethod(pClass, "DescribeSettings")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tDescribed = ""
    }
    If '$IsObject(tDescribed) Quit ""
    Set tSettings = []
    Set tIterator = tDescribed.%GetIterator()
    While tIterator.%GetNext(.tName, .tMeta) {
        If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName) Continue
        Set tRow = {}
        Do tRow.%Set("name", tName, "string")
        Do tRow.%Set("type", $Select($IsObject(tMeta): tMeta.%Get("type"), 1: "string"), "string")
        Do tRow.%Set("hint", $Select($IsObject(tMeta): tMeta.%Get("hint"), 1: ""), "string")
        Do tSettings.%Push(tRow)
    }
    Quit tSettings
}

/// <p>The <code>PUT</code> this port sends: the authenticator's checks, its credential-named settings
/// filled from the fresh read, the vendor's write, and a vendor 500 mapped (class description).</p>
ClassMethod Put(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Vendor(..#RESOURCEENDPOINT, "PUT", .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    If tBody.%GetTypeOf(..#AUTHENTICATORFIELD) = "object" {
        Set tAuthenticator = tBody.%Get(..#AUTHENTICATORFIELD)
        Set tSent = ..CredentialSettings(tAuthenticator)
        If tSent '= "" Quit ..Violation(..#AUTHENTICATORFIELD _ "." _ $List(tSent, 1), ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORSECRET, .pHttpStatus, .pFault)
        If '..AuthenticatorUsable(..Text(tAuthenticator, ..#NAMESPACEMEMBER), ..Text(tAuthenticator, ..#IMPLEMENTATIONMEMBER), .tCode) {
            Quit ..Violation(..#AUTHENTICATORFIELD _ "." _ $Select(tCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORNAMESPACE: ..#NAMESPACEMEMBER, 1: ..#IMPLEMENTATIONMEMBER), tCode, .pHttpStatus, .pFault)
        }
        ; The fresh, unstripped read the omitted credential settings are taken from. A 404 is a
        ; create, which has none. The vendor's own gate refuses a caller without the endpoint's
        ; resource here, before anything is sent.
        Set tReadSC = ..Vendor(..#RESOURCEENDPOINT, "GET", .pQuery, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
            Set pHttpStatus = tReadHttp
            Set pFault = tReadFault
            Quit tReadSC
        }
        If $$$ISOK(tReadSC) && $IsObject(tFresh) && (tFresh.%GetTypeOf(..#AUTHENTICATORFIELD) = "object") {
            Set tStored = tFresh.%Get(..#AUTHENTICATORFIELD)
            If ..SameAuthenticator(tStored, tAuthenticator) {
                Set tKept = ..CredentialSettings(tStored)
                For tI = 1:1:$ListLength(tKept) {
                    Set tName = $List(tKept, tI)
                    Set tType = tStored.%GetTypeOf(tName)
                    If (tType = "object") || (tType = "array") {
                        Do tAuthenticator.%Set(tName, ##class(%DynamicAbstractObject).%FromJSON(tStored.%Get(tName).%ToJSON()))
                    } Else {
                        Do tAuthenticator.%Set(tName, tStored.%Get(tName), tType)
                    }
                }
            }
        }
        Set tFresh = ""
    }
    Set tSC = ..Vendor(..#RESOURCEENDPOINT, "PUT", .pQuery, tBody, .pResult, .pHttpStatus, .pFault)
    Set tBody = ""
    If $$$ISOK(tSC) {
        Set pResult = ..Stripped(pResult)
        Quit tSC
    }
    If +pHttpStatus '= 500 Quit tSC
    Set tDetail = ""
    If $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") Set tDetail = pFault.%Get("detail")
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERVALIDATION, .pHttpStatus, .pFault, tDetail)
}

/// <p>The client secret write: <var>pBody</var> must carry <parameter>SECRETFIELD</parameter> and no
/// other key. A key outside it is refused as a caller fault; a missing or empty secret is 422
/// <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERNOSECRET</parameter> with nothing sent.</p>
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
    If tStray {
        Set tSecret = ""
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#RESOURCEENDPOINT _ " " _ ..#SECRETSTYPE _ " was given a key other than its one secret", $$$ERROR($$$GeneralError, "a secret body carries only " _ ..#SECRETFIELD), pFault.code)
        Quit tSC
    }
    If tSecret = "" Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNOSECRET, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERNOSECRET, .pHttpStatus, .pFault)
    Set tVendor = {}
    Do tVendor.%Set(..#SECRETFIELD, tSecret, "string")
    Set tSecret = ""
    Set tSC = ..Vendor(..#RESOURCEENDPOINT, ..#SECRETSTYPE, .pQuery, tVendor, .pResult, .pHttpStatus, .pFault)
    Set tVendor = ""
    Quit tSC
}

/// <p>The <parameter>MAPPINGSTYPE</parameter> read for server <var>pName</var> (class description).
/// An absent server is the vendor's 404.</p>
ClassMethod Mappings(pName As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Kill tQuery
    Set tQuery(..#NAMEQUERY) = pName
    Set tSC = ..Vendor(..#RESOURCEENDPOINT, "GET", .tQuery, "", .tRead, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRead) || 'tRead.%IsA("%Library.DynamicObject") Quit ..Fail(..#RESOURCEENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tSC = ..MappingTable(pName, .tMappings, .tHeld, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("IssuerEndpoint", ..Text(tRead, "IssuerEndpoint"), "string")
    Do pResult.%Set("Mappings", tMappings)
    Do pResult.%Set("Held", tHeld)
    Do pResult.%Set("Service", "", "string")
    Do pResult.%Set("Key", "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Every mapping on the instance, from both services' vendor <code>LIST</code>s, each behind the
/// endpoint's own gate: server <var>pName</var>'s as <var>pMappings</var>,
/// <code>[&lt;Service&gt;/&lt;key&gt;]</code>, and all of them as <var>pHeld</var>,
/// <code>{&lt;Service&gt;/&lt;key&gt;: server}</code>. An empty <var>pName</var> holds none.</p>
ClassMethod MappingTable(pName As %String, Output pMappings As %DynamicArray, Output pHeld As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pMappings = []
    Set pHeld = {}
    Set tSC = $$$OK
    For tI = 1:1:$Length(..#SERVICES, ",") {
        Set tService = $Piece(..#SERVICES, ",", tI)
        Kill tQuery
        Set tQuery(..#SERVICEQUERY) = tService
        Set tSC = ..Vendor(..#MAPPINGENDPOINT, "LIST", .tQuery, "", .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRows) Continue
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tMapping = ..MappingName(tService, ..Text(tRow, "Key"))
            Set tHolder = ..Text(tRow, "Resource")
            Do pHeld.%Set(tMapping, tHolder, "string")
            If (pName '= "") && (tHolder = pName) Do pMappings.%Push(tMapping)
        }
    }
    Quit tSC
}

/// <p>The one name a mapping is known by here: <var>pService</var>, a slash, and <var>pKey</var>
/// lower-cased, as the vendor stores it.</p>
ClassMethod MappingName(pService As %String, pKey As %String) As %String
{
    Quit pService _ "/" _ $ZConvert(pKey, "L")
}

/// <p>The <parameter>ADDTYPE</parameter> write: the mapping of <var>pService</var> and <var>pKey</var>
/// created for server <var>pName</var>, or moved to it from the server that holds it.</p>
ClassMethod AddMapping(pName As %String, pService As %String, pKey As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$ListFind($ListFromString(..#SERVICES), pService) Quit ..Violation("Service", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGSERVICEVALUE, .pHttpStatus, .pFault)
    If (pKey = "") || ($Length(pKey) > 64) Quit ..Violation("Key", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGKEYABSENT, .pHttpStatus, .pFault)
    Kill tQuery
    Set tQuery(..#SERVICEQUERY) = pService
    Set tQuery(..#KEYQUERY) = pKey
    Set tBody = {}
    Do tBody.%Set("Resource", pName, "string")
    Set tSC = ..Vendor(..#MAPPINGENDPOINT, "PUT", .tQuery, tBody, .tAnswer, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) {
        Set pResult = {}
        Quit tSC
    }
    ; The vendor answers 500 for a key that names no application or namespace, and 422 for a server
    ; that is gone.
    If +pHttpStatus = 500 Quit ..Violation("Key", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGKEYABSENT, .pHttpStatus, .pFault)
    If +pHttpStatus = 422 Quit ..Fail(..#RESOURCEENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>The <parameter>REMOVETYPE</parameter> write: the mapping of <var>pService</var> and
/// <var>pKey</var>, deleted when server <var>pName</var> holds it and refused
/// <parameter>OcuPilot.Api.Error.OAUTHMAPPINGABSENT</parameter> otherwise.</p>
ClassMethod RemoveMapping(pName As %String, pService As %String, pKey As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$ListFind($ListFromString(..#SERVICES), pService) Quit ..Violation("Service", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGSERVICEVALUE, .pHttpStatus, .pFault)
    Kill tQuery
    Set tQuery(..#SERVICEQUERY) = pService
    Set tQuery(..#KEYQUERY) = pKey
    Set tSC = ..Vendor(..#MAPPINGENDPOINT, "GET", .tQuery, "", .tMapping, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) {
        Set pHttpStatus = tHttp
        Set pFault = tFault
        Quit tSC
    }
    If $$$ISERR(tSC) || '$IsObject(tMapping) || (..Text(tMapping, "Resource") '= pName) {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHMAPPINGABSENT, ##class(OcuPilot.Api.Error).#REASONOAUTHMAPPINGABSENT, .pHttpStatus, .pFault)
    }
    Set tSC = ..Vendor(..#MAPPINGENDPOINT, "DELETE", .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Set pResult = {}
    Quit tSC
}

/// <p>The <parameter>AUTHENTICATORSTYPE</parameter> read: <code>{Namespace, Authenticators:
/// [{Implementation, Settings}]}</code>, every compiled, concrete authenticator class namespace
/// <var>pNamespace</var> offers (<parameter>DEFAULTNAMESPACE</parameter> when empty), each with
/// <method>SettingsOf</method>'s settings. A namespace that does not exist or that the caller cannot
/// enter answers <parameter>DEFAULTIMPLEMENTATION</parameter> alone.</p>
ClassMethod Authenticators(pNamespace As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tNamespace = $Select(pNamespace = "": ..#DEFAULTNAMESPACE, 1: pNamespace)
    Set tClasses = ""
    Set tEntered = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If $Match(tNamespace, "^[%A-Za-z][A-Za-z0-9_-]*$") && ##class(%SYS.Namespace).Exists(tNamespace) {
            Set $NAMESPACE = tNamespace
            Set tEntered = 1
            Set tStatement = ##class(%SQL.Statement).%New()
            Set tPrepared = tStatement.%PrepareClassQuery("%Dictionary.ClassDefinition", "SubclassOf", 0)
            If $$$ISOK(tPrepared) {
                Set tRows = tStatement.%Execute(..#AUTHENTICATORBASE)
                While tRows.%Next() {
                    Set tClass = tRows.%Get("Name")
                    If ..IsAuthenticatorClass(tClass) Set tClasses = tClasses _ $ListBuild(tClass)
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tEntered = 0
        Set tClasses = ""
    }
    If 'tEntered || (tClasses = "") {
        Set tNamespace = $Select(tEntered: tNamespace, 1: ..#DEFAULTNAMESPACE)
        Set tClasses = $ListBuild(..#DEFAULTIMPLEMENTATION)
    }
    Set tList = []
    For tI = 1:1:$ListLength(tClasses) {
        Set tClass = $List(tClasses, tI)
        Set tSettings = ..SettingsOf(tNamespace, tClass)
        If '$IsObject(tSettings) Continue
        Set tEntry = {}
        Do tEntry.%Set(..#IMPLEMENTATIONMEMBER, tClass, "string")
        Do tEntry.%Set("Settings", tSettings)
        Do tList.%Push(tEntry)
    }
    Set pResult = {}
    Do pResult.%Set(..#NAMESPACEMEMBER, tNamespace, "string")
    Do pResult.%Set("Authenticators", tList)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The first pair of <parameter>GATEPAIRS</parameter> the caller does not hold, as
/// <code>&lt;resource&gt;:&lt;permission&gt;</code>, or <code>""</code> when it holds them all. Each
/// pair is asked through the admin port's <method>HoldsPair</method>.</p>
ClassMethod RefusedPair() As %String
{
    Set tRefused = ""
    For tI = 1:1:$Length(..#GATEPAIRS, ",") {
        Set tPair = $Piece(..#GATEPAIRS, ",", tI)
        If '..HoldsPair(tPair) Set tRefused = tPair Quit
    }
    Quit tRefused
}

/// <p>The 403 a caller without pair <var>pPair</var> is answered before any vendor call: the admin
/// port's own mapping of 403, with the pair in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A 422 <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERVALIDATION</parameter> fault carrying
/// one violation of <var>pCode</var> on <var>pField</var> (AD-39).</p>
ClassMethod Violation(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tRow)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERVALIDATION, .pHttpStatus, .pFault, tDetail)
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

}
