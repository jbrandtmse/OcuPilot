/// <p>The Classes and Routines lists' answer to a question the namespace's source-control class asked after OcuPilot created
/// or deleted a document (Story 21.38, AD-39's ninth exception, AD-53, AD-61): the person's Yes, No or Cancel, which runs the
/// class's <code>AfterUserAction</code> as the person through <class>OcuPilot.Port.AtelierPort</class>.</p>
/// <p><b>It is a person's alone</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): the agent never answers a
/// source-control question, no question text reaches the model, and nothing here is minted, carded or drafted. A person's own
/// answer is never asked governance (AD-22), so its key ships disabled.</p>
/// <p><b>Its screen carries two values</b>: the <code>step</code> the question followed (1, 2 or 7) and the <code>answer</code>
/// (0 No, 1 Yes, 2 Cancel), each held to those values before any call (<method>ScreenActionDelta</method>). The fresh read
/// asks no presence, because a deleted document is gone. WRITE on the namespace's routines database is an argument pair
/// (<class>OcuPilot.Screen.Tool.ExplorerWrite</class>), and the port checks it again. The write answers nothing for the
/// screen: the class's reply is not read.</p>
Class OcuPilot.Screen.Tool.ExplorerSourceControlAnswer Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>Reached by a person's confirmed action alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The question dialog's answer, which no list surface draws.</p>
Parameter SCREENACTIONS = "answer";

Parameter SCREENVALUES = "answer=step:answer";

/// <p>The fresh read: the one document and the two declared values empty beside it, answered whether or not the namespace
/// holds the document.</p>
Parameter READTYPE = "ANSWERDOCS";

Parameter WRITETYPE = "ANSWER";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>An answer acts in the namespace the question was asked in.</p>
Parameter PRECONDITIONFIELD = "Namespace";

Parameter READANSWERS = "Present,Modified,Absent,Namespace,step,answer";

Parameter FINGERPRINTSUBJECT = "Namespace,step,answer";

/// <p>The steps and the answers a person's answer carries, each a string as the screen sends it.</p>
Parameter STEPS = "1,2,7";

Parameter ANSWERS = "0,1,2";

/// <p>The step and the answer.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#STEPKEY, ##class(OcuPilot.Port.AtelierPort).#ANSWERKEY)
}

/// <p>What is wrong with <var>pValue</var> as the one document an answer names, or <code>""</code>.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) = 1) Quit ""
    Quit "'" _ ..#IDARGUMENT _ "' names exactly one document of this list"
}

/// <p>The schema: the document, the step and the answer. The agent is never offered it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "The one document the question was asked about."})
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#STEPKEY, {"type": "string", "description": "The step the question followed: 1, 2 or 7."})
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#ANSWERKEY, {"type": "string", "description": "The answer: 0 No, 1 Yes, 2 Cancel."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.AtelierPort).#STEPKEY)
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.AtelierPort).#ANSWERKEY)
    Quit tSchema
}

/// <p>The screen's two values as this tool's arguments, each as sent, and any value outside <parameter>STEPS</parameter>
/// or <parameter>ANSWERS</parameter> refused with nothing sent (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tStep = ##class(OcuPilot.Port.AtelierPort).#STEPKEY
    Set tAnswer = ##class(OcuPilot.Port.AtelierPort).#ANSWERKEY
    For tCase = $ListBuild(tStep, ..#STEPS), $ListBuild(tAnswer, ..#ANSWERS) {
        Set tField = $List(tCase, 1)
        Set tValue = ""
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Set tValue = pValues.%Get(tField)
        If (tValue = "") || '$ListFind($ListFromString($List(tCase, 2)), tValue) {
            Set pProblem = "'" _ tField _ "' is " _ $Replace($List(tCase, 2), ",", ", ")
            Quit
        }
        Do pArgs.%Set(tField, tValue, "string")
    }
    If pProblem '= "" Set pArgs = {}
    Quit $$$OK
}

/// <p>The namespace, then the step and the answer of the stored payload <var>pPayload</var> under the port's own query
/// keys, so the answer is sent for the namespace it was read in (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AtelierPort).#STEPKEY, ##class(OcuPilot.Port.AtelierPort).#ANSWERKEY {
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>No state row: an answer moves no state of the document.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>No consequence note: an answer is not destructive.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

/// <p>Nothing for the screen to show: the class's reply to an answer is not read (AD-39, its ninth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Quit ""
}

}
