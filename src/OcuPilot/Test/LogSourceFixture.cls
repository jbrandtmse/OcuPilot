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
/// <p><b>It counts filesystem touches.</b> <method>FileExists</method>,
/// <method>OpenStream</method> and <method>DirectoryEntries</method> each add one to
/// <method>Touches</method>, so "nothing above the gate reaches the filesystem" is read off a
/// counter rather than asserted against nothing.</p>
/// <p><b>A directory listing can be armed.</b> <method>AddEntry</method> queues listing entries,
/// and while any is queued <method>DirectoryEntries</method> answers those instead of reading the
/// directory -- which is how a thousand-file listing, or two files sharing one modification time,
/// is driven without creating them.</p>
/// <p><b>The integrity checks and a check's report can be armed</b> (Story 18.4):
/// <method>ArmIntegrityChecks</method> and <method>ArmIntegrityReport</method>, so a running check, a
/// report carrying errors and a full listing are driven without an instance holding them.</p>
/// <p><b>The live tail's timing and faults can be armed</b> (Story 18.38): <method>SetTail</method> sets
/// the bound, check and beat seconds, <method>ArmTailThrow</method> makes a look at the file throw,
/// <method>Faults</method> counts what <method>LogFault</method> was asked to log, which is how "nothing
/// is logged" is read off a counter, and <method>AbsentLooks</method> counts the looks that found the file
/// absent.</p>
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

/// <p>Answer <method>PairsFor</method> for <var>pSource</var> in namespace <var>pNamespace</var>
/// from <var>pPairs</var>, spelled as <method>SetPairs</method> spells them. Armed per namespace,
/// it wins over <method>SetPairs</method> for that namespace alone.</p>
ClassMethod SetNamespacePairs(pSource As %String, pNamespace As %String, pPairs As %String)
{
    Set ^||OcuPilotLogFixture("nsPairs", pSource, pNamespace) = pPairs
}

/// <p>Answer <method>RecordsClass</method> with <var>pClass</var> --
/// <class>OcuPilot.Test.LogRecordsFixture</class>, whose vendor rows a test arms.</p>
ClassMethod SetRecordsClass(pClass As %String)
{
    Set ^||OcuPilotLogFixture("records") = pClass
}

/// <p>Answer <method>NamespaceResolver</method> with <var>pClass</var> --
/// <class>OcuPilot.Test.NamespaceFixture</class>, whose roster and gate a test arms.</p>
ClassMethod SetNamespaceResolver(pClass As %String)
{
    Set ^||OcuPilotLogFixture("resolver") = pClass
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

/// <p>Queue one entry <method>DirectoryEntries</method> answers: <var>pName</var>, its listing type
/// <var>pType</var> (<code>F</code> for a regular file), <var>pSize</var> in bytes and
/// <var>pModified</var> as UTC <code>$Horolog</code>.</p>
ClassMethod AddEntry(pName As %String, pType As %String, pSize As %Integer, pModified As %String)
{
    Set tAt = $Get(^||OcuPilotLogFixture("entryCount"), 0) + 1
    Set ^||OcuPilotLogFixture("entry", tAt) = $ListBuild(pName, pType, pSize, pModified)
    Set ^||OcuPilotLogFixture("entryCount") = tAt
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
    ; Armed per source key, or per source and namespace through nsPairs for the per-namespace
    ; secondary sources. OcuPilot.Test.ErrorLogFixture arms the error log's namespace-dependent
    ; answer.
    If (pNamespace '= "") && $Data(^||OcuPilotLogFixture("nsPairs", pSource, pNamespace)) {
        Set tDeclared = ^||OcuPilotLogFixture("nsPairs", pSource, pNamespace)
    } ElseIf '$Data(^||OcuPilotLogFixture("pairs", pSource)) {
        Quit ##super(pSource, pNamespace)
    } Else {
        Set tDeclared = ^||OcuPilotLogFixture("pairs", pSource)
    }
    Set tPairs = ""
    For tI = 1:1:$Length(tDeclared, ",") {
        Set tPair = $Piece(tDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

ClassMethod RecordsClass() As %String
{
    Set tForced = $Get(^||OcuPilotLogFixture("records"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod NamespaceResolver() As %String
{
    Set tForced = $Get(^||OcuPilotLogFixture("resolver"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
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

ClassMethod DirectoryEntries(pDirectory As %String, pCurrent As %String, Output pEntries) As %Status
{
    Set ^||OcuPilotLogFixture("touches") = $Get(^||OcuPilotLogFixture("touches"), 0) + 1
    Set tCount = $Get(^||OcuPilotLogFixture("entryCount"), 0)
    If tCount = 0 Quit ##super(pDirectory, pCurrent, .pEntries)
    Kill pEntries
    For tAt = 1:1:tCount {
        Set pEntries(tAt) = ^||OcuPilotLogFixture("entry", tAt)
    }
    Quit $$$OK
}

/// <p>Answer <method>IntegrityChecks</method> with the JSON array <var>pChecksJson</var>, each
/// <code>{ID, StartTime, RunningState, HasEnded}</code> in the order given (Story 18.4).</p>
ClassMethod ArmIntegrityChecks(pChecksJson As %String)
{
    Set ^||OcuPilotLogFixture("integrity") = pChecksJson
}

/// <p>Answer <method>IntegrityReport</method> for check <var>pId</var> with the lines of
/// <var>pLines</var>, a <class>%List</class> (Story 18.4).</p>
ClassMethod ArmIntegrityReport(pId As %String, pLines As %List)
{
    Set ^||OcuPilotLogFixture("integrityReport", pId) = pLines
}

ClassMethod IntegrityChecks(Output pRows As %DynamicArray) As %Status
{
    If '$Data(^||OcuPilotLogFixture("integrity")) Quit ##super(.pRows)
    Set pRows = ##class(%DynamicArray).%FromJSON(^||OcuPilotLogFixture("integrity"))
    Quit $$$OK
}

ClassMethod IntegrityReport(pId As %String, Output pStream As %Stream.TmpCharacter) As %Status
{
    If '$Data(^||OcuPilotLogFixture("integrityReport", pId)) Quit ##super(pId, .pStream)
    Set pStream = ##class(%Stream.TmpCharacter).%New()
    Set tLines = ^||OcuPilotLogFixture("integrityReport", pId)
    For tI = 1:1:$ListLength(tLines) {
        Do pStream.Write($ListGet(tLines, tI) _ $Char(10))
    }
    Quit $$$OK
}

/// <p>Arm the live tail's timing: the longest a tail is held, the pause between two looks at the file and
/// the pause between two heartbeats, all in seconds. A value left <code>""</code> keeps the port's own.</p>
ClassMethod SetTail(pBound As %Numeric, pCheck As %Numeric, pBeat As %Numeric)
{
    Set ^||OcuPilotLogFixture("tailBound") = pBound
    Set ^||OcuPilotLogFixture("tailCheck") = pCheck
    Set ^||OcuPilotLogFixture("tailBeat") = pBeat
}

/// <p>Make <method>TailState</method> throw an exception named <var>pName</var> once it has looked at the
/// file <var>pAfterLooks</var> times, and on every look after: <code>0</code> throws on the first look,
/// <code>1</code> on the second.</p>
ClassMethod ArmTailThrow(pName As %String, pAfterLooks As %Integer = 0)
{
    Set ^||OcuPilotLogFixture("tailThrow") = pName
    Set ^||OcuPilotLogFixture("tailThrowAfter") = pAfterLooks
}

/// <p>How many times <method>LogFault</method> has been asked to log since <method>Clear</method>.</p>
ClassMethod Faults() As %Integer
{
    Quit +$Get(^||OcuPilotLogFixture("faults"), 0)
}

/// <p>How many looks at the file <method>TailState</method> has answered absent since <method>Clear</method>.</p>
ClassMethod AbsentLooks() As %Integer
{
    Quit +$Get(^||OcuPilotLogFixture("tailAbsent"), 0)
}

ClassMethod TailBoundSeconds() As %Integer
{
    Set tForced = $Get(^||OcuPilotLogFixture("tailBound"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod TailCheckSeconds() As %Numeric
{
    Set tForced = $Get(^||OcuPilotLogFixture("tailCheck"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod TailBeatSeconds() As %Numeric
{
    Set tForced = $Get(^||OcuPilotLogFixture("tailBeat"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod TailState(pPath As %String, Output pSize As %Integer, Output pIdentity As %String) As %Boolean
{
    Set tLooks = $Get(^||OcuPilotLogFixture("tailLooks"), 0)
    Set ^||OcuPilotLogFixture("tailLooks") = tLooks + 1
    Set tThrow = $Get(^||OcuPilotLogFixture("tailThrow"), "")
    If (tThrow '= "") && (tLooks >= $Get(^||OcuPilotLogFixture("tailThrowAfter"), 0)) {
        Throw ##class(%Exception.SystemException).%New(tThrow, 0, "TailState", "armed by OcuPilot.Test.LogSourceFixture")
    }
    Set tPresent = ##super(pPath, .pSize, .pIdentity)
    If 'tPresent Set ^||OcuPilotLogFixture("tailAbsent") = $Get(^||OcuPilotLogFixture("tailAbsent"), 0) + 1
    Quit tPresent
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotLogFixture("faults") = $Get(^||OcuPilotLogFixture("faults"), 0) + 1
    ; A fault armed on purpose is counted and not written to the instance's console log.
    If '$Data(^||OcuPilotLogFixture("tailThrow")) Do ##super(pMessage, pStatus, pCode)
}

}
