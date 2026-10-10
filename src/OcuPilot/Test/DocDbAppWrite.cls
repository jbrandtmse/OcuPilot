/// <p>Pins Story 18.30's writes on both callers of each tool (C2 to C4): the form's Save and the list's Delete over the
/// wire (<code>POST /docdb-application</code>, <code>PUT /docdb-application/:id</code>, <code>POST
/// /screens/webapp.docdbapps/action</code>), and the agent's mint and confirm -- a create that stores the name as typed
/// in the upper-cased namespace, a change that keeps what it does not send, a delete, every row of the rules refused
/// before any <code>PUT</code>, a name taken in any case, a moved target, a held lock, and the write routes' own
/// refusals.</p>
/// <p>Every write is real for a record named <code>OcuProbe1830...</code> in <code>USER</code> and the class touches no
/// other: each record a test asserts on it creates, and each is removed by exact namespace and name.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, changes and deletes probe
/// records and one probe resource and sets the governance policy. After each test the record list reads as that test
/// found it.</p>
Class OcuPilot.Test.DocDbAppWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DocDbAppProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.DocDbAppCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DocDbAppUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.DocDbAppDelete";

Parameter PORT = "OcuPilot.Port.DocDbAppPort";

Parameter SCREEN = "webapp.docdbapps";

Parameter ERRORS = "OcuPilot.Api.DocDbAppError";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbAppWrite creates, changes and deletes probe Doc DB application records on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Kill tSettings
    Set tSettings("webapp.docdbapps.create") = "enabled"
    Set tSettings("webapp.docdbapps.update") = "enabled"
    Set tSettings("webapp.docdbapps.delete") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe record and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the record list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the record list reads as before the test")
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

/// <p>C2 and C3: a create on both callers stores the name exactly as written in the upper-cased namespace, answers the
/// id and the read-back, and the read-back reads <code>matches</code>; a create naming the namespace in lower case
/// stores <code>USER</code>.</p>
/// <p>Mutation (Rule 19): remove the <code>TypedId</code> override from <class>OcuPilot.Screen.Tool.DocDbAppCreate</class>
/// -- the agent leg stores the name lower-cased and goes red.</p>
Method TestACreateStoresTheNameAsTypedOnBothCallers()
{
    Set tBody = {"Namespace": "user", "Name": "OcuProbe1830Mixed", "Description": "screen", "Enabled": true, "Resource": ""}
    Do ..Save(tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "matches", "its read-back matches")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("id") = $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830Mixed"), 1: 0), 1, "the id is the namespace as stored and the name as written")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "USER|OcuProbe1830Mixed", "the instance stores OcuProbe1830Mixed in USER")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830Mixed", "Description"), "screen", "with the description sent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "the record is removed")

    Set tArgs = {"Namespace": "user", "Name": "OcuProbe1830Mixed", "Description": "agent", "Enabled": "1"}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1830Mixed", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "USER|OcuProbe1830Mixed", "the instance stores OcuProbe1830Mixed in USER, not the folded spelling")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "USER", "OcuProbe1830Mixed"), "agent|1|", "with the description and the enabled flag sent")
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
        Set tBody = {"Namespace": "user", "Name": (tName), "Description": "form"}
        Do tBody.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Do ..Save(tBody, .tStatus, .tAnswer)
        Set tStored = $ClassMethod(..#PROBE, "Stored", "USER", tName)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), "201 " _ $List(tForm, 3) _ "boolean", "the form's create with Enabled " _ $List(tForm, 2) _ " stores " _ $List(tForm, 3))
        Set tAgentName = $ClassMethod(..#PROBE, "Name", "A" _ $List(tForm, 1))
        Set tArgs = {"Namespace": "user", "Name": (tAgentName)}
        Do tArgs.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tAgentName, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's create with Enabled " _ $List(tForm, 2) _ " is minted (" _ tProblem _ ")")
        Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload) _ " " _ tPayload.%GetTypeOf("Enabled"), "Description,Enabled,Resource boolean", "its proposal carries the complete set with Enabled a boolean")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteDetail).Fields(tProposal) _ "|" _ $Select($IsObject(tProposal): tProposal.%Get("unchangedCount"), 1: ""), "Enabled|2", "its card's one change row is the Enabled the caller sent, the two omitted settings counted unchanged (AD-54)")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult) _ " " _ ..Verdict($Get(tResult)), "200  matches", "and confirmed, its read-back matching")
        Set tStored = $ClassMethod(..#PROBE, "Stored", "USER", tAgentName)
        Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), $List(tForm, 3) _ "boolean", "it stores " _ $List(tForm, 3))
    }
}

/// <p>C2: a change on the form's Save with each form of <code>Enabled</code> the rules admit flips the flag the record
/// held, answers a matching read-back and stores the boolean the form reads as.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.DocDbAppRules.IsEnabled</method> refuse a number -- the
/// number legs go red.</p>
Method TestEveryEnabledFormChangesTheFlagOnTheFormsSave()
{
    Set tForms = $ListBuild($ListBuild("T", "true", 1), $ListBuild("F", "false", 0), $ListBuild("N1", "1", 1), $ListBuild("N0", "0", 0), $ListBuild("S1", """1""", 1), $ListBuild("S0", """0""", 0))
    For tI = 1:1:$ListLength(tForms) {
        Set tForm = $List(tForms, tI)
        Set tName = $ClassMethod(..#PROBE, "Name", "C" _ $List(tForm, 1))
        Set tSeed = {"Description": "flag", "Resource": ""}
        Do tSeed.%Set("Enabled", ($List(tForm, 3) = 0), "boolean")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", tName, tSeed), "a record holding the opposite flag")
        Set tEnabled = ##class(%DynamicObject).%FromJSON("{""Enabled"": " _ $List(tForm, 2) _ "}")
        Set tBody = {}
        Do tBody.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Do ..Change($ClassMethod(..#PROBE, "Id", "USER", tName), tBody, .tStatus, .tAnswer)
        Set tStored = $ClassMethod(..#PROBE, "Stored", "USER", tName)
        Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer) _ " " _ $Select($IsObject(tStored): tStored.%Get("Enabled") _ tStored.%GetTypeOf("Enabled"), 1: "-"), "200 matches " _ $List(tForm, 3) _ "boolean", "the form's change with Enabled " _ $List(tForm, 2) _ " reads back matching and stores " _ $List(tForm, 3))
    }
}

/// <p>C2: a change on both callers keeps every setting it does not send, applies the ones it does, answers the
/// read-back, and the record's name stays as stored although the id names it in another case; a change that changes
/// nothing sends nothing.</p>
/// <p>Mutation (Rule 19): drop <code>Resource</code> from the payload <method>OcuPilot.Screen.Tool.DocDbAppUpdate.MergeUpdate</method>
/// answers -- the agent's payload leg goes red.</p>
Method TestAChangeKeepsWhatItDoesNotSendOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "before", "Enabled": true, "Resource": "OcuProbe1830Res"}), "a probe record naming it")
    Set tId = $ClassMethod(..#PROBE, "Id", "user", "ocuprobe1830a")
    Do ..Change(tId, {"Description": "form"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form's change answers 200 although the id names the record in other case: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "USER", "OcuProbe1830A"), "form|1|OcuProbe1830Res", "the description changed, the other two settings as they were")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "Names")), "USER|OcuProbe1830A", "and the record keeps the name it was created with")
    Do ..Change(tId, {"Description": "form"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): +tAnswer.%IsDefined("readBack"), 1: "-"), "200 0", "a change that changes nothing is answered without a write")

    Set tArgs = {"Namespace": "user", "Name": "OcuProbe1830A", "Enabled": false}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1830A", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
    Do $$$AssertEquals(tPayload.%Get("Description") _ "|" _ tPayload.%Get("Enabled") _ "|" _ tPayload.%Get("Resource"), "form|0|OcuProbe1830Res", "its proposal carries the fresh read's three settings with the change applied")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "USER", "OcuProbe1830A"), "form|0|OcuProbe1830Res", "the flag changed, the description and the resource as they were")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1830A", {"Namespace": "user", "Name": "OcuProbe1830A", "Enabled": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an agent change that changes nothing is refused at the mint: " _ tProblem)
    Do ..Change(tId, {"Resource": ""}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830A", "Resource"), "200 ", "a change to an empty resource clears it")
}

/// <p>C2: a delete on both callers removes the record and reads back absent; a delete of a record the instance does not
/// hold is 404 <code>PORT.NOTFOUND</code> from the Delete and refused at the agent's mint.</p>
Method TestADeleteRemovesTheRecordOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A"), "a probe record")
    Do ..Remove($ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A"), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers 200: " _ ..Text(tAnswer))
    Do $$$AssertEquals(..Verdict(tAnswer), "notFound", "its read-back reads the record absent")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, "the record is gone")
    Do ..Remove($ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A"), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a record the instance does not hold is 404 PORT.NOTFOUND")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830B", {"Description": "agent", "Enabled": false, "Resource": ""}), "a second probe record")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuProbe1830B", {"Namespace": "user", "Name": "OcuProbe1830B"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "destructive") _ " " _ ##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "consequence"), "1 ", "destructive, stating no consequence")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "notFound", "its read-back reads the record absent")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, "the record is gone")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuProbe1830B", {"Namespace": "user", "Name": "OcuProbe1830B"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a delete of the absent record is refused at the mint: " _ tProblem)
}

/// <p>C4: every row of the create's rules is refused on its field before any <code>PUT</code>, by the form's Save as a
/// 422 <code>DOCDBAPP.VALIDATION</code> carrying the violation and by the agent's mint as its problem naming the field
/// and the published sentence, an empty name or namespace as 400 <code>TOOL.ARGUMENTS</code> at the mint; no record is
/// created.</p>
/// <p>Mutation (Rule 19): drop the <code>Description</code> length rule from
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Valid</method> -- its legs create the record and go red.</p>
Method TestEveryCreateRuleIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tErrors = ..#ERRORS
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tLongDescription = $Translate($Justify("", 257), " ", "d")
    Set tCases = ""
    Set tCases = tCases _ $ListBuild($ListBuild("name starts with a digit", "{""Name"": ""1Bad""}", "Name", $Parameter(tErrors, "NAME"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("name holds a space", "{""Name"": ""OcuProbe1830 Bad""}", "Name", $Parameter(tErrors, "NAME"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("name holds an empty part", "{""Name"": ""OcuProbe1830..Bad""}", "Name", $Parameter(tErrors, "NAME"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("name over 220", "{""Name"": ""OcuProbe1830" _ $Translate($Justify("", 220), " ", "n") _ """}", "Name", $Parameter(tErrors, "NAME"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("name empty", "{""Name"": """"}", "Name", $Parameter(tErrors, "NAME"), 1))
    Set tCases = tCases _ $ListBuild($ListBuild("namespace empty", "{""Namespace"": """"}", "Namespace", $Parameter(tErrors, "NAMESPACE"), 1))
    Set tCases = tCases _ $ListBuild($ListBuild("namespace not defined", "{""Namespace"": ""OCUNONS1830""}", "Namespace", $Parameter(tErrors, "NAMESPACE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("namespace holds a space", "{""Namespace"": ""bad ns""}", "Namespace", $Parameter(tErrors, "NAMESPACE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("description over 256", "{""Description"": """ _ tLongDescription _ """}", "Description", $Parameter(tErrors, "DESCRIPTION"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("description a number", "{""Description"": 5}", "Description", tShape, 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled yes", "{""Enabled"": ""yes""}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled the text true", "{""Enabled"": ""true""}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled 2", "{""Enabled"": 2}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled null", "{""Enabled"": null}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("enabled an object", "{""Enabled"": {}}", "Enabled", $Parameter(tErrors, "ENABLED"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource absent", "{""Resource"": ""OcuProbe1830NoSuchRes""}", "Resource", $Parameter(tErrors, "RESOURCE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource a database resource", "{""Resource"": ""%DB_IRISSYS""}", "Resource", $Parameter(tErrors, "RESOURCE"), 0))
    Set tCases = tCases _ $ListBuild($ListBuild("resource a number", "{""Resource"": 5}", "Resource", tShape, 0))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBody = {"Namespace": "user", "Name": "OcuProbe1830R", "Description": "rule", "Enabled": true, "Resource": ""}
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
        Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, $List(tCase, 1) _ ": and no record was created")
        Set tName = $Select(tBody.%GetTypeOf("Name") = "string": tBody.%Get("Name"), 1: "OcuProbe1830R")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tName, tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's mint is refused")
        Do $$$AssertEquals(tHttp, 400, $List(tCase, 1) _ ": as 400 TOOL.ARGUMENTS")
        If '$List(tCase, 5) Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 0, $List(tCase, 1) _ ": and the mint created no record")
    }
}

/// <p>C4: every row of the change's rules is refused on its field before any <code>PUT</code>, by the form's Save as a
/// 422 and by the agent's mint as its problem; the record is as it was. A resource that was not changed is never
/// judged: a record naming a resource the instance no longer holds still takes a change to its description.</p>
/// <p>Mutation (Rule 19): judge the resource of an update even when it is unchanged (the guard in
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Check</method> read as true) -- the stored-resource leg goes red.</p>
Method TestEveryChangeRuleIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tErrors = ..#ERRORS
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830U", {"Description": "keep", "Enabled": true, "Resource": ""}), "a probe record to change")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tCases = $ListBuild($ListBuild("description over 256", "{""Description"": """ _ $Translate($Justify("", 257), " ", "d") _ """}", "Description", $Parameter(tErrors, "DESCRIPTION")), $ListBuild("description a number", "{""Description"": 5}", "Description", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE), $ListBuild("enabled yes", "{""Enabled"": ""yes""}", "Enabled", $Parameter(tErrors, "ENABLED")), $ListBuild("enabled 2", "{""Enabled"": 2}", "Enabled", $Parameter(tErrors, "ENABLED")), $ListBuild("resource absent", "{""Resource"": ""OcuProbe1830NoSuchRes""}", "Resource", $Parameter(tErrors, "RESOURCE")), $ListBuild("resource a database resource", "{""Resource"": ""%DB_IRISSYS""}", "Resource", $Parameter(tErrors, "RESOURCE")), $ListBuild("resource a number", "{""Resource"": 5}", "Resource", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tChange = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do ..Change($ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830U"), tChange, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, $List(tCase, 3)), "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": a change is refused on its field: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, $List(tCase, 1) _ ": and nothing was written")
        Do tChange.%Set("Namespace", "user")
        Do tChange.%Set("Name", "OcuProbe1830U")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1830U", tChange, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's change is refused (" _ tProblem _ ")")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830V", {"Description": "keep", "Enabled": true, "Resource": "OcuProbe1830Res"}), "a record naming it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveResource"), "which the instance then no longer holds")
    Do ..Change($ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830V"), {"Description": "changed"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a change to the description is not refused for the resource it did not touch: " _ ..Text(tAnswer))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1830V", {"Namespace": "user", "Name": "OcuProbe1830V", "Description": "again"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "nor is the agent's (" _ tProblem _ ")")
}

/// <p>C2: a resource that is a service, system or application resource the instance lists -- each kind the classic Doc
/// DB page offers -- is accepted on both callers, and an empty one is.</p>
/// <p>Mutation (Rule 19): list only <code>Application</code> in <parameter>OcuPilot.Area.WebApp.DocDbAppRules.RESOURCETYPES</parameter>
/// -- the service and system legs go red.</p>
Method TestAListedServiceOrApplicationResourceIsAccepted()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureResource"), "a probe resource")
    Set tCases = $ListBuild($ListBuild("OcuProbe1830Svc", "%Service_DocDB"), $ListBuild("OcuProbe1830Sys", "%DocDB_Admin"), $ListBuild("OcuProbe1830App", "OcuProbe1830Res"))
    For tI = 1:1:$ListLength(tCases) {
        Set tName = $List($List(tCases, tI), 1)
        Set tResource = $List($List(tCases, tI), 2)
        Do ..Save({"Namespace": "user", "Name": (tName), "Resource": (tResource)}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "StoredField", "USER", tName, "Resource"), "201 " _ tResource, "the form's create naming " _ tResource)
        Set tAgentName = tName _ "X"
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tAgentName, {"Namespace": "user", "Name": (tAgentName), "Resource": (tResource)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's create naming " _ tResource _ " is minted (" _ tProblem _ ")")
    }
}

/// <p>C2: a name taken in any case is refused by the Save's own look-up and by the agent's mint; a name taken since the
/// mint is refused by the absence fingerprint at the confirm; a target moved since the mint refuses the confirm as
/// changed; and a target another write holds answers 409 <code>WRITE.TARGETBUSY</code> after the wait, with no
/// write.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Mint.AbsenceState</method> ignore its argument -- the
/// taken-since leg overwrites the record and goes red.</p>
Method TestATakenNameAMovedTargetAndABusyTargetAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "first", "Enabled": true, "Resource": ""}), "a probe record")
    Set tTaken = {"Namespace": "USER", "Name": "ocuprobe1830a", "Description": "second"}
    Do ..Save(tTaken, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "TAKEN"), "a create of a taken name in another case is refused on Name: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830A", "Description"), "first", "and the record is as it was")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "ocuprobe1830a", tTaken, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's create of it is refused at the mint: " _ tProblem)
    Set tFree = {"Namespace": "user", "Name": "OcuProbe1830B", "Description": "agent"}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1830B", tFree, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create of a free name is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "USER", "ocuprobe1830b", {"Description": "taken since", "Enabled": true, "Resource": ""}), "and the name is taken since, in another case")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused by the absence fingerprint")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830B", "Description"), "taken since", "and the record is as the other writer left it")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1830A", {"Namespace": "user", "Name": "OcuProbe1830A", "Description": "agent"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "user", "OcuProbe1830A", {"Description": "first", "Enabled": false, "Resource": ""}), "and a setting the payload carries moves")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830A", "Description"), "first", "and nothing was written")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("docdb-application", "instance", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A"), .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tRef)
    Do $$$AssertNotEquals(tLockKey, "", "the record names a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/docdb-application/" _ $ClassMethod(..#PROBE, "PathId", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830A")), .tStatus, .tBusy, {"Description": "busy"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code") _ " " _ tBusy.%Get("reason"), 1: tBusy), "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held Save is refused busy, with the published reason")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830A", "Description"), "first", "and nothing was written")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("docdb-application", "instance", $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830C"), .tFreeRef)
    Set tFreeKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tFreeRef)
    Lock +^OcuPilotProposalTarget(tFreeKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "a free name's lock, held as another create's hold is")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/docdb-application", .tStatus, .tBusy, {"Namespace": "user", "Name": "OcuProbe1830C"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tFreeKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code"), 1: tBusy), "409 WRITE.TARGETBUSY", "a create of a held name is refused busy")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "USER", "OcuProbe1830C")), 0, "and nothing was created")
}

/// <p>The write routes answer over the wire as JSON: <code>POST /docdb-application</code> creates a probe record with 201
/// and <code>PUT /docdb-application/:id</code> changes it with 200, each answering the id, the namespace, the name and
/// the read-back; a body key outside the settings is 400 <code>PORT.FIELD.UNEXPECTED</code> before anything is read; a
/// record the instance does not hold, and an id that is not two parts, are 404 <code>PORT.NOTFOUND</code>; a body that
/// is not an object is 400.</p>
Method TestTheWriteRoutesAnswerOverTheWire()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/docdb-application", .tStatus, .tAnswer, {"Namespace": "user", "Name": "OcuProbe1830W", "Description": "wire"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST /docdb-application answers 201")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("namespace") _ "|" _ tAnswer.%Get("name") _ "|" _ ..Verdict(tAnswer), 1: ""), "USER|OcuProbe1830W|matches", "with the namespace as stored, the name as written and the read-back")
    Set tId = $ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830W")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/docdb-application/" _ $ClassMethod(..#PROBE, "PathId", tId), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tChangeStatus, .tChangeRaw, .tHeaders, {"Description": "wire changed"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tChangeStatus, 200, "PUT /docdb-application/:id answers 200: " _ $Extract(tChangeRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Verdict(##class(%DynamicObject).%FromJSON(tChangeRaw)), "matches", "with its read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "USER", "OcuProbe1830W", "Description"), "wire changed", "and the instance holds the change")
    Do ..Change(tId, {"Name": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "a body naming Name is refused before anything is read")
    Do ..Save({"Namespace": "user", "Name": "OcuProbe1830W", "Service": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "and so is a create's body naming a key the tool does not admit")
    Do ..Change($ClassMethod(..#PROBE, "Id", "USER", "OcuProbe1830Z"), {"Description": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a record the instance does not hold is 404")
    Do ..Change("OcuProbe1830W", {"Description": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "so is an id that is not two parts")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/docdb-application", .tStatus, .tAnswer, "[1]", "application/json")
    Do $$$AssertEquals(tStatus, 400, "a body that is not an object is 400")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "Names")), 1, "and one probe record exists")
}

/// <p>The create with every field omitted but the id's two parts stores the instance's defaults: enabled, no
/// description and no resource, on both callers. The agent's card shows no change row for a setting the caller did not
/// send and counts the three unchanged (AD-54).</p>
/// <p>Mutation (Rule 19): complete the body in <method>OcuPilot.Area.WebApp.DocDbAppRules.CreateBody</method>, before
/// the kernel composes it, in place of <method>OcuPilot.Area.WebApp.DocDbAppRules.CompleteBody</method> after -- the
/// card leg goes red.</p>
Method TestACreateOfTheTwoPartsAloneTakesTheInstancesDefaults()
{
    Do ..Save({"Namespace": "user", "Name": "OcuProbe1830D"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer) _ " " _ $ClassMethod(..#PROBE, "Summary", "USER", "OcuProbe1830D"), "201 matches |1|", "the form's create stores the defaults: " _ ..Text(tAnswer))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuProbe1830E", {"Namespace": "user", "Name": "OcuProbe1830E"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload), "Description,Enabled,Resource", "its proposal carries all three settings, the omitted ones at the instance's defaults")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteDetail).Fields(tProposal) _ "|" _ $Select($IsObject(tProposal): tProposal.%Get("unchangedCount"), 1: ""), "|3", "its card shows no change row for a setting the caller did not send, and counts the three unchanged")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Summary", "USER", "OcuProbe1830E"), "|1|", "the agent's stores the same")
}

/// <p><code>POST /docdb-application</code> with <var>pBody</var>: the status and the parsed answer.</p>
Method Save(pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/docdb-application", .pStatus, .pAnswer, pBody.%ToJSON(), "application/json")
}

/// <p><code>PUT /docdb-application/:id</code> for the composite id <var>pId</var> with <var>pBody</var>.</p>
Method Change(pId As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/docdb-application/" _ $ClassMethod(..#PROBE, "PathId", pId), .pStatus, .pAnswer, pBody.%ToJSON(), "application/json")
}

/// <p>The list's Delete action for the composite id <var>pId</var>.</p>
Method Remove(pId As %String, Output pStatus As %Integer, Output pAnswer)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ ..#SCREEN _ "/action", .pStatus, .pAnswer, {"action": "delete", "id": (pId)}.%ToJSON(), "application/json")
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
