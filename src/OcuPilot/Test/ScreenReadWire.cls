/// <p>The screen-read route over the wire: <code>GET /api/ocupilot/screens/:screen/read</code>
/// through the real <code>/api/ocupilot</code> application, as the configured test principal
/// (<class>OcuPilot.Test.Http</class>). No production descriptor declares a read yet, so the rows
/// observable here are the two not-found rows and the wrong verb; the success, denied and bad-cap
/// rows run through <class>OcuPilot.Test.Dispatch</class> in <class>OcuPilot.Test.ScreenRead</class>.</p>
/// <p>Needs the API application installed and the test principal's password. Reads only.</p>
Class OcuPilot.Test.ScreenReadWire Extends %UnitTest.TestCase
{

/// <p>An unknown screen and a screen with no read are each one 404 envelope with
/// <code>ROUTE.NOTFOUND</code>, as JSON.</p>
Method TestAnUnknownAndAReadlessScreenAreNotFoundOverTheWire()
{
    For tScreen = "nosuch.screen", "shell.home" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ tScreen _ "/read?maxRows=5", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tScreen _ ": the request completes")
        Do $$$AssertEquals(tStatus, 404, tScreen _ ": 404")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tScreen _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tScreen _ ": exactly one envelope")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.error, "not_found", tScreen _ ": on the not_found slug")
        Do $$$AssertEquals(tObj.code, "ROUTE.NOTFOUND", tScreen _ ": with ROUTE.NOTFOUND")
    }
}

/// <p>A <code>POST</code> to the screen-read path is the framework's 405 naming <code>GET</code>, an
/// answer only a mapped <code>GET /screens/:screen/read</code> route produces; without the route
/// the path matches nothing and is a 404.</p>
/// <p>Mutation: delete the screen-read route from <class>OcuPilot.Api.Router</class>'s
/// <code>UrlMap</code> -> the request answers 404 and every assertion here goes red.</p>
Method TestAPostToTheScreenReadPathIsRefusedNamingGet()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/nosuch.screen/read", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 405, "a POST to the screen-read route is refused")
    Do $$$AssertTrue($ListFind($ListFromString($Get(tHeaders("ALLOW"))), "GET"), "and Allow names GET: " _ $Get(tHeaders("ALLOW")))
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "ROUTE.METHODNOTALLOWED", "through the one error writer")
}

}
