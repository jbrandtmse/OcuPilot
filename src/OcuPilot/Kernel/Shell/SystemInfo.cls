/// <p>The instance state Home's System Information panel reports (Story 15.4, FR-73, AD-5,
/// AD-36's shell-chrome exception, AD-43).</p>
/// <p><class>OcuPilot.Api.UiSystem</class> answers it as
/// <code>GET /api/ocupilot/ui/system</code>. It is not a screen, a declared read or a tool, and
/// it declares no auto-refresh: the panel settles with this one read and Home stays absent from
/// AD-43's roster.</p>
/// <p><b>Each of the seven <method>Members</method> is read in the calling process behind its own
/// <code>Try</code></b> (<method>Field</method>), so a refused or absent source degrades that one
/// member to <code>""</code> and reaches the log, and the others still answer --
/// <class>OcuPilot.Kernel.Shell.About</class>'s <method>ReadSource</method> seam, copied.</p>
/// <p><b>Three sources, one sample.</b> The five dashboard members come from a single
/// <method>Sample</method> of <parameter>DASHBOARDCLASS</parameter>, taken once per payload in
/// <code>%SYS</code> by explicit save and restore with the restore as the first line of the
/// <code>Catch</code> (AD-16) -- that class is not mapped to an application namespace and raises
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code> there. Mirror state and production status answer in
/// the request's own namespace and need no switch.</p>
/// <p><b>Every state word is the source's own</b> -- the dashboard's
/// <code>Normal</code>/<code>Warning</code>/<code>Troubled</code>, the mirror's
/// <code>Not initialized</code>/<code>Primary</code>/..., and the vendor's own English production
/// word. Nothing here translates one or invents a vocabulary of its own; only the panel's row
/// labels are OcuPilot strings.</p>
Class OcuPilot.Kernel.Shell.SystemInfo Extends %RegisteredObject
{

/// <p>The subsystem name a refused source is logged under.</p>
Parameter LOGSUBSYSTEM = "uisystem";

/// <p>The class the five dashboard members are sampled from. Reached by name rather than by
/// <code>##class()</code> because it exists only in <code>%SYS</code>, so a compiled reference
/// from an application namespace would not resolve.</p>
Parameter DASHBOARDCLASS As %String = "SYS.Stats.Dashboard";

/// <p>The name the shared dashboard sample is logged under when it fails. It is not a member:
/// one sample serves five of them, so a failed sample degrades those five and names itself
/// once rather than five times.</p>
Parameter DASHBOARDSOURCE As %String = "dashboard";

/// <p>The leading element <method>%SYSTEM.Mirror.GetMemberStatus</method> answers when it caught
/// its own error. It is normalized to <code>""</code> rather than rendered, because it is not a
/// mirror state a reader can act on.</p>
Parameter MIRRORERROR As %String = "Error";

/// <p>How long the production read waits for the interoperability runtime lock, in seconds. Home
/// is chrome and must not block on a contended instance, so a lock this read cannot take in that
/// time degrades this one member.</p>
Parameter PRODUCTIONLOCKTIMEOUT As %Integer = 2;

/// <p>The prefix <method>Ens.Config.Production.ProductionStateToText</method> answers for a state
/// code it has no arm for. It is a diagnostic token rather than a state word, so an answer
/// carrying it degrades to <code>""</code>.</p>
Parameter PRODUCTIONUNRECOGNIZED As %String = "Unrecognized:";

/// <p>The seven members <method>Payload</method> reads through <method>Field</method>, in the
/// order the panel lists them. A member's name is also its <method>ReadSource</method> field
/// name, so there is one vocabulary rather than two to keep aligned.</p>
ClassMethod Members() As %List
{
    Quit $ListBuild("uptime", "mirror", "databaseSpace", "journalSpace", "lockTable", "writeDaemon", "production")
}

/// <p>Build the panel's state, writing nothing. <var>pObject</var> carries the seven members
/// <method>Members</method> names, each as a string.</p>
/// <p>Every member is emitted, <code>""</code> included: a value the instance does not report is
/// <code>""</code> on the wire and the panel's row shows its not-reported word, which is a
/// different thing from a key the response never carried.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set pObject = {}
        Kill tDashboard
        Do ..Dashboard(.tDashboard)
        Set tMembers = ..Members()
        For tI = 1:1:$ListLength(tMembers) {
            Set tMember = $List(tMembers, tI)
            Do pObject.%Set(tMember, ..Field(tMember, .tDashboard), "string")
        }
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One raw read, behind its own <code>Try</code>. <var>pField</var> is one of
/// <method>Members</method> and <var>pDashboard</var> is <method>Dashboard</method>'s sample; a
/// refusal reads <code>""</code> and reaches the log through <method>LogSourceFailure</method>
/// rather than failing the payload.</p>
ClassMethod Field(pField As %String, ByRef pDashboard) As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource(pField, .pDashboard)
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure(pField, ex)
    }
    Quit tValue
}

/// <p>The seven raw reads behind one seam; an unknown field reads <code>""</code>.</p>
/// <p>The seam exists so a test can make one source fail without touching the instance, and so
/// the per-field <code>Try</code> in <method>Field</method> has something to guard. Production
/// never overrides it. The five dashboard members are read out of <var>pDashboard</var>, which
/// <method>Dashboard</method> has already filled or left empty; the other two reach their
/// accessors here, neither of which switches namespace (AD-16).</p>
ClassMethod ReadSource(pField As %String, ByRef pDashboard) As %String
{
    If pField = "mirror" Quit ..MirrorState()
    If pField = "production" Quit ..ProductionState()
    If $ListFind(..Members(), pField) = 0 Quit ""
    Quit $Get(pDashboard(pField))
}

/// <p>The five dashboard members, sampled once and left in <var>pDashboard</var> keyed by member
/// name. A sample that fails leaves it empty, so those five degrade to <code>""</code> together
/// and the failure is logged once under <parameter>DASHBOARDSOURCE</parameter>.</p>
/// <p>The switch to <code>%SYS</code> is explicit save and restore with the restore as the first
/// line of the <code>Catch</code> (AD-16).</p>
ClassMethod Dashboard(Output pDashboard)
{
    Kill pDashboard
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ..SampleDashboard(.pDashboard)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Kill pDashboard
        Do ..LogSourceFailure(..#DASHBOARDSOURCE, ex)
    }
    Quit
}

/// <p>One <method>Sample</method> of <parameter>DASHBOARDCLASS</parameter>, projected into
/// <var>pDashboard</var> under the member names <method>Members</method> uses.</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> is already <code>%SYS</code></b> --
/// <method>Dashboard</method> switches and restores around this call. Raises whatever the sample
/// raises; the caller owns the degrade. Overridable so a test can drive the refused branch on a
/// container whose own privileges never refuse; production never overrides it.</p>
/// <p><code>SystemUpTime</code> is carried verbatim: the vendor formats it
/// (<code>"4d  4h 08m"</code>, two spaces), and reformatting it would publish a duration OcuPilot
/// computed rather than the one the instance reports. A metric the Application Monitor has not
/// collected answers <code>""</code>, which is an absence rather than a fault.</p>
ClassMethod SampleDashboard(Output pDashboard)
{
    Kill pDashboard
    Set tSample = $ClassMethod(..#DASHBOARDCLASS, "Sample")
    If '$IsObject(tSample) Quit
    Set pDashboard("uptime") = tSample.SystemUpTime
    Set pDashboard("databaseSpace") = tSample.DatabaseSpace
    Set pDashboard("journalSpace") = tSample.JournalSpace
    Set pDashboard("lockTable") = tSample.LockTable
    Set pDashboard("writeDaemon") = tSample.WriteDaemon
    Set tSample = ""
    Quit
}

/// <p>This member's mirror state as the vendor words it for a reader --
/// <code>Not initialized</code> on an instance that is not a mirror member.</p>
/// <p><method>%SYSTEM.Mirror.GetMemberStatus</method> is used rather than
/// <method>GetStatus</method>, which answers the raw token (<code>NOTINIT</code>) rather than a
/// word. It sets its own trap and answers <code>$LB("Error", $ZE)</code> instead of raising, so
/// <method>Field</method>'s <code>Try</code> would never fire: that answer is raised here, which
/// is what makes a failed mirror read degrade and log like any other rather than render as a
/// plausible state.</p>
/// <p>Only the first element is reported. The second, where the vendor sets one, is the primary's
/// trouble flag, and composing the two would publish a state word neither the vendor nor this
/// product declares.</p>
ClassMethod MirrorState() As %String
{
    Set tStatus = ..MirrorStatus()
    Set tState = $ListGet(tStatus, 1)
    If tState = ..#MIRRORERROR {
        Throw ##class(%Exception.General).%New("OcuPilot.Kernel.Shell.SystemInfo", 1, , "the mirror member status could not be read: " _ $ListGet(tStatus, 2))
    }
    Quit tState
}

/// <p>The vendor's own answer, as the <code>$List</code> it returns. Overridable so a test can
/// drive a state this container is not in -- including the caught-error answer, which no healthy
/// instance produces; production never overrides it.</p>
ClassMethod MirrorStatus() As %List
{
    Quit $SYSTEM.Mirror.GetMemberStatus()
}

/// <p>The production status of the namespace this request is scoped to, as the vendor's own
/// English word, with the production's name in parentheses where the instance reports one.</p>
/// <p><b>Scoped to the request's namespace, deliberately.</b> Interoperability is per namespace,
/// and the router stashes the validated <code>?ns=</code> in <class>OcuPilot.Kernel.Scope</class>
/// without assigning <code>$NAMESPACE</code> (AD-44, AD-21), so the scope is read from
/// <method>OcuPilot.Kernel.Scope.Current</method> -- which falls back to <code>$NAMESPACE</code>
/// for an in-process caller that never went through the router -- and entered by explicit save and
/// restore with the restore as the first line of the <code>Catch</code> (AD-16). No namespace is
/// accepted from the caller. A namespace that is not production-enabled answers <code>""</code>
/// and is not a fault; <method>%Library.EnsembleMgr.IsEnsembleNamespace</method> catches its own
/// error, so a caller who may not read those nodes takes the same branch.</p>
/// <p><method>Ens.Config.Production.ProductionStateToText</method> is called with
/// <var>pLocalize</var> 0 so the English word is returned whatever the session language (NFR-14).
/// A state code it has no arm for -- 5, 6 and -5 all reach it -- maps to its
/// <parameter>PRODUCTIONUNRECOGNIZED</parameter> token, which degrades to <code>""</code> so the
/// row shows its not-reported word rather than publishing a diagnostic as though it were a
/// state.</p>
ClassMethod ProductionState() As %String
{
    If '..ProductionEnabled() Quit ""
    Set tScope = ##class(OcuPilot.Kernel.Scope).Current()
    Set tOrigNS = $NAMESPACE
    Set tName = ""
    Set tState = ""
    Set tText = ""
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = tScope
        Set tSC = ..ProductionStatus(.tName, .tState)
        If $$$ISOK(tSC) Set tText = ##class(Ens.Config.Production).ProductionStateToText(tState, 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }
    If $Extract(tText, 1, $Length(..#PRODUCTIONUNRECOGNIZED)) = ..#PRODUCTIONUNRECOGNIZED Quit ""
    If tName = "" Quit tText
    Quit tText _ " (" _ tName _ ")"
}

/// <p>The vendor's own answer for the scoped namespace, as the status and outputs
/// <method>Ens.Director.GetProductionStatus</method> returns. Overridable so a test can drive a
/// state this container is not in -- including a code the vendor's own text mapping has no arm
/// for, and a refused read -- which no healthy instance produces; production never overrides
/// it.</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> is already the scoped namespace</b> --
/// <method>ProductionState</method> switches and restores around this call.</p>
ClassMethod ProductionStatus(Output pName As %String, Output pState As %Integer) As %Status
{
    Quit ##class(Ens.Director).GetProductionStatus(.pName, .pState, ..#PRODUCTIONLOCKTIMEOUT, 1)
}

/// <p>Whether the namespace this request is scoped to is production-enabled --
/// <method>OcuPilot.Kernel.Scope.Current</method>, not <code>$NAMESPACE</code>, for the reason
/// <method>ProductionState</method> records. Overridable so a test can drive the
/// non-interoperability branch on a namespace that is one; production never overrides it.</p>
ClassMethod ProductionEnabled() As %Boolean
{
    Quit ##class(%Library.EnsembleMgr).IsEnsembleNamespace(##class(OcuPilot.Kernel.Scope).Current())
}

/// <p>The audit-log seam a refused read travels through, so a member that degraded to
/// <code>""</code> is recoverable from the log rather than silently absent from the panel.
/// <var>pField</var> is the member that failed, or
/// <parameter>DASHBOARDSOURCE</parameter> for the sample the five dashboard members share.</p>
/// <p>It swallows its own failure: it is called from inside a per-field <code>Catch</code>, and an
/// exception escaping here would reach <method>Payload</method>'s <code>Catch</code> and turn a
/// degraded member into the failure the per-field <code>Try</code> exists to prevent. Overridable
/// for capture in a test; production never overrides it.</p>
ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, "A System information source could not be read", {"field": (pField), "detail": (pException.DisplayString())})
    } Catch {
    }
}

}
