/// <p>Pins Story 8.8's device create (AD-3, AD-10, AD-39, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.DeviceCreate</class> advertises, the device form's descriptor, one body
/// from both callers with <code>Alias</code> and <code>Prompt</code> as integers, every field rule
/// refused on both callers before anything is sent, a name taken before or after the mint, and open
/// parameters the instance cannot parse refused on their field and failing the agent's confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and an account holding
/// <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:WRITE</code>. Every write reaches the instance through
/// <class>OcuPilot.Test.DeviceRecordPort</class>; every device it creates is named with
/// <parameter>OcuPilot.Test.DeviceProbe.PREFIX</parameter> and removed by exact name.</p>
Class OcuPilot.Test.DeviceCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.DeviceCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.DeviceList";

Parameter FORM = "OcuPilot.Screen.Descriptor.DeviceForm";

Parameter RULES = "OcuPilot.Area.OsMgmt.DeviceRules";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.DeviceSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.DeviceConfirm";

Parameter RECORD = "OcuPilot.Test.DeviceRecordPort";

Parameter PROBE = "OcuPilot.Test.DeviceProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe device is removed by exact name")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "CpfValid", .tNamesProbe), "and the configuration file validates")
    Do $$$AssertEquals(tNamesProbe, 0, "naming no probe device")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>AD-3, AD-54: a create over the vendor's single read and its <code>PUT</code>, advertising the
/// name and the eight template fields -- three of them required, the type as its six values -- over
/// the prohibited set's reviewed create list.</p>
Method TestTheSchemaAndTheSettableSetAreTheSets()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(..Keys(tSchema.%Get("properties")), "Alias,AlternateDevice,Description,Name,OpenParameters,PhysicalDevice,Prompt,SubType,Type,expectedImpact,rationale,reverse", "the schema is the name, the eight fields and the agent's own words")
    Do $$$AssertEquals(..Sorted(..ListOf(tSchema.%Get("required"))), "Name,PhysicalDevice,SubType,Type", "requiring the name and the three the vendor's create requires")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Type").%Get("enum").%ToJSON(), "[""TRM"",""SPL"",""MT"",""BT"",""IPC"",""OTH""]", "the type offered as its six values")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "device")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "device")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "device")), "which is the change list too")
    Do $$$AssertEquals(..Sorted($ListFromString($Parameter(..#RULES, "FIELDS"))), ..Sorted($ClassMethod(..#TOOL, "SettableFields")), "and the set the rules and the screen's edit read")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates") _ " " _ $ClassMethod(..#TOOL, "ChangeAction") _ " " _ $ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType"), "1 created GET PUT", "a create publishing created, over the vendor's GET and PUT")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs") _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))), "requiring the list's own pairs and the system database write its save needs")
}

/// <p>The form descriptor: built, unlisted, at the list's route with the editor suffix, over the
/// device type with the list's own pairs and the classic device page; every rule code carries a
/// sentence the form read publishes; and the list now declares Create and invites the agent.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Manage</code> from
/// <class>OcuPilot.Screen.Descriptor.DeviceForm</class>'s privileges -> the pair assertions go red,
/// and <class>OcuPilot.Test.DeviceWire</class>'s 403 leg separately.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = ..#FORM
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")), "1 0", "it is built and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "form-page device", "a form page over the device type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "osmgmt.deviceform", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertTrue($ListFind($ClassMethod(tForm, "PrivilegePairs"), $ListBuild("%Admin_Manage", "USE")), "the manage resource among it")
    Do $$$AssertEquals($ClassMethod(tForm, "ClassicPage"), "%CSP.UI.Portal.Config.Device", "and the classic device page as its classic key")
    Set tCodes = ##class(OcuPilot.Api.Error).DeviceViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a sentence")
        Do $$$AssertNotEquals($ClassMethod(..#RULES, "FieldOf", $List(tCodes, tI)), "", $List(tCodes, tI) _ " names its field")
    }
    Do $$$AssertEquals($ClassMethod(..#RULES, "Rules").%Size(), $ListLength(tCodes), "the form read publishes one rule per code")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey") _ "|" _ tDeclaration.%Get("table").%Get("emptyAgentKey"), "|deviceListEmptyAgent", "and its empty state invites the agent")
}

/// <p>The Create, screen and Agent create rows, value shapes: the screen's Save and the agent's
/// confirmed create send one body -- all eight fields, the alternate device naming another probe
/// device, <code>Alias</code> and <code>Prompt</code> as integers whatever JSON type the caller
/// used -- and each creates the device.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.DeviceRules.Shape</method> leave the
/// payload as it is -> the agent's body carries the alias as a string and this goes red; make it drop
/// <code>AlternateDevice</code> -> both callers' bodies lose it and this goes red.</p>
Method TestACreateSendsOneBodyFromBothCallers()
{
    Set tAlternate = ..Name("Alt")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tAlternate), "a device to name as the alternate is created")
    Set tExpected = "Alias=9988|AlternateDevice=" _ tAlternate _ "|Description=probe|OpenParameters=|PhysicalDevice=/tmp/p88.txt|Prompt=1|SubType=P-DEC|Type=OTH"
    Set tName = ..Name("A")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, {"Name": (tName), "PhysicalDevice": "/tmp/p88.txt", "Type": "OTH", "SubType": "P-DEC", "OpenParameters": "", "Description": "probe", "Alias": 9988, "AlternateDevice": (tAlternate), "Prompt": 1}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's create is saved")
    Do $$$AssertEquals(tHttp, 201, "the vendor answers 201")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastName"), "PUT " _ tName, "at the vendor's PUT, naming the device in the query parameter")
    Set tScreenBody = $ClassMethod(..#RECORD, "LastWriteBody")
    Do $$$AssertEquals(..Normal(tScreenBody), tExpected, "the screen sends the eight fields it was given")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "AlternateDevice"), tAlternate, "and the instance holds the alternate device")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Alias"), 9988, "and the instance holds the alias")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), "the device is removed")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Mint(tName, {"Name": (tName), "PhysicalDevice": "/tmp/p88.txt", "Type": "OTH", "SubType": "P-DEC", "OpenParameters": "", "Description": "probe", "Alias": "9988", "AlternateDevice": (tAlternate), "Prompt": "1"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create of the same device is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 8, "one diff row per supplied field")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing unchanged")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Set tAgentBody = $ClassMethod(..#RECORD, "LastWriteBody")
    Do $$$AssertEquals(..Normal(tAgentBody), tExpected, "the confirm sends the same fields")
    Do $$$AssertEquals(..Types(tAgentBody), ..Types(tScreenBody), "in the same JSON types")
    Do $$$AssertEquals(..Types(tAgentBody), "Alias=number|AlternateDevice=string|Description=string|OpenParameters=string|PhysicalDevice=string|Prompt=number|SubType=string|Type=string", "the alias and the prompt as integers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "answering the created action")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the device exists")
}

/// <p>The Field rules row, AC3: each broken rule is refused on its field on the screen, with nothing
/// sent, and at the agent's mint at 400 with the same sentence -- among them the rules the vendor does
/// not enforce: a <code>^</code> or a control character, a type outside the six, a fractional or
/// duplicate alias.</p>
/// <p>Mutation (Rule 19): drop the <code>^</code> test from
/// <method>OcuPilot.Area.OsMgmt.DeviceRules.Writable</method> -> every <code>^</code> case is accepted
/// and this goes red.</p>
Method TestEveryFieldRuleRefusesOnBothCallers()
{
    Set tHolder = ..Name("Holder")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tHolder, {"Alias": 9977}), "a device holding alias 9977 is created")
    Set tLong = "", $Piece(tLong, "x", 130) = ""
    Set tLonger = "", $Piece(tLonger, "x", 258) = ""
    Set tCases($Increment(tCases)) = $ListBuild("Name", "empty", "", "DEVICE.NAME.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("Name", "value", ..Name("") _ $Extract(tLong, 1, 60), "DEVICE.NAME.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild("Name", "value", ..Name("B^x"), "DEVICE.NAME.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Name", "value", ..Name("B=x"), "DEVICE.NAME.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Name", "value", ..Name("B" _ $Char(9)), "DEVICE.NAME.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("PhysicalDevice", "absent", "", "DEVICE.PHYSICALDEVICE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("PhysicalDevice", "value", "", "DEVICE.PHYSICALDEVICE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("PhysicalDevice", "value", tLong, "DEVICE.PHYSICALDEVICE.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild("PhysicalDevice", "value", "/tmp/a^b", "DEVICE.PHYSICALDEVICE.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Type", "absent", "", "DEVICE.TYPE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("Type", "value", "", "DEVICE.TYPE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("Type", "value", "ZZZ", "DEVICE.TYPE.VALUE")
    Set tCases($Increment(tCases)) = $ListBuild("Type", "value", "trm", "DEVICE.TYPE.VALUE")
    Set tCases($Increment(tCases)) = $ListBuild("SubType", "absent", "", "DEVICE.SUBTYPE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("SubType", "value", "", "DEVICE.SUBTYPE.REQUIRED")
    Set tCases($Increment(tCases)) = $ListBuild("SubType", "value", "OcuPilotNoSuchSubType", "DEVICE.SUBTYPE.ABSENT")
    Set tCases($Increment(tCases)) = $ListBuild("OpenParameters", "value", tLong, "DEVICE.OPENPARAMETERS.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild("OpenParameters", "value", """W""^", "DEVICE.OPENPARAMETERS.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Description", "value", tLonger, "DEVICE.DESCRIPTION.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild("Description", "value", "a^b", "DEVICE.DESCRIPTION.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Description", "value", "a" _ $Char(10) _ "b", "DEVICE.DESCRIPTION.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("AlternateDevice", "value", tLong, "DEVICE.ALTERNATEDEVICE.LENGTH")
    Set tCases($Increment(tCases)) = $ListBuild("AlternateDevice", "value", "a^b", "DEVICE.ALTERNATEDEVICE.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Alias", "value", "1.5", "DEVICE.ALIAS.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Alias", "value", "0", "DEVICE.ALIAS.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Alias", "value", "-3", "DEVICE.ALIAS.SHAPE")
    Set tCases($Increment(tCases)) = $ListBuild("Alias", "value", "9977", "DEVICE.ALIAS.TAKEN")
    Set tCases($Increment(tCases)) = $ListBuild("Alias", "value", "210210", "DEVICE.ALIAS.SAME")
    Set tCases($Increment(tCases)) = $ListBuild("Prompt", "value", "3", "DEVICE.PROMPT.VALUE")
    Set tCases($Increment(tCases)) = $ListBuild("Prompt", "value", "x", "DEVICE.PROMPT.VALUE")
    For tI = 1:1:tCases {
        Set tField = $List(tCases(tI), 1)
        Set tMode = $List(tCases(tI), 2)
        Set tCode = $List(tCases(tI), 4)
        Set tArgs = {"Name": (..Name("B")), "PhysicalDevice": "/tmp/p88b.txt", "Type": "OTH", "SubType": "P-DEC"}
        If tCode = "DEVICE.ALIAS.SAME" Do tArgs.%Set("PhysicalDevice", "210210")
        If tMode = "absent" Do tArgs.%Remove(tField)
        If tMode '= "absent" Do tArgs.%Set(tField, $List(tCases(tI), 3), "string")
        Set tName = tArgs.%Get("Name")
        Set tLabel = tI _ " " _ tCode
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tField), tCode, tLabel _ ": the screen refuses it on " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tLabel _ ": and sends nothing")
        If tName = "" Continue
        Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, tLabel _ ": the agent's mint refuses it at 400")
        Do $$$AssertTrue(..Problem($Get(tFault)) [ ("'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)), tLabel _ ": with the field's own sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("B")), 0, "and no device was created")
}

/// <p>The Name taken row: an exact-case name the instance holds is refused on the screen as taken,
/// while one differing only in case is another device; the agent's mint of the held name is refused;
/// and a name taken between the mint and the confirm refuses the confirm as the target changed, with
/// nothing sent (AD-54).</p>
Method TestANameTakenIsRefusedBeforeAndAfterTheMint()
{
    Set tName = ..Name("C")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a device is created")
    Set tArgs = {"PhysicalDevice": "/tmp/p88c.txt", "Type": "OTH", "SubType": "P-DEC"}
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), "DEVICE.NAME.TAKEN", "the screen refuses the held name as taken")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's mint of the held name is refused")
    Set tVariant = ..Name("c")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tVariant, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "a name differing only in case is another device and is created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tVariant) + $ClassMethod(..#PROBE, "Holds", tName), 2, "so both exist")

    Set tLate = ..Name("D")
    Set tSC = ..Mint(tLate, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create of a free name is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tLate, {"Description": "someone else's"}), "then somebody else creates it")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tLate, "Description"), "someone else's", "and the other device is untouched")
}

/// <p>The Open parameters row: open parameters the instance cannot parse reach the vendor, which
/// refuses them with its error 644, and the screen answers that as the form's own refusal on the
/// field rather than an internal error; no device is created.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -> the
/// screen's answer carries no violation and this goes red.</p>
Method TestUnparsableOpenParametersAreRefusedOnTheirField()
{
    Set tName = ..Name("E")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, {"Name": (tName), "PhysicalDevice": "/tmp/p88e.txt", "Type": "OTH", "SubType": "P-DEC", "OpenParameters": "((("}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "the create is refused")
    Do $$$AssertEquals(..CodeFor(.tViolations, "OpenParameters"), "DEVICE.OPENPARAMETERS.SHAPE", "on the open parameters, with the form's own code")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 1, "after the one write the vendor refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no device was created")
}

/// <p>AD-10, AD-55: a screen create carrying a key outside the eight is put to the prohibited set,
/// which refuses it at 403, rather than dropped; nothing is sent.</p>
/// <p>Mutation (Rule 19): ask the set over <code>{}</code> instead of the caller's fields in
/// <method>OcuPilot.Area.OsMgmt.DeviceSave.Create</method> -> the key is dropped, the device is
/// created and this goes red.</p>
Method TestAScreenCreateCarryingAnotherKeyIsRefused()
{
    Set tName = ..Name("K")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, {"Name": (tName), "PhysicalDevice": "/tmp/p88k.txt", "Type": "OTH", "SubType": "P-DEC", "Settings": "x"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "the create is refused")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD, "by the prohibited set")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no device is created")
}

/// <p>The Open parameters row, agent half: the rules pass open parameters the instance cannot parse,
/// so the mint succeeds; the confirm's write reaches the vendor, which refuses it, and the confirm
/// fails with the port's normalized failure -- OcuPilot's code, not the vendor's text -- and no device
/// is created.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.Fail</method> answer the vendor's error
/// text as the fault's code, in the container only -> the confirm answers that text and this goes
/// red.</p>
Method TestUnparsableOpenParametersFailTheAgentsConfirm()
{
    Set tName = ..Name("F")
    Set tSC = ..Mint(tName, {"Name": (tName), "PhysicalDevice": "/tmp/p88f.txt", "Type": "OTH", "SubType": "P-DEC", "OpenParameters": "((("}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted")
    If $$$ISERR(tSC) Quit
    Do $ClassMethod(..#RECORD, "Clear")
    Set tResult = ""
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm fails")
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "with the port's normalized failure")
    Set tText = $Get(tCode) _ $Select($IsObject($Get(tDetail)): tDetail.%ToJSON(), 1: $Get(tDetail)) _ $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText '[ "#644") && (tText '[ "((("), "carrying none of the vendor's text")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "WriteCount"), "PUT 1", "after the one write the vendor refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no device was created")
}

/// <p>Mint one create of <var>pName</var> through the shipped mint and the tool's own port, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..MintWith(..#TOOL, pName, pArgs, .pProposal, .pHttpStatus, .pFault)
}

/// <p>Mint one write of tool <var>pTool</var> against <var>pName</var> through the shipped mint.</p>
ClassMethod MintWith(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set pHttpStatus = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pName, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Confirm <var>pKey</var> through the shipped transition, its port recording what it sends.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Quit ..ConfirmKey(pKey, .pHttp, .pCode, .pResult)
}

ClassMethod ConfirmKey(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>A probe device's name: <parameter>OcuPilot.Test.DeviceProbe.PREFIX</parameter> and
/// <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit $Parameter(..#PROBE, "PREFIX") _ pSuffix
}

/// <p>The JSON body <var>pText</var> as <code>key=value</code> pairs in key order, joined with
/// <code>|</code>, so two bodies compare whatever their key order.</p>
ClassMethod Normal(pText As %String) As %String
{
    If pText = "" Quit ""
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pText)
    Set tOut = ""
    For tI = 1:1:$Length(..Keys(tBody), ",") {
        Set tKey = $Piece(..Keys(tBody), ",", tI)
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tKey _ "=" _ tBody.%Get(tKey)
    }
    Quit tOut
}

/// <p>The JSON body <var>pText</var> as <code>key=type</code> pairs in key order.</p>
ClassMethod Types(pText As %String) As %String
{
    If pText = "" Quit ""
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pText)
    Set tOut = ""
    For tI = 1:1:$Length(..Keys(tBody), ",") {
        Set tKey = $Piece(..Keys(tBody), ",", tI)
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tKey _ "=" _ tBody.%GetTypeOf(tKey)
    }
    Quit tOut
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p>The problem a 400 <code>TOOL.ARGUMENTS</code> refusal carries in its detail, or
/// <code>""</code>.</p>
ClassMethod Problem(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) || (pFault.%GetTypeOf("detail") '= "object") Quit ""
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p><var>pArray</var>'s scalar members as a <class>%List</class>.</p>
ClassMethod ListOf(pArray As %DynamicArray) As %List
{
    Set tList = ""
    If '$IsObject(pArray) Quit tList
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) { Set tList = tList _ $ListBuild(tValue) }
    Quit tList
}

ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Quit ..Sorted(tKeys)
}

ClassMethod Sorted(pList As %List) As %String
{
    Kill tSeen
    For tI = 1:1:$ListLength(pList) Set tSeen($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
