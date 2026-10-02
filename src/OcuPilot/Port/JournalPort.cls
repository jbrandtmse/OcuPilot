/// <p>The journal tools' port (AD-52, Story 18.5): <class>OcuPilot.Port.AdminPort</class> with the
/// journal switches' and the integrity check's reads and writes composed here, and every other call
/// the admin port's own, its journal file guard (AD-21's eighth case) included.</p>
/// <p><b>Two fresh reads are composed here</b> (AD-51 as amended by Story 18.5).
/// <parameter>STATETYPE</parameter> answers <code>{CurrentFile, CurrentDirectory}</code> from one
/// <parameter>FILEENDPOINT</parameter> <code>LIST</code> with <code>maxRows</code> 1, the newest listed
/// file and its parent directory. <parameter>DIRSTATETYPE</parameter> answers the same with
/// <code>OtherDirectory</code>, the configured directory a directory switch moves to, read from
/// <parameter>SETTINGSENDPOINT</parameter> <code>GET</code> as the vendor's own
/// <code>GetTheOtherDirectory</code> chooses it; an instance with one configured directory is refused
/// 409 <parameter>OcuPilot.Api.JournalError.SWITCHDIRNOOTHER</parameter>, so nothing is minted or
/// sent.</p>
/// <p><b>The directory switch is checked after the vendor answers</b>: its 409 is
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRNOOTHER</parameter>, and a 200 whose
/// <code>CurrentFile</code> sits in the directory journaling wrote in before the call is 409
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRUNMOVED</parameter> naming that directory, because the
/// vendor answers that way for a caller without <code>%Admin_Manage:USE</code> having switched only the
/// file (measured on <code>ocupilot-b-ci</code>, 2026-10-02).</p>
/// <p><b>The integrity check's body is built here</b> (AD-51): <code>{CheckDetails}</code> from the
/// query's <parameter>CHECKDETAILSQUERY</parameter>, false unless it reads true; a caller body is
/// refused. A check still running at <method>AsyncTimeout</method> has started: success with HTTP
/// <parameter>STARTEDHTTP</parameter> and no answer (AD-26). A finished check answers the admin
/// port's <code>{Result, console}</code>, whose lines reach the caller alone (AD-39's fifth
/// exception). A file's <code>GET</code> through this port also answers
/// <parameter>CHECKDETAILSQUERY</parameter> as <code>null</code>, so the tool's one argument merges
/// into a diff row.</p>
/// <p><b>It names no administration API class.</b> Every vendor call goes through
/// <method>Call</method>, which is <method>OcuPilot.Port.AdminPort.Invoke</method>, so the gate, the
/// stubs, the journal file guard and the fault mapping are the admin port's (AD-27).</p>
Class OcuPilot.Port.JournalPort Extends OcuPilot.Port.AdminPort
{

/// <p>The journal settings endpoint: the switches and the settings read.</p>
Parameter SETTINGSENDPOINT = "Journal.Settings";

/// <p>The journal file endpoint: the file list, a file's summary and its integrity check.</p>
Parameter FILEENDPOINT = "Journal.File";

/// <p>The switch file's fresh read, composed here.</p>
Parameter STATETYPE = "STATE";

/// <p>The switch directory's fresh read, composed here.</p>
Parameter DIRSTATETYPE = "DIRSTATE";

/// <p>The directory switch's request type.</p>
Parameter SWITCHDIRTYPE = "SWITCHDIR";

/// <p>The integrity check's request type.</p>
Parameter INTEGRITYTYPE = "INTEGRITYCHECK";

/// <p>The query key the integrity check's one argument travels under, and its body key.</p>
Parameter CHECKDETAILSQUERY = "CheckDetails";

/// <p>The fields the composed reads answer.</p>
Parameter CURRENTFILEFIELD = "CurrentFile";

Parameter CURRENTDIRECTORYFIELD = "CurrentDirectory";

Parameter OTHERDIRECTORYFIELD = "OtherDirectory";

/// <p>The settings read's two directory keys.</p>
Parameter PRIMARYKEY = "CurrentDirectory";

Parameter ALTERNATEKEY = "AlternateDirectory";

/// <p>The pairs whose answer or body this port composes rather than takes from its caller (AD-51 as
/// amended by Story 18.5).</p>
Parameter COMPOSEDTYPES = "Journal.Settings/STATE,Journal.Settings/DIRSTATE,Journal.File/INTEGRITYCHECK";

/// <p>The HTTP status of an integrity check still running when <method>AsyncTimeout</method> passes:
/// accepted, and continuing on the instance (AD-26).</p>
Parameter STARTEDHTTP = 202;

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes
/// goes through here, so a test port overrides this one method to record or answer a call.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with the branches this class's header names.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pEndpoint = ..#SETTINGSENDPOINT {
        If pType = ..#STATETYPE Quit ..State(0, .pResult, .pHttpStatus, .pFault)
        If pType = ..#DIRSTATETYPE Quit ..State(1, .pResult, .pHttpStatus, .pFault)
        If pType = ..#SWITCHDIRTYPE Quit ..SwitchDirectory(pBody, .pResult, .pHttpStatus, .pFault)
    }
    If (pEndpoint = ..#FILEENDPOINT) && (pType = ..#INTEGRITYTYPE) Quit ..Integrity(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If (pEndpoint = ..#FILEENDPOINT) && (pType = "GET") {
        Set tSC = ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) && $IsObject($Get(pResult)) && pResult.%IsA("%Library.DynamicObject") Do pResult.%Set(..#CHECKDETAILSQUERY, "", "null")
        Quit tSC
    }
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The switches' fresh read: <code>{CurrentFile, CurrentDirectory}</code>, the newest file the
/// journal file list answers and its directory, normalized with its trailing separator; with
/// <var>pOther</var>, <code>OtherDirectory</code> too (<method>OtherDirectory</method>), and an
/// instance with one configured directory is refused 409
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRNOOTHER</parameter>. An empty list is a 500.</p>
ClassMethod State(pOther As %Boolean, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Newest(.tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tDirectory = ..DirectoryOf(tFile)
    Set pResult = {}
    Do pResult.%Set(..#CURRENTFILEFIELD, tFile, "string")
    Do pResult.%Set(..#CURRENTDIRECTORYFIELD, tDirectory, "string")
    If pOther {
        Set tSC = ..OtherDirectory(tDirectory, .tOtherDirectory, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Set pResult = ""
            Quit tSC
        }
        If tOtherDirectory = "" {
            Set pResult = ""
            Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.JournalError).#SWITCHDIRNOOTHER, ##class(OcuPilot.Api.JournalError).#REASONSWITCHDIRNOOTHER, .pHttpStatus, .pFault)
        }
        Do pResult.%Set(..#OTHERDIRECTORYFIELD, tOtherDirectory, "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The newest listed journal file, in <var>pFile</var>: the first row of one
/// <parameter>FILEENDPOINT</parameter> <code>LIST</code> with <code>maxRows</code> 1. An answer with
/// no row naming a file is a 500.</p>
ClassMethod Newest(Output pFile As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFile = ""
    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tSC = ..Call(..#FILEENDPOINT, "LIST", .tQuery, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") && (tRows.%Size() > 0) && $IsObject(tRows.%Get(0)) {
        Set pFile = tRows.%Get(0).%Get("Name")
        If $IsObject(pFile) Set pFile = ""
    }
    If pFile '= "" Quit $$$OK
    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
    Do ..LogFault(..#FILEENDPOINT _ " LIST named no current journal file", $$$ERROR($$$GeneralError, "the journal file list answered no row"), pFault.code)
    Quit tSC
}

/// <p>The configured journal directory a directory switch from <var>pDirectory</var> moves to, in
/// <var>pOther</var>, as the vendor's <code>GetTheOtherDirectory</code> chooses it from
/// <parameter>SETTINGSENDPOINT</parameter> <code>GET</code>: <code>""</code> when the primary and the
/// alternate name one directory; the primary when journaling writes in the alternate; the alternate
/// otherwise. Directories are compared normalized and ignoring case.</p>
ClassMethod OtherDirectory(pDirectory As %String, Output pOther As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pOther = ""
    Kill tQuery
    Set tSC = ..Call(..#SETTINGSENDPOINT, "GET", .tQuery, "", .tSettings, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tPrimary = ..Normalized(..Text($Get(tSettings), ..#PRIMARYKEY))
    Set tAlternate = ..Normalized(..Text($Get(tSettings), ..#ALTERNATEKEY))
    If (tAlternate = "") || ..SameDirectory(tPrimary, tAlternate) Quit $$$OK
    Set pOther = $Select(..SameDirectory(pDirectory, tAlternate): tPrimary, 1: tAlternate)
    Quit $$$OK
}

/// <p>The directory switch: the directory journaling writes in before the call
/// (<method>Newest</method>), the vendor's <code>SWITCHDIR</code>, its 409 answered
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRNOOTHER</parameter>, and a 200 whose
/// <code>CurrentFile</code> sits in that same directory answered 409
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRUNMOVED</parameter>, never as a switch.</p>
ClassMethod SwitchDirectory(pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Newest(.tBefore, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tWasIn = ..DirectoryOf(tBefore)
    Kill tQuery
    Set tSC = ..Call(..#SETTINGSENDPOINT, ..#SWITCHDIRTYPE, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus = 409 {
            Set pResult = ""
            Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.JournalError).#SWITCHDIRNOOTHER, ##class(OcuPilot.Api.JournalError).#REASONSWITCHDIRNOOTHER, .pHttpStatus, .pFault)
        }
        Quit tSC
    }
    Set tNow = ..Text($Get(pResult), ..#CURRENTFILEFIELD)
    If (tNow = "") || ..SameDirectory(..DirectoryOf(tNow), tWasIn) {
        Set pResult = ""
        Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.JournalError).#SWITCHDIRUNMOVED, ##class(OcuPilot.Api.JournalError).Unmoved(tWasIn), .pHttpStatus, .pFault)
        Do ..LogFault(..#SETTINGSENDPOINT _ " " _ ..#SWITCHDIRTYPE _ " answered a switch that stayed in its directory", $$$ERROR($$$GeneralError, "the vendor's directory switch answered a file in the directory journaling wrote in before it"), pFault.code)
        Quit tSC
    }
    Quit $$$OK
}

/// <p>The integrity check of the file the query names: a caller body refused, then the vendor's
/// <code>INTEGRITYCHECK</code> with <method>IntegrityBody</method>'s body through
/// <method>Call</method>, whose journal file guard refuses an unlisted file before the call. A check
/// not finished within <method>AsyncTimeout</method> answers OK with <var>pHttpStatus</var>
/// <parameter>STARTEDHTTP</parameter> and <var>pResult</var> and <var>pFault</var> empty.</p>
ClassMethod Integrity(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If $IsObject(pBody) || (pBody '= "") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#FILEENDPOINT _ " " _ ..#INTEGRITYTYPE _ " was given a caller body, and its body is built by the port", $$$ERROR($$$GeneralError, "a journal integrity check takes no caller body"), pFault.code)
        Quit tSC
    }
    Kill tQuery
    Set tQuery(..#JOURNALFILEPARAM) = $Get(pQuery(..#JOURNALFILEPARAM))
    Set tSC = ..Call(..#FILEENDPOINT, ..#INTEGRITYTYPE, .tQuery, ..IntegrityBody(.pQuery), .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    ; AD-26: past the bound the queued check has started, and the vendor's worker finishes it.
    If $IsObject($Get(pFault)) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTTIMEOUT) {
        Set pResult = ""
        Set pHttpStatus = ..#STARTEDHTTP
        Set pFault = ""
        Quit $$$OK
    }
    Quit tSC
}

/// <p>The integrity check's body, <code>{CheckDetails}</code>: true when <var>pQuery</var>'s
/// <parameter>CHECKDETAILSQUERY</parameter> reads <code>1</code> or <code>true</code>, false
/// otherwise.</p>
ClassMethod IntegrityBody(ByRef pQuery) As %DynamicObject
{
    Set tValue = $Get(pQuery(..#CHECKDETAILSQUERY))
    Set tBody = {}
    Do tBody.%Set(..#CHECKDETAILSQUERY, (tValue = 1) || ($ZConvert(tValue, "L") = "true"), "boolean")
    Quit tBody
}

/// <p>The directory a journal file <var>pFile</var> sits in, normalized with its trailing separator,
/// or <code>""</code>.</p>
ClassMethod DirectoryOf(pFile As %String) As %String
{
    If pFile = "" Quit ""
    Quit ..Normalized(##class(%File).GetDirectory(pFile))
}

/// <p><var>pDirectory</var> normalized with its trailing separator, or <code>""</code>.</p>
ClassMethod Normalized(pDirectory As %String) As %String [ Private ]
{
    If pDirectory = "" Quit ""
    Quit ##class(%File).NormalizeDirectory(pDirectory)
}

/// <p>Whether two directories name one place: equal without regard to case once every trailing
/// separator is removed. <code>""</code> names none.</p>
ClassMethod SameDirectory(pA As %String, pB As %String) As %Boolean
{
    Set tA = $ZConvert($ZStrip(pA, ">", "/\"), "L")
    Set tB = $ZConvert($ZStrip(pB, ">", "/\"), "L")
    If (tA = "") || (tB = "") Quit 0
    Quit (tA = tB)
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

/// <p>The admin port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): the integrity check is the admin port's
/// script with <method>IntegrityBody</method>'s body, the journal file guard's read first; the
/// switches and every other call are the admin port's script. The composed reads and the directory
/// switch's checks of the vendor's answer are guards a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#FILEENDPOINT) && (pType = ..#INTEGRITYTYPE) {
        Kill tQuery
        Set tQuery(..#JOURNALFILEPARAM) = $Get(pQuery(..#JOURNALFILEPARAM))
        Quit ##super(pEndpoint, pType, .tQuery, ..IntegrityBody(.pQuery), pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
