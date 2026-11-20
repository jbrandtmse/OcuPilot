/// <p>Pins what Story 24.12's quality measure writes (Batch 2) do against the instance's real compiler and at the callers the other write classes reach only through the port or the seam:
/// a compile the vendor refuses, armed by a class generator that fails once, undoes an update at every caller (the person's screen action, the agent's confirmed proposal and the port) with the
/// class text, the model and the registry as they were and the prior measure compiled again; a linked measure's changed expression, format or URL is refused by the person's call and the
/// agent's mint while the values it already holds pass; and two classes that declare one name are refused by the person's call and by the agent's copy and delete mints. The helpers are
/// <class>OcuPilot.Test.AnalyticsQualityMeasureBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named measures and classes in <code>USER</code>, and the global <code>^OcuProbeQMWFail</code> there.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureWriteReal Extends OcuPilot.Test.AnalyticsQualityMeasureBase
{

Method OnBeforeOneTest() As %Status
{
    Kill ^["USER"]OcuProbeQMWFail
    Quit ##super()
}

Method OnAfterOneTest() As %Status
{
    Kill ^["USER"]OcuProbeQMWFail
    Quit ##super()
}

/// <p>The text of the measure <var>pId</var> in <var>pClass</var> with a method whose generator fails the next compile once: it reads <code>^OcuProbeQMWFail</code> in the compiling namespace and
/// kills it as it fails, so the compile after that one passes.</p>
ClassMethod FailOnceText(pId As %String, pClass As %String) As %String
{
    Set tNL = $Char(13, 10)
    Set tMethod = "Method Gen() [ CodeMode = objectgenerator ]" _ tNL _ "{" _ tNL _ " If $Get(^OcuProbeQMWFail) {" _ tNL _ "  Kill ^OcuProbeQMWFail" _ tNL _ "  Quit $$$ERROR($$$GeneralError, ""forced"")" _ tNL _ " }" _ tNL _ " Do %code.WriteLine("" Quit"")" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _ tNL
    Quit $Replace(..MeasureText(pId, pClass), "/// A line the writes keep.", tMethod _ "/// A line the writes keep.")
}

/// <p>Save and compile the measure <var>pId</var> as <var>pClass</var> with <method>FailOnceText</method>'s text.</p>
ClassMethod SaveFailOnce(pId As %String, pClass As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pClass, ..FailOnceText(pId, pClass))
    If $$$ISOK(tSC) {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(pClass, "ck-d")
        Set $NAMESPACE = tOrigNS
    }
    Quit tSC
}

/// <p>The next compile in <code>USER</code> fails once.</p>
ClassMethod ArmFailure()
{
    Set ^["USER"]OcuProbeQMWFail = 1
}

/// <p>1 when the failure armed by <method>ArmFailure</method> was used, that is, the vendor's compiler ran the class's generator.</p>
ClassMethod FailureUsed() As %Boolean
{
    Quit ''('$Data(^["USER"]OcuProbeQMWFail))
}

/// <p>The mint of <var>pTool</var> with <var>pArgs</var> is refused with no proposal and the refusal's problem is the sentence <var>pSentence</var>.</p>
Method MintRefusedWith(pTool As %String, pArgs As %DynamicObject, pSentence As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject($Get(tProposal)) && (+$Get(tHttp) >= 400), $Parameter(pTool, "TOOLNAME") _ " is refused at the mint with no proposal")
    Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("problem"), 1: "")
    Do $$$AssertEquals(tProblem, pSentence, $Parameter(pTool, "TOOLNAME") _ ": the refusal says why")
}

/// <p>AC3 against the real compiler: a compile the instance refuses after every pre-check passed undoes an update at the person's screen action, the agent's confirmed proposal and the port. Each
/// answers 422 <code>ANALYTICS.QUALITYMEASURE.COMPILE</code>; the class text, the model, the registry and the compile state are as they were, the measure compiled again, so the restore recompiled
/// the prior text; each records the outcome the write reached; and the next update applies.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> save the prior text and not compile it -- the registered legs go red; make it do nothing -- the text legs go
/// red too.</p>
Method TestARefusedCompileOfAnUpdateIsUndoneAtEveryCaller()
{
    Set tName = ..Name("Real")
    Set tClass = ..#CLASSMARKER _ "Real"
    Do $$$AssertStatusOK(..SaveFailOnce("Real", tClass), "the measure, whose class holds a generator that fails the next compile once, is saved and compiled")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "and it is registered and up to date")
    Set tText = ..TextOf(tClass)
    Set tModel = ..QModel(tName)
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()

    Do ..ArmFailure()
    Set tStatus = ..Act(..#MEASURESCREEN, "update", tName, {"Caption": "from the person"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "the person's Edit is refused with the compile's code")
    Do $$$AssertEquals(..FailureUsed(), 1, "because the vendor's compiler ran and failed")
    Do $$$AssertEquals(..TextOf(tClass), tText, "the class text is as it was")
    Do $$$AssertEquals(..QModel(tName), tModel, "the model is as it was")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "and the measure is registered and compiled again")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node changed")

    Do ..Mint(..#UPDATETOOL, {"Name": (tName), "Caption": "from the agent"}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Do ..ArmFailure()
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "the agent's confirmed update is refused with the compile's code: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals(..FailureUsed(), 1, "because the vendor's compiler ran and failed")
        Do $$$AssertEquals(..TextOf(tClass) _ "|" _ ..QModel(tName) _ "|" _ ..QRegistered(tName, tClass), tText _ "|" _ tModel _ "|1", "the class text and the model are as they were and the measure is compiled again")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }

    Do ..ArmFailure()
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Caption": "from the port"}, "", .tRes), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "the port's update is refused with the compile's code")
    Do $$$AssertEquals(..FailureUsed(), 1, "because the vendor's compiler ran and failed")
    Do $$$AssertEquals(..TextOf(tClass) _ "|" _ ..QModel(tName) _ "|" _ ..QRegistered(tName, tClass), tText _ "|" _ tModel _ "|1", "the class text and the model are as they were and the measure is compiled again")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node changed")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tName, "analytics.qualitymeasures.update"), 3, "each refused write recorded its audit row")
    Do $$$AssertEquals(..Recorded(tSince, tName, "analytics.qualitymeasures.update", "restored"), 1, "with the outcome restored")

    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Caption": "applied"}, "", .tRes), "200 ", "with no failure armed the same update applies")
    Do $$$AssertEquals($Piece(..QModel(tName), "|", 2), "applied", "and the model holds it")
}

/// <p>A compile the instance refuses undoes an update of a measure that was not up to date: the prior text is saved back and nothing is compiled, so the measure is as stale as it was. The class
/// compiled, then changed by a person without a compile, so the vendor still lists it and its fresh read says it is not compiled.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> compile whatever it restores -- the not-compiled leg goes red.</p>
Method TestARefusedCompileOfAStaleMeasureIsUndoneAndLeftStale()
{
    Set tName = ..Name("Stale2")
    Set tClass = ..#CLASSMARKER _ "Stale2"
    Do $$$AssertStatusOK(..SaveFailOnce("Stale2", tClass), "the measure is saved and compiled")
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, $Replace(..FailOnceText("Stale2", tClass), "Parameter KEEP = ""kept"";", "Parameter KEEP = ""kept"";" _ $Char(13, 10) _ $Char(13, 10) _ "Parameter LATER = ""saved after the compile"";")), "a person changes the class and does not compile it")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 0, "so the measure is registered and not up to date")
    Set tText = ..TextOf(tClass)
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..ArmFailure()
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"Caption": "refused"}, "", .tRes), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "an update whose compile the vendor refuses answers the compile's code")
    Do $$$AssertEquals(..FailureUsed(), 1, "because the vendor's compiler ran and failed")
    Do $$$AssertEquals(..TextOf(tClass), tText, "the class text, the person's change included, is as it was")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 0, "and the measure is still not compiled")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node changed")
    Do $$$AssertEquals(..Recorded(tSince, tName, "analytics.qualitymeasures.update", "restored"), 1, "the outcome is restored")
}

/// <p>AD-65 at both callers: a linked measure's expression, format or URL is the master's to define, so a change to one is refused 409 <code>ANALYTICS.QUALITYMEASURE.LINKED</code> by the
/// person's Edit and refused at the agent's mint with nothing written, while an Edit that sends the values the linked measure already holds, as the dialog does with every field its form held,
/// changes the caption and keeps the link.</p>
/// <p>Mutation (Rule 19): drop the linked check of <method>OcuPilot.Port.AnalyticsPort.VendorQualityMeasureCompose</method> -- the two refusal legs go red.</p>
Method TestALinkedMeasureRefusesAChangedFieldAtBothCallers()
{
    Set tMaster = ..Name("Master")
    Set tLinked = ..Name("Follower")
    Do $$$AssertStatusOK(..SaveMeasure("Master", ..#CLASSMARKER _ "Master"), "the master is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("Follower", ..#CLASSMARKER _ "Follower", tMaster), "and a measure linked to it")
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild("Format", "x"), $ListBuild("Expression", "2"), $ListBuild("Href", "https://example.invalid/other") {
        Set tField = $List(tCase, 1)
        Set tValues = {}
        Do tValues.%Set(tField, $List(tCase, 2), "string")
        Set tArgs = {"Name": (tLinked)}
        Do tArgs.%Set(tField, $List(tCase, 2), "string")
        Set tStatus = ..Act(..#MEASURESCREEN, "update", tLinked, tValues, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.QUALITYMEASURE.LINKED", "the person's Edit of the linked measure's " _ tField _ " is refused")
        Do ..MintRefusedWith(..#UPDATETOOL, tArgs, ##class(OcuPilot.Api.AnalyticsError).#REASONQUALITYMEASURELINKED)
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Set tStatus = ..Act(..#MEASURESCREEN, "update", tLinked, {"Caption": "Edited follower", "Expression": "1", "Format": "", "Href": ""}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "an Edit that sends the values the linked measure holds is not refused: " _ $Select($IsObject($Get(tAnswer)): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Set tModel = ..QModel(tLinked)
    Do $$$AssertEquals($Piece(tModel, "|", 2) _ "|" _ $Piece(tModel, "|", 5) _ "|" _ $Piece(tModel, "|", 6), "Edited follower|1|" _ tMaster, "the caption changed and the link and its stored expression are kept")
}

/// <p>AC1: two classes that declare the measure's name are refused 409 <code>ANALYTICS.QUALITYMEASURE.AMBIGUOUS</code> by the person's update, copy and delete and at the agent's copy and delete
/// mints, with nothing written.</p>
/// <p>Mutation (Rule 19): drop the ambiguity check from <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> -- a mint leg goes red; the port's own check is
/// <class>OcuPilot.Test.AnalyticsQualityMeasureWriteEdge</class>'s.</p>
Method TestATwinIsRefusedAtThePersonsCallAndTheAgentsMint()
{
    Set tName = ..Name("Twin2")
    Do $$$AssertStatusOK(..SaveMeasure("Twin2", ..#CLASSMARKER _ "Twin2"), "the measure is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("Twin2", ..#CLASSMARKER _ "Twin2Second"), "a second class declares the same name")
    Do ..EnableKey("analytics.qualitymeasures.delete")
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild("update", "{""Caption"":""x""}"), $ListBuild("copy", "{""NewName"":""" _ ..Name("Twin2Copy") _ """,""NewClass"":""" _ ..#CLASSMARKER _ "Twin2Copy""}"), $ListBuild("delete", "") {
        Set tValues = $Select($List(tCase, 2) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2)))
        Set tStatus = ..Act(..#MEASURESCREEN, $List(tCase, 1), tName, tValues, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.QUALITYMEASURE.AMBIGUOUS", "the person's " _ $List(tCase, 1) _ " is refused: " _ $Select($IsObject($Get(tAnswer)): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    }
    Do ..MintRefused(..#COPYTOOL, {"Name": (tName), "NewName": (..Name("Twin2Copy")), "NewClass": (..#CLASSMARKER _ "Twin2Copy")}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#DELETETOOL, {"Name": (tName)}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
}

}
