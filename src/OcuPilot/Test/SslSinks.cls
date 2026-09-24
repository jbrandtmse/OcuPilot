/// <p>The sinks the SSL/TLS tests scan for text that must never reach them (AD-35, AD-39): the lines
/// written to this instance's <code>messages.log</code> -- where every OcuPilot log line goes, and
/// which the messages log screen and its read tool show -- and the instance's own audit rows, both
/// read from a mark taken before the operation under test.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SslSinks Extends %RegisteredObject
{

/// <p>The path of this instance's <code>messages.log</code>, read at call time.</p>
ClassMethod LogPath() As %String
{
    Quit ##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory())
}

/// <p>How many bytes <code>messages.log</code> holds now: the mark <method>LogSince</method> reads
/// from.</p>
ClassMethod LogOffset() As %Integer
{
    Quit +##class(%File).GetFileSize(..LogPath())
}

/// <p>The text <code>messages.log</code> gained after byte <var>pOffset</var>: <code>""</code> when it
/// has not grown, and the whole file when it is now shorter than the mark (it rotated).</p>
ClassMethod LogSince(pOffset As %Integer) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        If $$$ISERR(tStream.LinkToFile(..LogPath())) Quit
        If tStream.Size = pOffset Quit
        If tStream.Size > pOffset Do tStream.MoveTo(pOffset + 1)
        While 'tStream.AtEnd {
            Set tText = tText _ tStream.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

/// <p>Write two lines of its own to <code>messages.log</code>, one after the other, waiting up to
/// <var>pSeconds</var> for each to be in the file after byte <var>pOffset</var>; answer whether both
/// arrived. The instance writes the log late and holds a repeated line until a different one
/// follows, then writes the held line after that one -- so the first line releases whatever the
/// operation under test logged, and the second lands only after it.</p>
ClassMethod Flush(pOffset As %Integer, pSeconds As %Integer = 30) As %Boolean
{
    Set tLanded = 0
    For tRound = 1, 2 {
        Set tLine = "OcuPilot test log flush " _ $Job _ "-" _ tRound _ "-" _ $Random(1000000000)
        Do ##class(%SYS.System).WriteToConsoleLog(tLine, 0, 0)
        Set tLanded = 0
        For tI = 1:1:(pSeconds * 4) {
            If ..LogSince(pOffset) [ tLine {
                Set tLanded = 1
                Quit
            }
            Hang 0.25
        }
        If 'tLanded Quit
    }
    Quit tLanded
}

/// <p>The instant this instance's audit rows are stamped in, as their <code>UTCTimeStamp</code>
/// spells it: the mark <method>AuditSince</method> reads from.</p>
ClassMethod AuditMark() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, 1, 3)
}

/// <p>Every audit row stamped at or after <var>pMark</var>, its description and its data, joined.
/// The audit database is read in <code>%SYS</code> (AD-16) with the mark bound, never
/// concatenated.</p>
ClassMethod AuditSince(pMark As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ?", pMark)
        While tResult.%Next() {
            Set tText = tText _ tResult.%Get("Description") _ "|" _ tResult.%Get("EventData") _ $Char(10)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>Every member of the ledger row <var>pRow</var> (as <method>OcuPilot.Test.AuditMarker.WriteRow</method>
/// answers it), joined.</p>
ClassMethod Joined(ByRef pRow) As %String
{
    Set tText = ""
    Set tName = ""
    For {
        Set tName = $Order(pRow(tName))
        If tName = "" Quit
        Set tText = tText _ pRow(tName) _ "|"
    }
    Quit tText
}

/// <p>Every text column of every ledger row of turn <var>pTurnKey</var>, joined: what the ledger
/// recorded of the turn's calls and writes.</p>
ClassMethod LedgerText(pTurnKey As %String) As %String
{
    Set tText = ""
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Kind, Name, Route, Target, Arguments, Fields, Code, Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurnKey)
    While tResult.%Next() {
        For tI = 1:1:8 Set tText = tText _ tResult.%GetData(tI) _ "|"
        Set tText = tText _ $Char(10)
    }
    Quit tText
}

}
