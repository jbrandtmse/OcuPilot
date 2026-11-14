/// <p>The analytics codes and sentences (AD-29, AD-39, AD-65, Story 20.11): every <code>ANALYTICS.*</code> code
/// <class>OcuPilot.Port.AnalyticsPort</class> answers with, and the sentence each carries. Each sentence is
/// published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/analytics.test.mjs</file>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409: the
/// vendor's analytics classes check no <code>%DeepSee_*</code> resource, so the port decides before any call. The
/// <code>ANALYTICS.MDX.*</code> codes (Story 20.33) are MDX query's, each on the slug and status its comment names;
/// <code>ANALYTICS.MDX.SQL</code> (Story 20.35) is the agent's MDX read's.</p>
Class OcuPilot.Api.AnalyticsError Extends %RegisteredObject
{

/// <p>The route's namespace does not report analytics.</p>
Parameter NAMESPACE = "ANALYTICS.NAMESPACE";

Parameter REASONNAMESPACE = "Analytics is not enabled in this namespace.";

/// <p>400: the statement is empty or too long, or a drill-through does not name one cell of the answer.</p>
Parameter MDXINPUT = "ANALYTICS.MDX.INPUT";

Parameter REASONMDXINPUT = "Send one MDX statement of up to 100,000 characters; a drill-through names one cell of its answer.";

/// <p>422: the statement is not a SELECT or a DRILLTHROUGH.</p>
Parameter MDXKIND = "ANALYTICS.MDX.KIND";

Parameter REASONMDXKIND = "Only SELECT and DRILLTHROUGH statements run here; CREATE and DROP change only a session, which this tool does not keep.";

/// <p>422: the statement names more than two axes.</p>
Parameter MDXAXES = "ANALYTICS.MDX.AXES";

Parameter REASONMDXAXES = "A query here uses at most two axes: columns and rows.";

/// <p>409: the database the vendor keeps its result cache in is read-only.</p>
Parameter MDXREADONLY = "ANALYTICS.MDX.READONLY";

Parameter REASONMDXREADONLY = "This namespace keeps its analytics cache in a read-only database, so MDX cannot run here.";

/// <p>409: the caller already has an MDX run live.</p>
Parameter MDXBUSY = "ANALYTICS.MDX.BUSY";

Parameter REASONMDXBUSY = "An MDX query you started is still running; cancel it or wait for it to end.";

/// <p>503: the instance's live background runs, of every kind together, are at their cap.</p>
Parameter MDXFULL = "ANALYTICS.MDX.FULL";

Parameter REASONMDXFULL = "As many background queries as this instance allows are running, SQL and MDX together; try again when one ends.";

/// <p>404: no MDX run of the caller's has this id, or it has been swept.</p>
Parameter MDXNOTFOUND = "ANALYTICS.MDX.NOTFOUND";

Parameter REASONMDXNOTFOUND = "No MDX run of yours has this id; an ended run is kept for 15 minutes.";

/// <p>503: the run ended without an answer.</p>
Parameter MDXLOST = "ANALYTICS.MDX.LOST";

Parameter REASONMDXLOST = "The MDX run ended without an answer; run it again.";

/// <p>422: the agent's MDX read refuses a statement that may run server-side code or SQL, or that cannot be read as MDX.</p>
Parameter MDXSQL = "ANALYTICS.MDX.SQL";

Parameter REASONMDXSQL = "This query may run server-side code or SQL, which the agent's read never runs; you can run it yourself on MDX query after confirming.";

/// <p>409: a cube this build or synchronize reaches, the target or a cube that depends on it, is being built or synchronized now
/// (Story 20.34).</p>
Parameter CUBEBUSY = "ANALYTICS.CUBE.BUSY";

Parameter REASONCUBEBUSY = "This cube, or a cube that depends on it, is being built or synchronized now. Try again when that ends.";

/// <p>409: a synchronize of a cube, or of a cube that depends on it, whose source does not record its changes (DSTIME).</p>
Parameter CUBENODSTIME = "ANALYTICS.CUBE.NODSTIME";

Parameter REASONCUBENODSTIME = "This cube, or a cube that depends on it, has a source that does not record its changes (DSTIME), so it can only be built.";

/// <p>409: a synchronize of a cube, or of a cube that depends on it, that has never been built.</p>
Parameter CUBENOTBUILT = "ANALYTICS.CUBE.NOTBUILT";

Parameter REASONCUBENOTBUILT = "This cube, or a cube that depends on it, has never been built, so there is nothing to synchronize. Build it first.";

/// <p>409: the database the namespace keeps its cubes' facts in is read-only or not mounted.</p>
Parameter CUBEREADONLY = "ANALYTICS.CUBE.READONLY";

Parameter REASONCUBEREADONLY = "This namespace keeps its cubes' facts in a read-only database, so they cannot be built or synchronized here.";

/// <p>409: the instance answered a build or synchronize with an error it was not asked about by name; its text is logged, never sent.</p>
Parameter CUBEFAILED = "ANALYTICS.CUBE.FAILED";

Parameter REASONCUBEFAILED = "The instance answered this update with an error, so it may not have finished. The cube's Facts and Last update show what it holds now.";

/// <p>The consequence code of a build, which the proposal card and the typed-name dialog name.</p>
Parameter CUBEBUILD = "ANALYTICS.CUBE.BUILD";

/// <p>The consequence code of a synchronize.</p>
Parameter CUBESYNCHRONIZE = "ANALYTICS.CUBE.SYNCHRONIZE";

/// <p>The sentence for <var>pCode</var>, or <code>""</code> for a code this class does not hold.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#MDXINPUT Quit ..#REASONMDXINPUT
    If pCode = ..#MDXKIND Quit ..#REASONMDXKIND
    If pCode = ..#MDXAXES Quit ..#REASONMDXAXES
    If pCode = ..#MDXREADONLY Quit ..#REASONMDXREADONLY
    If pCode = ..#MDXBUSY Quit ..#REASONMDXBUSY
    If pCode = ..#MDXFULL Quit ..#REASONMDXFULL
    If pCode = ..#MDXNOTFOUND Quit ..#REASONMDXNOTFOUND
    If pCode = ..#MDXLOST Quit ..#REASONMDXLOST
    If pCode = ..#MDXSQL Quit ..#REASONMDXSQL
    If pCode = ..#CUBEBUSY Quit ..#REASONCUBEBUSY
    If pCode = ..#CUBENODSTIME Quit ..#REASONCUBENODSTIME
    If pCode = ..#CUBENOTBUILT Quit ..#REASONCUBENOTBUILT
    If pCode = ..#CUBEREADONLY Quit ..#REASONCUBEREADONLY
    If pCode = ..#CUBEFAILED Quit ..#REASONCUBEFAILED
    Quit ""
}

/// <p>The cube manager's codes (Story 20.34), as a <class>%List</class>: the five refusals of a build or synchronize.</p>
ClassMethod CubeCodes() As %List
{
    Quit $ListBuild(..#CUBEBUSY, ..#CUBENODSTIME, ..#CUBENOTBUILT, ..#CUBEREADONLY, ..#CUBEFAILED)
}

/// <p>The refusals the cube manager's fresh read answers when the action does not fit the state, as a <class>%List</class>:
/// those a build and a synchronize are refused with before any vendor call. <parameter>CUBEFAILED</parameter> is the vendor's
/// answer, not a state.</p>
ClassMethod CubePreconditionCodes() As %List
{
    Quit $ListBuild(..#CUBEBUSY, ..#CUBENODSTIME, ..#CUBENOTBUILT, ..#CUBEREADONLY, ..#NAMESPACE)
}

/// <p>The consequence codes of the cube manager's two writes, as a <class>%List</class>.</p>
ClassMethod CubeConsequenceCodes() As %List
{
    Quit $ListBuild(..#CUBEBUILD, ..#CUBESYNCHRONIZE)
}

}
