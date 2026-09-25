/// <p>The OAuth 2.0 authorization server port (AD-51, AD-52): <class>OcuPilot.Port.AdminPort</class>
/// with <parameter>SERVERENDPOINT</parameter>, this instance's one authorization server configuration,
/// shaped here, behind the endpoint's own gate and this port's <parameter>GATEPAIRS</parameter>.</p>
/// <p><b>The configuration is a singleton.</b> The vendor reads no query parameter for it, so this
/// port sends none, whatever id its caller names.</p>
/// <p><b><code>GET</code></b> adds <parameter>ROWFIELDS</parameter>: <code>Clients</code>, the clients
/// registered with this server as <code>[{ClientId, Name}]</code>, read through
/// <parameter>CLIENTSENDPOINT</parameter>'s <code>LIST</code> under that endpoint's own gate; and
/// <code>ClientsHidden</code>, true when that gate refuses the caller. The vendor's <code>GET</code>
/// never answers the key password.</p>
/// <p><b><code>PUT</code></b> removes <parameter>ROWFIELDS</parameter>, refuses a customization class
/// its namespace does not compile (<method>ClassUsable</method>), and names a vendor 500:
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCREDENTIALSKEY</parameter> when the body changes the server
/// credentials, <parameter>OcuPilot.Api.Error.OAUTHSERVERVALIDATION</parameter> otherwise, the vendor's
/// text logged alone.</p>
/// <p><b><parameter>PASSWORDTYPE</parameter></b> takes <code>{ServerPassword}</code> alone, non-empty:
/// the vendor stores an empty one, which clears the stored password.</p>
/// <p><b><parameter>ROTATETYPE</parameter></b> is this port's own (AD-27, Story 12.7's case): the
/// admin API has no rotate type, so after the gate and a fresh read it calls
/// <code>OAuth2.Server.Configuration.RotateKeys()</code> in <code>%SYS</code> (AD-16). A configuration
/// whose keys come from its server credentials is refused, and an absent one is 404.</p>
Class OcuPilot.Port.OAuthAuthorizationServerPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port shapes, and the endpoint its registered clients are read through.</p>
Parameter SERVERENDPOINT = "Security.OAuth2.Server";

Parameter CLIENTSENDPOINT = "Security.OAuth2.ServerClients";

/// <p>The members this port's <code>GET</code> adds, which a <code>PUT</code> body never carries.</p>
Parameter ROWFIELDS = "Clients,ClientsHidden";

Parameter CLIENTSFIELD = "Clients";

Parameter HIDDENFIELD = "ClientsHidden";

/// <p>The vendor's key password write and the one secret it takes.</p>
Parameter PASSWORDTYPE = "CHANGEPWD";

Parameter PASSWORDFIELD = "ServerPassword";

/// <p>The write this port carries out itself, and the pair it answers under.</p>
Parameter ROTATETYPE = "ROTATEKEYS";

Parameter COMPOSEDTYPES = "Security.OAuth2.Server/ROTATEKEYS";

/// <p>The vendor class the rotation is completed through.</p>
Parameter CONFIGURATIONCLASS = "OAuth2.Server.Configuration";

/// <p>The fields the port reads from a body or a fresh read.</p>
Parameter CREDENTIALSFIELD = "ServerCredentials";

Parameter NAMESPACEFIELD = "CustomizationNamespace";

Parameter CLASSFIELDS = "AuthenticateClass,SessionClass,ValidateUserClass,GenerateTokenClass,RevokeTokenClass";

/// <p>The vendor's bound on a customization class name.</p>
Parameter CLASSMAXLENGTH As INTEGER = 256;

/// <p>The pairs every <parameter>SERVERENDPOINT</parameter> call through this port requires, in the
/// order a refusal names the first one missing (AD-29): the authorization server tab's own set. The
/// vendor endpoint's <code>ResourcesOR()</code> is <code>%Admin_OAuth2_Server</code>.</p>
Parameter GATEPAIRS = "%Admin_OAuth2_Server:USE,%DB_IRISSYS:READ";

/// <p>The admin port's call, with <parameter>SERVERENDPOINT</parameter>'s <code>GET</code>,
/// <code>PUT</code>, <code>DELETE</code>, <parameter>PASSWORDTYPE</parameter> and
/// <parameter>ROTATETYPE</parameter> shaped here; any other endpoint or type is the admin port's own
/// call.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s; <var>pQuery</var> is ignored for the shaped
/// types and neither it nor <var>pBody</var> is modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#SERVERENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If '$ListFind($ListBuild("GET", "PUT", "DELETE", ..#PASSWORDTYPE, ..#ROTATETYPE), pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRefused = ..RefusedPair()
    If tRefused '= "" Quit ..GateRefusal(tRefused, .pHttpStatus, .pFault)
    Do ..Refresh()
    Set tSC = $$$OK
    Try {
        If pType = "GET" {
            Set tSC = ..Read(.pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = "PUT" {
            Set tSC = ..Put(pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#PASSWORDTYPE {
            Set tSC = ..ChangePassword(pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If ($IsObject(pBody) || (pBody '= "")) && ($ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) || (pType = "DELETE")) {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a bodyless type takes no caller body"), pFault.code)
            Quit
        }
        If pType = ..#ROTATETYPE {
            Set tSC = ..RotateKeys(.pResult, .pHttpStatus, .pFault)
            Quit
        }
        Kill tNone
        Set tSC = ..Vendor(pEndpoint, "DELETE", .tNone, "", .pResult, .pHttpStatus, .pFault)
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

/// <p>The configuration as the vendor's <code>GET</code> answers it, with
/// <parameter>ROWFIELDS</parameter> added (class description). An absent configuration is the
/// vendor's 404.</p>
ClassMethod Read(Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Kill tNone
    Set tSC = ..Vendor(..#SERVERENDPOINT, "GET", .tNone, "", .tRead, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRead)) || 'tRead.%IsA("%Library.DynamicObject") Quit ..Fail(..#SERVERENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tSC = ..Clients(.tClients, .tHidden, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Set pHttpStatus = tHttp
        Set pFault = tFault
        Quit tSC
    }
    Do tRead.%Set(..#CLIENTSFIELD, tClients)
    Do tRead.%Set(..#HIDDENFIELD, tHidden, "boolean")
    Set pResult = tRead
    Quit $$$OK
}

/// <p>The clients registered with this server, in <var>pClients</var> as
/// <code>[{ClientId, Name}]</code> ordered by name then client id, through
/// <parameter>CLIENTSENDPOINT</parameter>'s own <code>LIST</code> and gate. A caller that gate refuses
/// is answered <var>pHidden</var> 1 and no client; any other failure is an error status.</p>
ClassMethod Clients(Output pClients As %DynamicArray, Output pHidden As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pClients = []
    Set pHidden = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tNone
    Set tSC = ..Vendor(..#CLIENTSENDPOINT, "LIST", .tNone, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus '= 403 Quit tSC
        Set pHidden = 1
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    If '$IsObject($Get(tRows)) Quit $$$OK
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tId = ..Text(tRow, "ClientId")
        If tId = "" Continue
        Set tSorted(..Text(tRow, "Name"), tId) = ""
    }
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tId = ""
        For {
            Set tId = $Order(tSorted(tName, tId))
            If tId = "" Quit
            Set tEntry = {}
            Do tEntry.%Set("ClientId", tId, "string")
            Do tEntry.%Set("Name", tName, "string")
            Do pClients.%Push(tEntry)
        }
    }
    Quit $$$OK
}

/// <p>The <code>PUT</code> this port sends: <parameter>ROWFIELDS</parameter> removed, the
/// customization classes checked, the vendor's write, and a vendor 500 named (class description).</p>
ClassMethod Put(pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Kill tNone
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Vendor(..#SERVERENDPOINT, "PUT", .tNone, pBody, .pResult, .pHttpStatus, .pFault)
    Set tBody = ..VendorBody(pBody)
    ; The fresh read the class checks and the credentials comparison are made against. A 404 is a
    ; create, which holds nothing.
    Set tReadSC = ..Vendor(..#SERVERENDPOINT, "GET", .tNone, "", .tFresh, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
        Set pHttpStatus = tReadHttp
        Set pFault = tReadFault
        Quit tReadSC
    }
    If $$$ISERR(tReadSC) || '$IsObject($Get(tFresh)) Set tFresh = ""
    Set tNamespace = $Select(tBody.%GetTypeOf(..#NAMESPACEFIELD) = "string": tBody.%Get(..#NAMESPACEFIELD), 1: ..Text(tFresh, ..#NAMESPACEFIELD))
    Set tMoved = '$IsObject(tFresh) || ($ZConvert(tNamespace, "U") '= $ZConvert(..Text(tFresh, ..#NAMESPACEFIELD), "U"))
    Set tBad = ""
    For tI = 1:1:$Length(..#CLASSFIELDS, ",") {
        Set tField = $Piece(..#CLASSFIELDS, ",", tI)
        If tBody.%GetTypeOf(tField) '= "string" Continue
        Set tClass = tBody.%Get(tField)
        If 'tMoved && (tClass = ..Text(tFresh, tField)) Continue
        If '..ClassUsable(tNamespace, tClass) Set tBad = tField Quit
    }
    If tBad '= "" Quit ..Violation(tBad, ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONCLASSABSENT, .pHttpStatus, .pFault)
    Set tSC = ..Vendor(..#SERVERENDPOINT, "PUT", .tNone, tBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    Do ..Refresh()
    If +pHttpStatus '= 500 Quit tSC
    Set tCredentials = ""
    If tBody.%GetTypeOf(..#CREDENTIALSFIELD) = "string" Set tCredentials = tBody.%Get(..#CREDENTIALSFIELD)
    If (tCredentials '= "") && (tCredentials '= ..Text(tFresh, ..#CREDENTIALSFIELD)) Quit ..Violation(..#CREDENTIALSFIELD, ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSKEY, .pHttpStatus, .pFault)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERVALIDATION, .pHttpStatus, .pFault)
}

/// <p>A copy of <var>pBody</var> without <parameter>ROWFIELDS</parameter>, which the vendor's body
/// schema refuses.</p>
ClassMethod VendorBody(pBody As %DynamicObject) As %DynamicObject
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    For tI = 1:1:$Length(..#ROWFIELDS, ",") Do tBody.%Remove($Piece(..#ROWFIELDS, ",", tI))
    Quit tBody
}

/// <p>Whether <var>pClass</var> is a class name of at most <parameter>CLASSMAXLENGTH</parameter>
/// characters compiled in namespace <var>pNamespace</var>, read from <code>%Dictionary</code> there.
/// A namespace that does not exist or that the caller cannot enter answers 0. The caller's namespace
/// is unchanged on return (AD-16).</p>
ClassMethod ClassUsable(pNamespace As %String, pClass As %String) As %Boolean
{
    If (pClass = "") || ($Length(pClass) > ..#CLASSMAXLENGTH) Quit 0
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit 0
    If '$Match(pNamespace, "^[%A-Za-z][A-Za-z0-9_-]*$") Quit 0
    Set tUsable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If '##class(%SYS.Namespace).Exists(pNamespace) Quit
        Set $NAMESPACE = pNamespace
        Set tUsable = ##class(%Dictionary.CompiledClass).%ExistsId(pClass)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tUsable = 0
    }
    Quit ''tUsable
}

/// <p>The key password write: <var>pBody</var> must carry <parameter>PASSWORDFIELD</parameter> and no
/// other key. A key outside it is refused as a caller fault; a missing or empty password is 422
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERNOPASSWORD</parameter> with nothing sent. A vendor 500 is
/// named as the <code>PUT</code>'s is, against the stored server credentials.</p>
ClassMethod ChangePassword(pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tPassword = ""
    Set tStray = 0
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If tKey '= ..#PASSWORDFIELD Set tStray = 1 Quit
            If pBody.%GetTypeOf(tKey) = "string" Set tPassword = tValue
        }
    } ElseIf pBody '= "" {
        Set tStray = 1
    }
    Kill tValue
    If tStray {
        Set tPassword = ""
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#SERVERENDPOINT _ " " _ ..#PASSWORDTYPE _ " was given a key other than its one secret", $$$ERROR($$$GeneralError, "a secret body carries only " _ ..#PASSWORDFIELD), pFault.code)
        Quit tSC
    }
    If tPassword = "" Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERNOPASSWORD, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERNOPASSWORD, .pHttpStatus, .pFault)
    Set tVendor = {}
    Do tVendor.%Set(..#PASSWORDFIELD, tPassword, "string")
    Set tPassword = ""
    Kill tNone
    Set tSC = ..Vendor(..#SERVERENDPOINT, ..#PASSWORDTYPE, .tNone, tVendor, .pResult, .pHttpStatus, .pFault)
    Set tVendor = ""
    If $$$ISOK(tSC) Quit tSC
    Do ..Refresh()
    If +pHttpStatus '= 500 Quit tSC
    Set tReadSC = ..Vendor(..#SERVERENDPOINT, "GET", .tNone, "", .tFresh, .tReadHttp, .tReadFault)
    If $$$ISOK(tReadSC) && (..Text($Get(tFresh), ..#CREDENTIALSFIELD) '= "") Quit ..Violation(..#CREDENTIALSFIELD, ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSKEY, .pHttpStatus, .pFault)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERVALIDATION, .pHttpStatus, .pFault)
}

/// <p>Reload this process's in-memory copy of the configuration and its metadata from the database,
/// discarding anything a refused write left unsaved. Once a process opens the vendor's configuration
/// it stays in memory (measured: a change another process saved was not seen by a later open here),
/// so without this the process's next read would answer what it held then, and its next save would
/// store it. The caller's namespace is unchanged on return (AD-16).</p>
ClassMethod Refresh() [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tConfiguration = $ClassMethod(..#CONFIGURATIONCLASS, "Open", .tOpenSC)
        If $IsObject(tConfiguration) {
            Do tConfiguration.%Reload()
            If $IsObject(tConfiguration.Metadata) Do tConfiguration.Metadata.%Reload()
        }
        Set tConfiguration = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The <parameter>ROTATETYPE</parameter> write (class description). On success <var>pResult</var>
/// is <code>{}</code>; a rotation the vendor refuses is 422
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERVALIDATION</parameter>, its text logged alone.</p>
ClassMethod RotateKeys(Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Kill tNone
    Set tSC = ..Vendor(..#SERVERENDPOINT, "GET", .tNone, "", .tFresh, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tFresh)) Quit ..Fail(..#SERVERENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    If ..Text(tFresh, ..#CREDENTIALSFIELD) '= "" Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#OAUTHSERVERKEYSCREDENTIALS, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERKEYSCREDENTIALS, .pHttpStatus, .pFault)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tOpenSC = $$$OK
        Set tConfiguration = $ClassMethod(..#CONFIGURATIONCLASS, "Open", .tOpenSC)
        If '$IsObject(tConfiguration) {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(..#SERVERENDPOINT, 404, tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tRotateSC = tConfiguration.RotateKeys()
        Set tConfiguration = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tRotateSC) {
            Do ..Refresh()
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERVALIDATION, .pHttpStatus, .pFault)
            Do ..LogFault(..#SERVERENDPOINT _ " " _ ..#ROTATETYPE _ " was refused by the vendor", tRotateSC, pFault.code)
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

/// <p>A 422 <parameter>OcuPilot.Api.Error.OAUTHSERVERVALIDATION</parameter> fault carrying one
/// violation of <var>pCode</var> on <var>pField</var> (AD-39).</p>
ClassMethod Violation(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tRow)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERVALIDATION, .pHttpStatus, .pFault, tDetail)
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
