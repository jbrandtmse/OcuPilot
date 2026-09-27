/// <p>A <class>OcuPilot.Kernel.Agent.Sanitize</class> whose <method>Clean</method> always throws and
/// whose <method>LogFault</method> counts its calls in <code>^||OcuPilotSanitizeFault</code>, so
/// <class>OcuPilot.Test.Sanitize</class> can drive the fail-closed path and observe the log call.
/// No storage.</p>
Class OcuPilot.Test.SanitizeFault Extends OcuPilot.Kernel.Agent.Sanitize
{

ClassMethod Clean(pText As %String, ByRef pMatchers) As %String
{
    Throw ##class(%Exception.General).%New("OcuPilotProbeSanitizeFault", 5001, , "the probe cleaner refuses every string")
}

ClassMethod LogFault(pStatus As %Status)
{
    Set ^||OcuPilotSanitizeFault = $Get(^||OcuPilotSanitizeFault) + 1
}

}
