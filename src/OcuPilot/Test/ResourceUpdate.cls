/// <p>Pins Story 8.4's resource edit (AD-4, AD-6, AD-10, AD-27, AD-55): what
/// <class>OcuPilot.Screen.Tool.ResourceUpdate</class> declares, AC3's merge on both callers, the field
/// rules and the edit route's own refusals, a privileged public permission marked, an added public
/// letter on OcuPilot's own resources refused on both callers, and the port's refusal of a vendor
/// write that did not apply (<parameter>OcuPilot.Port.AdminPort.VERIFIEDWRITES</parameter>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class> or to
/// <class>OcuPilot.Test.ResourceWritePort</class>, whose write never runs, so nothing here changes a
/// resource; the stock <code>%DB_USER</code> resource is read, never written. No arming variable is
/// required.</p>
Class OcuPilot.Test.ResourceUpdate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ResourceUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.ResourceFixture";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

/// <p>The shipped prohibited set with its target read replaced by the fixture's armed object.</p>
Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name the edits here propose; the fixture answers for it.</p>
Parameter PROBE = "OcuPilotProbeResourceUpdate";

Parameter PRIVILEGEDPROBE = "%Admin_OcuPilotProbe";

/// <p>A stock resource every instance holds, read and never written.</p>
Parameter STOCK = "%DB_USER";

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
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-4, AD-8, AD-55: the edit is a merge write -- a <code>GET</code> read, a <code>PUT</code>
/// that sends a body -- over the screen's own pairs, whose settable set is the prohibited set's
/// reviewed change list for a resource, and whose declared read set the live <code>GET</code>
/// answers.</p>
/// <p>Mutation: drop <code>PublicPermission</code> from
/// <parameter>OcuPilot.Screen.Tool.ResourceUpdate.PERMITTEDFIELDS</parameter> -> the settable-set
/// assertion goes red.</p>
Method TestTheUpdateIsAMergeWriteOverTheScreensOwnPairs()
{
    Set tClass = ..#TOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the edit tool by name")
    Do $$$AssertTrue($IsObject(tTool) && (tTool.%Get("class") = tClass), "and answers it by its own class")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "SendsBody"), "GET/PUT/1", "a merge write")
    Do $$$AssertEquals($ClassMethod(tClass, "Creates"), 0, "over a present resource")
    Do $$$AssertEquals($ClassMethod(tClass, "ChangeAction"), "updated", "publishing the updated action")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "", "fingerprinted over the whole body")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $ListToString($ClassMethod(..#SET, "PermittedChangeFields", "resource")), "the settable set is the prohibited set's reviewed change list")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LIST, .tDeclaredResolved)
    Do $$$AssertEquals(tResolved && tDeclaredResolved, 1, "both pair sets resolve")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is the screen's own")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Security.Resource", "PUT"), "the port admits the write")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsVerifiedWrite("Security.Resource", "PUT"), "as one whose answer it verifies")

    Kill tQuery
    Set tQuery("name") = ..#STOCK
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the endpoint answers for " _ ..#STOCK)
    If '$IsObject($Get(tFresh)) Quit
    Set tKeys = ""
    Set tIterator = tFresh.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListToString(tKeys), "Description,PublicPermission", "the live read answers exactly the two fields the edit carries")
}

/// <p>AC3 on both callers: a Description-only edit sends the complete property set from the fresh
/// read, so a <code>PublicPermission</code> of <code>W</code> the instance holds survives, and the
/// screen and the confirm send the identical body.</p>
/// <p>Mutation: send the caller's fields without <method>OcuPilot.Kernel.Proposal.Mint.Merge</method>
/// in <method>OcuPilot.Area.Permissions.ResourceSave.Update</method> -> the screen body loses
/// <code>PublicPermission</code> and this goes red.</p>
Method TestAnEditKeepsTheFieldTheCallerDidNotChangeOnBothCallers()
{
    Set tFresh = ..Fresh("old", "W")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh)
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"Description": "new"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen accepts the edit")
    Set tScreenBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(tScreenBody, "{""Description"":""new"",""PublicPermission"":""W""}", "the screen sends the fresh read with the edit applied")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), ..#PROBE, "naming the resource in the query parameter")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh)
    Set tSC = ..Mint(..#PROBE, {"Name": (..#PROBE), "Description": "new"}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent mints the same edit")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "one changed row")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 1, "and one unchanged field disclosed")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), tScreenBody, "the confirm sends the identical complete body")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "updated", "answering the updated action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
}

/// <p>AD-55: the edit's field rules refuse on both callers; a key outside the two is 400 and a
/// resource the instance does not hold is 404 on the screen, with nothing sent.</p>
/// <p>Mutation: drop the <code>EDITFIELDS</code> check from
/// <method>OcuPilot.Area.Permissions.ResourceSave.Update</method> -> the unexpected-key leg goes
/// red.</p>
Method TestTheEditRulesRefuseOnBothCallers()
{
    For tCase = 1:1:3 {
        Set tName = ..#PROBE
        If tCase = 1 Set tArgs = {"Description": ($Translate($Justify("", 257), " ", "d"))}, tField = "Description", tCode = "RESOURCEDESCRIPTIONLENGTH"
        If tCase = 2 Set tArgs = {"PublicPermission": "Q"}, tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONSHAPE"
        If tCase = 3 Set tName = "%DB_OcuPilotProbe", tArgs = {"PublicPermission": "U"}, tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONLETTERS"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("old", ""))
        Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tField), tExpected, "case " _ tCase _ ": the screen refuses on " _ tField)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "case " _ tCase _ ": and nothing reaches the port")
        Do tArgs.%Set("Name", tName, "string")
        Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "case " _ tCase _ ": the agent's mint refuses it at 400")
        Do $$$AssertTrue(..Problem(tFault) [ ##class(OcuPilot.Api.Error).ReasonForViolation(tExpected), "case " _ tCase _ ": with the same sentence")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("old", ""))
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"Description": "new", "Type": 0}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "a key outside the two is refused at 400")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).CallCount(), 0, "before the port is touched")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"Description": "new"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp, 404, "an absent resource is 404")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>AC6, AD-10: a public permission that adds a letter on an administrative resource is minted
/// destructive with the privilege-grant consequence and applied on the screen; removing the letter
/// is neither.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>'s
/// <code>resource</code> branch answer 0 -> the first leg goes red.</p>
Method TestAPrivilegedPublicPermissionIsMarkedOnTheAgentsEdit()
{
    Set tCodePrivileged = $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("probe", ""))
    Set tSC = ..Mint(..#PRIVILEGEDPROBE, {"Name": (..#PRIVILEGEDPROBE), "PublicPermission": "U"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "adding Use on an administrative resource is proposed")
    If $$$ISOK(tSC) {
        Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ tCodePrivileged, "destructive, naming the privilege")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("probe", "U"))
    Set tSC = ..Mint(..#PRIVILEGEDPROBE, {"Name": (..#PRIVILEGEDPROBE), "PublicPermission": ""}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "removing it is proposed")
    If $$$ISOK(tSC) {
        Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "and grants nothing")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("probe", ""))
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PRIVILEGEDPROBE, {"PublicPermission": "U"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's Save applies it")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "at the port")
}

/// <p>AD-10, P2: an edit that adds a public-permission letter to one of OcuPilot's own resources is
/// refused <code>PROHIBITED.OCUPILOTRESOURCE</code> on the screen and inside the agent's confirm, for
/// both names in another case; a Description-only edit of one is permitted.</p>
/// <p>Mutation: drop the added-letter test from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Resource</method> -> both callers go red.</p>
Method TestAnAddedPublicLetterOnOcuPilotsOwnResourceIsRefusedOnBothCallers()
{
    Set tCode = $Parameter(..#SET, "OCUPILOTRESOURCE")
    For tName = $ZConvert(##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "L"), $ZConvert(##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE, "U") {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("own", ""))
        Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"PublicPermission": "R"}, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ tCode, tName _ ": the screen refuses it")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": and nothing reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh("own", ""))
        Set tSC = ..Mint(tName, {"Name": (tName), "PublicPermission": "R"}, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ ": the mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SETFIXTURE)
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode2, .tResult)
        Do $$$AssertEquals(tHttp _ " " _ tCode2, "403 " _ tCode, tName _ ": the confirm refuses it inside the transition")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": with no write")

        Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", ..Fresh("own", ""), ..Fresh("renamed", ""), $ClassMethod(..#SETFIXTURE, "Diff", "Description"), tName, "resource", .tProhibits, .tOut, $Parameter(..#TOOL, "TOOLNAME"))
        Do $$$AssertStatusOK(tSC, tName _ ": the set answers a Description-only edit")
        Do $$$AssertEquals(tProhibits, 0, tName _ ": and permits it, code was '" _ tOut _ "'")
    }
}

/// <p>AD-27: a <code>Security.Resource</code> write the vendor answers 200 whose re-read does not
/// carry the sent value fails <code>PORT.NOTAPPLIED</code> at 500, never a success; a write whose
/// re-read carries it succeeds. Letters read back in another order are
/// <class>OcuPilot.Test.ResourceWire</class>'s leg, on a probe that holds two.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Port.AdminPort.VERIFIEDWRITES</parameter> -> the write
/// reads as made and this goes red.</p>
Method TestAVendorWriteThatDidNotApplyFailsNotApplied()
{
    Kill tQuery
    Set tQuery("name") = ..#STOCK
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "GET", .tQuery, "", .tBefore, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the stock resource reads")
    If '$IsObject($Get(tBefore)) Quit

    Set tSent = {"Description": "OcuPilot write probe that never runs", "PublicPermission": (tBefore.%Get("PublicPermission"))}
    Set tSC = ##class(OcuPilot.Test.ResourceWritePort).Invoke("Security.Resource", "PUT", .tQuery, tSent, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a write whose value did not read back is not a success")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, "as PORT.NOTAPPLIED")

    Set tSame = {"Description": (tBefore.%Get("Description")), "PublicPermission": (tBefore.%Get("PublicPermission"))}
    Set tSC = ##class(OcuPilot.Test.ResourceWritePort).Invoke("Security.Resource", "PUT", .tQuery, tSame, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a write whose values read back succeeds")

    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "GET", .tQuery, "", .tAfter, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%ToJSON(), 1: ""), tBefore.%ToJSON(), "and the stock resource is untouched")
}

/// <p>One resource as the vendor's <code>GET</code> shapes it, as compact JSON.</p>
ClassMethod Fresh(pDescription As %String, pPublic As %String) As %String
{
    Set tResource = {}
    Do tResource.%Set("Description", pDescription, "string")
    Do tResource.%Set("PublicPermission", pPublic, "string")
    Quit tResource.%ToJSON()
}

/// <p>The stored proposal <var>pKey</var>'s destructive marking and consequence code.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = $ClassMethod("OcuPilot.Kernel.State.Propose", "GuardedByKey", pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>Mint one edit of <var>pName</var> through the fixture mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The problem a 400 <code>TOOL.ARGUMENTS</code> refusal carries, or <code>""</code>.</p>
ClassMethod Problem(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.%Get("detail")) Quit ""
    Quit pFault.%Get("detail").%Get("problem")
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

}
