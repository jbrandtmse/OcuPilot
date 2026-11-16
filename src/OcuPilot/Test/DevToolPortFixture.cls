/// <p>Subclass of <class>OcuPilot.Port.DevToolPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.DevToolRead</class> runs the port's real order of checks against the live instance:
/// <method>GateClass</method> answers an armed class, <method>HarvestPortClass</method> answers
/// <class>OcuPilot.Test.DevToolHarvestRecorder</class>, <method>AtelierPortClass</method> an armed class (the real one when
/// none is armed), <method>MaxDocuments</method> an armed number and <method>LogFault</method> writes to
/// <code>^||OcuPilotDevToolFixture</code>, where <method>LogCount</method> counts the lines. A promote's preflight reads
/// go through the port's own <method>ReadSource</method> and <method>ReadVersion</method>, whose answer for one armed
/// document (<method>SetForge</method>) is then altered.</p>
Class OcuPilot.Test.DevToolPortFixture Extends OcuPilot.Port.DevToolPort
{

/// <p>Forget every override and every logged line, and every call the recorder holds.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDevToolFixture
    Do ##class(OcuPilot.Test.DevToolHarvestRecorder).Clear()
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotDevToolFixture("gate") = pClass
}

/// <p>Answer <method>AtelierPortClass</method> with <var>pClass</var>; <code>""</code> restores the real port.</p>
ClassMethod SetAtelierClass(pClass As %String)
{
    Set ^||OcuPilotDevToolFixture("atelier") = pClass
}

/// <p>Alter the preflight's read of the document <var>pName</var> in <var>pNamespace</var>: <code>changed</code> answers
/// another hash, <code>missing</code> no source, <code>long</code> the text past one save's limit with its own hash,
/// <code>header</code> a first line naming another class with its own hash, and <code>noversion</code> an empty
/// version.</p>
ClassMethod SetForge(pNamespace As %String, pName As %String, pKind As %String)
{
    Set ^||OcuPilotDevToolFixture("forge", pNamespace, pName) = pKind
}

/// <p>Answer <method>MaxDocuments</method> with <var>pMax</var>.</p>
ClassMethod SetMaxDocuments(pMax As %Integer)
{
    Set ^||OcuPilotDevToolFixture("max") = pMax
}

/// <p>How many lines <method>LogFault</method> was asked to write.</p>
ClassMethod LogCount() As %Integer
{
    Quit +$Get(^||OcuPilotDevToolFixture("log"))
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotDevToolFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod HarvestPortClass() As %String
{
    Quit "OcuPilot.Test.DevToolHarvestRecorder"
}

ClassMethod AtelierPortClass() As %String
{
    Set tForced = $Get(^||OcuPilotDevToolFixture("atelier"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ReadSource(pNamespace As %String, pName As %String, Output pText As %String, Output pHash As %String, Output pAvailable As %Boolean) As %Status [ Private ]
{
    Set tSC = ##super(pNamespace, pName, .pText, .pHash, .pAvailable)
    Set tForge = $Get(^||OcuPilotDevToolFixture("forge", pNamespace, pName))
    If $$$ISERR(tSC) || 'pAvailable Quit tSC
    If tForge = "changed" Set pHash = $Translate(pHash, "0123456789ABCDEF", "123456789ABCDEF0")
    If tForge = "missing" Set pAvailable = 0, pText = "", pHash = ""
    If tForge = "long" Set pText = pText _ $Char(10) _ $Justify("", ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS)
    If tForge = "header" Set pText = "Class OcuProbe248.Elsewhere" _ $Char(10) _ $Piece(pText, $Char(10), 2, *)
    Quit tSC
}

ClassMethod ReadVersion(pNamespace As %String, pName As %String, Output pVersion As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##super(pNamespace, pName, .pVersion, .pHttpStatus, .pFault)
    If $Get(^||OcuPilotDevToolFixture("forge", pNamespace, pName)) = "noversion" Set pVersion = ""
    Quit tSC
}

ClassMethod MaxDocuments() As %Integer
{
    If $Data(^||OcuPilotDevToolFixture("max")) Quit ^||OcuPilotDevToolFixture("max")
    Quit ##super()
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tIndex = $Increment(^||OcuPilotDevToolFixture("log"))
    Set ^||OcuPilotDevToolFixture("log", tIndex) = $ListBuild(pMessage, $System.Status.GetErrorText(pStatus), pCode)
}

}
