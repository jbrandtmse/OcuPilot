/// <p>Subclass of <class>OcuPilot.Api.UiAbout</class> overriding the four seams
/// <class>OcuPilot.Kernel.Shell.About</class> declares -- one raw source read, the DocBook
/// application check, the <code>HELPADDRESS</code> lookup and the audit-log call -- so the
/// handler's own branches can be driven and captured without writing to the instance.</p>
/// <p>Each seam falls back to the production one when nothing is armed, the shape
/// <class>OcuPilot.Test.InstanceFixture</class> uses.</p>
Class OcuPilot.Test.UiAboutFixture Extends OcuPilot.Api.UiAbout
{

/// <p>Arm one source to <code>Throw</code>, which is what a refused or broken read looks like to
/// <method>OcuPilot.Kernel.Shell.About.Field</method>'s per-field <code>Try</code>. That field must
/// degrade to <code>""</code> while every other field and the payload's own status are
/// unchanged.</p>
ClassMethod SetSourceThrows(pField As %String)
{
    Set ^||OcuPilotAboutFixture("sourcethrows", pField) = 1
}

/// <p>Arm whether the instance is treated as serving its own documentation, so both branches of
/// <method>OcuPilot.Kernel.Shell.About.DocBookBase</method> are reachable on one container -- this
/// image ships no <code>/csp/docbook</code> application at all.</p>
ClassMethod SetDocBookEnabled(pEnabled As %Boolean)
{
    Set ^||OcuPilotAboutFixture("docbook") = ''pEnabled
}

/// <p>Arm the DocBook application check to raise, which is what a caller without read on the
/// <code>%SYS</code> database sees -- the ordinary case for a least-privileged operator, and the
/// one that must degrade without writing a log line.</p>
ClassMethod SetDocBookThrows()
{
    Set ^||OcuPilotAboutFixture("docbookthrows") = 1
}

/// <p>Arm the <code>HELPADDRESS</code> a class is treated as publishing. <code>""</code> is the
/// interesting value: a compiled classic page that declares no address.</p>
ClassMethod SetHelpAddress(pClass As %String, pAddress As %String)
{
    Set ^||OcuPilotAboutFixture("helpaddress", pClass) = pAddress
}

/// <p>Forget every override and any captured log call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotAboutFixture
}

/// <p>The field named by the last <method>LogSourceFailure</method> call, and how many such calls
/// there were. A refused read must reach the log naming which field it was, and a read that
/// succeeded must log nothing.</p>
ClassMethod SourceLogged() As %String
{
    Quit $Get(^||OcuPilotAboutFixture("sourcelogged"), "")
}

ClassMethod SourceLogCalls() As %Integer
{
    Quit $Get(^||OcuPilotAboutFixture("sourcelogcalls"), 0)
}

ClassMethod ReadSource(pField As %String) As %String
{
    If $Data(^||OcuPilotAboutFixture("sourcethrows", pField)) {
        Throw ##class(%Exception.General).%New("UiAboutFixture", 1, , "fixture: " _ pField _ " source refused")
    }
    Quit ##super(pField)
}

ClassMethod ReadDocBookApplication() As %Boolean
{
    If $Data(^||OcuPilotAboutFixture("docbookthrows")) {
        Throw ##class(%Exception.General).%New("UiAboutFixture", 1, , "fixture: the DocBook application check was refused")
    }
    Quit ##super()
}

ClassMethod DocBookEnabled() As %Boolean
{
    If '$Data(^||OcuPilotAboutFixture("docbook")) Quit ##super()
    Quit ''^||OcuPilotAboutFixture("docbook")
}

ClassMethod HelpAddress(pClass As %String) As %String
{
    If '$Data(^||OcuPilotAboutFixture("helpaddress", pClass)) Quit ##super(pClass)
    Quit ^||OcuPilotAboutFixture("helpaddress", pClass)
}

ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Set ^||OcuPilotAboutFixture("sourcelogged") = pField
    Set ^||OcuPilotAboutFixture("sourcelogcalls") = $Get(^||OcuPilotAboutFixture("sourcelogcalls"), 0) + 1
}

}
