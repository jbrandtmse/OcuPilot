/// <p>The OAuth 2.0 authorization server editor's Save (AD-55): <code>POST /oauth/authorization-server</code>
/// creates this instance's configuration through
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate</class>, and
/// <code>PUT /oauth/authorization-server</code> changes it through
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate</class>. The agent's half is the same tool
/// classes read by the mint and the confirm.</p>
/// <p><b>It resolves everything about a write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the complete-set merge. It
/// mints no proposal and takes no confirm token. Every rule is checked before the first write. The
/// writes then run in order: the configuration (an edit only when its diff is not empty), then the
/// key password when one was supplied, through
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword</class>'s own operation.</p>
/// <p><b>The key password travels beside the fields and never with them</b> (AD-35, AD-56): it is
/// taken out of the body before anything else reads it and cleared before the handler returns. An
/// empty one is not sent. A password refused after the configuration saved answers the saved
/// configuration with <code>passwordRefused</code>, its sentence.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.OAuthAuthorizationServerSave Extends %RegisteredObject
{

/// <p>The tool classes the writes resolve through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate";

Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerForm";

/// <p>The one secret the body carries beside the fields.</p>
Parameter PASSWORDFIELD = "ServerPassword";

/// <p>The keys a body may carry: the template fields and the key password.</p>
Parameter BODYFIELDS = "IssuerEndpoint,Description,AccessTokenInterval,AuthorizationCodeInterval,RefreshTokenInterval,SessionInterval,ClientSecretInterval,SupportedScopes,AllowUnsupportedScope,ReturnRefreshToken,SupportSession,AudRequired,AllowPublicClientRefresh,ForcePKCEForPublicClients,ForcePKCEForConfidentialClients,CustomizationRoles,CustomizationNamespace,AuthenticateClass,SessionClass,ValidateUserClass,GenerateTokenClass,RevokeTokenClass,ServerCredentials,SigningAlgorithm,EncryptionAlgorithm,KeyAlgorithm,SSLConfiguration,Metadata,DefaultScope,ServerPassword";

/// <p>The rules class every route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.OAuthAuthorizationServerRules";

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

/// <p>The one id the configuration is known by (AD-13).</p>
ClassMethod TargetId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>Answer <code>POST /oauth/authorization-server</code>: create the configuration from the body
/// and answer <code>{issuer, readBack}</code> with 201 (AD-58), plus <code>passwordRefused</code>
/// when the password write was refused. A present configuration is refused
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCONFIGTAKEN</parameter> before any write; a broken rule
/// is one 422 <parameter>OcuPilot.Api.Error.OAUTHSERVERVALIDATION</parameter> envelope carrying
/// every violation; any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tPassword = ""
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
        Set tPassword = ..TakeText(tBody, ..#PASSWORDFIELD)
        Set tPerformSC = ..Create(tBody, .tHttp, .tFault, .tViolations, .tIssuer, .tWrite)
        Set (tPasswordReason, tReadBack) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tPassword '= "") Set tPasswordReason = ..StorePassword(tPassword)
        Set tPassword = ""
        ; AD-58: the configuration read back after the Save's last write, over what its own write sent.
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && $Data(tWrite("sent")) Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#CREATETOOL, ..TargetId(), tWrite("sent"), "", ..PortClass(), $Get(tWrite("written")), $Get(tHttp))
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, $Get(tIssuer), tPasswordReason, tReadBack)
    } Catch ex {
        Set tPassword = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /oauth/authorization-server</code>: change the configuration by the body's
/// fields and answer <code>{issuer, readBack}</code> with 200 (AD-58), plus
/// <code>passwordRefused</code> where it applies. An instance with no configuration is 404
/// <parameter>OcuPilot.Api.Error.OAUTHSERVERCONFIGABSENT</parameter> and nothing is sent.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Set tPassword = ""
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
        Set tPassword = ..TakeText(tBody, ..#PASSWORDFIELD)
        Set tPerformSC = ..Update(tBody, .tHttp, .tFault, .tViolations, .tIssuer, .tWrite)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$Get(tViolations) {
            Set tPassword = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCONFIGABSENT, ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGABSENT)
            Quit
        }
        Set (tPasswordReason, tReadBack) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && (tPassword '= "") Set tPasswordReason = ..StorePassword(tPassword)
        Set tPassword = ""
        ; AD-58: the configuration read back after the Save's last write, over what its own write sent.
        If $$$ISOK(tPerformSC) && '$Get(tViolations) && $Data(tWrite("sent")) Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#UPDATETOOL, ..TargetId(), tWrite("sent"), tWrite("fresh"), ..PortClass(), $Get(tWrite("written")), $Get(tHttp))
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, $Get(tIssuer), tPasswordReason, tReadBack)
    } Catch ex {
        Set tPassword = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the configuration from <var>pArgs</var>, whose password has been taken out, once the
/// instance holds none and every rule holds. <var>pIssuer</var> is the issuer sent.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>; a refusal the port answers on a field arrives as a violation too. Once the
/// write reads OK, <var>pWrite</var><code>("sent")</code> is the body it sent and
/// <var>pWrite</var><code>("written")</code> the port's answer, for the caller's read-back after
/// its own follow-up writes (AD-58); otherwise both are undefined.</p>
ClassMethod Create(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pIssuer As %String, Output pWrite) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pIssuer = ""
    Kill pWrite
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        ; AD-54: the vendor's PUT is an upsert, so a configuration somebody made since the form opened
        ; is refused here rather than overwritten.
        Set tReadSC = ..Read(.tFresh, .pHttpStatus, .pFault)
        If $$$ISOK(tReadSC) {
            Set pViolations($Increment(pViolations)) = $ListBuild($Parameter(..#RULES, "FIELDISSUER"), ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGTAKEN)
            Quit
        }
        If +$Get(pHttpStatus) '= 404 {
            Set tSC = tReadSC
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, .pViolations, "create", "")
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), ..TargetId(), "string")
        Set tSC = $ClassMethod(tClass, "ComposeCreate", tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the configuration's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        ; AD-10, AD-55: the set the confirm asks, over the body the write sends, before the port.
        Set tSC = ..Prohibited(tClass, tPayload, [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pIssuer = tPayload.%Get($Parameter(..#RULES, "FIELDISSUER"))
        Set tSC = ..Send(tClass, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
        If $$$ISOK(tSC) Set pWrite("sent") = tPayload, pWrite("written") = $Get(tWritten)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the configuration by the fields <var>pArgs</var> sends, merged over a fresh read through
/// the edit tool's own merge, so a field the caller did not send keeps the instance's value and the
/// body is the complete set (AD-4); an edit that changes no field sends no write. <var>pIssuer</var>
/// is the issuer the configuration holds after it.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s, with
/// <var>pWrite</var><code>("fresh")</code> the fresh read the body was merged over. An instance
/// with no configuration is an error status with <var>pHttpStatus</var> 404 and nothing sent.</p>
ClassMethod Update(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pIssuer As %String, Output pWrite) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pIssuer = ""
    Kill pWrite
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tSC = ..Read(.tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 0
        Set pFault = ""
        Set pIssuer = tFresh.%Get($Parameter(..#RULES, "FIELDISSUER"))
        ; Nothing to change -- a password-only Save -- sends no configuration write.
        If pArgs.%Size() = 0 Quit
        Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, .pViolations, "update", tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, "", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) {
            Do ..PortViolations(pFault, .pViolations)
            Quit
        }
        Set pWrite("sent") = tPayload, pWrite("fresh") = tFresh, pWrite("written") = $Get(tWritten)
        Set pIssuer = tPayload.%Get($Parameter(..#RULES, "FIELDISSUER"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The configuration, read through the edit tool's own port and read type (AD-52). An absent one
/// is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Read(Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = ..TargetId()
    Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#OAUTHSERVERCONFIGABSENT)
    }
    Quit tSC
}

/// <p>Store <var>pPassword</var> as the configuration's key password through the password tool's own
/// write: its pairs, AD-10's set and its port, with a body of the password alone (AD-56 (i)). Answer
/// <code>""</code>, or the refusal's sentence. The password is held in this frame alone and cleared
/// before it returns.</p>
ClassMethod StorePassword(pPassword As %String) As %String
{
    Set tReason = ""
    Set tBody = ""
    Set tSupplied = ""
    Try {
        Set tClass = ..#PASSWORDTOOL
        Set tReason = ..Gated(tClass, "{}", "[]")
        If tReason '= "" Quit
        Set tSupplied = {}
        Do tSupplied.%Set(..#PASSWORDFIELD, pPassword, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod($Parameter(tClass, "DESCRIPTORCLASS"), "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), ..TargetId(), "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) Set tReason = ..FaultReason($Get(tFault))
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set (tBody, tSupplied) = ""
    Quit tReason
}

/// <p>The pairs and AD-10's set for tool <var>pClass</var>'s write carrying <var>pPayloadJson</var>
/// and <var>pDiffJson</var>: <code>""</code> when the write may happen, or the refusal's
/// sentence.</p>
ClassMethod Gated(pClass As %String, pPayloadJson As %String, pDiffJson As %String) As %String [ Private ]
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(pClass, "TOOLNAME"), .tTool)
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tDescriptor = $Parameter(pClass, "DESCRIPTORCLASS")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), ..TargetId(), .tTargetRef)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pClass, "IdArgument"), ..TargetId(), "string")
    Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, pPayloadJson, pDiffJson, tArgs.%ToJSON(), $Username, ..ProhibitedClass(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
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
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make carrying
/// <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status
/// with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), ..TargetId(), .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write with <var>pPayload</var>, through
/// <method>PortClass</method>; <var>pWritten</var> is the port's answer.</p>
ClassMethod Send(pToolClass As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = ..TargetId()
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render an outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{issuer}</code> at <var>pSuccess</var>, with <code>passwordRefused</code> when
/// not empty and <var>pReadBack</var> as <code>readBack</code> when there is one (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pIssuer As %String, pPasswordReason As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
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
    If pPasswordReason '= "" Do tAnswer.%Set("passwordRefused", pPasswordReason, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERVALIDATION, ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION, tDetail)
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
