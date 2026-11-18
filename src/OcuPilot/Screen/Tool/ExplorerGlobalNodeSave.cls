/// <p>Global nodes' Save (Story 21.5, AD-4, AD-6, AD-10, AD-51, AD-53, AD-58): set one existing node to a new plain-text value through
/// <class>OcuPilot.Port.GlobalPort</class>, once the person has confirmed the edit dialog. No node is created, and a value that is not plain
/// text of 1,000 characters at most is neither edited nor written (<class>OcuPilot.Api.GlobalError</class>).</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): a node's value never reaches the model (AD-36), so
/// the provider's tool list, the dispatch lookup and the screen context's <code>tools</code> never carry it, and its key ships disabled. A
/// person's own Save is never asked governance (AD-22).</p>
/// <p><b>Its screen carries two values</b>: the new <code>Value</code>, and <code>Was</code>, the value the dialog opened on. A Save
/// is refused 409 <code>STATE.CONFLICT</code>, and nothing is written, when the node now holds another value than <code>Was</code>
/// (<method>ScreenActionDelta</method>). The new value is the one settable argument (AD-4's merge write over the fresh read).</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalNodeSave Extends OcuPilot.Screen.Tool.ExplorerGlobalNodeWrite
{

Parameter TOOLNAME = "explorer.globalnodes.save";

Parameter DESCRIPTION = "Set one node of a global to a new plain-text value, as the global node page's Save does once confirmed. A person's own confirmed save reaches this tool; it is never offered to the agent.";

Parameter WRITETYPE = "PUT";

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "save";

/// <p>The new value, and the value the dialog opened on, which the node must still hold.</p>
Parameter SCREENVALUES = "save=Value:Was";

/// <p>A node may be edited to the empty string, and an empty value may be the one the dialog opened on.</p>
Parameter SCREENEMPTY = "save=Value:Was";

/// <p>An edit acts on a node that holds a value.</p>
Parameter PRECONDITIONFIELD = "Value";

/// <p>The value reaches the port in its query, so the read-back compares the payload's <code>Value</code> with the node's.</p>
Parameter READBACKFIELDS = "Value";

/// <p>The read-back compares the payload's <code>Value</code> although the save sends no body.</p>
Parameter READBACKPAYLOAD As BOOLEAN = 1;

Parameter FINGERPRINTSUBJECT = "Reference,Value,Namespace";

/// <p>The argument the new value travels in.</p>
Parameter VALUEARGUMENT = "Value";

Parameter IDDESCRIPTION = "The node to edit, as its canonical reference.";

/// <p>The one argument: the new value.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#VALUEARGUMENT)
}

/// <p>The schema: the node's reference and the new value, and the agent's own words.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": (..#IDDESCRIPTION)})
    Do tProperties.%Set(..#VALUEARGUMENT, {"type": "string", "description": "The new value: plain text of 1,000 characters at most."})
    Do tSchema.%Get("required").%Push(..IdArgument())
    Do tSchema.%Get("required").%Push(..#VALUEARGUMENT)
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Quit tSchema
}

/// <p>The new value refused unless it is plain text of 1,000 characters at most, as the port refuses it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If (pProblem '= "") || '$IsObject(pArgs) Quit tSC
    If (pArgs.%GetTypeOf(..#VALUEARGUMENT) '= "string") || '##class(OcuPilot.Port.GlobalPort).ValueValid(pArgs.%Get(..#VALUEARGUMENT)) {
        Set pProblem = ##class(OcuPilot.Port.GlobalPort).ReasonFor("GLOBAL.VALUE.SHAPE")
    }
    Quit $$$OK
}

/// <p>The screen's two values as this tool's argument: <code>Value</code> as it is, whatever it holds (the port refuses a value that is
/// not plain text, 1,000 characters at most), and <code>Was</code>, the value the dialog opened on, compared with the node's value in the
/// fresh read <var>pFresh</var>: another is <var>pProblem</var>, and nothing is written.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) || (pValues.%GetTypeOf("Value") '= "string") || (pValues.%GetTypeOf("Was") '= "string") {
        Set pProblem = "'Value' and 'Was' are the new value and the value the dialog opened on"
        Quit $$$OK
    }
    If $IsObject(pFresh) && (pFresh.%Get("Value") '= pValues.%Get("Was")) {
        Set pProblem = ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT
        Quit $$$OK
    }
    Do pArgs.%Set(..#VALUEARGUMENT, pValues.%Get("Value"), "string")
    Quit $$$OK
}

/// <p>The namespace and the new value, from the payload <var>pPayload</var> under the port's own query keys, so the write sets what the
/// person confirmed where the node was read (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Do ##super(pPayload, .pQuery)
    If pPayload.%GetTypeOf(..#VALUEARGUMENT) = "string" Set pQuery(##class(OcuPilot.Port.GlobalPort).#VALUEKEY) = pPayload.%Get(..#VALUEARGUMENT)
}

/// <p>The state the save moves: the node's value, from the value read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>No consequence note: a node's save is not destructive.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

}
