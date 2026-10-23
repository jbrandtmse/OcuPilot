/// <p>Interoperability's host test (AD-6, AD-35, AD-51, AD-52, AD-53, AD-62, Story 20.6): send one test request to an item of a
/// running production, a business process or a business operation, and show what it answered. It sends through
/// <code>EnsLib.Testing.Service</code> as the classic Testing Service dialog does, and changes no configuration: the request it
/// saves and the messages the production makes stay in the message store.</p>
/// <p>Two callers reach it: the item's Test tab, through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the request
/// class and the field values it built, and the agent's proposal and confirmation. The target is the item's composite id
/// <code>[Production, Name]</code> (<class>OcuPilot.Screen.Tool.InteropItemMint</class>); the fresh read is the port's
/// <code>TESTTARGET</code>, <b>composed from the request class and the fields the call carries</b> (<parameter>READSVALUES</parameter>),
/// so the mint, a screen action and the confirm's re-read each judge one request: the production must run with testing enabled, the
/// item must be an enabled process or operation that takes the class, and a value for a credential-named field is refused, each
/// with its own <code>INTEROP.TEST.*</code> code, 409, before anything is built. The fingerprint covers the state that judgement
/// read and the request itself.</p>
/// <p><b>The answer reaches the screen and the proposal card only</b> (<method>WriteOutput</method>, AD-39's seventh exception):
/// never a tool result, the ledger, the audit row, a log line or screen context.</p>
/// <p><b>It declares</b> <code>%Ens_TestingService:USE</code> and WRITE on the namespace's globals database beyond the Test tab's
/// pairs (AD-8, AD-62), and the custom resource of <code>EnsPortal.Dialog.TestingService</code> (AD-44), each refused by name
/// before any port call. It is not destructive: a test sends a message the production then handles, and its card states that
/// consequence (<parameter>CONSEQUENCECODE</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropItemTestSend Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.itemtest.send";

Parameter DESCRIPTION = "Propose sending one test request to an item of the running production of the namespace the user is working in, as the classic Testing Service does. It sends nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it and the item as that production's Production items list reports it; the item must be an enabled business process or business operation. Name the request class and the fields exactly as the item's Test tab lists them, with each field's value as a person would type it, and a dotted name for a field inside an embedded object. A virtual document class takes one field, content, holding the message text. Leave out a field to leave it unset. The production must be running with Testing Enabled, a field whose name holds a credential is refused, and a value its field refuses is refused. The test sends a real message through the production; the target runs it, and anything it sends on is sent too.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropItemTestTab";

/// <p>The composed fresh read of the test about to be sent.</p>
Parameter READTYPE = "TESTTARGET";

Parameter WRITETYPE = "SENDTEST";

Parameter READSVALUES As BOOLEAN = 1;

Parameter SENDSBODY As BOOLEAN = 0;

Parameter SCREENACTIONS = "test";

/// <p>The dialog sends the request class it chose and the fields it built, as JSON object text (AD-56 (ii)).</p>
Parameter SCREENVALUES = "test=requestClass:fields";

/// <p>A test saves a request and sends a message; it writes no code.</p>
Parameter ROUTINESDATABASE As BOOLEAN = 0;

Parameter WRITERESOURCE = "%Ens_TestingService";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.Dialog.TestingService";

Parameter CHANGEACTION = "updated";

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Testing";

/// <p>The card's state label, and the state a test acts on: the production's.</p>
Parameter STATEFIELD = "State";

Parameter PRECONDITIONFIELD = "State";

Parameter FINGERPRINTSUBJECT = "Namespace,Production,Name,Type,Enabled,State,Testing,RequestClass,Kind,Fields";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Production,Name,Type,Enabled,State,Testing,RequestClass,Kind,Fields,RequestValid";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.TEST.DISABLED,INTEROP.TEST.TARGETTYPE,INTEROP.TEST.TARGETDISABLED,INTEROP.TEST.REQUESTTYPE,INTEROP.TEST.SECRET,INTEROP.ITEM.AMBIGUOUS,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.TEST.SENDS";

/// <p>The argument naming the request class, and the one holding its fields.</p>
Parameter CLASSARGUMENT = "RequestClass";

Parameter FIELDSARGUMENT = "Fields";

/// <p>The longest a request class name may be.</p>
Parameter CLASSBOUND = 255;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTITEMTEST
}

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#CLASSARGUMENT, ..#FIELDSARGUMENT)
}

/// <p>What the schema says of the item's name. The test it sends states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The item to test, named exactly as the production's Production items list reports it. An item the list does not report, and one that is not an enabled business process or business operation, is refused."
}

/// <p>The derived schema with the production, the request class and the fields added and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#CLASSARGUMENT, {"type": "string", "maxLength": (..#CLASSBOUND), "description": "The request class to send, named exactly as the item's Test tab lists it in its Request class column. A class the item does not take is refused."})
    Do tProperties.%Set(..#FIELDSARGUMENT, {"type": "object", "description": "The request's fields: an object whose members are field names, as the Test tab lists them in its Field column (a dotted name for a field inside an embedded object), and whose values are text, as a person would type them. A virtual document class takes one member, content, holding the message text. Leave out a field to leave it unset. A field whose name holds a credential is refused."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push(..#CLASSARGUMENT)
        Do tSchema.%Get("required").%Push(..#FIELDSARGUMENT)
    }
    Quit tSchema
}

/// <p>The two rows the card shows: the request class, and the fields as the read gives them in canonical JSON text. They are
/// the whole of what the test sends. A read that names no class the item takes is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#CLASSARGUMENT) '= "string") || (pFresh.%GetTypeOf(..#FIELDSARGUMENT) '= "string") || (pFresh.%Get("Kind") = "") {
        Set pProblem = "this instance did not report the request the test would send"
        Quit $$$OK
    }
    For tField = ..#CLASSARGUMENT, ..#FIELDSARGUMENT {
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", pFresh.%Get(tField), "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The fresh read as the payload and nothing to merge: the card's rows are <method>StateDiff</method>'s, and the arguments
/// are carried to the port by <method>PortQuery</method>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments (AD-56 (ii)): <code>requestClass</code> as sent and <code>fields</code>
/// from JSON object text to an object of text values, each held to the bounds the port reads them under; any other spelling is
/// refused.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tPort = "OcuPilot.Port.InteropPort"
    Set tClass = ""
    Set tText = ""
    If $IsObject(pValues) {
        If pValues.%GetTypeOf($Parameter(tPort, "REQUESTCLASSKEY")) = "string" Set tClass = pValues.%Get($Parameter(tPort, "REQUESTCLASSKEY"))
        If pValues.%GetTypeOf($Parameter(tPort, "FIELDSKEY")) = "string" Set tText = pValues.%Get($Parameter(tPort, "FIELDSKEY"))
    }
    If (tClass = "") || ($Length(tClass) > ..#CLASSBOUND) {
        Set pProblem = "'" _ $Parameter(tPort, "REQUESTCLASSKEY") _ "' names the request class, 1 to " _ ..#CLASSBOUND _ " characters"
        Quit $$$OK
    }
    Set pProblem = ..FieldsFromText(tText, .tFields)
    If pProblem '= "" Quit $$$OK
    Do pArgs.%Set(..#CLASSARGUMENT, tClass, "string")
    Do pArgs.%Set(..#FIELDSARGUMENT, tFields)
    Quit $$$OK
}

/// <p>The field values a screen sent as the JSON object text <var>pText</var>, as an object in <var>pFields</var>, and
/// <code>""</code>; or the sentence that refuses the text, with <var>pFields</var> <code>""</code>: it is at most
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters and parses to an object. Shared by the host test
/// and the message edit (<class>OcuPilot.Screen.Tool.InteropMessageEditResend</class>).</p>
ClassMethod FieldsFromText(pText As %String, Output pFields) As %String
{
    Set pFields = ""
    If $Length(pText) <= ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS {
        Try {
            Set pFields = ##class(%DynamicAbstractObject).%FromJSON(pText)
        } Catch {
            Set pFields = ""
        }
    }
    If $IsObject(pFields) && pFields.%IsA("%Library.DynamicObject") Quit ""
    Set pFields = ""
    Quit "'" _ $Parameter("OcuPilot.Port.InteropPort", "FIELDSKEY") _ "' is a JSON object of text values, at most " _ ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS _ " characters"
}

/// <p>The request class and the field values, from the payload <var>pPayload</var> -- the call's arguments, or a stored payload,
/// which carries the fresh read's -- under the port's own query keys (AD-52), so the mint, a screen action and the confirm's
/// re-read each read, and the write sends, one request. <code>Fields</code> is an object in the arguments and JSON text in a
/// payload; either is passed as JSON text. The action key is only a call's (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.InteropPort"
    If pPayload.%GetTypeOf(..#CLASSARGUMENT) = "string" Set pQuery($Parameter(tPort, "REQUESTCLASSKEY")) = pPayload.%Get(..#CLASSARGUMENT)
    Do ..FieldsQuery(pPayload, ..#FIELDSARGUMENT, .pQuery)
}

/// <p>The fields <var>pPayload</var> carries as <var>pName</var> -- an object in a call's arguments, JSON text in a stored payload --
/// in <var>pQuery</var> under the port's fields key, as JSON text. Shared by the host test and the message edit.</p>
ClassMethod FieldsQuery(pPayload As %DynamicObject, pName As %String, ByRef pQuery)
{
    Set tKey = $Parameter("OcuPilot.Port.InteropPort", "FIELDSKEY")
    Set tType = pPayload.%GetTypeOf(pName)
    If tType = "string" Set pQuery(tKey) = pPayload.%Get(pName)
    If tType = "object" Set pQuery(tKey) = pPayload.%Get(pName).%ToJSON()
}

/// <p>What is wrong with the call's own arguments, as one sentence, or <code>""</code>: the request class is 1 to
/// <parameter>CLASSBOUND</parameter> characters, and the fields are as <method>FieldsProblem</method> requires. The port judges the
/// rest, from the instance.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set tClass = $Select(pArgs.%GetTypeOf(..#CLASSARGUMENT) = "string": pArgs.%Get(..#CLASSARGUMENT), 1: "")
    If (tClass = "") || ($Length(tClass) > ..#CLASSBOUND) {
        Set pProblem = "'" _ ..#CLASSARGUMENT _ "' names the request class, 1 to " _ ..#CLASSBOUND _ " characters"
        Quit $$$OK
    }
    Set pProblem = ..FieldsProblem(pArgs, ..#FIELDSARGUMENT)
    Quit $$$OK
}

/// <p>What is wrong with the argument <var>pName</var> of <var>pArgs</var> as a call's field values, as one sentence, or
/// <code>""</code>: an object of text values whose JSON is at most the agent's bound for a card-sized argument
/// (<parameter>OcuPilot.Screen.Tool.ExplorerSave.CHANGEMAXLENGTH</parameter>). Shared by the host test and the message edit.</p>
ClassMethod FieldsProblem(pArgs As %DynamicObject, pName As %String) As %String
{
    If pArgs.%GetTypeOf(pName) '= "object" Quit "'" _ pName _ "' is an object of text values"
    Set tFields = pArgs.%Get(pName)
    Set tBound = ##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH
    If $Length(tFields.%ToJSON()) > tBound Quit "'" _ pName _ "' is at most " _ tBound _ " characters of JSON"
    Set tProblem = ""
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If tType '= "string" {
            Set tProblem = "'" _ pName _ "' holds text values only, and '" _ $Extract(tKey, 1, 100) _ "' is not text"
            Quit
        }
    }
    Quit tProblem
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the
/// proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p><code>Fields</code> when any member of the call's fields is named like a credential
/// (<method>OcuPilot.Port.InteropPort.SecretPath</method>, the rule the port refuses it by), else none: its ledger row and step show the redaction mark in
/// place of whatever the agent sent (AD-3 layer 1, AD-41). The port refuses such a value before it is stored, so this redacts
/// the call that was refused. Fields sent as JSON text, which <method>ArgumentProblem</method> refuses, are read the same way,
/// and text that is not a JSON object is redacted whole.</p>
ClassMethod CallSecretNames(pInput As %DynamicAbstractObject) As %List
{
    If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pInput.%GetTypeOf(..#FIELDSARGUMENT)
    Set tFields = ""
    If tType = "object" Set tFields = pInput.%Get(..#FIELDSARGUMENT)
    If tType = "string" {
        Try {
            Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pInput.%Get(..#FIELDSARGUMENT))
        } Catch {
            Set tFields = ""
        }
        If '$IsObject(tFields) || 'tFields.%IsA("%Library.DynamicObject") Quit $ListBuild(..#FIELDSARGUMENT)
    }
    If '$IsObject(tFields) Quit ""
    Set tSecret = 0
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If ##class(OcuPilot.Port.InteropPort).SecretPath(tKey) {
            Set tSecret = 1
            Quit
        }
    }
    Quit $Select(tSecret: $ListBuild(..#FIELDSARGUMENT), 1: "")
}

/// <p>What the screen and the proposal card show of the test the port answered <var>pWritten</var> for:
/// <code>{status, sessionId, responseClass, lines, errors}</code>, the answer's lines as text and whether the test failed. A
/// test answers no <code>outcome</code> member, which the card reads as a SQL answer. Never stored, logged or put on the ledger,
/// and never sent to the model (AD-39's seventh exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("status") '= "string") || (pWritten.%GetTypeOf("lines") '= "array") Quit ""
    Set tOutput = {}
    For tName = "status", "sessionId", "responseClass" {
        Do tOutput.%Set(tName, pWritten.%Get(tName), "string")
    }
    Do tOutput.%Set("lines", pWritten.%Get("lines"))
    Do tOutput.%Set("errors", ''pWritten.%Get("errors"), "boolean")
    Quit tOutput
}

}
