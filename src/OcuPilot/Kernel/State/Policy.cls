/// <p>The stored governance policy (AD-22, AD-9): one row per <property>Name</property>. The row
/// named <parameter>PRESETNAME</parameter> holds the preset -- <code>""</code>,
/// <parameter>PRESETREADONLY</parameter> or <parameter>PRESETFULL</parameter> -- and every other row
/// holds one key's setting, <parameter>VALUEENABLED</parameter> or
/// <parameter>VALUEDISABLED</parameter>. A key with no row inherits.</p>
/// <p><b>The preset row is the policy's version anchor.</b> <method>GuardedApply</method> saves it
/// conditionally on the version the caller read and writes the key rows in the same transaction,
/// so a stale write changes nothing (Consistency Conventions: concurrent writes). A clean instance
/// holds no row and reads version 0.</p>
/// <p><b>Nothing here is a gate and nothing caches.</b> <class>OcuPilot.Kernel.Governance.Policy</class>
/// resolves a key against this store on every call.</p>
/// <p>A new table, so <code>SCHEMAVERSION</code> does not move: no older row changes meaning.
/// Named scalars only, and no hand-written Storage.</p>
Class OcuPilot.Kernel.State.Policy Extends OcuPilot.Kernel.State.Base
{

/// <p>The name of the row holding the preset.</p>
Parameter PRESETNAME = "preset";

/// <p>The preset that disables every write key a stored setting does not enable.</p>
Parameter PRESETREADONLY = "read-only";

/// <p>The preset that enables every write key a stored setting does not disable.</p>
Parameter PRESETFULL = "full";

/// <p>A key row's value when the key is enabled.</p>
Parameter VALUEENABLED = "enabled";

/// <p>A key row's value when the key is disabled.</p>
Parameter VALUEDISABLED = "disabled";

/// <p>The inherit setting, which removes a key's row rather than storing a value.</p>
Parameter VALUEINHERIT = "inherit";

/// <p>The row's name: <parameter>PRESETNAME</parameter>, or a governance key.</p>
Property Name As %String(MAXLEN = 256);

/// <p>The preset on the preset row; <parameter>VALUEENABLED</parameter> or
/// <parameter>VALUEDISABLED</parameter> on a key row.</p>
Property Value As %String(MAXLEN = 32);

/// <p>ISO-8601 UTC timestamp of the last write to this row.</p>
Property UpdatedAt As %String(MAXLEN = 32);

Index PolicyNameIdx On Name [ Unique ];

/// <p>Every stored row as <var>pValues</var>, subscripted by name, and the preset row's version in
/// <var>pVersion</var> (<code>0</code> when the instance holds no preset row). A read that fails
/// answers its error; the caller treats it as a refusal.</p>
ClassMethod GuardedAll(Output pValues, Output pVersion As %Integer) As %Status
{
    Kill pValues
    Set pVersion = 0
    Set tSC = ..GuardedRowsNoParam("SELECT Name, Value, RowVersion FROM OcuPilot_Kernel_State.Policy", .tRows)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tRows) {
        Set tName = ..Text($Get(tRows(tI, 1)))
        If tName = "" Continue
        Set pValues(tName) = ..Text($Get(tRows(tI, 2)))
        If tName = ..#PRESETNAME Set pVersion = +$Get(tRows(tI, 3))
    }
    Quit $$$OK
}

/// <p>Store preset <var>pPreset</var> and every setting in <var>pSettings</var> (subscripted by
/// key, each <parameter>VALUEINHERIT</parameter>, <parameter>VALUEENABLED</parameter> or
/// <parameter>VALUEDISABLED</parameter>), in one transaction, while the preset row still carries
/// <var>pExpectedVersion</var>. A key <var>pSettings</var> does not name is left as it is.</p>
/// <p>A stale version is <parameter>OcuPilot.Kernel.State.Base.STALESAVEREASON</parameter>'s
/// refusal (<method>IsStaleSave</method>) and writes nothing; so is a first save that loses the
/// race to create the preset row. <b>Caller contract:</b> the values are validated before this is
/// called.</p>
ClassMethod GuardedApply(pPreset As %String, ByRef pSettings, pExpectedVersion As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    Try {
        Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Policy WHERE %EXACT(Name) = ?", ..#PRESETNAME, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            If +pExpectedVersion '= 0 {
                Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
                Quit
            }
            Set tRow = ..%New()
            Set tRow.Name = ..#PRESETNAME
        }
        Set tNow = ..Timestamp()
        Set tRow.Value = pPreset
        Set tRow.UpdatedAt = tNow
        TSTART
        Set tInTx = 1
        Set tSC = ..GuardedSaveIfCurrent(tRow, +pExpectedVersion)
        Set tRow = ""
        If $$$ISERR(tSC) {
            If ..IsDuplicateKey(tSC) Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
            Quit
        }
        Set tKey = ""
        For {
            Set tKey = $Order(pSettings(tKey), 1, tSetting)
            If tKey = "" Quit
            If tSetting = ..#VALUEINHERIT {
                Set tSC = ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Policy WHERE %EXACT(Name) = ?", tKey)
                If $$$ISERR(tSC) Quit
                Continue
            }
            Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Policy WHERE %EXACT(Name) = ?", tKey, .tKeyRow)
            If $$$ISERR(tSC) Quit
            If '$IsObject(tKeyRow) {
                Set tKeyRow = ..%New()
                Set tKeyRow.Name = tKey
            }
            Set tKeyRow.Value = tSetting
            Set tKeyRow.UpdatedAt = tNow
            Set tSC = ..GuardedSave(tKeyRow)
            Set tKeyRow = ""
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
    }
    Quit tSC
}

/// <p>Remove every row, so the baseline alone decides again. Absent is never an error.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Policy")
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
