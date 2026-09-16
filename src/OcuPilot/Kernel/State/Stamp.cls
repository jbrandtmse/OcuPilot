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
/// <p><b>A production row reads back through SQL as <code>NULL</code>, not as
/// <code>''</code></b> -- IRIS stores an empty <code>%String</code> property as SQL
/// <code>NULL</code>, and <code>NULL = ''</code> is never true. Verified live: of 426
/// production rows, <code>WHERE Profile IS NULL</code> matches all 426 and
/// <code>WHERE Profile = ''</code> (literal or bound) matches none. A consumer that
/// wants production rows must write <code>WHERE Profile IS NULL</code>; a consumer that
/// wants a specific named profile writes <code>WHERE Profile = 'probe'</code> as usual.</p>
Property Profile As %String(MAXLEN = 16);

Property DatabaseName As %String(MAXLEN = 64);

Property DatabaseResourceName As %String(MAXLEN = 64);

Property AdminResourceName As %String(MAXLEN = 64);

Property AdminRoleName As %String(MAXLEN = 64);

Property ApplicationName As %String(MAXLEN = 64);

Property MappingPattern As %String(MAXLEN = 64);

/// <p>One of <code>"granted"</code>, <code>"alreadyheld"</code> and
/// <code>"skipped-placeholder"</code> (AC9). Never a silent skip -- on
/// <code>"skipped-placeholder"</code>, <property>GrantCommandHint</property> carries the exact
/// command an operator must run.</p>
/// <p><code>"granted"</code> names the run that actually granted the role, and is the only one
/// that wrote the <code>RoleGranted</code> audit marker; <code>"alreadyheld"</code> names a later
/// run that found the role already assigned and granted nothing.</p>
Property GrantOutcome As %String(MAXLEN = 32);

/// <p>Weak reference (AD-37): the username the administrative role was granted to,
/// stored as data, never as a foreign key -- <method>ResolveGrantedUser</method> is what
/// renders a since-deleted account correctly. It names the account that <b>holds</b> the role
/// after the run, so it is set on <code>"granted"</code> and on <code>"alreadyheld"</code> alike;
/// <code>""</code> only on <code>"skipped-placeholder"</code>, where nobody was granted and the
/// rejected identity is reported as data instead. Which of the two happened is
/// <property>GrantOutcome</property>'s answer, never this one's.</p>
Property GrantedUsername As %String(MAXLEN = 64);

/// <p>The exact <code>Security.Users.AddRoles(...)</code> command an operator must run when
/// <property>GrantOutcome</property> is <code>"skipped-placeholder"</code>; <code>""</code> on
/// the two outcomes that leave the role held.</p>
Property GrantCommandHint As %String(MAXLEN = 256);

/// <p>Resolve <property>GrantedUsername</property> against the live instance, rendering
/// a user who no longer exists as <code>"no longer present"</code> rather than failing
/// (AD-37) -- <property>GrantedUsername</property> is data, not a foreign key, so IRIS
/// never tells OcuPilot when the account behind it is deleted. Returns <code>""</code>
/// unchanged when the property is empty, which is the <code>"skipped-placeholder"</code>
/// outcome.</p>
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

/// <p>Remove the stamps recorded for a <b>named</b> profile, through the escalated frame.
/// Stamp's own storage lives in the same table for every profile -- nothing about the
/// row-storage boundary is profile-specific the way the installer's own named objects
/// (database, resources, role, application, mapping) are -- so
/// <method>OcuPilot.Install.Installer.Uninstall</method> calls this for the disposable
/// <code>"probe"</code> profile to keep its own bookkeeping disposable too, alongside
/// the named objects it already removes.</p>
/// <p><b>Passing the production profile (<code>""</code>) is a no-op, deliberately and
/// unavoidably.</b> A production row stores <property>Profile</property> as SQL
/// <code>NULL</code> (see that property), and neither a literal <code>''</code> nor a
/// bound empty parameter ever equals <code>NULL</code>, so the DELETE matches nothing and
/// returns <code>SQLCODE 100</code> -- a success, not an error. That is the right
/// outcome rather than a bug worth "fixing" with an <code>IS NULL</code> branch:
/// production stamps live inside the protected database itself, which
/// <method>OcuPilot.Install.Installer.Uninstall</method> deletes outright a few lines
/// earlier, and no acceptance criterion asks for install history to be destroyed
/// separately. Do not widen this predicate without deciding that question first.</p>
ClassMethod DeleteByProfile(pProfile As %String) As %Status
{
    ; Inherited dispatch (..), not ##class(OcuPilot.Kernel.State.Base): GuardedExecuteOneParam
    ; is [ Private ], and IRIS enforces that at runtime against the *named* class, so the
    ; explicit ##class() form raises <PRIVATE METHOD> from here even though Stamp extends
    ; Base. The escalation is unaffected -- the method still executes in Base's own
    ; routine, which is the one the privileged application's Routines allow-list names.
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", pProfile)
}

}
