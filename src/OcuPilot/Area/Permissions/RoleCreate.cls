/// <p>The screen's half of a role create (AD-55), over <code>POST /roles</code>. The agent's half
/// is the same tool class (<class>OcuPilot.Screen.Tool.RoleCreate</class>) read by
/// <class>OcuPilot.Kernel.Proposal.Mint</class> and <class>OcuPilot.Kernel.Proposal.Confirm</class>,
/// and its mint applies <method>OcuPilot.Area.Permissions.RoleCreateRules.Validate</method>'s
/// rules.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// type, the port, the settable field list and the payload composition. It mints no proposal and
/// takes no confirm token. In order: the caller's own pairs (AD-8); the name's own rules; AD-10's
/// prohibited set over the caller's own fields, a privilege grant answered as a violation on each
/// field that carries one; the form's rules; the composed payload; and only then the port.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither. The name look-up goes through
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.Taken</method>, which resolves the tool's own
/// port directly.</p>
Class OcuPilot.Area.Permissions.RoleCreate Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.RoleCreate";

/// <p>The form screen whose declared pairs gate this route (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleForm";

/// <p>The input property that names the target: the vendor's <code>name</code> query parameter.</p>
Parameter IDARGUMENT = "Name";

/// <p>The two fields a privilege-grant refusal can land on, comma-separated, in the form's
/// order.</p>
Parameter GRANTFIELDS = "Resources,GrantedRoles";

ClassMethod ToolClass() As %String
{
    Quit ..#TOOLCLASS
}

/// <p>The port the write goes through, which is the tool's own declaration (AD-52). Overridable so
/// a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#TOOLCLASS, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /roles</code>: create one role from the body and answer
/// <code>{name, role}</code> with 201, the role as the instance then holds it. A broken rule is one
/// 422 <parameter>OcuPilot.Api.Error.ROLEVALIDATION</parameter> envelope carrying every violation;
/// any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }

        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Perform(tName, tBody, .tCreated, .tHttp, .tFault, .tViolations)
        If $Get(tViolations) > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tPerformSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPerformSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("name", tName, "string")
        Do tAnswer.%Set("role", $Select($IsObject($Get(tCreated)): tCreated, 1: {}))
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the role <var>pName</var> from <var>pArgs</var>, and answer the role the instance then
/// holds in <var>pCreated</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code[, reason])</code>, count in
/// <code>pViolations</code>); a non-zero count means nothing was written and the other outputs say
/// nothing. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>, and
/// success carries the created role.</p>
/// <p><b>A privilege-grant verdict is attributed, not re-derived.</b> The set is asked again with
/// each of <parameter>GRANTFIELDS</parameter> alone, and every field whose own answer is a privilege
/// grant carries the set's one sentence (AD-39, AD-53). The predicate lives in the set alone.</p>
ClassMethod Perform(pName As %String, pArgs As %DynamicObject, Output pCreated As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pCreated = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tRules = "OcuPilot.Area.Permissions.RoleCreateRules"
        Do $ClassMethod(tRules, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#TOOLCLASS
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tSC) Quit

        ; AD-10, AD-55. The set the confirm asks, asked before the port and before the field rules,
        ; over the caller's own fields.
        Set tFields = ..CallerFields(pArgs)
        Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tClass, "TOOLNAME"), tTargetRef, tFields.%ToJSON(), "[]", .tProhibits, .tProhibitCode)
        If $$$ISERR(tSC) Quit
        If tProhibits {
            Set tGrant = ##class(OcuPilot.Kernel.Proposal.Prohibited).#PRIVILEGEGRANT
            If tProhibitCode = tGrant {
                For tI = 1:1:$Length(..#GRANTFIELDS, ",") {
                    Set tField = $Piece(..#GRANTFIELDS, ",", tI)
                    If tFields.%GetTypeOf(tField) = "unassigned" Continue
                    Set tAlone = {}
                    Do tAlone.%Set(tField, tFields.%Get(tField))
                    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tClass, "TOOLNAME"), tTargetRef, tAlone.%ToJSON(), "[]", .tFieldProhibits, .tFieldCode)
                    If $$$ISERR(tSC) Quit
                    If tFieldProhibits && (tFieldCode = tGrant) {
                        Set pViolations($Increment(pViolations)) = $ListBuild(tField, tGrant, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tGrant))
                    }
                }
                If $$$ISERR(tSC) || (pViolations > 0) Quit
            }
            Set pHttpStatus = 403
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tProhibitCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tProhibitCode))
            Set tSC = $$$ERROR($$$GeneralError, tProhibitCode)
            Quit
        }

        Set tSC = $ClassMethod(tRules, "Validate", pName, pArgs, .pViolations, 0, 1)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tComposeSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the create's payload could not be composed after its rules passed")
            Quit
        }

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .pCreated, .pHttpStatus, .pFault)
    } Catch ex {
        Set pCreated = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The caller's own body fields, minus the identifying argument, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on the screen path. It is not the
/// composed payload, so a field the tool does not admit reaches the set rather than being silently
/// dropped.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = ..#IDARGUMENT Continue
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONROLEVALIDATION, ##class(OcuPilot.Api.Error).#ROLEVALIDATION, tDetail)
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
