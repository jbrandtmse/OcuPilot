/// <p>Test-only <class>OcuPilot.Screen.Tool.LicenseServerDelete</class> subclass declaring
/// <class>OcuPilot.Test.LicenseSeamPort</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.LicenseActionFixture</class> records its fresh read and its write. Outside the
/// tool package, so the registry never lists it. <method>KeyServer</method> answers the key server type
/// a test sets in <code>^||OcuPilotLicenseSeam("keyServer")</code>, and the instance's otherwise.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamLicenseServerDelete Extends OcuPilot.Screen.Tool.LicenseServerDelete
{

Parameter PORTCLASS = "OcuPilot.Test.LicenseSeamPort";

/// <p>The key server type a test set, or the instance's own.</p>
ClassMethod KeyServer() As %String
{
    If $Data(^||OcuPilotLicenseSeam("keyServer")) Quit ^||OcuPilotLicenseSeam("keyServer")
    Quit ##super()
}

}
