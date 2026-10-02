/// <p>Story 19.3's probe documents: <class>OcuPilot.Test.ExplorerProbe</class>'s classes, routines
/// and globals renamed under <parameter>PACKAGE</parameter>, the document text and version the editor
/// reads, a second writer's change, and a document lock held by another process
/// (<method>HoldLock</method>), released by <method>ReleaseLock</method>.</p>
Class OcuPilot.Test.ExplorerSaveProbe Extends OcuPilot.Test.ExplorerProbe
{

Parameter PACKAGE = "OcuProbe193";

Parameter OWNPACKAGE = "OcuPilotProbe193";

Parameter ROUTINEPREFIX = "OcuProbe193";

Parameter ROUTINES = "OcuProbe193Mac.mac,OcuProbe193Inc.inc,OcuProbe193Int.int";

/// <p>The global the lock job and the test signal through, in the probe namespace; its name begins
/// with <parameter>PACKAGE</parameter>, so <method>Remove</method> kills it.</p>
Parameter LOCKGLOBAL = "OcuProbe193Lock";

/// <p>How long the lock job holds the lock at most, in seconds, whatever the test does.</p>
Parameter LOCKSECONDS As INTEGER = 60;

/// <p>Document <var>pDocument</var> as the class or routine viewer's read answers it in
/// <var>pNamespace</var>: <code>{name, form, available, content, modified, ...}</code>, or
/// <code>""</code>.</p>
ClassMethod Document(pNamespace As %String, pDocument As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("name") = pDocument
    Set tEndpoint = $Select($ZConvert($Piece(pDocument, ".", $Length(pDocument, ".")), "L") = "cls": "Class", 1: "Routine")
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    If $$$ISERR(tSC) || '$IsObject($Get(tDocument)) Quit ""
    Quit tDocument
}

/// <p>The version the editor reads for <var>pDocument</var>: the document read's
/// <code>modified</code>, or <code>""</code>.</p>
ClassMethod Version(pNamespace As %String, pDocument As %String) As %String
{
    Set tDocument = ..Document(pNamespace, pDocument)
    If '$IsObject(tDocument) Quit ""
    Quit tDocument.modified
}

/// <p>Document <var>pDocument</var>'s text in <var>pNamespace</var> as the viewer reads it, its lines
/// joined by line feeds; <code>""</code> when it cannot be read.</p>
ClassMethod Source(pNamespace As %String, pDocument As %String) As %String
{
    Set tDocument = ..Document(pNamespace, pDocument)
    If '$IsObject(tDocument) || 'tDocument.available Quit ""
    Set tText = ""
    Set tIterator = tDocument.content.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Quit tText
}

/// <p>The text of probe class <var>pName</var> (without <code>.cls</code>) whose one method answers
/// <var>pAnswer</var>, its lines ended by line feeds.</p>
ClassMethod ClassText(pName As %String, pAnswer As %String = "1") As %String
{
    Set tText = "Class " _ pName _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ $Char(10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(10) _ "{" _ $Char(10)
    Set tText = tText _ "    Quit " _ pAnswer _ $Char(10) _ "}" _ $Char(10) _ $Char(10) _ "}" _ $Char(10)
    Quit tText
}

/// <p>Change class <var>pName</var> (without <code>.cls</code>) in <var>pNamespace</var> as another
/// writer would, to the text whose method answers <var>pAnswer</var>.</p>
ClassMethod Rewrite(pNamespace As %String, pName As %String, pAnswer As %String) As %Status
{
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, ..ClassText(pName, pAnswer), $Char(10))
}

/// <p>Hold the edit lock on document <var>pDocument</var> in <var>pNamespace</var> from another
/// process, as an open editor does, until <method>ReleaseLock</method> or
/// <parameter>LOCKSECONDS</parameter>; 1 once the lock is held.</p>
ClassMethod HoldLock(pNamespace As %String, pDocument As %String) As %Boolean
{
    Set tGlobal = "^[""" _ pNamespace _ """]" _ ..#LOCKGLOBAL
    Kill @tGlobal
    Job ##class(OcuPilot.Test.ExplorerSaveProbe).LockJob(pNamespace, pDocument, ..#LOCKSECONDS)::5
    If '$Test Quit 0
    For tI = 1:1:100 {
        If $Data(@tGlobal@("held")) Quit
        Hang 0.1
    }
    Quit +$Get(@tGlobal@("held"))
}

/// <p>The lock job: take the edit lock on <var>pDocument</var> in <var>pNamespace</var>, say whether it
/// is held, and give it up once released or after <var>pSeconds</var>. It calls no OcuPilot class
/// once switched.</p>
ClassMethod LockJob(pNamespace As %String, pDocument As %String, pSeconds As %Integer)
{
    Set $NAMESPACE = pNamespace
    Set tSC = ##class(%RoutineMgr).LockItem(pDocument)
    Set ^OcuProbe193Lock("held") = $Select($System.Status.IsOK(tSC): 1, 1: 0)
    For tI = 1:1:(pSeconds * 10) {
        If $Get(^OcuProbe193Lock("release")) Quit
        Hang 0.1
    }
    If $System.Status.IsOK(tSC) Do ##class(%RoutineMgr).LockItem(pDocument, 0)
    Set ^OcuProbe193Lock("done") = 1
}

/// <p>Release the lock <method>HoldLock</method> took in <var>pNamespace</var>; 1 once the job has
/// given it up, or when no job holds it.</p>
ClassMethod ReleaseLock(pNamespace As %String) As %Boolean
{
    Set tGlobal = "^[""" _ pNamespace _ """]" _ ..#LOCKGLOBAL
    If '$Data(@tGlobal@("held")) Quit 1
    Set @tGlobal@("release") = 1
    For tI = 1:1:100 {
        If $Get(@tGlobal@("done")) Quit
        Hang 0.1
    }
    Set tDone = +$Get(@tGlobal@("done"))
    If tDone Kill @tGlobal
    Quit tDone
}

}
