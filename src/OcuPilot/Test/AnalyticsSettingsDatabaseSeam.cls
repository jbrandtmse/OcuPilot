/// <p><class>OcuPilot.Test.AnalyticsGateSeam</class> whose answer for the database the analytics settings global maps to is set by a test, so
/// <class>OcuPilot.Test.AnalyticsSettingsWriteEdge</class> drives the write gate's destination half in process. <method>Arm</method> <code>sdatabase</code> with
/// <code>readonly</code> reports that database mounted read-only and with <code>unmounted</code> reports it not mounted. An unarmed seam answers what the instance does.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsSettingsDatabaseSeam Extends OcuPilot.Test.AnalyticsGateSeam
{

/// <p>The instance's answer for <var>pGlobal</var>, changed as armed when <var>pGlobal</var> is the analytics settings' global.</p>
ClassMethod DestinationDatabase(pNamespace As %String, pGlobal As %String, Output pResource As %String, Output pReadOnly As %Boolean, Output pMounted As %Boolean) As %Boolean
{
    Set tResolved = ##super(pNamespace, pGlobal, .pResource, .pReadOnly, .pMounted)
    If pGlobal = ..#SETTINGSGLOBAL {
        If $Get(^||OcuPilotAnalyticsSeam("sdatabase")) = "readonly" Set pReadOnly = 1
        If $Get(^||OcuPilotAnalyticsSeam("sdatabase")) = "unmounted" Set pMounted = 0
    }
    Quit tResolved
}

}
