/// <p>Stand-in probe endpoint for <method>OcuPilot.Port.AdminPort.ProbeAnswers</method>,
/// driven by <method>SetMode</method>. It answers the three questions the port asks and
/// records what it was constructed with, so the probe contract can be broken one way at a
/// time without a vendor endpoint and without touching the instance.</p>
/// <p>It deliberately extends no <code>%Api.Admin.*</code> class (AD-27): the port asks its
/// questions through dynamic dispatch, so any class answering them will do, and the vendor
/// dependency stays in <class>OcuPilot.Port.AdminPort</class> alone.</p>
/// <p>State lives in the process-private global <code>^||OcuPilotProbeFixture</code> rather
/// than in properties: the port constructs this class itself, so a test has no instance to
/// configure.</p>
Class OcuPilot.Test.ProbeFixture Extends %RegisteredObject
{

/// <p>Arm one failure shape: <code>ok</code> (the default) answers everything;
/// <code>noconstruct</code> refuses to construct; <code>noresources</code> returns an empty
/// <code>ResourcesOR()</code>; <code>asyncthrows</code> throws from
/// <code>ShouldRunAsync()</code>; <code>asyncnonboolean</code> answers it with neither
/// <code>0</code> nor <code>1</code> without throwing (DW-122) -- the branch a throw cannot
/// reach, since it lands in <method>OcuPilot.Port.AdminPort.ProbeAnswers</method>'s
/// <code>Catch</code> with a different message.</p>
ClassMethod SetMode(pMode As %String)
{
    Set ^||OcuPilotProbeFixture("mode") = pMode
}

/// <p>Forget the armed mode and any construction record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotProbeFixture
}

/// <p>What the port constructed this fixture with. <var>pField</var> is
/// <code>type</code> or <code>apiVersion</code>; <code>""</code> when it was never
/// constructed, which is itself a failure signal for a test that expected it to be.</p>
ClassMethod Constructed(pField As %String) As %String
{
    Quit $Get(^||OcuPilotProbeFixture(pField), "")
}

Method %OnNew(pType As %Integer = -1, pApiVersion As %Integer = 1) As %Status
{
    Set tSC = $$$OK
    Set ^||OcuPilotProbeFixture("type") = pType
    Set ^||OcuPilotProbeFixture("apiVersion") = pApiVersion
    If $Get(^||OcuPilotProbeFixture("mode")) = "noconstruct" {
        Set tSC = $$$ERROR($$$GeneralError, "probe fixture armed to refuse construction")
    }
    Quit tSC
}

/// <p>One resource, as a real endpoint would return -- or an empty list under
/// <code>noresources</code>.</p>
Method ResourcesOR() As %List
{
    If $Get(^||OcuPilotProbeFixture("mode")) = "noresources" Quit ""
    Quit $ListBuild("%Admin_Operate")
}

/// <p>Synchronous, as the real probe endpoint is -- or a throw under
/// <code>asyncthrows</code>, which is what "the endpoint no longer answers" looks like from
/// the port's side -- or, under <code>asyncnonboolean</code>, an answer that is neither 0
/// nor 1 (DW-122): the method's <code>%Boolean</code> return type is a declared contract,
/// not a runtime coercion, so a caller of an untyped OREF genuinely can receive this.</p>
Method ShouldRunAsync() As %Boolean
{
    If $Get(^||OcuPilotProbeFixture("mode")) = "asyncthrows" {
        Throw ##class(%Exception.General).%New("ProbeFixture", 1, , "probe fixture armed to throw from ShouldRunAsync")
    }
    If $Get(^||OcuPilotProbeFixture("mode")) = "asyncnonboolean" {
        Quit 5
    }
    Quit 0
}

}
