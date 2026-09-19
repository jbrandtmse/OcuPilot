/// <p>Where a proposal is minted (AD-6, AD-4, AD-13): read the target fresh through the port, merge
/// the tool's resolved arguments over the object that read returned, compute the diff and the
/// fingerprint, and store one row.</p>
/// <p><b>It lives outside <package>OcuPilot.Kernel.Agent</package> and
/// <package>OcuPilot.Kernel.State</package> precisely so it may name the port and the
/// descriptor.</b> The turn job may reach only the provider port and the tool registry (AD-7), and
/// a storage method may re-enter nothing at all (AD-9); minting does both -- it calls the admin
/// port and it writes OcuPilot's own state -- so it is neither of those things and sits between
/// them.</p>
/// <p><b>Nothing here writes to the instance.</b> The merged body is assembled and stored; Story
/// 5.3 sends it inside the atomic transition a confirm claims. That is why
/// <class>OcuPilot.Port.AdminPort</class> gains no mutating request type in this story.</p>
/// <p><b>The merge is over the fresh read's own object</b> (AD-4), never over the derived field
/// list: the payload's property names are exactly the ones the instance answered with, so a
/// published schema that carries a property this instance's GET does not cannot add one, and a
/// property the read returned and the arguments did not name travels unchanged.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method> and <method>StoreClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Kernel.Proposal.Mint Extends %RegisteredObject
{

/// <p>The admin request type the fresh read is made with: one object, by its own id (AD-36's
/// single-object <code>GET</code>, whose 404 reads as zero rows).</p>
Parameter READTYPE = "GET";

/// <p>The canonical dotted name of the write tool that turns the instance's auditing on and off
/// (FR-47, Story 5.10). Named here rather than in a screen, a descriptor or a policy file because
/// the predicate below is the kernel's and has exactly one home (AD-10).</p>
Parameter AUDITINGTOOL = "security.auditing.update";

/// <p>The body property that write carries the auditing flag in.</p>
Parameter AUDITINGFIELD = "Enabled";

/// <p>The port the fresh read goes through. Overridable so a fixture can answer a known object;
/// production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The store a minted proposal is written to. Overridable for the same reason; production never
/// overrides it.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Propose"
}

/// <p>Mint one proposal for tool <var>pToolName</var> of screen <var>pDescriptor</var>, called by
/// <var>pUser</var> inside turn <var>pTurnKey</var> of conversation <var>pConvKey</var>, from the
/// resolved arguments <var>pArgs</var>.</p>
/// <p><var>pEndpoint</var>, <var>pIdParam</var>, <var>pIdValue</var>, <var>pIdArgument</var> and
/// <var>pSettable</var> are the tool's own answers (<class>OcuPilot.Screen.Tool.Write</class>):
/// the admin endpoint, the query parameter its <code>GET</code> identifies a target by, that
/// target's id, the input property that carried it, and the field names the merge may set. An
/// empty <var>pEndpoint</var> falls back to the descriptor's own declared read source, which is
/// the endpoint the screen already lists through.</p>
/// <p>On success <var>pProposal</var> is
/// <code>{proposalId, target: {type, scope, id}, tool, changed, unchangedCount, expiresAt}</code>,
/// <var>pHttpStatus</var> 200 and <var>pFault</var> <code>""</code>. On failure the status is an
/// error, <var>pProposal</var> is <code>""</code>, and <var>pHttpStatus</var>/<var>pFault</var>
/// carry the refusal -- the port's own where the port refused, and 400
/// <code>TOOL.ARGUMENTS</code> where the arguments or the target are the problem.</p>
/// <p><b>A target the instance no longer holds is a refusal, never an empty success</b>: the
/// <code>GET</code>'s 404 and an answer that is not an object are the same "target gone", and both
/// name the target.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "") As %Status
{
    Set tSC = $$$OK
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tEndpoint = pEndpoint
        If tEndpoint = "" Set tEndpoint = ..EndpointOf(pDescriptor)
        If (tEndpoint = "") || (pIdParam = "") || (pIdValue = "") {
            Set tSC = ..Internal("the mint was called with no endpoint, no identifying parameter or no target id", .pHttpStatus, .pFault)
            Quit
        }

        ; AD-6: a secret-declared field is never accepted from the model, so the refusal is here,
        ; before the port is touched and before anything is stored.
        Set tSecrets = $ClassMethod(pDescriptor, "SecretArguments")
        Set tSecretName = ..FirstNamed(pArgs, tSecrets)
        If tSecretName '= "" {
            Set tSC = ..Refuse("'" _ tSecretName _ "' is a secret field and is never accepted from the agent; it is supplied at confirmation", .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(pDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(pDescriptor, "Scope")), pIdValue, .tTargetRef)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal's target reference could not be built: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pFault)
            Quit
        }

        Kill tQuery
        Set tQuery(pIdParam) = pIdValue
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", tEndpoint, ..#READTYPE, .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tReadHttp) = 404 {
                Set tSC = ..Refuse("'" _ pIdValue _ "' is not present on this instance", .pHttpStatus, .pFault)
                Quit
            }
            Set pHttpStatus = +$Get(tReadHttp)
            Set pFault = $Get(tReadFault)
            Set tSC = tReadSC
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = ..Refuse("'" _ pIdValue _ "' is not present on this instance", .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Merge(tFresh, pArgs, pIdArgument, pSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If tProblem '= "" {
            Set tSC = ..Refuse(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal's payload could not be merged: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, $ClassMethod(pDescriptor, "FingerprintExcludes"), .tFingerprint)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal's fingerprint could not be taken: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pFault)
            Quit
        }

        Kill tValues
        Set tValues("user") = pUser
        Set tValues("convKey") = pConvKey
        Set tValues("turnKey") = pTurnKey
        Set tValues("toolName") = pToolName
        Set tValues("targetRef") = tTargetRef
        Set tValues("fingerprint") = tFingerprint
        Set tValues("arguments") = ..StoredArguments(pArgs)
        Set tValues("payload") = tPayload.%ToJSON()
        Set tValues("diff") = tDiff.%ToJSON()
        Set tValues("unchangedCount") = tUnchanged
        Set tValues("rationale") = ..TextArgument(pArgs, "rationale")
        Set tValues("expectedImpact") = ..TextArgument(pArgs, "expectedImpact")
        Set tValues("reverse") = ..TextArgument(pArgs, "reverse")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse(tTargetRef, .tType, .tScope, .tId)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal's target reference could not be read back", .pHttpStatus, .pFault)
            Quit
        }
        Set tValues("auditWarning") = ..WarnsAuditingOff(pToolName, tType, tScope, pArgs)
        Set tSC = $ClassMethod(..StoreClass(), "GuardedMint", .tValues, pLimitsClass, .tKey, .tToken, .tExpiresAt)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal could not be stored: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, tScope, tId, .tTarget)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the proposal's target could not be put on the wire", .pHttpStatus, .pFault)
            Quit
        }
        Set pProposal = {}
        Do pProposal.%Set("proposalId", tKey, "string")
        Do pProposal.%Set("target", tTarget)
        Do pProposal.%Set("tool", pToolName, "string")
        Do pProposal.%Set("changed", tDiff)
        Do pProposal.%Set("unchangedCount", +tUnchanged, "number")
        Do pProposal.%Set("expiresAt", tExpiresAt, "string")
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pProposal = ""
        Set tSC = ..Internal("the proposal could not be minted: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the write this proposal carries would stop the instance marking agent writes in the
/// audit database (AD-10, AD-15), which is the one warning a card draws inside itself, above its
/// footer.</p>
/// <p><b>Caller contract:</b> <var>pToolName</var> is the canonical dotted tool name,
/// <var>pTargetType</var> and <var>pTargetScope</var> the resolved target's own two halves
/// (AD-13), and <var>pArgs</var> the arguments the mint is about to store. It reads live state
/// through none of them and decides nothing about whether the write may happen -- a refusal is
/// <method>OcuPilot.Kernel.Proposal.Write.Claim</method>'s, inside the atomic transition (AD-34,
/// AD-40).</p>
/// <p>It answers true for exactly one shape: the auditing write, against an
/// <code>instance</code>-scoped target, whose <parameter>AUDITINGFIELD</parameter> argument is
/// boolean false. Every tool that ships today answers false, and Story 5.10 is the first write
/// that trips it.</p>
ClassMethod WarnsAuditingOff(pToolName As %String, pTargetType As %String, pTargetScope As %String, pArgs As %DynamicObject) As %Boolean
{
    Set tWarns = 0
    Try {
        If pToolName '= ..#AUDITINGTOOL Quit
        If pTargetScope '= ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE Quit
        If pTargetType = "" Quit
        If '$IsObject(pArgs) Quit
        If pArgs.%GetTypeOf(..#AUDITINGFIELD) '= "boolean" Quit
        Set tWarns = 'pArgs.%Get(..#AUDITINGFIELD)
    } Catch {
        Set tWarns = 0
    }
    Quit tWarns
}

/// <p>The merged payload and the diff for a fresh read <var>pFresh</var> and arguments
/// <var>pArgs</var>.</p>
/// <p><b>The payload starts as a copy of the fresh read and keeps its property set exactly</b>
/// (AD-4). An argument in <var>pSettable</var> overwrites the property of the same name; an
/// argument naming a property the read did not carry is <var>pProblem</var>, never a property
/// added to the body, because an added property is a write the user never reviewed. The
/// identifying argument <var>pIdArgument</var> and every argument outside <var>pSettable</var>
/// (the agent's own words) are skipped: they describe the call, not the body.</p>
/// <p><var>pDiff</var> is one <code>{field, before, after}</code> per property whose value the
/// arguments actually change, in the order <var>pSettable</var> declares, and
/// <var>pUnchanged</var> is how many of the payload's own properties the write still sends
/// untouched.</p>
ClassMethod Merge(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Set tTotal = 0
        Set tIterator = pPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tTotal = tTotal + 1
        }
        Set tChanged = 0
        For tI = 1:1:$ListLength(pSettable) {
            Set tField = $List(pSettable, tI)
            If tField = pIdArgument Continue
            If pArgs.%GetTypeOf(tField) = "unassigned" Continue
            If pPayload.%GetTypeOf(tField) = "unassigned" {
                Set pProblem = "this instance's own record of the target carries no property '" _ tField _ "', so the write cannot set one"
                Quit
            }
            Set tBefore = ..Display(pPayload.%Get(tField), pPayload.%GetTypeOf(tField))
            Set tAfter = ..Display(pArgs.%Get(tField), pArgs.%GetTypeOf(tField))
            If tAfter = tBefore Continue
            Set tAfterType = pArgs.%GetTypeOf(tField)
            If (tAfterType = "object") || (tAfterType = "array") {
                Do pPayload.%Set(tField, pArgs.%Get(tField))
            } Else {
                Do pPayload.%Set(tField, pArgs.%Get(tField), tAfterType)
            }
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", tBefore, "string")
            Do tRow.%Set("after", tAfter, "string")
            Do pDiff.%Push(tRow)
            Set tChanged = tChanged + 1
        }
        If pProblem '= "" {
            Set pPayload = ""
            Set pDiff = []
            Quit
        }
        Set pUnchanged = tTotal - tChanged
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The admin endpoint <var>pDescriptor</var>'s own declared read lists through, or
/// <code>""</code>.</p>
ClassMethod EndpointOf(pDescriptor As %String) As %String [ Private ]
{
    Set tEndpoint = ""
    Try {
        Set tRead = $ClassMethod(pDescriptor, "Read")
        If '$IsObject(tRead) Quit
        If tRead.%GetTypeOf("source") '= "object" Quit
        Set tEndpoint = tRead.%Get("source").%Get("endpoint")
    } Catch {
        Set tEndpoint = ""
    }
    Quit tEndpoint
}

/// <p>The first name in <var>pNames</var> that <var>pArgs</var> carries, or <code>""</code>.</p>
ClassMethod FirstNamed(pArgs As %DynamicObject, pNames As %List) As %String [ Private ]
{
    Set tFound = ""
    If '$IsObject(pArgs) Quit ""
    For tI = 1:1:$ListLength(pNames) {
        If pArgs.%GetTypeOf($List(pNames, tI)) '= "unassigned" {
            Set tFound = $List(pNames, tI)
            Quit
        }
    }
    Quit tFound
}

/// <p>One value as the diff shows it and as the fingerprint's own comparison reads it: a string
/// verbatim, a boolean as <code>true</code>/<code>false</code>, a null as <code>""</code>, and an
/// object or an array as its compact JSON.</p>
ClassMethod Display(pValue As %RawString, pType As %String) As %String [ Private ]
{
    If (pType = "null") || (pType = "unassigned") Quit ""
    If pType = "boolean" Quit $Select(''pValue: "true", 1: "false")
    If $IsObject(pValue) Quit pValue.%ToJSON()
    Quit pValue
}

/// <p>The stored form of the call's arguments: compact JSON, exactly what the model sent, with no
/// secret-declared key among them -- a call carrying one was refused before the port was
/// touched.</p>
ClassMethod StoredArguments(pArgs As %DynamicObject) As %String [ Private ]
{
    If '$IsObject(pArgs) Quit "{}"
    Quit pArgs.%ToJSON()
}

/// <p><var>pArgs</var>'s string member <var>pName</var>, or <code>""</code>.</p>
ClassMethod TextArgument(pArgs As %DynamicObject, pName As %String) As %String [ Private ]
{
    If '$IsObject(pArgs) Quit ""
    If pArgs.%GetTypeOf(pName) '= "string" Quit ""
    Quit pArgs.%Get(pName)
}

/// <p>A refusal the arguments or the target earned: 400 <code>TOOL.ARGUMENTS</code> with
/// <var>pProblem</var> as <code>detail.problem</code>, the shape
/// <method>OcuPilot.Screen.Tool.Base.ArgumentsRefusal</method> answers.</p>
ClassMethod Refuse(pProblem As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ ": " _ pProblem)
}

/// <p>An internal failure of the mint: 500 with the generic fault on the wire, and
/// <var>pDetail</var> in the status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
