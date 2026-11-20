/// <p>Pins what <class>OcuPilot.Test.AnalyticsPmmlCreate</class> and <class>OcuPilot.Test.AnalyticsPmmlCreateEdge</class> leave open in Story 24.14 Batch 3's PMML definition create (AD-10, AD-22, AD-58,
/// AD-59, AD-60, AD-61), against <code>USER</code> with the real compiler: the agent's confirm refused once its governance key is off while the person's New is not; the script form refusing
/// the texts and names the write refuses and running no other path, failing closed when its lookup fails and answering no step for a text too long for one; a text with carriage returns, entities, double quotes and shell-like characters stored and read back as sent by every
/// caller; a legal text near the bound stored whole; the bound applied to the class text and refused as text; a compile the vendor refuses after it generated classes leaving none; and OcuPilot's own names in other cases and with a prefix refused.
/// The helpers are <class>OcuPilot.Test.AnalyticsPmmlCreateBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes classes under <code>ProbePmml.</code> in <code>USER</code> and rewrites the stored governance policy,
/// which it restores after each test.</p>
Class OcuPilot.Test.AnalyticsPmmlCreateGap Extends OcuPilot.Test.AnalyticsPmmlCreateBase
{

/// <p>The longest PMML text these tests store: below the bound by what the class text adds, because the source code API refuses a class text longer than the bound.</p>
Parameter LARGELENGTH = 2999000;

/// <p>Remove what the base removes and the classes the own-name legs would make were the refusal missing.</p>
Method RemoveFixtures() As %Status
{
    Set tSC = ##super()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tPackage = "OcuPilot.ProbePmml", "OcuPilotProbePmml" {
            Set tSC = $$$ADDSC(tSC, $System.OBJ.DeletePackage(tPackage, "-d"))
        }
    } Catch ex {
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the governance key <var>pKey</var> to <var>pValue</var> (<code>enabled</code> or <code>disabled</code>) for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method SetKey(pKey As %String, pValue As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = pValue
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is set " _ pValue)
}

/// <p>The text <var>pText</var> saved as the class <var>pClass</var> and compiled by the vendor directly, with nothing of OcuPilot's in between: the compile's status. A class the compile
/// refused is left as it is for the caller to look at, and <method>RemoveFixtures</method> removes it.</p>
ClassMethod CompileDirect(pClass As %String, pText As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tClassText = ##class(OcuPilot.Port.AnalyticsPort).PmmlClassText(pClass, pText)
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pClass, $Replace(tClassText, $Char(10), $Char(13, 10)))
        If $$$ISOK(tSC) Set tSC = $System.OBJ.Compile(pClass, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The text <var>pText</var> as the class stores it: line feeds for each carriage return and line feed pair and for each lone carriage return.</p>
ClassMethod Stored(pText As %String) As %String
{
    Quit $Replace($Replace(pText, $Char(13, 10), $Char(10)), $Char(13), $Char(10))
}

/// <p>The probe's text with carriage-return line breaks and what a pasted document can hold: double-quoted attributes, the five predefined entities and a numeric one, a dollar sign, a caret, a
/// tilde, a backslash, a percent sign, a semicolon, <code>//</code>, a block-comment opener and closer, an ObjectScript call, and a comment with a lone carriage return and a blank line.</p>
ClassMethod PastedText() As %String
{
    Set tCRLF = $Char(13, 10)
    Set tRest = $Piece(..Text(), $Char(10), 3, *)
    Quit "<PMML version=""4.1"" xmlns=""http://www.intersystems.com/deepsee/pmml"">" _ tCRLF _
        $Char(9) _ "<Header description=""a &amp; b &lt; c &gt; d &quot;q&quot; &apos;s&apos; &#233; $x ^y ~z \ 100% ; // /* */ ##class(a).b()""/>" _ tCRLF _
        "<!-- a lone carriage return follows" _ $Char(13) _ "and a blank line" _ tCRLF _ tCRLF _ "-->" _ tCRLF _
        $Replace(tRest, $Char(10), tCRLF)
}

/// <p>The probe's text with an XML comment of <var>pLength</var> less than the rest of it padded in after the first line, so the whole is exactly <var>pLength</var> characters, in lines of 1,000.</p>
ClassMethod PaddedText(pLength As %Integer) As %String
{
    Set tNL = $Char(10)
    Set tBase = ..Text()
    Set tFirst = $Piece(tBase, tNL, 1) _ tNL _ "<!--" _ tNL
    Set tLast = "-->" _ tNL _ $Piece(tBase, tNL, 2, *)
    Set tNeed = pLength - $Length(tFirst) - $Length(tLast)
    Set tLine = $Translate($Justify("", 999), " ", "x") _ tNL
    Set tFill = ""
    For tAt = 1:1:tNeed \ 1000 {
        Set tFill = tFill _ tLine
    }
    Set tRemainder = tNeed # 1000
    If tRemainder > 0 Set tFill = tFill _ $Translate($Justify("", tRemainder - 1), " ", "x") _ tNL
    Quit tFirst _ tFill _ tLast
}

/// <p>AC5, AD-22: with its governance key off, the agent's add is refused 403 <code>GOVERNANCE.DISABLED</code> at the confirm and nothing is made, no audit row is written and the proposal makes no
/// class; the person's New, which the key does not ask, still makes the class.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Governance.Gate.Decide</method> allow every tool -- the refusal leg goes red.</p>
Method TestTheAgentsAddIsRefusedWithItsKeyOffAndThePersonsIsNot()
{
    Set tText = ..Text()
    Set tAgent = ..Name("KeyOffAgent")
    Do ..Mint(..#ADDTOOL, {"Class": (tAgent), "PMML": (tText)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do ..SetKey("analytics.pmmlmodels.add", "disabled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Snapshot()
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's add is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..Free(tAgent), 1, "neither the class nor its package was made")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and no class was saved, changed or deleted")
    Do $$$AssertEquals(..Rows(tSince, "pmml-definition", tAgent, "analytics.pmmlmodels.add"), 0, "and no audit row names the add")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tPerson = ..Name("KeyOffPerson")
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tPerson), "PMML": (tText)}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's New is not asked for the key: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..StoredText(tPerson), tText, "and makes the class")
    Do $$$AssertEquals(..Rows(tSince, "pmml-definition", tPerson, "analytics.pmmlmodels.add"), 1, "with one audit row")
}

/// <p>AC3, AC5, AD-59: the script form of the create refuses the names and texts the write refuses, each as one step that only sets the refusal's published sentence, runs to a failure and
/// makes nothing; the script of a valid create saves and compiles through the vendor's own classes and names no class of OcuPilot's, so it runs on an instance that has none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlDefinitionSnippet</method> ignore the plan's refusal -- the first refusal leg raises.</p>
Method TestTheScriptFormRefusesWhatTheWriteRefusesAndRunsNoOtherPath()
{
    Set tNL = $Char(10)
    Set tHead = "<PMML version='4.1' xmlns='http://www.intersystems.com/deepsee/pmml'>"
    Set tOwn = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE)
    Set tClassReason = ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLCLASS
    Set tTextReason = ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLTEXT
    Set tCases = $ListBuild($ListBuild("an OcuPilot class", "OcuPilot.ProbePmmlNew", ..Text(), tOwn), $ListBuild("a % class", "%ProbePmmlNew.Script", ..Text(), tClassReason), $ListBuild("a class with no package", "NoPackage", ..Text(), tClassReason), $ListBuild("a brace", ..Name("ScriptBrace"), tHead _ tNL _ "}" _ tNL _ "ClassMethod Evil() As %String { Quit ""x"" }", tTextReason), $ListBuild("a document type", ..Name("ScriptType"), "<!DOCTYPE PMML [ <!ENTITY x SYSTEM 'file:///etc/hosts'> ]>" _ tHead _ "</PMML>", tTextReason), $ListBuild("an empty text", ..Name("ScriptEmpty"), "", tTextReason))
    Set tBefore = ..Snapshot()
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tSteps = ..Script("ADD", $List(tCase, 2), {"Class": ($List(tCase, 2)), "PMML": ($List(tCase, 3))})
        Do $$$AssertEquals(tSteps.%Size(), 1, $List(tCase, 1) _ ": the refusal is one script step")
        If tSteps.%Size() '= 1 Continue
        Set tStep = tSteps.%Get(0).text
        Do $$$AssertTrue(tStep [ $List(tCase, 4), $List(tCase, 1) _ ": the step sets the published sentence")
        Do $$$AssertTrue(tStep '[ "SetTextFromString", $List(tCase, 1) _ ": and saves nothing")
        Do $$$AssertEquals(..RunScript(tSteps), 0, $List(tCase, 1) _ ": the script runs to a failure")
        Do $$$AssertEquals(..Free($List(tCase, 2)), 1, $List(tCase, 1) _ ": and neither the class nor its package exists")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was saved, changed or deleted")
    Set tClass = ..Name("ScriptValid")
    Set tSteps = ..Script("ADD", tClass, {"Class": (tClass), "PMML": (..Text())})
    Do $$$AssertEquals(tSteps.%Size(), 1, "the valid create is one script step")
    If tSteps.%Size() '= 1 Quit
    Set tStep = tSteps.%Get(0).text
    Do $$$AssertTrue((tStep [ "SetTextFromString") && (tStep [ "$System.OBJ.Compile") && (tStep '[ "OcuPilot"), "it saves and compiles through the vendor's own classes and names none of OcuPilot's")
}

/// <p>AD-59: the script form's free-name lookup reads as held when it fails, so a script whose lookup cannot run saves nothing; and a text too long for a script step answers no step rather than
/// failing the script's composition, however many characters the step would have to spell out.</p>
/// <p>Mutation (Rule 19): start the lookup's answer at free in <method>OcuPilot.Port.AnalyticsPort.PmmlDefinitionSnippet</method> -- the failed-lookup leg goes red; drop its length test -- the long-text leg
/// goes red.</p>
Method TestTheScriptFormFailsClosedAndAnswersNoStepForALongText()
{
    Set tClass = ..Name("ScriptLookup")
    Set tSteps = ..Script("ADD", tClass, {"Class": (tClass), "PMML": (..Text())})
    Do $$$AssertEquals(tSteps.%Size(), 1, "the create is one script step")
    If tSteps.%Size() '= 1 Quit
    Set tStep = tSteps.%Get(0).text
    Do $$$AssertTrue(tStep [ "FROM %Dictionary.ClassDefinition WHERE", "the step looks the name up in the class catalog")
    Do tSteps.%Get(0).%Set("text", $Replace(tStep, "FROM %Dictionary.ClassDefinition WHERE", "FROM ProbePmmlNo.SuchTable WHERE"), "string")
    Do $$$AssertEquals(..RunScript(tSteps), 0, "a script whose lookup fails runs to a failure")
    Do $$$AssertEquals(..Free(tClass), 1, "and saves nothing")
    Set tLong = ..Name("ScriptLong")
    Set tText = $Piece(..Text(), $Char(10), 1) _ $Char(10) _ "<!--" _ $Translate($Justify("", ##class(OcuPilot.Port.AtelierPort).#SNIPPETMAXCHARACTERS + 1), " ", $Char(9)) _ "-->" _ $Char(10) _ $Piece(..Text(), $Char(10), 2, *)
    Set tSize = -1
    Try {
        Set tSize = ..Script("ADD", tLong, {"Class": (tLong), "PMML": (tText)}).%Size()
    } Catch ex {
        Set tSize = "threw " _ ex.DisplayString()
    }
    Do $$$AssertEquals(tSize, 0, "a text longer than a script step holds answers no step")
    Do $$$AssertEquals(..Free(tLong), 1, "and nothing was made")
}

/// <p>AC1, AD-58, AD-59: a text with carriage-return line breaks, double-quoted attributes, entities, dollar, caret, tilde and backslash characters, an ObjectScript call and a comment holding a lone
/// carriage return is stored with line feeds and nothing else changed, and read back as sent with the verdict <code>matches</code>, by the port, the person's route, the agent's confirm and the script form.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsPmmlModelAdd.TextNormalized</method> answer its arguments unchanged -- the person's and the agent's read-back legs go red.</p>
Method TestAPastedTextIsStoredAsSentByEveryCaller()
{
    Set tText = ..PastedText()
    Set tExpected = ..Stored(tText)
    Do $$$AssertTrue(($Length(tText, $Char(13, 10)) > 1) && ($Length(tText, $Char(13)) > $Length(tText, $Char(13, 10))), "the text holds carriage-return line breaks and a lone carriage return")
    Set tPort = ..Name("PastedPort")
    Do $$$AssertEquals(..Add(tPort, tText, .tRes), "200 ", "the port makes the class")
    Do $$$AssertEquals(..StoredText(tPort), tExpected, "and stores the text with line feeds, character for character")
    Do $$$AssertEquals(..ListedModels(tPort), $Parameter(..#PMML, "CREATEDMODELS"), "its models are the two the text defines")

    Set tPerson = ..Name("PastedPerson")
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tPerson), "PMML": (tText)}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's New answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, "matches", "and reads back what was sent")
    Do $$$AssertEquals(..StoredText(tPerson), tExpected, "the person's class holds the same text")

    Set tAgent = ..Name("PastedAgent")
    Do ..Mint(..#ADDTOOL, {"Class": (tAgent), "PMML": (tText)}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's add confirms: " _ $Extract($Get(tRaw), 1, 300))
        If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "created|matches", "created, the read-back matching what was proposed")
        Do $$$AssertEquals(..StoredText(tAgent), tExpected, "the agent's class holds the same text")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }

    Set tScript = ..Name("PastedScript")
    Set tSteps = ..Script("ADD", tScript, {"Class": (tScript), "PMML": (tText)})
    Do $$$AssertEquals(tSteps.%Size(), 1, "the create has one script step")
    If tSteps.%Size() '= 1 Quit
    Do $$$AssertEquals(..RunScript(tSteps), 1, "the script runs to a success")
    Do $$$AssertEquals(..StoredText(tScript), tExpected, "and its class holds the same text")
}

/// <p>AC1: a legal text of <parameter>LARGELENGTH</parameter> characters, in thousands of lines, is stored whole, character for character, and its two models are listed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PmmlTextRefused</method> refuse a text longer than 2,000,000 characters -- the leg goes red.</p>
Method TestALargeLegalTextIsStoredWhole()
{
    Set tText = ..PaddedText(..#LARGELENGTH)
    Do $$$AssertEquals($Length(tText), ..#LARGELENGTH, "the text is as long as the test says")
    Set tClass = ..Name("Large")
    Do $$$AssertEquals(..Add(tClass, tText, .tRes), "200 ", "the port makes the class")
    Set tStored = ..StoredText(tClass)
    Do $$$AssertEquals($Length(tStored), ..#LARGELENGTH, "its XData is as long")
    Set tSame = (tStored = tText)
    Do $$$AssertEquals(tSame, 1, "and equal to the text sent, character for character")
    Do $$$AssertEquals(..ListedModels(tClass), $Parameter(..#PMML, "CREATEDMODELS"), "its two models are listed")
}

/// <p>AC3: the text bound is the class text's. A text whose class text is exactly <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters is stored whole; a text one
/// character longer, and a text of exactly that many characters, which the text test alone admits, are refused 422 <code>ANALYTICS.PMML.TEXT</code> with the published sentence by the port, the
/// person's route and the agent's mint, before anything is saved, and neither the class nor its package exists afterwards.</p>
/// <p>Mutation (Rule 19): drop the class-text length test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlDefinition</method> -- the refusal legs go red; compare it with <code>&gt;=</code> -- the
/// stored leg goes red.</p>
Method TestATextIsBoundedByItsClassTextAndRefusedAsText()
{
    Set tPort = "OcuPilot.Port.AnalyticsPort"
    Set tMax = $Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS")
    Set tReason = ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLTEXT
    Set tClass = ..Name("Bound")
    Set tFits = tMax - $Length($ClassMethod(tPort, "PmmlClassText", tClass, ""))
    Set tText = ..PaddedText(tFits)
    Do $$$AssertEquals($Length($ClassMethod(tPort, "PmmlClassText", tClass, tText)), tMax, "the class text is exactly the bound")
    Do $$$AssertEquals(..Add(tClass, tText, .tRes), "200 ", "the port makes the class whose class text is exactly the bound")
    Do $$$AssertEquals($Length(..StoredText(tClass)), tFits, "and stores its text whole")
    Set tBefore = ..Snapshot()
    For tCase = "one character over", "the text test's own bound" {
        Set tOver = ..Name($Select(tCase = "one character over": "BoundOver", 1: "BoundText"))
        Set tLength = $Select(tCase = "one character over": tMax - $Length($ClassMethod(tPort, "PmmlClassText", tOver, "")) + 1, 1: tMax)
        Set tLong = ..PaddedText(tLength)
        Do $$$AssertTrue(($Length(tLong) = tLength) && '$ClassMethod(tPort, "PmmlTextRefused", tLong), tCase _ ": the text test alone admits the text")
        Do $$$AssertEquals(..Add(tOver, tLong, .tRes), "422 ANALYTICS.PMML.TEXT", tCase _ ": the port refuses it as text")
        Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tOver), "PMML": (tLong)}, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), "422 ANALYTICS.PMML.TEXT|" _ tReason, tCase _ ": the person's route refuses it with the published sentence")
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#ADDTOOL, {"Class": (tOver), "PMML": (tLong)}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject($Get(tProposal)), tCase _ ": the agent's mint is refused with no proposal")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() [ tReason), tCase _ ": naming the published sentence: " _ $Select($IsObject($Get(tFault)): $Extract(tFault.%ToJSON(), 1, 300), 1: ""))
        If $Get(tTurn) '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        Do $$$AssertEquals(..Free(tOver), 1, tCase _ ": neither the class nor its package exists")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no refused write saved, compiled or deleted a class")
}

/// <p>AC4: a document the vendor's compile refuses after it generated the definition's classes (two models of one name) is answered 422 <code>ANALYTICS.PMML.COMPILE</code> by the port, the person's
/// route and the agent's confirm; neither the class nor any class of its package remains, the audit row records the outcome <code>restored</code>, and the same document compiled directly shows
/// the premise, generated classes left behind.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> do nothing -- the refusal legs go red.</p>
Method TestACompileRefusedAfterItsClassesWereGeneratedLeavesNone()
{
    Set tDuplicate = $Replace(..Text(), "modelName='Span'", "modelName='Hue'")
    Do $$$AssertTrue(tDuplicate '= ..Text(), "the document names one model twice")
    Set tControl = ..Name("Control")
    Do $$$AssertStatusNotOK(..CompileDirect(tControl, tDuplicate), "the vendor's own compile refuses it")
    Do $$$AssertEquals(..PackageHeld(tControl), 1, "and leaves the classes it had generated, so the writes below have something to put back")
    Do $$$AssertStatusOK(..RemoveFixtures(), "the control's classes are removed")
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tClass = ..Name("Twice")
    Do $$$AssertEquals(..Add(tClass, tDuplicate, .tRes), "422 ANALYTICS.PMML.COMPILE", "the port answers the compile's code")
    Do $$$AssertEquals(..Free(tClass), 1, "neither the class nor a class of its package remains")
    Do $$$AssertEquals(..Recorded(tSince, tClass, "analytics.pmmlmodels.add", "restored"), 1, "the audit row records the outcome restored")
    Set tPerson = ..Name("TwicePerson")
    Set tStatus = ..Post(..#SCREENROUTE, {"Class": (tPerson), "PMML": (tDuplicate)}, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.COMPILE", "the person's route answers the same")
    Do $$$AssertEquals(..Free(tPerson), 1, "and leaves nothing")
    Set tAgent = ..Name("TwiceAgent")
    Do ..Mint(..#ADDTOOL, {"Class": (tAgent), "PMML": (tDuplicate)}, .tProposal, .tTurn)
    If $IsObject($Get(tProposal)) {
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "422 ANALYTICS.PMML.COMPILE", "the agent's confirm answers the same: " _ $Extract($Get(tRaw), 1, 200))
        Do $$$AssertEquals(..Free(tAgent), 1, "and leaves nothing")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class of any of the writes is left")
}

/// <p>AC2, AD-10: OcuPilot's own names are refused 403 <code>PROHIBITED.OCUPILOTCODE</code> by the port, the person's route and the agent's mint in lower and upper case, below a package of
/// the product and with its name as a prefix of the first package, and nothing is made.</p>
/// <p>Mutation (Rule 19): drop the own-code test from <method>OcuPilot.Port.AnalyticsPort.PlanPmmlDefinition</method> -- the prefix leg, which the package shape test passes, goes red.</p>
Method TestOwnNamesInOtherCasesAndWithAPrefixAreRefused()
{
    Set tText = ..Text()
    For tName = "ocupilot.ProbePmml.NewLower", "OCUPILOT.ProbePmml.NewUpper", "OcuPilotProbePmml.NewPrefix", "ocupilotprobepmml.NewPrefixLower" {
        Do ..AssertOwnCodeRefused(tName, ..#WRITEENDPOINT, "ADD", tName, {"Class": (tName), "PMML": (tText)}, "", ..#SCREENROUTE, "", {"Class": (tName), "PMML": (tText)}, ..#ADDTOOL, {"Class": (tName), "PMML": (tText)})
        Do $$$AssertEquals(..Free(tName), 1, tName _ ": neither the class nor its package exists")
    }
}

}
