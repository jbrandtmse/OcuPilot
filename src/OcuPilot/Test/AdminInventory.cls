/// <p>The checked-in inventory of the vendor's admin API endpoint classes (AD-27: the
/// inventory is a fixture, never prose; AD-3: "generated" means a checked-in artifact, never
/// runtime reflection). One row per class in the endpoint package, carrying the body-template
/// method it publishes, whether it overrides <code>ShouldRunAsync</code> itself, whether its own
/// UDL source reaches for CSP state, whether that source queues its own task, and whether the
/// class is mutating.</p>
/// <p><class>OcuPilot.Test.Inventory</class> re-derives the same rows from the running
/// instance and fails on any difference, so an IRIS upgrade that moves the ground is caught
/// by the suite rather than by a user. <method>Regenerate</method> emits the block below as
/// source for a human to paste in after reviewing the diff; nothing derives it at runtime.</p>
/// <p><b>A source lookup that fails is recorded as <code>unreadable</code>, never as
/// "no match".</b> Three classes in this package are compiler stubs
/// (<code>ERROR #5360: ... is a stub name and can not be opened</code>), so scoring a failed
/// read as "references neither" would quietly count them as ordinary classes and hide the day
/// a real class stops being readable.</p>
Class OcuPilot.Test.AdminInventory Extends %RegisteredObject
{

/// <p>The method whose local override separates an async endpoint path from a synchronous
/// one (AD-26).</p>
Parameter ASYNCMETHOD = "ShouldRunAsync";

/// <p>The call whose presence in a class's own source marks a <code>Run()</code> that queues its
/// own task, AD-26's second async entry.</p>
Parameter QUEUECALL = "AddToAsyncQueue";

/// <p>The write runners a class defines itself when it is mutating (AD-3).</p>
Parameter MUTATINGMETHODS = "RunPut,RunPost,RunDelete,RunPatch";

/// <p>The inventory, as of the pinned image (IRIS for Health 2026.2 build 221U). Class names
/// are relative to <method>OcuPilot.Port.AdminPort.EndpointPackage</method>.
/// <var>template</var> is the body-template method or empty; <var>async</var> is 1 when the
/// class overrides <parameter>ASYNCMETHOD</parameter> itself; <var>csp</var> is
/// <code>none</code>, <code>request</code>, <code>response</code>, <code>both</code> or
/// <code>unreadable</code>; <var>queues</var> is 1 when the class's own source calls
/// <parameter>QUEUECALL</parameter>, 0 when it does not, or <code>unreadable</code>;
/// <var>mutating</var> is 1 when the class defines one of <parameter>MUTATINGMETHODS</parameter>
/// itself.</p>
XData Inventory
{
<inventory>
<endpoint class="AsyncResult" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Database.Actions" template="" async="1" csp="request" queues="1" mutating="0"/>
<endpoint class="Database.AsyncTaskIntegrity" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="Database.AsyncTaskIntegrityGlobalLists" template="" async="0" csp="unreadable" queues="unreadable" mutating="0"/>
<endpoint class="Database.AsyncTaskSysBackground" template="" async="0" csp="response" queues="0" mutating="0"/>
<endpoint class="Database.ConfigCRUD" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Database.SysCRUD" template="PutRequestBodySchema" async="1" csp="none" queues="0" mutating="1"/>
<endpoint class="Device.Settings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Device.Standard" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Device.SubType" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="DocDB" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="ECP.AppServerList" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="ECP.AppServerSSLConnection" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="ECP.DataServer" template="RequestBodySchema" async="1" csp="none" queues="0" mutating="1"/>
<endpoint class="ECP.Settings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="FSAccess.Path" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="FSAccess.Purpose" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Journal.File" template="" async="1" csp="none" queues="0" mutating="0"/>
<endpoint class="Journal.ListTask" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="Journal.ListTaskResultRows" template="" async="0" csp="unreadable" queues="unreadable" mutating="0"/>
<endpoint class="Journal.Record" template="" async="0" csp="request" queues="1" mutating="0"/>
<endpoint class="Journal.Settings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="LanguageServer" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="License.Key" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="License.Server" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Lock" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Monitor" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="Namespace.GlobalMappings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Namespace.Namespace" template="PutRequestBodySchema" async="1" csp="none" queues="0" mutating="1"/>
<endpoint class="Namespace.PackageMappings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Namespace.RoutineMappings" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Process" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Audit.Enabled" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Audit.Event" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Audit.Record" template="" async="1" csp="request" queues="1" mutating="0"/>
<endpoint class="Security.Audit.RecordListTask" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="Security.Audit.RecordListTaskResultRows" template="" async="0" csp="unreadable" queues="unreadable" mutating="0"/>
<endpoint class="Security.Encryption.AdminInFile" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Encryption.File" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Encryption.Key" template="" async="0" csp="none" queues="0" mutating="0"/>
<endpoint class="Security.Encryption.KeyInFile" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Encryption.Settings" template="RequestBodySchema" async="0" csp="request" queues="0" mutating="1"/>
<endpoint class="Security.LDAP" template="PutRequestBodySchema" async="1" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.MFT" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.Client.ClientConfiguration" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.Client.ServerDefinition" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.ResourceServer" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.ResourceServerMapping" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.Server" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.OAuth2.ServerClients" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.PrivilegedRoutine" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Resource" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Role" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.SQLPrivilege.Admin" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.SQLPrivilege.Column" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.SQLPrivilege.Standard" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.SSLConfig" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Service" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.Superserver" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.User" template="Schema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.WebAuth" template="PutRequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Security.X509Credential" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Task.CRUD" template="PutAndPostSchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Task.Manager" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="WQMCategory" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Wallet.Collection" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="Wallet.Secret" template="" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="WebApp.App" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="WebApp.PctClassAccess" template="RequestBodySchema" async="0" csp="none" queues="0" mutating="1"/>
<endpoint class="WebSession" template="" async="0" csp="none" queues="0" mutating="1"/>
</inventory>
}

/// <p>Re-derive the inventory from the running instance. <var>pRows</var> comes back
/// subscripted by the package-relative class name, each node
/// <code>&lt;template&gt;|&lt;async&gt;|&lt;csp&gt;|&lt;queues&gt;|&lt;mutating&gt;</code>.</p>
ClassMethod Derive(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tPackage = ##class(OcuPilot.Port.AdminPort).EndpointPackage()
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH ? ORDER BY Name")
        If $$$ISERR(tSC) Quit
        Set tRs = tStmt.%Execute(tPackage)
        ; A query that did not run is not a package with no classes in it. Left unchecked,
        ; a failed %Execute returns $$$OK with zero rows, Regenerate emits an empty block,
        ; and the failure reads as a negative result -- the same trap SourceState's
        ; "unreadable" exists to close, in the method that establishes the population
        ; everything else is compared against.
        If '$IsObject(tRs) || (tRs.%SQLCODE < 0) {
            Set tSC = $$$ERROR($$$GeneralError, "the endpoint inventory query did not run: SQLCODE " _ $Select($IsObject(tRs): tRs.%SQLCODE, 1: "no result set"))
            Quit
        }
        While tRs.%Next() {
            Set tName = tRs.%Get("Name")
            Set tShort = $Extract(tName, $Length(tPackage) + 1, *)
            Set pRows(tShort) = ##class(OcuPilot.Port.AdminPort).TemplateMethod(tShort) _ "|" _ ..LocallyDefines(tName, ..#ASYNCMETHOD) _ "|" _ ..SourceState(tName) _ "|" _ ..QueueState(tName) _ "|" _ ..Mutating(tName)
        }
        ; %Next() returns 0 both at the end of the rows and on a fetch error, so a failure
        ; part-way through reads as a shorter population -- the same trap as the unchecked
        ; %Execute above, one loop later.
        If tRs.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the endpoint inventory fetch stopped early: SQLCODE " _ tRs.%SQLCODE)
            Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read the checked-in inventory back out of the <code>Inventory</code> XData, in the
/// same shape <method>Derive</method> returns.</p>
ClassMethod Stored(Output pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Inventory", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Inventory XData block could not be opened")
            Quit
        }
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ "<endpoint " Continue
            Set tClass = ..Attribute(tLine, "class")
            If tClass = "" Continue
            Set pRows(tClass) = ..Attribute(tLine, "template") _ "|" _ ..Attribute(tLine, "async") _ "|" _ ..Attribute(tLine, "csp") _ "|" _ ..Attribute(tLine, "queues") _ "|" _ ..Attribute(tLine, "mutating")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Emit the <code>Inventory</code> XData block, derived live, as source text.</p>
/// <p>It returns the text rather than writing it: <class>OcuPilot.Api.Response</class> and
/// <class>OcuPilot.Api.Error</class> are the only classes in the tree permitted to
/// <code>Write</code> (AD-12), and this one has no reason to be an exception.</p>
ClassMethod Regenerate(Output pSource As %String) As %Status
{
    Set tSC = $$$OK
    Set pSource = ""
    Try {
        Set tSC = ..Derive(.tRows)
        If $$$ISERR(tSC) Quit
        Set pSource = "<inventory>" _ $Char(10)
        Set tKey = ""
        For {
            Set tKey = $Order(tRows(tKey))
            Quit:tKey=""
            Set tRow = tRows(tKey)
            Set pSource = pSource _ "<endpoint class=""" _ tKey _ """ template=""" _ $Piece(tRow, "|", 1) _ """ async=""" _ $Piece(tRow, "|", 2) _ """ csp=""" _ $Piece(tRow, "|", 3) _ """ queues=""" _ $Piece(tRow, "|", 4) _ """ mutating=""" _ $Piece(tRow, "|", 5) _ """/>" _ $Char(10)
        }
        Set pSource = pSource _ "</inventory>"
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pClass</var> defines <var>pMethod</var> itself rather than inheriting
/// it -- read from the compiled method's <code>Origin</code>, which names the class the
/// definition came from.</p>
ClassMethod LocallyDefines(pClass As %String, pMethod As %String) As %Boolean
{
    Set tLocal = 0
    Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(pClass, pMethod, , .tSC)
    If $IsObject(tMethod) Set tLocal = (tMethod.Origin = pClass)
    Quit tLocal
}

/// <p>Which of <code>%request</code> and <code>%response</code> occur anywhere in
/// <var>pClass</var>'s own UDL source: <code>none</code>, <code>request</code>,
/// <code>response</code>, <code>both</code>, or <code>unreadable</code> when the source
/// could not be fetched at all.</p>
/// <p>A substring scan over the whole document, comments included <i>(inference: a class
/// naming either only in a <code>///</code> comment would score as reaching for it; none in
/// the pinned image does, which is what the row-by-row comparison checks)</i>. It is a
/// drift detector, not a structural claim about what the class executes.</p>
/// <p><code>unreadable</code> is a value, not a fallback: a failed lookup must never be
/// scored as "references neither", because that reads as a negative result and it is not
/// one.</p>
ClassMethod SourceState(pClass As %String) As %String
{
    If '..ReadSource(pClass, .tText) Quit "unreadable"
    Quit $Case((tText [ "%request") _ (tText [ "%response"), "11": "both", "10": "request", "01": "response", : "none")
}

/// <p>Whether <var>pClass</var>'s own UDL source calls <parameter>QUEUECALL</parameter>:
/// <code>1</code>, <code>0</code>, or <code>unreadable</code> when the source could not be
/// fetched. A substring scan with <method>SourceState</method>'s limits, and the same rule that a
/// failed lookup is never scored as "no match".</p>
ClassMethod QueueState(pClass As %String) As %String
{
    If '..ReadSource(pClass, .tText) Quit "unreadable"
    Quit (tText [ ..#QUEUECALL)
}

/// <p>Whether <var>pClass</var> defines one of <parameter>MUTATINGMETHODS</parameter> itself
/// (AD-3's definition of a mutating endpoint).</p>
ClassMethod Mutating(pClass As %String) As %Boolean
{
    Set tMutating = 0
    Set tNames = $ListFromString(..#MUTATINGMETHODS)
    For tI = 1:1:$ListLength(tNames) {
        If ..LocallyDefines(pClass, $ListGet(tNames, tI)) {
            Set tMutating = 1
            Quit
        }
    }
    Quit tMutating
}

/// <p>Fetch <var>pClass</var>'s UDL source into <var>pText</var>; 0 when it could not be
/// fetched.</p>
ClassMethod ReadSource(pClass As %String, Output pText As %String) As %Boolean [ Private ]
{
    Set pText = ""
    Set tRead = 0
    Try {
        Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, pClass, .pText)
        Set tRead = $$$ISOK(tSC)
    } Catch {
        Set tRead = 0
    }
    Quit tRead
}

/// <p>One double-quoted attribute value out of an <code>&lt;endpoint/&gt;</code> row.</p>
ClassMethod Attribute(pLine As %String, pName As %String) As %String [ Private ]
{
    Quit $Piece($Piece(pLine, pName _ "=""", 2), """", 1)
}

}
