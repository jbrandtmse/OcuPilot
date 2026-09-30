/// <p>The lock port (AD-51, AD-52, Story 16.12): <class>OcuPilot.Port.AdminPort</class> with the lock
/// removals' reads and writes composed over the vendor's own <code>Lock</code> <code>LIST</code> and
/// <code>DELETE</code>, and every other call the admin port's own.</p>
/// <p><b>The reads.</b> <parameter>ROWTYPE</parameter> answers the one lock whose <code>DeleteID</code>
/// is the <parameter>IDPARAM</parameter> query parameter exactly, from a <code>LIST</code> filtered by
/// that id: <code>{DeleteID, Pid, Owner, RemoteOwner, Reference, ModeCount, Directory, System,
/// RemoveInTransaction}</code>. <parameter>OWNERTYPE</parameter> answers every lock of that lock's
/// owner -- the <code>DeleteID</code>'s third comma piece (<code>P905</code>, or <code>C</code> and a
/// client for a remote owner), compared exactly, because the vendor's <code>filter</code> is a
/// case-insensitive substring over the whole row -- from a <code>LIST</code> of at most
/// <parameter>MAXOWNERLOCKS</parameter> plus one rows: <code>{DeleteID, Pid, Owner, RemoteOwner,
/// DeleteIDs, Locks: [{DeleteID, Reference, ModeCount, Directory}], RemoveInTransaction}</code>, each
/// list in <code>DeleteID</code> order. Both answer <code>RemoveInTransaction</code> as
/// <code>null</code>, so the tools' one argument merges into a diff row, and both answer 404, logging
/// nothing, when the id names no listed lock.</p>
/// <p><b>The writes.</b> <parameter>REMOVETYPE</parameter> and <parameter>REMOVEOWNERTYPE</parameter>
/// re-list first and then send one <code>Lock</code> <code>DELETE</code>
/// <code>?id=&lt;DeleteID&gt;&amp;checkTxn=&lt;c&gt;</code> per id the <parameter>IDSQUERY</parameter>
/// query parameter names, in its order, and only for an id found verbatim in that fresh listing: a
/// <code>DeleteID</code> naming no listed lock crashed the serving process in measurement. An id no
/// longer listed is skipped, since its owner has released it; for <parameter>REMOVETYPE</parameter>
/// that skip is 404 <code>PORT.NOTFOUND</code>. <code>c</code> is the
/// <parameter>CHECKTXNQUERY</parameter> query parameter, <code>1</code> unless it reads
/// <code>0</code>, and <code>0</code> for a lock the listing reports held by a remote owner. The
/// vendor's 409 answers <parameter>OcuPilot.Api.LockError.INTRANSACTION</parameter> and the port sends
/// nothing further; an owner scope is not atomic, so the removals before it stand. A caller body is
/// refused.</p>
/// <p><b>It names no administration API class</b> (AD-2, AD-27): every vendor call goes through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the gate, the stubs, the namespace switch and
/// the fault mapping are the admin port's.</p>
Class OcuPilot.Port.LockPort Extends OcuPilot.Port.AdminPort
{

/// <p>The vendor endpoint every lock call addresses.</p>
Parameter LOCKENDPOINT = "Lock";

/// <p>The vendor's list and removal types.</p>
Parameter LISTTYPE = "LIST";

Parameter DELETETYPE = "DELETE";

/// <p>The reads this port composes: one lock, and every lock of its owner.</p>
Parameter ROWTYPE = "ROW";

Parameter OWNERTYPE = "OWNER";

/// <p>The writes this port composes: one lock, and every lock of an owner.</p>
Parameter REMOVETYPE = "REMOVE";

Parameter REMOVEOWNERTYPE = "REMOVEOWNER";

/// <p>The query parameter a lock is named by, the vendor's own for its <code>DELETE</code>.</p>
Parameter IDPARAM = "id";

/// <p>The query key the stored ids travel under, as a JSON array of <code>DeleteID</code>s. It never
/// reaches the vendor.</p>
Parameter IDSQUERY = "ids";

/// <p>The vendor's in-transaction check parameter.</p>
Parameter CHECKTXNQUERY = "checkTxn";

/// <p>The vendor's list filter and row cap.</p>
Parameter FILTERQUERY = "filter";

Parameter MAXROWSQUERY = "maxRows";

/// <p>The most locks one owner-scope removal names.</p>
Parameter MAXOWNERLOCKS As INTEGER = 200;

/// <p>The pairs whose vendor calls this port composes from the tools' declared argument and the
/// target (AD-51).</p>
Parameter COMPOSEDTYPES = "Lock/REMOVE,Lock/REMOVEOWNER";

/// <p>The admin API write this port issues of its own for those pairs.</p>
Parameter DELEGATEDTYPES = "Lock/DELETE";

/// <p>The argument both reads answer as <code>null</code>.</p>
Parameter OVERRIDEFIELD = "RemoveInTransaction";

/// <p>The admin port's call, with the four types this class's header names answered here.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s, and <var>pQuery</var> is not modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint '= ..#LOCKENDPOINT) || '$ListFind($ListBuild(..#ROWTYPE, ..#OWNERTYPE, ..#REMOVETYPE, ..#REMOVEOWNERTYPE), pType) {
        Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    }
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tWrite = (pType = ..#REMOVETYPE) || (pType = ..#REMOVEOWNERTYPE)
    If tWrite && ($IsObject(pBody) || (pBody '= "")) {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its calls are composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
        Quit tSC
    }
    Set tId = $Get(pQuery(..#IDPARAM))
    If tId = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "A lock is named by its DeleteID", .pHttpStatus, .pFault)
    Set tOwner = ..OwnerOf(tId)
    Set tScoped = (pType = ..#OWNERTYPE) || (pType = ..#REMOVEOWNERTYPE)
    If tScoped && (tOwner = "") Quit ..Absent(pEndpoint, .pHttpStatus, .pFault)
    Set tSC = ..Listing(tId, tScoped, .tByDeleteID, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pHttpStatus = 0
    Set pFault = ""
    If 'tWrite {
        If '$Data(tByDeleteID(tId)) Quit ..Absent(pEndpoint, .pHttpStatus, .pFault)
        If pType = ..#ROWTYPE {
            Set pResult = ..RowAnswer(tByDeleteID(tId))
        } Else {
            Set pResult = ..OwnerAnswer(tId, .tByDeleteID)
        }
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tIds = $Select(pType = ..#REMOVETYPE: $ListBuild(tId), 1: ..IdsOf(.pQuery))
    Set tCheck = ..CheckTxnOf(.pQuery)
    Set tRemoved = 0
    Set tSC = $$$OK
    For tI = 1:1:$ListLength(tIds) {
        Set tDeleteID = $List(tIds, tI)
        ; Only an id this listing holds verbatim is ever sent (AD-52 as amended 2026-09-30).
        If '$Data(tByDeleteID(tDeleteID)) Continue
        Kill tQuery
        Set tQuery(..#IDPARAM) = tDeleteID
        Set tQuery(..#CHECKTXNQUERY) = $Select(''tByDeleteID(tDeleteID).%Get("RemoteOwner"): 0, 1: tCheck)
        Set tSC = ..Call(..#LOCKENDPOINT, ..#DELETETYPE, .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            If +pHttpStatus = 409 Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.LockError).#INTRANSACTION, ##class(OcuPilot.Api.LockError).#REASONINTRANSACTION, .pHttpStatus, .pFault)
            Quit
        }
        Set tRemoved = tRemoved + 1
    }
    If $$$ISERR(tSC) Quit tSC
    If (pType = ..#REMOVETYPE) && (tRemoved = 0) Quit ..Absent(pEndpoint, .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("removed", tRemoved, "number")
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every vendor call this port
/// makes goes through here, so a test port overrides this one method to answer a canned listing or
/// record what would be sent.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The owner key <var>pDeleteID</var> names: its third comma piece, or <code>""</code>.</p>
ClassMethod OwnerOf(pDeleteID As %String) As %String
{
    Quit $Piece(pDeleteID, ",", 3)
}

/// <p>The fresh listing, as <code>pByDeleteID(DeleteID) = row</code>: for <var>pOwnerScope</var> 0
/// the rows a <code>LIST</code> filtered by <var>pId</var> answers whose <code>DeleteID</code> is
/// <var>pId</var> exactly; for 1 the rows of a <code>LIST</code> filtered by the owner key, capped at
/// <parameter>MAXOWNERLOCKS</parameter> plus one, whose <code>DeleteID</code>'s owner key is
/// <var>pId</var>'s exactly. A list that fails is its own fault; one that answers no array is a
/// 500.</p>
ClassMethod Listing(pId As %String, pOwnerScope As %Boolean, Output pByDeleteID, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pByDeleteID
    Set tOwner = ..OwnerOf(pId)
    Kill tQuery
    If pOwnerScope {
        Set tQuery(..#FILTERQUERY) = "," _ tOwner _ ","
        Set tQuery(..#MAXROWSQUERY) = ..#MAXOWNERLOCKS + 1
    } Else {
        Set tQuery(..#FILTERQUERY) = pId
    }
    Set tSC = ..Call(..#LOCKENDPOINT, ..#LISTTYPE, .tQuery, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit ..Fail(..#LOCKENDPOINT, 500, $$$ERROR($$$GeneralError, "the lock list answered no array"), .pHttpStatus, .pFault)
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If tRow.%GetTypeOf("DeleteID") '= "string" Continue
        Set tDeleteID = tRow.%Get("DeleteID")
        If tDeleteID = "" Continue
        If pOwnerScope {
            If ..OwnerOf(tDeleteID) '= tOwner Continue
        } ElseIf tDeleteID '= pId {
            Continue
        }
        Set pByDeleteID(tDeleteID) = tRow
    }
    Quit $$$OK
}

/// <p><parameter>ROWTYPE</parameter>'s answer for the listed row <var>pRow</var>.</p>
ClassMethod RowAnswer(pRow As %DynamicObject) As %DynamicObject
{
    Set tAnswer = {}
    Do tAnswer.%Set("DeleteID", pRow.%Get("DeleteID"), "string")
    Do ..Copy(pRow, tAnswer, "Pid")
    Do tAnswer.%Set("Owner", ..OwnerOf(pRow.%Get("DeleteID")), "string")
    Do tAnswer.%Set("RemoteOwner", ''pRow.%Get("RemoteOwner"), "boolean")
    For tName = "Reference", "ModeCount", "Directory", "System" Do ..Copy(pRow, tAnswer, tName)
    Do tAnswer.%Set(..#OVERRIDEFIELD, "", "null")
    Quit tAnswer
}

/// <p><parameter>OWNERTYPE</parameter>'s answer for the target <var>pId</var> over the owner's
/// listed rows <var>pByDeleteID</var>, both lists in <code>DeleteID</code> order.</p>
ClassMethod OwnerAnswer(pId As %String, ByRef pByDeleteID) As %DynamicObject
{
    Set tTarget = pByDeleteID(pId)
    Set tAnswer = {}
    Do tAnswer.%Set("DeleteID", pId, "string")
    Do ..Copy(tTarget, tAnswer, "Pid")
    Do tAnswer.%Set("Owner", ..OwnerOf(pId), "string")
    Do tAnswer.%Set("RemoteOwner", ''tTarget.%Get("RemoteOwner"), "boolean")
    Set tIds = []
    Set tLocks = []
    Set tDeleteID = ""
    For {
        Set tDeleteID = $Order(pByDeleteID(tDeleteID), 1, tRow)
        If tDeleteID = "" Quit
        Do tIds.%Push(tDeleteID, "string")
        Set tLock = {}
        Do tLock.%Set("DeleteID", tDeleteID, "string")
        For tName = "Reference", "ModeCount", "Directory" Do ..Copy(tRow, tLock, tName)
        Do tLocks.%Push(tLock)
    }
    Do tAnswer.%Set("DeleteIDs", tIds)
    Do tAnswer.%Set("Locks", tLocks)
    Do tAnswer.%Set(..#OVERRIDEFIELD, "", "null")
    Quit tAnswer
}

/// <p>Copy <var>pFrom</var>'s member <var>pName</var> onto <var>pTo</var> in its own JSON type, or as
/// <code>""</code> where it is absent.</p>
ClassMethod Copy(pFrom As %DynamicObject, pTo As %DynamicObject, pName As %String) [ Private ]
{
    Set tType = pFrom.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "object") || (tType = "array") {
        Do pTo.%Set(pName, "", "string")
        Quit
    }
    Do pTo.%Set(pName, pFrom.%Get(pName), tType)
}

/// <p>The ids <var>pQuery</var>'s <parameter>IDSQUERY</parameter> names, as a <class>%List</class> of
/// non-empty strings, or the <parameter>IDPARAM</parameter> id alone where it names none.</p>
ClassMethod IdsOf(ByRef pQuery) As %List
{
    Set tIds = ""
    Try {
        Set tArray = ##class(%DynamicAbstractObject).%FromJSON($Get(pQuery(..#IDSQUERY)))
        If '$IsObject(tArray) || 'tArray.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tArray.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tValue) {
            If $IsObject(tValue) || (tValue = "") || (tArray.%GetTypeOf(tIndex) '= "string") Continue
            If '$ListFind(tIds, tValue) Set tIds = tIds _ $ListBuild(tValue)
        }
    } Catch {
        Set tIds = ""
    }
    If (tIds = "") && ($Get(pQuery(..#IDPARAM)) '= "") Set tIds = $ListBuild(pQuery(..#IDPARAM))
    Quit tIds
}

/// <p>The in-transaction check <var>pQuery</var> asks for: <code>0</code> where
/// <parameter>CHECKTXNQUERY</parameter> reads <code>0</code>, <code>1</code> otherwise.</p>
ClassMethod CheckTxnOf(ByRef pQuery) As %Integer
{
    Quit $Select($Get(pQuery(..#CHECKTXNQUERY), 1) = "0": 0, 1: 1)
}

/// <p>The 404 an id no listed lock carries answers: <code>PORT.NOTFOUND</code>, logging nothing,
/// since nothing was sent to the vendor.</p>
ClassMethod Absent(pEndpoint As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
}

/// <p><code>rest</code> for <parameter>REMOVETYPE</parameter> and <parameter>REMOVEOWNERTYPE</parameter>,
/// whose script is the vendor's own <code>DELETE</code>, and the admin port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#LOCKENDPOINT) && ((pType = ..#REMOVETYPE) || (pType = ..#REMOVEOWNERTYPE)) Quit "rest"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s writes as a script (AD-59): one <code>Lock</code> <code>DELETE</code>
/// step per stored id, in order, each with the in-transaction check the stored proposal carries.
/// Every other call is the admin port's script. Nothing here reads the instance.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#LOCKENDPOINT) || ((pType '= ..#REMOVETYPE) && (pType '= ..#REMOVEOWNERTYPE)) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tSteps = []
    Set tIds = $Select(pType = ..#REMOVETYPE: $Select($Get(pQuery(..#IDPARAM)) = "": "", 1: $ListBuild(pQuery(..#IDPARAM))), 1: ..IdsOf(.pQuery))
    Set tCheck = ..CheckTxnOf(.pQuery)
    For tI = 1:1:$ListLength(tIds) {
        Kill tQuery
        Set tQuery(..#IDPARAM) = $List(tIds, tI)
        Set tQuery(..#CHECKTXNQUERY) = tCheck
        Set tStep = ..RestStep(..#LOCKENDPOINT, ..#DELETETYPE, .tQuery, "", pContext)
        If $IsObject(tStep) Do tSteps.%Push(tStep)
    }
    Quit tSteps
}

}
