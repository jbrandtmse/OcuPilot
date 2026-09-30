/// <p>The external language server editor's port (AD-52, Story 16.25):
/// <class>OcuPilot.Port.AdminPort</class> with one read completed and one delete gated. Every other
/// endpoint and request type is the admin port's own call, unchanged.</p>
/// <p><b>A <code>LanguageServer</code> <code>GET</code> that succeeds is completed by the same
/// server's <code>ACTIVITY</code></b>, sent with the vendor's <code>maxRows</code> 1, and
/// <code>ACTIVITY</code>'s <code>CurrentlyRunning</code> is set on the <code>GET</code>'s answer.
/// Measured on <code>ocupilot-ci</code>: <code>GET</code> answers the whole definition and no running
/// state, while <code>ACTIVITY</code> answers the running state and no definition. The update and the
/// delete refuse a running server and exempt a <code>Remote</code> one, so their one fresh read -- the
/// mint's, the confirm's, the prohibited set's and the screen caller's alike -- needs both (AD-52,
/// AD-53). A failed <code>ACTIVITY</code> fails the whole read.</p>
/// <p><b>A Python server's <code>DELETE</code> is refused to a caller without
/// <parameter>CALLOUTPAIR</parameter></b>, by name and before the vendor is called (AD-8). The
/// vendor's delete removes the server's virtual environment through an operating-system command
/// before its own check refuses such a caller, so the harm happens inside that one call (measured
/// on <code>ocupilot-ci</code>). The server's type is read first, through the admin port's own
/// <code>GET</code>.</p>
/// <p><b>It names no administration API class.</b> Every call goes through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the endpoint's gate, the stubs, the namespace
/// switch and the fault mapping are the admin port's, and AD-27's one-file containment is
/// unchanged.</p>
Class OcuPilot.Port.LanguageServerPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port completes and gates.</p>
Parameter LANGUAGESERVERENDPOINT = "LanguageServer";

/// <p>The request type completed, and the one it is completed from.</p>
Parameter COMPLETEDTYPE = "GET";

Parameter COMPLETINGTYPE = "ACTIVITY";

/// <p>The one <parameter>COMPLETINGTYPE</parameter> field set on the answer.</p>
Parameter COMPLETINGFIELD = "CurrentlyRunning";

/// <p>The vendor's <code>maxRows</code> the completing read sends: the running state rides beside
/// the activity rows, so one row is all the read needs.</p>
Parameter COMPLETINGMAXROWS As INTEGER = 1;

/// <p>The request type gated, the server type it is gated for, and the pair it requires.</p>
Parameter DELETETYPE = "DELETE";

Parameter PYTHONTYPE = "Python";

Parameter CALLOUTPAIR = "%System_CallOut:USE";

/// <p>The admin port's call, with a Python server's <parameter>DELETETYPE</parameter> refused to a
/// caller without <parameter>CALLOUTPAIR</parameter>, and a successful
/// <parameter>COMPLETEDTYPE</parameter> followed by <parameter>COMPLETINGTYPE</parameter> for the same
/// server with <parameter>COMPLETINGFIELD</parameter> set on <var>pResult</var>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. A failed <code>GET</code> answers exactly as the
/// admin port does. A failed <code>ACTIVITY</code> fails the whole read with its own status, HTTP
/// status and fault, and <var>pResult</var> empty, so a caller never sees a server half-read. An
/// <code>ACTIVITY</code> that answers no boolean <code>CurrentlyRunning</code> leaves the field absent,
/// which a caller that needs it refuses. The gated delete answers 403 with the privilege denial's
/// envelope and <code>detail.failedPair</code> naming the pair; its type read's failure is answered as
/// that read's.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#LANGUAGESERVERENDPOINT) && (pType = ..#DELETETYPE) {
        ; AD-8: the server's type is read first, and a Python server's delete is refused to a
        ; caller without the call-out pair before the vendor is reached. A type read that fails is
        ; answered as that read's failure, so nothing is deleted on an unread type.
        Set tReadSC = ##super(pEndpoint, ..#COMPLETEDTYPE, .pQuery, "", .tStored, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) {
            Set pResult = ""
            Set pHttpStatus = tReadHttp
            Set pFault = tReadFault
            Quit tReadSC
        }
        If ..CallOutRefused($Get(tStored), .pHttpStatus, .pFault) {
            Set pResult = ""
            Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code() _ ": " _ ..#CALLOUTPAIR)
        }
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If (pEndpoint '= ..#LANGUAGESERVERENDPOINT) || (pType '= ..#COMPLETEDTYPE) Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Quit tSC
    Kill tQuery
    Merge tQuery = pQuery
    Set tQuery("maxRows") = ..#COMPLETINGMAXROWS
    Set tActivitySC = ##super(pEndpoint, ..#COMPLETINGTYPE, .tQuery, "", .tActivity, .tActivityHttp, .tActivityFault)
    If $$$ISERR(tActivitySC) {
        Set pResult = ""
        Set pHttpStatus = tActivityHttp
        Set pFault = tActivityFault
        Quit tActivitySC
    }
    If $IsObject(tActivity) && tActivity.%IsA("%Library.DynamicObject") && (tActivity.%GetTypeOf(..#COMPLETINGFIELD) = "boolean") {
        Do pResult.%Set(..#COMPLETINGFIELD, tActivity.%Get(..#COMPLETINGFIELD), "boolean")
    }
    Quit tSC
}

/// <p>Whether the server <var>pStored</var> describes is a Python server whose delete the caller
/// may not make: its <code>Type</code> is <parameter>PYTHONTYPE</parameter> and the caller does not
/// hold <parameter>CALLOUTPAIR</parameter>. When it is, <var>pHttpStatus</var> is 403 and
/// <var>pFault</var> the privilege denial's, naming the pair (<class>OcuPilot.Kernel.Denial</class>).</p>
ClassMethod CallOutRefused(pStored, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Boolean
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tType = ""
    If $IsObject(pStored) && pStored.%IsA("%Library.DynamicObject") Set tType = pStored.%Get("Type")
    If tType '= ..#PYTHONTYPE Quit 0
    If ..HoldsPair(..#CALLOUTPAIR) Quit 0
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(..#CALLOUTPAIR)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit 1
}

/// <p>The admin port's answer: this port's writes are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): the admin port's own forms. The
/// completing <code>ACTIVITY</code> and the delete's type read are reads, and the call-out gate
/// refuses rather than calls, so every write this port sends is the admin port's route.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
