/// <p>The OAuth 2.0 resource server editor's Save (AD-55): <code>POST /oauth/resource-server</code>
/// creates one resource server through <class>OcuPilot.Screen.Tool.OAuthResourceServerCreate</class>,
/// and <code>PUT /oauth/resource-server/:id</code> changes one through
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerUpdate</class>. The agent's half is the same tool
/// classes read by the mint and the confirm.</p>
/// <p><b>It resolves everything about a write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the complete-set merge. It
/// mints no proposal and takes no confirm token. Every rule -- the fields' and every service mapping
/// row's -- is checked before the first write. The writes then run in order: the server (an edit only
/// when its diff is not empty), the client secret when one was supplied, each mapping removal, and
/// each mapping addition, the last three through their tools' own operations
/// (<class>OcuPilot.Screen.Tool.OAuthResourceServerSetSecret</class>,
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerRemoveMapping</class>,
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerAddMapping</class>).</p>
/// <p><b>The client secret travels beside the fields and never with them</b> (AD-35, AD-56): it is
/// taken out of the body before anything else reads it and cleared before the handler returns. An
/// empty one is not sent. A write refused after the server saved answers the saved server with
/// <code>secretRefused</code>, its sentence, or <code>mappingsRefused</code>, <code>{count,
/// reason}</code>.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.OAuthResourceServerSave Extends %RegisteredObject
{

/// <p>The tool classes the writes resolve through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerUpdate";

Parameter SECRETTOOL = "OcuPilot.Screen.Tool.OAuthResourceServerSetSecret";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.OAuthResourceServerAddMapping";

Parameter REMOVETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerRemoveMapping";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The one secret, and the two mapping lists the body carries beside the fields.</p>
Parameter SECRETFIELD = "ClientSecret";

Parameter ADDEDFIELD = "mappingsAdded";

Parameter REMOVEDFIELD = "mappingsRemoved";

/// <p>The prefix a mapping row's violation field carries.</p>
Parameter MAPPINGFIELD = "Mappings.";

/// <p>The keys an edit's body may carry; a create's may carry the name too.</p>
Parameter BODYFIELDS = "Enabled,Description,IssuerEndpoint,ScopeRequiredToConnect,Audiences,AccessTokenIsJWT,AlwaysCallIntrospection,ClientId,IntrospectionAuthMethod,UseOIDC,Authenticator,ClientSecret,mappingsAdded,mappingsRemoved";

/// <p>The rules class every route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.OAuthResourceServerRules";

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

/// <p>Answer <code>POST /oauth/resource-server</code>: create one server from the body and answer
/// <code>{name}</code> with 201, plus <code>secretRefused</code> and <code>mappingsRefused</code> when
/// those writes were refused. A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERVALIDATION</parameter> envelope carrying every
/// violation; any other refusal is the port's or the prohibited set's own envelope.</p>
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
        If ..StrayKey(tBody, ..#IDARGUMENT _ "," _ ..#BODYFIELDS, .tStray) {
            Set tSC = ..Unexpected(tStray)
            Quit
        }
        Set tSecret = ..TakeText(tBody, ..#SECRETFIELD)
        Set tAdded = ..TakeList(tBody, ..#ADDEDFIELD)
        Set tRemoved = ..TakeList(tBody, ..#REMOVEDFIELD)
        Set tName = $ClassMethod(..#RULES, "Text", tBody, ..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, tBody, tAdded, tRemoved, .tHttp, .tFault, .tViolations)
        Set (tSecretReason, tMappingsCount, tMappingsReason) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tSecret '= "" Set tSecretReason = ..StoreSecret(tName, tSecret)
            Do ..StoreMappings(tName, tAdded, tRemoved, .tMappingsCount, .tMappingsReason)
        }
        Set tSecret = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tName, tSecretReason, tMappingsCount, tMappingsReason)
    } Catch ex {
        Set tSecret = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /oauth/resource-server/:id</code>: change the server <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- by the body's fields, and answer <code>{name}</code> with
/// 200, plus <code>secretRefused</code> and <code>mappingsRefused</code> where they apply. A server
/// the instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.OAUTHRESOURCESERVERNAMEABSENT</parameter> and nothing is sent.</p>
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
        Set tAdded = ..TakeList(tBody, ..#ADDEDFIELD)
        Set tRemoved = ..TakeList(tBody, ..#REMOVEDFIELD)
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, tAdded, tRemoved, .tHttp, .tFault, .tViolations)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$Get(tViolations) {
            Set tSecret = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERNAMEABSENT, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERNAMEABSENT)
            Quit
        }
        Set (tSecretReason, tMappingsCount, tMappingsReason) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tSecret '= "" Set tSecretReason = ..StoreSecret(tName, tSecret)
            Do ..StoreMappings(tName, tAdded, tRemoved, .tMappingsCount, .tMappingsReason)
        }
        Set tSecret = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName, tSecretReason, tMappingsCount, tMappingsReason)
    } Catch ex {
        Set tSecret = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the server <var>pName</var> from <var>pArgs</var>, whose secret and mapping lists have
/// been taken out, once every field rule and every row of <var>pAdded</var> and <var>pRemoved</var>
/// holds.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a refusal the port answers on a field arrives as a
/// violation too.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, pAdded As %DynamicArray, pRemoved As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
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
        If $$$ISERR(tSC) Quit
        Set tSC = ..MappingRowViolations(pName, pAdded, pRemoved, "", .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the resource server's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the server <var>pName</var> by the fields <var>pArgs</var> sends, merged over a fresh
/// read through the edit tool's own merge, so a field the caller did not send keeps the instance's
/// value and the body is the complete set (AD-4); an edit that changes no field sends no server
/// write.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A server the instance does not hold is an
/// error status with <var>pHttpStatus</var> 404 and nothing sent.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, pAdded As %DynamicArray, pRemoved As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
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
        If (pAdded.%Size() > 0) || (pRemoved.%Size() > 0) {
            Kill tQuery
            Set tQuery($ClassMethod(tClass, "IdParam")) = pName
            Set tType = $Parameter($ClassMethod(tClass, "PortClass"), "MAPPINGSTYPE")
            Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), tType, .tQuery, "", .tMappings, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set pHttpStatus = 0
            Set pFault = ""
            Set tSC = ..MappingRowViolations(pName, pAdded, pRemoved, tMappings, .pViolations)
            If $$$ISERR(tSC) || (pViolations > 0) Quit
        }
        ; Nothing to change -- a secret-only or mappings-only Save -- sends no server write.
        If pArgs.%Size() = 0 Quit

        Set tSC = $ClassMethod(tRules, "Validate", pName, pArgs, .pViolations, "update", 1, tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, pArgs, "", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Append to <var>pViolations</var> every rule a row of <var>pAdded</var> or <var>pRemoved</var>
/// breaks, over the server's <code>MAPPINGS</code> read <var>pMappings</var> (<code>""</code> for a
/// create, which holds none): a row that is not <code>{Service, Key}</code> text, and each row's
/// <method>OcuPilot.Area.Security.OAuthResourceServerRules.MappingViolations</method>.</p>
ClassMethod MappingRowViolations(pName As %String, pAdded As %DynamicArray, pRemoved As %DynamicArray, pMappings As %DynamicObject, ByRef pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    For tList = pRemoved, pAdded {
        Set tMode = $Select(tList = pRemoved: "remove", 1: "add")
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '..MappingRowShaped(tRow) {
                Set pViolations($Increment(pViolations)) = $ListBuild($Extract(..#MAPPINGFIELD, 1, *-1), ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            Set tSC = $ClassMethod(..#RULES, "MappingViolations", pName, tRow.%Get("Service"), tRow.%Get("Key"), tMode, pMappings, ..#MAPPINGFIELD, .tRowViolations)
            If $$$ISERR(tSC) Quit
            For tI = 1:1:$Get(tRowViolations) Set pViolations($Increment(pViolations)) = tRowViolations(tI)
        }
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Whether <var>pRow</var> is <code>{Service, Key}</code>, both text, and nothing else.</p>
ClassMethod MappingRowShaped(pRow) As %Boolean [ Private ]
{
    If '$IsObject(pRow) || 'pRow.%IsA("%Library.DynamicObject") Quit 0
    If (pRow.%GetTypeOf("Service") '= "string") || (pRow.%GetTypeOf("Key") '= "string") Quit 0
    Quit pRow.%Size() = 2
}

/// <p>Store <var>pSecret</var> as server <var>pName</var>'s client secret through the secret tool's own
/// write: its pairs, AD-10's set and its port, with a body of the secret alone (AD-56 (i)). Answer
/// <code>""</code>, or the refusal's sentence. The secret is held in this frame alone and cleared
/// before it returns.</p>
ClassMethod StoreSecret(pName As %String, pSecret As %String) As %String
{
    Set tReason = ""
    Set tBody = ""
    Set tSupplied = ""
    Try {
        Set tClass = ..#SECRETTOOL
        Set tReason = ..Gated(tClass, pName, "{}", "[]", .tTargetRef)
        If tReason '= "" Quit
        Set tSupplied = {}
        Do tSupplied.%Set(..#SECRETFIELD, pSecret, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod($Parameter(tClass, "DESCRIPTORCLASS"), "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pName, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) Set tReason = ..FaultReason($Get(tFault))
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set (tBody, tSupplied) = ""
    Quit tReason
}

/// <p>Remove each mapping of <var>pRemoved</var>, then add each of <var>pAdded</var>, for server
/// <var>pName</var> through the two mapping tools' own writes. <var>pCount</var> is how many were
/// refused and <var>pReason</var> the first refusal's sentence, both <code>""</code> when none
/// was.</p>
ClassMethod StoreMappings(pName As %String, pAdded As %DynamicArray, pRemoved As %DynamicArray, Output pCount As %Integer, Output pReason As %String)
{
    Set pCount = ""
    Set pReason = ""
    For tList = pRemoved, pAdded {
        Set tClass = $Select(tList = pRemoved: ..#REMOVETOOL, 1: ..#ADDTOOL)
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tReason = ..StoreMapping(tClass, pName, tRow.%Get("Service"), tRow.%Get("Key"))
            If tReason = "" Continue
            Set pCount = pCount + 1
            If pReason = "" Set pReason = tReason
        }
    }
}

/// <p>One mapping write of tool <var>pClass</var> for server <var>pName</var>, service
/// <var>pService</var> and key <var>pKey</var>, through the tool's pairs, AD-10's set and its port.
/// Answer <code>""</code>, or the refusal's sentence.</p>
ClassMethod StoreMapping(pClass As %String, pName As %String, pService As %String, pKey As %String) As %String
{
    Set tReason = ""
    Try {
        Set tPayload = {}
        Do tPayload.%Set($Parameter(pClass, "SERVICEFIELD"), pService, "string")
        Do tPayload.%Set($Parameter(pClass, "KEYFIELD"), pKey, "string")
        Set tReason = ..Gated(pClass, pName, tPayload.%ToJSON(), "[]", .tTargetRef)
        If tReason '= "" Quit
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(pClass, ..PortClass(), $ClassMethod(pClass, "Endpoint"), $ClassMethod(pClass, "IdParam"), pName, tPayload.%ToJSON(), "", .tWritten, .tHttp, .tFault)
        If $$$ISERR(tWriteSC) Set tReason = ..FaultReason($Get(tFault))
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Quit tReason
}

/// <p>The pairs and AD-10's set for tool <var>pClass</var>'s write to server <var>pName</var> carrying
/// <var>pPayloadJson</var> and <var>pDiffJson</var>: <code>""</code> when the write may happen, or the
/// refusal's sentence.</p>
ClassMethod Gated(pClass As %String, pName As %String, pPayloadJson As %String, pDiffJson As %String, Output pTargetRef As %String) As %String [ Private ]
{
    Set pTargetRef = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(pClass, "TOOLNAME"), .tTool)
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tDescriptor = $Parameter(pClass, "DESCRIPTORCLASS")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pName, .pTargetRef)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pClass, "IdArgument"), pName, "string")
    Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, pTargetRef, pPayloadJson, pDiffJson, tArgs.%ToJSON(), $Username, ..ProhibitedClass(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    If $$$ISERR(tGateSC) Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    If 'tRefused Quit ""
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tGateCode)
    If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tGateCode)
    Quit tReason
}

/// <p>The sentence a port fault <var>pFault</var> carries, or the kernel's default.</p>
ClassMethod FaultReason(pFault) As %String [ Private ]
{
    If $IsObject(pFault) && (pFault.%Get("reason") '= "") Quit pFault.%Get("reason")
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
/// through <method>PortClass</method>.</p>
ClassMethod Send(pToolClass As %String, pName As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .tAnswer, .pHttpStatus, .pFault)
}

/// <p>Render an outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{name}</code> at <var>pSuccess</var>, with <code>secretRefused</code> and
/// <code>mappingsRefused</code> when not empty.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String, pSecretReason As %String, pMappingsCount As %String, pMappingsReason As %String) As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", pName, "string")
    If pSecretReason '= "" Do tAnswer.%Set("secretRefused", pSecretReason, "string")
    If +pMappingsCount > 0 {
        Set tRefused = {}
        Do tRefused.%Set("count", +pMappingsCount, "number")
        Do tRefused.%Set("reason", pMappingsReason, "string")
        Do tAnswer.%Set("mappingsRefused", tRefused)
    }
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

/// <p>Remove <var>pName</var> from <var>pBody</var> and answer it when it was an array, or
/// <code>[]</code>; any other value answers one row that is not a mapping, which the rules refuse.</p>
ClassMethod TakeList(pBody As %DynamicObject, pName As %String) As %DynamicArray [ Private ]
{
    Set tType = pBody.%GetTypeOf(pName)
    Set tList = []
    If tType = "array" {
        Set tList = pBody.%Get(pName)
    } ElseIf tType '= "unassigned" {
        Do tList.%Push("")
    }
    Do pBody.%Remove(pName)
    Quit tList
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
    Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do tFields.%Remove(..#IDARGUMENT)
    Quit tFields
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERVALIDATION, ##class(OcuPilot.Api.Error).#OAUTHRESOURCESERVERVALIDATION, tDetail)
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
