/// <p>Test-only <class>OcuPilot.Area.Security.EncryptionKeyFileSave</class> subclass:
/// <method>PortClass</method> answers <class>OcuPilot.Test.EncryptionSeamPort</class>, which records each
/// call and sends it, <method>ProhibitedClass</method> the class a test names in
/// <code>^||OcuPilotEncryptionProhibited</code>, and <method>Handle</method> runs the Save in this
/// process against request and response stubs, capturing what it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionSaveFixture Extends OcuPilot.Area.Security.EncryptionKeyFileSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.EncryptionSeamPort"
}

ClassMethod ProhibitedClass() As %String
{
    Set tArmed = $Get(^||OcuPilotEncryptionProhibited)
    If tArmed '= "" Quit tArmed
    Quit ##super()
}

/// <p>Run <code>POST /encryption-key-file</code> with body <var>pBody</var>; <var>pAnswer</var> is the
/// unparsed response body, <var>pStatus</var> the numeric status and <var>pCache</var> the answer's
/// <code>Cache-Control</code>.</p>
ClassMethod Handle(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer, Output pCache As %String) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set pCache = ""
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "POST"
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write($Select($IsObject(pBody): pBody.%ToJSON(), 1: "{}"))
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotEncryptionSaveCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..HandleCreate()
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotEncryptionSaveCap, "")
        Set pStatus = +%response.Status
        Set pCache = $Get(%response.Headers("Cache-Control"))
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotEncryptionSaveCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Handle</method> binds; it must live in this class's own routine
/// for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotEncryptionSaveCap = $Get(%OcuPilotEncryptionSaveCap, "") _ s Quit
wchr(a) Set %OcuPilotEncryptionSaveCap = $Get(%OcuPilotEncryptionSaveCap, "") _ $Char(a) Quit
wnl Set %OcuPilotEncryptionSaveCap = $Get(%OcuPilotEncryptionSaveCap, "") _ $Char(10) Quit
wff Set %OcuPilotEncryptionSaveCap = $Get(%OcuPilotEncryptionSaveCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotEncryptionSaveCap = $Get(%OcuPilotEncryptionSaveCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
