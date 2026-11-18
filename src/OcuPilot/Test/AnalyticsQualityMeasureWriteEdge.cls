/// <p>Pins the edges of Story 24.12's quality measure writes (Batch 2: AD-8, AD-22, AD-34, AD-61, AD-65) against <code>USER</code>: two classes that declare one measure's name refuse every write
/// before any write; a compile the instance refuses, armed through <class>OcuPilot.Test.AnalyticsListingGroupSeam</class>, leaves the class text and the registry as they were before each of the
/// three writes that compile (a created class is deleted, a changed one is saved back and, when it was compiled, compiled again) and each records its audit row; a class changed after a proposal
/// was minted closes it as target-changed; the baseline ships three keys on and one off; and the gate refuses, in process and before any write, a caller without
/// <code>%DeepSee_PortalEdit:USE</code> and one without <code>%Development:USE</code>. The helpers are <class>OcuPilot.Test.AnalyticsQualityMeasureBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named measures and classes in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureWriteEdge Extends OcuPilot.Test.AnalyticsQualityMeasureBase
{

Parameter COMPILESEAM = "OcuPilot.Test.AnalyticsListingGroupSeam";

Parameter ATELIERSEAM = "OcuPilot.Test.AnalyticsListingGroupAtelier";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#ATELIERSEAM, "Reset")
    Quit ##super()
}

/// <p>The write <var>pType</var> of the measure <var>pId</var> with <var>pBody</var> through the compile seam, with the query members of <var>pExtra</var>: the HTTP status and the fault's code in one string.</p>
ClassMethod Compiling(pType As %String, pId As %String, pBody As %DynamicObject, pExtra As %DynamicObject = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set tSC = $ClassMethod(..#COMPILESEAM, "Invoke", "QualityMeasures", pType, .tQuery, pBody, .tRes, .tHttp, .tFault)
    Quit tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>1 when the <code>ConfigChange</code> row of the verb <var>pVerb</var> on the measure <var>pId</var> since <var>pSince</var> records the outcome <var>pOutcome</var>.</p>
ClassMethod Recorded(pSince As %String, pId As %String, pVerb As %String, pOutcome As %String) As %Boolean
{
    Do $ClassMethod(..#QUEUES, "AuditRows", pSince, "quality-measure", pId, pVerb, .tData)
    Quit ''(tData [ ("""outcome"":""" _ pOutcome _ """"))
}

/// <p>AC1: two classes that declare the measure's name refuse every write that is keyed by the name, each 409 <code>ANALYTICS.QUALITYMEASURE.AMBIGUOUS</code> and before any write, for an update, a copy
/// and a delete; an add of the name is refused as taken. The classes, their text and the registry are as they were.</p>
/// <p>Mutation (Rule 19): drop the ambiguity check from <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> -- every leg goes red.</p>
Method TestTwoClassesThatDeclareAMeasureRefuseEveryWrite()
{
    Set tName = ..Name("Twin")
    Set tClass = ..#CLASSMARKER _ "Twin"
    Do $$$AssertStatusOK(..SaveMeasure("Twin", tClass), "the measure is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("Twin", ..#CLASSMARKER _ "TwinSecond"), "a second class declares the same name, and compiles")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the first class is the registered one")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tCode = "409 ANALYTICS.QUALITYMEASURE.AMBIGUOUS"
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Caption": "x"}, "", .tRes), tCode, "an update is refused")
    Do $$$AssertEquals(..Port("QualityMeasures", "COPY", tName, {}, {"newName": (..Name("TwinCopy")), "newClass": (..#CLASSMARKER _ "TwinCopy")}, .tRes), tCode, "a copy is refused")
    Do $$$AssertEquals(..Port("QualityMeasures", "DELETE", tName, {}, "", .tRes), tCode, "a delete is refused")
    Do $$$AssertEquals(..Port("QualityMeasures", "ADD", tName, {"Name": (tName), "Class": (..#CLASSMARKER _ "TwinNew"), "SubjectArea": (..#VISITS)}, "", .tRes), "409 ANALYTICS.QUALITYMEASURE.TAKEN", "an add of the name is refused as taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was added or lost")
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the registered class's text is unchanged")
    Do ..MintRefused(..#UPDATETOOL, {"Name": (tName), "Caption": "x"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
}

/// <p>AC3: a compile the instance refuses, after the pre-checks passed, undoes each of the three writes that compile. An update saves the prior text back and compiles it again, so the class text, the model
/// and the registry equal their state before the write; a measure that was not compiled is saved back and not compiled; an add and a copy delete the class they created. Each answers 422
/// <code>ANALYTICS.QUALITYMEASURE.COMPILE</code>, never the compiler's own text, and each records its audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> do nothing -- every leg goes red.</p>
Method TestARefusedCompileUndoesEachWrite()
{
    Set tName = ..Name("Undo")
    Set tClass = ..#CLASSMARKER _ "Undo"
    Set tOff = ..Name("UndoOff")
    Set tOffClass = ..#CLASSMARKER _ "UndoOff"
    Do $$$AssertStatusOK(..SaveMeasure("Undo", tClass), "the measure is saved and compiled")
    Do ..SaveMeasure("UndoOff", tOffClass, "", "[Long]/[Missing]")
    Do $$$AssertEquals(..QRegistered(tOff, tOffClass), 0, "a second measure is saved and its compile is refused, so it is registered and not compiled")
    Set tText = ..TextOf(tClass)
    Set tModel = ..QModel(tName)
    Set tOffText = ..TextOf(tOffClass)
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = "422 ANALYTICS.QUALITYMEASURE.COMPILE"
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("UPDATE", tName, {"Caption": "changed"}), tCode, "an update: the refused compile answers the compile's code")
    Do $$$AssertEquals(..TextOf(tClass), tText, "the class text is as it was")
    Do $$$AssertEquals(..QModel(tName), tModel, "the model is as it was")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the measure is compiled and registered again")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tName, "analytics.qualitymeasures.update"), 1, "the write recorded its audit row")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("UPDATE", tOff, {"Expression": "[Long]"}), tCode, "an update of a measure that was not compiled answers the compile's code")
    Do $$$AssertEquals(..TextOf(tOffClass) _ "|" _ ..QRegistered(tOff, tOffClass), tOffText _ "|0", "its text is saved back and it is not compiled")
    Do $$$AssertEquals(..Recorded(tSince, tOff, "analytics.qualitymeasures.update", "restored"), 1, "and its audit row records the outcome restored, so the restore did not try to compile the saved-back text")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("ADD", ..Name("UndoNew"), {"Name": (..Name("UndoNew")), "Class": (..#CLASSMARKER _ "UndoNew"), "SubjectArea": (..#VISITS)}), tCode, "an add answers the compile's code")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("COPY", tName, {}, {"newName": (..Name("UndoCopy")), "newClass": (..#CLASSMARKER _ "UndoCopy")}), tCode, "a copy answers the compile's code")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was added or left and no node changed")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", ..Name("UndoNew"), "analytics.qualitymeasures.add") + ..Rows(tSince, "quality-measure", ..Name("UndoCopy"), "analytics.qualitymeasures.copy"), 2, "the add and the copy recorded their audit rows")
    Do $$$AssertEquals(..Compiling("UPDATE", tName, {"Caption": "applied"}), "200 ", "with no failure armed the same write applies")
}

/// <p>The proposal of <var>pTool</var> with <var>pArgs</var>, on the measure whose id is <var>pId</var> in the class <var>pClass</var>, is minted; the class is then saved again with the class
/// parameter <var>pNote</var> added and the measure as it was, so the confirm closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, and the classes and the registry are
/// as that second save left them.</p>
Method AssertStale(pTool As %String, pArgs As %DynamicObject, pId As %String, pClass As %String, pNote As %String)
{
    Set tWhat = $Parameter(pTool, "TOOLNAME")
    Do ..Mint(pTool, pArgs, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(..SaveMeasure(pId, pClass, "", "[Long]/[Everyone]", pNote), tWhat _ ": the class is saved again after the mint, with a class parameter added and the measure as it was")
    Set tBefore = ..Snapshot()
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", tWhat _ ": the confirm is refused as moved: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..Snapshot(), tBefore, tWhat _ ": nothing was written, and the class is as the second save left it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5: a class changed after a proposal was minted closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, and nothing is written, for the update, the copy and the delete;
/// and the baseline ships the add, the update and the copy on and the delete off, which the governance gate reads.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.QualityMeasureRow</method> answer an empty <code>Version</code> -- the update's and the delete's stale legs go red; make the
/// copy's target answer in <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> carry an empty <code>Version</code> -- the copy's stale leg goes red; flip the delete's line of
/// <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the key leg goes red.</p>
Method TestAChangedClassClosesTheProposalAndTheBaselineShipsOneKeyOff()
{
    Set tName = ..Name("Stale")
    Set tClass = ..#CLASSMARKER _ "Stale"
    Do $$$AssertStatusOK(..SaveMeasure("Stale", tClass), "the measure is saved and compiled")
    Do ..EnableKey("analytics.qualitymeasures.delete")
    Do ..AssertStale(..#UPDATETOOL, {"Name": (tName), "Caption": "from the agent"}, "Stale", tClass, "changed")
    Do ..AssertStale(..#COPYTOOL, {"Name": (tName), "NewName": (..Name("StaleCopy")), "NewClass": (..#CLASSMARKER _ "StaleCopy")}, "Stale", tClass, "changedAgain")
    Do ..AssertStale(..#DELETETOOL, {"Name": (tName)}, "Stale", tClass, "changedLast")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    For tCase = $ListBuild("analytics.qualitymeasures.add", 1), $ListBuild("analytics.qualitymeasures.update", 1), $ListBuild("analytics.qualitymeasures.copy", 1), $ListBuild("analytics.qualitymeasures.delete", 0) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
}

/// <p>AC1: an update whose expression names a group the measure holds but that cannot count, a disabled group or one whose elements are all disabled, is refused 422
/// <code>ANALYTICS.QUALITYMEASURE.EXPRESSION</code> and nothing is written; the agent's mint refuses it too; the enabled group is accepted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> count a disabled group -- the first leg goes red; make it count an element that is disabled -- the second leg
/// goes red.</p>
Method TestAnExpressionNamingAGroupThatCannotCountIsRefused()
{
    Set tName = ..Name("Spare")
    Set tClass = ..#CLASSMARKER _ "Spare"
    Do $$$AssertStatusOK(..SaveMeasure("Spare", tClass, "", "[Long]/[Everyone]", "", 1), "a measure with a disabled group and a group with no enabled element is saved and compiled")
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild("[Off]", "a disabled group"), $ListBuild("[Long]/[Idle]", "a group whose elements are all disabled") {
        Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Expression": ($List(tCase, 1))}, "", .tRes), "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", $List(tCase, 2) _ " is refused")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 2) _ ": nothing was written")
        Do ..MintRefused(..#UPDATETOOL, {"Name": (tName), "Expression": ($List(tCase, 1))}, "TOOL.ARGUMENTS")
    }
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Expression": "[Long]"}, "", .tRes), "200 ", "an expression naming the enabled group is accepted")
}

/// <p>AC1: in process, through the gate seam, a write is refused before any write for a caller without <code>%DeepSee_PortalEdit:USE</code> (403 naming it, the screen's own pair) and for one without
/// <code>%Development:USE</code> (403 naming it, one of the pairs <code>AtelierPort.Pairs</code> adds), each for the four writes; the read of the measure needs the first and not the second.</p>
/// <p>Mutation (Rule 19): drop <code>AtelierPort.Pairs()</code> from <method>OcuPilot.Port.AnalyticsPort.AdmitClassWrite</method> -- the <code>%Development:USE</code> leg goes red.</p>
Method TestAWriteIsRefusedWithoutItsPairsBeforeAnyWrite()
{
    Set tName = ..Name("Gate")
    Set tClass = ..#CLASSMARKER _ "Gate"
    Do $$$AssertStatusOK(..SaveMeasure("Gate", tClass), "the measure is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tWrites = $ListBuild($ListBuild("UPDATE", tName), $ListBuild("DELETE", tName), $ListBuild("COPY", tName), $ListBuild("ADD", ..Name("GateNew")))
    For tExcept = "%DeepSee_PortalEdit:USE", "%Development:USE" {
        Do ..HoldEverythingBut(tExcept)
        For tAt = 1:1:$ListLength(tWrites) {
            Set tWrite = $List(tWrites, tAt)
            Set tResult = ..Seamed("QualityMeasures", $List(tWrite, 1), $List(tWrite, 2), {"Name": ($List(tWrite, 2)), "Class": (..#CLASSMARKER _ "GateNew"), "SubjectArea": (..#VISITS)}, .tRes)
            Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|" _ tExcept, $List(tWrite, 1) _ " without " _ tExcept _ " is refused naming it: " _ tResult)
        }
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was written")
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the class text is as it was")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tName
    Do ..HoldEverythingBut("%Development:USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "QualityMeasures", "QUALITYMEASURE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the plain read of the measure needs no %Development:USE")
    Do ..HoldEverythingBut("%DeepSee_PortalEdit:USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "QualityMeasures", "QUALITYMEASURE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 AUTH.NOPRIVILEGE", "and it does need the screen's own pair")
}

}
