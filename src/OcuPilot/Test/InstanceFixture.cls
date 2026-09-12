/// <p>Subclass of <class>OcuPilot.Api.Instance</class> overriding the handler's three
/// seams -- the verification, the build-identity read and the audit-log call -- so the
/// handler's own branches can be driven and captured without a fixture admin API and
/// without reading or writing the instance's version row.</p>
/// <p>Each seam falls back to the production one when nothing is armed, the same shape
/// <class>OcuPilot.Test.GateFixture</class> uses.</p>
Class OcuPilot.Test.InstanceFixture Extends OcuPilot.Api.Instance
{

/// <p>Arm what <method>VerifyInstance</method> reports. <var>pVersion</var> is returned
/// verbatim and <var>pDetail</var> is what the handler is expected to log.</p>
ClassMethod SetVerification(pVersion As %Integer, pDetail As %String = "")
{
    Set ^||OcuPilotInstanceFixture("version") = pVersion
    Set ^||OcuPilotInstanceFixture("detail") = pDetail
}

/// <p>Arm the build identity the payload should carry byte for byte.</p>
ClassMethod SetBuildIdentity(pIdentity As %String)
{
    Set ^||OcuPilotInstanceFixture("build") = pIdentity
}

/// <p>Forget every override and any captured log call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotInstanceFixture
}

/// <p>The detail <method>LogDetail</method> was last handed, or <code>""</code> when it was
/// never called -- which is itself a failure signal for a test that expected a log.</p>
ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotInstanceFixture("logged"), "")
}

ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    If '$Data(^||OcuPilotInstanceFixture("version")) Quit ##super(.pVersion, .pDetail)
    Set pVersion = ^||OcuPilotInstanceFixture("version")
    Set pDetail = $Get(^||OcuPilotInstanceFixture("detail"), "")
    Quit $$$OK
}

ClassMethod BuildIdentity() As %String
{
    If '$Data(^||OcuPilotInstanceFixture("build")) Quit ##super()
    Quit ^||OcuPilotInstanceFixture("build")
}

ClassMethod LogDetail(pDetail As %String)
{
    Set ^||OcuPilotInstanceFixture("logged") = pDetail
}

}
