/// <p>One per-user screen-context sharing choice (FR-11, Story 4.4): whether this named user's
/// turns carry screen context, overriding the instance default
/// (<property>OcuPilot.Kernel.State.Switch.ShareContextByDefault</property>) for that user alone.
/// A user with no row here reads the instance default. Held in OcuPilot's protected database and
/// reached only through <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9), on the
/// pattern <class>OcuPilot.Kernel.State.Hold</class> established.</p>
/// <p><b>The user is a weak reference</b> (AD-37): <property>UserName</property> is the scoped
/// identity recorded as data, never a foreign key. A name that no longer resolves still reads back
/// verbatim and answers no read.</p>
/// <p><b>Nothing here is a gate.</b> <class>OcuPilot.Api.Turn</class> reads this row alone to
/// decide whether context is discarded before a turn starts; this class stores and answers.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule, and no
/// hand-written Storage.</p>
Class OcuPilot.Kernel.State.Sharing Extends OcuPilot.Kernel.State.Base
{

/// <p>The user this row's choice is for. Unique, so one user carries at most one row.</p>
/// <p>The length is <class>Security.Users</class>'s own <code>Name</code> length on this build, so
/// a name the instance accepts is a name this column holds.</p>
Property UserName As %String(MAXLEN = 160);

/// <p>Whether this user's turns carry screen context.</p>
Property Share As %Boolean [ InitialExpression = 1 ];

Index SharingUserNameIdx On UserName [ Unique ];

/// <p>Whether <var>pUserName</var> carries a row, and the choice it holds. <var>pFound</var> is 0
/// and <var>pShare</var> 0 when no row names the user -- the ordinary answer, never an error; the
/// caller then falls back to the instance default.</p>
/// <p><b>Matched the way the unique index matches</b>, which is case-insensitively (IRIS SQL
/// string comparison folds case by default and <property>UserNameIdx</property> collates the same
/// way).</p>
ClassMethod GuardedForUser(pUserName As %String, Output pFound As %Boolean, Output pShare As %Boolean) As %Status
{
    Set pFound = 0
    Set pShare = 0
    Set tSC = $$$OK
    Try {
        If pUserName = "" Quit
        Set tSC = ..GuardedOpenOneWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Sharing WHERE UserName = ? ORDER BY ID", pUserName, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set pFound = 1
        Set pShare = ''tRow.Share
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store <var>pUserName</var>'s choice, creating the row when there is none and updating it in
/// place otherwise.</p>
ClassMethod GuardedSetForUser(pUserName As %String, pShare As %Boolean) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedOpenOneWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Sharing WHERE UserName = ? ORDER BY ID", pUserName, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set tRow = ..%New()
            Set tRow.UserName = pUserName
        }
        Set tRow.Share = ''pShare
        Set tSC = ..GuardedSave(tRow)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every row this suite wrote, so a test leaves the instance default in force for every
/// user again.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Sharing")
}

}
