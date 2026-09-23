/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass with one replaced seam:
/// <method>LogFault</method> records each line the port would log -- its message and its status
/// text -- in a process-private global, and writes nothing to the log. Every other step is the
/// shipped port's, the content import among them.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.X509LogPort Extends OcuPilot.Port.AdminPort
{

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotX509Log($Increment(^||OcuPilotX509Log)) = pMessage _ " | " _ $System.Status.GetErrorText(pStatus) _ " | " _ pCode
}

/// <p>Every recorded line, joined, and the count cleared.</p>
ClassMethod Taken() As %String
{
    Set tText = ""
    For tI = 1:1:$Get(^||OcuPilotX509Log) Set tText = tText _ $Get(^||OcuPilotX509Log(tI)) _ $Char(10)
    Kill ^||OcuPilotX509Log
    Quit tText
}

}
