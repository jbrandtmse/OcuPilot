/// <p>What Screen permissions' three writes share (AD-51, AD-52, AD-53, AD-64, Story 20.15): an
/// action-style write of one screen's adjusted permission set through
/// <class>OcuPilot.Port.ScreenAccessPort</class>, reached by two callers -- the list's row actions through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. None sends a body.</p>
/// <p><b>The fresh read is the port's <code>GET</code></b>, composed for the change at the mint and at a
/// screen action (<method>PortQuery</method>): a change the rules refuse is refused by the port with its
/// <code>ACCESS.*</code> code before anything is stored, and the read answers the set the change would leave
/// in <code>Result</code>, which <method>StateDiff</method> shows against <code>Pairs</code>.</p>
/// <p><b>Its gate is the descriptor's fixed set, never an adjusted one</b> (<method>PrivilegePairs</method>):
/// <code>%Development:USE</code> or <code>%Admin_Secure:USE</code>, either one
/// (<method>OcuPilot.Screen.Gate.AdjusterPairs</method>), so the screen that adjusts permissions cannot be
/// adjusted away from the accounts that hold either. The tools are advertised (AD-53, AD-64); dispatch and
/// confirm read this fixed set through <method>PrivilegePairs</method>.</p>
Class OcuPilot.Screen.Tool.ScreenAccessAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AgentScreenPermissions";

/// <p>The port that reads and stores a screen's permission set (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.ScreenAccessPort";

/// <p>Declared, enabled and offered to the model (AD-53, AD-64).</p>
Parameter ADVERTISED As BOOLEAN = 1;

Parameter READTYPE = "GET";

/// <p>The read is composed from the change it is read for (<method>PortQuery</method>), at the mint as at a
/// screen action.</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter READANSWERS = "Screen,Pairs,Adjusted,Pair,Result";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The label the card's one row carries.</p>
Parameter STATEFIELD = "Pairs";

Parameter PRECONDITIONFIELD = "Pairs";

Parameter FINGERPRINTSUBJECT = "Pair,Pairs,Adjusted";

Parameter READBACKFIELDS = "Pairs";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.ScreenAccessPort).#ENDPOINT
}

/// <p>The screen's <code>toolIdentifier</code>, which the list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Screen"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.ScreenAccessPort).#SCREENKEY
}

/// <p>The refusals the port's composed read answers with when the change does not fit the stored set
/// (AD-51).</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Port.ScreenAccessPort).PreconditionCodes()
}

/// <p>The descriptor's fixed either-of set, then the custom resource of each <parameter>CLASSICPAGES</parameter>
/// page (AD-8, AD-44). It never reads <method>OcuPilot.Screen.Gate.RequiredPairs</method>: this screen's
/// requirement is fixed.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages($ClassMethod(..#DESCRIPTORCLASS, "PrivilegePairs"), ..#CLASSICPAGES)
}

/// <p>The identifying property described: the screen, named by its identifier as the Screen permissions
/// list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The screen, named by the identifier the Screen permissions list reports, such as osmgmt.locks. A screen it does not report is refused.", "string")
    Quit tSchema
}

/// <p>The card's one row, <code>Pairs: &lt;current&gt; &#8594; &lt;set after the change&gt;</code>, from the
/// composed read <var>pFresh</var>. A read that answered no set is <var>pProblem</var>, since a requirement
/// nobody established is not one to change.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Pairs") '= "array") || (pFresh.%GetTypeOf("Result") '= "array") {
            Set pProblem = "this instance did not report the screen's required permissions"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", ..Joined(pFresh.%Get("Pairs")), "string")
        Do tRow.%Set("after", ..Joined(pFresh.%Get("Result")), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The strings of <var>pArray</var> joined with a comma and a space.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pArray) Quit tText
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tValue
    }
    Quit tText
}

}
