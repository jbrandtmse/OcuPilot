/// <p>The port to the instance's own administration API (AD-27). <b>This is the only class
/// in the tree that names an <code>%Api.Admin.*</code> class</b>, and it names them only
/// through the parameters below, so a vendor change has a blast radius of one file.</p>
/// <p>Story 1.8 builds the verification half: <method>VerifyInstance</method> reports the
/// usable admin API version and confirms that a named probe endpoint still answers the
/// contract AD-2's invocation sequence depends on. Epic 2 grows the sequence itself around
/// it -- <code>ValidateRequest</code>, the output capture and the
/// <code>%response.Status</code> read are not here.</p>
Class OcuPilot.Port.AdminPort Extends %RegisteredObject
{

/// <p>The vendor's admin API routing class, whose <code>UrlMap</code>
/// <method>HighestDispatchVersion</method> reads.</p>
Parameter ADMINAPICLASS = "%Api.Admin";

/// <p>The package the vendor's endpoint classes live in. Named here, not in the inventory
/// fixture that enumerates them, so AD-27's containment holds for the literal as well as
/// for the calls.</p>
Parameter ENDPOINTPACKAGE = "%Api.Admin.Endpoints.";

/// <p>The endpoint whose answers stand for the whole API's contract. Chosen because it is
/// read-only, takes no request body and needs no query parameter, so constructing it and
/// asking it three questions changes nothing on the instance.</p>
Parameter PROBEENDPOINT = "%Api.Admin.Endpoints.WebSession";

/// <p>The API version OcuPilot is built against (NFR-8). Every endpoint is constructed at
/// this version (AD-2, step 1).</p>
Parameter APIVERSION As INTEGER = 2;

/// <p>The request type the probe is constructed with -- the vendor's
/// <code>TYPELIST</code>. Spelled as its number because reading the vendor's parameter for
/// it would mean a second class naming an <code>%Api.Admin.*</code> class.</p>
Parameter PROBETYPE As INTEGER = 0;

/// <p>The admin API routing class this port reads. Overridable so
/// <class>OcuPilot.Test.PortFixture</class> can point the real derivation at a fixture
/// class carrying a fixture <code>UrlMap</code>, which is how version 1, version 3 and an
/// absent API are pinned without touching the instance's own admin API. Production never
/// overrides this.</p>
ClassMethod AdminApiClass() As %String
{
    Quit ..#ADMINAPICLASS
}

/// <p>The endpoint class <method>ProbeAnswers</method> constructs. Overridable for the same
/// reason as <method>AdminApiClass</method>; production never overrides it.</p>
ClassMethod ProbeEndpointClass() As %String
{
    Quit ..#PROBEENDPOINT
}

/// <p>The vendor endpoint package, exposed as a method so
/// <class>OcuPilot.Test.AdminInventory</class> enumerates the classes without naming the
/// package itself.</p>
ClassMethod EndpointPackage() As %String
{
    Quit ..#ENDPOINTPACKAGE
}

/// <p>The highest <code>N</code> among <var>pClass</var>'s own <code>UrlMap</code> routes
/// that forward to <code>&lt;pClass&gt;.Dispatch.v&lt;N&gt;</code>; <code>0</code> when the
/// class, the <code>UrlMap</code> or every such forward is absent <b>or unreadable</b> --
/// the two are not told apart here, so the caller's detail must not claim which it was.</p>
/// <p>This reproduces the vendor's own computation -- <code>%Api.Admin.Info()</code> reads
/// the same <code>UrlMap</code> out of the same class-definition dictionary, tests for
/// <code>Forward="&lt;class&gt;</code> and takes
/// <code>+$Piece(line, "&lt;class&gt;.Dispatch.v", 2)</code> -- so OcuPilot and
/// <code>/api/admin/info</code> cannot report different versions. Two deliberate
/// differences, neither able to change the answer: <code>Info()</code> seeds at 1 and so
/// can never report an absent API, where this reports <code>0</code>, which is what the
/// mismatch notice needs to say; and <code>Info()</code> skips the XData's first and last
/// lines as the <code>&lt;Routes&gt;</code> wrapper, where this reads every line -- a
/// <code>Forward=</code> can only occur inside that wrapper.</p>
/// <p><code>Info()</code> itself is never called in-process: it reads
/// <code>%session.Username</code>, sets <code>%response.Status</code> and writes its JSON
/// to the device.</p>
ClassMethod HighestDispatchVersion(pClass As %String) As %Integer
{
    Set tVersion = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, "UrlMap", , .tSC)
        If '$IsObject(tXData) Quit
        Set tMarker = "Forward=""" _ pClass
        Set tPrefix = pClass _ ".Dispatch.v"
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ tMarker Continue
            Set tFound = +$Piece(tLine, tPrefix, 2)
            If tFound > tVersion Set tVersion = tFound
        }
    } Catch {
        Set tVersion = 0
    }
    Quit tVersion
}

/// <p>Whether the probe endpoint still answers the contract AD-2's sequence depends on:
/// it constructs as <code>%New(&lt;type&gt;, 2)</code>, its <code>ResourcesOR()</code>
/// returns a non-empty <code>%List</code> for the gate to evaluate, and its
/// <code>ShouldRunAsync()</code> answers 0 or 1 so the synchronous and async paths can be
/// told apart.</p>
/// <p><var>pDetail</var> names the class and what it lacked; it is empty exactly when the
/// probe passed. The three questions are asked through
/// <code>$ClassMethod</code>/dynamic dispatch rather than a typed reference, so a fixture
/// endpoint needs no vendor superclass (AD-27).</p>
ClassMethod ProbeAnswers(Output pDetail As %String) As %Boolean
{
    Set pDetail = ""
    Set tClass = ..ProbeEndpointClass()
    Try {
        Set tEndpoint = $ClassMethod(tClass, "%New", ..#PROBETYPE, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set pDetail = "probe endpoint " _ tClass _ " did not construct at ApiVersion " _ ..#APIVERSION
            Quit
        }
        Set tResources = tEndpoint.ResourcesOR()
        If ('$ListValid(tResources)) || ($ListLength(tResources) = 0) {
            Set pDetail = "probe endpoint " _ tClass _ " returned no resource from ResourcesOR()"
            Quit
        }
        Set tAsync = tEndpoint.ShouldRunAsync()
        If (tAsync '= 0) && (tAsync '= 1) {
            Set pDetail = "probe endpoint " _ tClass _ " answered ShouldRunAsync() with " _ tAsync
            Quit
        }
    } Catch ex {
        Set pDetail = "probe endpoint " _ tClass _ " failed the port's contract: " _ ex.DisplayString()
    }
    Quit pDetail = ""
}

/// <p>Report the usable admin API version, and refuse to report one at all unless the named
/// probe endpoint still answers (AD-27: fail loudly, never a partly-working screen).</p>
/// <p><var>pVersion</var> is the derived version, or <code>0</code> when the API is absent
/// or the probe failed. <var>pDetail</var> is empty exactly when
/// <var>pVersion</var> is the instance's real version and the probe passed; otherwise it
/// names what was missing and is what the caller logs. An error
/// <class>%Status</class> is always accompanied by a non-empty <var>pDetail</var>.</p>
/// <p>A version other than <parameter>APIVERSION</parameter> is not an error here: the
/// client needs the number in order to name it in the mismatch notice.</p>
ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    Set tSC = $$$OK
    Set pVersion = 0
    Set pDetail = ""
    Try {
        Set tClass = ..AdminApiClass()
        Set pVersion = ..HighestDispatchVersion(tClass)
        If pVersion = 0 {
            Set pDetail = "admin API unusable: " _ tClass _ " publishes no readable UrlMap route forwarding to " _ tClass _ ".Dispatch.v<N>"
            Quit
        }
        Set tProbeDetail = ""
        If '..ProbeAnswers(.tProbeDetail) {
            Set pVersion = 0
            Set pDetail = tProbeDetail
            Quit
        }
    } Catch ex {
        Set pVersion = 0
        Set pDetail = "the admin API check failed: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
