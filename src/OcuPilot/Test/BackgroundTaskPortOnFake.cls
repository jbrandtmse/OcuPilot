/// <p>Subclass of <class>OcuPilot.Port.BackgroundTaskPort</class> that controls a portal row through
/// <class>OcuPilot.Test.BackgroundTaskFake</class> in place of the vendor's background task: its
/// <parameter>PORTALTASKCLASS</parameter> is the fake, and its one replaced seam is
/// <method>PortalRows</method>, which answers the one row <method>ArmRow</method> armed instead of
/// asking the portal's query, since the query blanks the background task id of a task the vendor
/// cannot open. The gate, the fresh read, <method>Control</method> and <method>PortalControl</method>
/// are the shipped port's own.</p>
/// <p>State lives in <code>^||OcuPilotBackgroundPortOnFake</code>; <method>Clear</method> forgets
/// it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundTaskPortOnFake Extends OcuPilot.Port.BackgroundTaskPort
{

Parameter PORTALTASKCLASS = "OcuPilot.Test.BackgroundTaskFake";

/// <p>Answer the portal half with one row: the job <var>pJob</var>, whose background task is
/// <var>pTaskId</var>.</p>
ClassMethod ArmRow(pJob As %String, pTaskId As %String)
{
    Set ^||OcuPilotBackgroundPortOnFake("job") = pJob
    Set ^||OcuPilotBackgroundPortOnFake("task") = pTaskId
}

/// <p>Forget the armed row.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotBackgroundPortOnFake
}

ClassMethod PortalRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set pRows = []
    If $Data(^||OcuPilotBackgroundPortOnFake("job")) {
        Set tRow = {"Source": "Management Portal", "Task": "Compact DB Space", "Namespace": "%SYS", "Status": "Paused", "Details": "", "ErrorCount": "", "StartTime": "2026-10-10 12:00:00"}
        Do tRow.%Set("Id", ^||OcuPilotBackgroundPortOnFake("job"), "string")
        Do tRow.%Set("SysBGTaskId", ^||OcuPilotBackgroundPortOnFake("task"), "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
