/// <p>Pins that a read of Database details' Volume files without its one criterion, <code>dir</code>,
/// is refused 400 <code>READ.CRITERION</code> before any vendor endpoint runs, so the vendor's own 400
/// is never reached and never logged (AD-2, AD-36): through
/// <class>OcuPilot.Test.Read.ReadFixture</class> over <class>OcuPilot.Test.PortFixture</class>, whose
/// recorded endpoint name stays empty and whose log capture stays empty, and over the wire. A read that
/// carries its directory is still served.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and one database. Live-safe:
/// it creates nothing and writes only process-private globals.</p>
Class OcuPilot.Test.VolumeListCriterion Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.DatabaseVolumeList";

Parameter SENTENCE = "400 READ.CRITERION dir is required";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>The fault of a refused read as <code>status code reason</code>.</p>
ClassMethod Sentence(pHttp As %Integer, pFault As %DynamicObject) As %String
{
    Quit +pHttp _ " " _ $Select($IsObject(pFault): pFault.%Get("code") _ " " _ pFault.%Get("reason"), 1: "")
}

/// <p>A read with no <code>dir</code>, and one whose <code>dir</code> is empty, is 400
/// <code>READ.CRITERION</code> "dir is required"; no endpoint ran and nothing was logged.</p>
/// <p>Mutation (Rule 19): drop <code>VOLUMELISTTYPE</code> from the route criterion's guard in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the vendor's endpoint runs and both reads go red.</p>
Method TestAReadWithoutItsDirectoryIsRefusedBeforeTheVendorIsAsked()
{
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a read with no criterion fails")
    Do $$$AssertEquals(..Sentence(tHttp, tFault), ..#SENTENCE, "as 400 READ.CRITERION naming dir")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("name"), "", "and no endpoint ran")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing was logged")

    Kill tCriteria
    Set tCriteria("dir") = ""
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult2, .tHttp2, .tFault2, .tCriteria)
    Do $$$AssertEquals(..Sentence(tHttp2, tFault2), ..#SENTENCE, "an empty dir is refused the same way")
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).Recorded("name"), "", "with no endpoint run")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing logged")
}

/// <p>The route answers the same, and a read that names a real directory is served.</p>
/// <p>Mutation (Rule 19): as above -&gt; the route answers the vendor's 400 and the first leg goes red.</p>
Method TestTheRouteAnswersTheSame()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/osmgmt.databasevolumes/read?maxRows=10", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(..Sentence(tStatus, tBody), ..#SENTENCE, "the route refuses a read with no dir")

    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "LIST", .tQuery, "", .tDatabases, .tListHttp, .tListFault)
    Do $$$AssertStatusOK(tListSC, "the database list answers")
    If $$$ISERR(tListSC) || (tDatabases.%Size() = 0) Quit
    Kill tCriteria
    Set tCriteria("dir") = tDatabases.%Get(0).Directory
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tHttp), 200, "and a read naming a directory is served")
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.rows.%Size() > 0), "with its volume files")
}

}
