/// <p>The OAuth 2.0 server description editor's Save and Discover (AD-55, AD-27):
/// <code>POST /oauth/server-description</code> creates one description through
/// <class>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate</class>, <code>PUT
/// /oauth/server-description/:id</code> changes one through
/// <class>OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate</class>, and <code>POST
/// /oauth/server-description/discover</code> fetches an issuer's published metadata into the form,
/// saving nothing. The agent's half is the same tool classes read by the mint and the confirm.</p>
/// <p><b>It resolves everything about a write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the complete-set
/// expansion. It mints no proposal and takes no confirm token. A create runs, in order: the caller's
/// pairs (AD-8), AD-10's prohibited set over the caller's non-secret fields, the form's rules, the
/// composed payload, its expansion, and only then the port. An edit runs the caller's pairs, the
/// fresh read, a check that the body carries only the editor's fields, the metadata members it
/// changes applied over the fresh read's, the form's rules, the merge over the fresh read (AD-4), the
/// prohibited set over the merged payload, the expansion, and only then the port. An edit may rename
/// the issuer.</p>
/// <p><b>The registration access token is a secret</b> (AD-35, AD-56): it is taken out of the body
/// before anything else reads it, sent after a successful create or edit through
/// <class>OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken</class>'s own write with a body of
/// exactly <code>{InitialAccessToken}</code>, and never logged, echoed or returned. A token the
/// instance refuses answers the saved description with <code>tokenRefused</code>, the refusal's
/// sentence.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.OAuthServerSave Extends %RegisteredObject
{

/// <p>The tool classes the writes resolve through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate";

Parameter TOKENTOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm";

/// <p>The input property that names the target: the issuer endpoint.</p>
Parameter IDARGUMENT = "IssuerEndpoint";

/// <p>The one secret the editor's body may carry.</p>
Parameter SECRETFIELD = "InitialAccessToken";

/// <p>The keys a Save's body may carry.</p>
Parameter BODYFIELDS = "IssuerEndpoint,SSLConfiguration,ServerCredentials,Metadata,InitialAccessToken";

/// <p>The keys a Discover's body may carry.</p>
Parameter DISCOVERFIELDS = "IssuerEndpoint,SSLConfiguration";

/// <p>The rules class every route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.OAuthServerRules";

/// <p>The port the writes, the fresh read and the discovery go through, which is the tools' own
/// declaration (AD-52). Overridable so a fixture can observe what was sent; production never
/// overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /oauth/server-description</code>: create one description from the body and
/// answer <code>{issuer}</code> with 201, plus <code>tokenRefused</code> when the body's token was
/// refused. A broken rule is one 422 <parameter>OcuPilot.Api.Error.OAUTHVALIDATION</parameter>
/// envelope carrying every violation; any other refusal is the port's or the prohibited set's own
/// envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tToken = ""
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ..BadBody()
            Quit
        }
        If ..StrayKey(tBody, ..#BODYFIELDS, .tStray) {
            Set tSC = ..Unexpected(tStray)
            Quit
        }
        Set tToken = ..TakeSecret(tBody)
        Set tIssuer = ##class(OcuPilot.Area.Security.OAuthServerRules).Text(tBody, ..#IDARGUMENT)
        Set tPerformSC = ..Create(tIssuer, tBody, .tHttp, .tFault, .tViolations)
        Set tTokenReason = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tToken '= "") Set tTokenReason = ..StoreToken(tIssuer, tToken)
        Set tToken = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tIssuer, tTokenReason)
    } Catch ex {
        Set tToken = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /oauth/server-description/:id</code>: change the description <var>pId</var> --
/// one path segment, decoded once here (AD-13) -- by the body's fields, and answer
/// <code>{issuer}</code> with 200, the issuer being the new one after a rename. A key outside the
/// editor's is 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a description the
/// instance does not hold is 404 <parameter>OcuPilot.Api.Error.OAUTHISSUERENDPOINTABSENT</parameter>
/// and nothing is sent.</p>
/// <p>The body's <code>Metadata</code> carries only the members the form changes, a cleared one as
/// <code>""</code> or <code>[]</code>; the route applies them over the fresh read's members, so the
/// tool's argument is the whole metadata the description will hold.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tToken = ""
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ..BadBody()
            Quit
        }
        If ..StrayKey(tBody, ..#BODYFIELDS, .tStray) {
            Set tSC = ..Unexpected(tStray)
            Quit
        }
        Set tToken = ..TakeSecret(tBody)
        Set tIssuer = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tIssuer, tBody, .tNewIssuer, .tHttp, .tFault, .tViolations)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$Get(tViolations) {
            Set tToken = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHISSUERENDPOINTABSENT, ##class(OcuPilot.Api.Error).#OAUTHISSUERENDPOINTABSENT)
            Quit
        }
        Set tTokenReason = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tToken '= "") Set tTokenReason = ..StoreToken(tNewIssuer, tToken)
        Set tToken = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, $Get(tNewIssuer, tIssuer), tTokenReason)
    } Catch ex {
        Set tToken = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /oauth/server-description/discover</code> with body
/// <code>{IssuerEndpoint, SSLConfiguration}</code>: the issuer's published metadata, as
/// <code>{issuer, metadata}</code> with 200, fetched through
/// <method>OcuPilot.Port.OAuthServerPort.Discover</method> and saved nowhere (AD-27). A broken rule
/// is the 422 violations envelope; a failed fetch is the port's 422 naming its cause.</p>
ClassMethod HandleDiscover() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ..BadBody()
            Quit
        }
        If ..StrayKey(tBody, ..#DISCOVERFIELDS, .tStray) {
            Set tSC = ..Unexpected(tStray)
            Quit
        }
        Set tRules = ..#RULES
        Set tIssuer = $ClassMethod(tRules, "Text", tBody, ..#IDARGUMENT)
        Set tSSL = $ClassMethod(tRules, "Text", tBody, "SSLConfiguration")
        Kill tViolations
        Set tViolations = 0
        Set tRuleSC = $ClassMethod(tRules, "IssuerViolation", tIssuer, 0, "", .tViolations)
        If $$$ISERR(tRuleSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tRuleSC))
            Quit
        }
        If tSSL = "" Set tViolations($Increment(tViolations)) = $ListBuild("SSLConfiguration", ##class(OcuPilot.Api.Error).#OAUTHSSLCONFIGURATIONREQUIRED)
        If tViolations > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Set tDiscoverSC = $ClassMethod(..PortClass(), "Discover", tIssuer, tSSL, .tMetadata, .tHttp, .tFault)
        If $$$ISERR(tDiscoverSC) {
            Set tSC = ..Answer(tDiscoverSC, 0, $Get(tHttp), $Get(tFault), 200, tIssuer, "")
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("issuer", tIssuer, "string")
        Do tAnswer.%Set("metadata", tMetadata)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the description <var>pIssuer</var> from <var>pArgs</var>, whose token has been taken
/// out.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a refusal the port answers on a field arrives as a
/// violation too.</p>
ClassMethod Create(pIssuer As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = $ClassMethod(..#RULES, "Validate", pIssuer, pArgs, .pViolations, "create", 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-10, AD-55: the set the confirm asks, over the caller's own fields.
        Set tSC = ..Prohibited(tClass, pIssuer, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the description's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pIssuer, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the description <var>pIssuer</var> by the fields <var>pArgs</var> sends, merged over a
/// fresh read, so a field the caller did not send keeps the instance's value and the body is the
/// complete set (AD-4). <var>pNewIssuer</var> is the issuer the description carries after the
/// write.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A description the instance does not hold
/// is an error status with <var>pHttpStatus</var> 404 and nothing sent.</p>
ClassMethod Update(pIssuer As %String, pArgs As %DynamicObject, Output pNewIssuer As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pNewIssuer = pIssuer
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tRules = ..#RULES
        Set tSC = $ClassMethod(tRules, "Present", pIssuer, .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""

        ; The members the form changed, held to their names and shapes, then applied over the fresh
        ; read's: the tool's Metadata argument is the whole metadata the description will hold.
        Set tArgs = ..Copy(pArgs)
        If tArgs.%GetTypeOf("Metadata") = "object" {
            Set tSC = $ClassMethod(tRules, "MemberViolations", tArgs.%Get("Metadata"), .pViolations)
            If $$$ISERR(tSC) || (pViolations > 0) Quit
            Do tArgs.%Set("Metadata", ..MergedMetadata(tFresh, tArgs.%Get("Metadata")))
        }
        Set tSC = $ClassMethod(tRules, "Validate", pIssuer, tArgs, .pViolations, "update", 1, tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, "", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, pIssuer, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pIssuer, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pNewIssuer = tPayload.%Get(..#IDARGUMENT)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The metadata <var>pFresh</var> holds with each member <var>pChanges</var> names applied: a
/// member set to <code>""</code>, <code>[]</code> or <code>null</code> is removed, which the
/// expansion then sends empty; any other value replaces the stored one.</p>
ClassMethod MergedMetadata(pFresh As %DynamicObject, pChanges As %DynamicObject) As %DynamicObject
{
    Set tMerged = {}
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Metadata") = "object") Set tMerged = ..Copy(pFresh.%Get("Metadata"))
    Set tIterator = pChanges.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        Set tType = pChanges.%GetTypeOf(tMember)
        If (tType = "null") || ((tType = "string") && (tValue = "")) || ((tType = "array") && (tValue.%Size() = 0)) {
            Do tMerged.%Remove(tMember)
        } ElseIf (tType = "array") || (tType = "object") {
            Do tMerged.%Set(tMember, ..Copy(tValue))
        } Else {
            Do tMerged.%Set(tMember, tValue, tType)
        }
    }
    Quit tMerged
}

/// <p>Store <var>pToken</var> as description <var>pIssuer</var>'s registration access token through
/// the token tool's own write -- its pairs, AD-10's set and its port, with a body of exactly
/// <code>{InitialAccessToken}</code> (AD-56 (i)) -- and answer <code>""</code>, or the refusal's
/// sentence when the write is refused. The token is held in this frame alone and cleared before it
/// returns.</p>
ClassMethod StoreToken(pIssuer As %String, pToken As %String) As %String
{
    Set tReason = ""
    Set tSupplied = ""
    Set tBody = ""
    Try {
        Set tClass = ..#TOKENTOOL
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pIssuer, .tTargetRef)
        If $$$ISERR(tSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pIssuer, "string")
        Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, "{}", "[]", tArgs.%ToJSON(), $Username, ..ProhibitedClass(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
        If $$$ISERR(tGateSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        If tRefused {
            Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tGateCode)
            If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tGateCode)
            Quit
        }
        Set tSupplied = {}
        Do tSupplied.%Set(..#SECRETFIELD, pToken, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod(tDescriptor, "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pIssuer, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") Set tReason = tFault.%Get("reason")
        }
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set tSupplied = ""
    Set tBody = ""
    Quit tReason
}

/// <p>Move the <code>OAUTH.*</code> rows a port fault carries in <code>detail.violations</code> into
/// <var>pViolations</var>, so a refusal the port answers on a field answers as the form's own
/// 422.</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $Piece(tRow.%Get("code"), ".", 1) '= "OAUTH" Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pIssuer</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an
/// error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pIssuer As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pIssuer, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pIssuer</var> with <var>pPayload</var>,
/// through <method>PortClass</method>.</p>
ClassMethod Send(pToolClass As %String, pIssuer As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pIssuer
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .tAnswer, .pHttpStatus, .pFault)
}

/// <p>Render an outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{issuer}</code> at <var>pSuccess</var>, with <code>tokenRefused</code> when
/// <var>pTokenReason</var> is not empty.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pIssuer As %String, pTokenReason As %String) As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("issuer", pIssuer, "string")
    If pTokenReason '= "" Do tAnswer.%Set("tokenRefused", pTokenReason, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(pSuccess, tAnswer)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Remove the declared secret from <var>pBody</var> and answer it, or <code>""</code>. A secret
/// that is not a string is dropped.</p>
ClassMethod TakeSecret(pBody As %DynamicObject) As %String [ Private ]
{
    Set tSecret = ""
    If pBody.%GetTypeOf(..#SECRETFIELD) = "string" Set tSecret = pBody.%Get(..#SECRETFIELD)
    Do pBody.%Remove(..#SECRETFIELD)
    Quit tSecret
}

/// <p>Whether <var>pBody</var> carries a key outside <var>pAllowed</var>, the first in
/// <var>pKey</var>.</p>
ClassMethod StrayKey(pBody As %DynamicObject, pAllowed As %String, Output pKey As %String) As %Boolean [ Private ]
{
    Set pKey = ""
    Set tAllowed = $ListFromString(pAllowed)
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tAllowed, tKey) {
            Set pKey = tKey
            Quit
        }
    }
    Quit (pKey '= "")
}

/// <p>The 400 a key outside the editor's fields answers, on that field.</p>
ClassMethod Unexpected(pKey As %String) As %Status [ Private ]
{
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (pKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tDetail)
}

/// <p>The unreadable-body refusal every JSON handler gives.</p>
ClassMethod BadBody() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
}

/// <p>The caller's own body fields, minus the identifying argument, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on a create.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = ..Copy(pArgs)
    Do tFields.%Remove(..#IDARGUMENT)
    Quit tFields
}

/// <p>A deep copy of <var>pObject</var>.</p>
ClassMethod Copy(pObject As %DynamicAbstractObject) As %DynamicAbstractObject [ Private ]
{
    Quit ##class(%DynamicAbstractObject).%FromJSON(pObject.%ToJSON())
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONOAUTHVALIDATION, ##class(OcuPilot.Api.Error).#OAUTHVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs
/// (AD-8), before anything is read or sent: <var>pRefused</var> 1 means the envelope is written and
/// the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
