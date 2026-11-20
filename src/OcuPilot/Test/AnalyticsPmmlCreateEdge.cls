/// <p>Pins the refusals of Story 24.14 Batch 3's PMML definition create (AD-8, AD-10, AD-11, AD-54, AD-60, AD-61, AD-65) against <code>USER</code>, with the real compiler: a class of OcuPilot's own, a
/// <code>%</code> name or one with no package, a held class, a held package and a case variant are each refused with their own code and nothing is saved or deleted; a name taken between the mint and
/// the confirm closes the proposal as target-changed; an empty, oversized or document-type text and each shape of a <code>}</code> character is refused <code>ANALYTICS.PMML.TEXT</code> before
/// anything is saved or compiled, and a lone <code>{</code> is refused by the compile; a document the compile refuses leaves no class and records its restored outcome; and the gate refuses a caller without
/// its pairs, without WRITE on the routines database and in a namespace without analytics before any lookup, and a read-only or unmounted routines database refuses it. The helpers are <class>OcuPilot.Test.AnalyticsPmmlCreateBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes classes under <code>ProbePmml.</code> in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsPmmlCreateEdge Extends OcuPilot.Test.AnalyticsPmmlCreateBase
{

Parameter SEAM = "OcuPilot.Test.AnalyticsListingGroupDatabaseSeam";

/// <p>AC2: a class of OcuPilot's own is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> by the port, the person's route and the agent's mint; a name with a <code>%</code>, with no package or with a character a
/// class cannot hold is refused 422 <code>ANALYTICS.PMML.CLASS</code> by the port and the person's route and by the agent's mint; nothing is saved.</p>
/// <p>Mutation (Rule 19): drop the own-code test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlDefinition</method> -- the first leg goes red; make <method>OcuPilot.Port.AnalyticsPort.ListingClassShaped</method> accept a
/// <code>%</code> name -- the shape leg goes red.</p>
Method TestAnOwnClassAndAMalformedNameAreRefused()
{
    Set tText = ..Text()
    Do ..AssertOwnCodeRefused("an OcuPilot class", ..#WRITEENDPOINT, "ADD", "OcuPilot.ProbePmmlNew", {"Class": "OcuPilot.ProbePmmlNew", "PMML": (tText)}, "", ..#SCREENROUTE, "", {"Class": "OcuPilot.ProbePmmlNew", "PMML": (tText)}, ..#ADDTOOL, {"Class": "OcuPilot.ProbePmmlNew", "PMML": (tText)})
    Set tBefore = ..Snapshot()
    For tName = "%ProbePmmlNew.Shape", "NoPackage", "ProbePmml.New Space", "ProbePmml..NewDots", "9ProbePmml.NewDigit" {
        Do $$$AssertEquals(..Add(tName, tText, .tRes), "422 ANALYTICS.PMML.CLASS", tName _ ": the port refuses the name")
        Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tName), "PMML": (tText)}, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.CLASS", tName _ ": the person's route refuses it")
        Do ..MintRefused(..#ADDTOOL, {"Class": (tName), "PMML": (tText)}, "TOOL.ARGUMENTS")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was saved")
}

/// <p>AC2: a held class, a class whose package is held and a case variant of either are each refused 409 <code>ANALYTICS.PMML.TAKEN</code> by the port, the person's route and the agent's mint, and the held
/// class, its generated classes and the held package are as they were; the definition's read answers a held class's row, 409 for a held package alone and 404 for a free name.</p>
/// <p>Mutation (Rule 19): drop the package test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlDefinition</method> -- the held-package legs go red; compare the class name case-sensitively in
/// <method>OcuPilot.Port.AnalyticsPort.ReadPmmlDefinitionData</method> -- the case-variant legs go red.</p>
Method TestAHeldClassOrPackageIsRefusedAndNothingIsTouched()
{
    Set tText = ..Text()
    Set tHeld = ..Name("Held")
    Do $$$AssertEquals(..Add(tHeld, tText, .tRes), "200 ", "a definition is created")
    Set tPackage = ..Name("Package")
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tPackage _ ".Inside", "Class " _ tPackage _ ".Inside Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "}" _ $Char(13, 10)), "a class is saved in a package whose own name no class holds")
    Set tBefore = ..Snapshot()
    Do $$$AssertTrue(tBefore [ (tHeld _ ".Data="), "the held definition's compile generated classes in its package: " _ tBefore)
    Do $$$AssertEquals(..ClassHeld(tHeld) _ "|" _ ..PackageHeld(tHeld) _ "|" _ ..Free(tHeld), "1|1|0", "the lookups read a held class and its generated package")
    Do $$$AssertEquals(..ClassHeld(tPackage) _ "|" _ ..PackageHeld(tPackage) _ "|" _ ..Free(tPackage), "0|1|0", "and a package held alone")
    Do $$$AssertEquals(..Free(..Name("Free")), 1, "and a free name")
    For tName = tHeld, $ZConvert(tHeld, "L"), $ZConvert(tHeld, "U"), tPackage, $ZConvert(tPackage, "L") {
        Do $$$AssertEquals(..Add(tName, tText, .tRes), "409 ANALYTICS.PMML.TAKEN", tName _ ": the port refuses it as taken")
        Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tName), "PMML": (tText)}, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), "409 ANALYTICS.PMML.TAKEN|" _ ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLTAKEN, tName _ ": the person's route refuses it, with the published sentence")
        Do ..MintRefused(..#ADDTOOL, {"Class": (tName), "PMML": (tText)}, "ANALYTICS.PMML.TAKEN")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was saved, changed or deleted")
    Do $$$AssertEquals(..Port(..#WRITEENDPOINT, "PMMLDEFINITION", tHeld, "", "", .tRow), "200 ", "the read of the held class answers its row")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.%Get("Class") _ "|" _ tRow.%Get("Models") _ "|" _ (tRow.%Get("PMML") = tText), tHeld _ "|2|1", "with its class, its two models and its text")
    Do $$$AssertEquals(..Port(..#WRITEENDPOINT, "PMMLDEFINITION", tPackage, "", "", .tRow), "409 ANALYTICS.PMML.TAKEN", "the read of a name whose package alone is held is refused as taken")
    Do $$$AssertEquals(..Port(..#WRITEENDPOINT, "PMMLDEFINITION", ..Name("Free"), "", "", .tRow), "404 PORT.NOTFOUND", "the read of a free name is 404")
}

/// <p>AC2: a name taken between the mint and the confirm closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, and the class the other caller made is as it was.</p>
/// <p>Mutation (Rule 19): make the read of <method>OcuPilot.Port.AnalyticsPort.InvokePmmlDefinition</method> answer 404 for a held class -- the confirm writes over it and the leg goes red.</p>
Method TestANameTakenAfterTheMintClosesTheProposal()
{
    Set tText = ..Text()
    Set tClass = ..Name("Race")
    Do ..Mint(..#ADDTOOL, {"Class": (tClass), "PMML": (tText)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Add(tClass, tText, .tRes), "200 ", "the person makes the class after the mint")
    Set tBefore = ..Snapshot()
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is refused as moved: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC3: an empty text, one longer than the import bound, a document type declaration and an entity declaration (in any case) are each refused 422 <code>ANALYTICS.PMML.TEXT</code> by the port, the person's
/// route (but the oversized text) and the agent's mint, and neither the class nor its package exists afterwards.</p>
/// <p>Mutation (Rule 19): drop the document type test from <method>OcuPilot.Port.AnalyticsPort.PmmlTextRefused</method> -- the declaration legs go red; compare the length with the bound plus one -- the oversized leg goes red.</p>
Method TestAnUntrustedTextIsRefusedBeforeAnythingIsSaved()
{
    Set tHead = "<PMML version='4.1' xmlns='http://www.intersystems.com/deepsee/pmml'>"
    Set tCases = $ListBuild($ListBuild("empty", ""), $ListBuild("oversized", $Justify("", $Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS") + 1)), $ListBuild("document type", "<!DOCTYPE PMML [ <!ENTITY x SYSTEM 'file:///etc/hosts'> ]>" _ tHead _ "</PMML>"), $ListBuild("lower-case document type", "<!doctype pmml>" _ tHead _ "</PMML>"), $ListBuild("entity", tHead _ "<!ENTITY y 'z'></PMML>"), $ListBuild("lower-case entity", tHead _ "<!entity y 'z'></PMML>"))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tClass = ..Name("Text" _ tAt)
        Do $$$AssertEquals(..Add(tClass, $List(tCase, 2), .tRes), "422 ANALYTICS.PMML.TEXT", $List(tCase, 1) _ ": the port refuses the text")
        Do $$$AssertEquals(..Free(tClass), 1, $List(tCase, 1) _ ": neither the class nor its package exists")
        If $List(tCase, 1) = "oversized" Continue
        Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tClass), "PMML": ($List(tCase, 2))}, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.TEXT", $List(tCase, 1) _ ": the person's route refuses it")
        If $List(tCase, 2) '= "" Do ..MintRefused(..#ADDTOOL, {"Class": (tClass), "PMML": ($List(tCase, 2))}, "TOOL.ARGUMENTS")
        Do $$$AssertEquals(..Free(tClass), 1, $List(tCase, 1) _ ": still nothing saved")
    }
}

/// <p>AC3, the text-guard pins: a <code>}</code> where the vendor's parse would end the XData block and read what follows as class members is refused 422 <code>ANALYTICS.PMML.TEXT</code> before anything is
/// written or compiled, and neither the class nor its package exists afterwards: a plain line-start <code>}</code>, one at a line's end after text, one before a member keyword on the same line, and, for each of
/// no-break space, vertical tab, form feed, zero-width space, byte-order mark, carriage return, next line and line separator, that character before a line-start <code>}</code>; and one the guard does not
/// need to name, a <code>}</code> inside a quoted attribute.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlTextRefused</method> refuse a <code>}</code> only at a line's start -- the line-end, keyword and character legs go red.</p>
Method TestEachShapeOfABraceIsRefusedBeforeAnythingIsSaved()
{
    Set tNL = $Char(10)
    Set tHead = "<PMML version='4.1' xmlns='http://www.intersystems.com/deepsee/pmml'>"
    Set tMember = "ClassMethod Evil() As %String { Quit ""x"" }"
    Set tCases = $ListBuild($ListBuild("line start", tHead _ tNL _ "}" _ tNL _ tMember), $ListBuild("line end", tHead _ "x}" _ tNL _ tMember), $ListBuild("line end after a space", tHead _ "x }" _ tNL _ tMember), $ListBuild("before a member keyword", tHead _ "a} " _ tMember), $ListBuild("inside an attribute", tHead _ "<Header description='a}b'/></PMML>"))
    For tChar = 160, 11, 12, 8203, 65279, 13, 133, 8232 {
        Set tCases = tCases _ $ListBuild($ListBuild("character " _ tChar _ " before a line-start brace", tHead _ tNL _ $Char(tChar) _ "}" _ tNL _ tMember))
    }
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tClass = ..Name("Brace" _ tAt)
        Set tBefore = ..Snapshot()
        Do $$$AssertEquals(..Add(tClass, $List(tCase, 2), .tRes), "422 ANALYTICS.PMML.TEXT", $List(tCase, 1) _ ": refused as text")
        Do $$$AssertEquals(..Free(tClass), 1, $List(tCase, 1) _ ": neither the class nor its package exists")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 1) _ ": nothing was saved, compiled or deleted")
    }
    Set tClass = ..Name("BraceRoute")
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tClass), "PMML": (tHead _ tNL _ "}" _ tNL _ tMember)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.TEXT", "the person's route refuses a line-start brace")
    Do ..MintRefused(..#ADDTOOL, {"Class": (tClass), "PMML": (tHead _ tNL _ "}" _ tNL _ tMember)}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Free(tClass), 1, "and the agent's mint saved nothing either")
}

/// <p>AC4: well-formed XML that is not valid PMML, and a lone <code>{</code>, reach the compile, which refuses them: the answer is 422 <code>ANALYTICS.PMML.COMPILE</code> with the published sentence, never the
/// compiler's own text; no class named for the definition and no class of its package remains; the audit row records the outcome <code>restored</code>; and the same holds for the person's route and the agent's confirm.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> do nothing -- the no-class legs go red.</p>
Method TestARefusedCompileLeavesNothingAndRecordsItsOutcome()
{
    Set tHead = "<PMML version='4.1' xmlns='http://www.intersystems.com/deepsee/pmml'>"
    Set tBad = tHead _ "<Bogus/></PMML>"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Snapshot()
    Set tClass = ..Name("Refused")
    Do $$$AssertEquals(..Add(tClass, tBad, .tRes), "422 ANALYTICS.PMML.COMPILE", "the port answers the compile's code")
    Do $$$AssertEquals(..Free(tClass), 1, "neither the class nor its package remains")
    Do $$$AssertEquals(..Recorded(tSince, tClass, "analytics.pmmlmodels.add", "restored"), 1, "the audit row records the outcome restored")
    Set tPerson = ..Name("RefusedPerson")
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tPerson), "PMML": (tBad)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), "422 ANALYTICS.PMML.COMPILE|" _ ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLCOMPILE, "the person's route answers the same, with the published sentence")
    Do $$$AssertEquals(..Free(tPerson), 1, "and leaves nothing")
    Set tAgent = ..Name("RefusedAgent")
    Do ..Mint(..#ADDTOOL, {"Class": (tAgent), "PMML": (tBad)}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.COMPILE", "the agent's confirm answers the same: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals(..Free(tAgent), 1, "and leaves nothing")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Set tValid = ..Text()
    Set tBrace = ..Name("Lone")
    Set tLone = $Piece(tValid, $Char(10), 1) _ $Char(10) _ $Piece(tValid, $Char(10), 2) _ "{" _ $Char(10) _ $Piece(tValid, $Char(10), 3, *)
    Do $$$AssertEquals(..Add(tBrace, tLone, .tRes), "422 ANALYTICS.PMML.COMPILE", "a { at a line's end is not refused as text: the compile refuses it")
    Do $$$AssertEquals(..Free(tBrace), 1, "and neither the class nor its package remains")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class of any of the writes is left")
    Do $$$AssertEquals(..Add(..Name("LoneControl"), tValid, .tRes), "200 ", "the same text without the { compiles, so the { is what the compile refused")
}

/// <p>AC5: with the database that holds class definitions read-only or not mounted, through the seam, the create is refused 409 <code>ANALYTICS.PMML.READONLY</code> with every pair held and
/// nothing written; unarmed, the same create is made.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.AdmitPmmlDefinition</method> pass another family's read-only code -- both modes' legs go red.</p>
Method TestADatabaseThatIsReadOnlyOrNotMountedRefusesTheCreate()
{
    Set tText = ..Text()
    Set tClass = ..Name("ReadOnly")
    Set tBefore = ..Snapshot()
    Do ..HoldEverythingBut("")
    For tMode = "readonly", "unmounted" {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", "pmmldatabase", tMode)
        Set tResult = ..Seamed(..#WRITEENDPOINT, "ADD", tClass, {"Class": (tClass), "PMML": (tText)}, .tRes)
        Do $$$AssertEquals(tResult, "409 ANALYTICS.PMML.READONLY", "with the database " _ tMode _ " the create is refused: " _ tResult)
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Seamed(..#WRITEENDPOINT, "ADD", tClass, {"Class": (tClass), "PMML": (tText)}, .tRes), "200 ", "unarmed, the same create is made")
}

/// <p>AC5: in process, through the gate seam, the create is refused before any lookup for a caller without <code>%Development:USE</code> (403 naming it), without the portal pair, and without WRITE on
/// the routines database that holds class definitions; the definition's read needs the pairs of the screen and not the write database; a namespace without analytics is refused 409 <code>ANALYTICS.NAMESPACE</code>.</p>
/// <p>Mutation (Rule 19): drop <code>%Development:USE</code> from <parameter>OcuPilot.Port.AnalyticsPort.PMMLPAIRS</parameter> -- the <code>%Development:USE</code> leg goes red; make
/// <method>OcuPilot.Port.AnalyticsPort.AdmitPmmlDefinition</method> admit every caller -- the routines database leg goes red.</p>
Method TestTheCreateIsRefusedWithoutItsPairsOrItsDatabase()
{
    Set tText = ..Text()
    Set tClass = ..Name("Gate")
    Set tBefore = ..Snapshot()
    For tExcept = "%DeepSee_Portal:USE", "%Development:USE" {
        Do ..HoldEverythingBut(tExcept)
        Set tResult = ..Seamed(..#WRITEENDPOINT, "ADD", tClass, {"Class": (tClass), "PMML": (tText)}, .tRes)
        Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|" _ tExcept, "the create without " _ tExcept _ " is refused naming it: " _ tResult)
    }
    Do ..HoldEverythingBut("%DB_USER:WRITE")
    Set tResult = ..Seamed(..#WRITEENDPOINT, "ADD", tClass, {"Class": (tClass), "PMML": (tText)}, .tRes)
    Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|%DB_USER:WRITE", "the create without WRITE on the routines database is refused naming it: " _ tResult)
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tClass
    Do ..HoldEverythingBut("%DB_USER:WRITE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#WRITEENDPOINT, "PMMLDEFINITION", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "the plain read of a free name needs no WRITE on the routines database")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove"), "analytics is turned off in USER")
    Set tResult = ..Port(..#WRITEENDPOINT, "ADD", tClass, {"Class": (tClass), "PMML": (tText)}, "", .tRes)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Enable"), "and on again")
    Do $$$AssertEquals(tResult, "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused: " _ tResult)
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
}

}
