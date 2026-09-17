/// <p>The one call-time governance gate point (AD-22). <class>OcuPilot.Kernel.Agent.Dispatch</class>
/// asks it for every tool call, after the caller's identity is checked and before any restraint read,
/// privilege check, port or tool.</p>
/// <p><b>Release 1 allows every registered tool.</b> What Release 1 refuses is absent from the tool
/// set (AD-10), and a write is confirmed by a person (AD-6). Story 14.2's per-tool policy attaches
/// here, keyed by <code>tool</code> or <code>tool:action</code>; a denial answers a code the
/// dispatcher renders as the tool result while the tool stays advertised.</p>
/// <p>A gate that fails to answer is a refusal: the dispatcher reads an error status as
/// <code>TOOL.UNAVAILABLE</code> and invokes nothing.</p>
Class OcuPilot.Kernel.Governance.Gate Extends %RegisteredObject
{

/// <p>Decide whether <var>pUser</var> may call the tool <var>pTool</var> (its canonical dotted
/// name), of kind <var>pKind</var>, with <var>pArgs</var> as the model sent them.</p>
/// <p><var>pDecision</var> comes back subscripted by <code>allowed</code> (1 or 0) and
/// <code>code</code> (the machine code a refusal answers, <code>""</code> when allowed).</p>
ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    Kill pDecision
    Set pDecision("allowed") = 1
    Set pDecision("code") = ""
    Quit $$$OK
}

}
