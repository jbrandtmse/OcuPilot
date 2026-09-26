/// <p>The OAuth 2.0 token revoke's port (AD-52): <class>OcuPilot.Port.AdminPort</class> with the
/// authorization server's revoke addressed through the account that holds the tokens. On
/// <parameter>TOKENENDPOINT</parameter> it answers the read type <parameter>HOLDERTYPE</parameter>
/// from <code>Security.User</code> <code>LIST</code>, and sends <parameter>REVOKETYPE</parameter>
/// under the account's stored name. Every other endpoint and request type is the admin port's own
/// call, unchanged.</p>
/// <p><b>Why the read is the account.</b> The revoke's target is a user, and no admin endpoint reads
/// token state: the proposal's fresh read, the confirm's re-read, the prohibited set's live read and
/// the screen caller's read are all the account's own <code>LIST</code> row, narrowed by the
/// vendor's <code>names</code> parameter to the one row whose <code>Name</code> equals the id
/// without regard to case. <code>Security.User</code> <code>GET</code> answers no <code>Name</code>,
/// so it cannot supply the spelling the revoke needs.</p>
/// <p><b>Why the stored name.</b> The vendor deletes tokens whose <code>Username</code> equals the
/// query exactly, while the id a proposal carries is folded to lower case (AD-13). The revoke is
/// therefore sent under the <code>Name</code> the <code>LIST</code> row carries, and an id no row
/// names -- a wildcard among them -- is a 404 with nothing sent.</p>
/// <p><b>It names no administration API class.</b> Both calls go through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so each endpoint's own gate, the stubs, the
/// namespace switch and the fault mapping are the admin port's, and AD-27's one-file containment
/// is unchanged.</p>
Class OcuPilot.Port.TokenPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint whose read and revoke this port addresses through the account.</p>
Parameter TOKENENDPOINT = "Security.OAuth2.Server";

/// <p>The read type this port answers itself: the account that holds the tokens.</p>
Parameter HOLDERTYPE = "HOLDER";

/// <p>The vendor's revoke request type, sent under the account's stored name.</p>
Parameter REVOKETYPE = "REVOKE";

/// <p>The query parameter the tool names the account by, which is also the vendor's own for
/// <parameter>REVOKETYPE</parameter>.</p>
Parameter USERQUERY = "user";

/// <p>The endpoint and request type the account is read from, and the query parameter that narrows
/// it.</p>
Parameter USERENDPOINT = "Security.User";

Parameter USERLISTTYPE = "LIST";

Parameter USERLISTQUERY = "names";

/// <p>The admin port's call, with <parameter>TOKENENDPOINT</parameter>'s
/// <parameter>HOLDERTYPE</parameter> and <parameter>REVOKETYPE</parameter> resolved through the
/// account <code>pQuery("user")</code> names.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>HOLDERTYPE</parameter> answers the
/// account's <code>LIST</code> row. <parameter>REVOKETYPE</parameter> reads the same row, then sends
/// the vendor's revoke with <code>user</code> set to the row's <code>Name</code>, on a copy of
/// <var>pQuery</var>. An id no row names is an error status at 404 on the <code>not_found</code>
/// slug, and a revoke is then never sent; a refused <code>LIST</code> answers exactly as the admin
/// port does.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint '= ..#TOKENENDPOINT) || ((pType '= ..#HOLDERTYPE) && (pType '= ..#REVOKETYPE)) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tId = $Get(pQuery(..#USERQUERY))
    If tId = "" Quit ..Fail(..#USERENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Kill tList
    Set tList(..#USERLISTQUERY) = tId
    Set tSC = ##super(..#USERENDPOINT, ..#USERLISTTYPE, .tList, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tHolder = ..Holder(tId, $Get(tRows))
    If '$IsObject(tHolder) Quit ..Fail(..#USERENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    If pType = ..#HOLDERTYPE {
        Set pResult = tHolder
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Kill tQuery
    Merge tQuery = pQuery
    Set tQuery(..#USERQUERY) = tHolder.%Get("Name")
    Quit ##super(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The one row of <var>pRows</var> -- a <code>Security.User</code> <code>LIST</code> answer --
/// whose <code>Name</code> equals <var>pId</var> without regard to case, or <code>""</code>. The
/// vendor's <code>names</code> parameter matches a pattern, so the rows it answers are narrowed
/// here to the exact account.</p>
ClassMethod Holder(pId As %String, pRows) As %DynamicObject
{
    Set tHolder = ""
    If '$IsObject(pRows) || 'pRows.%IsA("%Library.DynamicArray") Quit tHolder
    Set tWanted = $ZConvert(pId, "L")
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If tRow.%GetTypeOf("Name") '= "string" Continue
        If $ZConvert(tRow.%Get("Name"), "L") '= tWanted Continue
        Set tHolder = tRow
        Quit
    }
    Quit tHolder
}

}
