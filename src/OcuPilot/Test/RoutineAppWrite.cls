/// <p>Pins Story 18.31's writes on both callers of each tool (C2 and C3): the form's Save and the list's Delete over the
/// wire (<code>POST /routine-application</code>, <code>PUT /routine-application/:id</code>, <code>POST
/// /screens/webapp.routineapps/action</code>), and the agent's mint and confirm -- a create that stores the name as
/// typed, a change that keeps the roles and routines the application holds, a delete, every row of the rules refused
/// before any <code>PUT</code>, a name any application holds, a moved target, a held lock, a web application write that
/// names a routine application (DW-2252), and OcuPilot's own two applications refused every write.</p>
/// <p>Every write is real for an application named <code>OcuProbe1831...</code> and the class touches no other: each
/// application a test asserts on it creates, and each is removed by exact name. <b>It never writes
/// <code>OcuPilotState</code> or <code>OcuPilotIdentity</code>:</b> every leg that names them is refused before the port,
/// and the class compares both applications' stored state before and after each test, read-only.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, changes and deletes probe
/// applications and one probe resource and sets the governance policy. After each test the application list reads as that
/// test found it.</p>
Class OcuPilot.Test.RoutineAppWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RoutineAppCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.RoutineAppDelete";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter SCREEN = "webapp.routineapps";

Parameter ERRORS = "OcuPilot.Api.RoutineAppError";

/// <p>The code the kernel's own-application arm answers.</p>
Parameter OWNCODE = "PROHIBITED.OCUPILOTROUTINEAPP";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>OcuPilot's own two applications as the vendor reads them before the test.</p>
Property PreparedOwn As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppWrite creates, changes and deletes probe privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Set ..PreparedOwn = ..OwnTwo()
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Kill tSettings
    Set tSettings("webapp.routineapps.create") = "enabled"
    Set tSettings("webapp.routineapps.update") = "enabled"
    Set tSettings("webapp.routineapps.delete") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do $$$AssertNotEquals(..PreparedOwn, "", "OcuPilot's own two applications were read before the test")
    Do $$$AssertEquals(..OwnTwo(), ..PreparedOwn, "and read the same after it")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C2: a create on both callers stores the name exactly as written, answers the id and the read-back, the read-back
/// reads <code>matches</code>, and the application holds no role and no routine.</p>
/// <p>Mutation (Rule 19): remove the <code>TypedId</code> override from <class>OcuPilot.Screen.Tool.RoutineAppCreate</class>
/// -- the inherited Doc DB join answers nothing for these arguments and the agent leg stores the name lower-cased and goes
/// red.</p>
Method TestACreateStoresTheNameAsTypedOnBothCallers()
{
    Set tBody = {"Name": "OcuProbe1831Mixed", "Description": "screen", "Enabled": true, "Resource": ""}
    Do ..Save(tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "matches", "its read-back matches")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("id") _ "|" _ tAnswer.%Get("name") _ "|" _ tAnswer.%IsDefined("namespace"), 1: ""), "OcuProbe1831Mixed|OcuProbe1831Mixed|0", "the id is the name as written and the answer names no namespace")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "OcuProbe1831Mixed", "the instance stores OcuProbe1831Mixed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831Mixed", "Description"), "screen", "with the description sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", "OcuProbe1831Mixed"), "[]|[]", "and no role and no routine")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "the application is removed")

    Set tArgs = {"Name": "OcuProbe1831Mixed", "Description": "agent", "Enabled": "1"}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1831Mixed", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "OcuProbe1831Mixed", "the instance stores OcuProbe1831Mixed, not the folded spelling")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831Mixed"), "agent|1|", "with the description and the enabled flag sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", "OcuProbe1831Mixed"), "[]|[]", "and no role and no routine")
}

/// <p>C2: the longest name and description the instance stores, 64 and 256 characters, are accepted on the form's
/// Save.</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Api.RoutineAppError.NAMEMAX</parameter> to 63 -- the name leg goes
/// red.</p>
Method TestTheLongestNameAndDescriptionAreAccepted()
{
    Set tName = "OcuProbe1831" _ $Translate($Justify("", 52), " ", "n")
    Set tDescription = $Translate($Justify("", 256), " ", "d")
    Do $$$AssertEquals($Length(tName), 64, "a name of 64 characters")
    Do ..Save({"Name": (tName), "Description": (tDescription)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer), "201 matches", "is accepted with a description of 256: " _ ..Text(tAnswer))
    Do $$$AssertEquals($Length($ClassMethod(..#PROBE, "StoredField", "", tName, "Description")), 256, "and stored whole")
}

/// <p>C2: every form of <code>Enabled</code> the rules admit -- <code>true</code>, <code>false</code>, 1, 0, "1" and "0" --
/// is stored as the boolean it reads as, on both callers.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.DocDbAppRules.CreateBody</method> return its argument as it is --
/// the agent's payload legs go red.</p>
Method TestEveryEnabledFormIsStoredAsABooleanOnBothCallers()
{
    Set tForms = $ListBuild($ListBuild("T", "true", 1), $ListBuild("F", "false", 0), $ListBuild("N1", "1", 1), $ListBuild("N0", "0", 0), $ListBuild("S1", """1""", 1), $ListBuild("S0", """0""", 0))
    For tI = 1:1:$ListLength(tForms) {
        Set tForm = $List(tForms, tI)
        Set tEnabled = ##class(%DynamicObject).%FromJSON("{""Enabled"": " _ $List(tForm, 2) _ "}")
        Set tName = $ClassMethod(..#PROBE, "Name", "S" _ $List(tForm, 1))
        Set tBody = {"Name": (tName), "Description": "form"}
        Do tBody.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Do ..Save(tBody, .tStatus, .tAnswer)
        Set tStored = $ClassMethod(..#PROBE, "Stored", "", tName)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), "201 " _ $List(tForm, 3) _ "boolean", "the form's create with Enabled " _ $List(tForm, 2) _ " stores " _ $List(tForm, 3))
        Set tAgentName = $ClassMethod(..#PROBE, "Name", "A" _ $List(tForm, 1))
        Set tArgs = {"Name": (tAgentName)}
        Do tArgs.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tAgentName, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's create with Enabled " _ $List(tForm, 2) _ " is minted (" _ tProblem _ ")")
        Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload) _ " " _ tPayload.%GetTypeOf("Enabled"), "Description,Enabled,Resource boolean", "its proposal carries the complete set with Enabled a boolean")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteDetail).Fields(tProposal) _ "|" _ $Select($IsObject(tProposal): tProposal.%Get("unchangedCount"), 1: ""), "Enabled|2", "its card's one change row is the Enabled the caller sent, the two omitted settings counted unchanged (AD-54)")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult) _ " " _ ..Verdict($Get(tResult)), "200  matches", "and confirmed, its read-back matching")
        Set tStored = $ClassMethod(..#PROBE, "Stored", "", tAgentName)
        Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), $List(tForm, 3) _ "boolean", "it stores " _ $List(tForm, 3))
    }
}

/// <p>C2: a change on the form's Save with each form of <code>Enabled</code> the rules admit flips the flag the
/// application held, answers a matching read-back and stores the boolean the form reads as.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.DocDbAppRules.IsEnabled</method> refuse a number -- the number
/// legs go red.</p>
Method TestEveryEnabledFormChangesTheFlagOnTheFormsSave()
{
    Set tForms = $ListBuild($ListBuild("T", "true", 1), $ListBuild("F", "false", 0), $ListBuild("N1", "1", 1), $ListBuild("N0", "0", 0), $ListBuild("S1", """1""", 1), $ListBuild("S0", """0""", 0))
    For tI = 1:1:$ListLength(tForms) {
        Set tForm = $List(tForms, tI)
        Set tName = $ClassMethod(..#PROBE, "Name", "C" _ $List(tForm, 1))
        Set tSeed = {"Description": "flag", "Resource": ""}
        Do tSeed.%Set("Enabled", ($List(tForm, 3) = 0), "boolean")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", tName, tSeed), "an application holding the opposite flag")
        Set tEnabled = ##class(%DynamicObject).%FromJSON("{""Enabled"": " _ $List(tForm, 2) _ "}")
        Set tBody = {}
        Do tBody.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Do ..Change(tName, tBody, .tStatus, .tAnswer)
        Set tStored = $ClassMethod(..#PROBE, "Stored", "", tName)
        Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer) _ " " _ $Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), "200 matches " _ $List(tForm, 3) _ "boolean", "the form's change with Enabled " _ $List(tForm, 2) _ " reads back matching and stores " _ $List(tForm, 3))
    }
}

/// <p>C2 (AD-4): a change on both callers keeps every setting it does not send and the role and the routine the application
/// holds, applies the ones it does, answers the read-back, and the application's name stays as stored although the id
/// names it in another case; a change that changes nothing sends nothing.</p>
/// <p>Mutation (Rule 19): a temporary <code>MergeUpdate</code> override on
/// <class>OcuPilot.Screen.Tool.RoutineAppUpdate</class> that calls the inherited one and removes <code>Routines</code>
/// from the payload -- the vendor empties the routines and the lists legs go red on both callers.</p>
Method TestAChangeKeepsWhatItDoesNotSendOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Set tSeed = $ClassMethod(..#PROBE, "WithLists", "before")
    Do tSeed.%Set("Resource", "OcuProbe1831Res")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", tSeed), "a probe application naming it, holding a role and a routine")
    Set tLists = $ClassMethod(..#PROBE, "Lists", "OcuProbe1831A")
    Do $$$AssertEquals(tLists, "[{""MatchRole"":"""",""TargetRoles"":[""%DB_HSCUSTOM""]}]|[{""RoutineOrClass"":""OcuProbe1831.Routine"",""Db"":""HSCUSTOM"",""Type"":""Class""}]", "which the instance holds")
    Do ..Change("ocuprobe1831a", {"Description": "form"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form's change answers 200 although the id names the application in other case: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831A"), "form|1|OcuProbe1831Res", "the description changed, the other two settings as they were")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", "OcuProbe1831A"), tLists, "and the role and the routine are as they were")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "OcuProbe1831A", "and the application keeps the name it was created with")
    Do ..Change("ocuprobe1831a", {"Description": "form"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): +tAnswer.%IsDefined("readBack"), 1: "-"), "200 0", "a change that changes nothing is answered without a write")

    Set tArgs = {"Name": "OcuProbe1831A", "Enabled": false}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
    Do $$$AssertEquals(tPayload.%Get("Description") _ "|" _ tPayload.%Get("Enabled") _ "|" _ tPayload.%Get("Resource"), "form|0|OcuProbe1831Res", "its proposal carries the fresh read's three settings with the change applied")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload), "Description,Enabled,MatchRoles,Resource,Routines", "and the fresh read's two lists, which the vendor would empty if they were not sent")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831A"), "form|0|OcuProbe1831Res", "the flag changed, the description and the resource as they were")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", "OcuProbe1831A"), tLists, "and the role and the routine are as they were")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Enabled": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an agent change that changes nothing is refused at the mint: " _ tProblem)
    Do ..Change("OcuProbe1831A", {"Resource": ""}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831A", "Resource") _ " " _ ($ClassMethod(..#PROBE, "Lists", "OcuProbe1831A") = tLists), "200  1", "a change to an empty resource clears it and still keeps the lists")
}

/// <p>C2: a delete on both callers removes the application and reads back absent, whatever role and routine it holds; a
/// delete of an application the instance does not hold is 404 <code>PORT.NOTFOUND</code> from the Delete and refused at
/// the agent's mint, whose card lists the five fields it removes.</p>
/// <p>Mutation (Rule 19): drop <code>Security.PrivilegedRoutine/DELETE</code> from
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> -- the delete legs answer 501 and go red; drop
/// <code>MatchRoles,Routines</code> from <parameter>OcuPilot.Screen.Tool.RoutineAppDelete.FINGERPRINTSUBJECT</parameter> -- the
/// last leg deletes an application whose lists moved since the mint and goes red.</p>
Method TestADeleteRemovesTheApplicationOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Do ..Remove("OcuProbe1831A", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers 200: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "notFound", "its read-back reads the application absent")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, "the application is gone")
    Do ..Remove("OcuProbe1831A", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "an application the instance does not hold is 404 PORT.NOTFOUND")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831B", $ClassMethod(..#PROBE, "WithLists", "agent")), "a second probe application")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuProbe1831B", {"Name": "OcuProbe1831B"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "destructive") _ " " _ ##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "consequence"), "1 ", "destructive, stating no consequence")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteDetail).Fields(tProposal), "Description,Enabled,MatchRoles,Resource,Routines", "its card lists the three settings and the two lists it removes")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "notFound", "its read-back reads the application absent")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, "the application is gone")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuProbe1831B", {"Name": "OcuProbe1831B"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a delete of the absent application is refused at the mint: " _ tProblem)

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831C", {"Description": "agent", "Enabled": true, "Resource": ""}), "a third probe application holding no role and no routine")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuProbe1831C", {"Name": "OcuProbe1831C"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "its delete is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831C", $ClassMethod(..#PROBE, "WithLists", "agent")), "and a role and a routine are added, which no setting shows")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "", "OcuProbe1831C")), 1, "and the application is still there")
}

/// <p>C2: every row of the create's rules is refused on its field before any <code>PUT</code>, by the form's Save as a 422
/// <code>PRIVROUTINE.VALIDATION</code> carrying the violation and by the agent's mint as its problem naming the field and
/// the published sentence, an empty name as 400 <code>TOOL.ARGUMENTS</code> at the mint; no application is created.</p>
/// <p>Mutation (Rule 19): drop the <code>Description</code> length rule from
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Valid</method> -- its legs create the application and go red.</p>
Method TestEveryCreateRuleIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tErrors = ..#ERRORS
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tLongDescription = $Translate($Justify("", 257), " ", "d")
    Set tCases = ""
    Set tCases = tCases _ $ListBuild($ListBuild("name over 64", "{""Name"": ""OcuProbe1831" _ $Translate($Justify("", 53), " ", "n") _ """}", "Name", $Parameter(tErrors, "NAME"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("name empty", "{""Name"": """"}", "Name", $Parameter(tErrors, "NAME"), 1))
    Set tCases = tCases _ $ListBuild($ListBuild("description over 256", "{""Description"": """ _ tLongDescription _ """}", "Description", $Parameter(tErrors, "DESCRIPTION"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("description a number", "{""Description"": 5}", "Description", tShape, 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled yes", "{""Enabled"": ""yes""}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled the text true", "{""Enabled"": ""true""}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled 2", "{""Enabled"": 2}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled null", "{""Enabled"": null}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled an object", "{""Enabled"": {}}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource absent", "{""Resource"": ""OcuProbe1831NoSuchRes""}", "Resource", $Parameter(tErrors, "RESOURCE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource a database resource", "{""Resource"": ""%DB_IRISSYS""}", "Resource", $Parameter(tErrors, "RESOURCE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource a number", "{""Resource"": 5}", "Resource", tShape, 0))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBody = {"Name": "OcuProbe1831R", "Description": "rule", "Enabled": true, "Resource": ""}
        Set tOverride = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tIterator = tOverride.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = tOverride.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do tBody.%Set(tKey, tValue)
            } Else {
                Do tBody.%Set(tKey, tValue, tType)
            }
        }
        Do ..Save(tBody, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, $List(tCase, 3)), "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": the Save is refused on " _ $List(tCase, 3) _ ": " _ ..Text(tAnswer))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), $Parameter(tErrors, "VALIDATION"), $List(tCase, 1) _ ": under the validation envelope, never INTERNAL")
        Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, $List(tCase, 1) _ ": and no application was created")
        Set tName = $Select(tBody.%GetTypeOf("Name") = "string": tBody.%Get("Name"), 1: "OcuProbe1831R")
        If $List(tCase, 5) {
            ; A name that names no target is refused by the tool's own entry, before the mint.
            Set tSC = $ClassMethod(..#CREATETOOL, "View", "", tBody, 100, .tResult, .tHttp, .tFault)
        } Else {
            Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tName, tBody, .tProposal, .tHttp, .tProblem)
        }
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's mint is refused")
        Do $$$AssertEquals(tHttp, 400, $List(tCase, 1) _ ": as 400 TOOL.ARGUMENTS")
        If '$List(tCase, 5) Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, $List(tCase, 1) _ ": and the mint created no application")
    }
    Do ..Save({"Name": 5}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ tShape, "a name that is not text is refused on Name as a shape violation: " _ ..Text(tAnswer))
}

/// <p>C2: every row of the change's rules is refused on its field before any <code>PUT</code>, by the form's Save as a 422
/// and by the agent's mint as its problem; the application is as it was. A resource that was not changed is never judged:
/// an application naming a resource the instance no longer holds still takes a change to its description.</p>
/// <p>Mutation (Rule 19): judge the resource of an update even when it is unchanged (the guard in
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Check</method> read as true) -- the stored-resource leg goes red.</p>
Method TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tErrors = ..#ERRORS
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831U", {"Description": "keep", "Enabled": true, "Resource": ""}), "a probe application to change")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tCases = $ListBuild($ListBuild("description over 256", "{""Description"": """ _ $Translate($Justify("", 257), " ", "d") _ """}", "Description", $Parameter(tErrors, "DESCRIPTION")), $ListBuild("description a number", "{""Description"": 5}", "Description", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE), $ListBuild("enabled yes", "{""Enabled"": ""yes""}", "Enabled", $Parameter(tErrors, "ENABLED")), $ListBuild("enabled 2", "{""Enabled"": 2}", "Enabled", $Parameter(tErrors, "ENABLED")), $ListBuild("resource absent", "{""Resource"": ""OcuProbe1831NoSuchRes""}", "Resource", $Parameter(tErrors, "RESOURCE")), $ListBuild("resource a database resource", "{""Resource"": ""%DB_IRISSYS""}", "Resource", $Parameter(tErrors, "RESOURCE")), $ListBuild("resource a number", "{""Resource"": 5}", "Resource", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tChange = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do ..Change("OcuProbe1831U", tChange, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, $List(tCase, 3)), "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": a change is refused on its field: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, $List(tCase, 1) _ ": and nothing was written")
        Do tChange.%Set("Name", "OcuProbe1831U")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831U", tChange, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's change is refused (" _ tProblem _ ")")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831V", {"Description": "keep", "Enabled": true, "Resource": "OcuProbe1831Res"}), "an application naming it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveResource"), "which the instance then no longer holds")
    Do ..Change("OcuProbe1831V", {"Description": "changed"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a change to the description is not refused for the resource it did not touch: " _ ..Text(tAnswer))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831V", {"Name": "OcuProbe1831V", "Description": "again"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "nor is the agent's (" _ tProblem _ ")")
}

/// <p>C2: a resource that is a service, system or application resource the instance lists is accepted on both callers,
/// and an empty one is.</p>
/// <p>Mutation (Rule 19): list only <code>Application</code> in <parameter>OcuPilot.Area.WebApp.DocDbAppRules.RESOURCETYPES</parameter>
/// -- the service and system legs go red.</p>
Method TestAListedServiceOrApplicationResourceIsAccepted()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Set tCases = $ListBuild($ListBuild("OcuProbe1831Svc", "%Service_DocDB"), $ListBuild("OcuProbe1831Sys", "%DocDB_Admin"), $ListBuild("OcuProbe1831App", "OcuProbe1831Res"))
    For tI = 1:1:$ListLength(tCases) {
        Set tName = $List($List(tCases, tI), 1)
        Set tResource = $List($List(tCases, tI), 2)
        Do ..Save({"Name": (tName), "Resource": (tResource)}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "StoredField", "", tName, "Resource"), "201 " _ tResource, "the form's create naming " _ tResource)
        Set tAgentName = tName _ "X"
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tAgentName, {"Name": (tAgentName), "Resource": (tResource)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's create naming " _ tResource _ " is minted (" _ tProblem _ ")")
    }
}

/// <p>C2: a name any application holds is refused by the Save's own look-up and by the agent's mint, in any case and
/// whatever kind of application holds it -- a routine application, a web application or one of OcuPilot's own; a name
/// taken since the mint is refused by the absence fingerprint at the confirm; a target moved since the mint refuses the
/// confirm as changed; and a target another write holds answers 409 <code>WRITE.TARGETBUSY</code> after the wait, with
/// no write.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Mint.AbsenceState</method> ignore its argument -- the
/// taken-since leg overwrites the application and goes red; make <method>OcuPilot.Area.WebApp.RoutineAppRules.Taken</method>
/// read a <code>PRIVROUTINE.TYPE</code> 404 as free -- the web application leg goes red.</p>
Method TestATakenNameAMovedTargetAndABusyTargetAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", {"Description": "first", "Enabled": true, "Resource": ""}), "a probe application")
    Set tTaken = {"Name": "ocuprobe1831a", "Description": "second"}
    Do ..Save(tTaken, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "TAKEN"), "a create of a taken name in another case is refused on Name: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831A", "Description"), "first", "and the application is as it was")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "ocuprobe1831a", tTaken, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's create of it is refused at the mint: " _ tProblem)
    For tHeld = "/csp/user", "OcuPilotState", "ocupilotidentity" {
        Do ..Save({"Name": (tHeld)}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "TAKEN"), "a create naming " _ tHeld _ ", which another application holds, is refused on Name: " _ ..Text(tAnswer))
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tHeld, {"Name": (tHeld)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, "and the agent's mint of it is refused: " _ tProblem)
        Set tWhy = $Select(tHeld = "/csp/user": "'Name': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter(..#ERRORS, "TAKEN")), 1: "'" _ tHeld _ "' is already present on this instance")
        Do $$$AssertTrue(tProblem [ tWhy, "the mint names why, a web application's name by the field and the published sentence and an application the kernel finds held by its own: " _ tProblem)
    }
    Set tFree = {"Name": "OcuProbe1831B", "Description": "agent"}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1831B", tFree, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create of a free name is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "ocuprobe1831b", {"Description": "taken since", "Enabled": true, "Resource": ""}), "and the name is taken since, in another case")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused by the absence fingerprint")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831B", "Description"), "taken since", "and the application is as the other writer left it")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Description": "agent"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", {"Description": "first", "Enabled": false, "Resource": ""}), "and a setting the payload carries moves")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831A", "Description"), "first", "and nothing was written")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Description": "agent"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted again (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", $ClassMethod(..#PROBE, "WithLists", "first")), "and a role and a routine are added, which the payload also carries")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target, the lists included")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("routine-application", "instance", "OcuProbe1831A", .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tRef)
    Do $$$AssertNotEquals(tLockKey, "", "the application names a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", "OcuProbe1831A"), .tStatus, .tBusy, {"Description": "busy"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code") _ " " _ tBusy.%Get("reason"), 1: tBusy), "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held Save is refused busy, with the published reason")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831A", "Description"), "first", "and nothing was written")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("routine-application", "instance", "OcuProbe1831C", .tFreeRef)
    Set tFreeKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tFreeRef)
    Lock +^OcuPilotProposalTarget(tFreeKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "a free name's lock, held as another create's hold is")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/routine-application", .tStatus, .tBusy, {"Name": "OcuProbe1831C"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tFreeKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code"), 1: tBusy), "409 WRITE.TARGETBUSY", "a create of a held name is refused busy")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "", "OcuProbe1831C")), 0, "and nothing was created")
}

/// <p>The write routes answer over the wire as JSON: <code>POST /routine-application</code> creates a probe application with
/// 201 and <code>PUT /routine-application/:id</code> changes it with 200, each answering the id, the name and the
/// read-back; a body key outside the settings -- the name on a change, a namespace on a create -- is 400
/// <code>PORT.FIELD.UNEXPECTED</code> before anything is read; an application the instance does not hold is 404
/// <code>PORT.NOTFOUND</code> and a name a web application holds 404 <code>PRIVROUTINE.TYPE</code>; a body that is not an
/// object is 400.</p>
Method TestTheWriteRoutesAnswerOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/routine-application", .tStatus, .tAnswer, {"Name": "OcuProbe1831W", "Description": "wire"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST /routine-application answers 201")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("id") _ "|" _ tAnswer.%Get("name") _ "|" _ ..Verdict(tAnswer), 1: ""), "OcuProbe1831W|OcuProbe1831W|matches", "with the id, the name as written and the read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", "OcuProbe1831W"), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tChangeStatus, .tChangeRaw, .tHeaders, {"Description": "wire changed"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tChangeStatus, 200, "PUT /routine-application/:id answers 200: " _ $Extract(tChangeRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Verdict(##class(%DynamicObject).%FromJSON(tChangeRaw)), "matches", "with its read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831W", "Description"), "wire changed", "and the instance holds the change")
    Do ..Change("OcuProbe1831W", {"Name": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "a body naming Name is refused before anything is read")
    Do ..Save({"Name": "OcuProbe1831W", "Namespace": "user"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "and so is a create's body naming a namespace, which an application has not")
    Do ..Save({"Name": "OcuProbe1831W", "Service": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "and a key the tool does not admit")
    Do ..Change("OcuProbe1831Z", {"Description": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "an application the instance does not hold is 404")
    Do ..Change("/csp/user", {"Description": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PRIVROUTINE.TYPE", "a name a web application holds is 404 PRIVROUTINE.TYPE, nothing sent")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/routine-application", .tStatus, .tAnswer, "[1]", "application/json")
    Do $$$AssertEquals(tStatus, 400, "a body that is not an object is 400")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 1, "and one probe application exists")
}

/// <p>The create with every field omitted but the name stores the instance's defaults: enabled, no description and no
/// resource, on both callers. The agent's card shows no change row for a setting the caller did not send and counts the
/// three unchanged (AD-54).</p>
/// <p>Mutation (Rule 19): drop the <code>CompleteBody</code> call from <method>OcuPilot.Screen.Tool.DocDbAppCreate.ComposeCreate</method>
/// -- the stored defaults and the card legs go red.</p>
Method TestACreateOfTheNameAloneTakesTheInstancesDefaults()
{
    Do ..Save({"Name": "OcuProbe1831D"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer) _ " " _ $ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831D"), "201 matches |1|", "the form's create stores the defaults: " _ ..Text(tAnswer))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1831E", {"Name": "OcuProbe1831E"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload), "Description,Enabled,Resource", "its proposal carries the three settings alone, the omitted ones at the instance's defaults")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteDetail).Fields(tProposal) _ "|" _ $Select($IsObject(tProposal): tProposal.%Get("unchangedCount"), 1: ""), "|3", "its card shows no change row for a setting the caller did not send, and counts the three unchanged")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831E"), "|1|", "the agent's stores the same")
}

/// <p>DW-2252: a web application write naming a privileged routine application is refused 409
/// <code>PRIVROUTINE.WEBAPP</code> before the vendor, which would answer a <code>PUT</code> 500 and delete the
/// application on a <code>DELETE</code>; the application reads as it did, a read of it through <code>WebApp.App</code>
/// is unchanged, and a name that is not a routine application is not stopped here.</p>
/// <p>Mutation (Rule 19): drop the <code>pWebApp</code> branch from <method>OcuPilot.Port.AdminPort.PrivilegedRoutineGuard</method>
/// -- the <code>PUT</code> leg answers the vendor's 500 and the <code>DELETE</code> leg deletes the probe, and both go
/// red.</p>
Method TestAWebApplicationWriteNamingARoutineApplicationIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", $ClassMethod(..#PROBE, "WithLists", "web")), "a probe application holding a role and a routine")
    Set tBefore = $ClassMethod(..#PROBE, "Lists", "OcuProbe1831A") _ "|" _ $ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831A")
    Kill tQuery
    Set tQuery("name") = "OcuProbe1831A"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a web application read of it is unchanged: the guard covers the writes")
    Kill tQuery
    Set tQuery("name") = "OcuProbe1831A"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tQuery, {"Description": "web"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "409 " _ ##class(OcuPilot.Api.RoutineAppError).#WEBAPP _ "|" _ ##class(OcuPilot.Api.RoutineAppError).#REASONWEBAPP, "a PUT naming it is refused 409 with the published code and sentence")
    Kill tQuery
    Set tQuery("name") = "OcuProbe1831A"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Api.RoutineAppError).#WEBAPP, "and so is a DELETE")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", "OcuProbe1831A") _ "|" _ $ClassMethod(..#PROBE, "Summary", "", "OcuProbe1831A"), tBefore, "the application reads as it did")
    Kill tQuery
    Set tQuery("name") = "/csp/ocuprobe1831absent"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertNotEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.RoutineAppError).#WEBAPP, "a name that is not a routine application is not refused by it")
}

/// <p>C2 (the web application row): a routine tool naming a web application's path -- the list's Delete, the agent's change
/// and delete -- is answered from the fresh read and sends nothing: the Delete 404 <code>PRIVROUTINE.TYPE</code>, the
/// mint a 400 refusal that the application is not present, and the web application reads as it did. The legs run only
/// while the port's type check answers <code>/csp/user</code> as 404 <code>PRIVROUTINE.TYPE</code>, so a broken check cannot
/// let the Delete reach a web application.</p>
/// <p>Mutation (Rule 19): not re-run on this class. The type check is the only thing between the list's Delete and the
/// web application, so a mutated check would delete <code>/csp/user</code> on the throwaway; the guard's own leg is
/// <method>OcuPilot.Test.RoutineAppRead.TestAWebApplicationNameIsRefusedByTheTypeCheck</method>, which only reads.</p>
Method TestAWebApplicationNameIsAnsweredFromTheFreshReadByEveryRoutineTool()
{
    Set tBefore = ##class(OcuPilot.Test.OwnRoutineApplication).WebAppJSON("/csp/user")
    Do $$$AssertNotEquals(tBefore, "", "/csp/user reads before the calls, so the unchanged read below cannot pass on an empty read")
    Kill tQuery
    Set tQuery("name") = "/csp/user"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Set tGuarded = (tHttp = 404) && $IsObject($Get(tFault)) && (tFault.%Get("code") = $Parameter(..#ERRORS, "TYPE"))
    Do $$$AssertTrue(tGuarded, "the port answers the name as 404 PRIVROUTINE.TYPE")
    If 'tGuarded Quit
    Do ..Remove("/csp/user", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 " _ $Parameter(..#ERRORS, "TYPE"), "the list's Delete is answered 404 PRIVROUTINE.TYPE from the fresh read")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "/csp/user", {"Name": "/csp/user", "Description": "x"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp, "0 400", "the agent's change is refused at the mint: " _ tProblem)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "/csp/user", {"Name": "/csp/user"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp, "0 400", "and so is its delete: " _ tProblem)
    Do $$$AssertEquals(##class(OcuPilot.Test.OwnRoutineApplication).WebAppJSON("/csp/user"), tBefore, "and the web application reads as it did")
}

/// <p>C3: OcuPilot's own two applications, in any case, are refused every write -- by the kernel's arm for each of the
/// three tools, asked through <code>Prohibits</code> and answering <code>PROHIBITED.OCUPILOTROUTINEAPP</code>; at the
/// agent's mint of a change or a delete as a 403; at the form's Save of a change and the list's Delete as a 403; and a create
/// naming them as a held name -- with nothing sent, and both applications read as they did. A probe application is
/// not refused by the arm.</p>
/// <p>Mutation (Rule 19): drop the <code>routine-application</code> arm from <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// -- the <code>Prohibits</code> legs go red, asked as a pure question; the wire legs stay green because the port arm
/// <method>OcuPilot.Kernel.Proposal.Prohibited.RoutineEndpointRefused</method> also refuses, so nothing is written either
/// way. Shrink <method>OcuPilot.Kernel.Proposal.Prohibited.RoutineApplicationChangeFields</method> to the three settings --
/// the <code>Routines</code> and <code>MatchRoles</code> legs go red.</p>
Method TestTheOwnTwoApplicationsAreRefusedEveryWrite()
{
    For tName = "OcuPilotState", "OcuPilotIdentity", "ocupilotstate", "OCUPILOTIDENTITY" {
        For tTool = "webapp.routineapps.create", "webapp.routineapps.update", "webapp.routineapps.delete" {
            Set tProhibits = ..Ask(tTool, tName, {"Description": "x"}.%ToJSON(), [{"field": "Description", "before": "a", "after": "x"}].%ToJSON(), .tCode, .tSC)
            Do $$$AssertStatusOK(tSC, "the set answers " _ tTool _ " on " _ tName)
            Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 " _ ..#OWNCODE, tTool _ " on " _ tName _ " is prohibited with the routine application code")
        }
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", "OcuProbe1831A", {"Description": "first", "Enabled": true, "Resource": ""}), "a probe application the set reads")
    Set tProhibits = ..Ask("webapp.routineapps.update", "OcuProbe1831A", {"Description": "x"}.%ToJSON(), [{"field": "Description", "before": "a", "after": "x"}].%ToJSON(), .tCode, .tSC)
    Do $$$AssertStatusOK(tSC, "the set answers a probe application's change")
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "which the arm does not refuse")
    For tField = "Routines", "MatchRoles" {
        Set tBody = {}
        Do tBody.%Set(tField, $Select(tField = "Routines": [{"RoutineOrClass": "OcuProbe1831.Routine", "Db": "HSCUSTOM", "Type": "Class"}], 1: [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}]))
        Set tProhibits = ..Ask("webapp.routineapps.update", "OcuProbe1831A", tBody.%ToJSON(), [{"field": (tField), "before": "a", "after": "x"}].%ToJSON(), .tCode, .tSC)
        Do $$$AssertStatusOK(tSC, "the set answers a diff naming " _ tField)
        Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "a probe application's " _ tField _ " is one of the update's five fields")
    }
    For tField = "Name", "Type" {
        Set tBody = {}
        Do tBody.%Set(tField, "x")
        Set tProhibits = ..Ask("webapp.routineapps.update", "OcuProbe1831A", tBody.%ToJSON(), [{"field": (tField), "before": "a", "after": "x"}].%ToJSON(), .tCode, .tSC)
        Do $$$AssertStatusOK(tSC, "the set answers a diff naming " _ tField)
        Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD, "a probe application's " _ tField _ " is not a field the tools change")
    }
    For tName = "OcuPilotState", "OcuPilotIdentity" {
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tName, {"Name": (tName), "Description": "x"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ tProblem, "0 403 " _ ..#OWNCODE, "the agent's change of " _ tName _ " is refused at the mint")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ tProblem, "0 403 " _ ..#OWNCODE, "and its delete")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, "and its create, which finds the name held: " _ tProblem)
        Do ..Change(tName, {"Description": "wire"}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403 " _ ..#OWNCODE, "the form's change of " _ tName _ " is refused")
        Do ..Remove(tName, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403 " _ ..#OWNCODE, "and the list's Delete of it")
    }
    Do $$$AssertEquals(..OwnTwo(), ..PreparedOwn, "OcuPilot's own two applications read as they did")
}

/// <p><code>POST /routine-application</code> with <var>pBody</var>: the status and the parsed answer.</p>
Method Save(pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/routine-application", .pStatus, .pAnswer, pBody.%ToJSON(), "application/json")
}

/// <p><code>PUT /routine-application/:id</code> for the name <var>pId</var> with <var>pBody</var>.</p>
Method Change(pId As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", pId), .pStatus, .pAnswer, pBody.%ToJSON(), "application/json")
}

/// <p>The list's Delete action for the name <var>pId</var>.</p>
Method Remove(pId As %String, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ ..#SCREEN _ "/action", .pStatus, .pAnswer, {"action": "delete", "id": (pId)}.%ToJSON(), "application/json")
}

/// <p>Prohibits for <var>pTool</var> against the routine application <var>pId</var>, with <var>pPayload</var> and
/// <var>pDiff</var>: the verdict and its code. <var>pSC</var> is the status the set answered, which the caller asserts, so
/// a failed call is never read as "not prohibited". A pure question: it writes nothing.</p>
ClassMethod Ask(pTool As %String, pId As %String, pPayload As %String, pDiff As %String, Output pCode As %String, Output pSC As %Status) As %Boolean
{
    Set pCode = ""
    Set pSC = ##class(OcuPilot.Kernel.EntityRef).Key("routine-application", "instance", pId, .tRef)
    If $$$ISERR(pSC) Quit 0
    Set pSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(pTool, tRef, pPayload, pDiff, .tProhibits, .tCode)
    If $$$ISERR(pSC) Quit 0
    Set pCode = tCode
    Quit tProhibits
}

/// <p>OcuPilot's own two applications as the vendor's <code>GET</code> reads them, one line each, or <code>""</code> when
/// either does not read. Read only.</p>
ClassMethod OwnTwo() As %String
{
    Set tOut = ""
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tRead)) Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: $Char(10)) _ tName _ " " _ tRead.%ToJSON()
    }
    Quit $Select($Length(tOut, $Char(10)) = 2: tOut, 1: "")
}

/// <p>The read-back verdict of <var>pAnswer</var>, or <code>(none)</code>
/// (<method>OcuPilot.Test.MftConnectionWrite.Verdict</method>).</p>
ClassMethod Verdict(pAnswer) As %String
{
    Quit ##class(OcuPilot.Test.MftConnectionWrite).Verdict(pAnswer)
}

/// <p>The code of the violation on <var>pField</var> in the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod ViolationOf(pAnswer, pField As %String) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("detail")) || (pAnswer.%Get("detail").%GetTypeOf("violations") '= "array") Quit ""
    Set tIterator = pAnswer.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = pField Quit
        Set tRow = ""
    }
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("code"), 1: "")
}

/// <p>The start of <var>pAnswer</var> as text, for an assertion message.</p>
ClassMethod Text(pAnswer) As %String
{
    Quit $Extract($Select($IsObject(pAnswer): pAnswer.%ToJSON(), 1: pAnswer), 1, 300)
}

}
