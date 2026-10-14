/// <p>Pins what Story 20.16's editor saves ask again when the person confirms (AD-6, AD-8, AD-40, AC5, AC8): the proposal of each
/// save requires <code>%Ens_Code:WRITE</code>, the vendor editors' write resource, and Confirm refuses 403
/// <code>AUTH.NOPRIVILEGE</code> naming a revoked <code>%Ens_Code:WRITE</code> or <code>%Development:USE</code>, writes nothing and
/// leaves the proposal live; Confirm refuses 400 <code>TOOL.ARGUMENTS</code>, naming the kind, a class that became another kind after
/// the mint, writes nothing and leaves the proposal live; and each save's Confirm rule admits its own kind alone.</p>
/// <p>A class that changed after the mint is otherwise closed 409 at the digest, before the kind is asked, so the second test confirms
/// through <class>OcuPilot.Test.InteropEditorConfirm</class>, whose fingerprint answers a match. The mint's own refusals are pinned in
/// <class>OcuPilot.Test.InteropEditorSaveRules</class>, and the pair refusals at dispatch in
/// <class>OcuPilot.Test.InteropEditorSaveGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and a <code>USER</code> namespace that
/// runs interoperability. It makes and removes the <code>OcuProbe2016</code> probe package
/// (<class>OcuPilot.Test.InteropEditorProbe</class>) and snapshots the stored governance policy before each test and puts it back
/// after it. It creates no user and changes no grant.</p>
Class OcuPilot.Test.InteropEditorSaveConfirm Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

Parameter HELPER = "OcuPilot.Test.InteropEditorSave";

Parameter CONFIRM = "OcuPilot.Test.InteropEditorConfirm";

/// <p>The three saves, <code>&lt;probe kind&gt;|&lt;save class&gt;|&lt;tool&gt;|&lt;what a document of the kind is called&gt;</code>.</p>
Parameter SAVES = "rule|OcuPilot.Screen.Tool.InteropRuleEditorSave|interop.ruleeditor.save|a business rule;process|OcuPilot.Screen.Tool.InteropProcessEditorSave|interop.processeditor.save|a business process written in BPL;transform|OcuPilot.Screen.Tool.InteropTransformEditorSave|interop.transformeditor.save|a data transformation written in DTL";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
    Do $ClassMethod(..#CONFIRM, "MatchFingerprint", 0)
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
    Do $ClassMethod(..#CONFIRM, "MatchFingerprint", 0)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), "every probe document, generated class and cache node is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ForgetLedger"), "the ledger rows of the probe turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Make probe <var>pKind</var> and mint its save's proposal for the edit <class>OcuPilot.Test.InteropEditorSave</class> gives it, in
/// <var>pProposal</var>; 1 when a proposal was minted. The text the probe held is in <var>pBefore</var>.</p>
Method MintFor(pKind As %String, pTool As %String, Output pProposal As %DynamicObject, Output pBefore As %String) As %Boolean
{
    Set pProposal = ""
    Set tName = $ClassMethod(..#PROBE, "Name", pKind, ..#PACKAGE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", pKind, ..#PACKAGE), pKind _ ": the probe is saved and compiled")
    Set pBefore = $ClassMethod(..#HELPER, "Stored", tName)
    Set tSC = $ClassMethod(..#HELPER, "Dispatch", pTool, $ClassMethod(..#HELPER, "EditOf", pKind), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError {
        Do $$$AssertTrue(0, pTool _ ": the edit is minted: " _ $Extract($Get(tContent), 1, 300))
        Quit 0
    }
    Set pProposal = tProposal
    Quit 1
}

/// <p>The state of the stored proposal <var>pProposalId</var>.</p>
ClassMethod StateOf(pProposalId As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
    Quit $Select($Get(tFound): $Get(tValues("state")), 1: "")
}

/// <p>Confirm <var>pProposal</var> in process as the running account through <class>OcuPilot.Test.InteropEditorConfirm</class>,
/// scoped to <parameter>NAMESPACE</parameter>; the HTTP status and code it answers, then the detail's <var>pMember</var>, joined by
/// spaces.</p>
ClassMethod ConfirmThrough(pProposal As %DynamicObject, pMember As %String) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Kill tResult, tDetail
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Quit tHttp _ " " _ tCode _ " " _ $Select($IsObject($Get(tDetail)): tDetail.%Get(pMember), 1: "")
}

/// <p>A pair revoked from the account after the mint refuses the confirm, 403 <code>AUTH.NOPRIVILEGE</code> naming that pair, for each
/// save and for each of the two pairs this story adds to the class save's: the proposal requires <code>%Ens_Code:WRITE</code>, the
/// class keeps the text it held, the proposal is still live, and with the pair back the same proposal confirms and saves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.InteropEditorSave.PrivilegePairs</method> drops <code>%Ens_Code:WRITE</code>
/// -- the requirement leg and the revoked-write leg go red.</p>
Method TestAPairRevokedAfterTheMintRefusesTheConfirmAndLeavesTheProposalLive()
{
    For tI = 1:1:$Length(..#SAVES, ";") {
        Set tRow = $Piece(..#SAVES, ";", tI)
        Set tKind = $Piece(tRow, "|", 1)
        Set tTool = $Piece(tRow, "|", 3)
        Set tName = $ClassMethod(..#PROBE, "Name", tKind, ..#PACKAGE)
        If '..MintFor(tKind, tTool, .tProposal, .tBefore) Continue
        Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.proposalId, .tFound, .tValues)
        Do $$$AssertTrue($Get(tValues("requiredPairs")) [ "%Ens_Code:WRITE", tTool _ ": the proposal requires %Ens_Code:WRITE: " _ $Get(tValues("requiredPairs")))
        For tPair = "%Ens_Code:WRITE", "%Development:USE" {
            Set tLabel = tTool _ " with " _ tPair _ " revoked after the mint"
            Do ##class(OcuPilot.Test.ProposalFixture).DenyPair(tPair)
            Set tAnswer = ..ConfirmThrough(tProposal, "failedPair")
            Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
            Do $$$AssertEquals(tAnswer, "403 " _ ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE _ " " _ tPair, tLabel _ ": the confirm is refused by name")
            Do $$$AssertEquals($ClassMethod(..#HELPER, "Stored", tName), tBefore, tLabel _ ": nothing was saved")
            Do $$$AssertEquals(..StateOf(tProposal.proposalId), "live", tLabel _ ": the proposal is still live")
        }
        Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tTool _ ": with the pairs back the same proposal confirms: " _ $Get(tCode))
        Do $$$AssertEquals(..StateOf(tProposal.proposalId), "confirmed", tTool _ ": and is confirmed")
        Do $$$AssertTrue($ClassMethod(..#HELPER, "Stored", tName) '= tBefore, tTool _ ": and the class holds the new text")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), tKind _ ": the probe is removed before the next kind")
    }
}

/// <p>A class that another writer made a plain class after the mint is refused at Confirm 400 <code>TOOL.ARGUMENTS</code>, with a
/// problem naming the kind, for each save: the other writer's text is left in place and the proposal is still live. The fingerprint
/// is answered as matching, because a changed class otherwise closes the proposal 409 before the kind is asked.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.ConfirmProblem</method> asks the class save's own
/// <method>AgentProblem</method> instead of the editor save's, descendants recompiled -- this goes red and the mint legs of
/// <class>OcuPilot.Test.InteropEditorSaveRules</class> stay green.</p>
Method TestAClassThatBecameAnotherKindAfterTheMintIsRefusedAtConfirm()
{
    For tI = 1:1:$Length(..#SAVES, ";") {
        Set tRow = $Piece(..#SAVES, ";", tI)
        Set tKind = $Piece(tRow, "|", 1)
        Set tTool = $Piece(tRow, "|", 3)
        Set tName = $ClassMethod(..#PROBE, "Name", tKind, ..#PACKAGE)
        If '..MintFor(tKind, tTool, .tProposal, .tBefore) Continue
        Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.ExplorerSaveProbe", "Rewrite", ..#NAMESPACE, tName, "9"), tKind _ ": another writer makes the class a plain class")
        Set tRewritten = $ClassMethod(..#HELPER, "Stored", tName)
        Do $$$AssertTrue(tRewritten '= tBefore, tKind _ ": the class holds the other writer's text")
        Do $ClassMethod(..#CONFIRM, "MatchFingerprint", 1)
        Set tAnswer = ..ConfirmThrough(tProposal, "problem")
        Do $ClassMethod(..#CONFIRM, "MatchFingerprint", 0)
        Set tPrefix = "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ " '" _ tName _ ".cls' is not " _ $Piece(tRow, "|", 4) _ " in namespace " _ ..#NAMESPACE
        Do $$$AssertEquals($Extract(tAnswer, 1, $Length(tPrefix)), tPrefix, tTool _ ": the confirm is refused as the wrong kind: " _ tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "Stored", tName), tRewritten, tTool _ ": nothing was saved over the other writer's text")
        Do $$$AssertEquals(..StateOf(tProposal.proposalId), "live", tTool _ ": the proposal is still live")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), tKind _ ": the probe is removed before the next kind")
    }
}

/// <p>Each save's Confirm rule admits a document of its own kind and refuses, naming the kind, a document of each other kind, a plain
/// class and a class the namespace does not hold; and Confirm asks the rule, because the compiled save has the method.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSave.ConfirmProblem</method> asks the class save's own
/// <method>AgentProblem</method>, descendants recompiled -- the refusal legs go red and the mint legs of
/// <class>OcuPilot.Test.InteropEditorSaveRules</class> stay green.</p>
Method TestEachSavesConfirmRuleAdmitsItsOwnKindAlone()
{
    Set tPlain = ..#PACKAGE _ ".Plain"
    For tKind = "rule", "process", "transform", "coded" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", tKind, ..#PACKAGE), tKind _ ": the probe is saved and compiled")
    }
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.ExplorerSaveProbe", "Rewrite", ..#NAMESPACE, tPlain, "1"), "a plain probe class is saved")
    Set tArgs = {"Namespace": (..#NAMESPACE)}
    For tI = 1:1:$Length(..#SAVES, ";") {
        Set tRow = $Piece(..#SAVES, ";", tI)
        Set tOwn = $Piece(tRow, "|", 1)
        Set tClass = $Piece(tRow, "|", 2)
        Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||ConfirmProblem"), tClass _ " has the rule Confirm asks")
        For tOther = "rule", "process", "transform", "coded", "plain", "missing" {
            Set tName = $Select(tOther = "plain": tPlain, tOther = "missing": ..#PACKAGE _ ".Missing", 1: $ClassMethod(..#PROBE, "Name", tOther, ..#PACKAGE)) _ ".cls"
            Kill tProblem
            Do $$$AssertStatusOK($ClassMethod(tClass, "ConfirmProblem", tName, tArgs, .tProblem), tClass _ ": the rule answers for " _ tName)
            If tOther = tOwn {
                Do $$$AssertEquals($Get(tProblem), "", tClass _ ": admits " _ tName)
            } Else {
                Do $$$AssertTrue($Get(tProblem) [ ("is not " _ $Piece(tRow, "|", 4) _ " in namespace " _ ..#NAMESPACE), tClass _ ": refuses " _ tName _ " as another kind: " _ $Get(tProblem))
            }
        }
    }
}

}
