/// <p>A seam subclass of <class>OcuPilot.Port.AdminPort</class> for Story 18.5's journal suites: it
/// counts each vendor call it makes -- every call reaches the endpoint's own resource gate once
/// (<method>HoldsResource</method>) -- and reaches the private journal file guard
/// (<method>Guard</method>), so a test can show a refusal made before the vendor was called for the
/// target, and can answer a file's <code>GET</code> absent (<method>AnswerAbsent</method>). State lives
/// in <code>^||OcuPilotJournalCountPort</code>; <method>Reset</method> forgets it. Nothing about the
/// instance is changed. It also records what each vendor call was sent (<method>SentKeys</method>).</p>
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
/// semantics or <code>Run()</code>. Each call's stub request URL and query parameters are recorded
/// for <method>SentKeys</method> (Story 18.19).</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Set tCall = ..Calls() + 1
    Set ^||OcuPilotJournalCountPort("calls") = tCall
    If $IsObject($Get(%request)) {
        Set ^||OcuPilotJournalCountPort("sent", tCall) = %request.URL
        Set tName = ""
        For {
            Set tName = $Order(%request.Data(tName))
            If tName = "" Quit
            Set ^||OcuPilotJournalCountPort("sent", tCall, tName) = $Get(%request.Data(tName, 1))
        }
    }
    Quit ##super(pResource)
}

/// <p>The query parameter names the last vendor call whose stub URL ends with <var>pUrlEnd</var> was
/// sent with, comma-separated in collation order, or <code>"none"</code> when no such call was made
/// since <method>Reset</method>.</p>
ClassMethod SentKeys(pUrlEnd As %String) As %String
{
    Set tCall = ""
    For {
        Set tCall = $Order(^||OcuPilotJournalCountPort("sent", tCall), -1)
        If tCall = "" Quit
        Set tUrl = ^||OcuPilotJournalCountPort("sent", tCall)
        If $Extract(tUrl, * - $Length(pUrlEnd) + 1, *) = pUrlEnd Quit
    }
    If tCall = "" Quit "none"
    Set tKeys = ""
    Set tName = ""
    For {
        Set tName = $Order(^||OcuPilotJournalCountPort("sent", tCall, tName))
        If tName = "" Quit
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tName
    }
    Quit tKeys
}

/// <p>The journal file guard for <var>pEndpoint</var>'s request type <var>pType</var> over the query
/// <var>pQuery</var>, which it may complete, answering its status, HTTP status and fault.</p>
ClassMethod Guard(pEndpoint As %String, pType As %String, ByRef pQuery, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..JournalGuard(pEndpoint, pType, .pQuery, .pHttpStatus, .pFault)
}

}
