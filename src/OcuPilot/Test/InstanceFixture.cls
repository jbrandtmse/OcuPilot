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

/// <p>DW-120 -- arm <method>VerifyInstance</method> to <code>Throw</code> rather than
/// return, which is what an unexpected exception in the real port looks like.
/// <method>SetVerification</method> alone cannot reach
/// <method>OcuPilot.Api.Instance.Handle</method>'s own internal-error branch: even a
/// forced error <class>%Status</class> is only ever read to source a log detail, and
/// <method>Payload</method> still returns <code>$$$OK</code>. Only a genuine <code>Throw</code>
/// reaches <method>Payload</method>'s <code>Catch</code>, which is what turns its return
/// into an error <method>Handle</method> renders through
/// <class>OcuPilot.Api.Error</class>'s internal writer instead of a response body.</p>
ClassMethod SetVerificationThrows(pMessage As %String)
{
    Set ^||OcuPilotInstanceFixture("throws") = pMessage
}

/// <p>Forget every override and any captured log call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotInstanceFixture
}

/// <p>The detail <method>LogDetail</method> was last handed, or <code>""</code> when it was
/// never called -- which is itself a failure signal for a test that expected a log.</p>
/// <p>It cannot answer "was it called at all": a call carrying an empty detail stores the
/// same <code>""</code> a call that never happened reads back. Use <method>LogCalls</method>
/// for that question.</p>
ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotInstanceFixture("logged"), "")
}

/// <p>How many times <method>LogDetail</method> was called. The only way to tell a log
/// carrying an empty detail from no log at all, which is the whole of what the handler's
/// <code>If tDetail '= ""</code> guard decides.</p>
ClassMethod LogCalls() As %Integer
{
    Quit $Get(^||OcuPilotInstanceFixture("logcalls"), 0)
}

ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    If $Data(^||OcuPilotInstanceFixture("throws")) {
        Throw ##class(%Exception.General).%New("InstanceFixture", 1, , $Get(^||OcuPilotInstanceFixture("throws")))
    }
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
    Set ^||OcuPilotInstanceFixture("logcalls") = $Get(^||OcuPilotInstanceFixture("logcalls"), 0) + 1
}

}
