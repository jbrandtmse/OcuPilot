/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass that runs the Auditing screen's
/// <code>copy</code> in this process through <class>OcuPilot.Test.AuditStartedPort</class>, by
/// <class>OcuPilot.Test.AuditStartedCopy</class> under the shipped tool's registry entry, and
/// captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuditStartedAction Extends OcuPilot.Api.ScreenAction
{

Parameter TOOL = "security.auditing.copy";

Parameter TOOLCLASS = "OcuPilot.Test.AuditStartedCopy";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AuditingConfig";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.AuditStartedPort"
}

/// <p>Copy the audit database to <var>pNamespace</var> as the screen route's <code>Run</code> does,
/// answering the envelope written in <var>pAnswer</var> and <code>%response.Status</code> in
/// <var>pStatus</var>.</p>
ClassMethod Copy(pNamespace As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set pAnswer = ""
    Set pStatus = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tTool)) Quit $$$ERROR($$$GeneralError, "the copy tool did not resolve")
    Set tType = $ClassMethod(..#DESCRIPTOR, "PrimaryEntityType")
    Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, "SYSTEM")
    Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTOR, "Scope"))
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, tScope, tId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tValues = {}
    Do tValues.%Set("CopyNamespace", pNamespace, "string")
    Set tFile = ##class(%File).TempFilename("json")
    Set tIO = $IO
    New %response
    Set %response = ##class(%CSP.Response).%New()
    Open tFile:("WNS"):5
    If '$Test Quit $$$ERROR($$$GeneralError, "the capture file could not be opened")
    Try {
        Use tFile
        Set tSC = ..Run(tTool, ..#TOOLCLASS, "copy", tType, tScope, tId, tTargetRef, tValues, {})
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Use tIO
    Close tFile
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tReadSC = tStream.LinkToFile(tFile)
    If $$$ISOK(tReadSC) Set pAnswer = tStream.Read(1000000)
    Set tStream = ""
    Do ##class(%File).Delete(tFile)
    Set pStatus = +%response.Status
    Quit tSC
}

}
