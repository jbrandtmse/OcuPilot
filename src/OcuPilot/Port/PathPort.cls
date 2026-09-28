/// <p>The port to the instance's directory allow-list: AD-21's sixth case, the one form every
/// server-path field takes. A caller names an allowed <b>root</b> and a <b>relative name</b> under
/// it, never a path. <method>Rows</method> answers the roots a declared read shows (source
/// <code>path</code>, AD-36), and <method>Resolve</method> turns a root and a name into one
/// contained path for the tool that writes or reads it.</p>
/// <p><b>The roots are computed on every call and never cached.</b> They are the purpose
/// <parameter>PURPOSE</parameter>'s, the list the instance's own file dialogs read, reached through
/// <class>OcuPilot.Port.AdminPort</class> alone (AD-2, AD-27): <parameter>PURPOSEENDPOINT</parameter>
/// <code>GET</code>, and <parameter>PATHENDPOINT</parameter> <code>LIST</code> when that purpose is
/// restricted. Restricted, the roots are exactly its root paths, in the vendor's order, and there
/// may be none. Absent or unrestricted, the one root is the manager directory; a 404 from either
/// read counts as absent, since a purpose removed between the two reads answers 404 on the
/// second. The vendor classes behind those endpoints raise their own roles internally, so nothing
/// here calls them directly (AD-8).</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, checked in order in
/// the calling process before any port call. A caller missing one is refused 403
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> naming it.</p>
/// <p><b>Containment is textual</b>, as the vendor's own directory check is, so a symbolic link
/// inside a root is followed. No refusal carries a path or the caller's text.</p>
/// <p>Nothing here escalates, spawns or writes to the response device. The allow-list's switch to
/// <code>%SYS</code> is <class>OcuPilot.Port.AdminPort</class>'s; the port switches there itself,
/// by explicit save and restore (AD-16), only to read the configured databases an overwrite may
/// not reach, from <code>Config.Databases</code>' <code>List</code> query, and reads the journal
/// directories from <class>%SYS.Journal.System</class>, both on every call. Seams a test subclass
/// may override: <method>AdminPortClass</method>, <method>ManagerDirectory</method>,
/// <method>ConfigurationFile</method>, <method>DatabaseDirectories</method>,
/// <method>JournalDirectories</method>, <method>JournalSources</method>, <method>HoldsPrivilege</method> and
/// <method>NameAdmitted</method>. Production overrides none of them.</p>
Class OcuPilot.Port.PathPort Extends %RegisteredObject
{

/// <p>The allow-list purpose the instance's own file dialogs read.</p>
Parameter PURPOSE = "%GUIFileSelector";

/// <p>One name of a relative name: a letter or digit, then up to 99 letters, digits, dots,
/// underscores or dashes.</p>
Parameter SEGMENTPATTERN = "^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$";

/// <p>The most <code>/</code>-separated names a relative name may carry.</p>
Parameter MAXSEGMENTS As INTEGER = 8;

/// <p>The source keys a declared read may name on this port, comma-separated (AD-21, AD-36).</p>
Parameter SOURCES = "roots";

/// <p>The port's own pair set, checked in this order before any port call (AD-29).</p>
Parameter PAIRS = "%Admin_FileSystemAccess:USE,%DB_IRISSYS:READ";

/// <p>The read ceiling <method>Resolve</method> reads the roots under.</p>
Parameter RESOLVEMAXROWS As INTEGER = 1000;

/// <p>The admin endpoint answering whether a purpose exists and is restricted.</p>
Parameter PURPOSEENDPOINT = "FSAccess.Purpose";

/// <p>The admin endpoint listing a purpose's root paths.</p>
Parameter PATHENDPOINT = "FSAccess.Path";

/// <p>The kind of location that names a directory; an empty relative name is its root.</p>
Parameter KINDDIRECTORY = "directory";

/// <p>The kind of location that names a file; its relative name carries at least one name.</p>
Parameter KINDFILE = "file";

/// <p>The kind of location that names a file the consumer reads: it must already exist, and its
/// relative name carries at least one name.</p>
Parameter KINDSOURCE = "source";

/// <p>The name of a database's file in its directory.</p>
Parameter DATABASEFILE = "IRIS.DAT";

/// <p>The subdirectory of a database's directory its streams go in when the database names no
/// stream location of its own, as <code>Config.Databases</code>' <code>StreamLocation</code>
/// documents.</p>
Parameter STREAMDIRECTORY = "stream";

/// <p>The log subsystem a raw fault is written under.</p>
Parameter LOGSUBSYSTEM = "pathport";

/// <p>The port every allow-list read goes through. Overridable so a fixture can count the calls;
/// production never overrides it.</p>
ClassMethod AdminPortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The manager directory, with its trailing separator: the one root of an unrestricted
/// instance, the directory no file may sit directly in, and the parent of the database
/// directories an overwrite may not reach. Read on every call, because it is the instance's and
/// not a constant.</p>
ClassMethod ManagerDirectory() As %String
{
    Quit $System.Util.ManagerDirectory()
}

/// <p>The instance's active configuration file, its full path: the directory it sits in holds
/// the instance's configuration files. Read on every call, never a constant. Overridable so a
/// fixture can name another; production never overrides it.</p>
ClassMethod ConfigurationFile() As %String
{
    Quit ##class(%SYS.System).GetCPFFileName()
}

/// <p>Whether the calling process holds <var>pResource</var> at <var>pPermission</var>, asked at
/// the moment of the call (AD-8). Overridable so a fixture can deny one pair; production never
/// overrides it.</p>
ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    Quit ''$System.Security.Check(pResource, pPermission)
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in
/// order. <var>pFailedPair</var> names the first it lacks as <code>resource:permission</code>, or
/// is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        If ..HoldsPrivilege($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)) Continue
        Set pFailedPair = tPair
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The rows of declared-read source <var>pSource</var>, at most <var>pMaxRows</var> of them
/// (AD-36): <method>Roots</method> for <code>roots</code>. A source outside
/// <parameter>SOURCES</parameter> is a declaration no registry admits, and is a 500.</p>
ClassMethod Rows(pSource As %String = "", pMaxRows As %Integer = 0, Output pAnswer As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If '$ListFind($ListFromString(..#SOURCES), pSource) {
        Quit ..Fail("a read named a path source this port does not serve", $$$ERROR($$$GeneralError, "unknown path source"), .pHttpStatus, .pFault)
    }
    Quit ..Roots(pMaxRows, .pAnswer, .pHttpStatus, .pFault)
}

/// <p>The allowed roots, as at most <var>pMaxRows</var> rows <code>{Directory, Restricted}</code>
/// in <var>pRows</var>, and <var>pHttpStatus</var> 200. Restricted, one row per root path of
/// <parameter>PURPOSE</parameter> in the vendor's order, each <code>Restricted</code> true, and
/// possibly none; otherwise the one row of the manager directory, <code>Restricted</code>
/// false.</p>
/// <p>A caller the gate refuses gets 403 <code>PORT.ACCESSDENIED</code> with no port call made;
/// any other read failure passes through with its status and fault. <var>pMaxRows</var> below one
/// is a caller fault and a 500. Must not be called from an escalated frame (AD-9).</p>
ClassMethod Roots(pMaxRows As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..Denied(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = +pMaxRows
        If tMax < 1 {
            Set tSC = ..Fail("the roots were asked for no row", $$$ERROR($$$GeneralError, "maxRows below one"), .pHttpStatus, .pFault)
            Quit
        }

        Kill tQuery
        Set tQuery("purpose") = ..#PURPOSE
        Set tRestricted = 0
        Set tReadSC = $ClassMethod(..AdminPortClass(), "Invoke", ..#PURPOSEENDPOINT, "GET", .tQuery, "", .tPurpose, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If tHttp '= 404 {
                Set pHttpStatus = tHttp
                Set pFault = tFault
                Set tSC = tReadSC
                Quit
            }
        } ElseIf '$IsObject(tPurpose) || 'tPurpose.%IsA("%Library.DynamicObject") {
            Set tSC = ..Fail("the purpose read answered something other than an object", $$$ERROR($$$GeneralError, "not an object"), .pHttpStatus, .pFault)
            Quit
        } Else {
            Set tRestricted = (tPurpose.%Get("Restricted") = 1)
        }

        If tRestricted {
            Kill tQuery
            Set tQuery("purpose") = ..#PURPOSE
            Set tQuery("maxRows") = tMax
            Set tListSC = $ClassMethod(..AdminPortClass(), "Invoke", ..#PATHENDPOINT, "LIST", .tQuery, "", .tList, .tHttp, .tFault)
            If $$$ISERR(tListSC) {
                If tHttp '= 404 {
                    Set pHttpStatus = tHttp
                    Set pFault = tFault
                    Set tSC = tListSC
                    Quit
                }
                Set tRestricted = 0
            } ElseIf '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") {
                Set tSC = ..Fail("the root path read answered something other than a list", $$$ERROR($$$GeneralError, "not a list"), .pHttpStatus, .pFault)
                Quit
            } Else {
                Set pRows = []
                Set tIterator = tList.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tEntry) {
                    If pRows.%Size() >= tMax Quit
                    If '$IsObject(tEntry) Continue
                    Do pRows.%Push(..Row(tEntry.%Get("RootPath"), 1))
                }
            }
        }
        If 'tRestricted {
            Set pRows = [(..Row(..ManagerDirectory(), 0))]
        }
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail("the roots failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One root as a declared read's row: <code>{Directory, Restricted}</code>, in that order.</p>
ClassMethod Row(pDirectory As %String, pRestricted As %Boolean) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Directory", pDirectory, "string")
    Do tRow.%Set("Restricted", ''pRestricted, "boolean")
    Quit tRow
}

/// <p>Resolve allowed root <var>pRoot</var> and relative name <var>pPath</var> to one location of
/// kind <var>pKind</var>: <parameter>KINDDIRECTORY</parameter>, <parameter>KINDFILE</parameter> (a
/// file the consumer writes) or <parameter>KINDSOURCE</parameter> (a file it reads). On success
/// <var>pResolved</var> is the normalized path, a directory with its trailing separator, and
/// <var>pHttpStatus</var> is 200.</p>
/// <p>The gate runs first. Then <var>pPath</var> is refused 400 <code>PATH.NAME</code> unless
/// <method>NameAdmitted</method> admits it; the roots are read again under
/// <parameter>RESOLVEMAXROWS</parameter>, and <var>pRoot</var> is refused 400
/// <code>PATH.ROOT</code> unless it equals one of them character for character; and the composed
/// path, normalized with the one-argument <class>%File</class> form, is refused
/// <code>PATH.NAME</code> unless <method>Contains</method> puts it under that root. A directory
/// may be the root itself.</p>
/// <p>A file or a source is refused <code>PATH.MANAGER</code> when
/// <method>DirectlyInManagerDirectory</method> places it directly in the manager directory, which
/// holds the instance's own files. Then a file is refused <code>PATH.EXISTS</code> when a
/// directory stands at that name, or a file does and <var>pOverwrite</var> is false; and, when
/// <var>pOverwrite</var> is true, <code>PATH.INSTANCE</code> when the file standing at that name is
/// one <method>InstanceFile</method> names. A source is refused <code>PATH.NOFILE</code> unless a file,
/// not a directory, stands at that name; it is never refused for existing, and
/// <var>pOverwrite</var> means nothing to it. A directory is refused
/// <code>PATH.MANAGERDIR</code> when it is the manager directory itself and
/// <var>pVendorWrites</var> is true. Only a consuming tool that declares it overwrites passes
/// <var>pOverwrite</var>, and only one whose vendor writes its own files into the directory it
/// names (a database, a journal, a backup) passes <var>pVendorWrites</var>.</p>
/// <p>Each refusal carries <code>detail.violations</code>, one <code>{field, code, reason}</code>
/// on <var>pRootField</var> or <var>pPathField</var>, the names the caller's own form uses. A kind
/// outside the three is a caller fault and a 500. A consumer calls this at the mint and again at
/// the write, and sends <var>pResolved</var> under the vendor's own field.</p>
ClassMethod Resolve(pRoot As %String = "", pPath As %String = "", pKind As %String = "", pRootField As %String = "root", pPathField As %String = "path", Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pOverwrite As %Boolean = 0, pVendorWrites As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set pResolved = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..Denied(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If (pKind '= ..#KINDDIRECTORY) && (pKind '= ..#KINDFILE) && (pKind '= ..#KINDSOURCE) {
            Set tSC = ..Fail("a path was resolved for a kind this port does not know", $$$ERROR($$$GeneralError, "unknown kind"), .pHttpStatus, .pFault)
            Quit
        }
        If '..NameAdmitted(pPath, pKind) {
            Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHNAME, ##class(OcuPilot.Api.Error).#REASONPATHNAME, pPathField, .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Roots(..#RESOLVEMAXROWS, .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tMember = 0
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("Directory") = pRoot {
                Set tMember = 1
                Quit
            }
        }
        If 'tMember {
            Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHROOT, ##class(OcuPilot.Api.Error).#REASONPATHROOT, pRootField, .pHttpStatus, .pFault)
            Quit
        }

        Set tBase = ##class(%File).NormalizeDirectory(pRoot)
        ; The one-argument forms: they never change directory, so a location that does not exist
        ; yet still normalizes; each answers "" only when it fails, which is refused below.
        If pKind = ..#KINDDIRECTORY {
            Set tCandidate = ##class(%File).NormalizeDirectory(tBase _ pPath)
        } Else {
            Set tCandidate = ##class(%File).NormalizeFilename(tBase _ pPath)
        }
        If (tBase = "") || '..Contains(pRoot, tCandidate) {
            Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHNAME, ##class(OcuPilot.Api.Error).#REASONPATHNAME, pPathField, .pHttpStatus, .pFault)
            Quit
        }
        If pKind = ..#KINDDIRECTORY {
            If pVendorWrites && ..IsManagerDirectory(tCandidate) {
                Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHMANAGERDIR, ##class(OcuPilot.Api.Error).#REASONPATHMANAGERDIR, pPathField, .pHttpStatus, .pFault)
                Quit
            }
        } Else {
            If ..DirectlyInManagerDirectory(tCandidate) {
                Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHMANAGER, ##class(OcuPilot.Api.Error).#REASONPATHMANAGER, pPathField, .pHttpStatus, .pFault)
                Quit
            }
            If pKind = ..#KINDSOURCE {
                If ##class(%File).DirectoryExists(tCandidate) || '##class(%File).Exists(tCandidate) {
                    Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHNOFILE, ##class(OcuPilot.Api.Error).#REASONPATHNOFILE, pPathField, .pHttpStatus, .pFault)
                    Quit
                }
            } Else {
                If ##class(%File).DirectoryExists(tCandidate) || ('pOverwrite && ##class(%File).Exists(tCandidate)) {
                    Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHEXISTS, ##class(OcuPilot.Api.Error).#REASONPATHEXISTS, pPathField, .pHttpStatus, .pFault)
                    Quit
                }
                If pOverwrite && ##class(%File).Exists(tCandidate) && ..InstanceFile(tCandidate) {
                    Set tSC = ..Violation(##class(OcuPilot.Api.Error).#PATHINSTANCE, ##class(OcuPilot.Api.Error).#REASONPATHINSTANCE, pPathField, .pHttpStatus, .pFault)
                    Quit
                }
            }
        }
        Set pResolved = tCandidate
        Set pHttpStatus = 200
    } Catch ex {
        Set pResolved = ""
        Set tSC = ..Fail("a path failed to resolve inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pPath</var> is a relative name a location of kind <var>pKind</var> may take:
/// empty for a directory, or one to <parameter>MAXSEGMENTS</parameter> names separated by
/// <code>/</code>, each matching <parameter>SEGMENTPATTERN</parameter>, with no literal
/// <code>..</code> anywhere. A string test only; nothing here reaches the filesystem.</p>
ClassMethod NameAdmitted(pPath As %String, pKind As %String) As %Boolean
{
    If pPath [ ".." Quit 0
    If pPath = "" Quit (pKind = ..#KINDDIRECTORY)
    Set tCount = $Length(pPath, "/")
    If tCount > ..#MAXSEGMENTS Quit 0
    Set tAdmitted = 1
    For tI = 1:1:tCount {
        If $Match($Piece(pPath, "/", tI), ..#SEGMENTPATTERN) Continue
        Set tAdmitted = 0
        Quit
    }
    Quit tAdmitted
}

/// <p>Whether normalized <var>pCandidate</var> lies under <var>pRoot</var>: it begins with the
/// root, trailing separator included, so a sibling such as <code>/a/bc/</code> is outside
/// <code>/a/b/</code>. The root itself is inside, which is what lets a directory field name
/// it.</p>
ClassMethod Contains(pRoot As %String, pCandidate As %String) As %Boolean
{
    If (pRoot = "") || (pCandidate = "") Quit 0
    Set tRoot = ##class(%File).NormalizeDirectory(pRoot)
    If tRoot = "" Quit 0
    Quit ($Extract(pCandidate, 1, $Length(tRoot)) = tRoot)
}

/// <p>Whether normalized file path <var>pFile</var> sits directly in the manager directory: it is
/// that directory, normalized, followed by its own last name. A file in a subdirectory of it is
/// not. Textual, as <method>Contains</method> is; a manager directory that is empty or does not
/// normalize answers true, so the refusal it guards fails closed.</p>
ClassMethod DirectlyInManagerDirectory(pFile As %String) As %Boolean
{
    Set tManager = ..ManagerDirectoryNormalized()
    If tManager = "" Quit 1
    Quit (pFile = (tManager _ ##class(%File).GetFilename(pFile)))
}

/// <p>Whether normalized directory path <var>pDirectory</var> is the manager directory itself.
/// Textual; a manager directory that is empty or does not normalize answers true, so the refusal
/// it guards fails closed.</p>
ClassMethod IsManagerDirectory(pDirectory As %String) As %Boolean
{
    Set tManager = ..ManagerDirectoryNormalized()
    If tManager = "" Quit 1
    Quit (pDirectory = tManager)
}

/// <p>Whether normalized file path <var>pFile</var> is one of the instance's own files an
/// overwrite must not reach: <method>DirectlyInConfigurationDirectory</method>,
/// <method>DatabaseFileBelowManagerDirectory</method>, <method>InDatabaseDirectory</method> or
/// <method>InJournalDirectory</method>. It says nothing about whether the file exists.</p>
ClassMethod InstanceFile(pFile As %String) As %Boolean
{
    Quit ..DirectlyInConfigurationDirectory(pFile) || ..DatabaseFileBelowManagerDirectory(pFile) || ..InDatabaseDirectory(pFile) || ..InJournalDirectory(pFile)
}

/// <p>Whether normalized file path <var>pFile</var> sits directly in the directory of
/// <method>ConfigurationFile</method>, beside the instance's configuration file and its saved
/// copies. Textual; a configuration file that is empty, or whose directory is empty or does not
/// normalize, answers true, so the refusal it guards fails closed.</p>
ClassMethod DirectlyInConfigurationDirectory(pFile As %String) As %Boolean
{
    Set tDirectory = ..ConfigurationFile()
    If tDirectory '= "" Set tDirectory = ##class(%File).GetDirectory(tDirectory)
    If tDirectory '= "" Set tDirectory = ##class(%File).NormalizeDirectory(tDirectory)
    If tDirectory = "" Quit 1
    Quit (pFile = (tDirectory _ ##class(%File).GetFilename(pFile)))
}

/// <p>Whether normalized file path <var>pFile</var> is a database file one directory below the
/// manager directory: its name is <parameter>DATABASEFILE</parameter>, ignoring case, and its
/// directory's parent is the manager directory. Textual; a manager directory that is empty or does
/// not normalize answers true, so the refusal it guards fails closed.</p>
ClassMethod DatabaseFileBelowManagerDirectory(pFile As %String) As %Boolean
{
    Set tManager = ..ManagerDirectoryNormalized()
    If tManager = "" Quit 1
    If $ZConvert(##class(%File).GetFilename(pFile), "U") '= ..#DATABASEFILE Quit 0
    Set tDirectory = ##class(%File).GetDirectory(pFile)
    If tDirectory = "" Quit 0
    Quit (##class(%File).ParentDirectoryName(tDirectory) = tManager)
}

/// <p>Whether normalized file path <var>pFile</var> is a configured database's own: it sits
/// directly in a database's directory, as the database file, its lock file and the volume files
/// kept beside it do, or anywhere under that database's stream location, as
/// <method>DatabaseDirectories</method> answers them at this call. A file in any other
/// subdirectory of a database's directory is not the database's. Textual; a read that fails
/// answers true, so the refusal it guards fails closed.</p>
ClassMethod InDatabaseDirectory(pFile As %String) As %Boolean
{
    If $$$ISERR(..DatabaseDirectories(.tDirectories, .tStreams)) Quit 1
    Set tIn = 0
    For tI = 1:1:$ListLength(tDirectories) {
        If pFile = ($List(tDirectories, tI) _ ##class(%File).GetFilename(pFile)) {
            Set tIn = 1
            Quit
        }
    }
    If tIn Quit 1
    For tI = 1:1:$ListLength(tStreams) {
        If ..Contains($List(tStreams, tI), pFile) {
            Set tIn = 1
            Quit
        }
    }
    Quit tIn
}

/// <p>Whether normalized file path <var>pFile</var> sits directly in one of the instance's journal
/// directories, as <method>JournalDirectories</method> answers them at this call. Textual; a read
/// that fails answers true, so the refusal it guards fails closed.</p>
ClassMethod InJournalDirectory(pFile As %String) As %Boolean
{
    If $$$ISERR(..JournalDirectories(.tDirectories)) Quit 1
    Set tIn = 0
    For tI = 1:1:$ListLength(tDirectories) {
        If pFile = ($List(tDirectories, tI) _ ##class(%File).GetFilename(pFile)) {
            Set tIn = 1
            Quit
        }
    }
    Quit tIn
}

/// <p>The configured local databases' directories in <var>pDirectories</var> and their stream
/// locations in <var>pStreams</var>, each normalized with its trailing separator, read on every
/// call from <code>Config.Databases</code>' <code>List</code> query in <code>%SYS</code>, reached by
/// explicit save and restore (AD-16). A database that names no stream location keeps its streams in
/// <parameter>STREAMDIRECTORY</parameter> under its directory. A directory in the mirror or
/// data-server form names no local path and is left out. On failure both lists are empty and the
/// status says why. Overridable so a fixture can name others or fail the read; production never
/// overrides it.</p>
ClassMethod DatabaseDirectories(Output pDirectories As %List, Output pStreams As %List) As %Status
{
    Set tSC = $$$OK
    Set pDirectories = ""
    Set pStreams = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.Databases:List")
        Set tSC = tRS.Execute("*", "", 1)
        While $$$ISOK(tSC) && tRS.Next(.tSC) {
            Set tDirectory = tRS.Get("Directory")
            If (tDirectory = "") || ($Extract(tDirectory) = ":") Continue
            Set tStream = tRS.Get("StreamLocation")
            If tStream = "" Set tStream = ##class(%File).NormalizeDirectory(tDirectory) _ ..#STREAMDIRECTORY
            Set tDirectory = ##class(%File).NormalizeDirectory(tDirectory)
            Set tStream = ##class(%File).NormalizeDirectory(tStream)
            If (tDirectory = "") || (tStream = "") {
                Set tSC = $$$ERROR($$$GeneralError, "a configured database's directory did not normalize")
                Quit
            }
            Set pDirectories = pDirectories _ $ListBuild(tDirectory)
            Set pStreams = pStreams _ $ListBuild(tStream)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pDirectories = ""
        Set pStreams = ""
    }
    Quit tSC
}

/// <p>The instance's journal directories in <var>pDirectories</var>, each normalized with its
/// trailing separator and named once, read on every call through <method>JournalSources</method>:
/// the primary directory, the alternate directory, and the directory of the file journaling writes
/// now. One the instance answers empty is left out. On failure the list is empty and the status
/// says why. Overridable so a fixture can name others or fail the read; production never overrides
/// it.</p>
ClassMethod JournalDirectories(Output pDirectories As %List) As %Status
{
    Set tSC = $$$OK
    Set pDirectories = ""
    Try {
        Set tSC = ..JournalSources(.tPrimary, .tAlternate, .tCurrent)
        If $$$ISERR(tSC) Quit
        If tCurrent '= "" Set tCurrent = ##class(%File).GetDirectory(tCurrent)
        For tDirectory = tPrimary, tAlternate, tCurrent {
            If tDirectory = "" Continue
            Set tDirectory = ##class(%File).NormalizeDirectory(tDirectory)
            If tDirectory = "" {
                Set tSC = $$$ERROR($$$GeneralError, "a journal directory did not normalize")
                Quit
            }
            If '$ListFind(pDirectories, tDirectory) Set pDirectories = pDirectories _ $ListBuild(tDirectory)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pDirectories = ""
    Quit tSC
}

/// <p>The primary journal directory in <var>pPrimary</var>, the alternate in <var>pAlternate</var>
/// and the file journaling writes now in <var>pCurrentFile</var>, as
/// <class>%SYS.Journal.System</class> answers them at this call, each as the instance spells it.
/// Overridable so a fixture can name three distinct ones; production never overrides it.</p>
ClassMethod JournalSources(Output pPrimary As %String, Output pAlternate As %String, Output pCurrentFile As %String) As %Status
{
    Set tSC = $$$OK
    Set pPrimary = ""
    Set pAlternate = ""
    Set pCurrentFile = ""
    Try {
        Set pPrimary = ##class(%SYS.Journal.System).GetPrimaryDirectory()
        Set pAlternate = ##class(%SYS.Journal.System).GetAlternateDirectory()
        Set pCurrentFile = ##class(%SYS.Journal.System).GetCurrentFileName()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The manager directory, normalized, or <code>""</code> when it is empty or does not
/// normalize.</p>
ClassMethod ManagerDirectoryNormalized() As %String [ Private ]
{
    Set tManager = ..ManagerDirectory()
    If tManager '= "" Set tManager = ##class(%File).NormalizeDirectory(tManager)
    Quit tManager
}

/// <p>The 403 the gate answers: <code>PORT.ACCESSDENIED</code> on its written sentence, with
/// <code>detail.failedPair</code>.</p>
ClassMethod Denied(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tIgnored)
    If $$$ISERR(tMapSC) Quit ..Fail("the port's own refusal could not be mapped", tMapSC, .pHttpStatus, .pFault)
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A 400 refusal on one field, as <code>code</code> with its sentence, carried again as that
/// field's one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, pReason As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
