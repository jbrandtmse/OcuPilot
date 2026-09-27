/// <p>Subclass of <class>OcuPilot.Port.LogSourcePort</class> overriding only its secondary-log vendor
/// seams -- the <code>Fetch*</code> methods and <method>Interoperable</method> -- so
/// <class>OcuPilot.Test.LogSecondary</class> drives the readers' real mapping, merge and cap
/// against rows it arms. It never reaches a vendor store: an unarmed fetch answers no rows.</p>
/// <p>Every seam call is counted, in total and per method and namespace, which is how "no read
/// before the gate" and "no read for a refused namespace" are observed. A fault can be armed per
/// method and namespace. State lives in <code>^||OcuPilotRecordsFixture</code>; <method>Clear</method>
/// forgets it.</p>
Class OcuPilot.Test.LogRecordsFixture Extends OcuPilot.Port.LogSourcePort
{

/// <p>Forget every armed row, fault and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotRecordsFixture
}

/// <p>Arm one background task, <code>$ListBuild(ID, StartTime, Namespace, Task, Status,
/// Details)</code>, in listing order.</p>
ClassMethod AddTask(pTask As %List)
{
    Set tAt = $Get(^||OcuPilotRecordsFixture("tasks"), 0) + 1
    Set ^||OcuPilotRecordsFixture("tasks") = tAt
    Set ^||OcuPilotRecordsFixture("tasks", tAt) = pTask
}

/// <p>Arm one error log row, <code>$ListBuild(Type, ErrorNo, ErrorText)</code>, for task
/// <var>pId</var>.</p>
ClassMethod AddTaskError(pId As %String, pRow As %List)
{
    Set tAt = $Get(^||OcuPilotRecordsFixture("taskErrors", pId), 0) + 1
    Set ^||OcuPilotRecordsFixture("taskErrors", pId) = tAt
    Set ^||OcuPilotRecordsFixture("taskErrors", pId, tAt) = pRow
}

/// <p>Arm one row answered by <var>pMethod</var> (<code>FetchXdbc</code>,
/// <code>FetchDiagnostics</code> or <code>FetchEvents</code>) for namespace <var>pNamespace</var>,
/// in the shape that method documents, with <var>pMessages</var> as a diagnostics result's
/// messages.</p>
ClassMethod AddRow(pMethod As %String, pNamespace As %String, pRow As %List, pMessages As %List = "")
{
    Set tAt = $Get(^||OcuPilotRecordsFixture("rows", pMethod, pNamespace), 0) + 1
    Set ^||OcuPilotRecordsFixture("rows", pMethod, pNamespace) = tAt
    Set ^||OcuPilotRecordsFixture("rows", pMethod, pNamespace, tAt) = pRow
    For tI = 1:1:$ListLength(pMessages) {
        Set ^||OcuPilotRecordsFixture("rows", pMethod, pNamespace, tAt, tI) = $List(pMessages, tI)
    }
}

/// <p>Make <method>Interoperable</method> answer <var>pAnswer</var> for <var>pNamespace</var>;
/// unarmed, it answers 1.</p>
ClassMethod SetInteroperable(pNamespace As %String, pAnswer As %Boolean)
{
    Set ^||OcuPilotRecordsFixture("interop", pNamespace) = ''pAnswer
}

/// <p>Make <var>pMethod</var> fail for <var>pNamespace</var> (<code>""</code> for the instance
/// fetchers), as a <code>&lt;PROTECT&gt;</code> would.</p>
ClassMethod SetFault(pMethod As %String, pNamespace As %String = "")
{
    Set ^||OcuPilotRecordsFixture("fault", pMethod, $Select(pNamespace = "": " ", 1: pNamespace)) = 1
}

/// <p>How many seam calls were made since <method>Clear</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotRecordsFixture("calls"), 0)
}

/// <p>How many calls <var>pMethod</var> took for <var>pNamespace</var>.</p>
ClassMethod CallsFor(pMethod As %String, pNamespace As %String = "") As %Integer
{
    Quit +$Get(^||OcuPilotRecordsFixture("callsFor", pMethod, $Select(pNamespace = "": " ", 1: pNamespace)), 0)
}

/// <p>Count a call, and answer the armed fault for it when there is one.</p>
ClassMethod Count(pMethod As %String, pNamespace As %String = "") As %Status [ Private ]
{
    Set tKey = $Select(pNamespace = "": " ", 1: pNamespace)
    Set ^||OcuPilotRecordsFixture("calls") = $Get(^||OcuPilotRecordsFixture("calls"), 0) + 1
    Set ^||OcuPilotRecordsFixture("callsFor", pMethod, tKey) = $Get(^||OcuPilotRecordsFixture("callsFor", pMethod, tKey), 0) + 1
    If $Get(^||OcuPilotRecordsFixture("fault", pMethod, tKey)) Quit $$$ERROR($$$GeneralError, "<PROTECT> armed by the fixture")
    Quit $$$OK
}

ClassMethod FetchTasks(Output pTasks) As %Status
{
    Kill pTasks
    Set tSC = ..Count("FetchTasks")
    If $$$ISERR(tSC) Quit tSC
    For tAt = 1:1:$Get(^||OcuPilotRecordsFixture("tasks"), 0) {
        Set pTasks(tAt) = ^||OcuPilotRecordsFixture("tasks", tAt)
    }
    Quit $$$OK
}

ClassMethod FetchTaskErrors(pId As %String, pMax As %Integer, Output pRows, Output pCut As %Boolean) As %Status
{
    Kill pRows
    Set pCut = 0
    Set tSC = ..Count("FetchTaskErrors")
    If $$$ISERR(tSC) Quit tSC
    For tAt = 1:1:$Get(^||OcuPilotRecordsFixture("taskErrors", pId), 0) {
        If tAt > pMax {
            Set pCut = 1
            Quit
        }
        Set pRows(tAt) = ^||OcuPilotRecordsFixture("taskErrors", pId, tAt)
    }
    Quit $$$OK
}

ClassMethod FetchXdbc(pNamespace As %String, Output pRows) As %Status
{
    Kill pRows
    Set tSC = ..Count("FetchXdbc", pNamespace)
    If $$$ISERR(tSC) Quit tSC
    For tAt = 1:1:$Get(^||OcuPilotRecordsFixture("rows", "FetchXdbc", pNamespace), 0) {
        Set pRows(tAt) = ^||OcuPilotRecordsFixture("rows", "FetchXdbc", pNamespace, tAt)
    }
    Quit $$$OK
}

ClassMethod FetchDiagnostics(pNamespace As %String, pMax As %Integer, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set tSC = ..Count("FetchDiagnostics", pNamespace)
    If $$$ISERR(tSC) Quit tSC
    Set tCount = 0
    For tAt = 1:1:$Get(^||OcuPilotRecordsFixture("rows", "FetchDiagnostics", pNamespace), 0) {
        If tAt > pMax Quit
        Set tCount = tAt
        Merge pRows(tAt) = ^||OcuPilotRecordsFixture("rows", "FetchDiagnostics", pNamespace, tAt)
    }
    Set pRows = tCount
    Quit $$$OK
}

ClassMethod FetchEvents(pNamespace As %String, pMax As %Integer, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set tSC = ..Count("FetchEvents", pNamespace)
    If $$$ISERR(tSC) Quit tSC
    Set tCount = 0
    For tAt = 1:1:$Get(^||OcuPilotRecordsFixture("rows", "FetchEvents", pNamespace), 0) {
        If tAt > pMax Quit
        Set tCount = tAt
        Set pRows(tAt) = ^||OcuPilotRecordsFixture("rows", "FetchEvents", pNamespace, tAt)
    }
    Set pRows = tCount
    Quit $$$OK
}

ClassMethod Interoperable(pNamespace As %String) As %Boolean
{
    Do ..Count("Interoperable", pNamespace)
    Quit $Get(^||OcuPilotRecordsFixture("interop", pNamespace), 1)
}

}
