/// <p>Pins Stories 18.31's and 18.33's reads: the screen's declared read and <code>webapp.routineapps.read</code> answer the same rows
/// from one read, each carrying <code>Enabled</code> and <code>Description</code> from the application's own
/// <code>GET</code> (the list answers neither) and <code>Enabled</code> a boolean; <code>GET /routine-application/form</code>
/// answers an application's name and three settings and a new application's defaults; an application the instance does
/// not hold is 404 <code>PORT.NOTFOUND</code>, and a name another kind of application holds is 404
/// <code>PRIVROUTINE.TYPE</code>. An existing application's form read also carries its two lists as the vendor's own
/// <code>GET</code> reads them, the instance's roles with each one's privileged mark and the databases the instance
/// defines.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe privileged routine
/// applications (<class>OcuPilot.Test.RoutineAppProbe</class>) and removes them by exact name before all, after each and
/// after all. It reads OcuPilot's own two routine applications and never writes them. After each test the application
/// list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "webapp.routineapps";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppRead creates probe privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>C1: the screen and the tool answer the same rows, each carrying the four list fields with <code>Enabled</code> a
/// boolean read from the application's own <code>GET</code> -- the vendor's <code>LIST</code> answers it false on every
/// row and answers no description -- and the probe applications are listed named as written; OcuPilot's own two are
/// listed with the flag each one's <code>GET</code> reads at that moment.</p>
/// <p>Mutation (Rule 19): drop the <code>rowGet</code> from <class>OcuPilot.Screen.Descriptor.RoutineAppList</class> --
/// the live-list legs stay and the rows legs go red, the screen answering <code>Enabled</code> false and no
/// description.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", {"Description": "first", "Enabled": false, "Resource": ""}), "a first probe application")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "ocuprobe1831b", {"Description": "second", "Enabled": true, "Resource": "OcuProbe1831Res"}), "and a second naming the resource")
    Kill tQuery
    Set tRawSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "LIST", .tQuery, "", .tRaw, .tRawHttp, .tRawFault)
    Do $$$AssertStatusOK(tRawSC, "the live privileged routine LIST answers")
    Set tProbeRows = 0
    Set tRawIterator = $Select($IsObject($Get(tRaw)) && tRaw.%IsA("%Library.DynamicArray"): tRaw.%GetIterator(), 1: "")
    While $IsObject(tRawIterator) && tRawIterator.%GetNext(.tRawIndex, .tRawRow) {
        If '$IsObject(tRawRow) || '$ClassMethod(..#PROBE, "IsProbe", tRawRow.%Get("Name")) Continue
        Set tProbeRows = tProbeRows + 1
        Do $$$AssertEquals(tRawRow.%IsDefined("Description") _ tRawRow.%Get("Enabled"), "00", "the live row of " _ tRawRow.%Get("Name") _ " carries no description and reads Enabled false whatever the application holds")
    }
    Do $$$AssertEquals(tProbeRows, 2, "both probe applications are in the live list")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 100, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Set tSeen = ""
    Set tOwn = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "Description,Enabled,Name,Resource", "row " _ tIndex _ " carries the four list fields and nothing else")
        Do $$$AssertEquals(tRow.%GetTypeOf("Enabled"), "boolean", "row " _ tIndex _ " reads Enabled as a boolean")
        If $ClassMethod(..#PROBE, "IsProbe", tRow.%Get("Name")) Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ tRow.%Get("Enabled") _ ":" _ tRow.%Get("Description") _ ":" _ tRow.%Get("Resource")
        If $ListFind($ListBuild("OcuPilotState", "OcuPilotIdentity"), tRow.%Get("Name")) Set tOwn = tOwn _ $Select(tOwn = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ tRow.%Get("Enabled")
    }
    Do $$$AssertEquals(tSeen, "OcuProbe1831A:0:first:,ocuprobe1831b:1:second:OcuProbe1831Res", "both probes are listed, named as written, with Enabled, description and resource as stored")
    Set tOwnStored = "OcuPilotIdentity:" _ ''$ClassMethod(..#PROBE, "StoredField", "", "OcuPilotIdentity", "Enabled") _ ",OcuPilotState:" _ ''$ClassMethod(..#PROBE, "StoredField", "", "OcuPilotState", "Enabled")
    Do $$$AssertEquals(..Sorted(tOwn), tOwnStored, "and OcuPilot's own two are listed with the flag each one's GET reads")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "webapp.routineapps.read resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 100}, 100, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's rows")
}

/// <p>C1: over the wire the form read answers 200 as JSON for a probe application: <code>Name</code> and its three
/// settings, no namespace; the same application named in another case answers the same application; an absent one is
/// 404 <code>PORT.NOTFOUND</code> and a name a web application holds 404 <code>PRIVROUTINE.TYPE</code>; a new
/// application's form carries its defaults.</p>
/// <p>Mutation (Rule 19): point <parameter>OcuPilot.Area.WebApp.RoutineAppRules.UPDATETOOL</parameter> at the Doc DB update
/// tool -- the form read answers 404 for an application that exists and this goes red; make
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Truth</method> answer 0 -- the enabled application's leg goes red.</p>
Method TestTheFormReadAnswersTheNameAndThreeSettings()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", {"Description": "form", "Enabled": false, "Resource": ""}), "a probe application")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=OcuProbe1831A", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /routine-application/form answers: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm), "databases,roles,row", "the form answers the row, the roles and the databases")
    Set tRow = tForm.%Get("row")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "Description,Enabled,MatchRoles,Name,Resource,Routines", "the row carries the name, the three settings and the two lists, and no namespace")
    Do $$$AssertEquals(tRow.%Get("Name") _ "|" _ tRow.%Get("Description") _ "|" _ tRow.%Get("Enabled") _ "|" _ tRow.%GetTypeOf("Enabled") _ "|" _ tRow.%Get("Resource"), "OcuProbe1831A|form|0|boolean|", "as the instance stores them, Enabled a boolean")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=ocuprobe1831a", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("row").%Get("Description"), "200 form", "the same application named in another case is the same application")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831R", {"Description": "held", "Enabled": true, "Resource": "OcuProbe1831Res"}), "an application naming it")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=OcuProbe1831R", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tHeldRow = ##class(%DynamicObject).%FromJSON(tRaw).%Get("row")
    Do $$$AssertEquals(tStatus _ " " _ tHeldRow.%Get("Resource") _ " " _ tHeldRow.%Get("Enabled") _ tHeldRow.%GetTypeOf("Enabled"), "200 OcuProbe1831Res 1boolean", "an enabled application's resource and flag are the ones the form reads")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=OcuProbe1831Z", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 PORT.NOTFOUND", "an application the instance does not hold is 404 PORT.NOTFOUND")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=" _ $ZConvert("/csp/user", "O", "URL"), tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 PRIVROUTINE.TYPE", "a name a web application holds is 404 PRIVROUTINE.TYPE")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tNew = ##class(%DynamicObject).%FromJSON(tRaw).%Get("row")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tNew) _ " " _ tNew.%Get("Name") _ tNew.%Get("Description") _ tNew.%Get("Resource") _ " " _ tNew.%Get("Enabled") _ tNew.%GetTypeOf("Enabled"), "200 Description,Enabled,Name,Resource  1boolean", "a new application's form carries the same members, enabled and otherwise empty")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=OcuPilotState", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tOwn = ##class(%DynamicObject).%FromJSON(tRaw).%Get("row")
    Do $$$AssertEquals(tStatus _ " " _ tOwn.%Get("Name") _ " " _ tOwn.%Get("Enabled"), "200 OcuPilotState " _ ''$ClassMethod(..#PROBE, "StoredField", "", "OcuPilotState", "Enabled"), "OcuPilot's own application is read, which no rule refuses")
}

/// <p>C1: the form read of an application holding a role and a routine answers the two lists exactly as the vendor's own
/// <code>GET</code> does, <code>roles</code> as <code>[{name, privileged}]</code> with <code>%All</code> marked
/// privileged and a database role not, and <code>databases</code> as the names <code>Config.Databases</code> lists; a new
/// application's form carries neither.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.RoutineAppRules.FormRead</method> add nothing -- every leg
/// goes red.</p>
Method TestTheFormReadCarriesTheListsTheRolesAndTheDatabases()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", $ClassMethod(..#PROBE, "WithLists", "lists")), "a probe application holding a role and a routine")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form?id=OcuProbe1831A", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /routine-application/form answers: " _ $Extract(tRaw, 1, 300))
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tStored = $ClassMethod(..#PROBE, "Stored", "", "OcuProbe1831A")
    Do $$$AssertEquals(tForm.%Get("row").%Get("MatchRoles").%ToJSON(), tStored.%Get("MatchRoles").%ToJSON(), "the row's roles are the GET's")
    Do $$$AssertEquals(tForm.%Get("row").%Get("Routines").%ToJSON(), tStored.%Get("Routines").%ToJSON(), "and its routines")
    Do $$$AssertEquals(tForm.%Get("row").%Get("MatchRoles").%ToJSON(), "[{""MatchRole"":"""",""TargetRoles"":[""%DB_HSCUSTOM""]}]", "which are the ones the probe was created with")
    Set tAll = ""
    Set tDatabaseRole = ""
    Set tShapes = 0
    Set tIterator = tForm.%Get("roles").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        Set tShapes = tShapes + (##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRole) '= "name,privileged")
        If tRole.%Get("name") = "%All" Set tAll = tRole.%Get("privileged") _ tRole.%GetTypeOf("privileged")
        If tRole.%Get("name") = "%DB_HSCUSTOM" Set tDatabaseRole = tRole.%Get("privileged")
    }
    Do $$$AssertEquals(tShapes, 0, "each role carries its name and its mark")
    Do $$$AssertEquals(tAll, "1boolean", "%All is marked privileged")
    Do $$$AssertEquals(tDatabaseRole, 0, "and a database role is not")
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        Do tRS.Execute("*")
        While tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.Get("Name")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(ex.AsStatus(), "Config.Databases:List is read")
    }
    Set tListed = ""
    Set tIterator = tForm.%Get("databases").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tName
    }
    Do $$$AssertNotEquals(tNames, "", "the instance defines databases")
    Do $$$AssertEquals(..Sorted(tListed), ..Sorted(tNames), "the form lists the databases Config.Databases lists")
    Set tPrevious = ""
    Set tOrdered = 1
    Set tIterator = tForm.%Get("databases").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If $ZConvert(tPrevious, "U") ] $ZConvert(tName, "U") Set tOrdered = 0
        Set tPrevious = tName
    }
    Do $$$AssertEquals(tOrdered, 1, "in order, without regard to case")
    Set tPort = "OcuPilot.Port.AdminPort"
    Do $$$AssertEquals($ClassMethod(tPort, "DatabaseDefined", "HSCUSTOM") _ $ClassMethod(tPort, "DatabaseDefined", "hscustom") _ $ClassMethod(tPort, "DatabaseDefined", "") _ $ClassMethod(tPort, "DatabaseDefined", "OCUPROBE1833NODB"), "1000", "a database is defined by its name exactly as written")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/routine-application/form", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(##class(%DynamicObject).%FromJSON(tRaw)), "row", "a new application's form carries the row alone")
}

/// <p>AD-10, DW-2262: the admin port answers a read of a name another kind of application holds as 404
/// <code>PRIVROUTINE.TYPE</code> from <class>OcuPilot.Api.RoutineAppError</class>, before the vendor and without a log
/// line, and an absent name as the vendor's own 404.</p>
/// <p>Mutation (Rule 19): drop the type check from <method>OcuPilot.Port.AdminPort.PrivilegedRoutineGuard</method> -- the
/// web application leg goes red.</p>
Method TestAWebApplicationNameIsRefusedByTheTypeCheck()
{
    Kill tQuery
    Set tQuery("name") = "/csp/user"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "0 404 " _ ##class(OcuPilot.Api.RoutineAppError).#TYPE _ "|" _ ##class(OcuPilot.Api.RoutineAppError).#REASONTYPE, "a web application's name reads as 404 with the published code and sentence")
    Kill tQuery
    Set tQuery("name") = "OcuProbe1831Z"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "and an absent name as the not-found code")
}

/// <p><var>pText</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pText As %String) As %String
{
    Quit ##class(OcuPilot.Test.SuperserverDescriptor).Sorted(pText)
}

}
