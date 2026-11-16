/// <p><class>OcuPilot.Port.BackupPort</class> with its vendor call replaced, so a test drives <method>SuspendCall</method>'s device handling
/// without freezing writes. <method>VendorSuspend</method> records the current device it was reached with and answers what
/// <method>Mode</method> set: a good status, an error status, or a raise. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackupDeviceSeam Extends OcuPilot.Port.BackupPort
{

/// <p>Answer <var>pMode</var> from <method>VendorSuspend</method>: <code>ok</code>, <code>status</code> or <code>raise</code>.</p>
ClassMethod Mode(pMode As %String)
{
    Set ^||OcuPilotBackupDeviceMode = pMode
    Kill ^||OcuPilotBackupDeviceSeen
}

/// <p>The current device <method>VendorSuspend</method> was reached with since <method>Mode</method>, or <code>""</code>.</p>
ClassMethod Seen() As %String
{
    Quit $Get(^||OcuPilotBackupDeviceSeen)
}

/// <p>The shipped port's <method>SuspendCall</method> for <var>pType</var>, which is private.</p>
ClassMethod Suspend(pType As %String) As %Status
{
    Quit ..SuspendCall(pType, 0)
}

ClassMethod VendorSuspend(pType As %String, pLimit As %Integer) As %Status [ Private ]
{
    Set ^||OcuPilotBackupDeviceSeen = $IO
    Set tMode = $Get(^||OcuPilotBackupDeviceMode, "ok")
    If tMode = "raise" Throw ##class(%Exception.General).%New("seam", 5001, , "raised by the test")
    If tMode = "status" Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

}
