/// <p>A seam subclass of <class>OcuPilot.Port.AdminPort</class> for Story 18.5's journal suites: it
/// counts each vendor call it makes -- every call reaches the endpoint's own resource gate once
/// (<method>HoldsResource</method>) -- and reaches the private journal file guard
/// (<method>Guard</method>), so a test can show a refusal made before the vendor was called for the
/// target, and can answer a file's <code>GET</code> absent (<method>AnswerAbsent</method>). State lives
/// in <code>^||OcuPilotJournalCountPort</code>; <method>Reset</method> forgets it. Nothing about the
/// instance is changed.</p>
Class OcuPilot.Test.JournalCountPort Extends OcuPilot.Port.AdminPort
{

/// <p>Forget the count and what was armed.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotJournalCountPort
}

/// <p>Answer the next <code>Journal.File</code> <code>GET</code>s as the admin port answers an absent
/// object, 404 <code>PORT.NOTFOUND</code>, without calling the instance, until <method>Reset</method>.</p>
ClassMethod AnswerAbsent()
{
    Set ^||OcuPilotJournalCountPort("absent") = 1
}

/// <p>The admin port's call, or the armed absence (<method>AnswerAbsent</method>).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If '$Get(^||OcuPilotJournalCountPort("absent")) || (pEndpoint '= "Journal.File") || (pType '= "GET") Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 404
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "The instance has no such object")
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>How many vendor calls this port has made since <method>Reset</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotJournalCountPort("calls"))
}

/// <p>The admin port's own gate, counted: it is asked once per vendor call, before the endpoint's
/// semantics or <code>Run()</code>.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Set ^||OcuPilotJournalCountPort("calls") = ..Calls() + 1
    Quit ##super(pResource)
}

/// <p>The journal file guard for <var>pEndpoint</var>'s request type <var>pType</var> over the query
/// <var>pQuery</var>, which it may complete, answering its status, HTTP status and fault.</p>
ClassMethod Guard(pEndpoint As %String, pType As %String, ByRef pQuery, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..JournalGuard(pEndpoint, pType, .pQuery, .pHttpStatus, .pFault)
}

}
