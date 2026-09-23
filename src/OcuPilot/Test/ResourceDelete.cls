/// <p>Pins Story 8.4's resource delete (AD-6, AD-10, AD-51): what
/// <class>OcuPilot.Screen.Tool.ResourceDelete</class> declares, its two refusals -- a system resource
/// at the mint, OcuPilot's own resources at the write -- its removal rows and fingerprint, and a
/// marked bodyless confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing here
/// deletes a resource; the stock <code>%DB_USER</code> and <code>%Admin_Secure</code> resources are
/// read through the port, never written. No arming variable is required.</p>
Class OcuPilot.Test.ResourceDelete Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ResourceDelete";

Parameter LIST = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name the deletes here propose; nothing on the instance holds it.</p>
Parameter PROBE = "OcuPilotProbeResourceDelete";

/// <p>A system resource every instance holds, whose vendor <code>AllowDelete</code> is false.</p>
Parameter SYSTEMRESOURCE = "%Admin_Secure";

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

/// <p>AD-51, AD-52: the delete is an action-style write over the admin port whose fingerprint
/// subject is the whole of its own read, carrying its precondition, and whose pair set is the
/// screen's own. Its declared read set is measured against the live <code>GET</code> for a stock
/// resource (DW-1475).</p>
/// <p>Mutation: drop <code>PublicPermission</code> from
/// <parameter>OcuPilot.Screen.Tool.ResourceDelete.READANSWERS</parameter> -> the live-read
/// comparison goes red.</p>
Method TestTheDeleteIsAnActionWriteOverTheScreensOwnPairs()
{
    Set tClass = ..#TOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the delete tool by name")
    Do $$$AssertTrue($IsObject(tTool) && (tTool.%Get("class") = tClass), "and answers it by its own class")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.AdminPort", "its target lives behind the admin port")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "SendsBody"), "GET/DELETE/0", "a bodyless delete over the single-object read")
    Do $$$AssertEquals($ClassMethod(tClass, "ChangeAction"), "deleted", "publishing the deleted action")
    Do $$$AssertEquals($ClassMethod(tClass, "Destructive"), 1, "and destructive")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, "it admits no settable field")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Description,PublicPermission", "its fingerprint covers the whole read")
    Do $$$AssertEquals($ClassMethod(tClass, "PreconditionField"), "PublicPermission", "carrying what every user loses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LIST, .tDeclaredResolved)
    Do $$$AssertEquals(tResolved && tDeclaredResolved, 1, "both pair sets resolve")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is the screen's own")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Security.Resource", "DELETE"), "the port admits the pair")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless("Security.Resource", "DELETE"), "as one that reads no body")

    Kill tQuery
    Set tQuery("name") = "%DB_USER"
    Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tReadSC, "the endpoint answers for %DB_USER")
    If '$IsObject($Get(tFresh)) Quit
    Set tKeys = ""
    Set tIterator = tFresh.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListToString(tKeys), $ListToString($ClassMethod(tClass, "ReadAnswers")), "READANSWERS names exactly the keys the live read answers")
}

/// <p>AC2: a resource whose vendor <code>AllowDelete</code> is false is refused at the mint with the
/// published <code>RESOURCE.NAME.SYSTEM</code> sentence, in another case too, before anything is
/// stored; and the list shows that resource not deletable.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.ResourceDelete.ArgumentProblem</method> answer no
/// problem -> the mint proposes the delete and this goes red.</p>
Method TestASystemResourceIsRefusedAtTheMint()
{
    For tName = ..#SYSTEMRESOURCE, $ZConvert(..#SYSTEMRESOURCE, "L") {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson())
        Set tSC = ..Mint(tName, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tName _ ": a system resource is not proposed")
        Do $$$AssertEquals(tHttp, 400, tName _ ": at 400")
        Set tProblem = ..Problem(tFault)
        Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#RESOURCENAMESYSTEM), tName _ ": with the published sentence: " _ tProblem)
    }
    Kill tQuery
    Set tQuery("names") = ..#SYSTEMRESOURCE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list answers")
    If $IsObject($Get(tRows)) && (tRows.%Size() > 0) {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tRows.%Get(0).%Get("AllowDelete"), tRows.%Get(0).%GetTypeOf("AllowDelete")), "false", "and the list's row reads not deletable")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson())
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a resource the list does not call a system resource is proposed")
}

/// <p>AD-10, P2: deleting either of OcuPilot's own resources, in another case, is refused
/// <code>PROHIBITED.OCUPILOTRESOURCE</code> inside the transition, and the list is read from the
/// declarations that create them.</p>
/// <p>Mutation: drop the <code>DELETE</code> leg from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Resource</method> -> both names go red.</p>
Method TestOcuPilotsOwnResourcesAreRefusedAtTheWrite()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotResources(.tOwn)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own resources are read")
    Do $$$AssertEquals($ListToString(tOwn), "%db_ocupilot,ocupilotadmin", "the database and the administrative resource")
    For tName = "%DB_OcuPilot", "OCUPILOTADMIN" {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson())
        Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SETFIXTURE)
        Set tSC = ..Mint(tName, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ ": the mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "OCUPILOTRESOURCE"), tName _ ": the confirm refuses it as OcuPilot's own")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": and nothing is written")
    }
}

/// <p>AD-51: the card's rows are one removal row per subject field, and a confirm after the public
/// permission moved is refused <code>PROPOSAL.TARGETCHANGED</code> with nothing written.</p>
/// <p>Mutation: take <code>PublicPermission</code> out of
/// <parameter>OcuPilot.Screen.Tool.ResourceDelete.FINGERPRINTSUBJECT</parameter> (and the
/// precondition) -> the moved permission is confirmed and this goes red.</p>
Method TestTheRemovalRowsAndAMovedPublicPermissionRefusesTheConfirm()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson())
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is proposed")
    If $$$ISERR(tSC) Quit
    Set tChanged = tProposal.%Get("changed")
    Do $$$AssertEquals(tChanged.%Size(), 2, "two removal rows")
    Set tFields = ""
    Set tIterator = tChanged.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = tFields _ $ListBuild(tRow.%Get("field"))
        Do $$$AssertEquals(tRow.%Get("removed") _ "|" _ tRow.%Get("after"), "1|", tRow.%Get("field") _ " is removed with no after-state")
        If tRow.%Get("field") = "PublicPermission" Do $$$AssertEquals(tRow.%Get("before"), "R", "the permission the instance holds")
    }
    Do $$$AssertEquals($ListToString(tFields), "Description,PublicPermission", "in the subject's order")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing is disclosed as unchanged")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson("RW"))
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a moved permission refuses the confirm")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing written")
}

/// <p>AC5, AD-15, AD-14: a confirmed delete sends a bodyless <code>DELETE</code> naming the
/// resource by its canonical spelling, is marked, and answers the <code>deleted</code> action.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.ResourceDelete.CHANGEACTION</parameter> to
/// <code>updated</code> -> the action assertion goes red.</p>
Method TestAConfirmedDeleteIsMarkedAndSendsNoBody()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..ResourceJson())
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the delete is proposed")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "the answer carries the deleted action")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "DELETE", "the write is the vendor's DELETE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "with no body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), $ZConvert(..#PROBE, "L"), "naming the resource by its canonical spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
}

/// <p>One resource as the vendor's <code>GET</code> shapes it, as compact JSON.</p>
ClassMethod ResourceJson(pPublic As %String = "R") As %String
{
    Set tResource = {"Description": "probe"}
    Do tResource.%Set("PublicPermission", pPublic, "string")
    Quit tResource.%ToJSON()
}

/// <p>Mint one delete of <var>pName</var> through the fixture mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
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

}
