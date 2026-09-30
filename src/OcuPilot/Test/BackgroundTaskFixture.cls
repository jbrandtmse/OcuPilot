/// <p>Subclass of <class>OcuPilot.Port.BackgroundTaskPort</class> overriding only its seams, so the
/// Background tasks tests run the port's real merge, fresh read, control routing and refusal
/// mapping against armed answers: the portal's rows, the admin API's <code>AsyncResult</code>
/// answers, the database half and its links to the admin rows (Story 18.4), what the portal's
/// background task answers a control, and a denied pair. Every call it
/// would make is recorded rather than made.</p>
/// <p>State lives in <code>^||OcuPilotBackgroundFixture</code>; <method>Clear</method> forgets it.
/// Nothing on the instance is read or changed.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundTaskFixture Extends OcuPilot.Port.BackgroundTaskPort
{

/// <p>Answer the portal half with the rows <var>pJson</var>, each carrying
/// <code>SysBGTaskId</code>.</p>
ClassMethod ArmPortal(pJson As %String)
{
    Set ^||OcuPilotBackgroundFixture("portal") = pJson
}

/// <p>Answer the task database query with the rows <var>pJson</var>, each <code>{ID, Database,
/// HasEnded}</code>, which the port's own <code>KeepRunning</code> then filters (Story 18.3), or fail
/// that read with <code>"fail"</code>. Unarmed, no task runs against a database.</p>
ClassMethod ArmDatabases(pJson As %String)
{
    Set ^||OcuPilotBackgroundFixture("databases") = pJson
}

/// <p>Answer the database half (Story 18.4, DW-1821) with the rows <var>pJson</var>, each as
/// <code>DatabaseRows</code> answers one, or fail that read with <code>"fail"</code>. Unarmed, no task
/// runs against a database.</p>
ClassMethod ArmDatabaseRows(pJson As %String)
{
    Set ^||OcuPilotBackgroundFixture("databaseRows") = pJson
}

/// <p>Link the caller's async tasks to background tasks (Story 18.4, DW-1821): <var>pJson</var> is an
/// object from each GUID to its background task id. Unarmed, no task is linked.</p>
ClassMethod ArmTaskLinks(pJson As %String)
{
    Set ^||OcuPilotBackgroundFixture("links") = pJson
}

/// <p>Answer the admin API's <code>AsyncResult</code> <code>LIST</code> with the vendor rows
/// <var>pJson</var>.</p>
ClassMethod ArmAdmin(pJson As %String)
{
    Set ^||OcuPilotBackgroundFixture("admin") = pJson
}

/// <p>Answer a portal control with vendor error <var>pCode</var>, or OK for 0; <code>"absent"</code>
/// answers a background task that no longer opens.</p>
ClassMethod ArmPortalAnswer(pCode As %String)
{
    Set ^||OcuPilotBackgroundFixture("portalAnswer") = pCode
}

/// <p>Answer an admin API control at HTTP <var>pHttp</var>.</p>
ClassMethod ArmAdminAnswer(pHttp As %Integer)
{
    Set ^||OcuPilotBackgroundFixture("adminAnswer") = pHttp
}

/// <p>Answer the gate as not holding <var>pPair</var>.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotBackgroundFixture("denied") = pPair
}

/// <p>Every control call made, oldest first, each <code>PORTAL &lt;type&gt; &lt;task id&gt;</code>
/// or <code>ADMIN &lt;type&gt; &lt;GUID&gt;</code>, joined by <code>|</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotBackgroundFixture("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tCall
    }
    Quit tOut
}

/// <p>How many times either half was read.</p>
ClassMethod Reads() As %Integer
{
    Quit +$Get(^||OcuPilotBackgroundFixture("reads"))
}

/// <p>Forget every armed answer and record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotBackgroundFixture
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Get(^||OcuPilotBackgroundFixture("denied")) = pPair Quit 0
    Quit 1
}

ClassMethod PortalRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Do $Increment(^||OcuPilotBackgroundFixture("reads"))
    Set pRows = ##class(%DynamicArray).%FromJSON($Get(^||OcuPilotBackgroundFixture("portal"), "[]"))
    Quit $$$OK
}

ClassMethod TaskDatabases(Output pDatabases) As %Status [ Private ]
{
    Kill pDatabases
    Set tArmed = $Get(^||OcuPilotBackgroundFixture("databases"), "[]")
    If tArmed = "fail" Quit $$$ERROR($$$GeneralError, "the armed task database read fails")
    Do ..KeepRunning(##class(%DynamicArray).%FromJSON(tArmed), .pDatabases)
    Quit $$$OK
}

ClassMethod DatabaseRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set pRows = []
    Set tArmed = $Get(^||OcuPilotBackgroundFixture("databaseRows"), "[]")
    If tArmed = "fail" Quit $$$ERROR($$$GeneralError, "the armed database half fails")
    Set pRows = ##class(%DynamicArray).%FromJSON(tArmed)
    Quit $$$OK
}

ClassMethod TaskLinks(pGuids As %List, Output pLinks) As %Status [ Private ]
{
    Kill pLinks
    Set tLinks = ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotBackgroundFixture("links"), "{}"))
    For tI = 1:1:$ListLength(pGuids) {
        Set tGuid = $List(pGuids, tI)
        If tLinks.%IsDefined(tGuid) Set pLinks(tGuid) = tLinks.%Get(tGuid)
    }
    Quit $$$OK
}

/// <p>The admin API's <code>AsyncResult</code> answers, armed; every other call is refused 501,
/// so nothing reaches the instance.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint = ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pFault = ""
    If (pEndpoint = ..#ASYNCRESULTENDPOINT) && (pType = ..#LISTTYPE) {
        Do $Increment(^||OcuPilotBackgroundFixture("reads"))
        Set pResult = ##class(%DynamicArray).%FromJSON($Get(^||OcuPilotBackgroundFixture("admin"), "[]"))
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If (pEndpoint = ..#ASYNCRESULTENDPOINT) && (..ControlMethod(pType) '= "") {
        Set ^||OcuPilotBackgroundFixture("calls", $Increment(^||OcuPilotBackgroundFixture("calls"))) = "ADMIN " _ pType _ " " _ $Get(pQuery(..#IDPARAM))
        Set pHttpStatus = +$Get(^||OcuPilotBackgroundFixture("adminAnswer"), 200)
        If pHttpStatus = 200 {
            Set pResult = {}
            Quit $$$OK
        }
        Quit ..Fail(pEndpoint, pHttpStatus, $$$ERROR($$$GeneralError, "the armed refusal"), .pHttpStatus, .pFault)
    }
    Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
}

ClassMethod PortalControl(pTaskId As %String, pType As %String, Output pAbsent As %Boolean, Output pVendorSC As %Status) As %Status [ Private ]
{
    Set ^||OcuPilotBackgroundFixture("calls", $Increment(^||OcuPilotBackgroundFixture("calls"))) = "PORTAL " _ pType _ " " _ pTaskId
    Set pAbsent = 0
    Set pVendorSC = $$$OK
    Set tAnswer = $Get(^||OcuPilotBackgroundFixture("portalAnswer"), 0)
    If tAnswer = "absent" {
        Set pAbsent = 1
    } ElseIf +tAnswer '= 0 {
        Set pVendorSC = $System.Status.Error(+tAnswer)
    }
    Quit $$$OK
}

/// <p>Faults are logged nowhere: the log write is captured by
/// <class>OcuPilot.Test.LogProbe</class> rather than reaching <file>messages.log</file>.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

}
