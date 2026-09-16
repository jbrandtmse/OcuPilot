/// <p>Subclass of <class>OcuPilot.Port.LogSourcePort</class> overriding only its seams, so
/// <class>OcuPilot.Test.LogSource</class> runs the port's real validation, gate order, identity
/// and windowing against a scratch file the suite owns. The instance's own
/// <file>messages.log</file> is never written, rotated or removed by anything here.</p>
/// <p>Every seam falls back to <code>##super()</code> when nothing is armed, so an unconfigured
/// call behaves like production.</p>
/// <p><b>The manager directory is armed as a queue, not a value.</b>
/// <method>QueueManagerDirectory</method> appends; each call to <method>ManagerDirectory</method>
/// consumes the next one and the last queued answers every later call. That is what makes
/// "resolved on every call, never cached" observable: two different directories holding two
/// different files, and a port that cached the first would serve the first file twice.</p>
/// <p><b>It counts filesystem touches.</b> <method>FileExists</method> and
/// <method>OpenStream</method> each add one to <method>Touches</method>, so "nothing above the
/// gate reaches the filesystem" is read off a counter rather than asserted against nothing.</p>
/// <p>State lives in <code>^||OcuPilotLogFixture</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.LogSourceFixture Extends OcuPilot.Port.LogSourcePort
{

/// <p>Append <var>pDir</var> to the directory queue <method>ManagerDirectory</method> answers
/// from.</p>
ClassMethod QueueManagerDirectory(pDir As %String)
{
    Set tAt = $Get(^||OcuPilotLogFixture("dirCount"), 0) + 1
    Set ^||OcuPilotLogFixture("dir", tAt) = pDir
    Set ^||OcuPilotLogFixture("dirCount") = tAt
}

/// <p>Answer <method>Sources</method> with the comma-separated <var>pKeys</var>.</p>
ClassMethod SetSources(pKeys As %String)
{
    Set ^||OcuPilotLogFixture("sources") = pKeys
}

/// <p>Answer <method>PairsFor</method> for <var>pSource</var> from the comma-separated
/// <var>pPairs</var>, each spelled <code>resource:permission</code>. An empty <var>pPairs</var>
/// arms an <b>empty pair set</b>, which is a different thing from arming nothing.</p>
ClassMethod SetPairs(pSource As %String, pPairs As %String)
{
    Set ^||OcuPilotLogFixture("pairs", pSource) = pPairs
}

/// <p>Answer <method>FileFor</method> for <var>pSource</var> with the file name
/// <var>pFile</var>.</p>
ClassMethod SetFile(pSource As %String, pFile As %String)
{
    Set ^||OcuPilotLogFixture("file", pSource) = pFile
}

/// <p>Answer <method>MaxBytesCap</method> with <var>pCap</var>.</p>
ClassMethod SetMaxBytesCap(pCap As %Integer)
{
    Set ^||OcuPilotLogFixture("cap") = pCap
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var> --
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotLogFixture("gate") = pClass
}

/// <p>How many times the port has reached the filesystem since <method>Clear</method>: the
/// presence check and the open each count one.</p>
ClassMethod Touches() As %Integer
{
    Quit +$Get(^||OcuPilotLogFixture("touches"), 0)
}

/// <p>Reset the touch count, leaving every override armed, so one test can count the touches of
/// a second call without re-arming the first call's setup.</p>
ClassMethod ClearTouches()
{
    Kill ^||OcuPilotLogFixture("touches")
}

/// <p>Forget every override and every count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLogFixture
}

ClassMethod Sources() As %List
{
    Set tForced = $Get(^||OcuPilotLogFixture("sources"), "")
    If tForced '= "" Quit $ListFromString(tForced)
    Quit ##super()
}

ClassMethod PairsFor(pSource As %String, pNamespace As %String = "") As %List
{
    ; Armed per source key, not per namespace: this fixture drives the file sources, whose
    ; requirement does not depend on one. OcuPilot.Test.ErrorLogFixture is the one that arms a
    ; namespace-dependent answer.
    If '$Data(^||OcuPilotLogFixture("pairs", pSource)) Quit ##super(pSource, pNamespace)
    Set tPairs = ""
    Set tDeclared = ^||OcuPilotLogFixture("pairs", pSource)
    For tI = 1:1:$Length(tDeclared, ",") {
        Set tPair = $Piece(tDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

ClassMethod FileFor(pSource As %String) As %String
{
    ; $Data, not $Get: an armed empty file name is a key the port has no file for, which is a
    ; different thing from arming nothing. PairsFor reads its arming the same way.
    If '$Data(^||OcuPilotLogFixture("file", pSource)) Quit ##super(pSource)
    Quit ^||OcuPilotLogFixture("file", pSource)
}

ClassMethod ManagerDirectory() As %String
{
    Set tCount = $Get(^||OcuPilotLogFixture("dirCount"), 0)
    If tCount = 0 Quit ##super()
    Set tAt = $Get(^||OcuPilotLogFixture("dirAt"), 0) + 1
    If tAt > tCount Set tAt = tCount
    Set ^||OcuPilotLogFixture("dirAt") = tAt
    Quit ^||OcuPilotLogFixture("dir", tAt)
}

ClassMethod MaxBytesCap() As %Integer
{
    Set tForced = $Get(^||OcuPilotLogFixture("cap"), "")
    If tForced '= "" Quit +tForced
    Quit ##super()
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotLogFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod FileExists(pPath As %String) As %Boolean
{
    Set ^||OcuPilotLogFixture("touches") = $Get(^||OcuPilotLogFixture("touches"), 0) + 1
    Quit ##super(pPath)
}

ClassMethod OpenStream(pPath As %String, Output pStream As %Stream.Object) As %Status
{
    Set ^||OcuPilotLogFixture("touches") = $Get(^||OcuPilotLogFixture("touches"), 0) + 1
    Quit ##super(pPath, .pStream)
}

}
