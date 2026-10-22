/// <p>Test-only <class>OcuPilot.Port.MftPort</class> subclass that serves managed file transfer connections from process
/// memory (<class>OcuPilot.Test.ScreenSaveTrace</class>) and never reaches the instance: a <code>GET</code> of
/// <code>Security.MFT</code> answers the stored connection or 404, a <code>PUT</code> stores its body, and a
/// <code>GET</code> of <code>Security.SSLConfig</code> answers a client configuration for every name but
/// <parameter>ABSENTTLS</parameter>. Each call is a step in the trace, <code>ssl</code>, <code>read</code> or
/// <code>write</code>. Armed <code>fail</code>, the <code>PUT</code> answers a 500 fault; armed <code>throw</code>, it
/// raises an exception; armed <code>emptyread</code>, a <code>GET</code> of a connection succeeds and answers nothing.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveMemoryPort Extends OcuPilot.Port.MftPort
{

/// <p>The one SSL/TLS configuration name answered as absent.</p>
Parameter ABSENTTLS = "OcuNoSuchTLS";

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If (pEndpoint = "Security.SSLConfig") && (pType = "GET") {
        Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("ssl")
        If $Get(pQuery("name")) = ..#ABSENTTLS Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
        Set pResult = {"Name": ($Get(pQuery("name"))), "Type": 0}
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = "GET") {
        Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("read")
        If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("emptyread") {
            Set pHttpStatus = 200
            Quit $$$OK
        }
        Set tStored = ##class(OcuPilot.Test.ScreenSaveTrace).Stored($Get(pQuery("connection")))
        If '$IsObject(tStored) Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
        Set pResult = tStored
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If (pEndpoint = ..#ENDPOINT) && (pType = "PUT") {
        Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("write")
        If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("throw") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the memory port raised an exception"))
        If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("fail") {
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the memory port failed the write")
        }
        Do ##class(OcuPilot.Test.ScreenSaveTrace).Put($Get(pQuery("connection")), pBody)
        Set pResult = {}
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("other:" _ pType _ " " _ pEndpoint)
    Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
}

}
