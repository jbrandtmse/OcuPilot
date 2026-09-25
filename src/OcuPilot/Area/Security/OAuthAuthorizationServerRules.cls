/// <p>The OAuth 2.0 authorization server editor's rules (AD-39, AD-55): the one rule set every caller
/// of <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate</class> and
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate</class> applies
/// (<method>Validate</method>), the complete set a body is made (<method>Expand</method>,
/// <method>Defaults</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so a field
/// refusal on the screen and the agent's argument refusal are one wording. Each rule covers a value
/// the vendor refuses with a 500, or accepts although the classic page cannot enter it
/// (measured).</p>
Class OcuPilot.Area.Security.OAuthAuthorizationServerRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerForm";

/// <p>The port the class checks and the clients read go through.</p>
Parameter PORT = "OcuPilot.Port.OAuthAuthorizationServerPort";

/// <p>The generated field lists and the derived template list.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter TEMPLATELIST = "Security.OAuth2.Server";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDISSUER = "IssuerEndpoint";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDSCOPES = "SupportedScopes";

Parameter FIELDDEFAULTSCOPE = "DefaultScope";

Parameter FIELDREFRESH = "ReturnRefreshToken";

Parameter FIELDMETADATA = "Metadata";

Parameter FIELDNAMESPACE = "CustomizationNamespace";

Parameter FIELDROLES = "CustomizationRoles";

Parameter FIELDSSL = "SSLConfiguration";

Parameter FIELDCREDENTIALS = "ServerCredentials";

Parameter FIELDSIGNING = "SigningAlgorithm";

Parameter FIELDENCRYPTION = "EncryptionAlgorithm";

Parameter FIELDKEY = "KeyAlgorithm";

/// <p>The metadata member holding the grant types, and the one the vendor always adds.</p>
Parameter GRANTTYPES = "grant_types_supported";

Parameter REFRESHGRANT = "refresh_token";

/// <p>The grant types the editor offers, one of which must be chosen.</p>
Parameter GRANTCHOICES = "authorization_code,implicit,password,client_credentials,jwt_authorization";

/// <p>The metadata members the editor sets: the two front-channel flags and the three URLs.</p>
Parameter METADATAFLAGS = "frontchannel_logout_supported,frontchannel_logout_session_supported";

Parameter METADATAURLS = "service_documentation,op_policy_uri,op_tos_uri";

/// <p>The intervals: those whose floor is 1, and those whose floor is 0.</p>
Parameter INTERVALS = "AccessTokenInterval,AuthorizationCodeInterval,RefreshTokenInterval";

Parameter ZEROINTERVALS = "SessionInterval,ClientSecretInterval";

/// <p>The six top-level flags.</p>
Parameter FLAGFIELDS = "AllowUnsupportedScope,SupportSession,AudRequired,AllowPublicClientRefresh,ForcePKCEForPublicClients,ForcePKCEForConfidentialClients";

/// <p>The top-level fields that carry text.</p>
Parameter TEXTFIELDS = "IssuerEndpoint,Description,ReturnRefreshToken,CustomizationNamespace,AuthenticateClass,SessionClass,ValidateUserClass,GenerateTokenClass,RevokeTokenClass,ServerCredentials,SigningAlgorithm,EncryptionAlgorithm,KeyAlgorithm,SSLConfiguration,DefaultScope";

/// <p>The refresh token policies the classic page offers, the empty one among them.</p>
Parameter REFRESHPOLICIES = ",a,c,f";

/// <p>The vendor's value lists for the three algorithms (<code>OAuth2.Server.Configuration</code>),
/// the empty one among them.</p>
Parameter SIGNINGALGORITHMS = ",HS256,HS384,HS512,RS256,RS384,RS512,ES256,ES384,ES512,PS256,PS384,PS512";

Parameter ENCRYPTIONALGORITHMS = ",A128CBC-HS256,A192CBC-HS384,A256CBC-HS512";

Parameter KEYALGORITHMS = ",RSA1_5,RSA-OAEP,A128KW,A192KW,A256KW,dir";

/// <p>The vendor's bound on the description, and the largest interval it stores.</p>
Parameter DESCRIPTIONMAXLENGTH As INTEGER = 1024;

Parameter INTERVALMAX As INTEGER = 2147483647;

/// <p>The fields a create must carry, as the form names them.</p>
Parameter REQUIREDFIELDS = "IssuerEndpoint,SupportedScopes,CustomizationRoles,CustomizationNamespace,AuthenticateClass,SessionClass,ValidateUserClass,GenerateTokenClass,RevokeTokenClass";

/// <p>The screens whose declared reads name the roles, SSL/TLS configurations and X.509 credentials
/// the form offers (AD-5), and the field each row names it by.</p>
Parameter ROLESCREEN = "OcuPilot.Screen.Descriptor.RoleList";

Parameter ROLENAMEFIELD = "Name";

Parameter SSLSCREEN = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter SSLNAMEFIELD = "Name";

Parameter CREDENTIALSCREEN = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter CREDENTIALNAMEFIELD = "Alias";

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

/// <p>A new configuration's values, the classic page's (its new-configuration defaults), for every
/// template field a create's arguments leave out. The issuer and the scopes have none.</p>
ClassMethod Defaults() As %DynamicObject
{
    Set tDefaults = {"IssuerEndpoint": "", "Description": "", "AccessTokenInterval": 3600, "AuthorizationCodeInterval": 60, "RefreshTokenInterval": 86400, "SessionInterval": 86400, "ClientSecretInterval": 0, "SupportedScopes": [], "AllowUnsupportedScope": false, "ReturnRefreshToken": "", "SupportSession": true, "AudRequired": false, "AllowPublicClientRefresh": false, "ForcePKCEForPublicClients": false, "ForcePKCEForConfidentialClients": false, "CustomizationRoles": ["%DB_IRISSYS", "%Manager"], "CustomizationNamespace": "%SYS", "AuthenticateClass": "%OAuth2.Server.Authenticate", "SessionClass": "OAuth2.Server.Session", "ValidateUserClass": "%OAuth2.Server.Validate", "GenerateTokenClass": "%OAuth2.Server.Generate", "RevokeTokenClass": "%OAuth2.Server.Revoke", "ServerCredentials": "", "SigningAlgorithm": "RS256", "EncryptionAlgorithm": "", "KeyAlgorithm": "", "SSLConfiguration": "", "DefaultScope": ""}
    Do tDefaults.%Set(..#FIELDMETADATA, {"grant_types_supported": ["authorization_code", "refresh_token"], "frontchannel_logout_supported": true, "frontchannel_logout_session_supported": true, "service_documentation": "", "op_policy_uri": "", "op_tos_uri": ""})
    Quit tDefaults
}

/// <p>Every rule a configuration write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies every rule; <code>update</code> applies a rule
/// only to a field <var>pArgs</var> carries, and reads the others from <var>pFresh</var>. A role, an
/// SSL/TLS configuration or a credential is admitted when <var>pFresh</var> stores it or the
/// caller's read of that list names it. A look-up that fails reads as an empty list, which
/// admits only stored values.</p>
ClassMethod Validate(pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        For tI = 1:1:$Length(..#TEXTFIELDS, ",") {
            Set tField = $Piece(..#TEXTFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") || (tType = "boolean") || (tType = "null") || (tType = "number") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        For tI = 1:1:$Length(..#FLAGFIELDS, ",") {
            Set tField = $Piece(..#FLAGFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType '= "unassigned") && (tType '= "boolean") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHFLAGVALUE)
        }
        If ..Changes(pArgs, ..#FIELDISSUER, tCreates) {
            Set tIssuer = ..Text(pArgs, ..#FIELDISSUER)
            If tIssuer = "" {
                Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHSERVERISSUERREQUIRED)
            } ElseIf '..IssuerShaped(tIssuer) {
                Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHSERVERISSUERSHAPE)
            }
        }
        If $Length(..Text(pArgs, ..#FIELDDESCRIPTION)) > ..#DESCRIPTIONMAXLENGTH Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#OAUTHSERVERDESCRIPTIONLENGTH)
        For tList = ..#INTERVALS, ..#ZEROINTERVALS {
            Set tFloor = $Select(tList = ..#INTERVALS: 1, 1: 0)
            For tI = 1:1:$Length(tList, ",") {
                Set tField = $Piece(tList, ",", tI)
                If pArgs.%GetTypeOf(tField) = "unassigned" Continue
                If '..IntervalShaped(pArgs.%Get(tField), pArgs.%GetTypeOf(tField), tFloor) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHINTERVALVALUE)
            }
        }
        If ..Changes(pArgs, ..#FIELDSCOPES, tCreates) Do ..ScopeViolations(pArgs.%Get(..#FIELDSCOPES), pArgs.%GetTypeOf(..#FIELDSCOPES), .pViolations)
        If ..Text(pArgs, ..#FIELDDEFAULTSCOPE) '= $ZStrip(..Text(pArgs, ..#FIELDDEFAULTSCOPE), "*C") Do ..Add(.pViolations, ..#FIELDDEFAULTSCOPE, ##class(OcuPilot.Api.Error).#OAUTHDEFAULTSCOPESHAPE)
        If (pArgs.%GetTypeOf(..#FIELDREFRESH) = "string") && '$ListFind($ListFromString(..#REFRESHPOLICIES), pArgs.%Get(..#FIELDREFRESH)) Do ..Add(.pViolations, ..#FIELDREFRESH, ##class(OcuPilot.Api.Error).#OAUTHRETURNREFRESHTOKENVALUE)
        Set tMetadataType = pArgs.%GetTypeOf(..#FIELDMETADATA)
        If tMetadataType = "object" {
            Do ..MetadataViolations(pArgs.%Get(..#FIELDMETADATA), .pViolations)
        } ElseIf tMetadataType '= "unassigned" {
            Do ..Add(.pViolations, ..#FIELDMETADATA, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        Do ..AlgorithmViolations(pArgs, pFresh, tCreates, .pViolations)
        Set tSC = ..CustomizationViolations(pArgs, pFresh, tCreates, .pViolations)
        If $$$ISERR(tSC) Quit
        For tPair = $ListBuild(..#FIELDSSL, ..#SSLSCREEN, ..#SSLNAMEFIELD, ##class(OcuPilot.Api.Error).#OAUTHSSLCONFIGURATIONABSENT), $ListBuild(..#FIELDCREDENTIALS, ..#CREDENTIALSCREEN, ..#CREDENTIALNAMEFIELD, ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSABSENT) {
            Set tField = $List(tPair, 1)
            Set tValue = ..Text(pArgs, tField)
            If tValue = "" Continue
            If (tValue = ..Text(pFresh, tField)) || ..Named(..ReadableNames($List(tPair, 2), $List(tPair, 3)), tValue) Continue
            Do ..Add(.pViolations, tField, $List(tPair, 4))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pIssuer</var> is <code>https://host[:port][/prefix]</code> with no query, fragment,
/// user or whitespace, which is the only shape the vendor stores faithfully.</p>
ClassMethod IssuerShaped(pIssuer As %String) As %Boolean
{
    If '$Match(pIssuer, "https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[A-Za-z0-9._~%!$&'()*+,;=:@/-]*)?") Quit 0
    Set tPort = $Piece($Piece($Piece(pIssuer, "://", 2), "/", 1), ":", 2)
    If (tPort '= "") && ((+tPort < 1) || (+tPort > 65535)) Quit 0
    Quit 1
}

/// <p>Whether <var>pValue</var>, of JSON type <var>pType</var>, is a whole number of seconds from
/// <var>pFloor</var> to <parameter>INTERVALMAX</parameter>, as a number or its digits.</p>
ClassMethod IntervalShaped(pValue, pType As %String, pFloor As %Integer) As %Boolean
{
    If pType = "string" {
        If '$Match(pValue, "[0-9]{1,10}") Quit 0
    } ElseIf pType '= "number" {
        Quit 0
    }
    If pValue '= (pValue \ 1) Quit 0
    Quit (pValue >= pFloor) && (pValue <= ..#INTERVALMAX)
}

/// <p>The scope violations of <var>pValue</var>, of JSON type <var>pType</var>: not an array or an
/// empty one; an entry that is not <code>{Scope, Description}</code> with a scope of at least one
/// character and no whitespace or control character; and a scope listed twice.</p>
ClassMethod ScopeViolations(pValue, pType As %String, ByRef pViolations) [ Private ]
{
    If pType '= "array" {
        Do ..Add(.pViolations, ..#FIELDSCOPES, $Select((pType = "unassigned") || (pType = "null"): ##class(OcuPilot.Api.Error).#OAUTHSCOPESREQUIRED, 1: ##class(OcuPilot.Api.Error).#OAUTHSCOPESSHAPE))
        Quit
    }
    If pValue.%Size() = 0 {
        Do ..Add(.pViolations, ..#FIELDSCOPES, ##class(OcuPilot.Api.Error).#OAUTHSCOPESREQUIRED)
        Quit
    }
    Set (tShape, tDuplicate) = 0
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") || (tEntry.%GetTypeOf("Scope") '= "string") {
            Set tShape = 1
            Continue
        }
        Set tDescriptionType = tEntry.%GetTypeOf("Description")
        If (tDescriptionType '= "unassigned") && (tDescriptionType '= "string") Set tShape = 1
        If tEntry.%Size() > (1 + (tDescriptionType '= "unassigned")) Set tShape = 1
        If $ZStrip(tEntry.%Get("Description"), "*C") '= tEntry.%Get("Description") Set tShape = 1
        Set tScope = tEntry.%Get("Scope")
        If (tScope = "") || ($ZStrip(tScope, "*CW") '= tScope) {
            Set tShape = 1
            Continue
        }
        If $Data(tSeen(tScope)) Set tDuplicate = 1
        Set tSeen(tScope) = ""
    }
    If tShape Do ..Add(.pViolations, ..#FIELDSCOPES, ##class(OcuPilot.Api.Error).#OAUTHSCOPESSHAPE)
    If tDuplicate Do ..Add(.pViolations, ..#FIELDSCOPES, ##class(OcuPilot.Api.Error).#OAUTHSCOPESDUPLICATE)
}

/// <p>The metadata violations of <var>pMetadata</var>: a member the editor does not set; a grant type
/// list with none of the editor's choices, or a name outside them and
/// <parameter>REFRESHGRANT</parameter>; a front-channel member that is not a boolean; and a
/// documentation URL that is neither empty nor absolute <code>http(s)</code>. A member left out keeps
/// the stored value, or a create's default. Each field is <code>Metadata.&lt;member&gt;</code>.</p>
ClassMethod MetadataViolations(pMetadata As %DynamicObject, ByRef pViolations) [ Private ]
{
    Set tFlags = $ListFromString(..#METADATAFLAGS)
    Set tUrls = $ListFromString(..#METADATAURLS)
    Set tIterator = pMetadata.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        If (tMember = ..#GRANTTYPES) || $ListFind(tFlags, tMember) || $ListFind(tUrls, tMember) Continue
        Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHSERVERMETADATAMEMBER)
    }
    Set tType = pMetadata.%GetTypeOf(..#GRANTTYPES)
    If tType = "array" {
        Set (tChosen, tOutside) = 0
        Set tChoices = $ListFromString(..#GRANTCHOICES)
        Set tGrants = pMetadata.%Get(..#GRANTTYPES).%GetIterator()
        While tGrants.%GetNext(.tIndex, .tGrant) {
            If $IsObject(tGrant) || (pMetadata.%Get(..#GRANTTYPES).%GetTypeOf(tIndex) '= "string") {
                Set tOutside = 1
                Continue
            }
            If $ListFind(tChoices, tGrant) {
                Set tChosen = 1
            } ElseIf tGrant '= ..#REFRESHGRANT {
                Set tOutside = 1
            }
        }
        If tOutside {
            Do ..Add(.pViolations, ..MetadataField(..#GRANTTYPES), ##class(OcuPilot.Api.Error).#OAUTHGRANTTYPESVALUE)
        } ElseIf 'tChosen {
            Do ..Add(.pViolations, ..MetadataField(..#GRANTTYPES), ##class(OcuPilot.Api.Error).#OAUTHGRANTTYPESREQUIRED)
        }
    } ElseIf tType '= "unassigned" {
        Do ..Add(.pViolations, ..MetadataField(..#GRANTTYPES), ##class(OcuPilot.Api.Error).#OAUTHGRANTTYPESVALUE)
    }
    For tI = 1:1:$ListLength(tFlags) {
        Set tMember = $List(tFlags, tI)
        Set tType = pMetadata.%GetTypeOf(tMember)
        If (tType '= "unassigned") && (tType '= "boolean") Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHFLAGVALUE)
    }
    For tI = 1:1:$ListLength(tUrls) {
        Set tMember = $List(tUrls, tI)
        Set tType = pMetadata.%GetTypeOf(tMember)
        If tType = "unassigned" Continue
        If (tType '= "string") || ((pMetadata.%Get(tMember) '= "") && '..UrlShaped(pMetadata.%Get(tMember))) Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHMETADATAURLSHAPE)
    }
}

/// <p>Whether <var>pUrl</var> is an absolute <code>http</code> or <code>https</code> URL with a host
/// and no whitespace or control character.</p>
ClassMethod UrlShaped(pUrl As %String) As %Boolean
{
    If $ZStrip(pUrl, "*CW") '= pUrl Quit 0
    Quit $Match($ZConvert(pUrl, "L"), "https?://[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]{1,5})?([/?#].*)?")
}

/// <p>The algorithm violations of <var>pArgs</var>: a value off the vendor's list for each of the
/// three, and a key management and content encryption algorithm of which one is set and the other
/// not, read against <var>pFresh</var> for the one the arguments leave out.</p>
ClassMethod AlgorithmViolations(pArgs As %DynamicObject, pFresh As %DynamicObject, pCreates As %Boolean, ByRef pViolations) [ Private ]
{
    For tPair = $ListBuild(..#FIELDSIGNING, ..#SIGNINGALGORITHMS), $ListBuild(..#FIELDENCRYPTION, ..#ENCRYPTIONALGORITHMS), $ListBuild(..#FIELDKEY, ..#KEYALGORITHMS) {
        Set tField = $List(tPair, 1)
        If pArgs.%GetTypeOf(tField) '= "string" Continue
        If '$ListFind($ListFromString($List(tPair, 2)), pArgs.%Get(tField)) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHALGORITHMVALUE)
    }
    If '..Changes(pArgs, ..#FIELDENCRYPTION, pCreates) && '..Changes(pArgs, ..#FIELDKEY, pCreates) Quit
    Set tEncryption = ..Effective(pArgs, pFresh, ..#FIELDENCRYPTION, pCreates)
    Set tKey = ..Effective(pArgs, pFresh, ..#FIELDKEY, pCreates)
    If (tEncryption = "") '= (tKey = "") Do ..Add(.pViolations, ..#FIELDENCRYPTION, ##class(OcuPilot.Api.Error).#OAUTHENCRYPTIONPAIR)
}

/// <p>The customization violations of <var>pArgs</var>: a namespace the caller's namespace list does
/// not name; a class that is empty, or that the effective namespace does not compile; and a role
/// list that is empty, or that names a role neither stored nor readable. A class is checked when
/// it or the namespace changes.</p>
ClassMethod CustomizationViolations(pArgs As %DynamicObject, pFresh As %DynamicObject, pCreates As %Boolean, ByRef pViolations) As %Status [ Private ]
{
    Set tPort = ..#PORT
    Set tMoved = ..Changes(pArgs, ..#FIELDNAMESPACE, pCreates)
    Set tNamespace = ..Effective(pArgs, pFresh, ..#FIELDNAMESPACE, pCreates)
    If tMoved && ((tNamespace = "") || '..NamespaceReadable(tNamespace)) {
        Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONNAMESPACEABSENT)
        Set tNamespace = ""
    }
    Set tClasses = $Parameter(tPort, "CLASSFIELDS")
    For tI = 1:1:$Length(tClasses, ",") {
        Set tField = $Piece(tClasses, ",", tI)
        If 'tMoved && '..Changes(pArgs, tField, pCreates) Continue
        Set tClass = ..Effective(pArgs, pFresh, tField, pCreates)
        If tClass = "" {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONCLASSREQUIRED)
            Continue
        }
        If tNamespace = "" Continue
        If '$ClassMethod(tPort, "ClassUsable", tNamespace, tClass) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONCLASSABSENT)
    }
    If '..Changes(pArgs, ..#FIELDROLES, pCreates) Quit $$$OK
    Set tType = pArgs.%GetTypeOf(..#FIELDROLES)
    If (tType '= "array") || (pArgs.%Get(..#FIELDROLES).%Size() = 0) {
        Do ..Add(.pViolations, ..#FIELDROLES, $Select((tType = "array") || (tType = "unassigned") || (tType = "null"): ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONROLESREQUIRED, 1: ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE))
        Quit $$$OK
    }
    Set tStored = ..StoredRoles(pFresh)
    Set tReadable = ""
    Set tAbsent = 0
    Set tIterator = pArgs.%Get(..#FIELDROLES).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        If $IsObject(tRole) || (pArgs.%Get(..#FIELDROLES).%GetTypeOf(tIndex) '= "string") || (tRole = "") {
            Set tAbsent = 1
            Quit
        }
        If $ListFind(tStored, $ZConvert(tRole, "U")) Continue
        If tReadable = "" Set tReadable = ..ReadableNames(..#ROLESCREEN, ..#ROLENAMEFIELD)
        If '..Named(tReadable, tRole, 1) Set tAbsent = 1 Quit
    }
    If tAbsent Do ..Add(.pViolations, ..#FIELDROLES, ##class(OcuPilot.Api.Error).#OAUTHCUSTOMIZATIONROLESABSENT)
    Quit $$$OK
}

/// <p><var>pFresh</var>'s customization roles, upper-cased, as a <class>%List</class>.</p>
ClassMethod StoredRoles(pFresh As %DynamicObject) As %List
{
    Set tRoles = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#FIELDROLES) '= "array") Quit tRoles
    Set tIterator = pFresh.%Get(..#FIELDROLES).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        If '$IsObject(tRole) && (tRole '= "") Set tRoles = tRoles _ $ListBuild($ZConvert(tRole, "U"))
    }
    Quit tRoles
}

/// <p>Make <var>pPayload</var> the body the vendor's <code>PUT</code> takes: its derived template
/// fields and nothing else (AD-3), with <parameter>REFRESHGRANT</parameter> among the grant types it
/// names, as the vendor's own setter adds it.</p>
ClassMethod Expand(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    If $$$ISERR(..TemplateFields(.tKeep)) Quit
    Set tDrop = ""
    Set tIterator = pPayload.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeep, tKey) Set tDrop = tDrop _ $ListBuild(tKey)
    }
    For tI = 1:1:$ListLength(tDrop) Do pPayload.%Remove($List(tDrop, tI))
    If pPayload.%GetTypeOf(..#FIELDMETADATA) = "object" Do ..WithRefreshGrant(pPayload.%Get(..#FIELDMETADATA))
}

/// <p>Add <parameter>REFRESHGRANT</parameter> to the grant types <var>pMetadata</var> names, when it
/// names a list without it, as the vendor's own setter does. The merge and the composition call it
/// too, so the card shows the grant types the write sends.</p>
ClassMethod WithRefreshGrant(pMetadata As %DynamicObject)
{
    If '$IsObject(pMetadata) || (pMetadata.%GetTypeOf(..#GRANTTYPES) '= "array") Quit
    Set tGrants = pMetadata.%Get(..#GRANTTYPES)
    Set tIterator = tGrants.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGrant) {
        If tGrant = ..#REFRESHGRANT Quit
    }
    If $Get(tGrant) '= ..#REFRESHGRANT Do tGrants.%Push(..#REFRESHGRANT)
}

/// <p><var>pFresh</var>'s <code>Metadata</code> with every member <var>pMembers</var> carries set
/// over it, as a new object; <var>pMembers</var> alone when <var>pFresh</var> holds no metadata.</p>
ClassMethod MergedMetadata(pFresh As %DynamicObject, pMembers As %DynamicObject) As %DynamicObject
{
    Set tMerged = {}
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#FIELDMETADATA) = "object") Set tMerged = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%Get(..#FIELDMETADATA).%ToJSON())
    If '$IsObject(pMembers) Quit tMerged
    Set tIterator = pMembers.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tType = pMembers.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tMerged.%Set(tKey, ##class(%DynamicAbstractObject).%FromJSON(tValue.%ToJSON()))
        } ElseIf tType = "null" {
            Do tMerged.%Set(tKey, "", "null")
        } Else {
            Do tMerged.%Set(tKey, tValue, tType)
        }
    }
    Quit tMerged
}

/// <p><var>pScopes</var> with each entry written <code>{Description, Scope}</code>, the vendor's own
/// order, so a list the caller restates compares equal to the stored one; any other entry is kept as
/// it is, for the rules to refuse.</p>
ClassMethod OrderedScopes(pScopes As %DynamicArray) As %DynamicArray
{
    Set tOrdered = []
    Set tIterator = pScopes.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") || (tEntry.%Size() > 2) || (tEntry.%GetTypeOf("Scope") '= "string") || '$ListFind($ListBuild("string", "unassigned"), tEntry.%GetTypeOf("Description")) {
            Do tOrdered.%Push(tEntry)
            Continue
        }
        Set tCopy = {}
        Do tCopy.%Set("Description", tEntry.%Get("Description"), "string")
        Do tCopy.%Set("Scope", tEntry.%Get("Scope"), "string")
        Do tOrdered.%Push(tCopy)
    }
    Quit tOrdered
}

/// <p>A list <var>pValue</var> as card text: the scopes' names, each followed by its description in
/// parentheses when <var>pDescribed</var> is 1, or the entries themselves, comma-separated.</p>
ClassMethod ListText(pValue, pDescribed As %Boolean = 0) As %String
{
    If '$IsObject(pValue) Quit ""
    Set tText = ""
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tName = $Select($IsObject(tEntry): tEntry.%Get("Scope") _ $Select(pDescribed: " (" _ tEntry.%Get("Description") _ ")", 1: ""), 1: tEntry)
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tName
    }
    Quit tText
}

/// <p>The card's rows for a change from <var>pFresh</var> to <var>pPayload</var>: <var>pDiff</var>'s
/// rows with <code>SupportedScopes</code> and <code>CustomizationRoles</code> drawn as names and
/// <code>Metadata</code> drawn as one row per member it changes; a scope list whose names are
/// unchanged is drawn with its descriptions. Nothing is added or removed but the metadata row.</p>
ClassMethod CardRows(pFresh As %DynamicObject, pPayload As %DynamicObject, pDiff As %DynamicArray) As %DynamicArray
{
    Set tRows = []
    Set tIterator = pDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tField = tRow.%Get("field")
        If (tField = ..#FIELDSCOPES) || (tField = ..#FIELDROLES) {
            Set tOld = $Select($IsObject(pFresh): pFresh.%Get(tField), 1: "")
            Set tBefore = ..ListText(tOld)
            Set tAfter = ..ListText(pPayload.%Get(tField))
            ; A change to a scope's description alone reads the same by name, so draw the descriptions.
            If tBefore = tAfter {
                Set tBefore = ..ListText(tOld, 1)
                Set tAfter = ..ListText(pPayload.%Get(tField), 1)
            }
            Do tRow.%Set("before", tBefore, "string")
            Do tRow.%Set("after", tAfter, "string")
            Do tRows.%Push(tRow)
            Continue
        }
        If tField '= ..#FIELDMETADATA {
            Do tRows.%Push(tRow)
            Continue
        }
        Set tBefore = $Select($IsObject(pFresh) && (pFresh.%GetTypeOf(..#FIELDMETADATA) = "object"): pFresh.%Get(..#FIELDMETADATA), 1: {})
        Set tAfter = pPayload.%Get(..#FIELDMETADATA)
        If '$IsObject(tAfter) Continue
        Set tMembers = tAfter.%GetIterator()
        While tMembers.%GetNext(.tMember, .tValue) {
            Set tOld = ..MemberText(tBefore, tMember)
            Set tNew = ..MemberText(tAfter, tMember)
            If tOld = tNew Continue
            Set tMemberRow = {}
            Do tMemberRow.%Set("field", ..MetadataField(tMember), "string")
            Do tMemberRow.%Set("before", tOld, "string")
            Do tMemberRow.%Set("after", tNew, "string")
            Do tRows.%Push(tMemberRow)
        }
    }
    Quit tRows
}

/// <p>Metadata member <var>pMember</var> of <var>pObject</var> as card text: a list as its names, a
/// flag as <code>true</code> or <code>false</code>.</p>
ClassMethod MemberText(pObject As %DynamicObject, pMember As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pMember)
    If tType = "array" Quit ..ListText(pObject.%Get(pMember))
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pMember), tType)
}

/// <p>The card row naming the clients registered with the server <var>pRead</var> describes -- every
/// <code>Name (ClientId)</code>, before and, with <var>pRemoved</var> 0, after -- or <code>""</code>
/// when the list is hidden or empty.</p>
ClassMethod ClientsRow(pRead As %DynamicObject, pRemoved As %Boolean = 0) As %DynamicObject
{
    If '$IsObject(pRead) Quit ""
    If pRead.%Get($Parameter(..#PORT, "HIDDENFIELD")) Quit ""
    Set tClients = pRead.%Get($Parameter(..#PORT, "CLIENTSFIELD"))
    If '$IsObject(tClients) || (tClients.%Size() = 0) Quit ""
    Set tText = ""
    Set tIterator = tClients.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tClient) {
        If '$IsObject(tClient) Continue
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tClient.%Get("Name") _ " (" _ tClient.%Get("ClientId") _ ")"
    }
    Set tRow = {}
    Do tRow.%Set("field", $Parameter(..#PORT, "CLIENTSFIELD"), "string")
    Do tRow.%Set("before", tText, "string")
    Do tRow.%Set("after", $Select(pRemoved: "", 1: tText), "string")
    If pRemoved Do tRow.%Set("removed", 1, "boolean")
    Quit tRow
}

/// <p>The field a metadata member's refusal names.</p>
ClassMethod MetadataField(pMember As %String) As %String
{
    Quit ..#FIELDMETADATA _ "." _ pMember
}

/// <p>Whether <var>pNamespace</var> is one the caller's namespace list names, compared without regard
/// to case.</p>
ClassMethod NamespaceReadable(pNamespace As %String) As %Boolean
{
    Quit ..Named(..Namespaces(), pNamespace, 1)
}

/// <p>The namespaces the shell's <code>/namespaces</code> answers the caller.</p>
ClassMethod Namespaces() As %DynamicArray
{
    Quit ##class(OcuPilot.Area.Security.OAuthResourceServerRules).Namespaces()
}

/// <p>The names screen <var>pScreen</var>'s own declared read answers the caller in
/// <var>pField</var> (AD-5), or <code>[]</code>.</p>
ClassMethod ReadableNames(pScreen As %String, pField As %String) As %DynamicArray
{
    Quit ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(pScreen, pField)
}

/// <p>Whether <var>pNames</var> holds <var>pName</var>, exactly or, with <var>pFoldCase</var>,
/// without regard to case.</p>
ClassMethod Named(pNames As %DynamicArray, pName As %String, pFoldCase As %Boolean = 0) As %Boolean
{
    If '$IsObject(pNames) Quit 0
    Set tWanted = $Select(pFoldCase: $ZConvert(pName, "U"), 1: pName)
    Set tFound = 0
    Set tIterator = pNames.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If $Select(pFoldCase: $ZConvert(tName, "U"), 1: tName) = tWanted Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Answer <code>GET /oauth/authorization-server/form</code>: what the form needs before it can
/// draw a field (AD-39): <code>{requiredFields, rules, namespaces, roles, sslConfigurations,
/// credentials, clients, clientsHidden}</code>, and <code>definition</code>, the configuration as
/// the edit tool's own read answers it, when the instance has one. The four name lists are what the
/// caller reads through the shell's and the three list screens' own reads (AD-5).</p>
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
        Do tBody.%Set("namespaces", ..Namespaces())
        Do tBody.%Set("roles", ..ReadableNames(..#ROLESCREEN, ..#ROLENAMEFIELD))
        Do tBody.%Set("sslConfigurations", ..ReadableNames(..#SSLSCREEN, ..#SSLNAMEFIELD))
        Do tBody.%Set("credentials", ..ReadableNames(..#CREDENTIALSCREEN, ..#CREDENTIALNAMEFIELD))
        Set tReadSC = ..Present(.tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) && (+$Get(tHttp) '= 404) {
            Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
            Quit
        }
        Set tClients = []
        Set tHidden = 0
        If $$$ISOK(tReadSC) {
            Set tClients = tFresh.%Get($Parameter(..#PORT, "CLIENTSFIELD"))
            Set tHidden = ''tFresh.%Get($Parameter(..#PORT, "HIDDENFIELD"))
            Set tDefinition = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
            For tI = 1:1:$Length($Parameter(..#PORT, "ROWFIELDS"), ",") Do tDefinition.%Remove($Piece($Parameter(..#PORT, "ROWFIELDS"), ",", tI))
            Do tBody.%Set("definition", tDefinition)
        }
        Do tBody.%Set("clients", $Select($IsObject(tClients): tClients, 1: []))
        Do tBody.%Set("clientsHidden", tHidden, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The configuration, read through the edit tool's own port and read type (AD-52), in
/// <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Present(Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.OAUTHSERVERCONFIGABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCONFIGABSENT, ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGABSENT)
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
    Set tCodes = ##class(OcuPilot.Api.Error).OAuthAuthorizationServerViolationCodes()
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

/// <p>The form field an <code>OAUTH.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses; a code several
/// fields share names the first of them.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If (tPart = "SERVERISSUER") || (tPart = "SERVERCONFIG") Quit ..#FIELDISSUER
    If tPart = "INTERVAL" Quit $Piece(..#INTERVALS, ",", 1)
    If tPart = "SCOPES" Quit ..#FIELDSCOPES
    If tPart = "DEFAULTSCOPE" Quit ..#FIELDDEFAULTSCOPE
    If tPart = "SERVERDESCRIPTION" Quit ..#FIELDDESCRIPTION
    If tPart = "RETURNREFRESHTOKEN" Quit ..#FIELDREFRESH
    If tPart = "GRANTTYPES" Quit ..MetadataField(..#GRANTTYPES)
    If tPart = "SERVERMETADATA" Quit ..#FIELDMETADATA
    If tPart = "METADATAURL" Quit ..MetadataField($Piece(..#METADATAURLS, ",", 1))
    If tPart = "FLAG" Quit $Piece(..#FLAGFIELDS, ",", 1)
    If tPart = "ALGORITHM" Quit ..#FIELDSIGNING
    If tPart = "ENCRYPTION" Quit ..#FIELDENCRYPTION
    If tPart = "CUSTOMIZATIONNAMESPACE" Quit ..#FIELDNAMESPACE
    If tPart = "CUSTOMIZATIONCLASS" Quit $Piece($Parameter(..#PORT, "CLASSFIELDS"), ",", 1)
    If tPart = "CUSTOMIZATIONROLES" Quit ..#FIELDROLES
    If tPart = "SSLCONFIGURATION" Quit ..#FIELDSSL
    Quit ..#FIELDCREDENTIALS
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
/// <var>pFresh</var>'s on an edit and <method>Defaults</method>' on a create.</p>
ClassMethod Effective(pArgs As %DynamicObject, pFresh As %DynamicObject, pField As %String, pCreates As %Boolean) As %String [ Private ]
{
    If pArgs.%GetTypeOf(pField) '= "unassigned" Quit ..Text(pArgs, pField)
    If pCreates Quit ..Text(..Defaults(), pField)
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
