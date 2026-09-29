/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass that runs the Namespaces list's
/// <code>copy-mappings</code> in this process through <class>OcuPilot.Test.NamespaceStartedPort</class>,
/// by <class>OcuPilot.Test.SeamNamespaceCopyMappings</class> under the shipped tool's registry entry,
/// and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceStartedAction Extends OcuPilot.Api.ScreenAction
{

Parameter TOOL = "osmgmt.namespaces.copymappings";

Parameter TOOLCLASS = "OcuPilot.Test.SeamNamespaceCopyMappings";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.NamespaceList";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.NamespaceStartedPort"
}

/// <p>Copy the mappings of <var>pSource</var> into <var>pDestination</var> as the screen route's
/// <code>Run</code> does, answering the envelope written in <var>pAnswer</var> and
/// <code>%response.Status</code> in <var>pStatus</var>.</p>
ClassMethod Copy(pDestination As %String, pSource As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set pAnswer = ""
    Set pStatus = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tTool)) Quit $$$ERROR($$$GeneralError, "the copy tool did not resolve")
    Set tType = $ClassMethod(..#DESCRIPTOR, "PrimaryEntityType")
    Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, pDestination)
    Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTOR, "Scope"))
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, tScope, tId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tValues = {}
    Do tValues.%Set("SourceNamespace", pSource, "string")
    Set tFile = ##class(%File).TempFilename("json")
    Set tIO = $IO
    New %response
    Set %response = ##class(%CSP.Response).%New()
    Open tFile:("WNS"):5
    If '$Test Quit $$$ERROR($$$GeneralError, "the capture file could not be opened")
    Try {
        Use tFile
        Set tSC = ..Run(tTool, ..#TOOLCLASS, "copy-mappings", tType, tScope, tId, tTargetRef, tValues, {})
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
