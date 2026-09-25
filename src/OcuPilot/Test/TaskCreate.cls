/// <p>Pins Story 9.7's agent tool <class>OcuPilot.Screen.Tool.TaskCreate</class> (AD-3, AD-6, AD-10,
/// AD-14, AD-54): its schema and the descriptions taken from <code>%SYS.TaskSuper</code>; the
/// absence read by name, case ignored; a name taken since the mint refused at the confirm; the
/// complete body and the created id the confirm answers; and a run as another account minted
/// destructive with its consequence.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the test process holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because its
/// confirms create real probe tasks (<class>OcuPilot.Test.TaskProbe</class>), each removed by id after
/// its exact name is read back. <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.TaskCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskCreate creates and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
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

/// <p>AC2: every property the schema advertises beside the agent's own words is a key of
/// <code>Task.CRUD</code>'s derived template, is one the prohibited set permits a create, and carries
/// an authored description; each field <code>%SYS.TaskSuper</code> gives a display list carries that
/// list as its legal values; and <code>OutputDirectory</code> is never advertised (AD-21).</p>
/// <p>Mutation (Rule 19): remove <code>TimePeriod</code>'s description from
/// <method>OcuPilot.Screen.Tool.TaskCreate.Described</method> -- its description leg goes red.</p>
Method TestTheSchemaIsDerivedAndDescribedFromTaskSuper()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Name"",""TaskClass""]", "the name and the task type are required")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"Name": "x", "TaskClass": "y"}, .tProblem)
    Do $$$AssertEquals(tProblem, "", "the schema is inside the subset a provider is sent")
    ; A whole create as a model sends it, typed as the schema says: the schema and the form's rules
    ; both accept it.
    Set tWhole = {"Name": "OcuP97Whole", "Description": "OcuPilot task create probe", "NameSpace": "%SYS", "TaskClass": "%SYS.Task.PurgeTaskHistory", "Settings": {"KeepDays": "30"}, "TimePeriod": "Weekly", "TimePeriodEvery": 1, "TimePeriodDay": "24", "DailyFrequency": "Several", "DailyFrequencyTime": "Minutes", "DailyIncrement": 30, "DailyStartTime": "01:00", "DailyEndTime": "05:00", "StartDate": ($ZDate(+$Horolog + 1, 3)), "Expires": true, "ExpiresDays": 0, "ExpiresHours": 1, "ExpiresMinutes": 30, "Priority": "Low", "IsBatch": false, "MirrorStatus": "Any", "OpenOutputFile": true, "OutputFilename": "ocup97whole.txt", "OutputFileIsBinary": false, "EmailOutput": true, "SuspendOnError": true, "SuspendTerminated": false, "RescheduleOnStart": true, "EmailOnCompletion": ["ops@example.com"], "EmailOnError": ["ops@example.com", "dev@example.com"], "EmailOnExpiration": []}
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tWhole, .tProblem)
    Do $$$AssertEquals(tProblem, "", "a whole create, typed as the schema says, is inside it")
    Set tSC = ##class(OcuPilot.Area.Task.TaskRules).Validate("create", tWhole, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 0, "and the form's rules accept it: " _ ##class(OcuPilot.Area.Task.TaskRules).Problem(.tViolations))
    Set tTemplate = ..TemplateKeys()
    Do $$$AssertTrue($ListLength(tTemplate) = 35, "the derived template has its 35 keys (" _ $ListLength(tTemplate) _ ")")
    Set tPermitted = $ClassMethod(..#SET, "PermittedCreateFields", "task")
    Set tGeneric = $ListBuild("The value this create sets. Omit it to leave the field at the instance's own default.", "The whole list this create sets.")
    Set tNames = ""
    Set tIterator = tSchema.%Get("properties").%GetIterator()
    While tIterator.%GetNext(.tKey, .tProperty) {
        If $ListFind($ListBuild("rationale", "expectedImpact", "reverse"), tKey) Continue
        Set tNames = tNames _ $ListBuild(tKey)
        Do $$$AssertTrue($ListFind(tTemplate, tKey) > 0, tKey _ " is a derived template key")
        Do $$$AssertTrue($ListFind(tPermitted, tKey) > 0, tKey _ " is one the prohibited set permits a create")
        Set tDescription = tProperty.%Get("description")
        Do $$$AssertTrue((tDescription '= "") && '$ListFind(tGeneric, tDescription), tKey _ " carries an authored description")
    }
    Do $$$AssertEquals($ListLength(tNames), 34, "the thirty-four are advertised")
    Do $$$AssertEquals($ListFind(tNames, "OutputDirectory"), 0, "and the directory is not")
    Do $$$AssertEquals(..Sorted(tNames), ..Sorted(tPermitted), "exactly the permitted set")
    Do $$$AssertEquals(..Sorted($ListFromString($Parameter(..#TOOL, "PERMITTEDFIELDS"))), ..Sorted(tPermitted), "which is the tool's own positive list")
    ; AD-3: the rules' own field list and the composed body's keys are the same set, so no settable
    ; field is validated and then dropped from the body, or sent without being settable.
    Do $$$AssertEquals(..Sorted($ListFromString($Parameter("OcuPilot.Area.Task.TaskRules", "FIELDS"))), ..Sorted(tPermitted), "the rules compose exactly the permitted set")
    Set tKeys = $ListBuild("Settings")
    Set tIterator = ##class(OcuPilot.Area.Task.TaskRules).Defaults().%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) { Set tKeys = tKeys _ $ListBuild(tKey) }
    Do $$$AssertEquals(..Sorted(tKeys), ..Sorted(tPermitted), "and a new task's own values cover every other key")
    For tField = "TimePeriod", "DailyFrequency", "DailyFrequencyTime", "Priority", "MirrorStatus" {
        Set tEnum = tSchema.%Get("properties").%Get(tField).%Get("enum")
        Do $$$AssertEquals($Select($IsObject(tEnum): ..Joined(tEnum), 1: ""), ..DisplayList(tField), tField _ "'s legal values are TaskSuper's display list")
    }
    Do $$$AssertTrue(tSchema.%Get("properties").%Get("TimePeriod").%Get("description") [ "governs how TimePeriodEvery and TimePeriodDay are read", "TimePeriod carries TaskSuper's own description")
}

/// <p>AD-54: the create is minted over the name's absence with the target keyed
/// <code>task:instance:&lt;Name&gt;</code>; every supplied field is a row, each setting as
/// <code>Settings.&lt;key&gt;</code>; the unchanged count is the body's other keys; and a name another
/// task holds, in another case, refuses the mint.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.TaskCreate.CREATES</parameter> to 0 --
/// the absent target refuses the mint and this goes red.</p>
Method TestTheCreateIsMintedOverTheNamesAbsence()
{
    Set tSC = ..Mint(..OnDemand("OcuP97Mint"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ ..Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Set tTarget = tProposal.%Get("target")
    Do $$$AssertEquals(tTarget.%Get("type") _ ":" _ tTarget.%Get("scope") _ ":" _ tTarget.%Get("id"), "task:instance:ocup97mint", "the target is the name in its canonical spelling (AD-13)")
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = tFields _ $ListBuild(tRow.%Get("field"))
    }
    Do $$$AssertEquals($ListToString(tFields), "Name,TaskClass,Settings.Directory,TimePeriod", "one row per supplied field, the setting named, the location it names on the card")
    Do $$$AssertEquals(tProposal.%Get("changed").%Get(2).%Get("after"), "/tmp/", "the setting's row shows the location")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 30, "the body's other keys are sent unchanged, the supplied Settings not among them")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload"), "{}"))
    Do $$$AssertEquals(..Count(tPayload), 34, "the stored body is complete: thirty-three keys and the settings")

    Set tVendor = ##class(OcuPilot.Test.TaskProbe).VendorName()
    Do $$$AssertNotEquals(tVendor, "", "the instance holds a task to collide with")
    Set tSC = ..Mint(..OnDemand($ZConvert(tVendor, "L")), .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a name another task holds, in another case, refuses the mint")
    Do $$$AssertTrue(..Problem(.tFault) [ "already present", "refused as present, not for another reason: " _ ..Problem(.tFault))
}

/// <p>AD-14, AD-54: the confirm creates the task from the stored complete body and answers the
/// instance's id as <code>createdId</code>; a name taken since the mint refuses the confirm with
/// nothing written.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from
/// <method>OcuPilot.Screen.Tool.TaskCreate.CreatedId</method> -- the <code>createdId</code> leg goes
/// red.</p>
Method TestTheConfirmCreatesAndAnswersTheId()
{
    Set tSC = ..Mint(..OnDemand("OcuP97Agent"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ ..Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm answers 200 (" _ $Get(tCode) _ ")")
    Set tId = ##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97Agent")
    Do $$$AssertNotEquals(tId, "", "the task is created")
    Do $$$AssertTrue($IsObject($Get(tResult)), "and the confirm answers")
    If $IsObject($Get(tResult)) {
        Do $$$AssertEquals(tResult.%Get("createdId"), tId, "and the answer carries its id")
        Do $$$AssertEquals(tResult.%Get("action"), "created", "with the created action")
    }
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("TimePeriod") _ "|" _ tStored.%Get("Settings.Directory") _ "|" _ tStored.%Get("Expires"), "5|/tmp/|0", "stored On Demand, its setting kept, no expiry")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)

    Set tSC = ..Mint(..OnDemand("OcuP97Race"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the second create is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Create(..OnDemand("OcuP97Race"), .tSaveHttp, .tSaveFault, .tViolations, .tRaceId)
    Do $$$AssertNotEquals($Get(tRaceId), "", "somebody takes the name after the mint")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused")
    Set tIds = ##class(OcuPilot.Test.TaskProbe).Probes(.tNames)
    Do $$$AssertEquals($ListLength(tIds), 1, "and nothing more is written")
    Do ##class(OcuPilot.Test.TaskProbe).Remove($Get(tRaceId))
}

/// <p>AC6 for a holder of <code>%Admin_Secure:USE</code>: a run as another account is minted
/// destructive with <parameter>OcuPilot.Screen.Tool.TaskCreate.CONSEQUENCERUNSASOTHER</parameter>,
/// its row naming the account, and confirming it creates the task; a run as the caller is
/// neither.</p>
/// <p>Mutation (Rule 19): drop the task arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- the destructive
/// leg goes red.</p>
Method TestARunAsAnotherAccountIsMintedDestructive()
{
    Set tOther = $Select($ZConvert($Username, "U") = "_SYSTEM": "Admin", 1: "_SYSTEM")
    Set tArgs = ..OnDemand("OcuP97RunAs")
    Do tArgs.%Set("RunAsUser", tOther, "string")
    Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ ..Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 TASK.RUNSASOTHER", "destructive, naming its consequence")
    Set tRow = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChanged) {
        If tChanged.%Get("field") = "RunAsUser" Set tRow = tChanged.%Get("after")
    }
    Do $$$AssertEquals(tRow, tOther, "its row names the account")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "and the confirm creates it (" _ $Get(tCode) _ ")")
    Set tId = ##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97RunAs")
    Do $$$AssertNotEquals(tId, "", "the task is created")
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("RunAsUser"), tOther, "running as that account")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)

    Set tArgs = ..OnDemand("OcuP97RunAsMe")
    Do tArgs.%Set("RunAsUser", $ZConvert($Username, "L"), "string")
    Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a run as the caller is minted")
    If $$$ISERR(tSC) Quit
    Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "and is neither destructive nor marked")
}

/// <p>AD-55: the agent's mint applies the form's own rules (<method>OcuPilot.Screen.Tool.TaskCreate.ArgumentProblem</method>),
/// so a create the wizard refuses is refused at the mint, naming the field and its sentence, and no
/// proposal or task exists.</p>
/// <p>Mutation (Rule 19): drop the <code>Validate</code> call from
/// <method>OcuPilot.Screen.Tool.TaskCreate.ArgumentProblem</method> -- both refusals mint and this
/// goes red.</p>
Method TestTheMintAppliesTheFormsRules()
{
    Set tSeveral = ..OnDemand("OcuP97MintRules")
    Do tSeveral.%Set("TimePeriod", "Daily", "string")
    Do tSeveral.%Set("DailyFrequency", "Several", "string")
    Do tSeveral.%Set("DailyFrequencyTime", "Minutes", "string")
    Do tSeveral.%Set("DailyEndTime", "05:00", "string")
    Do tSeveral.%Set("DailyStartTime", "01:00", "string")
    Do tSeveral.%Set("StartDate", $ZDate(+$Horolog + 1, 3), "string")
    Set tSC = ..Mint(tSeveral, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "Several without an increment refuses the mint")
    Do $$$AssertTrue(..Problem(.tFault) [ "'DailyIncrement': " _ ##class(OcuPilot.Api.Error).#REASONTASKDAILYINCREMENTREQUIRED, "naming the field and its sentence: " _ ..Problem(.tFault))
    Set tStranger = ..OnDemand("OcuP97MintStranger")
    Do tStranger.%Set("RunAsUser", "OcuP97NoSuchAccount", "string")
    Set tSC = ..Mint(tStranger, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "an account the instance does not hold refuses the mint")
    Do $$$AssertTrue(..Problem(.tFault) [ "'RunAsUser': ", "on RunAsUser: " _ ..Problem(.tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97MintRules") _ ##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97MintStranger"), "", "and nothing was created")
}

/// <p>AC6's effect arm, judged on the payload alone: a blank <code>RunAsUser</code> and the caller's
/// own name in any case grant nothing, and any other account grants its privileges.</p>
Method TestRunningAsAnotherAccountIsJudgedByEffect()
{
    For tCase = $ListBuild("", 0), $ListBuild($ZConvert($Username, "L"), 0), $ListBuild($ZConvert($Username, "U"), 0), $ListBuild("OcuP97Other", 1) {
        Set tPayload = {"Name": "OcuP97Effect"}
        If $List(tCase, 1) '= "" Do tPayload.%Set("RunAsUser", $List(tCase, 1), "string")
        Set tSC = $ClassMethod(..#SET, "GrantsPrivilegeByEffect", "task", tPayload, "", .tGrants)
        Do $$$AssertStatusOK(tSC, "the effect is judged")
        Do $$$AssertEquals(+$Get(tGrants), $List(tCase, 2), "RunAsUser '" _ $List(tCase, 1) _ "'")
    }
}

/// <p>The wizard's descriptor: built and unlisted at the list's route with the editor suffix, a form
/// page over the task type, gated by exactly the list's pairs, declaring its classic page and three
/// prompts; the list declares Create as its primary action.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = "OcuPilot.Screen.Descriptor.TaskForm"
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")), "1 0", "it is built and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "form-page task", "a form page over the task type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "tasks.scheduleform", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Task.TaskSave", "DESCRIPTORCLASS") _ " " _ $Parameter("OcuPilot.Area.Task.TaskRules", "DESCRIPTORCLASS"), tForm _ " " _ tForm, "and the routes gate on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISOK(tSC) {
        Do $$$AssertEquals(tDeclaration.%Get("classicPage"), "%cspapp.op.utilsystaskbuilder", "its classic page is the class the classic wizard compiles to")
        Do $$$AssertEquals(tDeclaration.%Get("suggestedPrompts").%Size(), 3, "with three suggested prompts")
    }
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tList)
    If $$$ISOK(tSC) Do $$$AssertEquals(tList.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Set tCodes = ##class(OcuPilot.Api.Error).TaskViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes task field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
}

/// <p>An On Demand create of <code>%SYS.Task.IntegrityCheck</code> named <var>pName</var>, whose
/// directory setting is a location the card names.</p>
ClassMethod OnDemand(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "TaskClass": "%SYS.Task.IntegrityCheck", "Settings": {"Directory": "/tmp/"}, "TimePeriod": "On Demand"}
}

/// <p>Mint one create through the fixture mint, over the tool's own declared port.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pArgs.%Get("Name"), $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Proposal <var>pKey</var>'s stored destructive flag and consequence.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>The top-level keys of <code>Task.CRUD</code>'s derived template, from the generated field
/// lists.</p>
ClassMethod TemplateKeys() As %List
{
    Set tKeys = ""
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.FieldLists", "Lists", , .tSC)
    If '$IsObject(tXData) Quit ""
    Do tXData.Data.Rewind()
    Set tLists = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    Set tIterator = tLists.%Get("Task.CRUD").%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tPath = tRow.%Get("path")
        If (tPath [ ".") || (tPath [ "[") Continue
        Set tKeys = tKeys _ $ListBuild(tPath)
    }
    Quit tKeys
}

/// <p><code>%SYS.TaskSuper</code>'s compiled <code>DISPLAYLIST</code> for <var>pField</var>,
/// comma-separated.</p>
ClassMethod DisplayList(pField As %String) As %String
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId("%SYS.TaskSuper||" _ pField, 0)
    If '$IsObject(tProperty) Quit ""
    Set tList = tProperty.Parameters.GetAt("DISPLAYLIST")
    Quit $Translate($Extract(tList, 2, *), $Extract(tList), ",")
}

/// <p><var>pArray</var>'s members, comma-separated.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tOut = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tValue
    }
    Quit tOut
}

/// <p>How many top-level keys <var>pObject</var> holds.</p>
ClassMethod Count(pObject As %DynamicObject) As %Integer
{
    Set tCount = 0
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The problem a refusal's fault carries, or <code>""</code>.</p>
ClassMethod Problem(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    If pFault.%GetTypeOf("detail") '= "object" Quit pFault.%Get("reason")
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p><var>pList</var> sorted and comma-separated.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tNames
    For tI = 1:1:$ListLength(pList) Set tNames($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
