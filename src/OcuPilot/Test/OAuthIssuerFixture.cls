/// <p>A test-only OAuth 2.0 issuer inside the instance: <method>Start</method> JOBs a TCP responder
/// bound to <code>localhost:&lt;port&gt;</code>, so the instance's own discovery and JWKS fetches
/// reach it with no internet and no web application. <method>Stop</method> ends it.</p>
/// <p>It answers these paths, each once per connection and then closes it:</p>
/// <ul>
/// <li><code>/.well-known/openid-configuration</code>: 200 JSON naming issuer
/// <code>http://localhost:&lt;port&gt;</code>, both required endpoints, the userinfo endpoint,
/// <code>jwks_uri</code>, two lists and one boolean (<method>Document</method>);</li>
/// <li><code>/jwks</code>: 200 JSON, a fixed one-key set (<parameter>JWKS</parameter>);</li>
/// <li><code>/wrong-issuer/.well-known/openid-configuration</code>: 200 JSON whose issuer claim
/// is another issuer;</li>
/// <li><code>/status/.well-known/openid-configuration</code>: 503;</li>
/// <li><code>/not-json/.well-known/openid-configuration</code>: 200 <code>text/html</code>;</li>
/// <li><code>/bad-json/.well-known/openid-configuration</code>: 200 JSON that does not parse;</li>
/// <li>anything else: 404.</li>
/// </ul>
/// <p>The responder's pid lives in <code>^IRIS.Temp.OcuPilotIssuer(port)</code>. Callers run it on a
/// throwaway only, and always <method>Stop</method> it in their teardown.</p>
Class OcuPilot.Test.OAuthIssuerFixture Extends %RegisteredObject
{

/// <p>The port a caller that names none binds.</p>
Parameter DEFAULTPORT As INTEGER = 18764;

/// <p>A port nothing listens on, for the unreachable cause.</p>
Parameter CLOSEDPORT As INTEGER = 18765;

/// <p>The fixed key set <code>/jwks</code> answers: one RSA public key, synthetic.</p>
Parameter JWKS = "{""keys"":[{""kty"":""RSA"",""kid"":""ocupilot-fixture"",""use"":""sig"",""alg"":""RS256"",""e"":""AQAB"",""n"":""0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw""}]}";

/// <p>The global holding each running responder's pid, by port.</p>
Parameter STATEGLOBAL = "^IRIS.Temp.OcuPilotIssuer";

/// <p>The issuer a responder on <var>pPort</var> names.</p>
ClassMethod Issuer(pPort As %Integer = {..#DEFAULTPORT}) As %String
{
    Quit "http://localhost:" _ pPort
}

/// <p>Start the responder on <var>pPort</var>, stopping any one already there, and answer its issuer
/// in <var>pIssuer</var>. An error status means nothing is listening.</p>
ClassMethod Start(pPort As %Integer = {..#DEFAULTPORT}, Output pIssuer As %String) As %Status
{
    Set pIssuer = ""
    Set tSC = ..Stop(pPort)
    If $$$ISERR(tSC) Quit tSC
    Kill @..#STATEGLOBAL@(pPort)
    Job ..Serve(pPort)::10
    If '$Test Quit $$$ERROR($$$GeneralError, "the issuer fixture could not be started")
    Set tDeadline = $ZHorolog + 5
    While ($Get(@..#STATEGLOBAL@(pPort, "ready")) = "") && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    Set tReady = $Get(@..#STATEGLOBAL@(pPort, "ready"))
    If tReady '= 1 Quit $$$ERROR($$$GeneralError, "the issuer fixture did not listen on port " _ pPort _ ": " _ tReady)
    Set pIssuer = ..Issuer(pPort)
    Quit $$$OK
}

/// <p>Stop the responder on <var>pPort</var>, if one runs, and wait until it has closed its port.</p>
ClassMethod Stop(pPort As %Integer = {..#DEFAULTPORT}) As %Status
{
    Set tPid = $Get(@..#STATEGLOBAL@(pPort))
    If tPid = "" Quit $$$OK
    Set @..#STATEGLOBAL@(pPort, "stop") = 1
    Set tDeadline = $ZHorolog + 5
    While $Data(@..#STATEGLOBAL@(pPort)) && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    If $Data(@..#STATEGLOBAL@(pPort)) {
        Kill @..#STATEGLOBAL@(pPort)
        Quit $$$ERROR($$$GeneralError, "the issuer fixture on port " _ pPort _ " did not stop")
    }
    Quit $$$OK
}

/// <p>Whether a responder is running on <var>pPort</var>.</p>
ClassMethod Running(pPort As %Integer = {..#DEFAULTPORT}) As %Boolean
{
    Quit ($Get(@..#STATEGLOBAL@(pPort, "ready")) = 1)
}

/// <p>The responder's loop: listen, read one request, answer it, close and listen again, until
/// <method>Stop</method> asks it to end. Runs in its own job. The answer is written to the connection
/// by a stream, and closing the device ends the connection.</p>
ClassMethod Serve(pPort As %Integer)
{
    Set tDevice = "|TCP|" _ pPort
    Set tGlobal = ..#STATEGLOBAL
    Set tListening = 0
    Try {
        For {
            If $Get(@tGlobal@(pPort, "stop")) Quit
            Open tDevice:(:pPort:"S":$Char(10)):5
            If '$Test {
                If 'tListening Set @tGlobal@(pPort, "ready") = "the port could not be opened"
                Quit
            }
            If 'tListening {
                Set @tGlobal@(pPort) = $Job
                Set @tGlobal@(pPort, "ready") = 1
                Set tListening = 1
            }
            Use tDevice
            ; Wait for a request line, keeping the port listening across idle seconds so a client
            ; that connects between two of them is not dropped.
            Set tLine = ""
            Set tRead = 0
            For {
                Read tPart:1
                Set tRead = $Test
                Set tLine = tLine _ tPart
                If tRead || $Get(@tGlobal@(pPort, "stop")) Quit
            }
            If 'tRead Quit
            Set tPath = $Piece($ZStrip(tLine, ">", $Char(13)), " ", 2)
            ; The headers, up to the blank line; the fixture needs none of them.
            For tI = 1:1:100 {
                Read tHeader:2
                If '$Test Quit
                If $ZStrip(tHeader, ">", $Char(13)) = "" Quit
            }
            Do ..Answer(pPort, tPath, .tStatus, .tType, .tBody)
            Set tResponse = ##class(%Stream.TmpCharacter).%New()
            Do tResponse.Write("HTTP/1.1 " _ tStatus _ $Char(13, 10) _ "Content-Type: " _ tType _ $Char(13, 10))
            Do tResponse.Write("Content-Length: " _ $Length(tBody) _ $Char(13, 10) _ "Connection: close" _ $Char(13, 10, 13, 10))
            Do tResponse.Write(tBody)
            Do tResponse.OutputToDevice()
            Set tResponse = ""
            Close tDevice
        }
    } Catch {
    }
    Try {
        Close tDevice
    } Catch {
    }
    Kill @tGlobal@(pPort)
}

/// <p>What the fixture on <var>pPort</var> answers for <var>pPath</var>: the HTTP status line's
/// code and phrase, the content type and the body.</p>
ClassMethod Answer(pPort As %Integer, pPath As %String, Output pStatus As %String, Output pType As %String, Output pBody As %String)
{
    Set pStatus = "200 OK"
    Set pType = "application/json"
    Set tWellKnown = "/.well-known/openid-configuration"
    If pPath = tWellKnown {
        Set pBody = ..Document(pPort, ..Issuer(pPort)).%ToJSON()
    } ElseIf pPath = "/jwks" {
        Set pBody = ..#JWKS
    } ElseIf pPath = ("/wrong-issuer" _ tWellKnown) {
        Set pBody = ..Document(pPort, "http://localhost:" _ pPort _ "/another-issuer").%ToJSON()
    } ElseIf pPath = ("/status" _ tWellKnown) {
        Set pStatus = "503 Service Unavailable"
        Set pType = "text/plain"
        Set pBody = "unavailable"
    } ElseIf pPath = ("/bad-json" _ tWellKnown) {
        Set pBody = "{""issuer"": "
    } ElseIf pPath = ("/not-json" _ tWellKnown) {
        Set pType = "text/html"
        Set pBody = "<html><body>not a discovery document</body></html>"
    } Else {
        Set pStatus = "404 Not Found"
        Set pType = "text/plain"
        Set pBody = "not found"
    }
}

/// <p>The discovery document the fixture on <var>pPort</var> publishes, naming issuer
/// <var>pIssuer</var>.</p>
ClassMethod Document(pPort As %Integer, pIssuer As %String) As %DynamicObject
{
    Set tBase = ..Issuer(pPort)
    Set tDocument = {}
    Do tDocument.%Set("issuer", pIssuer, "string")
    Do tDocument.%Set("authorization_endpoint", tBase _ "/authorize", "string")
    Do tDocument.%Set("token_endpoint", tBase _ "/token", "string")
    Do tDocument.%Set("userinfo_endpoint", tBase _ "/userinfo", "string")
    Do tDocument.%Set("jwks_uri", tBase _ "/jwks", "string")
    Do tDocument.%Set("scopes_supported", ["openid", "profile"])
    Do tDocument.%Set("response_types_supported", ["code"])
    Do tDocument.%Set("claims_parameter_supported", 1, "boolean")
    Quit tDocument
}

}
