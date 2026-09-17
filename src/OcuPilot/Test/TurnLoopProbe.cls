/// <p>Test-only <class>OcuPilot.Kernel.Agent.Loop</class> subclass whose seams are switches, so the
/// loop runs in process with no socket: the port is <class>OcuPilot.Test.ProviderPortProbe</class>,
/// the limits are <class>OcuPilot.Test.TurnLimits</class> unless a test names others, the dispatcher
/// is the shipped one unless a test names another, the restraint verdict is the real one unless
/// a test forces the kill switch on -- from the start, or once a number of tool calls have been
/// answered -- enforced read-only on, or the read to fail, and a logged failure is recorded here
/// instead of written. No
/// method of the loop itself is replaced.</p>
Class OcuPilot.Test.TurnLoopProbe Extends OcuPilot.Kernel.Agent.Loop
{

/// <p>Forget every switch.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotTurnLoopProbe
}

/// <p>Answer the kill switch on, with <var>pCode</var> as its code, from now on.</p>
ClassMethod ForceKillSwitch(pCode As %String)
{
    Set ^||OcuPilotTurnLoopProbe("killSwitch") = pCode
}

/// <p>Answer the kill switch on, with <var>pCode</var> as its code, once <var>pCalls</var> tool calls
/// have been answered through <method>DispatchTools</method>.</p>
ClassMethod ForceKillSwitchAfterCalls(pCalls As %Integer, pCode As %String)
{
    Set ^||OcuPilotTurnLoopProbe("killAfter") = $ListBuild(pCalls, pCode)
}

/// <p>Answer enforced read-only on from now on.</p>
ClassMethod ForceReadOnly()
{
    Set ^||OcuPilotTurnLoopProbe("readOnly") = 1
}

/// <p>Answer the restraint read as failed from now on, with the verdict a failed read leaves:
/// neither the kill switch nor read-only on.</p>
ClassMethod ForceRestraintError()
{
    Set ^||OcuPilotTurnLoopProbe("restraintError") = 1
}

/// <p>Answer <var>pClass</var> as the dispatcher from now on; <code>""</code> restores the shipped
/// one.</p>
ClassMethod SetDispatchClass(pClass As %String)
{
    Set ^||OcuPilotTurnLoopProbe("dispatch") = pClass
}

/// <p>Answer <var>pClass</var> as the limits from now on; <code>""</code> restores
/// <class>OcuPilot.Test.TurnLimits</class>.</p>
ClassMethod SetLimitsClass(pClass As %String)
{
    Set ^||OcuPilotTurnLoopProbe("limits") = pClass
}

/// <p>Every logged failure since the last <method>Reset</method>, one <code>message | code</code>
/// per line.</p>
ClassMethod Logged() As %String
{
    Set tLines = ""
    For tI = 1:1:+$Get(^||OcuPilotTurnLoopProbe("log")) {
        Set tLines = tLines _ $Select(tI = 1: "", 1: $Char(10)) _ $Get(^||OcuPilotTurnLoopProbe("log", tI))
    }
    Quit tLines
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String)
{
    Set ^||OcuPilotTurnLoopProbe("log", $Increment(^||OcuPilotTurnLoopProbe("log"))) = pMessage _ " | " _ pCode
}

/// <p>The shipped dispatch, counting the calls it answers and arming the kill switch when
/// <method>ForceKillSwitchAfterCalls</method>' count is reached.</p>
ClassMethod DispatchTools(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray) As %Status
{
    Set tSC = ##super(pKey, pUser, pDefinitionId, pToolUses, pLimitsClass, .pResults, .pNames)
    Set tAnswered = $Increment(^||OcuPilotTurnLoopProbe("answered"), pToolUses.%Size())
    Set tAfter = $Get(^||OcuPilotTurnLoopProbe("killAfter"))
    If (tAfter '= "") && (tAnswered >= $List(tAfter, 1)) Do ..ForceKillSwitch($List(tAfter, 2))
    Quit tSC
}

ClassMethod LimitsClass() As %String
{
    If $Get(^||OcuPilotTurnLoopProbe("limits")) '= "" Quit ^||OcuPilotTurnLoopProbe("limits")
    Quit "OcuPilot.Test.TurnLimits"
}

ClassMethod DispatchClass() As %String
{
    If $Get(^||OcuPilotTurnLoopProbe("dispatch")) '= "" Quit ^||OcuPilotTurnLoopProbe("dispatch")
    Quit ##super()
}

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProviderPortProbe"
}

/// <p>The real verdict, with the kill switch or read-only forced on, or the read failed, when a test
/// asked for it.</p>
ClassMethod Restraint(pUser As %String, Output pVerdict) As %Status
{
    If $Get(^||OcuPilotTurnLoopProbe("restraintError")) {
        Kill pVerdict
        Set pVerdict("blocked") = 1
        Set pVerdict("killSwitch") = 0
        Set pVerdict("enforcedReadOnly") = 0
        Quit $$$ERROR($$$GeneralError, "the probe answered the switches as unreadable")
    }
    Set tSC = ##super(pUser, .pVerdict)
    If $Get(^||OcuPilotTurnLoopProbe("readOnly")) Set pVerdict("enforcedReadOnly") = 1
    If $Get(^||OcuPilotTurnLoopProbe("killSwitch")) '= "" {
        Set pVerdict("killSwitch") = 1
        Set pVerdict("code") = ^||OcuPilotTurnLoopProbe("killSwitch")
    }
    Quit tSC
}

}
