/// <p>A test-only OAuth 2.0 issuer inside the instance: <method>Start</method> JOBs a TCP responder
/// bound to <code>localhost:&lt;port&gt;</code>, so the instance's own discovery and JWKS fetches
/// reach it with no internet and no web application. <method>Stop</method> ends it.</p>
/// <p>Its port listens from <method>Start</method> to <method>Stop</method>. It answers one request
/// per connection, waits the linger <method>Start</method> was given, then ends that connection and
/// accepts the next, so a client that connects while an earlier one is being answered waits its
/// turn. It answers these paths:</p>
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
/// <li><code>/register</code>: 201 JSON, a dynamic client registration of synthetic
/// <code>client_id</code>, <code>client_secret</code> and <code>registration_access_token</code>
/// values with a <code>registration_client_uri</code> of
/// <code>http://localhost:&lt;port&gt;/register/&lt;client_id&gt;</code>
/// (<method>Registration</method>). The SHA-256 of the request's <code>Authorization</code> header,
/// Base64-encoded, is kept in <code>^IRIS.Temp.OcuPilotIssuer(port,"auth")</code>;</li>
/// <li><code>/register/&lt;client_id&gt;</code>, any method: 200 with the same JSON;</li>
/// <li>anything else: 404.</li>
/// </ul>
/// <p>A request body is read to its <code>Content-Length</code> and ignored. The responder's pid
/// lives in <code>^IRIS.Temp.OcuPilotIssuer(port)</code>. Callers run it on a throwaway only, and
/// always <method>Stop</method> it in their teardown.</p>
Class OcuPilot.Test.OAuthIssuerFixture Extends %RegisteredObject
{

/// <p>The port a caller that names none binds.</p>
Parameter DEFAULTPORT As INTEGER = 18764;

/// <p>A port nothing listens on, for the unreachable cause.</p>
Parameter CLOSEDPORT As INTEGER = 18765;

/// <p>The fixed key set <code>/jwks</code> answers: one RSA public key, synthetic.</p>
Parameter JWKS = "{""keys"":[{""kty"":""RSA"",""kid"":""ocupilot-fixture"",""use"":""sig"",""alg"":""RS256"",""e"":""AQAB"",""n"":""0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw""}]}";

/// <p>The synthetic credentials <code>/register</code> issues.</p>
Parameter CLIENTID = "ocupilotprobe000client";

Parameter CLIENTSECRET = "ocupilotprobe000clientsecret";

Parameter ACCESSTOKEN = "ocupilotprobe000registrationtoken";

/// <p>The global holding each running responder's pid, by port.</p>
Parameter STATEGLOBAL = "^IRIS.Temp.OcuPilotIssuer";

/// <p>The issuer a responder on <var>pPort</var> names.</p>
ClassMethod Issuer(pPort As %Integer = {..#DEFAULTPORT}) As %String
{
    Quit "http://localhost:" _ pPort
}

/// <p>Start the responder on <var>pPort</var>, stopping any one already there, and answer its issuer
/// in <var>pIssuer</var>. <var>pLinger</var> is how many seconds it waits after writing each answer
/// before it ends that connection. An error status means nothing is listening.</p>
ClassMethod Start(pPort As %Integer = {..#DEFAULTPORT}, Output pIssuer As %String, pLinger As %Numeric = 0) As %Status
{
    Set pIssuer = ""
    Set tSC = ..Stop(pPort)
    If $$$ISERR(tSC) Quit tSC
    Kill @..#STATEGLOBAL@(pPort)
    Job ..Serve(pPort, +pLinger)::10
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

/// <p>The responder's loop: open the listening port once, then, until <method>Stop</method> asks it
/// to end, hand each connection the port accepts to a device of its own
/// (<code>$SYSTEM.Socket.Fork</code>), answer one request there, wait <var>pLinger</var> seconds and
/// close that device. The listening port stays open throughout and closes only when the loop ends.
/// Runs in its own job.</p>
ClassMethod Serve(pPort As %Integer, pLinger As %Numeric = 0)
{
    Set tDevice = "|TCP|" _ pPort
    Set tConnection = "|TCP|1"
    Set tGlobal = ..#STATEGLOBAL
    Try {
        Open tDevice:(:pPort:"SA":$Char(10)):5
        If '$Test {
            Set @tGlobal@(pPort, "ready") = "the port could not be opened"
            Quit
        }
        Set @tGlobal@(pPort) = $Job
        Set @tGlobal@(pPort, "ready") = 1
        For {
            If $Get(@tGlobal@(pPort, "stop")) Quit
            ; Wait at most a second for a connection, so a stop request is seen within one.
            Set tReady = $SYSTEM.Socket.Select($ListBuild(tDevice), 1)
            If (tReady = "") || (tReady = -1) Continue
            If '$SYSTEM.Socket.Fork(tDevice, tConnection) Continue
            Try {
                Use tConnection:(::"S":$Char(10))
                Do ..Converse(pPort)
                If pLinger > 0 Hang pLinger
            } Catch {
            }
            Close tConnection
        }
    } Catch {
    }
    Try {
        Close tConnection
    } Catch {
    }
    Try {
        Close tDevice
    } Catch {
    }
    Kill @tGlobal@(pPort)
}

/// <p>Read one request from the current device, a connection of the responder on <var>pPort</var>,
/// and write its answer there by a stream, flushed so the client has the whole answer before the
/// connection ends. A connection that sends no request line within five seconds is answered
/// nothing.</p>
ClassMethod Converse(pPort As %Integer)
{
    Set tGlobal = ..#STATEGLOBAL
    Read tLine:5
    If '$Test Quit
    Set tPath = $Piece($ZStrip(tLine, ">", $Char(13)), " ", 2)
    ; The headers, up to the blank line: the body's length and the registration's bearer.
    Set tLength = 0
    Set tAuthorization = ""
    For tI = 1:1:100 {
        Read tHeader:2
        If '$Test Quit
        Set tHeader = $ZStrip(tHeader, ">", $Char(13))
        If tHeader = "" Quit
        Set tName = $ZConvert($ZStrip($Piece(tHeader, ":", 1), "<>W"), "L")
        If tName = "content-length" Set tLength = +$ZStrip($Piece(tHeader, ":", 2, *), "<>W")
        If tName = "authorization" Set tAuthorization = $ZStrip($Piece(tHeader, ":", 2, *), "<>W")
    }
    ; The body is drained so the client's write completes; its content is not read.
    Set tDrained = 0
    While (tDrained < tLength) {
        Read tChunk#(tLength - tDrained):2
        Set tEnded = $Test
        ; A line feed ends the read and is not in the chunk, but it was one byte of the body.
        Set tDrained = tDrained + $Length(tChunk) + ($ZB = $Char(10))
        If 'tEnded && (tChunk = "") Quit
    }
    If tPath = "/register" Set @tGlobal@(pPort, "auth") = $System.Encryption.Base64Encode($System.Encryption.SHAHash(256, tAuthorization))
    Set tAuthorization = ""
    Do ..Answer(pPort, tPath, .tStatus, .tType, .tBody)
    Set tResponse = ##class(%Stream.TmpCharacter).%New()
    Do tResponse.Write("HTTP/1.1 " _ tStatus _ $Char(13, 10) _ "Content-Type: " _ tType _ $Char(13, 10))
    Do tResponse.Write("Content-Length: " _ $Length(tBody) _ $Char(13, 10) _ "Connection: close" _ $Char(13, 10, 13, 10))
    Do tResponse.Write(tBody)
    Do tResponse.OutputToDevice()
    Set tResponse = ""
    Do ##class(%IO.DeviceStream).AttachNew($IO).Flush()
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
    } ElseIf pPath = "/register" {
        Set pStatus = "201 Created"
        Set pBody = ..Registration(pPort).%ToJSON()
    } ElseIf pPath = ("/register/" _ ..#CLIENTID) {
        Set pBody = ..Registration(pPort).%ToJSON()
    } Else {
        Set pStatus = "404 Not Found"
        Set pType = "text/plain"
        Set pBody = "not found"
    }
}

/// <p>The registration the fixture on <var>pPort</var> answers: synthetic credentials and the URI
/// the client's later updates go to.</p>
ClassMethod Registration(pPort As %Integer) As %DynamicObject
{
    Set tRegistration = {}
    Do tRegistration.%Set("client_id", ..#CLIENTID, "string")
    Do tRegistration.%Set("client_secret", ..#CLIENTSECRET, "string")
    Do tRegistration.%Set("client_secret_expires_at", 0, "number")
    Do tRegistration.%Set("registration_access_token", ..#ACCESSTOKEN, "string")
    Do tRegistration.%Set("registration_client_uri", ..Issuer(pPort) _ "/register/" _ ..#CLIENTID, "string")
    Quit tRegistration
}

/// <p>The Base64 SHA-256 of the <code>Authorization</code> header the last <code>/register</code>
/// request on <var>pPort</var> carried, or <code>""</code> when none arrived.</p>
ClassMethod LastAuthorizationHash(pPort As %Integer = {..#DEFAULTPORT}) As %String
{
    Quit $Get(@..#STATEGLOBAL@(pPort, "auth"))
}

/// <p>The Base64 SHA-256 a <code>Bearer</code> header carrying <var>pToken</var> hashes to, for
/// comparison with <method>LastAuthorizationHash</method>.</p>
ClassMethod BearerHash(pToken As %String) As %String
{
    Quit $System.Encryption.Base64Encode($System.Encryption.SHAHash(256, "Bearer " _ pToken))
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
