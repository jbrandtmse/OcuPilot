/// <p>The one place that answers "may this write happen, and why not" (AD-30, AD-40). The
/// write-tool boundary, the turn loop's step check and the confirm transition each call
/// <method>Verdict</method>; none of them re-derives it, and <b>nothing else in the ObjectScript
/// source produces a restraint code</b> -- <file>scripts/check-objectscript.py</file>'s
/// restraint-code containment rule refuses a second producer.</p>
/// <p><b>That rule is narrower than the property it serves</b>, in three named ways. It bans a
/// second producer of a restraint <i>code</i>: a caller that read
/// <class>OcuPilot.Kernel.State.Switch</class> and <class>OcuPilot.Kernel.State.Hold</class> and
/// decided for itself would name no code and pass it, and those stores cannot be restricted by
/// class name because <class>OcuPilot.Api.Switches</class> reads both of them legitimately. It
/// reads <file>.cls</file>, <file>.mac</file> and <file>.inc</file> only, so a client that named a
/// code would pass it. And within those it skips comments and XData bodies. The wider property is
/// held by review.</p>
/// <p>It sits beside <class>OcuPilot.Kernel.Egress</class>, which is the shipped layout of a policy
/// class over a <package>OcuPilot.Kernel.State</package> store: the store answers what is written
/// down, the policy class decides what follows from it. <package>OcuPilot.Kernel.Governance</package>
/// is AD-22's polish-week folder and stays empty.</p>
/// <p><b>Read on every call, returned as values.</b> No memo, no process-private cache and no held
/// object: an OREF kept across a call makes <method>%OpenId</method> hand back the stale copy
/// (<file>.claude/rules/objectscript-basics.md</file>), and AD-30's rule is that neither switch is
/// cached for the length of a turn. Every reference this class opens is dropped before it
/// returns.</p>
/// <p><b>A read that fails blocks.</b> <method>Verdict</method> answers <var>pVerdict</var>
/// <code>blocked</code> 1 alongside the error <class>%Status</class>: a caller that cannot learn
/// whether the agent is restrained must not write.</p>
/// <p><b>Story 14.5's per-user read-only becomes a fourth source read inside this method</b> -- one
/// more <code>If</code> and one more footer key (<code>statusReadOnlyForYou</code>, already
/// published) -- so the three call sites never change and no second check is possible.</p>
Class OcuPilot.Kernel.Restraint Extends %RegisteredObject
{

/// <p>Audience: the kill switch is on for everyone on this instance. It resolves the published
/// kill-switch banner's <code>&lt;everyone / you&gt;</code> slot, so it is a machine value rather
/// than copy -- the client picks the word out of the published literal.</p>
Parameter AUDIENCEEVERYONE = "everyone";

/// <p>Audience: the kill switch is on for the acting user alone.</p>
Parameter AUDIENCEYOU = "you";

/// <p>The client string key the panel's always-shown footer line renders when nothing restrains the
/// agent to reads.</p>
Parameter FOOTERKEYOFF = "statusReadOnlyOff";

/// <p>The client string key that line renders under enforced read-only. Broadest scope, so it wins
/// over <parameter>FOOTERKEYDEFINITION</parameter> when both sources are on -- the order the
/// published footer row lists them in <i>(inference: that ordering is the only evidence selecting a
/// precedence; no document states one outright)</i>.</p>
Parameter FOOTERKEYENFORCED = "statusReadOnlyEnforced";

/// <p>The client string key that line renders when the definition in force is itself read-only.</p>
Parameter FOOTERKEYDEFINITION = "statusReadOnlyByDefinition";

/// <p>Whether a write may happen for <var>pUserName</var> under the definition
/// <var>pDefinitionId</var>, and why not.</p>
/// <p><var>pVerdict</var> comes back subscripted by:</p>
/// <ul>
/// <li><code>blocked</code> -- 1 when no write may be made.</li>
/// <li><code>code</code> -- the restraint code (<class>OcuPilot.Api.Error</class>), or
/// <code>""</code> when nothing blocks.</li>
/// <li><code>reason</code> -- that code's written sentence, or <code>""</code>.</li>
/// <li><code>footerKey</code> -- the one client string key the panel's footer line renders.</li>
/// <li><code>killSwitch</code> -- 1 when the agent is switched off for this caller.</li>
/// <li><code>killSwitchAudience</code> -- <parameter>AUDIENCEEVERYONE</parameter>,
/// <parameter>AUDIENCEYOU</parameter> or <code>""</code>.</li>
/// <li><code>killSwitchReason</code> -- the operator's own text, verbatim, or <code>""</code>.</li>
/// <li><code>enforcedReadOnly</code> -- 1 while the instance switch is on, which is the one
/// read-only source that also carries a banner.</li>
/// </ul>
/// <p><b>Precedence is broadest first.</b> The kill switch outranks read-only, because a switched-off
/// agent does not read either; within the kill switch, the instance outranks the user; within
/// read-only, enforced outranks the definition. Exactly one <code>code</code> and exactly one
/// <code>footerKey</code> come back, so the panel cannot say two things at once.</p>
/// <p><b>Caller contract:</b> <var>pDefinitionId</var> is the definition already resolved for this
/// turn (<method>OcuPilot.Kernel.State.Agent.ResolveDefault</method>); <code>""</code> means no
/// definition is in force, which contributes no read-only source of its own. Check
/// <code>$$$ISERR</code> on the returned status: a failed read blocks, and proceeding on it would
/// be a write made while the switches were unreadable.</p>
ClassMethod Verdict(pUserName As %String, pDefinitionId As %String, Output pVerdict) As %Status
{
    Kill pVerdict
    Set pVerdict("blocked") = 1
    Set pVerdict("code") = ""
    Set pVerdict("reason") = ""
    Set pVerdict("footerKey") = ..#FOOTERKEYOFF
    Set pVerdict("killSwitch") = 0
    Set pVerdict("killSwitchAudience") = ""
    Set pVerdict("killSwitchReason") = ""
    Set pVerdict("enforcedReadOnly") = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitches)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedForUser(pUserName, .tHeld, .tHoldReason)
        If $$$ISERR(tSC) Quit
        Set tSC = ..DefinitionReadOnly(pDefinitionId, .tByDefinition)
        If $$$ISERR(tSC) Quit

        Set pVerdict("enforcedReadOnly") = ''tSwitches("enforcedReadOnly")
        If pVerdict("enforcedReadOnly") {
            Set pVerdict("footerKey") = ..#FOOTERKEYENFORCED
        } ElseIf tByDefinition {
            Set pVerdict("footerKey") = ..#FOOTERKEYDEFINITION
        }

        If ''tSwitches("killSwitch") {
            Set pVerdict("killSwitch") = 1
            Set pVerdict("killSwitchAudience") = ..#AUDIENCEEVERYONE
            Set pVerdict("killSwitchReason") = tSwitches("killSwitchReason")
        } ElseIf tHeld {
            Set pVerdict("killSwitch") = 1
            Set pVerdict("killSwitchAudience") = ..#AUDIENCEYOU
            Set pVerdict("killSwitchReason") = tHoldReason
        }

        Set pVerdict("blocked") = 0
        If pVerdict("killSwitchAudience") = ..#AUDIENCEEVERYONE {
            Do ..Refuse(.pVerdict, ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL)
        } ElseIf pVerdict("killSwitchAudience") = ..#AUDIENCEYOU {
            Do ..Refuse(.pVerdict, ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER)
        } ElseIf pVerdict("enforcedReadOnly") {
            Do ..Refuse(.pVerdict, ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED)
        } ElseIf tByDefinition {
            Do ..Refuse(.pVerdict, ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pVerdict("blocked") = 1
    }
    Quit tSC
}

/// <p>Record <var>pCode</var> as the one reason this verdict blocks, with that code's written
/// sentence beside it (AD-39).</p>
ClassMethod Refuse(ByRef pVerdict, pCode As %String) [ Private ]
{
    Set pVerdict("blocked") = 1
    Set pVerdict("code") = pCode
    Set pVerdict("reason") = ##class(OcuPilot.Api.Error).ReasonForRestraint(pCode)
}

/// <p>Whether the definition <var>pDefinitionId</var> is itself restrained to reads
/// (<property>OcuPilot.Kernel.State.Agent.ReadOnly</property>, stored by Story 3.1 and enforced
/// here).</p>
/// <p><code>""</code>, and an id no row holds, contribute no read-only source: a turn with no
/// definition in force is the configuration-empty state rather than a restrained one. The row's
/// reference is dropped before this returns, so the next call re-reads rather than being handed the
/// copy still in memory.</p>
ClassMethod DefinitionReadOnly(pDefinitionId As %String, Output pReadOnly As %Boolean) As %Status [ Private ]
{
    Set pReadOnly = 0
    Set tSC = $$$OK
    Try {
        If pDefinitionId = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(pDefinitionId, .tExists)
        If $$$ISERR(tSC) Quit
        If 'tExists Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pDefinitionId, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set pReadOnly = ''tRow.ReadOnly
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The verdict for <var>pUserName</var> under the definition in force, resolving that definition
/// first (<method>OcuPilot.Kernel.State.Agent.ResolveDefault</method>).</p>
/// <p>It resolves an argument and calls <method>Verdict</method>; it computes no part of the
/// verdict itself.</p>
ClassMethod Resolved(pUserName As %String, Output pVerdict) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefinitionId)
    If $$$ISERR(tSC) {
        Do ..Verdict(pUserName, "", .pVerdict)
        Set pVerdict("blocked") = 1
        Quit tSC
    }
    Quit ..Verdict(pUserName, tDefinitionId, .pVerdict)
}

}
