/// <p>Test-only <class>OcuPilot.Screen.Read</class> subclass that records what a <code>state</code>
/// source's store is asked for and what it answers: the row bound the executor passes and the
/// number of rows the store fetched. Nothing of the executor itself is replaced.</p>
/// <p>State lives in <code>^||OcuPilotStateReadProbe</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.StateReadProbe Extends OcuPilot.Screen.Read
{

ClassMethod Clear()
{
    Kill ^||OcuPilotStateReadProbe
}

/// <p>What the last store call recorded: <code>maxRows</code> or <code>fetched</code>.</p>
ClassMethod Recorded(pField As %String) As %String
{
    Quit $Get(^||OcuPilotStateReadProbe(pField))
}

ClassMethod StateRows(pDescriptor As %String, pEndpoint As %String, pMaxRows As %Integer, Output pAnswer As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pEndpoint, pMaxRows, .pAnswer, .pHttpStatus, .pFault)
    Set ^||OcuPilotStateReadProbe("maxRows") = pMaxRows
    Set ^||OcuPilotStateReadProbe("fetched") = $Select($IsObject(pAnswer): pAnswer.%Size(), 1: "")
    Quit tSC
}

}
