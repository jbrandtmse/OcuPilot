/// <p>The OAuth 2.0 client configuration editor's rules (AD-39, AD-55): the one rule set every caller
/// of <class>OcuPilot.Screen.Tool.OAuthClientCreate</class> and
/// <class>OcuPilot.Screen.Tool.OAuthClientUpdate</class> applies (<method>Validate</method>), the
/// <code>Metadata</code> members derived from the vendor's <code>OAuth2.Client.Metadata</code>
/// (<method>Members</method>), the expansion that makes a body the complete set
/// (<method>Expand</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so a field
/// refusal on the screen and the agent's argument refusal are one wording.</p>
/// <p><b>The member set, each member's kind and a fixed member's values are read from
/// <class>OcuPilot.Screen.Tool.FieldLists</class></b>, derived from the instance (AD-3). A member in
/// the port's <parameter>OcuPilot.Port.OAuthClientPort.SECRETMEMBERS</parameter> or
/// <parameter>OcuPilot.Port.OAuthClientPort.MANAGEDMEMBERS</parameter> is not settable: the first
/// are never sent and the second are sent as the instance holds them.</p>
Class OcuPilot.Area.Security.OAuthClientRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthClientCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthClientUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientForm";

/// <p>The port whose secret and managed member lists the rules read.</p>
Parameter PORT = "OcuPilot.Port.OAuthClientPort";

/// <p>The generated field lists, the derived template list and the derived member list.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter TEMPLATELIST = "Security.OAuth2.Client.ClientConfiguration";

Parameter MEMBERSLIST = "Security.OAuth2.Client.ClientConfiguration:OAuth2.Client.Metadata";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "ApplicationName";

Parameter FIELDSERVER = "ServerDefinition";

Parameter FIELDTYPE = "ClientType";

Parameter FIELDSSL = "SSLConfiguration";

Parameter FIELDREDIRECT = "RedirectionEndpoint";

Parameter FIELDCREDENTIALS = "ClientCredentials";

Parameter FIELDINTERVAL = "JWTInterval";

Parameter FIELDENABLED = "Enabled";

Parameter FIELDMETADATA = "Metadata";

/// <p>The top-level fields that carry text.</p>
Parameter TEXTFIELDS = "ServerDefinition,Description,ClientType,SSLConfiguration,RedirectionEndpoint,JWTAudience,ClientId,ClientCredentials,DefaultScope";

/// <p>The client types the vendor stores, and the one that has no redirect URL.</p>
Parameter CLIENTTYPES = "confidential,public,resource";

Parameter RESOURCETYPE = "resource";

/// <p>The vendor's longest application name.</p>
Parameter NAMEMAXLENGTH As INTEGER = 128;

/// <p>The fields a create must carry, as the form names them.</p>
Parameter REQUIREDFIELDS = "ApplicationName,ServerDefinition,ClientType,SSLConfiguration,RedirectionEndpoint";

/// <p>The screens whose declared reads name what the form offers (AD-5), and the field each row
/// names it by.</p>
Parameter SERVERSCREEN = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter SSLSCREEN = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter SSLNAMEFIELD = "Name";

Parameter X509SCREEN = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter X509NAMEFIELD = "Alias";

/// <p>Every derived member, in the list's order, in <var>pNames</var>, with
/// <code>pKinds(name)</code> its kind and <code>pValues(name)</code> a fixed member's values as a
/// <class>%List</class>. A list that cannot be read is an error status.</p>
ClassMethod Members(Output pNames As %List, Output pKinds, Output pValues) As %Status
{
    Set pNames = ""
    Kill pKinds, pValues
    Set tSC = ..ListRows(..#MEMBERSLIST, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tName = tRow.%Get("path")
        Set tKind = tRow.%Get("kind")
        If (tName = "") || (tKind = "") {
            Set tSC = $$$ERROR($$$GeneralError, ..#MEMBERSLIST _ " row '" _ tName _ "' carries no member kind")
            Quit
        }
        Set pNames = pNames _ $ListBuild(tName)
        Set pKinds(tName) = tKind
        Set tValues = ""
        If tRow.%GetTypeOf("values") = "array" {
            Set tValueIterator = tRow.%Get("values").%GetIterator()
            While tValueIterator.%GetNext(.tValueIndex, .tValue) {
                Set tValues = tValues _ $ListBuild(tValue)
            }
        }
        Set pValues(tName) = tValues
    }
    If $$$ISOK(tSC) && (pNames = "") Set tSC = $$$ERROR($$$GeneralError, ..#MEMBERSLIST _ " has no rows")
    Quit tSC
}

/// <p>Whether member <var>pName</var> is one a caller may set: neither a secret nor a member the
/// instance manages.</p>
ClassMethod Settable(pName As %String) As %Boolean
{
    If $ListFind($ListFromString($Parameter(..#PORT, "SECRETMEMBERS")), pName) Quit 0
    If $ListFind($ListFromString($Parameter(..#PORT, "MANAGEDMEMBERS")), pName) Quit 0
    Quit 1
}

/// <p>The body's top-level fields, in the derived template list's order (AD-3).</p>
ClassMethod TemplateFields(Output pFields As %List) As %Status
{
    Set pFields = ""
    Set tSC = ..ListRows(..#TEMPLATELIST, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("path") '= "") Set pFields = pFields _ $ListBuild(tRow.%Get("path"))
    }
    If pFields = "" Quit $$$ERROR($$$GeneralError, ..#TEMPLATELIST _ " has no rows")
    Quit $$$OK
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

/// <p>The JSON schema of the <code>Metadata</code> argument: an object described with
/// <var>pDescription</var> followed by every settable member grouped by kind, a fixed member with its
/// values. <code>""</code> when the members cannot be read.</p>
ClassMethod MetadataSchema(pDescription As %String) As %DynamicObject
{
    If $$$ISERR(..Members(.tNames, .tKinds, .tValues)) Quit ""
    Set (tUris, tTexts, tFixed, tLists, tIntegers, tFlags) = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If '..Settable(tName) Continue
        Set tKind = tKinds(tName)
        If tValues(tName) '= "" {
            Set tFixed = tFixed _ $ListBuild(tName _ " (" _ $ListToString(tValues(tName), ", ") _ ")")
        } ElseIf tKind = "uri" {
            Set tUris = tUris _ $ListBuild(tName)
        } ElseIf tKind = "list" {
            Set tLists = tLists _ $ListBuild(tName)
        } ElseIf tKind = "integer" {
            Set tIntegers = tIntegers _ $ListBuild(tName)
        } ElseIf tKind = "flag" {
            Set tFlags = tFlags _ $ListBuild(tName)
        } Else {
            Set tTexts = tTexts _ $ListBuild(tName)
        }
    }
    Set tText = pDescription _ " Its members are named as OpenID Connect client registration names them, and no other member is accepted. URLs, as text: " _ $ListToString(tUris, ", ") _ ". Text: " _ $ListToString(tTexts, ", ") _ ". One of the listed values, or an empty string: " _ $ListToString(tFixed, "; ") _ ". Lists, as arrays of text: " _ $ListToString(tLists, ", ") _ ". Whole numbers: " _ $ListToString(tIntegers, ", ") _ ". Flags, as true or false: " _ $ListToString(tFlags, ", ") _ "."
    Set tSchema = {"type": "object"}
    Do tSchema.%Set("description", tText, "string")
    Quit tSchema
}

/// <p>Every rule a client configuration write applies to <var>pArgs</var>, in <var>pViolations</var>
/// as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's rules to <var>pName</var> and requires
/// every required field; <code>update</code> reads each field <var>pArgs</var> does not carry from
/// <var>pFresh</var>, so a field is required only when the arguments empty it and the redirect URL
/// is judged against the client type the configuration will have. <var>pArgs</var>'s
/// <code>Metadata</code> is held to the settable members' names and shapes. <var>pCheckTaken</var> 0
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
        Set tEnabledType = pArgs.%GetTypeOf(..#FIELDENABLED)
        If (tEnabledType '= "unassigned") && (tEnabledType '= "boolean") Do ..Add(.pViolations, ..#FIELDENABLED, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)

        Set tServer = ..Effective(pArgs, pFresh, ..#FIELDSERVER, tCreates)
        If ..Changes(pArgs, ..#FIELDSERVER, tCreates) {
            If tServer = "" {
                Do ..Add(.pViolations, ..#FIELDSERVER, ##class(OcuPilot.Api.Error).#OAUTHSERVERDEFINITIONREQUIRED)
            } Else {
                Set tSC = ..ServerPresent(tServer, .tPresent)
                If $$$ISERR(tSC) Quit
                If 'tPresent Do ..Add(.pViolations, ..#FIELDSERVER, ##class(OcuPilot.Api.Error).#OAUTHSERVERDEFINITIONABSENT)
            }
        }
        Set tClientType = ..Effective(pArgs, pFresh, ..#FIELDTYPE, tCreates)
        If ..Changes(pArgs, ..#FIELDTYPE, tCreates) && '$ListFind($ListFromString(..#CLIENTTYPES), tClientType) {
            Do ..Add(.pViolations, ..#FIELDTYPE, ##class(OcuPilot.Api.Error).#OAUTHCLIENTTYPEVALUE)
        }
        If ..Changes(pArgs, ..#FIELDSSL, tCreates) && (..Effective(pArgs, pFresh, ..#FIELDSSL, tCreates) = "") {
            Do ..Add(.pViolations, ..#FIELDSSL, ##class(OcuPilot.Api.Error).#OAUTHSSLCONFIGURATIONREQUIRED)
        }
        If ..Changes(pArgs, ..#FIELDREDIRECT, tCreates) || ..Changes(pArgs, ..#FIELDTYPE, tCreates) {
            Set tRedirect = ..Effective(pArgs, pFresh, ..#FIELDREDIRECT, tCreates)
            If tRedirect = "" {
                If tClientType '= ..#RESOURCETYPE Do ..Add(.pViolations, ..#FIELDREDIRECT, ##class(OcuPilot.Api.Error).#OAUTHREDIRECTIONENDPOINTREQUIRED)
            } ElseIf '..RedirectShaped(tRedirect) {
                Do ..Add(.pViolations, ..#FIELDREDIRECT, ##class(OcuPilot.Api.Error).#OAUTHREDIRECTIONENDPOINTSHAPE)
            }
        }
        Set tCredentials = ..Text(pArgs, ..#FIELDCREDENTIALS)
        If (tCredentials '= "") && '$ClassMethod(..#PORT, "CredentialUsable", tCredentials) {
            Do ..Add(.pViolations, ..#FIELDCREDENTIALS, ##class(OcuPilot.Api.Error).#OAUTHCLIENTCREDENTIALSABSENT)
        }
        If '..WholeOrEmpty(pArgs, ..#FIELDINTERVAL) Do ..Add(.pViolations, ..#FIELDINTERVAL, ##class(OcuPilot.Api.Error).#OAUTHJWTINTERVALSHAPE)

        Set tMetadataType = pArgs.%GetTypeOf(..#FIELDMETADATA)
        If tMetadataType = "object" {
            Set tSC = ..MemberViolations(pArgs.%Get(..#FIELDMETADATA), .pViolations)
            If $$$ISERR(tSC) Quit
        } ElseIf tMetadataType '= "unassigned" {
            Do ..Add(.pViolations, ..#FIELDMETADATA, ##class(OcuPilot.Api.Error).#OAUTHMETADATASHAPE)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation for <var>pName</var>: absent, longer than
/// <parameter>NAMEMAXLENGTH</parameter> or carrying a control character, or -- with
/// <var>pCheckTaken</var> -- carried by a configuration already.</p>
ClassMethod NameViolation(pName As %String, pCheckTaken As %Boolean, ByRef pViolations) As %Status
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEREQUIRED)
        Quit $$$OK
    }
    If ($Length(pName) > ..#NAMEMAXLENGTH) || ($ZStrip(pName, "*C") '= pName) {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMESHAPE)
        Quit $$$OK
    }
    If 'pCheckTaken Quit $$$OK
    Set tSC = ..Present(pName, .tFresh, .tHttp, .tFault)
    If $$$ISOK(tSC) {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMETAKEN)
        Quit $$$OK
    }
    If +$Get(tHttp) = 404 Quit $$$OK
    Quit tSC
}

/// <p>Whether <var>pUrl</var> is an absolute <code>http</code> or <code>https</code> URL with a host
/// and no whitespace or control character.</p>
ClassMethod RedirectShaped(pUrl As %String) As %Boolean
{
    If $ZStrip(pUrl, "*C") '= pUrl Quit 0
    Quit $Match(pUrl, "(?i)https?://[^/?#\s:]+(:[0-9]{1,5})?(/\S*)?")
}

/// <p>Whether the description whose ID is <var>pId</var> exists, read through the port; an ID that
/// is not a whole number names none. A look-up that could not be made is an error status.</p>
ClassMethod ServerPresent(pId As %String, Output pPresent As %Boolean) As %Status
{
    Set pPresent = 0
    If '$Match(pId, "[1-9][0-9]{0,17}") Quit $$$OK
    Kill tQuery
    Set tQuery($Parameter(..#PORT, "SERVERQUERY")) = pId
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $Parameter(..#PORT, "SERVERENDPOINT"), "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    Set pPresent = $IsObject(tRead)
    Quit $$$OK
}

/// <p>The member violations of <var>pMetadata</var>: a member that is not settable, a value that is
/// not its member's shape -- text for a URI or text member, an array of text for a list, a whole
/// number or its digits for an integer, a boolean for a flag, <code>""</code> being every scalar's
/// empty form -- and a fixed member's value outside its values. Each violation's field is
/// <code>Metadata.&lt;member&gt;</code>.</p>
ClassMethod MemberViolations(pMetadata As %DynamicObject, ByRef pViolations) As %Status
{
    Set tSC = ..Members(.tNames, .tKinds, .tValues)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = pMetadata.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        Set tField = ..#FIELDMETADATA _ "." _ tMember
        If '$ListFind(tNames, tMember) || '..Settable(tMember) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHMETADATAUNKNOWN)
            Continue
        }
        Set tType = pMetadata.%GetTypeOf(tMember)
        Set tKind = tKinds(tMember)
        Set tShaped = 0
        If (tKind = "uri") || (tKind = "text") Set tShaped = (tType = "string")
        If tKind = "flag" Set tShaped = (tType = "boolean") || ((tType = "string") && (tValue = ""))
        If tKind = "integer" Set tShaped = ((tType = "number") && (tValue = (tValue \ 1))) || ((tType = "string") && $Match(tValue, "|[0-9]{1,18}"))
        If tKind = "list" {
            Set tShaped = (tType = "array")
            If tShaped {
                Set tItems = tValue.%GetIterator()
                While tItems.%GetNext(.tItemIndex, .tItem) {
                    If tValue.%GetTypeOf(tItemIndex) '= "string" Set tShaped = 0
                }
            }
        }
        If 'tShaped {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHMETADATASHAPE)
            Continue
        }
        If (tValues(tMember) '= "") && (tValue '= "") && '$ListFind(tValues(tMember), tValue) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHMETADATAVALUE)
        }
    }
    Quit $$$OK
}

/// <p>Make <var>pPayload</var> the body the vendor's <code>PUT</code> takes: its derived template
/// fields and nothing else (AD-3), with <code>Metadata</code> carrying no secret member. For an edit
/// (<var>pComplete</var> 1) it carries every settable member (AD-4), a member the payload leaves out
/// in its empty form -- <code>[]</code> for a list, <code>""</code> otherwise -- because the vendor
/// merges <code>Metadata</code> member by member. A create is composed rather than merged (AD-54):
/// a member it leaves out is not sent, so the vendor sets its own algorithm defaults. A managed member
/// is left as the payload has it, and the port sends it as its own fresh read has it.</p>
ClassMethod Expand(pPayload As %DynamicObject, pComplete As %Boolean = 1)
{
    If '$IsObject(pPayload) Quit
    If $$$ISERR(..TemplateFields(.tKeep)) Quit
    Set tDrop = ""
    Set tIterator = pPayload.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeep, tKey) Set tDrop = tDrop _ $ListBuild(tKey)
    }
    For tI = 1:1:$ListLength(tDrop) Do pPayload.%Remove($List(tDrop, tI))
    If $$$ISERR(..Members(.tNames, .tKinds, .tValues)) Quit
    If pPayload.%GetTypeOf(..#FIELDMETADATA) '= "object" Do pPayload.%Set(..#FIELDMETADATA, {})
    Set tMetadata = pPayload.%Get(..#FIELDMETADATA)
    Set tSecrets = $ListFromString($Parameter(..#PORT, "SECRETMEMBERS"))
    For tI = 1:1:$ListLength(tSecrets) Do tMetadata.%Remove($List(tSecrets, tI))
    If 'pComplete Quit
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If '..Settable(tName) Continue
        Set tType = tMetadata.%GetTypeOf(tName)
        If (tType '= "unassigned") && (tType '= "null") Continue
        If tKinds(tName) = "list" {
            Do tMetadata.%Set(tName, [])
        } Else {
            Do tMetadata.%Set(tName, "", "string")
        }
    }
}

/// <p>Answer <code>GET /oauth/client-configuration/form[?applicationName=&lt;name&gt;]</code>: what
/// the form needs before it can draw a field (AD-39): <code>{requiredFields, rules, members,
/// serverDescriptions, sslConfigurations, credentials}</code>. <code>members</code> is
/// <code>[{name, kind, values, settable}]</code> in the derived order; the three lists are what the
/// caller can read through the server description, SSL/TLS and X.509 screens' own declared reads
/// (AD-5), the credentials narrowed to those with a private key the caller can use. With a name it
/// adds <code>definition</code>: the edit tool's fresh read with no secret, plus
/// <code>RegistrationEndpoint</code>, the registration endpoint its description publishes. A name
/// no configuration carries is 404 <parameter>OcuPilot.Api.Error.OAUTHAPPLICATIONNAMEABSENT</parameter>.
/// No secret is ever part of the answer.</p>
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
        Set tMembersSC = ..Members(.tNames, .tKinds, .tValues)
        If $$$ISERR(tMembersSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tMembersSC))
            Quit
        }
        Set tMembers = []
        Set tSecrets = $ListFromString($Parameter(..#PORT, "SECRETMEMBERS"))
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If $ListFind(tSecrets, tName) Continue
            Set tRow = {}
            Do tRow.%Set("name", tName, "string")
            Do tRow.%Set("kind", tKinds(tName), "string")
            Set tAllowed = []
            For tJ = 1:1:$ListLength(tValues(tName)) Do tAllowed.%Push($List(tValues(tName), tJ))
            Do tRow.%Set("values", tAllowed)
            Do tRow.%Set("settable", ..Settable(tName), "boolean")
            Do tMembers.%Push(tRow)
        }
        Do tBody.%Set("members", tMembers)
        Do tBody.%Set("serverDescriptions", ..ServerDescriptions())
        Do tBody.%Set("sslConfigurations", ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(..#SSLSCREEN, ..#SSLNAMEFIELD))
        Set tCredentials = []
        Set tAliases = ##class(OcuPilot.Area.Security.OAuthServerRules).ReadableNames(..#X509SCREEN, ..#X509NAMEFIELD)
        Set tAliasIterator = tAliases.%GetIterator()
        While tAliasIterator.%GetNext(.tAliasIndex, .tAlias) {
            If $ClassMethod(..#PORT, "CredentialUsable", tAlias) Do tCredentials.%Push(tAlias)
        }
        Do tBody.%Set("credentials", tCredentials)
        Set tName = $Get(%request.Data("applicationName", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tDefinition = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
            Do tDefinition.%Set(..#FIELDNAME, tName, "string")
            Kill tQuery
            Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = tName
            Set tRegistrationSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $Parameter(..#PORT, "REGISTRATIONTYPE"), .tQuery, "", .tRegistration, .tRegistrationHttp, .tRegistrationFault)
            If $$$ISERR(tRegistrationSC) {
                Set tSC = ..RenderRead(tRegistrationSC, tRegistrationHttp, tRegistrationFault)
                Quit
            }
            Do tDefinition.%Set("RegistrationEndpoint", tRegistration.%Get("RegistrationEndpoint"), "string")
            Do tBody.%Set("definition", tDefinition)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The server descriptions the caller can read through that tab's own declared read (AD-5), as
/// <code>[{id, issuer}]</code>, or <code>[]</code> for a caller the tab refuses.</p>
ClassMethod ServerDescriptions() As %DynamicArray
{
    Set tRows = []
    Try {
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#SERVERSCREEN, .tFailedPair) Quit
        Set tReadSC = ##class(OcuPilot.Screen.Read).Execute(..#SERVERSCREEN, "", .tResult, .tHttp, .tFault)
        If $$$ISERR(tReadSC) || '$IsObject($Get(tResult)) Quit
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tOut = {}
            Do tOut.%Set("id", ..Text(tRow, "ID"), "string")
            Do tOut.%Set("issuer", ..Text(tRow, "IssuerEndpoint"), "string")
            Do tRows.%Push(tOut)
        }
    } Catch {
        Set tRows = []
    }
    Quit tRows
}

/// <p>The configuration <var>pName</var>, read through the edit tool's own port and read type
/// (AD-52), in <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var>
/// 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.OAUTHAPPLICATIONNAMEABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHAPPLICATIONNAMEABSENT, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEABSENT)
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
    Set tCodes = ##class(OcuPilot.Api.Error).OAuthClientViolationCodes()
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

/// <p>The form field an <code>OAUTH.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses, or
/// <code>Metadata</code> for a member rule.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "APPLICATIONNAME" Quit ..#FIELDNAME
    If tPart = "SERVERDEFINITION" Quit ..#FIELDSERVER
    If tPart = "CLIENTTYPE" Quit ..#FIELDTYPE
    If tPart = "SSLCONFIGURATION" Quit ..#FIELDSSL
    If tPart = "REDIRECTIONENDPOINT" Quit ..#FIELDREDIRECT
    If tPart = "CLIENTCREDENTIALS" Quit ..#FIELDCREDENTIALS
    If tPart = "JWTINTERVAL" Quit ..#FIELDINTERVAL
    Quit ..#FIELDMETADATA
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

/// <p>Whether <var>pArgs</var>'s <var>pField</var> is absent, empty, a whole number, or a string of
/// digits.</p>
ClassMethod WholeOrEmpty(pArgs As %DynamicObject, pField As %String) As %Boolean [ Private ]
{
    Set tType = pArgs.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") Quit 1
    Set tValue = pArgs.%Get(pField)
    If tType = "number" Quit (tValue = (tValue \ 1))
    If tType = "string" Quit $Match(tValue, "|[0-9]{1,18}")
    Quit 0
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
