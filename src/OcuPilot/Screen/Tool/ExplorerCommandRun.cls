/// <p>System Explorer's Command console Run (AD-5, AD-10, AD-22, AD-23, AD-51, AD-52, AD-53, Story 24.6): run one ObjectScript
/// command in the namespace the screen is scoped to, in the request that asks for it, through
/// <class>OcuPilot.Port.DevToolPort</class>. The command runs as the signed-in person, with that person's rights, and OcuPilot
/// cannot see or undo what it changes, so this is AD-10's named run-code exception and it is held to the same three rules as
/// the unit-test run (<class>OcuPilot.Screen.Tool.ExplorerUnitTestRun</class>).</p>
/// <p><b>It is a person's alone</b> (<parameter>ADVERTISED</parameter> 0, AD-53): the provider's tool list, the dispatch lookup,
/// the screen context's tools and the discovery tool never carry it, and <class>OcuPilot.Kernel.Proposal.Prohibited</class>
/// refuses a call of it that the agent can reach (<parameter>PERSONGATE</parameter>). Its one caller is the Command console's
/// row action <code>run</code> through <class>OcuPilot.Api.ScreenAction</class>, so it mints no proposal and has no copy-out
/// draft.</p>
/// <p><b>It is off by default</b> (AD-22): <parameter>PERSONGATE</parameter> makes the action route ask the governance key
/// <code>explorer.command.run</code>, shipped <code>false</code>, which an OcuPilot administrator switches on in Governance
/// policy. Every run is confirmed by the person first, in a dialog that names its consequence.</p>
/// <p><b>The fresh read is the port's <code>STATE</code></b>, composed from the command (<parameter>READSVALUES</parameter>,
/// <method>PortQuery</method>): the port refuses the shapes the matrix names before any body runs. <b>It is destructive</b>:
/// nothing the command does is undone from OcuPilot, there is no time limit and no cancel. Each run that reaches the body writes
/// one OcuPilot <code>SecurityChange</code> row that never carries the command. The answer, the command's output and its own
/// error, reaches the screen alone (<method>WriteOutput</method>, AD-39's eighth exception).</p>
Class OcuPilot.Screen.Tool.ExplorerCommandRun Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.command.run";

Parameter DESCRIPTION = "Run an ObjectScript command in a namespace. Only a person runs it, from the Command console; the agent never does.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerCommand";

/// <p>Reached by the screen's route alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The action route asks <code>explorer.command.run</code> and refuses with this code while the key is off (AD-10).</p>
Parameter PERSONGATE = "EXPLORER.COMMAND.OFF";

Parameter PORTCLASS = "OcuPilot.Port.DevToolPort";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "RUN";

/// <p>No body: the port runs what the declared value names.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the command the action carries (<method>PortQuery</method>).</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>Declared: nothing a command does is undone from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "run";

Parameter SCREENVALUES = "run=command";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Command";

/// <p>What the run covers: the namespace and the command.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Command";

Parameter PRECONDITIONFIELD = "Namespace";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Namespace";

/// <p>The argument naming the target, whose one value is the port's <parameter>OcuPilot.Port.DevToolPort.IDVALUECOMMAND</parameter>.</p>
Parameter IDARGUMENT = "Target";

/// <p>The name the screen's value travels under as this tool's argument.</p>
Parameter COMMANDARGUMENT = "Command";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#ENDPOINTCOMMAND
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

/// <p>The declared value as this tool's argument.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#COMMANDARGUMENT)
}

/// <p>The schema: the literal target and the command. The tool is never advertised, so no model reads it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "Send the literal 'command': the command is run in the namespace the screen is scoped to."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do tProperties.%Set(..#COMMANDARGUMENT, {"type": "string", "description": "One line of ObjectScript, up to 30,000 characters."})
    Do tSchema.%Get("required").%Push(..#COMMANDARGUMENT)
    Quit tSchema
}

/// <p>The screen's value as this tool's argument (AD-56 (ii)): <code>Command</code>, as sent. The port judges it, so the refusal
/// is its own.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf("command") = "string" Do pArgs.%Set(..#COMMANDARGUMENT, pValues.%Get("command"), "string")
    Quit $$$OK
}

/// <p>The command under the port's own query key, from the payload <var>pPayload</var>, so the fresh read and the write name one
/// run (AD-52). The namespace is the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#COMMANDARGUMENT) = "string") && (pPayload.%Get(..#COMMANDARGUMENT) '= "") Set pQuery(##class(OcuPilot.Port.DevToolPort).#COMMANDKEY) = pPayload.%Get(..#COMMANDARGUMENT)
}

/// <p>The one state row: the namespace the command runs in. It never carries the command.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) Quit $$$OK
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get("Namespace"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>What the screen shows of the run the port answered <var>pWritten</var> for: the command's output, whether it was cut, and the
/// error the command raised, or <code>""</code>. Never stored, logged or put on the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("output") '= "string" Quit ""
    Set tOutput = {}
    Do tOutput.%Set("output", pWritten.%Get("output"), "string")
    Do tOutput.%Set("truncated", ''pWritten.%Get("truncated"), "boolean")
    Do tOutput.%Set("error", pWritten.%Get("error"), "string")
    Quit tOutput
}

}
