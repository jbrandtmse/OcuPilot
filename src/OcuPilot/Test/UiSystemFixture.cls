/// <p>Subclass of <class>OcuPilot.Api.UiSystem</class> overriding the five seams
/// <class>OcuPilot.Kernel.Shell.SystemInfo</class> declares -- one raw source read, the
/// <code>%SYS</code> dashboard sample, the mirror accessor, the production-enabled check and the
/// audit-log call -- so the read's own branches can be driven and captured without writing to the
/// instance.</p>
/// <p>Each seam falls back to the production one when nothing is armed, the shape
/// <class>OcuPilot.Test.UiAboutFixture</class> uses. Needs an installed instance; it writes only
/// to its own process-private global.</p>
Class OcuPilot.Test.UiSystemFixture Extends OcuPilot.Api.UiSystem
{

/// <p>Arm one member's source to <code>Throw</code>, which is what a refused or broken read looks
/// like to <method>OcuPilot.Kernel.Shell.SystemInfo.Field</method>'s per-field <code>Try</code>.
/// That member must degrade to <code>""</code> while every other member and the payload's own
/// status are unchanged.</p>
ClassMethod SetSourceThrows(pField As %String)
{
    Set ^||OcuPilotSystemFixture("sourcethrows", pField) = 1
}

/// <p>Arm the dashboard sample to raise, which is what a caller without
/// <code>%Admin_Operate:USE</code> or read on <code>IRISSYS</code> sees. All five dashboard
/// members degrade together; mirror and production still answer.</p>
ClassMethod SetDashboardThrows()
{
    Set ^||OcuPilotSystemFixture("dashboardthrows") = 1
}

/// <p>Arm one dashboard member's sampled value, so the unsampled case -- a metric the Application
/// Monitor has not collected, which reads <code>""</code> -- is reachable on a container whose
/// own monitor has collected everything.</p>
ClassMethod SetDashboardValue(pField As %String, pValue As %String)
{
    Set ^||OcuPilotSystemFixture("dashboardvalue", pField) = pValue
}

/// <p>Arm what <method>%SYSTEM.Mirror.GetMemberStatus</method> is treated as answering, as a
/// <code>$List</code>. <code>$LB("Error", &lt;text&gt;)</code> is the interesting value: the
/// accessor catches its own error and reports it as a status rather than raising.</p>
ClassMethod SetMirrorStatus(pStatus As %List)
{
    Set ^||OcuPilotSystemFixture("mirrorstatus") = pStatus
}

/// <p>Arm whether this namespace is treated as production-enabled, so both production branches
/// are reachable on one container.</p>
ClassMethod SetEnsembleNamespace(pEnabled As %Boolean)
{
    Set ^||OcuPilotSystemFixture("ensns") = ''pEnabled
}

/// <p>Arm what <method>Ens.Director.GetProductionStatus</method> is treated as answering. The
/// interesting states are the ones the vendor's own text mapping has no arm for (5, 6 and -5),
/// which this container never reaches.</p>
ClassMethod SetProductionStatus(pName As %String, pState As %Integer)
{
    Set ^||OcuPilotSystemFixture("productionname") = pName
    Set ^||OcuPilotSystemFixture("productionstate") = pState
}

/// <p>Arm the production read to answer an error status, which is what a runtime lock this read
/// cannot take in <parameter>OcuPilot.Kernel.Shell.SystemInfo.PRODUCTIONLOCKTIMEOUT</parameter>
/// seconds looks like. That member degrades and logs; the other six answer.</p>
ClassMethod SetProductionStatusFails()
{
    Set ^||OcuPilotSystemFixture("productionfails") = 1
}

/// <p>Arm the production read to <code>Throw</code> rather than answer a status, so the
/// <code>Catch</code> in <method>OcuPilot.Kernel.Shell.SystemInfo.ProductionState</method> -- the
/// one AD-16 requires to restore the namespace before it rethrows -- is reached. No healthy
/// instance produces it; <method>SetProductionStatusFails</method> covers the refusal that does.</p>
ClassMethod SetProductionStatusThrows()
{
    Set ^||OcuPilotSystemFixture("productionthrows") = 1
}

/// <p>The namespace <code>$NAMESPACE</code> held when the production seam was last called. AD-16
/// says the scoped read enters its namespace by explicit save and restore, and this is what makes
/// "it ran in the scoped namespace" an observation rather than an inference: the seam's own caller
/// contract is that the switch has already happened.</p>
ClassMethod ProductionNamespace() As %String
{
    Quit $Get(^||OcuPilotSystemFixture("productionns"), "")
}

/// <p>Forget every override and any captured log call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSystemFixture
}

/// <p>The member named by the last <method>LogSourceFailure</method> call, and how many such
/// calls there were. A refused read must reach the log naming which source it was, and a read
/// that succeeded must log nothing.</p>
ClassMethod SourceLogged() As %String
{
    Quit $Get(^||OcuPilotSystemFixture("sourcelogged"), "")
}

ClassMethod SourceLogCalls() As %Integer
{
    Quit $Get(^||OcuPilotSystemFixture("sourcelogcalls"), 0)
}

ClassMethod ReadSource(pField As %String, ByRef pDashboard) As %String
{
    If $Data(^||OcuPilotSystemFixture("sourcethrows", pField)) {
        Throw ##class(%Exception.General).%New("UiSystemFixture", 1, , "fixture: " _ pField _ " source refused")
    }
    Quit ##super(pField, .pDashboard)
}

ClassMethod SampleDashboard(Output pDashboard)
{
    If $Data(^||OcuPilotSystemFixture("dashboardthrows")) {
        Throw ##class(%Exception.General).%New("UiSystemFixture", 1, , "fixture: the dashboard sample was refused")
    }
    Do ##super(.pDashboard)
    Set tField = ""
    For {
        Set tField = $Order(^||OcuPilotSystemFixture("dashboardvalue", tField))
        Quit:tField=""
        Set pDashboard(tField) = ^||OcuPilotSystemFixture("dashboardvalue", tField)
    }
    Quit
}

ClassMethod MirrorStatus() As %List
{
    If '$Data(^||OcuPilotSystemFixture("mirrorstatus")) Quit ##super()
    Quit ^||OcuPilotSystemFixture("mirrorstatus")
}

ClassMethod ProductionEnabled() As %Boolean
{
    If '$Data(^||OcuPilotSystemFixture("ensns")) Quit ##super()
    Quit ''^||OcuPilotSystemFixture("ensns")
}

ClassMethod ProductionStatus(Output pName As %String, Output pState As %Integer) As %Status
{
    Set ^||OcuPilotSystemFixture("productionns") = $NAMESPACE
    If $Data(^||OcuPilotSystemFixture("productionthrows")) {
        Throw ##class(%Exception.General).%New("UiSystemFixture", 1, , "fixture: the production read raised")
    }
    If $Data(^||OcuPilotSystemFixture("productionfails")) {
        Set pName = ""
        Set pState = ""
        Quit $$$ERROR($$$GeneralError, "fixture: the production status could not be read")
    }
    If '$Data(^||OcuPilotSystemFixture("productionstate")) Quit ##super(.pName, .pState)
    Set pName = $Get(^||OcuPilotSystemFixture("productionname"), "")
    Set pState = ^||OcuPilotSystemFixture("productionstate")
    Quit $$$OK
}

ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Set ^||OcuPilotSystemFixture("sourcelogged") = pField
    Set ^||OcuPilotSystemFixture("sourcelogcalls") = $Get(^||OcuPilotSystemFixture("sourcelogcalls"), 0) + 1
}

}
