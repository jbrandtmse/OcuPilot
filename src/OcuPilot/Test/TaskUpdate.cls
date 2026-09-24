/// <p>Pins Story 9.8's agent tool <class>OcuPilot.Screen.Tool.TaskUpdate</class> (AD-3, AD-4, AD-6,
/// AD-10, AD-35): its schema; the mint's diff rows, each setting as <code>Settings.&lt;key&gt;</code>;
/// a confirm after the task ran; every field the edit did not name surviving the confirm; running as
/// another account judged on a change; and a task type holding a secret setting.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the test process holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates, edits and runs probe tasks (<class>OcuPilot.Test.TaskEditProbe</class>), each removed by
/// id after its exact name is read back. <method>OnBeforeAllTests</method> refuses anywhere it does
/// not.</p>
Class OcuPilot.Test.TaskUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter PROBE = "OcuPilot.Test.TaskEditProbe";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The secret the secret-bearing probe holds, compared in process and never written out.</p>
Parameter PROBESECRET = "ocup98-not-a-real-secret";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskUpdate creates, edits and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AD-3: the schema advertises the task's id, required, and the thirty-two fields an edit may set,
/// each a derived template key carrying an authored description; <code>TaskClass</code>,
/// <code>NameSpace</code> and <code>OutputDirectory</code> are never advertised; and the settable set
/// is the prohibited set's reviewed change list (AD-10).</p>
Method TestTheSchemaIsDerivedAndDescribed()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Id""]", "the task's id alone is required")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"Id": "1", "Description": "x", "Settings": {"KeepDays": "3"}}, .tProblem)
    Do $$$AssertEquals(tProblem, "", "the schema is inside the subset a provider is sent")
    Set tTemplate = ##class(OcuPilot.Test.TaskCreate).TemplateKeys()
    Set tGeneric = $ListBuild("The new value for this field. Omit it to leave the field as the instance holds it.", "The new value for this field, replacing the whole list.")
    Set tNames = ""
    Set tIterator = tSchema.%Get("properties").%GetIterator()
    While tIterator.%GetNext(.tKey, .tProperty) {
        If $ListFind($ListBuild("rationale", "expectedImpact", "reverse", "Id"), tKey) Continue
        Set tNames = tNames _ $ListBuild(tKey)
        Do $$$AssertTrue($ListFind(tTemplate, tKey) > 0, tKey _ " is a derived template key")
        Set tDescription = tProperty.%Get("description")
        Do $$$AssertTrue((tDescription '= "") && '$ListFind(tGeneric, tDescription), tKey _ " carries an authored description")
    }
    Do $$$AssertEquals($ListLength(tNames), 32, "thirty-two fields are advertised")
    For tField = "TaskClass", "NameSpace", "OutputDirectory" {
        Do $$$AssertEquals($ListFind(tNames, tField), 0, tField _ " is not")
    }
    Set tChange = $ClassMethod(..#SET, "PermittedChangeFields", "task")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskCreate).Sorted(tNames), ##class(OcuPilot.Test.TaskCreate).Sorted(tChange), "exactly the prohibited set's reviewed change list")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskCreate).Sorted($ClassMethod(..#TOOL, "SettableFields")), ##class(OcuPilot.Test.TaskCreate).Sorted(tChange), "which is what the tool may set")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "PortClass") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "GET PUT OcuPilot.Port.TaskPort updated", "a merge write over the task port")
}

/// <p>AD-4, AD-6: the mint is keyed <code>task:instance:&lt;id&gt;</code> and answers one row per
/// field the arguments change -- a setting as <code>Settings.&lt;key&gt;</code> -- while a time the
/// task holds, sent in the other spelling, is no row; the stored payload is the fresh read with the
/// change merged over it; and arguments that change nothing refuse the mint.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.TaskUpdate.MergeUpdate</method> set a
/// supplied <code>Settings</code> wholesale under one <code>Settings</code> row -- the rows leg goes
/// red.</p>
Method TestTheMintAnswersOneRowPerChange()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Mint"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    ; The instance spells the held time 01:00:00; the agent sends 01:00, which is no change.
    Set tSC = ..Mint({"Id": (tId), "Description": "changed", "DailyStartTime": "01:00", "Settings": {"KeepDays": "45"}}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ ##class(OcuPilot.Test.TaskCreate).Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Set tTarget = tProposal.%Get("target")
    Do $$$AssertEquals(tTarget.%Get("type") _ ":" _ tTarget.%Get("scope") _ ":" _ tTarget.%Get("id"), "task:instance:" _ tId, "the target is the task's id")
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Description"",""before"":""OcuPilot edit probe"",""after"":""changed""},{""field"":""Settings.KeepDays"",""before"":""30"",""after"":""45""}]", "one row per change, the setting named, the held time none")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload"), "{}"))
    Do $$$AssertEquals(tPayload.%Get("Settings").%ToJSON(), "{""KeepDays"":""45""}", "the payload's settings are the task's own with the change merged")
    Do $$$AssertEquals(tPayload.%Get("Priority") _ " " _ tPayload.%Get("OutputFilename"), "Low ocup98edit.txt", "and every other field is the fresh read's")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), ##class(OcuPilot.Test.TaskCreate).Count(tPayload) - 2, "the two changes aside, every key is sent unchanged")
    Set tSC = ..Mint({"Id": (tId), "Description": "OcuPilot edit probe"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "arguments that change nothing refuse the mint")
    Set tSC = ..Mint({"Id": (tId), "Settings": {"Nope": "1"}}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a setting the type does not declare refuses the mint")
    Do $$$AssertTrue(##class(OcuPilot.Test.TaskCreate).Problem(.tFault) [ ("'Settings.Nope': " _ ##class(OcuPilot.Api.Error).#REASONTASKSETTINGUNKNOWN), "by name: " _ ##class(OcuPilot.Test.TaskCreate).Problem(.tFault))
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>AC3: a proposal minted before the task runs still confirms once the run has moved
/// <code>NextScheduled</code>, because the tool's fresh read does not carry it (measured) and so the
/// fingerprint cannot; a field somebody else changed after the mint still refuses the confirm.</p>
/// <p>Mutation (Rule 19): set <code>INFO</code>'s <code>NextScheduled</code> on
/// <class>OcuPilot.Port.TaskPort</class>'s <code>GET</code> answer -- the run moves the digest and the
/// first confirm goes red.</p>
Method TestAConfirmAfterTheTaskRanWrites()
{
    Set tArgs = {"Name": "OcuP98Ran", "TaskClass": "%SYS.Task.RunLegacyTask", "NameSpace": "%SYS", "Settings": {"ExecuteCode": "Quit"}, "TimePeriod": "Daily", "TimePeriodEvery": "1", "DailyFrequency": "Once", "DailyStartTime": "03:00", "StartDate": ($ZDate(+$Horolog + 2, 3))}
    Set tSC = $ClassMethod(..#PROBE, "Create", tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint({"Id": (tId), "Description": "ran since the mint"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted")
    If $$$ISERR(tSC) Quit
    Set tBefore = $ClassMethod(..#PROBE, "Info", tId, "NextScheduled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunNow", tId), "the task is asked to run")
    Do $$$AssertNotEquals($ClassMethod(..#PROBE, "Info", tId, "NextScheduled"), tBefore, "and the run moves NextScheduled")
    ; The Task Manager takes a RunNow at its next once-a-minute pass: wait, bounded, for the run to finish.
    Set tFinished = $ClassMethod(..#PROBE, "Info", tId, "LastFinished")
    For tWait = 1:1:150 {
        If $ClassMethod(..#PROBE, "Info", tId, "LastFinished") '= tFinished Quit
        Hang 1
    }
    Do $$$AssertNotEquals($ClassMethod(..#PROBE, "Info", tId, "LastFinished"), tFinished, "and the task has run, moving LastFinished")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes (" _ $Get(tCode) _ ")")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description"), "ran since the mint", "the change is stored")

    Set tSC = ..Mint({"Id": (tId), "Description": "second edit"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a second edit is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Update(tId, {"Priority": "High"}, .tSaveHttp, .tSaveFault, .tViolations, .tName)
    Do $$$AssertStatusOK(tSC, "somebody else changes another field")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "and that still refuses the confirm")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>AC2 on the agent's path: a confirmed edit of two fields sends the fresh read merged with the
/// change, and every field the edit did not name reads back from the instance as it was.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.TaskPort.Trimmed</method> send an unchanged
/// <code>Settings</code> as <code>{}</code> rather than drop it -- the vendor resets the setting and
/// its read-back goes red.</p>
Method TestAConfirmedTwoFieldEditKeepsEveryOtherField()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Keep"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tId)
    Set tSC = ..Mint({"Id": (tId), "Description": "two fields", "DailyIncrement": 15}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes (" _ $Get(tCode) _ ")")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tAfter), "the task reads back")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(tAfter.%Get("Description") _ " " _ tAfter.%Get("DailyIncrement"), "two fields 15", "the two fields changed")
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind($ListBuild("Description", "DailyIncrement"), tKey) Continue
        Do $$$AssertEquals(tAfter.%Get(tKey), tValue, tKey _ " reads back as it was")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>AC5 for a holder of <code>%Admin_Secure:USE</code>: an edit of a task that runs as another
/// account, leaving the account, is not destructive; one that moves it to an account neither stored
/// nor the caller's is minted destructive with <code>TASK.RUNSASOTHER</code>; and the effect is judged
/// against the live target (AD-10).</p>
/// <p>Mutation (Rule 19): make the task arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> ignore the live
/// target -- the unchanged leg goes red.</p>
Method TestRunningAsAnotherAccountIsJudgedOnAChange()
{
    Set tOther = $Select($ZConvert($Username, "U") = "_SYSTEM": "Admin", 1: "_SYSTEM")
    Set tArgs = $ClassMethod(..#PROBE, "Ac7", "OcuP98RunAs")
    Do tArgs.%Set("RunAsUser", tOther, "string")
    Set tSC = $ClassMethod(..#PROBE, "Create", tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "a probe task running as " _ tOther _ " is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint({"Id": (tId), "Description": "the account stays"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an edit leaving the account is minted")
    If $$$ISOK(tSC) {
        Do ##class(OcuPilot.Test.TaskCreate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "and is neither destructive nor marked")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)

    Set tArgs = $ClassMethod(..#PROBE, "Ac7", "OcuP98RunAsMove")
    Set tSC = $ClassMethod(..#PROBE, "Create", tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "a probe task running as the caller is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint({"Id": (tId), "RunAsUser": (tOther)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an edit moving it to " _ tOther _ " is minted")
    If $$$ISOK(tSC) {
        Do ##class(OcuPilot.Test.TaskCreate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 TASK.RUNSASOTHER", "destructive, naming its consequence")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)

    For tCase = $ListBuild("Admin", "admin", 0), $ListBuild("Admin", "SuperUser", 1), $ListBuild("Admin", "", 1) {
        Set tTarget = {}
        If $List(tCase, 2) '= "" Do tTarget.%Set("RunAsUser", $List(tCase, 2), "string")
        Set tSC = $ClassMethod(..#SET, "GrantsPrivilegeByEffect", "task", {"RunAsUser": ($List(tCase, 1))}, tTarget, .tGrants)
        Do $$$AssertEquals(+$Get(tGrants), $List(tCase, 3), "RunAsUser Admin over a target running as '" _ $List(tCase, 2) _ "'")
    }
}

/// <p>AC4, the refused leg: a task whose type holds a secret setting is read, proposed and diffed
/// with no settings at all, and a settings change on it is refused by name
/// (<code>TASK.SETTING.SECRET</code>) at the mint and at the Save, so no replacing
/// <code>Settings</code> is sent and the stored secret is unchanged (compared in process).</p>
/// <p>Mutation (Rule 19): remove the <code>%SYS.Task.Password</code> arm of
/// <method>OcuPilot.Port.TaskPort.ClassicOnlySettings</method> -- the read answers the secret and the
/// settings change is minted, and this goes red.</p>
Method TestASecretSettingIsNeverReadAndAChangeIsRefused()
{
    Set tSC = $ClassMethod(..#PROBE, "CreateSecret", "OcuP98Secret", ..#PROBESECRET, .tId)
    Do $$$AssertStatusOK(tSC, "the secret-bearing probe is created")
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("id") = tId
    Set tSC = $ClassMethod($ClassMethod(..#TOOL, "PortClass"), "Invoke", "Task.CRUD", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFresh)): tFresh.%GetTypeOf("Settings"), 1: "no read"), "unassigned", "the read carries no settings")
    Do $$$AssertTrue($IsObject($Get(tFresh)) && (tFresh.%ToJSON() '[ ..#PROBESECRET), "and no secret")
    Set tSC = ..Mint({"Id": (tId), "Settings": {"SMTPUser": "ocup98other"}}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a settings change refuses the mint")
    Do $$$AssertTrue(##class(OcuPilot.Test.TaskCreate).Problem(.tFault) [ ("'Settings': " _ ##class(OcuPilot.Api.Error).#REASONTASKSETTINGSECRET), "by name: " _ ##class(OcuPilot.Test.TaskCreate).Problem(.tFault))
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Update(tId, {"Settings": {"SMTPUser": "ocup98other"}}, .tHttp, .tFault, .tViolations, .tName)
    Do $$$AssertEquals($Select(+$Get(tViolations): $ListToString(tViolations(1)), 1: "none"), "Settings,TASK.SETTING.SECRET", "and the Save refuses it on Settings")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretHeld", tId, ..#PROBESECRET), "the stored secret is unchanged")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>AC4, the kept leg: an edit of a secret-bearing task that leaves its settings alone -- the agent's
/// confirm and the Save -- writes, and its stored secret survives both, compared in process; the
/// proposal's payload and diff carry no settings.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.TaskPort.WithholdSettings</method> set
/// <code>Settings</code> to <code>{}</code> rather than remove it -- the edit then sends a replacing
/// empty <code>Settings</code> and the survival leg goes red.</p>
Method TestAnEditLeavingTheSettingsKeepsTheSecret()
{
    Set tSC = $ClassMethod(..#PROBE, "CreateSecret", "OcuP98SecretKept", ..#PROBESECRET, .tId)
    Do $$$AssertStatusOK(tSC, "the secret-bearing probe is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint({"Id": (tId), "Description": "the secret stays"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an edit leaving the settings is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tProposal.%ToJSON() '[ "Settings", "the proposal names no setting")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue(($Get(tValues("payload")) '[ "Settings") && ($Get(tValues("payload")) '[ ..#PROBESECRET), "and its stored payload carries none")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes (" _ $Get(tCode) _ ")")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretHeld", tId, ..#PROBESECRET), "and the stored secret survives it")
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Update(tId, {"Priority": "High"}, .tHttp, .tFault, .tViolations, .tName)
    Do $$$AssertStatusOK(tSC, "the Save of another field writes")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretHeld", tId, ..#PROBESECRET), "and the stored secret survives it too")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("Priority"), "the secret stays " _ ##class(%SYS.TaskSuper).PriorityDisplayToLogical("High"), "both edits are stored")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Mint one edit through the fixture mint, over the tool's own declared port.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), "" _ pArgs.%Get("Id"), $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

}
