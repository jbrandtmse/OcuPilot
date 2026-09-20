/// <p>Everything OcuPilot remembers about one user (AD-50, Story 15.2): one row per
/// <code>(UserName, Kind, Name)</code>, with <property>Kind</property> naming what the row is.
/// Held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9).</p>
/// <p><b>A new preference adds a <property>Kind</property> value, never a new
/// <class>OcuPilot.Kernel.State.Base</class> subclass.</b> The 29-character cap on a
/// <code>%Persistent</code> class name leaves seven characters after
/// <code>OcuPilot.Kernel.State.</code>, which <code>Favorite</code> and <code>Bookmark</code>
/// already exceed; and the drain of writing, guarding, versioning and testing a store is paid
/// once rather than once per polish item.</p>
/// <p><b>Both halves of the key are weak references</b> (AD-37):
/// <property>UserName</property> and <property>Name</property> are scoped identities recorded as
/// data, never foreign keys. A user the instance no longer holds, and a route no screen declares
/// any more, both read back verbatim; dropping an unresolvable one from a rendered list is the
/// caller's job, never this store's.</p>
/// <p><b>This store holds set membership, not values.</b> There is no value column: a row exists
/// or it does not. A later <property>Kind</property> that needs one adds it.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule, and no
/// hand-written Storage.</p>
Class OcuPilot.Kernel.State.Pref Extends OcuPilot.Kernel.State.Base
{

/// <p>The user this row belongs to. The length is <class>Security.Users</class>'s own
/// <code>Name</code> length on this build, so a name the instance accepts is a name this column
/// holds.</p>
Property UserName As %String(MAXLEN = 160);

/// <p>What this row is: <parameter>KINDFAVORITE</parameter> or <parameter>KINDRECENT</parameter>
/// today. The handler validates the value; this column stores it.</p>
Property Kind As %String(MAXLEN = 16);

/// <p>The thing remembered -- a screen route for both kinds this story ships. Declared equal to
/// <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter>, which a property's
/// <code>MAXLEN</code> cannot itself read; <class>OcuPilot.Test.PrefState</class> asserts the
/// two are the same number.</p>
Property Name As %String(MAXLEN = 512);

/// <p>When this row was last written, ISO-8601 UTC to the microsecond
/// (<method>Stamp</method>). It is what orders the recents list, and it is the one column a
/// repeat visit moves.</p>
Property UpdatedAt As %String(MAXLEN = 32);

Index PrefUserKindNameIdx On (UserName, Kind, Name) [ Unique ];

/// <p>The <property>Kind</property> value for a screen the user pinned.</p>
Parameter KINDFAVORITE As %String = "favorite";

/// <p>The <property>Kind</property> value for a screen the user visited.</p>
Parameter KINDRECENT As %String = "recent";

/// <p>How many favorites one user may hold. A twenty-first is refused by the instance rather than
/// by the client alone.</p>
Parameter FAVORITEMAX As %Integer = 20;

/// <p>How many recents one user keeps. The oldest beyond this are deleted by
/// <method>GuardedTrim</method> after every visit.</p>
Parameter RECENTMAX As %Integer = 10;

/// <p><var>pUserName</var>'s rows of <var>pKind</var>, as a <class>%DynamicArray</class> of
/// <code>{route, updatedAt}</code> objects.</p>
/// <p><b>Ordered by kind, because the two lists mean different things.</b> Favorites read
/// oldest-first, which is the order they were pinned in and is stable as long as they are held;
/// recents read newest-first, which is what "recent" means. Both orders are declared in their own
/// whole SQL literal, never assembled, so no caller value reaches the statement text (AD-21).</p>
/// <p>No rows is the ordinary answer, never an error. A row whose id disappears between the
/// enumeration and the open -- another tab clearing the list -- is skipped rather than failing the
/// read.</p>
ClassMethod GuardedListForUser(pUserName As %String, pKind As %String, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = $$$OK
    Try {
        If pUserName = "" Quit
        Set tSC = ..IdsForUser(pUserName, pKind, .tIds)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:+$Get(tIds) {
            Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
            If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
            Set tEntry = {}
            Do tEntry.%Set("route", ..Text(tRow.Name), "string")
            Do tEntry.%Set("updatedAt", ..Text(tRow.UpdatedAt), "string")
            Do pRows.%Push(tEntry)
            Set tRow = ""
        }
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add <var>pName</var> to <var>pUserName</var>'s <var>pKind</var> set, bounded by
/// <var>pMax</var> rows.</p>
/// <p><var>pAtLimit</var> is 1, and nothing is written, when the set already holds
/// <var>pMax</var> rows and <var>pName</var> is not one of them -- the refusal the handler turns
/// into 422. A second add of a row already held is a no-op that answers <var>pAtLimit</var> 0:
/// the outcome the caller asked for is already true.</p>
ClassMethod GuardedAdd(pUserName As %String, pKind As %String, pName As %String, pMax As %Integer, Output pAtLimit As %Boolean) As %Status
{
    Set pAtLimit = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..OpenByKey(pUserName, pKind, pName, .tRow)
        If $$$ISERR(tSC) Quit
        If $IsObject(tRow) {
            Set tRow = ""
            Quit
        }
        Set tSC = ..IdsForUser(pUserName, pKind, .tIds)
        If $$$ISERR(tSC) Quit
        If +$Get(tIds) >= +pMax {
            Set pAtLimit = 1
            Quit
        }
        Set tRow = ..%New()
        Set tRow.UserName = pUserName
        Set tRow.Kind = pKind
        Set tRow.Name = pName
        Set tRow.UpdatedAt = ..Stamp()
        Set tSC = ..GuardedSave(tRow)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove one row. Removing a row the user does not hold is a no-op answering
/// <code>$$$OK</code>, because the outcome the caller asked for is already true.</p>
ClassMethod GuardedRemove(pUserName As %String, pKind As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..OpenByKey(pUserName, pKind, pName, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set tId = tRow.%Id()
        Set tRow = ""
        Set tSC = ..DeleteById(tId)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every row of <var>pKind</var> the user holds. An empty set is an ordinary answer.</p>
ClassMethod GuardedClear(pUserName As %String, pKind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..IdsForUser(pUserName, pKind, .tIds)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:+$Get(tIds) {
            Set tSC = ..DeleteById(tIds(tI))
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record a visit: refresh <var>pName</var>'s <property>UpdatedAt</property>, creating the row
/// when the user has none.</p>
/// <p><b>A lost race is not a failure.</b> The refresh is conditional on the version just read
/// (<method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method>), and a stale save means
/// another tab registered the same visit -- so the caller's outcome is already true and the
/// refusal is swallowed, on <class>OcuPilot.Kernel.State.Nav</class>'s precedent. It is the one
/// read-modify-write in this store; add and remove are a create and a delete by key and have no
/// conflict window at all.</p>
ClassMethod GuardedTouch(pUserName As %String, pKind As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..OpenByKey(pUserName, pKind, pName, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set tRow = ..%New()
            Set tRow.UserName = pUserName
            Set tRow.Kind = pKind
            Set tRow.Name = pName
            Set tRow.UpdatedAt = ..Stamp()
            Set tSC = ..GuardedSave(tRow)
            Set tRow = ""
            Quit
        }
        Set tExpected = +tRow.RowVersion
        Set tRow.UpdatedAt = ..Stamp()
        Set tSC = ..GuardedSaveIfCurrent(tRow, tExpected)
        Set tRow = ""
        If $$$ISERR(tSC) && ..IsStaleSave(tSC) Set tSC = $$$OK
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Keep the first <var>pKeep</var> rows <method>IdsForUser</method> answers for
/// <var>pKind</var> and delete the rest. A set already at or under the bound is left alone.</p>
/// <p><b>"First" is that kind's own order, so this keeps the newest only for
/// <parameter>KINDRECENT</parameter>.</b> Every other kind falls to
/// <method>IdsForUser</method>'s default branch, which reads oldest-first, and trimming one there
/// would delete its newest rows. A later kind that needs trimming adds its own ordering branch
/// first.</p>
ClassMethod GuardedTrim(pUserName As %String, pKind As %String, pKeep As %Integer) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..IdsForUser(pUserName, pKind, .tIds)
        If $$$ISERR(tSC) Quit
        ; IdsForUser answers the recent kind newest-first, so everything past pKeep is older
        ; than everything kept.
        Set tFirst = +pKeep + 1
        For tI = tFirst:1:+$Get(tIds) {
            Set tSC = ..DeleteById(tIds(tI))
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many rows of <var>pKind</var> <var>pUserName</var> holds. For tests and for a caller
/// that wants the count without the rows.</p>
ClassMethod GuardedCountForUser(pUserName As %String, pKind As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    Set tSC = ..IdsForUser(pUserName, pKind, .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +$Get(tIds)
    Quit $$$OK
}

/// <p>Remove every user's preferences. For test set-up and tear-down only.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Pref")
}

/// <p>The ids of <var>pUserName</var>'s <var>pKind</var> rows, in that kind's own order. Each
/// branch's statement is one whole literal; the two values bind.</p>
ClassMethod IdsForUser(pUserName As %String, pKind As %String, Output pIds) As %Status [ Private ]
{
    If pKind = ..#KINDRECENT {
        Quit ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Pref WHERE UserName = ? AND Kind = ? ORDER BY UpdatedAt DESC, ID DESC", pUserName, pKind, .pIds)
    }
    Quit ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Pref WHERE UserName = ? AND Kind = ? ORDER BY ID", pUserName, pKind, .pIds)
}

/// <p>The one row at <code>(pUserName, pKind, pName)</code>, or <code>$$$NULLOREF</code>. The
/// three values bind; none reaches the statement text.</p>
ClassMethod OpenByKey(pUserName As %String, pKind As %String, pName As %String, Output pRow) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhereThreeParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Pref WHERE UserName = ? AND Kind = ? AND Name = ? ORDER BY ID", pUserName, pKind, pName, .pRow)
}

/// <p>Delete one row by its own id. The id is this store's, never a caller's, and it binds.</p>
ClassMethod DeleteById(pId As %String) As %Status [ Private ]
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Pref WHERE ID = ?", pId)
}

/// <p>Now, as ISO-8601 UTC with six fractional digits --
/// <method>OcuPilot.Kernel.State.Turn.Timestamp</method>'s shape at microsecond resolution, 27
/// characters against <property>UpdatedAt</property>'s 32.</p>
/// <p><b>Not that method, because whole seconds cannot order two visits inside one second.</b>
/// <method>IdsForUser</method> reads the recent kind <code>ORDER BY UpdatedAt DESC</code>, so
/// tied stamps fall back to row-creation order and a just-visited screen does not move to the
/// front. Milliseconds are not enough either: three consecutive writes measured on this build
/// share one millisecond, and <code>$ZTimeStamp</code> resolves below a microsecond, so six
/// digits is the first precision that separates them. The longer string still sorts correctly as
/// a string. The convention for a timestamp on the wire is not in play:
/// <method>OcuPilot.Api.Preferences.Routes</method> drops this column, so the value never leaves
/// the instance.</p>
ClassMethod Stamp() As %String [ Private ]
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1, 6), " ", "T") _ "Z"
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
