/// <p>What Journals' two switches share (Story 18.5): the target is the literal
/// <parameter>CURRENTID</parameter> on the <code>journal-file</code> type (AD-13, AD-14), because a
/// switch acts on whatever file journaling writes now and the vendor reads no target. Any other id is
/// refused by <method>ArgumentProblem</method> for the agent and <method>ScreenActionDelta</method>
/// for the screen, before anything is sent.</p>
/// <p>The fresh read is one <class>OcuPilot.Port.JournalPort</class> composes from the journal file
/// list, so a switch made between the mint and the confirm moves <code>CurrentFile</code> and refuses
/// the confirm (AD-6, AD-51). The card's one row is the state the switch moves
/// (<method>StateDiff</method>).</p>
Class OcuPilot.Screen.Tool.JournalSwitch Extends OcuPilot.Screen.Tool.JournalAction [ Abstract ]
{

/// <p>The vendor reads the switches from <code>Journal.Settings</code>.</p>
Parameter WRITEENDPOINT = "Journal.Settings";

/// <p>The one id every caller names the switch's target by.</p>
Parameter CURRENTID = "current";

ClassMethod Endpoint() As %String
{
    Quit ..#WRITEENDPOINT
}

/// <p>The query parameter the id travels under, which the vendor ignores.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property described as the literal
/// <parameter>CURRENTID</parameter>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'current': a switch acts on the file journaling writes now. Any other value is refused.", "string")
    Quit tSchema
}

/// <p>The agent's id refused unless it is <parameter>CURRENTID</parameter> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..IdProblem(pIdValue)
    Quit $$$OK
}

/// <p>The screen's target refused unless it is <parameter>CURRENTID</parameter>, after the default
/// arguments (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tId = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") Set tId = pValues.%Get(..IdArgument())
    Set pProblem = ..IdProblem(tId)
    Quit $$$OK
}

/// <p>Why <var>pId</var> is not the switch's target, or <code>""</code>.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ..#CURRENTID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ..#CURRENTID _ "': a switch acts on the file journaling writes now"
}

}
