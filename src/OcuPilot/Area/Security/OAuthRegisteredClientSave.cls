/// <p>The OAuth 2.0 server client description editor's Save (AD-55): <code>POST /oauth/server-client</code>
/// registers one client through <class>OcuPilot.Screen.Tool.OAuthRegisteredClientCreate</class>, and
/// <code>PUT /oauth/server-client/:id</code> changes one through
/// <class>OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate</class>. The agent's half is the same tool
/// classes read by the mint and the confirm.</p>
/// <p><b>It resolves everything about a write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the complete-set merge. It
/// mints no proposal and takes no confirm token. Every rule is checked before the first write. The
/// writes then run in order: the client (a create, or an edit only when its diff is not empty), then
/// the client secret when one was supplied, through
/// <class>OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret</class>'s own operation.</p>
/// <p><b>The client secret travels beside the fields and never with them</b> (AD-35, AD-56): it is
/// taken out of the body before anything else reads it and cleared before the handler returns. An
/// empty one is not sent. A create of any client type but a public one requires it, because the
/// secret the vendor generates is never shown. A secret refused after the client saved answers the
/// saved client with <code>secretRefused</code>, its sentence.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.OAuthRegisteredClientSave Extends %RegisteredObject
{

/// <p>The tool classes the writes resolve through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate";

Parameter SECRETTOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientForm";

/// <p>The one secret the body carries beside the fields.</p>
Parameter SECRETFIELD = "ClientSecret";

/// <p>The keys a body may carry: the template fields and the client secret.</p>
Parameter BODYFIELDS = "Name,RedirectURL,LaunchURL,Description,ClientType,ClientCredentials,Metadata,DefaultScope,ClientSecret";

/// <p>The rules class every route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.OAuthRegisteredClientRules";

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

/// <p>Answer <code>POST /oauth/server-client</code>: register one client from the body and answer
/// <code>{clientId, name}</code> with 201, plus <code>secretRefused</code> when the secret write was
/// refused. A name any client holds is refused
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTNAMETAKEN</parameter> before any write; a broken rule
/// is one 422 <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTVALIDATION</parameter> envelope carrying
/// every violation; any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tSecret = ""
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
        Set tSecret = ..TakeText(tBody, ..#SECRETFIELD)
        Set tPerformSC = ..Create(tBody, (tSecret '= ""), .tHttp, .tFault, .tViolations, .tId, .tName)
        Set tSecretReason = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tSecret '= "") Set tSecretReason = ..StoreSecret(tId, tSecret)
        Set tSecret = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, $Get(tId), $Get(tName), tSecretReason)
    } Catch ex {
        Set tSecret = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /oauth/server-client/:id</code>: change client <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- by the body's fields, and answer <code>{clientId, name}</code>
/// with 200, plus <code>secretRefused</code> where it applies. A client the instance does not hold is
/// 404 <parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTABSENT</parameter> and nothing is sent.</p>
/// <p>The body's <code>Metadata</code> carries only the members the form changes; the route applies
/// them over the fresh read's members.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tSecret = ""
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
        Set tSecret = ..TakeText(tBody, ..#SECRETFIELD)
        Set tId = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tId, tBody, .tHttp, .tFault, .tViolations, .tName)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$Get(tViolations) {
            Set tSecret = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTABSENT, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTABSENT)
            Quit
        }
        Set tSecretReason = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tSecret '= "") Set tSecretReason = ..StoreSecret(tId, tSecret)
        Set tSecret = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tId, $Get(tName), tSecretReason)
    } Catch ex {
        Set tSecret = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Register a client from <var>pArgs</var>, whose secret has been taken out, once every rule holds
/// and no client holds its name. <var>pSecretSupplied</var> says whether a secret travels beside it.
/// <var>pId</var> is the client id the instance generated and <var>pName</var> the name sent.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a refusal the port answers on a field arrives as a
/// violation too.</p>
ClassMethod Create(pArgs As %DynamicObject, pSecretSupplied As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pId As %String, Output pName As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pId = ""
    Set pName = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tRules = ..#RULES
        Set tSC = $ClassMethod(tRules, "Validate", pArgs, .pViolations, "create", "")
        If $$$ISERR(tSC) Quit
        Set tType = $ClassMethod(tRules, "Text", pArgs, $Parameter(tRules, "FIELDTYPE"))
        If pArgs.%GetTypeOf($Parameter(tRules, "FIELDTYPE")) = "unassigned" Set tType = $ClassMethod(tRules, "Text", $ClassMethod(tRules, "Defaults"), $Parameter(tRules, "FIELDTYPE"))
        If 'pSecretSupplied && (tType '= $Parameter(tRules, "PUBLICTYPE")) Set pViolations($Increment(pViolations)) = $ListBuild(..#SECRETFIELD, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTSECRETREQUIRED)
        Set pName = $ClassMethod(tRules, "Text", pArgs, $Parameter(tRules, "FIELDNAME"))
        ; AD-54: a name any client holds, in any case, is refused rather than registered twice.
        If pName '= "" {
            Set tSC = $ClassMethod(tRules, "NameTaken", pName, .tTaken, ..PortClass())
            If $$$ISERR(tSC) Quit
            If tTaken Set pViolations($Increment(pViolations)) = $ListBuild($Parameter(tRules, "FIELDNAME"), ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTNAMETAKEN)
        }
        If pViolations > 0 Quit
        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the client's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        ; AD-10, AD-55: the set the confirm asks, over the body the write sends, before the port.
        Set tSC = ..Prohibited(tClass, pName, tPayload, [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        If $IsObject($Get(tWritten)) Set pId = tWritten.%Get($Parameter(..PortClass(), "CREATEDFIELD"))
        If pId = "" {
            Set pHttpStatus = 500
            Set tSC = $$$ERROR($$$GeneralError, "the client was registered and the instance answered no client id for it")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change client <var>pId</var> by the fields <var>pArgs</var> sends, merged over a fresh read
/// through the edit tool's own merge, so a field the caller did not send keeps the instance's value
/// and the body is the complete set (AD-4); an edit that changes no field sends no write.
/// <var>pName</var> is the name the client holds after it.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A client the instance does not hold is an
/// error status with <var>pHttpStatus</var> 404 and nothing sent.</p>
ClassMethod Update(pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pName As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pName = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tRules = ..#RULES
        Set tSC = $ClassMethod(tRules, "Present", pId, .tFresh, .pHttpStatus, .pFault, ..PortClass())
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set pName = $ClassMethod(tRules, "Text", tFresh, $Parameter(tRules, "FIELDNAME"))
        ; Nothing to change -- a secret-only Save -- sends no client write.
        If pArgs.%Size() = 0 Quit
        Set tSC = $ClassMethod(tRules, "Validate", pArgs, .pViolations, "update", tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pName = $ClassMethod(tRules, "Text", tPayload, $Parameter(tRules, "FIELDNAME"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store <var>pSecret</var> as client <var>pId</var>'s secret through the secret tool's own write:
/// its pairs, AD-10's set and its port, with a body of the secret alone (AD-56 (i)). Answer
/// <code>""</code>, or the refusal's sentence. The secret is held in this frame alone and cleared
/// before it returns.</p>
ClassMethod StoreSecret(pId As %String, pSecret As %String) As %String
{
    Set tReason = ""
    Set tBody = ""
    Set tSupplied = ""
    Try {
        Set tClass = ..#SECRETTOOL
        Set tReason = ..Gated(tClass, pId)
        If tReason '= "" Quit
        Set tSupplied = {}
        Do tSupplied.%Set(..#SECRETFIELD, pSecret, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod($Parameter(tClass, "DESCRIPTORCLASS"), "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pId, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) Set tReason = ..FaultReason($Get(tFault))
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set (tBody, tSupplied) = ""
    Quit tReason
}

/// <p>The pairs and AD-10's set for tool <var>pClass</var>'s bodyless write on client <var>pId</var>:
/// <code>""</code> when the write may happen, or the refusal's sentence.</p>
ClassMethod Gated(pClass As %String, pId As %String) As %String [ Private ]
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(pClass, "TOOLNAME"), .tTool)
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tDescriptor = $Parameter(pClass, "DESCRIPTORCLASS")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pClass, "IdArgument"), pId, "string")
    Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, "{}", "[]", tArgs.%ToJSON(), $Username, ..ProhibitedClass(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    If $$$ISERR(tGateSC) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    If 'tRefused Quit ""
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tGateCode)
    If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tGateCode)
    Quit tReason
}

/// <p>The sentence a port fault <var>pFault</var> carries, or the kernel's default.</p>
ClassMethod FaultReason(pFault) As %String [ Private ]
{
    If $IsObject(pFault) && (pFault.%Get("reason") '= "") {
        Set tRows = ""
        If pFault.%GetTypeOf("detail") = "object" Set tRows = pFault.%Get("detail").%Get("violations")
        If $IsObject(tRows) && (tRows.%Size() > 0) && (tRows.%Get(0).%Get("reason") '= "") Quit tRows.%Get(0).%Get("reason")
        Quit pFault.%Get("reason")
    }
    Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
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
        If tRow.%Get("field") = "" Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make on <var>pId</var> -- the
/// intended name for a create -- carrying <var>pPayload</var> and <var>pDiff</var>; a
/// <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pId As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Render an outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{clientId, name}</code> at <var>pSuccess</var>, with <code>secretRefused</code>
/// when not empty.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pId As %String, pName As %String, pSecretReason As %String) As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("clientId", pId, "string")
    Do tAnswer.%Set("name", pName, "string")
    If pSecretReason '= "" Do tAnswer.%Set("secretRefused", pSecretReason, "string")
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

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTVALIDATION, ##class(OcuPilot.Api.Error).#OAUTHSERVERCLIENTVALIDATION, tDetail)
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
