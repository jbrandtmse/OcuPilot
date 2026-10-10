/// <p><class>OcuPilot.Test.InteropItemSeam</class> and, once <method>UsePathPortFixture</method> arms it, a port that
/// asks <class>OcuPilot.Test.PathPortFixture</class> the path questions instead of
/// <class>OcuPilot.Port.PathPort</class> (Story 20.22), so a test can move the served directory between a mint and
/// the write that judges the same value again. <method>Disarm</method> clears it, the fixture's own state and the
/// parent seam's. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropSettingSeam Extends OcuPilot.Test.InteropItemSeam
{

/// <p>Answer the path questions through <class>OcuPilot.Test.PathPortFixture</class> until
/// <method>Disarm</method>.</p>
ClassMethod UsePathPortFixture()
{
    Set ^||OcuPilotInteropSettingPath = 1
}

/// <p>The shipped answers again, the fixture reset and an empty log.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotInteropSettingPath
    Do ##class(OcuPilot.Test.PathPortFixture).Reset()
    Do ##super()
}

ClassMethod PathPortClass() As %String
{
    If $Get(^||OcuPilotInteropSettingPath) Quit "OcuPilot.Test.PathPortFixture"
    Quit ##super()
}

}
