/// <p>Pins Story 24.14 Batch 4's PMML export to a cube (AD-7, AD-15, AD-22, AD-58, AD-65) against <code>USER</code>, with the real compiler and the probe's categorical model <code>Colors</code>: the person's Export to cube
/// and the agent's <code>analytics.pmmlmodel.export</code> proposal, minted and confirmed over HTTP, each run the model's own test and make a result class that holds exactly the run's records, value for value, and a
/// cube class restricted to that test, whose cube the Cubes list shows unbuilt; the test's rows are dropped, the read-back reads <code>matches</code> and one audit row of OcuPilot's own is recorded; the other
/// two sources, and a link to a source class, export the same way; and the baseline ships the key on. The helpers are <class>OcuPilot.Test.AnalyticsPmmlExportBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It creates the probe's source table and definition in <code>USER</code>, and makes and removes classes under <code>ProbePmml.Export</code> and cubes
/// named <code>ProbePmmlExport</code> there.</p>
Class OcuPilot.Test.AnalyticsPmmlExport Extends OcuPilot.Test.AnalyticsPmmlExportBase [ DependsOn = OcuPilot.Test.PmmlProbe ]
{

/// <p>AC1, AC4, AC5: the person's Export to cube and the agent's confirmed proposal each answer the AD-14 action <code>updated</code> with the read-back <code>matches</code>, make the two classes and the cube,
/// copy exactly the run's records into the result class and leave no vendor result row; the person's answer carries the three names and the number of rows for the screen; the agent's card states the export's
/// consequence, titles the model and shows the source and the names; each leaves one audit row (the agent's also its marker and ledger row).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlCopy</method> copy nothing -- both callers' record legs go red.</p>
Method TestAnExportIsMadeByEachCallerAndReadsBack()
{
    Set tOracle = ..OracleAnswer("dataset")
    Do $$$AssertEquals(tOracle.outcome _ "|" _ tOracle.records, "ran|12", "the model's own test over the probe's data source reads twelve records")
    Set tExpected = ..AnswerValues(tOracle)
    Do $$$AssertEquals(tExpected, "high=6;low=6;", "six of each value")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..ExportAct(..ExportValues("Person"), .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Export to cube answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching what was sent")
        Do $$$AssertEquals(tAnswer.output.ResultClass _ "|" _ tAnswer.output.CubeClass _ "|" _ tAnswer.output.Cube _ "|" _ tAnswer.output.Records, ..ExportClass("Person") _ "|" _ ..ExportCubeClass("Person") _ "|" _ ..ExportCube("Person") _ "|12", "the screen is answered the three names and the records copied")
    }
    Do ..AssertExported("Person", tExpected, 12, "the person's export")
    Do $$$AssertEquals(..Rows(tSince, "pmml-model", ..ModelId(), "analytics.pmmlmodel.export"), 1, "one audit row names the person's export")
    Do $$$AssertTrue(..Recorded(tSince, ..ModelId(), "analytics.pmmlmodel.export", "applied", "pmml-model"), "recording its outcome")

    Do ..Mint(..#EXPORTTOOL, ..ExportArgs("Agent"), .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tKey = tProposal.proposalId
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive") + 0) _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TargetName"), "ANALYTICS.PMML.EXPORT|0|" _ $Parameter(..#PMML, "CATEGORICAL"), "the card states the export's consequence and titles the model")
    Set tFields = ""
    For tAt = 0:1:tProposal.changed.%Size() - 1 {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tProposal.changed.%Get(tAt).field
    }
    Do $$$AssertEquals(tFields, "Source,DataSource,ResultClass,CubeClass,Cube", "and shows the source and the names")
    Do $$$AssertEquals(..ExportLeft("Agent"), "", "nothing is made by the mint")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the proposal confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do ..AssertExported("Agent", tExpected, 12, "the agent's export")
    Do ..AssertAgentRecords(tSince, tProposal, ..#EXPORTTOOL, tTurn, "pmml-model", ..ModelId())
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1: the test's other sources export too: the model's verification records, one custom SQL query and the data source with a link to the source class, whose result class holds a
/// <code>Record</code> that resolves to the source row; each equals the port's own run of the same source, value for value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> pass the dataset's name for every source -- the verification and custom legs go red.</p>
Method TestTheOtherSourcesAndALinkToTheSourceClassExportToo()
{
    For tSource = "verification", "custom" {
        Set tOracle = ..OracleAnswer(tSource)
        Do $$$AssertEquals(tOracle.outcome, "ran", tSource _ ": the oracle's own test ran")
        Set tMarker = $ZConvert($Extract(tSource, 1), "U") _ $Extract(tSource, 2, *)
        Do $$$AssertEquals(..ExportAct(..ExportValues(tMarker, tSource), .tAnswer), 200, tSource _ ": the export is made: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
        Do ..AssertExported(tMarker, ..AnswerValues(tOracle), tOracle.records, tSource)
    }
    Set tLinked = ..ExportValues("Linked")
    Do tLinked.%Set("SourceClass", $ZConvert($Parameter(..#PMML, "SOURCECLASS"), "L"), "string")
    Do $$$AssertEquals(..Export(tLinked, .tRes), "200 ", "an export with a link to the source class, spelled in another case, is made")
    Do ..AssertExported("Linked", ..AnswerValues(..OracleAnswer("dataset")), 12, "linked")
    Set tText = ..TextOf(..ExportClass("Linked"))
    Do $$$AssertTrue(tText [ ("Property Record As " _ $Parameter(..#PMML, "SOURCECLASS") _ " "), "the result class links to the class by its stored name")
    Do $$$AssertEquals(..LinkedX(..ExportClass("Linked"), "5"), 5, "and a record resolves to its source row")
}

/// <p>AC5: the baseline ships <code>analytics.pmmlmodel.export</code> on, which the governance gate reads.</p>
/// <p>Mutation (Rule 19): flip the key's line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>false</code> -- the leg goes red.</p>
Method TestTheBaselineShipsTheExportOn()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Kill tDecision
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide("analytics.pmmlmodel.export", "write", $Username, {}, .tDecision), "the gate decides")
    Do $$$AssertEquals($Get(tDecision("allowed")), 1, "the export is allowed by the baseline")
}

}
