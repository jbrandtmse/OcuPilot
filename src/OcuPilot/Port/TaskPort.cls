/// <p>The task delete's port (AD-52): <class>OcuPilot.Port.AdminPort</class> with one read
/// completed. A <code>Task.CRUD</code> <code>GET</code> that succeeds is followed by the same
/// endpoint's <code>INFO</code> with the same query, and <code>INFO</code>'s <code>Type</code> is
/// set on the <code>GET</code>'s answer. Every other endpoint and request type is the admin port's
/// own call, unchanged.</p>
/// <p><b>Why the read is completed here.</b> Measured on this build: <code>GET</code> answers the
/// task's <code>Name</code>, <code>TaskClass</code> and <code>NameSpace</code> and no
/// <code>Type</code>, while <code>INFO</code> answers <code>Type</code> (<code>System</code> or
/// <code>User</code>) and no <code>Name</code>. A delete's card names the task and says whether it
/// is one of the instance's own system tasks, so its one fresh read needs both. Which request
/// types carry which field is a vendor wire fact, so it lives in a port (AD-27); the tool declaring
/// this port is what makes the mint's read, the confirm's re-read, the prohibited set's live read
/// and the screen caller's read one answer (AD-52, AD-53).</p>
/// <p><b>It names no administration API class.</b> Both calls go through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the endpoint's gate, the stubs, the
/// namespace switch and the fault mapping are the admin port's, and AD-27's one-file containment
/// is unchanged.</p>
/// <p><b>A create's answer carries the new task's <code>Id</code></b> (Story 9.7). The vendor's
/// <code>POST</code> answers the saved task without its id, which is only in the 201's
/// <code>Location</code> header (<code>/api/admin/v1/task?id=&lt;n&gt;</code>, measured on this
/// build); this port reads that header and sets <code>Id</code>, an integer, on the answer.</p>
Class OcuPilot.Port.TaskPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint whose <code>GET</code> this port completes.</p>
Parameter TASKENDPOINT = "Task.CRUD";

/// <p>The request type completed, and the one it is completed from.</p>
Parameter COMPLETEDTYPE = "GET";

Parameter COMPLETINGTYPE = "INFO";

/// <p>The one <parameter>COMPLETINGTYPE</parameter> field set on the answer.</p>
Parameter COMPLETINGFIELD = "Type";

/// <p>The create's request type, whose answer gains <parameter>CREATEDFIELD</parameter>.</p>
Parameter CREATETYPE = "POST";

/// <p>The field the new task's id is set under.</p>
Parameter CREATEDFIELD = "Id";

/// <p>The admin port's call, with a successful <parameter>TASKENDPOINT</parameter>
/// <parameter>COMPLETEDTYPE</parameter> followed by <parameter>COMPLETINGTYPE</parameter> over
/// the same <var>pQuery</var> and <parameter>COMPLETINGFIELD</parameter> set on
/// <var>pResult</var>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. A failed <code>GET</code> answers exactly as
/// the admin port does. A failed <code>INFO</code> fails the whole read with <code>INFO</code>'s
/// status, HTTP status and fault, and <var>pResult</var> empty, so a caller never sees a task
/// half-read. An <code>INFO</code> that answers no string <code>Type</code> leaves the field
/// absent, which a caller that needs it refuses.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#TASKENDPOINT) && (pType = ..#CREATETYPE) Quit ..Create(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If (pEndpoint '= ..#TASKENDPOINT) || (pType '= ..#COMPLETEDTYPE) Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Quit tSC
    Set tInfoSC = ##super(pEndpoint, ..#COMPLETINGTYPE, .pQuery, "", .tInfo, .tInfoHttp, .tInfoFault)
    If $$$ISERR(tInfoSC) {
        Set pResult = ""
        Set pHttpStatus = tInfoHttp
        Set pFault = tInfoFault
        Quit tInfoSC
    }
    If $IsObject(tInfo) && tInfo.%IsA("%Library.DynamicObject") && (tInfo.%GetTypeOf(..#COMPLETINGFIELD) = "string") {
        Do pResult.%Set(..#COMPLETINGFIELD, tInfo.%Get(..#COMPLETINGFIELD), "string")
    }
    Quit tSC
}

/// <p>The admin port's create, with the new task's id read from the 201's <code>Location</code> and
/// set on <var>pResult</var> as <parameter>CREATEDFIELD</parameter>. A 2xx whose header carries no
/// numeric <code>id=</code> leaves the field absent, which a caller that needs it refuses.</p>
ClassMethod Create(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tLocation)
    If $$$ISERR(tSC) Quit tSC
    Set tId = $Piece($Piece($Get(tLocation), "id=", 2), "&", 1)
    If '$Match(tId, "^[0-9]+$") Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Set pResult = {}
    Do pResult.%Set(..#CREATEDFIELD, +tId, "number")
    Quit tSC
}

}
