/// <p>The OAuth 2.0 resource server editor's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerCreate</class>,
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerUpdate</class> and the two mapping tools applies
/// (<method>Validate</method>, <method>MappingViolations</method>), the expansion that makes a body the
/// complete set (<method>Expand</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so a field
/// refusal on the screen and the agent's argument refusal are one wording. Each rule is one the
/// vendor would otherwise answer with a 500 or a 422 (measured).</p>
Class OcuPilot.Area.Security.OAuthResourceServerRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerForm";

/// <p>The port the authenticator and mapping reads go through.</p>
Parameter PORT = "OcuPilot.Port.OAuthResourceServerPort";

/// <p>The generated field lists and the derived template list.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter TEMPLATELIST = "Security.OAuth2.ResourceServer";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDISSUER = "IssuerEndpoint";

Parameter FIELDAUDIENCES = "Audiences";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDSCOPE = "ScopeRequiredToConnect";

Parameter FIELDMETHOD = "IntrospectionAuthMethod";

Parameter FIELDAUTHENTICATOR = "Authenticator";

/// <p>The top-level fields that carry text, and the four flags.</p>
Parameter TEXTFIELDS = "Description,IssuerEndpoint,ScopeRequiredToConnect,ClientId,IntrospectionAuthMethod";

Parameter FLAGFIELDS = "Enabled,AccessTokenIsJWT,AlwaysCallIntrospection,UseOIDC";

/// <p>The introspection methods the vendor stores, the empty one among them.</p>
Parameter METHODS = ",client_secret_post,client_secret_basic,none";

/// <p>The vendor's bounds: a name, an audience and the two bounded texts, and a mapping's key.</p>
Parameter NAMEMAXLENGTH As INTEGER = 128;

Parameter TEXTMAXLENGTH As INTEGER = 256;

Parameter KEYMAXLENGTH As INTEGER = 64;

/// <p>The fields a create must carry, as the form names them.</p>
Parameter REQUIREDFIELDS = "Name,IssuerEndpoint,Audiences";

/// <p>The screens whose declared reads name what the form offers (AD-5), and the field each row
/// names it by.</p>
Parameter SERVERSCREEN = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter SERVERISSUERFIELD = "IssuerEndpoint";

Parameter WEBAPPSCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter WEBAPPNAMEFIELD = "Name";

/// <p>The body's top-level fields, in the derived template list's order (AD-3).</p>
ClassMethod TemplateFields(Output pFields As %List) As %Status
{
    Set pFields = ""
    Set tSC = $$$OK
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#FIELDLISTSCLASS, "Lists", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the generated field lists are missing from " _ ..#FIELDLISTSCLASS)
            Quit
        }
        Do tXData.Data.Rewind()
        Set tLists = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        Set tList = ""
        If $IsObject(tLists) Set tList = tLists.%Get(..#TEMPLATELIST)
        If '$IsObject(tList) || (tList.%GetTypeOf("rows") '= "array") {
            Set tSC = $$$ERROR($$$GeneralError, ..#TEMPLATELIST _ " has no list in " _ ..#FIELDLISTSCLASS)
            Quit
        }
        Set tIterator = tList.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tPath = tRow.%Get("path")
            If (tPath = "") || (tPath [ ".") || (tPath [ "[") Continue
            Set pFields = pFields _ $ListBuild(tPath)
        }
        If pFields = "" Set tSC = $$$ERROR($$$GeneralError, ..#TEMPLATELIST _ " has no rows")
    } Catch ex {
        Set pFields = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule a resource server write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's rules to <var>pName</var> and requires
/// every required field; <code>update</code> reads each field <var>pArgs</var> does not carry from
/// <var>pFresh</var>, so a field is required only when the arguments empty it. <var>pCheckTaken</var> 0
/// skips the name look-up, for the agent's mint, which has read the target itself. A look-up that
/// fails is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        If tCreates {
            Set tSC = ..NameViolation(pName, pCheckTaken, .pViolations)
            If $$$ISERR(tSC) Quit
        }
        For tI = 1:1:$Length(..#TEXTFIELDS, ",") {
            Set tField = $Piece(..#TEXTFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") || (tType = "boolean") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        For tI = 1:1:$Length(..#FLAGFIELDS, ",") {
            Set tField = $Piece(..#FLAGFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType '= "unassigned") && (tType '= "boolean") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHFLAGVALUE)
        }
        If $Length(..Text(pArgs, ..#FIELDDESCRIPTION)) > ..#TEXTMAXLENGTH Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#OAUTHDESCRIPTIONLENGTH)
        If $Length(..Text(pArgs, ..#FIELDSCOPE)) > ..#TEXTMAXLENGTH Do ..Add(.pViolations, ..#FIELDSCOPE, ##class(OcuPilot.Api.Error).#OAUTHSCOPEREQUIREDLENGTH)
        If (pArgs.%GetTypeOf(..#FIELDMETHOD) = "string") && '$ListFind($ListFromString(..#METHODS), pArgs.%Get(..#FIELDMETHOD)) {
            Do ..Add(.pViolations, ..#FIELDMETHOD, ##class(OcuPilot.Api.Error).#OAUTHINTROSPECTIONAUTHMETHODVALUE)
        }
        If ..Changes(pArgs, ..#FIELDISSUER, tCreates) {
            Set tIssuer = ..Effective(pArgs, pFresh, ..#FIELDISSUER, tCreates)
            If tIssuer = "" {
                Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTREQUIRED)
            } ElseIf '..IssuerPresent(tIssuer) {
                Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT)
            }
        }
        If ..Changes(pArgs, ..#FIELDAUDIENCES, tCreates) Do ..AudienceViolations(pArgs.%Get(..#FIELDAUDIENCES), pArgs.%GetTypeOf(..#FIELDAUDIENCES), .pViolations)
        Set tAuthenticatorType = pArgs.%GetTypeOf(..#FIELDAUTHENTICATOR)
        If tAuthenticatorType = "object" {
            Do ..AuthenticatorViolations(pArgs.%Get(..#FIELDAUTHENTICATOR), .pViolations)
        } ElseIf tAuthenticatorType '= "unassigned" {
            Do ..Add(.pViolations, ..#FIELDAUTHENTICATOR, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation for <var>pName</var>: absent, longer than
/// <parameter>NAMEMAXLENGTH</parameter> or carrying a control character, or -- with
/// <var>pCheckTaken</var> -- carried by a resource server already.</p>
ClassMethod NameViolation(pName As %String, pCheckTaken As %Boolean, ByRef pViolations) As %Status
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEREQUIRED)
        Quit $$$OK
    }
    If ($Length(pName) > ..#NAMEMAXLENGTH) || ($ZStrip(pName, "*C") '= pName) {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMESHAPE)
        Quit $$$OK
    }
    If 'pCheckTaken Quit $$$OK
    Set tSC = ..Present(pName, .tFresh, .tHttp, .tFault)
    If $$$ISOK(tSC) {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMETAKEN)
        Quit $$$OK
    }
    If +$Get(tHttp) = 404 Quit $$$OK
    Quit tSC
}

/// <p>The audience violations of <var>pValue</var>, of JSON type <var>pType</var>: not an array or an
/// empty one, an entry that is not 1 to 256 characters of text with no control character, and an
/// entry listed twice.</p>
ClassMethod AudienceViolations(pValue, pType As %String, ByRef pViolations) [ Private ]
{
    If pType '= "array" {
        Do ..Add(.pViolations, ..#FIELDAUDIENCES, $Select((pType = "unassigned") || (pType = "null"): ##class(OcuPilot.Api.Error).#OAUTHAUDIENCESREQUIRED, 1: ##class(OcuPilot.Api.Error).#OAUTHAUDIENCESSHAPE))
        Quit
    }
    If pValue.%Size() = 0 {
        Do ..Add(.pViolations, ..#FIELDAUDIENCES, ##class(OcuPilot.Api.Error).#OAUTHAUDIENCESREQUIRED)
        Quit
    }
    Set (tShape, tDuplicate) = 0
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAudience) {
        If (pValue.%GetTypeOf(tIndex) '= "string") || (tAudience = "") || ($Length(tAudience) > ..#TEXTMAXLENGTH) || ($ZStrip(tAudience, "*C") '= tAudience) {
            Set tShape = 1
            Continue
        }
        If $Data(tSeen(tAudience)) Set tDuplicate = 1
        Set tSeen(tAudience) = ""
    }
    If tShape Do ..Add(.pViolations, ..#FIELDAUDIENCES, ##class(OcuPilot.Api.Error).#OAUTHAUDIENCESSHAPE)
    If tDuplicate Do ..Add(.pViolations, ..#FIELDAUDIENCES, ##class(OcuPilot.Api.Error).#OAUTHAUDIENCESDUPLICATE)
}

/// <p>The authenticator violations of <var>pAuthenticator</var>: a namespace the caller's namespace
/// list does not name, a class that namespace does not compile as an authenticator, and a setting
/// that is a credential's, that the class does not describe, or whose value is not the described
/// type. Each field is <code>Authenticator.&lt;member&gt;</code>.</p>
ClassMethod AuthenticatorViolations(pAuthenticator As %DynamicObject, ByRef pViolations) [ Private ]
{
    Set tPort = ..#PORT
    Set tNamespaceMember = $Parameter(tPort, "NAMESPACEMEMBER")
    Set tImplementationMember = $Parameter(tPort, "IMPLEMENTATIONMEMBER")
    Set tNamespace = ..Text(pAuthenticator, tNamespaceMember)
    Set tImplementation = ..Text(pAuthenticator, tImplementationMember)
    If (tNamespace = "") || '..NamespaceReadable(tNamespace) {
        Do ..Add(.pViolations, ..#FIELDAUTHENTICATOR _ "." _ tNamespaceMember, ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORNAMESPACE)
        Quit
    }
    If '$ClassMethod(tPort, "AuthenticatorUsable", tNamespace, tImplementation, .tCode) {
        Do ..Add(.pViolations, ..#FIELDAUTHENTICATOR _ "." _ $Select(tCode = ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORNAMESPACE: tNamespaceMember, 1: tImplementationMember), tCode)
        Quit
    }
    Set tSettings = $ClassMethod(tPort, "SettingsOf", tNamespace, tImplementation)
    If $IsObject(tSettings) {
        Set tIterator = tSettings.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tSetting) { Set tTypes(tSetting.%Get("name")) = tSetting.%Get("type") }
    }
    Set tIterator = pAuthenticator.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        If (tMember = tNamespaceMember) || (tMember = tImplementationMember) Continue
        Set tField = ..#FIELDAUTHENTICATOR _ "." _ tMember
        If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tMember) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORSECRET)
            Continue
        }
        If '$Data(tTypes(tMember)) || '..SettingShaped(tTypes(tMember), pAuthenticator.%GetTypeOf(tMember), tValue) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHAUTHENTICATORSETTING)
        }
    }
}

/// <p>Whether a value of JSON type <var>pType</var> fits an authenticator setting described as
/// <var>pKind</var>: a boolean, an integer or its digits, a number or its text, text, or an object or
/// array. An empty text fits every scalar kind, as the vendor's own default does.</p>
ClassMethod SettingShaped(pKind As %String, pType As %String, pValue) As %Boolean [ Private ]
{
    If pKind = "object" Quit (pType = "object") || (pType = "array")
    If (pType = "object") || (pType = "array") || (pType = "null") Quit 0
    If (pType = "string") && (pValue = "") Quit 1
    If pKind = "boolean" Quit (pType = "boolean")
    If pKind = "integer" Quit ((pType = "number") && (pValue = (pValue \ 1))) || ((pType = "string") && $Match(pValue, "-?[0-9]{1,18}"))
    If pKind = "double" Quit (pType = "number") || ((pType = "string") && $IsValidNum(pValue))
    Quit (pType = "string")
}

/// <p>The mapping violations of adding (<var>pMode</var> <code>add</code>) or removing
/// (<code>remove</code>) the mapping of <var>pService</var> and <var>pKey</var> for server
/// <var>pName</var>, over its <code>MAPPINGS</code> read <var>pFresh</var>, in <var>pViolations</var>:
/// a service that is neither mapping service; a key that is not <code>*</code>, an application this
/// instance serves or a namespace it has, at most 64 characters; and a removal this server does not
/// hold. Each field is <var>pPrefix</var> followed by <code>Service</code> or <code>Key</code>.</p>
ClassMethod MappingViolations(pName As %String, pService As %String, pKey As %String, pMode As %String, pFresh As %DynamicObject, pPrefix As %String, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tServices = $ListFromString($Parameter(..#PORT, "SERVICES"))
        If '$ListFind(tServices, pService) {
            Do ..Add(.pViolations, pPrefix _ "Service", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGSERVICEVALUE)
            Quit
        }
        If pMode = "remove" {
            Set tMapping = $ClassMethod(..#PORT, "MappingName", pService, pKey)
            If '$IsObject(pFresh) || '$ListFind(..MappingList(pFresh.%Get("Mappings")), tMapping) Do ..Add(.pViolations, pPrefix _ "Key", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGABSENT)
            Quit
        }
        If '..KeyExists(pService, pKey) Do ..Add(.pViolations, pPrefix _ "Key", ##class(OcuPilot.Api.Error).#OAUTHMAPPINGKEYABSENT)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pKey</var> names <code>*</code>, or for <var>pService</var>'s Web Gateway an
/// application the caller reads through the web applications screen, or for its bindings a namespace
/// the caller's namespace list names; compared without regard to case, as the vendor stores keys
/// lower-cased.</p>
ClassMethod KeyExists(pService As %String, pKey As %String) As %Boolean
{
    If (pKey = "") || ($Length(pKey) > ..#KEYMAXLENGTH) Quit 0
    If pKey = $Parameter(..#PORT, "DEFAULTKEY") Quit 1
    Set tNames = $Select(pService = $Piece($Parameter(..#PORT, "SERVICES"), ",", 1): ..WebApplications(), 1: ..Namespaces())
    Set tWanted = $ZConvert(pKey, "L")
    Set tFound = 0
    Set tIterator = tNames.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If $ZConvert(tName, "L") = tWanted Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Whether <var>pNamespace</var> is one the caller's namespace list names, compared without regard
/// to case.</p>
ClassMethod NamespaceReadable(pNamespace As %String) As %Boolean
{
    Set tFound = 0
    Set tIterator = ..Namespaces().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If $ZConvert(tName, "U") = $ZConvert(pNamespace, "U") Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>The namespaces the shell's <code>/namespaces</code> answers the caller, as a
/// <class>%DynamicArray</class> of names.</p>
ClassMethod Namespaces() As %DynamicArray
{
    Set tNames = []
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Shell.Namespaces).Payload(.tPayload)
        If $$$ISERR(tSC) || '$IsObject($Get(tPayload)) Quit
        Set tIterator = tPayload.%Get("namespaces").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If $IsObject(tEntry) Do tNames.%Push(tEntry.%Get("name"))
        }
    } Catch {
        Set tNames = []
    }
    Quit tNames
}

/// <p>The web applications the caller reads through that screen's own declared read (AD-5).</p>
ClassMethod WebApplications() As %DynamicArray
{
    Quit ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(..#WEBAPPSCREEN, ..#WEBAPPNAMEFIELD)
}

/// <p>The issuers of the server descriptions the caller reads through that tab's own declared read
/// (AD-5), or <code>[]</code> for a caller the tab refuses.</p>
ClassMethod ServerDescriptions() As %DynamicArray
{
    Quit ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(..#SERVERSCREEN, ..#SERVERISSUERFIELD)
}

/// <p>Whether <var>pIssuer</var> is the issuer of a server description the caller reads, compared
/// exactly, as the vendor looks it up.</p>
ClassMethod IssuerPresent(pIssuer As %String) As %Boolean
{
    Set tFound = 0
    Set tIterator = ..ServerDescriptions().%GetIterator()
    While tIterator.%GetNext(.tIndex, .tIssuer) {
        If tIssuer = pIssuer Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Make <var>pPayload</var> the body the vendor's <code>PUT</code> takes: its derived template
/// fields and nothing else (AD-3). With a fresh read <var>pFresh</var> whose authenticator names the
/// same namespace and class as <var>pPayload</var>'s, every setting the payload leaves out is filled
/// from the fresh read, in the fresh read's order, because the vendor replaces the authenticator whole
/// (AD-4). An authenticator of another namespace or class is sent as it is, so the settings it leaves
/// out take that class's defaults.</p>
ClassMethod Expand(pPayload As %DynamicObject, pFresh As %DynamicObject = "")
{
    If '$IsObject(pPayload) Quit
    If $$$ISERR(..TemplateFields(.tKeep)) Quit
    Set tDrop = ""
    Set tIterator = pPayload.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeep, tKey) Set tDrop = tDrop _ $ListBuild(tKey)
    }
    For tI = 1:1:$ListLength(tDrop) Do pPayload.%Remove($List(tDrop, tI))
    If '$IsObject(pFresh) Quit
    If pPayload.%GetTypeOf(..#FIELDAUTHENTICATOR) '= "object" Quit
    If pFresh.%GetTypeOf(..#FIELDAUTHENTICATOR) '= "object" Quit
    Set tSent = pPayload.%Get(..#FIELDAUTHENTICATOR)
    Set tStored = pFresh.%Get(..#FIELDAUTHENTICATOR)
    If '$ClassMethod(..#PORT, "SameAuthenticator", tStored, tSent) Quit
    Set tFilled = {}
    Set tIterator = tStored.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tFrom = $Select(tSent.%GetTypeOf(tKey) '= "unassigned": tSent, 1: tStored)
        Do ..CopyMember(tFrom, tKey, tFilled)
    }
    Set tIterator = tSent.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tFilled.%GetTypeOf(tKey) = "unassigned" Do ..CopyMember(tSent, tKey, tFilled)
    }
    Do pPayload.%Set(..#FIELDAUTHENTICATOR, tFilled)
}

/// <p>Copy <var>pFrom</var>'s member <var>pKey</var> into <var>pTo</var>, keeping its JSON type.</p>
ClassMethod CopyMember(pFrom As %DynamicObject, pKey As %String, pTo As %DynamicObject) [ Private ]
{
    Set tType = pFrom.%GetTypeOf(pKey)
    If (tType = "object") || (tType = "array") {
        Do pTo.%Set(pKey, ##class(%DynamicAbstractObject).%FromJSON(pFrom.%Get(pKey).%ToJSON()))
    } ElseIf tType = "null" {
        Do pTo.%Set(pKey, "", "null")
    } Else {
        Do pTo.%Set(pKey, pFrom.%Get(pKey), tType)
    }
}

/// <p><var>pMappings</var>, a <code>MAPPINGS</code> read's array, as a <class>%List</class>.</p>
ClassMethod MappingList(pMappings) As %List
{
    Set tList = ""
    If '$IsObject(pMappings) Quit tList
    Set tIterator = pMappings.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMapping) { Set tList = tList _ $ListBuild(tMapping) }
    Quit tList
}

/// <p><var>pMappings</var>, a <code>MAPPINGS</code> read's array, as one comma-separated line.</p>
ClassMethod MappingsText(pMappings) As %String
{
    Quit $ListToString(..MappingList(pMappings), ", ")
}

/// <p>Answer <code>GET /oauth/resource-server/form[?name=&lt;name&gt;][&amp;namespace=&lt;ns&gt;]</code>:
/// what the form needs before it can draw a field (AD-39): <code>{requiredFields, rules,
/// serverDescriptions, webApplications, namespaces, authenticators, held, resourceServerCount}</code>.
/// The three name lists are what the caller can read through the server description tab's, the web
/// applications screen's and the shell's own reads (AD-5). <code>authenticators</code> is the port's
/// read for the requested namespace, else the definition's, else <code>%SYS</code>. <code>held</code>
/// maps every service mapping on the instance to its server. With a name it adds
/// <code>definition</code>, the edit tool's fresh read with no credential, and <code>mappings</code>,
/// the server's own. A name no server carries is 404
/// <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERNAMEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("serverDescriptions", ..ServerDescriptions())
        Do tBody.%Set("webApplications", ..WebApplications())
        Do tBody.%Set("namespaces", ..Namespaces())
        Set tPort = ..PortClass()
        Set tEndpoint = $ClassMethod(..#UPDATETOOL, "Endpoint")
        Kill tNone
        Set tListSC = $ClassMethod(tPort, "Invoke", tEndpoint, "LIST", .tNone, "", .tServers, .tListHttp, .tListFault)
        If $$$ISERR(tListSC) {
            Set tSC = ..RenderRead(tListSC, tListHttp, tListFault)
            Quit
        }
        Do tBody.%Set("resourceServerCount", $Select($IsObject(tServers): tServers.%Size(), 1: 0), "number")
        Set tTableSC = $ClassMethod(tPort, "MappingTable", "", .tMappings, .tHeld, .tTableHttp, .tTableFault)
        If $$$ISERR(tTableSC) {
            Set tSC = ..RenderRead(tTableSC, tTableHttp, tTableFault)
            Quit
        }
        Do tBody.%Set("held", tHeld)
        Set tNamespace = $Get(%request.Data("namespace", 1))
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tDefinition = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
            Do tDefinition.%Set(..#FIELDNAME, tName, "string")
            Do tBody.%Set("definition", tDefinition)
            Kill tQuery
            Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = tName
            Set tMappingsSC = $ClassMethod(tPort, "Invoke", tEndpoint, $Parameter(..#PORT, "MAPPINGSTYPE"), .tQuery, "", .tRead, .tMappingsHttp, .tMappingsFault)
            If $$$ISERR(tMappingsSC) {
                Set tSC = ..RenderRead(tMappingsSC, tMappingsHttp, tMappingsFault)
                Quit
            }
            Do tBody.%Set("mappings", tRead.%Get("Mappings"))
            If (tNamespace = "") && (tFresh.%GetTypeOf(..#FIELDAUTHENTICATOR) = "object") Set tNamespace = ..Text(tFresh.%Get(..#FIELDAUTHENTICATOR), $Parameter(..#PORT, "NAMESPACEMEMBER"))
        }
        Kill tQuery
        Set tQuery($Parameter(..#PORT, "NAMESPACEQUERY")) = tNamespace
        Set tAuthSC = $ClassMethod(tPort, "Invoke", tEndpoint, $Parameter(..#PORT, "AUTHENTICATORSTYPE"), .tQuery, "", .tAuthenticators, .tAuthHttp, .tAuthFault)
        If $$$ISERR(tAuthSC) {
            Set tSC = ..RenderRead(tAuthSC, tAuthHttp, tAuthFault)
            Quit
        }
        Do tBody.%Set("authenticators", tAuthenticators)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The server <var>pName</var>, read through the edit tool's own port and read type (AD-52), in
/// <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERNAMEABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERNAMEABSENT, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).OAuthResourceServerViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field an <code>OAUTH.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "RESOURCESERVERNAME" Quit ..#FIELDNAME
    If tPart = "ISSUERENDPOINT" Quit ..#FIELDISSUER
    If tPart = "AUDIENCES" Quit ..#FIELDAUDIENCES
    If tPart = "DESCRIPTION" Quit ..#FIELDDESCRIPTION
    If tPart = "SCOPEREQUIRED" Quit ..#FIELDSCOPE
    If tPart = "INTROSPECTIONAUTHMETHOD" Quit ..#FIELDMETHOD
    If tPart = "FLAG" Quit "Enabled"
    If tPart = "AUTHENTICATOR" {
        Set tRule = $Piece(pCode, ".", 3)
        If tRule = "NAMESPACE" Quit ..#FIELDAUTHENTICATOR _ "." _ $Parameter(..#PORT, "NAMESPACEMEMBER")
        If tRule = "IMPLEMENTATION" Quit ..#FIELDAUTHENTICATOR _ "." _ $Parameter(..#PORT, "IMPLEMENTATIONMEMBER")
        Quit ..#FIELDAUTHENTICATOR
    }
    If tPart = "MAPPINGSERVICE" Quit "Service"
    Quit "Key"
}

/// <p><var>pViolations</var> as one sentence naming each field and its reason, or <code>""</code>.</p>
ClassMethod Problem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>The port the rules read through: the edit tool's own declaration (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as
/// <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>The value <var>pField</var> will hold: <var>pArgs</var>'s when it carries one, otherwise
/// <var>pFresh</var>'s on an edit and <code>""</code> on a create.</p>
ClassMethod Effective(pArgs As %DynamicObject, pFresh As %DynamicObject, pField As %String, pCreates As %Boolean) As %String [ Private ]
{
    If pArgs.%GetTypeOf(pField) '= "unassigned" Quit ..Text(pArgs, pField)
    If pCreates Quit ""
    Quit ..Text(pFresh, pField)
}

/// <p>Whether a rule over <var>pField</var> applies: always on a create, and on an edit only when
/// <var>pArgs</var> carries the field.</p>
ClassMethod Changes(pArgs As %DynamicObject, pField As %String, pCreates As %Boolean) As %Boolean [ Private ]
{
    Quit pCreates || (pArgs.%GetTypeOf(pField) '= "unassigned")
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
