/// <p>Pins the agent's Screen permissions proposals in process (Story 20.18, AD-6, AD-10, AD-15, AD-34, AD-51,
/// AD-58, AD-64; DW-2181): <code>agent.screenpermissions.addpair</code>, <code>.removepair</code> and
/// <code>.reset</code> called through the dispatcher on a seeded turn mint a card whose one <code>Pairs</code>
/// row reads the set before and after; a proposal whose resulting set lacks a pair the stored set holds is
/// minted destructive with consequence <code>SCREENACCESS.LOWERED</code> and any other is not; each confirm
/// changes the store, answers the read-back its tool declares, and leaves one <code>SecurityChange</code> row
/// and one agent marker.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It adjusts <code>osmgmt.locks</code> and
/// removes every screen adjustment before and after each test, snapshots the stored governance policy and puts
/// it back, and removes the proposals and turns it seeded. It creates no principal.</p>
Class OcuPilot.Test.ScreenAccessAgent Extends %UnitTest.TestCase
{

Parameter SCREEN = "osmgmt.locks";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter ADDTOOL = "agent.screenpermissions.addpair";

Parameter REMOVETOOL = "agent.screenpermissions.removepair";

Parameter RESETTOOL = "agent.screenpermissions.reset";

/// <p>The pair a raise adds.</p>
Parameter RAISED = "%Admin_Secure:USE";

/// <p>The pair a lowering removes.</p>
Parameter LOWERED = "%DB_IRISSYS:READ";

/// <p>Locks' stored set once raised.</p>
Parameter RAISEDSET = "%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Secure:USE";

/// <p>Locks' stored set once lowered.</p>
Parameter LOWEREDSET = "%Admin_Operate:USE";

Property StoredPolicy [ MultiDimensional ];

/// <p>The seeded turns' keys, so their ledger rows are removed after the test.</p>
Property PreparedTurns As %List;

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set ..PreparedTurns = ""
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded(), "every screen adjustment is removed")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    For tI = 1:1:$ListLength(..PreparedTurns) Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($List(..PreparedTurns, tI))
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The agent's call of <var>pTool</var> for <var>pPair</var> on <parameter>SCREEN</parameter>, through the
/// dispatcher on a seeded turn: <var>pContent</var> is the answer's content parsed, <var>pIsError</var> its
/// error flag.</p>
Method Dispatch(pTool As %String, pPair As %String, Output pContent, Output pIsError As %Boolean, Output pTurn As %String) As %Status
{
    Set pContent = ""
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTurns = ..PreparedTurns _ $ListBuild(pTurn)
    Set tUse = {"type": "tool_use", "id": "toolu_screenaccess", "input": {"Screen": (..#SCREEN), "rationale": "probe", "expectedImpact": "probe"}}
    If pPair '= "" Do tUse.input.%Set("Pair", pPair, "string")
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurn, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set pIsError = ''tResults.%Get(0).%Get("is_error")
    Try { Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tResults.%Get(0).%Get("content")) } Catch { Set pContent = tResults.%Get(0).%Get("content") }
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> in process as the running account.</p>
ClassMethod ConfirmIn(pProposal As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Quit ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>Store <parameter>SCREEN</parameter>'s adjustment as <var>pSpec</var>, comma-separated.</p>
ClassMethod Adjust(pSpec As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Access).GuardedPut(..#SCREEN, pSpec, 0, $Username)
}

/// <p>The stored adjustment of <parameter>SCREEN</parameter>, or <code>""</code> when it has none.</p>
ClassMethod Stored() As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Access).GuardedGet(..#SCREEN, .tPairs, .tVersion, .tFound)
    Quit $Select($$$ISOK(tSC) && tFound: tPairs, 1: "")
}

/// <p>The proposal's stored <code>destructive</code> and <code>consequence</code>, joined by a bar.</p>
ClassMethod Treatment(pContent As %DynamicObject) As %String
{
    If '$IsObject(pContent) Quit "<none>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pContent.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit "<absent>"
    Quit +$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence"))
}

/// <p>The card's "requires" line for the stored proposal, as JSON: the pairs it recorded, spelled by
/// <class>OcuPilot.Kernel.Proposal.Disclosure</class>.</p>
ClassMethod Requires(pContent As %DynamicObject) As %String
{
    If '$IsObject(pContent) Quit "<none>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pContent.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit "<absent>"
    Set tPrivilege = ##class(OcuPilot.Kernel.Proposal.Disclosure).Privilege($Get(tValues("requiredPairs")), $Username)
    Quit $Select($IsObject(tPrivilege): tPrivilege.requires.%ToJSON(), 1: "<no privilege line>")
}

/// <p>The card's <code>Pairs</code> row as <code>before -&gt; after</code>, or <code>""</code>.</p>
ClassMethod PairsRow(pContent As %DynamicObject) As %String
{
    If '$IsObject(pContent) || '$IsObject(pContent.%Get("changed")) Quit ""
    Set tIterator = pContent.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.field = "Pairs" Quit
    }
    Quit $Select($IsObject($Get(tRow)): tRow.before _ " -> " _ tRow.after, 1: "")
}

/// <p>The effective set <parameter>SCREEN</parameter> requires now, comma-separated.</p>
ClassMethod Effective() As %String
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#SCREEN), .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ##class(OcuPilot.Screen.Gate).SpellPair($List(tPair, 1), $List(tPair, 2))
    }
    Quit tText
}

/// <p>Raise: an add-pair mints one <code>Pairs</code> row, is not destructive and names no consequence, and its
/// card requires the either-of the Screen permissions screen declares. The confirm stores the new set, reads
/// back <code>nothingSent</code>, and leaves one <code>SecurityChange</code> row and one agent marker.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.LowersScreenPermission</method>
/// answer 1 -- the treatment leg goes red.</p>
Method TestARaiseIsMintedPlainAndConfirmed()
{
    Set tSC = ..Dispatch(..#ADDTOOL, ..#RAISED, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the add-pair mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..PairsRow(tContent), "%Admin_Operate:USE, %DB_IRISSYS:READ -> %Admin_Operate:USE, %DB_IRISSYS:READ, " _ ..#RAISED, "its one Pairs row reads before and after")
    Do $$$AssertEquals(tContent.changed.%Size(), 1, "and it is the only row")
    Do $$$AssertEquals(..Treatment(tContent), "0|", "a raise is not destructive and names no consequence")
    Do $$$AssertEquals(..Requires(tContent), "[""%Development:USE or %Admin_Secure:USE""]", "the card requires the either-of")
    Do $$$AssertEquals(..Stored(), "", "and nothing was stored at the mint")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Stored(), ..#RAISEDSET, "the store holds the raised set")
    Do $$$AssertEquals(tResult.readBack.verdict, "nothingSent", "the read-back says nothing was sent")
    Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "marked (AD-15)")
    Do ..AssertAudit(tSince, tContent.proposalId, ..#ADDTOOL, "updated", "%Admin_Operate:USE,%DB_IRISSYS:READ", ..#RAISEDSET)
}

/// <p>Lower: a remove-pair of a declared pair is destructive with <code>SCREENACCESS.LOWERED</code>. Its confirm
/// stores the smaller set and leaves its audit rows.</p>
/// <p>Mutation (Rule 19): remove the screen-permission arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> -- this goes red.</p>
Method TestALowerIsMintedDestructiveAndConfirmed()
{
    Set tSC = ..Dispatch(..#REMOVETOOL, ..#LOWERED, .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "the remove-pair mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..PairsRow(tContent), "%Admin_Operate:USE, %DB_IRISSYS:READ -> %Admin_Operate:USE", "its Pairs row reads before and after")
    Do $$$AssertEquals(..Treatment(tContent), "1|SCREENACCESS.LOWERED", "a lowering is destructive and names its consequence")
    Do $$$AssertEquals(..Requires(tContent), "[""%Development:USE or %Admin_Secure:USE""]", "and requires the either-of")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Stored(), ..#LOWEREDSET, "the store holds the lowered set")
    Do $$$AssertEquals(tResult.readBack.verdict, "nothingSent", "the read-back says nothing was sent")
    Do ..AssertAudit(tSince, tContent.proposalId, ..#REMOVETOOL, "updated", "%Admin_Operate:USE,%DB_IRISSYS:READ", ..#LOWEREDSET)
}

/// <p>Reset: a reset of a raise drops a pair the declared set lacks, so it is destructive; a reset of a lowering
/// restores a pair, so it is not; a reset with nothing adjusted is refused <code>ACCESS.NOTADJUSTED</code> at
/// the mint. Each confirm leaves the screen unadjusted and the read-back reads the adjustment gone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.ScreenAccessReset.PortQuery</method> ignore the
/// payload -- the confirm legs go red.</p>
Method TestAResetIsClassifiedByWhatItDropsAndConfirmed()
{
    Set tSC = ..Dispatch(..#RESETTOOL, "", .tContent, .tIsError, .tTurn)
    Set tText = $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent)
    Do $$$AssertTrue(tIsError && (tText [ "ACCESS.NOTADJUSTED"), "a reset of an unadjusted screen is refused at the mint: " _ tText)
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#RESETTOOL), 0, "and no proposal exists")

    Do $$$AssertStatusOK(..Adjust(..#RAISEDSET), "Locks is raised")
    Set tSC = ..Dispatch(..#RESETTOOL, "", .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "a reset of the raise mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..Treatment(tContent), "1|SCREENACCESS.LOWERED", "it drops a pair the declared set lacks, so it is destructive")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(..Stored(), "", "the adjustment is gone")
    Do $$$AssertEquals(tResult.readBack.verdict, "notFound", "and the read-back reads it gone: " _ tResult.readBack.%ToJSON())
    Do ..AssertAudit(tSince, tContent.proposalId, ..#RESETTOOL, "reset", ..#RAISEDSET, "%Admin_Operate:USE,%DB_IRISSYS:READ")

    Do $$$AssertStatusOK(..Adjust(..#LOWEREDSET), "Locks is lowered")
    Set tSC = ..Dispatch(..#RESETTOOL, "", .tContent, .tIsError, .tTurn)
    Do $$$AssertEquals(tIsError, 0, "a reset of the lowering mints: " _ $Select($IsObject(tContent): tContent.%ToJSON(), 1: tContent))
    If '$IsObject(tContent) || tIsError Quit
    Do $$$AssertEquals(..Treatment(tContent), "0|", "it restores a pair, so it is not destructive")
    Set tSC = ..ConfirmIn(tContent, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the confirm answers: " _ $Get(tCode))
    Do $$$AssertEquals(..Stored(), "", "and the adjustment is gone")
}

/// <p>Assert one <code>SecurityChange</code> row for the screen with verb <var>pVerb</var> naming <var>pOld</var>
/// and <var>pNew</var>, and one agent marker naming <var>pTool</var>, both since <var>pSince</var>.</p>
Method AssertAudit(pSince As %String, pProposalId As %String, pTool As %String, pVerb As %String, pOld As %String, pNew As %String)
{
    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(pSince, 1, ..#SCREEN, pVerb, .tRows)
    Do $$$AssertEquals(tRows, 1, pTool _ ": exactly one security-change row records it: " _ tRows)
    If tRows = 1 {
        Set tRow = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Do $$$AssertEquals(tRow.changes.pairs.old _ "|" _ tRow.changes.pairs.new, pOld _ "|" _ pNew, pTool _ ": naming the pairs before and after")
    }
    Set tMarkers = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, ##class(OcuPilot.Test.AuditMarker).MarkerName(), pProposalId, .tMarkerData)
    Do $$$AssertEquals(tMarkers, 1, pTool _ ": one agent marker carries the proposal id")
}

}
