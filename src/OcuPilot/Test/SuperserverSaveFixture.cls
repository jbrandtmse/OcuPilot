/// <p>Test-only <class>OcuPilot.Area.Security.SuperserverSave</class> subclass: <method>PortClass</method>
/// answers <class>OcuPilot.Test.SuperserverSeamPort</class>, which records each call and sends a probe-port
/// write, <method>ProhibitedClass</method> answers <class>OcuPilot.Test.SuperserverSet</class>, and
/// <method>Create</method> and <method>Update</method> are run in this process against request and response
/// stubs through <method>Handle</method>, capturing what they write.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverSaveFixture Extends OcuPilot.Area.Security.SuperserverSave
{

Parameter RULES = "OcuPilot.Test.SuperserverRulesSeam";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.SuperserverSeamPort"
}

ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.SuperserverSet"
}

/// <p>Run <code>POST /superserver</code> (<var>pId</var> empty) or <code>PUT /superserver/:id</code> with body
/// <var>pBody</var>; <var>pId</var> is the composite id as the client names it, encoded here as one path
/// segment. <var>pAnswer</var> is the unparsed response body and <var>pStatus</var> the numeric status.</p>
ClassMethod Handle(pId As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = $Select(pId = "": "POST", 1: "PUT")
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotSuperserverCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = $Select(pId = "": ..HandleCreate(), 1: ..HandleUpdate(##class(OcuPilot.Test.SuperserverProbe).QueryId(pId)))
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO::"^%X364"
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotSuperserverCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO::"^%X364"
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotSuperserverCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotSuperserverCap = $Get(%OcuPilotSuperserverCap, "") _ s Quit
wchr(a) Set %OcuPilotSuperserverCap = $Get(%OcuPilotSuperserverCap, "") _ $Char(a) Quit
wnl Set %OcuPilotSuperserverCap = $Get(%OcuPilotSuperserverCap, "") _ $Char(10) Quit
wff Set %OcuPilotSuperserverCap = $Get(%OcuPilotSuperserverCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotSuperserverCap = $Get(%OcuPilotSuperserverCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
