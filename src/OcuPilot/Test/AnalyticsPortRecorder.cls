/// <p><class>OcuPilot.Port.AnalyticsPort</class> that counts the statements handed to <method>MdxPrepare</method>, in the process-private
/// <code>^||OcuPilotMdxPrepares</code>, and then prepares them as the port does. A test that drives
/// <class>OcuPilot.Test.AnalyticsMdxReadFixture</class> reads <method>Count</method> to show that a refused statement was never prepared.
/// Everything else is the port's.</p>
Class OcuPilot.Test.AnalyticsPortRecorder Extends OcuPilot.Port.AnalyticsPort
{

/// <p>Forget the count.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotMdxPrepares
}

/// <p>How many statements <method>MdxPrepare</method> has been handed in this process since <method>Reset</method>.</p>
ClassMethod Count() As %Integer
{
    Quit +$Get(^||OcuPilotMdxPrepares)
}

ClassMethod MdxPrepare(pNamespace As %String, pText As %String, Output pRS, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pAsk As %Boolean, Output pFound As %List, ByRef pVariables) As %Status
{
    Set ^||OcuPilotMdxPrepares = $Get(^||OcuPilotMdxPrepares) + 1
    Quit ##super(pNamespace, pText, .pRS, .pAnswer, .pHttpStatus, .pFault, .pAsk, .pFound, .pVariables)
}

}
