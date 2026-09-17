/// <p>The instance identity the shell reads (AD-27, NFR-8): the usable admin API version, the
/// instance's name and version, the build identity the version row recorded, and the three fields
/// the status bar names the instance with -- its system-mode flag, its licensee and its host node.
/// <class>OcuPilot.Api.Instance</class> answers it as <code>GET /api/ocupilot/instance</code> and
/// <class>OcuPilot.Kernel.Shell.InstanceRead</class> as the <code>shell.instance.read</code> tool,
/// so both answer the one object <method>Payload</method> builds.</p>
/// <p>The verification itself is <class>OcuPilot.Port.AdminPort</class>'s. A version other than 2
/// is carried as that number, never refused -- the client needs the number to name it.</p>
/// <p>Neither <code>%SYS.System</code> nor <code>$ZVERSION</code> needs a namespace switch
/// (AD-16).</p>
Class OcuPilot.Kernel.Shell.Instance Extends %RegisteredObject
{

/// <p>The subsystem name the verification detail is logged under.</p>
Parameter LOGSUBSYSTEM = "adminport";

/// <p>Build the instance identity, writing nothing. <var>pObject</var> carries
/// <code>adminApiVersion</code>, <code>instanceName</code>, <code>instanceVersion</code>,
/// <code>buildIdentity</code>, <code>serverFlag</code>, <code>licensedTo</code> and
/// <code>serverName</code>; a non-empty verification detail has already reached the log by
/// the time this returns.</p>
/// <p>Every status-bar field is emitted, empty string included: a field the instance cannot
/// report is <code>""</code> on the wire and the client drops its segment, which is a
/// different thing from a key the response never carried.</p>
/// <p><b>A failed verification is read and then deliberately not propagated.</b> Its
/// <class>%Status</class> is consulted only to source a detail for the log: the client
/// needs the number in order to name it, so a version it cannot use is carried as that
/// number, never refused. The status this method returns therefore reports
/// whether the <i>body could be built</i>, nothing about the instance.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tVersion = 0
        Set tDetail = ""
        Set tVerify = ..VerifyInstance(.tVersion, .tDetail)
        If $$$ISERR(tVerify) && (tDetail = "") Set tDetail = $System.Status.GetErrorText(tVerify)
        If tDetail '= "" Do ..LogDetail(tDetail)
        Set pObject = {}
        Do pObject.%Set("adminApiVersion", tVersion, "number")
        Do pObject.%Set("instanceName", ..InstanceName())
        Do pObject.%Set("instanceVersion", ..InstanceVersion())
        Do pObject.%Set("buildIdentity", ..BuildIdentity())
        Do pObject.%Set("serverFlag", ..ServerFlag())
        Do pObject.%Set("licensedTo", ..LicensedTo())
        Do pObject.%Set("serverName", ..ServerName())
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The admin API verification seam. Delegates to
/// <class>OcuPilot.Port.AdminPort</class>, the one class permitted to name an
/// <code>%Api.Admin.*</code> class (AD-27). Overridable so
/// <class>OcuPilot.Test.InstanceFixture</class> can drive this builder's own branches
/// without a fixture admin API; production never overrides it.</p>
ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).VerifyInstance(.pVersion, .pDetail)
}

/// <p>The deployed build identity, read from the production version row (AD-38). Empty when
/// no row exists or the read fails -- an instance that cannot say what it is running
/// reports nothing rather than a guess.</p>
/// <p>Overridable so the passthrough can be pinned against a value no live row would
/// carry; production never overrides it.</p>
ClassMethod BuildIdentity() As %String
{
    Set tIdentity = ""
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).CurrentVersionRow("", .tRow)
        If $$$ISOK(tSC) && $IsObject(tRow) Set tIdentity = tRow.BuildIdentity
    } Catch {
        Set tIdentity = ""
    }
    Quit tIdentity
}

/// <p>This instance's configured name.</p>
ClassMethod InstanceName() As %String
{
    Quit ##class(%SYS.System).GetInstanceName()
}

/// <p>This instance's IRIS version banner.</p>
ClassMethod InstanceVersion() As %String
{
    Quit $ZVersion
}

/// <p>This instance's system mode, verbatim, or <code>""</code> when none is set. The
/// vendor's setter upper-cases its argument and normalises anything outside
/// <code>LIVE</code>, <code>TEST</code>, <code>FAILOVER</code> and <code>DEVELOPMENT</code>
/// to <code>""</code> (<code>irissys/%SYSTEM/Version.cls</code>), so an empty answer is the
/// ordinary state of an unflagged instance and not a failure. A value outside those four can
/// only have been written to the global directly; it still travels verbatim, because
/// reporting it as one of the four would be a lie and dropping it would hide a
/// misconfiguration.</p>
ClassMethod ServerFlag() As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource("flag")
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure("flag", ex)
    }
    Quit tValue
}

/// <p>The customer name on the active licence key, or <code>""</code>.</p>
ClassMethod LicensedTo() As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource("licensee")
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure("licensee", ex)
    }
    Quit tValue
}

/// <p>The host node this instance runs on, or <code>""</code>.</p>
ClassMethod ServerName() As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource("node")
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure("node", ex)
    }
    Quit tValue
}

/// <p>The three raw reads the status-bar fields are built from, behind one seam.
/// <var>pField</var> is <code>flag</code>, <code>licensee</code> or <code>node</code>; an
/// unknown field reads <code>""</code>.</p>
/// <p>The seam exists so a test can make a source fail without touching the instance: each
/// caller above wraps this in its own <code>Try</code>, and that per-field
/// <code>Try</code> is what makes the question of whether these reads need a privilege moot
/// -- a refusal degrades that one field to <code>""</code>, names itself in the log through
/// <method>LogSourceFailure</method>, and the payload is still built.
/// Production never overrides it, and none of the three reads switches namespace
/// (AD-16).</p>
ClassMethod ReadSource(pField As %String) As %String
{
    If pField = "flag" Quit $SYSTEM.Version.SystemMode()
    If pField = "licensee" Quit $SYSTEM.License.KeyCustomerName()
    If pField = "node" Quit ##class(%SYS.System).GetNodeName()
    Quit ""
}

/// <p>The audit-log seam a refused status-bar read travels through, so a field that
/// degraded to <code>""</code> is recoverable from the log rather than being silently
/// absent from the band. <var>pField</var> is the field that failed.</p>
/// <p>It swallows its own failure: this is called from inside a per-field
/// <code>Catch</code>, and an exception escaping here would reach
/// <method>Payload</method>'s <code>Catch</code> and turn a degraded field into the failure the
/// per-field <code>Try</code> exists to prevent. Overridable for capture in a test;
/// production never overrides it.</p>
ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, "A status-bar source could not be read", {"field": (pField), "detail": (pException.DisplayString())})
    } Catch {
    }
}

/// <p>The audit-log seam the verification detail travels through, so an actionable message
/// reaches the log whatever the payload carries (AD-27). Overridable for capture in a test;
/// production never overrides it.</p>
ClassMethod LogDetail(pDetail As %String)
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, "Admin API verification reported a problem", {"detail": (pDetail)})
}

}
