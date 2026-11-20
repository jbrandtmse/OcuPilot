/// <p>Pins Story 24.14 Batch 3's PMML definition create (AD-54, AD-55, AD-59, AD-61, AD-65) against <code>USER</code>, with analytics on through <class>OcuPilot.Test.AnalyticsProbe</class> and
/// classes named <code>ProbePmml.New</code> and a marker: the person's New PMML definition and the agent's <code>analytics.pmmlmodels.add</code> proposal, minted and confirmed over HTTP, each make a
/// compiled definition class whose <code>PMML</code> XData equals the text sent and that the PMML models list reports model for model, with the read-back verdict <code>matches</code> and one audit
/// row of OcuPilot's own; the script form makes the same class and, run once the name is taken, changes nothing; and the baseline ships the key on. The helpers are
/// <class>OcuPilot.Test.AnalyticsPmmlCreateBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. One class per run.</p>
Class OcuPilot.Test.AnalyticsPmmlCreate Extends OcuPilot.Test.AnalyticsPmmlCreateBase
{

/// <p>AC1, AC5: the person's New PMML definition and the agent's add proposal each make a compiled definition class whose <code>PMML</code> XData equals the text sent; the PMML models list reports
/// both of its models; each answers the AD-14 action <code>created</code> with the read-back verdict <code>matches</code> and leaves one audit row (the agent's also its marker and ledger row);
/// the agent's card states that the class is saved and compiled.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlDefinitionRow</method> answer an empty <code>PMML</code> -- the two read-back legs and the XData legs go red.</p>
Method TestADefinitionIsCreatedByEachCallerAndReadsBack()
{
    Set tText = ..Text()
    Set tPerson = ..Name("Person")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tPerson), "PMML": (tText)}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's New PMML definition answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.readBack.verdict, tPerson _ "|matches", "created, the read-back matching what was sent")
    Do $$$AssertEquals(..StoredText(tPerson), tText, "the class's PMML XData equals the text sent, line for line")
    Do $$$AssertEquals(..ListedModels(tPerson), $Parameter(..#PMML, "CREATEDMODELS"), "and the PMML models list reports each model the vendor reports for the class")
    Do $$$AssertEquals(..Rows(tSince, "pmml-definition", tPerson, "analytics.pmmlmodels.add"), 1, "one audit row names the create")

    Set tAgent = ..Name("Agent")
    Do ..Mint(..#ADDTOOL, {"Class": (tAgent), "PMML": (tText)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.PMML.SAVE|0", "the add's card states that the class is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ tAgent _ "|matches", "created, naming the class, the read-back matching")
    Do $$$AssertEquals(..StoredText(tAgent), tText, "the agent's class holds the text sent")
    Do $$$AssertEquals(..ListedModels(tAgent), $Parameter(..#PMML, "CREATEDMODELS"), "and the list reports both of its models")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ADDTOOL, tTurn, "pmml-definition", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5: the script form of the create makes the same class the write makes, with the text sent, and, run once the name is taken, changes nothing: the class, and the classes its compile
/// generated, are as they were.</p>
/// <p>Mutation (Rule 19): make the free-name condition of <method>OcuPilot.Port.AnalyticsPort.PmmlDefinitionSnippet</method> always true -- the run-again leg goes red.</p>
Method TestTheScriptFormMakesTheClassAndChangesNothingOnceTheNameIsTaken()
{
    Set tText = ..Text()
    Set tClass = ..Name("Script")
    Set tSteps = ..Script("ADD", tClass, {"Class": (tClass), "PMML": (tText)})
    Do $$$AssertEquals(tSteps.%Size(), 1, "the create has one script step")
    If tSteps.%Size() '= 1 Quit
    Do $$$AssertEquals(..RunScript(tSteps), 1, "the script runs to a success")
    Do $$$AssertEquals(..StoredText(tClass), tText, "and made the class with the text sent")
    Do $$$AssertEquals(..ListedModels(tClass), $Parameter(..#PMML, "CREATEDMODELS"), "whose models the list reports")
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tSteps), 0, "run again, the script reports the name taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and the class and every class its compile generated are as they were")
    Set tPackage = ..Name("ScriptPackage")
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tPackage _ ".Held", "Class " _ tPackage _ ".Held Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)), "a class is saved in the package of a free class name")
    Set tSteps = ..Script("ADD", tPackage, {"Class": (tPackage), "PMML": (tText)})
    Do $$$AssertEquals(..RunScript(tSteps), 0, "the script of a name whose package is held only reports the refusal")
    Do $$$AssertEquals(..ClassHeld(tPackage), 0, "and makes no class")
}

/// <p>The route the create adds answers JSON envelopes of the declared type and shape as the HTTP account: <code>POST /analytics/pmml-models</code> creates a definition (201
/// <code>{id, target, readBack}</code>); the same class again is a 409 envelope, a body with no class a 422 one and a body with an unknown member a 400 one.</p>
Method TestTheRouteAnswersJsonEnvelopesOfTheDeclaredShape()
{
    Set tText = ..Text()
    Set tClass = ..Name("Wire")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild({"Class": (tClass), "PMML": (tText)}.%ToJSON(), 201), $ListBuild({"Class": (tClass), "PMML": (tText)}.%ToJSON(), 409), $ListBuild({"PMML": (tText)}.%ToJSON(), 422), $ListBuild({"Class": (..Name("WireOther")), "PMML": (tText), "Unknown": 1}.%ToJSON(), 400) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/analytics/pmml-models?ns=USER", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, $List(tCase, 1), "application/json")
        Do $$$AssertEquals(tStatus, $List(tCase, 2), "POST /analytics/pmml-models answers " _ $List(tCase, 2) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tAnswer = ""
        Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tAnswer) {
            Do $$$AssertTrue(0, "its body is one JSON document")
            Continue
        }
        If $List(tCase, 2) = 201 Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.readBack.verdict, tClass _ "|matches", "the create names its target and reads back")
        If $List(tCase, 2) > 299 Do $$$AssertTrue(tAnswer.code '= "", "a refusal carries its code")
    }
}

/// <p>AC5: the baseline ships <code>analytics.pmmlmodels.add</code> on, which the governance gate reads.</p>
/// <p>Mutation (Rule 19): flip the key's line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>false</code> -- the leg goes red.</p>
Method TestTheBaselineShipsTheCreateOn()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Kill tDecision
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide("analytics.pmmlmodels.add", "write", $Username, {}, .tDecision), "the gate decides")
    Do $$$AssertEquals($Get(tDecision("allowed")), 1, "the create is allowed by the baseline")
}

}
