/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass with three replaced seams:
/// <method>PortClass</method> answers the port a test names in
/// <code>^||OcuPilotNamespaceWritePort</code>, and <class>OcuPilot.Test.MappingAcceptPort</class>,
/// which writes nothing, when none is named; and <method>ToolFor</method> runs the global mapping
/// delete and the copy of mappings through their seam subclasses
/// (<class>OcuPilot.Test.SeamGlobalMappingDelete</class>,
/// <class>OcuPilot.Test.SeamNamespaceCopyMappings</class>), which declare the default port, so their
/// fresh read and write go to that seam; and <method>ProhibitedClassName</method> answers the set a
/// test names in <code>^||OcuPilotMappingProhibitedClass</code>, the shipped one otherwise. The
/// resolved registry entry, the pairs and the prohibited set's own read of the live target are the
/// shipped route's.</p>
/// <p><method>Act</method> runs <method>OcuPilot.Api.ScreenAction.Handle</method> in this process
/// against request and response stubs and captures the envelope it writes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingActionFixture Extends OcuPilot.Api.ScreenAction
{

/// <p>The shipped tools this fixture runs through a seam subclass, and the subclasses, in step.</p>
Parameter SEAMED = "OcuPilot.Screen.Tool.GlobalMappingDelete,OcuPilot.Screen.Tool.NamespaceCopyMappings";

Parameter SEAMS = "OcuPilot.Test.SeamGlobalMappingDelete,OcuPilot.Test.SeamNamespaceCopyMappings";

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotNamespaceWritePort, "OcuPilot.Test.MappingAcceptPort")
}

/// <p>The prohibited set a test names in <code>^||OcuPilotMappingProhibitedClass</code>, or the
/// shipped one.</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit $Get(^||OcuPilotMappingProhibitedClass, ##super())
}

/// <p>The shipped resolution, with a <parameter>SEAMED</parameter> tool's class replaced by its
/// seam.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    Set tAt = $ListFind($ListFromString(..#SEAMED), $Get(pToolClass))
    If tAt Set pToolClass = $List($ListFromString(..#SEAMS), tAt)
    Quit tSC
}

/// <p>Send the screen action <var>pBody</var> to screen <var>pScreen</var>'s route in this process,
/// answering the unparsed envelope in <var>pAnswer</var> and the status
/// <code>%response.Status</code> was left at in <var>pStatus</var>.</p>
ClassMethod Act(pScreen As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pStatus = 0
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
        Set %OcuPilotMappingActionCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)
        Set tSC = ..Handle(pScreen)
        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0
        Set pAnswer = $Get(%OcuPilotMappingActionCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotMappingActionCap
    Quit tSC
}

/// <p>The mnemonic I/O space <method>Act</method> binds; it must live in this class's own routine
/// for <code>$ZNAME</code> to resolve these labels.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotMappingActionCap = $Get(%OcuPilotMappingActionCap, "") _ s Quit
wchr(a) Set %OcuPilotMappingActionCap = $Get(%OcuPilotMappingActionCap, "") _ $Char(a) Quit
wnl Set %OcuPilotMappingActionCap = $Get(%OcuPilotMappingActionCap, "") _ $Char(10) Quit
wff Set %OcuPilotMappingActionCap = $Get(%OcuPilotMappingActionCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotMappingActionCap = $Get(%OcuPilotMappingActionCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}
