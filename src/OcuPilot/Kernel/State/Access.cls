/// <p>The adjusted permission sets of screens (AD-64, AD-9): one row per adjusted screen, keyed by the
/// screen's <code>toolIdentifier</code>, holding the pairs that replace the screen's declared
/// <code>privileges</code>. A screen with no row requires its declared set. The store is instance-wide
/// and is not <class>OcuPilot.Kernel.State.Pref</class>'s per-user store.</p>
/// <p><b>Nothing here is a gate.</b> <method>OcuPilot.Screen.Gate.RequiredPairs</method> is the one
/// reader that turns a row into a requirement, and <class>OcuPilot.Port.ScreenAccessPort</class> the one
/// product writer. This class stores and answers, and names no <code>Screen</code>, <code>Port</code> or
/// <code>Api</code> class (AD-9).</p>
/// <p><b>Who may write.</b> <method>GuardedPut</method> and <method>GuardedRemove</method> admit a caller who holds
/// <code>OcuPilotAdmin:USE</code> or one of <parameter>WRITERPAIRS</parameter>, the pairs the port's gate admits (AD-64),
/// and <method>GuardedPut</method> refuses a set the port would refuse. Every other writer, and
/// <code>Base</code>'s public saves, admit an administrator only (<parameter>ADMINWRITE</parameter>). Each accepted
/// <method>GuardedPut</method> and <method>GuardedRemove</method> records its own <code>SecurityChange</code> audit row,
/// so a write through the port is audited once.</p>
/// <p><b>The hot path is <method>GuardedPairsFor</method></b>: one escalated frame, two global reads on
/// the unique index and the stored property, no SQL. A screen's pairs are spelled <code>resource:permission</code>, comma-separated.</p>
/// <p>A new table, so <code>SCHEMAVERSION</code> does not move: no older row changes meaning. Named
/// scalars only, and no hand-written Storage.</p>
Class OcuPilot.Kernel.State.Access Extends OcuPilot.Kernel.State.Base [ SqlTableName = ScreenAccess ]
{

/// <p>An administrator-owned store (<parameter>OcuPilot.Kernel.State.Base.ADMINWRITE</parameter>): <code>Base</code>'s
/// public saves and <method>DeleteAllGuarded</method> refuse a caller who does not hold the administrative resource.
/// <method>GuardedPut</method> and <method>GuardedRemove</method> admit the adjusters of
/// <parameter>WRITERPAIRS</parameter> as well.</p>
Parameter ADMINWRITE As %Boolean = 1;

/// <p>The pairs, either one of which admits a caller to <method>GuardedPut</method> and
/// <method>GuardedRemove</method> beside the administrative resource: <code>%Development:USE</code> or
/// <code>%Admin_Secure:USE</code>, the port's gate (<method>OcuPilot.Screen.Gate.AdjusterPairs</method>, AD-64).
/// <code>Kernel/State</code> may not name <code>OcuPilot.Screen</code>, so the text is repeated here and a test holds
/// the two equal.</p>
Parameter WRITERPAIRS As %String = "%Development:USE,%Admin_Secure:USE";

/// <p>The most pairs a set holds: <code>OcuPilot.Api.AccessError.MAXPAIRS</code>, repeated for the reason
/// <parameter>WRITERPAIRS</parameter> is.</p>
Parameter MAXPAIRS As %Integer = 8;

/// <p>The permissions a pair may carry, comma-separated: the port's.</p>
Parameter PERMISSIONS As %String = "READ,WRITE,USE";

/// <p>The shape of a resource name in a pair: the port's.</p>
Parameter RESOURCEPATTERN As %String = "^%?[A-Za-z][A-Za-z0-9_.-]{0,127}$";

/// <p>The audit row's entity type and verbs: the port's former ones, now recorded by this store.</p>
Parameter ENTITYTYPE As %String = "screen-permission";

Parameter VERBUPDATED As %String = "updated";

Parameter VERBRESET As %String = "reset";

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
/// refusal (<method>IsStaleSave</method>).</p>
/// <p>Refused <code>$$$AccessDenied</code> (vendor <code>ERROR #822</code>) before anything is read or written when
/// the caller holds neither the administrative resource nor a pair of <parameter>WRITERPAIRS</parameter>
/// (<method>WriterRefused</method>), when <var>pPairs</var> is empty, holds more than <parameter>MAXPAIRS</parameter>
/// pairs or a pair that is not <code>resource:READ|WRITE|USE</code> (<method>SetRefused</method>), when
/// <var>pBy</var> is not the calling account, and when the row an update opens is not the row stored for
/// <var>pScreen</var> (a held copy whose screen was changed in memory).</p>
/// <p>An accepted write records one <code>SecurityChange</code> audit row naming the calling account, the pairs before
/// and the pairs after. The pairs before are the stored set, or <var>pDeclared</var> -- the set the screen requires
/// when it has no adjustment, which only the caller knows -- for a create.</p>
ClassMethod GuardedPut(pScreen As %String, pPairs As %String, pExpectedVersion As %Integer, pBy As %String, pDeclared As %String = "") As %Status
{
    Set tSC = ..WriterRefused()
    If $$$ISOK(tSC) Set tSC = ..SetRefused(pPairs)
    If $$$ISOK(tSC) && '..CallerOwns(pBy) Set tSC = $$$ERROR($$$AccessDenied)
    If $$$ISERR(tSC) Quit tSC
    Set tOld = pDeclared
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
            If tRow.Screen '= pScreen {
                Set tSC = $$$ERROR($$$AccessDenied)
                Quit
            }
            Set tSC = ..GuardedPairsFor(pScreen, .tOld, .tFound)
            If $$$ISERR(tSC) Quit
        }
        Set tRow.Pairs = pPairs
        Set tRow.ChangedBy = pBy
        Set tRow.ChangedAt = ..Timestamp()
        Set tSC = ..GuardedSaveIfCurrentAnyCaller(tRow, +pExpectedVersion)
        Set tRow = ""
        If $$$ISERR(tSC) && ..IsDuplicateKey(tSC) Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Do ..Audit(..#VERBUPDATED, pScreen, tOld, pPairs)
    Quit tSC
}

/// <p>Remove <var>pScreen</var>'s row while it still carries <var>pExpectedVersion</var>. A row that
/// is gone or has moved is <parameter>OcuPilot.Kernel.State.Base.STALESAVEREASON</parameter>'s
/// refusal. Refused <code>$$$AccessDenied</code> to a caller <method>GuardedPut</method> refuses
/// (<method>WriterRefused</method>). An accepted removal records one <code>SecurityChange</code> audit row naming the
/// stored set and <var>pDeclared</var>, the set the screen requires again.</p>
ClassMethod GuardedRemove(pScreen As %String, pExpectedVersion As %Integer, pDeclared As %String = "") As %Status
{
    Set tSC = ..WriterRefused()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GuardedPairsFor(pScreen, .tOld, .tFound)
    If $$$ISERR(tSC) Quit tSC
    ; One statement checks the version and deletes, so a save that lands between them cannot be removed.
    Set tParams = [(pScreen), (+pExpectedVersion)]
    Set tSC = ..GuardedExecuteRows("DELETE FROM OcuPilot_Kernel_State.ScreenAccess WHERE %EXACT(Screen) = ? AND COALESCE(RowVersion, 0) = ?", .tParams, .tCount)
    If $$$ISERR(tSC) Quit tSC
    If tCount = 0 Quit $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
    Do ..Audit(..#VERBRESET, pScreen, tOld, pDeclared)
    Quit $$$OK
}

/// <p>Remove every row, so each screen requires its declared set again. Absent is never an error. Administrators
/// only.</p>
ClassMethod DeleteAllGuarded() As %Status
{
    Set tSC = ..AdminWriteRefused($ClassName())
    If $$$ISERR(tSC) Quit tSC
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.ScreenAccess")
}

/// <p>The refusal for a caller who may not change a screen's adjustment: <code>$$$OK</code> for an administrator
/// (<code>OcuPilotAdmin:USE</code>) and for a caller holding one of <parameter>WRITERPAIRS</parameter>,
/// <code>$$$AccessDenied</code> (vendor <code>ERROR #822</code>) otherwise. Evaluated in the caller's process, before
/// any escalation (AD-8).</p>
ClassMethod WriterRefused() As %Status [ Private ]
{
    If ..CallerIsAdministrator() Quit $$$OK
    Set tHeld = 0
    For tI = 1:1:$Length(..#WRITERPAIRS, ",") {
        Set tPair = $Piece(..#WRITERPAIRS, ",", tI)
        If $System.Security.Check($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)) {
            Set tHeld = 1
            Quit
        }
    }
    If tHeld Quit $$$OK
    Quit $$$ERROR($$$AccessDenied)
}

/// <p>The refusal for a set the port would refuse by its shape: <code>$$$AccessDenied</code> when
/// <var>pPairs</var> is empty, holds more than <parameter>MAXPAIRS</parameter> pairs, or holds a member that is not
/// a resource of <parameter>RESOURCEPATTERN</parameter>, a colon and one of <parameter>PERMISSIONS</parameter>.
/// It does not ask whether a resource is defined: the port does, and an undefined resource lowers no
/// requirement.</p>
ClassMethod SetRefused(pPairs As %String) As %Status [ Private ]
{
    Set tCount = $Length(pPairs, ",")
    If (pPairs = "") || (tCount > ..#MAXPAIRS) Quit $$$ERROR($$$AccessDenied)
    Set tBad = 0
    For tI = 1:1:tCount {
        Set tPair = $Piece(pPairs, ",", tI)
        If ($Length(tPair, ":") '= 2) || '$Match($Piece(tPair, ":", 1), ..#RESOURCEPATTERN) || '$ListFind($ListFromString(..#PERMISSIONS), $Piece(tPair, ":", 2)) {
            Set tBad = 1
            Quit
        }
    }
    If tBad Quit $$$ERROR($$$AccessDenied)
    Quit $$$OK
}

/// <p>Record <code>SecurityChange</code> for one accepted write: the pairs before and after, as comma-separated
/// texts. It never fails the write (AD-15).</p>
ClassMethod Audit(pVerb As %String, pScreen As %String, pOld As %String, pNew As %String) [ Private ]
{
    Try {
        Set tPairs = {}
        Do tPairs.%Set("old", pOld, "string")
        Do tPairs.%Set("new", pNew, "string")
        Set tChanges = {}
        Do tChanges.%Set("pairs", tPairs)
        Do ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, ..#ENTITYTYPE, pScreen, tChanges, 1)
    } Catch ex {
        Quit
    }
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
