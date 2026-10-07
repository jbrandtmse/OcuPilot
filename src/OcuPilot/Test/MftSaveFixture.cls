/// <p>Test-only <class>OcuPilot.Area.Security.MftConnectionSave</class> subclass: <method>PortClass</method>
/// answers <class>OcuPilot.Test.MftSeamPort</class>, which records each call and sends a probe-name write,
/// <method>ProhibitedClass</method> answers <class>OcuPilot.Test.MftSet</class>, and <method>Handle</method> runs
/// <method>HandleCreate</method> or <method>HandleUpdate</method> in this process against request and response
/// stubs, capturing what they write.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MftSaveFixture Extends OcuPilot.Area.Security.MftConnectionSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.MftSeamPort"
}

ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.MftSet"
}

/// <p>Run <code>POST /mft-connection</code> (<var>pId</var> empty) or <code>PUT /mft-connection/:id</code> with body
/// <var>pBody</var>; <var>pId</var> is the connection name as the client names it, encoded here as one path
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
        Set %OcuPilotMftCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = $Select(pId = "": ..HandleCreate(), 1: ..HandleUpdate(##class(OcuPilot.Test.MftProbe).QueryId(pId)))
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO::"^%X364"
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotMftCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO::"^%X364"
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotMftCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotMftCap = $Get(%OcuPilotMftCap, "") _ s Quit
wchr(a) Set %OcuPilotMftCap = $Get(%OcuPilotMftCap, "") _ $Char(a) Quit
wnl Set %OcuPilotMftCap = $Get(%OcuPilotMftCap, "") _ $Char(10) Quit
wff Set %OcuPilotMftCap = $Get(%OcuPilotMftCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotMftCap = $Get(%OcuPilotMftCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
