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
/// <p><b>Two shapes of row, told apart by <property>Kind</property>.</b> A membership kind --
/// <parameter>KINDFAVORITE</parameter>, <parameter>KINDRECENT</parameter> -- is a row that exists
/// or does not, and ignores <property>Value</property>. A value kind --
/// <parameter>KINDSCREENVIEW</parameter>, <parameter>KINDREFRESH</parameter>,
/// <parameter>KINDSHELL</parameter> -- keeps exactly one row per key and carries what the user
/// chose in <property>Value</property> (Story 15.5).</p>
/// <p><b>The three value kinds are never trimmed.</b> Each holds one row per key rather than a
/// bounded list, so <method>GuardedTrim</method>'s ordering warning does not reach them and
/// nothing calls it for them.</p>
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

/// <p>What the user chose, for a value kind; <code>""</code> for a membership kind, which
/// ignores it. Read through <method>Text</method> like every other column.</p>
/// <p><b>This did not move <parameter>OcuPilot.Kernel.State.Base.SCHEMAVERSION</parameter></b>
/// (Consistency Conventions: when <code>SCHEMAVERSION</code> moves). Every row written before it
/// existed holds no value at all, which reads back as the safe default <code>""</code>, and the
/// two membership kinds never consult it -- so no older OcuPilot reads a newer row wrongly and no
/// newer one needs a migration step, exactly as <property>RowVersion</property> reaching all eight
/// subclasses moved nothing.</p>
/// <p>Outside <index>PrefUserKindNameIdx</index> deliberately: the key is what the row is about,
/// and the value is what it says.</p>
Property Value As %String(MAXLEN = 256);

/// <p>When this row was last written, ISO-8601 UTC to the microsecond
/// (<method>Stamp</method>). It is what orders the recents list, and it is the one column a
/// repeat visit moves.</p>
Property UpdatedAt As %String(MAXLEN = 32);

Index PrefUserKindNameIdx On (UserName, Kind, Name) [ Unique ];

/// <p>The <property>Kind</property> value for a screen the user pinned.</p>
Parameter KINDFAVORITE As %String = "favorite";

/// <p>The <property>Kind</property> value for a screen the user visited.</p>
Parameter KINDRECENT As %String = "recent";

/// <p>The <property>Kind</property> value for one screen's remembered table view -- its sort,
/// direction, filter and max rows, as the client serializes them into
/// <property>Value</property> (Story 15.5). Keyed by route, so
/// <method>OcuPilot.Api.Preferences.IsBuiltRoute</method> gates it exactly as it gates a
/// favorite.</p>
Parameter KINDSCREENVIEW As %String = "view";

/// <p>The <property>Kind</property> value for one screen's remembered auto-refresh rate, in whole
/// seconds. Keyed by route. AD-43's roster is untouched by this: which screens may refresh is the
/// descriptor's, and this is only the rate one of them remembers.</p>
Parameter KINDREFRESH As %String = "refresh";

/// <p>The <property>Kind</property> value for a piece of shell chrome the user moved. Keyed by a
/// member name from the closed set <method>IsShellMember</method> answers, never by a route.</p>
Parameter KINDSHELL As %String = "shell";

/// <p>The <parameter>KINDSHELL</parameter> member holding the side bar's open state, as
/// <code>1</code> or <code>0</code>.</p>
Parameter SHELLSIDEBAROPEN As %String = "sideBarOpen";

/// <p>The <parameter>KINDSHELL</parameter> member holding the agent co-pilot panel's width in
/// px.</p>
Parameter SHELLPANELWIDTH As %String = "panelWidth";

/// <p>The longest <property>Value</property> this store holds, equal to that property's own
/// <code>MAXLEN</code>, which a property cannot read from a parameter.
/// <class>OcuPilot.Test.PrefState</class> asserts the two are the same number, the idiom
/// <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter> established. The handler
/// refuses a longer value rather than letting the save fail on datatype validation.</p>
Parameter VALUEMAXLENGTH As %Integer = 256;

/// <p>How many favorites one user may hold. A twenty-first is refused by the instance rather than
/// by the client alone.</p>
Parameter FAVORITEMAX As %Integer = 20;

/// <p>How many recents one user keeps. The oldest beyond this are deleted by
/// <method>GuardedTrim</method> after every visit.</p>
Parameter RECENTMAX As %Integer = 10;

/// <p>The whole SQL literal <method>GuardedAdd</method> counts a bounded list with, inside the
/// critical section <method>OcuPilot.Kernel.State.Base.GuardedSaveWithinCap</method> holds. Held
/// here as a parameter because a statement assembled at the call site is a statement a caller
/// value could reach (AD-21); the two key values bind.</p>
Parameter COUNTFORUSERSQL As %String = "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Pref WHERE UserName = ? AND Kind = ?";

/// <p><var>pUserName</var>'s rows of <var>pKind</var>, as a <class>%DynamicArray</class> of
/// <code>{route, value, updatedAt}</code> objects. <code>route</code> is the
/// <property>Name</property> column whatever the kind keys by; <code>value</code> is
/// <code>""</code> for a membership kind.</p>
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
            Do tEntry.%Set("value", ..Text(tRow.Value), "string")
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
/// <p><b>Neither race this loses is a failure</b> (DW-1327). The count is taken inside
/// <method>OcuPilot.Kernel.State.Base.GuardedSaveWithinCap</method>'s critical section rather than
/// here, so two adds of different routes cannot both read the bound as not-yet-reached; and an add
/// whose key another writer inserted between the look-up and the save answers the documented no-op
/// rather than propagating the unique-index violation as a 500.</p>
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
        Set tRow = ..%New()
        Set tRow.UserName = pUserName
        Set tRow.Kind = pKind
        Set tRow.Name = pName
        Set tRow.UpdatedAt = ..Stamp()
        Set tSC = ..GuardedSaveWithinCap(tRow, pUserName, pKind, ..#COUNTFORUSERSQL, pMax, .pAtLimit)
        Set tRow = ""
        If $$$ISERR(tSC) && ..IsDuplicateKey(tSC) {
            Set pAtLimit = 0
            Set tSC = $$$OK
        }
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
/// refusal is swallowed, on <class>OcuPilot.Kernel.State.Nav</class>'s precedent. The create
/// branch loses its own race the same way: a duplicate key means another tab created the row
/// first (DW-1327).</p>
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
            ; DW-1327. Another tab registered the same first visit between the look-up and the
            ; save, so the row the caller asked for exists and the violation is the no-op this
            ; method documents rather than a 500.
            If $$$ISERR(tSC) && ..IsDuplicateKey(tSC) Set tSC = $$$OK
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

/// <p>Store <var>pValue</var> at <code>(pUserName, pKind, pName)</code> for a value kind,
/// creating the row when the user has none (Story 15.5).</p>
/// <p><b>One guarded frame, and one refusal that is not swallowed.</b> An existing row is updated
/// through <method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method>, conditional on the
/// version just read, and a stale save is returned so the handler renders
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter> (Consistency Conventions: concurrent
/// writes). It is not <method>GuardedTouch</method>'s case: a lost visit leaves the caller's
/// outcome already true, while a lost value write leaves a value the caller did not ask for.</p>
/// <p><b>The create race answers by updating</b> (DW-1327): a key another writer inserted between
/// the look-up and the save is re-read and written, so the value the caller sent is the value
/// stored rather than a 500. A row removed again before that re-read is a fault, never a
/// success: answering OK for a set that stored nothing is worse than refusing it.</p>
ClassMethod GuardedSetValue(pUserName As %String, pKind As %String, pName As %String, pValue As %String) As %Status
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
            Set tRow.Value = pValue
            Set tRow.UpdatedAt = ..Stamp()
            Set tSC = ..GuardedSave(tRow)
            Set tRow = ""
            If $$$ISOK(tSC) Quit
            If '..IsDuplicateKey(tSC) Quit
            Set tSC = ..OpenByKey(pUserName, pKind, pName, .tRow)
            If $$$ISERR(tSC) Quit
            ; The racing row was removed again before this re-read. Returning $$$OK here would
            ; answer 200 for a set that stored nothing, which is the one outcome worse than a
            ; refusal: the caller believes the instance holds a value it does not.
            If '$IsObject(tRow) {
                Set tSC = $$$ERROR($$$GeneralError, "the row a concurrent write created was removed before it could be set")
                Quit
            }
        }
        Set tExpected = +tRow.RowVersion
        Set tRow.Value = pValue
        Set tRow.UpdatedAt = ..Stamp()
        Set tSC = ..GuardedSaveIfCurrent(tRow, tExpected)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pName</var> is one of the closed set of shell members
/// <parameter>KINDSHELL</parameter> keys by. Declared here beside the two member names rather than
/// in the handler, so the store and the route read one vocabulary.</p>
ClassMethod IsShellMember(pName As %String) As %Boolean
{
    If pName = ..#SHELLSIDEBAROPEN Quit 1
    If pName = ..#SHELLPANELWIDTH Quit 1
    Quit 0
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
