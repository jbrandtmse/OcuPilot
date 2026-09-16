/// <p>The instance's agent switches (FR-19, FR-20): the kill switch and the reason an operator gave
/// for it, enforced read-only, and the instance default for screen-context sharing. <b>One row for
/// the whole instance</b>, updated in place, on the pattern
/// <class>OcuPilot.Kernel.State.Egress</class> established -- defaults as parameters, so a clean
/// instance answers without a row and install writes none.</p>
/// <p><b>Nothing here is a gate.</b> This class stores and answers; the one place that decides
/// whether a write may happen is <class>OcuPilot.Kernel.Restraint</class> (AD-30), which reads this
/// store, the per-user holds and the resolved definition together.</p>
/// <p><b>The class name is <code>Switch</code>, not <code>Switches</code></b>:
/// <code>OcuPilot.Kernel.State.Switches</code> is 30 characters against the 29-character cap
/// <file>scripts/check-objectscript.py</file> enforces on any class reaching
/// <class>%Persistent</class>, so the compiler would hash this class's storage global.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule, and no
/// hand-written Storage.</p>
Class OcuPilot.Kernel.State.Switch Extends OcuPilot.Kernel.State.Base [ SqlTableName = SwitchState ]
{

/// <p>Whether the agent is switched off for everyone on an instance that has stored nothing.
/// <b>Off</b>: a fresh install leaves the agent available, which is what "the kill switch is off
/// and no switch row exists" means.</p>
Parameter DEFAULTKILLSWITCH As %Integer = 0;

/// <p>Whether read-only is enforced on an instance that has stored nothing. Off, for the reason
/// above: enforcement is an operator's act, not an install's.</p>
Parameter DEFAULTENFORCEDREADONLY As %Integer = 0;

/// <p>Whether a new conversation shares screen context on an instance that has stored nothing
/// (FR-11). On, which is what the panel's own per-session switch starts at.</p>
Parameter DEFAULTSHARECONTEXT As %Integer = 1;

/// <p>Whether the agent is switched off for everyone.</p>
Property KillSwitch As %Boolean [ InitialExpression = 0 ];

/// <p>The reason an operator gave for switching the agent off. It fills the published kill-switch
/// banner's <code>&lt;reason&gt;</code>, so it is operator text carried verbatim and never composed
/// here.</p>
Property KillSwitchReason As %String(MAXLEN = 512);

/// <p>Whether every user's agent is restrained to reads (FR-19).</p>
Property EnforcedReadOnly As %Boolean [ InitialExpression = 0 ];

/// <p>The instance default for screen-context sharing, which seeds the panel's own per-session
/// switch (FR-11).</p>
Property ShareContextByDefault As %Boolean [ InitialExpression = 1 ];

/// <p>ISO-8601 UTC timestamp of the last write to this row.</p>
Property UpdatedAt As %String(MAXLEN = 32);

/// <p>The switches in force, as <var>pValues</var> subscripted by <code>killSwitch</code>,
/// <code>killSwitchReason</code>, <code>enforcedReadOnly</code>, <code>shareContextByDefault</code>
/// and <code>updatedAt</code>: the stored row's values where the instance holds one, the defaults
/// otherwise.</p>
/// <p>An instance with no row is the ordinary state, never an error. A read that fails answers the
/// defaults and says so through the error <class>%Status</class>; the caller decides what to do,
/// and <class>OcuPilot.Kernel.Restraint</class> treats a failed read as a refusal rather than as a
/// permission.</p>
ClassMethod Resolve(Output pValues) As %Status
{
    Kill pValues
    Set pValues("killSwitch") = ..#DEFAULTKILLSWITCH
    Set pValues("killSwitchReason") = ""
    Set pValues("enforcedReadOnly") = ..#DEFAULTENFORCEDREADONLY
    Set pValues("shareContextByDefault") = ..#DEFAULTSHARECONTEXT
    Set pValues("updatedAt") = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedCurrent(.tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set pValues("killSwitch") = ''tRow.KillSwitch
        Set pValues("killSwitchReason") = ..Text(tRow.KillSwitchReason)
        Set pValues("enforcedReadOnly") = ''tRow.EnforcedReadOnly
        Set pValues("shareContextByDefault") = ''tRow.ShareContextByDefault
        Set pValues("updatedAt") = ..Text(tRow.UpdatedAt)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <var>pValues</var> -- the same subscripts <method>Resolve</method> answers with -- to
/// the instance's one row, creating it when there is none. A subscript the caller omits keeps the
/// stored value, so setting the kill switch alone does not clear enforced read-only.</p>
/// <p><code>updatedAt</code> is this class's, never the caller's: a subscript of that name in
/// <var>pValues</var> is ignored.</p>
ClassMethod SetGuarded(ByRef pValues) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedCurrent(.tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Set tRow = ..%New()
        If $Data(pValues("killSwitch")) Set tRow.KillSwitch = ''+pValues("killSwitch")
        If $Data(pValues("killSwitchReason")) Set tRow.KillSwitchReason = pValues("killSwitchReason")
        If $Data(pValues("enforcedReadOnly")) Set tRow.EnforcedReadOnly = ''+pValues("enforcedReadOnly")
        If $Data(pValues("shareContextByDefault")) Set tRow.ShareContextByDefault = ''+pValues("shareContextByDefault")
        Set tRow.UpdatedAt = ..Timestamp()
        Set tSC = ..GuardedSave(tRow)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the instance's switch row, so a test that wrote one leaves the defaults in force
/// again. Absent is never an error.</p>
ClassMethod DeleteGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.SwitchState")
}

/// <p>The one row, or <code>$$$NULLOREF</code> when the instance holds none. The lowest id wins, so
/// a second row written by a concurrent create is ignored rather than alternating with the first:
/// the switches are instance-wide and there is nothing to choose between two of them.</p>
ClassMethod GuardedCurrent(Output pObject) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID", .pObject)
}

/// <p>ISO-8601 UTC, e.g. <code>2026-09-15T10:30:45Z</code> -- <code>$ZTimeStamp</code>, never
/// <code>$Horolog</code>, and never raw <code>$ZDateTime</code>, which is space-separated.</p>
ClassMethod Timestamp() As %String
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> of a
/// <code>%String</code> column reads back as normalized to <code>""</code>
/// (<file>.claude/rules/objectscript-basics.md</file>). Every write here goes through the object
/// layer, so the sentinel cannot arrive today; the normalization is at the read site because that
/// is where it stays correct if one ever does.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
