/// <p>Pins Story 8.8's device edit (AD-4, AD-6, AD-39, AD-55): what
/// <class>OcuPilot.Screen.Tool.DeviceUpdate</class> advertises, the complete set both callers send
/// over a fresh read, an emptied alias and prompt clearing the field, a key outside the eight refused,
/// a device deleted since the read refused rather than re-created (AC4), and rules that read only the
/// fields an edit changes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and an account holding
/// <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:WRITE</code>. Every write reaches the instance through
/// <class>OcuPilot.Test.DeviceRecordPort</class>; every device it creates is named with
/// <parameter>OcuPilot.Test.DeviceProbe.PREFIX</parameter> and removed by exact name.</p>
Class OcuPilot.Test.DeviceUpdate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.DeviceUpdate";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.DeviceSaveFixture";

Parameter RECORD = "OcuPilot.Test.DeviceRecordPort";

Parameter PROBE = "OcuPilot.Test.DeviceProbe";

/// <p>The create suite, whose helpers this class shares.</p>
Parameter SHARED = "OcuPilot.Test.DeviceCreate";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Add", ..Name("Edit"), {"Description": "d", "OpenParameters": ("""W"""), "Alias": 9955, "Prompt": 2})
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

/// <p>AD-4: a merge write over the vendor's single read and its <code>PUT</code>, advertising the
/// name and the eight fields over the prohibited set's reviewed change list, fingerprinted over every
/// field it sends.</p>
Method TestTheEditIsAMergeWriteOverTheEightFields()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(..Keys(tSchema.%Get("properties")), "Alias,AlternateDevice,Description,Name,OpenParameters,PhysicalDevice,Prompt,SubType,Type,expectedImpact,rationale,reverse", "the schema is the name, the eight fields and the agent's own words")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Name""]", "requiring the name alone")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "device")), "the settable set is the prohibited set's reviewed change list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "ChangeAction") _ " " _ $ClassMethod(..#TOOL, "Creates"), "GET PUT 1 updated 0", "a merge write publishing updated")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "FingerprintSubject"), "", "fingerprinted over every field it sends")
}

/// <p>The Edit, screen row and the complete set (AD-4), on both callers: an edit of the description
/// alone sends the fresh read's eight fields with that one changed, the alias and the prompt as
/// integers, and the instance keeps every field the edit did not change.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.DeviceSave.Update</method> send the
/// caller's fields without <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> -> the screen body
/// loses seven fields and this goes red.</p>
Method TestAnEditSendsTheCompleteSetOnBothCallers()
{
    Set tName = ..Name("Edit")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Description": "x"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's edit is saved")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastName"), "PUT " _ tName, "at the vendor's PUT")
    Set tScreenBody = $ClassMethod(..#RECORD, "LastWriteBody")
    Do $$$AssertEquals(..Normal(tScreenBody), "Alias=9955|AlternateDevice=|Description=x|OpenParameters=""W""|PhysicalDevice=/tmp/" _ tName _ ".txt|Prompt=2|SubType=P-DEC|Type=OTH", "the fresh read's eight fields with the one change")
    Do $$$AssertEquals(..Types(tScreenBody), "Alias=number|AlternateDevice=string|Description=string|OpenParameters=string|PhysicalDevice=string|Prompt=number|SubType=string|Type=string", "the alias and the prompt as integers")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Description") _ "|" _ $ClassMethod(..#PROBE, "Stored", tName, "Alias"), "x|9955", "the instance holds the change and keeps the alias")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tName, {"Name": (tName), "Description": "y"}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "with one changed row")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 7, "and the seven fields it keeps")
    Set tSC = $ClassMethod(..#SHARED, "ConfirmKey", tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Set tAgentBody = $ClassMethod(..#RECORD, "LastWriteBody")
    Do $$$AssertEquals(..Normal(tAgentBody), $Replace(..Normal(tScreenBody), "Description=x", "Description=y"), "the confirm sends the same complete set")
    Do $$$AssertEquals(..Types(tAgentBody), ..Types(tScreenBody), "in the same JSON types")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "updated", "answering the updated action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed")
}

/// <p>Value shapes: an empty alias or prompt clears the field, sent as <code>""</code>, and an alias
/// sent as text is sent as an integer.</p>
Method TestAnEmptyValueClearsTheAliasAndThePrompt()
{
    Set tName = ..Name("Edit")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Alias": "", "Prompt": ""}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's edit emptying both is saved")
    Set tBody = $ClassMethod(..#RECORD, "LastWriteBody")
    Do $$$AssertEquals($Piece(..Types(tBody), "|", 1) _ "|" _ $Piece(..Types(tBody), "|", 6), "Alias=string|Prompt=string", "both sent as strings")
    Do $$$AssertEquals($Piece(..Normal(tBody), "|", 1) _ "|" _ $Piece(..Normal(tBody), "|", 6), "Alias=|Prompt=", "and empty")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Alias") _ "|" _ $ClassMethod(..#PROBE, "Stored", tName, "Prompt"), "|", "which clears both on the instance")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Alias": "9954"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "an alias sent as text is saved")
    Do $$$AssertEquals($Piece(..Types($ClassMethod(..#RECORD, "LastWriteBody")), "|", 1), "Alias=number", "as an integer")
}

/// <p>The Edit, screen row's error: a key outside the eight -- the name among them -- is refused at
/// 400 with nothing sent, and the agent's schema refuses the same key.</p>
Method TestAnyOtherKeyIsRefusedOnBothCallers()
{
    For tBody = {"Name": (..Name("Other"))}, {"Settings": "x"}, {"Description": "x", "Foo": 1} {
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("Edit"), tBody, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp, 400, tBody.%ToJSON() _ ": refused at 400")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tBody.%ToJSON() _ ": as a field this edit does not take")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tBody.%ToJSON() _ ": and nothing is sent")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), {"Name": (..Name("Edit")), "Settings": "x"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's schema refuses it")
}

/// <p>The Open parameters row on an edit: open parameters the instance cannot parse are refused by the
/// vendor and answered as the form's own refusal on the field; the stored value is unchanged.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Area.OsMgmt.DeviceSave.Update</method>'s
/// <code>PortViolations</code> call -> the edit carries no violation and this goes red.</p>
Method TestUnparsableOpenParametersAreRefusedOnTheirFieldOnAnEdit()
{
    Set tName = ..Name("Edit")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName, "OpenParameters")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"OpenParameters": "((("}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "the edit is refused")
    Do $$$AssertEquals($ClassMethod(..#SHARED, "CodeFor", .tViolations, "OpenParameters"), "DEVICE.OPENPARAMETERS.SHAPE", "on the open parameters, with the form's own code")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "OpenParameters"), tBefore, "and the stored value is unchanged")
}

/// <p>AC4, the Deleted since the read row: the vendor's <code>PUT</code> is an upsert. An edit whose
/// device was deleted since the read is refused on both callers and the device is not re-created: the
/// screen's fresh read answers 404 before anything is sent, and the agent's confirm finds the target
/// changed.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Area.OsMgmt.DeviceSave.Update</method>'s 404 on a fresh
/// read that finds no device -> the screen's edit is sent, the upsert re-creates the device, and this
/// goes red.</p>
Method TestADeletedDeviceIsRefusedAndNotRecreated()
{
    Set tGone = ..Name("Gone")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tGone, {"Description": "x", "PhysicalDevice": "/tmp/p88gone.txt", "Type": "OTH", "SubType": "P-DEC"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "the screen's edit of an absent device is refused")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and nothing is created")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tGone), "a device is created")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tGone, {"Name": (tGone), "Description": "y"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and the agent's edit of it is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tGone), "then it is deleted")
    Set tSC = $ClassMethod(..#SHARED, "ConfirmKey", tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and the device is not re-created")
}

/// <p>Always: the rules read only the fields an edit changes. A device the instance stores with a type
/// outside the six takes an unrelated edit on both callers, while changing the type to another value
/// outside the six is refused; an alias another device holds is refused, and the device's own is
/// not.</p>
/// <p>Mutation (Rule 19): validate the whole body rather than
/// <method>OcuPilot.Area.OsMgmt.DeviceRules.Changed</method>'s fields in
/// <method>OcuPilot.Area.OsMgmt.DeviceSave.Update</method> -> the unrelated edit is refused on the
/// stored type and this goes red.</p>
Method TestTheRulesReadOnlyTheFieldsAnEditChanges()
{
    Set tOdd = ..Name("Odd")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tOdd, {"Type": "ZZZ", "Alias": 9944}), "a device is stored with a type outside the six")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tOdd, {"Description": "fine", "Type": "ZZZ", "Alias": 9944}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's unrelated edit is saved")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tOdd, {"Name": (tOdd), "Description": "fine again"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and the agent's is minted")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tOdd, {"Type": "QQQ"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#SHARED, "CodeFor", .tViolations, "Type"), "DEVICE.TYPE.VALUE", "a changed type outside the six is refused")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("Edit"), {"Alias": 9944}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#SHARED, "CodeFor", .tViolations, "Alias"), "DEVICE.ALIAS.TAKEN", "an alias another device holds is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, ..Name("Edit"), {"Name": (..Name("Edit")), "Alias": "9944"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "on the agent's mint too")
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("Edit"), {"PhysicalDevice": "9955"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#SHARED, "CodeFor", .tViolations, "Alias"), "DEVICE.ALIAS.SAME", "and a physical device name equal to the alias the device keeps is refused")
}

ClassMethod Name(pSuffix As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Name", pSuffix)
}

ClassMethod Normal(pText As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Normal", pText)
}

ClassMethod Types(pText As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Types", pText)
}

ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Quit $ClassMethod(..#SHARED, "Keys", pObject)
}

ClassMethod Sorted(pList As %List) As %String
{
    Quit $ClassMethod(..#SHARED, "Sorted", pList)
}

}
