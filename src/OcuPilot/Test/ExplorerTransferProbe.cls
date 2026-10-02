/// <p>Story 19.13's probe documents and files: <class>OcuPilot.Test.ExplorerProbe</class>'s classes,
/// routines and globals renamed under <parameter>PACKAGE</parameter>, and the files the export and
/// import tests write, all under <method>Directory</method>, which <method>MakeDirectory</method>
/// creates and <method>RemoveDirectory</method> removes with every file in it.</p>
Class OcuPilot.Test.ExplorerTransferProbe Extends OcuPilot.Test.ExplorerProbe
{

Parameter PACKAGE = "OcuProbe1913";

Parameter OWNPACKAGE = "OcuPilotProbe1913";

Parameter ROUTINEPREFIX = "OcuProbe1913";

Parameter ROUTINES = "OcuProbe1913Mac.mac,OcuProbe1913Inc.inc";

/// <p>The probe directory's own name, directly under the manager directory.</p>
Parameter DIRECTORYNAME = "OcuProbe1913";

/// <p>The allowed root every probe file is named under: the manager directory, the one root of an
/// instance that restricts no file selector.</p>
ClassMethod Root() As %String
{
    Quit $System.Util.ManagerDirectory()
}

/// <p>The probe directory, with its trailing separator.</p>
ClassMethod Directory() As %String
{
    Quit ##class(%File).NormalizeDirectory(..Root() _ ..#DIRECTORYNAME)
}

/// <p>The relative name of probe file <var>pName</var>, under <method>Root</method>.</p>
ClassMethod RelativeName(pName As %String) As %String
{
    Quit ..#DIRECTORYNAME _ "/" _ pName
}

/// <p>Create the probe directory.</p>
ClassMethod MakeDirectory() As %Status
{
    If ##class(%File).DirectoryExists(..Directory()) Quit $$$OK
    If ##class(%File).CreateDirectoryChain(..Directory()) Quit $$$OK
    Quit $$$ERROR($$$GeneralError, "the probe directory could not be created")
}

/// <p>Delete every file in the probe directory and the directory itself; a failing status when it
/// survives.</p>
ClassMethod RemoveDirectory() As %Status
{
    Set tDirectory = ..Directory()
    If '##class(%File).DirectoryExists(tDirectory) Quit $$$OK
    Do ##class(%File).RemoveDirectoryTree(tDirectory)
    If ##class(%File).DirectoryExists(tDirectory) Quit $$$ERROR($$$GeneralError, "the probe directory survives")
    Quit $$$OK
}

/// <p>Write <var>pText</var> to probe file <var>pName</var> as UTF-8.</p>
ClassMethod WriteFile(pName As %String, pText As %String) As %Status
{
    Set tSC = ..MakeDirectory()
    If $$$ISERR(tSC) Quit tSC
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tStream.TranslateTable = "UTF8"
    Set tSC = tStream.LinkToFile(..Directory() _ pName)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = tStream.Write(pText)
    If $$$ISERR(tSC) Quit tSC
    Quit tStream.%Save()
}

/// <p>Probe file <var>pName</var>'s text, read as UTF-8, or <code>""</code>.</p>
ClassMethod ReadFile(pName As %String) As %String
{
    Set tText = ""
    Set tFile = ..Directory() _ pName
    If '##class(%File).Exists(tFile) Quit ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tStream.TranslateTable = "UTF8"
    If $$$ISERR(tStream.LinkToFile(tFile)) Quit ""
    While 'tStream.AtEnd {
        Set tText = tText _ tStream.Read(32000)
    }
    Quit tText
}

/// <p>Whether probe file <var>pName</var> exists.</p>
ClassMethod FileExists(pName As %String) As %Boolean
{
    Quit ##class(%File).Exists(..Directory() _ pName)
}

/// <p>Document <var>pDocument</var>'s source in <var>pNamespace</var>, as the source code API's
/// document read answers it (<code>GET doc</code>), its lines joined by line feeds; <code>""</code>
/// when it cannot be read.</p>
ClassMethod Source(pNamespace As %String, pDocument As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("name") = pDocument
    Set tEndpoint = $Select($ZConvert($Piece(pDocument, ".", $Length(pDocument, ".")), "L") = "cls": "Class", 1: "Routine")
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    If $$$ISERR(tSC) || '$IsObject($Get(tDocument)) || 'tDocument.available Quit ""
    Set tText = ""
    Set tIterator = tDocument.content.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Quit tText
}

}
