/// <p>Interoperability's data transformation test (AD-6, AD-35, AD-39, AD-51, AD-52, AD-53, AD-62, Story 20.27): run one listed data
/// transformation once, on a message the caller pastes, and show the target as text. It parses the message with a virtual
/// document's <code>ImportFromString</code> or the XML reader and calls <code>Transform</code> in the request's process, as the classic
/// Test Transform dialog does, and changes no configuration.</p>
/// <p>Two callers reach it: the Data transformations row's Test action, through <class>OcuPilot.Api.ScreenAction</class>, whose dialog
/// sends the message, and the agent's proposal and confirmation. The target is the transformation's document name
/// (<code>&lt;class&gt;.cls</code>); the fresh read is the port's <code>TRANSFORM</code>, <b>composed from the pasted message the call
/// carries</b> (<parameter>READSVALUES</parameter>), so the mint, a screen action and the confirm's re-read each judge one message: a
/// source or target that is neither a virtual document nor an XML class is refused with its own
/// <code>INTEROP.TRANSFORM.*</code> code, 409, and a message that is empty or too long is a 422 on <code>content</code>, each before
/// anything is parsed or run. The fingerprint covers the classes that judgement read and the message itself.</p>
/// <p><b>The answer reaches the screen and the proposal card only</b> (<method>WriteOutput</method>, AD-39's seventh exception): never a
/// tool result, the ledger, the audit row, a log line or screen context.</p>
/// <p><b>It declares</b> <code>%Ens_DTLTest:USE</code> and WRITE on the namespace's globals database beyond the list's pairs (AD-8,
/// AD-62), and the custom resource of <code>EnsPortal.Dialog.TestTransform</code> (AD-44), each refused by name before any port call.
/// It is not destructive: the transformation's own code runs, and its card states that consequence
/// (<parameter>CONSEQUENCECODE</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropTransformTest Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.transforms.test";

Parameter DESCRIPTION = "Propose running one data transformation of the namespace the user is working in, once, on a source message you supply, as the classic Test Transform dialog does. It runs nothing by itself: it answers a proposal the user reviews and confirms. Name the transformation as the Data transformations list reports it (the class name with .cls) and give the source message as text: an HL7, X12 or other EDI document's text, or XML when the transformation's source is an XML class. A transformation whose source or target is neither an EDI document nor XML is refused. The transformation's own code runs on this instance as the user, and whatever it writes or sends, it writes or sends. Its target and the lines it writes are shown to the person only and are never returned to you.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropTransformList";

/// <p>The composed fresh read of the test about to be run.</p>
Parameter READTYPE = "TRANSFORM";

Parameter WRITETYPE = "TRANSFORMTEST";

Parameter READSVALUES As BOOLEAN = 1;

Parameter SENDSBODY As BOOLEAN = 0;

Parameter SCREENACTIONS = "test";

/// <p>The dialog sends the pasted message (AD-56 (ii)). An empty one reaches the port, which refuses it on the field.</p>
Parameter SCREENVALUES = "test=content";

Parameter SCREENEMPTY = "test=content";

/// <p>A test writes no code.</p>
Parameter ROUTINESDATABASE As BOOLEAN = 0;

Parameter WRITERESOURCE = "%Ens_DTLTest";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.Dialog.TestTransform";

Parameter CHANGEACTION = "updated";

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "SourceClass";

Parameter PRECONDITIONFIELD = "SourceClass";

Parameter FINGERPRINTSUBJECT = "Namespace,Name,SourceClass,SourceDocType,SourceKind,TargetClass,TargetDocType,TargetKind,Create,content";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Name,SourceClass,SourceDocType,SourceKind,TargetClass,TargetDocType,TargetKind,Create,content";

Parameter PRECONDITIONCODES = "INTEROP.TRANSFORM.SOURCEFORMAT,INTEROP.TRANSFORM.TARGETFORMAT,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.TRANSFORM.RUNS";

/// <p>The argument holding the pasted message.</p>
Parameter CONTENTARGUMENT = "content";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTTRANSFORMS
}

/// <p><class>OcuPilot.Screen.Tool.InteropTransformMint</class>, which refuses an unsound message before the instance is read.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropTransformMint"
}

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#CONTENTARGUMENT)
}

/// <p>What the schema says of the transformation's name. The test it runs states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The data transformation to run, named exactly as the Data transformations list reports it in its Name column, the class name with .cls. A transformation the list does not report is refused, and so is one whose source or target is neither an EDI document nor XML. Its target is shown to the person only; it is not returned to you."
}

/// <p>The derived schema with the transformation's name described and the source message added and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Do tProperties.%Set(..#CONTENTARGUMENT, {"type": "string", "maxLength": (##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH), "description": "The source message to run the transformation on, as text: an HL7, X12 or other EDI document's text, or XML for a transformation whose source class is an XML class. It is parsed as the transformation's source class and run once."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#CONTENTARGUMENT)
    Quit tSchema
}

/// <p>The rows the card shows: <code>Transform</code> (the name), <code>Source</code> and <code>Target</code> (the class, and the
/// document type in parentheses when it has one) and <code>Input</code>, the pasted message as one changed-lines block with its line
/// ends normalized (<method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method>). A read that names no source class is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("SourceClass") '= "string") || (pFresh.%GetTypeOf("TargetClass") '= "string") || (pFresh.%GetTypeOf(..#CONTENTARGUMENT) '= "string") {
        Set pProblem = "this instance did not report the data transformation the test would run"
        Quit $$$OK
    }
    Do ..PushRow(pRows, "Transform", pFresh.%Get("Name"))
    Do ..PushRow(pRows, "Source", ..ClassText(pFresh.%Get("SourceClass"), pFresh.%Get("SourceDocType")))
    Do ..PushRow(pRows, "Target", ..ClassText(pFresh.%Get("TargetClass"), pFresh.%Get("TargetDocType")))
    Set tText = $Translate($Replace(pFresh.%Get(..#CONTENTARGUMENT), $Char(13, 10), $Char(10)), $Char(13), $Char(10))
    Set tInput = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk("", tText)
    Do tInput.%Set("field", "Input", "string")
    Do pRows.%Push(tInput)
    Quit $$$OK
}

/// <p>One plain card row on <var>pRows</var>: <var>pField</var> from nothing to <var>pAfter</var>.</p>
ClassMethod PushRow(pRows As %DynamicArray, pField As %String, pAfter As %String) [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pAfter, "string")
    Do pRows.%Push(tRow)
}

/// <p>The class <var>pClass</var>, followed by its document type <var>pDocType</var> in parentheses when it has one.</p>
ClassMethod ClassText(pClass As %String, pDocType As %String) As %String [ Private ]
{
    Quit pClass _ $Select(pDocType = "": "", 1: " (" _ pDocType _ ")")
}

/// <p>The fresh read as the payload and nothing to merge: the card's rows are <method>StateDiff</method>'s, and the arguments are
/// carried to the port by <method>PortQuery</method>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The screen's one value as this tool's argument (AD-56 (ii)): <code>content</code>, a string as sent. Its length is the port's to
/// judge (422 <code>INTEROP.TRANSFORM.CONTENT</code> on the field), so the dialog shows the refusal on Input.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) || (pValues.%GetTypeOf(..#CONTENTARGUMENT) '= "string") {
        Set pProblem = "'" _ ..#CONTENTARGUMENT _ "' is the source message to run the transformation on, as text"
        Quit $$$OK
    }
    Do pArgs.%Set(..#CONTENTARGUMENT, pValues.%Get(..#CONTENTARGUMENT), "string")
    Quit $$$OK
}

/// <p>The pasted message, from the payload <var>pPayload</var> -- the call's arguments, or a stored payload, which carries the fresh
/// read's -- under the port's own query key (AD-52), so the mint, a screen action and the confirm's re-read each read, and the write
/// runs, one message. The action key is only a call's (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#CONTENTARGUMENT) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#CONTENTKEY) = pPayload.%Get(..#CONTENTARGUMENT)
}

/// <p>What is wrong with the call's own arguments, as one sentence, or <code>""</code>: the source message is 1 to
/// <parameter>OcuPilot.Screen.Tool.ExplorerSave.CHANGEMAXLENGTH</parameter> characters, the agent's bound for a card-sized argument. The
/// port judges the rest, from the instance.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set tBound = ##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH
    Set tLength = $Select(pArgs.%GetTypeOf(..#CONTENTARGUMENT) = "string": $Length(pArgs.%Get(..#CONTENTARGUMENT)), 1: 0)
    If (tLength < 1) || (tLength > tBound) Set pProblem = "'" _ ..#CONTENTARGUMENT _ "' is the source message, 1 to " _ tBound _ " characters"
    Quit $$$OK
}

/// <p>The same rule again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal
/// live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The transformation's name, which the card titles it by: the fresh read's, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the screen and the proposal card show of the run the port answered <var>pWritten</var> for:
/// <code>{status, sourceClass, targetClass, lines, console, errors}</code>, the target's text or the error's text, what the
/// transformation wrote to the device, and whether the run failed. A test answers no <code>outcome</code> member, which the card reads
/// as a SQL answer. Never stored, logged or put on the ledger, and never sent to the model (AD-39's seventh exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("status") '= "string") || (pWritten.%GetTypeOf("lines") '= "array") || (pWritten.%GetTypeOf("console") '= "array") Quit ""
    Set tOutput = {}
    For tName = "status", "sourceClass", "targetClass" {
        Do tOutput.%Set(tName, pWritten.%Get(tName), "string")
    }
    Do tOutput.%Set("lines", pWritten.%Get("lines"))
    Do tOutput.%Set("console", pWritten.%Get("console"))
    Do tOutput.%Set("errors", ''pWritten.%Get("errors"), "boolean")
    Quit tOutput
}

}
