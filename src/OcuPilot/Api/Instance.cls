/// <p>The handler behind <code>GET /api/ocupilot/instance</code> -- OcuPilot's first data
/// call. It reports the usable admin API version, the instance's name and version, and the
/// build identity the version row recorded, so the shell can verify the instance it is
/// talking to before rendering any screen (AD-27, NFR-8).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the verification itself is
/// <class>OcuPilot.Port.AdminPort</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12). A version other than 2 is a 200 carrying
/// that number, never an error envelope -- the client needs the number to name it.</p>
/// <p>Neither <code>%SYS.System</code> nor <code>$ZVERSION</code> needs a namespace switch
/// (AD-16).</p>
Class OcuPilot.Api.Instance Extends %RegisteredObject
{

/// <p>The subsystem name the verification detail is logged under.</p>
Parameter LOGSUBSYSTEM = "adminport";

/// <p>Build the response body, writing nothing. <var>pObject</var> carries
/// <code>adminApiVersion</code>, <code>instanceName</code>, <code>instanceVersion</code>
/// and <code>buildIdentity</code>; a non-empty verification detail has already reached the
/// log by the time this returns.</p>
/// <p><b>A failed verification is read and then deliberately not propagated.</b> Its
/// <class>%Status</class> is consulted only to source a detail for the log: the client
/// needs the number in order to name it, so a version it cannot use is a 200 carrying that
/// number, never an error envelope. The status this method returns therefore reports
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
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer the request: one success envelope through the one success writer, or the one
/// generic internal envelope when the body could not be built.</p>
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

/// <p>The admin API verification seam. Delegates to
/// <class>OcuPilot.Port.AdminPort</class>, the one class permitted to name an
/// <code>%Api.Admin.*</code> class (AD-27). Overridable so
/// <class>OcuPilot.Test.InstanceFixture</class> can drive the handler's own branches
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

/// <p>The audit-log seam the verification detail travels through, so an actionable message
/// reaches the log whatever the response says (AD-27). Overridable for capture in a test;
/// production never overrides it.</p>
ClassMethod LogDetail(pDetail As %String)
{
    Do ##class(OcuPilot.Api.Error).LogError(..#LOGSUBSYSTEM, "Admin API verification reported a problem", {"detail": (pDetail)})
}

}
