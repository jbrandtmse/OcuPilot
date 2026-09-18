/// <p>Process details (Story 6.8): the declaration against the read, criteria and classic-link
/// grammar, the OS management area's pair set and the registry; the I/O matrix over the wire as
/// <code>_SYSTEM</code> -- this test process's own live pid, an unknown pid, no id and an
/// over-long id; that <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers
/// <code>process</code> for it; and the integration AC, the read tool answering the same row the
/// route does with no <code>Variables</code> key.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>. Uses this test process's own
/// <code>$Job</code> as the stable pid for the "Live process" matrix case and the integration AC,
/// since it is a real, live process on this instance for the length of each request (Design
/// Notes: "Stable pids"); "No id" sends no pid at all and "Bad id" sends a fixed eleven-character
/// literal. Issues reads only.</p>
Class OcuPilot.Test.ProcessDetails Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ProcessDetails";

/// <p>The tool identifier the screen read and the derived read tool share.</p>
Parameter TOOL = "osmgmt.processdetails";

/// <p>A pid no process on this instance holds, for the "Gone" matrix row (AD-37).</p>
Parameter UNKNOWNPID = "999999999";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p><var>pObject</var>'s keys, in order, comma-separated.</p>
ClassMethod KeysOf(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var>, with <var>pQuery</var> appended, as
/// <code>_SYSTEM</code>. <var>pAnswer</var> is the parsed body, or <code>""</code> when it does not
/// parse, which is a failed assertion on its own.</p>
Method Read(pTool As %String, pMaxRows As %Integer, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=" _ pMaxRows _ pQuery, "_SYSTEM", "SYS", .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The declaration passes the read, criteria and classic-link grammar; its route and tool
/// identifier resolve to it; its classic page is a class compiled on this instance; it is the
/// OS management area's entry on the <code>process</code> entity type, at instance scope, parented
/// to Processes, keyed by the composite <code>Pid</code>, refreshing at the AD-43 roster; it
/// declares no <code>Settings</code>-style secret field anywhere and no secret; and the OS
/// management area covers its pair set.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from the descriptor -&gt;
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses it and this goes red naming the
/// missing pair.</p>
Method TestTheDeclarationValidatesAndIsDeclaredAsProcessDetails()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so are its criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/processes/details"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#TOOL), tClass, "and so does its tool identifier")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.ProcessDetails", "the classic page is ProcessDetails")
    Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), "which is a class compiled on this instance")

    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "os-management", "in the OS management area")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 0, "routable but unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", "on the detail archetype")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "os-management/processes", "parented to Processes")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), "process", "on the process entity type")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", "at instance scope")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "keyed by a composite id")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "IdParts")), "Pid", "over the one part Pid")
    Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 1, "and it refreshes")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the AD-43 roster")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "with no secret field")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, "because it declares no action")

    ; AD-24/AD-35/AD-48: the never-named fields, checked over the read fields and the context. Each
    ; needle is the exact quoted JSON key, never the bare word -- "Roles" is a bare substring of the
    ; legitimate "LoginRoles" and "EscalatedRoles", which a plain '[ check would misname as present.
    Set tAllNames = tDeclaration.read.fields.%ToJSON() _ tDeclaration.context.fields.%ToJSON()
    For tField = "Variables", "CSPSessionID", "CurrentSrcLine", "LastGlobalReference", "UserInfo", "Roles", "LicenseUserId" {
        Set tNeedle = """" _ tField _ """"
        Do $$$AssertTrue(tAllNames '[ tNeedle, tField _ " is named nowhere: " _ tAllNames)
    }
    ; Nor is any CanBe* control field -- this screen ships no process control (Stories 5.12, 7.8, 16.6).
    Do $$$AssertEquals((tAllNames [ "CanBe"), 0, "no CanBe* field is named either")

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", "and the OS management area covers its pair set")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RouteEntityType(tClass), "process", "its route id names a process, resolved through its parent")
}

/// <p>Matrix "Live process" -- this test process's own live <code>$Job</code> answers every
/// declared field with a vendor value, with <code>Pid</code> equal to it, <code>OpenDevices</code>
/// an array, and no <code>Variables</code> or <code>CSPSessionID</code> key.</p>
/// <p>The projection writes every declared field as a key, <code>null</code> when the vendor does not
/// answer it, and the read seeds <code>Pid</code> from the criterion, so neither proves the vendor
/// answered: a non-null value per field and <code>NameSpace</code> (vendor-only) do.</p>
/// <p>Mutation: rename <code>ClientIPAddress</code> to <code>ClientIPAdress</code> throughout the
/// descriptor -&gt; the non-null assertion for that field goes red.</p>
Method TestALiveProcessReadsOverTheWire()
{
    Set tPid = $Job
    Set tSC = ..Read(..#TOOL, 5, "&pid=" _ tPid, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "exactly one row")
    If tAnswer.rows.%Size() '= 1 Quit
    Set tRow = tAnswer.rows.%Get(0)

    Do $$$AssertEquals(tRow.Pid, tPid, "Pid equals the pid asked for")
    Do $$$AssertEquals(tRow.%GetTypeOf("OpenDevices"), "array", "OpenDevices is an array")

    Do $$$AssertEquals(tRow.NameSpace, $Namespace, "the vendor answers this test process's own namespace")

    Set tFieldIterator = $ClassMethod(..#DESCRIPTOR, "Read").fields.%GetIterator()
    While tFieldIterator.%GetNext(.tIndex, .tField) {
        Do $$$AssertNotEquals(tRow.%GetTypeOf(tField), "null", "declared field '" _ tField _ "' carries a vendor value on the live row")
    }
    Do $$$AssertEquals(tRow.%GetTypeOf("Variables"), "unassigned", "no Variables key reaches the row")
    Do $$$AssertEquals(tRow.%GetTypeOf("CSPSessionID"), "unassigned", "no CSPSessionID key reaches the row")
}

/// <p>Matrix "Gone" -- an unknown pid answers 200 with no rows (AD-37, vendor 404), not a refusal.</p>
Method TestAnUnknownPidReadsAsNoRows()
{
    Set tSC = ..Read(..#TOOL, 5, "&pid=" _ ..#UNKNOWNPID, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "not a refusal")
    If tStatus '= 200 Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 0, "and no rows")
}

/// <p>Matrix "No id" -- a parent-scoped GET called without its one criterion is refused 400
/// <code>READ.CRITERION</code> naming <code>pid</code>, before the port.</p>
Method TestNoIdIsRefused()
{
    Set tSC = ..Read(..#TOOL, 5, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "refused")
    If tStatus '= 400 Quit
    Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", "naming the criterion code")
    Do $$$AssertTrue(tAnswer.reason [ "pid", "and naming pid: " _ tAnswer.reason)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("rows"), "unassigned", "with no rows")
}

/// <p>Matrix "Bad id" -- eleven characters is over <code>pid</code>'s declared ten-character
/// bound, refused 400 <code>READ.CRITERION</code> before the port, never a 500 from an over-long
/// vendor property.</p>
Method TestAnOverLongIdIsRefused()
{
    Set tSC = ..Read(..#TOOL, 5, "&pid=12345678901", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "refused")
    If tStatus '= 400 Quit
    Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", "naming the criterion code")
    Do $$$AssertTrue(tAnswer.reason [ "pid", "and naming pid: " _ tAnswer.reason)
}

/// <p>The integration AC -- the read tool, called in process with this test process's own live
/// pid, answers the same one row's identity the route's own read does, over the same declared
/// fields, with no <code>Variables</code> key.</p>
/// <p><b>Field values are not compared whole</b>, unlike <class>OcuPilot.Test.TaskDetails</class>'s
/// own integration AC: a task's properties are static between two reads, but this row is a live
/// process's own metrics, and issuing the tool call and then the route's read in sequence advances
/// counters like <code>CommandsExecuted</code> and <code>CPUTime</code> between them, and the in-process
/// tool reads this process while its port call runs in <code>%SYS</code>, so even
/// <code>NameSpace</code> differs. The row's keys, in order, and its vendor-answered
/// <code>UserName</code> are what "the same row" means here; <code>Pid</code> is seeded from the
/// criterion on both paths.</p>
Method TestTheReadToolAnswersTheSameRowAsTheRoute()
{
    Set tPid = $Job
    Set tArgs = {}
    Do tArgs.%Set("pid", tPid, "string")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 1000, .tView)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the tool reads")
    If $$$ISERR(tSC) || '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.rows.%Size(), 1, "the tool answers one row")

    Set tRouteSC = ..Read(..#TOOL, 1000, "&pid=" _ tPid, .tStatus, .tRoute)
    Do $$$AssertEquals(tStatus, 200, "the route answers the same read")
    If (tStatus '= 200) || '$IsObject(tRoute) Quit

    Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), "the same declared fields")
    Do $$$AssertEquals(tRoute.rows.%Size(), 1, "the route answers one row too")
    If (tView.rows.%Size() '= 1) || (tRoute.rows.%Size() '= 1) Quit
    Do $$$AssertEquals(tView.rows.%Get(0).Pid, tPid, "the tool's row names this test process's own Pid")
    Do $$$AssertEquals(tRoute.rows.%Get(0).Pid, tPid, "and so does the route's")
    Do $$$AssertEquals(..KeysOf(tView.rows.%Get(0)), ..KeysOf(tRoute.rows.%Get(0)), "the tool's row carries the route row's keys, in order")
    Do $$$AssertEquals(tRoute.rows.%Get(0).NameSpace, $Namespace, "the route's row is this test process's, by its vendor-answered namespace")
    Do $$$AssertEquals(tView.rows.%Get(0).UserName, tRoute.rows.%Get(0).UserName, "and the tool's row names the same vendor-answered user")
    Do $$$AssertEquals(tView.rows.%Get(0).%GetTypeOf("Variables"), "unassigned", "the tool's one row carries no Variables key")
}

}
