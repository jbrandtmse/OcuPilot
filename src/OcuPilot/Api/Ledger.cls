/// <p>The handler behind <code>GET /agent/ledger</code> (Story 4.9, AD-12, AD-24, AD-46): the one
/// route the agent ledger is read through, and the agent audit viewer's (Story 16.16). Every caller
/// has cleared <method>OcuPilot.Api.Router.OnPreDispatch</method>.</p>
/// <p><b>Thin by rule.</b> It validates the shape of three query parameters -- <code>user</code>,
/// <code>windowHours</code> and <code>maxRows</code> -- and of the four search criteria
/// (<code>all</code>, <code>route</code>, <code>begin</code>, <code>end</code>), passes
/// <code>turnKey</code> through as the bound value it is, and delegates;
/// the subject's resolution, the cross-user privilege gate, the bounded read and the per-row gate
/// are all <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s, which is where AD-46 puts
/// them. Nothing here reads the store and nothing here evaluates a pair.</p>
/// <p><b>Validation refuses a malformed request; it is not what protects the query.</b> Every value
/// the read uses is bound as a parameter (AD-21), so a <code>user</code> carrying SQL matches
/// literally and finds nothing -- the shape check is about answering a caller clearly, not about
/// defending the statement.</p>
Class OcuPilot.Api.Ledger Extends %RegisteredObject
{

/// <p>The loop whose limits class every bound here is read from.</p>
Parameter LOOPCLASS = "OcuPilot.Kernel.Agent.Loop";

/// <p>The query parameters this route reads.</p>
Parameter USERPARAM = "user";

Parameter WINDOWPARAM = "windowHours";

Parameter TURNKEYPARAM = "turnKey";

Parameter MAXROWSPARAM = "maxRows";

/// <p>The four search criteria (Story 16.16).</p>
Parameter ALLPARAM = "all";

Parameter ROUTEPARAM = "route";

Parameter BEGINPARAM = "begin";

Parameter ENDPARAM = "end";

/// <p>The shape a screen route takes: lower-case segments of letters, digits and hyphens, joined by
/// <code>/</code>, at most <parameter>ROUTEMAXLENGTH</parameter> characters.</p>
Parameter ROUTEPATTERN = "^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$";

Parameter ROUTEMAXLENGTH As %Integer = 512;

/// <p>The shape an account name takes on this instance: a letter, a digit or an underscore, then up
/// to 159 more of those plus <code>.</code>, <code>@</code>, <code>%</code> and <code>-</code>. Wide
/// enough for <code>_SYSTEM</code> and for an LDAP principal, and narrow enough that a caller who
/// sent something else is told so rather than answered with an empty list.</p>
Parameter USERPATTERN = "^[A-Za-z0-9_][A-Za-z0-9_.@%-]{0,159}$";

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>The ledger this handler reads through. Overridable for a fixture; production never overrides
/// it.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Ledger"
}

/// <p>Answer <code>GET /agent/ledger</code>:
/// <code>{rows, rowsSent, truncated, rowsWithheld, rowsDropped, windowHours, criteria}</code>, the
/// caller's own rows unless <code>user</code> names another, or <code>all</code> asks for every
/// user, and the caller holds the OcuPilot administrative resource.</p>
/// <p><code>windowHours</code> defaults to the store's own default window and
/// <code>maxRows</code> to <code>LEDGERVIEWMAXROWS</code>; a <code>turnKey</code> selects one turn's
/// rows and the window then does not apply. Each of the three shapes refuses with its own
/// <code>LEDGER.*</code> code in one envelope (AD-12).</p>
/// <p>The criteria: <code>all</code> is <code>""</code> or <code>1</code> and never beside a
/// <code>user</code>; <code>route</code> is a screen route (<parameter>ROUTEPATTERN</parameter>);
/// <code>begin</code> and <code>end</code> are instance local times
/// (<method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method>), <code>end</code> not before
/// <code>begin</code>, and <code>begin</code> never beside a non-zero <code>windowHours</code>.
/// Each refuses <code>LEDGER.CRITERION.INVALID</code> naming <code>detail.criterion</code>; a
/// <code>begin</code> more than the bounded window ago refuses
/// <code>LEDGER.WINDOW.INVALID</code>.</p>
ClassMethod Handle() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tLimits = $ClassMethod(..#LOOPCLASS, "LimitsClass")
        Set tViewCap = +$Parameter(tLimits, "LEDGERVIEWMAXROWS")
        Set tMaxWindow = +$Parameter("OcuPilot.Kernel.State.Base", "BOUNDEDMAXHOURS")

        Set tSubject = %request.Get(..#USERPARAM, "")
        If (tSubject '= "") && '$Match(tSubject, ..#USERPATTERN) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONLEDGERUSERINVALID, ##class(OcuPilot.Api.Error).#LEDGERUSERINVALID)
            Quit
        }

        Set tWindow = %request.Get(..#WINDOWPARAM, "")
        If tWindow = "" Set tWindow = 0
        If '$Match(tWindow, "^(0|[1-9][0-9]*)$") || (tWindow > tMaxWindow) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONLEDGERWINDOWINVALID _ ": 0 for the default window, or a whole number of hours up to " _ tMaxWindow _ ".", ##class(OcuPilot.Api.Error).#LEDGERWINDOWINVALID)
            Quit
        }

        Set tMaxRows = %request.Get(..#MAXROWSPARAM, "")
        If tMaxRows = "" Set tMaxRows = tViewCap
        If '$Match(tMaxRows, "^[1-9][0-9]*$") || (tMaxRows > tViewCap) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONLEDGERMAXROWSINVALID _ ": a whole number from 1 to " _ tViewCap _ ".", ##class(OcuPilot.Api.Error).#LEDGERMAXROWSINVALID)
            Quit
        }

        Set tAll = %request.Get(..#ALLPARAM, "")
        If (tAll '= "") && (tAll '= "1") {
            Set tSC = ..RefuseCriterion(..#ALLPARAM)
            Quit
        }
        If (tAll = "1") && (tSubject '= "") {
            Set tSC = ..RefuseCriterion(..#ALLPARAM)
            Quit
        }
        Set tRoute = %request.Get(..#ROUTEPARAM, "")
        If (tRoute '= "") && (($Length(tRoute) > ..#ROUTEMAXLENGTH) || '$Match(tRoute, ..#ROUTEPATTERN)) {
            Set tSC = ..RefuseCriterion(..#ROUTEPARAM)
            Quit
        }
        Set tLedger = ..LedgerClass()
        Set tBegin = %request.Get(..#BEGINPARAM, "")
        Set tBeginUtc = ""
        If tBegin '= "" {
            Set tBeginUtc = $ClassMethod(tLedger, "LocalToUtc", tBegin)
            If (tBeginUtc = "") || (+tWindow '= 0) {
                Set tSC = ..RefuseCriterion(..#BEGINPARAM)
                Quit
            }
        }
        Set tEnd = %request.Get(..#ENDPARAM, "")
        If tEnd '= "" {
            Set tEndUtc = $ClassMethod(tLedger, "LocalToUtc", tEnd)
            If (tEndUtc = "") || ((tBeginUtc '= "") && (tEndUtc ']] tBeginUtc) && (tEndUtc '= tBeginUtc)) {
                Set tSC = ..RefuseCriterion(..#ENDPARAM)
                Quit
            }
        }
        If (tBeginUtc '= "") && '$ClassMethod(tLedger, "WindowFromBegin", tBeginUtc, .tHours) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONLEDGERWINDOWINVALID _ ": a begin no more than " _ tMaxWindow _ " hours ago.", ##class(OcuPilot.Api.Error).#LEDGERWINDOWINVALID)
            Quit
        }

        Set tViewSC = $ClassMethod(tLedger, "ViewForUser", ..CallerUsername(), tSubject, +tWindow, %request.Get(..#TURNKEYPARAM, ""), +tMaxRows, .tView, .tFault, (tAll = "1"), tRoute, tBegin, tEnd)
        If $$$ISERR(tViewSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tViewSC))
            Quit
        }
        If $IsObject(tFault) {
            Set tSC = ..RenderFault(tFault)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tView)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Refuse the criterion <var>pCriterion</var>: 400 <code>LEDGER.CRITERION.INVALID</code> with
/// <code>detail.criterion</code> naming it.</p>
ClassMethod RefuseCriterion(pCriterion As %String) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("criterion", pCriterion, "string")
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONLEDGERCRITERIONINVALID, ##class(OcuPilot.Api.Error).#LEDGERCRITERIONINVALID, tDetail)
}

/// <p>Render the wire fault <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> answered, on
/// the HTTP status its machine code carries: a refused cross-user read is 403 and an unreadable
/// store is 503. An unmapped code renders 500 through the one internal renderer rather than
/// guessing a status.</p>
ClassMethod RenderFault(pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = pFault.%Get("code")
    Set tDetail = $Select(pFault.%GetTypeOf("detail") = "object": pFault.%Get("detail"), 1: "")
    If tCode = ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE {
        Quit ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, pFault.%Get("reason"), tCode, tDetail)
    }
    If tCode = ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE {
        Quit ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, pFault.%Get("reason"), tCode, tDetail)
    }
    Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the ledger answered an unmapped fault code: " _ tCode)))
}

}
