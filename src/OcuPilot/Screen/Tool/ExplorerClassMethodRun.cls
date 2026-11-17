/// <p>System Explorer's Class method console Run (AD-5, AD-10, AD-22, AD-23, AD-51, AD-52, AD-53, Story 24.6): call one class
/// method, with the arguments the person gives, in the namespace the screen is scoped to, in the request that asks for it,
/// through <class>OcuPilot.Port.DevToolPort</class>. The method runs as the signed-in person, with that person's rights, and
/// OcuPilot cannot see or undo what it changes, so this is AD-10's named run-code exception and it is held to the same three
/// rules as <class>OcuPilot.Screen.Tool.ExplorerCommandRun</class>, which it follows rather than extends because the two are
/// expected to diverge: their values, their fresh reads and their answers differ.</p>
/// <p><b>It is a person's alone, off by default and confirmed</b>: unadvertised (<parameter>ADVERTISED</parameter> 0), refused to
/// any call the agent can reach by <class>OcuPilot.Kernel.Proposal.Prohibited</class>, and asked its governance key
/// <code>explorer.classmethod.run</code>, shipped <code>false</code>, by the action route (<parameter>PERSONGATE</parameter>).
/// Its one caller is the Class method console's row action <code>run</code> through
/// <class>OcuPilot.Api.ScreenAction</class>, so it mints no proposal and has no copy-out draft. Each run that reaches the body
/// writes one OcuPilot <code>SecurityChange</code> row naming the class and the method and never the arguments or the answer.</p>
/// <p><b>The fresh read is the port's <code>STATE</code></b>, composed from the class, the method and the arguments
/// (<parameter>READSVALUES</parameter>, <method>PortQuery</method>): the port refuses a class method it cannot resolve before
/// any body runs. The answer, the return value, the by-reference values, the output and the method's own error, reaches the
/// screen alone (<method>WriteOutput</method>, AD-39's eighth exception).</p>
Class OcuPilot.Screen.Tool.ExplorerClassMethodRun Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.classmethod.run";

Parameter DESCRIPTION = "Call a class method in a namespace. Only a person calls it, from the Class method console; the agent never does.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassMethod";

/// <p>Reached by the screen's route alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The action route asks <code>explorer.classmethod.run</code> and refuses with this code while the key is off (AD-10).</p>
Parameter PERSONGATE = "EXPLORER.CLASSMETHOD.OFF";

Parameter PORTCLASS = "OcuPilot.Port.DevToolPort";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "RUN";

/// <p>No body: the port runs what the declared values name.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the class, the method and the arguments the action carries (<method>PortQuery</method>).</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>Declared: nothing a class method does is undone from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "run";

Parameter SCREENVALUES = "run=class:method:args";

/// <p>What <parameter>READTYPE</parameter> answers: <code>Arguments</code> is the list as sent and <code>ArgumentCount</code>
/// its length.</p>
Parameter READANSWERS = "Namespace,Class,Method,Arguments,ArgumentCount";

/// <p>What the run covers: the namespace, the class and method and the arguments.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Class,Method,Arguments,ArgumentCount";

Parameter PRECONDITIONFIELD = "Namespace";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Method";

/// <p>The argument naming the target, whose one value is the port's
/// <parameter>OcuPilot.Port.DevToolPort.IDVALUECLASSMETHOD</parameter>.</p>
Parameter IDARGUMENT = "Target";

/// <p>The names the screen's values travel under as this tool's arguments.</p>
Parameter CLASSARGUMENT = "Class";

Parameter METHODARGUMENT = "Method";

Parameter ARGSARGUMENT = "Arguments";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#ENDPOINTCLASSMETHOD
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

/// <p>The three declared values as this tool's arguments.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#CLASSARGUMENT, ..#METHODARGUMENT, ..#ARGSARGUMENT)
}

/// <p>The schema: the literal target and the three values. The tool is never advertised, so no model reads it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "Send the literal 'classmethod': the method is called in the namespace the screen is scoped to."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do tProperties.%Set(..#CLASSARGUMENT, {"type": "string", "description": "A class name, such as Package.Class."})
    Do tProperties.%Set(..#METHODARGUMENT, {"type": "string", "description": "One of the class's class methods."})
    Do tProperties.%Set(..#ARGSARGUMENT, {"type": "string", "description": "The arguments as a JSON array's text, at most 20."})
    For tName = ..#CLASSARGUMENT, ..#METHODARGUMENT, ..#ARGSARGUMENT Do tSchema.%Get("required").%Push(tName)
    Quit tSchema
}

/// <p>The screen's three values as this tool's arguments (AD-56 (ii)), each as sent. The port judges each, so the refusal is its
/// own.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tPair = $ListBuild("class", ..#CLASSARGUMENT), $ListBuild("method", ..#METHODARGUMENT), $ListBuild("args", ..#ARGSARGUMENT) {
        If pValues.%GetTypeOf($List(tPair, 1)) = "string" Do pArgs.%Set($List(tPair, 2), pValues.%Get($List(tPair, 1)), "string")
    }
    Quit $$$OK
}

/// <p>The class, the method and the arguments under the port's own query keys, from the payload <var>pPayload</var>, so the fresh
/// read and the write name one run (AD-52). The namespace is the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tPair = $ListBuild(..#CLASSARGUMENT, ##class(OcuPilot.Port.DevToolPort).#CLASSKEY), $ListBuild(..#METHODARGUMENT, ##class(OcuPilot.Port.DevToolPort).#METHODKEY), $ListBuild(..#ARGSARGUMENT, ##class(OcuPilot.Port.DevToolPort).#ARGSKEY) {
        If (pPayload.%GetTypeOf($List(tPair, 1)) = "string") && (pPayload.%Get($List(tPair, 1)) '= "") Set pQuery($List(tPair, 2)) = pPayload.%Get($List(tPair, 1))
    }
}

/// <p>The one state row: the class and method the call names. It never carries the arguments.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) Quit $$$OK
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get("Class") _ "." _ pFresh.%Get("Method"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>What the screen shows of the call the port answered <var>pWritten</var> for: the return value, the by-reference values,
/// the output, each flag that says one was cut, and the error the method raised, or <code>""</code>. Never stored, logged or put
/// on the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("output") '= "string" Quit ""
    Set tOutput = {}
    Do tOutput.%Set("returnValue", pWritten.%Get("returnValue"), "string")
    Do tOutput.%Set("argCount", +pWritten.%Get("argCount"), "number")
    If pWritten.%GetTypeOf("byRefValues") = "object" Do tOutput.%Set("byRefValues", pWritten.%Get("byRefValues"))
    Do tOutput.%Set("output", pWritten.%Get("output"), "string")
    For tFlag = "truncated", "byRefTruncated", "returnValueTruncated" Do tOutput.%Set(tFlag, ''pWritten.%Get(tFlag), "boolean")
    Do tOutput.%Set("error", pWritten.%Get("error"), "string")
    Quit tOutput
}

}
