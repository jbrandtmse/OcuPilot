/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass that runs the Namespaces list's
/// <code>copy-mappings</code> and <code>enable-interop</code> in this process through
/// <class>OcuPilot.Test.NamespaceStartedPort</class>, by
/// <class>OcuPilot.Test.SeamNamespaceCopyMappings</class> and
/// <class>OcuPilot.Test.SeamNamespaceEnableInterop</class> under the shipped tools' registry entries,
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

/// <p>The enable tool, and the seam it runs through.</p>
Parameter ENABLETOOL = "osmgmt.namespaces.enableinterop";

Parameter ENABLETOOLCLASS = "OcuPilot.Test.SeamNamespaceEnableInterop";

/// <p>Copy the mappings of <var>pSource</var> into <var>pDestination</var> as the screen route's
/// <code>Run</code> does, answering the envelope written in <var>pAnswer</var> and
/// <code>%response.Status</code> in <var>pStatus</var>.</p>
ClassMethod Copy(pDestination As %String, pSource As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tValues = {}
    Do tValues.%Set("SourceNamespace", pSource, "string")
    Quit ..Act(..#TOOL, ..#TOOLCLASS, "copy-mappings", pDestination, tValues, .pAnswer, .pStatus)
}

/// <p>Enable interoperability on <var>pNamespace</var> as the screen route's <code>Run</code> does,
/// answering as <method>Copy</method> does.</p>
ClassMethod Enable(pNamespace As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Quit ..Act(..#ENABLETOOL, ..#ENABLETOOLCLASS, "enable-interop", pNamespace, {}, .pAnswer, .pStatus)
}

/// <p>Run action <var>pAction</var> of tool <var>pToolName</var> through <var>pToolClass</var> on
/// <var>pId</var> with <var>pValues</var>, capturing the envelope.</p>
ClassMethod Act(pToolName As %String, pToolClass As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status [ Private ]
{
    Set pAnswer = ""
    Set pStatus = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pToolName, .tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tTool)) Quit $$$ERROR($$$GeneralError, "the tool " _ pToolName _ " did not resolve")
    Set tType = $ClassMethod(..#DESCRIPTOR, "PrimaryEntityType")
    Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, pId)
    Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTOR, "Scope"))
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, tScope, tId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tValues = pValues
    Set tFile = ##class(%File).TempFilename("json")
    Set tIO = $IO
    New %response
    Set %response = ##class(%CSP.Response).%New()
    Open tFile:("WNS"):5
    If '$Test Quit $$$ERROR($$$GeneralError, "the capture file could not be opened")
    Try {
        Use tFile
        Set tSC = ..Run(tTool, pToolClass, pAction, tType, tScope, tId, tTargetRef, tValues, {})
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
