/// <p>Subclass of <class>OcuPilot.Port.LogSourcePort</class> overriding only its
/// application-error seams, so <class>OcuPilot.Test.ErrorLog</class> runs the port's real step
/// order, its real <code>%SYS</code> window and its real projections while driving the branches a
/// live read cannot reach.</p>
/// <p>Every seam falls back to <code>##super()</code> when nothing is armed, so an unconfigured
/// call behaves like production. State lives in <code>^||OcuPilotErrorFixture</code>;
/// <method>Clear</method> forgets it.</p>
/// <p><b>It counts query executions, and counts <code>ErrorDetail</code>'s separately.</b>
/// <method>Queries</method> is what makes "no query runs before the gate" an observation rather
/// than an assertion against nothing; <method>Details</method> is this story's <b>secrecy
/// witness</b> -- it must read 0 across the namespaces, dates, list and read-tool paths and
/// non-zero only on the detail path, which is what says the summary path never reaches the
/// captured variable table (AD-48). A counter moves, a promise does not.</p>
/// <p>Both counters are incremented in <method>OpenQuery</method>, the port's one query
/// construction point, which runs <b>inside</b> the <code>%SYS</code> window. That is sound and
/// deliberate: a <code>..</code> call dispatches within the running class's own routine and needs
/// no class resolution, unlike a fresh <code>##class(OcuPilot.*)</code> dispatch, which is the
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code> trap the window is written around.</p>
Class OcuPilot.Test.ErrorLogFixture Extends OcuPilot.Port.LogSourcePort
{

/// <p>Answer <method>Sources</method> with the comma-separated <var>pKeys</var>, so a test can
/// take the application error key out of the fixed enum and reach the <code>LOG.SOURCE</code>
/// refusal <method>OcuPilot.Port.LogSourcePort.Errors</method> opens with.</p>
ClassMethod SetSources(pKeys As %String)
{
    Set ^||OcuPilotErrorFixture("sources") = pKeys
}

/// <p>Answer <method>ErrorLevels</method> with the comma-separated <var>pLevels</var>.</p>
ClassMethod SetLevels(pLevels As %String)
{
    Set ^||OcuPilotErrorFixture("levels") = pLevels
}

/// <p>Answer <method>PairsFor</method> for the application error source from the comma-separated
/// <var>pPairs</var>, each spelled <code>resource:permission</code>, whatever namespace is asked
/// for. An empty <var>pPairs</var> arms an <b>empty pair set</b>, which is a different thing from
/// arming nothing -- it is the shape an unresolvable resource produces, and the port must refuse it
/// rather than hand it to the gate.</p>
ClassMethod SetErrorPairs(pPairs As %String)
{
    Set ^||OcuPilotErrorFixture("pairs") = pPairs
}

/// <p>Answer <method>NamespaceResolver</method> with <var>pClass</var> --
/// <class>OcuPilot.Test.ErrorNamespaceResolver</class>, whose <code>GlobalDatabase</code> resolves
/// to nothing.</p>
ClassMethod SetNamespaceResolver(pClass As %String)
{
    Set ^||OcuPilotErrorFixture("resolver") = pClass
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var> --
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares.
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which the real
/// <code>$System.Security.Check</code> answers yes to every resource, so a denial cannot be
/// observed in process without this. The real check is exercised over the wire by
/// <class>OcuPilot.Test.ErrorLogDenial</class>.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotErrorFixture("gate") = pClass
}

/// <p>Answer <method>DetailQuery</method> with <var>pQuery</var>.</p>
ClassMethod SetDetailQuery(pQuery As %String)
{
    Set ^||OcuPilotErrorFixture("detailquery") = pQuery
}

/// <p>How many queries the port has constructed since <method>ClearCounts</method>, of any
/// name.</p>
ClassMethod Queries() As %Integer
{
    Quit +$Get(^||OcuPilotErrorFixture("queries"), 0)
}

/// <p>How many of those were <method>DetailQuery</method>'s -- the captured variable table. This
/// is the secrecy witness.</p>
ClassMethod Details() As %Integer
{
    Quit ..QueriesNamed(..DetailQuery())
}

/// <p>How many of those were <var>pQueryName</var>'s. A count per name, not one total, because
/// "the namespace was refused before the <i>date</i> query ran" is a statement about which query
/// ran rather than about how many: the enumeration the namespace is chosen from runs either
/// way.</p>
ClassMethod QueriesNamed(pQueryName As %String) As %Integer
{
    Quit +$Get(^||OcuPilotErrorFixture("query", pQueryName), 0)
}

/// <p>Reset every count, leaving every override armed, so one test can count a second call's
/// queries without re-arming the first call's setup.</p>
ClassMethod ClearCounts()
{
    Kill ^||OcuPilotErrorFixture("queries")
    Kill ^||OcuPilotErrorFixture("query")
}

/// <p>Forget every override and every count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotErrorFixture
}

ClassMethod Sources() As %List
{
    If '$Data(^||OcuPilotErrorFixture("sources")) Quit ##super()
    Quit $ListFromString(^||OcuPilotErrorFixture("sources"))
}

ClassMethod ErrorLevels() As %List
{
    If '$Data(^||OcuPilotErrorFixture("levels")) Quit ##super()
    Quit $ListFromString(^||OcuPilotErrorFixture("levels"))
}

ClassMethod PairsFor(pSource As %String, pNamespace As %String = "") As %List
{
    ; $Data, not $Get: an armed empty specification is an empty pair set, which is a different
    ; thing from arming nothing. The port refuses the first and evaluates the second.
    If (pSource '= ..#ERRORSKEY) || '$Data(^||OcuPilotErrorFixture("pairs")) Quit ##super(pSource, pNamespace)
    ; The port's OWN parser, not a copy of it: ObjectScript's [ Private ] is subclass-visible, so a
    ; subclass may call it, and the port's ParsePairs exists precisely so one pair grammar cannot be
    ; read two ways. An armed set the fixture parsed differently would test the fixture.
    Quit ..ParsePairs(^||OcuPilotErrorFixture("pairs"))
}

ClassMethod NamespaceResolver() As %String
{
    Set tForced = $Get(^||OcuPilotErrorFixture("resolver"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotErrorFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod DetailQuery() As %String
{
    Set tForced = $Get(^||OcuPilotErrorFixture("detailquery"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod OpenQuery(pQueryName As %String, Output pResultSet As %ResultSet) As %Status
{
    Set ^||OcuPilotErrorFixture("queries") = $Get(^||OcuPilotErrorFixture("queries"), 0) + 1
    Set ^||OcuPilotErrorFixture("query", pQueryName) = $Get(^||OcuPilotErrorFixture("query", pQueryName), 0) + 1
    Quit ##super(pQueryName, .pResultSet)
}

}
