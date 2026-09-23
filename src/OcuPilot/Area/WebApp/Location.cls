/// <p>Where a WSGI or ASGI web application's directory lives (AD-21): one directory name,
/// resolved under a fixed root on this instance. It is the one place a web-application create
/// turns a caller's text into a filesystem directory, and both callers of the create tool reach it
/// through <method>OcuPilot.Area.WebApp.Create.Validate</method> and
/// <method>OcuPilot.Screen.Tool.WebAppCreate.DerivedFields</method> (AD-55).</p>
/// <p><b>The caller names a directory, never a path.</b> The name is a single segment matching
/// <parameter>NAMEPATTERN</parameter> and carrying no literal <code>..</code>; it is resolved under
/// <method>Root</method>, computed on every call and never cached, by lexical normalization of the
/// root and the name together; and the resolved directory is
/// accepted only when it lies strictly inside that root, the comparison keeping the root's trailing
/// separator so a sibling such as <code>&lt;mgr&gt;/wsgiprobe/</code> is outside. Nothing here
/// creates a directory. Any other location stays a classic-portal action.</p>
Class OcuPilot.Area.WebApp.Location Extends %RegisteredObject
{

/// <p>The one directory name a caller may give: a letter or digit, then up to 63 letters, digits,
/// dots, dashes or underscores.</p>
Parameter NAMEPATTERN = "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$";

/// <p>The root's own directory name under the manager directory.</p>
Parameter ROOTNAME = "wsgi";

/// <p>The fixed root every application directory resolves under:
/// <code>&lt;ManagerDirectory&gt;wsgi/</code>, normalized with its trailing separator
/// (<code>/durable/iris/mgr/wsgi/</code> on this build). Computed on every call, because the manager
/// directory is the instance's and not a constant; <code>""</code> when it cannot be computed,
/// which every caller reads as "nothing resolves".</p>
ClassMethod Root() As %String
{
    Set tRoot = ""
    Try {
        Set tManager = $System.Util.ManagerDirectory()
        If tManager = "" Quit
        Set tRoot = ##class(%File).NormalizeDirectory(..#ROOTNAME, tManager)
    } Catch {
        Set tRoot = ""
    }
    Quit tRoot
}

/// <p>Whether <var>pName</var> resolves to an application directory, with that directory in
/// <var>pPath</var> (normalized, trailing separator kept) or <code>""</code>.</p>
/// <p><b>Caller contract:</b> <var>pPath</var> is what is sent as both <code>WSGIAppLocation</code>
/// and <code>Path</code>; the caller's own text is never sent. Refused: a name outside
/// <parameter>NAMEPATTERN</parameter>, any name carrying <code>..</code>, a root that cannot be
/// computed, and a resolution that is the root itself or lies outside it.</p>
ClassMethod Resolve(pName As %String, Output pPath As %String) As %Boolean
{
    Set pPath = ""
    Set tResolved = 0
    Try {
        If '$Match(pName, ..#NAMEPATTERN) Quit
        If pName [ ".." Quit
        Set tRoot = ..Root()
        If tRoot = "" Quit
        ; The one-argument form: with a base argument %File changes into that directory first
        ; and answers "" when it does not exist yet, which a root no application has used is.
        Set tCandidate = ##class(%File).NormalizeDirectory(tRoot _ pName)
        If tCandidate = "" Quit
        If '..IsInsideRoot(tRoot, tCandidate) Quit
        Set pPath = tCandidate
        Set tResolved = 1
    } Catch {
        Set pPath = ""
        Set tResolved = 0
    }
    Quit tResolved
}

/// <p>Whether the normalized directory <var>pCandidate</var> lies strictly inside
/// <var>pRoot</var>: it starts with the root, trailing separator included, and is not the root
/// itself. Separate from <method>Resolve</method> so the prefix check can be shown on its own --
/// inside <method>Resolve</method> the pattern and the <code>..</code> refusal already refuse
/// every input that could reach it.</p>
ClassMethod IsInsideRoot(pRoot As %String, pCandidate As %String) As %Boolean
{
    If (pRoot = "") || (pCandidate = "") Quit 0
    Set tRoot = ##class(%File).NormalizeDirectory(pRoot)
    If tRoot = "" Quit 0
    If pCandidate = tRoot Quit 0
    Quit ($Extract(pCandidate, 1, $Length(tRoot)) = tRoot)
}

}
