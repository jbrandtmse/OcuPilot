/// <p>The authentication options' Save (AD-55, Story 18.8): <code>PUT /authentication-options</code> changes
/// the instance's authentication and web session options through
/// <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class>, the tool the agent's mint and confirm read. An SMTP
/// password the body carries is written afterwards, by
/// <class>OcuPilot.Screen.Tool.AuthOptionsSmtpPassword</class>'s own operation (AD-56 (i)).</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request types, the
/// port, the settable fields, the merge, the consequence and the pairs, each asked before anything is sent. It
/// mints no proposal and takes no confirm token. It runs, in this order: the caller's pairs, both tools' included
/// (AD-8); the per-target lock (AD-34); the password taken out of the body; the rules over the arguments; the
/// fresh read; the merge; the rules over the payload it would send; AD-10's prohibited set; the merge
/// <code>PUT</code>; the password write; and the read-back (AD-58), which reports the password written and never
/// reads it. A merge whose diff has no row sends nothing.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.Security.AuthOptionsSave Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

/// <p>The tool whose operation writes the SMTP password (AD-56 (i)).</p>
Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.AuthOptionsSmtpPassword";

/// <p>The screen whose declared pairs gate the route, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuthOptions";

/// <p>The rules class the route applies.</p>
Parameter RULES = "OcuPilot.Area.Security.AuthOptionsRules";

/// <p>The body key the SMTP password travels under; it is taken out before any rule reads the body.</p>
Parameter PASSWORDFIELD = "SMTPPassword";

/// <p>The port the write and the fresh read go through, which is the tool's own declaration (AD-52).
/// Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason <method>PortClass</method>
/// is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>The one id the options are known by (AD-13).</p>
ClassMethod TargetId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>Answer <code>PUT /authentication-options</code>: change the options by the settings the body carries and
/// answer <code>{readBack}</code> with 200 (AD-58), with <code>consequence</code> when the write carries one
/// and <code>secretsRefused</code> when the password write was refused, or <code>{}</code> when nothing
/// changes. A top-level key other than the twenty-one settings and the password is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a broken rule is one 422
/// <parameter>OcuPilot.Api.WebAuthError.VALIDATION</parameter> envelope carrying every violation; any other
/// refusal is the gate's, the port's or the prohibited set's own envelope.</p>
/// <p>The body's <code>SMTPPassword</code> is the password to set, or <code>""</code> to clear it; a body
/// without it leaves the password as it is.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Set (tPassword, tBody) = ""
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
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, ..TargetId(), .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tHasPassword = ..TakePassword(tBody, .tPassword, .tShaped)
        Set tPerformSC = ..Update(tBody, .tHttp, .tFault, .tViolations, .tWrite, tShaped)
        Set tBody = ""
        Set (tSecretsReason, tReadBack, tConsequence) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tHasPassword Set tSecretsReason = ..StorePassword(..TargetId(), tPassword)
            Set tPassword = ""
            Set tStored = $Select(tHasPassword && (tSecretsReason = ""): $ListBuild(..#PASSWORDFIELD), 1: "")
            Set tConsequence = $Get(tWrite("consequence"))
            ; AD-58: the options read back after the Save's last write, over what its own write sent; a Save
            ; that sent only the password reports it written, as a secret-only write is.
            If $Data(tWrite("sent")) {
                Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#UPDATETOOL, ..TargetId(), tWrite("sent"), $Get(tWrite("fresh")), ..PortClass(), $Get(tWrite("answer")), $Get(tWrite("http")), tStored)
            } ElseIf tStored '= "" {
                Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#PASSWORDTOOL, ..TargetId(), {}, "", ..PortClass(), "", 0, tStored)
            }
        }
        Set tPassword = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), tSecretsReason, tReadBack, tConsequence)
    } Catch ex {
        Set (tPassword, tBody) = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Change the options by the settings <var>pArgs</var> sends, merged over a fresh read by the tool's own
/// merge, so a setting the caller did not send keeps the instance's value and the body is the complete set
/// less an unchanged <code>AutheKB</code> (AD-4). Nothing is sent when no setting changed.
/// <var>pPasswordShaped</var> 0 adds the password's shape violation.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was
/// written. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>: 400 for an
/// undeclared key, 403 for a prohibited change, and the port's own for a vendor refusal. Nothing is sent on
/// any of them but the last. On success <var>pWrite</var> carries <code>("fresh")</code>, the fresh read,
/// and, when a body was sent, <code>("sent")</code>, <code>("answer")</code>, <code>("http")</code> and
/// <code>("consequence")</code>, for the caller's read-back after its own password write (AD-58).</p>
ClassMethod Update(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pWrite, pPasswordShaped As %Boolean = 1) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pWrite
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ..Undeclared(pArgs, tSettable, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        ; AD-55: the rules that need no fresh read, before anything is read.
        Set tSC = $ClassMethod(..#RULES, "Check", pArgs, .pViolations, 0)
        If $$$ISERR(tSC) Quit
        If 'pPasswordShaped Do ..Add(.pViolations, ..#PASSWORDFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If pViolations > 0 Quit

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = ..TargetId()
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the authentication options read answered no object")
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set pWrite("fresh") = tFresh

        Set tSC = $ClassMethod(tClass, "MergeRaw", tFresh, pArgs, $ClassMethod(tClass, "IdArgument"), tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }

        ; Nothing to change sends nothing.
        If tDiff.%Size() = 0 Quit

        ; The rules that read two settings together, over the payload the body would carry.
        Set tSC = $ClassMethod(..#RULES, "Check", tPayload, .pViolations, 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ..Prohibited(tClass, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tConsequence = $ClassMethod(tClass, "Consequence", tPayload, 0, "")
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = ..TargetId()
        Do $ClassMethod(tClass, "PortQuery", tPayload, .tQuery)
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pWrite("sent") = tPayload
        Set pWrite("answer") = $Get(tAnswer)
        Set pWrite("http") = pHttpStatus
        Set pWrite("consequence") = tConsequence
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <var>pPassword</var> -- a new SMTP password, or <code>""</code> to clear it -- for the target
/// <var>pId</var> through the password tool's own operation: its pairs, AD-10's set and its port, with a
/// body of that secret alone (AD-56 (i)). Answer <code>""</code>, or the refusal's sentence. The password is
/// cleared from this method's locals before it returns, and nothing here stores or logs it (AD-35).</p>
ClassMethod StorePassword(pId As %String, pPassword As %String) As %String
{
    Set tReason = ""
    Set (tBody, tSupplied) = ""
    Try {
        Set tClass = ..#PASSWORDTOOL
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pId, .tTargetRef)
        If $$$ISERR(tSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pId, "string")
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
        Do tSupplied.%Set(..#PASSWORDFIELD, pPassword, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod(tDescriptor, "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pId, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") Set tReason = tFault.%Get("reason")
        }
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set (tBody, tSupplied) = ""
    Quit tReason
}

/// <p>Remove <parameter>PASSWORDFIELD</parameter> from <var>pBody</var>: answer 1 when the body carried it,
/// with its value in <var>pPassword</var> (<code>""</code> clears the password), and 0 when it did not.
/// <var>pShaped</var> is 0 when it carried something other than a string, which is refused.</p>
ClassMethod TakePassword(pBody As %DynamicObject, Output pPassword As %String, Output pShaped As %Boolean) As %Boolean [ Private ]
{
    Set pPassword = ""
    Set pShaped = 1
    Set tType = pBody.%GetTypeOf(..#PASSWORDFIELD)
    If tType = "unassigned" Quit 0
    If tType = "string" {
        Set pPassword = pBody.%Get(..#PASSWORDFIELD)
    } Else {
        Set pShaped = 0
    }
    Do pBody.%Remove(..#PASSWORDFIELD)
    Quit 1
}

/// <p>Refuse every key of <var>pArgs</var> outside <var>pAllowed</var>: an error status with a 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault naming each key in
/// <code>detail.violations</code>, or <code>$$$OK</code>.</p>
ClassMethod Undeclared(pArgs As %DynamicObject, pAllowed As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRows = []
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pAllowed, tKey) Continue
        Do tRows.%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    }
    If tRows.%Size() = 0 Quit $$$OK
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make carrying <var>pPayload</var> and
/// <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
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

/// <p>Render the outcome of <method>Update</method>: the violations as one 422 envelope, a refusal as its own
/// envelope, and success as <code>{readBack, consequence, secretsRefused}</code>, each only when there is one
/// (AD-58), or <code>{}</code> when nothing was sent.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSecretsReason As %String = "", pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit $ClassMethod(..#RULES, "RenderViolations", .pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    If pConsequence '= "" Do tAnswer.%Set("consequence", pConsequence, "string")
    If pSecretsReason '= "" Do tAnswer.%Set("secretsRefused", pSecretsReason, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or the pairs
/// either tool declares beyond them -- its write's resource and the custom resource of each classic page its
/// <code>CLASSICPAGES</code> names (AD-8, AD-44) -- before anything is read or sent: <var>pRefused</var> 1
/// means the envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    For tClass = ..#UPDATETOOL, ..#PASSWORDTOOL {
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        If 'tResolved {
            Set pRefused = 1
            Quit
        }
        If '##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) {
            Set pRefused = 1
            Quit
        }
    }
    If 'pRefused Quit $$$OK
    If tFailedPair = "" Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of the authentication options tools could not be read")))
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
