/// <p>System Explorer's Unit tests Run (AD-5, AD-10, AD-22, AD-23, AD-51, AD-52, AD-53, Story 24.5): run the unit tests of a
/// package, a class or one method in the namespace the screen is scoped to, in the request that asks for it, through
/// <class>OcuPilot.Port.DevToolPort</class> and <code>%UnitTest.Manager</code>. The tests' own code runs as the signed-in
/// person, with that person's rights, and OcuPilot cannot see or undo what it changes, so this is AD-10's named run-code
/// exception and it is held to three rules.</p>
/// <p><b>It is a person's alone</b> (<parameter>ADVERTISED</parameter> 0, AD-53's fifth named case): the provider's tool list,
/// the dispatch lookup, the screen context's tools and the discovery tool never carry it, and
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> refuses a call of it that the agent can reach
/// (<parameter>PERSONGATE</parameter>). Its one caller is the Unit tests screen's row action <code>run</code> through
/// <class>OcuPilot.Api.ScreenAction</class>, so it mints no proposal and has no copy-out draft.</p>
/// <p><b>It is off by default</b> (AD-22): <parameter>PERSONGATE</parameter> makes the action route ask the governance key
/// <code>explorer.unittests.run</code>, shipped <code>false</code>, which an OcuPilot administrator switches on in Governance
/// policy. Every run is confirmed by the person first, in a dialog that names its consequence.</p>
/// <p><b>The fresh read is the port's <code>STATE</code></b>, composed from the target and its level
/// (<parameter>READSVALUES</parameter>, <method>PortQuery</method>): the classes the run would run, whether it names a
/// production test and whether another run holds the lock. The port refuses the matrix's shapes before any body runs.</p>
/// <p><b>It is destructive</b>: nothing a test does is undone from OcuPilot. Named limits: there is no cancel, an answer lost
/// to the gateway's timeout still shows in the record, and every run resets the instance's SQL statistics flags and the
/// vendor's temporary unit-test state. The run's answer, three numbers, reaches the screen alone
/// (<method>WriteOutput</method>).</p>
Class OcuPilot.Screen.Tool.ExplorerUnitTestRun Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.unittests.run";

Parameter DESCRIPTION = "Run a namespace's unit tests. Only a person runs them, from the Unit tests screen; the agent never does.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerUnitTests";

/// <p>Reached by the screen's route alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The action route asks <code>explorer.unittests.run</code> and refuses with this code while the key is off (AD-10).</p>
Parameter PERSONGATE = "EXPLORER.UNITTEST.OFF";

Parameter PORTCLASS = "OcuPilot.Port.DevToolPort";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "RUN";

/// <p>No body: the port runs what the declared values name.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the tests and the level the action carries (<method>PortQuery</method>).</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>Declared: nothing a test does is undone from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "run";

Parameter SCREENVALUES = "run=tests:level";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Tests,Level,Classes,Production,Busy";

/// <p>What the run covers: the namespace, the target and its level, and the classes they resolve to. <code>Busy</code> is the
/// field the run's precondition reads and is covered with them.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Tests,Level,Classes,Busy";

Parameter PRECONDITIONFIELD = "Busy";

/// <p>The refusals the port's read answers when the run cannot go ahead.</p>
Parameter PRECONDITIONCODES = "EXPLORER.UNITTEST.PRODUCTION,EXPLORER.UNITTEST.BUSY";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Classes";

/// <p>The argument naming the target, whose one value is the port's <parameter>OcuPilot.Port.DevToolPort.IDVALUE</parameter>.</p>
Parameter IDARGUMENT = "Target";

/// <p>The names the screen's values travel under as this tool's arguments.</p>
Parameter TESTSARGUMENT = "Tests";

Parameter LEVELARGUMENT = "Level";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#ENDPOINTUNITTESTRUN
}

ClassMethod IdArgument() As %String
{
    Quit ..#IDARGUMENT
}

/// <p>The query key the port reads the target from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#IDKEY
}

/// <p>The screen's own pairs and nothing beyond them (AD-8, AD-44): the port adds the namespace's database pairs, WRITE on its
/// routines database included, and names the failed pair. <var>pResolved</var> is 0 when the screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>The two declared values as this tool's arguments.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#TESTSARGUMENT, ..#LEVELARGUMENT)
}

/// <p>The schema: the literal target and the two values. The tool is never advertised, so no model reads it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "Send the literal 'unittests': the tests are run in the namespace the screen is scoped to."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do tProperties.%Set(..#TESTSARGUMENT, {"type": "string", "description": "A package, a class, or Class:Method."})
    Do tProperties.%Set(..#LEVELARGUMENT, {"type": "string", "enum": ["package", "class", "method"], "description": "What the target names."})
    Do tSchema.%Get("required").%Push(..#TESTSARGUMENT)
    Do tSchema.%Get("required").%Push(..#LEVELARGUMENT)
    Quit tSchema
}

/// <p>The screen's two values as this tool's arguments (AD-56 (ii)): <code>Tests</code> and <code>Level</code>, as sent. The
/// port judges each, so the refusal is its own.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tPair = $ListBuild("tests", ..#TESTSARGUMENT), $ListBuild("level", ..#LEVELARGUMENT) {
        If pValues.%GetTypeOf($List(tPair, 1)) = "string" Do pArgs.%Set($List(tPair, 2), pValues.%Get($List(tPair, 1)), "string")
    }
    Quit $$$OK
}

/// <p>The tests and the level under the port's own query keys, from the payload <var>pPayload</var>, so the fresh read and the
/// write name one run (AD-52). The namespace is the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#TESTSARGUMENT) = "string") && (pPayload.%Get(..#TESTSARGUMENT) '= "") Set pQuery(##class(OcuPilot.Port.DevToolPort).#TESTSKEY) = pPayload.%Get(..#TESTSARGUMENT)
    If (pPayload.%GetTypeOf(..#LEVELARGUMENT) = "string") && (pPayload.%Get(..#LEVELARGUMENT) '= "") Set pQuery(##class(OcuPilot.Port.DevToolPort).#LEVELKEY) = pPayload.%Get(..#LEVELARGUMENT)
}

/// <p>The one state row: the classes the run would run.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) Quit $$$OK
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get("Classes"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>What the screen shows of the run the port answered <var>pWritten</var> for: <code>{run, passed, failed}</code>, or
/// <code>""</code>. Never stored, logged or put on the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("run") '= "number" Quit ""
    Set tOutput = {}
    Do tOutput.%Set("run", pWritten.%Get("run"), "number")
    Do tOutput.%Set("passed", +pWritten.%Get("passed"), "number")
    Do tOutput.%Set("failed", +pWritten.%Get("failed"), "number")
    Quit tOutput
}

}
