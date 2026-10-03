/// <p>Test-only <class>OcuPilot.Area.OsMgmt.LicenseRules</class> subclass whose key check goes through
/// <class>OcuPilot.Test.LicenseSeamPort</class>, which records it, and whose <method>Validate</method>
/// route handler runs in this process against request and response stubs.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LicenseRulesFixture Extends OcuPilot.Area.OsMgmt.LicenseRules
{

ClassMethod KeyPortClass() As %String
{
    Quit "OcuPilot.Test.LicenseSeamPort"
}

/// <p>Run <code>POST /license/key/validate</code> with body <var>pBody</var>; <var>pAnswer</var> is the
/// unparsed response body, <var>pStatus</var> the numeric status and <var>pCacheControl</var> the
/// answer's <code>Cache-Control</code> header.</p>
ClassMethod Check(pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer, Output pCacheControl As %String) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
    Set pCacheControl = ""
    Set tCapturing = 0
    New %request, %response
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "POST"
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Set tSC = tStream.Write(pBody.%ToJSON())
        If $$$ISERR(tSC) Quit
        Set %request.Content = tStream
        Set %response = ##class(%CSP.Response).%New()
        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotLicenseRulesCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..HandleValidate()
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotLicenseRulesCap, "")
        Set pStatus = +%response.Status
        Set pCacheControl = $Get(%response.Headers("Cache-Control"), %response.GetHeader("Cache-Control"))
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotLicenseRulesCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Check</method> binds; it must live in this class's own routine for
/// <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotLicenseRulesCap = $Get(%OcuPilotLicenseRulesCap, "") _ s Quit
wchr(a) Set %OcuPilotLicenseRulesCap = $Get(%OcuPilotLicenseRulesCap, "") _ $Char(a) Quit
wnl Set %OcuPilotLicenseRulesCap = $Get(%OcuPilotLicenseRulesCap, "") _ $Char(10) Quit
wff Set %OcuPilotLicenseRulesCap = $Get(%OcuPilotLicenseRulesCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotLicenseRulesCap = $Get(%OcuPilotLicenseRulesCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
