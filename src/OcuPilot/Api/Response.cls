/// <p>The success half of OcuPilot's one response envelope (AD-12).</p>
/// <p>This class and <class>OcuPilot.Api.Error</class> are the <b>only</b> classes in the
/// tree permitted to <code>Write</code> to the response device. Handlers never
/// <code>Write</code> directly — success goes through <method>JSON</method> /
/// <method>JSONStatus</method>; failure through <class>OcuPilot.Api.Error</class>.</p>
Class OcuPilot.Api.Response Extends %RegisteredObject
{

/// <p>Write a JSON success response with HTTP 200.</p>
/// <p>If <var>pData</var> is an object (<class>%DynamicObject</class> or
/// <class>%DynamicArray</class>), calls <method>%ToJSON</method>. Otherwise writes the
/// raw string value.</p>
ClassMethod JSON(pData) As %Status
{
    Set %response.ContentType = "application/json"
    If $IsObject(pData) {
        Write pData.%ToJSON()
    } Else {
        Write pData
    }
    Quit $$$OK
}

/// <p>Write a JSON response with a specific HTTP status code.</p>
ClassMethod JSONStatus(pStatus As %Integer, pData) As %Status
{
    Set %response.Status = pStatus
    Quit ..JSON(pData)
}

}
