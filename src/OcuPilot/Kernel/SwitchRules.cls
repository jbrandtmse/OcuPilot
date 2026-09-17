/// <p>The rules that keep the agent switches and the per-user holds honest, applied in one pass that
/// <b>accumulates every violation</b> rather than stopping at the first -- the shape
/// <class>OcuPilot.Kernel.AgentRules</class> established, and for the same reason: an operator
/// filling in a form is told everything that is wrong with it at once.</p>
/// <p>Each violation is <code>{field, code, reason}</code> -- the field it lands on, a stable
/// machine code declared in <class>OcuPilot.Api.Error</class>, and that code's written sentence from
/// the same class (AD-39). Rendering them is
/// <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method>, which resolves a sentence by code,
/// so there is one violation renderer rather than two.</p>
/// <p><b>Not under <package>OcuPilot.Kernel.State</package></b>: that package may not name
/// <class>OcuPilot.Api.Error</class>, and this class needs its code vocabulary. It sits beside
/// <class>OcuPilot.Kernel.AgentRules</class>, which makes the same reference for the same
/// reason.</p>
Class OcuPilot.Kernel.SwitchRules Extends %RegisteredObject
{

/// <p>The longest kill-switch reason either surface stores, matching both properties' own
/// <code>MAXLEN</code>.</p>
Parameter MAXREASONLENGTH As %Integer = 512;

/// <p>The longest user name a hold may carry, matching
/// <property>OcuPilot.Kernel.State.Hold.UserName</property>'s own <code>MAXLEN</code>.</p>
Parameter MAXUSERNAMELENGTH As %Integer = 160;

/// <p>Every violation the instance-wide switch values <var>pValues</var> commit, appended to
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>; returns how
/// many.</p>
/// <p><b>The kill switch may not be on without a reason.</b> The published banner carries the
/// operator's reason in front of everyone it affects, so a switch with none would leave a sentence
/// with a hole in it. Turning the switch off leaves the reason alone -- it is history at that
/// point, not a claim.</p>
/// <p><b>The length rule applies whichever way the switch is set</b>, because it is the column's
/// limit rather than the banner's: a reason longer than <parameter>MAXREASONLENGTH</parameter>
/// fails <method>%Save</method> on the datatype, so a rule that skipped it while the switch was off
/// would answer 500 where every other bad field on this surface answers 422.</p>
/// <p><b>The row cap must be a whole number from 1 to 1,000</b> (Story 4.4, AD-24): the bound a
/// turn's screen context and every read tool result are cut to. A value of the wrong JSON type --
/// <method>OcuPilot.Api.Switches.MergeBody</method> lets an integer field's raw value through for
/// most JSON types, unlike a boolean or a string field, precisely so this rule can refuse it on
/// the field rather than silently keeping the stored value (a JSON boolean is the one type
/// <code>MergeBody</code> excludes itself, since it would otherwise read back as a plausible 1 or
/// 0 before this rule ever saw it) -- fails the same
/// whole-number match a string outside the range does.</p>
ClassMethod ValidateSwitches(ByRef pValues, Output pViolations) As %Integer
{
    Kill pViolations
    Set tReason = $Get(pValues("killSwitchReason"))
    If (''+$Get(pValues("killSwitch")) && ($ZStrip(tReason, "<>W") = "")) || ($Length(tReason) > ..#MAXREASONLENGTH) {
        Do ..Add(.pViolations, "killSwitchReason", ##class(OcuPilot.Api.Error).#AGENTSWITCHREASONREQUIRED)
    }
    Set tRowCap = $Get(pValues("contextRowCap"))
    If (tRowCap = "") || '$Match(tRowCap, "^[0-9]+$") || (+tRowCap < 1) || (+tRowCap > 1000) {
        Do ..Add(.pViolations, "contextRowCap", ##class(OcuPilot.Api.Error).#AGENTSWITCHCONTEXTROWCAP)
    }
    Quit +$Get(pViolations)
}

/// <p>Every violation the per-user hold <var>pValues</var> -- <code>userName</code> and
/// <code>reason</code> -- commits, in the order they are reported.</p>
/// <p><var>pHeldAlready</var> is whether the instance already holds that user, which the caller
/// reads through <method>OcuPilot.Kernel.State.Hold.GuardedIdForUser</method>: the unique index
/// refuses a second hold anyway, and the rule answers first so the caller gets a field rather than
/// <code>#5808</code>.</p>
ClassMethod ValidateHold(ByRef pValues, pHeldAlready As %Boolean = 0, Output pViolations) As %Integer
{
    Kill pViolations
    Set tUserName = $Get(pValues("userName"))
    If ($ZStrip(tUserName, "<>W") = "") || ($Length(tUserName) > ..#MAXUSERNAMELENGTH) {
        Do ..Add(.pViolations, "userName", ##class(OcuPilot.Api.Error).#AGENTHOLDUSERREQUIRED)
    } ElseIf ''pHeldAlready {
        Do ..Add(.pViolations, "userName", ##class(OcuPilot.Api.Error).#AGENTHOLDDUPLICATE)
    }
    Set tReason = $Get(pValues("reason"))
    If ($ZStrip(tReason, "<>W") = "") || ($Length(tReason) > ..#MAXREASONLENGTH) {
        Do ..Add(.pViolations, "reason", ##class(OcuPilot.Api.Error).#AGENTHOLDREASONREQUIRED)
    }
    Quit +$Get(pViolations)
}

/// <p>Append one violation as <code>$ListBuild(field, code)</code>, whose sentence
/// <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method> resolves by code (AD-39).</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
