/// <p>The one call-time governance gate (AD-22). <class>OcuPilot.Kernel.Agent.Dispatch</class>
/// asks it for every tool call, after the caller's identity is checked and before any restraint read,
/// privilege check, port or tool; <class>OcuPilot.Kernel.Proposal.Confirm</class> asks it again at
/// the write, inside the transition and before the claim (AD-40). It is never asked for a person's
/// own screen write or for a copy-out draft.</p>
/// <p>The decision is <class>OcuPilot.Kernel.Governance.Policy</class>'s cascade over the tool's
/// key, read from the stored policy on every call. A denial answers
/// <parameter>OcuPilot.Api.Error.GOVERNANCEDISABLED</parameter>, which the dispatcher renders as the
/// tool result while the tool stays advertised. It never touches the restraint verdict (AD-30), and
/// it can never enable a prohibited write: that set is refused on the write path whatever this
/// answers (AD-10).</p>
/// <p>A gate that fails to answer is a refusal: the dispatcher reads an error status as
/// <code>TOOL.UNAVAILABLE</code> and invokes nothing, and the confirm answers an internal
/// failure.</p>
Class OcuPilot.Kernel.Governance.Gate Extends %RegisteredObject
{

/// <p>Decide whether <var>pUser</var> may call the tool <var>pTool</var> (its canonical dotted
/// name), of kind <var>pKind</var>, with <var>pArgs</var> as the model sent them or as the proposal
/// stored them.</p>
/// <p><var>pDecision</var> comes back subscripted by <code>allowed</code> (1 or 0),
/// <code>code</code> (<code>GOVERNANCE.DISABLED</code> on a denial, <code>""</code> when allowed),
/// <code>key</code> (the key that was resolved) and <code>source</code> (the layer that decided).
/// A read is allowed without resolving its tool. A tool the registry does not carry is governed by
/// its name, and a write of a name the baseline does not list is denied.</p>
ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    Kill pDecision
    Set pDecision("allowed") = 0
    Set pDecision("code") = ""
    Set pDecision("key") = pTool
    Set pDecision("source") = ""
    Set tSC = $$$OK
    Try {
        Set tClass = ""
        If pKind '= ##class(OcuPilot.Kernel.Governance.Policy).#READKIND {
            Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pTool, .tTool, 1)
            If $$$ISERR(tSC) Quit
            If $IsObject(tTool) Set tClass = tTool.%Get("class")
        }
        Set tKey = ##class(OcuPilot.Kernel.Governance.Policy).KeyFor(tClass, pTool, pArgs)
        Set pDecision("key") = tKey
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(tKey, pKind, .tEnabled, .tSource)
        If $$$ISERR(tSC) Quit
        Set pDecision("allowed") = ''tEnabled
        Set pDecision("source") = tSource
        If 'tEnabled Set pDecision("code") = ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pDecision("allowed") = 0
        Set pDecision("code") = ""
    }
    Quit tSC
}

}
