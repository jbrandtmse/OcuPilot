/// <p>The stream sink a turn passes with each model call (AD-33): it writes the call's text so far
/// onto the running model step's own <code>text</code>, through
/// <method>OcuPilot.Kernel.State.Step.GuardedSnapshotText</method>. No row is added and no key joins
/// the progress payload.</p>
/// <p><b>Cadence.</b> The first text is written as soon as it arrives; after that at most one write
/// per <code>STREAMINTERVALMS</code> of the limits class, and only when the text has grown. Once a
/// written text has reached <code>TEXTMAXLENGTH</code> nothing more is written. A write that fails,
/// or raises, stops this sink for the rest of the call and never fails the call. The clock is read
/// through <method>NowMs</method>, which a probe overrides.</p>
Class OcuPilot.Kernel.Agent.StreamStep Extends OcuPilot.Kernel.Provider.StreamSink
{

/// <p>The turn whose step this writes.</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>The running model step's sequence number.</p>
Property Seq As %Integer;

/// <p>The class the cadence and the cap are read from.</p>
Property LimitsClass As %String(MAXLEN = 128);

/// <p>When the last write was made, in <method>NowMs</method> units, or <code>""</code> before the
/// first.</p>
Property LastWriteMs As %Numeric;

/// <p>The length of the text the last write carried.</p>
Property LastLength As %Integer [ InitialExpression = 0 ];

/// <p>Set once a write failed; nothing more is written.</p>
Property Off As %Boolean [ InitialExpression = 0 ];

/// <p>A sink for step <var>pSeq</var> of turn <var>pKey</var> under <var>pLimitsClass</var>.</p>
Method %OnNew(pKey As %String = "", pSeq As %Integer = 0, pLimitsClass As %String = "") As %Status
{
    Set ..TurnKey = pKey
    Set ..Seq = pSeq
    Set ..LimitsClass = pLimitsClass
    Set ..LastWriteMs = ""
    Quit $$$OK
}

/// <p>Write <var>pText</var> when the cadence and the cap allow it. Never raises.</p>
Method Publish(pText As %String)
{
    Try {
        If ..Off Quit
        Set tLength = $Length(pText)
        If tLength <= ..LastLength Quit
        Set tCap = +$Parameter(..LimitsClass, "TEXTMAXLENGTH")
        If (tCap > 0) && (..LastLength >= tCap) Quit
        Set tNow = ..NowMs()
        If ..LastWriteMs '= "" {
            Set tElapsed = tNow - ..LastWriteMs
            ; A negative difference is the clock's midnight wrap, and reads as time having passed.
            If (tElapsed >= 0) && (tElapsed < +$Parameter(..LimitsClass, "STREAMINTERVALMS")) Quit
        }
        Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedSnapshotText(..TurnKey, ..Seq, pText, ..LimitsClass)
        If $$$ISERR(tSC) {
            Set ..Off = 1
            Quit
        }
        Set ..LastWriteMs = tNow
        Set ..LastLength = tLength
    } Catch ex {
        Set ..Off = 1
    }
}

/// <p>Milliseconds on a within-the-day scale, used only as a difference.</p>
Method NowMs() As %Numeric
{
    Quit $ZHorolog * 1000
}

}
