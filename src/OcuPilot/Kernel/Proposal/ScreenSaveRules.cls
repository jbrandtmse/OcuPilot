/// <p>What the rules classes of a screen editor's Save share (AD-39, AD-55): the answer to a failed read of a target, the
/// form read's gate, the violations as one 422 envelope, and the helpers each rule reads a body with. A concrete rules
/// class extends this one, names its screen and its violation codes in <parameter>DESCRIPTORCLASS</parameter> and
/// <parameter>ERRORCLASS</parameter>, and declares <code>Check</code> and <code>Taken</code>, which differ by the
/// target's identity. <class>OcuPilot.Kernel.Proposal.ScreenSave</class> reaches them through its
/// <code>RulesCheck</code> and <code>RulesTaken</code> adapters.</p>
Class OcuPilot.Kernel.Proposal.ScreenSaveRules Extends %RegisteredObject [ Abstract ]
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS;

/// <p>The class whose parameters carry this rule set's codes and sentences: at least <code>VALIDATION</code>,
/// <code>TAKEN</code> and their <code>REASON</code> forms.</p>
Parameter ERRORCLASS;

/// <p>Render <var>pViolations</var> as one 422 envelope, <parameter>ERRORCLASS</parameter>'s <code>VALIDATION</code>,
/// carrying every broken rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, $Parameter(..#ERRORCLASS, "REASONVALIDATION"), $Parameter(..#ERRORCLASS, "VALIDATION"), tDetail)
}

/// <p>Render a failed read of a target: 404 <code>PORT.NOTFOUND</code>, the fault the port answered, or an
/// internal error when it answered none.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .tAbsent, .tVendorText)
        Quit ##class(OcuPilot.Api.Error).Render(404, tAbsent.error, tAbsent.reason, tAbsent.code)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1 means the
/// envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pBody</var>'s <var>pName</var> as text, <code>""</code> when it carries none.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String
{
    Set tType = pBody.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pBody.%Get(pName) _ ""
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
