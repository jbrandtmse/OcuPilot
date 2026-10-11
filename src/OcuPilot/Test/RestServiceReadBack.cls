/// <p>Pins that the read-back, and not the management API's answer, says whether the REST service delete worked (AD-58,
/// Story 18.32): the vendor's delete answers 200 whether or not it removed anything, so a delete that changed nothing
/// must read back <code>present</code> and one that removed the service <code>notFound</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and nothing else. The vendor
/// is <class>OcuPilot.Test.MgmntImplFixture</class> behind <class>OcuPilot.Test.MgmntPortFixture</class> and the
/// caller's pairs are <class>OcuPilot.Test.ScreenGate</class>'s, so it reads and creates nothing on the instance.</p>
Class OcuPilot.Test.RestServiceReadBack Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.RestServiceDelete";

Parameter PORT = "OcuPilot.Test.MgmntPortFixture";

/// <p>The canned services' second row, which the vendor's list keeps when the first is removed.</p>
Parameter KEPT = "[{""name"":""Probe.v1"",""webApplications"":""/api/probe"",""dispatchClass"":""Probe.v1.disp"",""namespace"":""PROBENS"",""swaggerSpec"":""/api/mgmnt/v2/PROBENS/Probe.v1""}]";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

ClassMethod Clear()
{
    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ##class(OcuPilot.Test.MgmntPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>The delete's read-back of <var>pName</var> in <code>USER</code>, asked of the fixture port.</p>
ClassMethod Verdict(pName As %String) As %String
{
    Set tFresh = {"Name": (pName), "Namespace": "USER"}
    Set tAnswer = ##class(OcuPilot.Kernel.Proposal.ReadBack).Of(..#TOOL, pName, {}, tFresh, {"Namespace": "USER"}.%ToJSON(), ..#PORT)
    Quit $Select($IsObject(tAnswer): tAnswer.%Get("verdict"), 1: "")
}

/// <p>A vendor delete that answers 200 and removes nothing is accepted by the port, which cannot tell, and read back
/// <code>present</code>; once the vendor's list no longer holds the service the same read-back reads
/// <code>notFound</code>.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Screen.Tool.RestServiceDelete</class> answer <code>1</code> from
/// <method>ReadBackGone</method> -- the first verdict reads <code>notFound</code> and this goes red.</p>
Method TestAVendorDeleteThatRemovedNothingReadsBackPresent()
{
    Do ##class(OcuPilot.Test.MgmntPort).ArmCanned()
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("DeleteApplication", "200 OK", "{""msg"":""deleted""}")
    Do ##class(OcuPilot.Test.MgmntPort).HoldAllWritePairs()
    Set tSC = ##class(OcuPilot.Test.MgmntPort).Service("DELETE", "USER", "Orphan.v2", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port takes the vendor's 200 for a delete")
    Do $$$AssertTrue(##class(OcuPilot.Test.MgmntImplFixture).CallText() [ "DeleteApplication(USER,Orphan.v2)", "and the delete was sent")
    Do $$$AssertEquals(..Verdict("Orphan.v2"), "present", "yet the service is still listed, so the read-back says present")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetRESTApps", "200 OK", ..#KEPT)
    Do $$$AssertEquals(..Verdict("Orphan.v2"), "notFound", "and once the vendor's list no longer holds it, notFound")
}

}
