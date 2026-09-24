/// <p>Story 7.10's unarmed suite: the application-error delete's three scopes, pinned where nothing
/// is deleted (AD-13, AD-48, AD-53).</p>
/// <p><b>What it pins.</b> The tool's schema admits an optional <code>date</code> and
/// <code>errorNumber</code> and is still closed; <class>OcuPilot.Screen.Tool.ErrorDeleteMint</class>
/// refuses an <code>errorNumber</code> without a <code>date</code> and any argument carrying the
/// composite separator before any read, and joins a scope's arguments into one composite id;
/// <method>OcuPilot.Screen.Tool.ErrorDelete.ArgumentPairs</method> resolves a composite id's pairs
/// on its namespace, so the shared gate refuses every scope short of its WRITE pair; the port
/// refuses a malformed scope 400 and a scope the log does not hold 404, and narrows its
/// enumeration to a date or one error; and the error log screen declares the
/// <code>delete</code> action the tool carries out.</p>
/// <p><b>What it needs from the environment.</b> An instance whose application error log holds at
/// least one error in some namespace; every leg that needs one asserts it found one. It writes and
/// deletes nothing: every enumeration is a read, and every mint here is refused before a proposal
/// is stored. The real deletes are <class>OcuPilot.Test.ErrorDelete</class>'s, on a throwaway.</p>
Class OcuPilot.Test.ErrorDeleteScope Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ErrorDelete";

Parameter MINT = "OcuPilot.Screen.Tool.ErrorDeleteMint";

/// <p>The delete tool with the counting port, handed to the mint as its tool class.</p>
Parameter PROBETOOL = "OcuPilot.Test.ErrorDeleteScopeTool";

Parameter FIXTURE = "OcuPilot.Test.ErrorLogFixture";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LogErrorList";

Parameter PORT = "OcuPilot.Port.LogSourcePort";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A namespace no instance carries.</p>
Parameter ABSENTNAMESPACE = "OCUPILOTNOSUCHNAMESPACE";

/// <p>A date in a spelling <code>DateList</code> never emits: the same day as
/// <code>09/23/2026</code>, and still not a date the log answers.</p>
Parameter MISSPELTDATE = "9/23/26";

/// <p>An error number no date carries.</p>
Parameter ABSENTNUMBER = "999999999";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
    Quit $$$OK
}

/// <p>The schema admits the two optional scope arguments, types them, requires neither, and still
/// refuses a key it does not declare.</p>
/// <p>Mutation (Rule 19): drop the <code>errorNumber</code> property from
/// <method>OcuPilot.Screen.Tool.ErrorDelete.InputSchema</method> -- the by-error arguments are
/// refused and this goes red.</p>
Method TestTheSchemaAdmitsTheTwoScopeArgumentsAndStaysClosed()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("date").%Get("type"), "string", "date is advertised as a string")
    Do $$$AssertEquals(tProperties.%Get("errorNumber").%Get("type"), "integer", "errorNumber as an integer")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""namespace""]", "and only the namespace is required")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "the schema is still closed")
    Do $$$AssertTrue(tProperties.%Get("date").%Get("description") [ "MM/DD/YYYY", "the date's description names the spelling the log lists")

    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "USER"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "a namespace alone validates: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "USER", "date": "09/23/2026"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "a namespace and a date validate: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "USER", "date": "09/23/2026", "errorNumber": 4}, .tProblem)
    Do $$$AssertStatusOK(tSC, "and all three: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "USER", "errorNumber": "4"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an errorNumber that is not a number is refused")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "USER", "entries": []}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "and a key the schema does not declare is refused")
    Do $$$AssertTrue(tProblem [ "entries", "naming it: " _ tProblem)
}

/// <p>AC5 -- the mint refuses an <code>errorNumber</code> without a <code>date</code>, an empty
/// <code>date</code>, and any argument carrying <code>$Char(1)</code>, with 400
/// <code>TOOL.ARGUMENTS</code>, before the port opens a single query.</p>
/// <p>Mutation (Rule 19): delete the <code>errorNumber</code>-needs-<code>date</code> refusal from
/// <method>OcuPilot.Screen.Tool.ErrorDeleteMint.Mint</method> -- the mint then asks the port about
/// <code>USER &#8250; 4</code>, the query counter moves and the problem no longer names the missing
/// date.</p>
Method TestTheMintRefusesAMalformedScopeBeforeAnyRead()
{
    Do $$$AssertEquals($ClassMethod(..#TOOL, "MintClass"), ..#MINT, "the tool mints through its own scope-joining mint")

    Set tSC = ..MintWith({"namespace": "USER", "errorNumber": 4}, "USER", ..#PROBETOOL, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an errorNumber without a date is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "as the arguments' fault")
    Set tProblem = ..ProblemOf(.tFault)
    Do $$$AssertTrue((tProblem [ "errorNumber") && (tProblem [ "date"), "naming the number and the date it needs: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "and the port opened no query")

    Do $ClassMethod(..#FIXTURE, "ClearCounts")
    Set tSeparated = "US" _ $Char(1) _ "ER"
    Set tSC = ..MintWith({"namespace": (tSeparated)}, tSeparated, ..#PROBETOOL, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an argument carrying the separator is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "as the arguments' fault")
    Do $$$AssertTrue(..ProblemOf(.tFault) [ "namespace", "naming the argument: " _ ..ProblemOf(.tFault))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "and the port opened no query")

    Do $ClassMethod(..#FIXTURE, "ClearCounts")
    Set tSC = ..MintWith({"namespace": "USER", "date": ("09/23/2026" _ $Char(1) _ "4")}, "USER", ..#PROBETOOL, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a date carrying the separator is refused too")
    Do $$$AssertTrue(..ProblemOf(.tFault) [ "date", "naming the date: " _ ..ProblemOf(.tFault))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "before any query")

    Do $ClassMethod(..#FIXTURE, "ClearCounts")
    Set tSC = ..MintWith({"namespace": "USER", "date": ""}, "USER", ..#PROBETOOL, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an empty date is refused rather than read as the whole namespace")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertTrue(..ProblemOf(.tFault) [ "date", "naming the date: " _ ..ProblemOf(.tFault))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "before any query")
}

/// <p>The mint joins the scope's arguments into one composite id, which is what reaches the port,
/// and a refusal naming that id reads it with the breadcrumb separator rather than a control
/// character. Refused by the port's own date check, so no proposal is stored.</p>
/// <p>Mutation (Rule 19): mint with the bare namespace instead of the joined id -- the whole
/// namespace is enumerated, the mint proceeds past the refusal, and this goes red.</p>
Method TestTheMintJoinsTheScopeIntoOneIdTheLogIsAskedAbout()
{
    Set tNamespace = ..HeldNamespace(.tDate)
    Do $$$AssertNotEquals(tNamespace, "", "the instance's application error log holds errors in some namespace")
    If tNamespace = "" Quit

    Set tSC = ..MintWith({"namespace": (tNamespace), "date": (..#MISSPELTDATE)}, tNamespace, ..#TOOL, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a date the log does not list as spelled is refused at the mint")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Set tProblem = ..ProblemOf(.tFault)
    Do $$$AssertTrue(tProblem [ (tNamespace _ " " _ $Char(8250) _ " " _ ..#MISSPELTDATE), "naming the joined scope as a breadcrumb: " _ tProblem)
    Do $$$AssertEquals(tProblem [ $Char(1), 0, "with no control character left in it")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and nothing was proposed")
}

/// <p>AC4's pairs, on the composite id: <method>OcuPilot.Screen.Tool.ErrorDelete.ArgumentPairs</method>
/// resolves every scope's pairs on its first part, the namespace, which is what the screen route
/// hands it.</p>
/// <p>Mutation (Rule 19): pass the whole id to <method>OcuPilot.Port.LogSourcePort.PairsFor</method>
/// -- a composite names no namespace the resolver knows, the answer is empty, and this goes
/// red.</p>
Method TestArgumentPairsOnACompositeAreItsNamespacesPairs()
{
    Set tExpected = $ClassMethod(..#PORT, "PairsFor", $Parameter(..#PORT, "ERRORSKEY"), "USER")
    Do $$$AssertTrue($ListLength(tExpected) > 0, "the namespace's own pairs resolve")
    For tId = "USER", ("USER" _ $Char(1) _ "09/23/2026"), ("USER" _ $Char(1) _ "09/23/2026" _ $Char(1) _ "4") {
        Set tArgs = {}
        Do tArgs.%Set("namespace", tId, "string")
        Set tPairs = $ClassMethod(..#TOOL, "ArgumentPairs", "", tArgs, .tResolved)
        Do $$$AssertEquals(tResolved, 1, "they resolve for a " _ $ListLength(##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)) _ "-part id")
        Do $$$AssertTrue(tPairs = tExpected, "and equal the namespace's own, WRITE half included")
    }
}

/// <p>AC4 at the shared gate the screen route runs before its fresh read
/// (<method>OcuPilot.Kernel.Proposal.Operation.Gate</method>): handed each scope's composite id as
/// the tool's argument, a caller short of the namespace's WRITE pair is refused 403 naming it. The
/// pair is refused through <class>OcuPilot.Test.ConfirmFixture</class>'s seam, so no grant
/// changes.</p>
/// <p>Mutation (Rule 19): pass the whole id to <method>OcuPilot.Port.LogSourcePort.PairsFor</method>
/// in <method>OcuPilot.Screen.Tool.ErrorDelete.ArgumentPairs</method> -- the composite resolves no
/// pairs, the gate lets the caller through, and this goes red.</p>
Method TestTheRouteGateRefusesEveryScopeShortOfItsWritePair()
{
    Set tWritePair = ""
    Set tPairs = $ClassMethod(..#PORT, "PairsFor", $Parameter(..#PORT, "ERRORSKEY"), "USER")
    For tI = 1:1:$ListLength(tPairs) {
        If $List($List(tPairs, tI), 2) = "WRITE" Set tWritePair = $List($List(tPairs, tI), 1) _ ":WRITE"
    }
    Do $$$AssertNotEquals(tWritePair, "", "USER's WRITE pair resolves")
    If tWritePair = "" Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(..#TOOL, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tSC, "the delete tool resolves")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair(tWritePair)
    For tId = "USER", ("USER" _ $Char(1) _ "09/23/2026"), ("USER" _ $Char(1) _ "09/23/2026" _ $Char(1) _ "4") {
        Set tArgs = {}
        Do tArgs.%Set("namespace", tId, "string")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, "", "", "", tArgs.%ToJSON(), $Username, "", "OcuPilot.Test.ConfirmFixture", .tGatePairs, .tRefused, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "the gate answers")
        Do $$$AssertEquals(+$Get(tRefused), 1, "a " _ $ListLength(##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)) _ "-part scope is refused")
        Do $$$AssertEquals(+$Get(tHttp), 403, "at 403")
        Do $$$AssertEquals($Get(tCode), ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the privilege code")
        Do $$$AssertEquals($Select($IsObject($Get(tDetail)): tDetail.%Get("failedPair"), 1: ""), tWritePair, "naming the WRITE pair")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
}

/// <p>The port refuses a malformed scope 400 <code>LOG.ENTRY</code> before its gate or any query,
/// and a namespace it does not hold 404 <code>LOG.NAMESPACE</code>.</p>
/// <p>Mutation (Rule 19): raise <parameter>OcuPilot.Port.LogSourcePort.SCOPEPARTS</parameter> to
/// 4 -- the four-part id reaches the namespace check, a query runs and the refusal is a 404.</p>
Method TestThePortRefusesAMalformedOrAbsentScope()
{
    Set tSC = ..Enumerate("USER" _ $Char(1) _ "09/23/2026" _ $Char(1) _ "4" _ $Char(1) _ "1", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a four-part id is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#LOGENTRY, "with the entry code")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "before any query")

    Do $ClassMethod(..#FIXTURE, "ClearCounts")
    Set tSC = ..Enumerate("USER" _ $Char(1) _ $Char(1) _ "4", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an id with an empty part is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Queries"), 0, "before any query")

    Set tSC = ..Enumerate(..#ABSENTNAMESPACE _ $Char(1) _ "09/23/2026", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a namespace the log does not hold is refused, whatever date follows it")
    Do $$$AssertEquals(+$Get(tHttp), 404, "at 404")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#LOGNAMESPACE, "with the namespace code")
}

/// <p>A date the log does not list exactly as spelled is 404 <code>LOG.DATE</code>, and a number
/// that date does not hold is 404 <code>LOG.ENTRY</code>. A held date narrows the enumeration to
/// that date's errors, and a held number to that one error, each carrying the vendor's
/// <code>time</code>.</p>
/// <p>Mutation (Rule 19): delete the <code>DateHeld</code> check from
/// <method>OcuPilot.Port.LogSourcePort.ErrorSetRun</method> -- the misspelt date enumerates as an
/// empty set at 200 and the <code>LOG.DATE</code> leg goes red.</p>
Method TestThePortNarrowsToADateOrOneErrorAndRefusesOneItDoesNotHold()
{
    Set tNamespace = ..HeldNamespace(.tDate, .tNumber, .tQty)
    Do $$$AssertNotEquals(tNamespace, "", "the instance's application error log holds errors in some namespace")
    If tNamespace = "" Quit
    Set tSeparator = $Char(1)

    Set tSC = ..Enumerate(tNamespace _ tSeparator _ ..#MISSPELTDATE, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "a date spelled other than the log lists it is refused at 404")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#LOGDATE, "with the date code")

    Set tSC = ..Enumerate(tNamespace _ tSeparator _ tDate _ tSeparator _ ..#ABSENTNUMBER, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "a number that date does not hold is refused at 404")
    Do $$$AssertEquals(..CodeOf(.tFault), ##class(OcuPilot.Api.Error).#LOGENTRY, "with the entry code")

    Do $ClassMethod(..#FIXTURE, "ClearCounts")
    Set tSC = ..Enumerate(tNamespace _ tSeparator _ tDate, .tByDate, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a held date enumerates: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "QueriesNamed", $Parameter(..#PORT, "DATELISTQUERY")), 1, "reading the date list once, to check the date, and never walking every date")
    If '$IsObject($Get(tByDate)) Quit
    Do $$$AssertEquals(tByDate.%Get("namespace"), tNamespace, "answering the namespace, not the composite")
    Do $$$AssertTrue(tByDate.%Get("count") > 0, "with that date's errors: " _ tByDate.%Get("count"))
    Do $$$AssertTrue(tByDate.%Get("count") <= tQty, "and no more than DateList counts for it")
    Set tOther = 0
    Set tUntimed = 0
    Set tIterator = tByDate.%Get("entries").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("date") '= tDate Set tOther = tOther + 1
        If tEntry.%Get("time") = "" Set tUntimed = tUntimed + 1
    }
    Do $$$AssertEquals(tOther, 0, "every entry is on that date")
    Do $$$AssertEquals(tUntimed, 0, "and every entry carries its time")

    Set tSC = ..Enumerate(tNamespace _ tSeparator _ tDate _ tSeparator _ tNumber, .tOne, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a held number enumerates")
    If '$IsObject($Get(tOne)) Quit
    Do $$$AssertEquals(tOne.%Get("count"), 1, "as exactly one entry")
    Do $$$AssertEquals(tOne.%Get("entries").%Get(0).%Get("errorNumber"), +tNumber, "that error")
}

/// <p>The error log screen declares one <code>delete</code> row action with no self-protection
/// rule, and the delete tool is what carries it out (AD-53).</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ErrorDelete.SCREENACTIONS</parameter>
/// <code>""</code> -- the tool no longer carries the action and this goes red.</p>
Method TestTheScreenDeclaresTheDeleteTheToolCarriesOut()
{
    Do $$$AssertEquals($ListToString($ClassMethod(..#SCREEN, "RowActionIds")), "delete", "the error log declares one row action, delete")
    Do $$$AssertTrue($ListFind($ClassMethod(..#TOOL, "ScreenActionIds"), "delete") > 0, "and the delete tool carries it out")
    Set tArgs = $ClassMethod(..#TOOL, "ScreenActionArguments", "delete", .tServes)
    Do $$$AssertEquals(tServes, 1, "serving it")
    Do $$$AssertEquals(tArgs.%ToJSON(), "{}", "with no argument, since it sends no body")
    Do $$$AssertEquals($ClassMethod(..#SCREEN, "EntityLabelKey"), "errorLogListLabel", "and the card names the entity with the screen's own published noun")
}

/// <p>Mint through <class>OcuPilot.Screen.Tool.ErrorDeleteMint</class> with <var>pArgs</var> and
/// identifying value <var>pId</var>, as <var>pToolClass</var>.</p>
ClassMethod MintWith(pArgs As %DynamicObject, pId As %String, pToolClass As %String, Output pProposal, Output pHttp, Output pFault) As %Status
{
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", "", pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), pToolClass)
}

/// <p>Enumerate the scope <var>pId</var> through the counting fixture's inherited
/// <method>OcuPilot.Port.LogSourcePort.Invoke</method>.</p>
ClassMethod Enumerate(pId As %String, Output pResult, Output pHttp, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery($Parameter(..#PORT, "NAMESPACEPARAM")) = pId
    Quit $ClassMethod(..#FIXTURE, "Invoke", $Parameter(..#PORT, "ENDPOINTERRORS"), $Parameter(..#PORT, "TYPEENUMERATE"), .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>A namespace the log holds errors in, its newest date, that date's highest error number and
/// its count, read from the port's own drill levels; <code>""</code> when the log holds none.</p>
ClassMethod HeldNamespace(Output pDate As %String, Output pNumber As %String, Output pQty As %Integer) As %String
{
    Set pDate = ""
    Set pNumber = ""
    Set pQty = 0
    Set tSC = $ClassMethod(..#PORT, "Errors", "namespaces", "", "", "", "", .tNamespaces, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tNamespaces)) Quit ""
    Set tIterator = tNamespaces.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNamespace = tRow.%Get("namespace")
        Set tSC = $ClassMethod(..#PORT, "Errors", "dates", tNamespace, "", "", "", .tDates, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tDates)) || (tDates.%Get("rows").%Size() = 0) Continue
        Set tDate = tDates.%Get("rows").%Get(0).%Get("date")
        Set tSC = $ClassMethod(..#PORT, "Errors", "list", tNamespace, tDate, "", "1", .tList, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tList)) || (tList.%Get("rows").%Size() = 0) Continue
        Set pDate = tDate
        Set pNumber = tList.%Get("rows").%Get(0).%Get("errorNumber")
        Set pQty = tDates.%Get("rows").%Get(0).%Get("count")
        Quit
    }
    If pDate = "" Quit ""
    Quit tNamespace
}

/// <p>The code <var>pFault</var> carries, or <code>""</code>.</p>
ClassMethod CodeOf(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    Quit pFault.%Get("code")
}

/// <p>The <code>detail.problem</code> <var>pFault</var> carries, or <code>""</code>.</p>
ClassMethod ProblemOf(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit ""
    Quit pFault.%Get("detail").%Get("problem")
}

}
