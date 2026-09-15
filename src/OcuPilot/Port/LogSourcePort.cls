/// <p>The port to the log sources the administration API does not back (AD-21, AD-29). It serves
/// bounded byte pages of whole lines from a file in the instance's manager directory.</p>
/// <p><method>Page</method> is the one entry point. A caller names a <b>source key</b> from
/// <method>Sources</method>'s fixed enum and never a path, a file name or any part of one: the
/// directory comes from <code>$System.Util.ManagerDirectory()</code> on every call and the file
/// name from the key (AD-21). The step order is load-bearing -- enum, gate, <var>maxBytes</var>,
/// the offset/identity pair, resolve, open, identity, window, read -- and nothing above the gate
/// reaches the filesystem (AD-29: this port inherits no vendor gate, so it declares its own
/// <code>(resource, permission)</code> set and evaluates it first).</p>
/// <p><b>The file moves under a paging reader.</b> The instance rotates the console log at its
/// configured maximum size by renaming it away and creating a new one, so a byte offset held
/// across a rotation points into a file that no longer exists. Each page therefore carries an
/// <b>identity</b> token derived from the file's first bytes, and a call whose held identity no
/// longer matches -- or whose held offset is past the current end -- is answered from byte 1 with
/// <code>restarted</code> true. A restart is an outcome, never a fault.</p>
/// <p>Every refusal is a wire-safe fault <class>OcuPilot.Kernel.Fault</class> built, with a code
/// from <class>OcuPilot.Api.Error</class> (AD-12, AD-39); raw status text goes to
/// <method>LogFault</method> alone. Nothing here writes to the response device, switches
/// namespace, escalates or spawns.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.LogSourceFixture</class>):
/// <method>Sources</method>, <method>PairsFor</method>, <method>FileFor</method>,
/// <method>ManagerDirectory</method>, <method>MaxBytesCap</method>, <method>GateClass</method>,
/// <method>FileExists</method> and <method>OpenStream</method>. Production overrides none of
/// them.</p>
Class OcuPilot.Port.LogSourcePort Extends %RegisteredObject
{

/// <p>The fixed enum of source keys this port serves (AD-21), comma-separated. A caller names a
/// key from this list and nothing else; a route binds the key, so no caller names a file.</p>
Parameter SOURCES = "messages";

/// <p>The <parameter>SOURCES</parameter> key for the instance's console log.</p>
Parameter MESSAGESKEY = "messages";

/// <p>The console log's file name, resolved against <method>ManagerDirectory</method> on every
/// call.</p>
Parameter MESSAGESFILE = "messages.log";

/// <p>The console log's <code>(resource, permission)</code> pair set, comma-separated as
/// <code>resource:permission</code> (AD-8).</p>
/// <p><b>One pair, and <code>%DB_IRISSYS:READ</code> is deliberately not among them.</b> Every
/// admin-port read declares it because that port runs every endpoint in <code>%SYS</code>;
/// reading a file off disk consults no database resource and this path never enters
/// <code>%SYS</code>. The classic portal requires the same one resource, on the web application
/// that serves its console-log page (<code>/csp/sys/op</code> carries
/// <code>%Admin_Operate</code>) and explicitly on a sibling page in that application
/// (<file>irislib/%CSP/UI/Portal/ViewLog.cls</file>'s <code>RESOURCE</code>), so a user reaches a
/// line through OcuPilot only if they could have read it directly (AD-29).</p>
Parameter MESSAGESPAIRS = "%Admin_Operate:USE";

/// <p>The window size, in bytes, a caller that names none is served.</p>
Parameter DEFAULTMAXBYTES As INTEGER = 65536;

/// <p>The hard server-side ceiling on a window, in bytes (AD-36). No parameter raises it and
/// none disables it; a <code>maxBytes</code> above it is refused, never clamped.</p>
Parameter MAXBYTESCAP As INTEGER = 1048576;

/// <p>How many of the file's first bytes <method>Identity</method> hashes. A whole-file hash
/// would change on every append and make every continuation a restart; the first bytes change
/// only when the file does.</p>
Parameter PREFIXBYTES As INTEGER = 512;

/// <p>The largest single <code>Read</code> this port issues. A single
/// <code>%Stream.FileBinary</code> read returns at most about 32 KB whatever it is asked for, so
/// every window is assembled from chunks of this size.</p>
Parameter CHUNKSIZE As INTEGER = 32000;

/// <p>The gate this port evaluates its pair set through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The subsystem name a raw status is logged under.</p>
Parameter LOGSUBSYSTEM = "logsourceport";

/// <p>The source keys this port serves. Overridable so a fixture can drive an unknown key and a
/// second source without waiting for one to ship; production never overrides it.</p>
ClassMethod Sources() As %List
{
    Quit $ListFromString(..#SOURCES)
}

/// <p>The <code>(resource, permission)</code> pair set source <var>pSource</var> requires, as a
/// <code>%List</code> of two-element <code>%List</code>s, or <code>""</code> for a key with no
/// declared requirement.</p>
/// <p><b>A function of the source, not a class constant</b>, because Story 2.12's source gates
/// per namespace. An empty answer is refused by <method>Page</method> rather than passed to the
/// gate, which holds the empty set to be satisfied by everyone.</p>
/// <p>Overridable for a fixture; production never overrides it.</p>
ClassMethod PairsFor(pSource As %String) As %List
{
    Set tPairs = ""
    Set tDeclared = ""
    If pSource = ..#MESSAGESKEY Set tDeclared = ..#MESSAGESPAIRS
    For tI = 1:1:$Length(tDeclared, ",") {
        Set tPair = $Piece(tDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

/// <p>The file name source <var>pSource</var> reads, or <code>""</code> for a key this port has
/// no file for. A name only -- the directory is <method>ManagerDirectory</method>'s.</p>
/// <p>Overridable for a fixture; production never overrides it.</p>
ClassMethod FileFor(pSource As %String) As %String
{
    If pSource = ..#MESSAGESKEY Quit ..#MESSAGESFILE
    Quit ""
}

/// <p>The instance's manager directory, resolved on <b>every</b> call and never cached (AD-21:
/// the console log's location is operator-settable, so a cached directory is a path that can go
/// stale under a running request).</p>
/// <p>Overridable so a fixture can point the port at a directory it owns; production never
/// overrides it.</p>
ClassMethod ManagerDirectory() As %String
{
    Quit $System.Util.ManagerDirectory()
}

/// <p>The hard byte ceiling on a window. Overridable so a fixture can drive the cap refusal
/// without asking for a megabyte; production never overrides it.</p>
ClassMethod MaxBytesCap() As %Integer
{
    Quit ..#MAXBYTESCAP
}

/// <p>The class <method>Gate</method> evaluates the pair set through. Overridable so a fixture
/// can drive a denial in process -- <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real <code>$System.Security.Check</code> answers yes to every
/// resource. The real check is exercised over the wire by
/// <class>OcuPilot.Test.LogSourceDenial</class>. Production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Whether <var>pPath</var> is present. <b>The port's first filesystem touch</b>, and one of
/// only two; a fixture overrides it to count them, which is what makes "nothing above the gate
/// reaches the filesystem" an observation rather than an assertion against nothing.</p>
ClassMethod FileExists(pPath As %String) As %Boolean
{
    Quit ''##class(%File).Exists(pPath)
}

/// <p>Open <var>pPath</var> for reading. The port's other filesystem touch.</p>
ClassMethod OpenStream(pPath As %String, Output pStream As %Stream.Object) As %Status
{
    Set tSC = $$$OK
    Set pStream = ""
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(pPath)
        If $$$ISERR(tSC) Quit
        Set pStream = tStream
    } Catch ex {
        Set pStream = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Send a raw status to the log, and nowhere else (AD-39).</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>Serve one bounded page of whole lines from log source <var>pSource</var>.</p>
/// <p><var>pOffset</var> and <var>pIdentity</var> are a page's returned cursor, supplied together
/// or not at all; with neither, the page is the <b>last</b> <var>pMaxBytes</var> of the file.
/// <var>pMaxBytes</var> defaults to <parameter>DEFAULTMAXBYTES</parameter> and is refused above
/// <method>MaxBytesCap</method>.</p>
/// <p>On success <var>pResult</var> carries <code>source</code>, <code>lines</code>,
/// <code>offset</code> (the byte the next call passes back, 1-based), <code>identity</code>,
/// <code>size</code>, <code>restarted</code> and <code>truncated</code> (true when the page did
/// not reach the end of the file), and <var>pHttpStatus</var> is 200. Otherwise an error
/// <class>%Status</class> is returned with <var>pResult</var> empty, <var>pHttpStatus</var> the
/// numeric status to answer with and <var>pFault</var> the wire fault
/// <code>{error, reason, code}</code>, plus <code>detail</code> when there is one.</p>
/// <p>Caller contract: <var>pOffset</var>, <var>pMaxBytes</var> and <var>pIdentity</var> arrive
/// as caller text and are validated here, so a handler passes a query parameter through
/// unchanged. Must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Page(pSource As %String, pOffset As %String = "", pMaxBytes As %String = "", pIdentity As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '$ListFind(..Sources(), pSource) {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve a log source by that name", .pHttpStatus, .pFault)
            Quit
        }

        Set tPairs = ..PairsFor(pSource)
        If '$ListValid(tPairs) || ($ListLength(tPairs) = 0) {
            ; An empty pair set is held by everyone (OcuPilot.Screen.Gate.EvaluatePairs), so a
            ; source whose requirement is empty or unreadable is refused here rather than handed
            ; to the gate, which would admit it. No pair is named: there is none to report.
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "This account may not read that log source", .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        If '..Gate(tPairs, .tFailedPair) {
            Set tDetail = ""
            If tFailedPair '= "" {
                Set tDetail = {}
                Do tDetail.%Set("failedPair", tFailedPair)
            }
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "This account may not read that log source", .pHttpStatus, .pFault, tDetail)
            Quit
        }

        Set tMaxBytes = ..#DEFAULTMAXBYTES
        If pMaxBytes '= "" {
            If ('$Match(pMaxBytes, "^[0-9]+$")) || (+pMaxBytes = 0) || (+pMaxBytes > ..MaxBytesCap()) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGMAXBYTES, "maxBytes must be a whole number of bytes above zero and no larger than the cap this endpoint serves", .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxBytes = +pMaxBytes
        }

        Set tHasCursor = (pOffset '= "")
        If tHasCursor '= (pIdentity '= "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGOFFSET, "offset and identity are a page's cursor and travel together; supply both or neither", .pHttpStatus, .pFault)
            Quit
        }
        If tHasCursor && (('$Match(pOffset, "^[0-9]+$")) || (+pOffset < 1)) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#LOGOFFSET, "offset must be a whole number of bytes from one upwards", .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Resolve(pSource, .tPath, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tOpenSC = ..OpenStream(tPath, .tStream)
        If $$$ISERR(tOpenSC) || '$IsObject(tStream) {
            Set tSC = ..Unreadable(tOpenSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tIdentitySC = ..Identity(tStream, .tSize, .tIdentity)
        If $$$ISERR(tIdentitySC) {
            Set tSC = ..Unreadable(tIdentitySC, .pHttpStatus, .pFault)
            Quit
        }

        ; Two independent restart conditions, either of which alone restarts: the file is not the
        ; one the cursor was taken from, and the cursor is past the end of the file it names.
        Set tRestarted = 0
        If 'tHasCursor {
            Set tStart = tSize - tMaxBytes + 1
            If tStart < 1 Set tStart = 1
        } Else {
            Set tStart = +pOffset
            If (pIdentity '= tIdentity) || (tStart > (tSize + 1)) {
                Set tRestarted = 1
                Set tStart = 1
            }
        }

        Set tWindowSC = ..ReadWindow(tStream, tStart, tMaxBytes, tSize, .tLines, .tNextOffset, .tTruncated)
        If $$$ISERR(tWindowSC) {
            Set tSC = ..Unreadable(tWindowSC, .pHttpStatus, .pFault)
            Quit
        }

        Set pResult = {}
        Do pResult.%Set("source", pSource)
        Do pResult.%Set("lines", tLines)
        Do pResult.%Set("offset", tNextOffset, "number")
        Do pResult.%Set("identity", tIdentity)
        Do pResult.%Set("size", tSize, "number")
        Do pResult.%Set("restarted", ''tRestarted, "boolean")
        Do pResult.%Set("truncated", ''tTruncated, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pSource _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <var>pPairs</var>, asked of
/// <method>GateClass</method>'s evaluator so the check and the spelling of a failure are the
/// gate's and not a second copy (the <class>OcuPilot.Api.Namespaces</class> idiom).</p>
ClassMethod Gate(pPairs As %List, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Quit $ClassMethod(..GateClass(), "EvaluatePairs", pPairs, .pFailedPair)
}

/// <p>The path source <var>pSource</var> reads, resolved from <method>ManagerDirectory</method>
/// and <method>FileFor</method> on this call and checked for presence.</p>
/// <p>Refuses <code>LOG.SOURCE</code> for a key with no file and <code>LOG.ABSENT</code> when the
/// resolved file is not there; neither refusal echoes the path (AD-21, AD-47).</p>
ClassMethod Resolve(pSource As %String, Output pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pPath = ""
    Set tFile = ..FileFor(pSource)
    If tFile = "" {
        Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGSOURCE, "OcuPilot does not serve a log source by that name", .pHttpStatus, .pFault)
    } Else {
        Set pPath = ##class(%File).NormalizeFilename(tFile, ..ManagerDirectory())
        If '..FileExists(pPath) {
            Set pPath = ""
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#LOGABSENT, "That log file is not present on this instance", .pHttpStatus, .pFault)
        }
    }
    Quit tSC
}

/// <p>The file's size and its identity token: the URL-safe Base64 of the SHA-256 of the file's
/// <b>first line</b>, read from within its first <parameter>PREFIXBYTES</parameter> bytes, or of
/// the empty string when it has none.</p>
/// <p><b>The first line, not the first N bytes.</b> A console log under
/// <parameter>PREFIXBYTES</parameter> -- which is exactly what one is in the seconds after a
/// rotation -- would hash a different prefix on every append, so every held cursor would restart
/// while the file was still small. The first line is fixed the moment it is written, and on this
/// build it carries the previous generation's last-write time to the millisecond, so it
/// distinguishes generations. A first line longer than the prefix is fingerprinted by its opening
/// <parameter>PREFIXBYTES</parameter> bytes, which are equally fixed.</p>
/// <p><b>URL-safe alphabet.</b> The token is handed back to the caller as a query parameter, and
/// standard Base64's <code>+</code> decodes to a space in a query string -- so a caller that
/// echoed the token verbatim would be answered <code>restarted</code> for a file that had not
/// moved. <code>-</code> and <code>_</code> survive the transport the cursor travels on, and the
/// padding <code>=</code> is left in place so the token's length is unchanged.</p>
/// <p>An error <class>%Status</class> means the file could not be read at all, which is what
/// <method>Page</method> turns into <code>LOG.UNREADABLE</code> -- an open succeeds on a path
/// that is a directory, so the first read is where that is found out.</p>
ClassMethod Identity(pStream As %Stream.Object, Output pSize As %Integer, Output pIdentity As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pSize = 0
    Set pIdentity = ""
    Try {
        Set pSize = +pStream.Size
        If pSize < 0 Set pSize = 0
        Set tPrefix = ""
        If pSize > 0 {
            Set tWant = ..#PREFIXBYTES
            If tWant > pSize Set tWant = pSize
            Do pStream.MoveTo(1)
            Set tSC = ..ReadBytes(pStream, tWant, .tPrefix)
            If $$$ISERR(tSC) Quit
            Set tPrefix = $Piece(tPrefix, $Char(10), 1)
        }
        Set pIdentity = $Translate($System.Encryption.Base64Encode($System.Encryption.SHAHash(256, tPrefix), 1), "+/", "-_")
    } Catch ex {
        Set pSize = 0
        Set pIdentity = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read up to <var>pWant</var> bytes from <var>pStream</var>'s current position into
/// <var>pBytes</var>, in <parameter>CHUNKSIZE</parameter> slices -- a single
/// <code>%Stream.FileBinary</code> read returns at most about 32 KB whatever it is asked for, so
/// a one-call read of a 64 KB window would silently come back short.</p>
/// <p>A read that reports an error stops the loop and returns it rather than spinning: a stream
/// that cannot be read reports <code>AtEnd</code> 0 forever.</p>
ClassMethod ReadBytes(pStream As %Stream.Object, pWant As %Integer, Output pBytes As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pBytes = ""
    While ($Length(pBytes) < pWant) && 'pStream.AtEnd {
        Set tLen = pWant - $Length(pBytes)
        If tLen > ..#CHUNKSIZE Set tLen = ..#CHUNKSIZE
        Set tChunk = pStream.Read(.tLen, .tSC)
        If $$$ISERR(tSC) Quit
        If tLen <= 0 Quit
        Set pBytes = pBytes _ tChunk
    }
    Quit tSC
}

/// <p>The whole lines of the window that starts at byte <var>pStart</var> and runs at most
/// <var>pMaxBytes</var> bytes, with the byte the next call should ask for.</p>
/// <p><b>Whole lines, three cases.</b> A window that begins mid-line -- the byte before
/// <var>pStart</var> is not a newline -- discards through its first newline. A window that stops
/// mid-line drops the partial tail and points <var>pNextOffset</var> at that tail's first byte,
/// so the next page serves it complete. A window holding no newline at all and not reaching the
/// end of the file is one line longer than the window: nothing is served,
/// <var>pTruncated</var> is true, and <var>pNextOffset</var> advances past the window so a reader
/// cannot loop on it.</p>
/// <p><var>pTruncated</var> is true exactly when the page did not reach the end of the file
/// (AD-36). <var>pLines</var> are UTF-8 decoded; a byte sequence that is not UTF-8 decodes to
/// <code>?</code> rather than reaching the envelope as a lone byte.</p>
ClassMethod ReadWindow(pStream As %Stream.Object, pStart As %Integer, pMaxBytes As %Integer, pSize As %Integer, Output pLines As %DynamicArray, Output pNextOffset As %Integer, Output pTruncated As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pLines = []
    Set pNextOffset = pStart
    Set pTruncated = 0
    Set tNewline = $Char(10)
    Try {
        If pStart > pSize Quit

        ; One byte before the window, when there is one, so "does this window begin mid-line?" is
        ; answered from the file rather than assumed from where the offset came from.
        Set tProbe = (pStart > 1)
        ; Clamped to the size every whole-line decision below is judged against. The instance
        ; appends to this file while the page is being assembled, so an unclamped read can return
        ; bytes past pSize -- and those bytes make tReachedEnd true, which is what suppresses the
        ; partial-tail drop and would serve a half-written line as a whole one.
        Set tWant = pMaxBytes + tProbe
        Set tAvailable = pSize - (pStart - tProbe) + 1
        If tWant > tAvailable Set tWant = tAvailable
        Do pStream.MoveTo(pStart - tProbe)
        Set tSC = ..ReadBytes(pStream, tWant, .tBuf)
        If $$$ISERR(tSC) Quit

        Set tMidLine = 0
        If tProbe {
            Set tMidLine = ($Extract(tBuf, 1) '= tNewline)
            Set tBuf = $Extract(tBuf, 2, *)
        }
        ; The file reported a size this window sits inside and handed back nothing, so it shrank
        ; between the two reads. There is nothing to serve and nowhere further forward to point.
        If tBuf = "" Quit

        Set tRegionStart = pStart
        If tMidLine {
            Set tAfterNewline = $Find(tBuf, tNewline)
            If tAfterNewline = 0 {
                Set pNextOffset = pStart + $Length(tBuf)
                Set pTruncated = 1
                Quit
            }
            Set tRegionStart = pStart + tAfterNewline - 1
            Set tBuf = $Extract(tBuf, tAfterNewline, *)
        }

        Set tReachedEnd = ((tRegionStart + $Length(tBuf) - 1) >= pSize)
        If 'tReachedEnd {
            Set tPieces = $Length(tBuf, tNewline)
            If tPieces = 1 {
                Set pNextOffset = tRegionStart + $Length(tBuf)
                Set pTruncated = 1
                Quit
            }
            ; Drop the partial tail after the last newline; pNextOffset then points at its first
            ; byte, so the next page serves that line whole.
            Set tBuf = $Extract(tBuf, 1, $Length(tBuf) - $Length($Piece(tBuf, tNewline, tPieces)))
        }

        Set pNextOffset = tRegionStart + $Length(tBuf)
        Set pTruncated = (pNextOffset <= pSize)

        Set tCount = $Length(tBuf, tNewline)
        For tI = 1:1:tCount {
            Set tLine = $Piece(tBuf, tNewline, tI)
            ; The empty piece a trailing newline leaves is a terminator, not a line.
            If (tI = tCount) && (tLine = "") Quit
            If $Extract(tLine, *) = $Char(13) Set tLine = $Extract(tLine, 1, *-1)
            Do pLines.%Push($ZConvert(tLine, "I", "UTF8"))
        }
    } Catch ex {
        Set pLines = []
        Set pNextOffset = pStart
        Set pTruncated = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 503 a present file that cannot be read answers with. <var>pStatus</var> is logged and
/// never put on the wire (AD-39).</p>
ClassMethod Unreadable(pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#LOGUNREADABLE, "That log file is present and this instance could not read it", .pHttpStatus, .pFault)
    Do ..LogFault("a log source could not be read", pStatus, pFault.code)
    Quit tSC
}

/// <p>A refusal this port decided itself, with no vendor status behind it. <var>pDetail</var>,
/// when supplied, becomes the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure inside the port: the generic internal fault on the wire, the raw
/// status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
