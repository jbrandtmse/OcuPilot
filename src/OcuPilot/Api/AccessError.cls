/// <p>The screen permission codes and sentences (AD-29, AD-39, AD-64, Story 20.15): every
/// <code>ACCESS.*</code> code <class>OcuPilot.Port.ScreenAccessPort</class> answers with, and the
/// sentence each carries. Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned
/// equal to its <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/access.test.mjs</file>.
/// They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290).</p>
/// <p>The unknown screen is rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with
/// 404, the not-adjusted reset on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409,
/// and every other code on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422,
/// carrying one violation on <code>Pair</code>.</p>
Class OcuPilot.Api.AccessError Extends %RegisteredObject
{

/// <p>The identifier names no built screen.</p>
Parameter SCREENUNKNOWN = "ACCESS.SCREEN.UNKNOWN";

Parameter REASONSCREENUNKNOWN = "No screen has that identifier.";

/// <p>Reset of a screen that requires its declared permissions already.</p>
Parameter NOTADJUSTED = "ACCESS.NOTADJUSTED";

Parameter REASONNOTADJUSTED = "This screen already requires its declared permissions, so there is nothing to reset.";

/// <p>Removal of the last required permission.</p>
Parameter PAIRSEMPTY = "ACCESS.PAIRS.EMPTY";

Parameter REASONPAIRSEMPTY = "A screen keeps at least one required permission.";

/// <p>A resource this instance does not define.</p>
Parameter RESOURCEUNKNOWN = "ACCESS.RESOURCE.UNKNOWN";

Parameter REASONRESOURCEUNKNOWN = "This instance defines no resource of that name.";

/// <p>A pair that is not a resource and one of READ, WRITE or USE.</p>
Parameter PAIRMALFORMED = "ACCESS.PAIR.MALFORMED";

Parameter REASONPAIRMALFORMED = "Name a resource and a permission, written resource:permission, where the permission is READ, WRITE or USE.";

/// <p>Removal of a pair the set does not hold.</p>
Parameter PAIRABSENT = "ACCESS.PAIR.ABSENT";

Parameter REASONPAIRABSENT = "This screen's required permissions do not include that pair.";

/// <p>Addition of a pair the set already holds.</p>
Parameter PAIRPRESENT = "ACCESS.PAIR.PRESENT";

Parameter REASONPAIRPRESENT = "This screen's required permissions already include that pair.";

/// <p>Addition of a pair to a full set.</p>
Parameter PAIRSTOOMANY = "ACCESS.PAIRS.TOOMANY";

Parameter REASONPAIRSTOOMANY = "A screen requires at most 8 permissions.";

/// <p>The most pairs a screen's adjusted set holds.</p>
Parameter MAXPAIRS = 8;

/// <p>Every code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#SCREENUNKNOWN, ..#NOTADJUSTED, ..#PAIRSEMPTY, ..#RESOURCEUNKNOWN, ..#PAIRMALFORMED, ..#PAIRABSENT, ..#PAIRPRESENT, ..#PAIRSTOOMANY)
}

/// <p>The codes a tool's fresh read refuses with when the action's precondition does not hold, as a
/// <class>%List</class>: <class>OcuPilot.Screen.Tool.Write</class>'s <code>PRECONDITIONCODES</code>.
/// Each depends on the stored set, so a confirm whose set moved closes the proposal as target-changed.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit $ListBuild(..#NOTADJUSTED, ..#PAIRSEMPTY, ..#PAIRABSENT, ..#PAIRPRESENT, ..#PAIRSTOOMANY)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#SCREENUNKNOWN Quit ..#REASONSCREENUNKNOWN
    If pCode = ..#NOTADJUSTED Quit ..#REASONNOTADJUSTED
    If pCode = ..#PAIRSEMPTY Quit ..#REASONPAIRSEMPTY
    If pCode = ..#RESOURCEUNKNOWN Quit ..#REASONRESOURCEUNKNOWN
    If pCode = ..#PAIRMALFORMED Quit ..#REASONPAIRMALFORMED
    If pCode = ..#PAIRABSENT Quit ..#REASONPAIRABSENT
    If pCode = ..#PAIRPRESENT Quit ..#REASONPAIRPRESENT
    If pCode = ..#PAIRSTOOMANY Quit ..#REASONPAIRSTOOMANY
    Quit ""
}

}
