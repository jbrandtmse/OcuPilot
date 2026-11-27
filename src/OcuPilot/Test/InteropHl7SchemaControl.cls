/// <p>Pins Story 24.18 Batch 1's add and delete from both callers (AD-6, AD-10, AD-15, AD-22, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62): a person's New HL7 schema and the agent's confirmed add each create
/// a schema that reads back from the vendor's own export with the base and description sent, each leaving the vendor's own audit row and none of OcuPilot's; a person's Delete and the agent's
/// confirmed delete each remove a probe, the agent's behind its key and a typed, destructive card, and a standard schema is refused and untouched; and each write's script form renders the guards and the
/// vendor call, and no draft for a value the port would refuse by shape.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs.</p>
Class OcuPilot.Test.InteropHl7SchemaControl Extends OcuPilot.Test.InteropHl7Case
{

Parameter DELETEKEY = "interop.hl7schemas.delete";

/// <p>AC2: a person's Save and the agent's confirmed add each create a free name; each reads back from the vendor's export and the schema's own sets with the base and description it sent, the
/// agent's with no base; each leaves one vendor <code>Modify</code> row and no row of OcuPilot's own; the agent's confirm answers a creation, marked (AD-15), whose read-back matches.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Hl7VendorWrite</method> skip the description -- the read-back legs go red.</p>
Method TestAddFromBothCallersReadsBackAsSent()
{
    Set tFx = ..#FIXTURE
    Set tSince = ..AuditNow()
    Do $$$AssertEquals(..Save({"Name": (..#NAMEA), "Base": "2.5.1", "Description": "From the screen"}, .tAnswer), "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA), "2.5.1|From the screen|0", "the screen's schema holds its base and description")
    Set tBody = $ClassMethod(tFx, "Body", ..#NAMEA)
    Do $$$AssertTrue((tBody [ " name=""" _ ..#NAMEA _ ".HL7"">") && (tBody [ "description=""From the screen""") && (tBody [ "base=""2.5.1"""), "and the vendor's own export names them: " _ tBody)
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAMEA), 1, "the add leaves one vendor Modify row")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEA, .tData, 1, 1), 0, "and none of OcuPilot's own")
    Set tCode = ..Mint("Add", ..#NAMEB, {"Description": "From the agent"}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the agent's add mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-hl7-schema|USER|" _ ..#NAMEB, "its target is the schema, by its name")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEB), "<absent>", "nothing is written by the mint")
    Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tHttp, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEB), "|From the agent|0", "the agent's schema holds its description and no base")
    Do $$$AssertTrue(($ClassMethod(tFx, "Body", ..#NAMEB) [ "description=""From the agent""") && ($ClassMethod(tFx, "Body", ..#NAMEB) '[ "base="), "and the vendor's export names the description alone")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAMEB), 1, "one vendor Modify row")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAMEB, .tData, 1, 1), 0, "and none of OcuPilot's own")
}

/// <p>AC2: the Save route answers JSON over the wire: 201 with the schema's name as its id, its target and a matching read-back, and 409 <code>INTEROP.HL7.TAKEN</code> for the same name in any letter case,
/// with the held schema untouched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.IdOf</method> answer an empty id for an HL7 schema -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/hl7-schemas?ns=USER"
    Set tBody = {"Name": (..#NAMEA), "Base": "2.5", "Description": "Wire schema"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#NAMEA _ "|interop-hl7-schema|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name's id, its target and a matching read-back")
    For tName = ..#NAMEA, $ZConvert(..#NAMEA, "L") {
        Set tBody = {"Name": (tName)}
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus _ "|" _ ##class(%DynamicObject).%FromJSON(tRaw).code, "409|INTEROP.HL7.TAKEN", tName _ ": a held name is refused 409 with the envelope's code: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Text", ..#NAMEA), "2.5|Wire schema|0", "the held schema is untouched")
}

/// <p>AC4: a person's Delete removes a probe and the agent's confirmed delete another, the agent's refused while its key is off and its card destructive with the published consequence; each
/// leaves the vendor's own audit row; a standard schema is refused from both callers with <code>INTEROP.HL7.STANDARD</code> and its sets and the instance's fourteen standard schemas are untouched.</p>
/// <p>Mutation (Rule 19): remove the standard test from <method>OcuPilot.Port.InteropPort.Hl7WriteToken</method> and from <method>OcuPilot.Port.InteropPort.ReadHl7Schema</method> -- the vendor's own
/// guard still refuses, with another code, and the 409 assertions go red.</p>
Method TestDeleteFromBothCallersAndAStandardSchemaIsRefused()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "A"), "a probe is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEB, ..#SOURCE, "2.5.1", "B"), "and a second")
    Set tSince = ..AuditNow()
    Do $$$AssertEquals(..Act("delete", ..#NAMEA, "", .tAnswer), "200 ", "a person's Delete answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA), 0, "the probe is gone")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAMEA), 1, "with one vendor Modify row")
    Set tCode = ..Mint("Delete", ..#NAMEB, {}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the agent's delete mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.HL7.DELETE|1", "its card is destructive and states what the delete leaves")
    Do $$$AssertTrue(tProposal.changed.%ToJSON() [ ..#NAMEB, "and names the schema: " _ tProposal.changed.%ToJSON())
    Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tHttp), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the delete's key is off: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEB), 1, "and the schema stays")
    Do $$$AssertStatusOK(..EnableKeys(..#DELETEKEY), "the key is turned on")
    Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
    Do $$$AssertEquals(tHttp, 200, "the delete confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEB) _ "|" _ ..VendorRows(tSince, ..#NAMEB), "0|1", "the schema is gone, with one vendor Modify row")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tStandard = $ClassMethod(tFx, "Text", "2.5")
    Do $$$AssertEquals(..Act("delete", "2.5", "", .tAnswer), "409 INTEROP.HL7.STANDARD", "a person's delete of 2.5 is refused")
    Set tCode = ..Mint("Delete", "2.5", {}, .tReason, .tRefused, .tRefusedTurn)
    Do $$$AssertEquals(tCode _ "|" _ $IsObject($Get(tRefused)), "INTEROP.HL7.STANDARD|0", "and so is the agent's, at the mint")
    Do $$$AssertEquals($ClassMethod(tFx, "Text", "2.5") _ "|" _ $ClassMethod(tFx, "Standards"), tStandard _ "|14", "2.5 is untouched and the fourteen standard schemas are held")
    Do $$$AssertEquals($Get(tReason), $Parameter("OcuPilot.Api.InteropError", "REASONHL7STANDARD"), "with the published sentence")
}

/// <p>AC4, AC5: a delete the agent minted is closed as moved when the schema's description or base changed after the review, and the schema stays.</p>
/// <p>Mutation (Rule 19): narrow <code>FINGERPRINTSUBJECT</code> in <class>OcuPilot.Screen.Tool.InteropHl7SchemaDelete</class> to <code>Category,Namespace</code> -- both legs go red.</p>
Method TestADeleteMintedBeforeTheSchemaChangedIsClosedAsMoved()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "reviewed"), "a probe is stored")
    Do $$$AssertStatusOK(..EnableKeys(..#DELETEKEY), "the delete key is turned on")
    Set tOrigNS = $NAMESPACE
    For tMove = "Description", "base" {
        Set tCode = ..Mint("Delete", ..#NAMEA, {}, .tReason, .tProposal, .tTurn)
        Do $$$AssertEquals(tCode, "minted", tMove _ ": the delete mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Set $NAMESPACE = ..#SOURCE
        If tMove = "Description" Set ^EnsHL7.Description(..#NAMEA) = "changed after the review"
        If tMove = "base" Set ^EnsHL7.Schema(..#NAMEA, "base") = "2.5.1"
        Set $NAMESPACE = tOrigNS
        Do ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tConfirmed)
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", tMove _ ": a schema that changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA), 1, tMove _ ": and the schema stays")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC8: each write's script form renders the switch to the namespace, each refusal as one guard and the vendor call, with the schema's name and values as string literals, and renders no draft for a name
/// or a value or a file name the port would refuse by shape. Run line by line, an add's script stores a free name and only sets the refusal for a name held in another letter case, and a delete's script removes a held
/// probe and refuses a standard schema and one that is not held.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.Hl7SchemaSnippet</method> drop the held-name guard from an add -- the held-in-another-case run goes red. The delete script's standard guard is
/// pinned by its rendered text only, since the vendor's own delete refuses a standard schema in the run. Drop the file guard from <method>OcuPilot.Port.InteropPort.Hl7TransferSnippet</method> -- the
/// import's guard leg goes red; drop its file-name shape test -- the bad-file legs go red.</p>
Method TestTheScriptFormsRenderTheGuardsAndNoDraftForABadValue()
{
    Set tFx = ..#FIXTURE
    For tType = "ADDHL7SCHEMA", "DELETEHL7SCHEMA", "IMPORTHL7SCHEMA", "EXPORTHL7SCHEMA" {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = ..#NAMEA
        Set tQuery("root") = "/probe/dir/"
        Set tQuery("path") = "a.xml"
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery, {"Base": "2.5.1", "Description": "Script schema"})
        Set tText = ..StepText(tSteps)
        Do $$$AssertEquals(tSteps.%Size(), 1, tType _ ": the script is one step")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ ..#NAMEA), tType _ ": it switches the namespace and names the schema: " _ tText)
        If tType '= "EXPORTHL7SCHEMA" Do $$$AssertTrue((tText [ "IsEnabled($Namespace)") && (tText [ "Lock +^EnsHL7.Schema("), tType _ ": and guards source control and takes the vendor's lock: " _ tText)
        If tType = "ADDHL7SCHEMA" Do $$$AssertTrue((tText [ "Script schema") && (tText [ "$ZConvert(") && (tText [ "AuditModifySchema"), "the add carries the values, guards a name held in any letter case and records the vendor's audit")
        If tType = "DELETEHL7SCHEMA" Do $$$AssertTrue((tText [ "SchemaDocument).Delete(") && (tText [ """std"""), "the delete guards a standard schema and calls the vendor's delete")
        If tType = "IMPORTHL7SCHEMA" Do $$$AssertTrue((tText [ "$System.OBJ.Load(") && (tText [ "/probe/dir/"), "the import loads the one document by name")
        If tType = "IMPORTHL7SCHEMA" Do $$$AssertTrue((tText [ "LocalName = ""Category""") && (tText [ ##class(OcuPilot.Api.InteropError).#REASONHL7IMPORTSHAPE) && ($Length(tText, ##class(OcuPilot.Api.InteropError).#REASONHL7IMPORTSTANDARD) = 3) && (tText [ ##class(OcuPilot.Api.InteropError).#REASONHL7CASE), "and guards a file that is not one schema or marks one standard, a standard schema and one held in another letter case: " _ tText)
        If tType = "EXPORTHL7SCHEMA" Do $$$AssertTrue(tText [ "$System.OBJ.Export(", "the export calls the vendor's export")
    }
    Set tLong = $Translate($Justify("", 65), " ", "x")
    Set tDescription = $Translate($Justify("", 2001), " ", "d")
    For tBad = $ListBuild("ADDHL7SCHEMA", "", "{}"), $ListBuild("ADDHL7SCHEMA", "a b", "{}"), $ListBuild("ADDHL7SCHEMA", "-x", "{}"), $ListBuild("ADDHL7SCHEMA", tLong, "{}"), $ListBuild("ADDHL7SCHEMA", ..#NAMEA, "{""Base"":5}"), $ListBuild("ADDHL7SCHEMA", ..#NAMEA, "{""Description"":5}"), $ListBuild("ADDHL7SCHEMA", ..#NAMEA, "{""Description"":""" _ tDescription _ """}"), $ListBuild("DELETEHL7SCHEMA", "a b", "{}"), $ListBuild("DELETEHL7SCHEMA", "", "{}"), $ListBuild("EXPORTHL7SCHEMA", tLong, "{}") {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tBad, 2)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, ##class(%DynamicAbstractObject).%FromJSON($List(tBad, 3)))
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " of '" _ $Extract($List(tBad, 2), 1, 12) _ "' with " _ $Extract($List(tBad, 3), 1, 24) _ " renders no draft")
    }
    For tBad = $ListBuild("IMPORTHL7SCHEMA", "../a.xml"), $ListBuild("IMPORTHL7SCHEMA", "a" _ $Char(10) _ ".xml"), $ListBuild("EXPORTHL7SCHEMA", "x/../../a.xml"), $ListBuild("EXPORTHL7SCHEMA", $Translate($Justify("", 256), " ", "f")) {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = ..#NAMEA
        Set tQuery("root") = "/probe/dir/"
        Set tQuery("path") = $List(tBad, 2)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, "")
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " of the file '" _ $Extract($Translate($List(tBad, 2), $Char(10), " "), 1, 16) _ "' renders no draft")
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Foreign", ..#SOURCE) _ "|" _ $ClassMethod(tFx, "SchemasLeft"), "0|0", "rendering ran nothing and stored nothing")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", $ZConvert(..#NAMEB, "L")), "a schema is held under the lower-case spelling of a second name")
    For tCase = $ListBuild(..#NAMEA, 1), $ListBuild(..#NAMEB, 0) {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tCase, 1)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ADDHL7SCHEMA", .tQuery, {"Base": "2.5.1", "Description": "Script"})
        Set tNS = $NAMESPACE
        Set tRan = ..RunScript(tSteps)
        Set $NAMESPACE = tNS
        Do $$$AssertEquals(tRan, $List(tCase, 2), $List(tCase, 1) _ ": the add's script " _ $Select($List(tCase, 2): "adds the free name", 1: "only sets the refusal for a name held in another letter case"))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Text", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Held", ..#NAMEB), "2.5.1|Script|0|0", "the free name was added as the script had it, and the other spelling was not")
    For tCase = $ListBuild(..#NAMEA, 1), $ListBuild("2.5", 0), $ListBuild("OcuProbe2418nobody", 0) {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tCase, 1)
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "DELETEHL7SCHEMA", .tQuery, "")
        Set tNS = $NAMESPACE
        Set tRan = ..RunScript(tSteps)
        Set $NAMESPACE = tNS
        Do $$$AssertEquals(tRan, $List(tCase, 2), $List(tCase, 1) _ ": the delete's script " _ $Select($List(tCase, 2): "removes a held probe", 1: "refuses a standard schema and one that is not held"))
    }
    Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NAMEA) _ "|" _ $ClassMethod(tFx, "Standards"), "0|14", "the probe is gone and the standard schemas are held")
}

}
