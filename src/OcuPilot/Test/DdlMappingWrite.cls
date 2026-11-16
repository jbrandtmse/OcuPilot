/// <p>Pins Story 21.13's writes on both callers (AC1, AC2, AC3, AC4; AD-4, AD-6, AD-15, AD-53, AD-54, AD-55, AD-58) against the real instance: a user DDL
/// mapping created, changed and deleted by the screen (the Save route, and the screen's own action route
/// <class>OcuPilot.Test.EcpActionFixture</class>) and by the agent's mint and confirm (<class>OcuPilot.Test.LicenseProbe</class>); a system DDL mapping
/// changed and deleted by both and restored; a refused write that changes nothing; and the agent's confirm that writes once with one audit marker, a
/// delete refused by governance until its key is enabled.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// the class creates, changes and deletes DDL mappings and sets the governance policy. Every mapping it creates is named <code>ZZOCU</code> and the job
/// number; every system mapping it changes or deletes is put back by name through the vendor's own <code>Modify</code> and <code>Create</code>, on every
/// path, and both lists are read before and after each test.</p>
Class OcuPilot.Test.DdlMappingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter WRITE = "OcuPilot.Test.ConfigSettingWrite";

Parameter READ = "OcuPilot.Test.DdlMappingRead";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SAVE = "OcuPilot.Area.OsMgmt.DdlMappingSave";

Parameter SYSTEMSCREEN = "osmgmt.systemddlmappings";

Parameter USERSCREEN = "osmgmt.userddlmappings";

Parameter SYSTEMCLASS = "Config.SqlSysDatatypes";

Parameter USERCLASS = "Config.SqlUserDatatypes";

/// <p>The datatypes the marker mappings take: the first is a create's, the second a set's.</p>
Parameter FIRSTTYPE = "%Library.String(MAXLEN=%1)";

Parameter SECONDTYPE = "%Library.Integer";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>Both lists as the test found them, as <code>{class: {name: datatype}}</code> JSON.</p>
Property PreparedEntries As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DdlMappingWrite creates, changes and deletes this instance's DDL mappings and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped config port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tEntries = ..Entries()
    If (tEntries.%GetTypeOf(..#SYSTEMCLASS) '= "object") || (tEntries.%GetTypeOf(..#USERCLASS) '= "object") Quit $$$ERROR($$$GeneralError, "could not read both DDL mapping lists, so no test changes a mapping it could not put back")
    Set ..PreparedEntries = tEntries.%ToJSON()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do $$$AssertStatusOK(..Restore(##class(%DynamicObject).%FromJSON(..PreparedEntries)), "every mapping the test created, changed or deleted is put back")
    Do $$$AssertEquals(..Entries().%ToJSON(), ..PreparedEntries, "and both lists read as before the test")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Both lists as <code>{class: {name: datatype}}</code>, read through the vendor's own <code>List</code> query in <code>%SYS</code>.</p>
ClassMethod Entries() As %DynamicObject
{
    Set tAll = {}
    For tClass = ..#SYSTEMCLASS, ..#USERCLASS {
        Set tCount = $ClassMethod(..#READ, "VendorEntries", tClass, .tEntries)
        If tCount < 0 Continue
        Set tObject = {}
        Set tName = ""
        For {
            Set tName = $Order(tEntries(tName))
            If tName = "" Quit
            Do tObject.%Set(tName, tEntries(tName), "string")
        }
        Do tAll.%Set(tClass, tObject)
    }
    Quit tAll
}

/// <p>Put both lists back to <var>pPrepared</var> through the vendor's own calls, in <code>%SYS</code>: an entry the test deleted is created, one it
/// changed is modified, and a user mapping it left behind is deleted. The first failure is answered; every entry is tried.</p>
ClassMethod Restore(pPrepared As %DynamicObject) As %Status
{
    Set tFirst = $$$OK
    Set tOrigNS = $NAMESPACE
    For tClass = ..#SYSTEMCLASS, ..#USERCLASS {
        Set tWanted = pPrepared.%Get(tClass)
        Set tNow = ..Entries().%Get(tClass)
        Try {
            Set $NAMESPACE = "%SYS"
            Set tIterator = tNow.%GetIterator()
            While tIterator.%GetNext(.tName, .tValue) {
                If tWanted.%GetTypeOf(tName) = "unassigned" {
                    Set tSC = $ClassMethod(tClass, "Delete", tName)
                    If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
                }
            }
            Set tIterator = tWanted.%GetIterator()
            While tIterator.%GetNext(.tName, .tValue) {
                Kill tProps
                Set tProps("Datatype") = tValue
                If tNow.%GetTypeOf(tName) = "unassigned" {
                    Set tSC = $ClassMethod(tClass, "Create", tName, .tProps)
                } ElseIf tNow.%Get(tName) '= tValue {
                    Set tSC = $ClassMethod(tClass, "Modify", tName, .tProps)
                } Else {
                    Continue
                }
                If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
            }
        } Catch ex {
            If $$$ISOK(tFirst) Set tFirst = ex.AsStatus()
        }
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    }
    Quit tFirst
}

/// <p>The entries of <var>pClass</var> as the instance holds them now, without <var>pName</var>, as JSON, so what a write did not touch can be compared.</p>
ClassMethod Without(pClass As %String, pName As %String) As %String
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(..Entries().%Get(pClass).%ToJSON())
    If tCopy.%GetTypeOf(pName) '= "unassigned" Do tCopy.%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p>The datatype of <var>pName</var> on <var>pEndpoint</var> through the port, or <code>(404)</code> style text when it reads absent.</p>
ClassMethod TypeOf(pEndpoint As %String, pName As %String) As %String
{
    Quit $ClassMethod(..#WRITE, "ValueOf", pEndpoint, pName)
}

/// <p>The screen action <code>delete</code> on <var>pName</var> of screen <var>pScreen</var>, through the action fixture; the parsed envelope in
/// <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod ActDelete(pScreen As %String, pName As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", pName, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with the datatype <var>pType</var> (none for a delete) and confirm it, answering <code>http code</code>
/// and the confirm's answer in <var>pResult</var>, or <code>refused: &lt;problem&gt;</code> when the mint refused; the proposal is in <var>pProposal</var>.</p>
ClassMethod Agent(pTool As %String, pName As %String, pType As %String, Output pResult As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    If pType '= "" Do tArgs.%Set("Value", pType, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, tArgs, .pProposal, .tHttp, .tProblem)
    If '$IsObject($Get(pProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The Save route's create of the user mapping <var>pName</var> with the datatype <var>pType</var>, as the dialog's Save sends it; answers the read-back
/// verdict, or <code>http code</code> of the refusal, with the violations as <code>field:code</code> in <var>pViolations</var>.</p>
ClassMethod Save(pName As %String, pType As %String, Output pViolations As %String) As %String
{
    Set tSC = $ClassMethod(..#SAVE, "Create", "", pName, {"Value": (pType)}, .tHttp, .tFault, .tViolations, .tReadBack)
    Set pViolations = ""
    For tI = 1:1:+$Get(tViolations) Set pViolations = pViolations _ $Select(pViolations = "": "", 1: ",") _ $List(tViolations(tI), 1) _ ":" _ $List(tViolations(tI), 2)
    If +$Get(tViolations) > 0 Quit "violations"
    If $$$ISERR(tSC) Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: "(none)")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal's id in <var>pProposalId</var> and the turn's key
/// in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Quit $ClassMethod(..#WRITE, "Dispatched", pKey, pInput, .pProposalId, .pTurnKey)
}

/// <p>Store the two delete keys enabled, so the agent's confirm of a delete is not refused by governance; the teardown restores the policy.</p>
ClassMethod EnableDeletes() As %Status
{
    Kill tSettings
    Set tSettings("osmgmt.userddlmappings.delete") = "enabled"
    Set tSettings("osmgmt.systemddlmappings.delete") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>A marker name for this job: <code>ZZOCU</code>, the job number and <var>pSuffix</var>.</p>
ClassMethod Marker(pSuffix As %String = "") As %String
{
    Quit "ZZOCU" _ $Job _ pSuffix
}

/// <p><b>AC1.</b> A user mapping is created, its datatype set and it is deleted, each by both callers: the screen's Save route and its set and delete
/// actions, and the agent's confirmed proposals. Each round-trips over <code>Config.SqlUserDatatypes</code>: the row reads what was sent, the read-back
/// matches (and reads the entry gone after a delete), and every other user mapping reads as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>ModifyEntry</code> sends the fresh read's datatype instead of the new one ->
/// the set assertions go red.</p>
Method TestAUserMappingIsCreatedChangedAndDeletedByBothCallers()
{
    Set tScreenName = ..Marker("S")
    Set tAgentName = ..Marker("A")
    Set tBefore = ..Entries()
    Do $$$AssertEquals(..Save(tScreenName, ..#FIRSTTYPE, .tViolations) _ "|" _ tViolations, "matches|", "the Save route creates the mapping and its read-back matches")
    Do $$$AssertEquals(..TypeOf("UserDDL", tScreenName), ..#FIRSTTYPE, "which reads what was sent")
    Do $$$AssertEquals(..Without(..#USERCLASS, tScreenName), tBefore.%Get(..#USERCLASS).%ToJSON(), "and every other user mapping reads as before")
    Do ##class(OcuPilot.Test.ConfigSettingRead).RowsByName(##class(OcuPilot.Test.ConfigSettingRead).Read("DdlUserMappingList"), .tRows)
    Do $$$AssertEquals($Select($IsObject($Get(tRows(tScreenName))): tRows(tScreenName).%Get("Value"), 1: "(absent)"), ..#FIRSTTYPE, "and the user list's own read answers its row with the datatype sent")
    Set tStatus = $ClassMethod(..#WRITE, "Act", ..#USERSCREEN, tScreenName, ..#SECONDTYPE, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..TypeOf("UserDDL", tScreenName), "200|matches|" _ ..#SECONDTYPE, "the screen's Set value changes the datatype and reads it back")
    Do $$$AssertEquals(..Without(..#USERCLASS, tScreenName), tBefore.%Get(..#USERCLASS).%ToJSON(), "and every other user mapping reads as before")
    Set tStatus = ..ActDelete(..#USERSCREEN, tScreenName, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..Entries().%Get(..#USERCLASS).%GetTypeOf(tScreenName), "200|notFound|unassigned", "the screen's Delete removes it and reads it gone")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingCreate", tAgentName, ..#FIRSTTYPE, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..TypeOf("UserDDL", tAgentName), "200 |matches|" _ ..#FIRSTTYPE, "the agent's confirmed create makes it, read back matching: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "", "and its card states no consequence")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingSet", tAgentName, ..#SECONDTYPE, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..TypeOf("UserDDL", tAgentName), "200 |matches|" _ ..#SECONDTYPE, "the agent's confirmed set changes it: " _ tOutcome)
    Do $$$AssertEquals(..Without(..#USERCLASS, tAgentName), tBefore.%Get(..#USERCLASS).%ToJSON(), "and every other user mapping reads as before")
    Do $$$AssertStatusOK(..EnableDeletes(), "the delete keys are stored enabled, which the confirm asks")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingDelete", tAgentName, "", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..Entries().%Get(..#USERCLASS).%GetTypeOf(tAgentName), "200 |notFound|unassigned", "the agent's confirmed delete removes it, read back gone: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "CONFIG.MAPPING.DELETE", "and its card states the delete consequence")
    Do $$$AssertEquals(..Entries().%ToJSON(), tBefore.%ToJSON(), "both lists read as they did before the test")
}

/// <p><b>AC2.</b> A system mapping's datatype is set and the mapping is deleted, each by both callers, over <code>Config.SqlSysDatatypes</code>, and each
/// is restored: the screen's and the agent's set round-trip with the read-back matching and every other system mapping unchanged, the screen's and the
/// agent's deletes read the entry gone with the count one lower, and the vendor's own <code>Create</code> brings it back with the datatype it held. No
/// surface, tool or request type creates a system mapping.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Serves</code> admits <code>CREATE</code> on <code>SystemDDL</code> -> the
/// no-create assertion and <class>OcuPilot.Test.DdlMappingRead</class>'s roster go red.</p>
Method TestASystemMappingIsChangedAndDeletedByBothCallersAndRestored()
{
    Set tBefore = ..Entries()
    Set tSystem = tBefore.%Get(..#SYSTEMCLASS)
    Set tIterator = tSystem.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
    }
    Set tHeld = tName
    Set tHeldType = tSystem.%Get(tHeld)
    Set tCount = ..Count(..#SYSTEMCLASS)
    Set tStatus = $ClassMethod(..#WRITE, "Act", ..#SYSTEMSCREEN, tHeld, ..#SECONDTYPE, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..TypeOf("SystemDDL", tHeld), "200|matches|" _ ..#SECONDTYPE, "the screen's Set value changes a system mapping's datatype and reads it back")
    Do $$$AssertEquals(..Without(..#SYSTEMCLASS, tHeld), ..WithoutOf(tBefore, ..#SYSTEMCLASS, tHeld), "and every other system mapping reads as before")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlSystemMappingSet", tHeld, tHeldType, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..TypeOf("SystemDDL", tHeld), "200 |" _ tHeldType, "the agent's confirmed set puts it back: " _ tOutcome)
    Set tStatus = ..ActDelete(..#SYSTEMSCREEN, tHeld, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..Count(..#SYSTEMCLASS), "200|notFound|" _ (tCount - 1), "the screen's Delete removes it, reads it gone and the count is one lower")
    Do $$$AssertStatusOK(..Restore(tBefore), "the vendor's Create brings it back")
    Do $$$AssertEquals(..TypeOf("SystemDDL", tHeld) _ "|" _ ..Count(..#SYSTEMCLASS), tHeldType _ "|" _ tCount, "with the datatype it held and the count it had")
    Do $$$AssertStatusOK(..EnableDeletes(), "the delete keys are stored enabled, which the confirm asks")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlSystemMappingDelete", tHeld, "", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..Count(..#SYSTEMCLASS), "200 |notFound|" _ (tCount - 1), "the agent's confirmed delete does the same: " _ tOutcome)
    Do $$$AssertStatusOK(..Restore(tBefore), "and the vendor's Create brings it back again")
    Do $$$AssertEquals(..Entries().%ToJSON(), tBefore.%ToJSON(), "both lists read as they did before the test")
    Kill tQuery
    Set tQuery("name") = ..Marker("N")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemDDL", "CREATE", .tQuery, {"Value": "%Library.String"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ ..Entries().%Get(..#SYSTEMCLASS).%GetTypeOf(tQuery("name")), "501|PORT.NOTIMPLEMENTED|unassigned", "the port creates no system mapping")
    Set tStatus = $ClassMethod(..#ACTION, "Act", ..#SYSTEMSCREEN, {"action": "create", "id": "x"}, .tJson, .tActStatus)
    Do $$$AssertTrue(tActStatus >= 400, "the system screen has no create action: " _ tActStatus)
    Set tTools = ""
    Do ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tList)
    Set tListIterator = tList.%GetIterator()
    While tListIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("name") [ "systemddlmappings" Set tTools = tTools _ $Select(tTools = "": "", 1: ",") _ tEntry.%Get("name")
    }
    Do $$$AssertTrue(tTools '[ "create", "no tool creates a system mapping: " _ tTools)
}

/// <p>How many entries <var>pClass</var> holds now.</p>
ClassMethod Count(pClass As %String) As %Integer
{
    Set tCount = 0
    Set tIterator = ..Entries().%Get(pClass).%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The JSON of <var>pAll</var>'s <var>pClass</var> entries without <var>pName</var>.</p>
ClassMethod WithoutOf(pAll As %DynamicObject, pClass As %String, pName As %String) As %String
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pAll.%Get(pClass).%ToJSON())
    If tCopy.%GetTypeOf(pName) '= "unassigned" Do tCopy.%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p><b>AC3.</b> A refused write changes nothing on either caller: at the screen's route an absent mapping is 404 <code>CONFIG.SETTING.NOTFOUND</code>
/// for a set and for a delete and a datatype that is not a class is 400 <code>CONFIG.SETTING.VALUE</code>; the Save route refuses a held name 409
/// <code>CONFIG.MAPPING.TAKEN</code> and a name or a datatype the rules refuse on its field; and the mint refuses each with its sentence. Both lists
/// read as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s <code>NameCode</code> admits <code>*</code> -> the name row goes red,
/// with a mapping created under a name no screen could name again.</p>
Method TestARefusedWriteChangesNothingOnEitherCaller()
{
    Set tBefore = ..Entries().%ToJSON()
    Set tName = ..Marker("R")
    Do $$$AssertEquals(..Save(tName, ..#FIRSTTYPE, .tViolations), "matches", "a mapping to hold")
    Set tStatus = $ClassMethod(..#WRITE, "Act", ..#USERSCREEN, ..Marker("X"), ..#SECONDTYPE, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "Code", tAnswer), "404|CONFIG.SETTING.NOTFOUND", "a set of an absent mapping is refused at the screen")
    Set tStatus = $ClassMethod(..#WRITE, "Act", ..#USERSCREEN, tName, "not a class", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "Code", tAnswer), "400|CONFIG.SETTING.VALUE", "a datatype that is not a class is refused at the screen")
    Set tStatus = ..ActDelete(..#USERSCREEN, ..Marker("X"), .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#WRITE, "Code", tAnswer), "404|CONFIG.SETTING.NOTFOUND", "a delete of an absent mapping is refused at the screen")
    Do $$$AssertEquals(..Save(tName, ..#SECONDTYPE, .tViolations), "409 CONFIG.MAPPING.TAKEN", "the Save refuses a held name")
    Do $$$AssertEquals(..TypeOf("UserDDL", tName), ..#FIRSTTYPE, "and leaves the held mapping as it was")
    Do $$$AssertEquals(..Save("ZZ*" _ ..Marker("Q"), ..#FIRSTTYPE, .tViolations) _ "|" _ tViolations, "violations|Name:CONFIG.MAPPING.NAME", "the Save refuses a name the rules refuse, on its field")
    Do $$$AssertEquals(..Save(..Marker("Q"), "x y", .tViolations) _ "|" _ tViolations, "violations|Value:CONFIG.SETTING.VALUE", "and a datatype the rules refuse, on its field")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingCreate", tName, ..#SECONDTYPE, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: " _ $Parameter("OcuPilot.Api.ConfigError", "MAPPINGTAKEN"), "the agent's create of a held name is refused at the mint on the taken-name code, whose published sentence the codes test pins: " _ tOutcome)
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingCreate", ..Marker("Q"), "not a class", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: " _ $Parameter("OcuPilot.Api.ConfigError", "REASONSETTINGVALUE"), "and a datatype that is not a class")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.DdlUserMappingDelete", ..Marker("X"), "", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: '" _ ..Marker("X") _ "' is not present on this instance", "and a delete of an absent mapping, on the mint's own sentence")
    Do ..Restore(##class(%DynamicObject).%FromJSON(tBefore))
    Do $$$AssertEquals(..Entries().%ToJSON(), tBefore, "both lists read as before")
}

/// <p><b>AC4.</b> With the keys the baseline enables, the agent's call for a create is dispatched, mints a proposal, and its confirm creates the mapping
/// once, with a read-back and one write-kind ledger row carrying the audit marker; the token is spent, so a second confirm is refused. A delete is refused
/// at dispatch while its key ships off, and with its key stored enabled it mints a destructive proposal that carries the delete consequence and confirms
/// once. A person's actions are not governed (AD-22).</p>
/// <p>Mutation (Rule 19): <code>osmgmt.userddlmappings.delete</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// refusal assertion goes red.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarker()
{
    Set tName = ..Marker("G")
    Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", ..#FIRSTTYPE, "string")
    Do $$$AssertEquals(..Dispatched("osmgmt.userddlmappings.create", tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the create mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..TypeOf("UserDDL", tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ ..#FIRSTTYPE _ "|matches", "its confirm creates the mapping, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..TypeOf("UserDDL", tName), "1|" _ ..#FIRSTTYPE, "a second confirm of the same proposal is refused and changes nothing more")
    Set tSet = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tSet.%Set("Value", ..#SECONDTYPE, "string")
    Do $$$AssertEquals(..Dispatched("osmgmt.userddlmappings.set", tSet, .tSetId, .tSetTurn) _ "|" _ (tSetId '= ""), "minted|1", "the baseline lets the set mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tSetId, "", $Username, .tSetResult, .tSetHttp, .tSetCode, .tSetDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ ..TypeOf("UserDDL", tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tSetResult), "1|" _ ..#SECONDTYPE _ "|matches", "its confirm changes the datatype, with a read-back: " _ $Get(tSetCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tSetTurn, .tSetRow) _ "|" _ $Get(tSetRow("AuditMarked")), "1|" _ $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "with one audit marker of its own")
    Set tDelete = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals(..Dispatched("osmgmt.userddlmappings.delete", tDelete, .tNoneId, .tNoneTurn), "refused", "a delete is refused at dispatch while its key ships off")
    Kill tSettings
    Set tSettings("osmgmt.userddlmappings.delete") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the delete key is stored enabled")
    Do $$$AssertEquals(..Dispatched("osmgmt.userddlmappings.delete", tDelete, .tDeleteId, .tDeleteTurn) _ "|" _ (tDeleteId '= ""), "minted|1", "and the same call mints")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tDeleteId, .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "1|CONFIG.MAPPING.DELETE", "as a destructive proposal that carries the delete consequence")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tDeleteId, "", $Username, .tResult3, .tHttp3, .tCode3, .tDetail3)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult3) _ "|" _ ..Entries().%Get(..#USERCLASS).%GetTypeOf(tName), "1|notFound|unassigned", "its confirm deletes the mapping once, read back gone: " _ $Get(tCode3))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tDeleteTurn, .tDeleteRow), 1, "with one audit marker of its own")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    Set tPerson = ..Save(..Marker("H"), ..#FIRSTTYPE, .tViolations)
    Do $$$AssertEquals(tPerson, "matches", "while a person's Save is not governed and still creates")
}

/// <p><b>AC3, AC4.</b> A create minted for a free name and confirmed after another caller took the name is refused 409
/// <code>PROPOSAL.TARGETCHANGED</code> and changes nothing: the mapping keeps the datatype the other caller gave it.</p>
/// <p>Mutation (Rule 19): <code>DdlUserMappingCreate</code> declares no <code>PRECONDITIONCODES</code> -> the status assertion goes red, the confirm
/// answering a fault in its place.</p>
Method TestACreateConfirmedAfterTheNameWasTakenIsRefusedAsAChangedTarget()
{
    Set tName = ..Marker("T")
    Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", ..#FIRSTTYPE, "string")
    Do $$$AssertEquals(..Dispatched("osmgmt.userddlmappings.create", tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the create of a free name mints")
    Do $$$AssertEquals(..Save(tName, ..#SECONDTYPE, .tViolations), "matches", "the name is then taken by a person's Save")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as a target that changed")
    Do $$$AssertEquals(..TypeOf("UserDDL", tName), ..#SECONDTYPE, "and the mapping keeps the datatype the person gave it")
}

/// <p><b>AC1, AC3.</b> The Save route answers JSON over the wire: 201 with the mapping's id, its target and a matching read-back, a held name 409 with the
/// envelope's code and sentence, and a name the rules refuse 422 with the violation on its field.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.DdlMappingSave.HandleCreate</method> (inherited) answer 200 -- the status leg goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tName = ..Marker("W")
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/config/ddl-mappings"
    Set tBody = {"Name": (tName), "Value": (..#FIRSTTYPE)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.readBack.verdict, tName _ "|user-ddl-mapping|instance|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the mapping's id, its target and a matching read-back")
    Do $$$AssertEquals(..TypeOf("UserDDL", tName), ..#FIRSTTYPE, "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 409, "a held name is refused 409: " _ $Extract($Get(tRaw), 1, 300))
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tRefusal.code _ "|" _ tRefusal.reason, "CONFIG.MAPPING.TAKEN|" _ $Parameter("OcuPilot.Api.ConfigError", "REASONMAPPINGTAKEN"), "with the envelope's code and its published sentence")
    Set tBad = {"Name": "ZZ*OCU", "Value": (..#FIRSTTYPE)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBad.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a name the rules refuse is 422: " _ $Extract($Get(tRaw), 1, 300))
    Set tViolation = ##class(%DynamicObject).%FromJSON(tRaw).detail.violations.%Get(0)
    Do $$$AssertEquals(tViolation.field _ "|" _ tViolation.code, "Name|CONFIG.MAPPING.NAME", "with the violation on the Name field")
}

}
