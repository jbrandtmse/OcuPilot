/// <p>Subclass of <class>OcuPilot.Port.AtelierPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.AtelierPort</class> runs the port's real gate order, argument checks,
/// filters, capture and status mapping against canned route answers.</p>
/// <p>Unless a test arms <method>UseFakeRoutes</method>, <method>ImplClass</method> answers the
/// vendor's own class and the port reads the live instance. Armed, it answers this class, whose
/// <method>GetNamespace</method>, <method>GetDocNames</method>, <method>GetDoc</method>,
/// <method>Index</method>, <method>Compile</method>, <method>DeleteDocs</method>,
/// <method>ExportToXMLFile</method>, <method>ListDocumentsInXMLFiles</method>,
/// <method>LoadXMLFiles</method>, <method>PutDoc</method>, <method>Search</method>,
/// <method>GetMacroDefinition</method>, <method>GetMacroLocation</method> and <method>Query</method>
/// stand in for the vendor's routes: each
/// records what it was handed --
/// the namespace and device current while it ran and whether output was redirected, its arguments,
/// the request's query data, content type, body and <code>If-None-Match</code> -- leaves
/// <code>%SourceControl</code> set, as
/// a vendor route does, sets the armed HTTP status and writes the armed envelope. <method>GateClass</method>,
/// <method>HighestVersion</method> and <method>DatabaseResources</method> answer what a test arms,
/// <method>LogFault</method> always routes through <class>OcuPilot.Test.FaultProbe</class>, and
/// <method>LogNote</method> through <class>OcuPilot.Test.LogProbe</class>. State lives in <code>^||OcuPilotAtelierFixture</code>.</p>
/// <p>A canned route runs while the port has switched to the read's namespace, so a test that arms
/// one reads the install namespace.</p>
Class OcuPilot.Test.AtelierPortFixture Extends OcuPilot.Port.AtelierPort
{

/// <p>How many characters <method>WriteOversize</method> writes in one string, and how many such
/// strings: together above the capture's ceiling.</p>
Parameter OVERSIZECHUNK As INTEGER = 30000;

/// <p>See <parameter>OVERSIZECHUNK</parameter>.</p>
Parameter OVERSIZECHUNKS As INTEGER = 130;

/// <p>Forget every override, every armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotAtelierFixture
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real
/// gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotAtelierFixture("gate") = pClass
}

/// <p>Answer <method>ImplClass</method> with this class, so the armed routes answer.</p>
ClassMethod UseFakeRoutes()
{
    Set ^||OcuPilotAtelierFixture("fake") = 1
}

/// <p>Answer <method>HighestVersion</method> with <var>pVersion</var>.</p>
ClassMethod SetVersion(pVersion As %Integer)
{
    Set ^||OcuPilotAtelierFixture("version") = pVersion
}

/// <p>Answer <method>DatabaseResources</method> with these resources for every namespace:
/// <var>pMapped</var> is a comma-separated list of mapped databases' resources, and an empty
/// <var>pRoutine</var> reads as unresolved.</p>
ClassMethod SetResources(pRoutine As %String, pGlobal As %String, pMapped As %String = "")
{
    Set ^||OcuPilotAtelierFixture("resources") = $ListBuild(pRoutine, pGlobal, $Select(pMapped = "": "", 1: $ListFromString(pMapped)))
}

/// <p>Arm route <var>pMethod</var> to set <var>pStatus</var> (an HTTP status line) and write
/// <var>pText</var>, and to return <var>pReturn</var>.</p>
ClassMethod Arm(pMethod As %String, pStatus As %String, pText As %String, pReturn As %Status = {$$$OK})
{
    Set ^||OcuPilotAtelierFixture("route", pMethod) = $ListBuild(pStatus, pText, pReturn, 0)
}

/// <p>Queue one answer for route <var>pMethod</var>, <var>pStatus</var> and <var>pText</var>: each call
/// takes the oldest queued answer before the armed one, so a read that calls one route twice is
/// answered twice.</p>
ClassMethod Queue(pMethod As %String, pStatus As %String, pText As %String)
{
    Set tIndex = $Increment(^||OcuPilotAtelierFixture("queue", pMethod))
    Set ^||OcuPilotAtelierFixture("queue", pMethod, tIndex) = $ListBuild(pStatus, pText, $$$OK, 0)
}

/// <p>Arm route <var>pMethod</var> to write an answer above the capture's ceiling, the way the
/// vendor's renderer writes one: in pieces, inside a <code>Try</code> whose error it returns.</p>
ClassMethod ArmOversize(pMethod As %String)
{
    Set ^||OcuPilotAtelierFixture("route", pMethod) = $ListBuild("200 OK", "", $$$OK, 1)
}

/// <p>Arm route <var>pMethod</var> to raise an exception naming <var>pError</var> (an ObjectScript
/// error name such as <code>&lt;PROTECT&gt;</code>) after writing nothing.</p>
ClassMethod ArmThrow(pMethod As %String, pError As %String)
{
    Set ^||OcuPilotAtelierFixture("route", pMethod) = $ListBuild("200 OK", "", $$$OK, 2, pError)
}

/// <p>How many routes were called since the last <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotAtelierFixture("calls"))
}

/// <p>Recorded call <var>pIndex</var> (1-based) as <code>{method, current, device, redirect,
/// namespace, arg, typePassed, params, contentType, body, ifNoneMatch}</code>, or <code>{}</code>.</p>
ClassMethod CallAt(pIndex As %Integer) As %DynamicObject
{
    Set tJson = $Get(^||OcuPilotAtelierFixture("call", pIndex))
    If tJson = "" Quit {}
    Quit ##class(%DynamicObject).%FromJSON(tJson)
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotAtelierFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ImplClass(pVersion As %Integer) As %String
{
    Set ^||OcuPilotAtelierFixture("implVersion") = pVersion
    If $Get(^||OcuPilotAtelierFixture("fake")) Quit ..%ClassName(1)
    Quit ##super(pVersion)
}

/// <p>The version <method>ImplClass</method> was last asked for, or <code>""</code>.</p>
ClassMethod ImplVersion() As %String
{
    Quit $Get(^||OcuPilotAtelierFixture("implVersion"))
}

ClassMethod HighestVersion() As %Integer
{
    If $Data(^||OcuPilotAtelierFixture("version")) Quit ^||OcuPilotAtelierFixture("version")
    Quit ##super()
}

ClassMethod DatabaseResources(pNamespace As %String, Output pRoutineResource As %String, Output pGlobalResource As %String, Output pMapped As %List, Output pResolved As %Boolean)
{
    If $Data(^||OcuPilotAtelierFixture("resources"), tArmed) {
        Set pRoutineResource = $ListGet(tArmed, 1)
        Set pGlobalResource = $ListGet(tArmed, 2)
        Set pMapped = $ListGet(tArmed, 3)
        Set pResolved = (pRoutineResource '= "")
        Quit
    }
    Do ##super(pNamespace, .pRoutineResource, .pGlobalResource, .pMapped, .pResolved)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("atelierport", pMessage, pStatus, pCode)
}

/// <p>The information-severity line routed through <class>OcuPilot.Test.LogProbe</class>, so a test
/// reads its severity and text.</p>
ClassMethod LogNote(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tData = {}
    Do tData.%Set("code", pCode, "string")
    Do tData.%Set("status", $System.Status.GetErrorText(pStatus), "string")
    Do ##class(OcuPilot.Test.LogProbe).Info("atelierport", pMessage, tData)
}

/// <p>The canned <code>GetNamespace</code> route.</p>
ClassMethod GetNamespace(pNamespace) As %Status
{
    Quit ..Answer("GetNamespace", pNamespace, "", 0)
}

/// <p>The canned <code>GetDocNames</code> route; it records whether a type argument was passed.</p>
ClassMethod GetDocNames(pNamespace As %String, pCat, pType) As %Status
{
    Quit ..Answer("GetDocNames", pNamespace, $Get(pCat), $Data(pType))
}

/// <p>The canned <code>GetDoc</code> route.</p>
ClassMethod GetDoc(pNamespace As %String, pDocName As %String) As %Status
{
    Quit ..Answer("GetDoc", pNamespace, pDocName, 0)
}

/// <p>The canned <code>Index</code> route.</p>
ClassMethod Index(pNamespace As %String) As %Status
{
    Quit ..Answer("Index", pNamespace, "", 0)
}

/// <p>The canned <code>Compile</code> route.</p>
ClassMethod Compile(pNamespace As %String) As %Status
{
    Quit ..Answer("Compile", pNamespace, "", 0)
}

/// <p>The canned <code>DeleteDocs</code> route.</p>
ClassMethod DeleteDocs(pNamespace As %String) As %Status
{
    Quit ..Answer("DeleteDocs", pNamespace, "", 0)
}

/// <p>Make every export's file write fail from now on (<method>WriteLines</method>).</p>
ClassMethod FailWrites()
{
    Set ^||OcuPilotAtelierFixture("writefails") = 1
}

/// <p>The port's file write, or, once <method>FailWrites</method> is armed, a write that fails after
/// creating a short file at a name where none stood, and touching none that did.</p>
ClassMethod WriteLines(pFile As %String, pLines As %DynamicArray) As %Status [ Private ]
{
    If '$Get(^||OcuPilotAtelierFixture("writefails")) Quit ##super(pFile, pLines)
    If '##class(%File).Exists(pFile) {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(pFile)
        If $$$ISOK(tSC) Set tSC = tStream.Write("partial")
        If $$$ISOK(tSC) Set tSC = tStream.%Save()
        If $$$ISERR(tSC) Quit tSC
    }
    Quit $$$ERROR($$$GeneralError, "the canned file write fails")
}

/// <p>The canned <code>ExportToXMLFile</code> route.</p>
ClassMethod ExportToXMLFile(pNamespace As %String) As %Status
{
    Quit ..Answer("ExportToXMLFile", pNamespace, "", 0)
}

/// <p>The canned <code>ListDocumentsInXMLFiles</code> route.</p>
ClassMethod ListDocumentsInXMLFiles(pNamespace As %String) As %Status
{
    Quit ..Answer("ListDocumentsInXMLFiles", pNamespace, "", 0)
}

/// <p>The canned <code>LoadXMLFiles</code> route.</p>
ClassMethod LoadXMLFiles(pNamespace As %String) As %Status
{
    Quit ..Answer("LoadXMLFiles", pNamespace, "", 0)
}

/// <p>The canned <code>PutDoc</code> route.</p>
ClassMethod PutDoc(pNamespace As %String, pDocName As %String) As %Status
{
    Quit ..Answer("PutDoc", pNamespace, pDocName, 0)
}

/// <p>The canned <code>Search</code> route.</p>
ClassMethod Search(pNamespace As %String) As %Status
{
    Quit ..Answer("Search", pNamespace, "", 0)
}

/// <p>The canned <code>GetMacroDefinition</code> route.</p>
ClassMethod GetMacroDefinition(pNamespace As %String) As %Status
{
    Quit ..Answer("GetMacroDefinition", pNamespace, "", 0)
}

/// <p>The canned <code>GetMacroLocation</code> route.</p>
ClassMethod GetMacroLocation(pNamespace As %String) As %Status
{
    Quit ..Answer("GetMacroLocation", pNamespace, "", 0)
}

/// <p>The canned <code>Query</code> route.</p>
ClassMethod Query(pNamespace As %String) As %Status
{
    Quit ..Answer("Query", pNamespace, "", 0)
}

/// <p>Record the call, then answer with the oldest answer queued for <var>pMethod</var>, else as
/// armed: <code>200 OK</code> and an empty envelope when nothing is.</p>
ClassMethod Answer(pMethod As %String, pNamespace As %String, pArg As %String, pTypePassed As %Boolean) As %Status [ Private ]
{
    Set tCall = {}
    Do tCall.%Set("method", pMethod)
    Do tCall.%Set("current", $NAMESPACE)
    Do tCall.%Set("device", $IO)
    Do tCall.%Set("redirect", +$ZUtil(82, 12), "number")
    Do tCall.%Set("namespace", pNamespace)
    Do tCall.%Set("arg", pArg)
    Do tCall.%Set("typePassed", ''pTypePassed, "boolean")
    Set tParams = {}
    Set tKey = ""
    For {
        Set tKey = $Order(%request.Data(tKey))
        If tKey = "" Quit
        Do tParams.%Set(tKey, $Get(%request.Data(tKey, 1)))
    }
    Do tCall.%Set("params", tParams)
    Do tCall.%Set("contentType", %request.ContentType)
    Set tBody = ""
    If $IsObject(%request.Content) {
        Do %request.Content.Rewind()
        Set tBody = %request.Content.Read(32000)
        Do %request.Content.Rewind()
    }
    Do tCall.%Set("body", tBody)
    Do tCall.%Set("ifNoneMatch", $Get(%request.CgiEnvs("HTTP_IF_NONE_MATCH")))
    Set tIndex = $Increment(^||OcuPilotAtelierFixture("calls"))
    Set ^||OcuPilotAtelierFixture("call", tIndex) = tCall.%ToJSON()
    ; A vendor route leaves the namespace's source-control object behind, as this does.
    Set %SourceControl = "left by the canned route"

    Set tNext = $Order(^||OcuPilotAtelierFixture("queue", pMethod, ""), 1, tQueued)
    If tNext '= "" {
        Kill ^||OcuPilotAtelierFixture("queue", pMethod, tNext)
        Set tArmed = tQueued
    } Else {
        Set tArmed = $Get(^||OcuPilotAtelierFixture("route", pMethod), $ListBuild("200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{}}", $$$OK, 0))
    }
    Set %response.Status = $ListGet(tArmed, 1)
    Set tMode = $ListGet(tArmed, 4)
    If tMode = 1 Quit ..WriteOversize()
    If tMode = 2 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$ObjectScriptError, $ListGet(tArmed, 5) _ " in the canned route"))
    Do ..Emit($ListGet(tArmed, 2))
    Quit $ListGet(tArmed, 3)
}

/// <p>Write <var>pText</var> to the current device, as a route's renderer does.</p>
ClassMethod Emit(pText As %String) [ Private ]
{
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    Do tStream.Write(pText)
    Do tStream.OutputToDevice()
}

/// <p>Write an envelope above the capture's ceiling, as the vendor's renderer does: its
/// <code>%ToJSON()</code> to the device inside one <code>Try</code>, whose error is returned.</p>
ClassMethod WriteOversize() As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tContent = []
        Set tChunk = $Translate($Justify("", ..#OVERSIZECHUNK), " ", "x")
        For tI = 1:1:..#OVERSIZECHUNKS {
            Do tContent.%Push(tChunk)
        }
        Set tEnvelope = {"status": {"errors": [], "summary": ""}, "console": [], "result": {}}
        Do tEnvelope.result.%Set("content", tContent)
        Do tEnvelope.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
