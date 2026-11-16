/// <p><class>OcuPilot.Port.AtelierPort</class> that records each write it is asked for in
/// <code>^||OcuPilotDevToolAtelier</code>, as the type, the namespace and the document, and, after
/// <method>FailSave</method>, refuses the save or create of that one document with a written reason, passing every other
/// call on unchanged. <class>OcuPilot.Test.DevToolPortFixture</class> hands it to the promote through
/// <method>OcuPilot.Test.DevToolPortFixture.SetAtelierClass</method>.</p>
Class OcuPilot.Test.DevToolAtelierRecorder Extends OcuPilot.Port.AtelierPort
{

/// <p>The reason the refused write carries.</p>
Parameter REFUSED = "The document is held by another process.";

/// <p>Forget every recorded write and every armed refusal.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDevToolAtelier
}

/// <p>Refuse the next save or create of <var>pName</var>, and every one after it.</p>
ClassMethod FailSave(pName As %String)
{
    Set ^||OcuPilotDevToolAtelier("fail") = pName
}

/// <p>The writes recorded since <method>Clear</method>, as <code>TYPE:namespace:name</code> entries, comma-separated, in
/// the order they were asked for. A compile's entry names its documents joined by <code>+</code> and ends with its flag
/// set (<code>:cuk</code>).</p>
ClassMethod Writes() As %String
{
    Set tList = ""
    For tI = 1:1:+$Get(^||OcuPilotDevToolAtelier) {
        Set tList = tList _ $Select(tI = 1: "", 1: ",") _ ^||OcuPilotDevToolAtelier(tI)
    }
    Quit tList
}

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pDocument As %DynamicObject) As %Status
{
    If (pType = ..#TYPESAVE) || (pType = ..#TYPECREATE) || (pType = ..#TYPECOMPILE) {
        Set tIndex = $Increment(^||OcuPilotDevToolAtelier)
        Set tEntry = pType _ ":" _ $Get(pQuery(..#NAMESPACEKEY)) _ ":" _ $Get(pQuery(..#NAMESKEY))
        If pType = ..#TYPECOMPILE Set tEntry = pType _ ":" _ $Get(pQuery(..#NAMESPACEKEY)) _ ":" _ $Translate($Get(pQuery(..#NAMESKEY)), ",", "+") _ ":" _ ..CompileFlags(+$Get(pQuery(..#KEEPSOURCEKEY)), +$Get(pQuery(..#COMPILEDEPENDENTSKEY)), +$Get(pQuery(..#SKIPUPTODATEKEY)))
        Set ^||OcuPilotDevToolAtelier(tIndex) = tEntry
        If ((pType = ..#TYPESAVE) || (pType = ..#TYPECREATE)) && (pQuery(..#NAMESKEY) = $Get(^||OcuPilotDevToolAtelier("fail"))) {
            Set pResult = ""
            Set pDocument = ""
            Set pHttpStatus = 409
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#DOCUMENTLOCKED, ..#REFUSED)
            Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.AtelierError).#DOCUMENTLOCKED)
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pDocument)
}

}
