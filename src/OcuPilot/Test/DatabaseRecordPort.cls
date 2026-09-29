/// <p>Test-only <class>OcuPilot.Port.DatabasePort</class> subclass whose one replaced seam is
/// <method>Call</method>: every vendor call the port makes is recorded in a process-private global
/// -- its endpoint, request type, identifying query value and body -- before it is sent, so a test
/// reads the order of a sequenced write (Story 18.3). A call, read or write, whose
/// <code>endpoint/type</code> a test names with <method>FailOn</method> is answered 500 without being
/// sent. When <method>Accepts</method> answers 1 every mutating call is recorded and answered 200 with
/// nothing sent, while reads still reach the instance. <method>Invoke</method> keeps the port's last
/// answer and fault for each <code>endpoint/type</code>, and answers a namespace read a test armed with
/// <method>ArmNamespace</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseRecordPort Extends OcuPilot.Port.DatabasePort
{

/// <p>Whether mutating calls are answered here and never sent. 0 here.</p>
ClassMethod Accepts() As %Boolean
{
    Quit 0
}

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tMutating = ##class(OcuPilot.Port.AdminPort).IsMutating(pEndpoint, pType)
    Set tIndex = $Increment(^||OcuPilotDatabaseCalls)
    Set ^||OcuPilotDatabaseCalls(tIndex) = $ListBuild(pEndpoint _ "/" _ pType, $Get(pQuery("name")) _ $Get(pQuery("dir")), $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), tMutating)
    If $ListFind($ListFromString($Get(^||OcuPilotDatabaseFail)), pEndpoint _ "/" _ pType) {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "refused by the test port")
    }
    If tMutating && ..Accepts() {
        Set pResult = {}
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The port's call, keeping its answer and fault under <code>endpoint/type</code>; a
/// <code>Namespace.Namespace</code> <code>GET</code> answers the object <method>ArmNamespace</method>
/// armed, when one is.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tPair = pEndpoint _ "/" _ pType
    If (tPair = "Namespace.Namespace/GET") && ($Get(^||OcuPilotDatabaseNamespace) '= "") {
        Set pResult = ##class(%DynamicObject).%FromJSON(^||OcuPilotDatabaseNamespace)
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotDatabaseAnswer(tPair) = $Select($IsObject($Get(pResult)): pResult.%ToJSON(), 1: "")
    Set ^||OcuPilotDatabaseFault(tPair) = $Select($IsObject($Get(pFault)): pFault.%ToJSON(), 1: "")
    Quit tSC
}

/// <p>Answer every call of each <code>endpoint/type</code> in <var>pPairs</var> (comma-separated) with
/// a 500 and send nothing; <code>""</code> answers every call as sent.</p>
ClassMethod FailOn(pPairs As %String = "")
{
    If pPairs = "" {
        Kill ^||OcuPilotDatabaseFail
    } Else {
        Set ^||OcuPilotDatabaseFail = pPairs
    }
}

/// <p>Answer <code>Namespace.Namespace</code> <code>GET</code> with the JSON object text
/// <var>pJson</var>, sending nothing.</p>
ClassMethod ArmNamespace(pJson As %String)
{
    Set ^||OcuPilotDatabaseNamespace = pJson
}

/// <p>The last answer <method>Invoke</method> gave for <var>pPair</var>, as JSON text, or
/// <code>""</code>.</p>
ClassMethod AnswerOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotDatabaseAnswer(pPair))
}

/// <p>The last fault <method>Invoke</method> gave for <var>pPair</var>, as JSON text, or
/// <code>""</code>.</p>
ClassMethod FaultOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotDatabaseFault(pPair))
}

/// <p>Forget every recorded call, answer and fault, any armed failure and any armed namespace.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDatabaseCalls, ^||OcuPilotDatabaseFail, ^||OcuPilotDatabaseAnswer, ^||OcuPilotDatabaseFault, ^||OcuPilotDatabaseNamespace
}

/// <p>How many calls of any kind were made since <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotDatabaseCalls)
}

/// <p>The <code>endpoint/type</code> of every mutating call since <method>Clear</method>, in order,
/// comma-separated.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotDatabaseCalls) {
        If '$ListGet(^||OcuPilotDatabaseCalls(tI), 4) Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListGet(^||OcuPilotDatabaseCalls(tI), 1)
    }
    Quit tOut
}

/// <p>The <code>endpoint/type</code> of every call since <method>Clear</method>, reads included, in
/// order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotDatabaseCalls) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListGet(^||OcuPilotDatabaseCalls(tI), 1)
    }
    Quit tOut
}

/// <p>The body of the last mutating call of <var>pPair</var>, as JSON text, or <code>""</code>.</p>
ClassMethod BodyOf(pPair As %String) As %String
{
    Set tBody = ""
    For tI = +$Get(^||OcuPilotDatabaseCalls):-1:1 {
        If '$ListGet(^||OcuPilotDatabaseCalls(tI), 4) Continue
        If $ListGet(^||OcuPilotDatabaseCalls(tI), 1) '= pPair Continue
        Set tBody = $ListGet(^||OcuPilotDatabaseCalls(tI), 3)
        Quit
    }
    Quit tBody
}

/// <p>The identifying query value (<code>name</code> or <code>dir</code>) of the last mutating call of
/// <var>pPair</var>, or <code>""</code>.</p>
ClassMethod TargetOf(pPair As %String) As %String
{
    Set tTarget = ""
    For tI = +$Get(^||OcuPilotDatabaseCalls):-1:1 {
        If '$ListGet(^||OcuPilotDatabaseCalls(tI), 4) Continue
        If $ListGet(^||OcuPilotDatabaseCalls(tI), 1) '= pPair Continue
        Set tTarget = $ListGet(^||OcuPilotDatabaseCalls(tI), 2)
        Quit
    }
    Quit tTarget
}

}
