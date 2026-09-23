/// <p>The screen's half of a user create (AD-55), over <code>POST /users</code>. The agent's half
/// is the same tool class (<class>OcuPilot.Screen.Tool.UserCreate</class>) read by
/// <class>OcuPilot.Kernel.Proposal.Mint</class> and <class>OcuPilot.Kernel.Proposal.Confirm</class>,
/// and its mint applies <method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method>'s rules.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// type, the port, the settable field list and the payload composition. It mints no proposal and
/// takes no confirm token. In order: the caller's own pairs (AD-8); the name's shape; AD-10's
/// prohibited set over the caller's own fields minus the declared secrets; the form's rules; the
/// composed payload with the password merged in after that verdict, as
/// <method>OcuPilot.Kernel.Proposal.Confirm</method> merges a supplied secret; and only then the
/// port, which builds the vendor's wrapper. A privileged role is not refused: the form states its
/// consequence at the Roles field before Save (AD-10).</p>
/// <p><b>The password is a secret</b> (AD-35): it is never logged, echoed or returned, and the
/// created account the route answers is the vendor's own read, which carries none.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither. The name look-up goes through
/// <method>OcuPilot.Area.Permissions.UserCreateRules.Taken</method>, which resolves the tool's own
/// port directly.</p>
Class OcuPilot.Area.Permissions.UserCreate Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.UserCreate";

/// <p>The form screen whose declared pairs gate this route (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserForm";

/// <p>The input property that names the target: the vendor's <code>name</code> query parameter.</p>
Parameter IDARGUMENT = "Name";

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

/// <p>Answer <code>POST /users</code>: create one account from the body and answer
/// <code>{name, user}</code> with 201, the account as the instance then holds it. A broken rule is
/// one 422 <parameter>OcuPilot.Api.Error.USERVALIDATION</parameter> envelope carrying every
/// violation; any other refusal is the port's or the prohibited set's own envelope.</p>
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
        Set tBody = ""
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
        Do tAnswer.%Set("user", $Select($IsObject($Get(tCreated)): tCreated, 1: {}))
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the account <var>pName</var> from <var>pArgs</var>, and answer the account the
/// instance then holds in <var>pCreated</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code[, reason])</code>, count in
/// <code>pViolations</code>); a non-zero count means nothing was written and the other outputs say
/// nothing. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>, and
/// success carries the created account.</p>
ClassMethod Perform(pName As %String, pArgs As %DynamicObject, Output pCreated As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pCreated = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tRules = "OcuPilot.Area.Permissions.UserCreateRules"
        Do $ClassMethod(tRules, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#TOOLCLASS
        Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tRefSC) {
            Set tSC = tRefSC
            Quit
        }

        ; AD-10, AD-55. The set the confirm asks, asked before the port and before the field rules,
        ; over the caller's own fields -- minus the declared secrets, which the confirm merges only
        ; after its verdict too.
        Set tSecrets = $ClassMethod(tClass, "SecretArguments")
        Set tProhibitSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tClass, "TOOLNAME"), tTargetRef, ..CallerFields(pArgs, tSecrets).%ToJSON(), "[]", .tProhibits, .tProhibitCode)
        If $$$ISERR(tProhibitSC) {
            Set tSC = tProhibitSC
            Quit
        }
        If tProhibits {
            Set pHttpStatus = 403
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tProhibitCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tProhibitCode))
            Set tSC = $$$ERROR($$$GeneralError, tProhibitCode)
            Quit
        }

        Set tSC = $ClassMethod(tRules, "Validate", pName, pArgs, .pViolations)
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

        ; AD-35: the declared secrets join the body here, after the verdict and the rules, and
        ; nowhere else.
        For tI = 1:1:$ListLength(tSecrets) {
            Set tSecret = $List(tSecrets, tI)
            If pArgs.%GetTypeOf(tSecret) = "string" Do tPayload.%Set(tSecret, pArgs.%Get(tSecret), "string")
        }

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .pCreated, .pHttpStatus, .pFault)
        Set tPayload = ""
    } Catch ex {
        Set pCreated = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The caller's own body fields, minus the identifying argument and minus every name in
/// <var>pSecrets</var>, as one <class>%DynamicObject</class>: what AD-10's set is asked about on the
/// screen path. It is not the composed payload, so a field the tool does not admit reaches the set
/// rather than being silently dropped.</p>
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
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONUSERVALIDATION, ##class(OcuPilot.Api.Error).#USERVALIDATION, tDetail)
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
