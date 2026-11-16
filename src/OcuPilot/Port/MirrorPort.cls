/// <p>The mirror port (AD-29, AD-36, Story 21.12): the one product class that reads the instance's mirror state and, on a
/// mirror member, the members of its mirror with each one's role, status and latencies. It switches <code>$NAMESPACE</code> to
/// <code>%SYS</code> by save and restore around the vendor query (AD-16). It writes nothing.</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, evaluated through <method>GateClass</method> in the
/// calling process before any vendor call. A caller missing one is refused 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>.</p>
/// <p><b>Endpoints.</b> <parameter>STATEENDPOINT</parameter> answers one object for <code>GET</code>:
/// <code>{State, MirrorName}</code>, <code>State</code> being <code>Failover</code> or <code>Async</code> on a member, otherwise
/// <code>Unlicensed</code> when the license does not allow mirroring and <code>NotMember</code> when it does.
/// <parameter>MEMBERSENDPOINT</parameter> answers rows for <code>LIST</code>: <code>{MemberName, CurrentRole, CurrentStatus,
/// JournalLatency, DatabaseLatency}</code>, and answers none, without calling the vendor, on an instance that is not a member,
/// where the vendor query refuses. Every other endpoint and request type is refused as not implemented.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>, <method>Membership</method> and
/// <method>MemberRows</method>. Production overrides none of them.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on
/// return.</p>
Class OcuPilot.Port.MirrorPort Extends %RegisteredObject
{

/// <p>The pair set every read requires, comma-separated as <code>resource:permission</code>, in the order the gate
/// reports in (AD-8, AD-29).</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints a screen's read lists, in <code>LIST</code>.</p>
Parameter ENDPOINTS = "Members";

Parameter MEMBERSENDPOINT = "Members";

Parameter STATEENDPOINT = "State";

/// <p>The fields of a member row, in the order <method>RowFor</method> reads its values.</p>
Parameter FIELDS = "MemberName,CurrentRole,CurrentStatus,JournalLatency,DatabaseLatency";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

/// <p>The query key a list is read under, and the cap a list that names none is read under.</p>
Parameter MAXROWSKEY = "maxRows";

Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The values <code>State</code> answers.</p>
Parameter STATEFAILOVER = "Failover";

Parameter STATEASYNC = "Async";

Parameter STATENOTMEMBER = "NotMember";

Parameter STATEUNLICENSED = "Unlicensed";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "mirrorport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in process;
/// production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line;
/// production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The instance's mirror membership: <var>pMember</var> is <code>$System.Mirror.IsMember()</code> (0 not a member, 1 a
/// failover member, 2 an async member) and <var>pNoMirror</var> is <code>$System.License.NoMirror()</code> (1 when the license
/// does not allow mirroring), both read live. Overridable so a fixture can arm a member; production never overrides it.</p>
ClassMethod Membership(Output pMember As %Integer, Output pNoMirror As %Boolean)
{
    Set pMember = +$System.Mirror.IsMember()
    Set pNoMirror = ''$System.License.NoMirror()
}

/// <p>The member rows of this instance's mirror in <var>pRows</var>, at most <var>pMax</var> of them, each
/// <code>{MemberName, CurrentRole, CurrentStatus, JournalLatency, DatabaseLatency}</code> as text, from the vendor's
/// <code>SYS.Mirror:MemberStatusList</code> run in <code>%SYS</code>. Called only on a member. Overridable so a fixture can arm
/// rows; production never overrides it.</p>
ClassMethod MemberRows(pMax As %Integer, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("SYS.Mirror:MemberStatusList")
        Set tSC = tRS.Execute("")
        While $$$ISOK(tSC) && (pRows.%Size() < pMax) && tRS.Next() {
            Set tValues = ""
            For tI = 1:1:$Length(..#FIELDS, ",") Set tValues = tValues _ $ListBuild(tRS.Get($Piece(..#FIELDS, ",", tI)))
            Do pRows.%Push(..RowFor(tValues))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The member row <var>pValues</var> makes: one text field for each of <parameter>FIELDS</parameter>, in that order, from a
/// <class>%List</class> of the vendor's column values.</p>
ClassMethod RowFor(pValues As %List) As %DynamicObject
{
    Set tRow = {}
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Do tRow.%Set($Piece(..#FIELDS, ",", tI), $ListGet(pValues, tI) _ "", "string")
    }
    Quit tRow
}

/// <p>The pairs <var>pSpec</var> names as the <code>%List</code> the gate evaluates.</p>
ClassMethod Pairs(pSpec As %String) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(pSpec)
}

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint = ..#MEMBERSENDPOINT Quit (pType = ..#TYPELIST)
    If pEndpoint = ..#STATEENDPOINT Quit (pType = ..#TYPEGET)
    Quit 0
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A <code>LIST</code> answers <var>pResult</var> as an array of rows, at most <parameter>DEFAULTMAXROWS</parameter> unless
/// <var>pQuery</var> carries <parameter>MAXROWSKEY</parameter>; a <code>GET</code> answers one object. <var>pBody</var> must be
/// empty.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; 400 <code>PORT.VALIDATION</code> for a cap of the
/// wrong shape; and 500 <code>INTERNAL</code>, logged, for a body or any failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(.pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a mirror call takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..Listing($Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..State(.pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>The rows of the list <var>pEndpoint</var> names, after the read gate, at most <var>pMax</var> of them: the call the
/// screens' and the read tools' reads are issued through (AD-36). Otherwise <method>Invoke</method>'s answers.</p>
ClassMethod Rows(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Admit(.pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Listing(pMax, .pRows, .pHttpStatus, .pFault)
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The gate: <parameter>PAIRS</parameter>.</p>
ClassMethod Admit(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(..#PAIRS), .tFailedPair) Quit $$$OK
    Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
}

/// <p>The member rows, at most <var>pMax</var>: none, without a vendor query, unless the instance is a member.</p>
ClassMethod Listing(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = []
    Set pHttpStatus = 200
    Do ..Membership(.tMember, .tNoMirror)
    If '$Select(tMember = 1: 1, tMember = 2: 1, 1: 0) Quit $$$OK
    Set tSC = ..MemberRows(pMax, .tRows)
    If $$$ISERR(tSC) Quit ..Fail("the mirror members could not be read", tSC, .pHttpStatus, .pFault)
    Set pRows = tRows
    Quit $$$OK
}

/// <p>The mirror state in <var>pState</var>: <code>{State, MirrorName}</code>, <code>MirrorName</code> empty on an instance
/// that is not a member.</p>
ClassMethod State(Output pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ..Membership(.tMember, .tNoMirror)
    Set tState = $Select(tMember = 1: ..#STATEFAILOVER, tMember = 2: ..#STATEASYNC, tNoMirror: ..#STATEUNLICENSED, 1: ..#STATENOTMEMBER)
    Set pState = {}
    Do pState.%Set("State", tState, "string")
    Do pState.%Set("MirrorName", $Select((tMember = 1) || (tMember = 2): $System.Mirror.MirrorName() _ "", 1: ""), "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The 403 the gate answers, <code>AUTH.NOPRIVILEGE</code> with the pair in <code>detail.failedPair</code> (AD-8,
/// AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>A refusal this port decided, with a written reason (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
