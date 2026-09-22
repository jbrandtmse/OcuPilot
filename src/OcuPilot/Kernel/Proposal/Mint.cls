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
/// <p>Seams a subclass overrides: <method>PortClass</method>, <method>StoreClass</method> and
/// <method>RegistryClass</method>. Production overrides none of them.</p>
Class OcuPilot.Kernel.Proposal.Mint Extends %RegisteredObject
{

/// <p>The admin request type the fresh read is made with when the call names no tool class: one
/// object, by its own id (AD-36's single-object <code>GET</code>, whose 404 reads as zero rows).
/// A tool that names its class is read with <method>OcuPilot.Screen.Tool.Write.ReadType</method>
/// instead (AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The canonical dotted name of the write tool that turns the instance's auditing on and off
/// (FR-47, Story 5.10). Named here rather than in a screen, a descriptor or a policy file because
/// the predicate below is the kernel's and has exactly one home (AD-10).</p>
Parameter AUDITINGTOOL = "security.auditing.update";

/// <p>The body property that write carries the auditing flag in.</p>
Parameter AUDITINGFIELD = "Enabled";

/// <p>The JSON type name <method>Representable</method> and <method>Coerced</method> answer the
/// boolean question under, spelled once so <method>WarnsAuditingOff</method> and the merge cannot
/// ask two different questions.</p>
Parameter TYPEBOOLEAN = "boolean";

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

/// <p>The tool registry a proposed tool's own declarations are resolved through -- today its
/// <method>OcuPilot.Screen.Tool.Write.Destructive</method> answer. The kernel may read the
/// registry; the registry never reads the kernel. Overridable for the reason
/// <method>PortClass</method> is.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>Mint one proposal for tool <var>pToolName</var> of screen <var>pDescriptor</var>, called by
/// <var>pUser</var> inside turn <var>pTurnKey</var> of conversation <var>pConvKey</var>, from the
/// resolved arguments <var>pArgs</var>.</p>
/// <p><var>pEndpoint</var>, <var>pIdParam</var>, <var>pIdValue</var>, <var>pIdArgument</var> and
/// <var>pSettable</var> are the tool's own answers (<class>OcuPilot.Screen.Tool.Write</class>):
/// the admin endpoint, the query parameter its read identifies a target by, that
/// target's id, the input property that carried it, and the field names the merge may set. An
/// empty <var>pEndpoint</var> falls back to the descriptor's own declared read source, which is
/// the endpoint the screen already lists through.</p>
/// <p><var>pToolClass</var> is the tool's own class, which is what the three action-style
/// declarations are read from (AD-51): the request type the fresh read is made with, whether the
/// confirmed write will carry a body, and the state rows the card shows for a write that sends
/// none. An empty <var>pToolClass</var> is a merge write read with <parameter>READTYPE</parameter>
/// and no state rows, which is what every caller predating AD-51 gets.</p>
/// <p>On success <var>pProposal</var> is
/// <code>{proposalId, target: {type, scope, id}, tool, changed, unchangedCount, expiresAt}</code>,
/// <var>pHttpStatus</var> 200 and <var>pFault</var> <code>""</code>. On failure the status is an
/// error, <var>pProposal</var> is <code>""</code>, and <var>pHttpStatus</var>/<var>pFault</var>
/// carry the refusal -- the port's own where the port refused, and 400
/// <code>TOOL.ARGUMENTS</code> where the arguments or the target are the problem.</p>
/// <p><b>A target the instance no longer holds is a refusal, never an empty success</b>: the
/// <code>GET</code>'s 404 and an answer that is not an object are the same "target gone", and both
/// name the target.</p>
ClassMethod Mint(pDescriptor As %String, pToolName As %String, pUser As %String, pConvKey As %String, pTurnKey As %String, pArgs As %DynamicObject, pLimitsClass As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pEndpoint As %String = "", pIdParam As %String = "", pIdValue As %String = "", pIdArgument As %String = "", pSettable As %List = "", pToolClass As %String = "") As %Status
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
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", tEndpoint, ..ReadTypeOf(pToolClass), .tQuery, "", .tFresh, .tReadHttp, .tReadFault)
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

        ; AD-51. A write that sends no body has nothing for Merge to move, so its card's one row
        ; comes from the fresh read and the tool is what computes it. A target that is not in the
        ; state the action moves it out of is refused here, before anything is stored, rather than
        ; minting a proposal whose diff says nothing changes.
        If pToolClass '= "" {
            Set tStateSC = $ClassMethod(pToolClass, "StateDiff", tFresh, .tStateRows, .tStateProblem)
            If $$$ISERR(tStateSC) {
                Set tSC = ..Internal("the proposal's state diff could not be computed: " _ $System.Status.GetErrorText(tStateSC), .pHttpStatus, .pFault)
                Quit
            }
            If tStateProblem '= "" {
                Set tSC = ..Refuse(tStateProblem, .pHttpStatus, .pFault)
                Quit
            }
            If $IsObject(tStateRows) {
                Set tStateIterator = tStateRows.%GetIterator()
                While tStateIterator.%GetNext(.tStateIndex, .tStateRow) {
                    If $IsObject(tStateRow) Do tDiff.%Push(tStateRow)
                }
            }
            ; Nothing is sent, so nothing is sent unchanged: the caption and the rows behind it are
            ; one population (OcuPilot.Kernel.Proposal.Disclosure), and that population is empty.
            If '$ClassMethod(pToolClass, "SendsBody") Set tUnchanged = 0
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
        Set tValues("destructive") = ..DestructiveTool(pToolName)
        ; FR-17's definition condition is answered at confirm against the definition that was in
        ; force here. Read, never written: the definition store is Epic 10's.
        Set tDefinitionSC = ..DefinitionInForce(.tDefinitionId, .tDefinitionVersion)
        If $$$ISERR(tDefinitionSC) {
            Set tSC = ..Internal("the proposal's definition could not be read: " _ $System.Status.GetErrorText(tDefinitionSC), .pHttpStatus, .pFault)
            Quit
        }
        Set tValues("definitionId") = tDefinitionId
        Set tValues("definitionVersion") = tDefinitionVersion
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
/// <p>It answers true for one shape: the auditing write, against an <code>instance</code>-scoped
/// target, whose <parameter>AUDITINGFIELD</parameter> argument does not leave auditing on.
/// <class>OcuPilot.Screen.Tool.AuditingUpdate</class> is the only tool that can trip it; every
/// other tool that ships answers false on its name alone.</p>
/// <p><b>It reads the argument through the two methods the payload reads it through</b> --
/// <method>Representable</method> then <method>Coerced</method>, in <method>Merge</method>'s own
/// order -- so the warning and the body cannot answer different questions about one value. A
/// <code>%GetTypeOf</code> gate of its own would make <code>0</code> and <code>"false"</code>
/// coerce to false in the payload while the card said nothing, which is the one combination this
/// predicate exists to prevent: a write that turns auditing off with no warning above it.</p>
/// <p>A value <method>Representable</method> rejects -- JSON <code>null</code> is the reachable
/// one -- warns, because the payload will not carry it as "auditing stays on": the merge refuses
/// it and the proposal is never minted, so the warning is fail-safe rather than noise.</p>
ClassMethod WarnsAuditingOff(pToolName As %String, pTargetType As %String, pTargetScope As %String, pArgs As %DynamicObject) As %Boolean
{
    Set tWarns = 0
    Try {
        If pToolName '= ..#AUDITINGTOOL Quit
        If pTargetScope '= ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE Quit
        If pTargetType = "" Quit
        If '$IsObject(pArgs) Quit
        If pArgs.%GetTypeOf(..#AUDITINGFIELD) = "unassigned" Quit
        Set tValue = pArgs.%Get(..#AUDITINGFIELD)
        If '..Representable(tValue, ..#TYPEBOOLEAN) {
            Set tWarns = 1
            Quit
        }
        Set tWarns = '..Coerced(tValue, ..#TYPEBOOLEAN)
    } Catch {
        Set tWarns = 0
    }
    Quit tWarns
}

/// <p>Whether the tool named <var>pToolName</var> declares its write destructive
/// (<method>OcuPilot.Screen.Tool.Write.Destructive</method>), for the wire key the card's
/// treatment reads.</p>
/// <p><b>The declaration is the tool's own.</b> This resolves it through the registry rather than
/// holding a list of destructive tool names here: such a list would have to be kept in step with
/// the tool set by hand, and a tool added outside it would ship undeclared. A name the registry
/// does not carry, or a class that answers nothing, is not destructive -- the fail-closed direction
/// for a <i>styling</i> declaration, whose failure mode is a card drawn plainly rather than a write
/// permitted.</p>
ClassMethod DestructiveTool(pToolName As %String) As %Boolean [ Private ]
{
    Set tDestructive = 0
    Try {
        If $$$ISERR($ClassMethod(..RegistryClass(), "Resolve", pToolName, .tTool)) Quit
        If '$IsObject(tTool) Quit
        If tTool.%Get("class") = "" Quit
        Set tDestructive = ''$ClassMethod(tTool.%Get("class"), "Destructive")
    } Catch {
        Set tDestructive = 0
    }
    Quit tDestructive
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
            Set tArgType = pArgs.%GetTypeOf(tField)
            If (tArgType = "object") || (tArgType = "array") {
                Do pPayload.%Set(tField, pArgs.%Get(tField))
            } Else {
                ; AD-4: the body keeps the property set AND the property types the instance's own
                ; read answered with. A tool schema's scalar type is derived from a template
                ; placeholder, which is information rather than contract -- this instance answers a
                ; number for five WebApp.App fields whose template shows a string -- so a numeric
                ; instance field set from a string argument is sent back as a number, not as its
                ; string spelling.
                Set tAfterType = ..SettableType(pPayload.%GetTypeOf(tField), tArgType)
                ; A value the instance's own type cannot carry is refused here rather than coerced:
                ; the diff row below reports the argument as the model wrote it, so a silent
                ; coercion would promise the user one value and send the instance another.
                If '..Representable(pArgs.%Get(tField), tAfterType) {
                    Set pProblem = "'" _ tField _ "' is " _ tAfterType _ " on this instance, and '" _ tAfter _ "' is not one"
                    Quit
                }
                Do pPayload.%Set(tField, ..Coerced(pArgs.%Get(tField), tAfterType), tAfterType)
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

/// <p>The agent definition in force and the version it carries, for the proposal's row.</p>
/// <p><var>pVersion</var> is <method>OcuPilot.Kernel.State.Agent.GuardedVersion</method>'s answer,
/// where <code>""</code> is "no row" and is never conflated with <code>0</code>. No definition in
/// force leaves both empty, which is the configuration-empty state rather than a failure.</p>
ClassMethod DefinitionInForce(Output pId As %String, Output pVersion As %String) As %Status [ Private ]
{
    Set pId = ""
    Set pVersion = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.pId)
    If $$$ISERR(tSC) Quit tSC
    If pId = "" Quit $$$OK
    Quit ##class(OcuPilot.Kernel.State.Agent).GuardedVersion(pId, .pVersion)
}

/// <p>The admin request type <var>pToolClass</var>'s fresh read is made with (AD-51), or
/// <parameter>READTYPE</parameter> when the call named no tool class. A class that answers an
/// empty type is read with the parameter too, so an unreadable declaration is a merge write's
/// read rather than a call with no type at all.</p>
ClassMethod ReadTypeOf(pToolClass As %String) As %String
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "ReadType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#READTYPE
    Quit tType
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

/// <p>The JSON type a merged scalar is written with: the fresh read's own type <var>pFreshType</var>
/// where that read carried the field as a scalar, else the argument's own <var>pArgType</var>.</p>
/// <p>An absent or null fresh value settles nothing about the field's type, so the argument's type
/// stands; an object or array on either side never reaches here.</p>
ClassMethod SettableType(pFreshType As %String, pArgType As %String) As %String [ Private ]
{
    If (pFreshType = "unassigned") || (pFreshType = "null") Quit pArgType
    If (pFreshType = "object") || (pFreshType = "array") Quit pArgType
    Quit pFreshType
}

/// <p>Whether <var>pValue</var> can be carried by <var>pType</var> without changing what it says:
/// a number needs a numeric spelling, a boolean one of <code>true</code>, <code>false</code>,
/// <code>0</code> or <code>1</code>, and every other type takes anything.</p>
/// <p>The gate in front of <method>Coerced</method>, which otherwise answers <code>0</code> for a
/// word. Refusing at the mint is what keeps the diff the user reviews and the body the confirmed
/// write sends the same thing (AD-4, AD-6).</p>
ClassMethod Representable(pValue As %RawString, pType As %String) As %Boolean [ Private ]
{
    If pType = "number" Quit ''$IsValidNum(pValue)
    If pType = "boolean" Quit ((pValue = "true") || (pValue = "false") || (pValue = 0) || (pValue = 1))
    Quit 1
}

/// <p><var>pValue</var> as <var>pType</var> spells it: a number numerically, a boolean as 0 or 1
/// reading <code>true</code>/<code>false</code> as well as 0 and 1, and anything else
/// verbatim.</p>
/// <p><b>Caller contract:</b> <method>Representable</method> has already answered true for the
/// pair; this method does not validate.</p>
ClassMethod Coerced(pValue As %RawString, pType As %String) As %RawString [ Private ]
{
    If pType = "number" Quit +pValue
    If pType = "boolean" {
        If pValue = "true" Quit 1
        If pValue = "false" Quit 0
        Quit ''pValue
    }
    Quit pValue
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
/// <p>Not <code>Private</code>, because two other callers must read a value exactly as the diff
/// the user reviewed does. One rendering, not three:
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s predicates compare a payload against a
/// live read and must agree with the diff about what "changed" means, and
/// <class>OcuPilot.Kernel.Proposal.Disclosure</class> renders the unchanged rows beside it on the
/// same card.</p>
ClassMethod Display(pValue As %RawString, pType As %String) As %String
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
