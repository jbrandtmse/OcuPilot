/// <p>Suite for <class>OcuPilot.Api.StaticHandler</class> (AC3's server half, AC4, AC6,
/// AC7, AC11's second half), in two halves that need each other.</p>
/// <p><b>Over the wire</b>, against the probe profile's own unauthenticated shell
/// application and a small synthetic bundle this class writes, installs through the real
/// installer and removes again: the root, a deep link, a hashed asset, an unresolved path, a
/// missing asset, the wrong verb, the headers, and the bundle-absent answer. No file the
/// production shell serves is read, written or removed here -- but
/// <method>OnBeforeAllTests</method> does run the production install, which re-asserts the
/// production applications and role like any other repeat install.</p>
/// <p><b>In process</b>, over a hostile-input corpus the web server would never forward: the
/// front web server refuses <code>%2F</code> and <code>%00</code> and resolves dot segments
/// before IRIS sees a request, so <method>OcuPilot.Api.StaticHandler.ResolvePath</method>'s
/// two checks cannot be justified by an over-the-wire test at all -- a traversal attempt
/// answers Apache's own 404 and never reaches OcuPilot. Driving the method directly is the
/// only way to demonstrate them.</p>
Class OcuPilot.Test.Static Extends %UnitTest.TestCase
{

/// <p>The probe profile's shell application path, as
/// <method>OcuPilot.Install.Installer.Names</method> resolves it.</p>
Parameter SHELLPATH = "/probeocupilot";

/// <p>The synthetic bundle's hashed script name, and the exact bytes it holds -- short,
/// ASCII and fixed, so the over-the-wire comparison is byte-for-byte rather than
/// approximate.</p>
Parameter ASSETNAME = "main-PROBE001.js";

/// <p>See <parameter>ASSETNAME</parameter>.</p>
Parameter ASSETBODY = "export const ocuPilotProbeBundle = 1;";

/// <p>The scratch directory this class writes its synthetic bundle into, under the manager
/// directory; created in <method>OnBeforeAllTests</method> and removed in
/// <method>OnAfterAllTests</method>. It is the installer's <i>source</i>, never the shell
/// application's own directory.</p>
ClassMethod SourceDirectory() As %String
{
    Quit ##class(%File).NormalizeDirectory("ocupilotbundleprobe", $System.Util.ManagerDirectory())
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = ..WriteSyntheticBundle()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe", 0, ..SourceDirectory())
}

/// <p>Re-installs the synthetic bundle before every test, so the one test that removes it
/// (<method>TestBundleAbsentAnswersNoBundle</method>) cannot leave the others without one
/// whatever order they run in.</p>
Method OnBeforeOneTest() As %Status
{
    Quit ##class(OcuPilot.Install.Installer).Install("probe", 0, ..SourceDirectory())
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do ##class(%File).RemoveDirectoryTree(..SourceDirectory())
    Quit tSC
}

/// <p>Write a three-file bundle -- an <code>index.html</code> carrying the nonce
/// placeholder, one hashed script, and one file in a subdirectory -- into
/// <method>SourceDirectory</method>. The subdirectory matters: it is what makes the
/// installer's recursive copy and the handler's nested-path resolution observable.</p>
Method WriteSyntheticBundle() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDir = ..SourceDirectory()
        Do ##class(%File).RemoveDirectoryTree(tDir)
        Do ##class(%File).CreateDirectoryChain(tDir, .tMk)
        Set tMediaDir = ##class(%File).NormalizeDirectory(tDir _ "media")
        Do ##class(%File).CreateDirectoryChain(tMediaDir, .tMk2)

        Set tIndex = "<!doctype html><html><head><base href=""" _ ..#SHELLPATH _ "/""></head><body>"
        Set tIndex = tIndex _ "<app-root ngCspNonce=""" _ ##class(OcuPilot.Api.StaticHandler).#NONCEPLACEHOLDER _ """></app-root>"
        Set tIndex = tIndex _ "<script src=""" _ ..#ASSETNAME _ """ type=""module""></script></body></html>"

        Set tSC = ..WriteFile(tDir _ "index.html", tIndex)
        If $$$ISERR(tSC) Quit
        Set tSC = ..WriteFile(tDir _ ..#ASSETNAME, ..#ASSETBODY)
        If $$$ISERR(tSC) Quit
        Set tSC = ..WriteFile(tMediaDir _ "probe-FACE0001.woff2", "not-a-real-font")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <var>pContent</var> to <var>pPath</var> as raw bytes.</p>
Method WriteFile(pPath As %String, pContent As %String) As %Status
{
    Set tStream = ##class(%Stream.FileBinary).%New()
    Set tSC = tStream.LinkToFile(pPath)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = tStream.Write(pContent)
    If $$$ISERR(tSC) Quit tSC
    Quit tStream.%Save()
}

/// <p>Request <var>pPath</var> under the probe shell application, anonymously -- the
/// application is unauthenticated, so sending credentials would prove nothing about it.</p>
Method Fetch(pPath As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#SHELLPATH _ pPath, "", "", .pStatus, .pBody, .pHeaders)
}

/// <p>AC3 (server half), AC5, AC6 -- the application root answers the shell document
/// anonymously, with the document cache policy, the nosniff header, and a
/// content-security-policy naming only the instance's own origin whose nonce is the one
/// actually substituted into the document. The placeholder itself must be gone: a document
/// that still carried it would name a nonce the header does not, and every style Angular
/// injects at runtime would be refused.</p>
/// <p>Mutation: delete the <code>$Replace</code> that substitutes the nonce in
/// <method>OcuPilot.Api.StaticHandler.ServeIndex</method> -> the "placeholder is gone" and
/// "the header names the document's own nonce" assertions go red. Widening any directive in
/// <method>OcuPilot.Api.StaticHandler.ContentSecurityPolicy</method> -> the exact-policy
/// assertion goes red.</p>
Method TestShellRootServesTheDocumentWithItsPolicyAndCacheHeaders()
{
    Set tSC = ..Fetch("/", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the application root answers 200 with no credentials")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "text/html", "the document is served as text/html")
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "no-store, no-cache, must-revalidate", "the document is never cached (DW-3)")
    Do $$$AssertEquals($Get(tHeaders("X-CONTENT-TYPE-OPTIONS")), "nosniff", "the response forbids MIME sniffing")
    Do $$$AssertTrue(tBody [ "<app-root", "the body is the shell document")
    Do $$$AssertTrue((tBody '[ ##class(OcuPilot.Api.StaticHandler).#NONCEPLACEHOLDER), "the nonce placeholder is gone from the served document")

    Set tPolicy = $Get(tHeaders("CONTENT-SECURITY-POLICY"))
    Do $$$AssertTrue(tPolicy [ "default-src 'self'", "the policy names only the instance's own origin")
    Do $$$AssertTrue(tPolicy [ "script-src 'self'", "no inline or fetched script may be evaluated")
    Do $$$AssertTrue((tPolicy '[ "unsafe-inline"), "the policy admits no unsafe-inline")
    Do $$$AssertTrue((tPolicy '[ "http://") && (tPolicy '[ "https://"), "the policy names no external host, so no CDN is reachable")

    Set tNonce = $Piece($Piece(tPolicy, "'nonce-", 2), "'", 1)
    Do $$$AssertTrue(tNonce '= "", "the policy carries a nonce for the styles Angular injects at runtime")
    Do $$$AssertTrue(tBody [ ("""" _ tNonce _ """"), "the document carries the very nonce the policy names")

    ; The whole policy, spelled out. The four assertions above admit a directive that names
    ; a scheme rather than an origin (`img-src 'self' data:` shipped past them), which AC5
    ; and AD-47 both rule out. Only an exact comparison makes a widened directive visible.
    Set tExpected = "default-src 'self'; script-src 'self'; style-src 'self' 'nonce-" _ tNonce _ "'; img-src 'self'; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
    Do $$$AssertEquals(tPolicy, tExpected, "the policy is exactly these directives, each naming the instance's own origin and no scheme")
}

/// <p>AC5, AC6 -- a request that names the shell document by filename is the document, not an
/// asset. Served as an asset it would carry the immutable cache policy DW-3 forbids for it,
/// no content-security policy at all, and the nonce placeholder still in the body.</p>
/// <p>Mutation: remove the <code>tCandidate = (tRoot _ ..#INDEXFILE)</code> branch from
/// <method>OcuPilot.Api.StaticHandler.ResolvePath</method> -> all three assertions go red.</p>
Method TestIndexNamedByFilenameIsStillTheDocument()
{
    Set tSC = ..Fetch("/index.html", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the shell document answers when named by filename")
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "no-store, no-cache, must-revalidate", "with the document cache policy, never the immutable asset one")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-SECURITY-POLICY")) [ "default-src 'self'", "and its content-security policy")
    Do $$$AssertTrue((tBody '[ ##class(OcuPilot.Api.StaticHandler).#NONCEPLACEHOLDER), "and its nonce substituted")
}

/// <p>AC5, AC6 -- a <code>HEAD</code> request carries the document's headers and no body.
/// The <code>UrlMap</code> routes <code>HEAD</code> to the same target as <code>GET</code>;
/// this pins that the response a client actually receives is body-less, which the CSP server
/// is what guarantees.</p>
Method TestHeadCarriesTheDocumentHeadersAndNoBody()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("HEAD", ..#SHELLPATH _ "/", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "HEAD on the application root answers 200")
    Do $$$AssertEquals(tBody, "", "and carries no body")
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "no-store, no-cache, must-revalidate", "with the document cache policy")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-SECURITY-POLICY")) [ "default-src 'self'", "and the content-security policy")
}

/// <p>AC5 -- the nonce is per response, not a constant. Two document responses must carry
/// different nonces, or a same-origin script could replay one.</p>
Method TestEachDocumentResponseCarriesItsOwnNonce()
{
    Do $$$AssertStatusOK(..Fetch("/", .tStatus1, .tBody1, .tHeaders1), "the first request completes")
    Do $$$AssertStatusOK(..Fetch("/", .tStatus2, .tBody2, .tHeaders2), "the second request completes")
    Set tNonce1 = $Piece($Piece($Get(tHeaders1("CONTENT-SECURITY-POLICY")), "'nonce-", 2), "'", 1)
    Set tNonce2 = $Piece($Piece($Get(tHeaders2("CONTENT-SECURITY-POLICY")), "'nonce-", 2), "'", 1)
    Do $$$AssertTrue(tNonce1 '= "", "the first response carries a nonce")
    Do $$$AssertNotEquals(tNonce2, tNonce1, "each response carries its own freshly generated nonce")
}

/// <p>AC3 (server half) -- a deep link, cold, answers the shell document rather than a 404,
/// with the address unchanged (no redirect). The client half is the browser check.</p>
/// <p>Mutation: make <method>OcuPilot.Api.StaticHandler.ResolvePath</method> return
/// <code>"reject"</code> instead of <code>"index"</code> for an unresolved path -> this and
/// the unresolved-path test both go red.</p>
Method TestDeepLinkAnswersTheShellDocument()
{
    Set tSC = ..Fetch("/permissions/users/" _ ##class(OcuPilot.Kernel.EntityId).Encode("_SYSTEM") _ "?ns=HSCUSTOM", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "a deep link answers 200, not a redirect and not a 404")
    Do $$$AssertTrue(tBody [ "<app-root", "a deep link answers the shell document")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "text/html", "as text/html")
}

/// <p>DW-97 -- an entity id holding two consecutive dots reaches the shell document, and the
/// literal <code>..</code> refusal that would otherwise have stopped it is untouched.</p>
/// <p>Both halves are needed and neither implies the other. The first: the shared codec's
/// output for <code>a..b</code> carries <code>%252E%252E</code>, the hop decodes it exactly
/// once to the text <code>%2E%2E</code>, and
/// <method>OcuPilot.Api.StaticHandler.ResolvePath</method> sees no literal <code>..</code>, so
/// the deep link answers <code>index.html</code>. The second: a hand-typed
/// <code>..</code> path -- and a singly encoded <code>%2E%2E</code>, which the hop decodes
/// into one -- still answers 400 <code>STATIC.BADPATH</code>, because AD-21's check was fixed
/// in the codec rather than weakened to carry data.</p>
/// <p>Mutation: drop the <code>"."</code> replacement from
/// <method>OcuPilot.Kernel.EntityId.PercentEncode</method> -> the first half goes red with a
/// 400, while the two refusals stay green.</p>
Method TestDottedEntityIdDeepLinksWhileLiteralDotsAreStillRefused()
{
    Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode("a..b")
    Do $$$AssertTrue((tEncoded '[ ".."), "the codec emits no literal .. for a dotted id")
    Do $$$AssertStatusOK(..Fetch("/permissions/users/" _ tEncoded, .tStatus, .tBody, .tHeaders), "the request completes")
    Do $$$AssertEquals(tStatus, 200, "a double-encoded dotted id answers the shell document")
    Do $$$AssertTrue(tBody [ "<app-root", "which is index.html, not an error envelope")

    Do $$$AssertStatusOK(..Fetch("/permissions/users/a%2E%2Eb", .tStatus2, .tBody2, .tHeaders2), "the singly encoded request completes")
    Do $$$AssertEquals(tStatus2, 400, "a singly encoded %2E%2E decodes to a literal .. in transit and is still refused")
    Set tObj2 = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tObj2.code, "STATIC.BADPATH", "through the one error writer, with the containment code")

    Do $$$AssertStatusOK(..Fetch("/permissions/users/a..b", .tStatus3, .tBody3, .tHeaders3), "the hand-typed request completes")
    Do $$$AssertEquals(tStatus3, 400, "and a hand-typed literal .. is refused unchanged")
    Set tObj3 = ##class(%DynamicObject).%FromJSON(tBody3)
    Do $$$AssertEquals(tObj3.code, "STATIC.BADPATH", "with the same code")
}

/// <p>AC4, AC6 (DW-3) -- a hashed asset is served byte for byte, with its own media type
/// and the immutable cache policy that keeps an old bundle coherent until the document
/// reload replaces it.</p>
/// <p>Mutation: swap <parameter>OcuPilot.Api.StaticHandler.ASSETCACHECONTROL</parameter> and
/// <parameter>OcuPilot.Api.StaticHandler.INDEXCACHECONTROL</parameter> -> this test's cache
/// assertion and the document test's both go red.</p>
Method TestHashedAssetIsServedByteExactAndImmutable()
{
    Set tSC = ..Fetch("/" _ ..#ASSETNAME, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "a hashed asset answers 200")
    Do $$$AssertEquals(tBody, ..#ASSETBODY, "the asset is served byte for byte")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/javascript", "with its own media type")
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "public, max-age=31536000, immutable", "and the immutable cache policy")
    Do $$$AssertEquals($Get(tHeaders("X-CONTENT-TYPE-OPTIONS")), "nosniff", "and the nosniff header")

    Set tSC2 = ..Fetch("/media/probe-FACE0001.woff2", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the nested request completes")
    Do $$$AssertEquals(tStatus2, 200, "a file in a subdirectory of the bundle is served too")
    Do $$$AssertTrue($Get(tHeaders2("CONTENT-TYPE")) [ "font/woff2", "with the media type its extension names")
}

/// <p>AC4 -- anything unresolved answers the shell document with 200, including an
/// asset-shaped path that does not exist. That is AD-21's rule and its cost: a genuinely
/// missing chunk reaches the browser as a MIME-type error rather than a 404, recorded here
/// rather than smoothed over.</p>
Method TestUnresolvedPathAndMissingAssetAnswerTheDocument()
{
    Do $$$AssertStatusOK(..Fetch("/anything/at/all", .tStatus, .tBody, .tHeaders), "the request completes")
    Do $$$AssertEquals(tStatus, 200, "an unresolved path answers 200")
    Do $$$AssertTrue(tBody [ "<app-root", "with the shell document")

    Do $$$AssertStatusOK(..Fetch("/main-NOSUCHHASH.js", .tStatus2, .tBody2, .tHeaders2), "the request completes")
    Do $$$AssertEquals(tStatus2, 200, "a missing hashed asset answers 200")
    Do $$$AssertTrue(tBody2 [ "<app-root", "with the shell document, per AD-21")
    Do $$$AssertTrue($Get(tHeaders2("CONTENT-TYPE")) [ "text/html", "and the document's own media type, which is what surfaces as a MIME-type error rather than a 404")
}

/// <p>AC7 -- the static application serves only files: a path shaped like a data route
/// answers the shell document, and the only JSON it ever writes is its own error envelope.</p>
Method TestStaticApplicationExposesNoDataRoute()
{
    Do $$$AssertStatusOK(..Fetch("/api/instance", .tStatus, .tBody, .tHeaders), "the request completes")
    Do $$$AssertEquals(tStatus, 200, "a data-shaped path is still just an unresolved path")
    Do $$$AssertTrue(tBody [ "<app-root", "and answers the shell document, never data")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "text/html", "and is not JSON")
}

/// <p>AC4 -- the wrong verb is refused through the one error writer, with the
/// <code>Allow</code> header naming the verbs the application does serve.
/// <code>%CSP.REST</code> adds <code>OPTIONS</code> to every route's verb list itself and
/// that cannot be overridden, so the assertion is that <code>GET</code> and
/// <code>HEAD</code> are both named rather than that the header reads exactly two verbs.</p>
Method TestWrongVerbIsRefusedThroughTheOneErrorWriter()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#SHELLPATH _ "/x", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 405, "the wrong verb is refused")
    Set tAllow = $Get(tHeaders("ALLOW"))
    Do $$$AssertTrue(tAllow [ "GET", "the Allow header names GET")
    Do $$$AssertTrue(tAllow [ "HEAD", "and HEAD")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "method_not_allowed", "rendered through the one error writer")
    Do $$$AssertEquals(tObj.code, "ROUTE.METHODNOTALLOWED", "with its stable machine code")
}

/// <p>AC11 -- with no bundle installed the shell answers
/// <code>STATIC.NOBUNDLE</code> rather than failing, and never a partial page. The
/// directory is emptied here rather than the application removed, which is the state a
/// container start leaves when the client was never built.</p>
/// <p>Mutation: make <method>OcuPilot.Api.StaticHandler.ServeIndex</method> fall through to
/// the stream write when the document is absent -> this goes red (a 500 or an empty 200).</p>
Method TestBundleAbsentAnswersNoBundle()
{
    Set tDirectory = ##class(OcuPilot.Api.StaticHandler).RootDirectory(..#SHELLPATH)
    Do ##class(%File).RemoveDirectoryTree(tDirectory)
    Do ##class(%File).CreateDirectoryChain(tDirectory, .tMk)
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "index.html"), "the bundle directory now holds no document")

    Set tSC = ..Fetch("/", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 503, "an uninstalled bundle answers 503, not 200 and not 500")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "unavailable", "through the one error writer")
    Do $$$AssertEquals(tObj.code, "STATIC.NOBUNDLE", "with its stable machine code")
    Do $$$AssertTrue((tBody '[ tDirectory), "and the response names no filesystem path")
}

/// <p>AC4, first check -- the literal rejection set, driven over a corpus the web server
/// would never forward. Rows 6 and 7 carry a backslash and a colon: both are legal in a Unix
/// filename, normalization therefore resolves them happily <i>inside</i> the root, and the
/// literal set is the only check that refuses them.</p>
/// <p>Mutation (demonstrated): delete the literal rejection line from
/// <method>OcuPilot.Api.StaticHandler.ResolvePath</method> -> rows 6 and 7 go red, while the
/// four dot-segment rows stay green (the containment check catches those) and the null and
/// tab rows stay green (the control-character loop catches those). That asymmetry is the
/// evidence that no one of the three checks subsumes the others.</p>
Method TestResolvePathRefusesHostileInput()
{
    Set tRoot = ##class(OcuPilot.Api.StaticHandler).RootDirectory(..#SHELLPATH)
    Set tCorpus = $ListBuild("../etc/passwd", "..", "a/../../../etc/passwd", "media/../../x.js", "a" _ $Char(0) _ "b.js", "a\b.js", "C:/windows/x.js", "sub/" _ $Char(9) _ "x.js")
    For tI = 1:1:$ListLength(tCorpus) {
        Set tInput = $List(tCorpus, tI)
        Set tOutcome = ##class(OcuPilot.Api.StaticHandler).ResolvePath(tRoot, tInput, .tFull)
        Do $$$AssertEquals(tOutcome, "reject", "hostile corpus row " _ tI _ " is refused")
    }
}

/// <p>AC4, second check -- the post-normalization containment check, driven directly.
/// It compares against the root <b>with its trailing separator</b>: without that, a sibling
/// directory whose name merely extends the root's passes a prefix test, which is the gap in
/// the code this handler was harvested from.</p>
/// <p>Driven at <method>OcuPilot.Api.StaticHandler.IsInsideRoot</method> rather than through
/// <method>OcuPilot.Api.StaticHandler.ResolvePath</method> for a stated reason: the literal
/// rejection above already refuses every input that could otherwise reach the containment
/// check, so through <code>ResolvePath</code> a correct containment check and a missing one
/// are indistinguishable.</p>
/// <p>Mutation: drop the trailing separator from the comparison in
/// <method>OcuPilot.Api.StaticHandler.IsInsideRoot</method> -- compare
/// <code>$Extract(pCandidate, 1, $Length(tRoot) - 1)</code> against
/// <code>$Extract(tRoot, 1, *-1)</code> -- and the sibling-directory assertion goes red while
/// every row of the hostile corpus above stays green. (Replacing the method's own
/// <code>NormalizeDirectory</code> call with the raw <var>pRoot</var> is <b>not</b> a
/// mutation that works: both call sites already pass a normalized root, so that call is
/// idempotent at every reachable site.)</p>
Method TestContainmentUsesTheRootsTrailingSeparator()
{
    Set tRoot = ##class(OcuPilot.Api.StaticHandler).RootDirectory(..#SHELLPATH)
    Set tSibling = ##class(%File).NormalizeDirectory($Extract(tRoot, 1, *-1) _ "evil") _ "x.js"
    Set tParent = ##class(%File).NormalizeDirectory($System.Util.DataDirectory() _ "csp") _ "x.js"

    Do $$$AssertTrue(##class(OcuPilot.Api.StaticHandler).IsInsideRoot(tRoot, tRoot _ ..#ASSETNAME), "a file in the root is inside it")
    Do $$$AssertTrue(##class(OcuPilot.Api.StaticHandler).IsInsideRoot(tRoot, tRoot _ "media/x.woff2"), "a file in a subdirectory of the root is inside it")
    Do $$$AssertTrue('##class(OcuPilot.Api.StaticHandler).IsInsideRoot(tRoot, tParent), "a file in the parent directory is not")
    Do $$$AssertTrue('##class(OcuPilot.Api.StaticHandler).IsInsideRoot(tRoot, tSibling), "and neither is one in a sibling directory whose name extends the root's")
}

/// <p>AC4 -- a path that does resolve inside the root is accepted, so the corpus above is
/// evidence of refusal rather than of a method that refuses everything.</p>
Method TestResolvePathAcceptsAFileInsideTheRoot()
{
    Set tRoot = ##class(OcuPilot.Api.StaticHandler).RootDirectory(..#SHELLPATH)
    Set tOutcome = ##class(OcuPilot.Api.StaticHandler).ResolvePath(tRoot, ..#ASSETNAME, .tFull)
    Do $$$AssertEquals(tOutcome, "file", "a file that exists inside the root resolves")
    Do $$$AssertEquals(tFull, tRoot _ ..#ASSETNAME, "to its own absolute path")

    Set tOutcomeRoot = ##class(OcuPilot.Api.StaticHandler).ResolvePath(tRoot, "", .tFullRoot)
    Do $$$AssertEquals(tOutcomeRoot, "index", "the empty path is the shell document")
    Do $$$AssertEquals(tFullRoot, tRoot _ "index.html", "resolved inside the root")

    Set tOutcomeDir = ##class(OcuPilot.Api.StaticHandler).ResolvePath(tRoot, "media", .tFullDir)
    Do $$$AssertEquals(tOutcomeDir, "index", "a directory is the shell document, never a listing")
}

/// <p>AD-21 -- the bundle directory is resolved from the instance and the matched
/// application name alone, so no caller-supplied value can move it. Two different
/// applications resolve to two different directories; an empty application name resolves to
/// nothing at all rather than to the data directory itself.</p>
Method TestRootDirectoryComesFromTheInstance()
{
    Set tShell = ##class(OcuPilot.Api.StaticHandler).RootDirectory("/ocupilot")
    Set tProbe = ##class(OcuPilot.Api.StaticHandler).RootDirectory(..#SHELLPATH)
    Do $$$AssertTrue(tShell '= "", "the production application resolves a directory")
    Do $$$AssertNotEquals(tProbe, tShell, "a different application resolves a different directory")
    Do $$$AssertTrue($Extract(tShell, 1, $Length($System.Util.DataDirectory())) = $System.Util.DataDirectory(), "under the instance's own data directory")
    Do $$$AssertEquals(##class(OcuPilot.Api.StaticHandler).RootDirectory(""), "", "an empty application name resolves no directory at all")
    Do $$$AssertEquals(##class(OcuPilot.Api.StaticHandler).RootDirectory("/../../etc"), ##class(OcuPilot.Api.StaticHandler).RootDirectory("/etc"), "separators and dots in an application name never escape the csp directory")
}

/// <p>AC4 -- what a refused path actually puts on the wire: one 400 envelope carrying
/// <code>STATIC.BADPATH</code>, no file bytes, and no trace of the request text in it
/// (AD-21, AD-47). The rejection tests above assert the decision; this asserts the
/// response.</p>
/// <p>Driven in process through <method>OcuPilot.Test.Dispatch.Invoke</method> with the
/// matched application supplied, because the front web server resolves dot segments and
/// refuses a null before IRIS sees the request, so no over-the-wire request can reach this
/// branch. The benign control in the same method is what makes the refusal evidence rather
/// than a handler that refuses everything.</p>
/// <p>Mutation: render the refusal with the request text in its reason (or drop the literal
/// rejection so the path resolves) -> the echo assertions, or the status and code
/// assertions, go red.</p>
Method TestTraversalAttemptRendersOneBadPathEnvelope()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.StaticHandler", "/../../etc/passwd", "GET", , .tBody, .tStatus, .tAllow, ..#SHELLPATH)
    Do $$$AssertStatusOK(tSC, "dispatch of a traversal attempt completes")
    Do $$$AssertEquals(tStatus, 400, "a traversal attempt is refused with 400")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "bad_request", "rendered through the one error writer")
    Do $$$AssertEquals(tObj.code, "STATIC.BADPATH", "with its stable machine code")
    Do $$$AssertTrue((tBody '[ "passwd"), "and never echoes the request text")
    Do $$$AssertTrue((tBody '[ ".."), "nor the traversal it refused")

    Set tSC2 = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.StaticHandler", "/" _ ..#ASSETNAME, "GET", , .tBody2, .tStatus2, .tAllow2, ..#SHELLPATH)
    Do $$$AssertStatusOK(tSC2, "dispatch of a benign path completes")
    Do $$$AssertEquals(tStatus2, 200, "the same harness serves a path inside the root, so the refusal above is a decision and not the default")
    Do $$$AssertTrue((tBody2 '[ "STATIC.BADPATH"), "and renders no error envelope for it")
}

}
