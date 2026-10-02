/// <p>The request stub <class>OcuPilot.Port.AtelierPort</class> hands a route that reads its body
/// and refuses any content type but <code>application/json</code> (AD-61, rule 3). The vendor
/// request's own content-type setter is private, so this subclass sets the property's storage
/// directly. Nothing but the port constructs it.</p>
/// <p><b>Caller contract:</b> call <method>SetJsonBody</method> in the caller's own namespace,
/// before any namespace switch; a route reads only the two properties it sets.</p>
Class OcuPilot.Port.AtelierRequest Extends %CSP.Request
{

/// <p>Make <var>pJson</var>, a JSON text, this request's body, with content type
/// <code>application/json</code>. The body is a process-private character stream, so it reads
/// the same in whichever namespace the route runs.</p>
Method SetJsonBody(pJson As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tStream = ##class(%CSP.CharacterStream).%New()
        Set tSC = tStream.Write(pJson)
        If $$$ISERR(tSC) Quit
        Do tStream.Rewind()
        Set i%ContentType = "application/json"
        Set ..Content = tStream
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
