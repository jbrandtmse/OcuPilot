/// <p>One per-user kill-switch hold (FR-20): the agent is switched off for the user this row names,
/// with the reason an operator gave. Held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9).</p>
/// <p><b>The user is a weak reference</b> (AD-37): <property>UserName</property> is the scoped
/// identity recorded as data, never a foreign key. IRIS does not tell OcuPilot when a user is
/// deleted, so a name that no longer resolves still reads back verbatim and fails no read; whether
/// it still resolves is resolved where a namespace switch is allowed --
/// <class>OcuPilot.Api.Switches</class> -- and never here.</p>
/// <p><b>Nothing here is a gate.</b> <class>OcuPilot.Kernel.Restraint</class> is the one place that
/// decides whether a write may happen (AD-30); this class stores and answers.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule, and no
/// hand-written Storage.</p>
Class OcuPilot.Kernel.State.Hold Extends OcuPilot.Kernel.State.Base
{

/// <p>The user the agent is switched off for. Unique, so one user carries at most one hold.</p>
/// <p>The length is <class>Security.Users</class>'s own <code>Name</code> length on this build, so
/// a name the instance accepts is a name this column holds.</p>
Property UserName As %String(MAXLEN = 160);

/// <p>The reason an operator gave. It fills the published kill-switch banner's
/// <code>&lt;reason&gt;</code> for that user, so it is operator text carried verbatim.</p>
Property Reason As %String(MAXLEN = 512);

/// <p>ISO-8601 UTC timestamp of creation (Consistency Conventions: Dates).</p>
Property CreatedAt As %String(MAXLEN = 32);

Index UserNameIdx On UserName [ Unique ];

/// <p>Whether <var>pUserName</var> is held, and the reason recorded with the hold.</p>
/// <p><var>pHeld</var> is 0 and <var>pReason</var> <code>""</code> when no row names the user --
/// the ordinary answer, never an error.</p>
/// <p><b>Matched the way the unique index matches</b>, which is case-insensitively: IRIS SQL string
/// comparison folds case by default and <code>UserNameIdx</code> collates the same way, so a name
/// differing only in case is the row the index would have refused as a duplicate.</p>
ClassMethod GuardedForUser(pUserName As %String, Output pHeld As %Boolean, Output pReason As %String) As %Status
{
    Set pHeld = 0
    Set pReason = ""
    Set tSC = $$$OK
    Try {
        If pUserName = "" Quit
        Set tSC = ..GuardedOpenOneWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Hold WHERE UserName = ? ORDER BY ID", pUserName, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set pHeld = 1
        Set pReason = ..Text(tRow.Reason)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every hold's id, in creation order. <var>pIds</var> comes back as <code>pIds(1)</code>,
/// <code>pIds(2)</code>, ... and is simply absent when the instance holds none -- the empty state,
/// never an error.</p>
ClassMethod GuardedList(Output pIds) As %Status
{
    Quit ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.Hold ORDER BY ID", .pIds)
}

/// <p>The id of the hold naming <var>pUserName</var>, or <code>""</code> when none does. Matched
/// the way <method>GuardedForUser</method> matches, so a caller can answer "this user is already
/// held" with a field rather than leaving the unique index to fail the save with
/// <code>#5808</code>.</p>
ClassMethod GuardedIdForUser(pUserName As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Hold WHERE UserName = ? ORDER BY ID", pUserName, .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

/// <p>Hold <var>pUserName</var>, with <var>pReason</var>, stamping the creation timestamp.
/// <var>pId</var> comes back as the new row's id.</p>
/// <p><b>Caller contract:</b> the duplicate check is the caller's, so a repeat can be refused on
/// the field the caller sent rather than as <code>#5808</code> from the index; the index still
/// refuses one this method was called with anyway.</p>
ClassMethod GuardedCreate(pUserName As %String, pReason As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Try {
        Set tRow = ..%New()
        Set tRow.UserName = pUserName
        Set tRow.Reason = pReason
        Set tRow.CreatedAt = ..Timestamp()
        Set tSC = ..GuardedSave(tRow)
        If $$$ISERR(tSC) Quit
        Set pId = tRow.%Id()
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the hold <var>pId</var>, so the agent is switched back on for that user. An id no row
/// holds removes nothing and is not an error; the caller's own existence check is what turns it
/// into a 404.</p>
ClassMethod GuardedDeleteId(pId As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Hold WHERE ID = ?", pId)
}

/// <p>The three keys a hold row carries -- id, the user's name and the reason -- and <b>no
/// more</b>. Whether the user still resolves on this instance is not here: that is an answer about
/// the instance rather than about the stored row, and it is resolved by
/// <class>OcuPilot.Api.Switches</class>, where a namespace switch is allowed (AD-9, AD-16,
/// AD-37).</p>
ClassMethod ScreenRow(pObject As OcuPilot.Kernel.State.Hold) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("id", pObject.%Id(), "string")
    Do tOut.%Set("userName", ..Text(pObject.UserName), "string")
    Do tOut.%Set("reason", ..Text(pObject.Reason), "string")
    Quit tOut
}

/// <p>Every hold as a <method>ScreenRow</method>, in the order <method>GuardedList</method>
/// answers.</p>
/// <p><b>A row that cannot be opened is skipped rather than failing the read</b>: the id came from
/// this instance's own enumeration a moment ago, so a row that has gone was deleted between the two
/// calls and is not on the list any more.</p>
ClassMethod GuardedScreenRows(Output pRows As %DynamicArray) As %Status
{
    Set pRows = ""
    Set tSC = ..GuardedList(.tIds)
    If $$$ISERR(tSC) Quit tSC
    Set pRows = []
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
        Do pRows.%Push(..ScreenRow(tRow))
        Set tRow = ""
    }
    Quit $$$OK
}

/// <p>Remove every hold, so a test that wrote one leaves none behind.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Hold")
}

/// <p>ISO-8601 UTC, e.g. <code>2026-09-15T10:30:45Z</code> -- <code>$ZTimeStamp</code>, never
/// <code>$Horolog</code>, and never raw <code>$ZDateTime</code>, which is space-separated.</p>
ClassMethod Timestamp() As %String
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> of a
/// <code>%String</code> column reads back as normalized to <code>""</code>
/// (<file>.claude/rules/objectscript-basics.md</file>).</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
