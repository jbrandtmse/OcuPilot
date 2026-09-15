/// <p>DW-207: <method>OcuPilot.Install.Installer.Names</method> refuses a roster declaration it
/// cannot assert -- a relative application path, an application with no <code>matchRole</code>,
/// and an application with an empty asserted property set -- each by a message naming the roster
/// key. Driven through <class>OcuPilot.Test.RosterFault</class>; installs nothing and writes
/// nothing.</p>
Class OcuPilot.Test.RosterRefusal Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.RosterFault).Disarm()
    Quit $$$OK
}

/// <p>The armed fault's refusal text, asserted to fail and to name the first roster key.</p>
Method Refusal(pFault As %String) As %String
{
    Do ##class(OcuPilot.Test.RosterFault).Arm(pFault)
    Set tSC = ##class(OcuPilot.Test.RosterFault).NamesFor("", .tNames)
    Do ##class(OcuPilot.Test.RosterFault).Disarm()
    Do $$$AssertStatusNotOK(tSC, "Names refuses the '" _ pFault _ "' roster")
    Set tText = $System.Status.GetErrorText(tSC)
    Set tKey = $Piece(##class(OcuPilot.Install.Roster).Keys(), ",", 1)
    Do $$$AssertTrue((tKey '= "") && (tText [ ("'" _ tKey _ "'")), "the refusal names the roster key '" _ tKey _ "': " _ tText)
    Quit tText
}

/// <p>The unarmed fault class resolves the shipped roster, so each refusal below is the fault's
/// doing and not a broken driver.</p>
Method TestTheUnarmedRosterResolves()
{
    Set tSC = ##class(OcuPilot.Test.RosterFault).NamesFor("", .tNames)
    Do $$$AssertStatusOK(tSC, "the shipped roster resolves through the driver")
}

/// <p>Mutation (Rule 19): delete the absolute-path refusal from
/// <method>OcuPilot.Install.Installer.RosterNames</method> -- red.</p>
Method TestARelativePathIsRefused()
{
    Set tText = ..Refusal("relative")
    Do $$$AssertTrue(tText [ "declares no absolute path for application", "the refusal says the path is not absolute: " _ tText)
}

/// <p>Mutation (Rule 19): delete the <code>matchRole</code> refusal -- red.</p>
Method TestAMissingMatchRoleIsRefused()
{
    Set tText = ..Refusal("nomatchrole")
    Do $$$AssertTrue(tText [ "declares no matchRole", "the refusal says no matchRole is declared: " _ tText)
}

/// <p>Mutation (Rule 19): delete the empty-asserted-set refusal -- red.</p>
Method TestAnEmptyAssertedSetIsRefused()
{
    Set tText = ..Refusal("noasserted")
    Do $$$AssertTrue(tText [ "declares no asserted property for application", "the refusal says no property is asserted: " _ tText)
}

}
