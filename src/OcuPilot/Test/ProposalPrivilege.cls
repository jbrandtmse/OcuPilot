/// <p>Pins the proposal's privilege line on the instance (Story 11.8, AD-8): the pair set a mint
/// records is the one the write's own gate resolves, the wire row carries it with the first pair the
/// owner lacks, and a row with no readable set carries <code>null</code>.</p>
/// <p><b>What it needs from the environment:</b> an account holding <code>%All</code>, OcuPilot's
/// protected state, and the demo application <parameter>DEMOAPP</parameter> the container's opt-in
/// fixture creates. It writes to the instance only its own proposal rows and the fault lines an
/// unrecorded set logs; it arms nothing and creates no principal.</p>
Class OcuPilot.Test.ProposalPrivilege Extends %UnitTest.TestCase
{

Parameter DEMOAPP = "/csp/myapp";

Parameter WEBAPPTOOL = "OcuPilot.Screen.Tool.WebAppUpdate";

Parameter PROBEUSER = "OcuPilotProbeProposalPrivilege";

Parameter HOLDER = "OcuPilot.Test.PrivilegeHolderProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertStatusOK(tSC, "the proposals minted on seeded turns are removed")
    Do $$$AssertEquals(tSeeded, 0, "and none survives")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>(a) A mint records the set <method>OcuPilot.Kernel.Proposal.Operation.RequiredPairsOf</method>
/// answers over the stored arguments, and the turn's wire row carries it in order with nothing
/// missing for an owner who holds it.</p>
Method TestAMintRecordsTheGatesPairsAndTheWireCarriesThem()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn), "a turn is seeded")
    Set tToolClass = ..#WEBAPPTOOL
    Set tArgs = {}
    Do tArgs.%Set(##class(OcuPilot.Screen.Tool.Write).IdArgument(), ..#DEMOAPP, "string")
    Do tArgs.%Set("Enabled", 1, "boolean")
    Do tArgs.%Set("Resource", "%Development", "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tToolClass, "DESCRIPTORCLASS"), $Parameter(tToolClass, "TOOLNAME"), $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tToolClass, "Endpoint"), ##class(OcuPilot.Screen.Tool.Write).IdParam(), ..#DEMOAPP, ##class(OcuPilot.Screen.Tool.Write).IdArgument(), $ClassMethod(tToolClass, "SettableFields"))
    Do $$$AssertStatusOK(tSC, "the demo application's update is minted")
    If '$IsObject($Get(tProposal)) Quit
    Set tKey = tProposal.%Get("proposalId")

    Set tStored = ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "RequiredPairs")
    Set tRow = ##class(OcuPilot.Kernel.State.Propose).ProposalKeyIdxOpen(tKey)
    Do $$$AssertTrue($IsObject(tRow), "the minted row is opened")
    If '$IsObject(tRow) Quit
    Set tArguments = tRow.Arguments.Read()
    Set tRow = ""
    Set tResolveSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tToolClass, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tResolveSC, "the tool resolves")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Operation).RequiredPairsOf(tTool, tArguments, .tPairs), "its gate's pairs resolve over the stored arguments")
    Set tExpected = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tSpelled = $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        If '$ListFind($ListFromString(tExpected), tSpelled) Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ tSpelled
    }
    Do $$$AssertTrue(tExpected '= "", "the gate requires at least one pair")
    Do $$$AssertEquals(tStored, tExpected, "the stored set is the gate's own, de-duplicated in order")
    Do $$$AssertTrue($ListFind($ListFromString(tStored), "%Admin_Secure:USE") > 0, "and it names %Admin_Secure:USE")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, $Username, .tRows), "the turn's proposals are read")
    Do $$$AssertEquals(tRows.%Size(), 1, "one row comes back")
    Set tPrivilege = tRows.%Get(0).%Get("privilege")
    Do $$$AssertTrue($IsObject(tPrivilege), "the wire row carries a privilege object")
    If '$IsObject(tPrivilege) Quit
    Set tRequires = ""
    Set tIterator = tPrivilege.%Get("requires").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPair) {
        Set tRequires = tRequires _ $Select(tRequires = "": "", 1: ",") _ tPair
    }
    Do $$$AssertEquals(tRequires, tStored, "requires is the recorded set, in order")
    Do $$$AssertEquals(tPrivilege.%Get("missing"), "", "and the owner, who holds %All, lacks none of it")
}

/// <p>(b) The set carries a tool's extra pairs and its argument pairs.</p>
Method TestTheSetCarriesExtraAndArgumentPairs()
{
    For tName = "osmgmt.devices.create", "osmgmt.devices.update", "osmgmt.devices.delete" {
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool), tName _ " resolves")
        Do $$$AssertTrue($IsObject(tTool), tName _ " is a registered tool")
        If '$IsObject(tTool) Continue
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Operation).RequiredPairsOf(tTool, "{}", .tPairs), tName _ ": its pairs resolve")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")) > 0, tName _ ": the set includes %DB_IRISSYS:WRITE")
    }

    Set tName = "logs.applicationerrors.delete"
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool), tName _ " resolves")
    Do $$$AssertTrue($IsObject(tTool), tName _ " is a registered tool")
    If '$IsObject(tTool) Quit
    Set tArgs = {}
    Do tArgs.%Set("namespace", $Namespace, "string")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Operation).RequiredPairsOf(tTool, tArgs.%ToJSON(), .tPairs), tName _ ": its pairs resolve for " _ $Namespace)
    Set tAdded = ##class(OcuPilot.Port.LogSourcePort).PairsFor(##class(OcuPilot.Port.LogSourcePort).#ERRORSKEY, $Namespace)
    Do $$$AssertTrue($ListLength(tAdded) > 0, tName _ ": the port resolves pairs for " _ $Namespace)
    For tI = 1:1:$ListLength(tAdded) {
        Set tPair = $List(tAdded, tI)
        Do $$$AssertTrue($ListFind(tPairs, tPair) > 0, tName _ ": the set includes " _ $List(tPair, 1) _ ":" _ $List(tPair, 2))
    }
}

/// <p>(c) The missing pair is the first one the holder's check refuses, and none when every pair is
/// held.</p>
Method TestMissingNamesTheFirstPairNotHeld()
{
    Set tHeld = "%Admin_Secure:USE"
    Set tNotHeld = $Parameter(..#HOLDER, "NOTHELD") _ ":USE"
    Set tPrivilege = ##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege(tHeld _ "," _ tNotHeld, $Username, ..#HOLDER)
    Do $$$AssertTrue($IsObject(tPrivilege), "a readable set answers an object")
    If '$IsObject(tPrivilege) Quit
    Do $$$AssertEquals(tPrivilege.%Get("requires").%Size(), 2, "requires lists both pairs")
    Do $$$AssertEquals(tPrivilege.%Get("requires").%Get(0), tHeld, "in recorded order")
    Do $$$AssertEquals(tPrivilege.%Get("missing"), tNotHeld, "missing names the pair not held")

    Set tPrivilege = ##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege(tHeld, $Username, ..#HOLDER)
    Do $$$AssertTrue($IsObject(tPrivilege), "the held set answers an object")
    If '$IsObject(tPrivilege) Quit
    Do $$$AssertEquals(tPrivilege.%Get("missing"), "", "and nothing is missing")
}

/// <p>(d) A row with no recorded set, and one whose stored set is malformed, carries
/// <code>privilege</code> as <code>null</code>.</p>
Method TestARowWithNoReadableSetCarriesNull()
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotprobeprivilege", .tTarget)
    For tCase = 1, 2 {
        Kill tValues
        Set tValues("user") = ..#PROBEUSER
        Set tValues("convKey") = "probe-privilege-conv"
        Set tValues("turnKey") = "probe-privilege-turn-" _ tCase
        Set tValues("toolName") = "webapp.list.update"
        Set tValues("targetRef") = tTarget
        Set tValues("fingerprint") = "0"
        Set tValues("arguments") = "{}"
        Set tValues("payload") = "{}"
        Set tValues("diff") = "[]"
        Set tValues("unchangedCount") = 0
        If tCase = 2 Set tValues("requiredPairs") = "%Admin_Secure:USE,malformed"
        Set tLabel = $Select(tCase = 1: "a row minted with no set", 1: "a row whose stored set is malformed")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken), tLabel _ " is seeded")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "RequiredPairs"), $Get(tValues("requiredPairs")), tLabel _ ": the stored set is the one seeded")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tValues("turnKey"), ..#PROBEUSER, .tRows), tLabel _ ": its turn is read")
        Do $$$AssertEquals(tRows.%Size(), 1, tLabel _ ": one row comes back")
        If tRows.%Size() '= 1 Continue
        Do $$$AssertEquals(tRows.%Get(0).%GetTypeOf("privilege"), "null", tLabel _ " carries privilege as null")
    }
}

/// <p>(e) A mint records a resolved tool's set with its argument pairs, and records none for a tool
/// that does not resolve or a set longer than the store's column.</p>
Method TestAnUnresolvedOrOverlongSetRecordsNone()
{
    Set tResolved = ##class(OcuPilot.Kernel.Proposal.Mint).RecordedPairs($Parameter(..#WEBAPPTOOL, "TOOLNAME"), "{}")
    Do $$$AssertTrue($Length(tResolved) > 8, "a registered tool records its set: " _ tResolved)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).RecordedPairs("probe.privilege.unregistered", "{}"), "", "an unregistered tool records none")
    Do $$$AssertEquals(##class(OcuPilot.Test.PrivilegeMintProbe).RecordedPairs($Parameter(..#WEBAPPTOOL, "TOOLNAME"), "{}"), "", "a set longer than the column records none")

    Set tArgs = {}
    Do tArgs.%Set("namespace", $Namespace, "string")
    Set tRecorded = $ListFromString(##class(OcuPilot.Kernel.Proposal.Mint).RecordedPairs("logs.applicationerrors.delete", tArgs.%ToJSON()))
    Set tAdded = ##class(OcuPilot.Port.LogSourcePort).PairsFor(##class(OcuPilot.Port.LogSourcePort).#ERRORSKEY, $Namespace)
    Do $$$AssertTrue($ListLength(tAdded) > 0, "the port resolves pairs for " _ $Namespace)
    For tI = 1:1:$ListLength(tAdded) {
        Set tSpelled = $List($List(tAdded, tI), 1) _ ":" _ $List($List(tAdded, tI), 2)
        Do $$$AssertTrue($ListFind(tRecorded, tSpelled) > 0, "the recorded set carries the argument pair " _ tSpelled)
    }
}

}
