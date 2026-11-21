/// <p>Pins the refusals of Story 24.14 Batch 4's PMML export to a cube (AD-8, AD-10, AD-22, AD-54, AD-65) against <code>USER</code>, with the real compiler: a class of OcuPilot's own, a malformed name, two classes that are one
/// or nested, a held class, package or cube, a cube name outside the vendor's bound, a class to link to that is absent and a source that is not a query are each refused by the port, the person's action and the agent's mint
/// with their own codes and nothing is made; a name taken between the mint and the confirm closes the proposal as target-changed; a test that fails or outlasts its bound, a cube class the compiler refuses and a copy that
/// fails leave no class, cube, row or data and record the outcome <code>restored</code>; the gate refuses before any lookup; the agent's confirm is refused with its key off while the person's action runs; and the export's script form
/// makes what the write makes, changes nothing when a name is taken, restores when a step fails and spells no hostile name. The helpers are <class>OcuPilot.Test.AnalyticsPmmlExportBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes classes under <code>ProbePmml.Export</code> and cubes named <code>ProbePmmlExport</code> in <code>USER</code>, and rewrites the stored
/// governance policy, which it restores after each test.</p>
Class OcuPilot.Test.AnalyticsPmmlExportEdge Extends OcuPilot.Test.AnalyticsPmmlExportBase [ DependsOn = OcuPilot.Test.PmmlProbe ]
{

Parameter SEAM = "OcuPilot.Test.AnalyticsListingGroupDatabaseSeam";

/// <p>The write seam <method>Compiling</method> drives: the port that fails a step of the export when armed.</p>
Parameter COMPILESEAM = "OcuPilot.Test.PmmlPortExport";

/// <p>A cross join of four copies of the source table: twenty thousand records, which the export's test reads for longer than a bound of 0.01 seconds.</p>
Parameter FOURWAY = "SELECT a.ID, a.X, a.Color, a.Y FROM ProbePmml.Source a, ProbePmml.Source b, ProbePmml.Source c, ProbePmml.Source d";

/// <p>A query the instance cannot prepare: it names a table that is not there.</p>
Parameter FAILING = "SELECT ID, X, Color, Y FROM ProbePmml.NoSuchTable";

/// <p>The export of <var>pValues</var> is refused with the HTTP status <var>pHttp</var> and the code <var>pCode</var> by the port, by the person's action (with the published sentence) and by the agent's mint, and nothing
/// is saved, changed or deleted. <var>pWhat</var> names the case in each message.</p>
Method AssertRefused(pWhat As %String, pValues As %DynamicObject, pHttp As %Integer, pCode As %String)
{
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..Export(pValues, .tRes), pHttp _ " " _ pCode, pWhat _ ": the port refuses it")
    Set tStatus = ..ExportAct(pValues, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), pHttp _ " " _ pCode _ "|" _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor(pCode), pWhat _ ": the person's action refuses it, with the published sentence")
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pValues.%ToJSON())
    Do tArgs.%Set("Model", ..ModelSpelled(), "string")
    Do ..MintRefused(..#EXPORTTOOL, tArgs, pCode)
    Do $$$AssertEquals(..Snapshot(), tBefore, pWhat _ ": nothing was saved, changed or deleted")
    Do $$$AssertEquals($ClassMethod(..#PMML, "Rows"), 0, pWhat _ ": and no vendor result row is left")
}

/// <p>The class <var>pName</var> saved directly, empty, so that a name or a package is held without an export.</p>
ClassMethod Hold(pName As %String) As %Status
{
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pName, "Class " _ pName _ " Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10))
}

/// <p>AC2: a class of OcuPilot's own in the result class, the cube class or the class to link to is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> by the port, the person's action and the agent's mint; a result or cube class with a
/// <code>%</code>, with no package or with a character a class cannot hold is refused 422 <code>ANALYTICS.PMML.CLASS</code> by each; nothing is saved.</p>
/// <p>Mutation (Rule 19): drop the own-code test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> -- the own-code legs go red; make <method>OcuPilot.Port.AnalyticsPort.ListingClassShaped</method> accept a <code>%</code> name -- the shape legs go red.</p>
Method TestAnOwnClassAndAMalformedNameAreRefused()
{
    For tField = "ResultClass", "CubeClass", "SourceClass" {
        Set tValues = ..ExportValues("Own" _ tField)
        Do tValues.%Set(tField, "OcuPilot.ProbePmmlExport", "string")
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(tValues.%ToJSON())
        Do tArgs.%Set("Model", ..ModelSpelled(), "string")
        Do ..AssertOwnCodeRefused("an OcuPilot class as " _ tField, ..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), tValues, "", ..#EXPORTSCREEN, "export", tValues, ..#EXPORTTOOL, tArgs)
    }
    For tField = "ResultClass", "CubeClass" {
        For tName = "%ProbePmmlExport.Shape", "NoPackage", "ProbePmml.Export Space", "ProbePmml..ExportDots", "9ProbePmml.ExportDigit" {
            Set tValues = ..ExportValues("Shape")
            Do tValues.%Set(tField, tName, "string")
            Do ..AssertRefused(tField _ " " _ tName, tValues, 422, "ANALYTICS.PMML.CLASS")
        }
    }
}

/// <p>AC2: a result class and a cube class that are one class, or one of which is in the other's package, are refused 422 <code>ANALYTICS.PMML.SAME</code> by the port, the person's action and the agent's mint, in any case; two classes
/// of the same package that are neither are made.</p>
/// <p>Mutation (Rule 19): drop the package legs of the test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> -- the nested legs go red.</p>
Method TestTwoClassesThatAreOneOrNestedAreRefused()
{
    Set tResult = ..ExportClass("Same")
    Set tCases = $ListBuild($ListBuild("one class", tResult, tResult), $ListBuild("one class in another case", tResult, $ZConvert(tResult, "U")), $ListBuild("the cube class in the result class's package", tResult, tResult _ ".Cube"), $ListBuild("the result class in the cube class's package", tResult _ ".Result", tResult), $ListBuild("a nested pair in other cases", $ZConvert(tResult, "L"), $ZConvert(tResult, "U") _ ".Inner"))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tValues = ..ExportValues("Same")
        Do tValues.%Set("ResultClass", $List(tCase, 2), "string")
        Do tValues.%Set("CubeClass", $List(tCase, 3), "string")
        Do ..AssertRefused($List(tCase, 1), tValues, 422, "ANALYTICS.PMML.SAME")
    }
    Do $$$AssertEquals(..Export(..ExportValues("Same"), .tRes), "200 ", "a cube class that merely starts with the result class's name, as the defaults do, is made")
}

/// <p>AC2, AC3: a held result class, a held cube class, a class held alone, a package held alone and a case variant of each are refused 409 <code>ANALYTICS.PMML.TAKEN</code> by the port, the person's action and the agent's mint, and
/// a cube the namespace holds 409 <code>ANALYTICS.PMML.CUBETAKEN</code>, and the held classes, their generated classes and the held cube are as they were; the export's read answers each held name and which are held, and
/// nothing for a free one.</p>
/// <p>Mutation (Rule 19): drop the package test of <method>OcuPilot.Port.AnalyticsPort.PmmlHeldClass</method> -- the package legs go red; drop the cube test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> -- the cube legs go red.</p>
Method TestAHeldClassPackageOrCubeIsRefusedAndNothingIsTouched()
{
    Do $$$AssertEquals(..Export(..ExportValues("Held"), .tRes), "200 ", "an export is made")
    Set tPlain = ..ExportClass("Plain")
    Do $$$AssertStatusOK(..Hold(tPlain), "a class is saved whose package holds no class")
    Set tPackage = ..ExportClass("Package")
    Do $$$AssertStatusOK(..Hold(tPackage _ ".Inside"), "a class is saved in a package whose own name no class holds")
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..ClassHeld(tPlain) _ "|" _ ..PackageHeld(tPlain) _ "|" _ ..ClassHeld(tPackage) _ "|" _ ..PackageHeld(tPackage), "1|0|0|1", "the lookups read a class held alone and a package held alone")
    Set tCases = $ListBuild($ListBuild("the held result class", "ResultClass", ..ExportClass("Held")), $ListBuild("its case variant", "ResultClass", $ZConvert(..ExportClass("Held"), "L")), $ListBuild("the held cube class", "CubeClass", ..ExportCubeClass("Held")), $ListBuild("the cube class's package as a class", "ResultClass", ..ExportCubeClass("Held")), $ListBuild("a class held alone", "ResultClass", tPlain), $ListBuild("its case variant", "CubeClass", $ZConvert(tPlain, "U")), $ListBuild("a package held alone", "ResultClass", tPackage), $ListBuild("its case variant", "CubeClass", $ZConvert(tPackage, "L")))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tValues = ..ExportValues("Taken")
        Do tValues.%Set($List(tCase, 2), $List(tCase, 3), "string")
        Do ..AssertRefused($List(tCase, 1), tValues, 409, "ANALYTICS.PMML.TAKEN")
    }
    Set tValues = ..ExportValues("Taken")
    Do tValues.%Set("Cube", ..ExportCube("Held"), "string")
    Do ..AssertRefused("a cube the namespace holds", tValues, 409, "ANALYTICS.PMML.CUBETAKEN")
    Set tValues = ..ExportValues("Taken")
    Do tValues.%Set("Cube", $ZConvert(..ExportCube("Held"), "L"), "string")
    Do ..AssertRefused("the same cube in another case", tValues, 409, "ANALYTICS.PMML.CUBETAKEN")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was saved, changed or deleted")
    Do $$$AssertEquals(..ResultRows(..ExportClass("Held")), 12, "and the held export still holds its twelve rows")
    Do $$$AssertEquals(..Port(..#EXPORTENDPOINT, "PMMLEXPORT", ..ModelSpelled(), "", {"ResultClass": (..ExportClass("Held")), "CubeClass": (..ExportCubeClass("Held")), "Cube": (..ExportCube("Held"))}, .tRow), "200 ", "the read of the held names answers a row")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.%Get("ResultClass") _ "|" _ tRow.%Get("CubeClass") _ "|" _ tRow.%Get("Cube") _ "|" _ tRow.%Get("Held"), ..ExportClass("Held") _ "|" _ ..ExportCubeClass("Held") _ "|" _ ..ExportCube("Held") _ "|ResultClass,CubeClass,Cube", "with the held names and which are held")
    Do $$$AssertEquals(..Port(..#EXPORTENDPOINT, "PMMLEXPORT", ..ModelSpelled(), "", {"ResultClass": (..ExportClass("Fresh")), "CubeClass": (..ExportCubeClass("Fresh")), "Cube": (..ExportCube("Fresh"))}, .tRow), "200 ", "the read of free names answers a row")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.%Get("ResultClass") _ "|" _ tRow.%Get("CubeClass") _ "|" _ tRow.%Get("Cube") _ "|" _ tRow.%Get("Held"), "|||", "with no name and none held")
    Do $$$AssertEquals(..Port(..#EXPORTENDPOINT, "PMMLEXPORT", "OcuPilotProbe.Pmml.Definition||NoSuchModel", "", "", .tRow), "404 ANALYTICS.PMML.ABSENT", "and the read of a model that is not there is 404")
}

/// <p>AC2: a cube name over 250 characters, one with a control character or a <code>}</code> and an empty one are refused 422 <code>ANALYTICS.PMML.CUBENAME</code>, and a class to link to that the namespace does not hold, a <code>%</code> class
/// and one with no package are refused 422 <code>ANALYTICS.PMML.SOURCECLASS</code>, by the port, the person's action (but the empty name, which its route does not admit) and the agent's mint.</p>
/// <p>Mutation (Rule 19): compare the cube name's length with 251 in <method>OcuPilot.Port.AnalyticsPort.PmmlCubeNameShaped</method> -- the long leg goes red; drop its brace test -- the brace leg goes red.</p>
Method TestACubeNameOutsideTheBoundAndAnAbsentClassToLinkAreRefused()
{
    Set tLong = $Translate($Justify("", 251), " ", "x")
    Set tCases = $ListBuild($ListBuild("251 characters", tLong), $ListBuild("a brace", "Bad}Name"), $ListBuild("a tab", "Bad" _ $Char(9) _ "Name"), $ListBuild("a line feed", "Bad" _ $Char(10) _ "Name"))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tValues = ..ExportValues("Name")
        Do tValues.%Set("Cube", $List(tCase, 2), "string")
        Do ..AssertRefused($List(tCase, 1), tValues, 422, "ANALYTICS.PMML.CUBENAME")
    }
    Set tValues = ..ExportValues("Name")
    Do tValues.%Set("Cube", "", "string")
    Do $$$AssertEquals(..Export(tValues, .tRes), "422 ANALYTICS.PMML.CUBENAME", "an empty cube name is refused by the port")
    For tName = "ProbePmml.NoSuchSourceClass", "%Library.String", "NoPackage" {
        Set tValues = ..ExportValues("Source")
        Do tValues.%Set("SourceClass", tName, "string")
        Do ..AssertRefused("the class to link to " _ tName, tValues, 422, "ANALYTICS.PMML.SOURCECLASS")
    }
    Set tValues = ..ExportValues("Spaced")
    Do tValues.%Set("Cube", "Probe Cube With Spaces", "string")
    Do $$$AssertEquals(..Export(tValues, .tRes), "200 ", "a cube name with spaces is made")
    Do $$$AssertEquals(..CubeHeld("Probe Cube With Spaces"), 1, "and registered under it")
}

/// <p>AC2: a name taken between the mint and the confirm closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, for a result class, for a package and for a cube, and what the other caller made is as it was.</p>
/// <p>Mutation (Rule 19): drop <code>Held</code> from the read <method>OcuPilot.Port.AnalyticsPort.ReadPmmlExport</method> answers -- the confirms write over the taken names and the legs go red.</p>
Method TestANameTakenAfterTheMintClosesTheProposal()
{
    For tCase = "result class", "package", "cube" {
        Set tMarker = "Race" _ $Translate(tCase, " ")
        Do ..Mint(..#EXPORTTOOL, ..ExportArgs(tMarker), .tProposal, .tTurn)
        If '$IsObject($Get(tProposal)) Continue
        If tCase = "result class" Do $$$AssertStatusOK(..Hold(..ExportClass(tMarker)), "the result class is saved after the mint")
        If tCase = "package" Do $$$AssertStatusOK(..Hold(..ExportClass(tMarker) _ ".Inside"), "a class of the result class's package is saved after the mint")
        If tCase = "cube" {
            Set tTaker = ..ExportValues(tMarker _ "Taker")
            Do tTaker.%Set("Cube", ..ExportCube(tMarker), "string")
            Do $$$AssertEquals(..Export(tTaker, .tRes), "200 ", "an export takes the cube's own name after the mint")
        }
        Set tBefore = ..Snapshot()
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", tCase _ ": the confirm is refused as moved: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals(..Snapshot(), tBefore, tCase _ ": nothing was written")
        Do $$$AssertEquals(..ClassHeld(..ExportCubeClass(tMarker)), 0, tCase _ ": no cube class was made")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC3: a test that cannot be prepared (a query over a table that is not there) is refused 422 <code>ANALYTICS.PMML.EXPORTRUN</code> by the port, the person's action and the agent's mint; a vendor run that answers an error after the result class
/// is saved, and a test that outlasts a short bound (each a seam), are refused the same; no result class, cube class, cube, result row, data global or vendor result row remains, and the audit row of a write that reached a class records the outcome
/// <code>restored</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PerformPmmlExport</method> skip the restore of the result class -- the seam legs go red on the class left; drop the preparation check from
/// <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> -- the first leg goes red.</p>
Method TestATestThatDoesNotFinishLeavesNothing()
{
    Set tBefore = ..Snapshot()
    Set tUnprepared = ..ExportValues("Failing", "custom")
    Do tUnprepared.%Set("SQL", ..#FAILING, "string")
    Do ..AssertRefused("a statement the instance cannot prepare", tUnprepared, 422, "ANALYTICS.PMML.EXPORTRUN")
    Do $$$AssertEquals(..ExportLeft("Failing"), "", "and leaves nothing")
    Do $ClassMethod(..#COMPILESEAM, "Reset")
    Do $ClassMethod(..#COMPILESEAM, "Arm", "vendor", "error")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Compiling(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), ..ExportValues("VendorError")), "422 ANALYTICS.PMML.EXPORTRUN", "a vendor run that answers an error is refused")
    Do $$$AssertEquals(..ExportLeft("VendorError"), "", "and leaves nothing: " _ ..ExportLeft("VendorError"))
    Do $$$AssertTrue(..Recorded(tSince, ..ModelId(), "analytics.pmmlmodel.export", "restored", "pmml-model"), "and the audit row records the outcome restored")
    Do $ClassMethod(..#COMPILESEAM, "Reset")
    Do $ClassMethod(..#COMPILESEAM, "Arm", "bound", 0.01)
    Set tSlow = ..ExportValues("Slow", "custom")
    Do tSlow.%Set("SQL", ..#FOURWAY, "string")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Compiling(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), tSlow), "422 ANALYTICS.PMML.EXPORTRUN", "a test that outlasts its bound is refused")
    Do $$$AssertEquals(..ExportLeft("Slow"), "", "and leaves nothing: " _ ..ExportLeft("Slow"))
    Do $$$AssertTrue(..Recorded(tSince, ..ModelId(), "analytics.pmmlmodel.export", "restored", "pmml-model"), "and the audit row records the outcome restored")
    Do $ClassMethod(..#COMPILESEAM, "Reset")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class of any of the writes is left")
}

/// <p>AC3: a cube class the compiler refuses and a copy that fails (each a seam), and a cube name the real compile refuses (one of 250 characters), are refused 422 <code>ANALYTICS.PMML.EXPORTCOMPILE</code> by the port, and the real refusal by the person's
/// action and the agent's confirm too; neither class, nor a class of either package, nor the cube, nor the result class's rows or data, nor a vendor result row remains, and the audit row records the outcome <code>restored</code>; unarmed, an
/// export of an ordinary name is made.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlExportRestore</method> skip the result class -- every leg goes red; skip the extent kill in <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> -- the copy leg's data leg goes red.</p>
Method TestAStepThatFailsRestoresEverything()
{
    Set tBefore = ..Snapshot()
    For tSeam = "cubetext", "copy" {
        Do $ClassMethod(..#COMPILESEAM, "Reset")
        Do $ClassMethod(..#COMPILESEAM, "Arm", tSeam, $Select(tSeam = "cubetext": "bad", 1: "fail"))
        Set tMarker = $Select(tSeam = "cubetext": "BadCube", 1: "BadCopy")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..Compiling(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), ..ExportValues(tMarker)), "422 ANALYTICS.PMML.EXPORTCOMPILE", tSeam _ ": the export is refused")
        Do $$$AssertEquals(..ExportLeft(tMarker), "", tSeam _ ": nothing remains: " _ ..ExportLeft(tMarker))
        Do $$$AssertEquals(..Snapshot(), tBefore, tSeam _ ": no class of the write is left")
        Do $$$AssertTrue(..Recorded(tSince, ..ModelId(), "analytics.pmmlmodel.export", "restored", "pmml-model"), tSeam _ ": the audit row records the outcome restored")
    }
    Do $ClassMethod(..#COMPILESEAM, "Reset")
    Set tLong = $Translate($Justify("", 250), " ", "x")
    Set tValues = ..ExportValues("LongName")
    Do tValues.%Set("Cube", tLong, "string")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Export(tValues, .tRes), "422 ANALYTICS.PMML.EXPORTCOMPILE", "a cube name of 250 characters is passed by the plan and refused by the compile")
    Do $$$AssertEquals(..ExportLeft("LongName"), "", "and nothing remains: " _ ..ExportLeft("LongName"))
    Do $$$AssertTrue(..Recorded(tSince, ..ModelId(), "analytics.pmmlmodel.export", "restored", "pmml-model"), "and the audit row records the outcome restored")
    Set tQuoted = ..ExportValues("Quoted")
    Do tQuoted.%Set("Cube", "Probe ""Quoted"" & <Cube>'s", "string")
    Do $$$AssertEquals(..Export(tQuoted, .tRes), "422 ANALYTICS.PMML.EXPORTCOMPILE", "so is a cube name with a double quote, an ampersand, angle brackets and an apostrophe")
    Do $$$AssertEquals(..ExportLeft("Quoted"), "", "and nothing remains: " _ ..ExportLeft("Quoted"))
    Set tPerson = ..ExportValues("LongPerson")
    Do tPerson.%Set("Cube", tLong, "string")
    Set tStatus = ..ExportAct(tPerson, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), "422 ANALYTICS.PMML.EXPORTCOMPILE|" _ ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLEXPORTCOMPILE, "the person's action answers the same, with the published sentence")
    Do $$$AssertEquals(..ExportLeft("LongPerson"), "", "and leaves nothing")
    Set tAgent = ..ExportArgs("LongAgent")
    Do tAgent.%Set("Cube", tLong, "string")
    Do ..Mint(..#EXPORTTOOL, tAgent, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.EXPORTCOMPILE", "the agent's confirm answers the same: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals(..ExportLeft("LongAgent"), "", "and leaves nothing")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class of any of the writes is left")
    Do $$$AssertEquals(..Compiling(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), ..ExportValues("Unarmed")), "200 ", "unarmed, an export of ordinary names is made")
    Do $$$AssertEquals(..CubeHeld(..ExportCube("Unarmed")), 1, "and its cube is registered")
}

/// <p>AC2: in process, through the gate seam, the export is refused before any lookup for a caller without <code>%Development:USE</code> or the portal pair (403 naming it), without WRITE on the routines database, and without WRITE on the
/// database <code>^DeepSee.Fact</code> maps to (a seam names another resource), for a free name and a held one alike; a routines database that is read-only is refused 409 <code>ANALYTICS.PMML.READONLY</code> and a fact database that is
/// read-only 409 <code>ANALYTICS.CUBE.READONLY</code>; a namespace without analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>; a source that is not a query is refused 422 <code>ANALYTICS.PMML.QUERYONLY</code> by every caller.</p>
/// <p>Mutation (Rule 19): drop the fact database's test from <method>OcuPilot.Port.AnalyticsPort.AdmitPmmlExport</method> -- the fact legs go red; make it admit every caller -- the pair legs go red; skip the kind test in <method>OcuPilot.Port.AnalyticsPort.PlanPmmlExport</method> -- the source legs go red.</p>
Method TestTheGateRefusesBeforeAnyLookupAndASourceThatIsNotAQueryIsRefused()
{
    Do $$$AssertEquals(..Export(..ExportValues("Gate"), .tRes), "200 ", "an export is made, so that a held name can be asked for")
    Set tBody = ..ExportValues("Gate")
    Set tFree = ..ExportValues("GateFree")
    Set tBefore = ..Snapshot()
    For tValues = tBody, tFree {
        For tExcept = "%DeepSee_Portal:USE", "%Development:USE", "%DB_USER:WRITE" {
            Do ..HoldEverythingBut(tExcept)
            Set tResult = ..Seamed(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), tValues, .tRes)
            Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|" _ tExcept, tValues.%Get("ResultClass") _ ": the export without " _ tExcept _ " is refused naming it: " _ tResult)
        }
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "factresource", "%DB_PMMLEXPORTFACT")
    Do ..HoldEverythingBut("")
    Set tResult = ..Seamed(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), tFree, .tRes)
    Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|%DB_PMMLEXPORTFACT:WRITE", "an export without WRITE on the fact database's resource is refused naming it: " _ tResult)
    For tArm = $ListBuild("pmmldatabase", "readonly", "409 ANALYTICS.PMML.READONLY"), $ListBuild("pmmldatabase", "unmounted", "409 ANALYTICS.PMML.READONLY"), $ListBuild("factdatabase", "readonly", "409 ANALYTICS.CUBE.READONLY"), $ListBuild("factdatabase", "unmounted", "409 ANALYTICS.CUBE.READONLY") {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", $List(tArm, 1), $List(tArm, 2))
        Do ..HoldEverythingBut("")
        Set tResult = ..Seamed(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), tFree, .tRes)
        Do $$$AssertEquals(tResult, $List(tArm, 3), "with the " _ $List(tArm, 1) _ " " _ $List(tArm, 2) _ " the export is refused: " _ tResult)
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Kill tQuery
    Set tQuery("namespace") = "HSCUSTOM"
    Set tQuery("id") = ..ModelId()
    Do ..HoldEverythingBut("")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#EXPORTENDPOINT, "TOCUBE", .tQuery, tFree, .tRes, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused")
    Do $ClassMethod(..#GATE, "Reset")
    Set tChanges = ..ExportValues("Changes")
    Do tChanges.%Set("DataSource", $Parameter(..#PMML, "CHANGESOURCE"), "string")
    Do ..AssertRefused("a data source whose statement changes rows", tChanges, 422, "ANALYTICS.PMML.QUERYONLY")
    Set tUpdate = ..ExportValues("Update", "custom")
    Do tUpdate.%Set("SQL", "UPDATE ProbePmml.Source SET X = X", "string")
    Do ..AssertRefused("a custom statement that updates rows", tUpdate, 422, "ANALYTICS.PMML.QUERYONLY")
    Do $$$AssertEquals(..ExportLeft("Changes") _ ..ExportLeft("Update"), "", "and nothing was made")
}

/// <p>AC2, AD-22: with its governance key off, the agent's confirmed export is refused 403 <code>GOVERNANCE.DISABLED</code> and nothing is made, no audit row is written; the person's Export to cube, which the key does not ask, runs.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Governance.Gate.Decide</method> allow every tool -- the refusal leg goes red.</p>
Method TestTheAgentsExportIsRefusedWithItsKeyOffAndThePersonsIsNot()
{
    Do ..Mint(..#EXPORTTOOL, ..ExportArgs("KeyOffAgent"), .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do ..SetKey("analytics.pmmlmodel.export", "disabled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Snapshot()
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's export is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..ExportLeft("KeyOffAgent"), "", "nothing was made")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and no class was saved, changed or deleted")
    Do $$$AssertEquals(..Rows(tSince, "pmml-model", ..ModelId(), "analytics.pmmlmodel.export"), 0, "and no audit row names the export")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tStatus = ..ExportAct(..ExportValues("KeyOffPerson"), .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's export is not asked for the key: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..ClassHeld(..ExportClass("KeyOffPerson")) _ "|" _ ..CubeHeld(..ExportCube("KeyOffPerson")), "1|1", "and makes the classes and the cube")
    Do $$$AssertEquals(..Rows(tSince, "pmml-model", ..ModelId(), "analytics.pmmlmodel.export"), 1, "with one audit row")
}

/// <p>Leave a row in the data global of the class <var>pClass</var>, which is not defined: what a class of that name deleted earlier leaves behind. The class's name is short enough that its default data global is the name and <code>D</code>.</p>
ClassMethod LeaveData(pClass As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGlobal = "^" _ pClass _ "D"
        Set @tGlobal = 3
        Set @tGlobal@(3) = $ListBuild("", "stale", "stale", 0, "stale", 0)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AD-59: the export's script form is one step for each source that, rendered, runs no write and names no class of OcuPilot's but in its one comment, and, run, makes the classes, rows and cube class the write makes; run again, or after
/// another writer took a class or a cube, it changes nothing; over a data global an earlier class of the name left, the result class holds only the run's rows; and a cube class the compiler refuses, or a test that does not finish, leaves no class, cube, row or data.
/// The refusals the write makes are one step that only sets the published sentence, which fails the script and makes nothing.</p>
/// <p>Mutation (Rule 19): make the free-name condition of <method>OcuPilot.Port.AnalyticsPort.PmmlExportSnippet</method> always true -- the run-again and class-taken legs go red; skip the delete of the result class in its failure lines -- the refused-compile leg goes red;
/// drop the script's kill of the result class's extent before the test -- the stale-data leg goes red; skip the script's failure for a test that does not finish -- the unfinished-test leg goes red.</p>
Method TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails()
{
    Set tSentence = ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLTAKEN
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#EXPORTENDPOINT, "TOCUBE"), "objectscript", "the export has a script form")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#EXPORTENDPOINT, "PMMLEXPORT"), "", "and its read has none")
    For tSource = "dataset", "verification", "custom" {
        Set tMarker = "Script" _ $ZConvert($Extract(tSource, 1), "U") _ $Extract(tSource, 2, *)
        Set tOracle = ..OracleAnswer(tSource)
        Do $$$AssertEquals(tOracle.outcome, "ran", tSource _ ": the oracle's own test ran")
        Set tSteps = ..ExportScript(..ExportValues(tMarker, tSource))
        Do $$$AssertEquals(tSteps.%Size(), 1, tSource _ ": the export is one script step")
        If tSteps.%Size() '= 1 Continue
        Set tText = tSteps.%Get(0).text
        Do $$$AssertEquals(..ExportLeft(tMarker), "", tSource _ ": rendering it made nothing")
        Do $$$AssertTrue((tText [ " ; OcuPilot cannot undo an export.") && ($Length($Replace(tText, $Parameter(..#PMML, "DEFINITIONCLASS"), ""), "OcuPilot") = 2), tSource _ ": it states its one-way step in one comment and, but for the probe's own model class, names none of OcuPilot's")
        Do $$$AssertTrue(tText [ (" ; The test runs here without the " _ ##class(OcuPilot.Port.AnalyticsPort).#MDXSECONDS _ " second limit the export has."), tSource _ ": and says in one comment that the test has no limit here")
        Do $$$AssertTrue((tText [ "SetTextFromString") && (tText [ "%KillExtent") && (tText [ "%DeepSee.PMML.Utils") && (tText [ "FROM %DeepSee_PMML_Utils.TempResult"), tSource _ ": it saves, tests, copies and drops through the vendor's classes")
        Do $$$AssertEquals(..RunScript(tSteps), 1, tSource _ ": the script runs to a success")
        Do ..AssertExported(tMarker, ..AnswerValues(tOracle), tOracle.records, tSource _ " by script")
        If tSource = "dataset" Set tFirst = tSteps
    }
    If '$IsObject($Get(tFirst)) Quit
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tFirst), 0, "run again, the script reports the names taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and every class is as it was")
    Do $$$AssertEquals(..ResultRows(..ExportClass("ScriptDataset")), 12, "with the earlier export's twelve rows")
    Do $$$AssertTrue(tFirst.%Get(0).text [ tSentence, "the step names the published sentence for a held class")

    Set tRace = ..ExportScript(..ExportValues("ScriptRace"))
    Do $$$AssertStatusOK(..Hold(..ExportClass("ScriptRace")), "another writer takes the result class after the step is rendered")
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tRace), 0, "the script reports it taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and saves, changes and deletes nothing, the other writer's class as it was")
    Do $$$AssertEquals(..ExportLeft("ScriptRace"), "result class", "and only the other writer's class is there")
    Set tCubeRace = ..ExportScript(..ExportValues("ScriptCubeRace"))
    Set tTaker = ..ExportValues("ScriptCubeTaker")
    Do tTaker.%Set("Cube", ..ExportCube("ScriptCubeRace"), "string")
    Do $$$AssertEquals(..Export(tTaker, .tRes), "200 ", "another writer takes the cube's name after the step is rendered")
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tCubeRace), 0, "the script reports the cube taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and saves nothing")
    Do $$$AssertTrue(tCubeRace.%Get(0).text [ ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLCUBETAKEN, "the step names the published sentence for a held cube")

    Set tValues = ..ExportValues("ScriptLong")
    Do tValues.%Set("Cube", $Translate($Justify("", 250), " ", "x"), "string")
    Set tLong = ..ExportScript(tValues)
    Do $$$AssertEquals(tLong.%Size(), 1, "an export whose cube class the compiler refuses is one script step")
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tLong), 0, "its script runs to a failure")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and no class is saved: neither the result class, nor the cube class, nor one its compile generated")
    Do $$$AssertEquals(..ExportLeft("ScriptLong"), "", "and no row, vendor result row or data is left")

    Set tStaleOracle = ..OracleAnswer("dataset")
    Set tStaleSteps = ..ExportScript(..ExportValues("Stale"))
    Do ..LeaveData(..ExportClass("Stale"))
    Do $$$AssertEquals(..RunScript(tStaleSteps), 1, "over a data global an earlier class of the name left, the script runs to a success")
    Do ..AssertExported("Stale",..AnswerValues(tStaleOracle), tStaleOracle.records, "stale data by script")

    Set tFailSteps = ..ExportScript(..ExportValues("ScriptRunFail", "custom"))
    Do $$$AssertEquals(tFailSteps.%Size(), 1, "a custom export is one script step")
    Set tFailText = $Replace(tFailSteps.%Get(0).text, "ProbePmml.Source", "ProbePmml.NoSuchTable")
    Do $$$AssertTrue(tFailText '= tFailSteps.%Get(0).text, "its statement is swapped for one the instance cannot prepare")
    Set tFailStep = {}
    Do tFailStep.%Set("kind", "objectscript", "string")
    Do tFailStep.%Set("text", tFailText, "string")
    Set tFailSteps = []
    Do tFailSteps.%Push(tFailStep)
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..RunScript(tFailSteps), 0, "a script whose test does not finish runs to a failure")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and no class is saved")
    Do $$$AssertEquals(..ExportLeft("ScriptRunFail"), "", "and no row, vendor result row or data is left")

    Set tHeld = ..ExportValues("ScriptHeld")
    Do $$$AssertStatusOK(..Hold(..ExportClass("ScriptHeld")), "a class is saved")
    Set tOwn = ..ExportValues("ScriptOwn")
    Do tOwn.%Set("CubeClass", "OcuPilot.ProbePmmlExport", "string")
    Set tNone = ..ExportValues("ScriptNone")
    Do tNone.%Set("SourceClass", "ProbePmml.NoSuchSourceClass", "string")
    ; The values are objects, which a list would not keep.
    Set tValuesOf(1) = tHeld
    Set tValuesOf(2) = tOwn
    Set tValuesOf(3) = tNone
    Set tCases = $ListBuild($ListBuild("a held result class", tSentence), $ListBuild("a class of OcuPilot's own", ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE)), $ListBuild("a class to link to that is absent", ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLSOURCECLASS))
    Set tBefore = ..Snapshot()
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tSteps = ..ExportScript(tValuesOf(tAt))
        Do $$$AssertEquals(tSteps.%Size(), 1, $List(tCase, 1) _ ": the refusal is one script step")
        If tSteps.%Size() '= 1 Continue
        Set tText = tSteps.%Get(0).text
        Do $$$AssertTrue((tText [ $List(tCase, 2)) && (tText '[ "SetTextFromString") && (tText '[ "RunModel"), $List(tCase, 1) _ ": the step only sets the published sentence")
        Do $$$AssertEquals(..RunScript(tSteps), 0, $List(tCase, 1) _ ": and runs to a failure")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no refusal saved, changed or deleted a class")
}

/// <p>AD-59: a name or source the write's own shape checks refuse is never spelled in a script: a result class, cube class or class to link to holding a quote, a line feed, an underscore and <code>$$$</code>, a cube name holding a line
/// feed, a brace and <code>$$$</code>, a source that is none of the three, a model id that is not a class and a model, and a namespace that is not one each answer no step, so a script never holds the raw value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlExportDraftShaped</method> answer 1 -- the five field legs go red, each rendering the port's refusal sentence; make <method>OcuPilot.Port.AnalyticsPort.PmmlDraftClassShaped</method> accept every name in OcuPilot's own package --
/// the three own-package legs go red.</p>
Method TestAHostileNameOrSourceRendersNoScript()
{
    Set tHostile = "ProbePmml.Ex""port" _ $Char(10) _ "_$$$Evil"
    For tField = "ResultClass", "CubeClass", "SourceClass", "Cube", "Source" {
        Set tValues = ..ExportValues("Hostile")
        Do tValues.%Set(tField, $Select(tField = "Cube": "Bad" _ $Char(10) _ "}$$$Evil", tField = "Source": "banana", 1: tHostile), "string")
        Do $$$AssertEquals(..ExportScript(tValues).%Size(), 0, tField _ ": the hostile value renders no script")
    }
    For tField = "ResultClass", "CubeClass", "SourceClass" {
        Set tValues = ..ExportValues("Hostile")
        Do tValues.%Set(tField, "OcuPilot.Ex""port" _ $Char(10) _ "_$$$Evil", "string")
        Do $$$AssertEquals(..ExportScript(tValues).%Size(), 0, tField _ ": a malformed name in OcuPilot's own package renders no script")
    }
    Do $$$AssertEquals(..ExportScript(..ExportValues("Hostile"), "Bad""Class" _ $Char(10) _ "||Model").%Size(), 0, "a model id that is not a class and a model renders no script")
    Kill tQuery
    Set tQuery("namespace") = "US""ER" _ $Char(10) _ "$$$Evil"
    Set tQuery("id") = ..ModelId()
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", ..#EXPORTENDPOINT, "TOCUBE", .tQuery, ..ExportValues("Hostile")).%Size(), 0, "a namespace that is not one renders no script")
    Do $$$AssertEquals(..ExportLeft("Hostile"), "", "and nothing was made")
}

}
