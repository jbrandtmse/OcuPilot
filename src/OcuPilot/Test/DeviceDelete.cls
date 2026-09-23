/// <p>Pins Story 8.8's agent device delete (AD-6, AD-51, AD-52): what
/// <class>OcuPilot.Screen.Tool.DeviceDelete</class> declares, the card's removal rows and a confirmed,
/// marked delete, a device changed or deleted since the mint refusing the confirm, a name the instance does not
/// hold refused at the mint, and a vendor delete that left the device read as not applied.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and an account holding
/// <code>%Admin_Manage</code>. Every write reaches the instance through
/// <class>OcuPilot.Test.DeviceRecordPort</class>; every device it creates is named with
/// <parameter>OcuPilot.Test.DeviceProbe.PREFIX</parameter> and removed by exact name.</p>
Class OcuPilot.Test.DeviceDelete Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.DeviceDelete";

Parameter RECORD = "OcuPilot.Test.DeviceRecordPort";

Parameter PROBE = "OcuPilot.Test.DeviceProbe";

/// <p>The create suite, whose helpers this class shares.</p>
Parameter SHARED = "OcuPilot.Test.DeviceCreate";

/// <p>The eight fields in the classic page's order: the removal rows and the fingerprint subject.</p>
Parameter FIELDS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Add", ..Name("Del"), {"Description": "gone soon", "Alias": 9933, "Prompt": 1})
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

/// <p>AD-51: an action-style, destructive write -- the vendor's <code>GET</code> read and bodyless
/// <code>DELETE</code> -- advertising the name and the agent's own words, fingerprinted over all eight
/// fields its read answers with the physical device name as the precondition, over the list's own
/// pairs.</p>
Method TestTheDeleteIsAnActionWriteOverTheWholeRead()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals($ClassMethod(..#SHARED, "Keys", tSchema.%Get("properties")), "Name,expectedImpact,rationale,reverse", "the schema is the name and the agent's own words")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "SettableFields"), "", "admitting no field")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "ChangeAction") _ " " _ $ClassMethod(..#TOOL, "Destructive"), "GET DELETE 0 deleted 1", "a bodyless, destructive delete publishing deleted")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), ..#FIELDS, "fingerprinted over the eight fields")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PreconditionField"), "PhysicalDevice", "with the physical device name as its precondition")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "PrivilegePairs")), $ListToString($ClassMethod("OcuPilot.Screen.Descriptor.DeviceList", "PrivilegePairs") _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))), "requiring the list's own pairs and the system database write")
}

/// <p>The Agent delete row, AC2's delete: the proposal is destructive and its card lists the eight
/// fields the device loses, with the values the instance holds; the confirm issues the bodyless
/// <code>DELETE</code>, the device is gone, the write is marked and the answer carries the deleted
/// action.</p>
Method TestTheCardListsWhatGoesAndAConfirmDeletes()
{
    Set tName = ..Name("Del")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ">" _ tRow.%Get("after") _ $Select(tRow.%Get("removed"): "!", 1: ""))
    }
    Do $$$AssertEquals($ListToString(tRows, "|"), "PhysicalDevice=/tmp/" _ tName _ ".txt>!|Type=OTH>!|SubType=P-DEC>!|OpenParameters=>!|Description=gone soon>!|Alias=9933>!|AlternateDevice=>!|Prompt=1>!", "one removal row per field, in the classic page's order")
    Set tFound = 0
    Set tSC = $ClassMethod("OcuPilot.Kernel.State.Propose", "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the stored proposal is read")
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "and is destructive")

    Set tSC = $ClassMethod(..#SHARED, "ConfirmKey", tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "the delete is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastName") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "DELETE " _ tName _ " ", "the write is the vendor's DELETE, naming the device, with no body")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and the device is gone")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "the answer carries the deleted action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
}

/// <p>The Agent delete row's refusal: a device changed since the mint -- here only its description --
/// refuses the confirm as the target having changed, and nothing is deleted.</p>
/// <p>Mutation (Rule 19): narrow <parameter>OcuPilot.Screen.Tool.DeviceDelete.FINGERPRINTSUBJECT</parameter>
/// to <code>PhysicalDevice</code> -> the confirm deletes the changed device and this goes red.</p>
Method TestADeviceChangedSinceTheMintRefusesTheConfirm()
{
    Set tName = ..Name("Del")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(..Modify(tName, "Description", "changed by someone else"), "then somebody changes the description")
    Set tSC = $ClassMethod(..#SHARED, "ConfirmKey", tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the device is still there")
}

/// <p>The Agent delete row's refusal of a device deleted since the mint: the confirm's re-read finds
/// no device and refuses as the target having changed, and no <code>DELETE</code> reaches the port.</p>
/// <p>Mutation (Rule 19): disable <class>OcuPilot.Kernel.Proposal.Confirm</class>'s refusal of a
/// fingerprint that does not match, in the container only -> the confirm sends the
/// <code>DELETE</code> and this goes red.</p>
Method TestADeviceDeletedSinceTheMintRefusesTheConfirm()
{
    Set tName = ..Name("Del")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), "then somebody deletes the device")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SHARED, "ConfirmKey", tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertTrue($ClassMethod(..#RECORD, "CallTypes") '[ "DELETE", "no DELETE reaches the port: " _ $ClassMethod(..#RECORD, "CallTypes"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and the device stays absent")
}

/// <p>The Agent delete row's other refusal, and the orchestrator's pin: a name the instance does not
/// hold -- a device that does not exist, or one differing only in case from one that does -- is
/// refused at the mint at 400 <code>TOOL.ARGUMENTS</code>, naming it, and nothing is stored or
/// sent.</p>
/// <p>Mutation (Rule 19): remove <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>'s refusal of a
/// target that is not present -> the mint answers otherwise and this goes red.</p>
Method TestAnUnknownNameIsRefusedAtTheMint()
{
    For tName = ..Name("NoSuchDevice"), ..Name("del") {
        Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#TOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tName _ ": the mint is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", tName _ ": at 400 as the arguments")
        Do $$$AssertTrue($ClassMethod(..#SHARED, "Problem", $Get(tFault)) [ ("'" _ tName _ "' is not present"), tName _ ": naming the device it did not find")
        Do $$$AssertEquals($IsObject($Get(tProposal)), 0, tName _ ": and no proposal is answered")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("Del")), 1, "and the device whose name differs only in case is untouched")
}

/// <p>AD-27, <parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>: a
/// <code>Device.Standard</code> delete the vendor answers 200 while the device is still there fails
/// <code>PORT.NOTAPPLIED</code> at 500, never a success. The port under test answers the delete
/// without running the vendor and runs the verifying re-read against the instance.</p>
/// <p>Mutation (Rule 19): remove <code>Device.Standard/DELETE</code> from
/// <parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter> -> the delete reads as made and this
/// goes red.</p>
Method TestAReportedDeleteThatLeftTheDeviceIsNotApplied()
{
    Kill tQuery
    Set tQuery("name") = ..Name("Del")
    Set tSC = ##class(OcuPilot.Test.RoleDeletePort).Invoke("Device.Standard", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a delete whose device is still present is not a success")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, "as PORT.NOTAPPLIED")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("Del")), 1, "and the device is still there")
}

/// <p>Set <var>pProperty</var> of the probe device <var>pName</var> to <var>pValue</var> through the
/// vendor class, as another administrator would.</p>
ClassMethod Modify(pName As %String, pProperty As %String, pValue As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties(pProperty) = pValue
        Set tSC = ##class(Config.Devices).Modify(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

ClassMethod Name(pSuffix As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Name", pSuffix)
}

}
