/// <p>Fixture: <class>OcuPilot.Test.ProviderStub</class> with one observation added -- the value of
/// the adapter's own <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> <b>after</b>
/// <method>Invoke</method> has returned (Story 5.4, AC5).</p>
/// <p>It has to be observed from inside the adapter: the port constructs the instance and no
/// caller holds a reference to it, so "the in-memory holder is empty when the call ends" is not
/// observable from outside. The recording runs after <code>##super</code>, which is where the
/// shipped clear has already run on every exit path.</p>
Class OcuPilot.Test.ResidueStub Extends OcuPilot.Test.ProviderStub
{

/// <p>Forget what was observed.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotResidueStub
}

/// <p>The key the adapter still held when its last <method>Invoke</method> returned, and
/// <code>"unobserved"</code> when no call has been made since <method>Clear</method>.</p>
ClassMethod KeyAfterCall() As %String
{
    Quit $Get(^||OcuPilotResidueStub("after"), "unobserved")
}

/// <p>How many calls have been observed since <method>Clear</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotResidueStub("calls"))
}

Method Invoke(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String = "", ByRef pSettings, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pFault As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set tSC = ##super(.pValues, .pMessages, .pTools, pSystemPrompt, .pSettings, .pResponse, .pFault, .pHttpStatus)
    Set ^||OcuPilotResidueStub("after") = ..ApiKey
    Set ^||OcuPilotResidueStub("calls") = $Get(^||OcuPilotResidueStub("calls"), 0) + 1
    Quit tSC
}

}
