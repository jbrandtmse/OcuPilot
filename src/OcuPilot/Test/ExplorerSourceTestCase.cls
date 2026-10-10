/// <p>What <class>OcuPilot.Test.ExplorerSource</class> and <class>OcuPilot.Test.ExplorerSourceEdges</class>
/// share: the namespace their probe documents live in, the fixture that answers the fake routes, one call
/// of a source read, and an index answer and a document answer armed on those routes. It declares no test
/// of its own.</p>
/// <p>Needs the Atelier fixture free for the fake-route legs; it creates and removes nothing itself.</p>
Class OcuPilot.Test.ExplorerSourceTestCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The namespace the probe documents are created in.</p>
Parameter NAMESPACE = "USER";

/// <p>The fixture that answers the Atelier routes in place of the instance's.</p>
Parameter FAKE = "OcuPilot.Test.AtelierPortFixture";

/// <p>One call of the source read <var>pTool</var> on <var>pName</var> in <var>pNamespace</var>: the
/// status, the answer and, for a refusal, the HTTP status and the wire fault.</p>
ClassMethod Fetch(pTool As %String, pName As %String, pNamespace As %String = {..#NAMESPACE}, Output pResult As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tArgs = {}
    Do tArgs.%Set("name", pName, "string")
    Set tSC = $ClassMethod(pTool, "View", "", tArgs, 0, .pResult, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit tSC
}

/// <p>An index answer and a document answer for one document <var>pName</var> whose text is
/// <var>pLines</var>, armed on the fake routes. <var>pObjectOnly</var> 1 arms the document answer as
/// the instance gives an object-only routine: 404 with no status and no timestamp.</p>
ClassMethod ArmDocument(pName As %String, pLines As %DynamicArray, pObjectOnly As %Boolean = 0)
{
    Set tEntry = {"name": "", "db": "USER", "ts": "2026-10-08 10:00:00", "upd": false, "cat": "CLS", "gen": false, "others": [], "status": "", "content": {}}
    Do tEntry.%Set("name", pName, "string")
    Set tIndex = {"status": {"errors": [], "summary": ""}, "console": [], "result": {"content": []}}
    Do tIndex.%Get("result").%Get("content").%Push(tEntry)
    Do $ClassMethod(..#FAKE, "UseFakeRoutes")
    Do $ClassMethod(..#FAKE, "SetVersion", 8)
    Do $ClassMethod(..#FAKE, "SetResources", "%DB_USER", "%DB_USER", "")
    Do $ClassMethod(..#FAKE, "Arm", "Index", "200 OK", tIndex.%ToJSON())
    If pObjectOnly {
        Do $ClassMethod(..#FAKE, "Arm", "GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""" _ pName _ """,""db"":""USER"",""ts"":"""",""upd"":false,""cat"":""RTN"",""status"":"""",""enc"":false,""flags"":0,""content"":[]}}")
        Quit
    }
    Set tDocument = {"status": {"errors": [], "summary": ""}, "console": [], "result": {"name": "", "db": "USER", "ts": "2026-10-08 10:00:00", "upd": false, "cat": "CLS", "status": "", "enc": false, "flags": 0, "content": []}}
    Do tDocument.%Get("result").%Set("name", pName, "string")
    Do tDocument.%Get("result").%Set("content", pLines)
    Do $ClassMethod(..#FAKE, "Arm", "GetDoc", "200 OK", tDocument.%ToJSON())
}

}
