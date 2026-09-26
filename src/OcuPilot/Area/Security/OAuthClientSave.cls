/// <p>The OAuth 2.0 client configuration editor's Save (AD-55): <code>POST
/// /oauth/client-configuration</code> creates one configuration through
/// <class>OcuPilot.Screen.Tool.OAuthClientCreate</class>, and <code>PUT
/// /oauth/client-configuration/:id</code> changes one through
/// <class>OcuPilot.Screen.Tool.OAuthClientUpdate</class>. The agent's half is the same tool classes
/// read by the mint and the confirm.</p>
/// <p><b>It resolves everything about a write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the complete-set expansion.
/// It mints no proposal and takes no confirm token. A create runs, in order: the caller's pairs
/// (AD-8), a check that the body carries only the editor's fields, the name's presence and shape,
/// AD-10's prohibited set over the caller's non-secret fields, the form's rules (the name look-up
/// among them), the composed payload, its expansion, and only then the write. An edit runs the
/// caller's pairs, the body check, the fresh read, the form's rules over the fields it changes, the
/// changed metadata members applied over the fresh read's, the merge (AD-4), the prohibited set over
/// the merged payload, the expansion, and only then the write; an edit that changes no field sends no
/// configuration write.</p>
/// <p><b>Four secrets travel beside the fields and never with them</b> (AD-35, AD-56): the client
/// secret, the key password and the registration access token are taken out of the body before
/// anything else reads it and sent after the configuration saved, through
/// <class>OcuPilot.Screen.Tool.OAuthClientSetSecrets</class>'s own write; the initial access token is
/// the chosen server description's, stored through
/// <method>OcuPilot.Area.Security.OAuthServerSave.StoreToken</method>. An empty one is not sent. A
/// write refused after the configuration saved answers the saved configuration with
/// <code>secretsRefused</code> or <code>tokenRefused</code>, its sentence.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.OAuthClientSave Extends %RegisteredObject
{

/// <p>The tool classes the writes resolve through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthClientCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthClientUpdate";

Parameter SECRETSTOOL = "OcuPilot.Screen.Tool.OAuthClientSetSecrets";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientForm";

/// <p>The input property that names the target: the application name.</p>
Parameter IDARGUMENT = "ApplicationName";

/// <p>The client's own secrets, and the server description's one.</p>
Parameter SECRETFIELDS = "ClientSecret,ClientPassword,RegistrationAccessToken";

Parameter TOKENFIELD = "InitialAccessToken";

/// <p>The keys an edit's body may carry; a create's may carry the application name too.</p>
Parameter BODYFIELDS = "ServerDefinition,Enabled,Description,ClientType,SSLConfiguration,RedirectionEndpoint,JWTAudience,JWTInterval,ClientId,ClientCredentials,Metadata,DefaultScope,ClientSecret,ClientPassword,RegistrationAccessToken,InitialAccessToken";

/// <p>The rules class every route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.OAuthClientRules";

/// <p>The server description's own Save, whose token write this Save reuses.</p>
Parameter SERVERSAVE = "OcuPilot.Area.Security.OAuthServerSave";

/// <p>The port the writes and the fresh read go through, which is the tools' own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
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

/// <p>Answer <code>POST /oauth/client-configuration</code>: create one configuration from the body
/// and answer <code>{applicationName}</code> with 201, plus <code>secretsRefused</code> and
/// <code>tokenRefused</code> when those writes were refused. A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.OAUTHCLIENTVALIDATION</parameter> envelope carrying every
/// violation; any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set (tSecrets, tToken) = ""
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
        If ..StrayKey(tBody, ..#IDARGUMENT _ "," _ ..#BODYFIELDS, .tStray) {
            Set tSC = ..Unexpected(tStray)
            Quit
        }
        Set tSecrets = ..TakeSecrets(tBody)
        Set tToken = ..TakeText(tBody, ..#TOKENFIELD)
        Set tName = $ClassMethod(..#RULES, "Text", tBody, ..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer)
        Set (tSecretsReason, tTokenReason) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tSecrets.%Size() > 0 Set tSecretsReason = ..StoreSecrets(tName, tSecrets)
            If tToken '= "" Set tTokenReason = ..StoreToken($ClassMethod(..#RULES, "Text", tBody, "ServerDefinition"), tToken)
        }
        Set (tSecrets, tToken) = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tName, tSecretsReason, tTokenReason, $Get(tAnswer))
    } Catch ex {
        Set (tSecrets, tToken) = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /oauth/client-configuration/:id</code>: change the configuration <var>pId</var>
/// -- one path segment, decoded once here (AD-13) -- by the body's fields, and answer
/// <code>{applicationName}</code> with 200, plus <code>registrationNotUpdated</code>,
/// <code>secretsRefused</code> and <code>tokenRefused</code> where they apply. A configuration the
/// instance does not hold is 404 <parameter>OcuPilot.Api.Error.OAUTHAPPLICATIONNAMEABSENT</parameter>
/// and nothing is sent.</p>
/// <p>The body's <code>Metadata</code> carries only the members the form changes, a cleared one as
/// <code>""</code> or <code>[]</code>; the route applies them over the fresh read's members.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set (tSecrets, tToken) = ""
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
        Set tSecrets = ..TakeSecrets(tBody)
        Set tToken = ..TakeText(tBody, ..#TOKENFIELD)
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$Get(tViolations) {
            Set (tSecrets, tToken) = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHAPPLICATIONNAMEABSENT, ##class(OcuPilot.Api.Error).#OAUTHAPPLICATIONNAMEABSENT)
            Quit
        }
        Set (tSecretsReason, tTokenReason) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tSecrets.%Size() > 0 Set tSecretsReason = ..StoreSecrets(tName, tSecrets)
            If tToken '= "" Set tTokenReason = ..StoreToken($Get(tServer), tToken)
        }
        Set (tSecrets, tToken) = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName, tSecretsReason, tTokenReason, $Get(tAnswer))
    } Catch ex {
        Set (tSecrets, tToken) = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the configuration <var>pName</var> from <var>pArgs</var>, whose secrets have been taken
/// out, with the vendor's answer in <var>pAnswer</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a refusal the port answers on a field arrives as a
/// violation too.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pAnswer) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pAnswer = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        ; The name's presence and shape first, with no look-up: the set's reference is keyed by it.
        Set tSC = $ClassMethod(..#RULES, "NameViolation", pName, 0, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-10, AD-55: the set the confirm asks, over the caller's own fields, before the port.
        Set tSC = ..Prohibited(tClass, pName, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, "create", 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the configuration's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the configuration <var>pName</var> by the fields <var>pArgs</var> sends, merged over a
/// fresh read, so a field the caller did not send keeps the instance's value and the body is the
/// complete set (AD-4). <var>pServer</var> is the server description ID the configuration holds after
/// the write; <var>pAnswer</var> the vendor's answer, or <code>""</code> when nothing was sent.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A configuration the instance does not
/// hold is an error status with <var>pHttpStatus</var> 404 and nothing sent.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pAnswer, Output pServer As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pAnswer = ""
    Set pServer = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tRules = ..#RULES
        Set tSC = $ClassMethod(tRules, "Present", pName, .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set pServer = $ClassMethod(tRules, "Text", tFresh, "ServerDefinition")
        ; Nothing to change -- a secrets-only Save, or fields re-sent as stored -- sends no
        ; configuration write: a vendor save writes the stored registration access token into the
        ; audit database again (DW-1640).
        If pArgs.%Size() = 0 Quit

        Set tSC = $ClassMethod(tRules, "Validate", pName, pArgs, .pViolations, "update", 1, tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; The members the form changed, applied over the fresh read's: the tool's Metadata argument is
        ; the whole metadata the configuration will hold.
        Set tArgs = ..Copy(pArgs)
        If tArgs.%GetTypeOf("Metadata") = "object" Do tArgs.%Set("Metadata", ..MergedMetadata(tFresh, tArgs.%Get("Metadata")))

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, "", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pServer = $ClassMethod(tRules, "Text", tPayload, "ServerDefinition")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The metadata <var>pFresh</var> holds with each member <var>pChanges</var> names applied: a
/// member set to <code>""</code> or <code>[]</code> is removed, which the expansion then sends empty;
/// any other value replaces the stored one. The caller has held <var>pChanges</var> to the rules.</p>
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

/// <p>Store <var>pSecrets</var> -- the client's own declared secrets, each non-empty -- for
/// configuration <var>pName</var> through the secrets tool's own write: its pairs, AD-10's set and
/// its port, with a body of those secrets alone (AD-56 (i)). Answer <code>""</code>, or the
/// refusal's sentence. The secrets are held in this frame alone and cleared before it returns.</p>
ClassMethod StoreSecrets(pName As %String, pSecrets As %DynamicObject) As %String
{
    Set tReason = ""
    Set tBody = ""
    Try {
        Set tClass = ..#SECRETSTOOL
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pName, "string")
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
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, pSecrets, $ClassMethod(tDescriptor, "SecretArguments"))
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pName, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") Set tReason = tFault.%Get("reason")
        }
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set tBody = ""
    Quit tReason
}

/// <p>Store <var>pToken</var> as the initial access token of the server description whose ID is
/// <var>pServerId</var>, through that description's own token write
/// (<method>OcuPilot.Area.Security.OAuthServerSave.StoreToken</method>), and answer <code>""</code>
/// or the refusal's sentence. The description is named by its issuer, read through the port.</p>
ClassMethod StoreToken(pServerId As %String, pToken As %String) As %String
{
    Set tIssuer = ""
    Try {
        Kill tQuery
        Set tQuery($Parameter("OcuPilot.Port.OAuthClientPort", "SERVERQUERY")) = pServerId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $Parameter("OcuPilot.Port.OAuthClientPort", "SERVERENDPOINT"), "GET", .tQuery, "", .tServer, .tHttp, .tFault)
        If $$$ISOK(tSC) && $IsObject($Get(tServer)) Set tIssuer = $ClassMethod(..#RULES, "Text", tServer, "IssuerEndpoint")
    } Catch {
        Set tIssuer = ""
    }
    If tIssuer = "" Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Quit $ClassMethod(..#SERVERSAVE, "StoreToken", tIssuer, pToken)
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

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error
/// status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pName</var> with <var>pPayload</var>,
/// through <method>PortClass</method>, the vendor's answer in <var>pAnswer</var>.</p>
ClassMethod Send(pToolClass As %String, pName As %String, pPayload As %DynamicObject, Output pAnswer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pAnswer, .pHttpStatus, .pFault)
}

/// <p>Render an outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{applicationName}</code> at <var>pSuccess</var>, with
/// <code>registrationNotUpdated</code> from the port's answer <var>pAnswer</var>,
/// <code>secretsRefused</code> and <code>tokenRefused</code> when not empty.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String, pSecretsReason As %String, pTokenReason As %String, pAnswer) As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("applicationName", pName, "string")
    If $IsObject(pAnswer) && (pAnswer.%GetTypeOf("registrationNotUpdated") = "string") Do tAnswer.%Set("registrationNotUpdated", pAnswer.%Get("registrationNotUpdated"), "string")
    If pSecretsReason '= "" Do tAnswer.%Set("secretsRefused", pSecretsReason, "string")
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

/// <p>Remove the client's declared secrets from <var>pBody</var> and answer the non-empty ones as one
/// object. A secret that is not a string is dropped.</p>
ClassMethod TakeSecrets(pBody As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tSecrets = {}
    For tI = 1:1:$Length(..#SECRETFIELDS, ",") {
        Set tName = $Piece(..#SECRETFIELDS, ",", tI)
        Set tValue = ..TakeText(pBody, tName)
        If tValue '= "" Do tSecrets.%Set(tName, tValue, "string")
    }
    Quit tSecrets
}

/// <p>Remove <var>pName</var> from <var>pBody</var> and answer it when it was a string, or
/// <code>""</code>.</p>
ClassMethod TakeText(pBody As %DynamicObject, pName As %String) As %String [ Private ]
{
    Set tValue = ""
    If pBody.%GetTypeOf(pName) = "string" Set tValue = pBody.%Get(pName)
    Do pBody.%Remove(pName)
    Quit tValue
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

/// <p>The caller's own body fields, minus the identifying argument: what AD-10's set is asked about
/// on a create.</p>
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#OAUTHCLIENTVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs
/// (AD-8), before anything is read or sent.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
