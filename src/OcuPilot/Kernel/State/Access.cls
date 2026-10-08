/// <p>The adjusted permission sets of screens (AD-64, AD-9): one row per adjusted screen, keyed by the
/// screen's <code>toolIdentifier</code>, holding the pairs that replace the screen's declared
/// <code>privileges</code>. A screen with no row requires its declared set. The store is instance-wide
/// and is not <class>OcuPilot.Kernel.State.Pref</class>'s per-user store.</p>
/// <p><b>Nothing here is a gate.</b> <method>OcuPilot.Screen.Gate.RequiredPairs</method> is the one
/// reader that turns a row into a requirement, and <class>OcuPilot.Port.ScreenAccessPort</class> the one
/// writer. This class stores and answers, and names no <code>Screen</code>, <code>Port</code> or
/// <code>Api</code> class (AD-9).</p>
/// <p><b>The hot path is <method>GuardedPairsFor</method></b>: one escalated frame, two global reads on
/// the unique index and the stored property, no SQL. A screen's pairs are spelled <code>resource:permission</code>, comma-separated.</p>
/// <p>A new table, so <code>SCHEMAVERSION</code> does not move: no older row changes meaning. Named
/// scalars only, and no hand-written Storage.</p>
Class OcuPilot.Kernel.State.Access Extends OcuPilot.Kernel.State.Base [ SqlTableName = ScreenAccess ]
{

/// <p>The screen's <code>toolIdentifier</code>, compared exactly.</p>
Property Screen As %String(COLLATION = "EXACT", MAXLEN = 128);

/// <p>The pairs that replace the screen's declared set, <code>resource:permission</code>,
/// comma-separated.</p>
Property Pairs As %String(MAXLEN = 2048);

/// <p>The account that last changed the row.</p>
Property ChangedBy As %String(MAXLEN = 128);

/// <p>ISO-8601 UTC timestamp of the last change.</p>
Property ChangedAt As %String(MAXLEN = 32);

Index ScreenIdx On Screen [ Unique ];

/// <p>Whether <var>pScreen</var> holds a row and, when it does, its pairs (<var>pPairs</var>). A read
/// that fails answers its error, which the caller treats as a refusal.</p>
ClassMethod GuardedPairsFor(pScreen As %String, Output pPairs As %String, Output pFound As %Boolean) As %Status
{
    Set tSC = ..GuardedStoredValue("ScreenIdxExists", pScreen, "Pairs", .pPairs, .pFound)
    If $$$ISOK(tSC) Set pPairs = ..Text(pPairs)
    Quit tSC
}

/// <p>Every row as <var>pMap</var>, subscripted by screen, each the stored pair text.</p>
ClassMethod GuardedAll(Output pMap) As %Status
{
    Kill pMap
    Set tSC = ..GuardedRowsNoParam("SELECT Screen, Pairs FROM OcuPilot_Kernel_State.ScreenAccess", .tRows)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tRows) {
        Set tScreen = ..Text($Get(tRows(tI, 1)))
        If tScreen '= "" Set pMap(tScreen) = ..Text($Get(tRows(tI, 2)))
    }
    Quit $$$OK
}

/// <p>The row <var>pScreen</var> holds: <var>pFound</var>, its <var>pPairs</var> and its
/// <var>pVersion</var> (0 when there is none).</p>
ClassMethod GuardedGet(pScreen As %String, Output pPairs As %String, Output pVersion As %Integer, Output pFound As %Boolean) As %Status
{
    Set pPairs = ""
    Set pVersion = 0
    Set pFound = 0
    Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.ScreenAccess WHERE %EXACT(Screen) = ?", pScreen, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set pFound = 1
    Set pPairs = ..Text(tRow.Pairs)
    Set pVersion = +tRow.RowVersion
    Quit $$$OK
}

/// <p>Store <var>pPairs</var> for <var>pScreen</var> while its row still carries
/// <var>pExpectedVersion</var>: <code>0</code> creates the row, any other value updates it. A stale
/// version, and a create that loses a race, are <parameter>OcuPilot.Kernel.State.Base.STALESAVEREASON</parameter>'s
/// refusal (<method>IsStaleSave</method>). <b>Caller contract:</b> the pairs are validated before this
/// is called.</p>
ClassMethod GuardedPut(pScreen As %String, pPairs As %String, pExpectedVersion As %Integer, pBy As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If +pExpectedVersion = 0 {
            Set tRow = ..%New()
            Set tRow.Screen = pScreen
        } Else {
            Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.ScreenAccess WHERE %EXACT(Screen) = ?", pScreen, .tRow)
            If $$$ISERR(tSC) Quit
            If '$IsObject(tRow) {
                Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
                Quit
            }
        }
        Set tRow.Pairs = pPairs
        Set tRow.ChangedBy = pBy
        Set tRow.ChangedAt = ..Timestamp()
        Set tSC = ..GuardedSaveIfCurrent(tRow, +pExpectedVersion)
        Set tRow = ""
        If $$$ISERR(tSC) && ..IsDuplicateKey(tSC) Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <var>pScreen</var>'s row while it still carries <var>pExpectedVersion</var>. A row that
/// is gone or has moved is <parameter>OcuPilot.Kernel.State.Base.STALESAVEREASON</parameter>'s
/// refusal.</p>
ClassMethod GuardedRemove(pScreen As %String, pExpectedVersion As %Integer) As %Status
{
    ; One statement checks the version and deletes, so a save that lands between them cannot be removed.
    Set tParams = [(pScreen), (+pExpectedVersion)]
    Set tSC = ..GuardedExecuteRows("DELETE FROM OcuPilot_Kernel_State.ScreenAccess WHERE %EXACT(Screen) = ? AND COALESCE(RowVersion, 0) = ?", .tParams, .tCount)
    If $$$ISERR(tSC) Quit tSC
    If tCount = 0 Quit $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
    Quit $$$OK
}

/// <p>Remove every row, so each screen requires its declared set again. Absent is never an error.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.ScreenAccess")
}

/// <p>ISO-8601 UTC, e.g. <code>2026-09-27T10:30:45Z</code>.</p>
ClassMethod Timestamp() As %String
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> sentinel normalized to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
