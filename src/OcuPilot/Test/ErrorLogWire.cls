/// <p>The application error log over the wire: the four drill levels through the real
/// <code>/api/ocupilot</code> application, as the configured test principal
/// (<class>OcuPilot.Test.Http</class>).</p>
/// <p><b>Read-only against the live instance.</b> Nothing here creates, modifies or deletes an
/// application error, and nothing writes to <code>^ERRORS</code>. The instance already holds
/// readable entries -- the installer's own <code>SeedApplicationError</code> keeps one present after
/// every start -- so every leg has a subject without anything being written. The one seeding class is
/// <class>OcuPilot.Test.ErrorLogSeed</class>, on a throwaway container.</p>
/// <p>Needs the API application installed, the test principal's password, that principal holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> plus read and write on the
/// target namespace's globals database, and at least one recorded application error -- which the
/// legs that depend on it assert for themselves rather than assuming.</p>
Class OcuPilot.Test.ErrorLogWire Extends %UnitTest.TestCase
{

/// <p>The namespaces level's route, spelled once. It is literal, so
/// <file>scripts/check-objectscript.py</file>'s handler-wire-test rule keys the route by this path
/// and requires a test class naming it verbatim.</p>
Parameter NAMESPACESPATH = "/api/ocupilot/logs/errors/namespaces";

/// <p>The dates level's route -- see <parameter>NAMESPACESPATH</parameter>.</p>
Parameter DATESPATH = "/api/ocupilot/logs/errors/dates";

/// <p>The errors level's route -- see <parameter>NAMESPACESPATH</parameter>.</p>
Parameter LISTPATH = "/api/ocupilot/logs/errors/list";

/// <p>The detail level's route, and the one path the captured variable table is reachable from
/// (AD-48) -- see <parameter>NAMESPACESPATH</parameter>.</p>
Parameter DETAILPATH = "/api/ocupilot/logs/errors/detail";

/// <p>The namespace this class reads, taken from the instance's own enumeration in
/// <method>Prepare</method>.</p>
Property PreparedNamespace As %String;

/// <p>A second namespace that also holds errors, or <code>""</code> when this instance records
/// them for only one. It is what the route-scope leg sends as <code>?ns=</code>, so a handler that
/// read that parameter would answer a different namespace's rows.</p>
Property PreparedOtherNamespace As %String;

/// <p>The newest date <property>PreparedNamespace</property> holds errors for.</p>
Property PreparedDate As %String;

/// <p>How many dates <property>PreparedNamespace</property> holds, which is what
/// <method>Prepare</method> maximises and what says whether the ordering sweeps had rows to
/// compare. The name must not begin with <code>Test</code>: the compiler's datatype helpers would
/// be discovered as test methods.</p>
Property PreparedDateCount As %Integer [ InitialExpression = 0 ];

/// <p>The highest error number on that date.</p>
Property PreparedNumber As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedNamespace = ""
    Set ..PreparedOtherNamespace = ""
    Set ..PreparedDate = ""
    Set ..PreparedDateCount = 0
    Set ..PreparedNumber = ""
    Quit $$$OK
}

/// <p>Request <var>pPath</var> with <var>pQuery</var> (a query string, or <code>""</code>) as the
/// configured test principal.</p>
Method Fetch(pPath As %String, pQuery As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tPath = pPath
    If pQuery '= "" Set tPath = tPath _ "?" _ pQuery
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders)
}

/// <p>Resolve a namespace, a second namespace, a date and an error number from the instance's own
/// answers, so no leg hard-codes one. <code>0</code> means this instance records no application
/// errors at all, which every leg that needs one asserts against rather than passing quietly.</p>
/// <p><property>PreparedOtherNamespace</property> is a second namespace that holds errors where
/// there is one -- the strongest subject for the route-scope leg, because a steered read would
/// answer real, different rows -- and otherwise any other namespace the caller may enter, where a
/// steered read would answer a 404 instead. Either way the leg's own assertions distinguish it.</p>
/// <p><b>A namespace holding more than one date wins.</b> The ordering sweeps compare each row with
/// the one before it, so a namespace with a single date gives them nothing to compare and a
/// reordering at the port would ship green -- measured: this instance's first namespace by
/// enumeration order holds one date while its second holds five, so taking the first would make
/// both sweeps vacuous here. <property>PreparedDateCount</property> records what was actually
/// chosen, and the sweeps report it.</p>
Method Prepare() As %Boolean
{
    If ..PreparedNamespace '= "" Quit 1
    Set tSC = ..Fetch(..#NAMESPACESPATH, "", .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit 0
    Set tNamespaces = ##class(%DynamicObject).%FromJSON(tBody)
    Set tIterator = tNamespaces.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tDateSC = ..Fetch(..#DATESPATH, "namespace=" _ $ZConvert(tRow.namespace, "O", "URL"), .tDateStatus, .tDateBody, .tDateHeaders)
        If $$$ISERR(tDateSC) || (tDateStatus '= 200) Continue
        Set tDates = ##class(%DynamicObject).%FromJSON(tDateBody)
        If tDates.rows.%Size() = 0 Continue
        ; A namespace already chosen, and this one carries no more dates than it: nothing to gain.
        If (..PreparedNamespace '= "") && (tDates.rows.%Size() <= ..PreparedDateCount) && (..PreparedOtherNamespace '= "") Continue
        Set tDate = tDates.rows.%Get(0).date
        Set tListSC = ..Fetch(..#LISTPATH, "namespace=" _ $ZConvert(tRow.namespace, "O", "URL") _ "&date=" _ $ZConvert(tDate, "O", "URL") _ "&maxRows=1", .tListStatus, .tListBody, .tListHeaders)
        If $$$ISERR(tListSC) || (tListStatus '= 200) Continue
        Set tErrors = ##class(%DynamicObject).%FromJSON(tListBody)
        If tErrors.rows.%Size() = 0 Continue
        If (..PreparedNamespace = "") || (tDates.rows.%Size() > ..PreparedDateCount) {
            ; The namespace being displaced is still a second namespace that holds errors, which is
            ; the route-scope leg's strongest subject.
            If (..PreparedNamespace '= "") && (..PreparedOtherNamespace = "") Set ..PreparedOtherNamespace = ..PreparedNamespace
            Set ..PreparedNamespace = tRow.namespace
            Set ..PreparedDate = tDate
            Set ..PreparedDateCount = tDates.rows.%Size()
            Set ..PreparedNumber = tErrors.rows.%Get(0).errorNumber
        } ElseIf ..PreparedOtherNamespace = "" {
            Set ..PreparedOtherNamespace = tRow.namespace
        }
    }
    If (..PreparedNamespace '= "") && (..PreparedOtherNamespace = "") {
        Set ..PreparedOtherNamespace = ..AnyOtherNamespace(..PreparedNamespace)
    }
    Quit ..PreparedNamespace '= ""
}

/// <p>A namespace this caller may enter that is not <var>pExcept</var>, from the shell's own
/// namespace roster, or <code>""</code> when the instance offers only one.</p>
Method AnyOtherNamespace(pExcept As %String) As %String
{
    Set tFound = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/namespaces", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).namespaces.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tFound = "") && (tEntry.name '= pExcept) Set tFound = tEntry.name
    }
    Quit tFound
}

/// <p>The query string the drilled namespace and date travel on.</p>
Method ScopeQuery() As %String
{
    Quit "namespace=" _ $ZConvert(..PreparedNamespace, "O", "URL") _ "&date=" _ $ZConvert(..PreparedDate, "O", "URL")
}

/// <p>AC3, AC7 -- the namespaces level answers one envelope of JSON carrying the rows the
/// instance's own <code>NamespaceList</code> holds, over real HTTP.</p>
/// <p>Mutation: delete the route from <class>OcuPilot.Api.Router</class>'s <code>UrlMap</code> -&gt;
/// the request answers 404 and every assertion here goes red.</p>
Method TestTheNamespacesLevelAnswersOverTheWire()
{
    Set tSC = ..Fetch(..#NAMESPACESPATH, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the namespaces level answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Set tKeys = []
    Set tIterator = tPage.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""rows"",""truncated""]", "with the two declared keys: " _ tKeys.%ToJSON())
    Do $$$AssertEquals(tPage.%GetTypeOf("truncated"), "boolean", "truncated is a boolean (AD-36)")
    Do $$$AssertTrue(tPage.rows.%Size() > 0, "and this instance's namespaces come back: " _ tPage.rows.%Size())
    If tPage.rows.%Size() = 0 Quit
    Do $$$AssertEquals(tPage.rows.%Get(0).%IsDefined("namespace"), 1, "each row naming a namespace")
}

/// <p>AC3, AC7 -- the dates level answers that namespace's dates, newest first, each with its
/// count, and echoes the namespace it was asked for.</p>
/// <p><b>Ordering is asserted over every row, not against row 0.</b>
/// <property>PreparedDate</property> is itself row 0 of an identical earlier call, so an equality
/// against it moves with any ordering the port answers, reversed included; the sweep below compares
/// each row with the one before it in <code>$Horolog</code> day numbers, which is what a reordering
/// can redden.</p>
/// <p>Mutation: drop the <code>namespace</code> key from the payload -&gt; the echo assertion goes
/// red. Mutation: answer the dates in the query's reverse order at
/// <method>OcuPilot.Port.LogSourcePort.DateRows</method> -&gt; the sweep goes red wherever the
/// namespace holds more than one date.</p>
Method TestTheDatesLevelAnswersOverTheWire()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Fetch(..#DATESPATH, "namespace=" _ $ZConvert(..PreparedNamespace, "O", "URL"), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the dates level answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tPage.namespace, ..PreparedNamespace, "echoing the namespace it was asked for")
    Do $$$AssertTrue(tPage.rows.%Size() > 0, "with that namespace's dates: " _ tPage.rows.%Size())
    If tPage.rows.%Size() = 0 Quit
    Do $$$AssertEquals(tPage.rows.%Get(0).date, ..PreparedDate, "answering the same first date the preparation read")
    Do $$$AssertTrue(tPage.rows.%Get(0).count > 0, "each with its own count: " _ tPage.rows.%Get(0).count)
    ; Compared as $Horolog day numbers, not as strings, which would sort 09/10 above 09/9 and read
    ; a correct order as broken.
    Set tPreviousDay = ""
    Set tOutOfOrder = ""
    Set tDateIterator = tPage.rows.%GetIterator()
    While tDateIterator.%GetNext(.tIndex, .tDateRow) {
        Set tDay = $ZDateH(tDateRow.date, 1)
        If (tPreviousDay '= "") && (tDay > tPreviousDay) Set tOutOfOrder = "row " _ tIndex _ " (" _ tDateRow.date _ ") follows " _ $ZDate(tPreviousDay, 1)
        Set tPreviousDay = tDay
        If tOutOfOrder '= "" Quit
    }
    Do $$$AssertEquals(tOutOfOrder, "", "newest date first over every row, on " _ tPage.rows.%Size() _ " dates")
}

/// <p>AC3 -- the errors level answers that date's errors in the summary projection: the error
/// text, the time, and -- where the instance records them -- the routine and the code line.</p>
/// <p>The read is uncapped, so the ordering sweep runs over the whole date rather than over a row
/// the preparation already read.</p>
/// <p>Mutation: project <code>routine</code> from the <code>Code line</code> column -&gt; the
/// routine assertion goes red against a seeded entry whose text names its own routine. Mutation:
/// answer the errors in the query's reverse order at
/// <method>OcuPilot.Port.LogSourcePort.ErrorRows</method> -&gt; the sweep goes red wherever the date
/// holds more than one entry.</p>
Method TestTheErrorsLevelAnswersOverTheWire()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Fetch(..#LISTPATH, ..ScopeQuery(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the errors level answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tPage.namespace, ..PreparedNamespace, "echoing the namespace")
    Do $$$AssertEquals(tPage.date, ..PreparedDate, "and the date, byte for byte as the instance emitted it")
    Do $$$AssertTrue(tPage.rows.%Size() > 0, "with that date's errors: " _ tPage.rows.%Size())
    If tPage.rows.%Size() = 0 Quit
    Set tRow = tPage.rows.%Get(0)
    Do $$$AssertEquals(tRow.errorNumber, ..PreparedNumber, "answering the same first entry the preparation read")
    ; Every row against the one before it, for PreparedNumber's reason above: it is row 0 of an
    ; identical earlier call, so an equality against it holds whatever order the port answers.
    Set tPreviousNumber = ""
    Set tOutOfOrder = ""
    Set tRowIterator = tPage.rows.%GetIterator()
    While tRowIterator.%GetNext(.tIndex, .tSweepRow) {
        If (tPreviousNumber '= "") && (tSweepRow.errorNumber > tPreviousNumber) Set tOutOfOrder = "row " _ tIndex _ " (" _ tSweepRow.errorNumber _ ") follows " _ tPreviousNumber
        Set tPreviousNumber = tSweepRow.errorNumber
        If tOutOfOrder '= "" Quit
    }
    Do $$$AssertEquals(tOutOfOrder, "", "highest error number first over every row, on " _ tPage.rows.%Size() _ " rows")
    Do $$$AssertNotEquals(tRow.errorText, "", "each row carrying the instance's own error text: " _ tRow.errorText)
    Do $$$AssertNotEquals(tRow.time, "", "and its time: " _ tRow.time)
    Set tExpectedRoutine = ##class(OcuPilot.Port.LogSourcePort).RoutineOf(tRow.errorText)
    Do $$$AssertEquals(tRow.routine, tExpectedRoutine, "with the routine its own error text names, and no other: " _ tRow.routine)
}

/// <p>AC5 -- the detail level is where the captured variable table renders, and the only place it
/// does: three sections, read at the three <code>Type</code>s the vendor defines, with the caller
/// naming no <code>Type</code>.</p>
/// <p>Mutation: drop the variables section from the payload -&gt; the section assertion goes
/// red.</p>
Method TestTheDetailLevelAnswersOverTheWire()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Set tSC = ..Fetch(..#DETAILPATH, ..ScopeQuery() _ "&errorNumber=" _ ..PreparedNumber, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the detail level answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Set tKeys = []
    Set tIterator = tPage.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""expressions"",""stack"",""variables"",""truncated""]", "with the four declared keys: " _ tKeys.%ToJSON())
    Do $$$AssertTrue(tPage.expressions.%Size() > 0, "the logged expressions: " _ tPage.expressions.%Size())
    Do $$$AssertTrue(tPage.stack.%Size() > 0, "the stack levels: " _ tPage.stack.%Size())
    Do $$$AssertTrue(tPage.variables.%Size() > 0, "and every local at every level: " _ tPage.variables.%Size())
}

/// <p>AC4 -- the route's <code>?ns=</code> is inert on this screen. The namespace an application
/// error read acts on has exactly one source, the level the user drilled to, and it travels under
/// this endpoint's own parameter (AD-48).</p>
/// <p><b>The witness is the payload, not the status or the echoed label.</b> Both of those would
/// stay green if the handler steered the query while leaving the label alone -- the 2.11 review's
/// lesson. The scoped call names another namespace the caller may enter, and the first assertion
/// compares the whole answer byte for byte against the clean one: a steered read answers that
/// namespace's rows where it records errors on the same date, and a 404 where it does not, and one
/// comparison is red for both.</p>
/// <p>Mutation: read <code>%request.Get("ns", pNamespace)</code> in
/// <method>OcuPilot.Api.ErrorLog.Handle</method> before calling the port -&gt; the row comparison
/// goes red while the status stays 200.</p>
Method TestARouteScopeParameterChangesNothing()
{
    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    Do $$$AssertNotEquals(..PreparedOtherNamespace, "", "this instance offers a second namespace to steer the read towards")
    If ..PreparedOtherNamespace = "" Quit
    Do $$$AssertNotEquals(..PreparedOtherNamespace, ..PreparedNamespace, "and it is not the one drilled to")

    Set tSC = ..Fetch(..#LISTPATH, ..ScopeQuery(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the clean request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If tStatus '= 200 Quit
    Set tClean = ##class(%DynamicObject).%FromJSON(tBody)

    Set tScopedSC = ..Fetch(..#LISTPATH, ..ScopeQuery() _ "&ns=" _ $ZConvert(..PreparedOtherNamespace, "O", "URL"), .tScopedStatus, .tScopedBody, .tScopedHeaders)
    Do $$$AssertStatusOK(tScopedSC, "the scoped request completes")
    ; The payload FIRST, and byte for byte: it is the witness, and the status is not. A defect that
    ; steered the read towards the injected namespace changes the rows it answers -- or, where that
    ; namespace records nothing on this date, the status -- and this one comparison is red either
    ; way. Asserting the status first would let the leg report "the call failed" for a defect whose
    ; actual effect is that it read someone else's rows.
    Do $$$AssertEquals(tScopedBody, tBody, "the payload is byte-identical to the same call without ?ns=")
    Do $$$AssertEquals(tScopedStatus, 200, "and it answers, as the clean call did")
    Do $$$AssertEquals((tScopedBody [ "}{"), 0, "exactly one envelope")
    If tScopedStatus '= 200 Quit
    Set tScoped = ##class(%DynamicObject).%FromJSON(tScopedBody)
    Do $$$AssertEquals(tScoped.rows.%ToJSON(), tClean.rows.%ToJSON(), "the rows are the drilled namespace's, byte for byte, whatever ?ns= says")
    Do $$$AssertEquals(tScoped.namespace, ..PreparedNamespace, "and so is the namespace the payload names")

    ; The same parameter on the namespaces level, which names no namespace of its own at all.
    Set tRootSC = ..Fetch(..#NAMESPACESPATH, "", .tRootStatus, .tRootBody, .tRootHeaders)
    Set tRootScopedSC = ..Fetch(..#NAMESPACESPATH, "ns=" _ $ZConvert(..PreparedOtherNamespace, "O", "URL"), .tRootScopedStatus, .tRootScopedBody, .tRootScopedHeaders)
    Do $$$AssertEquals(tRootScopedStatus, tRootStatus, "the namespaces level answers the same status either way")
    Do $$$AssertEquals(tRootScopedBody, tRootBody, "and the identical payload")
}

/// <p>AC7 -- a namespace the instance's own enumeration does not answer with is one 404
/// <code>LOG.NAMESPACE</code> envelope over the wire, and a bad <code>maxRows</code> is one 400
/// <code>LOG.MAXROWS</code> envelope.</p>
/// <p>Mutation: default a bad <code>maxRows</code> instead of refusing it -&gt; the cap legs answer
/// 200 and go red.</p>
Method TestTheNamedRefusalsArriveAsOneEnvelope()
{
    Set tSC = ..Fetch(..#DATESPATH, "namespace=OCUPILOTNOSUCHNS", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 404, "an unknown namespace is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "LOG.NAMESPACE", "on the level's own code")
    Do $$$AssertEquals(tFault.error, "not_found", "and the not_found slug")
    Do $$$AssertEquals(tFault.%IsDefined("rows"), 0, "with no rows alongside it")

    Do $$$AssertTrue(..Prepare(), "this instance records at least one application error to read")
    If ..PreparedNamespace = "" Quit
    For tBad = "0", "-1", "01", "1.5", "abc" {
        Set tCapSC = ..Fetch(..#DATESPATH, "namespace=" _ $ZConvert(..PreparedNamespace, "O", "URL") _ "&maxRows=" _ $ZConvert(tBad, "O", "URL"), .tCapStatus, .tCapBody, .tCapHeaders)
        Do $$$AssertStatusOK(tCapSC, "maxRows '" _ tBad _ "': the request completes")
        Do $$$AssertEquals(tCapStatus, 400, "maxRows '" _ tBad _ "': is refused")
        Do $$$AssertEquals((tCapBody [ "}{"), 0, "maxRows '" _ tBad _ "': exactly one envelope")
        Set tCapFault = ##class(%DynamicObject).%FromJSON(tCapBody)
        Do $$$AssertEquals(tCapFault.code, "LOG.MAXROWS", "maxRows '" _ tBad _ "': on LOG.MAXROWS")
    }

    Set tStaleSC = ..Fetch(..#LISTPATH, "namespace=" _ $ZConvert(..PreparedNamespace, "O", "URL") _ "&date=01/01/1970", .tStaleStatus, .tStaleBody, .tStaleHeaders)
    Do $$$AssertEquals(tStaleStatus, 404, "a date the namespace does not hold is refused")
    Set tStaleFault = ##class(%DynamicObject).%FromJSON(tStaleBody)
    Do $$$AssertEquals(tStaleFault.code, "LOG.DATE", "on the date level's own code, rather than answered as an empty table")

    Set tEntrySC = ..Fetch(..#DETAILPATH, ..ScopeQuery() _ "&errorNumber=999999999", .tEntryStatus, .tEntryBody, .tEntryHeaders)
    Do $$$AssertEquals(tEntryStatus, 404, "an error number the date does not carry is refused")
    Set tEntryFault = ##class(%DynamicObject).%FromJSON(tEntryBody)
    Do $$$AssertEquals(tEntryFault.code, "LOG.ENTRY", "on the entry level's own code")
}

/// <p>A <code>POST</code> to each of the four paths is the framework's 405 naming <code>GET</code>,
/// an answer only a mapped <code>GET</code> route produces; without the route the path matches
/// nothing and is a 404.</p>
/// <p>Mutation: delete any one of the four routes from <class>OcuPilot.Api.Router</class>'s
/// <code>UrlMap</code> -&gt; that path answers 404 and this goes red naming it.</p>
Method TestAPostToEachErrorLogPathIsRefusedNamingGet()
{
    For tPath = ..#NAMESPACESPATH, ..#DATESPATH, ..#LISTPATH, ..#DETAILPATH {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 405, tPath _ ": a POST is refused")
        Do $$$AssertTrue($ListFind($ListFromString($Get(tHeaders("ALLOW"))), "GET"), tPath _ ": and Allow names GET: " _ $Get(tHeaders("ALLOW")))
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "ROUTE.METHODNOTALLOWED", tPath _ ": through the one error writer")
    }
}

}
