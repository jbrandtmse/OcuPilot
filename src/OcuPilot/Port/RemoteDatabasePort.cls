/// <p>The remote databases' port (AD-52, Story 18.16): <class>OcuPilot.Port.DatabasePort</class> with
/// a remote configuration's write sequenced here, and every other call the database port's own.</p>
/// <p><b>A configuration <code>PUT</code></b> -- a create's <code>{Server, Directory}</code> or an
/// update's complete set (AD-4) -- runs, in order: an omitted <code>Directory</code> refused
/// <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYNONE</parameter> before any vendor call (the
/// owner's database-directory rule); the configuration read, one holding an empty <code>Server</code>
/// refused 409 <parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter>; the data server read through
/// <code>ECP.DataServer</code> <code>GET</code>, a 404 refused
/// <parameter>OcuPilot.Api.DatabaseError.SERVERABSENT</parameter>; the bounded listing
/// (<method>Directories</method>); a directory the listing does not answer character for character
/// refused <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYABSENT</parameter>, and the one it
/// names <parameter>MANAGERNAME</parameter> <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYMANAGER</parameter>;
/// and only then the vendor's <code>PUT</code> (AD-21's seventh case). Each refusal is a 422 on its
/// field, the 409 excepted, and nothing is written after one.</p>
/// <p><b>A configuration <code>DELETE</code></b> refuses a local configuration 409
/// <parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter>, then is the database port's own, which
/// sends no file delete for a remote configuration.</p>
/// <p><b>The listing</b> runs in a short-lived child job the request waits for against
/// <method>ListSeconds</method>, on the <class>OcuPilot.Kernel.Provider.TestCall</class> model
/// (AD-42): a nonce, <code>$System.Event</code>, and the process's event queue cleared before each
/// spawn, so an abandoned child's late answer is discarded. When this instance's license enables no
/// ECP (<method>NetworkEnabled</method>) no child is spawned and the listing answers
/// <parameter>OcuPilot.Api.DatabaseError.SERVERUNREACHABLE</parameter> at once: a listing there
/// blocks, answers no rows and starts ECP client daemons that outlive it (measured at Story 18.16's
/// Task 0).</p>
/// <p><b>Caller contract:</b> no <code>New $ROLES</code> escalation is in effect in any frame of the
/// caller's stack (AD-9), because a job keeps the roles it was spawned with; and no turn calls the
/// listing (AD-7).</p>
Class OcuPilot.Port.RemoteDatabasePort Extends OcuPilot.Port.DatabasePort
{

/// <p>The bound, in seconds, a request waits for the listing (AD-21's seventh case): 20, Task 0's
/// rule over a measured listing of about 11 s.</p>
Parameter LISTSECONDS As INTEGER = 20;

/// <p>The data servers' endpoint, and the request type that lists a data server's databases.</p>
Parameter SERVERENDPOINT = "ECP.DataServer";

Parameter LISTINGTYPE = "DBLIST";

/// <p>The listing's route after the admin API's prefix, for a copy-out draft's step (AD-59).</p>
Parameter LISTINGROUTE = "/ecp/data-server/databases";

/// <p>The most rows a listing keeps; the vendor is asked for one more, so a cut list is known.</p>
Parameter LISTINGCAP As INTEGER = 1000;

/// <p>The name a data server's listing gives its own manager directory's database.</p>
Parameter MANAGERNAME = "IRISSYS";

/// <p>The status the data servers' list answers for a connected server (inference: the classic
/// page's connection state 5 reads Normal).</p>
Parameter NORMALSTATUS = "Normal";

/// <p>Seconds the spawn of the listing's child may take to be accepted.</p>
Parameter SPAWNTIMEOUT As INTEGER = 5;

/// <p>The port the configuration and the data server are read through: this one.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pEndpoint = ..#CONFIGENDPOINT {
        If pType = "PUT" Quit ..RemoteWrite(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = "DELETE" {
            Set tSC = ..Held($Get(pQuery(..#NAMEPARAM)), .tHeld, .tLocal, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit tSC
            If tLocal Quit ..LocalRefused(.pHttpStatus, .pFault)
        }
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>A remote configuration's create or update, in the order this class's header gives.</p>
ClassMethod RemoteWrite(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tBody = ..Without(pBody, $ListBuild(..#DELETEFILEQUERY))
    Set tServer = ..Value(tBody, ..#SERVERFIELD)
    Set tDirectory = ..Value(tBody, ..#DIRECTORYFIELD)
    If tDirectory = "" Quit ..FieldRefused(..#DIRECTORYFIELD, ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYNONE, .pHttpStatus, .pFault)
    Set tSC = ..Held($Get(pQuery(..#NAMEPARAM)), .tHeld, .tLocal, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tLocal Quit ..LocalRefused(.pHttpStatus, .pFault)
    Set tSC = ..ServerDefined(tServer, .tDefined, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tDefined Quit ..FieldRefused(..#SERVERFIELD, ##class(OcuPilot.Api.DatabaseError).#SERVERABSENT, .pHttpStatus, .pFault)
    Set tSC = ..Directories(tServer, .tRows, .tTruncated, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ..DirectoryRefusal(tRows, tDirectory)
    If tCode '= "" Quit ..FieldRefused(..#DIRECTORYFIELD, tCode, .pHttpStatus, .pFault)
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = $Get(pQuery(..#NAMEPARAM))
    Quit ..Call(..#CONFIGENDPOINT, "PUT", .tQuery, tBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>What refuses <var>pDirectory</var> against the listing <var>pRows</var>, or <code>""</code>:
/// <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYABSENT</parameter> when no row's
/// <code>Directory</code> equals it character for character, and
/// <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYMANAGER</parameter> when the row that does is
/// named <parameter>MANAGERNAME</parameter>. Pure.</p>
ClassMethod DirectoryRefusal(pRows As %DynamicArray, pDirectory As %String) As %String
{
    Set tCode = ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYABSENT
    If '$IsObject(pRows) Quit tCode
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (..Value(tRow, ..#DIRECTORYFIELD) '= pDirectory) Continue
        If $ZConvert(..Value(tRow, "Name"), "U") = ..#MANAGERNAME Set tCode = ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYMANAGER Quit
        Set tCode = ""
    }
    Quit tCode
}

/// <p>Whether the configuration <var>pName</var> is held, in <var>pHeld</var>, and whether it is a
/// local one (an empty <code>Server</code>), in <var>pLocal</var>, read through <method>Call</method>.
/// An absent configuration is neither and no error; any other failed read is its error.</p>
ClassMethod Held(pName As %String, Output pHeld As %Boolean, Output pLocal As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHeld = 0
    Set pLocal = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = pName
    Set tSC = ..Call(..#CONFIGENDPOINT, "GET", .tQuery, "", .tConfig, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus '= 404 Quit tSC
        Set pHttpStatus = 0
        Set pFault = ""
        Quit $$$OK
    }
    Set pHeld = 1
    Set pLocal = (..Value($Get(tConfig), ..#SERVERFIELD) = "")
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>Whether this instance defines the data server <var>pServer</var>, in <var>pDefined</var>, read
/// through <parameter>SERVERENDPOINT</parameter>'s <code>GET</code>: a 404, or an empty name, is not
/// defined and no error; any other failed read is its error.</p>
ClassMethod ServerDefined(pServer As %String, Output pDefined As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pDefined = 0
    Set pHttpStatus = 0
    Set pFault = ""
    If pServer = "" Quit $$$OK
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = pServer
    Set tSC = ..Call(..#SERVERENDPOINT, "GET", .tQuery, "", .tServer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus '= 404 Quit tSC
        Set pHttpStatus = 0
        Set pFault = ""
        Quit $$$OK
    }
    Set pDefined = 1
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>The databases data server <var>pServer</var> lists, as <code>[{Name, Directory}]</code> in
/// <var>pRows</var>, with <var>pTruncated</var> 1 when the vendor answered more than
/// <parameter>LISTINGCAP</parameter> (AD-21's seventh case).</p>
/// <p>When <method>NetworkEnabled</method> is 0 nothing is spawned and the answer is 422
/// <parameter>OcuPilot.Api.DatabaseError.SERVERUNREACHABLE</parameter> on <code>Server</code> at once.
/// Otherwise the vendor's listing runs in a child job (<method>ListChild</method>) the caller waits
/// for at most <method>ListSeconds</method>; past it, or when the child fails, or when the listing
/// answers no rows while the server's status (<method>ServerStatus</method>) is not
/// <parameter>NORMALSTATUS</parameter>, the answer is the same refusal. A server the instance does not
/// define is 422 <parameter>OcuPilot.Api.DatabaseError.SERVERABSENT</parameter>.</p>
/// <p><b>Caller contract:</b> this class's header's; it changes nothing stored.</p>
ClassMethod Directories(pServer As %String, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = []
    Set pTruncated = 0
    Set pHttpStatus = 0
    Set pFault = ""
    If '..NetworkEnabled() Quit ..Unreachable(.pHttpStatus, .pFault)
    Set tDeadline = $ZHorolog + ..ListSeconds()
    Set tSC = $$$OK
    Try {
        Do $System.Event.Clear($Job)
        Set tNonce = $System.Util.CreateGUID()
        If '..Spawn(tNonce, pServer) {
            Set tSC = ..Unreachable(.pHttpStatus, .pFault)
            Quit
        }
        Set tPayload = ""
        If ..Await(tNonce, tDeadline, .tPayload) '= "result" {
            Set tSC = ..Unreachable(.pHttpStatus, .pFault)
            Quit
        }
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(tPayload)
        If +tAnswer.%Get("http") = 404 {
            Set tSC = ..FieldRefused(..#SERVERFIELD, ##class(OcuPilot.Api.DatabaseError).#SERVERABSENT, .pHttpStatus, .pFault)
            Quit
        }
        If 'tAnswer.%Get("ok") || (tAnswer.%GetTypeOf("rows") '= "array") {
            Set tSC = ..Unreachable(.pHttpStatus, .pFault)
            Quit
        }
        Set tListed = tAnswer.%Get("rows")
        If (tListed.%Size() = 0) && (..ServerStatus(pServer) '= ..#NORMALSTATUS) {
            Set tSC = ..Unreachable(.pHttpStatus, .pFault)
            Quit
        }
        Set tIterator = tListed.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If pRows.%Size() = ..#LISTINGCAP {
                Set pTruncated = 1
                Quit
            }
            If '$IsObject(tRow) Continue
            Set tKept = {}
            Do tKept.%Set("Name", ..Value(tRow, "Name"), "string")
            Do tKept.%Set(..#DIRECTORYFIELD, ..Value(tRow, ..#DIRECTORYFIELD), "string")
            Do pRows.%Push(tKept)
        }
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = []
        Set tSC = ..Unreachable(.pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether this instance's license enables ECP: <code>$SYSTEM.License.NetworkEnabled()</code>.
/// A seam a test port overrides; production never does.</p>
ClassMethod NetworkEnabled() As %Boolean
{
    Quit ''$SYSTEM.License.NetworkEnabled()
}

/// <p><parameter>LISTSECONDS</parameter>. A seam a test port overrides to narrow the bound;
/// production never does.</p>
ClassMethod ListSeconds() As %Integer
{
    Quit ..#LISTSECONDS
}

/// <p>Spawn <method>ListChild</method> for this process and data server <var>pServer</var>, and answer
/// whether the <code>JOB</code> was accepted within <parameter>SPAWNTIMEOUT</parameter> seconds. The
/// child runs <method>ListRows</method> of this class, a subclass included. The one <code>JOB</code>
/// in this class.</p>
ClassMethod Spawn(pNonce As %String, pServer As %String) As %Boolean
{
    Job ##class(OcuPilot.Port.RemoteDatabasePort).ListChild($Job, pNonce, $Username, $ClassName(), pServer, ..#LISTINGCAP):($Namespace):..#SPAWNTIMEOUT
    Quit ''$Test
}

/// <p>Wait until <var>pDeadline</var> (<code>$ZHorolog</code> seconds) for a message carrying
/// <var>pNonce</var>; answer its kind (<code>result</code>, <code>refused</code> or
/// <code>failed</code>), or <code>""</code> at the deadline, with its third element in
/// <var>pPayload</var>. A message with another nonce, or one that is not a list, is discarded.</p>
ClassMethod Await(pNonce As %String, pDeadline As %Numeric, Output pPayload As %String) As %String [ Private ]
{
    Set pPayload = ""
    Set tKind = ""
    For {
        Set tRemaining = pDeadline - $ZHorolog
        If tRemaining <= 0 Quit
        Set tMessage = $System.Event.WaitMsg("", tRemaining)
        If $ListGet(tMessage, 1) '= 1 Continue
        Set tBody = $ListGet(tMessage, 2)
        If '$ListValid(tBody) Continue
        If $ListGet(tBody, 1) '= pNonce Continue
        Set tKind = $ListGet(tBody, 2)
        Set pPayload = $ListGet(tBody, 3)
        Quit
    }
    Quit tKind
}

/// <p>The listing's child job, spawned by <method>Spawn</method> and never called directly.
/// <var>pParent</var> is the request process, <var>pNonce</var> the tag its message carries,
/// <var>pUser</var> the user it must run as, <var>pClass</var> the port class whose
/// <method>ListRows</method> it runs (this class or a subclass), and <var>pCap</var> the rows kept.
/// It signals <code>refused</code> when it does not run as <var>pUser</var>, <code>failed</code> when
/// <var>pClass</var> is not this port or the call throws, and otherwise <code>result</code> with
/// <code>{ok, http, rows}</code> as JSON. It writes nothing.</p>
ClassMethod ListChild(pParent As %Integer, pNonce As %String, pUser As %String, pClass As %String, pServer As %String, pCap As %Integer)
{
    Try {
        If $Username '= pUser {
            Do $System.Event.Signal(pParent, $ListBuild(pNonce, "refused"))
            Quit
        }
        If '$ClassMethod(pClass, "%Extends", "OcuPilot.Port.RemoteDatabasePort") {
            Do $System.Event.Signal(pParent, $ListBuild(pNonce, "failed"))
            Quit
        }
        Set tSC = $ClassMethod(pClass, "ListRows", pServer, pCap, .tRows, .tHttp, .tFault)
        Set tOut = {}
        Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
        Do tOut.%Set("http", +$Get(tHttp), "number")
        If $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") {
            Do tOut.%Set("rows", tRows)
        } Else {
            Do tOut.%Set("rows", [])
        }
        Do $System.Event.Signal(pParent, $ListBuild(pNonce, "result", tOut.%ToJSON()))
    } Catch {
        Do $System.Event.Signal(pParent, $ListBuild(pNonce, "failed"))
    }
}

/// <p>The vendor's listing of data server <var>pServer</var>: <parameter>SERVERENDPOINT</parameter>
/// <parameter>LISTINGTYPE</parameter> through <method>Invoke</method> as the caller, asking for
/// <var>pCap</var> plus one rows. Run in <method>ListChild</method> alone; a seam a test port
/// overrides, which production never does.</p>
ClassMethod ListRows(pServer As %String, pCap As %Integer, Output pRows, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = pServer
    Set tQuery("maxRows") = pCap + 1
    Quit ..Invoke(..#SERVERENDPOINT, ..#LISTINGTYPE, .tQuery, "", .pRows, .pHttpStatus, .pFault)
}

/// <p>The status the data servers' list answers for <var>pServer</var>, compared without regard to
/// case, or <code>""</code> when the list cannot be read or does not name it. A seam a test port
/// overrides; production never does.</p>
ClassMethod ServerStatus(pServer As %String) As %String
{
    Kill tQuery
    Set tSC = ..Call(..#SERVERENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit ""
    Set tStatus = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($ZConvert(..Value(tRow, "Name"), "U") = $ZConvert(pServer, "U")) Set tStatus = ..Value(tRow, "Status") Quit
    }
    Quit tStatus
}

/// <p>The 422 <parameter>OcuPilot.Api.DatabaseError.SERVERUNREACHABLE</parameter> refusal on
/// <code>Server</code>.</p>
ClassMethod Unreachable(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..FieldRefused(..#SERVERFIELD, ##class(OcuPilot.Api.DatabaseError).#SERVERUNREACHABLE, .pHttpStatus, .pFault)
}

/// <p>A 422 refusal carrying one violation, <var>pCode</var> on <var>pField</var>, with nothing sent:
/// the envelope's code is <var>pCode</var> itself, so a confirm, which answers the envelope alone,
/// names the refusal as a Save names it on its field.</p>
ClassMethod FieldRefused(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason)
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Do pFault.%Set("detail", {"violations": [(tViolation)]})
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>The 409 <parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter> refusal, with nothing sent.</p>
ClassMethod LocalRefused(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 409
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.DatabaseError).#LOCAL, ##class(OcuPilot.Api.DatabaseError).#REASONLOCAL)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#LOCAL)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent or null as <code>""</code>.</p>
ClassMethod Value(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>The database port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a configuration <code>PUT</code> is the
/// listing's <code>GET</code> of the body's data server (<method>ListingStep</method>) and then the
/// database port's <code>PUT</code>; a configuration <code>DELETE</code> and every other call are the
/// database port's script. The listing's refusals are guards a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#CONFIGENDPOINT) && (pType = "PUT") {
        Set tSteps = []
        Set tServer = ..Value(pBody, ..#SERVERFIELD)
        If tServer '= "" Do tSteps.%Push(..ListingStep(tServer, pContext))
        Set tPut = ##super(pEndpoint, pType, .pQuery, pBody, pContext)
        If '$IsObject(tPut) || (tPut.%Size() = 0) Quit []
        Set tIterator = tPut.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(tStep)
        }
        Quit tSteps
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

/// <p>The listing as one <code>rest</code> step: a <code>curl</code> <code>GET</code> of
/// <parameter>LISTINGROUTE</parameter> naming data server <var>pServer</var>, on
/// <code>pContext.origin</code> as <code>pContext.user</code>.</p>
ClassMethod ListingStep(pServer As %String, pContext As %DynamicObject = "") As %DynamicObject
{
    Set tOrigin = ""
    Set tUser = ""
    If $IsObject(pContext) {
        Set tOrigin = pContext.%Get("origin")
        Set tUser = pContext.%Get("user")
    }
    Set tUrl = tOrigin _ ..#SNIPPETPREFIX _ ..#LISTINGROUTE _ "?" _ ..#NAMEPARAM _ "=" _ $ZConvert(pServer, "O", "URL")
    Quit ..Step("rest", "curl -u " _ ..ShellQuoted(tUser) _ " -X GET " _ ..ShellQuoted(tUrl))
}

}
