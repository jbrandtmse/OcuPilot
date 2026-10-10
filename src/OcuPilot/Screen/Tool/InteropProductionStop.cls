/// <p>Interoperability's production stop (AD-6, AD-51, AD-53, AD-62): Stop a running production, waiting at most the port's cap for work in progress. The vendor answers a stop of a production that is not running as a success that changes nothing, which the port refuses before any vendor call.</p>
/// <p>Two callers reach it: the Productions row action Stop through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
/// <p><b>A stop that answers OK can leave the production Suspended</b> (messages still queued behind it), which
/// the vendor does not report. <method>AfterWrite</method> re-reads the state and answers 409
/// <parameter>OcuPilot.Api.InteropError.SUSPENDED</parameter>; the stop was applied and stays marked.</p>
Class OcuPilot.Screen.Tool.InteropProductionStop Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.stop";

Parameter DESCRIPTION = "Propose stopping one running production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. The stop waits up to 15 seconds for work in progress to finish; if it takes longer nothing is stopped. A production that is not running is refused.";

Parameter SCREENACTIONS = "stop";

Parameter WRITETYPE = "STOP";

Parameter FINGERPRINTSUBJECT = "State,Namespace";

Parameter AFTERWORD = "Stopped";

Parameter CONSEQUENCECODE = "INTEROP.STOP";

/// <p>The code <method>AfterWrite</method> answers for a stop that left the production Suspended, the one
/// <class>OcuPilot.Api.InteropError</class> publishes as <parameter>SUSPENDED</parameter> and its sentence.</p>
Parameter SUSPENDEDCODE = "INTEROP.PRODUCTION.SUSPENDED";

/// <p>Re-read the production's state through <var>pPort</var> once the stop has read OK, in the namespace the
/// fresh read <var>pFresh</var> names. A production that reads Suspended is 409
/// <parameter>OcuPilot.Api.InteropError.SUSPENDED</parameter> with <code>detail.state</code>; any other state, a
/// read that fails and a fault leave the stop's own answer alone.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery(pIdParam) = pIdValue
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pFresh.%Get(..#NAMESPACEFIELD) '= "") {
            Set tQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pFresh.%Get(..#NAMESPACEFIELD)
        }
        Set tReadSC = $ClassMethod(pPort, "Invoke", pEndpoint, ..ReadType(), .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tReadSC) || '$IsObject($Get(tAnswer)) Quit
        If tAnswer.%Get("State") '= "Suspended" Quit
        Set tCode = ..#SUSPENDEDCODE
        Set pHttpStatus = 409
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, tCode, ##class(OcuPilot.Api.Error).ReasonForToolCode(tCode))
        Do pFault.%Set("detail", {"state": "Suspended"})
        Set tSC = $$$ERROR($$$GeneralError, tCode)
    } Catch {
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = $$$OK
    }
    Quit tSC
}

/// <p><method>AfterWrite</method> as a copy-out script step (AD-59): the production's state read once the
/// stop has run, in the namespace the stop's own step switched to. A production that still has messages
/// queued reads 3, Suspended, which the stop itself does not report.</p>
ClassMethod SnippetAfter(pEndpoint As %String, pIdParam As %String, pIdValue As %String, pStoredPayload As %DynamicObject, pContext As %DynamicObject = "") As %DynamicArray
{
    Set tText = " Set tSC = ##class(Ens.Director).GetProductionStatus(.tProduction, .tState)"
    Set tText = tText _ $Char(10) _ " ; tState reads 1 Running, 2 Stopped, 3 Suspended or 4 Troubled"
    Set tText = tText _ $Char(10) _ " ZWrite tState"
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

}
