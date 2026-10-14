/// <p>The success half of OcuPilot's one response envelope (AD-12).</p>
/// <p>This class and <class>OcuPilot.Api.Error</class> are the <b>only</b> classes in the
/// tree permitted to <code>Write</code> to the response device. Handlers never
/// <code>Write</code> directly — success goes through <method>JSON</method> /
/// <method>JSONStatus</method>, a held live tail's heartbeat through <method>Heartbeat</method>; failure
/// through <class>OcuPilot.Api.Error</class>.</p>
Class OcuPilot.Api.Response Extends %RegisteredObject
{

/// <p>Write a JSON success response with HTTP 200.</p>
/// <p>If <var>pData</var> is an object (<class>%DynamicObject</class> or
/// <class>%DynamicArray</class>), serializes it into a stream and writes the stream out, so an
/// answer longer than one ObjectScript string still goes out whole. Otherwise writes the raw
/// string value.</p>
ClassMethod JSON(pData) As %Status
{
    Set %response.ContentType = "application/json"
    If $IsObject(pData) {
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Do pData.%ToJSON(tStream)
        Do tStream.Rewind()
        Do tStream.OutputToDevice()
    } Else {
        Write pData
    }
    Quit $$$OK
}

/// <p>Write one heartbeat of a held JSON response (AD-12's second carve-out) and flush it: the JSON
/// content type, one newline, which JSON reads as nothing before the route's one envelope, and a
/// flush to the gateway. The first heartbeat also turns the gateway's compression off and its output
/// flushing on; without both the gateway holds every beat until the envelope for a client that accepts
/// gzip, which every browser does. Those and the status are fixed from the first flush on, so a caller
/// refuses before its first heartbeat and answers only its envelope after. Answers the flush's status,
/// which the vendor answers OK even after the client has disconnected, so a dropped client is not seen
/// here.</p>
ClassMethod Heartbeat() As %Status
{
    If '%response.InProgress {
        Set %response.ContentType = "application/json"
        Set %response.GzipOutput = 0
        Set %response.AllowOutputFlush = 1
    }
    Write $Char(10)
    Quit %response.Flush()
}

/// <p>Write a JSON response with a specific HTTP status code.</p>
ClassMethod JSONStatus(pStatus As %Integer, pData) As %Status
{
    Set %response.Status = pStatus
    Quit ..JSON(pData)
}

}
