/// <p>Pins the percent-class access create route over the wire (Story 18.10): <code>POST /web-app/pct-access</code>
/// answers a body with an unknown key 400 and an entry whose class has no percent sign 422 <code>PCTACCESS.CLASS</code>,
/// and writes nothing in either case. A second post of an entry already held answers 409 <code>PCTACCESS.EXISTS</code>
/// and writes nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, in <code>HSCUSTOM</code>. The one leg that creates an entry
/// creates <code>%OcuProbe1810.Wire</code> on <code>all-applications</code>, and <method>OnAfterOneTest</method> removes it.</p>
Class OcuPilot.Test.PctAccessSaveWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Refuses to run anywhere <parameter>ARMINGVARIABLE</parameter> does not read 1: this class creates and removes a percent-class access entry on this instance.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PctAccessSaveWire creates and removes a percent-class access entry on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The route the test posts to.</p>
Parameter SAVEPATH = "/web-app/pct-access";

/// <p>One request over the wire as the test account: the status and the parsed answer.</p>
ClassMethod Post(pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer, Output pContentType As %String) As %Status
{
    Set pAnswer = ""
    Set pContentType = ""
    Set tJson = pBody.%ToJSON()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#SAVEPATH _ "?ns=HSCUSTOM", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tJson)
    Set pContentType = $Get(tHeaders("CONTENT-TYPE"))
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
    Quit tSC
}

/// <p>Removes the probe entry this class creates, through the port's own delete, whether or not the leg reached it.</p>
Method OnAfterOneTest() As %Status
{
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("all-applications", "AllowClass", "%OcuProbe1810.Wire"))
    Do ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit $$$OK
}

/// <p>A body key the route does not read is refused 400 before anything is looked up.</p>
Method TestAnUnexpectedKeyIsRefused()
{
    Set tBody = {"Name": "/csp/user", "AllowType": "AllowClass", "Class": "%OcuProbe1810.Wire", "AllowAccess": true, "Extra": 1}
    Set tSC = ..Post(tBody, .tStatus, .tAnswer, .tContentType)
    Do $$$AssertStatusOK(tSC, "the request is sent")
    Do $$$AssertEquals(tStatus, 400, "a body key the route does not read answers 400")
    Do $$$AssertTrue($Find(tContentType, "application/json") > 0, "the refusal is JSON")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%Get("code") = ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "the refusal names the unexpected field, not another 400")
    Quit
}

/// <p>A class name without a percent sign is refused 422 on its own field, and no entry is written.</p>
Method TestAClassWithoutAPercentSignIsRefused()
{
    Set tBody = {"Name": "/csp/user", "AllowType": "AllowClass", "Class": "Ens.Director", "AllowAccess": true}
    Set tSC = ..Post(tBody, .tStatus, .tAnswer, .tContentType)
    Do $$$AssertStatusOK(tSC, "the request is sent")
    Do $$$AssertEquals(tStatus, 422, "a class without a percent sign answers 422")
    Do $$$AssertTrue($Find(tContentType, "application/json") > 0, "the refusal is JSON")
    Do $$$AssertEquals(tAnswer.code, "PCTACCESS.CLASS", "the refusal names the class")
    Quit
}

/// <p>An entry the application already holds is refused 409 <code>PCTACCESS.EXISTS</code> on a second post, and the
/// held entry keeps the access the first post gave it: the second post's body says the opposite, so a second vendor
/// write would show.</p>
/// <p>Mutation (Rule 19): remove the <code>EXISTS</code> branch in <class>OcuPilot.Area.WebApp.PctAccessSave</class>'s
/// <method>Create</method> -- the second post answers 201 and the held entry reads <code>AllowAccess</code> 0, so both
/// legs go red.</p>
Method TestAnExistingEntryIsRefusedAndNotWrittenAgain()
{
    Set tBody = {"Name": "all-applications", "AllowType": "AllowClass", "Class": "%OcuProbe1810.Wire", "AllowAccess": true}
    Set tSC = ..Post(tBody, .tStatus, .tAnswer, .tContentType)
    Do $$$AssertStatusOK(tSC, "the first post is sent")
    Do $$$AssertEquals(tStatus, 201, "the first post adds the entry")
    Set tAgain = {"Name": "all-applications", "AllowType": "AllowClass", "Class": "%OcuProbe1810.Wire", "AllowAccess": false}
    Set tSC = ..Post(tAgain, .tStatus2, .tAnswer2, .tContentType2)
    Do $$$AssertStatusOK(tSC, "the second post is sent")
    Do $$$AssertEquals(tStatus2, 409, "a second post of an entry already held answers 409")
    Do $$$AssertEquals($Select($IsObject(tAnswer2): tAnswer2.code, 1: ""), "PCTACCESS.EXISTS", "the refusal names the entry as already held")
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("all-applications", "AllowClass", "%OcuProbe1810.Wire"))
    Set tSC = ##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess", "STATE", .tQuery, "", .tState, .tStateHttp, .tStateFault)
    Do $$$AssertStatusOK(tSC, "the held entry is read through the port")
    Do $$$AssertEquals($Get(tStateHttp), 200, "the held entry reads back")
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.AllowAccess, 1: ""), 1, "and keeps the access the first post gave it, so no second write reached the vendor")
    Quit
}

}
