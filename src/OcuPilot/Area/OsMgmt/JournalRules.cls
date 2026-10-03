/// <p>Journal settings' rules (AD-39, AD-55, Story 18.18): the one rule set
/// <class>OcuPilot.Screen.Tool.JournalSettingsUpdate</class>'s mint and
/// <class>OcuPilot.Area.OsMgmt.JournalSave</class>'s Save apply before any vendor call
/// (<method>Validate</method>, <method>Problem</method>), and the classic Journal Settings page's purge
/// rule over the arguments a merge applies (<method>PurgeRule</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and each
/// refuses a value the admin API's <code>PUT</code> would answer 500 for, store rounded or store
/// unchecked (measured at the story's Task 0): the admin API checks no type, range or directory
/// itself.</p>
Class OcuPilot.Area.OsMgmt.JournalRules Extends %RegisteredObject
{

Parameter FIELDFILESIZE = "FileSizeLimit";

/// <p><code>Config.Journal</code>'s declared range for <code>FileSizeLimit</code>, which the vendor
/// stores at its lower bound.</p>
Parameter FILESIZEMIN As INTEGER = 0;

Parameter FILESIZEMAX As INTEGER = 4079;

/// <p>The purge counts and their upper bounds (<code>Config.Journal</code>, and the classic page's
/// own check).</p>
Parameter FIELDDAYS = "DaysBeforePurge";

Parameter DAYSMAX As INTEGER = 100;

Parameter FIELDBACKUPS = "BackupsBeforePurge";

Parameter BACKUPSMAX As INTEGER = 10;

Parameter FIELDPREFIX = "JournalFilePrefix";

/// <p>A prefix the vendor stores: letters, digits, hyphens and underscores, at most 64; it refuses a
/// dot.</p>
Parameter PREFIXPATTERN = "[A-Za-z0-9_-]{0,64}";

/// <p>The four flags, each a JSON boolean.</p>
Parameter BOOLEANFIELDS = "FreezeOnError,JournalcspSession,PurgeArchived,CompressFiles";

Parameter FIELDARCHIVE = "ArchiveName";

Parameter FIELDPURGEARCHIVED = "PurgeArchived";

/// <p>The two directories, each named by <code>&lt;which&gt;Root</code> and
/// <code>&lt;which&gt;Path</code>.</p>
Parameter DIRECTORIES = "primary,alternate";

/// <p>Every rule over the fields and arguments <var>pArgs</var> carries, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in <code>pViolations</code>:
/// each shape on its field, and each directory whose root or relative name is sent resolved through
/// <method>OcuPilot.Port.JournalPort.ResolveDirectory</method>, a refusal placed on the field it
/// names. A refusal that names no field -- a pair the path port requires -- is an error status
/// carrying <var>pHttpStatus</var> and <var>pFault</var>.</p>
ClassMethod Validate(pArgs As %DynamicObject, Output pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Quit
        Do ..WholeIn(pArgs, ..#FIELDFILESIZE, ..#FILESIZEMIN, ..#FILESIZEMAX, ##class(OcuPilot.Api.JournalError).#FILESIZESHAPE, .pViolations)
        Do ..WholeIn(pArgs, ..#FIELDDAYS, 0, ..#DAYSMAX, ##class(OcuPilot.Api.JournalError).#PURGESHAPE, .pViolations)
        Do ..WholeIn(pArgs, ..#FIELDBACKUPS, 0, ..#BACKUPSMAX, ##class(OcuPilot.Api.JournalError).#PURGESHAPE, .pViolations)
        Set tType = pArgs.%GetTypeOf(..#FIELDPREFIX)
        If (tType '= "unassigned") && ((tType '= "string") || '$Match(pArgs.%Get(..#FIELDPREFIX), ..#PREFIXPATTERN)) {
            Do ..Add(.pViolations, ..#FIELDPREFIX, ##class(OcuPilot.Api.JournalError).#PREFIXSHAPE)
        }
        For tI = 1:1:$Length(..#BOOLEANFIELDS, ",") {
            Set tField = $Piece(..#BOOLEANFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType '= "unassigned") && (tType '= "boolean") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.JournalError).#BOOLEANSHAPE)
        }
        For tI = 1:1:$Length(..#DIRECTORIES, ",") {
            Set tSC = ..DirectoryViolations(pArgs, $Piece(..#DIRECTORIES, ",", tI), .pViolations, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The rules of <method>Validate</method> as one problem sentence naming each field and its
/// published sentence, or <code>""</code>, in <var>pProblem</var>: what the tool's
/// <code>ArgumentProblem</code> answers. A refusal that names no field answers its own sentence; an
/// internal fault is an error status.</p>
ClassMethod Problem(pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ..Validate(pArgs, .tViolations, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If '$IsObject($Get(tFault)) || (tFault.%Get("reason") = "") || (tFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) Quit tSC
        Set pProblem = tFault.%Get("reason")
        Quit $$$OK
    }
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>The classic Journal Settings page's purge rule applied to the arguments <var>pArgs</var> a
/// merge over the fresh read <var>pFresh</var> takes, answered as a copy: while <var>pFresh</var>
/// names no archive target, <code>PurgeArchived</code> is sent false; while it is sent true, both purge
/// counts are sent 0. The merge applies the copy, so the payload, the diff and the body agree.</p>
ClassMethod PurgeRule(pArgs As %DynamicObject, pFresh As %DynamicObject) As %DynamicObject
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON($Select($IsObject(pArgs): pArgs.%ToJSON(), 1: "{}"))
    Set tPurge = 0
    If tArgs.%GetTypeOf(..#FIELDPURGEARCHIVED) = "boolean" {
        Set tPurge = tArgs.%Get(..#FIELDPURGEARCHIVED)
    } ElseIf tArgs.%GetTypeOf(..#FIELDPURGEARCHIVED) = "unassigned" {
        Set tPurge = ..Flag(pFresh, ..#FIELDPURGEARCHIVED)
    } Else {
        ; A value of another shape is the rules' to refuse, and nothing here moves.
        Quit tArgs
    }
    If tPurge && (..Text(pFresh, ..#FIELDARCHIVE) = "") {
        Do tArgs.%Set(..#FIELDPURGEARCHIVED, 0, "boolean")
        Set tPurge = 0
    }
    If tPurge {
        Do tArgs.%Set(..#FIELDDAYS, 0, "number")
        Do tArgs.%Set(..#FIELDBACKUPS, 0, "number")
    }
    Quit tArgs
}

/// <p>Add a violation unless <var>pArgs</var>'s <var>pField</var> is absent or a whole number from
/// <var>pMin</var> to <var>pMax</var>.</p>
ClassMethod WholeIn(pArgs As %DynamicObject, pField As %String, pMin As %Integer, pMax As %Integer, pCode As %String, ByRef pViolations) [ Private ]
{
    Set tType = pArgs.%GetTypeOf(pField)
    If tType = "unassigned" Quit
    Set tValue = pArgs.%Get(pField)
    If (tType = "number") && $IsValidNum(tValue) && (+tValue = (tValue \ 1)) && (+tValue >= pMin) && (+tValue <= pMax) Quit
    Do ..Add(.pViolations, pField, pCode)
}

/// <p>Add the violations of directory <var>pWhich</var>'s root and relative name, when
/// <var>pArgs</var> sends either: each must be a string, and the two must resolve to a directory the
/// instance holds.</p>
ClassMethod DirectoryViolations(pArgs As %DynamicObject, pWhich As %String, ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRootField = pWhich _ "Root"
    Set tPathField = pWhich _ "Path"
    Set tRootType = pArgs.%GetTypeOf(tRootField)
    Set tPathType = pArgs.%GetTypeOf(tPathField)
    If (tRootType = "unassigned") && (tPathType = "unassigned") Quit $$$OK
    If (tRootType '= "unassigned") && (tRootType '= "string") {
        Do ..Add(.pViolations, tRootField, ##class(OcuPilot.Api.Error).#PATHROOT)
        Quit $$$OK
    }
    If (tPathType '= "unassigned") && (tPathType '= "string") {
        Do ..Add(.pViolations, tPathField, ##class(OcuPilot.Api.Error).#PATHNAME)
        Quit $$$OK
    }
    Set tRoot = $Select(tRootType = "string": pArgs.%Get(tRootField), 1: "")
    Set tPath = $Select(tPathType = "string": pArgs.%Get(tPathField), 1: "")
    Set tSC = ##class(OcuPilot.Port.JournalPort).ResolveDirectory(tRoot, tPath, tRootField, tPathField, .tDirectory, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit $$$OK
    Set tRows = ""
    If $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) || (tRows.%Size() = 0) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Do ..Add(.pViolations, tRow.%Get("field"), tRow.%Get("code"))
    }
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null or an object as
/// <code>""</code>.</p>
ClassMethod Text(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>Whether <var>pObject</var>'s <var>pField</var> reads true.</p>
ClassMethod Flag(pObject, pField As %String) As %Boolean [ Private ]
{
    Set tValue = ..Text(pObject, pField)
    Quit (tValue = 1) || (tValue = "true")
}

}
