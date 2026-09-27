/// <p>The retention sweep over OcuPilot's own state (AD-37, the Operational Envelope's Retention
/// row), run once a day by <class>OcuPilot.Kernel.RetentionTask</class>.</p>
/// <p><b>What goes, in order.</b> Terminal turns past their short retention, with their steps,
/// directives, proposals and signals (<method>OcuPilot.Kernel.State.Turn.GuardedSweep</method>);
/// every user's turn start records past the turns-an-hour window
/// (<method>OcuPilot.Kernel.State.Turn.GuardedSweepStarts</method>), whether or not the account
/// still exists;
/// every conversation entry older than its own definition's
/// <property>OcuPilot.Kernel.State.Agent.RetentionDays</property>, then every conversation left with
/// no entry once it is older than the longest retention; every ledger row older than the longest
/// retention, so the per-row gate (AD-46) outlives every transcript it gates; and, for an account the
/// instance no longer holds, its running turns, its preferences and its sharing choice.</p>
/// <p><b>What is never removed for a deletion.</b> A deleted user's transcripts and ledger rows age
/// like everyone's; the principal-gone pass abandons turns and removes per-user settings only. Only
/// an account the instance answers does not exist is gone; one whose read fails, or whose identity
/// escalation is unavailable, is treated as present, so an unreadable identity removes nothing.</p>
/// <p>Each step's failure is logged under <parameter>LOGSUBSYSTEM</parameter> and does not stop the
/// next; <method>Sweep</method> answers the first failure.</p>
Class OcuPilot.Kernel.Retention Extends %RegisteredObject
{

/// <p>The subsystem a sweep failure is logged under.</p>
Parameter LOGSUBSYSTEM = "retention";

/// <p>Seconds the ledger is kept beyond the longest retention. A turn's ledger rows are logged
/// while it runs and its conversation entry is appended when it ends, at most the turn's wall-clock
/// limit later (AD-31), so the ledger cutoff trails the entry cutoff by more than that limit and the
/// oldest row of a kept entry is never the one removed.</p>
Parameter LEDGERMARGINSECONDS As %Integer = 3600;

/// <p>Run the sweep with <var>pLimitsClass</var>'s bounds (<class>OcuPilot.Kernel.Agent.Limits</class>
/// in production). A step that fails or throws is logged and the next step still runs; the answer
/// is the first failure.</p>
ClassMethod Sweep(pLimitsClass As %String = "OcuPilot.Kernel.Agent.Limits") As %Status
{
    Set tFirst = $$$OK
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()

    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedSweep(pLimitsClass)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSC = ..Step("terminal turns past retention could not be swept", tSC)
    If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC

    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedSweepStarts(pLimitsClass)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSC = ..Step("turn start records past their window could not be swept", tSC)
    If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC

    Kill tById
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedRetentions(.tById, .tDefaultDays, .tLongestDays)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSC = ..Step("the agent definitions' retention could not be read", tSC)
    If $$$ISERR(tSC) {
        If $$$ISOK(tFirst) Set tFirst = tSC
    } Else {
        Kill tCutoffs
        Set tCutoffs = tNow - (tDefaultDays * 86400)
        Set tId = ""
        For {
            Set tId = $Order(tById(tId), 1, tDays)
            If tId = "" Quit
            Set tCutoffs(tId) = tNow - (tDays * 86400)
        }
        Set tLongestCutoff = tNow - (tLongestDays * 86400)

        Try {
            Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedPurge(.tCutoffs, .tEntries)
        } Catch ex {
            Set tSC = ex.AsStatus()
        }
        Set tSC = ..Step("conversation entries past retention could not be removed", tSC)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
        Try {
            Set tSC = ##class(OcuPilot.Kernel.State.Convo).GuardedPurgeEmpty(..Iso(tLongestCutoff), .tConversations)
        } Catch ex {
            Set tSC = ex.AsStatus()
        }
        Set tSC = ..Step("empty conversations past retention could not be removed", tSC)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
        Try {
            Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedPurgeBefore(..Iso(tLongestCutoff - ..#LEDGERMARGINSECONDS), .tLedgerRows)
        } Catch ex {
            Set tSC = ex.AsStatus()
        }
        Set tSC = ..Step("ledger rows past retention could not be removed", tSC)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
    }

    Try {
        Set tSC = ..SweepGonePrincipals()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSC = ..Step("the state of deleted accounts could not be swept", tSC)
    If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
    Quit tFirst
}

/// <p>The principal-gone pass (AD-37): every user a <code>queued</code> or <code>running</code>
/// turn, a preference row or a sharing row names is asked about through <method>IsGone</method>;
/// for an account the instance answers does not exist, the user's turns are asked to abandon and
/// the user's preference and sharing rows are deleted. Anything else about the user is left. The
/// first failure is answered after every user has been visited.</p>
ClassMethod SweepGonePrincipals() As %Status
{
    Set tFirst = $$$OK
    Kill tUsers
    For tStore = "OcuPilot.Kernel.State.Turn:GuardedLiveUsers", "OcuPilot.Kernel.State.Pref:GuardedUsers", "OcuPilot.Kernel.State.Sharing:GuardedUsers" {
        Kill tFound
        Set tSC = $ClassMethod($Piece(tStore, ":", 1), $Piece(tStore, ":", 2), .tFound)
        If $$$ISERR(tSC) {
            If $$$ISOK(tFirst) Set tFirst = tSC
            Continue
        }
        Merge tUsers = tFound
    }
    Set tUser = ""
    For {
        Set tUser = $Order(tUsers(tUser))
        If tUser = "" Quit
        If '..IsGone(tUser) Continue
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser(tUser, .tCount)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedDeleteForUser(tUser)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
        Set tSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedDeleteForUser(tUser)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
    }
    Quit tFirst
}

/// <p>Whether the instance no longer holds account <var>pUser</var>, as
/// <method>OcuPilot.Kernel.State.Base.GuardedUserAbsent</method> answers it: only a positive "no
/// such account" is gone, and an unavailable escalation or a failed read answers 0.</p>
ClassMethod IsGone(pUser As %String) As %Boolean
{
    Quit ''$ClassMethod(..IdentityClass(), "GuardedUserAbsent", pUser, .tUnavailable)
}

/// <p>The storage face <method>IsGone</method> asks. Overridable so a test can drive an
/// unavailable identity read, which no instance produces on demand; production never overrides
/// it.</p>
ClassMethod IdentityClass() As %String
{
    Quit "OcuPilot.Kernel.State.Base"
}

/// <p><var>pStatus</var>, logged with <var>pMessage</var> when it is an error.</p>
ClassMethod Step(pMessage As %String, pStatus As %Status) As %Status [ Private ]
{
    If $$$ISERR(pStatus) Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus)
    Quit pStatus
}

/// <p>The ISO-8601 UTC form of <var>pSeconds</var>, in
/// <method>OcuPilot.Kernel.State.Turn.NowSeconds</method> units.</p>
ClassMethod Iso(pSeconds As %Integer) As %String
{
    Quit ##class(OcuPilot.Kernel.State.Turn).Timestamp((pSeconds \ 86400) _ "," _ (pSeconds # 86400))
}

}
