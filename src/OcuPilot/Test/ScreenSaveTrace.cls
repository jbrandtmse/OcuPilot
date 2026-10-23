/// <p>Test-only recorder for <class>OcuPilot.Test.ScreenSaveOrder</class>: the steps a screen Save takes, in order, each followed by
/// <code>*</code> when this process holds a Save's target lock at that moment; the switches a test arms; the in-memory
/// connections <class>OcuPilot.Test.ScreenSaveMemoryPort</class> serves; and the question the prohibited set was last
/// asked. Everything lives in process-private globals, so no instance state is touched.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveTrace Extends %RegisteredObject
{

/// <p>The start of the lock name a Save's target hold takes.</p>
Parameter LOCKPREFIX = "^OcuPilotProposalTarget(";

/// <p>Forget every step, switch, stored connection and recorded question.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotScreenSave
}

/// <p>Forget the recorded steps, writes and question, keeping the switches and the stored connections.</p>
ClassMethod ClearSteps()
{
    Kill ^||OcuPilotScreenSave("steps"), ^||OcuPilotScreenSave("writes"), ^||OcuPilotScreenSave("asked")
}

/// <p>Append <var>pStep</var>, followed by <code>*</code> when this process holds a target lock now.</p>
ClassMethod Mark(pStep As %String)
{
    Set tIndex = $Increment(^||OcuPilotScreenSave("steps"))
    Set ^||OcuPilotScreenSave("steps", tIndex) = pStep _ $Select(..Holding(): "*", 1: "")
}

/// <p>The recorded steps, comma-joined in order.</p>
ClassMethod Steps() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotScreenSave("steps")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ ^||OcuPilotScreenSave("steps", tI)
    }
    Quit tOut
}

/// <p>Whether this process owns a lock named under <parameter>LOCKPREFIX</parameter>, read from the lock table.</p>
ClassMethod Holding() As %Boolean
{
    Set tPrefix = ..#LOCKPREFIX
    Set tHeld = 0
    Set tName = $Order(^$LOCK(""))
    While tName '= "" {
        If ($Extract(tName, 1, $Length(tPrefix)) = tPrefix) && ($Get(^$LOCK(tName, "OWNER")) = $Job) {
            Set tHeld = 1
            Quit
        }
        Set tName = $Order(^$LOCK(tName))
    }
    Quit tHeld
}

/// <p>Arm the switch <var>pName</var> with <var>pValue</var>.</p>
ClassMethod Arm(pName As %String, pValue As %String = 1)
{
    Set ^||OcuPilotScreenSave("arm", pName) = pValue
}

/// <p>The value of the switch <var>pName</var>, <code>""</code> when it is not armed.</p>
ClassMethod Armed(pName As %String) As %String
{
    Quit $Get(^||OcuPilotScreenSave("arm", pName))
}

/// <p>Store the connection <var>pName</var> with the fields <var>pFields</var>, as the instance would hold it.</p>
ClassMethod Seed(pName As %String, pFields As %DynamicObject)
{
    Set ^||OcuPilotScreenSave("mem", pName) = pFields.%ToJSON()
}

/// <p>The stored connection <var>pName</var>, or <code>""</code>.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    If '$Data(^||OcuPilotScreenSave("mem", pName)) Quit ""
    Quit ##class(%DynamicObject).%FromJSON(^||OcuPilotScreenSave("mem", pName))
}

/// <p>Store <var>pBody</var> as the connection <var>pName</var> and count the write.</p>
ClassMethod Put(pName As %String, pBody As %DynamicObject)
{
    Set ^||OcuPilotScreenSave("mem", pName) = pBody.%ToJSON()
    Set tCount = $Increment(^||OcuPilotScreenSave("writes"))
}

/// <p>The writes the port has taken since <method>ClearSteps</method>.</p>
ClassMethod Writes() As %Integer
{
    Quit +$Get(^||OcuPilotScreenSave("writes"))
}

/// <p>Record the question the prohibited set was asked.</p>
ClassMethod Asked(pTool As %String, pRef As %String, pPayload As %String, pDiff As %String)
{
    Set ^||OcuPilotScreenSave("asked", "tool") = pTool
    Set ^||OcuPilotScreenSave("asked", "ref") = pRef
    Set ^||OcuPilotScreenSave("asked", "payload") = pPayload
    Set ^||OcuPilotScreenSave("asked", "diff") = pDiff
}

/// <p>The part <var>pPart</var> (<code>tool</code>, <code>ref</code>, <code>payload</code> or <code>diff</code>) of the
/// last question the prohibited set was asked.</p>
ClassMethod AskedOf(pPart As %String) As %String
{
    Quit $Get(^||OcuPilotScreenSave("asked", pPart))
}

}
