/// <p>Test-only <class>OcuPilot.Kernel.Agent.Dispatch</class> subclass whose seams are switches, so
/// every refusal in the dispatch order can be driven in process: the registry is
/// <class>OcuPilot.Test.DispatchTool.Registry</class> unless a test names another; the gate is the
/// shipped one unless a test denies or fails it; the restraint verdict is the real one unless a test forces it
/// blocked, clear or unreadable; a pair is held unless a test denies it, because the suite's own
/// account holds <code>%All</code> and the real check answers yes to everything; and a logged failure
/// is recorded here instead of written. Each seam counts its calls. No method of the dispatcher itself
/// is replaced.</p>
/// <p>State lives in <code>^||OcuPilotToolDispatchProbe</code>; <method>Reset</method> forgets it.</p>
Class OcuPilot.Test.ToolDispatchProbe Extends OcuPilot.Kernel.Agent.Dispatch
{

ClassMethod Reset()
{
    Kill ^||OcuPilotToolDispatchProbe
}

/// <p>Resolve tools through <var>pClass</var> from now on.</p>
ClassMethod SetRegistryClass(pClass As %String)
{
    Set ^||OcuPilotToolDispatchProbe("registry") = pClass
}

/// <p>Answer every gate decision not allowed, with <var>pCode</var> (<code>""</code> for none).</p>
ClassMethod DenyGate(pCode As %String = "")
{
    Set ^||OcuPilotToolDispatchProbe("gate") = $ListBuild(pCode)
}

/// <p>Answer every gate decision with an error status.</p>
ClassMethod FailGate()
{
    Set ^||OcuPilotToolDispatchProbe("gateError") = 1
}

/// <p>Answer the restraint verdict as <var>pMode</var>: <code>blocked</code> with
/// <var>pCode</var>, <code>clear</code>, or <code>error</code> -- an error status with
/// <code>blocked</code> 0.</p>
ClassMethod ForceRestraint(pMode As %String, pCode As %String = "")
{
    Set ^||OcuPilotToolDispatchProbe("restraint") = $ListBuild(pMode, pCode)
}

/// <p>Answer the pair <var>pResource</var>:<var>pPermission</var> as not held.</p>
ClassMethod DenyPair(pResource As %String, pPermission As %String)
{
    Set ^||OcuPilotToolDispatchProbe("deny", pResource _ ":" _ pPermission) = 1
}

/// <p>How many times seam <var>pSeam</var> (<code>gate</code>, <code>restraint</code>,
/// <code>pair</code>) was asked since the last <method>Reset</method>.</p>
ClassMethod Count(pSeam As %String) As %Integer
{
    Quit +$Get(^||OcuPilotToolDispatchProbe("count", pSeam))
}

/// <p>Every logged failure since the last <method>Reset</method>, one <code>message | code</code>
/// per line.</p>
ClassMethod Logged() As %String
{
    Set tLines = ""
    For tI = 1:1:+$Get(^||OcuPilotToolDispatchProbe("log")) {
        Set tLines = tLines _ $Select(tI = 1: "", 1: $Char(10)) _ $Get(^||OcuPilotToolDispatchProbe("log", tI))
    }
    Quit tLines
}

ClassMethod RegistryClass() As %String
{
    If $Get(^||OcuPilotToolDispatchProbe("registry")) '= "" Quit ^||OcuPilotToolDispatchProbe("registry")
    Quit "OcuPilot.Test.DispatchTool.Registry"
}

/// <p>This class, so <method>Decide</method> answers every gate question.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ToolDispatchProbe"
}

/// <p>The shipped gate's decision, or a denial when a test asked for one; counted either way.</p>
ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    Do $Increment(^||OcuPilotToolDispatchProbe("count", "gate"))
    If $Get(^||OcuPilotToolDispatchProbe("gateError")) Quit $$$ERROR($$$GeneralError, "the probe answered the gate as failed")
    Set tDeny = $Get(^||OcuPilotToolDispatchProbe("gate"))
    If tDeny '= "" {
        Kill pDecision
        Set pDecision("allowed") = 0
        Set pDecision("code") = $List(tDeny, 1)
        Quit $$$OK
    }
    Quit ##class(OcuPilot.Kernel.Governance.Gate).Decide(pTool, pKind, pUser, pArgs, .pDecision)
}

ClassMethod Restraint(pUser As %String, pDefinitionId As %String, Output pVerdict) As %Status
{
    Do $Increment(^||OcuPilotToolDispatchProbe("count", "restraint"))
    Set tForced = $Get(^||OcuPilotToolDispatchProbe("restraint"))
    If tForced = "" Quit ##super(pUser, pDefinitionId, .pVerdict)
    Kill pVerdict
    Set pVerdict("blocked") = 0
    Set pVerdict("code") = ""
    If $List(tForced, 1) = "error" Quit $$$ERROR($$$GeneralError, "the probe answered the restraint read as failed")
    If $List(tForced, 1) = "blocked" {
        Set pVerdict("blocked") = 1
        Set pVerdict("code") = $List(tForced, 2)
    }
    Quit $$$OK
}

ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Do $Increment(^||OcuPilotToolDispatchProbe("count", "pair"))
    Quit '$Get(^||OcuPilotToolDispatchProbe("deny", pResource _ ":" _ pPermission))
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String)
{
    Set ^||OcuPilotToolDispatchProbe("log", $Increment(^||OcuPilotToolDispatchProbe("log"))) = pMessage _ " | " _ pCode
}

}
