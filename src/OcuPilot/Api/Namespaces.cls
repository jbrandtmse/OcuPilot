/// <p>The handler behind <code>GET /api/ocupilot/namespaces</code>: the namespaces the calling
/// process may enter, each with whether it may also be written to and, when it may not and the
/// reason is a privilege, the <code>(resource, permission)</code> pair that failed.</p>
/// <p><code>scope</code> is this request's resolved namespace, read from
/// <class>OcuPilot.Kernel.Scope</class> rather than from <code>$Namespace</code> -- the route's
/// scope is a value the request carries (AD-44), and echoing it is what lets a client whose
/// <code>?ns=</code> was rejected fall back to something the instance chose.</p>
/// <p><b>The list is the set the caller can read</b> (AD-21, AD-48). No vendor call filters a
/// namespace roster by the caller's privileges, so the filter is here: a namespace whose global
/// database's resource the caller does not hold at <code>READ</code> is absent, and so is one
/// whose database information cannot be read at all -- a namespace that cannot be verified is
/// not offered.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the privilege answer is
/// <class>OcuPilot.Screen.Gate</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12).</p>
/// <p><b>Recomputed on every call</b> (AD-8). Nothing is cached, and <code>%SYS.Namespace</code>
/// is a <code>%</code>-class that answers in the install namespace, so no namespace switch is
/// taken or needed (AD-16).</p>
Class OcuPilot.Api.Namespaces Extends %RegisteredObject
{

/// <p>The permission entering a namespace requires on its global database's resource.</p>
Parameter READPERMISSION = "READ";

/// <p>The permission writing in a namespace requires on the same resource.</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The prefix <method>%SYS.Namespace.ListAll</method> gives an implicit namespace
/// (<code>^system^directory</code>). Implicit namespaces are a database addressed directly, not
/// a namespace a route can be scoped to, so they are dropped.</p>
Parameter IMPLICITPREFIX = "^";

/// <p>The gate whose <method>OcuPilot.Screen.Gate.EvaluatePairs</method> answers every privilege
/// question here -- the same <code>$System.Security.Check</code> shape and the same
/// <code>resource:permission</code> spelling of a failure the navigation map uses, never a
/// second gate.</p>
/// <p>Overridable so <class>OcuPilot.Test.NamespaceFixture</class> can point it at
/// <class>OcuPilot.Test.ScreenGate</class>: <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name, so no
/// in-process denial can be observed against it. Production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Screen.Gate"
}

/// <p>Every namespace name the instance reports, in collating order, implicit ones included --
/// the <parameter>IMPLICITPREFIX</parameter> filter is <method>Payload</method>'s, so a fixture
/// can supply a roster that exercises it.</p>
/// <p>Overridable for that fixture roster; production never overrides it.</p>
ClassMethod NamespaceNames(Output pList As %List) As %Status
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tSC = ##class(%SYS.Namespace).ListAll(.tArray)
        If $$$ISERR(tSC) Quit
        Set tName = ""
        For {
            Set tName = $Order(tArray(tName))
            If tName = "" Quit
            Set pList = pList _ $ListBuild(tName)
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The guarding resource and mount state of <var>pNamespace</var>'s default global database.
/// Returns 0 when the instance reports no resource for it, which is the one answer that must not
/// be read as "no privilege required": the namespace is then dropped from the list and refused
/// entry rather than admitted ungated.</p>
ClassMethod GlobalDatabase(pNamespace As %String, Output pResource As %String, Output pReadOnly As %Boolean) As %Boolean
{
    Set pResource = ""
    Set pReadOnly = 0
    Set tResolved = 0
    Try {
        Kill tInfo
        Do ##class(%SYS.Namespace).GetAllNSInfo(pNamespace, .tInfo)
        Set pResource = $Get(tInfo("GlobalDB", "Resource"))
        Set pReadOnly = ''$Get(tInfo("GlobalDB", "ReadOnly"))
        Set tResolved = (pResource '= "")
    } Catch {
        Set pResource = ""
        Set pReadOnly = 0
        Set tResolved = 0
    }
    Quit tResolved
}

/// <p>Whether the calling process may make a request scoped to <var>pNamespace</var>: it holds
/// <parameter>READPERMISSION</parameter> on that namespace's global-database resource.
/// <var>pFailedPair</var> names the pair that failed, and is <code>""</code> when the answer is
/// yes or when the namespace has no resource to test.</p>
/// <p>This is the entry check <method>OcuPilot.Api.Router.OnPreDispatch</method> applies to
/// <code>?ns=</code>, and it is deliberately <code>READ</code> alone: a namespace the caller can
/// read but not write scopes every read made there (DW-7), and the switch's own narrower rule
/// lives on the client.</p>
ClassMethod MayEnter(pNamespace As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tAllowed = 0
    Try {
        If '..GlobalDatabase(pNamespace, .tResource, .tReadOnly) Quit
        Set tAllowed = ..Holds(tResource, ..#READPERMISSION, .pFailedPair)
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p>Build the response body, writing nothing: <code>{scope, namespaces}</code>, each entry
/// <code>{name, writable}</code> plus <code>failedPair</code> only where the refusal is a
/// privilege.</p>
/// <p><b>A read-only mount carries no failed pair.</b> <code>HSLIB</code> on this image reports
/// <code>GlobalDB.ReadOnly = 1</code>, and no grant would make it writable, so naming a pair
/// there would send the user to change a privilege that is not the reason.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tSC = ..NamespaceNames(.tNames)
        If $$$ISERR(tSC) Quit
        Set tEntries = []
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If $Extract(tName) = ..#IMPLICITPREFIX Continue
            If '..GlobalDatabase(tName, .tResource, .tReadOnly) Continue
            Set tReadFailed = ""
            If '..Holds(tResource, ..#READPERMISSION, .tReadFailed) Continue
            Set tEntry = {}
            Do tEntry.%Set("name", tName)
            If tReadOnly {
                Do tEntry.%Set("writable", 0, "boolean")
            } Else {
                Set tWriteFailed = ""
                Set tWritable = ..Holds(tResource, ..#WRITEPERMISSION, .tWriteFailed)
                Do tEntry.%Set("writable", ''tWritable, "boolean")
                If 'tWritable, tWriteFailed '= "" Do tEntry.%Set("failedPair", tWriteFailed)
            }
            Do tEntries.%Push(tEntry)
        }
        Set pObject = {}
        Do pObject.%Set("scope", ##class(OcuPilot.Kernel.Scope).Current())
        Do pObject.%Set("namespaces", tEntries)
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer the request: one success envelope through the one success writer, or the one
/// generic internal envelope when the roster could not be built.</p>
ClassMethod Handle() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Payload(.tObject)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tObject)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>One <code>(resource, permission)</code> pair, asked of <method>GateClass</method>'s
/// evaluator so the check and the spelling of a failure are the gate's and not a second
/// copy.</p>
ClassMethod Holds(pResource As %String, pPermission As %String, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Quit $ClassMethod(..GateClass(), "EvaluatePairs", $ListBuild($ListBuild(pResource, pPermission)), .pFailedPair)
}

}
