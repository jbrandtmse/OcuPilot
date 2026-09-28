/// <p>The X.509 form's Save (AD-55): <code>POST /x509</code> imports one credential through
/// <class>OcuPilot.Screen.Tool.X509Import</class>, and <code>PUT /x509/:id</code> changes one
/// through <class>OcuPilot.Screen.Tool.X509Update</class>. The agent's half is the same two tool
/// classes read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list and the payload composition. It mints no proposal and
/// takes no confirm token. An import runs, in order: the caller's pairs (AD-8), the alias's own
/// rules, AD-10's prohibited set over the caller's non-secret fields, the form's rules (the secret
/// checks included), the composed payload, the secrets put on that body, and only then the port. An
/// edit runs the caller's pairs, the fresh read, a check that the body carries only the two lists,
/// the form's rules, the merge over the fresh read (AD-4), the prohibited set over the merged
/// payload and only then the port.</p>
/// <p><b>The certificate, key and password are secrets</b> (AD-35): they join the body after the
/// verdict and the rules, the body is cleared once the port has answered, and nothing here logs,
/// echoes or returns them.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.X509Save Extends %RegisteredObject
{

/// <p>The tool classes the two callers resolve the writes through (AD-55).</p>
Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.X509Import";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.X509Update";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.X509Form";

/// <p>The input property that names the target: the vendor's <code>alias</code> query parameter.</p>
Parameter IDARGUMENT = "Alias";

/// <p>The only keys an edit's body may carry. <code>CAFile</code> is not among them: an edit sends
/// back the instance's own (AD-4, AD-21).</p>
Parameter EDITFIELDS = "OwnerList,PeerNames";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.Security.X509Rules";

/// <p>The port the writes and the edit's fresh read go through, which is the tools' own declaration
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

/// <p>Answer <code>POST /x509</code>: import one credential from the body and answer
/// <code>{alias, readBack}</code> with 201 (AD-58). A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.X509VALIDATION</parameter> envelope carrying every violation; any
/// other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tAlias = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tAlias = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Create(tAlias, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set tBody = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tAlias, $Get(tReadBack))
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /x509/:id</code>: change the credential <var>pId</var> -- one path segment,
/// decoded once here (AD-13) -- from the body's <code>OwnerList</code> and <code>PeerNames</code>,
/// and answer <code>{alias, readBack}</code> with 200 (AD-58). Any other key is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; an alias the instance does not
/// hold is 404 <parameter>OcuPilot.Api.Error.X509ALIASABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tAlias = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tAlias, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONX509ALIASABSENT, ##class(OcuPilot.Api.Error).#X509ALIASABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tAlias, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Import the credential <var>pAlias</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written and the other outputs say nothing. Otherwise an error
/// status carries <var>pHttpStatus</var> and <var>pFault</var>. On success <var>pReadBack</var> is
/// the write's read-back (AD-58); it is <code>""</code> otherwise.</p>
ClassMethod Create(pAlias As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPayload = ""
    Try {
        Do $ClassMethod(..#RULES, "AliasViolation", pAlias, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#IMPORTTOOL
        Set tSecrets = $ClassMethod(tClass, "SecretArguments")
        ; AD-10, AD-55. The set the confirm asks, before the port and before the rules, over the
        ; caller's own fields minus the declared secrets, which the confirm merges only after its
        ; verdict too.
        Set tSC = ..Prohibited(tClass, pAlias, ..CallerFields(pArgs, tSecrets), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pAlias, pArgs, .pViolations, 0, 1, 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tComposeSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the import's payload could not be composed after its rules passed")
            Quit
        }
        ; AD-35: the declared secrets join the body here, after the verdict and the rules, and
        ; nowhere else.
        For tI = 1:1:$ListLength(tSecrets) {
            Set tSecret = $List(tSecrets, tI)
            If pArgs.%GetTypeOf(tSecret) = "string" Do tPayload.%Set(tSecret, pArgs.%Get(tSecret), "string")
        }
        Set tSC = ..Send(tClass, pAlias, tPayload, .pHttpStatus, .pFault, .tWritten)
        ; AD-58: the credential read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pAlias, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPayload = ""
    Quit tSC
}

/// <p>Change the credential <var>pAlias</var> by the lists <var>pArgs</var> sends, merged over a
/// fresh read, so a list the caller did not send keeps the instance's value and the body is the
/// vendor's whole <code>PUT</code> contract (AD-4).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. An alias the instance does not hold is
/// an error status with <var>pHttpStatus</var> 404; a key outside <parameter>EDITFIELDS</parameter>
/// is an error status with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pAlias As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pAlias
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#X509ALIASABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tAllowed = $ListFromString(..#EDITFIELDS)
        Set tIterator = pArgs.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind(tAllowed, tKey) {
                Set pHttpStatus = 400
                Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
                Set tDetail = {"violations": []}
                Do tDetail.%Get("violations").%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
                Do pFault.%Set("detail", tDetail)
                Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
                Quit
            }
        }
        Set tValue = ""
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pAlias, pArgs, .pViolations, 0, 0, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pAlias, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Send(tClass, pAlias, tPayload, .pHttpStatus, .pFault, .tWritten)
        ; AD-58: the credential read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pAlias, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pAlias</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an
/// error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pAlias As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pAlias, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pAlias</var> with <var>pPayload</var>,
/// through <method>PortClass</method>; <var>pWritten</var> is the port's answer.</p>
ClassMethod Send(pToolClass As %String, pAlias As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pAlias
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as
/// one 422 envelope, a refusal as its own envelope, and success as <code>{alias}</code> at
/// <var>pSuccess</var>, with <var>pReadBack</var> as <code>readBack</code> when there is one
/// (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pAlias As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit ..RenderViolations(.pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("alias", pAlias, "string")
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

/// <p>The caller's own body fields, minus the identifying argument and minus every name in
/// <var>pSecrets</var>, as one <class>%DynamicObject</class>: what AD-10's set is asked about on an
/// import. It is not the composed payload, so a field the tool does not admit -- a file path among
/// them -- reaches the set rather than being silently dropped.</p>
ClassMethod CallerFields(pArgs As %DynamicObject, pSecrets As %List = "") As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = ..#IDARGUMENT Continue
        If $ListFind(pSecrets, tKey) Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tFields.%Set(tKey, pArgs.%Get(tKey))
        } Else {
            Do tFields.%Set(tKey, pArgs.%Get(tKey), tType)
        }
    }
    Quit tFields
}

/// <p>Render one <code>(field, code)</code> violation as the 422 envelope.</p>
ClassMethod RenderOne(pField As %String, pCode As %String) As %Status
{
    Kill tViolations
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(pField, pCode)
    Quit ..RenderViolations(.tViolations)
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONX509VALIDATION, ##class(OcuPilot.Api.Error).#X509VALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs
/// (AD-8): <var>pRefused</var> 1 means the envelope is written and the handler writes nothing
/// else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
