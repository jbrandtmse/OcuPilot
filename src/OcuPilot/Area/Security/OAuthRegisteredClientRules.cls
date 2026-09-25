/// <p>The OAuth 2.0 server client description editor's rules (AD-39, AD-55): the one rule set every
/// caller of <class>OcuPilot.Screen.Tool.OAuthRegisteredClientCreate</class> and
/// <class>OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate</class> applies (<method>Validate</method>),
/// the complete set a body is made (<method>Defaults</method>, <method>MergedMetadata</method>,
/// <method>Expand</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so a field
/// refusal on the screen and the agent's argument refusal are one wording. The rules cover what the
/// vendor refuses with a 500 and what the classic page refuses: for every client type but a resource
/// server, at least one absolute redirect URL, one grant type and one response type, and the display
/// URLs on the host of a redirect URL.</p>
Class OcuPilot.Area.Security.OAuthRegisteredClientRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientForm";

/// <p>The port the fresh reads go through, and whose secret members the rules refuse.</p>
Parameter PORT = "OcuPilot.Port.OAuthRegisteredClientPort";

/// <p>The generated field lists, the derived template list, and the derived list of the vendor's
/// client metadata class, whose value lists the algorithm rules read (AD-3).</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter TEMPLATELIST = "Security.OAuth2.ServerClients";

Parameter MEMBERSLIST = "Security.OAuth2.Client.ClientConfiguration:OAuth2.Client.Metadata";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDREDIRECT = "RedirectURL";

Parameter FIELDLAUNCH = "LaunchURL";

Parameter FIELDTYPE = "ClientType";

Parameter FIELDCREDENTIALS = "ClientCredentials";

Parameter FIELDSCOPE = "DefaultScope";

Parameter FIELDMETADATA = "Metadata";

Parameter FIELDSECRET = "ClientSecret";

/// <p>The top-level fields that carry text.</p>
Parameter TEXTFIELDS = "Name,LaunchURL,Description,ClientType,ClientCredentials,DefaultScope";

/// <p>The client types the vendor stores, the one with no redirect URL, and the one with no
/// secret.</p>
Parameter CLIENTTYPES = "confidential,public,resource";

Parameter RESOURCETYPE = "resource";

Parameter PUBLICTYPE = "public";

/// <p>The grant types the classic page offers, and the one the vendor's own setter always adds.</p>
Parameter GRANTMEMBER = "grant_types";

Parameter GRANTCHOICES = "authorization_code,implicit,password,client_credentials,jwt_authorization";

Parameter REFRESHGRANT = "refresh_token";

/// <p>The response types the classic page offers.</p>
Parameter RESPONSEMEMBER = "response_types";

Parameter RESPONSECHOICES = "code,id_token,id_token token,token";

/// <p>The authentication types the classic page offers.</p>
Parameter AUTHMEMBER = "token_endpoint_auth_method";

Parameter AUTHMETHODS = "none,client_secret_basic,client_secret_post,client_secret_jwt,private_key_jwt";

/// <p>The display URLs the vendor holds to a redirect URL's scheme and host, and the key set's
/// URL, which it does not.</p>
Parameter HOSTMEMBERS = "logo_uri,client_uri,policy_uri,tos_uri,frontchannel_logout_uri";

Parameter JWKSMEMBER = "jwks_uri";

/// <p>The remaining members the editor sets.</p>
Parameter CONTACTSMEMBER = "contacts";

Parameter MAXAGEMEMBER = "default_max_age";

Parameter NAMEMEMBER = "client_name";

Parameter SESSIONMEMBER = "frontchannel_logout_session_required";

/// <p>The algorithm members each drawn from the vendor's value list, and the encryption pairs, each
/// <code>content:key</code>, set together or not at all.</p>
Parameter ALGORITHMMEMBERS = "token_endpoint_auth_signing_alg,id_token_signed_response_alg,id_token_encrypted_response_enc,id_token_encrypted_response_alg,userinfo_signed_response_alg,userinfo_encrypted_response_enc,userinfo_encrypted_response_alg,access_token_signed_response_alg,access_token_encrypted_response_enc,access_token_encrypted_response_alg,request_object_signing_alg,request_object_encryption_enc,request_object_encryption_alg";

Parameter ENCRYPTIONPAIRS = "id_token_encrypted_response_enc:id_token_encrypted_response_alg,userinfo_encrypted_response_enc:userinfo_encrypted_response_alg,access_token_encrypted_response_enc:access_token_encrypted_response_alg,request_object_encryption_enc:request_object_encryption_alg";

/// <p>The value the vendor's lists spell an unset algorithm with.</p>
Parameter NOALGORITHM = "none";

/// <p>The fields the form draws as required; a redirect URL, a grant type and a response type only
/// for a client that is not a resource server, and a secret only on a create that is not a public
/// client.</p>
Parameter REQUIREDFIELDS = "Name,ClientType,RedirectURL,Metadata.grant_types,Metadata.response_types,ClientSecret";

/// <p>The screen whose declared read names the X.509 credentials the form offers (AD-5), and the
/// field each row names one by.</p>
Parameter CREDENTIALSCREEN = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter CREDENTIALNAMEFIELD = "Alias";

/// <p>The body's top-level fields, in the derived template list's order (AD-3).</p>
ClassMethod TemplateFields(Output pFields As %List) As %Status
{
    Set pFields = ""
    Set tSC = ..ListRows(..#TEMPLATELIST, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tPath = tRow.%Get("path")
        If (tPath = "") || (tPath [ ".") || (tPath [ "[") Continue
        Set pFields = pFields _ $ListBuild(tPath)
    }
    If pFields = "" Quit $$$ERROR($$$GeneralError, ..#TEMPLATELIST _ " has no rows")
    Quit $$$OK
}

/// <p>Member <var>pMember</var>'s value list from the vendor's client metadata class, as a
/// <class>%List</class>, or <code>""</code> when it declares none or the list cannot be read.</p>
ClassMethod MemberValues(pMember As %String) As %List
{
    Set tValues = ""
    If $$$ISERR(..ListRows(..#MEMBERSLIST, .tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("path") '= pMember) Continue
        If tRow.%GetTypeOf("values") '= "array" Quit
        Set tValueIterator = tRow.%Get("values").%GetIterator()
        While tValueIterator.%GetNext(.tValueIndex, .tValue) { Set tValues = tValues _ $ListBuild(tValue) }
        Quit
    }
    Quit tValues
}

/// <p>The rows of generated field list <var>pKey</var>.</p>
ClassMethod ListRows(pKey As %String, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set pRows = ""
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
        If $IsObject(tLists) Set tList = tLists.%Get(pKey)
        If '$IsObject(tList) || (tList.%GetTypeOf("rows") '= "array") {
            Set tSC = $$$ERROR($$$GeneralError, pKey _ " has no list in " _ ..#FIELDLISTSCLASS)
            Quit
        }
        Set pRows = tList.%Get("rows")
    } Catch ex {
        Set pRows = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A new client's values, the classic page's own for a new client description, for every template
/// field a create's arguments leave out. The name and the redirect URLs have none.</p>
ClassMethod Defaults() As %DynamicObject
{
    Set tDefaults = {"Name": "", "RedirectURL": [], "LaunchURL": "", "Description": "", "ClientType": "confidential", "ClientCredentials": "", "DefaultScope": ""}
    Set tMetadata = {"grant_types": ["authorization_code", "refresh_token"], "response_types": ["code", "id_token", "id_token token", "token"], "token_endpoint_auth_method": "client_secret_basic", "token_endpoint_auth_signing_alg": "", "client_name": "", "logo_uri": "", "client_uri": "", "policy_uri": "", "tos_uri": "", "contacts": [], "default_max_age": "", "frontchannel_logout_uri": "", "jwks_uri": ""}
    Do tMetadata.%Set(..#SESSIONMEMBER, 0, "boolean")
    Do tMetadata.%Set("id_token_signed_response_alg", "RS256", "string")
    For tMember = "id_token_encrypted_response_enc", "id_token_encrypted_response_alg", "userinfo_signed_response_alg", "userinfo_encrypted_response_enc", "userinfo_encrypted_response_alg", "access_token_signed_response_alg", "access_token_encrypted_response_enc", "access_token_encrypted_response_alg", "request_object_signing_alg", "request_object_encryption_enc", "request_object_encryption_alg" {
        Do tMetadata.%Set(tMember, ..#NOALGORITHM, "string")
    }
    Do tDefaults.%Set(..#FIELDMETADATA, tMetadata)
    Quit tDefaults
}

/// <p>Every rule a client write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies every rule over <method>Defaults</method> with the
/// arguments set over them; <code>update</code> applies a rule to a field <var>pArgs</var> carries, and
/// to the fields a changed client type or redirect URL list governs, reading the rest from
/// <var>pFresh</var>. A credential is admitted when <var>pFresh</var> stores it or the caller's read
/// of the X.509 list names it. A name already registered is not this method's: it is
/// <method>NameTaken</method>'s.</p>
ClassMethod Validate(pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        Set tBase = $Select(tCreates: ..Defaults(), 1: pFresh)
        For tI = 1:1:$Length(..#TEXTFIELDS, ",") {
            Set tField = $Piece(..#TEXTFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") || (tType = "boolean") || (tType = "null") || (tType = "number") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        If ..Changes(pArgs, ..#FIELDNAME, tCreates) && (..Text(pArgs, ..#FIELDNAME) = "") Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTNAMEREQUIRED)
        Set tClientType = ..Effective(pArgs, tBase, ..#FIELDTYPE)
        Set tTypeChanged = ..Changes(pArgs, ..#FIELDTYPE, tCreates)
        If tTypeChanged && '$ListFind($ListFromString(..#CLIENTTYPES), tClientType) Do ..Add(.pViolations, ..#FIELDTYPE, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTTYPEVALUE)
        Set tResource = (tClientType = ..#RESOURCETYPE)

        ; The redirect URLs the client will hold, and the scheme and host of each.
        Set tRedirectChanged = ..Changes(pArgs, ..#FIELDREDIRECT, tCreates)
        Set tRedirects = ""
        If pArgs.%GetTypeOf(..#FIELDREDIRECT) '= "unassigned" {
            If '..StringList(pArgs.%Get(..#FIELDREDIRECT), pArgs.%GetTypeOf(..#FIELDREDIRECT), .tRedirects) Do ..Add(.pViolations, ..#FIELDREDIRECT, ##class(OcuPilot.Api.Error).#OAUTHREDIRECTURLSHAPE)
        } ElseIf $IsObject(tBase) {
            Do ..StringList(tBase.%Get(..#FIELDREDIRECT), tBase.%GetTypeOf(..#FIELDREDIRECT), .tRedirects)
        }
        If (tRedirectChanged || tTypeChanged) && 'tResource && ($ListLength(tRedirects) = 0) && '..Named(.pViolations, ..#FIELDREDIRECT) Do ..Add(.pViolations, ..#FIELDREDIRECT, ##class(OcuPilot.Api.Error).#OAUTHREDIRECTURLREQUIRED)
        Kill tBases
        Set tBadRedirect = 0
        For tI = 1:1:$ListLength(tRedirects) {
            Set tUrl = $List(tRedirects, tI)
            If '..RedirectShaped(tUrl) {
                Set tBadRedirect = 1
                Continue
            }
            Set tBases(..Origin(tUrl)) = ""
        }
        If tBadRedirect && tRedirectChanged && '..Named(.pViolations, ..#FIELDREDIRECT) Do ..Add(.pViolations, ..#FIELDREDIRECT, ##class(OcuPilot.Api.Error).#OAUTHREDIRECTURLSHAPE)

        Set tLaunch = ..Text(pArgs, ..#FIELDLAUNCH)
        If (tLaunch '= "") && '..RedirectShaped(tLaunch) Do ..Add(.pViolations, ..#FIELDLAUNCH, ##class(OcuPilot.Api.Error).#OAUTHLAUNCHURLSHAPE)
        Set tScope = ..Text(pArgs, ..#FIELDSCOPE)
        If tScope '= $ZStrip(tScope, "*C") Do ..Add(.pViolations, ..#FIELDSCOPE, ##class(OcuPilot.Api.Error).#OAUTHDEFAULTSCOPESHAPE)

        Set tMetadataType = pArgs.%GetTypeOf(..#FIELDMETADATA)
        If (tMetadataType '= "unassigned") && (tMetadataType '= "object") {
            Do ..Add(.pViolations, ..#FIELDMETADATA, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Set tMembers = {}
        } Else {
            Set tMembers = $Select(tMetadataType = "object": pArgs.%Get(..#FIELDMETADATA), 1: {})
        }
        Set tMetadata = ..MergedMetadata(tBase, tMembers)
        Do ..MetadataViolations(tMembers, tMetadata, tCreates, 'tResource, tTypeChanged, tRedirectChanged, .tBases, .pViolations)

        Set tCredentials = ..Text(pArgs, ..#FIELDCREDENTIALS)
        If (tCredentials '= "") && (tCredentials '= ..Text(pFresh, ..#FIELDCREDENTIALS)) && '..Named(..ReadableNames(), tCredentials) {
            Do ..Add(.pViolations, ..#FIELDCREDENTIALS, ##class(OcuPilot.Api.Error).#OAUTHCLIENTCREDENTIALSABSENT)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The member violations: <var>pMembers</var> is what the arguments carry and <var>pMetadata</var>
/// the metadata the client will hold. A member the arguments carry is held to its shape and list; the
/// grant and response types are required for a client that is not a resource server
/// (<var>pRedirected</var>) whenever they, or the client type, change; and the display URLs are held
/// to the redirect URLs' schemes and hosts <var>pBases</var> whenever they or the redirect URLs
/// change. Each field is <code>Metadata.&lt;member&gt;</code>.</p>
ClassMethod MetadataViolations(pMembers As %DynamicObject, pMetadata As %DynamicObject, pCreates As %Boolean, pRedirected As %Boolean, pTypeChanged As %Boolean, pRedirectChanged As %Boolean, ByRef pBases, ByRef pViolations) [ Private ]
{
    Set tSecrets = $ListFromString($Parameter(..#PORT, "SECRETMEMBERS"))
    For tI = 1:1:$ListLength(tSecrets) {
        If pMembers.%GetTypeOf($List(tSecrets, tI)) '= "unassigned" Do ..Add(.pViolations, ..MetadataField($List(tSecrets, tI)), ##class(OcuPilot.Api.Error).#OAUTHMETADATAUNKNOWN)
    }
    For tList = $ListBuild(..#GRANTMEMBER, ..#GRANTCHOICES, ##class(OcuPilot.Api.Error).#OAUTHCLIENTGRANTTYPESVALUE, ##class(OcuPilot.Api.Error).#OAUTHCLIENTGRANTTYPESREQUIRED), $ListBuild(..#RESPONSEMEMBER, ..#RESPONSECHOICES, ##class(OcuPilot.Api.Error).#OAUTHRESPONSETYPESVALUE, ##class(OcuPilot.Api.Error).#OAUTHRESPONSETYPESREQUIRED) {
        Set tMember = $List(tList, 1)
        Set tCarried = (pMembers.%GetTypeOf(tMember) '= "unassigned")
        If '(tCarried || pCreates || pTypeChanged) Continue
        Set tChoices = $ListFromString($List(tList, 2))
        If '..StringList(pMetadata.%Get(tMember), pMetadata.%GetTypeOf(tMember), .tValues) {
            Do ..Add(.pViolations, ..MetadataField(tMember), $List(tList, 3))
            Continue
        }
        Set (tChosen, tOutside) = 0
        For tJ = 1:1:$ListLength(tValues) {
            Set tValue = $List(tValues, tJ)
            If $ListFind(tChoices, tValue) {
                Set tChosen = 1
            } ElseIf '((tMember = ..#GRANTMEMBER) && (tValue = ..#REFRESHGRANT)) {
                Set tOutside = 1
            }
        }
        If tOutside && tCarried {
            Do ..Add(.pViolations, ..MetadataField(tMember), $List(tList, 3))
        } ElseIf 'tChosen && pRedirected {
            Do ..Add(.pViolations, ..MetadataField(tMember), $List(tList, 4))
        }
    }
    If pMembers.%GetTypeOf(..#AUTHMEMBER) '= "unassigned" {
        Set tMethod = ..Text(pMembers, ..#AUTHMEMBER)
        If (pMembers.%GetTypeOf(..#AUTHMEMBER) '= "string") || ((tMethod '= "") && '$ListFind($ListFromString(..#AUTHMETHODS), tMethod)) Do ..Add(.pViolations, ..MetadataField(..#AUTHMEMBER), ##class(OcuPilot.Api.Error).#OAUTHAUTHMETHODVALUE)
    }
    For tI = 1:1:$Length(..#ALGORITHMMEMBERS, ",") {
        Set tMember = $Piece(..#ALGORITHMMEMBERS, ",", tI)
        Set tType = pMembers.%GetTypeOf(tMember)
        If tType = "unassigned" Continue
        Set tValue = ..Text(pMembers, tMember)
        If (tType '= "string") || ((tValue '= "") && '$ListFind(..MemberValues(tMember), tValue)) Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHALGORITHMVALUE)
    }
    For tI = 1:1:$Length(..#ENCRYPTIONPAIRS, ",") {
        Set tContent = $Piece($Piece(..#ENCRYPTIONPAIRS, ",", tI), ":", 1)
        Set tKey = $Piece($Piece(..#ENCRYPTIONPAIRS, ",", tI), ":", 2)
        If '(pCreates || (pMembers.%GetTypeOf(tContent) '= "unassigned") || (pMembers.%GetTypeOf(tKey) '= "unassigned")) Continue
        Set tContentSet = '$ListFind($ListBuild("", ..#NOALGORITHM), ..Text(pMetadata, tContent))
        Set tKeySet = '$ListFind($ListBuild("", ..#NOALGORITHM), ..Text(pMetadata, tKey))
        If tContentSet '= tKeySet Do ..Add(.pViolations, ..MetadataField(tContent), ##class(OcuPilot.Api.Error).#OAUTHENCRYPTIONPAIR)
    }
    For tI = 1:1:($Length(..#HOSTMEMBERS, ",") + 1) {
        Set tMember = $Select(tI > $Length(..#HOSTMEMBERS, ","): ..#JWKSMEMBER, 1: $Piece(..#HOSTMEMBERS, ",", tI))
        Set tType = pMembers.%GetTypeOf(tMember)
        Set tCarried = (tType '= "unassigned")
        If tCarried && ((tType '= "string") || ((pMembers.%Get(tMember) '= "") && '..UrlShaped(pMembers.%Get(tMember)))) {
            Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHMETADATAURLSHAPE)
            Continue
        }
        If tMember = ..#JWKSMEMBER Continue
        If 'pRedirected || '(tCarried || pRedirectChanged || pTypeChanged) Continue
        Set tUrl = ..Text(pMetadata, tMember)
        If (tUrl = "") || '$Data(pBases) Continue
        If '$Data(pBases(..Origin(tUrl))) Do ..Add(.pViolations, ..MetadataField(tMember), ##class(OcuPilot.Api.Error).#OAUTHCLIENTURLHOST)
    }
    If pMembers.%GetTypeOf(..#CONTACTSMEMBER) '= "unassigned" {
        Set tShaped = ..StringList(pMembers.%Get(..#CONTACTSMEMBER), pMembers.%GetTypeOf(..#CONTACTSMEMBER), .tContacts)
        For tJ = 1:1:$ListLength(tContacts) {
            If '$Match($List(tContacts, tJ), "[^@\s,]+@[^@\s,.]+(\.[^@\s,.]+)+") Set tShaped = 0
        }
        If 'tShaped Do ..Add(.pViolations, ..MetadataField(..#CONTACTSMEMBER), ##class(OcuPilot.Api.Error).#OAUTHCONTACTSSHAPE)
    }
    Set tType = pMembers.%GetTypeOf(..#MAXAGEMEMBER)
    If tType '= "unassigned" {
        Set tValue = pMembers.%Get(..#MAXAGEMEMBER)
        Set tShaped = ((tType = "string") && $Match(tValue, "|[0-9]{1,9}")) || ((tType = "number") && (tValue = (tValue \ 1)) && (tValue >= 0) && (tValue < 1000000000))
        If 'tShaped Do ..Add(.pViolations, ..MetadataField(..#MAXAGEMEMBER), ##class(OcuPilot.Api.Error).#OAUTHMAXAGEVALUE)
    }
    Set tType = pMembers.%GetTypeOf(..#SESSIONMEMBER)
    If (tType '= "unassigned") && (tType '= "boolean") && '((tType = "string") && (pMembers.%Get(..#SESSIONMEMBER) = "")) Do ..Add(.pViolations, ..MetadataField(..#SESSIONMEMBER), ##class(OcuPilot.Api.Error).#OAUTHFLAGVALUE)
    Set tType = pMembers.%GetTypeOf(..#NAMEMEMBER)
    If (tType '= "unassigned") && (tType '= "string") Do ..Add(.pViolations, ..MetadataField(..#NAMEMEMBER), ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
}

/// <p>Whether <var>pValue</var>, of JSON type <var>pType</var>, is an array of strings, with them in
/// <var>pList</var> as a <class>%List</class>; an absent or null value is an empty list.</p>
ClassMethod StringList(pValue, pType As %String, Output pList As %List) As %Boolean
{
    Set pList = ""
    If (pType = "unassigned") || (pType = "null") Quit 1
    If pType '= "array" Quit 0
    Set tShaped = 1
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If pValue.%GetTypeOf(tIndex) '= "string" {
            Set tShaped = 0
            Continue
        }
        Set pList = pList _ $ListBuild(tEntry)
    }
    Quit tShaped
}

/// <p>Whether <var>pUrl</var> is an absolute URL with a scheme and a host, a numeric port if any, and
/// no whitespace or control character: the shape the vendor holds a redirect URL to.</p>
ClassMethod RedirectShaped(pUrl As %String) As %Boolean
{
    If $ZStrip(pUrl, "*CW") '= pUrl Quit 0
    Quit $Match(pUrl, "[A-Za-z][A-Za-z0-9+.-]*://[^/?#:@]+(:[0-9]{1,5})?([/?#].*)?")
}

/// <p>Whether <var>pUrl</var> is an absolute <code>http</code> or <code>https</code> URL with a host
/// and no whitespace or control character.</p>
ClassMethod UrlShaped(pUrl As %String) As %Boolean
{
    If $ZStrip(pUrl, "*CW") '= pUrl Quit 0
    Quit $Match($ZConvert(pUrl, "L"), "https?://[^/?#:@]+(:[0-9]{1,5})?([/?#].*)?")
}

/// <p><var>pUrl</var>'s scheme and host, the pair the vendor compares a display URL to a redirect URL
/// by: its port is not compared.</p>
ClassMethod Origin(pUrl As %String) As %String
{
    Quit $Piece(pUrl, "://", 1) _ "://" _ $Piece($Piece($Piece(pUrl, "://", 2, *), "/", 1), ":", 1)
}

/// <p><var>pFresh</var>'s <code>Metadata</code> with every member <var>pMembers</var> carries set over
/// it, as a new object, and <parameter>REFRESHGRANT</parameter> among the grant types when they are
/// set, as the vendor's own setter adds it. A secret member is never carried over.</p>
ClassMethod MergedMetadata(pFresh As %DynamicObject, pMembers As %DynamicObject) As %DynamicObject
{
    Set tMerged = {}
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#FIELDMETADATA) = "object") Set tMerged = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%Get(..#FIELDMETADATA).%ToJSON())
    If $IsObject(pMembers) {
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
        If pMembers.%GetTypeOf(..#GRANTMEMBER) = "array" Do ..WithRefreshGrant(tMerged)
    }
    Set tSecrets = $ListFromString($Parameter(..#PORT, "SECRETMEMBERS"))
    For tI = 1:1:$ListLength(tSecrets) Do tMerged.%Remove($List(tSecrets, tI))
    Quit tMerged
}

/// <p>Add <parameter>REFRESHGRANT</parameter> to the grant types <var>pMetadata</var> names, when it
/// names a list without it.</p>
ClassMethod WithRefreshGrant(pMetadata As %DynamicObject)
{
    If '$IsObject(pMetadata) || (pMetadata.%GetTypeOf(..#GRANTMEMBER) '= "array") Quit
    Set tGrants = pMetadata.%Get(..#GRANTMEMBER)
    Set tFound = 0
    Set tIterator = tGrants.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGrant) {
        If tGrant = ..#REFRESHGRANT Set tFound = 1
    }
    If 'tFound Do tGrants.%Push(..#REFRESHGRANT)
}

/// <p>Make <var>pPayload</var> the body the vendor's <code>POST</code> or <code>PUT</code> takes: its
/// derived template fields and nothing else (AD-3), with no secret member in its
/// <code>Metadata</code>.</p>
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
    If pPayload.%GetTypeOf(..#FIELDMETADATA) '= "object" Quit
    Set tSecrets = $ListFromString($Parameter(..#PORT, "SECRETMEMBERS"))
    For tI = 1:1:$ListLength(tSecrets) Do pPayload.%Get(..#FIELDMETADATA).%Remove($List(tSecrets, tI))
}

/// <p>A list <var>pValue</var> as card text: its entries, comma-separated.</p>
ClassMethod ListText(pValue) As %String
{
    If '$IsObject(pValue) Quit ""
    Set tText = ""
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ $Select($IsObject(tEntry): tEntry.%ToJSON(), 1: tEntry)
    }
    Quit tText
}

/// <p>The card's rows for a change from <var>pBefore</var> to <var>pPayload</var>: <var>pDiff</var>'s
/// rows with <code>RedirectURL</code> drawn as its URLs and <code>Metadata</code> drawn as one row per
/// member it changes. Nothing is added or removed but the metadata row.</p>
ClassMethod CardRows(pBefore As %DynamicObject, pPayload As %DynamicObject, pDiff As %DynamicArray) As %DynamicArray
{
    Set tRows = []
    Set tIterator = pDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tField = tRow.%Get("field")
        If tField = ..#FIELDREDIRECT {
            Do tRow.%Set("before", ..ListText($Select($IsObject(pBefore): pBefore.%Get(tField), 1: "")), "string")
            Do tRow.%Set("after", ..ListText(pPayload.%Get(tField)), "string")
            Do tRows.%Push(tRow)
            Continue
        }
        If tField '= ..#FIELDMETADATA {
            Do tRows.%Push(tRow)
            Continue
        }
        Set tOld = $Select($IsObject(pBefore) && (pBefore.%GetTypeOf(..#FIELDMETADATA) = "object"): pBefore.%Get(..#FIELDMETADATA), 1: {})
        Set tNew = pPayload.%Get(..#FIELDMETADATA)
        If '$IsObject(tNew) Continue
        Set tMembers = tNew.%GetIterator()
        While tMembers.%GetNext(.tMember, .tValue) {
            Set tBefore = ..MemberText(tOld, tMember)
            Set tAfter = ..MemberText(tNew, tMember)
            If tBefore = tAfter Continue
            Set tMemberRow = {}
            Do tMemberRow.%Set("field", ..MetadataField(tMember), "string")
            Do tMemberRow.%Set("before", tBefore, "string")
            Do tMemberRow.%Set("after", tAfter, "string")
            Do tRows.%Push(tMemberRow)
        }
    }
    Quit tRows
}

/// <p>Metadata member <var>pMember</var> of <var>pObject</var> as card text: a list as its entries, a
/// flag as <code>true</code> or <code>false</code>.</p>
ClassMethod MemberText(pObject As %DynamicObject, pMember As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pMember)
    If tType = "array" Quit ..ListText(pObject.%Get(pMember))
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pMember), tType)
}

/// <p>The field a metadata member's refusal names.</p>
ClassMethod MetadataField(pMember As %String) As %String
{
    Quit ..#FIELDMETADATA _ "." _ pMember
}

/// <p>Whether a client named <var>pName</var>, compared without regard to case, is registered, read
/// through the create tool's own absence read and port <var>pPort</var> (AD-54). A read that could
/// not be made is an error status, never a pass.</p>
ClassMethod NameTaken(pName As %String, Output pTaken As %Boolean, pPort As %String = "") As %Status
{
    Set pTaken = 0
    Set tClass = ..#CREATETOOL
    If pPort = "" Set pPort = ..PortClass()
    Kill tQuery
    Set tQuery(##class(OcuPilot.Kernel.Proposal.Operation).ReadIdParamOf(tClass, $ClassMethod(tClass, "IdParam"))) = pName
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget(tClass, pPort, $ClassMethod(tClass, "Endpoint"), .tQuery, pName, .tFresh, .tHttp, .tFault)
    If $$$ISOK(tSC) {
        Set pTaken = 1
        Quit $$$OK
    }
    If +$Get(tHttp) = 404 Quit $$$OK
    Quit tSC
}

/// <p>Answer <code>GET /oauth/server-client/form[?clientId=&lt;id&gt;]</code>: what the form needs
/// before it can draw a field (AD-39): <code>{requiredFields, rules, credentials, algorithms}</code>,
/// <code>credentials</code> the X.509 credential aliases the caller's read of that list answers (AD-5)
/// and <code>algorithms</code> each algorithm member's vendor value list; without an id
/// <code>defaults</code>, <method>Defaults</method>; and with one <code>definition</code>, the client as
/// the edit tool's own read answers it, with no secret member, and <code>clientId</code>. An id the instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTABSENT</parameter>.</p>
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
        Do tBody.%Set("credentials", ..ReadableNames())
        Set tAlgorithms = {}
        For tI = 1:1:$Length(..#ALGORITHMMEMBERS, ",") {
            Set tMember = $Piece(..#ALGORITHMMEMBERS, ",", tI)
            Set tValues = []
            Set tList = ..MemberValues(tMember)
            For tJ = 1:1:$ListLength(tList) Do tValues.%Push($List(tList, tJ))
            Do tAlgorithms.%Set(tMember, tValues)
        }
        Do tBody.%Set("algorithms", tAlgorithms)
        Set tId = $Get(%request.Data($Parameter(..#PORT, "IDQUERY"), 1))
        If tId = "" Do tBody.%Set("defaults", ..Defaults())
        If tId '= "" {
            Set tReadSC = ..Present(tId, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            Do tBody.%Set("definition", tFresh)
            Do tBody.%Set("clientId", tId, "string")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The client <var>pId</var>, read through the edit tool's own port and read type (AD-52), in
/// <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pId As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pPort As %String = "") As %Status
{
    Set pFresh = ""
    If pPort = "" Set pPort = ..PortClass()
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pId
    Set tSC = $ClassMethod(pPort, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTABSENT, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTABSENT)
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
    Set tCodes = ##class(OcuPilot.Api.Error).OAuthServerClientViolationCodes()
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
    If tPart = "SERVERCLIENTNAME" Quit ..#FIELDNAME
    If tPart = "SERVERCLIENTTYPE" Quit ..#FIELDTYPE
    If tPart = "REDIRECTURL" Quit ..#FIELDREDIRECT
    If tPart = "CLIENTGRANTTYPES" Quit ..MetadataField(..#GRANTMEMBER)
    If tPart = "RESPONSETYPES" Quit ..MetadataField(..#RESPONSEMEMBER)
    If tPart = "AUTHMETHOD" Quit ..MetadataField(..#AUTHMEMBER)
    If tPart = "ALGORITHM" Quit ..MetadataField($Piece(..#ALGORITHMMEMBERS, ",", 1))
    If tPart = "ENCRYPTION" Quit ..MetadataField($Piece($Piece(..#ENCRYPTIONPAIRS, ",", 1), ":", 1))
    If (tPart = "CLIENTURL") || (tPart = "METADATAURL") Quit ..MetadataField($Piece(..#HOSTMEMBERS, ",", 1))
    If tPart = "CONTACTS" Quit ..MetadataField(..#CONTACTSMEMBER)
    If tPart = "MAXAGE" Quit ..MetadataField(..#MAXAGEMEMBER)
    If tPart = "FLAG" Quit ..MetadataField(..#SESSIONMEMBER)
    If tPart = "LAUNCHURL" Quit ..#FIELDLAUNCH
    If tPart = "DEFAULTSCOPE" Quit ..#FIELDSCOPE
    If tPart = "CLIENTCREDENTIALS" Quit ..#FIELDCREDENTIALS
    If tPart = "SERVERCLIENTSECRET" Quit ..#FIELDSECRET
    Quit ..#FIELDMETADATA
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

/// <p>The X.509 credential aliases the credential list's own declared read answers the caller
/// (AD-5), or <code>[]</code>.</p>
ClassMethod ReadableNames() As %DynamicArray
{
    Quit ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(..#CREDENTIALSCREEN, ..#CREDENTIALNAMEFIELD)
}

/// <p>Whether <var>pNames</var> holds <var>pName</var> exactly.</p>
ClassMethod Named(ByRef pNames, pName As %String) As %Boolean
{
    If $IsObject($Get(pNames)) {
        Set tFound = 0
        Set tIterator = pNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If tName = pName Set tFound = 1 Quit
        }
        Quit tFound
    }
    ; A violation array: whether a violation already names field pName.
    Set tFound = 0
    For tI = 1:1:+$Get(pNames) {
        If $List(pNames(tI), 1) = pName Set tFound = 1 Quit
    }
    Quit tFound
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
/// <var>pBase</var>'s.</p>
ClassMethod Effective(pArgs As %DynamicObject, pBase As %DynamicObject, pField As %String) As %String [ Private ]
{
    If pArgs.%GetTypeOf(pField) '= "unassigned" Quit ..Text(pArgs, pField)
    Quit ..Text(pBase, pField)
}

/// <p>Whether a rule over <var>pField</var> applies: always on a create, and on an edit only when
/// <var>pArgs</var> carries the field.</p>
ClassMethod Changes(pArgs As %DynamicObject, pField As %String, pCreates As %Boolean) As %Boolean [ Private ]
{
    Quit pCreates || (pArgs.%GetTypeOf(pField) '= "unassigned")
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
