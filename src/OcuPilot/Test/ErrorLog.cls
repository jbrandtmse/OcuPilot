/// <p>The application error log at the port's own API (AD-48), driven against the entries this
/// instance already holds -- the installer's own <code>SeedApplicationError</code> puts one in on
/// every start, so every read here has a subject without anything being written.</p>
/// <p><b>Read-only throughout.</b> Nothing here creates, modifies or deletes an application error,
/// writes to <code>^ERRORS</code>, or creates a user, role or resource. The one class that seeds an
/// entry is <class>OcuPilot.Test.ErrorLogSeed</class>, on a throwaway container; the three denial
/// rows are <class>OcuPilot.Test.ErrorLogDenial</class>'s, over the wire with real principals.</p>
/// <p>Every branch a live read cannot reach -- a denied gate, a namespace whose resource resolves
/// to nothing, a source key outside the enum -- is driven through
/// <class>OcuPilot.Test.ErrorLogFixture</class>'s seams, and the fixture's per-query counters are
/// what make "no query ran" and "the detail was never read" observations rather than assertions
/// against nothing.</p>
Class OcuPilot.Test.ErrorLog Extends %UnitTest.TestCase
{

/// <p>The port under test: the fixture, so its seams and counters are available. Every method it
/// does not override is the production port's.</p>
Parameter PORT = "OcuPilot.Test.ErrorLogFixture";

/// <p>The production port, for the legs that must not run through a subclass.</p>
Parameter PRODUCTIONPORT = "OcuPilot.Port.LogSourcePort";

/// <p>The gate the denial legs drive, whose held set this class declares.</p>
Parameter GATE = "OcuPilot.Test.ScreenGate";

/// <p>The resolver whose <code>GlobalDatabase</code> answers 0 for every namespace.</p>
Parameter NORESOURCERESOLVER = "OcuPilot.Test.ErrorNamespaceResolver";

/// <p>The first pair every level requires, whatever the namespace -- the one a caller holding
/// nothing is named.</p>
Parameter OPERATEPAIR = "%Admin_Operate:USE";

/// <p>The second: the database <code>SYS.ApplicationError</code> is executed from. Database READ is
/// routine-execution permission, so a caller without it cannot run the query at all, and the gate
/// names the pair rather than letting a &lt;PROTECT&gt; surface as a 500 (AD-29).</p>
Parameter SYSPAIR = "%DB_IRISSYS:READ";

/// <p>A namespace this instance certainly has no application errors for, and no namespace at all:
/// the enumeration is what decides, not the name's plausibility.</p>
Parameter UNKNOWNNAMESPACE = "OCUPILOTNOSUCHNS";

/// <p>The namespace this class reads. It is not assumed to hold errors -- every leg takes it from
/// the instance's own <code>NamespaceList</code> and asserts it found one.</p>
Property PreparedNamespace As %String;

/// <p>The newest date that namespace holds errors for, taken from the instance.</p>
Property PreparedDate As %String;

/// <p>The highest error number on that date.</p>
Property PreparedNumber As %String;

/// <p>The resource guarding <property>PreparedNamespace</property>'s globals database.</p>
Property PreparedResource As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedNamespace = ""
    Set ..PreparedDate = ""
    Set ..PreparedNumber = ""
    Set ..PreparedResource = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>Call the production port. Returned as the triple every caller reads.</p>
ClassMethod Read(pLevel As %String, pNamespace As %String = "", pDate As %String = "", pNumber As %String = "", pMaxRows As %String = "", Output pResult As %DynamicObject, Output pStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#PRODUCTIONPORT, "Errors", pLevel, pNamespace, pDate, pNumber, pMaxRows, .pResult, .pStatus, .pFault)
}

/// <p>Call the fixture port, whose counters and seams a leg has armed.</p>
ClassMethod ReadFixture(pLevel As %String, pNamespace As %String = "", pDate As %String = "", pNumber As %String = "", pMaxRows As %String = "", Output pResult As %DynamicObject, Output pStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#PORT, "Errors", pLevel, pNamespace, pDate, pNumber, pMaxRows, .pResult, .pStatus, .pFault)
}

/// <p>The fault's <code>code</code>, or <code>""</code> when there is no fault object.</p>
ClassMethod CodeOf(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p>The fault's <code>detail.failedPair</code>, or <code>""</code>.</p>
ClassMethod FailedPairOf(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.detail) Quit ""
    Quit pFault.detail.failedPair
}

/// <p>Resolve a namespace, its newest date and that date's highest error number from the
/// instance's own enumerations, so no leg hard-codes one. <code>""</code> in
/// <property>PreparedNamespace</property> means this instance holds no application errors at all,
/// which every leg that needs one asserts against rather than passing quietly.</p>
/// <p><b>A namespace whose globals database is not IRISSYS is preferred</b> where the instance
/// offers one. <code>%SYS</code> records errors too and its globals resource <i>is</i>
/// <parameter>SYSPAIR</parameter>'s, so a caller holding the instance pairs already holds that
/// namespace's READ -- and the denial leg's "the database pair is what is named" would be naming
/// the pair the caller was just granted rather than the namespace's own.</p>
Method Prepare() As %Boolean
{
    If ..PreparedNamespace '= "" Quit 1
    Set tSC = ..Read("namespaces", "", "", "", "", .tNamespaces, .tStatus, .tFault)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit 0
    If tNamespaces.rows.%Size() = 0 Quit 0
    Set tSysResource = $Piece(..#SYSPAIR, ":", 1)
    Set tIterator = tNamespaces.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        ; A namespace already chosen, and this one is no better: nothing to reconsider.
        If (..PreparedNamespace '= "") && (..PreparedResource '= tSysResource) Continue
        Do ##class(OcuPilot.Api.Namespaces).GlobalDatabase(tRow.namespace, .tResource, .tReadOnly)
        If (..PreparedNamespace '= "") && (tResource = tSysResource) Continue
        Set tSC = ..Read("dates", tRow.namespace, "", "", "", .tDates, .tDateStatus, .tFault)
        If $$$ISERR(tSC) || (tDateStatus '= 200) Continue
        If tDates.rows.%Size() = 0 Continue
        Set tSC = ..Read("list", tRow.namespace, tDates.rows.%Get(0).date, "", "1", .tErrors, .tListStatus, .tFault)
        If $$$ISERR(tSC) || (tListStatus '= 200) Continue
        If tErrors.rows.%Size() = 0 Continue
        Set ..PreparedNamespace = tRow.namespace
        Set ..PreparedResource = tResource
        Set ..PreparedDate = tDates.rows.%Get(0).date
        Set ..PreparedNumber = tErrors.rows.%Get(0).errorNumber
    }
    Quit ..PreparedNamespace '= ""
}

/// <p>AC1 -- every value a level answers comes from <code>SYS.ApplicationError</code>'s own
/// queries, and from no other reading of <code>^ERRORS</code>. The witness is the fixture's
/// per-query counter: each level executes exactly the queries the port declares for it, and a
/// projection that read the global directly would answer the same values with the counter at
/// zero.</p>
/// <p>Mutation: read the projection's values from a <code>^ERRORS</code> node instead of the
/// query's row -&gt; the counter assertions go red while the values stay correct, which the value
/// assertions alone could not see.</p>
Method TestEveryValueComesFromTheSupportedQueries()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read: " _ ..PreparedNamespace _ " " _ ..PreparedDate)
    If ..PreparedNamespace = "" Quit

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("namespaces", "", "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespaces level answers")
    Do $$$AssertEquals(tStatus, 200, "with 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("NamespaceList"), 1, "through one NamespaceList execution")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Queries(), 1, "and no other query at all")

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tDates, .tDateStatus, .tFault)
    Do $$$AssertEquals(tDateStatus, 200, "the dates level answers")
    Do $$$AssertTrue(tDates.rows.%Size() > 0, "with the namespace's dates: " _ tDates.rows.%Size())
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 1, "through one DateList execution")

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("list", ..PreparedNamespace, ..PreparedDate, "", "", .tErrors, .tListStatus, .tFault)
    Do $$$AssertEquals(tListStatus, 200, "the list level answers")
    Do $$$AssertTrue(tErrors.rows.%Size() > 0, "with the date's errors: " _ tErrors.rows.%Size())
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 1, "after the DateList the date is tested against")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("ErrorList"), 1, "through one ErrorList execution")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("ErrorDetail"), 0, "and no ErrorDetail")
}

/// <p>AC1 -- the summary projection's own rule, over a corpus rather than over whatever the
/// instance happens to hold: the routine is the first whitespace-delimited token after the first
/// <code>^</code> in the error text, and an entry that carries no caret -- the
/// <code>&lt;LOG ENTRY&gt;</code> placeholder a <code>Throw</code> leaves behind -- has no routine
/// rather than a fabricated one.</p>
/// <p><b>The corpus is where the payload cases live, and it is the half that can move.</b>
/// <code>$ZError</code> appends a payload after the routine on several error classes, so "the
/// routine" and "the caret tail" are different strings on real rows: 45 of the 158 rows on three
/// dates of this instance's own log carry one. The live sweep below cannot see that -- it compares
/// the projection against the same derivation -- so the cases are asserted here against literals
/// taken from the instance.</p>
/// <p>Mutations: return the whole caret tail (<code>$Piece(text, "^", 2, *)</code>) -&gt; the
/// <code>&lt;THROW&gt;</code> and <code>&lt;UNDEFINED&gt;</code> cases go red while the live sweep
/// stays green; project <code>routine</code> from the <code>Code line</code> column instead
/// -&gt; the live sweep goes red on the first row whose routine is not its own text's token.</p>
Method TestAnAbsentRoutineIsEmptyRatherThanFabricated()
{
    Set tPort = ..#PRODUCTIONPORT
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1"), "OcuPilot.Install.Fixture.1", "a routine after the caret is the routine")
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<LOG ENTRY>"), "", "the placeholder a Throw leaves behind names no routine")
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", ""), "", "and neither does an empty text")
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<OCUPILOTDEMO>OcuPilot demo fixture"), "", "nor a text with no caret in it")

    ; The payload cases, verbatim from this instance's own log. A routine name carries no space, so
    ; everything from the first one on belongs to errorText -- which already carries it.
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<THROW>OnTask+1^OcuPilot.Install.DemoTask.1 *%Exception.StatusException ERROR #5001: OcuPilot demo task: this task always fails by design, to demonstrate a task suspended after an error."), "OcuPilot.Install.DemoTask.1", "a THROW's exception payload is not part of the routine")
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<UNDEFINED>zRun+12^OcuPilot.Api.Router.1 *tMissing"), "OcuPilot.Api.Router.1", "nor is an UNDEFINED's variable name")
    Do $$$AssertEquals($ClassMethod(tPort, "RoutineOf", "<PROTECT>zRun+3^OcuPilot.Api.Router.1 ^[""^^/durable/""]ERRORS"), "OcuPilot.Api.Router.1", "nor a PROTECT's global reference, which carries a second caret")

    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Read("list", ..PreparedNamespace, ..PreparedDate, "", "", .tErrors, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the date's errors answer")
    If tStatus '= 200 Quit
    Set tBad = ""
    Set tIterator = tErrors.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tExpected = $ClassMethod(tPort, "RoutineOf", tRow.errorText)
        If tRow.routine '= tExpected Set tBad = "row " _ tIndex _ " reads '" _ tRow.routine _ "' for '" _ tRow.errorText _ "'"
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row's routine is its own error text's tail, on " _ tErrors.rows.%Size() _ " rows")
}

/// <p>AC2 -- the caller's namespace is restored on the error path as well as the success path, and
/// a refusal raised while the port was in <code>%SYS</code> still arrives as one envelope rather
/// than as <code>&lt;CLASS DOES NOT EXIST&gt;</code>, because the fault is built after the
/// restore.</p>
/// <p>Mutation: delete the restore that follows
/// <method>OcuPilot.Port.LogSourcePort.ErrorsRead</method>'s <code>Try</code>/<code>Catch</code>
/// block -&gt; this goes red with <code>&lt;CLASS DOES NOT EXIST&gt;</code>, the trap itself, on the
/// first leg. <b>Not the <code>Catch</code>'s own restore</b>: every helper that method calls
/// catches internally and answers a <code>%Status</code>, so nothing propagates to that
/// <code>Catch</code> and deleting its restore leaves this class green -- applied and observed. The
/// <code>Catch</code> line is AD-16's belt-and-braces for a raise from the method's own body, and
/// this class is not the witness for it.</p>
Method TestTheNamespaceIsRestoredOnTheErrorPath()
{
    Set tBefore = $NAMESPACE
    Set tSC = ..Read("dates", ..#UNKNOWNNAMESPACE, "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals($NAMESPACE, tBefore, "the caller's namespace is what it was before a refused read")
    Do $$$AssertEquals(tStatus, 404, "and the refusal is an ordinary status")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.NAMESPACE", "carrying the level's own code")

    ; A failure raised INSIDE the window: the detail query is pointed at a query name the vendor
    ; class does not carry, so the result set will not construct.
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetDetailQuery("NoSuchQuery")
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..ReadFixture("detail", ..PreparedNamespace, ..PreparedDate, ..PreparedNumber, "", .tDetail, .tDetailStatus, .tDetailFault)
    Do $$$AssertEquals($NAMESPACE, tBefore, "the caller's namespace is restored after a failure raised inside the %SYS window")
    Do $$$AssertStatusNotOK(tSC, "which is reported as an error status")
    Do $$$AssertEquals(tDetailStatus, 500, "as the one generic internal status")
    Do $$$AssertEquals(..CodeOf(tDetailFault), "INTERNAL", "and the one generic code, built after the restore")
}

/// <p>AC5 -- the secrecy witness. The summary path never executes <code>ErrorDetail</code>, not
/// even to fill <code>routine</code> and <code>line</code>: the counter reads 0 across the
/// namespaces, dates and list levels and non-zero only on the detail level.</p>
/// <p>Mutation: fill <code>routine</code> and <code>line</code> from <code>ErrorDetail</code> at
/// <code>Type = 0</code> -&gt; the counter reads non-zero on the list level and this goes red while
/// the rendered values stay correct.</p>
Method TestTheSummaryPathNeverReadsTheDetail()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit

    For tLevel = "namespaces", "dates", "list" {
        Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
        Set tSC = ..ReadFixture(tLevel, ..PreparedNamespace, ..PreparedDate, "", "", .tResult, .tStatus, .tFault)
        Do $$$AssertEquals(tStatus, 200, tLevel _ ": answers")
        Do $$$AssertTrue(##class(OcuPilot.Test.ErrorLogFixture).Queries() > 0, tLevel _ ": through the supported queries")
        Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Details(), 0, tLevel _ ": and never through ErrorDetail")
    }

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("detail", ..PreparedNamespace, ..PreparedDate, ..PreparedNumber, "", .tDetail, .tDetailStatus, .tFault)
    Do $$$AssertEquals(tDetailStatus, 200, "the detail level answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Details(), 3, "and is the only path that reads ErrorDetail, once per Type")
}

/// <p>AC5 -- what the detail level answers: the three sections the vendor defines for this shape,
/// read at <code>Type</code> 0, -1 and -2 with the caller naming no <code>Type</code> of its
/// own.</p>
/// <p>Mutation: drop the variables section from
/// <method>OcuPilot.Port.LogSourcePort.DetailPayload</method> -&gt; the section's own assertion goes
/// red, and so does the detail counter above, which expects three executions.</p>
Method TestTheDetailCarriesTheThreeCapturedSections()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Read("detail", ..PreparedNamespace, ..PreparedDate, ..PreparedNumber, "", .tDetail, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the detail level answers")
    If tStatus '= 200 Quit
    Set tKeys = []
    Set tIterator = tDetail.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""expressions"",""stack"",""variables"",""truncated""]", "with the four declared keys, in order: " _ tKeys.%ToJSON())
    Do $$$AssertTrue(tDetail.expressions.%Size() > 0, "the logged expressions: " _ tDetail.expressions.%Size())
    Do $$$AssertTrue(tDetail.stack.%Size() > 0, "the stack levels: " _ tDetail.stack.%Size())
    Do $$$AssertTrue(tDetail.variables.%Size() > 0, "and every local at every level: " _ tDetail.variables.%Size())
    Do $$$AssertEquals(tDetail.expressions.%Get(0).%IsDefined("expression"), 1, "an expression row names its expression")
    Do $$$AssertEquals(tDetail.variables.%Get(0).%IsDefined("name"), 1, "a variable row names the variable")
}

/// <p>AC6 -- no query runs before the gate. At the namespaces level a refused caller executes
/// nothing at all; at a per-namespace level it executes the enumeration the namespace is chosen
/// from and <b>nothing scoped to that namespace</b>.</p>
/// <p>Mutation: move the gate below the date query -&gt; the DateList counter reads 1 where it must
/// read 0, and this goes red on the counter alone.</p>
Method TestNoQueryRunsBeforeTheGate()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    ; The resource guarding that namespace's globals database, resolved the way the port resolves
    ; it rather than spelled here: it is %DB_HSCUSTOM for HSCUSTOM and %DB_IRISSYS for %SYS, so a
    ; literal would pin one instance's namespace roster into this test.
    Set tResource = ..PreparedResource
    Do $$$AssertNotEquals(tResource, "", "the namespace's globals database names a guarding resource: " _ tResource)
    If tResource = "" Quit
    Do $$$AssertNotEquals(tResource _ ":READ", ..#SYSPAIR, "and it is not the system database's own, so the pair named below is the namespace's rather than one the caller was already granted")
    If (tResource _ ":READ") = ..#SYSPAIR Quit

    Do ##class(OcuPilot.Test.ErrorLogFixture).SetGateClass(..#GATE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("namespaces", "", "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 403, "a caller holding nothing is refused the namespaces level")
    Do $$$AssertEquals(..CodeOf(tFault), "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals(..FailedPairOf(tFault), ..#OPERATEPAIR, "naming the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Queries(), 0, "and no query ran at all")

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tDates, .tDateStatus, .tDateFault)
    Do $$$AssertEquals(tDateStatus, 403, "and the dates level too")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 0, "with no query scoped to the namespace")

    ; Holding the operate pair alone: still refused, and on the system-database pair, which is the
    ; one IRIS itself would otherwise refuse inside the %SYS window as a 500 naming nothing.
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("namespaces", "", "", "", "", .tSysResult, .tSysStatus, .tSysFault)
    Do $$$AssertEquals(tSysStatus, 403, "the operate pair alone does not open the enumeration either")
    Do $$$AssertEquals(..FailedPairOf(tSysFault), ..#SYSPAIR, "and the database the query runs from is what is named")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Queries(), 0, "with no query run")

    ; Both instance pairs: the enumeration runs, the per-namespace set still refuses.
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tDates2, .tDateStatus2, .tDateFault2)
    Do $$$AssertEquals(tDateStatus2, 403, "the instance pairs alone do not open a namespace")
    Do $$$AssertEquals(..FailedPairOf(tDateFault2), tResource _ ":READ", "and the database pair is what is named")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("NamespaceList"), 1, "the enumeration the namespace is chosen from did run")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 0, "and still nothing scoped to the namespace")

    ; READ but not WRITE: the pair order is fixed, so WRITE is what is named next.
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "READ")
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tDates3, .tDateStatus3, .tDateFault3)
    Do $$$AssertEquals(tDateStatus3, 403, "read alone does not open it either")
    Do $$$AssertEquals(..FailedPairOf(tDateFault3), tResource _ ":WRITE", "and the write pair is named, in the order the set declares")

    ; The whole set: served.
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "WRITE")
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tDates4, .tDateStatus4, .tDateFault4)
    Do $$$AssertEquals(tDateStatus4, 200, "the whole set is served")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 1, "and only then does the namespace's own query run")
}

/// <p>AC6 -- a namespace whose globals database reports no guarding resource is <b>refused</b>,
/// never admitted on an empty pair set. An empty set is held by everyone
/// (<method>OcuPilot.Screen.Gate.EvaluatePairs</method>), so handing one to the gate would open the
/// namespace to every caller.</p>
/// <p>Mutation: map the resolver's 0 answer to an empty pair set instead of a refusal -&gt; the
/// read is served and every assertion here goes red.</p>
Method TestAnUnresolvableResourceIsRefusedNotAdmitted()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit

    Do ##class(OcuPilot.Test.ErrorLogFixture).SetNamespaceResolver(..#NORESOURCERESOLVER)
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 403, "a namespace whose resource cannot be resolved is refused")
    Do $$$AssertEquals(..CodeOf(tFault), "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals(..FailedPairOf(tFault), "", "with no pair named, because there is none to name")
    Do $$$AssertEquals($IsObject(tResult), 0, "and no rows come back with it")

    ; The same shape reached the other way: an armed empty pair set.
    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetErrorPairs("")
    Set tSC = ..ReadFixture("dates", ..PreparedNamespace, "", "", "", .tResult2, .tStatus2, .tFault2)
    Do $$$AssertEquals(tStatus2, 403, "an empty declared pair set is refused rather than handed to the gate")
    Do $$$AssertEquals(..FailedPairOf(tFault2), "", "with no pair named")
}

/// <p>AC7 -- a namespace the instance's own enumeration does not answer with is refused before any
/// query scoped to it runs, and the caller's string never reaches one.</p>
/// <p>Mutation: pass the namespace to <code>DateList</code> without finding it in
/// <code>NamespaceList</code> first -&gt; the status is 200 rather than 404 and the DateList counter
/// reads 1 where it must read 0.</p>
Method TestAnUnknownNamespaceIsRefusedBeforeAnyQuery()
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("dates", ..#UNKNOWNNAMESPACE, "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 404, "an unknown namespace is refused")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.NAMESPACE", "on the level's own code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("NamespaceList"), 1, "after the one enumeration it is tested against")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("DateList"), 0, "and before any query scoped to it")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).QueriesNamed("ErrorList"), 0, "or to anything below it")

    ; The empty string is not a namespace either, and is refused the same way.
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("list", "", "", "", "", .tResult2, .tStatus2, .tFault2)
    Do $$$AssertEquals(tStatus2, 404, "and so is no namespace at all")
    Do $$$AssertEquals(..CodeOf(tFault2), "LOG.NAMESPACE", "on the same code")
}

/// <p>AC7 -- the date is the string <code>DateList</code> emitted, byte for byte. A date the
/// instance itself gave answers rows; the same day written any other way is a named refusal, not an
/// empty table.</p>
/// <p>Mutation: reformat the date to ISO before it reaches <code>ErrorList</code> -&gt; the verbatim
/// leg answers zero rows and goes red.</p>
Method TestTheDateRoundTripsVerbatim()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit

    Set tSC = ..Read("list", ..PreparedNamespace, ..PreparedDate, "", "", .tErrors, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the date the instance emitted is served")
    Do $$$AssertEquals(tErrors.date, ..PreparedDate, "and is echoed back unchanged: " _ tErrors.date)
    Do $$$AssertTrue(tErrors.rows.%Size() > 0, "with the date's own rows: " _ tErrors.rows.%Size())

    ; The same calendar day in ISO, which is what a client that computed one would send.
    Set tIso = $Piece(..PreparedDate, "/", 3) _ "-" _ $Piece(..PreparedDate, "/", 1) _ "-" _ $Piece(..PreparedDate, "/", 2)
    Do $$$AssertNotEquals(tIso, ..PreparedDate, "the two spellings differ, so the comparison means something: " _ tIso)
    Set tSC = ..Read("list", ..PreparedNamespace, tIso, "", "", .tIsoResult, .tIsoStatus, .tIsoFault)
    Do $$$AssertEquals(tIsoStatus, 404, "a date the instance did not emit is refused")
    Do $$$AssertEquals(..CodeOf(tIsoFault), "LOG.DATE", "on the date level's own code, rather than answered as an empty table")
}

/// <p>AC7 -- a stale error number, one <code>ErrorList</code> does not answer with for that
/// namespace and date, is a named refusal before the detail query runs.</p>
/// <p>Mutation: drop the membership check -&gt; the detail query runs for an entry that is not there
/// and answers 200 with three empty sections.</p>
Method TestAStaleErrorIsANamedRefusal()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("detail", ..PreparedNamespace, ..PreparedDate, "999999999", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 404, "an error number the date does not carry is refused")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.ENTRY", "on the entry level's own code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Details(), 0, "before the detail query ran")
}

/// <p>AC7 -- the cap. Absent means the default, a whole number above zero is honoured with no
/// ceiling, and anything else is refused 400 <code>LOG.MAXROWS</code> rather than silently
/// defaulted. The refusal cannot be passing because the cap is a ceiling: a value far above any
/// plausible one is served.</p>
/// <p>Mutation: default a bad <code>maxRows</code> instead of refusing it -&gt; every refusal leg
/// goes red while the served legs stay green.</p>
Method TestABadMaxRowsIsRefusedNotDefaulted()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit

    For tBad = "0", "-1", "01", "1.5", "abc", "+1", " 1" {
        Set tSC = ..Read("dates", ..PreparedNamespace, "", "", tBad, .tResult, .tStatus, .tFault)
        Do $$$AssertEquals(tStatus, 400, "maxRows '" _ tBad _ "': is refused")
        Do $$$AssertEquals(..CodeOf(tFault), "LOG.MAXROWS", "maxRows '" _ tBad _ "': on LOG.MAXROWS")
        Do $$$AssertEquals($IsObject(tResult), 0, "maxRows '" _ tBad _ "': and no rows come back with it")
    }

    Set tSC = ..Read("dates", ..PreparedNamespace, "", "", "", .tDefault, .tDefaultStatus, .tFault)
    Do $$$AssertEquals(tDefaultStatus, 200, "an absent maxRows is served")
    Do $$$AssertTrue(tDefault.rows.%Size() > 0, "with rows: " _ tDefault.rows.%Size())

    Set tSC = ..Read("dates", ..PreparedNamespace, "", "", "100000000", .tHuge, .tHugeStatus, .tFault)
    Do $$$AssertEquals(tHugeStatus, 200, "and a value far above any plausible cap is honoured, because there is no ceiling")
    Do $$$AssertEquals(tHuge.rows.%ToJSON(), tDefault.rows.%ToJSON(), "answering the same rows the default did")

    Set tSC = ..Read("list", ..PreparedNamespace, ..PreparedDate, "", "1", .tOne, .tOneStatus, .tFault)
    Do $$$AssertEquals(tOneStatus, 200, "a cap of one is served")
    Do $$$AssertEquals(tOne.rows.%Size(), 1, "one row")
    Do $$$AssertEquals(tOne.truncated, 1, "and reports that it truncated")
}

/// <p>AC1 -- a source key outside the port's fixed enum, and a level outside its fixed level enum,
/// are each refused 404 <code>LOG.SOURCE</code> before the gate and before any query. This story is
/// the first caller that can reach that code.</p>
/// <p>Mutation: delete either enum check -&gt; the refused call proceeds and the status and counter
/// assertions go red.</p>
Method TestAnUnknownSourceOrLevelIsRefusedBeforeTheGate()
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetSources("messages")
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("namespaces", "", "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 404, "a source key the enum does not carry is refused")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.SOURCE", "on LOG.SOURCE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Queries(), 0, "before any query ran")

    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ..ReadFixture("nosuchlevel", "", "", "", "", .tResult2, .tStatus2, .tFault2)
    Do $$$AssertEquals(tStatus2, 404, "and so is a level the enum does not carry")
    Do $$$AssertEquals(..CodeOf(tFault2), "LOG.SOURCE", "on the same code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Queries(), 0, "also before any query ran")
}

/// <p>AC1 -- the file entry point does not serve this source. <method>Page</method> reads the same
/// fixed enum, so the key is admitted there; it has no file behind it, and the requirement it
/// carries is a function of a namespace <method>Page</method> never names, so it is refused rather
/// than served a page.</p>
/// <p>Mutation: give the application error key a file name in
/// <method>OcuPilot.Port.LogSourcePort.FileFor</method> -&gt; <method>Page</method> resolves a path
/// for it and this goes red.</p>
Method TestThePageEntryPointDoesNotServeTheErrorSource()
{
    Set tSC = $ClassMethod(..#PRODUCTIONPORT, "Page", "applicationerrors", "", "", "", .tResult, .tStatus, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the file entry point refuses the application error source")
    Do $$$AssertEquals(tStatus, 403, "with the refusal an unresolvable requirement produces")
    Do $$$AssertEquals(..CodeOf(tFault), "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($IsObject(tResult), 0, "and no page comes back with it")
}

/// <p>AC3, AC7 -- the namespaces level answers only namespaces that actually hold errors, and the
/// dates level answers newest first, which is what makes "the first N rows" the right page one.</p>
/// <p><b>The ordering is asserted as a sweep over every row, not as row 0 against a remembered row
/// 0.</b> <property>PreparedDate</property> is itself taken from row 0 of an identical earlier
/// call, so comparing the two says only that one query answers twice the same -- it is true of any
/// ordering at all, reversed included. The sweep below compares each row against the one before it,
/// which is the same shape the error-number half already uses.</p>
/// <p>The sweep needs two dates to bite, and it is not asserted that there are two: a fresh install
/// has faulted on one day only, and a hard precondition here would fail every throwaway. The
/// development instance carries several days of history, which is where the mutation below was
/// applied and observed; the message reports how many dates it actually compared, so a run that
/// compared one is visible rather than silent.</p>
/// <p>Mutation: answer the dates in the query's reverse order -&gt; the ordering sweep goes red on
/// the second row ("newest date first over every row, on 5 dates"); the row-0 equality above stays
/// green, which is what says it was never the witness.</p>
Method TestTheEnumerationsAreTheInstancesOwn()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit

    Set tSC = ..Read("namespaces", "", "", "", "", .tNamespaces, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the namespaces level answers")
    Do $$$AssertTrue(tNamespaces.rows.%Size() > 0, "with at least one namespace: " _ tNamespaces.rows.%Size())
    Set tFound = 0
    Set tIterator = tNamespaces.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.namespace = ..PreparedNamespace Set tFound = 1
    }
    Do $$$AssertEquals(tFound, 1, "including the one this class read errors from")

    Set tSC = ..Read("dates", ..PreparedNamespace, "", "", "", .tDates, .tDateStatus, .tFault)
    Do $$$AssertEquals(tDateStatus, 200, "the dates level answers")
    Do $$$AssertEquals(tDates.namespace, ..PreparedNamespace, "echoing the namespace it was asked for")
    Do $$$AssertEquals(tDates.rows.%Get(0).date, ..PreparedDate, "newest first, which is the page a cap should serve")
    Do $$$AssertTrue(tDates.rows.%Get(0).count > 0, "each date with its own count: " _ tDates.rows.%Get(0).count)
    ; Every row against the one before it. The dates are MM/DD/YYYY in the instance's clock, so
    ; they are compared as $Horolog day numbers rather than as strings, which would sort 09/10 above
    ; 09/9 and read a correct order as broken.
    Set tPreviousDay = ""
    Set tOutOfOrder = ""
    Set tDateIterator = tDates.rows.%GetIterator()
    While tDateIterator.%GetNext(.tIndex, .tDateRow) {
        Set tDay = $ZDateH(tDateRow.date, 1)
        If (tPreviousDay '= "") && (tDay > tPreviousDay) Set tOutOfOrder = "row " _ tIndex _ " (" _ tDateRow.date _ ") follows " _ $ZDate(tPreviousDay, 1)
        Set tPreviousDay = tDay
        If tOutOfOrder '= "" Quit
    }
    Do $$$AssertEquals(tOutOfOrder, "", "newest date first over every row, on " _ tDates.rows.%Size() _ " dates")

    Set tSC = ..Read("list", ..PreparedNamespace, ..PreparedDate, "", "", .tErrors, .tListStatus, .tFault)
    Do $$$AssertEquals(tListStatus, 200, "the list level answers")
    Set tPrevious = ""
    Set tBad = ""
    Set tRowIterator = tErrors.rows.%GetIterator()
    While tRowIterator.%GetNext(.tIndex, .tRow) {
        If (tPrevious '= "") && (tRow.errorNumber > tPrevious) Set tBad = "row " _ tIndex _ " (" _ tRow.errorNumber _ ") follows " _ tPrevious
        Set tPrevious = tRow.errorNumber
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "highest error number first, over " _ tErrors.rows.%Size() _ " rows")
}

/// <p>AC5 -- the row shape both callers see: the list route's seven fields, of which the read tool
/// publishes five. A field outside the seven would reach the screen; a field outside the five would
/// reach the model.</p>
/// <p>Mutation: add <code>username</code> to
/// <parameter>OcuPilot.Screen.Tool.ErrorRead.SUMMARYFIELDS</parameter> -&gt; the tool's key-set
/// assertion goes red while the screen's stays green.</p>
Method TestTheRowShapesAreTheDeclaredOnes()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Read("list", ..PreparedNamespace, ..PreparedDate, "", "1", .tErrors, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the list level answers")
    If tStatus '= 200 Quit
    Set tKeys = []
    Set tIterator = tErrors.rows.%Get(0).%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""errorNumber"",""time"",""errorText"",""routine"",""line"",""username"",""process""]", "the screen's seven fields, in order: " _ tKeys.%ToJSON())
}

}
