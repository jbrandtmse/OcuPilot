/// <p>Serves the built Angular bundle for the <code>/ocupilot</code> shell application,
/// with the deep-link fallback the client router needs (AD-20, AD-21, AD-47).</p>
/// <p>The application is unauthenticated by design and this class is its dispatch class,
/// so the origin it serves is treated as hostile ground: it answers file bytes and nothing
/// else, reads no OcuPilot global, reflects no request text into any response, and sends a
/// content-security policy naming only the instance's own origin.</p>
/// <p><b>The bundle directory is resolved on the instance, never from the request</b>
/// (AD-21). <method>RootDirectory</method> derives it from
/// <code>$System.Util.DataDirectory()</code> and the matched application's own name, and
/// from nothing a caller can set. A caller-supplied path is then admitted only after
/// <method>ResolvePath</method> has applied both a literal rejection set and a
/// post-normalization prefix containment check against the normalized root, whose trailing
/// separator is what keeps a sibling directory (<code>.../ocupilotevil/x</code>) from
/// passing a prefix test against <code>.../ocupilot</code>.</p>
/// <p><b>An unresolved path answers <code>index.html</code> with 200</b>, which is what
/// makes a pasted or reloaded client route work (AD-21). The cost is that a genuinely
/// missing hashed asset answers the shell document with a MIME-type error in the browser
/// rather than a 404; changing that is a spine amendment, not a slice decision.</p>
/// <p>Failures render through <class>OcuPilot.Api.Error</class>, the tree's one error
/// writer, exactly as <class>OcuPilot.Api.Router</class> does. This class writes file bytes
/// through a stream's own <code>OutputToDevice</code> and never issues a bare
/// <code>Write</code>.</p>
Class OcuPilot.Api.StaticHandler Extends %CSP.REST
{

/// <p>Stateless: no CSP session per request.</p>
Parameter UseSession = 0;

/// <p>The document served for the application root, for a directory, and for any path
/// that does not resolve to a file.</p>
Parameter INDEXFILE = "index.html";

/// <p>Bytes read from a file per <code>OutputToDevice</code> call, so a large asset is
/// streamed rather than materialized (AC4, "streams in bounded chunks").</p>
Parameter CHUNKSIZE As %Integer = 32000;

/// <p>The largest <parameter>INDEXFILE</parameter> this handler will read whole in order
/// to substitute the nonce. A document beyond it is treated as no usable bundle rather
/// than served without its policy nonce, which would fail in the browser anyway.</p>
Parameter MAXINDEXBYTES As %Integer = 1048576;

/// <p>The literal the built <file>ui/src/index.html</file> carries on
/// <code>&lt;app-root ngCspNonce="..."&gt;</code> and that each document response replaces
/// with that response's own freshly generated nonce. The client half of this contract is
/// pinned by <file>ui/tools/build-output.test.mjs</file>; the two spellings must match.</p>
Parameter NONCEPLACEHOLDER = "OCUPILOTCSPNONCE";

/// <p>Response header names this handler sets. Kept as parameters so the tests name the
/// same strings the handler does.</p>
Parameter CACHECONTROLHEADER = "Cache-Control";

/// <p>See <parameter>CACHECONTROLHEADER</parameter>.</p>
Parameter CSPHEADER = "Content-Security-Policy";

/// <p>See <parameter>CACHECONTROLHEADER</parameter>.</p>
Parameter NOSNIFFHEADER = "X-Content-Type-Options";

/// <p>Cache policy for the shell document (DW-3): never cached, so a container start that
/// installs a new bundle is one reload away from being current.</p>
Parameter INDEXCACHECONTROL = "no-store, no-cache, must-revalidate";

/// <p>Cache policy for every other file (DW-3): the build hashes every emitted asset
/// filename, so a given name's bytes never change and the old bundle stays coherent until
/// the document reload replaces it.</p>
Parameter ASSETCACHECONTROL = "public, max-age=31536000, immutable";

/// <p>One <code>GET</code> and one <code>HEAD</code> route over everything under the
/// application. There is no route ordering to preserve here: the whole path is one
/// capture group and <method>ResolvePath</method> decides what it means.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/(.*)" Method="GET" Call="Serve" />
  <Route Url="/(.*)" Method="HEAD" Call="Serve" />
</Routes>
}

/// <p>The application path this request was matched against, with no caller input in it:
/// the CSP server sets <code>%request.Application</code> from the application it resolved,
/// and a caller cannot influence which application that is beyond choosing a URL the
/// server then resolves itself.</p>
ClassMethod MatchedApplication() As %String
{
    If '$Data(%request) Quit ""
    If '$IsObject(%request) Quit ""
    Quit %request.Application
}

/// <p>The bundle directory for <var>pApplication</var>:
/// <code>&lt;data directory&gt;csp/&lt;application name&gt;/</code>, where the application
/// name is its path with the separators removed and every character outside
/// <code>[A-Za-z0-9-]</code> dropped. <code>/durable/iris/csp</code> is writable on the
/// container image this project pins, while the install directory's <code>csp</code> is
/// not, which is why the data directory is the base.</p>
/// <p><b>Public because <method>OcuPilot.Install.Installer.Names</method> calls it</b>:
/// the installer creates the directory, copies the bundle into it and removes it again, and
/// the handler resolves it per request -- one rule, one implementation, so the two cannot
/// drift. The installer's call happens in the install namespace, before its own
/// <code>%SYS</code> switch.</p>
ClassMethod RootDirectory(pApplication As %String) As %String
{
    Set tName = ""
    For tI = 1:1:$Length(pApplication) {
        Set tCh = $Extract(pApplication, tI)
        If (tCh ? 1AN) || (tCh = "-") Set tName = tName _ tCh
    }
    Set tName = $ZConvert(tName, "L")
    If tName = "" Quit ""
    Set tBase = ##class(%File).NormalizeDirectory($System.Util.DataDirectory())
    Quit ##class(%File).NormalizeDirectory(tBase _ "csp/" _ tName)
}

/// <p>Decide what <var>pRelative</var> -- the one caller-supplied string this class ever
/// resolves against the filesystem -- names inside <var>pRoot</var>, and return
/// <code>"file"</code>, <code>"index"</code> or <code>"reject"</code>, with the resolved
/// absolute path in <var>pFullPath</var>.</p>
/// <p>Two independent checks, both required (AD-21):</p>
/// <ol>
/// <li>A <b>literal rejection set</b> applied to the request text before anything touches
/// the filesystem: a <code>..</code> anywhere in it, a null, a backslash, a colon, or any
/// control character.</li>
/// <li>A <b>post-normalization prefix containment check</b>: the normalized candidate must
/// begin with <code>%File.NormalizeDirectory(pRoot)</code>, trailing separator included.
/// Dropping that separator is the sibling-directory gap in the code this was harvested
/// from -- <code>.../ocupilotevil/x.js</code> passes a prefix test against
/// <code>.../ocupilot</code> and fails one against <code>.../ocupilot/</code>.</li>
/// </ol>
/// <p><b>Neither check subsumes the other, and each has its own test</b>: the literal set
/// catches what normalization would let through (a null, a backslash, a colon, a tab — all
/// legal in a Unix filename, none of which moves a path outside the root), and the
/// containment check catches what the literal set would let through if it were relaxed.
/// <class>OcuPilot.Test.Static</class> drives a hostile-input corpus through this method and
/// <method>IsInsideRoot</method> directly, because the web server itself would never forward
/// any of it — it refuses <code>%2F</code> and <code>%00</code> and resolves dot segments
/// before IRIS sees a request, so over the wire a traversal attempt reaches Apache's own 404
/// and never arrives here at all.</p>
ClassMethod ResolvePath(pRoot As %String, pRelative As %String, Output pFullPath As %String) As %String
{
    Set pFullPath = ""
    ; The empty root is refused BEFORE normalization, not after: on this build
    ; %File.NormalizeDirectory("") returns the process's own namespace directory
    ; (/durable/iris/mgr/HSCUSTOM/ here), so a post-normalization test for "" never fires
    ; and an empty root would resolve request paths against the namespace's database
    ; directory. RootDirectory returns "" for an application name with no usable
    ; characters, so this input is producible.
    If pRoot = "" Quit "reject"
    Set tRoot = ##class(%File).NormalizeDirectory(pRoot)
    If tRoot = "" Quit "reject"

    Set tRel = pRelative
    If (tRel [ "..") || (tRel [ $Char(0)) || (tRel [ "\") || (tRel [ ":") Quit "reject"
    Set tControl = 0
    For tI = 1:1:$Length(tRel) {
        If $Ascii(tRel, tI) < 32 {
            Set tControl = 1
            Quit
        }
    }
    If tControl Quit "reject"

    While $Extract(tRel, 1) = "/" {
        Set tRel = $Extract(tRel, 2, *)
    }
    Set pFullPath = tRoot _ ..#INDEXFILE
    If (tRel = "") || ($Extract(tRel, *) = "/") Quit "index"

    Set tCandidate = ##class(%File).NormalizeFilename(tRoot _ tRel)
    ; pFullPath is cleared on both refusals: it was set to the index path above, and this
    ; method's contract is that a "reject" outcome hands the caller no servable path.
    If tCandidate = "" Set pFullPath = "" Quit "reject"
    If '..IsInsideRoot(tRoot, tCandidate) Set pFullPath = "" Quit "reject"
    If ##class(%File).DirectoryExists(tCandidate) Quit "index"
    If '##class(%File).Exists(tCandidate) Quit "index"
    ; A request that names the shell document itself is the document, not an asset: served
    ; as an asset it would carry the immutable cache policy DW-3 forbids for it, no
    ; content-security policy, and the nonce placeholder unsubstituted.
    If tCandidate = (tRoot _ ..#INDEXFILE) Quit "index"
    Set pFullPath = tCandidate
    Quit "file"
}

/// <p>The second of AD-21's two checks, on its own so it can be demonstrated on its own:
/// whether the already-normalized <var>pCandidate</var> lies inside <var>pRoot</var>.</p>
/// <p><b>The comparison keeps the root's trailing separator.</b> Without it
/// <code>.../ocupilotevil/x.js</code> passes a prefix test against
/// <code>.../ocupilot</code> — the sibling-directory gap in the code this handler was
/// harvested from. That is the whole content of this method, and the reason it is not
/// inlined into <method>ResolvePath</method>: inlined, the literal <code>..</code> rejection
/// above already refuses every input that could reach it, so no test could tell a correct
/// containment check from a missing one.</p>
ClassMethod IsInsideRoot(pRoot As %String, pCandidate As %String) As %Boolean
{
    Set tRoot = ##class(%File).NormalizeDirectory(pRoot)
    If tRoot = "" Quit 0
    Quit ($Extract(pCandidate, 1, $Length(tRoot)) = tRoot)
}

/// <p>The one route target. <var>pPath</var> is the <code>UrlMap</code> capture group --
/// everything after the application -- which the CSP server has already percent-decoded
/// exactly once, UTF-8-decoded, stripped of its query string and resolved of dot segments
/// before this method is reached. It is never decoded again here (AD-13), and never
/// reflected into a response.</p>
ClassMethod Serve(pPath As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRoot = ..RootDirectory(..MatchedApplication())
        Set tOutcome = ..ResolvePath(tRoot, pPath, .tFull)
        If tOutcome = "reject" {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "The requested path is not one this application serves", ##class(OcuPilot.Api.Error).#STATICBADPATH)
        } ElseIf tOutcome = "index" {
            Set tSC = ..ServeIndex(tFull)
        } Else {
            Set tSC = ..ServeAsset(tFull)
        }
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Serve the shell document at <var>pFullPath</var>: read it whole (bounded by
/// <parameter>MAXINDEXBYTES</parameter>), substitute this response's own nonce for
/// <parameter>NONCEPLACEHOLDER</parameter>, set the policy and cache headers, and write the
/// result through a stream. An absent or over-large document is 503
/// <code>STATIC.NOBUNDLE</code>, never a partial page.</p>
ClassMethod ServeIndex(pFullPath As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        If '##class(%File).Exists(pFullPath) {
            Set tSC = ..RenderNoBundle()
            Return tSC
        }
        Set tText = ""
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(pFullPath)
        If $$$ISERR(tSC) Return tSC
        While 'tStream.AtEnd {
            Set tText = tText _ tStream.Read(..#CHUNKSIZE)
            If $Length(tText) > ..#MAXINDEXBYTES {
                Do ##class(OcuPilot.Kernel.Audit.Log).Error("static", "The shell document is larger than this handler will read, so no bundle is served", {"limit": (..#MAXINDEXBYTES)})
                Set tSC = ..RenderNoBundle()
                Return tSC
            }
        }

        Set tNonce = ..NewNonce()
        Set tText = $Replace(tText, ..#NONCEPLACEHOLDER, tNonce)

        Set %response.Status = 200
        Set %response.NoCharSetConvert = 1
        Set %response.ContentType = "text/html"
        Set %response.CharSet = "utf-8"
        Do %response.SetHeader(..#CACHECONTROLHEADER, ..#INDEXCACHECONTROL)
        Do %response.SetHeader(..#NOSNIFFHEADER, "nosniff")
        Do %response.SetHeader(..#CSPHEADER, ..ContentSecurityPolicy(tNonce))

        Set tOut = ##class(%Stream.TmpBinary).%New()
        Set tSC = tOut.Write(tText)
        If $$$ISERR(tSC) Return tSC
        Do tOut.Rewind()
        Set tSC = ..StreamToDevice(tOut)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Serve the regular file at <var>pFullPath</var> byte for byte, immutably cached, in
/// bounded chunks.</p>
ClassMethod ServeAsset(pFullPath As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(pFullPath)
        If $$$ISERR(tSC) Return tSC

        Set %response.Status = 200
        Set %response.NoCharSetConvert = 1
        Set %response.ContentType = ..ContentTypeFor(pFullPath)
        If ..IsTextMediaType(%response.ContentType) Set %response.CharSet = "utf-8"
        Do %response.SetHeader(..#CACHECONTROLHEADER, ..#ASSETCACHECONTROL)
        Do %response.SetHeader(..#NOSNIFFHEADER, "nosniff")

        Set tSC = ..StreamToDevice(tStream)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Write <var>pStream</var> to the response device in <parameter>CHUNKSIZE</parameter>
/// slices. <code>OutputToDevice</code> is a stream method, not the <code>Write</code>
/// command AD-12 reserves for <class>OcuPilot.Api.Response</class> and
/// <class>OcuPilot.Api.Error</class>.</p>
ClassMethod StreamToDevice(pStream As %Stream.Object) As %Status [ Private ]
{
    Set tSC = $$$OK
    While 'pStream.AtEnd {
        Set tLen = ..#CHUNKSIZE
        Set tSC = pStream.OutputToDevice(.tLen)
        If $$$ISERR(tSC) Quit
        If tLen <= 0 Quit
    }
    Quit tSC
}

/// <p>503 with the machine code <code>STATIC.NOBUNDLE</code> and a reason that names
/// neither the directory nor the request (AD-47: this response reaches an anonymous
/// caller).</p>
ClassMethod RenderNoBundle() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, "The OcuPilot client bundle is not installed on this instance", ##class(OcuPilot.Api.Error).#STATICNOBUNDLE)
}

/// <p>A fresh 128-bit policy nonce, base64 with no line breaks, for one response only.</p>
/// <p>The bytes come from <code>$System.Encryption.GenCryptRand</code>, not from
/// <code>$Random</code>: a nonce's only security property is that a same-origin script
/// cannot predict it, and <code>$Random</code> is a per-process pseudo-random sequence.</p>
ClassMethod NewNonce() As %String [ Private ]
{
    Quit $ZStrip($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(16), 1), "*C")
}

/// <p>The content-security policy sent with the shell document (AD-47): the instance's own
/// origin and nothing else, no CDN reachable, no inline or fetched script evaluated.</p>
/// <p><var>pNonce</var> appears in <code>style-src</code> alone. Angular injects component
/// styles as runtime <code>&lt;style&gt;</code> elements and every
/// <code>@angular/material</code> component uses <code>ViewEncapsulation.None</code>, so a
/// strict <code>style-src</code> needs a per-response nonce; scripts need none, because the
/// build emits no inline script.</p>
/// <p><b>Every other directive names <code>'self'</code> or <code>'none'</code> and no
/// scheme.</b> AC5 and AD-47 both say the policy names only the instance's own origin, and a
/// scheme source such as <code>data:</code> is not an origin. The built bundle carries no
/// <code>data:</code> URI in its document, its stylesheet or its script, so none is needed;
/// a later story that genuinely needs one widens this string and the exact-policy assertion
/// in <class>OcuPilot.Test.Static</class> makes that a visible, deliberate change rather
/// than a silent one.</p>
ClassMethod ContentSecurityPolicy(pNonce As %String) As %String
{
    Quit "default-src 'self'; script-src 'self'; style-src 'self' 'nonce-" _ pNonce _ "'; img-src 'self'; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
}

/// <p>The media type for <var>pFullPath</var>'s extension, from a closed table. An
/// extension the table does not carry is <code>application/octet-stream</code>, which
/// together with <code>X-Content-Type-Options: nosniff</code> means the browser never
/// guesses a type this handler did not state.</p>
ClassMethod ContentTypeFor(pFullPath As %String) As %String
{
    Set tExt = $ZConvert($Piece(pFullPath, ".", *), "L")
    If tExt = "html" Quit "text/html"
    If tExt = "js" Quit "application/javascript"
    If tExt = "mjs" Quit "application/javascript"
    If tExt = "css" Quit "text/css"
    If tExt = "json" Quit "application/json"
    If tExt = "map" Quit "application/json"
    If tExt = "svg" Quit "image/svg+xml"
    If tExt = "png" Quit "image/png"
    If tExt = "jpg" Quit "image/jpeg"
    If tExt = "jpeg" Quit "image/jpeg"
    If tExt = "gif" Quit "image/gif"
    If tExt = "webp" Quit "image/webp"
    If tExt = "ico" Quit "image/x-icon"
    If tExt = "woff2" Quit "font/woff2"
    If tExt = "woff" Quit "font/woff"
    If tExt = "ttf" Quit "font/ttf"
    If tExt = "txt" Quit "text/plain"
    If tExt = "webmanifest" Quit "application/manifest+json"
    Quit "application/octet-stream"
}

/// <p>Whether <var>pMediaType</var> is one whose bytes are UTF-8 text, so the response can
/// state <code>charset=utf-8</code> alongside it.</p>
ClassMethod IsTextMediaType(pMediaType As %String) As %Boolean
{
    If $Extract(pMediaType, 1, 5) = "text/" Quit 1
    If pMediaType = "application/javascript" Quit 1
    If pMediaType = "application/json" Quit 1
    If pMediaType = "image/svg+xml" Quit 1
    If pMediaType = "application/manifest+json" Quit 1
    Quit 0
}

/// <p>Framework-error override, identical in shape to
/// <method>OcuPilot.Api.Router.ReportHttpStatusCode</method>: every status this class did
/// not otherwise handle renders through <class>OcuPilot.Api.Error</class> rather than the
/// superclass's own <code>{status, ...}</code> shape, and the machine code is derived from
/// the slug, never from the number.</p>
ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
    Set tStatus = +pHttpStatus
    If $$$ISERR(pSC) {
        Do ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    } ElseIf tStatus = 404 {
        Do ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", "ROUTE.NOTFOUND")
    } Else {
        Set tSlug = ##class(OcuPilot.Api.Error).GetSlugForStatus(tStatus)
        Do ##class(OcuPilot.Api.Error).Render(tStatus, tSlug, "Request failed", "ROUTE." _ $ZConvert(tSlug, "U"))
    }
    Quit $$$OK
}

/// <p>Framework-error override for a verb this application does not serve. Delegates to
/// <method>OcuPilot.Api.Error.Render405</method>, which sets the <code>Allow</code>
/// header.</p>
ClassMethod Http405(pSupportedVerbs As %String = "") As %Status
{
    Do ##class(OcuPilot.Api.Error).Render405(pSupportedVerbs)
    Quit $$$OK
}

}
