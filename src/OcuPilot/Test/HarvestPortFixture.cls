/// <p>Subclass of <class>OcuPilot.Port.HarvestPort</class> overriding only its two seams, so
/// <class>OcuPilot.Test.Harvest</class> runs the port's real gate order, stubs, capture and outcome
/// mapping. <method>GateClass</method> answers the class a test forces, and
/// <method>LogFault</method> records each line in <code>^||OcuPilotHarvestPortFixture</code> instead
/// of writing the instance log. <method>Clear</method> forgets both.</p>
Class OcuPilot.Test.HarvestPortFixture Extends OcuPilot.Port.HarvestPort
{

/// <p>Forget the forced gate class and every recorded line.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotHarvestPortFixture
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real
/// gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotHarvestPortFixture("gate") = pClass
}

/// <p>How many lines <method>LogFault</method> recorded since <method>Clear</method>.</p>
ClassMethod LogCount() As %Integer
{
    Quit +$Get(^||OcuPilotHarvestPortFixture("log"))
}

/// <p>Recorded line <var>pIndex</var> (1-based) as <code>{message, status, code}</code>, or
/// <code>{}</code>. <code>status</code> is the raw status text.</p>
ClassMethod LogAt(pIndex As %Integer) As %DynamicObject
{
    Set tJson = $Get(^||OcuPilotHarvestPortFixture("log", pIndex))
    If tJson = "" Quit {}
    Quit ##class(%DynamicObject).%FromJSON(tJson)
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotHarvestPortFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tLine = {}
    Do tLine.%Set("message", pMessage)
    Do tLine.%Set("status", $System.Status.GetErrorText(pStatus))
    Do tLine.%Set("code", pCode, "string")
    Set tIndex = $Increment(^||OcuPilotHarvestPortFixture("log"))
    Set ^||OcuPilotHarvestPortFixture("log", tIndex) = tLine.%ToJSON()
}

}
