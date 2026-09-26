/// <p>Pins what each port's <code>Snippet</code> renders for its own branches of
/// <code>Invoke</code> (AD-59): the verb, the route, the query and the body keys of a
/// <code>rest</code> step, and the <code>%SYS</code> call of an <code>objectscript</code> step, one
/// method per port. <class>OcuPilot.Test.DraftRegistry</class> holds that every tool has a form and
/// that no secret is rendered; this class holds that the form is the right one.</p>
/// <p><b>What it needs from the environment:</b> nothing. Every <code>Snippet</code> is pure, so each
/// test calls it with a synthetic query, body and context and reads the text.</p>
Class OcuPilot.Test.DraftPorts Extends %UnitTest.TestCase
{

Parameter ORIGIN = "https://draft.example:52773";

Parameter PREFIX = "https://draft.example:52773/api/admin/v2";

/// <p>A PEM certificate block <method>OcuPilot.Port.AdminPort.PemBlock</method> accepts, whose base64
/// body is <code>TUlJQ0FB</code>.</p>
Parameter PEM = "-----BEGIN CERTIFICATE-----TUlJQ0FB-----END CERTIFICATE-----";

/// <p>The context every call renders with, carrying <var>pPayload</var> and <var>pDiff</var> when
/// given.</p>
ClassMethod Context(pPayload As %DynamicObject = "", pDiff As %DynamicArray = "") As %DynamicObject
{
    Set tContext = {"origin": (..#ORIGIN), "user": "draftuser"}
    If $IsObject(pPayload) Do tContext.%Set("payload", pPayload)
    If $IsObject(pDiff) Do tContext.%Set("diff", pDiff)
    Quit tContext
}

/// <p>Every step of <var>pSteps</var> as <code>kind: text</code>, joined by line feeds.</p>
ClassMethod Text(pSteps As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pSteps) Quit tText
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("kind") _ ": " _ tStep.%Get("text")
    }
    Quit tText
}

/// <p>A terminate that carries the error flag is <class>SYS.Process</class>'s own call; one that
/// does not is the vendor's route, with the flag's parameter dropped.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.ProcessPort.Snippet</method> keep
/// <code>sendError</code> in the query it hands the admin port -- this goes red.</p>
Method TestProcessPort()
{
    Kill tQuery
    Set tQuery("id") = "4711"
    Set tQuery("sendError") = 1
    Set tText = ..Text(##class(OcuPilot.Port.ProcessPort).Snippet("Process", "TERMINATE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "objectscript: ", "the error-flag terminate is ObjectScript: " _ tText)
    Do $$$AssertTrue(tText [ "##class(SYS.Process).%OpenId(""4711"")", "opening the process by its id")
    Do $$$AssertTrue(tText [ "tProcess.Terminate(1)", "and terminating it with the error flag")
    Kill tQuery
    Set tQuery("id") = "4711"
    Set tQuery("sendError") = 0
    Set tText = ..Text(##class(OcuPilot.Port.ProcessPort).Snippet("Process", "TERMINATE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ ("rest: curl -u 'draftuser' -X POST '" _ ..#PREFIX _ "/process/terminate?id=4711'"), "a plain terminate is the vendor's route: " _ tText)
    Do $$$AssertTrue(tText '[ "sendError", "without the flag's parameter")
}

/// <p>The server description is addressed by the vendor's id in place of the issuer, taken from the
/// stored read or left as <code>&lt;ID&gt;</code>; a create carries the issuer in its body and drops
/// the row fields; a key-set refresh is the definition's own call.</p>
Method TestOAuthServerPort()
{
    Set tEndpoint = "Security.OAuth2.Client.ServerDefinition"
    Kill tQuery
    Set tQuery("issuer") = "https://issuer.example"
    Set tText = ..Text(##class(OcuPilot.Port.OAuthServerPort).Snippet(tEndpoint, "DELETE", .tQuery, "", ..Context({"ID": "7"})))
    Do $$$AssertTrue(tText [ ("-X DELETE '" _ ..#PREFIX _ "/security/oauth2/client/server-definition?serverId=7'"), "a delete addresses the vendor's id: " _ tText)
    Do $$$AssertTrue(tText '[ "issuer=", "never the issuer")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthServerPort).Snippet(tEndpoint, "DELETE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "?serverId=<ID>'", "an id the stored read lacks reads as a readable placeholder: " _ tText)
    Set tText = ..Text(##class(OcuPilot.Port.OAuthServerPort).Snippet(tEndpoint, "POST", .tQuery, {"ID": "7", "ClientCount": 2, "Description": "d"}, ..Context()))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/oauth2/client/server-definition'"), "a create has no query: " _ tText)
    Do $$$AssertTrue(tText [ """IssuerEndpoint"":""https://issuer.example""", "and carries the issuer in its body")
    Do $$$AssertTrue((tText '[ """ClientCount""") && (tText '[ """ID"""), "without the row fields")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthServerPort).Snippet(tEndpoint, "REFRESHJWKS", .tQuery, "", ..Context({"ID": "7"})))
    Do $$$AssertTrue(tText [ "##class(OAuth2.ServerDefinition).Open(""7"", .tSC)", "a key-set refresh opens the definition: " _ tText)
    Do $$$AssertTrue(tText [ "RefreshJWKS(1, 1, .tSC)", "and refreshes it")
}

/// <p>An edit sends the body with the secret metadata members removed; a secret change sends each
/// declared secret, the registration token nested under <code>Metadata</code>, and nothing else.</p>
Method TestOAuthClientPort()
{
    Set tEndpoint = "Security.OAuth2.Client.ClientConfiguration"
    Kill tQuery
    Set tQuery("applicationName") = "app1"
    Set tBody = {"ApplicationName": "app1", "Metadata": {"client_secret": "<ClientSecret>", "registration_access_token": "<RegistrationAccessToken>", "client_name": "shown"}}
    Set tText = ..Text(##class(OcuPilot.Port.OAuthClientPort).Snippet(tEndpoint, "PUT", .tQuery, tBody, ..Context()))
    Do $$$AssertTrue(tText [ ("-X PUT '" _ ..#PREFIX _ "/security/oauth2/client/client-configuration?applicationName=app1'"), "an edit is the vendor's PUT: " _ tText)
    Do $$$AssertTrue(tText [ """client_name"":""shown""", "carrying the ordinary metadata")
    Do $$$AssertTrue((tText '[ "client_secret") && (tText '[ "registration_access_token"), "and neither secret member")
    Set tBody = {"ClientSecret": "<ClientSecret>", "RegistrationAccessToken": "<RegistrationAccessToken>", "ApplicationName": "app1"}
    Set tText = ..Text(##class(OcuPilot.Port.OAuthClientPort).Snippet(tEndpoint, "CHANGESECRET", .tQuery, tBody, ..Context()))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/oauth2/client/client-configuration/secrets?applicationName=app1'"), "a secret change is the vendor's route: " _ tText)
    Do $$$AssertTrue(tText [ """ClientSecret"":""<ClientSecret>""", "sending the client secret")
    Do $$$AssertTrue(tText [ """Metadata"":{""registration_access_token"":""<RegistrationAccessToken>""}", "and the token under Metadata")
    Do $$$AssertTrue(tText '[ "ApplicationName", "and nothing else")
}

/// <p>A secret change sends the secret alone; a key-set refresh is the client's own call.</p>
Method TestOAuthRegisteredClientPort()
{
    Set tEndpoint = "Security.OAuth2.ServerClients"
    Kill tQuery
    Set tQuery("clientId") = "abc"
    Set tText = ..Text(##class(OcuPilot.Port.OAuthRegisteredClientPort).Snippet(tEndpoint, "SECRET", .tQuery, {"ClientSecret": "<ClientSecret>", "Name": "n"}, ..Context()))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/oauth2/server/client/secret?clientId=abc'"), "a secret change is the vendor's route: " _ tText)
    Do $$$AssertTrue(tText [ "-d '{""ClientSecret"":""<ClientSecret>""}'", "sending the secret alone")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthRegisteredClientPort).Snippet(tEndpoint, "REFRESHJWKS", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "##class(OAuth2.Server.Client).Open(""abc"", .tSC)", "a key-set refresh opens the client: " _ tText)
    Do $$$AssertTrue(tText [ "tClient.RefreshJWKS(", "and refreshes it")
}

/// <p>Adding and removing a mapping are the mapping endpoint's own routes, keyed by service and key;
/// a secret change sends the secret alone.</p>
/// <p>Mutation (Rule 19): route <code>ADDMAPPING</code> to the resource-server endpoint in
/// <method>OcuPilot.Port.OAuthResourceServerPort.Snippet</method> -- this goes red.</p>
Method TestOAuthResourceServerPort()
{
    Set tEndpoint = "Security.OAuth2.ResourceServer"
    Kill tQuery
    Set tQuery("name") = "res1"
    Set tQuery("service") = "svc1"
    Set tQuery("key") = "k1"
    Set tText = ..Text(##class(OcuPilot.Port.OAuthResourceServerPort).Snippet(tEndpoint, "ADDMAPPING", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ ("-X PUT '" _ ..#PREFIX _ "/security/oauth2/resource-server/mapping?key=k1&service=svc1'"), "adding a mapping is the mapping route: " _ tText)
    Do $$$AssertTrue(tText [ "-d '{""Resource"":""res1""}'", "naming the resource server")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthResourceServerPort).Snippet(tEndpoint, "REMOVEMAPPING", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ ("-X DELETE '" _ ..#PREFIX _ "/security/oauth2/resource-server/mapping?key=k1&service=svc1'"), "removing one is its DELETE: " _ tText)
    Do $$$AssertTrue(tText '[ " -d ", "with no body")
    Kill tQuery
    Set tQuery("name") = "res1"
    Set tText = ..Text(##class(OcuPilot.Port.OAuthResourceServerPort).Snippet(tEndpoint, "CHANGESECRET", .tQuery, {"ClientSecret": "<ClientSecret>", "Other": 1}, ..Context()))
    Do $$$AssertTrue(tText [ "-d '{""ClientSecret"":""<ClientSecret>""}'", "a secret change sends the secret alone: " _ tText)
}

/// <p>A key rotation is the configuration's own call; a password change sends the password alone
/// with no query; a delete has no query.</p>
Method TestOAuthAuthorizationServerPort()
{
    Set tEndpoint = "Security.OAuth2.Server"
    Kill tQuery
    Set tQuery("ignored") = "x"
    Set tText = ..Text(##class(OcuPilot.Port.OAuthAuthorizationServerPort).Snippet(tEndpoint, "ROTATEKEYS", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "##class(OAuth2.Server.Configuration).Open(.tSC)", "a rotation opens the configuration: " _ tText)
    Do $$$AssertTrue(tText [ "tConfiguration.RotateKeys()", "and rotates its keys")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthAuthorizationServerPort).Snippet(tEndpoint, "CHANGEPWD", .tQuery, {"ServerPassword": "<ServerPassword>", "Other": 1}, ..Context()))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/oauth2/server/password' "), "a password change has no query: " _ tText)
    Do $$$AssertTrue(tText [ "-d '{""ServerPassword"":""<ServerPassword>""}'", "and sends the password alone")
    Set tText = ..Text(##class(OcuPilot.Port.OAuthAuthorizationServerPort).Snippet(tEndpoint, "DELETE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ ("-X DELETE '" _ ..#PREFIX _ "/security/oauth2/server'"), "a delete has no query: " _ tText)
}

/// <p>A task edit drops the completing field, and a clock field or settings the diff does not name,
/// which the stored read already holds; a field the diff names is sent.</p>
Method TestTaskPort()
{
    Kill tQuery
    Set tQuery("id") = "12"
    Set tBody = {"Name": "t1", "Type": 2, "DailyStartTime": "08:00:00", "Settings": {"a": "1"}}
    Set tText = ..Text(##class(OcuPilot.Port.TaskPort).Snippet("Task.CRUD", "PUT", .tQuery, tBody, ..Context(, ["Name"])))
    Do $$$AssertTrue(tText [ ("-X PUT '" _ ..#PREFIX _ "/task?id=12'"), "a task edit is the vendor's PUT: " _ tText)
    Do $$$AssertTrue(tText [ "-d '{""Name"":""t1""}'", "sending only what the stored read does not already hold")
    Set tText = ..Text(##class(OcuPilot.Port.TaskPort).Snippet("Task.CRUD", "PUT", .tQuery, tBody, ..Context(, ["DailyStartTime"])))
    Do $$$AssertTrue(tText [ """DailyStartTime"":""08:00:00""", "a clock field the diff names is sent: " _ tText)
}

/// <p>A revoke names the account by the stored read's own name where it carries one.</p>
Method TestTokenPort()
{
    Kill tQuery
    Set tQuery("user") = "typed"
    Set tText = ..Text(##class(OcuPilot.Port.TokenPort).Snippet("Security.OAuth2.Server", "REVOKE", .tQuery, "", ..Context({"Name": "Stored"})))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/oauth2/server/revoke?user=Stored'"), "a revoke names the stored account: " _ tText)
    Set tText = ..Text(##class(OcuPilot.Port.TokenPort).Snippet("Security.OAuth2.Server", "REVOKE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "/security/oauth2/server/revoke?user=typed'", "and the query's own where it carries none: " _ tText)
}

/// <p>A copy and a purge send the body the port composes from the query, and no query.</p>
Method TestAuditPort()
{
    Kill tQuery
    Set tQuery("CopyNamespace") = "USER"
    Set tText = ..Text(##class(OcuPilot.Port.AuditPort).Snippet("Security.Audit.Record", "COPY", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ ("-X POST '" _ ..#PREFIX _ "/security/audit/record/copy' "), "a copy has no query: " _ tText)
    Do $$$AssertTrue(tText [ """AuditCopyNamespace"":""USER""", "and names the namespace in its body")
    Kill tQuery
    Set tQuery("PurgeBefore") = "2026-09-01"
    Set tText = ..Text(##class(OcuPilot.Port.AuditPort).Snippet("Security.Audit.Record", "PURGE", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ """EndDateTime"":""2026-09-01 00:00:00""", "a purge sends its cutoff: " _ tText)
}

/// <p>The admin port's own branches: AD-27's resource and credential completions as ObjectScript,
/// the credential decoded from its PEM body; the wrapper, the constant body and the composite key
/// split of a <code>rest</code> step.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Port.AdminPort.ImportStep</method>'s decode the stored
/// certificate as given -- the decode no longer reads the PEM body and this goes red.</p>
Method TestAdminPort()
{
    Kill tQuery
    Set tQuery("name") = "R1"
    Set tText = ..Text(##class(OcuPilot.Port.AdminPort).Snippet("Security.Resource", "PUT", .tQuery, {"Description": "d", "PublicPermission": ""}, ..Context()))
    Do $$$AssertTrue(tText [ "##class(Security.Resources).Exists(""R1"")", "a resource with no public permission is Security.Resources' own: " _ tText)
    Do $$$AssertTrue(tText [ "Set tProps(""PublicPermission"") = """"", "with the empty permission")

    Kill tQuery
    Set tQuery("alias") = "a1"
    Set tSteps = ##class(OcuPilot.Port.AdminPort).Snippet("Security.X509Credential", "POST", .tQuery, {"Certificate": (..#PEM)}, ..Context())
    Set tText = ..Text(tSteps)
    Do $$$AssertTrue(tText [ "$System.Encryption.Base64Decode(""TUlJQ0FB"")", "a credential import decodes the PEM body: " _ tText)
    Do $$$AssertTrue(tText '[ "BEGIN CERTIFICATE", "never the PEM header")
    Do $$$AssertTrue(tText [ "##class(%SYS.X509Credentials).Exists(""a1"")", "and is refused for an alias already present")
    Set tLiteral = $Piece($Piece(tText, "Base64Decode(""", 2), """)", 1)
    Do $$$AssertEquals($System.Encryption.Base64Decode(tLiteral), "MIICAA", "the decoded certificate is the one the port imports")

    Kill tQuery
    Set tText = ..Text(##class(OcuPilot.Port.AdminPort).Snippet("Security.User", "POST", .tQuery, {"Name": "u1", "Password": "<Password>"}, ..Context({})))
    Do $$$AssertTrue(tText [ """User"":{""Name"":""u1""}", "a user create is wrapped as the vendor reads it: " _ tText)
    Do $$$AssertTrue(tText [ """Password"":""<Password>""", "with the password outside the wrapper")

    Kill tQuery
    Set tQuery("id") = "12"
    Set tText = ..Text(##class(OcuPilot.Port.AdminPort).Snippet("Task.CRUD", "RUN", .tQuery, {"Name": "ignored"}, ..Context()))
    Do $$$AssertTrue(tText [ "-d '{""RunNow"":true}'", "a run sends the constant body: " _ tText)

    Kill tQuery
    Set tQuery("event") = "S1/T1/N1"
    Set tText = ..Text(##class(OcuPilot.Port.AdminPort).Snippet("Security.Audit.Event", "CLEARCOUNT", .tQuery, "", ..Context()))
    Do $$$AssertTrue(tText [ "/security/audit/event/clear-count?name=N1&source=S1&type=T1'", "a composite key is split into its parts: " _ tText)
    Kill tQuery
    Set tQuery("event") = "S1/T1"
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).Snippet("Security.Audit.Event", "CLEARCOUNT", .tQuery, "", ..Context()).%Size(), 0, "and a malformed one renders nothing")
}

/// <p>The password tool's after-write step: set in the stored read, one step; clear, none; absent,
/// one step with the condition written above it.</p>
Method TestUserPasswordAfterStep()
{
    Set tTool = "OcuPilot.Screen.Tool.UserPassword"
    Set tText = ..Text($ClassMethod(tTool, "SnippetAfter", "Security.User", "name", "u1", {"ChangePassword": true}, ..Context()))
    Do $$$AssertTrue(tText [ "##class(Security.Users).Modify(""u1"", .tProps)", "a set flag is set again: " _ tText)
    Do $$$AssertTrue(tText '[ "; Only when", "unconditionally")
    Do $$$AssertEquals($ClassMethod(tTool, "SnippetAfter", "Security.User", "name", "u1", {"ChangePassword": false}, ..Context()).%Size(), 0, "a clear flag adds no step")
    Set tText = ..Text($ClassMethod(tTool, "SnippetAfter", "Security.User", "name", "u1", {"Enabled": true}, ..Context()))
    Do $$$AssertTrue((tText [ "; Only when") && (tText [ "Security.Users).Modify("), "an unknown flag is the step under its condition: " _ tText)
}

}
