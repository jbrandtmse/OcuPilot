/// <p><class>OcuPilot.Port.BackupPort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held
/// set a test declares, so <class>OcuPilot.Test.PortGate</class> and <class>OcuPilot.Test.BackupRead</class> drive the port's refusal in a
/// process holding <code>%All</code>, and with <method>ClusteredSystem</method> answering what <method>Cluster</method> sets, so a test
/// drives the freeze's refusal on a system that would ignore its limit without a clustered system to test on, and with <method>SuspendCall</method>
/// answering the vendor status <method>VendorRefuses</method> sets, so a test feeds a vendor refusal to the port's mapping without freezing writes, and with the harvested body
/// replaced by <class>OcuPilot.Test.BackupHarvestRecorder</class>, so a test sees the requests the body is sent and no backup starts. Nothing else
/// differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackupGateSeam Extends OcuPilot.Port.BackupPort
{

/// <p>The harvest port the seam reaches: <class>OcuPilot.Test.BackupHarvestRecorder</class>, which records the requests the harvested
/// body is sent and runs none.</p>
Parameter HARVESTPORT = "OcuPilot.Test.BackupHarvestRecorder";

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>Answer <var>pClustered</var> from <method>ClusteredSystem</method> until <method>Reset</method>.</p>
ClassMethod Cluster(pClustered As %Boolean)
{
    Set ^||OcuPilotBackupClustered = ''pClustered
}

/// <p>Answer the vendor error code <var>pCode</var> from <method>SuspendCall</method> until <method>Reset</method>, in place of calling
/// the vendor.</p>
ClassMethod VendorRefuses(pCode As %Integer)
{
    Set ^||OcuPilotBackupVendorCode = pCode
}

/// <p>The shipped answers again.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotBackupClustered, ^||OcuPilotBackupVendorCode
}

ClassMethod SuspendCall(pType As %String, pLimit As %Integer) As %Status [ Private ]
{
    If $Data(^||OcuPilotBackupVendorCode) Quit $System.Status.Error(^||OcuPilotBackupVendorCode, "a vendor refusal fed by the test")
    Quit ##super(pType, pLimit)
}

ClassMethod ClusteredSystem() As %Boolean
{
    If $Data(^||OcuPilotBackupClustered) Quit ^||OcuPilotBackupClustered
    Quit ##super()
}

}
