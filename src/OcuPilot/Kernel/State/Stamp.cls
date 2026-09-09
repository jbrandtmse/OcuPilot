/// <p>One row per install run (AD-9's guarded storage, proven from the table side by
/// AC4/AC5). Named scalars deliberately, <b>not</b> a <code>list Of %String</code> --
/// each created-object name is a distinct, independently-meaningful field, never queried
/// as a homogeneous collection, so a subtable projection would buy nothing here (see
/// <file>.claude/rules/iris-persistent-storage.md</file>).</p>
Class OcuPilot.Kernel.State.Stamp Extends OcuPilot.Kernel.State.Base
{

/// <p>ISO-8601 UTC, e.g. <code>2026-09-09T10:30:45Z</code> (Consistency Conventions:
/// Dates -- <code>$ZTimeStamp</code>, never <code>$Horolog</code> or raw
/// <code>$ZDateTime</code>).</p>
Property Timestamp As %String(MAXLEN = 32);

/// <p>The install profile this run targeted: <code>""</code> for production or
/// <code>"probe"</code> for the disposable test seam.</p>
Property Profile As %String(MAXLEN = 16);

Property DatabaseName As %String(MAXLEN = 64);

Property DatabaseResourceName As %String(MAXLEN = 64);

Property AdminResourceName As %String(MAXLEN = 64);

Property AdminRoleName As %String(MAXLEN = 64);

Property ApplicationName As %String(MAXLEN = 64);

Property MappingPattern As %String(MAXLEN = 64);

/// <p><code>"granted"</code> or <code>"skipped-placeholder"</code> (AC9). Never a silent
/// skip -- when this is not <code>"granted"</code>, <property>GrantCommandHint</property>
/// always carries the exact command an operator must run.</p>
Property GrantOutcome As %String(MAXLEN = 32);

/// <p>Weak reference (AD-37): the username the administrative role was granted to,
/// stored as data, never as a foreign key -- <method>ResolveGrantedUser</method> is what
/// renders a since-deleted account correctly. <code>""</code> when no grant was made.</p>
Property GrantedUsername As %String(MAXLEN = 64);

/// <p>The exact <code>Security.Users.AddRoles(...)</code> command an operator must run
/// when <property>GrantOutcome</property> is not <code>"granted"</code>;
/// <code>""</code> when it is.</p>
Property GrantCommandHint As %String(MAXLEN = 256);

/// <p>Resolve <property>GrantedUsername</property> against the live instance, rendering
/// a user who no longer exists as <code>"no longer present"</code> rather than failing
/// (AD-37) -- <property>GrantedUsername</property> is data, not a foreign key, so IRIS
/// never tells OcuPilot when the account behind it is deleted. Returns <code>""</code>
/// unchanged when no grant was ever recorded.</p>
Method ResolveGrantedUser() As %String
{
    Set tUser = ..GrantedUsername
    If tUser = $Char(0) Set tUser = ""
    If tUser = "" Quit ""
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            Set tExists = ##class(Security.Users).Exists(tUser, .tU, .tUS)
        }
    } Catch {
        Set tExists = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit $Select(tExists: tUser, 1: "no longer present")
}

/// <p>Remove every stamp recorded for <var>pProfile</var>, through the escalated frame.
/// Stamp's own storage lives in the same table for every profile -- nothing about the
/// row-storage boundary is profile-specific the way the installer's own named objects
/// (database, resources, role, application, mapping) are -- so
/// <method>OcuPilot.Install.Installer.Uninstall</method> calls this for the disposable
/// <code>"probe"</code> profile to keep its own bookkeeping disposable too, alongside
/// the named objects it already removes.</p>
ClassMethod DeleteByProfile(pProfile As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Base).GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", pProfile)
}

}
