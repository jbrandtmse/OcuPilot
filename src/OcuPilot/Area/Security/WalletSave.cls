/// <p>The wallet secret form's Save (AD-55): <code>POST /wallet/secret</code> stores one key-value
/// secret through <class>OcuPilot.Screen.Tool.WalletSecretCreate</class>, and
/// <code>PUT /wallet/secret/:id</code> changes one through
/// <class>OcuPilot.Screen.Tool.WalletSecretUpdate</class>. The agent's half is the same two tool
/// classes read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port, the settable field list, the payload composition and the derived
/// <code>Type</code>. It mints no proposal and takes no confirm token. A create runs, in order: the
/// caller's pairs (AD-8), the name's own rules, AD-10's prohibited set over the caller's fields less
/// the value, the form's rules, the composed payload, its derived fields, the value put on that
/// body, and only then the port. An edit runs the caller's pairs, the fresh read (an absent secret
/// is refused before anything is sent, which is what stops the vendor's upsert re-creating one,
/// AD-4), the key and type checks, the form's rules, the merge over the fresh read, the prohibited
/// set over the merged payload, a new value put on the body only when one was entered, and only then
/// the port.</p>
/// <p><b>The value is a secret</b> (AD-35): it joins the body after the verdict and the rules, the
/// body is cleared once the port has answered, and nothing here logs, echoes or returns it.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.WalletSave Extends %RegisteredObject
{

/// <p>The tool classes the two callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.WalletSecretCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WalletSecretUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretForm";

/// <p>The input property that names the target: the vendor's <code>name</code> query parameter.</p>
Parameter IDARGUMENT = "Name";

/// <p>The only keys an edit's body may carry.</p>
Parameter EDITFIELDS = "Usage,RequireTLS,AllowedHosts,Secret";

/// <p>The value's field, and the read's type field with the one type an edit changes.</p>
Parameter SECRETFIELD = "Secret";

Parameter TYPEFIELD = "Type";

Parameter KEYVALUETYPE = "%Wallet.KeyValue";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.Security.WalletRules";

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

/// <p>Answer <code>POST /wallet/secret</code>: store one secret from the body and answer
/// <code>{name}</code> with 201. A broken rule is one 422
/// <parameter>OcuPilot.Api.Error.WALLETVALIDATION</parameter> envelope carrying every violation; any
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
        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tViolations)
        Set tBody = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tName)
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /wallet/secret/:id</code>: change the secret <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- from the body's settings and optional new value, and answer
/// <code>{name}</code> with 200. Any other key is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a secret the instance does not
/// hold is 404 <parameter>OcuPilot.Api.Error.WALLETNAMEABSENT</parameter>; one that is not a
/// key-value secret is 422 <parameter>OcuPilot.Api.Error.WALLETTYPEUNSUPPORTED</parameter>.</p>
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
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations)
        Set tBody = ""
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONWALLETNAMEABSENT, ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName)
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Store the key-value secret <var>pName</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written and the other outputs say nothing. Otherwise an error
/// status carries <var>pHttpStatus</var> and <var>pFault</var>.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPayload = ""
    Try {
        Do $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#CREATETOOL
        Set tSecrets = $ClassMethod(tClass, "SecretArguments")
        ; AD-10, AD-55. The set the confirm asks, before the port and before the rules, over the
        ; caller's own fields less the declared secret, which the confirm merges only after its
        ; verdict too.
        Set tSC = ..Prohibited(tClass, pName, ..CallerFields(pArgs, tSecrets), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, 1, 1, 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; The value joins the body below, so it is composed from the settings alone and never
        ; reaches a diff.
        Set tSettings = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tSettings.%Remove(..#SECRETFIELD)
        Set tComposeSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tSettings, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        Set tSettings = ""
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the secret's payload could not be composed after its rules passed")
            Quit
        }
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        ; AD-35: the value joins the body here, after the verdict and the rules, and nowhere else.
        Do tPayload.%Set(..#SECRETFIELD, pArgs.%Get(..#SECRETFIELD), "string")
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPayload = ""
    Quit tSC
}

/// <p>Change the key-value secret <var>pName</var> by the settings <var>pArgs</var> sends, merged
/// over a fresh read, so a setting the caller did not send keeps the instance's value (AD-4), and
/// with a new value only when <var>pArgs</var> carries a non-empty one.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A secret the instance does not hold is an
/// error status with <var>pHttpStatus</var> 404, and nothing is sent; a key outside
/// <parameter>EDITFIELDS</parameter> one with <var>pHttpStatus</var> 400; a secret of another type
/// one with <var>pHttpStatus</var> 422.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPayload = ""
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT)
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

        If tFresh.%Get(..#TYPEFIELD) '= ..#KEYVALUETYPE {
            Set pHttpStatus = 422
            Set tReason = ##class(OcuPilot.Api.Error).#REASONWALLETTYPEUNSUPPORTED
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#WALLETTYPEUNSUPPORTED, tReason)
            Set tDetail = {"violations": []}
            Do tDetail.%Get("violations").%Push({"field": (..#TYPEFIELD), "code": (##class(OcuPilot.Api.Error).#WALLETTYPEUNSUPPORTED), "reason": (tReason)})
            Do pFault.%Set("detail", tDetail)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#WALLETTYPEUNSUPPORTED)
            Quit
        }

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, 0, 0, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; The value is merged onto the body after the verdict below, never over the fresh read,
        ; which carries none.
        Set tSettings = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tSettings.%Remove(..#SECRETFIELD)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tSettings, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        Set tSettings = ""
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        ; AD-35: a new value joins the body here, after the verdict, and only when one was
        ; entered; an empty one would change nothing, since the vendor keeps the stored value.
        If (pArgs.%GetTypeOf(..#SECRETFIELD) = "string") && (pArgs.%Get(..#SECRETFIELD) '= "") {
            Do tPayload.%Set(..#SECRETFIELD, pArgs.%Get(..#SECRETFIELD), "string")
        }
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPayload = ""
    Quit tSC
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an
/// error status with a 403 fault.</p>
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

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as
/// one 422 envelope, a refusal as its own envelope, and success as <code>{name}</code> at
/// <var>pSuccess</var>.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String) As %Status [ Private ]
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
/// <var>pSecrets</var>, as one <class>%DynamicObject</class>: what AD-10's set is asked about on a
/// create. It is not the composed payload, so a field the tool does not admit reaches the set rather
/// than being silently dropped.</p>
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
    Set tValue = ""
    Quit tFields
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONWALLETVALIDATION, ##class(OcuPilot.Api.Error).#WALLETVALIDATION, tDetail)
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
