/// <p>The OAuth 2.0 server description editor's rules (AD-39, AD-55): the one rule set every caller
/// of <class>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate</class> and
/// <class>OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate</class> applies
/// (<method>Validate</method>), the <code>Metadata</code> member set derived from the vendor's
/// <code>OAuth2.Server.Metadata</code> (<method>Members</method>), the expansion that makes a body
/// the complete set (<method>Expand</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, so a field
/// refusal on the screen and the agent's argument refusal are one wording.</p>
/// <p><b>The member set is read from <class>OcuPilot.Screen.Tool.FieldLists</class></b>, the
/// generated list <file>scripts/field-lists.sh</file> derives from the instance (AD-3): a member is
/// a URI (a string), a list (an array of strings) or a flag (a boolean), by the row's shape and type.
/// Nothing here names a member except the two the vendor's definition requires.</p>
Class OcuPilot.Area.Security.OAuthServerRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm";

/// <p>The generated field lists, and the key of the derived <code>Metadata</code> member list.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter MEMBERSLIST = "Security.OAuth2.Client.ServerDefinition:OAuth2.Server.Metadata";

/// <p>The key of the derived template list, whose rows are the body's top-level fields.</p>
Parameter TEMPLATELIST = "Security.OAuth2.Client.ServerDefinition";

/// <p>The two members the vendor's <code>%OnValidateObject</code> requires.</p>
Parameter AUTHORIZATIONMEMBER = "authorization_endpoint";

Parameter TOKENMEMBER = "token_endpoint";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDISSUER = "IssuerEndpoint";

Parameter FIELDSSL = "SSLConfiguration";

Parameter FIELDCREDENTIALS = "ServerCredentials";

Parameter FIELDMETADATA = "Metadata";

/// <p>The fields a create must carry, as the form names them.</p>
Parameter REQUIREDFIELDS = "IssuerEndpoint,SSLConfiguration,Metadata.authorization_endpoint,Metadata.token_endpoint";

/// <p>The screens whose declared reads name the SSL/TLS configurations and the X.509 credentials the
/// form offers (AD-5), and the field each row names them by.</p>
Parameter SSLSCREEN = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter SSLNAMEFIELD = "Name";

Parameter X509SCREEN = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter X509NAMEFIELD = "Alias";

/// <p>The derived members, in the list's order, in <var>pNames</var> as a <class>%List</class>, with
/// <code>pKinds(name)</code> <code>uri</code>, <code>list</code> or <code>flag</code>. A list that
/// cannot be read, or a row of a shape no kind maps, is an error status.</p>
ClassMethod Members(Output pNames As %List, Output pKinds) As %Status
{
    Set pNames = ""
    Kill pKinds
    Set tSC = $$$OK
    Try {
        Set tSC = ..ListRows(..#MEMBERSLIST, .tRows)
        If $$$ISERR(tSC) Quit
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tName = tRow.%Get("path")
            Set tKind = ""
            If tRow.%Get("shape") = "array" Set tKind = "list"
            If (tRow.%Get("shape") = "literal") && (tRow.%Get("templateType") = "string") Set tKind = "uri"
            If (tRow.%Get("shape") = "literal") && (tRow.%Get("templateType") = "boolean") Set tKind = "flag"
            If (tName = "") || (tKind = "") {
                Set tSC = $$$ERROR($$$GeneralError, ..#MEMBERSLIST _ " row '" _ tName _ "' maps to no member kind")
                Quit
            }
            Set pNames = pNames _ $ListBuild(tName)
            Set pKinds(tName) = tKind
        }
        If $$$ISOK(tSC) && (pNames = "") Set tSC = $$$ERROR($$$GeneralError, ..#MEMBERSLIST _ " has no rows")
    } Catch ex {
        Set pNames = ""
        Kill pKinds
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The body's top-level fields, in the derived template list's order (AD-3), as a
/// <class>%List</class> in <var>pFields</var>. A list that cannot be read is an error status.</p>
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

/// <p>The rows of the generated field list <var>pKey</var>, as a <class>%DynamicArray</class> in
/// <var>pRows</var>. A list that cannot be read is an error status.</p>
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

/// <p>The JSON schema of the <code>Metadata</code> argument: an object, described with
/// <var>pDescription</var> followed by every derived member grouped by kind, because the schema
/// subset a provider is sent describes no member below a property. A member's name and shape are
/// <method>Validate</method>'s to refuse. <code>""</code> when the members cannot be read.</p>
ClassMethod MetadataSchema(pDescription As %String) As %DynamicObject
{
    If $$$ISERR(..Members(.tNames, .tKinds)) Quit ""
    Set (tUris, tLists, tFlags) = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If tKinds(tName) = "list" {
            Set tLists = tLists _ $ListBuild(tName)
        } ElseIf tKinds(tName) = "flag" {
            Set tFlags = tFlags _ $ListBuild(tName)
        } Else {
            Set tUris = tUris _ $ListBuild(tName)
        }
    }
    Set tText = pDescription _ " Its members are named as a discovery document names them, and no other member is accepted. URLs, as text: " _ $ListToString(tUris, ", ") _ ". Lists, as arrays of text: " _ $ListToString(tLists, ", ") _ ". Flags, as true or false: " _ $ListToString(tFlags, ", ") _ "."
    Set tSchema = {"type": "object"}
    Do tSchema.%Set("description", tText, "string")
    Quit tSchema
}

/// <p>Every rule a server description write applies to <var>pArgs</var>, in <var>pViolations</var>
/// as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the issuer's rules to <var>pIssuer</var> and
/// requires the SSL/TLS configuration and both required endpoints; <code>update</code> applies the
/// issuer's rules only to an <code>IssuerEndpoint</code> <var>pArgs</var> renames it to, and requires
/// a field only when <var>pArgs</var> empties it. <var>pArgs</var>'s <code>Metadata</code>, when it
/// carries one, is the whole metadata the description will hold, and is held to the derived
/// members' names and shapes; without one, <var>pFresh</var>'s is. <var>pCheckTaken</var> 0 skips
/// the issuer look-up, for the agent's mint, which has read the target itself. A look-up that fails
/// is an error status, never a pass.</p>
ClassMethod Validate(pIssuer As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        If tCreates {
            Set tSC = ..IssuerViolation(pIssuer, pCheckTaken, "", .pViolations)
            If $$$ISERR(tSC) Quit
        } ElseIf pArgs.%GetTypeOf(..#FIELDISSUER) '= "unassigned" {
            Set tRenamed = ..Text(pArgs, ..#FIELDISSUER)
            If tRenamed '= pIssuer {
                Set tSC = ..IssuerViolation(tRenamed, pCheckTaken, pIssuer, .pViolations)
                If $$$ISERR(tSC) Quit
            }
        }

        For tField = ..#FIELDSSL, ..#FIELDCREDENTIALS {
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If (tField = ..#FIELDSSL) && ((tCreates && (..Text(pArgs, tField) = "")) || ('tCreates && (tType '= "unassigned") && (..Text(pArgs, tField) = ""))) {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHSSLCONFIGURATIONREQUIRED)
            }
            If (tField = ..#FIELDCREDENTIALS) && (..Text(pArgs, tField) '= "") {
                If '$ClassMethod(..PortClass(), "CredentialUsable", ..Text(pArgs, tField)) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHSERVERCREDENTIALSABSENT)
            }
        }

        Set tMetadataType = pArgs.%GetTypeOf(..#FIELDMETADATA)
        Set tHeld = ""
        If tMetadataType = "object" {
            Set tHeld = pArgs.%Get(..#FIELDMETADATA)
        } ElseIf tMetadataType '= "unassigned" {
            Do ..Add(.pViolations, ..#FIELDMETADATA, ##class(OcuPilot.Api.Error).#OAUTHMETADATASHAPE)
        } ElseIf $IsObject(pFresh) && (pFresh.%GetTypeOf(..#FIELDMETADATA) = "object") {
            Set tHeld = pFresh.%Get(..#FIELDMETADATA)
        }
        If tMetadataType = "object" {
            Set tSC = ..MemberViolations(tHeld, .pViolations)
            If $$$ISERR(tSC) Quit
        }
        If tCreates || $IsObject(tHeld) {
            If ..MemberText(tHeld, ..#AUTHORIZATIONMEMBER) = "" Do ..Add(.pViolations, ..#FIELDMETADATA _ "." _ ..#AUTHORIZATIONMEMBER, ##class(OcuPilot.Api.Error).#OAUTHAUTHORIZATIONENDPOINTREQUIRED)
            If ..MemberText(tHeld, ..#TOKENMEMBER) = "" Do ..Add(.pViolations, ..#FIELDMETADATA _ "." _ ..#TOKENMEMBER, ##class(OcuPilot.Api.Error).#OAUTHTOKENENDPOINTREQUIRED)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the issuer's own violation for <var>pIssuer</var>: absent, not an absolute
/// <code>http</code> or <code>https</code> URL, or -- with <var>pCheckTaken</var> -- carried by a
/// description other than <var>pOwn</var>. The look-up is the port's own list, compared
/// exactly.</p>
ClassMethod IssuerViolation(pIssuer As %String, pCheckTaken As %Boolean, pOwn As %String, ByRef pViolations) As %Status
{
    If pIssuer = "" {
        Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTREQUIRED)
        Quit $$$OK
    }
    If '..IssuerShaped(pIssuer) {
        Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTSHAPE)
        Quit $$$OK
    }
    If 'pCheckTaken Quit $$$OK
    Set tSC = ..Taken(pIssuer, .tTaken)
    If $$$ISERR(tSC) Quit tSC
    If tTaken && (pIssuer '= pOwn) Do ..Add(.pViolations, ..#FIELDISSUER, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTTAKEN)
    Quit $$$OK
}

/// <p>Whether <var>pIssuer</var> is an absolute <code>http</code> or <code>https</code> URL with a
/// host, no query or fragment (RFC 8414; the discovery path is appended to it), and no whitespace or
/// control character.</p>
ClassMethod IssuerShaped(pIssuer As %String) As %Boolean
{
    If $ZStrip(pIssuer, "*C") '= pIssuer Quit 0
    Quit $Match(pIssuer, "(?i)https?://[^/?#\s]+(/[^?#\s]*)?")
}

/// <p>Whether a description already carries <var>pIssuer</var>, read through the create tool's own
/// port. A look-up that could not be made is an error status.</p>
ClassMethod Taken(pIssuer As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Kill tQuery
    Set tQuery($ClassMethod(..#CREATETOOL, "IdParam")) = pIssuer
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#CREATETOOL, "Endpoint"), "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The member violations of <var>pMetadata</var>: a member the derived list does not name, and a
/// value that is not its member's shape -- a string for a URI, an array of strings for a list, a
/// boolean or the empty string for a flag, <code>""</code> being the flag's empty form, which clears
/// it. Each violation's field is <code>Metadata.&lt;member&gt;</code>.</p>
ClassMethod MemberViolations(pMetadata As %DynamicObject, ByRef pViolations) As %Status
{
    Set tSC = ..Members(.tNames, .tKinds)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = pMetadata.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        Set tField = ..#FIELDMETADATA _ "." _ tMember
        If '$ListFind(tNames, tMember) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHMETADATAUNKNOWN)
            Continue
        }
        Set tType = pMetadata.%GetTypeOf(tMember)
        Set tShaped = 0
        If tKinds(tMember) = "uri" Set tShaped = (tType = "string")
        If tKinds(tMember) = "flag" Set tShaped = (tType = "boolean") || ((tType = "string") && (tValue = ""))
        If tKinds(tMember) = "list" {
            Set tShaped = (tType = "array")
            If tShaped {
                Set tItems = tValue.%GetIterator()
                While tItems.%GetNext(.tItemIndex, .tItem) {
                    If tValue.%GetTypeOf(tItemIndex) '= "string" Set tShaped = 0
                }
            }
        }
        If 'tShaped Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#OAUTHMETADATASHAPE)
    }
    Quit $$$OK
}

/// <p>Make <var>pPayload</var> the body the vendor's <code>PUT</code> and <code>POST</code> take:
/// its derived template fields (<method>TemplateFields</method>, AD-3) and nothing else, with
/// <code>Metadata</code> carrying every derived
/// member (AD-4). A member the payload leaves out is sent in its empty form -- <code>""</code> for a
/// URI, <code>[]</code> for a list, <code>""</code> for a flag -- because the vendor merges
/// <code>Metadata</code> member by member and keeps a member the body omits. A flag is emptied with
/// <code>""</code>, not <code>false</code>: measured, the vendor stores <code>false</code> and reads
/// it back, while <code>""</code> clears it.</p>
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
    If $$$ISERR(..Members(.tNames, .tKinds)) Quit
    If pPayload.%GetTypeOf(..#FIELDMETADATA) '= "object" Do pPayload.%Set(..#FIELDMETADATA, {})
    Set tMetadata = pPayload.%Get(..#FIELDMETADATA)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = tMetadata.%GetTypeOf(tName)
        If (tType '= "unassigned") && (tType '= "null") Continue
        If tKinds(tName) = "list" {
            Do tMetadata.%Set(tName, [])
        } Else {
            Do tMetadata.%Set(tName, "", "string")
        }
    }
}

/// <p>Answer <code>GET /oauth/server-description/form[?issuer=&lt;issuer&gt;]</code>: what the form
/// needs before it can draw a field (AD-39): <code>{requiredFields, rules, members, sslConfigurations,
/// credentials}</code>, where <code>members</code> is <code>[{name, kind}]</code> in the derived
/// order and the two name lists are what the caller can read through the SSL/TLS and X.509 screens'
/// own declared reads (AD-5), or empty. With an issuer it adds <code>definition:
/// {IssuerEndpoint, SSLConfiguration, ServerCredentials, Metadata, ClientCount, ResourceCount}</code>
/// from the edit tool's fresh read; an issuer no description carries is 404
/// <parameter>OcuPilot.Api.Error.OAUTHISSUERENDPOINTABSENT</parameter>. The registration access
/// token is never part of the answer: no read returns it.</p>
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
        Set tMembersSC = ..Members(.tNames, .tKinds)
        If $$$ISERR(tMembersSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tMembersSC))
            Quit
        }
        Set tMembers = []
        For tI = 1:1:$ListLength(tNames) {
            Set tRow = {}
            Do tRow.%Set("name", $List(tNames, tI), "string")
            Do tRow.%Set("kind", tKinds($List(tNames, tI)), "string")
            Do tMembers.%Push(tRow)
        }
        Do tBody.%Set("members", tMembers)
        Do tBody.%Set("sslConfigurations", ..ReadableNames(..#SSLSCREEN, ..#SSLNAMEFIELD))
        Do tBody.%Set("credentials", ..ReadableNames(..#X509SCREEN, ..#X509NAMEFIELD))
        Set tIssuer = $Get(%request.Data("issuer", 1))
        If tIssuer '= "" {
            Set tReadSC = ..Present(tIssuer, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tDefinition = {}
            For tField = ..#FIELDISSUER, ..#FIELDSSL, ..#FIELDCREDENTIALS {
                Do tDefinition.%Set(tField, ..Text(tFresh, tField), "string")
            }
            Set tMetadata = {}
            If tFresh.%GetTypeOf(..#FIELDMETADATA) = "object" Set tMetadata = tFresh.%Get(..#FIELDMETADATA)
            Do tDefinition.%Set(..#FIELDMETADATA, tMetadata)
            For tField = "ClientCount", "ResourceCount" {
                Do tDefinition.%Set(tField, +tFresh.%Get(tField), "number")
            }
            Do tBody.%Set("definition", tDefinition)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The names screen <var>pScreen</var>'s declared read answers in <var>pField</var>, as a
/// <class>%DynamicArray</class>, issued through that screen's own gate and read (AD-5): a caller the
/// screen refuses, or a read that fails, gets <code>[]</code>.</p>
ClassMethod ReadableNames(pScreen As %String, pField As %String) As %DynamicArray
{
    Set tNames = []
    Try {
        If '##class(OcuPilot.Screen.Gate).Evaluate(pScreen, .tFailedPair) Quit
        Set tReadSC = ##class(OcuPilot.Screen.Read).Execute(pScreen, "", .tResult, .tHttp, .tFault)
        If $$$ISERR(tReadSC) || '$IsObject($Get(tResult)) Quit
        Set tRows = tResult.%Get("rows")
        If '$IsObject(tRows) Quit
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get(pField)
            If tName '= "" Do tNames.%Push(tName)
        }
    } Catch {
        Set tNames = []
    }
    Quit tNames
}

/// <p>The present description <var>pIssuer</var>, read through the edit tool's own port and read type
/// (AD-52), in <var>pFresh</var>. An absent one is an error status with <var>pHttpStatus</var>
/// 404.</p>
ClassMethod Present(pIssuer As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pIssuer
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.OAUTHISSUERENDPOINTABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHISSUERENDPOINTABSENT, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).OAuthViolationCodes()
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
/// <code>Metadata</code> for a member rule, whose member is named by the violation itself.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "ISSUERENDPOINT" Quit ..#FIELDISSUER
    If tPart = "SSLCONFIGURATION" Quit ..#FIELDSSL
    If tPart = "SERVERCREDENTIALS" Quit ..#FIELDCREDENTIALS
    If tPart = "AUTHORIZATIONENDPOINT" Quit ..#FIELDMETADATA _ "." _ ..#AUTHORIZATIONMEMBER
    If tPart = "TOKENENDPOINT" Quit ..#FIELDMETADATA _ "." _ ..#TOKENMEMBER
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

/// <p><var>pObject</var>'s <var>pField</var> as text: a null or absent field as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p><var>pMetadata</var>'s member <var>pMember</var> as text, <code>""</code> when absent.</p>
ClassMethod MemberText(pMetadata As %DynamicObject, pMember As %String) As %String [ Private ]
{
    If '$IsObject(pMetadata) Quit ""
    If pMetadata.%GetTypeOf(pMember) '= "string" Quit ""
    Quit $ZStrip(pMetadata.%Get(pMember), "<>W")
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
