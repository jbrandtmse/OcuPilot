/// <p>Pins Story 8.3's role delete (AD-6, AD-10, AD-51, AD-54): what
/// <class>OcuPilot.Screen.Tool.RoleDelete</class> declares, its three refusals -- a
/// <code>%</code>-prefixed name at the mint, OcuPilot's own roles and the last <code>%All</code>
/// holder's path at the write -- its removal rows and fingerprint, a marked bodyless confirm, and
/// the port's refusal of a vendor delete that did not apply.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class> or to
/// <class>OcuPilot.Test.RoleDeletePort</class>, whose delete never runs, so nothing here deletes a
/// role; the stock <code>%Developer</code> role is read, never written. No arming variable is
/// required.</p>
Class OcuPilot.Test.RoleDelete Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.RoleDelete";

Parameter LIST = "OcuPilot.Screen.Descriptor.RoleList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

/// <p>The shipped prohibited set with its target read and its census seams armable.</p>
Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name the deletes here propose; nothing on the instance holds it.</p>
Parameter PROBEROLE = "OcuPilotProbeRoleDelete";

/// <p>A stock role every instance holds, read and never written.</p>
Parameter STOCKROLE = "%Developer";

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

/// <p>AD-51, AD-52: the delete is an action-style write over the admin port, whose fingerprint
/// subject is the whole of its own read, which carries its precondition field, and whose pair set is
/// the screen's own. Its declared read set is measured against the live <code>GET</code> for a
/// stock role (DW-1475).</p>
/// <p>Mutation: drop <code>Resources</code> from
/// <parameter>OcuPilot.Screen.Tool.RoleDelete.READANSWERS</parameter> -> the registration guard
/// refuses the tool and the live-read comparison goes red.</p>
Method TestTheDeleteIsAnActionWriteOverTheScreensOwnPairs()
{
    Set tClass = ..#TOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the delete tool by name")
    Do $$$AssertTrue($IsObject(tTool) && (tTool.%Get("class") = tClass), "and answers it by its own class")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.AdminPort", "its target lives behind the admin port")
    Do $$$AssertEquals($ClassMethod(tClass, "Endpoint"), "Security.Role", "over the vendor's own role endpoint")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType"), "GET", "its fresh read is the single-object read")
    Do $$$AssertEquals($ClassMethod(tClass, "WriteType"), "DELETE", "and its write the vendor's delete")
    Do $$$AssertEquals($ClassMethod(tClass, "SendsBody"), 0, "it sends no body")
    Do $$$AssertEquals($ClassMethod(tClass, "ChangeAction"), "deleted", "publishes the deleted action")
    Do $$$AssertEquals($ClassMethod(tClass, "Destructive"), 1, "and is destructive")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, "it admits no settable field")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Description,GrantedRoles,EscalationOnly,Resources", "its fingerprint covers the whole read")
    Do $$$AssertEquals($ClassMethod(tClass, "PreconditionField"), "Resources", "carrying the grants every holder loses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LIST, .tDeclaredResolved)
    Do $$$AssertEquals(tResolved && tDeclaredResolved, 1, "both pair sets resolve")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is the screen's own")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Security.Role", "DELETE"), "the port admits the pair")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless("Security.Role", "DELETE"), "as one that reads no body")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsVerifiedDelete("Security.Role", "DELETE"), "and whose answer it verifies")

    Kill tQuery
    Set tQuery("name") = ..#STOCKROLE
    Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tReadSC, "the endpoint answers for " _ ..#STOCKROLE)
    If '$IsObject($Get(tFresh)) Quit
    Set tKeys = ""
    Set tIterator = tFresh.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListToString(tKeys), $ListToString($ClassMethod(tClass, "ReadAnswers")), "READANSWERS names exactly the keys the live read answers")
}

/// <p>A name beginning <code>%</code> is refused at the mint with the published
/// <code>ROLE.NAME.SYSTEM</code> sentence, before anything is stored.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.RoleDelete.ArgumentProblem</method> answer no
/// problem -> the mint proposes the delete and this goes red.</p>
Method TestASystemRoleIsRefusedAtTheMint()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson())
    Set tSC = ..Mint(..#STOCKROLE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a %-prefixed role is not proposed")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Set tProblem = ..Problem(tFault)
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#ROLENAMESYSTEM), "with the published sentence: " _ tProblem)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>AD-10: deleting any of OcuPilot's four own roles is refused inside the transition, under any
/// spelling, and the list is read from the declarations that create them.</p>
/// <p>Mutation: drop the <code>OcuPilotRoles</code> step from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Role</method> -> every name goes red.</p>
Method TestOcuPilotsOwnRolesAreRefusedAtTheWrite()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotRoles(.tOwn)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own roles are read")
    Do $$$AssertEquals($ListToString(tOwn), "ocupilotadmin,ocupilotidentity,ocupilotshell,ocupilotreadiness", "the administrative, identity and two application roles")
    For tName = "OcuPilotAdmin", "OCUPILOTIDENTITY", "ocupilotshell", "OcuPilotReadiness" {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson())
        Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SETFIXTURE)
        Set tSC = ..Mint(tName, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ ": the mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "OCUPILOTROLE"), tName _ ": the confirm refuses it as OcuPilot's own")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": and nothing is written")
    }
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(..#SET, "OCUPILOTROLE"))
    Do $$$AssertNotEquals(tReason, "", "the refusal carries a written sentence")
    Do $$$AssertTrue('($ZConvert(tReason, "L") [ "agent"), "which names no caller")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).Codes(), $Parameter(..#SET, "OCUPILOTROLE")), "and is one of the set's declared codes")
}

/// <p>AD-10: a delete whose census answers "no holder left" is refused inside the transition, and
/// the same delete with the seam disarmed is applied, so the seam is what refused. The shipped
/// census answers 1 for <code>%All</code> itself and 0 for a role that does not reach it.</p>
/// <p>Mutation: drop the <code>DeletingLeavesNoAllHolder</code> step from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Role</method> -> the armed confirm is applied and
/// this goes red.</p>
Method TestTheLastAllHoldersPathIsRefused()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson())
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#SETFIXTURE)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder(1)
    Set tSC = ..Mint(..#PROBEROLE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is proposed")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "LASTALLHOLDER"), "and refused as the last holder's path")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder("")
    Set tSC = ..Mint(..#PROBEROLE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the same delete is proposed again")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and with the census disarmed it is applied")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).DeletingLeavesNoAllHolder("%All", .tLeaves)
    Do $$$AssertStatusOK(tSC, "the shipped census answers")
    Do $$$AssertEquals(tLeaves, 1, "deleting %All itself leaves no holder")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).DeletingLeavesNoAllHolder(..#STOCKROLE, .tLeaves)
    Do $$$AssertEquals(tLeaves, 0, "while a role that does not reach %All changes nobody")
}

/// <p>AD-51: the card's rows are one removal row per subject field, carrying the value the instance
/// holds, and a confirm after the grants moved is refused <code>PROPOSAL.TARGETCHANGED</code> with
/// nothing written.</p>
/// <p>Mutation: take <code>Resources</code> out of
/// <parameter>OcuPilot.Screen.Tool.RoleDelete.FINGERPRINTSUBJECT</parameter> (and the precondition)
/// -> the moved grants are confirmed and this goes red.</p>
Method TestTheRemovalRowsAndAMovedGrantRefusesTheConfirm()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson())
    Set tSC = ..Mint(..#PROBEROLE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is proposed")
    If $$$ISERR(tSC) Quit
    Set tChanged = tProposal.%Get("changed")
    Do $$$AssertEquals(tChanged.%Size(), 4, "four removal rows")
    Set tFields = ""
    Set tIterator = tChanged.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tFields = tFields _ $ListBuild(tRow.%Get("field"))
        Do $$$AssertEquals(tRow.%Get("removed") _ "|" _ tRow.%Get("after"), "1|", tRow.%Get("field") _ " is removed with no after-state")
        If tRow.%Get("field") = "Resources" Do $$$AssertEquals(tRow.%Get("before"), "[{""Name"":""%DB_USER"",""Permissions"":""RW""}]", "the grants the instance holds")
    }
    Do $$$AssertEquals($ListToString(tFields), "Description,GrantedRoles,EscalationOnly,Resources", "in the subject's order")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing is disclosed as unchanged")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson("[{""Name"":""%DB_USER"",""Permissions"":""R""}]"))
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a moved grant refuses the confirm")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing written")
}

/// <p>AD-15, AD-14: a confirmed delete sends a bodyless <code>DELETE</code> naming the role, is
/// marked, and answers the <code>deleted</code> action.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.RoleDelete.CHANGEACTION</parameter> to
/// <code>updated</code> -> the action assertion goes red.</p>
Method TestAConfirmedDeleteIsMarkedAndSendsNoBody()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..RoleJson())
    Set tSC = ..Mint(..#PROBEROLE, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the delete is proposed")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "the answer carries the deleted action")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "DELETE", "the write is the vendor's DELETE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "with no body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), $ZConvert(..#PROBEROLE, "L"), "naming the role by its canonical spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
}

/// <p>AD-27: a <code>Security.Role</code> delete the vendor answers 200 while the role is still
/// there fails <code>PORT.NOTAPPLIED</code> at 500, never a success. The port under test runs the
/// shipped sequence for everything but the delete itself, which it answers as the vendor's no-op
/// drop does.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter> -> the delete
/// reads as made and this goes red.</p>
Method TestAVendorDeleteThatDidNotApplyFailsNotApplied()
{
    Kill tQuery
    Set tQuery("name") = ..#STOCKROLE
    Set tSC = ##class(OcuPilot.Test.RoleDeletePort).Invoke("Security.Role", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a delete whose role is still present is not a success")
    Do $$$AssertEquals(tHttp, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, "as PORT.NOTAPPLIED")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, "with its published sentence")
    Kill tQuery
    Set tQuery("name") = ..#STOCKROLE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and the stock role is untouched")
}

/// <p>One role as the vendor's <code>GET</code> shapes it, as compact JSON, with
/// <var>pResources</var> as its grants.</p>
ClassMethod RoleJson(pResources As %String = "[{""Name"":""%DB_USER"",""Permissions"":""RW""}]") As %String
{
    Set tRole = {"Description": "probe", "GrantedRoles": ["%Developer"]}
    Do tRole.%Set("EscalationOnly", 0, "boolean")
    Do tRole.%Set("Resources", ##class(%DynamicAbstractObject).%FromJSON(pResources))
    Quit tRole.%ToJSON()
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
