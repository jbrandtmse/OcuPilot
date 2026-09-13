/// <p>The provenance record for a web application OcuPilot's installer put on this instance
/// (DW-94, the owner's decision of 2026-09-11) -- one row per application path, written the
/// first time <method>OcuPilot.Install.Installer.Install</method> creates or recognises that
/// application, read before any repair, and the only thing
/// <method>OcuPilot.Install.Installer.Uninstall</method> will remove an application on the
/// strength of.</p>
/// <p><b>Why a record rather than an existence test.</b> Before it, the installer's one
/// question about an application at a roster path was
/// <code>Security.Applications.Exists</code>, so an application some other product had put at
/// <code>/ocupilot</code> was adopted, rewritten to OcuPilot's asserted properties, and
/// deleted by an uninstall that had never created it. The record makes "install created this"
/// a fact on the instance instead of an inference from a path.</p>
/// <p><b>One row per path, and the path is the key.</b> The probe profile's application paths
/// are distinct literals from production's
/// (<method>OcuPilot.Install.Installer.ProbeApplicationPath</method>), so a path identifies
/// one application on one instance whichever profile owns it;
/// <property>Profile</property> is carried so an uninstall removes its own profile's rows and
/// no other's.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per
/// <file>.claude/rules/iris-persistent-storage.md</file>; no hand-written Storage. The class
/// name is 28 characters, inside the 29-character storage-global cap.</p>
Class OcuPilot.Kernel.State.WebApp Extends OcuPilot.Kernel.State.Base
{

/// <p>The install profile that owns this application: <code>""</code> for production or
/// <code>"probe"</code> for the disposable test seam. Reads back through SQL as
/// <code>NULL</code>, not <code>''</code>, for a production row -- see
/// <class>OcuPilot.Kernel.State.Stamp</class>'s <property>Profile</property> for the verified
/// behaviour this class relies on identically, and why every production-profile query here
/// binds nothing and says <code>IS NULL</code>.</p>
Property Profile As %String(MAXLEN = 16);

/// <p>The web application's path, exactly as <code>Security.Applications</code> names it
/// (<code>/ocupilot</code>, <code>/api/ocupilot</code>, <code>/api/ocupilot/readiness</code>,
/// or the probe profile's equivalents).</p>
Property Path As %String(MAXLEN = 256);

/// <p>How this row came to exist: <code>created</code> when install created the application
/// itself, or <code>adopted</code> when install found one already at the path that declares
/// OcuPilot's own dispatch class -- which is what an IPM install looks like, since IPM's own
/// <code>&lt;WebApplication&gt;</code> elements create both applications in the
/// <code>Activate</code> phase before the <code>When="After"</code> <code>&lt;Invoke&gt;</code>
/// runs <method>OcuPilot.Install.Installer.Install</method> at all.</p>
Property Origin As %String(MAXLEN = 16);

/// <p>ISO-8601 UTC (Consistency Conventions: Dates).</p>
Property RecordedAt As %String(MAXLEN = 32);

/// <p>Whether the CSP Gateway registration gap has already been reported for this application
/// (AD-27). <code>Security.Applications.Create</code> does not notify the Gateway, so a newly
/// created path can 404 until an SMP Save or a Gateway restart; that is information worth
/// emitting once, when the application first appears, and noise on every later install. The
/// flag lives on the record rather than in a per-run array because the run that first
/// <i>records</i> an application is the run that has news, and on the IPM path that run
/// created nothing itself (DW-198).</p>
Property GatewayReported As %Boolean [ InitialExpression = 0 ];

/// <p>The row recording the application at <var>pPath</var>, or <code>$$$NULLOREF</code> when
/// none does -- never an error. Read through the escalated frame.</p>
ClassMethod GuardedForPath(pPath As %String, Output pObject) As %Status
{
    Quit ..GuardedOpenOneWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.WebApp WHERE %EXACT(Path) = ? ORDER BY ID DESC", pPath, .pObject)
}

/// <p>Every application path <var>pProfile</var> has a record for, as
/// <var>pPaths(&lt;path&gt;) = &lt;origin&gt;</var>. An empty answer is "this profile has
/// recorded no application", which on a genuinely first install is the truth.</p>
ClassMethod GuardedPathsForProfile(pProfile As %String, Output pPaths) As %Status
{
    Set tSC = $$$OK
    Kill pPaths
    Try {
        If pProfile = "" {
            Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.WebApp WHERE Profile IS NULL ORDER BY ID", .tIds)
        } Else {
            Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.WebApp WHERE Profile = ? ORDER BY ID", pProfile, .tIds)
        }
        If $$$ISERR(tSC) Quit
        Set tN = $Order(tIds(""))
        While tN '= "" {
            Set tSC = ..GuardedOpenId(tIds(tN), .tRow)
            If $$$ISERR(tSC) Quit
            Set pPaths(tRow.Path) = tRow.Origin
            Set tN = $Order(tIds(tN))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pPaths
    Quit tSC
}

/// <p>Every application path <var>pProfile</var> has a record for whose CSP Gateway
/// registration gap has not been reported yet, as <var>pPaths(&lt;path&gt;) = ""</var> --
/// what <method>OcuPilot.Install.Installer.ReportGatewayGap</method> has news about. An
/// instance whose applications were all recorded on an earlier run has none, which is why a
/// repeat install says nothing about them.</p>
ClassMethod GuardedUnreportedForProfile(pProfile As %String, Output pPaths) As %Status
{
    Set tSC = $$$OK
    Kill pPaths
    Try {
        If pProfile = "" {
            Set tSC = ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.WebApp WHERE Profile IS NULL AND GatewayReported = 0 ORDER BY ID", .tIds)
        } Else {
            Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.WebApp WHERE Profile = ? AND GatewayReported = 0 ORDER BY ID", pProfile, .tIds)
        }
        If $$$ISERR(tSC) Quit
        Set tN = $Order(tIds(""))
        While tN '= "" {
            Set tSC = ..GuardedOpenId(tIds(tN), .tRow)
            If $$$ISERR(tSC) Quit
            Set pPaths(tRow.Path) = ""
            Set tN = $Order(tIds(tN))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pPaths
    Quit tSC
}

/// <p>Record that install created (<var>pOrigin</var> <code>"created"</code>) or recognised
/// (<code>"adopted"</code>) the application at <var>pPath</var> for <var>pProfile</var>.
/// Idempotent: a path that already carries a row is left exactly as it is, so a repeat install
/// never rewrites the origin or re-arms the Gateway-gap report.</p>
ClassMethod GuardedRecord(pProfile As %String, pPath As %String, pOrigin As %String) As %Status
{
    Set tSC = ..GuardedForPath(pPath, .tExisting)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tExisting) Quit $$$OK
    Set tRow = ..%New()
    Set tRow.Profile = pProfile
    Set tRow.Path = pPath
    Set tRow.Origin = pOrigin
    Set tRow.RecordedAt = $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
    Set tRow.GatewayReported = 0
    Quit ..GuardedSave(tRow)
}

/// <p>Mark the application at <var>pPath</var> as having had its CSP Gateway registration gap
/// reported, so the next install says nothing about it. A path with no row is not an error --
/// there is nothing to mark.</p>
ClassMethod GuardedMarkGatewayReported(pPath As %String) As %Status
{
    Set tSC = ..GuardedForPath(pPath, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$OK
    Set tRow.GatewayReported = 1
    Quit ..GuardedSave(tRow)
}

/// <p>Remove the record for <var>pPath</var>, through the escalated frame --
/// <method>OcuPilot.Install.Installer.Uninstall</method>'s counterpart to
/// <method>GuardedRecord</method>, called once the application itself is gone.</p>
ClassMethod DeleteByPath(pPath As %String) As %Status
{
    ; Inherited dispatch (..), not ##class(OcuPilot.Kernel.State.Base): GuardedExecuteOneParam
    ; is [ Private ] and IRIS enforces that against the named class -- see
    ; OcuPilot.Kernel.State.Stamp.DeleteByProfile for the same note.
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.WebApp WHERE %EXACT(Path) = ?", pPath)
}

}
