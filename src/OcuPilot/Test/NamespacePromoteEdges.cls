/// <p>Pins the edges of Story 24.9's promote that <class>OcuPilot.Test.NamespacePromote</class> does not reach: every
/// preflight refusal, each answered before anything is sent; a routine replaced and an include file added; the agent's
/// confirm refusing a plan it cannot read; the one cap on the documents; and the promote's script (AD-59), which copies the
/// chosen documents, stops at a create whose name is taken and at a routine the first namespace no longer holds, and
/// compiles only after every copy succeeded.</p>
/// <p>The preflight's reads are altered through <class>OcuPilot.Test.DevToolPortFixture</class>, and the writes recorded
/// through <class>OcuPilot.Test.DevToolAtelierRecorder</class>.</p>
/// <p>Needs the install namespace and the namespaces <code>USER</code> and <code>HSCUSTOM</code>; it saves and removes the
/// <code>OcuProbe248</code> documents and the <code>OcuProbe250</code> routines in both around every test.</p>
Class OcuPilot.Test.NamespacePromoteEdges Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolAtelierRecorder";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerNamespacePromote";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter CHANGED = "OcuProbe248.Changed.cls";

Parameter ONLYHERE = "OcuProbe248.OnlyHere.cls";

Parameter MAC = "OcuProbe248Mac.mac";

/// <p>The routine both namespaces hold differently and the include file only the first holds.</p>
Parameter ROUTINE = "OcuProbe250Mac.mac";

Parameter INCLUDE = "OcuProbe250Inc.inc";

Parameter ROUTINESPEC = "OcuProbe250*.mac,OcuProbe250*.inc";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#HERE)
    Do ..Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Forget the fixtures and remove the probe documents from both namespaces.</p>
Method Reset()
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe documents are removed from both namespaces")
    For tNamespace = ..#HERE, ..#THERE {
        For tName = ..#ROUTINE, ..#INCLUDE {
            Do ..InNamespace(tNamespace, "If ##class(%RoutineMgr).Exists(" _ ..Quoted(tName) _ ") Do ##class(%RoutineMgr).Delete(" _ ..Quoted(tName) _ ")")
        }
    }
}

/// <p><var>pValue</var> as a string literal.</p>
ClassMethod Quoted(pValue As %String) As %String
{
    Quit """" _ $Replace(pValue, """", """""") _ """"
}

/// <p>Run the line <var>pLine</var> in <var>pNamespace</var>, and come back.</p>
ClassMethod InNamespace(pNamespace As %String, pLine As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Xecute pLine
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Save the routine <var>pName</var> in <var>pNamespace</var> with a first line commented <var>pNote</var>.</p>
Method SaveRoutine(pNamespace As %String, pName As %String, pNote As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoutine = ##class(%Routine).%New(pName)
        Do tRoutine.WriteLine($Piece(pName, ".", 1) _ " ; " _ pNote)
        Do tRoutine.WriteLine(" Quit")
        Set tSC = tRoutine.Save()
        Set tRoutine = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, pName _ " is saved in " _ pNamespace)
}

/// <p>The port's <var>pType</var> over the fixture, from <code>USER</code> into <code>HSCUSTOM</code>, for
/// <var>pDocuments</var> and <var>pSpec</var>, reviewed at <var>pReviewed</var> when it is not <code>""</code>.</p>
Method Port(pType As %String, pDocuments As %String, pSpec As %String, pReviewed As %String = "", Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#HERE
    Set tQuery("target") = ..#THERE
    Set tQuery("spec") = pSpec
    Set tQuery("documents") = pDocuments
    If pReviewed '= "" Set tQuery("reviewed") = pReviewed
    Quit $ClassMethod(..#FIXTURE, "Invoke", "NamespaceDiff", pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The plan of <var>pDocuments</var> under <var>pSpec</var>, or <code>""</code>.</p>
Method Plan(pDocuments As %String, pSpec As %String) As %DynamicObject
{
    Do $$$AssertStatusOK(..Port("PLAN", pDocuments, pSpec, , .tPlan), "the plan is read")
    Quit $Select($IsObject($Get(tPlan)): tPlan, 1: "")
}

/// <p>The hash of each document <var>pSpec</var> matches in <var>pNamespace</var>, as <code>name=hash</code> entries,
/// semicolon-joined, in name order.</p>
Method State(pNamespace As %String, pSpec As %String = {..#SPEC}) As %String
{
    Kill tCriteria
    Set tCriteria("spec") = pSpec
    Set tCriteria("namespace") = pNamespace
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "DocumentHashes", "LIST", .tCriteria, "", .tRows, .tHttp, .tFault), "the hash read answers in " _ pNamespace)
    Set tState = ""
    If '$IsObject($Get(tRows)) Quit tState
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tState = tState _ tRow.%Get("Document") _ "=" _ tRow.%Get("Hash") _ ";"
    }
    Quit tState
}

/// <p>One document's hash in <var>pNamespace</var> under <var>pSpec</var>, or <code>""</code>.</p>
Method HashOf(pNamespace As %String, pDocument As %String, pSpec As %String = {..#SPEC}) As %String
{
    Set tState = ..State(pNamespace, pSpec)
    Set tFrom = $Find(tState, pDocument _ "=")
    If 'tFrom Quit ""
    Quit $Piece($Extract(tState, tFrom, *), ";", 1)
}

/// <p>The promote's script for <var>pDocuments</var>, with the plan's steps as the stored payload carries them.</p>
Method Script(pDocuments As %String, pPlan As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#HERE
    Set tQuery("target") = ..#THERE
    Set tQuery("documents") = pDocuments
    Set tContext = {"payload": {}}
    If $IsObject(pPlan) Do tContext.payload.%Set("Steps", pPlan.Steps)
    Set tSteps = ##class(OcuPilot.Port.DevToolPort).Snippet("NamespaceDiff", "PROMOTE", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ $Select(tSteps.%Size(): tSteps.%Get(0).kind, 1: ""), "1|objectscript", "one ObjectScript step")
    Quit $Select(tSteps.%Size(): tSteps.%Get(0).text, 1: "")
}

/// <p>Run every line of the script <var>pText</var>, as a terminal would, and come back to this namespace.</p>
Method Run(pText As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        For tI = 1:1:$Length(pText, $Char(10)) {
            Xecute $Piece(pText, $Char(10), tI)
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the script runs")
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Whether <var>pClass</var> is compiled in <var>pNamespace</var>.</p>
ClassMethod CompiledIn(pNamespace As %String, pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tCompiled = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tCompiled = ##class(%Dictionary.CompiledClass).%ExistsId(pClass)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCompiled
}

/// <p>Each preflight refusal is answered before anything is sent, naming its document: the first namespace's text changed
/// since the plan, the other copy's text changed, a source the instance does not hold, a text longer than one save takes, a
/// first line naming another document, and an other copy whose version cannot be read. The documents sorted before the
/// refused one are not written either.</p>
/// <p>Mutation (Rule 19): drop the empty-version refusal from <method>OcuPilot.Port.DevToolPort.Preflight</method> -- the
/// save is sent and the last leg goes red.</p>
Method TestEachPreflightRefusalWritesNothing()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Set tSteps = ..#CHANGED _ "," _ ..#ONLYHERE _ "," _ ..#MAC
    Set tPlan = ..Plan(tSteps, ..#SPEC)
    If '$IsObject(tPlan) Quit
    Set tBefore = ..State(..#THERE)
    Set tStale = "409|" _ ##class(OcuPilot.Port.DevToolPort).#CODESTALE
    For tCase = $ListBuild(..#HERE, ..#MAC, "changed", tStale), $ListBuild(..#THERE, ..#CHANGED, "changed", tStale), $ListBuild(..#HERE, ..#MAC, "missing", "404|" _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND), $ListBuild(..#HERE, ..#MAC, "long", "400|" _ ##class(OcuPilot.Api.AtelierError).#SAVETOOLARGE), $ListBuild(..#HERE, ..#ONLYHERE, "header", "422|" _ ##class(OcuPilot.Api.AtelierError).#SAVEHEADER), $ListBuild(..#THERE, ..#CHANGED, "noversion", tStale) {
        Set tLabel = $List(tCase, 3) _ " " _ $List(tCase, 2) _ " in " _ $List(tCase, 1)
        Do $ClassMethod(..#FIXTURE, "Clear")
        Do $ClassMethod(..#RECORDER, "Clear")
        Do $ClassMethod(..#FIXTURE, "SetAtelierClass", ..#RECORDER)
        Do $ClassMethod(..#FIXTURE, "SetForge", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Kill tFault
        Do $$$AssertStatusNotOK(..Port("PROMOTE", tSteps, ..#SPEC, tPlan.PlanHash, , .tHttp, .tFault), tLabel _ ": refused")
        Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.detail.%Get("document"), 1: ""), $List(tCase, 4) _ "|" _ $List(tCase, 2), tLabel _ ": its status and code, naming the document")
        Do $$$AssertEquals($ClassMethod(..#RECORDER, "Writes"), "", tLabel _ ": nothing was sent")
    }
    Do $$$AssertEquals(..State(..#THERE), tBefore, "the other namespace is as it was")
}

/// <p>A routine both namespaces hold differently is replaced and an include file only the first holds is added, each then
/// equal to its source; the routine is compiled and the include file is not.</p>
Method TestARoutineIsReplacedAndAnIncludeFileAdded()
{
    Do ..SaveRoutine(..#HERE, ..#ROUTINE, "here")
    Do ..SaveRoutine(..#THERE, ..#ROUTINE, "there")
    Do ..SaveRoutine(..#HERE, ..#INCLUDE, "here")
    Set tSteps = ..#INCLUDE _ "," _ ..#ROUTINE
    Set tPlan = ..Plan(tSteps, ..#ROUTINESPEC)
    If '$IsObject(tPlan) Quit
    Do $$$AssertEquals(tPlan.Steps.%ToJSON(), "[{""Document"":""OcuProbe250Inc.inc"",""Change"":""Only in this namespace""},{""Document"":""OcuProbe250Mac.mac"",""Change"":""Content differs""}]", "the include file is a create and the routine a save")
    Do $ClassMethod(..#FIXTURE, "SetAtelierClass", ..#RECORDER)
    Do $$$AssertStatusOK(..Port("PROMOTE", tSteps, ..#ROUTINESPEC, tPlan.PlanHash, .tResult, .tHttp, .tFault), "the promote answers")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.documents.%Get(0).Outcome _ "|" _ tResult.documents.%Get(1).Outcome _ "|" _ tResult.stopped, "Added|Replaced|0", "Added, then Replaced")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Writes"), "CREATE:HSCUSTOM:OcuProbe250Inc.inc,SAVE:HSCUSTOM:OcuProbe250Mac.mac,COMPILE:HSCUSTOM:OcuProbe250Mac.mac:cuk", "the routine is compiled and the include file is not")
    For tDocument = ..#INCLUDE, ..#ROUTINE {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument, ..#ROUTINESPEC), ..HashOf(..#HERE, tDocument, ..#ROUTINESPEC), tDocument _ ": the other namespace holds the first's text")
    }
}

/// <p>The agent's confirm reads the plan again: a plan it can read whose steps the fence admits is confirmed, and one it
/// cannot read, or stored arguments that are not an object, refuse. A set that is not names of classes and routines is
/// refused before the mint reads anything.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.ExplorerNamespacePromote.ConfirmProblem</method> answer no
/// problem -- the unreadable leg goes red.</p>
Method TestTheConfirmReadsThePlanAgain()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Set tSteps = ..#CHANGED _ "," _ ..#ONLYHERE _ "," _ ..#MAC
    Set tArgs = {"Generated": "no"}
    Do tArgs.%Set("Namespace", ..#HERE, "string")
    Do tArgs.%Set("Target", ..#THERE, "string")
    Do tArgs.%Set("Spec", ..#SPEC, "string")
    Do $$$AssertStatusOK($ClassMethod(..#TOOL, "ConfirmProblem", tSteps, tArgs, .tProblem), "the confirm is asked")
    Do $$$AssertEquals(tProblem, "", "a plan whose steps the fence admits is confirmed")
    Do tArgs.%Set("Target", "%SYS", "string")
    Do $$$AssertStatusOK($ClassMethod(..#TOOL, "ConfirmProblem", tSteps, tArgs, .tProblem), "the confirm is asked again")
    Do $$$AssertEquals(tProblem, "the plan could not be read, so the agent does not promote it", "a plan it cannot read refuses")
    Do $$$AssertStatusOK($ClassMethod(..#TOOL, "ConfirmProblem", tSteps, "", .tProblem), "the confirm is asked with no arguments")
    Do $$$AssertNotEquals(tProblem, "", "stored arguments that are not an object refuse")
    Do $$$AssertNotEquals($ClassMethod(..#TOOL, "SetProblem", "OcuProbe248 Changed.cls"), "", "a name with a space is refused")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "SetProblem", tSteps), "", "the three steps are a set")
}

/// <p>The tool's cap and the screen's checked-row cap are the source code API's own.</p>
Method TestThePromoteCapIsTheSourceCodeAPIsOwn()
{
    Set tMax = ##class(OcuPilot.Port.AtelierPort).#MAXDOCUMENTS
    Do $$$AssertEquals($Parameter(..#TOOL, "MAXDOCUMENTS"), tMax, "the tool's cap")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff).DeclarationJson(.tDeclaration), "the descriptor reads")
    Do $$$AssertEquals($Select($IsObject($Get(tDeclaration)): tDeclaration.multiSelect.max, 1: ""), tMax, "the checked rows' cap")
}

/// <p>AD-59: the script of a promote starts as succeeding, then has one line to a document and one compile line to a kind,
/// each closing every block it opens; run, it copies the chosen documents into the other namespace and compiles them with
/// <code>cuk</code>. A read, and a plan, have no script form.</p>
/// <p>Mutation (Rule 19): drop the <code>Save</code> from the routine's line in <method>OcuPilot.Port.DevToolPort.Snippet</method>
/// -- the routine is not written and the hash leg goes red.</p>
Method TestTheScriptCopiesTheChosenDocumentsWhenRun()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Do $$$AssertEquals(##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "PROMOTE") _ "|" _ ##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "PLAN") _ "|" _ ##class(OcuPilot.Port.DevToolPort).SnippetForm("NamespaceDiff", "LIST"), "objectscript||", "only the promote has a script form")
    Set tSteps = ..#CHANGED _ "," _ ..#ONLYHERE _ "," _ ..#MAC
    Set tText = ..Script(tSteps, ..Plan(tSteps, ..#SPEC))
    Set tLines = $Length(tText, $Char(10))
    Do $$$AssertEquals(tLines, 6, "the first line, one line for each document and one compile line for each kind")
    For tI = 1:1:tLines {
        Set tLine = $Piece(tText, $Char(10), tI)
        Do $$$AssertEquals($Length(tLine, "{"), $Length(tLine, "}"), "line " _ tI _ " closes every block it opens")
    }
    Do $$$AssertTrue((tText [ "CompileList(""OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls"", ""cuk"")") && (tText [ "CompileList(""OcuProbe248Mac.mac"", ""cuk"")"), "the classes and the routines are compiled with cuk, each in one call")
    Do ..Run(tText)
    For tDocument = ..#CHANGED, ..#ONLYHERE, ..#MAC {
        Do $$$AssertEquals(..HashOf(..#THERE, tDocument), ..HashOf(..#HERE, tDocument), tDocument _ ": the script copied it")
    }
    Do $$$AssertTrue(..CompiledIn(..#THERE, "OcuProbe248.OnlyHere"), "and compiled the classes")
}

/// <p>AD-59: the script mirrors the write's stops. A create whose name the other namespace took after the plan is not
/// written over, the script stops there, and nothing is compiled; a routine the first namespace no longer holds is not
/// written over its copy as an empty routine.</p>
/// <p>Mutation (Rule 19): render a create's line without its free-name check in
/// <method>OcuPilot.Port.DevToolPort.Snippet</method> -- the taken class is written over and the first leg goes red.</p>
Method TestTheScriptStopsAtATakenNameAndAMissingSource()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE), "the probe pair is saved")
    Set tSteps = ..#CHANGED _ "," _ ..#ONLYHERE _ "," _ ..#MAC
    Set tText = ..Script(tSteps, ..Plan(tSteps, ..#SPEC))
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#THERE, "OcuProbe248.OnlyHere", $ClassMethod(..#PROBE, "PairText", "OnlyHere", "Taken")), "the other namespace takes the create's name after the plan")
    Set tTaken = ..HashOf(..#THERE, ..#ONLYHERE)
    Do ..Run(tText)
    Do $$$AssertEquals(..HashOf(..#THERE, ..#CHANGED), ..HashOf(..#HERE, ..#CHANGED), "the document before it is copied")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#ONLYHERE), tTaken, "the taken name is not written over")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#MAC), "", "the script stops there")
    Do $$$AssertTrue('..CompiledIn(..#THERE, "OcuProbe248.Changed"), "and compiles nothing")

    Do ..SaveRoutine(..#THERE, ..#ROUTINE, "there")
    Do ..SaveRoutine(..#HERE, ..#ROUTINE, "here")
    Set tPlan = ..Plan(..#ROUTINE, ..#ROUTINESPEC)
    Set tText = ..Script(..#ROUTINE, tPlan)
    Set tBefore = ..HashOf(..#THERE, ..#ROUTINE, ..#ROUTINESPEC)
    Do ..InNamespace(..#HERE, "Do ##class(%RoutineMgr).Delete(" _ ..Quoted(..#ROUTINE) _ ")")
    Do ..Run(tText)
    Do $$$AssertTrue(tBefore '= "", "the other namespace held the routine")
    Do $$$AssertEquals(..HashOf(..#THERE, ..#ROUTINE, ..#ROUTINESPEC), tBefore, "a routine the first namespace no longer holds leaves its copy as it was")
}

}
