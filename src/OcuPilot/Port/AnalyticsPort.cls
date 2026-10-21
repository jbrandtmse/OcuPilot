/// <p>The port to the instance's analytics (AD-65, AD-29, AD-36, Story 20.11): <b>the only product class that reads
/// cubes, term lists and folder items</b>, in the caller's process and as the signed-in user, through the documented
/// <code>%DeepSee</code> classes -- <code>%DeepSee.Utils</code>, <code>%DeepSee.CubeManager.Utils</code>,
/// <code>%DeepSee.TermList</code>, <code>%DeepSee.UserLibrary.Utils</code> and <code>%DeepSee.UserLibrary.FolderItem</code>.
/// Nothing here issues an HTTP request.</p>
/// <p><b>Why not <code>/api/deepsee</code>.</b> Its dispatch class resets the process's roles to the login roles, no route
/// checks a <code>%DeepSee_*</code> resource, its MDX routes append the caller's filter and return text to the statement, and
/// its routes read the web session. This port calls the classes those routes call, and adds the gate they lack.</p>
/// <p>The vendor's reads check no <code>%DeepSee_*</code> resource (measured), so <method>Invoke</method>'s gate is the whole
/// gate for a read. <b>The order is fixed</b>, and nothing reaches the vendor before all of it has passed:</p>
/// <ol>
/// <li>The endpoint and type are one this port serves, else 501 <code>PORT.NOTIMPLEMENTED</code>.</li>
/// <li>The endpoint's pairs (<parameter>PORTALPAIRS</parameter>, <parameter>TERMLISTPAIRS</parameter> or
/// <parameter>FOLDERPAIRS</parameter>), through <method>OcuPilot.Screen.Gate.EvaluateRequired</method>; a refusal is 403 naming
/// the failed pair.</li>
/// <li>The namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>), its shape checked; a namespace that does not report analytics is 409
/// <parameter>OcuPilot.Api.AnalyticsError.NAMESPACE</parameter>.</li>
/// <li>READ on the resource guarding the namespace's globals database, and on the one guarding its routines database (a cube
/// class's generated code runs from it); a resource that does not resolve is 400 <code>PORT.VALIDATION</code>.</li>
/// <li>The vendor calls, in the target namespace, switched by explicit save and restore (AD-16): the restore is the first line of
/// the <code>Catch</code>, no <code>OcuPilot.*</code> class is called while switched, and every row is built after the
/// restore.</li>
/// </ol>
/// <p>The vendor's own resource checks still apply on top of the gate: a cube is read only when
/// <code>%DeepSee.Utils.%CheckPrivilege</code> admits it, which is the check <code>%GetCubeList</code> applies, and a folder item is
/// listed only when its <code>%CheckResource()</code> admits it, which <code>%GetFolderItemList</code> applies with its show-all
/// argument 0. A cube's model reads (<code>%GetDimensionList</code> checks nothing) ask <code>%CubeExists</code> and
/// <code>%CheckPrivilege</code> first and answer no rows for a cube either refuses.</p>
/// <p><b>Reads only, each measured to write nothing:</b> <code>%GetCubeList</code>, <code>%GetCubeClass</code>,
/// <code>%GetCubeFactCount</code>, <code>%GetCubeMeasures</code>, <code>%GetDimensionList</code>, <code>%GetRelatedCube</code>,
/// <code>%CheckPrivilege</code>, <code>%CubeExists</code>, <code>GetLastUpdate</code>, <code>%GetTermLists</code>,
/// <code>%ToObj</code>, <code>%GetFolderItemList</code> (with no caller value: it splices its class argument into SQL),
/// <code>%GetFavoriteList</code> and a folder item's properties. The port never calls <code>%GetMemberTree</code>, which
/// writes <code>^DeepSee.Session</code>, <code>%GetDimensionMembers</code>, which writes the MDX cache, or
/// <code>%GetFavoritesForUser</code>, which deletes a favorite whose item is gone. It prepares no statement of its own.</p>
/// <p><b>Every refusal is a written reason</b> (AD-39): the vendor's text goes to <method>LogFault</method> and nowhere else.</p>
/// <p><b>MDX (Story 20.33, AD-65).</b> The <code>Mdx*</code> methods run one MDX statement through
/// <code>%DeepSee.ResultSet</code> for the MDX query screen and, later, the agent's MDX read, behind <parameter>MDXPAIRS</parameter>
/// and WRITE on the database the vendor's result cache lives in (<method>MdxAdmit</method>). The statement is untrusted text: it
/// reaches only <code>%PrepareMDX</code>; <method>MdxConstructs</method> is the one detection of the five constructs the vendor
/// splices into SQL or evaluates as ObjectScript (<parameter>MDXCONSTRUCTS</parameter>), read from the vendor's own tokens, run before
/// prepare on the statement and after it on the variable-resolved text (<method>MdxPrepare</method>), and failing closed. Only SELECT
/// (at most two axes) and DRILLTHROUGH run. A drill-through is composed here from the vendor's own filters for one cell
/// (<method>MdxDrill</method>); nothing from a client enters it. The caps are this class's <code>MDX*</code> parameters, each with
/// its reason. The vendor's <code>%CancelQuery</code> checks no owner, so the caller's run row is the owner check.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>RoutineResource</method>, <method>Collect</method> and
/// <method>LogFault</method>. Production overrides none.</p>
Class OcuPilot.Port.AnalyticsPort Extends (%RegisteredObject, OcuPilot.Kernel.RowFetch)
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints this port serves, comma-separated. <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems";

/// <p>The cubes of the namespace.</p>
Parameter ENDPOINTCUBES = "Cubes";

/// <p>One cube's measures, under the criterion <parameter>CUBEKEY</parameter>.</p>
Parameter ENDPOINTMEASURES = "Measures";

/// <p>One cube's levels, under the criterion <parameter>CUBEKEY</parameter>.</p>
Parameter ENDPOINTDIMENSIONS = "Dimensions";

/// <p>One cube's relationships, under the criterion <parameter>CUBEKEY</parameter>.</p>
Parameter ENDPOINTRELATIONSHIPS = "Relationships";

/// <p>The term lists of the namespace.</p>
Parameter ENDPOINTTERMLISTS = "TermLists";

/// <p>One term list's entries, under the criterion <parameter>TERMLISTKEY</parameter>.</p>
Parameter ENDPOINTTERMLISTENTRIES = "TermListEntries";

/// <p>The folder items of the namespace the caller's resources admit.</p>
Parameter ENDPOINTFOLDERITEMS = "FolderItems";

/// <p>The classic Model Browser's pair: the portal's menu resource, public at USE.</p>
Parameter PORTALPAIRS = "%DeepSee_Portal:USE";

/// <p>The classic Term List Manager's pairs: the portal's, and the one its editor adds.</p>
Parameter TERMLISTPAIRS = "%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE";

/// <p>The classic Folder Manager's pairs, narrowed to the developer resource of its either-of list: the portal's, and
/// <code>%Development:USE</code>.</p>
Parameter FOLDERPAIRS = "%DeepSee_Portal:USE,%Development:USE";

/// <p>The permission a database read needs.</p>
Parameter READPERMISSION = "READ";

/// <p>The one request type this port serves.</p>
Parameter TYPELIST = "LIST";

/// <p>The query key naming the namespace.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The query key naming a cube, for the three tabs.</p>
Parameter CUBEKEY = "cube";

/// <p>The query key naming a term list, for its entries.</p>
Parameter TERMLISTKEY = "termlist";

/// <p>The permission a write needs on a database's resource.</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>MDX query's own pairs (Story 20.33): the portal's, and the developer resource of the classic MDX Query Tool's either-of list.</p>
Parameter MDXPAIRS = "%DeepSee_Portal:USE,%Development:USE";

/// <p>The longest statement the MDX calls take, in characters: the SQL console's own bound.</p>
Parameter MDXMAXSTATEMENT As INTEGER = 100000;

/// <p>The row positions an answer reads: the SQL console's Max rows and the vendor's default listing size.</p>
Parameter MDXMAXROWS As INTEGER = 1000;

/// <p>The column positions an answer reads: a wider grid cannot be read on a screen (inference).</p>
Parameter MDXMAXCOLUMNS As INTEGER = 100;

/// <p>The rows a listing reads: the vendor's default <code>MAXROWS</code>.</p>
Parameter MDXMAXLISTINGROWS As INTEGER = 1000;

/// <p>The characters of one cell or label, and of the whole answer: AD-36's screen-only bounds.</p>
Parameter MDXMAXCELL As INTEGER = 1000;

Parameter MDXMAXANSWER As INTEGER = 1000000;

/// <p>The seconds a run is bounded to: longer than the slowest query measured at Story 20.33's plan stops, and a forgotten run frees
/// its slot of the instance's five within two minutes.</p>
Parameter MDXSECONDS As INTEGER = 120;

/// <p>The seconds a canceled or stopped run waits for the vendor to report its query finished: twice the slowest settle measured.</p>
Parameter MDXSETTLESECONDS As INTEGER = 10;

/// <p>The constructs the vendor splices into SQL or evaluates as ObjectScript (AD-65): <code>%SEARCH</code> and
/// <code>%SQLRESTRICT</code> reach <code>ComputedDimension.SQL</code>, <code>RETURN</code> and <code>%ORDER</code> are spliced into the
/// listing's SQL, and <code>%PARM</code> evaluates a braced value. In the order <method>MdxConstructs</method> lists them.</p>
Parameter MDXCONSTRUCTS = "%SEARCH,%SQLRESTRICT,RETURN,%ORDER,%PARM";

/// <p>How many levels of string literal <method>MdxConstructs</method> reads inside one another: a literal in a literal in a literal is
/// more than a <code>%MDX("...")</code> nesting needs (inference); deeper text is unreadable and asks first.</p>
Parameter MDXSTRINGDEPTH As INTEGER = 3;

/// <p>The plain-words consequence of a statement with a finding, published once (EXPERIENCE.md's Fixed strings) and pinned equal to
/// its <file>ui/src/app/core/strings.ts</file> key.</p>
Parameter MDXCONSEQUENCE = "This query runs server-side code or SQL with your rights.";

/// <p>The SQLCODE the instance answers a statement its alarm stopped with.</p>
Parameter MDXALARMSQLCODE As INTEGER = -450;

/// <p>The cell and answer bounds <method>FetchRows</method> applies are the MDX ones.</p>
Parameter MAXCELL As INTEGER = {..#MDXMAXCELL};

Parameter MAXANSWER As INTEGER = {..#MDXMAXANSWER};

/// <p>The vendor's own privilege refusal.</p>
Parameter CODEPRIVILEGE = 940;

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "analyticsport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONNAMESPACESHAPE = "Name the namespace the call runs in.";

Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the database that namespace keeps its analytics in.";

Parameter REASONROUTINESUNKNOWN = "This instance cannot name the database that namespace keeps its routines in.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONCUBEREQUIRED = "Name the cube.";

Parameter REASONTERMLISTREQUIRED = "Name the term list.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process; production never
/// overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The endpoint list as a <class>%List</class>.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListFromString(..#ENDPOINTS)
}

/// <p>The pair set <var>pEndpoint</var> requires, as the <code>%List</code> of two-element <code>%List</code>s the gate
/// evaluates; <code>""</code> for an endpoint this port does not serve. The cubes and their three tabs take the Model Browser's
/// pairs, the term lists and their entries the Term List Manager's, and the folder items the Folder Manager's.</p>
ClassMethod Pairs(pEndpoint As %String) As %List
{
    If $ListFind($ListBuild(..#ENDPOINTCUBES, ..#ENDPOINTMEASURES, ..#ENDPOINTDIMENSIONS, ..#ENDPOINTRELATIONSHIPS), pEndpoint) {
        Set tSpec = ..#PORTALPAIRS
    } ElseIf $ListFind($ListBuild(..#ENDPOINTTERMLISTS, ..#ENDPOINTTERMLISTENTRIES), pEndpoint) {
        Set tSpec = ..#TERMLISTPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTFOLDERITEMS {
        Set tSpec = ..#FOLDERPAIRS
    } Else {
        Quit ""
    }
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>: <code>LIST</code> on every endpoint, and
/// nothing else.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    Quit $ListFind(..Endpoints(), pEndpoint) && (pType = ..#TYPELIST)
}

/// <p>Serve <var>pEndpoint</var> for request type <code>LIST</code>, after the gate.</p>
/// <p><var>pQuery</var> carries <parameter>NAMESPACEKEY</parameter> (the request's scope when absent),
/// <parameter>MAXROWSKEY</parameter> (a whole number above zero; <parameter>DEFAULTMAXROWS</parameter> when absent) and, for the
/// three cube tabs, the cube under <parameter>CUBEKEY</parameter>, and for the entries the term list under
/// <parameter>TERMLISTKEY</parameter>. <var>pBody</var> is not read.</p>
/// <p>On success, at 200, <var>pResult</var> is an array of at most that many rows:</p>
/// <ul>
/// <li>Cubes: <code>{Name, Caption, Class, LastBuild, Facts}</code>, the cubes <code>%GetCubeList</code> shows the caller,
/// <code>LastBuild</code> the instance's local <code>YYYY-MM-DD HH:MM:SS</code> of the last build or repair event, empty when
/// none is recorded.</li>
/// <li>Measures: <code>{Name, Caption, Type, Hidden}</code>.</li>
/// <li>Dimensions: <code>{Position, Dimension, Hierarchy, Level}</code>, one row per level in model order, counted from 1.</li>
/// <li>Relationships: <code>{Name, RelatedCube}</code>.</li>
/// <li>TermLists: <code>{Name, Caption, Modified}</code>, <code>Modified</code> a <code>YYYY-MM-DD</code> date.</li>
/// <li>TermListEntries: <code>{TermList, Key, Value, Fields}</code>, <code>Fields</code> each extra field as
/// <code>&lt;field&gt;: &lt;value&gt;</code> joined with <code>; </code>.</li>
/// <li>FolderItems: <code>{Name, Type, Owner, Modified, Favorite}</code>, <code>Name</code> the item's full name,
/// <code>Modified</code> the instance's local <code>YYYY-MM-DD HH:MM:SS</code>, <code>Favorite</code> true for an item in the
/// signed-in user's favorites.</li>
/// </ul>
/// <p>A cube or term list that does not exist, or that the vendor refuses the caller, answers no rows.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and <var>pFault</var> the wire
/// fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace,
/// criterion or cap of the wrong shape, or a namespace whose databases cannot be resolved; 501 <code>PORT.NOTIMPLEMENTED</code>;
/// 409 <parameter>OcuPilot.Api.AnalyticsError.NAMESPACE</parameter> for a namespace that does not report analytics; 403
/// <code>PORT.ACCESSDENIED</code> for <code>&lt;PROTECT&gt;</code> or #940; and 500 <code>INTERNAL</code>, logged, for anything
/// else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tSC = ..Admit(pEndpoint, tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)

        Set tCriterion = ""
        If $ListFind($ListBuild(..#ENDPOINTMEASURES, ..#ENDPOINTDIMENSIONS, ..#ENDPOINTRELATIONSHIPS), pEndpoint) {
            Set tCriterion = $Get(pQuery(..#CUBEKEY))
            If tCriterion = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCUBEREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
        } ElseIf pEndpoint = ..#ENDPOINTTERMLISTENTRIES {
            Set tCriterion = $Get(pQuery(..#TERMLISTKEY))
            If tCriterion = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTERMLISTREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
        }

        Kill tData
        Set tVendorSC = $$$OK
        Set tCaught = ""
        Do ..Collect(tNamespace, pEndpoint, tCriterion, tMax, .tData, .tVendorSC, .tCaught)
        If $IsObject(tCaught) {
            Set tSC = ..Mapped(tCaught, "the " _ pEndpoint _ " read failed", .pHttpStatus, .pFault)
            Quit
        }
        If $$$ISERR(tVendorSC) {
            Set tSC = ..Statused(tVendorSC, "the " _ pEndpoint _ " read failed", .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = ..Rows(pEndpoint, .tData)
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>This port's gate (AD-29, AD-65), evaluated before any vendor call for <var>pEndpoint</var> in <var>pNamespace</var>, in this
/// order: the endpoint's pairs; the namespace's shape; the namespace reporting analytics; READ on its globals database; READ on its
/// routines database. A refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var> set as
/// <method>Invoke</method> answers them. Names no vendor class.</p>
ClassMethod Admit(pEndpoint As %String, pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit ..AdmitNamespace(pNamespace, .pHttpStatus, .pFault)
}

/// <p>The namespace half of the gate, after the pairs (AD-29, AD-65), shared by every endpoint and by the MDX calls: the namespace's
/// shape; the namespace reporting analytics; READ on its globals database; READ on its routines database. A refusal is an error
/// status with <var>pHttpStatus</var> and <var>pFault</var>. Names no vendor class.</p>
ClassMethod AdmitNamespace(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    If '##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("analytics", pNamespace) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#NAMESPACE, .pHttpStatus, .pFault)
    Set tGlobals = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(pNamespace, .tGlobals, .tReadOnly) || (tGlobals = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tGlobals, ..#READPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tRoutines = ""
    If '..RoutineResource(pNamespace, .tRoutines) || (tRoutines = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONROUTINESUNKNOWN, .pHttpStatus, .pFault)
    If tRoutines '= tGlobals {
        If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tRoutines, ..#READPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The resource guarding <var>pNamespace</var>'s routines database, as
/// <method>OcuPilot.Kernel.Shell.Namespaces.RoutineDatabase</method> reports it; 0 when the instance reports none. A cube's
/// generated code runs from this database, so a read needs READ on it as well as on the globals database. Overridable so a fixture
/// can name another resource; production never overrides it.</p>
ClassMethod RoutineResource(pNamespace As %String, Output pResource As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(pNamespace, .pResource, .tReadOnly)
}

/// <p>Read <var>pEndpoint</var> from the vendor in <var>pNamespace</var> into <var>pData</var>: <code>pData</code> is the row count,
/// and <code>pData(n)</code> row <code>n</code> as a <code>%List</code>, at most <var>pMax</var> rows when that is above zero.
/// <var>pCriterion</var> is the cube or term list a tab names. A vendor status that is an error is <var>pVendorStatus</var>; an
/// exception is <var>pCaught</var>.</p>
/// <p><b>Everything between the switch and the restore is in this one method</b> and names only vendor and system classes, because
/// an <code>OcuPilot.*</code> class is not visible in the target namespace (AD-16). The raw values are shaped into rows by
/// <method>Rows</method>, after the restore.</p>
ClassMethod Collect(pNamespace As %String, pEndpoint As %String, pCriterion As %String, pMax As %Integer, Output pData, Output pVendorStatus As %Status, Output pCaught As %Exception.AbstractException) [ Private ]
{
    Kill pData
    Set pData = 0
    Set pVendorStatus = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pEndpoint = ..#ENDPOINTCUBES {
            Set pVendorStatus = ##class(%DeepSee.Utils).%GetCubeList(.tList, "cubes", 1)
            Set tKey = ""
            While $$$ISOK(pVendorStatus) {
                Set tKey = $Order(tList(tKey))
                If tKey = "" Quit
                If (pMax > 0) && (pData >= pMax) Quit
                Set tCube = $List(tList(tKey), 1)
                Set tFacts = ##class(%DeepSee.Utils).%GetCubeFactCount(tCube, .tFactStatus)
                If $$$ISERR(tFactStatus) Set tFacts = ""
                Set pData = pData + 1
                Set pData(pData) = $ListBuild(tCube, $List(tList(tKey), 2), ##class(%DeepSee.Utils).%GetCubeClass(tCube), ##class(%DeepSee.CubeManager.Utils).GetLastUpdate(tCube, "build"), tFacts)
            }
        } ElseIf (pEndpoint = ..#ENDPOINTMEASURES) || (pEndpoint = ..#ENDPOINTDIMENSIONS) || (pEndpoint = ..#ENDPOINTRELATIONSHIPS) {
            If ##class(%DeepSee.Utils).%CubeExists(pCriterion) && ##class(%DeepSee.Utils).%CheckPrivilege(pCriterion) {
                If pEndpoint = ..#ENDPOINTMEASURES {
                    Set pVendorStatus = ##class(%DeepSee.Utils).%GetCubeMeasures(pCriterion, .tMeasures)
                    Set tAt = ""
                    While $$$ISOK(pVendorStatus) {
                        Set tAt = $Order(tMeasures(tAt))
                        If tAt = "" Quit
                        If (pMax > 0) && (pData >= pMax) Quit
                        Set pData = pData + 1
                        ; A calculated measure is $LB(name, caption, type): it has no hidden flag.
                        Set pData(pData) = $ListBuild($List(tMeasures(tAt), 1), $ListGet(tMeasures(tAt), 2), $ListGet(tMeasures(tAt), 3), ''$ListGet(tMeasures(tAt), 4))
                    }
                } Else {
                    Set pVendorStatus = ##class(%DeepSee.Utils).%GetDimensionList(pCriterion, .tInfo)
                    Set tDim = ""
                    While $$$ISOK(pVendorStatus) {
                        Set tDim = $Order(tInfo(tDim))
                        If tDim = "" Quit
                        Set tHier = ""
                        For {
                            Set tHier = $Order(tInfo(tDim, tHier))
                            If tHier = "" Quit
                            Set tLevel = ""
                            For {
                                Set tLevel = $Order(tInfo(tDim, tHier, tLevel))
                                If tLevel = "" Quit
                                If (pMax > 0) && (pData >= pMax) Quit
                                Set tEntry = tInfo(tDim, tHier, tLevel)
                                If (pEndpoint = ..#ENDPOINTDIMENSIONS) && ($List(tEntry, 1) = "l") {
                                    Set pData = pData + 1
                                    Set pData(pData) = $ListBuild(pData, $List(tEntry, 2), $List(tEntry, 3), $List(tEntry, 4))
                                } ElseIf (pEndpoint = ..#ENDPOINTRELATIONSHIPS) && ($List(tEntry, 1) = "r") {
                                    Set pData = pData + 1
                                    Set pData(pData) = $ListBuild($List(tEntry, 2), ##class(%DeepSee.Utils).%GetRelatedCube(pCriterion, $List(tEntry, 2)))
                                }
                            }
                            If (pMax > 0) && (pData >= pMax) Quit
                        }
                        If (pMax > 0) && (pData >= pMax) Quit
                    }
                }
            }
        } ElseIf pEndpoint = ..#ENDPOINTTERMLISTS {
            Set pVendorStatus = ##class(%DeepSee.TermList).%GetTermLists(.tTermLists)
            Set tAt = ""
            While $$$ISOK(pVendorStatus) {
                Set tAt = $Order(tTermLists(tAt))
                If tAt = "" Quit
                If (pMax > 0) && (pData >= pMax) Quit
                Set pData = pData + 1
                Set pData(pData) = $ListBuild($List(tTermLists(tAt), 1), $List(tTermLists(tAt), 2), $List(tTermLists(tAt), 3))
            }
        } ElseIf pEndpoint = ..#ENDPOINTTERMLISTENTRIES {
            ; An unknown term list answers no object and no status: no rows, not a failure. A fault part-way sets the status and
            ; answers the part it built, which is a failure, not a shorter list.
            Kill tObjectStatus
            Set tObject = ##class(%DeepSee.TermList).%ToObj(pCriterion, .tObjectStatus)
            Set pVendorStatus = $Get(tObjectStatus, $$$OK)
            If $$$ISOK(pVendorStatus) && $IsObject(tObject) {
                For tAt = 1:1:tObject.keyList.Count() {
                    If (pMax > 0) && (pData >= pMax) Quit
                    Set tKey = tObject.keyList.GetAt(tAt)
                    Set tFields = ""
                    For tField = 1:1:tObject.fieldList.Count() {
                        Set tName = tObject.fieldList.GetAt(tField)
                        If tName = "" Continue
                        Set tFields = tFields _ $Select(tFields = "": "", 1: "; ") _ tName _ ": " _ tObject.valueList.GetAt(tKey _ "^" _ $ZConvert(tName, "U"))
                    }
                    Set pData = pData + 1
                    Set pData(pData) = $ListBuild(tObject.name, tKey, tObject.valueList.GetAt(tKey _ "^VALUE"), tFields)
                }
            }
        } ElseIf pEndpoint = ..#ENDPOINTFOLDERITEMS {
            ; No folder class is passed: the vendor splices that argument into its statement.
            Set pVendorStatus = ##class(%DeepSee.UserLibrary.Utils).%GetFolderItemList(.tIds, "", 0, "")
            If $$$ISOK(pVendorStatus) Set pVendorStatus = ##class(%DeepSee.UserLibrary.Utils).%GetFavoriteList(.tFavorites)
            Set tAt = ""
            While $$$ISOK(pVendorStatus) {
                Set tAt = $Order(tIds(tAt))
                If tAt = "" Quit
                If (pMax > 0) && (pData >= pMax) Quit
                Set tItem = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(tIds(tAt))
                If '$IsObject(tItem) Continue
                Set tFullName = tItem.fullName
                Set pData = pData + 1
                Set pData(pData) = $ListBuild(tFullName, tItem.%GetTypeName(), tItem.owner, tItem.timeModified, $Data(tFavorites(tFullName)) # 2)
                Set tItem = ""
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The rows of <var>pEndpoint</var> from the values <method>Collect</method> gathered in <var>pData</var>, as an array of
/// objects. Text is typed as text, so a name that reads as a number stays a string.</p>
ClassMethod Rows(pEndpoint As %String, ByRef pData) As %DynamicArray [ Private ]
{
    Set tRows = []
    For tAt = 1:1:pData {
        Set tValues = pData(tAt)
        Set tRow = {}
        If pEndpoint = ..#ENDPOINTCUBES {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Caption", $List(tValues, 2), "string")
            Do tRow.%Set("Class", $List(tValues, 3), "string")
            Do tRow.%Set("LastBuild", ..BuildStamp($List(tValues, 4)), "string")
            If $List(tValues, 5) = "" {
                Do tRow.%Set("Facts", "", "null")
            } Else {
                Do tRow.%Set("Facts", +$List(tValues, 5), "number")
            }
        } ElseIf pEndpoint = ..#ENDPOINTMEASURES {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Caption", $List(tValues, 2), "string")
            Do tRow.%Set("Type", $List(tValues, 3), "string")
            Do tRow.%Set("Hidden", $List(tValues, 4), "boolean")
        } ElseIf pEndpoint = ..#ENDPOINTDIMENSIONS {
            Do tRow.%Set("Position", $List(tValues, 1), "number")
            Do tRow.%Set("Dimension", $List(tValues, 2), "string")
            Do tRow.%Set("Hierarchy", $List(tValues, 3), "string")
            Do tRow.%Set("Level", $List(tValues, 4), "string")
        } ElseIf pEndpoint = ..#ENDPOINTRELATIONSHIPS {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("RelatedCube", $List(tValues, 2), "string")
        } ElseIf pEndpoint = ..#ENDPOINTTERMLISTS {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Caption", $List(tValues, 2), "string")
            Do tRow.%Set("Modified", $Select($List(tValues, 3) = "": "", 1: $ZDate($List(tValues, 3), 3)), "string")
        } ElseIf pEndpoint = ..#ENDPOINTTERMLISTENTRIES {
            Do tRow.%Set("TermList", $List(tValues, 1), "string")
            Do tRow.%Set("Key", $List(tValues, 2), "string")
            Do tRow.%Set("Value", $List(tValues, 3), "string")
            Do tRow.%Set("Fields", $List(tValues, 4), "string")
        } Else {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Type", $List(tValues, 2), "string")
            Do tRow.%Set("Owner", $List(tValues, 3), "string")
            Do tRow.%Set("Modified", ..LocalStamp($List(tValues, 4)), "string")
            Do tRow.%Set("Favorite", $List(tValues, 5), "boolean")
        }
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The last build <var>pStamp</var> as <code>GetLastUpdate</code> answers it, in the instance's local time, cut to
/// <code>YYYY-MM-DD HH:MM:SS</code>; <code>""</code> for the vendor's <code>0</code> or an empty answer. Pure.</p>
ClassMethod BuildStamp(pStamp As %String) As %String
{
    If (pStamp = "") || (pStamp = 0) Quit ""
    Quit $Extract(pStamp, 1, 19)
}

/// <p>A UTC <code>YYYY-MM-DD HH:MM:SS[.fff]</code> as the instance's local <code>YYYY-MM-DD HH:MM:SS</code>, by
/// <code>$ZDATETIMEH</code>'s UTC-to-local form; <code>""</code> for a value that is not one. A folder item stores its modified
/// time as UTC.</p>
ClassMethod LocalStamp(pUtc As %String) As %String
{
    Set tLocal = ""
    Try {
        If $Length(pUtc) < 19 Quit
        Set tLocal = $ZDateTime($ZDateTimeH($ZDateTimeH($Extract(pUtc, 1, 19), 3), -3), 3)
    } Catch {
        Set tLocal = ""
    }
    Quit tLocal
}

/// <p>Whether status <var>pStatus</var> carries vendor status code <var>pCode</var>, as one whole entry of its comma-separated
/// code list.</p>
ClassMethod HasCode(pStatus As %Status, pCode As %String) As %Boolean [ Private ]
{
    Set tCodes = ""
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
    } Catch {
        Set tCodes = ""
    }
    Quit ($ListFind($ListFromString(tCodes, ","), pCode) > 0)
}

/// <p>A vendor status <var>pStatus</var> in this port's own words: <code>&lt;PROTECT&gt;</code> and #940 are 403
/// <code>PORT.ACCESSDENIED</code>, anything else 500 <code>INTERNAL</code>. Both log the vendor's text under
/// <var>pMessage</var>.</p>
ClassMethod Statused(pStatus As %Status, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tText = ""
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    If (tText [ "<PROTECT>") || ..HasCode(pStatus, ..#CODEPRIVILEGE) {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pStatus, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pStatus, .pHttpStatus, .pFault)
}

/// <p>A vendor exception <var>pException</var> in this port's own words: its status, as <method>Statused</method> answers it.</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Statused(pException.AsStatus(), pMessage, .pHttpStatus, .pFault)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line; production never
/// overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes the fault's
/// <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The 409 refusal <var>pCode</var>, with its published sentence.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.AnalyticsError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>The MDX gate (AD-29, AD-65), evaluated before any vendor call, in this order: <parameter>MDXPAIRS</parameter>; the namespace's
/// shape; the namespace reporting analytics; READ on its globals and routines databases (<method>AdmitNamespace</method>); WRITE on
/// the database <code>^DeepSee.Cache.Results</code> maps to in the namespace, which a prepare and an execute write (measured: even
/// creating a result set writes its session node), and that database mounted read-write. A refusal is an error status with
/// <var>pHttpStatus</var> and <var>pFault</var>: 403 naming the failed pair; 400 <code>PORT.VALIDATION</code> for a namespace of the
/// wrong shape or whose databases cannot be named; 409 <parameter>OcuPilot.Api.AnalyticsError.NAMESPACE</parameter> for a namespace
/// that does not report analytics; 409 <parameter>OcuPilot.Api.AnalyticsError.MDXREADONLY</parameter> for a cache database that is
/// read-only or not mounted. The screen's own pairs are the caller's to check first. Names no vendor class.</p>
ClassMethod MdxAdmit(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#MDXPAIRS), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tSC = ..AdmitNamespace(pNamespace, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCache = ""
    Set tReadOnly = 0
    Set tMounted = 0
    If '..CacheDatabase(pNamespace, .tCache, .tReadOnly, .tMounted) || (tCache = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tCache, ..#WRITEPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If tReadOnly || 'tMounted Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#MDXREADONLY, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The guarding resource and mount state of the database <code>^DeepSee.Cache.Results</code> maps to in <var>pNamespace</var>, as
/// <method>%SYS.Namespace.GetGlobalDest</method> and <method>%SYS.Namespace.GetNSInfo</method> report them; 0 when the instance reports
/// none, which a caller refuses rather than admits. A <code>%</code>-class that answers in any namespace, so no switch is taken
/// (AD-16). Overridable so a fixture can name another database; production never overrides it.</p>
ClassMethod CacheDatabase(pNamespace As %String, Output pResource As %String, Output pReadOnly As %Boolean, Output pMounted As %Boolean) As %Boolean
{
    Set pResource = ""
    Set pReadOnly = 0
    Set pMounted = 0
    Set tResolved = 0
    Try {
        Set tDest = ##class(%SYS.Namespace).GetGlobalDest($ZConvert(pNamespace, "U"), "^DeepSee.Cache.Results")
        Kill tInfo
        If tDest '= "" Do ##class(%SYS.Namespace).GetNSInfo("^" _ tDest, .tInfo, 1)
        Set pResource = $Get(tInfo("Resource"))
        Set pReadOnly = ''$Get(tInfo("ReadOnly"))
        Set pMounted = ''$Get(tInfo("Mounted"))
        Set tResolved = (pResource '= "") && ($Get(tInfo("Status")) = 1)
    } Catch {
        Set pResource = ""
        Set pReadOnly = 0
        Set pMounted = 0
        Set tResolved = 0
    }
    Quit tResolved
}

/// <p>Whether <var>pText</var> holds a construct the vendor splices into SQL or evaluates as ObjectScript, or cannot be read: the one
/// detection of AD-65's splice clause, which the MDX query screen asks first on and the agent's MDX read refuses. It writes nothing
/// and switches no namespace.</p>
/// <p>It answers 1 when a token of <code>%DeepSee.Query.Parser.%Tokenize</code>, a <code>[...]</code> token unquoted as the parser
/// unquotes it and then upper-cased, equals a member of <parameter>MDXCONSTRUCTS</parameter>; or a token of a string literal does,
/// each literal's value tokenized the same way to <parameter>MDXSTRINGDEPTH</parameter> levels, so a comment inside a word
/// (<code>%SE/**/ARCH</code>) is found; or, <b>failing closed</b> with <var>pUnread</var> 1, the text is blank, a tokenize answers an
/// error or raises, or a literal lies deeper than the depth read. <var>pFound</var> is a <code>$ListBuild</code> of the names found,
/// in <parameter>MDXCONSTRUCTS</parameter> order, without repeats; it is empty when only <var>pUnread</var> is set. A single-quoted
/// span needs no rule: <code>'</code> is a token by itself, so its content is in the stream.</p>
ClassMethod MdxConstructs(pText As %String, Output pFound As %List, Output pUnread As %Boolean) As %Boolean
{
    Set pFound = ""
    Set pUnread = 0
    Kill tHit
    Try {
        If ..MdxBlank(pText) {
            Set pUnread = 1
            Quit
        }
        Do ..ScanTokens(pText, 0, .tHit, .pUnread)
    } Catch {
        Set pUnread = 1
    }
    Set tConstructs = $ListFromString(..#MDXCONSTRUCTS)
    For tI = 1:1:$ListLength(tConstructs) {
        If $Data(tHit($List(tConstructs, tI))) Set pFound = pFound _ $ListBuild($List(tConstructs, tI))
    }
    Quit ''pUnread || ($ListLength(pFound) > 0)
}

/// <p>Whether <var>pText</var> holds nothing but white space: blanks, tabs, line ends and the no-break space.</p>
ClassMethod MdxBlank(pText As %String) As %Boolean
{
    Quit $ZStrip($Get(pText), "*", $Char(9, 10, 11, 12, 13, 32, 160)) = ""
}

/// <p>Tokenize <var>pText</var> and record each construct it names in <var>pHit</var>, recursing into each string literal until
/// <var>pDepth</var> reaches <parameter>MDXSTRINGDEPTH</parameter>. <var>pUnread</var> is set when a tokenize fails or a literal is
/// too deep.</p>
ClassMethod ScanTokens(pText As %String, pDepth As %Integer, ByRef pHit, ByRef pUnread As %Boolean) [ Private ]
{
    Kill tTokens
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%DeepSee.Query.Parser).%Tokenize(pText, .tTokens)
    } Catch {
        Set tSC = $$$ERROR($$$GeneralError, "the tokenizer raised")
    }
    If $$$ISERR(tSC) {
        Set pUnread = 1
        Quit
    }
    Set tConstructs = $ListFromString(..#MDXCONSTRUCTS)
    Set tAt = ""
    For {
        Set tAt = $Order(tTokens(tAt))
        If tAt = "" Quit
        Set tType = $List(tTokens(tAt), 1)
        Set tValue = $List(tTokens(tAt), 2)
        If tType = "LIT" {
            If pDepth >= ..#MDXSTRINGDEPTH {
                Set pUnread = 1
            } Else {
                Do ..ScanTokens(tValue, pDepth + 1, .pHit, .pUnread)
            }
            Continue
        }
        Set tWord = $ZConvert(##class(%DeepSee.Query.Parser).%UnquoteIdent(tValue), "U")
        If $ListFind(tConstructs, tWord) Set pHit(tWord) = 1
    }
}

/// <p>Prepare the statement <var>pText</var> in <var>pNamespace</var> with <code>%PrepareMDX</code>, which resolves pivot variables
/// from <var>pVariables</var> alone, and classify it; nothing is executed. <var>pRS</var> is the prepared result set.</p>
/// <ul>
/// <li>A statement the vendor will not prepare is not a refusal: the status is OK and <var>pAnswer</var> is
/// <code>{outcome: "error", message}</code> with the vendor's text.</li>
/// <li>A statement that is neither SELECT nor DRILLTHROUGH is 422 <parameter>OcuPilot.Api.AnalyticsError.MDXKIND</parameter>, and a
/// SELECT with more than two axes 422 <parameter>OcuPilot.Api.AnalyticsError.MDXAXES</parameter>, each an error status with
/// <var>pHttpStatus</var> and <var>pFault</var>.</li>
/// <li>Then <method>MdxConstructs</method> runs on the variable-resolved text, so a text the vendor could not resolve reads blank and
/// asks: <var>pAsk</var> is that answer and <var>pFound</var> the names found.</li>
/// </ul>
/// <p>No production caller hands <var>pVariables</var>. The vendor writes its query-text cache node while preparing, which
/// <method>MdxAdmit</method>'s WRITE check covers. <var>pRS</var> is handed back only with an OK status and no <var>pAnswer</var>; the caller
/// releases it with <method>MdxRelease</method>. The caller's namespace is unchanged on return.</p>
ClassMethod MdxPrepare(pNamespace As %String, pText As %String, Output pRS, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pAsk As %Boolean, Output pFound As %List, ByRef pVariables) As %Status
{
    Set pRS = ""
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pAsk = 0
    Set pFound = ""
    Set tCaught = ""
    Set tPrepareSC = $$$OK
    Set tType = ""
    Set tAxes = 0
    Set tResolved = ""
    Do ..Prepared(pNamespace, pText, .pVariables, .pRS, .tPrepareSC, .tType, .tAxes, .tResolved, .tCaught)
    If $IsObject(tCaught) {
        Do ..MdxRelease(pNamespace, .pRS)
        Quit ..Mapped(tCaught, "the MDX prepare failed", .pHttpStatus, .pFault)
    }
    If $$$ISERR(tPrepareSC) {
        Do ..MdxRelease(pNamespace, .pRS)
        Set pAnswer = ..ErrorAnswer(tPrepareSC)
        Quit $$$OK
    }
    If '$ListFind($ListBuild("SELECT", "DRILLTHROUGH"), tType) {
        Do ..MdxRelease(pNamespace, .pRS)
        Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#MDXKIND, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXKIND, .pHttpStatus, .pFault)
    }
    If (tType = "SELECT") && (tAxes > 2) {
        Do ..MdxRelease(pNamespace, .pRS)
        Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#MDXAXES, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXAXES, .pHttpStatus, .pFault)
    }
    Set pAsk = ..MdxConstructs(tResolved, .pFound, .tUnread)
    Quit $$$OK
}

/// <p>The vendor half of <method>MdxPrepare</method>, in <var>pNamespace</var>: a new result set prepared with <var>pText</var>, its
/// query type and axis count, and the variable-resolved text. Everything between the switch and the restore names only vendor and
/// system classes (AD-16); a raised error is <var>pCaught</var>.</p>
ClassMethod Prepared(pNamespace As %String, pText As %String, ByRef pVariables, Output pRS, Output pStatus As %Status, Output pType As %String, Output pAxes As %Integer, Output pResolved As %String, Output pCaught As %Exception.AbstractException) [ Private ]
{
    Set pRS = ""
    Set pStatus = $$$OK
    Set pType = ""
    Set pAxes = 0
    Set pResolved = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pRS = ##class(%DeepSee.ResultSet).%New()
        Set pStatus = pRS.%PrepareMDX(pText, .pVariables, .pResolved)
        If $$$ISOK(pStatus) {
            Set pType = pRS.%Query.queryType
            Set pAxes = pRS.%Query.axes.Count()
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Release the result set <var>pRS</var> in <var>pNamespace</var>: the vendor's destructor clears the result set's local cache in the namespace it
/// runs in, so a caller that holds one in its own namespace would leave that cache behind in <var>pNamespace</var>. Every caller of
/// <method>MdxPrepare</method> and <method>MdxDrill</method> that is handed a result set releases it here once it has read what it needs; the port
/// releases the ones it does not hand back. The caller holds no other reference to it. The caller's namespace is unchanged on return.</p>
ClassMethod MdxRelease(pNamespace As %String, ByRef pRS)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set pRS = ""
    }
}

/// <p>The query type of the prepared result set <var>pRS</var>: <code>SELECT</code> or <code>DRILLTHROUGH</code> for a result set
/// <method>MdxPrepare</method> accepted. Reads the object only.</p>
ClassMethod MdxKind(pRS) As %String
{
    Quit $Select($IsObject(pRS): pRS.%Query.queryType, 1: "")
}

/// <p>Start the prepared result set <var>pRS</var> in <var>pNamespace</var>: <code>%ExecuteAsynch</code> with no wait, so a SELECT's
/// axes and cells run on the vendor's agents, in the caller's security context. The vendor resolves the statement's members in the
/// caller first, running any SQL they name (<code>%SEARCH</code>, a computed dimension), so a start can take as long as that SQL. A
/// DRILLTHROUGH forces the wait for its MDX portion; its listing's SQL runs when its rows are fetched (<method>MdxAnswer</method>).
/// <var>pCube</var> and <var>pKey</var> name the query for <method>MdxCancel</method> and are set before the vendor runs anything. The
/// vendor's status is the answer; a raised error is its status.</p>
ClassMethod MdxStart(pNamespace As %String, pRS, Output pCube As %String, Output pKey As %String) As %Status
{
    Set pCube = ""
    Set pKey = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pCube = pRS.%GetCubeName()
        Set pKey = pRS.%GetQueryKey()
        ; The listing reads one row past the cap so the answer can say whether more exist.
        If (pRS.%Query.queryType = "DRILLTHROUGH") && (pRS.%Query.%MaxListingRows >= ..#MDXMAXLISTINGROWS) Set pRS.%Query.%MaxListingRows = ..#MDXMAXLISTINGROWS + 1
        Set tSC = pRS.%ExecuteAsynch(.tKey, , 0)
        If $Get(tKey) '= "" Set pKey = tKey
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's status of the started result set <var>pRS</var>: 0 to 99 while it works, 100 when it is done or failed. When it
/// has failed, <var>pError</var> is the vendor's status, which reads as an error; a canceled query is 100 with the vendor's
/// "Query cancelled". A raised error reads as done with that error.</p>
ClassMethod MdxStatus(pNamespace As %String, pRS, Output pError As %Status) As %Integer
{
    Set pError = $$$OK
    Set tStatus = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatus = pRS.%GetStatus(, .pError)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pError = ex.AsStatus()
        Set tStatus = 100
    }
    Quit tStatus
}

/// <p>Cancel the query <var>pKey</var> of cube <var>pCube</var> in <var>pNamespace</var> (<code>%CancelQuery</code>, a class method
/// that checks no owner: the caller's own run row is the owner check). The vendor stops every run of that statement text, the
/// classic tool's included (named limit).</p>
ClassMethod MdxCancel(pNamespace As %String, pCube As %String, pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.ResultSet).%CancelQuery(pCube, pKey)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Compose and prepare the drill-through of one cell of the executed result set <var>pRS</var>: <var>pRow</var> and
/// <var>pColumn</var> are the cell's 1-based positions as <method>MdxAnswer</method> lists them. A result set that is not a SELECT, whose
/// answer has no cells, and a position past the positions its answer lists (<method>Positions</method>) are refused 400
/// <parameter>OcuPilot.Api.AnalyticsError.MDXINPUT</parameter>. Otherwise it reads the vendor's own
/// <code>%GetFiltersForCellRange</code> for that one cell and prepares <code>DRILLTHROUGH MAXROWS</code>
/// <parameter>MDXMAXLISTINGROWS</parameter> <code>SELECT FROM [&lt;cube&gt;] %FILTER &lt;filter&gt;...</code>, the cube name
/// bracket-quoted with <code>]</code> doubled and each filter the vendor's, slicer first. <var>pDrill</var> is that prepared result
/// set, for <method>MdxStart</method>, which the caller releases with <method>MdxRelease</method>; nothing from a client enters the text. When
/// the vendor will not prepare it, <var>pAnswer</var> is <code>{outcome: "error", message}</code>, the status is OK and <var>pDrill</var> is
/// released.</p>
ClassMethod MdxDrill(pNamespace As %String, pRS, pRow As %Integer, pColumn As %Integer, Output pDrill, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pAnswer As %DynamicObject) As %Status
{
    Set pDrill = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pAnswer = ""
    Set tCaught = ""
    Set tRefused = 0
    Set tFilterSC = $$$OK
    Set tPrepareSC = $$$OK
    If ..MdxKind(pRS) '= "SELECT" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#MDXINPUT, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXINPUT, .pHttpStatus, .pFault)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCube = pRS.%GetCubeName()
        Do ..Positions(pRS, pRS.%GetAxisCount(), .tColumns, .tRows)
        If (pRow > tRows) || (pColumn > tColumns) {
            Set tRefused = 1
        } Else {
            Set tFilterSC = pRS.%GetFiltersForCellRange(.tFilters, pRow, pColumn, pRow, pColumn, .tMeasure)
            If $$$ISOK(tFilterSC) {
                Set tText = "DRILLTHROUGH MAXROWS " _ ..#MDXMAXLISTINGROWS _ " SELECT FROM [" _ $Replace(tCube, "]", "]]") _ "]"
                For tSlot = 0, 1, 2 {
                    If $Get(tFilters(tSlot)) '= "" Set tText = tText _ " %FILTER " _ tFilters(tSlot)
                }
                Set pDrill = ##class(%DeepSee.ResultSet).%New()
                Set tPrepareSC = pDrill.%PrepareMDX(tText)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) {
        Do ..MdxRelease(pNamespace, .pDrill)
        Quit ..Mapped(tCaught, "the MDX drill-through failed", .pHttpStatus, .pFault)
    }
    If tRefused Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#MDXINPUT, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXINPUT, .pHttpStatus, .pFault)
    If $$$ISERR(tFilterSC) Quit ..Statused(tFilterSC, "the MDX cell filters could not be read", .pHttpStatus, .pFault)
    If $$$ISERR(tPrepareSC) {
        Do ..MdxRelease(pNamespace, .pDrill)
        Set pAnswer = ..ErrorAnswer(tPrepareSC)
    }
    Quit $$$OK
}

/// <p>The answer of the finished result set <var>pRS</var> of <var>pNamespace</var>, after <method>MdxStatus</method> read 100 without
/// an error: <var>pSeconds</var> is how long the run took. A DRILLTHROUGH's listing is not read until its rows are fetched, so that read is
/// where a slow listing waits: with <var>pBound</var> above zero it runs under an alarm of that many seconds, and a listing the alarm
/// stops answers <code>{outcome: "stopped"}</code>.</p>
/// <ul>
/// <li>A SELECT is <code>{outcome: "cells", cube, columns, rows: [{label, cells}], rowsAvailable, columnsAvailable, truncated,
/// seconds}</code>. Each column header, and each row's <code>label</code>, joins the labels of that position with
/// <code>" / "</code>, outer to inner (the vendor lists a tuple's labels innermost first); a query with no rows axis answers one row
/// with an empty label, and no axes one cell; an axis the vendor answered empty has no positions (<method>Positions</method>). Values
/// are the vendor's own, as text. At most <parameter>MDXMAXROWS</parameter> rows and <parameter>MDXMAXCOLUMNS</parameter> columns are
/// read, each label and cell is cut at <parameter>MDXMAXCELL</parameter> characters, and rows are kept while the answer's JSON text is
/// at most <parameter>MDXMAXANSWER</parameter> characters; <code>truncated</code> says any of it was cut.</li>
/// <li>A DRILLTHROUGH is <code>{outcome: "rows", columns, rows, truncated, seconds}</code>, the listing read through
/// <method>FetchRows</method> to <parameter>MDXMAXLISTINGROWS</parameter> rows.</li>
/// <li>A listing the vendor cannot read is <code>{outcome: "error", message}</code>.</li>
/// </ul>
/// <p>Everything between the switch and the restore is in this one method and names only vendor and system classes and this class's
/// own methods, which are compiled into it (AD-16). The caller's namespace is unchanged on return.</p>
ClassMethod MdxAnswer(pNamespace As %String, pRS, pSeconds As %Numeric, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pBound As %Integer = 0) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tCaught = ""
    Set tAlarmed = 0
    Set tStopped = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pRS.%Query.queryType = "DRILLTHROUGH" {
            Set tListSC = pRS.%GetListingResultSet(.tSet)
            If $$$ISERR(tListSC) || '$IsObject(tSet) {
                Set pAnswer = ..ErrorAnswer($Select($$$ISERR(tListSC): tListSC, 1: $$$ERROR($$$GeneralError, "No listing result available")))
            } Else {
                Set tMeta = tSet.%GetMetadata()
                Set tColumns = []
                For tI = 1:1:tMeta.columns.Count() {
                    Do tColumns.%Push(tMeta.columns.GetAt(tI).colName, "string")
                }
                If pBound > 0 {
                    Do $System.Alarm.Set(pBound)
                    Set tAlarmed = 1
                }
                Do ..FetchRows(tSet, tColumns, ..#MDXMAXLISTINGROWS, .tRows, .tTruncated, .tMore, .tCut)
                If tAlarmed {
                    Do $System.Alarm.Clear()
                    Set tAlarmed = 0
                }
                If (tSet.%SQLCODE = ..#MDXALARMSQLCODE) || ((tSet.%SQLCODE < 0) && (tSet.%Message [ "<ALARM>")) {
                    Set tStopped = 1
                } ElseIf tSet.%SQLCODE < 0 {
                    Set pAnswer = {"outcome": "error", "message": (..Cut(tSet.%Message))}
                } Else {
                    Set pAnswer = {}
                    Do pAnswer.%Set("outcome", "rows", "string")
                    Do pAnswer.%Set("columns", tColumns)
                    Do pAnswer.%Set("rows", tRows)
                    Do pAnswer.%Set("truncated", ''tTruncated, "boolean")
                    Do pAnswer.%Set("seconds", +pSeconds, "number")
                }
                Set (tSet, tMeta) = ""
            }
        } Else {
            Set tAxes = pRS.%GetAxisCount()
            Do ..Positions(pRS, tAxes, .tColsAvail, .tRowsAvail)
            Set tColsShown = $Select(tColsAvail > ..#MDXMAXCOLUMNS: ..#MDXMAXCOLUMNS, 1: tColsAvail)
            Set tRowsShown = $Select(tRowsAvail > ..#MDXMAXROWS: ..#MDXMAXROWS, 1: tRowsAvail)
            Set tTruncated = (tColsShown < tColsAvail) || (tRowsShown < tRowsAvail)
            Set tHeaders = []
            For tC = 1:1:tColsShown {
                Set tLabel = ""
                If tAxes >= 1 {
                    Kill tL
                    Set tN = pRS.%GetOrdinalLabel(.tL, 1, tC)
                    For tI = tN:-1:1 {
                        Set tLabel = tLabel _ $Select(tLabel = "": "", 1: " / ") _ $Get(tL(tI))
                    }
                }
                If $Length(tLabel) > ..#MDXMAXCELL {
                    Set tLabel = $Extract(tLabel, 1, ..#MDXMAXCELL - 1) _ $Char(8230)
                    Set tTruncated = 1
                }
                Do tHeaders.%Push(tLabel, "string")
            }
            ; The answer with no rows, its flag at its longer value, measures everything but the rows.
            Set tFrame = {}
            Do tFrame.%Set("outcome", "cells", "string")
            Do tFrame.%Set("cube", pRS.%GetCubeName(), "string")
            Do tFrame.%Set("columns", tHeaders)
            Do tFrame.%Set("rows", [])
            Do tFrame.%Set("rowsAvailable", tRowsAvail, "number")
            Do tFrame.%Set("columnsAvailable", tColsAvail, "number")
            Do tFrame.%Set("truncated", 0, "boolean")
            Do tFrame.%Set("seconds", +pSeconds, "number")
            Set tTotal = $Length(tFrame.%ToJSON())
            Set tFrame = ""
            Set tRowObjects = []
            For tR = 1:1:tRowsShown {
                Set tLabel = ""
                If tAxes >= 2 {
                    Kill tL
                    Set tN = pRS.%GetOrdinalLabel(.tL, 2, tR)
                    For tI = tN:-1:1 {
                        Set tLabel = tLabel _ $Select(tLabel = "": "", 1: " / ") _ $Get(tL(tI))
                    }
                }
                If $Length(tLabel) > ..#MDXMAXCELL {
                    Set tLabel = $Extract(tLabel, 1, ..#MDXMAXCELL - 1) _ $Char(8230)
                    Set tTruncated = 1
                }
                Set tCells = []
                For tC = 1:1:tColsShown {
                    Set tValue = pRS.%GetOrdinalValue(tC, tR)
                    If $IsObject(tValue) Set tValue = ""
                    If $Length(tValue) > ..#MDXMAXCELL {
                        Set tValue = $Extract(tValue, 1, ..#MDXMAXCELL - 1) _ $Char(8230)
                        Set tTruncated = 1
                    }
                    Do tCells.%Push(tValue, "string")
                }
                Set tRowObject = {}
                Do tRowObject.%Set("label", tLabel, "string")
                Do tRowObject.%Set("cells", tCells)
                Set tLength = $Length(tRowObject.%ToJSON()) + 1
                If tTotal + tLength > ..#MDXMAXANSWER {
                    Set tTruncated = 1
                    Quit
                }
                Set tTotal = tTotal + tLength
                Do tRowObjects.%Push(tRowObject)
            }
            Set pAnswer = {}
            Do pAnswer.%Set("outcome", "cells", "string")
            Do pAnswer.%Set("cube", pRS.%GetCubeName(), "string")
            Do pAnswer.%Set("columns", tHeaders)
            Do pAnswer.%Set("rows", tRowObjects)
            Do pAnswer.%Set("rowsAvailable", tRowsAvail, "number")
            Do pAnswer.%Set("columnsAvailable", tColsAvail, "number")
            Do pAnswer.%Set("truncated", ''tTruncated, "boolean")
            Do pAnswer.%Set("seconds", +pSeconds, "number")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        If tAlarmed Do $System.Alarm.Clear()
        If ex.Name = "<ALARM>" {
            Set tStopped = 1
        } Else {
            Set tCaught = ex
        }
    }
    If tStopped {
        Set pAnswer = {"outcome": "stopped"}
        Quit $$$OK
    }
    If $IsObject(tCaught) {
        Set pAnswer = ""
        Quit ..Mapped(tCaught, "the MDX answer could not be read", .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The column and row positions the answer of the executed SELECT <var>pRS</var>, of <var>pAxes</var> axes, lists: each named axis's
/// own size, so an axis the vendor answered empty has none, and one for an axis the statement does not name. The caller has switched to
/// the result set's namespace.</p>
ClassMethod Positions(pRS, pAxes As %Integer, Output pColumns As %Integer, Output pRows As %Integer) [ Private ]
{
    Set pColumns = $Select(pAxes >= 1: pRS.%GetAxisSize(1), 1: 1)
    Set pRows = $Select(pAxes >= 2: pRS.%GetAxisSize(2), 1: 1)
}

/// <p>The <code>{outcome: "error", message}</code> answer for the vendor status <var>pStatus</var>: the vendor's text, cut at
/// <parameter>MDXMAXCELL</parameter> characters. The text can quote part of the statement and reaches the screen alone (AD-36's sixth
/// exception).</p>
ClassMethod ErrorAnswer(pStatus As %Status) As %DynamicObject
{
    Set tText = ""
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    Quit {"outcome": "error", "message": (..Cut(tText))}
}

/// <p><var>pText</var> cut at <parameter>MDXMAXCELL</parameter> characters with an ellipsis.</p>
ClassMethod Cut(pText As %String) As %String [ Private ]
{
    If $Length(pText) > ..#MDXMAXCELL Quit $Extract(pText, 1, ..#MDXMAXCELL - 1) _ $Char(8230)
    Quit pText
}

/// <p>No script form: this port carries no write (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No script steps: every branch of <method>Invoke</method> is a read (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

}
