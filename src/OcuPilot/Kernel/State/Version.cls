/// <p>The AD-38 version stamp the API checks (<class>OcuPilot.Api.Router</class>'s
/// traffic gate) -- <b>one row per profile</b>, updated in place, never a per-run history
/// like <class>OcuPilot.Kernel.State.Stamp</class>. Carries the profile's current
/// <property>SchemaVersion</property>, <property>Phase</property>
/// (<code>installing</code> | <code>installed</code> | <code>failed</code>),
/// <property>FailingStep</property> (set only when <property>Phase</property> is
/// <code>failed</code>), <property>UpdatedAt</property> (ISO-8601 UTC), and the deployed
/// build identity, so a stale browser bundle can eventually be prompted to reload
/// (Consumed-by: Story 1.5's DW-3).</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule;
/// nothing here is a homogeneous collection. No hand-written Storage.</p>
Class OcuPilot.Kernel.State.Version Extends OcuPilot.Kernel.State.Base
{

/// <p>The install profile this row tracks: <code>""</code> for production or
/// <code>"probe"</code> for the disposable test seam. Reads back through SQL as
/// <code>NULL</code>, not <code>''</code>, for the production row -- see
/// <class>OcuPilot.Kernel.State.Stamp</class>'s <property>Profile</property> for the
/// verified behavior this class relies on identically.</p>
Property Profile As %String(MAXLEN = 16);

/// <p>The schema version this profile's protected state is currently at. Advances only
/// after every migration step from the stored value up to the deployed
/// <parameter>OcuPilot.Install.Installer.SCHEMAVERSION</parameter> has succeeded.</p>
Property SchemaVersion As %Integer [ InitialExpression = 0 ];

/// <p><code>installing</code>, <code>installed</code> or <code>failed</code> -- never
/// any other value. A read failure or an absent row is <code>installing</code> at the
/// call site, not stored as a fourth value (see the golden example in this story's Design
/// Notes and <method>OcuPilot.Install.Installer.Phase</method>).</p>
Property Phase As %String(MAXLEN = 16) [ InitialExpression = "installing" ];

/// <p>Name of the step that failed, set only when <property>Phase</property> is
/// <code>failed</code>; <code>""</code> otherwise.</p>
Property FailingStep As %String(MAXLEN = 64);

/// <p>ISO-8601 UTC timestamp of the last write to this row
/// (Consistency Conventions: Dates). Excluded from
/// <method>OcuPilot.Install.Installer.StateFingerprint</method>'s composition (NFR-9's
/// Design Notes) -- a record of when install last ran is not drift.</p>
Property UpdatedAt As %String(MAXLEN = 32);

/// <p>The deployed build identity, recorded alongside the schema version so a client can
/// eventually be told its bundle is stale (Story 1.5's DW-3). A simple opaque string; not
/// itself versioned by this story.</p>
Property BuildIdentity As %String(MAXLEN = 64);

/// <p>Find <var>pProfile</var>'s current row, through the escalated frame. Returns
/// <var>pObject</var> as <code>$$$NULLOREF</code> when no row exists yet for this
/// profile -- a genuinely first start, never an error.</p>
ClassMethod GuardedCurrentForProfile(pProfile As %String, Output pObject) As %Status
{
    If pProfile = "" {
        ; A production row's Profile reads back as SQL NULL, never '' -- see this
        ; class's own Profile property doc and Stamp's identical, verified behavior.
        Quit ..GuardedOpenOneWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Version WHERE Profile IS NULL ORDER BY ID DESC", .pObject)
    }
    Quit ..GuardedOpenOneWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Version WHERE Profile = ? ORDER BY ID DESC", pProfile, .pObject)
}

/// <p>Remove every row recorded for <var>pProfile</var>, through the escalated frame --
/// the same disposable-test-seam purge shape as
/// <method>OcuPilot.Kernel.State.Stamp.DeleteByProfile</method>, and for the identical
/// reason: <code>"probe"</code> rows land in the <i>production</i> protected database
/// (this class's own data global starts with <code>OcuPilot</code>), so nothing else
/// removes them.</p>
/// <p><b>Passing <code>""</code> actually purges the production row</b> (review finding,
/// Fix Pack F-5, round 2: this used to bind <code>Profile = ?</code> with the literal
/// <code>''</code>, which never matches the SQL <code>NULL</code> a production row's
/// <property>Profile</property> actually reads back as -- so <code>Uninstall</code>'s own
/// comment claiming this "purges this profile's version row" was false for production. No
/// live harm today, since production's whole protected database is deleted before
/// <code>Uninstall</code> calls this -- but the comment must say what actually happens.
/// Same two-literal-query-texts shape <class>OcuPilot.Kernel.State.Demo</class>'s own
/// <method>DeleteByProfile</method> already uses, through
/// <method>OcuPilot.Kernel.State.Base.GuardedExecuteNoParam</method>'s zero-parameter
/// form.</p>
ClassMethod DeleteByProfile(pProfile As %String) As %Status
{
    If pProfile = "" {
        Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Version WHERE Profile IS NULL")
    }
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Version WHERE Profile = ?", pProfile)
}

}
