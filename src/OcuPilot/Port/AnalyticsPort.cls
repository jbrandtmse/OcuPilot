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
/// <p><b>MDX (Stories 20.33 and 20.35, AD-65).</b> The <code>Mdx*</code> methods run one MDX statement through
/// <code>%DeepSee.ResultSet</code> for the MDX query screen and the agent's MDX read, behind <parameter>MDXPAIRS</parameter>
/// and WRITE on the database the vendor's result cache lives in (<method>MdxAdmit</method>). The statement is untrusted text: it
/// reaches only <code>%PrepareMDX</code>; <method>MdxConstructs</method> is the one detection of the five constructs the vendor
/// splices into SQL or evaluates as ObjectScript (<parameter>MDXCONSTRUCTS</parameter>), read from the vendor's own tokens, run before
/// prepare on the statement and after it on the variable-resolved text (<method>MdxPrepare</method>), and failing closed. Only SELECT
/// (at most two axes) and DRILLTHROUGH run. A drill-through is composed here from the vendor's own filters for one cell
/// (<method>MdxDrill</method>); nothing from a client enters it. The caps are this class's <code>MDX*</code> parameters, each with
/// its reason. The vendor's <code>%CancelQuery</code> checks no owner, so the caller's run row is the owner check.</p>
/// <p><b>The agent's MDX read (Story 20.35).</b> <method>MdxRun</method> is the one run loop of the screen's background run and of the agent's
/// read tool: it starts the prepared result set, polls the vendor and the caller's stop hook, and on the bound or a stop cancels the vendor's
/// query and waits for it to finish. <method>RefuseFor</method> publishes <code>ANALYTICS.MDX.SQL</code>, the refusal of a statement
/// <method>MdxConstructs</method> finds a construct in or cannot read, to a tool that may not name the error class.</p>
/// <p><b>The cube manager (Story 20.34, AD-65, AD-51, AD-53).</b> The <code>CubeManager</code> endpoint lists each cube with its facts, last
/// build, last update, whether it can be synchronized, whether an update runs now, and the cubes that depend on it; its <code>STATE</code>
/// type reads one cube by its exact logical name, judged over the cube and its dependents; its <code>BUILD</code> and
/// <code>SYNCHRONIZE</code> types are the only writes this port makes. They are gated by <parameter>MANAGERPAIRS</parameter> and, beyond
/// the read gate, WRITE on the database <code>^DeepSee.Fact</code> maps to in the namespace, which must be mounted read-write
/// (<method>AdmitDestination</method>). The vendor checks no <code>%DeepSee_*</code> resource and writes no audit event for either, so the
/// gate is this port's and the audit row is OcuPilot's own (<method>AuditWrite</method>). A state the action does not fit is refused by
/// its own code before any vendor call (<method>StateRefusal</method>); the two vendor calls are the seams <method>VendorBuild</method>
/// and <method>VendorSynchronize</method>, each run switched to the namespace inside an output capture, and their answers are mapped by
/// <method>VendorOutcome</method>. The write runs in the request that asks for it, on the vendor's own build agents, and never in a
/// job of this product's (AD-7).</p>
/// <p><b>The term list editor (Story 24.2, AD-65, AD-53).</b> The <code>TermLists</code> and <code>TermListEntries</code> endpoints also serve the
/// single-object reads <code>TERMLIST</code> and <code>TERMLISTENTRY</code> and six writes (<code>ADD</code>, <code>UPDATE</code>, <code>DELETE</code>,
/// <code>ENTRYADD</code>, <code>ENTRYSET</code> and <code>ENTRYREMOVE</code>). A write is gated by <parameter>TERMLISTPAIRS</parameter> and, beyond the read gate, by
/// <method>AdmitTermList</method>: WRITE on the database <code>^DeepSee.TermList</code> maps to, mounted read-write, and journaled. Its shape rules
/// (<method>TermListViolations</method>) and the instance's own state (<method>TermListRefusal</method>, <method>TermListStateViolations</method>) are judged before any
/// vendor call, which the <code>VendorTermList*</code> seams then make, a write of several inside one transaction (<method>PerformTermList</method>). The vendor
/// audits none of them, so each records OcuPilot's own <code>ConfigChange</code> row.</p>
/// <p><b>The term list transfers (Story 24.10, AD-21, AD-65).</b> The <code>TermLists</code> endpoint also serves three reads (<code>EXPORTLIST</code>,
/// <code>IMPORTFILE</code> and <code>COPYTARGET</code>) and three writes (<code>EXPORT</code>, <code>IMPORT</code> and <code>COPY</code>). An export
/// is the vendor's own CSV (<code>%ExportCSV</code>), to a server file or as lines for the browser; it reads only. An import parses its text here
/// (<method>TermListParse</method>, which reads each line with the vendor's <code>%ParseCSVRecord</code>), judges every name, field, key and value by
/// <method>TermListViolations</method> and writes through the same seams as the editor, one transaction for the whole list (<method>WriteWholeList</method>);
/// a copy writes the source's read the same way. Both create a list that is not held and never overwrite one. A server file is a
/// <class>OcuPilot.Port.PathPort</class> resolution (<method>PathPortClass</method>); a local file's text is the caller's value and is stored nowhere.</p>
/// <p><b>The folder manager (Story 24.10, AD-21, AD-65).</b> The <code>FolderItems</code> endpoint also serves three reads (<code>FOLDERITEM</code>,
/// <code>EXPORTITEM</code> and <code>IMPORTFILE</code>) and three writes (<code>EXPORT</code>, <code>IMPORT</code> and <code>DELETE</code>), through
/// <method>InvokeFolderItem</method>. An export is the vendor's own XML (<code>%Export</code>) of one item, to a server file or as lines for the browser; it
/// reads only. An import reads its text first (<method>FolderItemsInText</method>: folder item elements only, never a class, a routine or a folder),
/// refuses a name the instance already holds, and writes with <code>%Import</code> in one transaction, so it creates every item of the file or none; it never
/// loads or compiles a document and never replaces. A delete is <code>%DeleteFolderItem</code>, refused for a locked item. Each write is gated by
/// <parameter>FOLDERPAIRS</parameter> and, beyond the read gate, by <method>AdmitFolderItem</method>; the vendor audits none of them, so each records
/// OcuPilot's own <code>ConfigChange</code> row.</p>
/// <p><b>The listing groups (Story 24.11, AD-65).</b> The <code>ListingGroups</code> endpoint answers the listing groups of the namespace and the
/// <code>ListingGroupListings</code> endpoint one group's listings, under the criterion <parameter>LISTINGGROUPKEY</parameter>; both are reads. The groups are the
/// vendor's own saved list (<code>%DeepSee.ListingGroup.%GetListingGroups</code> with the compiled flag 0, which applies the vendor's filter on each group's
/// <code>resource</code>), <code>Compiled</code> is whether the vendor's compiled list (flag 1) names the same class, and the counts and listings are read from
/// the model <code>%GetModel</code> loads from the class. A group the vendor cannot read has no name and is not listed. A listing's SQL is answered only to a
/// holder of <parameter>LISTINGGROUPSQLPAIRS</parameter> and is <code>""</code> to everyone else.</p>
/// <p><b>The listing group writes (Story 24.11, AD-61, AD-65).</b> The same two endpoints also serve the single-object reads <code>LISTINGGROUP</code>, <code>LISTING</code> and
/// <code>COPYTARGET</code> and seven writes (<method>InvokeListingGroup</method>): a group's add, update, copy and delete and a listing's add, change and remove. A write is gated by
/// <parameter>LISTINGGROUPPAIRS</parameter> and, beyond the read gate, by <method>AdmitListingGroup</method> (the edit pair, the source code API's own pairs, <code>AtelierPort.WritePairs</code> and WRITE on the
/// database <parameter>LISTINGGROUPGLOBAL</parameter> maps to). It composes the whole model from <code>%GetModel</code> read at the write, writes it with the vendor's own XML writer,
/// and saves, compiles and deletes the group's class through <method>AtelierPortClass</method> (<class>OcuPilot.Kernel.SourceDocument</class>), never through the vendor's save and
/// delete calls; a compile the instance refuses puts the class back as it was (<method>PerformListingGroup</method>). The vendor audits none of it, so each write records OcuPilot's
/// own <code>ConfigChange</code> row.</p>
/// <p><b>The quality measures (Story 24.12, AD-65).</b> The <code>QualityMeasures</code> endpoint answers one row per measure name the vendor's
/// <code>%GetQualityMeasureList</code> lists, read through the class the vendor's registry names for it (<code>%GetQualityMeasureClass</code>) and the model
/// <code>%GetModel</code> reads with its link followed; a measure listed with no name is not a row, and a name the registry does not hold is not either.
/// <code>Compiled</code> is <code>$System.OBJ.IsUpToDate</code> of the registered class. The <code>QualityMeasureElements</code> and <code>QualityMeasureMetas</code>
/// endpoints answer one measure's groups with their elements and its documentation items, under the criterion <parameter>QUALITYMEASUREKEY</parameter>; all three are reads.</p>
/// <p>Seams a test subclass overrides: <method>AtelierPortClass</method>, <method>ReadListingGroupData</method>, <method>VendorListingGroupCompose</method>, <method>GateClass</method>, <method>RoutineResource</method>, <method>Collect</method>,
/// <method>LogFault</method>, <method>VendorBuild</method>, <method>VendorSynchronize</method>, <method>DestinationDatabase</method>,
/// <method>DestinationJournaled</method>, <method>ReadTermListData</method>, <method>ReadFolderItem</method>, <method>FolderItemClasses</method>, <method>PathPortClass</method>, the <code>VendorTermList*</code> calls and the <code>VendorFolderItem*</code> calls. Production overrides none.</p>
Class OcuPilot.Port.AnalyticsPort Extends (%RegisteredObject, OcuPilot.Kernel.RowFetch)
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints this port serves, comma-separated. <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems,CubeManager,ListingGroups,ListingGroupListings,QualityMeasures,QualityMeasureElements,QualityMeasureMetas";

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

/// <p>The cube manager: the cubes with their build state, one cube's state, and the two writes (Story 20.34).</p>
Parameter ENDPOINTCUBEMANAGER = "CubeManager";

/// <p>The listing groups of the namespace the caller's resources admit, and one group's listings, under the criterion <parameter>LISTINGGROUPKEY</parameter> (Story 24.11).</p>
Parameter ENDPOINTLISTINGGROUPS = "ListingGroups";

Parameter ENDPOINTLISTINGGROUPLISTINGS = "ListingGroupListings";

/// <p>The quality measures of the namespace (Story 24.12).</p>
Parameter ENDPOINTQUALITYMEASURES = "QualityMeasures";

/// <p>One quality measure's groups with their elements, under the criterion <parameter>QUALITYMEASUREKEY</parameter>.</p>
Parameter ENDPOINTQUALITYMEASUREELEMENTS = "QualityMeasureElements";

/// <p>One quality measure's documentation items, under the criterion <parameter>QUALITYMEASUREKEY</parameter>.</p>
Parameter ENDPOINTQUALITYMEASUREMETAS = "QualityMeasureMetas";

/// <p>The classic Cube Manager's pairs (Story 20.34): the portal's, and <code>%DeepSee.UI.CubeRegistry</code>'s own
/// <code>RESOURCE</code>, which no shipped role but <code>%All</code> holds. They are not adjustable (AD-64).</p>
Parameter MANAGERPAIRS = "%DeepSee_Portal:USE,%DeepSee_Admin:USE";

/// <p>The classic Model Browser's pair: the portal's menu resource, public at USE.</p>
Parameter PORTALPAIRS = "%DeepSee_Portal:USE";

/// <p>The classic Term List Manager's pairs: the portal's, and the one its editor adds.</p>
Parameter TERMLISTPAIRS = "%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE";

/// <p>The classic Folder Manager's pairs, narrowed to the developer resource of its either-of list: the portal's, and
/// <code>%Development:USE</code>.</p>
Parameter FOLDERPAIRS = "%DeepSee_Portal:USE,%Development:USE";

/// <p>The classic Listing Group Manager's pairs, narrowed to the view resource of its either-of list: the portal's, and <code>%DeepSee_ListingGroup:USE</code>.</p>
Parameter LISTINGGROUPPAIRS = "%DeepSee_Portal:USE,%DeepSee_ListingGroup:USE";

/// <p>The classic Quality Measures Manager's pairs: the portal's, and <code>%DeepSee_PortalEdit:USE</code>, the <code>RESOURCE</code> of the classic page.</p>
Parameter QUALITYMEASUREPAIRS = "%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE";

/// <p>The pair a listing's SQL needs to be answered: the classic page's own check for showing the field (<code>CheckListingGroupSQLViewAccess</code>).</p>
Parameter LISTINGGROUPSQLPAIRS = "%DeepSee_ListingGroupSQL:USE";

/// <p>The permission a database read needs.</p>
Parameter READPERMISSION = "READ";

/// <p>The request type every endpoint serves.</p>
Parameter TYPELIST = "LIST";

/// <p>One cube's state on the cube manager, judged over the cube and its dependents (Story 20.34).</p>
Parameter TYPESTATE = "STATE";

/// <p>The cube manager's build and synchronize (Story 20.34): action-style writes over <parameter>TYPESTATE</parameter>.</p>
Parameter TYPEBUILD = "BUILD";

Parameter TYPESYNCHRONIZE = "SYNCHRONIZE";

/// <p>The term list editor (Story 24.2): the single-object reads of a term list and of one entry, and the six writes. Each read also takes
/// <parameter>ACTIONKEY</parameter>, which composes it for the write it precedes.</p>
Parameter TYPETERMLIST = "TERMLIST";

Parameter TYPETERMLISTENTRY = "TERMLISTENTRY";

Parameter TYPEADD = "ADD";

Parameter TYPEUPDATE = "UPDATE";

Parameter TYPEDELETE = "DELETE";

Parameter TYPEENTRYADD = "ENTRYADD";

Parameter TYPEENTRYSET = "ENTRYSET";

Parameter TYPEENTRYREMOVE = "ENTRYREMOVE";

/// <p>The term list transfers (Story 24.10): the three reads a transfer's mint, fingerprint and read-back use, and the three writes.</p>
Parameter TYPEEXPORTLIST = "EXPORTLIST";

Parameter TYPEIMPORTFILE = "IMPORTFILE";

Parameter TYPECOPYTARGET = "COPYTARGET";

Parameter TYPEEXPORT = "EXPORT";

Parameter TYPEIMPORT = "IMPORT";

Parameter TYPECOPY = "COPY";

/// <p>The folder item single-object read (Story 24.10): one item by its full name.</p>
Parameter TYPEFOLDERITEM = "FOLDERITEM";

/// <p>The folder item read composed for the export: the item, echoing the file the query names.</p>
Parameter TYPEEXPORTITEM = "EXPORTITEM";

/// <p>The query keys a transfer carries: the server file, the local file, the digest an import was reviewed with and the copy's new name.
/// <parameter>IMPORTID</parameter> is the target a person's import names when the file's list is not read in the browser.</p>
Parameter ROOTKEY = "root";

Parameter PATHKEY = "path";

Parameter FILENAMEKEY = "fileName";

Parameter CONTENTKEY = "content";

Parameter DIGESTKEY = "digest";

Parameter NEWNAMEKEY = "newName";

Parameter IMPORTID = "import";

/// <p>The endpoint and type pairs that send no body and take their arguments through the query (AD-51 as amended by Story 12.3): the term list
/// export, whose file the port reads from its query, the import, whose file or local text and reviewed digest it reads from its query, and the
/// copy, whose new name it reads from its query (Story 24.10).</p>
Parameter COMPOSEDTYPES = "TermLists/EXPORT,TermLists/IMPORT,TermLists/COPY,FolderItems/EXPORT,FolderItems/IMPORT";

/// <p>An export to a server file replaces a file already there: PathPort's overwrite, which this port declares as a constant, never a caller value.</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The most entries a script form (AD-59) of an import or a copy renders; a list with more has no script form.</p>
Parameter SNIPPETENTRIES As INTEGER = 1000;

/// <p>The global the term lists live in: the destination <method>AdmitTermList</method> judges.</p>
Parameter TERMLISTGLOBAL = "^DeepSee.TermList";

/// <p>The global the folder items live in, whose database a folder item import or delete needs WRITE on.</p>
Parameter FOLDERITEMGLOBAL = "^DeepSee.FolderItemD";

Parameter ENTITYFOLDERITEM = "folder-item";

Parameter VERBFOLDERITEMEXPORT = "analytics.folderitems.export";

Parameter VERBFOLDERITEMIMPORT = "analytics.folderitems.import";

Parameter VERBFOLDERITEMDELETE = "analytics.folderitems.delete";

/// <p>The most folder items one import file may hold, counted before any write.</p>
Parameter MAXIMPORTITEMS As INTEGER = 100;

/// <p>The declaration the vendor's export writes at the head of a file, which its export to a stream leaves out, so an export to this browser reads as the
/// file does.</p>
Parameter XMLDECLARATION = "<?xml version=""1.0"" encoding=""UTF-8""?>";

/// <p>The flags an import file is parsed with: the SAX defaults and no document type definition, so no entity of the file is ever resolved.</p>
Parameter XMLPARSEFLAGS As INTEGER = 155;

/// <p>The audit entity types and the verbs, the tools' own names, of the term list writes (AD-15).</p>
Parameter ENTITYTERMLIST = "term-list";

Parameter ENTITYTERMLISTENTRY = "term-list-entry";

Parameter VERBTERMLISTADD = "analytics.termlists.add";

Parameter VERBTERMLISTUPDATE = "analytics.termlists.update";

Parameter VERBTERMLISTDELETE = "analytics.termlists.delete";

Parameter VERBENTRYADD = "analytics.termlistentries.add";

Parameter VERBENTRYSET = "analytics.termlistentries.set";

Parameter VERBENTRYREMOVE = "analytics.termlistentries.remove";

Parameter VERBTERMLISTEXPORT = "analytics.termlists.export";

Parameter VERBTERMLISTIMPORT = "analytics.termlists.import";

Parameter VERBTERMLISTCOPY = "analytics.termlists.copy";

/// <p>The most characters of a term list name or an entry key, of a caption, pattern or subject area, and of a description or value, and the
/// most fields one list holds: the vendor's own limits (measured) and the editor's bound.</p>
Parameter NAMEMAX As INTEGER = 255;

Parameter SHORTTEXTMAX As INTEGER = 255;

Parameter LONGTEXTMAX As INTEGER = 32000;

Parameter FIELDSMAX As INTEGER = 50;

/// <p>The field the vendor keeps an entry's own value under.</p>
Parameter VALUEFIELD = "VALUE";

/// <p>The query key naming the cube a <code>STATE</code> or a write is about, kept exactly (AD-13).</p>
Parameter IDKEY = "id";

/// <p>The query key a <code>STATE</code> read composed for an action carries: the write type the read is made for.</p>
Parameter ACTIONKEY = "action";

/// <p>The global whose database a build or synchronize writes, and the global the MDX cache lives in: the two destinations
/// <method>AdmitDestination</method> judges.</p>
Parameter FACTGLOBAL = "^DeepSee.Fact";

Parameter CACHEGLOBAL = "^DeepSee.Cache.Results";

/// <p>The audit entity type and verbs of the cube manager's writes (AD-15).</p>
Parameter ENTITYCUBE = "cube";

Parameter VERBBUILD = "build";

Parameter VERBSYNCHRONIZE = "synchronize";

/// <p>The vendor's status codes a build or synchronize answer is mapped from: the cube lock, the build's error count, a cube that does
/// not exist.</p>
Parameter CODELOCK = 20005;

Parameter CODEBUILDERRORS = 20006;

Parameter CODENOCUBE = 20013;

/// <p>The most characters of what the vendor wrote to the device that a log line quotes.</p>
Parameter WRITTENMAX As INTEGER = 1000;

/// <p>How the dependent cubes of a row are joined.</p>
Parameter DEPENDENTSEPARATOR = ", ";

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

/// <p>The query key naming a listing group, for its listings.</p>
Parameter LISTINGGROUPKEY = "listinggroup";

/// <p>The query key naming a quality measure, for its elements and its documentation.</p>
Parameter QUALITYMEASUREKEY = "qualitymeasure";

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

/// <p>The seconds between the run loop's looks at the vendor's query and at the caller's stop hook.</p>
Parameter MDXPOLLPAUSE = 0.1;

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

Parameter REASONFOLDERITEMREQUIRED = "Name the folder item.";

/// <p>The listing group editor's request types (Story 24.11): the single-object reads of a group and of one listing. Its writes reuse
/// <parameter>TYPEADD</parameter>, <parameter>TYPEUPDATE</parameter>, <parameter>TYPEDELETE</parameter>, <parameter>TYPECOPY</parameter> and, for a listing,
/// <parameter>TYPEENTRYADD</parameter>, <parameter>TYPEENTRYSET</parameter> and <parameter>TYPEENTRYREMOVE</parameter>; its copy read is <parameter>TYPECOPYTARGET</parameter>.</p>
Parameter TYPELISTINGGROUP = "LISTINGGROUP";

Parameter TYPELISTING = "LISTING";

Parameter ENTITYLISTINGGROUP = "listing-group";

Parameter ENTITYLISTING = "listing-group-listing";

Parameter VERBLISTINGGROUPADD = "analytics.listinggroups.add";

Parameter VERBLISTINGGROUPUPDATE = "analytics.listinggroups.update";

Parameter VERBLISTINGGROUPCOPY = "analytics.listinggroups.copy";

Parameter VERBLISTINGGROUPDELETE = "analytics.listinggroups.delete";

Parameter VERBLISTINGADD = "analytics.listinggrouplistings.add";

Parameter VERBLISTINGSET = "analytics.listinggrouplistings.set";

Parameter VERBLISTINGREMOVE = "analytics.listinggrouplistings.remove";

/// <p>The global whose database the listing group writes need WRITE on.</p>
Parameter LISTINGGROUPGLOBAL = "^DeepSee.ListingGroups";

/// <p>What a listing group write needs beyond the view pairs: the classic Listing Group Manager's edit resource.</p>
Parameter LISTINGGROUPEDITPAIRS = "%DeepSee_ListingGroupEdit:USE";

/// <p>The query keys of a copy: the new group's class and, optionally, its target cubes (its name is <parameter>NEWNAMEKEY</parameter>).</p>
Parameter NEWCLASSKEY = "newClass";

Parameter TARGETCUBESKEY = "targetCubes";

/// <p>The longest listing group or listing name: the length of the vendor's entity name.</p>
Parameter LISTINGNAMEMAX As INTEGER = 250;

Parameter REASONLISTINGGROUPREQUIRED = "Name the listing group.";

/// <p>The published sentence of the cube refusal <var>pCode</var>, <code>""</code> for a code this port does not declare, for the tools
/// that may not name <class>OcuPilot.Api.AnalyticsError</class>.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.AnalyticsError).ReasonFor(pCode)
}

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
/// pairs, the term lists and their entries the Term List Manager's, the folder items the Folder Manager's, the listing groups and their listings the Listing Group Manager's and the quality measures with their two tabs the Quality Measures Manager's.</p>
ClassMethod Pairs(pEndpoint As %String) As %List
{
    If $ListFind($ListBuild(..#ENDPOINTCUBES, ..#ENDPOINTMEASURES, ..#ENDPOINTDIMENSIONS, ..#ENDPOINTRELATIONSHIPS), pEndpoint) {
        Set tSpec = ..#PORTALPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTCUBEMANAGER {
        Set tSpec = ..#MANAGERPAIRS
    } ElseIf $ListFind($ListBuild(..#ENDPOINTTERMLISTS, ..#ENDPOINTTERMLISTENTRIES), pEndpoint) {
        Set tSpec = ..#TERMLISTPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTFOLDERITEMS {
        Set tSpec = ..#FOLDERPAIRS
    } ElseIf $ListFind($ListBuild(..#ENDPOINTLISTINGGROUPS, ..#ENDPOINTLISTINGGROUPLISTINGS), pEndpoint) {
        Set tSpec = ..#LISTINGGROUPPAIRS
    } ElseIf $ListFind($ListBuild(..#ENDPOINTQUALITYMEASURES, ..#ENDPOINTQUALITYMEASUREELEMENTS, ..#ENDPOINTQUALITYMEASUREMETAS), pEndpoint) {
        Set tSpec = ..#QUALITYMEASUREPAIRS
    } Else {
        Quit ""
    }
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>: <code>LIST</code> on every endpoint; and, on the
/// cube manager, <code>STATE</code>, <code>BUILD</code> and <code>SYNCHRONIZE</code>, on the two term list endpoints their single-object read and writes, and on the
/// folder items (<method>IsFolderItemType</method>) their three reads and three writes.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
    If pEndpoint = ..#ENDPOINTTERMLISTS Quit (pType = ..#TYPETERMLIST) || (pType = ..#TYPEADD) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPEDELETE) || ..IsTermListTransfer(pType)
    If pEndpoint = ..#ENDPOINTTERMLISTENTRIES Quit (pType = ..#TYPETERMLISTENTRY) || (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    If pEndpoint = ..#ENDPOINTFOLDERITEMS Quit ..IsFolderItemType(pType)
    If pEndpoint = ..#ENDPOINTLISTINGGROUPS Quit (pType = ..#TYPELISTINGGROUP) || (pType = ..#TYPECOPYTARGET) || (pType = ..#TYPEADD) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPECOPY)
    If pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS Quit (pType = ..#TYPELISTING) || (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    Quit (pEndpoint = ..#ENDPOINTCUBEMANAGER) && ((pType = ..#TYPESTATE) || ..IsWrite(pType))
}

/// <p>Whether <var>pType</var> is one of the term list editor's six writes (Story 24.2) or its three transfers' (Story 24.10).</p>
ClassMethod IsTermListWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADD) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE) || (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPECOPY)
}

/// <p>Whether <var>pType</var> is one of the three term list transfer reads or three transfer writes (Story 24.10).</p>
ClassMethod IsTermListTransfer(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEEXPORTLIST) || (pType = ..#TYPEIMPORTFILE) || (pType = ..#TYPECOPYTARGET) || (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPECOPY)
}

/// <p>Whether <var>pType</var>, with <var>pAction</var> as the write it is composed for (<code>""</code> for a plain read), changes a term list and
/// so needs the destination's gate (<method>AdmitTermList</method>): a write other than an export, which reads only, and a single-object read
/// composed for such a write. Pure.</p>
ClassMethod ChangesTermLists(pType As %String, pAction As %String = "") As %Boolean
{
    If pType = ..#TYPEEXPORT Quit 0
    If ..IsTermListWrite(pType) Quit 1
    If (pAction = "") || (pAction = ..#TYPEEXPORT) Quit 0
    Quit (pType = ..#TYPETERMLIST) || (pType = ..#TYPETERMLISTENTRY) || (pType = ..#TYPEIMPORTFILE) || (pType = ..#TYPECOPYTARGET)
}

/// <p>Whether <var>pType</var> is one of the term list editor's two single-object reads or its six writes.</p>
ClassMethod IsTermListType(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPETERMLIST) || (pType = ..#TYPETERMLISTENTRY) || ..IsTermListWrite(pType) || ..IsTermListTransfer(pType)
}

/// <p>Whether <var>pType</var> is one of this port's two writes, the cube manager's build and synchronize (Story 20.34).</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEBUILD) || (pType = ..#TYPESYNCHRONIZE)
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
/// <li>ListingGroups: <code>{Name, Caption, Cubes, Class, Compiled, Listings, Disabled, Description, Resource, DefaultResource}</code>, <code>Cubes</code> the
/// model's target cubes as written, <code>Compiled</code> whether the vendor's compiled list names this group's class, <code>Listings</code> the number of listings the group holds.</li>
/// <li>ListingGroupListings: <code>{ListingGroup, Name, DisplayName, Type, Fields, OrderBy, Joins, Formats, Source, Resource, SelectMode, Disabled, Description, SQL}</code>, the
/// listings of the group the criterion <parameter>LISTINGGROUPKEY</parameter> names, <code>SQL</code> <code>""</code> unless the caller holds <parameter>LISTINGGROUPSQLPAIRS</parameter>.</li>
/// <li>QualityMeasures: <code>{Name, Catalog, Set, Id, Caption, Description, SubjectArea, Expression, LinkedTo, Published, Format, Href, Class, Compiled, Groups}</code>, one row per
/// measure name, <code>Class</code> the class the registry names for it, <code>Groups</code> the number of groups its model holds.</li>
/// <li>QualityMeasureElements: <code>{QualityMeasure, Group, GroupCaption, GroupDescription, GroupDisabled, Name, Caption, MDX, Disabled}</code>, one row per element of the measure
/// the criterion <parameter>QUALITYMEASUREKEY</parameter> names, a group with no element one row with empty element fields.</li>
/// <li>QualityMeasureMetas: <code>{QualityMeasure, Name, Caption, Section, Content, Disabled}</code>, one row per documentation item of that measure.</li>
/// <li>CubeManager: <code>{Name, Caption, Facts, LastBuild, LastUpdate, Synchronizes, Updating, DependentCubes}</code>, the cubes of
/// Cubes with the time of the last build or synchronize (<code>LastUpdate</code>), whether the source records changes
/// (<code>Synchronizes</code>), whether this cube is being built or synchronized now (<code>Updating</code>) and the cubes that
/// depend on it, sorted and joined with <parameter>DEPENDENTSEPARATOR</parameter>. Its <code>STATE</code>, <code>BUILD</code> and
/// <code>SYNCHRONIZE</code> types take the cube under <parameter>IDKEY</parameter> (<method>InvokeCubeManager</method>).</li>
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
    Set tLevel = $TLevel
    Try {
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        ; A write, and a STATE read composed for one, is judged against the fact database as well as the read gate.
        Set tChanges = $Select(pEndpoint = ..#ENDPOINTFOLDERITEMS: ..ChangesFolderItems(pType, $Get(pQuery(..#ACTIONKEY))), ..IsListingGroupEndpoint(pEndpoint): ..ChangesListingGroups(pType, $Get(pQuery(..#ACTIONKEY))), 1: ..ChangesTermLists(pType, $Get(pQuery(..#ACTIONKEY))))
        Set tWrite = ..IsWrite(pType) || tChanges || ((pType = ..#TYPESTATE) && ($Get(pQuery(..#ACTIONKEY)) '= ""))
        Set tSC = ..Admit(pEndpoint, tNamespace, tWrite, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If (pEndpoint = ..#ENDPOINTFOLDERITEMS) && (pType '= ..#TYPELIST) {
            Set tSC = ..InvokeFolderItem(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsListingGroupEndpoint(pEndpoint) && (pType '= ..#TYPELIST) {
            Set tSC = ..InvokeListingGroup(tNamespace, pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsTermListType(pType) {
            Set tSC = ..InvokeTermList(tNamespace, pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType '= ..#TYPELIST {
            Set tSC = ..InvokeCubeManager(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }

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
        } ElseIf pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS {
            ; A criterion that names no group answers no rows, and an empty one names none.
            Set tCriterion = $Get(pQuery(..#LISTINGGROUPKEY))
        } ElseIf $ListFind($ListBuild(..#ENDPOINTQUALITYMEASUREELEMENTS, ..#ENDPOINTQUALITYMEASUREMETAS), pEndpoint) {
            ; A criterion that names no measure answers no rows, and an empty one names none.
            Set tCriterion = $Get(pQuery(..#QUALITYMEASUREKEY))
        }
        ; A listing's SQL is answered to a holder of its own pair only; the pair is judged here, where the gate class is visible (AD-16).
        Set tShowSQL = 0
        If pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS Set tShowSQL = $ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#LISTINGGROUPSQLPAIRS))

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
        Set pResult = ..Rows(pEndpoint, .tData, tShowSQL)
        Set pHttpStatus = 200
    } Catch ex {
        While $TLevel > tLevel {
            TROLLBACK 1
        }
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>This port's gate (AD-29, AD-65), evaluated before any vendor call for <var>pEndpoint</var> in <var>pNamespace</var>, in this
/// order: the endpoint's pairs; the namespace's shape; the namespace reporting analytics; READ on its globals database; READ on its
/// routines database; and, when <var>pWrite</var> (a build or synchronize, or the read composed for one), WRITE on the database
/// <parameter>FACTGLOBAL</parameter> maps to, which must be mounted read-write (<method>AdmitDestination</method>). A refusal is an
/// error status with <var>pHttpStatus</var> and <var>pFault</var> set as <method>Invoke</method> answers them. Names no vendor class.</p>
ClassMethod Admit(pEndpoint As %String, pNamespace As %String, pWrite As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tSC = ..AdmitNamespace(pNamespace, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || 'pWrite Quit tSC
    If (pEndpoint = ..#ENDPOINTTERMLISTS) || (pEndpoint = ..#ENDPOINTTERMLISTENTRIES) Quit ..AdmitTermList(pNamespace, .pHttpStatus, .pFault)
    If pEndpoint = ..#ENDPOINTFOLDERITEMS Quit ..AdmitFolderItem(pNamespace, .pHttpStatus, .pFault)
    If ..IsListingGroupEndpoint(pEndpoint) Quit ..AdmitListingGroup(pNamespace, .pHttpStatus, .pFault)
    Quit ..AdmitDestination(pNamespace, ..#FACTGLOBAL, ##class(OcuPilot.Api.AnalyticsError).#CUBEREADONLY, .pHttpStatus, .pFault)
}

/// <p>The destination half of a write's gate (AD-29, AD-65): WRITE on the database <var>pGlobal</var> maps to in <var>pNamespace</var>
/// (a refusal naming the failed pair), and that database mounted read-write (409 <var>pReadOnlyCode</var>). 400
/// <code>PORT.VALIDATION</code> when the instance cannot name the database. One check for the MDX cache and for the facts. Names no
/// vendor class.</p>
ClassMethod AdmitDestination(pNamespace As %String, pGlobal As %String, pReadOnlyCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    Set tResource = ""
    Set tReadOnly = 0
    Set tMounted = 0
    If '..DestinationDatabase(pNamespace, pGlobal, .tResource, .tReadOnly, .tMounted) || (tResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tResource, ..#WRITEPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If tReadOnly || 'tMounted Quit ..Conflict(pReadOnlyCode, .pHttpStatus, .pFault)
    Quit $$$OK
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
/// <var>pCriterion</var> is the cube or term list a tab names, the listing group whose listings are read, or the quality measure whose groups or documentation are read, matched without regard to case as the vendor keys it. A vendor status that is an error is <var>pVendorStatus</var>; an
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
        If (pEndpoint = ..#ENDPOINTCUBES) || (pEndpoint = ..#ENDPOINTCUBEMANAGER) {
            Set pVendorStatus = ##class(%DeepSee.Utils).%GetCubeList(.tList, "cubes", 1)
            Set tKey = ""
            While $$$ISOK(pVendorStatus) {
                Set tKey = $Order(tList(tKey))
                If tKey = "" Quit
                If (pMax > 0) && (pData >= pMax) Quit
                Set tCube = $List(tList(tKey), 1)
                If pEndpoint = ..#ENDPOINTCUBEMANAGER {
                    Set pData = pData + 1
                    Set pData(pData) = ..CubeNodeHere(tCube, $List(tList(tKey), 2), 1, .tList)
                    Continue
                }
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
        } ElseIf (pEndpoint = ..#ENDPOINTLISTINGGROUPS) || (pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS) {
            ; The vendor's saved list applies its own filter on each group's resource; its compiled list names the classes whose compile registered them.
            ; %GetModel answers a model with no name for a class whose definition it cannot read, so such a group is not a row.
            Set pVendorStatus = ##class(%DeepSee.ListingGroup).%GetListingGroups(.tSaved, 0)
            If $$$ISOK(pVendorStatus) Set pVendorStatus = ##class(%DeepSee.ListingGroup).%GetListingGroups(.tCompiled, 1)
            If (pEndpoint = ..#ENDPOINTLISTINGGROUPS) && $$$ISOK(pVendorStatus) {
                Set tGroup = ""
                For {
                    Set tGroup = $Order(tSaved(tGroup))
                    If tGroup = "" Quit
                    Set tAt = ""
                    For {
                        Set tAt = $Order(tSaved(tGroup, tAt))
                        If tAt = "" Quit
                        If (pMax > 0) && (pData >= pMax) Quit
                        Set tClass = $List(tSaved(tGroup, tAt), 5)
                        Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(tClass)
                        If '$IsObject(tModel) || (tModel.name = "") Continue
                        Set tIsCompiled = $Data(tCompiled(tGroup, 1)) && ($List(tCompiled(tGroup, 1), 5) = tClass)
                        Set pData = pData + 1
                        Set pData(pData) = $ListBuild(tModel.name, $List(tSaved(tGroup, tAt), 3), tModel.targetCubes, tClass, ''tIsCompiled, tModel.listings.Count(), ''tModel.disabled, tModel.description, tModel.resource, tModel.defaultResource)
                    }
                    If (pMax > 0) && (pData >= pMax) Quit
                }
            } ElseIf (pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS) && $$$ISOK(pVendorStatus) {
                Set tGroup = $ZConvert(pCriterion, "U")
                If (tGroup '= "") && $Data(tSaved(tGroup)) {
                    ; Two classes can name one group; the compiled one answers, else the first saved.
                    Set tClass = $List(tSaved(tGroup, 1), 5)
                    Set tAt = ""
                    For {
                        Set tAt = $Order(tSaved(tGroup, tAt))
                        If tAt = "" Quit
                        If $Data(tCompiled(tGroup, 1)) && ($List(tCompiled(tGroup, 1), 5) = $List(tSaved(tGroup, tAt), 5)) {
                            Set tClass = $List(tSaved(tGroup, tAt), 5)
                            Quit
                        }
                    }
                    Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(tClass)
                    If $IsObject(tModel) && (tModel.name '= "") {
                        For tAt = 1:1:tModel.listings.Count() {
                            If (pMax > 0) && (pData >= pMax) Quit
                            Set tListing = tModel.listings.GetAt(tAt)
                            Set pData = pData + 1
                            Set pData(pData) = $ListBuild(tModel.name, tListing.name, tListing.displayName, tListing.listingType, tListing.fieldList, tListing.orderBy, tListing.joinInfo, tListing.formatList, tListing.sourceClass, tListing.resource, tListing.selectMode, ''tListing.disabled, tListing.description, tListing.sql)
                        }
                    }
                }
            }
        } ElseIf $ListFind($ListBuild(..#ENDPOINTQUALITYMEASURES, ..#ENDPOINTQUALITYMEASUREELEMENTS, ..#ENDPOINTQUALITYMEASUREMETAS), pEndpoint) {
            ; The vendor's list names each measure once per class declaring it and gives a disabled measure no name; the registry answers one class per name.
            Set pVendorStatus = $$$OK
            If pEndpoint = ..#ENDPOINTQUALITYMEASURES {
                Set pVendorStatus = ##class(%DeepSee.QualityMeasure.Utils).%GetQualityMeasureList(.tList)
                Set tAt = ""
                While $$$ISOK(pVendorStatus) {
                    Set tAt = $Order(tList(tAt))
                    If tAt = "" Quit
                    Set tListed = $List(tList(tAt), 1)
                    If (tListed = "") || $Data(tNameSeen($ZConvert(tListed, "U"))) Continue
                    Set tNameSeen($ZConvert(tListed, "U")) = ""
                    Set tNames($Increment(tNames)) = $ListBuild(tListed, $List(tList(tAt), 5))
                }
            } ElseIf pCriterion '= "" {
                Set tNames = 1
                Set tNames(1) = $ListBuild(pCriterion, "")
            }
            For tAt = 1:1:+$Get(tNames) {
                If (pMax > 0) && (pData >= pMax) Quit
                Set tName = $List(tNames(tAt), 1)
                Set tClass = ##class(%DeepSee.QualityMeasure.Utils).%GetQualityMeasureClass(tName, .tFound)
                If $$$ISERR(tFound) || (tClass = "") Continue
                Set tModel = ##class(%DeepSee.QualityMeasure.Utils).%GetModel(tName, .tModelStatus, 1)
                If pEndpoint = ..#ENDPOINTQUALITYMEASURES {
                    Set tIsCompiled = ''$System.OBJ.IsUpToDate(tClass)
                    Set pData = pData + 1
                    If $IsObject(tModel) {
                        Set pData(pData) = $ListBuild(tName, tModel.catalog, tModel.set, tModel.id, tModel.caption, tModel.description, tModel.subjectArea, tModel.expression, tModel.linkedTo, ''tModel.published, tModel.format, tModel.href, tClass, tIsCompiled, tModel.groups.Count())
                    } Else {
                        Set pData(pData) = $ListBuild(tName, $Piece(tName, "/", 1), $Piece(tName, "/", 2), $Piece(tName, "/", 3), $List(tNames(tAt), 2), "", "", "", "", 0, "", "", tClass, tIsCompiled, 0)
                    }
                    Continue
                }
                ; A model the vendor cannot read, or one that is not the measure the criterion names, has no rows.
                If '$IsObject(tModel) || ($ZConvert(tModel.name, "U") '= $ZConvert(pCriterion, "U")) Continue
                If pEndpoint = ..#ENDPOINTQUALITYMEASUREELEMENTS {
                    For tGroupAt = 1:1:tModel.groups.Count() {
                        If (pMax > 0) && (pData >= pMax) Quit
                        Set tGroupObject = tModel.groups.GetAt(tGroupAt)
                        If tGroupObject.elements.Count() = 0 {
                            Set pData = pData + 1
                            Set pData(pData) = $ListBuild(tModel.name, tGroupObject.name, tGroupObject.caption, tGroupObject.description, ''tGroupObject.disabled, "", "", "", 0)
                            Continue
                        }
                        For tElementAt = 1:1:tGroupObject.elements.Count() {
                            If (pMax > 0) && (pData >= pMax) Quit
                            Set tElement = tGroupObject.elements.GetAt(tElementAt)
                            Set pData = pData + 1
                            Set pData(pData) = $ListBuild(tModel.name, tGroupObject.name, tGroupObject.caption, tGroupObject.description, ''tGroupObject.disabled, tElement.name, tElement.caption, tElement.mdx, ''tElement.disabled)
                        }
                    }
                } Else {
                    For tMetaAt = 1:1:tModel.metas.Count() {
                        If (pMax > 0) && (pData >= pMax) Quit
                        Set tMeta = tModel.metas.GetAt(tMetaAt)
                        Set pData = pData + 1
                        Set pData(pData) = $ListBuild(tModel.name, tMeta.name, tMeta.caption, tMeta.section, tMeta.content, ''tMeta.disabled)
                    }
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
/// objects. Text is typed as text, so a name that reads as a number stays a string. A listing's <code>SQL</code> is shaped only when <var>pShowSQL</var> is true.</p>
ClassMethod Rows(pEndpoint As %String, ByRef pData, pShowSQL As %Boolean = 0) As %DynamicArray [ Private ]
{
    Set tRows = []
    For tAt = 1:1:pData {
        Set tValues = pData(tAt)
        Set tRow = {}
        If pEndpoint = ..#ENDPOINTCUBEMANAGER {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Caption", $List(tValues, 2), "string")
            If $List(tValues, 3) = "" {
                Do tRow.%Set("Facts", "", "null")
            } Else {
                Do tRow.%Set("Facts", +$List(tValues, 3), "number")
            }
            Do tRow.%Set("LastBuild", ..BuildStamp($List(tValues, 4)), "string")
            Do tRow.%Set("LastUpdate", ..BuildStamp($List(tValues, 5)), "string")
            Do tRow.%Set("Synchronizes", $List(tValues, 7), "boolean")
            Do tRow.%Set("Updating", $List(tValues, 8), "boolean")
            Do tRow.%Set("DependentCubes", $List(tValues, 10), "string")
        } ElseIf pEndpoint = ..#ENDPOINTCUBES {
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
        } ElseIf pEndpoint = ..#ENDPOINTLISTINGGROUPS {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Caption", $List(tValues, 2), "string")
            Do tRow.%Set("Cubes", $List(tValues, 3), "string")
            Do tRow.%Set("Class", $List(tValues, 4), "string")
            Do tRow.%Set("Compiled", $List(tValues, 5), "boolean")
            Do tRow.%Set("Listings", $List(tValues, 6), "number")
            Do tRow.%Set("Disabled", $List(tValues, 7), "boolean")
            Do tRow.%Set("Description", $List(tValues, 8), "string")
            Do tRow.%Set("Resource", $List(tValues, 9), "string")
            Do tRow.%Set("DefaultResource", $List(tValues, 10), "string")
        } ElseIf pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS {
            Do tRow.%Set("ListingGroup", $List(tValues, 1), "string")
            Do tRow.%Set("Name", $List(tValues, 2), "string")
            Do tRow.%Set("DisplayName", $List(tValues, 3), "string")
            Do tRow.%Set("Type", $List(tValues, 4), "string")
            Do tRow.%Set("Fields", $List(tValues, 5), "string")
            Do tRow.%Set("OrderBy", $List(tValues, 6), "string")
            Do tRow.%Set("Joins", $List(tValues, 7), "string")
            Do tRow.%Set("Formats", $List(tValues, 8), "string")
            Do tRow.%Set("Source", $List(tValues, 9), "string")
            Do tRow.%Set("Resource", $List(tValues, 10), "string")
            Do tRow.%Set("SelectMode", $List(tValues, 11), "string")
            Do tRow.%Set("Disabled", $List(tValues, 12), "boolean")
            Do tRow.%Set("Description", $List(tValues, 13), "string")
            Do tRow.%Set("SQL", $Select(pShowSQL: $List(tValues, 14), 1: ""), "string")
        } ElseIf pEndpoint = ..#ENDPOINTQUALITYMEASURES {
            Do tRow.%Set("Name", $List(tValues, 1), "string")
            Do tRow.%Set("Catalog", $List(tValues, 2), "string")
            Do tRow.%Set("Set", $List(tValues, 3), "string")
            Do tRow.%Set("Id", $List(tValues, 4), "string")
            Do tRow.%Set("Caption", $List(tValues, 5), "string")
            Do tRow.%Set("Description", $List(tValues, 6), "string")
            Do tRow.%Set("SubjectArea", $List(tValues, 7), "string")
            Do tRow.%Set("Expression", $List(tValues, 8), "string")
            Do tRow.%Set("LinkedTo", $List(tValues, 9), "string")
            Do tRow.%Set("Published", $List(tValues, 10), "boolean")
            Do tRow.%Set("Format", $List(tValues, 11), "string")
            Do tRow.%Set("Href", $List(tValues, 12), "string")
            Do tRow.%Set("Class", $List(tValues, 13), "string")
            Do tRow.%Set("Compiled", $List(tValues, 14), "boolean")
            Do tRow.%Set("Groups", $List(tValues, 15), "number")
        } ElseIf pEndpoint = ..#ENDPOINTQUALITYMEASUREELEMENTS {
            Do tRow.%Set("QualityMeasure", $List(tValues, 1), "string")
            Do tRow.%Set("Group", $List(tValues, 2), "string")
            Do tRow.%Set("GroupCaption", $List(tValues, 3), "string")
            Do tRow.%Set("GroupDescription", $List(tValues, 4), "string")
            Do tRow.%Set("GroupDisabled", $List(tValues, 5), "boolean")
            Do tRow.%Set("Name", $List(tValues, 6), "string")
            Do tRow.%Set("Caption", $List(tValues, 7), "string")
            Do tRow.%Set("MDX", $List(tValues, 8), "string")
            Do tRow.%Set("Disabled", $List(tValues, 9), "boolean")
        } ElseIf pEndpoint = ..#ENDPOINTQUALITYMEASUREMETAS {
            Do tRow.%Set("QualityMeasure", $List(tValues, 1), "string")
            Do tRow.%Set("Name", $List(tValues, 2), "string")
            Do tRow.%Set("Caption", $List(tValues, 3), "string")
            Do tRow.%Set("Section", $List(tValues, 4), "string")
            Do tRow.%Set("Content", $List(tValues, 5), "string")
            Do tRow.%Set("Disabled", $List(tValues, 6), "boolean")
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

/// <p>The refusal a tool names by <var>pWhich</var>, so that a tool, which may not name the error class, can publish it:
/// <code>sql</code> (422 <code>ANALYTICS.MDX.SQL</code>, a statement <method>MdxConstructs</method> finds a construct in or cannot read) and
/// <code>input</code> (400 <code>ANALYTICS.MDX.INPUT</code>, a drill of a statement whose answer has no cells). Any other name is 500 <code>INTERNAL</code>, logged.</p>
ClassMethod RefuseFor(pWhich As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pWhich = "sql" Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#MDXSQL, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXSQL, .pHttpStatus, .pFault)
    If pWhich = "input" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#MDXINPUT, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXINPUT, .pHttpStatus, .pFault)
    Quit ..Fail("an agent tool asked for a refusal the port does not publish", $$$ERROR($$$GeneralError, pWhich), .pHttpStatus, .pFault)
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
    Quit ..AdmitDestination(pNamespace, ..#CACHEGLOBAL, ##class(OcuPilot.Api.AnalyticsError).#MDXREADONLY, .pHttpStatus, .pFault)
}

/// <p>The guarding resource and mount state of the database <var>pGlobal</var> maps to in <var>pNamespace</var>, as
/// <method>%SYS.Namespace.GetGlobalDest</method> and <method>%SYS.Namespace.GetNSInfo</method> report them; 0 when the instance reports
/// none, which a caller refuses rather than admits. A <code>%</code>-class that answers in any namespace, so no switch is taken
/// (AD-16). Overridable so a fixture can name another database; production never overrides it.</p>
ClassMethod DestinationDatabase(pNamespace As %String, pGlobal As %String, Output pResource As %String, Output pReadOnly As %Boolean, Output pMounted As %Boolean) As %Boolean
{
    Set pResource = ""
    Set pReadOnly = 0
    Set pMounted = 0
    Set tResolved = 0
    Try {
        Set tDest = ##class(%SYS.Namespace).GetGlobalDest($ZConvert(pNamespace, "U"), pGlobal)
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
/// <p><b>A query whose cells a plug-in computes</b> (<code>%KPI("%DeepSee.Median", ...)</code>) reports 100 while those cells still read
/// <code>@Computing 0.00%</code>, and flags them pending (measured). This asks the vendor to update them, as its own synchronous execute does,
/// and answers 99 until none is pending, so 100 means every cell holds its value. A failed update is 100 with its error.</p>
/// <p>With <var>pUpdate</var> 0 it updates nothing and answers the vendor's own status, 100 with cells still pending included: a stopped
/// run's wait (<method>Settle</method>) computes no cell, and the vendor's cancel does not reach a query it already reports 100.</p>
ClassMethod MdxStatus(pNamespace As %String, pRS, Output pError As %Status, pUpdate As %Boolean = 1) As %Integer
{
    Set pError = $$$OK
    Set tStatus = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatus = pRS.%GetStatus(, .pError, .tPending)
        If pUpdate && (tStatus = 100) && tPending && $$$ISOK(pError) {
            Set tUpdateSC = pRS.%UpdatePendingResults(.tPending)
            If $$$ISERR(tUpdateSC) {
                Set pError = tUpdateSC
            } Else {
                ; Read again: the vendor switches a finished query to its local cache only when none is pending.
                Set tStatus = pRS.%GetStatus(, .pError, .tPending)
                If (tStatus = 100) && tPending && $$$ISOK(pError) Set tStatus = 99
            }
        }
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

/// <p>Run the prepared result set <var>pRS</var> of <var>pNamespace</var> to its answer, bounded by <var>pBound</var> seconds and by the
/// caller's stop hook: the one run loop of MDX query's background run and of the agent's MDX read (Story 20.35).</p>
/// <ol>
/// <li>The statement: <method>MdxStart</method> under an alarm of the time that remains, because the vendor resolves the statement's members,
/// and runs any SQL they name, inside the start. A DRILLTHROUGH's start is its whole wait; a SELECT is then polled every
/// <parameter>MDXPOLLPAUSE</parameter> seconds.</li>
/// <li>A cell's drill, when <var>pRow</var> and <var>pColumn</var> are not empty: <method>MdxDrill</method>, then the same wait on its
/// listing.</li>
/// <li>The answer: <method>MdxAnswer</method>, a listing's read under an alarm of the time that remains.</li>
/// </ol>
/// <p>The stop hook is <code>$ClassMethod(pStopClass, "MdxStopRequested", pStopKey)</code>, answering 1 to stop. It is asked before a start,
/// on each poll, before a drill and before a listing is read, and only unswitched (AD-16). It does not reach a listing's read, which waits
/// in the caller: the alarm ends that at the bound. An empty <var>pStopClass</var> never stops. Whenever the run is stopped, the vendor's
/// query is canceled (<method>MdxCancel</method>) and the vendor given up to <parameter>MDXSETTLESECONDS</parameter> seconds to report it
/// finished.</p>
/// <p><var>pAnswer</var> is <method>MdxAnswer</method>'s; the vendor's error answer (<method>ErrorAnswer</method>) when the query or its
/// drill failed; or <code>{outcome: "stopped", seconds}</code> with <var>pStopped</var> <code>bound</code> (<code>seconds</code> is
/// <var>pBound</var>) or <code>request</code> (<code>seconds</code> is the whole seconds run). Otherwise <var>pStopped</var> is
/// <code>""</code>. A refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var>. The drill's result set is released
/// here; <var>pRS</var> is the caller's to release (<method>MdxRelease</method>). The caller's namespace is unchanged on return.</p>
ClassMethod MdxRun(pNamespace As %String, pRS, pRow As %Integer, pColumn As %Integer, pBound As %Numeric, pStopClass As %String, pStopKey As %String, Output pAnswer As %DynamicObject, Output pStopped As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pStopped = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tDrill = ""
    Try {
        Set tSC = ..Ran(pNamespace, pRS, pRow, pColumn, pBound, pStopClass, pStopKey, .tDrill, .pAnswer, .pStopped, .pHttpStatus, .pFault)
    } Catch ex {
        Do ..MdxRelease(pNamespace, .tDrill)
        Throw ex
    }
    Do ..MdxRelease(pNamespace, .tDrill)
    Quit tSC
}

/// <p>The work of <method>MdxRun</method>, holding a drill's result set in <var>pDrill</var> so that <method>MdxRun</method> releases it on
/// every path.</p>
ClassMethod Ran(pNamespace As %String, pRS, pRow As %Integer, pColumn As %Integer, pBound As %Numeric, pStopClass As %String, pStopKey As %String, ByRef pDrill, Output pAnswer As %DynamicObject, Output pStopped As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tStart = $ZHorolog
    Set tDeadline = tStart + pBound
    Do ..Waited(pNamespace, pRS, pStopClass, pStopKey, tDeadline, (..MdxKind(pRS) = "DRILLTHROUGH"), .tOutcome, .tError)
    Set tResultRS = pRS
    If (tOutcome = "done") && (pRow '= "") && ..StopAsked(pStopClass, pStopKey) Set tOutcome = "canceled"
    If (tOutcome = "done") && (pRow '= "") {
        Set tSC = ..MdxDrill(pNamespace, pRS, pRow, pColumn, .pDrill, .pHttpStatus, .pFault, .tDrillAnswer)
        If $$$ISERR(tSC) Quit tSC
        If $IsObject($Get(tDrillAnswer)) {
            Set pAnswer = tDrillAnswer
            Quit $$$OK
        }
        Do ..Waited(pNamespace, pDrill, pStopClass, pStopKey, tDeadline, 1, .tOutcome, .tError)
        Set tResultRS = pDrill
    }
    If tOutcome = "canceled" Quit ..StoppedAnswer("request", $ZHorolog - tStart, pBound, .pAnswer, .pStopped)
    If tOutcome = "stopped" Quit ..StoppedAnswer("bound", $ZHorolog - tStart, pBound, .pAnswer, .pStopped)
    If tOutcome = "error" {
        Set pAnswer = ..ErrorAnswer(tError)
        Quit $$$OK
    }
    Set tListed = 0
    If ..MdxKind(tResultRS) = "DRILLTHROUGH" {
        ; The listing's statement runs when its rows are read, so a stop that reached no statement yet is read here.
        If ..StopAsked(pStopClass, pStopKey) Quit ..StoppedAnswer("request", $ZHorolog - tStart, pBound, .pAnswer, .pStopped)
        Set tRemaining = tDeadline - $ZHorolog
        If tRemaining <= 0 Quit ..StoppedAnswer("bound", $ZHorolog - tStart, pBound, .pAnswer, .pStopped)
        Set tListed = ..AlarmSeconds(tRemaining)
    }
    Set tSC = ..MdxAnswer(pNamespace, tResultRS, +$FNumber($ZHorolog - tStart, "", 2), .tResult, .pHttpStatus, .pFault, tListed)
    If $$$ISERR(tSC) Quit tSC
    If tResult.%Get("outcome") = "stopped" Quit ..StoppedAnswer("bound", $ZHorolog - tStart, pBound, .pAnswer, .pStopped)
    Set pAnswer = tResult
    Quit $$$OK
}

/// <p>Run the prepared result set <var>pRS</var> to its end, the stop hook or <var>pDeadline</var> (<code>$ZHorolog</code> units);
/// <var>pOutcome</var> is <code>done</code>, <code>error</code> (with the vendor's status in <var>pError</var>), <code>canceled</code>
/// (the hook) or <code>stopped</code> (the bound). A stop already asked is read before the start. The start runs under an alarm of the
/// time that remains, and the alarm is a <code>stopped</code> run (<method>Alarmed</method>). With <var>pBlocking</var>, a DRILLTHROUGH's,
/// the start is the whole run here; otherwise this polls the vendor's agents. Whenever the run is canceled or stopped, the vendor's query
/// is canceled and given up to <parameter>MDXSETTLESECONDS</parameter> seconds to report finished.</p>
ClassMethod Waited(pNamespace As %String, pRS, pStopClass As %String, pStopKey As %String, pDeadline As %Numeric, pBlocking As %Boolean, Output pOutcome As %String, Output pError As %Status) [ Private ]
{
    Set pOutcome = "done"
    Set pError = $$$OK
    Set tCube = ""
    Set tQueryKey = ""
    If ..StopAsked(pStopClass, pStopKey) {
        Set pOutcome = "canceled"
        Quit
    }
    Set tRemaining = pDeadline - $ZHorolog
    If tRemaining <= 0 {
        Set pOutcome = "stopped"
        Quit
    }
    Set tAlarmed = 0
    Try {
        Do $System.Alarm.Set(..AlarmSeconds(tRemaining))
        Set tAlarmed = 1
        Set tSC = ..MdxStart(pNamespace, pRS, .tCube, .tQueryKey)
        Do $System.Alarm.Clear()
        Set tAlarmed = 0
    } Catch ex {
        If tAlarmed Do $System.Alarm.Clear()
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        If ..Alarmed(tSC) {
            Set pOutcome = "stopped"
            Do ..Settle(pNamespace, pRS, tCube, tQueryKey)
        } Else {
            Set pOutcome = "error"
            Set pError = tSC
        }
        Quit
    }
    If pBlocking Quit
    For {
        Set tStatus = ..MdxStatus(pNamespace, pRS, .tVendorError)
        If tStatus = 100 {
            If $$$ISERR(tVendorError) {
                Set pOutcome = "error"
                Set pError = tVendorError
            }
            Quit
        }
        If ..StopAsked(pStopClass, pStopKey) {
            Set pOutcome = "canceled"
            Do ..Settle(pNamespace, pRS, tCube, tQueryKey)
            Quit
        }
        If $ZHorolog > pDeadline {
            Set pOutcome = "stopped"
            Do ..Settle(pNamespace, pRS, tCube, tQueryKey)
            Quit
        }
        Hang ..#MDXPOLLPAUSE
    }
}

/// <p>Whether the caller's stop hook asks the run to stop: <code>$ClassMethod(pStopClass, "MdxStopRequested", pStopKey)</code>, run
/// unswitched; 0 for an empty <var>pStopClass</var>.</p>
ClassMethod StopAsked(pStopClass As %String, pStopKey As %String) As %Boolean [ Private ]
{
    If pStopClass = "" Quit 0
    Quit ''$ClassMethod(pStopClass, "MdxStopRequested", pStopKey)
}

/// <p>Cancel the vendor's query <var>pQueryKey</var> of cube <var>pCube</var>, and wait up to <parameter>MDXSETTLESECONDS</parameter>
/// seconds for the vendor to report <var>pRS</var> finished, a plug-in's pending cells left uncomputed. Nothing happens for a run that never
/// named its query.</p>
ClassMethod Settle(pNamespace As %String, pRS, pCube As %String, pQueryKey As %String) [ Private ]
{
    If (pCube = "") || (pQueryKey = "") Quit
    Do ..MdxCancel(pNamespace, pCube, pQueryKey)
    Set tUntil = $ZHorolog + ..#MDXSETTLESECONDS
    For {
        If ..MdxStatus(pNamespace, pRS, .tError, 0) = 100 Quit
        If $ZHorolog > tUntil Quit
        Hang ..#MDXPOLLPAUSE
    }
}

/// <p>Whether the error status <var>pStatus</var> is the run's alarm: an <code>&lt;ALARM&gt;</code> that interrupted code, or the SQL
/// engine's SQLCODE <parameter>MDXALARMSQLCODE</parameter>, the form an alarm takes when it interrupts a statement (measured: a member's
/// <code>%SEARCH</code> SQL in a start answers #5540 with that SQLCODE).</p>
ClassMethod Alarmed(pStatus As %Status) As %Boolean [ Private ]
{
    If $System.Status.GetErrorText(pStatus) [ "<ALARM>" Quit 1
    Set tAlarmed = 0
    Try {
        Do $System.Status.DecomposeStatus(pStatus, .tErrors)
        For tI = 1:1:+$Get(tErrors) {
            If ($Get(tErrors(tI, "code")) = 5540) && ($Get(tErrors(tI, "param", 1)) = ..#MDXALARMSQLCODE) Set tAlarmed = 1
        }
    } Catch {
        Set tAlarmed = 0
    }
    Quit tAlarmed
}

/// <p>The whole seconds an alarm is set for when <var>pRemaining</var> seconds are left: the next whole second, and at least one, because an
/// alarm of zero seconds never fires.</p>
ClassMethod AlarmSeconds(pRemaining As %Numeric) As %Integer [ Private ]
{
    Quit $Select(pRemaining <= 1: 1, 1: (pRemaining \ 1) + ((pRemaining # 1) > 0))
}

/// <p>The stopped answer: <var>pAnswer</var> is <code>{outcome: "stopped", seconds}</code> and <var>pStopped</var> is <var>pWhy</var>,
/// <code>bound</code> or <code>request</code>. <code>seconds</code> is <var>pBound</var> for the bound and the whole seconds
/// <var>pElapsed</var> for a request.</p>
ClassMethod StoppedAnswer(pWhy As %String, pElapsed As %Numeric, pBound As %Numeric, Output pAnswer As %DynamicObject, Output pStopped As %String) As %Status [ Private ]
{
    Set pStopped = pWhy
    Set pAnswer = {}
    Do pAnswer.%Set("outcome", "stopped", "string")
    Do pAnswer.%Set("seconds", $Select(pWhy = "bound": +pBound, 1: pElapsed \ 1), "number")
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

/// <p>The cube <var>pCube</var> as the cube manager reads it, from vendor and system classes only; called with the namespace
/// already switched to the cube's (AD-16), by <method>Collect</method> and <method>CollectState</method>. A <code>%List</code> of:
/// the logical name; <var>pCaption</var>; the fact count (<code>""</code> when the vendor failed to count); the last build and the last
/// update as <code>GetLastUpdate</code> answers them (<code>0</code> for none); the cube's <code>%GetCubeDSTime</code>; whether the
/// source records its changes (its class's <code>%GetSourceInfo</code> names a <code>dstime</code>); whether an update runs now
/// (<method>CubeUpdatingHere</method>); whether the cube has been built (its <code>dstime</code> above zero for a source that records
/// changes, else any fact); and, when <var>pDependents</var>, the cubes that depend on it, named as <var>pList</var> (the
/// <code>%GetCubeList</code> answer, keyed by uppercase index) names them, sorted by name and joined with
/// <parameter>DEPENDENTSEPARATOR</parameter>; a dependent the list does not hold, because the caller's resources hide it, is left out.
/// Writes nothing (measured: <code>%GetCubeDSTime</code>, <code>%GetSourceInfo</code>, <code>%GetDependentCubes</code>,
/// <code>%IsCubeAvailable</code> and <code>GetLastUpdate</code>).</p>
ClassMethod CubeNodeHere(pCube As %String, pCaption As %String, pDependents As %Boolean, ByRef pList) As %List [ Private ]
{
    Set tFacts = ##class(%DeepSee.Utils).%GetCubeFactCount(pCube, .tFactStatus)
    If $$$ISERR(tFactStatus) Set tFacts = ""
    Set tDSTime = +##class(%DeepSee.Utils).%GetCubeDSTime(pCube)
    Set tSynchronizes = 0
    Set tClass = ##class(%DeepSee.Utils).%GetCubeClass(pCube)
    If tClass '= "" {
        Kill tInfo
        Set tInfoSC = $ClassMethod(tClass, "%GetSourceInfo", .tInfo)
        Set tSynchronizes = $$$ISOK(tInfoSC) && ($Get(tInfo("dstime")) '= "")
    }
    Set tDependents = ""
    If pDependents {
        Kill tFound
        If $$$ISOK(##class(%DeepSee.CubeUtils).%GetDependentCubes(pCube, .tFound)) {
            Set tIndex = ""
            For {
                Set tIndex = $Order(tFound(tIndex))
                If tIndex = "" Quit
                Set tName = $ListGet($Get(pList(tIndex)), 1)
                If tName '= "" Set tNames(tName) = ""
            }
            Set tName = ""
            For {
                Set tName = $Order(tNames(tName))
                If tName = "" Quit
                Set tDependents = tDependents _ $Select(tDependents = "": "", 1: ..#DEPENDENTSEPARATOR) _ tName
            }
        }
    }
    Set tBuilt = $Select(tSynchronizes: (tDSTime > 0), 1: (+tFacts > 0))
    Quit $ListBuild(pCube, pCaption, tFacts, ##class(%DeepSee.CubeManager.Utils).GetLastUpdate(pCube, "build"), ##class(%DeepSee.CubeManager.Utils).GetLastUpdate(pCube, "synch"), tDSTime, tSynchronizes, ..CubeUpdatingHere(pCube), tBuilt, tDependents)
}

/// <p>Whether the cube <var>pCube</var> is being built or synchronized now, called with the namespace switched (AD-16): the vendor's own
/// <code>%IsCubeAvailable</code> answering reason code <code>build</code>, or a zero-timeout incremental probe of
/// <code>^DeepSee.Build(&lt;index&gt;,"SYNC")</code> failing, taken and released at once as the vendor's own query probe does. The probe
/// is the one vendor global this port names.</p>
ClassMethod CubeUpdatingHere(pCube As %String) As %Boolean [ Private ]
{
    Set tAvailable = ##class(%DeepSee.Utils).%IsCubeAvailable(pCube, .tReason, .tReasonCode)
    If 'tAvailable && (tReasonCode = "build") Quit 1
    Set tIndex = $ZConvert(pCube, "U")
    Lock +^DeepSee.Build(tIndex, "SYNC"):0 Else  Quit 1
    Lock -^DeepSee.Build(tIndex, "SYNC")
    Quit 0
}

/// <p>Whether <var>pName</var> is a cube the cube manager shows the caller: a cube <var>pList</var>, the namespace's
/// <code>%GetCubeList(.list, "cubes", 1)</code>, holds under exactly that logical name (AD-13). The vendor's list applies its own
/// checks: the cube exists, the caller's resources admit it (<code>%CheckPrivilege</code>), and it is a base cube that is neither
/// abstract nor a version. So an action reads absent wherever the Cube manager's list does not show the cube. Pure.</p>
ClassMethod CubeShownHere(pName As %String, ByRef pList) As %Boolean [ Private ]
{
    If pName = "" Quit 0
    Set tKey = $ZConvert(pName, "U")
    If '$Data(pList(tKey)) Quit 0
    Quit $ListGet(pList(tKey), 1) = pName
}

/// <p>Read the cube <var>pName</var> and the cubes that depend on it into <var>pData</var>: <code>pData("exists")</code> is 1 when
/// <method>CubeShownHere</method> shows it, <code>pData</code> is the count of cubes and <code>pData(n)</code> the
/// <method>CubeNodeHere</method> of cube <code>n</code>, the target first and then each dependent. A dependent the caller's resources
/// hide is not on the vendor's list and is left out. A list the vendor fails to answer, or an exception, is <var>pCaught</var>.</p>
/// <p>Everything between the switch and the restore is vendor and system classes and this class's own <code>Here</code> methods
/// (AD-16); the row is shaped by <method>StateRow</method> after the restore.</p>
ClassMethod CollectState(pNamespace As %String, pName As %String, Output pData, Output pCaught As %Exception.AbstractException) [ Private ]
{
    Kill pData
    Set pData = 0
    Set pData("exists") = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Kill tList
        Set tListSC = ##class(%DeepSee.Utils).%GetCubeList(.tList, "cubes", 1)
        If $$$ISERR(tListSC) $$$ThrowStatus(tListSC)
        If ..CubeShownHere(pName, .tList) {
            Set pData("exists") = 1
            Set pData = 1
            Set pData(1) = ..CubeNodeHere(pName, $ListGet(tList($ZConvert(pName, "U")), 2), 1, .tList)
            Set tDependents = $List(pData(1), 10)
            For tI = 1:1:$Length(tDependents, ..#DEPENDENTSEPARATOR) {
                Set tDependent = $Piece(tDependents, ..#DEPENDENTSEPARATOR, tI)
                If tDependent = "" Continue
                Set pData = pData + 1
                Set pData(pData) = ..CubeNodeHere(tDependent, $ListGet($Get(tList($ZConvert(tDependent, "U"))), 2), 0, .tList)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The state of one cube as the cube manager reads it, from <var>pData</var> as <method>CollectState</method> gathered it:
/// <code>{Name, Namespace, Facts, LastBuild, BuildStamp, LastUpdate, Built, Synchronizes, Updating, DependentCubes}</code>.
/// <code>LastBuild</code> and <code>LastUpdate</code> are the instance's local <code>YYYY-MM-DD HH:MM:SS</code>, <code>""</code> for
/// none; <code>BuildStamp</code> is the last build as the vendor stores it, to the millisecond, so two builds in one second still differ.
/// <code>Built</code>, <code>Synchronizes</code> and <code>Updating</code> are judged over the cube and its dependents, because the
/// vendor updates them in the same call: built only if every one is, synchronizes only if every source records changes, updating if any
/// one is. Pure.</p>
ClassMethod StateRow(pNamespace As %String, ByRef pData) As %DynamicObject
{
    Set tTarget = pData(1)
    Set tBuilt = 1
    Set tSynchronizes = 1
    Set tUpdating = 0
    For tI = 1:1:pData {
        Set tNode = pData(tI)
        If '$List(tNode, 9) Set tBuilt = 0
        If '$List(tNode, 7) Set tSynchronizes = 0
        If $List(tNode, 8) Set tUpdating = 1
    }
    Set tStamp = $List(tTarget, 4)
    Set tRow = {}
    Do tRow.%Set("Name", $List(tTarget, 1), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    If $List(tTarget, 3) = "" {
        Do tRow.%Set("Facts", "", "null")
    } Else {
        Do tRow.%Set("Facts", +$List(tTarget, 3), "number")
    }
    Do tRow.%Set("LastBuild", ..BuildStamp(tStamp), "string")
    Do tRow.%Set("BuildStamp", $Select((tStamp = "") || (tStamp = 0): "", 1: tStamp), "string")
    Do tRow.%Set("LastUpdate", ..BuildStamp($List(tTarget, 5)), "string")
    Do tRow.%Set("Built", tBuilt, "boolean")
    Do tRow.%Set("Synchronizes", tSynchronizes, "boolean")
    Do tRow.%Set("Updating", tUpdating, "boolean")
    Do tRow.%Set("DependentCubes", $List(tTarget, 10), "string")
    Quit tRow
}

/// <p>The code a build or synchronize <var>pType</var> is refused with for the state <var>pRow</var> (<method>StateRow</method>'s),
/// or <code>""</code> when it may go ahead (Story 20.34): whatever the vendor would refuse after it had changed something, or turn into a
/// build, is refused here by its own code and nothing is called. Pure.</p>
/// <ul>
/// <li>Either write, with <code>Updating</code>: <code>ANALYTICS.CUBE.BUSY</code>.</li>
/// <li>A synchronize, unless <code>Synchronizes</code>: <code>ANALYTICS.CUBE.NODSTIME</code>.</li>
/// <li>A synchronize, unless <code>Built</code>: <code>ANALYTICS.CUBE.NOTBUILT</code>, which stops the vendor turning it into a full build
/// under the synchronize key.</li>
/// </ul>
ClassMethod StateRefusal(pType As %String, pRow As %DynamicObject) As %String
{
    If '..IsWrite(pType) || '$IsObject(pRow) Quit ""
    If pRow.%Get("Updating") Quit ##class(OcuPilot.Api.AnalyticsError).#CUBEBUSY
    If pType = ..#TYPESYNCHRONIZE {
        If 'pRow.%Get("Synchronizes") Quit ##class(OcuPilot.Api.AnalyticsError).#CUBENODSTIME
        If 'pRow.%Get("Built") Quit ##class(OcuPilot.Api.AnalyticsError).#CUBENOTBUILT
    }
    Quit ""
}

/// <p>Serve the cube manager's typed calls after <method>Invoke</method>'s gate: <code>STATE</code>, one cube read now, and
/// <code>BUILD</code> and <code>SYNCHRONIZE</code>, the writes (Story 20.34). The cube is named under <parameter>IDKEY</parameter>,
/// kept exactly: 400 when it is not named; 404 <code>PORT.NOTFOUND</code>, unlogged, for one the vendor does not know, the caller's
/// resources hide, or that is spelled other than its logical name. A <code>STATE</code> read carrying <parameter>ACTIONKEY</parameter>
/// is refused by <method>StateRefusal</method> as that write would be; a write is judged the same way again under the caller's
/// per-target hold, so a state that moved since the review is refused by its own code with no vendor call. An
/// <parameter>ACTIONKEY</parameter> that is not one of the two writes is 501.</p>
ClassMethod InvokeCubeManager(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = $Get(pQuery(..#IDKEY))
    If tName = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCUBEREQUIRED, .pHttpStatus, .pFault)
    Set tWrite = ..IsWrite(pType)
    Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
    If (tAction '= "") && '..IsWrite(tAction) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Kill tNames
    Set tSC = ..ReadCube(pNamespace, tName, .tRow, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tAction '= "" {
        Set tCode = ..StateRefusal(tAction, tRow)
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    If 'tWrite {
        Set pResult = tRow
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..PerformCube(pNamespace, pType, tName, .tNames, .pResult, .pHttpStatus, .pFault)
}

/// <p>The cube <var>pName</var> in <var>pRow</var> (<method>StateRow</method>), and in <var>pNames</var> the logical names of it and its
/// dependents by their uppercase index, which the vendor's answers are keyed by. A cube that is not shown is 404 <code>PORT.NOTFOUND</code>,
/// unlogged.</p>
ClassMethod ReadCube(pNamespace As %String, pName As %String, Output pRow As %DynamicObject, Output pNames, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Kill pNames
    Kill tData
    Do ..CollectState(pNamespace, pName, .tData, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the cube could not be read", .pHttpStatus, .pFault)
    If 'tData("exists") Quit ..Absent(.pHttpStatus, .pFault)
    For tI = 1:1:tData {
        Set pNames($ZConvert($List(tData(tI), 1), "U")) = $List(tData(tI), 1)
    }
    Set pRow = ..StateRow(pNamespace, .tData)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Build or synchronize the cube <var>pName</var> (Story 20.34): the state was judged by <method>InvokeCubeManager</method>, so the
/// vendor is called now, through <method>VendorBuild</method> or <method>VendorSynchronize</method>, and its answer is mapped by
/// <method>VendorOutcome</method>: done (a build that finished with errors is done, and says how many); 409
/// <parameter>OcuPilot.Api.AnalyticsError.CUBEBUSY</parameter> for the vendor's cube lock; 404 for a cube it does not know; 403
/// <code>PORT.ACCESSDENIED</code> for <code>&lt;PROTECT&gt;</code> or #940; and anything else, an exception the call raised included,
/// 409 <parameter>OcuPilot.Api.AnalyticsError.CUBEFAILED</parameter>, its text logged and never sent. After the namespace is restored a
/// completed update records OcuPilot's own <code>ConfigChange</code> row (<method>AuditWrite</method>).</p>
/// <p>The answer is <code>{Name, Namespace, lines, errors}</code>: the output lines for the screen (<method>BuildLines</method>,
/// <method>SyncLines</method>), and whether any cube built with errors.</p>
ClassMethod PerformCube(pNamespace As %String, pType As %String, pName As %String, ByRef pNames, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tWritten = ""
    Set tCaught = ""
    Kill tStats
    Kill tFacts
    If pType = ..#TYPEBUILD {
        Set tVendorSC = ..VendorBuild(pNamespace, pName, .tStats, .tCaught, .tWritten)
    } Else {
        Set tVendorSC = ..VendorSynchronize(pNamespace, pName, .tFacts, .tCaught, .tWritten)
    }
    Set tMessage = "the cube " _ $ZConvert(pType, "L") _ " failed" _ $Select(tWritten = "": "", 1: "; the vendor wrote: " _ tWritten)
    If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
    Set tOutcome = ..VendorOutcome(tVendorSC)
    If tOutcome = "denied" Quit ..Statused(tVendorSC, tMessage, .pHttpStatus, .pFault)
    If tOutcome = "busy" Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#CUBEBUSY, .pHttpStatus, .pFault)
    If tOutcome = "absent" Quit ..Absent(.pHttpStatus, .pFault)
    If tOutcome = "failed" {
        Do ..LogFault(tMessage, tVendorSC)
        Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#CUBEFAILED, .pHttpStatus, .pFault)
    }
    Set tLines = []
    Set tCubes = []
    Set tErrors = 0
    If pType = ..#TYPEBUILD {
        Do ..BuildLines(.tStats, .pNames, tLines, tCubes, .tErrors)
    } Else {
        Do ..SyncLines(.tFacts, .pNames, tLines, tCubes)
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("cubes", tCubes)
    Do ..AuditWrite($Select(pType = ..#TYPEBUILD: ..#VERBBUILD, 1: ..#VERBSYNCHRONIZE), pName, tEffects)
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Do pResult.%Set("lines", tLines)
    Do pResult.%Set("errors", (tErrors > 0), "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's build of the cube <var>pCube</var> and every cube that depends on it, in <var>pNamespace</var>
/// (<code>%DeepSee.Utils.%BuildCube(cube, 1, 0, 0, 0, 0, .stats)</code>): asynchronous on the vendor's agents, with no console output and
/// no tracking. It runs switched by explicit save and restore (AD-16), inside an output capture, so nothing the vendor writes reaches the
/// response; what it wrote is <var>pWritten</var>, cut, for the log. <var>pStats</var> is the vendor's statistics array; an exception is
/// <var>pCaught</var>. A capture that cannot be opened is a failed status and nothing is built.</p>
ClassMethod VendorBuild(pNamespace As %String, pCube As %String, Output pStats, Output pCaught As %Exception.AbstractException, Output pWritten As %String) As %Status
{
    Kill pStats
    Set pCaught = ""
    Set pWritten = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    If $$$ISERR(tCaptureSC) Quit tCaptureSC
    Try {
        Set $NAMESPACE = pNamespace
        Kill tStats
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(pCube, 1, 0, 0, 0, 0, .tStats)
        Merge pStats = tStats
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Set pWritten = ..EndCapture(tCookie)
    Quit tSC
}

/// <p>The vendor's synchronize of the cube <var>pCube</var> and every cube that depends on it, in <var>pNamespace</var>
/// (<code>%DeepSee.Utils.%SynchronizeCube(cube, 0, .facts)</code>), under the same switch and capture as <method>VendorBuild</method>.
/// <var>pFacts</var> is the vendor's <code>pFactsUpdated</code>: the total, and under each cube's uppercase index its count.</p>
ClassMethod VendorSynchronize(pNamespace As %String, pCube As %String, Output pFacts, Output pCaught As %Exception.AbstractException, Output pWritten As %String) As %Status
{
    Kill pFacts
    Set pCaught = ""
    Set pWritten = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    If $$$ISERR(tCaptureSC) Quit tCaptureSC
    Try {
        Set $NAMESPACE = pNamespace
        Kill tFacts
        Set tSC = ##class(%DeepSee.Utils).%SynchronizeCube(pCube, 0, .tFacts)
        Merge pFacts = tFacts
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Set pWritten = ..EndCapture(tCookie)
    Quit tSC
}

/// <p>End the output capture <var>pCookie</var> and answer what the vendor wrote, at most <parameter>WRITTENMAX</parameter> characters;
/// <code>""</code> for a capture that cannot be read. The text is for the log and goes nowhere else.</p>
ClassMethod EndCapture(pCookie As %String) As %String [ Private ]
{
    Set tText = ""
    Try {
        Kill tLines
        Set tEndSC = $$EndCapture^%SYS.Capture(pCookie, .tLines)
        If $IsObject($Get(tLines)) {
            Set tIterator = tLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If ($Length(tText) + $Length(tLine)) >= ..#WRITTENMAX Quit
                Set tText = tText _ tLine
            }
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

/// <p>What a vendor status <var>pStatus</var> from a build or synchronize means (Story 20.34): <code>ok</code>; <code>denied</code> for
/// <code>&lt;PROTECT&gt;</code> or #940; <code>busy</code> for the vendor's cube lock (#20005); <code>absent</code> for a cube it does not
/// know (#20013); <code>errors</code> for a build whose only fault is its count of failed rows (#20006), which still built; and
/// <code>failed</code> for anything else, including #20006 beside another error. Pure.</p>
ClassMethod VendorOutcome(pStatus As %Status) As %String
{
    If $$$ISOK(pStatus) Quit "ok"
    Set tText = ""
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    If (tText [ "<PROTECT>") || ..HasCode(pStatus, ..#CODEPRIVILEGE) Quit "denied"
    If ..HasCode(pStatus, ..#CODELOCK) Quit "busy"
    If ..HasCode(pStatus, ..#CODENOCUBE) Quit "absent"
    If ..OnlyCode(pStatus, ..#CODEBUILDERRORS) Quit "errors"
    Quit "failed"
}

/// <p>Whether every code of the error status <var>pStatus</var> is <var>pCode</var>, as the vendor tests a build that finished with
/// errors. Pure.</p>
ClassMethod OnlyCode(pStatus As %Status, pCode As %String) As %Boolean [ Private ]
{
    Set tCodes = ""
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
    } Catch {
        Set tCodes = ""
    }
    If tCodes = "" Quit 0
    Set tOnly = 1
    For tI = 1:1:$Length(tCodes, ",") {
        If $Piece(tCodes, ",", tI) '= pCode Set tOnly = 0
    }
    Quit tOnly
}

/// <p>The output lines a build answers, from the vendor's statistics <var>pStats</var>: for each cube built, in name order,
/// <code>Facts in &lt;cube&gt;: &lt;n&gt;</code> and, when its error count is above zero, <code>Build errors in &lt;cube&gt;: &lt;n&gt;</code>.
/// <var>pNames</var> gives the logical name of an index. The lines go to <var>pLines</var>, the names to <var>pCubes</var> and the total
/// of failed rows to <var>pErrors</var>. They are shown on the screen and stored nowhere. Pure.</p>
ClassMethod BuildLines(ByRef pStats, ByRef pNames, pLines As %DynamicArray, pCubes As %DynamicArray, ByRef pErrors As %Integer)
{
    Set tIndex = ""
    For {
        Set tIndex = $Order(pStats("cubes", tIndex))
        If tIndex = "" Quit
        Set tName = $Get(pNames(tIndex), tIndex)
        Set tByName(tName) = +$Get(pStats("cubes", tIndex, "factCount")) _ "|" _ +$Get(pStats("cubes", tIndex, "errors"))
    }
    Set tName = ""
    For {
        Set tName = $Order(tByName(tName))
        If tName = "" Quit
        Do pCubes.%Push(tName, "string")
        Do pLines.%Push("Facts in " _ tName _ ": " _ $Piece(tByName(tName), "|", 1), "string")
        If $Piece(tByName(tName), "|", 2) > 0 {
            Set pErrors = pErrors + $Piece(tByName(tName), "|", 2)
            Do pLines.%Push("Build errors in " _ tName _ ": " _ $Piece(tByName(tName), "|", 2), "string")
        }
    }
}

/// <p>The output lines a synchronize answers, from the vendor's <var>pFacts</var>: for each cube updated, in name order,
/// <code>Facts updated in &lt;cube&gt;: &lt;n&gt;</code>. A count the vendor did not give as a number (a cube whose pre-synchronize code
/// stopped it) is 0. Pure.</p>
ClassMethod SyncLines(ByRef pFacts, ByRef pNames, pLines As %DynamicArray, pCubes As %DynamicArray)
{
    Set tIndex = ""
    For {
        Set tIndex = $Order(pFacts(tIndex))
        If tIndex = "" Quit
        Set tByName($Get(pNames(tIndex), tIndex)) = $Select($IsValidNum($Get(pFacts(tIndex))): +pFacts(tIndex), 1: 0)
    }
    Set tName = ""
    For {
        Set tName = $Order(tByName(tName))
        If tName = "" Quit
        Do pCubes.%Push(tName, "string")
        Do pLines.%Push("Facts updated in " _ tName _ ": " _ tByName(tName), "string")
    }
}

/// <p>Record OcuPilot's own <code>ConfigChange</code> row for the build or synchronize of the cube <var>pId</var> that read OK (AD-15,
/// Story 20.34), from whichever caller made it: the vendor audits neither. <var>pVerb</var> is <parameter>VERBBUILD</parameter> or
/// <parameter>VERBSYNCHRONIZE</parameter>; <var>pEffects</var> names the namespace and the cubes updated, and never a fact. It never
/// fails the write: a row that cannot be recorded is logged. Called after the namespace is restored.</p>
ClassMethod AuditWrite(pVerb As %String, pId As %String, pEffects As %DynamicObject, pEntity As %String = "") [ Private ]
{
    Set tEntity = $Select(pEntity '= "": pEntity, 1: ..#ENTITYCUBE)
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, tEntity, pId, {}, 0, pEffects)
        If $$$ISERR(tSC) Do ..LogFault("the " _ tEntity _ " write could not be audited", tSC)
    } Catch ex {
        Do ..LogFault("the " _ tEntity _ " write could not be audited", ex.AsStatus())
    }
}

/// <p>404 <code>PORT.NOTFOUND</code>: the cube is not there, or not shown to the caller. Unlogged (AD-2).</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p><code>objectscript</code> for the cube manager's two writes, the term list editor's nine and the folder manager's three; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTCUBEMANAGER) && ..IsWrite(pType) Quit "objectscript"
    If ((pEndpoint = ..#ENDPOINTTERMLISTS) || (pEndpoint = ..#ENDPOINTTERMLISTENTRIES)) && ..IsTermListWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTFOLDERITEMS) && ..IsFolderItemWrite(pType) Quit "objectscript"
    If ..IsListingGroupEndpoint(pEndpoint) && ..IsListingGroupWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    Quit ""
}

/// <p>The write as a script (AD-59), in the namespace <parameter>NAMESPACEKEY</parameter> names; a term list write is
/// <method>TermListSnippet</method>'s, and no step when that renders nothing. A cube manager write is <code>%BuildCube</code> of the cube
/// <parameter>IDKEY</parameter> names, asynchronous, or <code>%SynchronizeCube</code> of it. The cube is a string literal, so nothing the
/// query carries runs as code. Whoever runs the script is checked by the vendor's own resources, which do not include
/// <code>%DeepSee_Admin</code>.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pEndpoint '= ..#ENDPOINTCUBEMANAGER {
        Set tPart = $Select(pEndpoint = ..#ENDPOINTFOLDERITEMS: ..FolderItemSnippet(pType, $Get(pQuery(..#IDKEY)), .pQuery), ..IsListingGroupEndpoint(pEndpoint): ..ListingGroupSnippet(pType, $Get(pQuery(..#IDKEY)), pBody, .pQuery), 1: ..TermListSnippet(pType, $Get(pQuery(..#IDKEY)), pBody, .pQuery))
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pType = ..#TYPEBUILD {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(%DeepSee.Utils).%BuildCube(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ", 1, 0, 0, 0, 0, .tStats)"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(%DeepSee.Utils).%SynchronizeCube(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ", 0, .tFacts)"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The lines <method>Snippet</method> adds for the term list write <var>pType</var> of the list or entry the id <var>pId</var> names
/// (Story 24.2), the vendor calls <method>PerformTermList</method> makes: a create, a header write, a delete, a value write per entry
/// value and field value, an entry removal as the vendor's documented layout has it. A write that makes several calls is one transaction,
/// rolled back when one fails. Each step is gated on one line by the port's own refusal: a create by a free name (the vendor's create
/// kills a list of the same name) and an entry add by a free key; every other write but the delete by the list being held. The body
/// <var>pBody</var> is the body the confirm sends; a change names the list as the body's <code>Name</code> carries it, the stored
/// spelling. Names and values are string literals.</p>
ClassMethod TermListSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    If (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPECOPY) Quit ..TransferSnippet(pType, pId, .pQuery)
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    Set tEntry = (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    Set tParts = $Select(tEntry: ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId), 1: $ListBuild(pId))
    Set tName = ..Literal($ListGet(tParts, 1))
    If (pType = ..#TYPEUPDATE) && (..Text(pBody, "Name") '= "") Set tName = ..Literal(..Text(pBody, "Name"))
    Set tKey = ..Literal($ListGet(tParts, 2))
    Set tList = "##class(%DeepSee.TermList)"
    Set tStamp = "$ZDateTime($Horolog, 3)"
    Set tHeld = " Set tId = $ZConvert(" _ tName _ ", ""U""), tSC = $Select($Data(^DeepSee.TermList(tId)): 1, 1: $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTABSENT) _ "))"
    If pType = ..#TYPEADD Quit tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTTAKEN) _ ")" _ tNL _ " If '" _ tList _ ".%TermListExists(" _ tName _ ") Set tSC = " _ tList _ ".%CreateTermList(" _ tName _ ", " _ ..Literal(..Text(pBody, "Caption")) _ ", " _ ..Literal(..FieldListOf(pBody, "")) _ ", " _ ..Literal(..Text(pBody, "Pattern")) _ ", " _ ..Literal(..Text(pBody, "Description")) _ ", " _ ..Literal(..Text(pBody, "SubjectArea")) _ ", " _ ..Hidden(pBody, 0) _ ")"
    If pType = ..#TYPEDELETE Quit tNL _ " Set tSC = " _ tList _ ".%DeleteTermList(" _ tName _ ")"
    If pType = ..#TYPEENTRYREMOVE Quit tNL _ tHeld _ tNL _ " If $System.Status.IsOK(tSC) Kill ^DeepSee.TermList(tId, ""data"", " _ tKey _ ") Set ^DeepSee.TermList(tId, ""modDate"") = " _ tStamp
    Set tText = tNL _ tHeld
    If pType = ..#TYPEENTRYADD Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC), $Data(^DeepSee.TermList(tId, ""data"", " _ tKey _ ")) Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTENTRYTAKEN) _ ")"
    Set tText = tText _ tNL _ " TSTART"
    If pType = ..#TYPEUPDATE {
        Set tText = tText _ tNL _ " Set tObject = ##class(%DeepSee.UserLibrary.TermList).%New()"
        Set tText = tText _ tNL _ " Set tObject.name = " _ tName
        Set tText = tText _ tNL _ " Set tObject.caption = " _ ..Literal(..Text(pBody, "Caption"))
        Set tText = tText _ tNL _ " Set tObject.fieldListString = " _ ..Literal(..FieldListOf(pBody, ""))
        Set tText = tText _ tNL _ " Set tObject.pattern = " _ ..Literal(..Text(pBody, "Pattern"))
        Set tText = tText _ tNL _ " Set tObject.description = " _ ..Literal(..Text(pBody, "Description"))
        Set tText = tText _ tNL _ " Set tObject.subjectArea = " _ ..Literal(..Text(pBody, "SubjectArea"))
        Set tText = tText _ tNL _ " Set tObject.modDate = " _ tStamp
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%FromObj(tObject)"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) { " _ $Select(..Hidden(pBody, 0): "Set ^DeepSee.TermList(tId, ""hideValue"") = 1", 1: "Kill ^DeepSee.TermList(tId, ""hideValue"")") _ " }"
    } Else {
        ; An add writes the entry's own value even when the body carries none, as the port's write does.
        If (pBody.%GetTypeOf("Value") = "string") || (pType = ..#TYPEENTRYADD) Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%SetValue(" _ tName _ ", " _ tKey _ ", " _ ..Literal(..Text(pBody, "Value")) _ ", """")"
        If pBody.%GetTypeOf("FieldValues") = "array" {
            Set tIterator = pBody.FieldValues.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tPair) {
                If '$IsObject(tPair) || (tPair.%GetTypeOf("Field") '= "string") || (tPair.%GetTypeOf("Value") '= "string") Continue
                Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%SetValue(" _ tName _ ", " _ tKey _ ", " _ ..Literal(tPair.%Get("Value")) _ ", " _ ..Literal(tPair.%Get("Field")) _ ")"
            }
        }
    }
    Quit tText _ tNL _ " If $System.Status.IsOK(tSC) { TCOMMIT } Else { TROLLBACK 1 }"
}

/// <p>The lines <method>TermListSnippet</method> adds for a transfer (Story 24.10): an export is the vendor's own <code>%ExportCSV</code> of a list that is
/// held, to the server file the query names, resolved as the write resolves it (<method>ExportFile</method>), or to the current device; an
/// import and a copy are <method>WholeListSnippet</method> of the list the file holds, or the source's read. An import file that cannot be read as a
/// term list export or holds another list than the one named, one whose text is not the reviewed <parameter>DIGESTKEY</parameter>, a source that is
/// not held, and a server file the export cannot resolve are each a script that only sets the refusal. A local file's text is never in a script, so
/// an import of one renders the list that text holds when the query carries it. <code>""</code> when the list has more entries than
/// <parameter>SNIPPETENTRIES</parameter>, so the draft is refused rather than rendered in part.</p>
ClassMethod TransferSnippet(pType As %String, pId As %String, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tList = "##class(%DeepSee.TermList)"
    If pType = ..#TYPEIMPORT {
        Set tSC = ..ImportText(##class(OcuPilot.Api.AnalyticsError).#TERMLISTTOOLARGE, .pQuery, .tText, .tHttp, .tFault)
        If $$$ISERR(tSC) || '..TermListParse(tText, .tData) || ((pId '= ..#IMPORTID) && (pId '= tData("name"))) Quit tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTIMPORTSHAPE) _ ")"
        If $Get(pQuery(..#DIGESTKEY)) '= ..TextDigest(tText) Quit tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTIMPORTCHANGED) _ ")"
        Quit ..WholeListSnippet(..Literal(tData("name")), .tData)
    }
    Set tAbsent = tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTABSENT) _ ")"
    If pType = ..#TYPECOPY {
        Do ..ReadTermListData($Get(pQuery(..#NAMESPACEKEY)), pId, .tData, .tVendorSC, .tCaught)
        If $IsObject(tCaught) || $$$ISERR(tVendorSC) || '+$Get(tData("exists")) Quit tAbsent
        Quit ..WholeListSnippet(..Literal($Get(pQuery(..#NEWNAMEKEY))), .tData)
    }
    Set tName = ..Literal(pId)
    Set tHeld = " Set tId = $ZConvert(" _ tName _ ", ""U""), tSC = $Select($Data(^DeepSee.TermList(tId)): 1, 1: $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTABSENT) _ "))"
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tFile = """"""
    Set tSource = ""
    If tPath '= "" {
        Set tSource = tNL _ " ; The server file is the allowed directory " _ $Translate($Get(pQuery(..#ROOTKEY)), $Char(10) _ $Char(13), "  ") _ " and the name " _ $Translate(tPath, $Char(10) _ $Char(13), "  ")
        Set tSC = ..ExportFile($Get(pQuery(..#ROOTKEY)), tPath, .tResolved, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit tSource _ tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: $System.Status.GetErrorText(tSC))) _ ")"
        Set tFile = ..Literal(tResolved)
    }
    Quit tSource _ tNL _ tHeld _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%ExportCSV(" _ tName _ ", " _ tFile _ ", " _ $Select(tPath = "": 0, 1: 1) _ ")"
}

/// <p>The lines that create the term list named by the literal <var>pNameLiteral</var> from <var>pData</var> in one transaction (Story 24.10): a free
/// name, the create with the header, and a value write for each entry and field value. Rolled back when one step fails. <code>""</code> when
/// <var>pData</var> holds more than <parameter>SNIPPETENTRIES</parameter> entries, since a script that wrote part of them would make another
/// change than the write (AD-59).</p>
ClassMethod WholeListSnippet(pNameLiteral As %String, ByRef pData) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tList = "##class(%DeepSee.TermList)"
    Set tFields = ""
    For tAt = 1:1:$Length(pData("fieldList"), "^") {
        If $Piece(pData("fieldList"), "^", tAt) '= "" Set tFields = tFields _ $Select(tFields = "": "", 1: "^") _ $Piece(pData("fieldList"), "^", tAt)
    }
    If pData("keys") > ..#SNIPPETENTRIES Quit ""
    Set tText = tNL _ " TSTART"
    Set tText = tText _ tNL _ " Set tSC = $Select($Data(^DeepSee.TermList($ZConvert(" _ pNameLiteral _ ", ""U""))): $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTTAKEN) _ "), 1: 1)"
    Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%CreateTermList(" _ pNameLiteral _ ", " _ ..Literal(pData("caption")) _ ", " _ ..Literal(tFields) _ ", " _ ..Literal(pData("pattern")) _ ", " _ ..Literal(pData("description")) _ ", " _ ..Literal(pData("subjectArea")) _ ", " _ ''pData("hide") _ ")"
    For tEntry = 1:1:pData("keys") {
        Set tKey = ..Literal(pData("key", tEntry))
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%SetValue(" _ pNameLiteral _ ", " _ tKey _ ", " _ ..Literal($Get(pData("val", tEntry, 0))) _ ", """")"
        For tAt = 1:1:$Length(pData("fieldList"), "^") {
            If $Piece(pData("fieldList"), "^", tAt) = "" Continue
            Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tList _ ".%SetValue(" _ pNameLiteral _ ", " _ tKey _ ", " _ ..Literal($Get(pData("val", tEntry, tAt))) _ ", " _ ..Literal($Piece(pData("fieldList"), "^", tAt)) _ ")"
        }
    }
    Quit tText _ tNL _ " If $System.Status.IsOK(tSC) { TCOMMIT } Else { TROLLBACK 1 }"
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

/// <p>The term list editor's destination gate (AD-29, AD-65, Story 24.2), after the namespace gate: WRITE on the database
/// <parameter>TERMLISTGLOBAL</parameter> maps to, which must be mounted read-write (409
/// <parameter>OcuPilot.Api.AnalyticsError.TERMLISTREADONLY</parameter>), and that database journaled (409
/// <parameter>OcuPilot.Api.AnalyticsError.TERMLISTNOTJOURNALED</parameter>), so that a write that makes several vendor calls is all or
/// nothing and none is left half done. A database whose journal state the instance cannot read is 400 <code>PORT.VALIDATION</code>.
/// Names no vendor class.</p>
ClassMethod AdmitTermList(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..AdmitJournaled(pNamespace, ..#TERMLISTGLOBAL, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTREADONLY, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTNOTJOURNALED, .pHttpStatus, .pFault)
}

/// <p>The destination gate of a write that makes several vendor calls (AD-29, AD-65), after the namespace gate: WRITE on the database
/// <var>pGlobal</var> maps to, which must be mounted read-write (409 <var>pReadOnlyCode</var>), and that database journaled (409
/// <var>pNotJournaledCode</var>), so that the write is all or nothing. A database whose journal state the instance cannot read is 400
/// <code>PORT.VALIDATION</code>. The term list editor and the folder manager each bind their own global and codes. Names no vendor class.</p>
ClassMethod AdmitJournaled(pNamespace As %String, pGlobal As %String, pReadOnlyCode As %String, pNotJournaledCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..AdmitDestination(pNamespace, pGlobal, pReadOnlyCode, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tJournaled = 0
    If '..DestinationJournaled(pNamespace, pGlobal, .tJournaled) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If 'tJournaled Quit ..Conflict(pNotJournaledCode, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Whether the database <var>pGlobal</var> maps to in <var>pNamespace</var> is journaled (<var>pJournaled</var>); the answer is 0 when
/// the instance cannot say, which a caller refuses rather than admits. A <code>$ZUTIL(49)</code> read of the database's directory, whose
/// seventeenth piece carries the no-journal flag 4096 (measured against <code>SYS.Database.GlobalJournalState</code>); no namespace is
/// switched. Overridable so a fixture can name a database with journaling off; production never overrides it.</p>
ClassMethod DestinationJournaled(pNamespace As %String, pGlobal As %String, Output pJournaled As %Boolean) As %Boolean
{
    Set pJournaled = 0
    Set tKnown = 0
    Try {
        Set tDest = ##class(%SYS.Namespace).GetGlobalDest($ZConvert(pNamespace, "U"), pGlobal)
        If (tDest '= "") && ($Piece(tDest, "^", 1) = "") && ($Piece(tDest, "^", 2) '= "") Set tKnown = ..JournaledFrom($ZUtil(49, $Piece(tDest, "^", 2)), .pJournaled)
    } Catch {
        Set pJournaled = 0
        Set tKnown = 0
    }
    Quit tKnown
}

/// <p>Whether <var>pInfo</var>, a database's <code>$ZUTIL(49)</code> answer, says it is journaled (<var>pJournaled</var>): the no-journal
/// flag 4096 of its seventeenth piece is clear. 0 when the answer is not that record. Pure.</p>
ClassMethod JournaledFrom(pInfo As %String, Output pJournaled As %Boolean) As %Boolean
{
    Set pJournaled = 0
    If $Length(pInfo, ",") < 17 Quit 0
    Set tFlags = $Piece(pInfo, ",", 17)
    If tFlags '? 1.N Quit 0
    Set pJournaled = ((tFlags \ 4096) # 2 = 0)
    Quit 1
}

/// <p>Whether <var>pText</var> is a name or key the editor admits: 1 to <parameter>NAMEMAX</parameter> characters with no control
/// character, and, when <var>pNoCaret</var>, no <code>^</code>. Pure.</p>
ClassMethod NameShaped(pText As %String, pNoCaret As %Boolean = 0) As %Boolean
{
    If (pText = "") || ($Length(pText) > ..#NAMEMAX) || ($ZStrip(pText, "*C") '= pText) Quit 0
    Quit 'pNoCaret || (pText '[ "^")
}

/// <p>Whether the instance can address the term list <var>pName</var>'s node and, when they are not empty, the entry <var>pKey</var>'s node
/// of the field <var>pField</var> (the vendor stores the list and the field in upper case). A reference past the instance's limit raises
/// <code>&lt;SUBSCRIPT&gt;</code>, and the limit counts the global's name and every subscript together, so names within their own bound can
/// pass it together (measured: a 255-character name takes a key of at most 226 characters beside a five-character field). The test reads a
/// process-private global whose name is as long as the vendor's, which nothing writes. Pure.</p>
ClassMethod TermListFits(pName As %String, pKey As %String = "", pField As %String = "VALUE") As %Boolean
{
    Set tFits = 1
    Try {
        Set tList = $ZConvert(pName, "U")
        If pKey = "" {
            Set tProbe = $Data(^||DeepSee.TermList(tList))
        } Else {
            Set tProbe = $Data(^||DeepSee.TermList(tList, "data", pKey, $ZConvert(pField, "U")))
        }
    } Catch {
        Set tFits = 0
    }
    Quit tFits
}

/// <p>The shape violations of a term list write that need nothing from the instance, in <var>pViolations</var>
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>): <var>pType</var> is the write,
/// <var>pName</var> the term list, <var>pKey</var> the entry's key (entry writes), <var>pBody</var> what the caller sends. A caption,
/// pattern or subject area is at most <parameter>SHORTTEXTMAX</parameter> characters, a description or value at most
/// <parameter>LONGTEXTMAX</parameter>; a name and a key are <method>NameShaped</method> and <method>TermListFits</method>, a key beside each field its values name; a field name is
/// <method>NameShaped</method> without <code>^</code>, is never <code>Value</code>, is not repeated without regard to case, and a list has
/// at most <parameter>FIELDSMAX</parameter>; a member of the wrong type is <code>PORT.FIELD.SHAPE</code>. Pure.</p>
ClassMethod TermListViolations(pType As %String, pName As %String, pKey As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tNameOk = ..NameShaped(pName) && ..TermListFits(pName)
    If (pType = ..#TYPEADD) && 'tNameOk Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTNAME)
    If (pType = ..#TYPEADD) || (pType = ..#TYPEUPDATE) {
        For tMember = "Caption", "Pattern", "SubjectArea", "Description" {
            Set tMemberType = pBody.%GetTypeOf(tMember)
            If tMemberType = "unassigned" Continue
            If tMemberType '= "string" {
                Set pViolations($Increment(pViolations)) = $ListBuild(tMember, tShape)
            } ElseIf $Length(pBody.%Get(tMember)) > $Select(tMember = "Description": ..#LONGTEXTMAX, 1: ..#SHORTTEXTMAX) {
                Set pViolations($Increment(pViolations)) = $ListBuild(tMember, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTVALUE)
            }
        }
        Set tHideType = pBody.%GetTypeOf("HideValue")
        If (tHideType '= "unassigned") && (tHideType '= "boolean") && (tHideType '= "number") Set pViolations($Increment(pViolations)) = $ListBuild("HideValue", tShape)
        Set tFieldsType = pBody.%GetTypeOf("Fields")
        If tFieldsType = "unassigned" Quit $$$OK
        If tFieldsType '= "array" {
            Set pViolations($Increment(pViolations)) = $ListBuild("Fields", tShape)
            Quit $$$OK
        }
        Set tSeen = ""
        Set tCount = 0
        Set tIterator = pBody.Fields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Set tCount = tCount + 1
            If pBody.Fields.%GetTypeOf(tIndex) '= "string" {
                Set pViolations($Increment(pViolations)) = $ListBuild("Fields", tShape)
                Continue
            }
            Set tUpper = $ZConvert(tField, "U")
            If '..NameShaped(tField, 1) || (tUpper = ..#VALUEFIELD) || $ListFind(tSeen, tUpper) || (tNameOk && '..TermListFits(pName, "k", tField)) Set pViolations($Increment(pViolations)) = $ListBuild("Fields", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTFIELD)
            Set tSeen = tSeen _ $ListBuild(tUpper)
        }
        If tCount > ..#FIELDSMAX Set pViolations($Increment(pViolations)) = $ListBuild("Fields", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTFIELD)
        Quit $$$OK
    }
    If (pType '= ..#TYPEENTRYADD) && (pType '= ..#TYPEENTRYSET) Quit $$$OK
    If (pType = ..#TYPEENTRYADD) && (('..NameShaped(pKey, 1)) || ('..TermListFits(pName, pKey))) Set pViolations($Increment(pViolations)) = $ListBuild("Key", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTKEY)
    Set tValueType = pBody.%GetTypeOf("Value")
    If tValueType '= "unassigned" {
        If tValueType '= "string" {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", tShape)
        } ElseIf $Length(pBody.%Get("Value")) > ..#LONGTEXTMAX {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTVALUE)
        }
    }
    Set tPairsType = pBody.%GetTypeOf("FieldValues")
    If tPairsType = "unassigned" Quit $$$OK
    If tPairsType '= "array" {
        Set pViolations($Increment(pViolations)) = $ListBuild("FieldValues", tShape)
        Quit $$$OK
    }
    Set tIterator = pBody.FieldValues.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPair) {
        If (pBody.FieldValues.%GetTypeOf(tIndex) '= "object") || (tPair.%GetTypeOf("Field") '= "string") || (tPair.%GetTypeOf("Value") '= "string") {
            Set pViolations($Increment(pViolations)) = $ListBuild("FieldValues", tShape)
        } ElseIf $Length(tPair.%Get("Value")) > ..#LONGTEXTMAX {
            Set pViolations($Increment(pViolations)) = $ListBuild("FieldValues", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTVALUE)
        } ElseIf (pKey '= "") && ..NameShaped(pKey, 1) && ..NameShaped(tPair.%Get("Field"), 1) && '..TermListFits(pName, pKey, tPair.%Get("Field")) {
            ; The instance's limit counts the key and the field together, so a key that fits beside the value can be too long beside a field.
            Set pViolations($Increment(pViolations)) = $ListBuild("Key", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTKEY)
        }
    }
    Quit $$$OK
}

/// <p>The violations that need the instance's own state, in <var>pViolations</var> as <method>TermListViolations</method> answers them, for
/// the term list read into <var>pData</var> (<method>ReadTermListData</method>): an entry value naming a field the list does not hold
/// (<code>NOFIELD</code>), and, on an update, a field that leaves the list while an entry holds a value for it (<code>FIELDINUSE</code>).
/// Pure.</p>
ClassMethod TermListStateViolations(pType As %String, ByRef pData, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    If '+$Get(pData("exists")) Quit $$$OK
    Set tHeld = ""
    For tAt = 1:1:$Length($Get(pData("fieldList")), "^") {
        Set tField = $Piece(pData("fieldList"), "^", tAt)
        If tField '= "" Set tHeld = tHeld _ $ListBuild($ZConvert(tField, "U"))
    }
    If (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) {
        If pBody.%GetTypeOf("FieldValues") '= "array" Quit $$$OK
        Set tIterator = pBody.FieldValues.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPair) {
            If '$ListFind(tHeld, $ZConvert(tPair.%Get("Field"), "U")) Set pViolations($Increment(pViolations)) = $ListBuild("FieldValues", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTNOFIELD)
        }
        Quit $$$OK
    }
    If (pType '= ..#TYPEUPDATE) || (pBody.%GetTypeOf("Fields") '= "array") Quit $$$OK
    Set tKept = ""
    Set tIterator = pBody.Fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tKept = tKept _ $ListBuild($ZConvert(tField, "U"))
    }
    ; pData("val", n, f) is indexed by the field's piece of the stored list, an empty piece included.
    For tAt = 1:1:$Length(pData("fieldList"), "^") {
        Set tField = $ZConvert($Piece(pData("fieldList"), "^", tAt), "U")
        If (tField = "") || $ListFind(tKept, tField) Continue
        For tEntry = 1:1:+$Get(pData("keys")) {
            If $Get(pData("val", tEntry, tAt)) '= "" {
                Set pViolations($Increment(pViolations)) = $ListBuild("Fields", ##class(OcuPilot.Api.AnalyticsError).#TERMLISTFIELDINUSE)
                Quit
            }
        }
    }
    Quit $$$OK
}

/// <p>The 422 refusal <var>pViolations</var> earn (AD-39): the first violation's code and sentence, every one in
/// <code>detail.violations</code>.</p>
ClassMethod ViolationRefusal(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {"violations": []}
    For tI = 1:1:pViolations {
        Set tCode = $List(pViolations(tI), 2)
        Do tDetail.%Get("violations").%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (##class(OcuPilot.Api.Error).ReasonForViolation(tCode))})
    }
    Set tFirst = $List(pViolations(1), 2)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tFirst, ##class(OcuPilot.Api.Error).ReasonForViolation(tFirst), .pHttpStatus, .pFault, tDetail)
}

/// <p>The sentence of the first rule the call <var>pBody</var> of the write <var>pType</var> on the term list <var>pName</var> breaks against
/// the instance's own state, <code>""</code> when none: a list that is not there, a field the list does not hold, a field in use. The mint
/// and a screen's save ask it so that the agent and the person are refused what the write would refuse. It reads through the namespace
/// <var>pNamespace</var> and writes nothing; the caller has passed this port's gate.</p>
ClassMethod StateProblem(pNamespace As %String, pType As %String, pName As %String, pBody As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        Kill tData
        Set tVendorSC = $$$OK
        Set tCaught = ""
        Do ..ReadTermListData(pNamespace, pName, .tData, .tVendorSC, .tCaught)
        If $IsObject(tCaught) || $$$ISERR(tVendorSC) Quit
        If '+$Get(tData("exists")) {
            Set tProblem = ##class(OcuPilot.Api.AnalyticsError).ReasonFor(##class(OcuPilot.Api.AnalyticsError).#TERMLISTABSENT)
            Quit
        }
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit
        Kill tViolations
        Set tSC = ..TermListStateViolations(pType, .tData, pBody, .tViolations)
        If $$$ISERR(tSC) || ('tViolations) Quit
        Set tProblem = "'" _ $List(tViolations(1), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(1), 2))
    } Catch {
        Set tProblem = ""
    }
    Quit tProblem
}

/// <p>Read the term list <var>pName</var> from the vendor in <var>pNamespace</var> into <var>pData</var>: <code>pData("exists")</code>; its
/// header under <code>name</code>, <code>caption</code>, <code>description</code>, <code>pattern</code>, <code>subjectArea</code>,
/// <code>fieldList</code> (the vendor's <code>^</code>-delimited text), <code>modDate</code> and <code>hide</code>; <code>pData("keys")</code>
/// entries, <code>pData("key", n)</code> each key and <code>pData("val", n, f)</code> its value, <code>f</code> 0 for the entry's own value
/// and 1 to the number of fields for each field's. A vendor error status is <var>pVendorStatus</var>; an exception is <var>pCaught</var>.
/// Everything between the switch and the restore names only vendor classes (AD-16). A seam: overridable so a fixture can fail a read.</p>
ClassMethod ReadTermListData(pNamespace As %String, pName As %String, Output pData, Output pVendorStatus As %Status, Output pCaught As %Exception.AbstractException)
{
    Kill pData
    Set pData("exists") = 0
    Set pVendorStatus = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Kill tStatus
        Set tObject = ##class(%DeepSee.TermList).%ToObj(pName, .tStatus)
        If $Data(tStatus) && $$$ISERR(tStatus) {
            Set pVendorStatus = tStatus
        } ElseIf $IsObject(tObject) {
            Set pData("exists") = 1
            Set pData("name") = tObject.name
            Set pData("caption") = tObject.caption
            Set pData("description") = tObject.description
            Set pData("pattern") = tObject.pattern
            Set pData("subjectArea") = tObject.subjectArea
            Set pData("fieldList") = tObject.fieldListString
            Set pData("modDate") = tObject.modDate
            Set pData("hide") = ''$Get(^DeepSee.TermList($ZConvert(pName, "U"), "hideValue"))
            Set pData("keys") = tObject.keyList.Count()
            For tAt = 1:1:pData("keys") {
                Set tKey = tObject.keyList.GetAt(tAt)
                Set pData("key", tAt) = tKey
                Set pData("val", tAt, 0) = tObject.valueList.GetAt(tKey _ "^VALUE")
                For tField = 1:1:$Length(tObject.fieldListString, "^") {
                    Set tFieldName = $Piece(tObject.fieldListString, "^", tField)
                    If tFieldName '= "" Set pData("val", tAt, tField) = tObject.valueList.GetAt(tKey _ "^" _ $ZConvert(tFieldName, "U"))
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The term list read into <var>pData</var> as a row: <code>{Name, Caption, Description, Pattern, SubjectArea, Fields, HideValue, Modified,
/// Namespace}</code>, <code>Fields</code> the list's field names in order. Pure.</p>
ClassMethod HeaderRow(pNamespace As %String, ByRef pData) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("Name", pData("name"), "string")
    Do tRow.%Set("Caption", pData("caption"), "string")
    Do tRow.%Set("Description", pData("description"), "string")
    Do tRow.%Set("Pattern", pData("pattern"), "string")
    Do tRow.%Set("SubjectArea", pData("subjectArea"), "string")
    Set tFields = []
    For tAt = 1:1:$Length(pData("fieldList"), "^") {
        If $Piece(pData("fieldList"), "^", tAt) '= "" Do tFields.%Push($Piece(pData("fieldList"), "^", tAt), "string")
    }
    Do tRow.%Set("Fields", tFields)
    Do tRow.%Set("HideValue", pData("hide"), "boolean")
    Do tRow.%Set("Modified", pData("modDate"), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The entry at position <var>pAt</var> of the term list read into <var>pData</var> as a row: <code>{TermList, Key, Value, FieldValues,
/// Fields, Namespace}</code>, <code>FieldValues</code> one <code>{Field, Value}</code> per field of the list and <code>Fields</code> the same
/// joined as <code>field: value</code> with <code>; </code>, as <code>TermListEntries</code> lists it. Pure.</p>
ClassMethod EntryRow(pNamespace As %String, ByRef pData, pAt As %Integer) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("TermList", pData("name"), "string")
    Do tRow.%Set("Key", pData("key", pAt), "string")
    Do tRow.%Set("Value", pData("val", pAt, 0), "string")
    Set tPairs = []
    Set tJoined = ""
    For tField = 1:1:$Length(pData("fieldList"), "^") {
        Set tName = $Piece(pData("fieldList"), "^", tField)
        If tName = "" Continue
        Set tValue = $Get(pData("val", pAt, tField))
        Do tPairs.%Push({"Field": (tName), "Value": (tValue)})
        Set tJoined = tJoined _ $Select(tJoined = "": "", 1: "; ") _ tName _ ": " _ tValue
    }
    Do tRow.%Set("FieldValues", tPairs)
    Do tRow.%Set("Fields", tJoined, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The position of the entry <var>pKey</var>, exactly, in the term list read into <var>pData</var>; 0 when it holds none. Pure.</p>
ClassMethod EntryAt(ByRef pData, pKey As %String) As %Integer
{
    Set tFound = 0
    For tAt = 1:1:+$Get(pData("keys")) {
        If pData("key", tAt) = pKey {
            Set tFound = tAt
            Quit
        }
    }
    Quit tFound
}

/// <p>404 <code>ANALYTICS.TERMLIST.ABSENT</code>: the term list is not there.</p>
ClassMethod ListAbsent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTABSENT, ##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTABSENT, .pHttpStatus, .pFault)
}

/// <p>Serve the term list editor's typed calls after <method>Invoke</method>'s gate (Story 24.2): the reads <code>TERMLIST</code> (one term
/// list as <method>HeaderRow</method>) and <code>TERMLISTENTRY</code> (one entry, as <method>EntryRow</method>), and the six writes. The
/// list is named under <parameter>IDKEY</parameter>, an entry by the composite <code>[TermList, Key]</code>, each part kept exactly (AD-13).
/// A read carrying <parameter>ACTIONKEY</parameter> is composed for that write, as a create expects it: an add's read is 409 when the target is
/// held and 404 when it is not, and the other writes' reads are 404 when the target is not there. A term list that is not there is 404
/// <code>PORT.NOTFOUND</code> on a plain read.</p>
ClassMethod InvokeTermList(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tId = $Get(pQuery(..#IDKEY))
    Set tName = tId
    Set tKey = ""
    If pEndpoint = ..#ENDPOINTTERMLISTENTRIES {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
        If $ListLength(tParts) '= 2 Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTERMLISTREQUIRED, .pHttpStatus, .pFault)
        Set tName = $List(tParts, 1)
        Set tKey = $List(tParts, 2)
        If tKey = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTERMLISTREQUIRED, .pHttpStatus, .pFault)
    }
    If tName = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTERMLISTREQUIRED, .pHttpStatus, .pFault)
    Set tWrite = ..IsTermListWrite(pType)
    Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
    If (tAction '= "") && '..IsTermListWrite(tAction) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    If pType = ..#TYPEEXPORTLIST Quit ..ReadExportList(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEEXPORT Quit ..PerformExport(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEIMPORTFILE Quit ..ReadImportFile(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEIMPORT Quit ..PerformImport(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPECOPYTARGET Quit ..ReadCopyTarget(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPECOPY Quit ..PerformCopy(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
    If tWrite Quit ..PerformTermList(pNamespace, pType, tName, tKey, pBody, .pResult, .pHttpStatus, .pFault)

    Kill tData
    Set tVendorSC = $$$OK
    Set tCaught = ""
    Do ..ReadTermListData(pNamespace, tName, .tData, .tVendorSC, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the term list could not be read", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the term list could not be read", .pHttpStatus, .pFault)
    Set tAt = $Select(tKey = "": 0, 1: ..EntryAt(.tData, tKey))
    Set tCode = ..TermListRefusal(tAction, +tData("exists"), tAt)
    If tCode = "ABSENT" Quit ..ListAbsent(.pHttpStatus, .pFault)
    If tCode = "NOENTRY" Quit ..Absent(.pHttpStatus, .pFault)
    If tCode '= "" Quit ..Conflict($Select(tCode = "TAKEN": ##class(OcuPilot.Api.AnalyticsError).#TERMLISTTAKEN, 1: ##class(OcuPilot.Api.AnalyticsError).#TERMLISTENTRYTAKEN), .pHttpStatus, .pFault)
    If (pEndpoint = ..#ENDPOINTTERMLISTS) {
        If tAction = ..#TYPEADD Quit ..Absent(.pHttpStatus, .pFault)
        If 'tData("exists") Quit ..Absent(.pHttpStatus, .pFault)
        Set pResult = ..HeaderRow(pNamespace, .tData)
    } Else {
        If tAction = ..#TYPEENTRYADD Quit ..Absent(.pHttpStatus, .pFault)
        If 'tAt Quit ..Absent(.pHttpStatus, .pFault)
        Set pResult = ..EntryRow(pNamespace, .tData, tAt)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The decision a term list write <var>pAction</var> is refused with, as <code>TAKEN</code> (an add of a held list), <code>ENTRYTAKEN</code>
/// (an entry add of a held key), <code>ABSENT</code> (any write on a list that is not there, an add excepted),
/// <code>NOENTRY</code> (a set or remove of a key not held), else <code>""</code>. <var>pExists</var> is whether the list is held,
/// <var>pAt</var> the entry's position, 0 when it is not held. <var>pAction</var> <code>""</code> is a plain read, which refuses nothing. Pure.</p>
ClassMethod TermListRefusal(pAction As %String, pExists As %Boolean, pAt As %Integer) As %String
{
    If pAction = "" Quit ""
    If pAction = ..#TYPEADD Quit $Select(pExists: "TAKEN", 1: "")
    If 'pExists Quit "ABSENT"
    If pAction = ..#TYPEENTRYADD Quit $Select(pAt: "ENTRYTAKEN", 1: "")
    If (pAction = ..#TYPEENTRYSET) || (pAction = ..#TYPEENTRYREMOVE) Quit $Select(pAt: "", 1: "NOENTRY")
    Quit ""
}

/// <p>Make the term list write <var>pType</var> on the list <var>pName</var> (and, for an entry write, the entry <var>pKey</var>) in
/// <var>pNamespace</var> (Story 24.2). In order, and each refusal before any vendor write: the shape rules
/// (<method>TermListViolations</method>, 422); the list read (<method>ReadTermListData</method>); the state's own refusal
/// (<method>TermListRefusal</method>: 409 held, 404 absent); the rules that need the state (<method>TermListStateViolations</method>, 422);
/// then the vendor calls through the seams. A write that makes more than one vendor call (an update, an entry add or set) runs them inside
/// one transaction, rolled back on any failure, so a failed write leaves the target as it was; nothing is audited, spawned or sent inside it.
/// After the namespace is restored a successful write records OcuPilot's own <code>ConfigChange</code> row (<method>AuditWrite</method>),
/// because the vendor audits none (measured). The answer is the written target read again: a term list or an entry row, or
/// <code>{Name, Namespace}</code> and <code>{TermList, Key, Namespace}</code> after a delete and a remove.</p>
ClassMethod PerformTermList(pNamespace As %String, pType As %String, pName As %String, pKey As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    Kill tViolations
    Set tSC = ..TermListViolations(pType, pName, pKey, pBody, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)
    Kill tData
    Set tVendorSC = $$$OK
    Set tCaught = ""
    Do ..ReadTermListData(pNamespace, pName, .tData, .tVendorSC, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the term list could not be read", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the term list could not be read", .pHttpStatus, .pFault)
    Set tAt = $Select(pKey = "": 0, 1: ..EntryAt(.tData, pKey))
    Set tCode = ..TermListRefusal(pType, +tData("exists"), tAt)
    If tCode = "ABSENT" Quit ..ListAbsent(.pHttpStatus, .pFault)
    If tCode = "NOENTRY" Quit ..Absent(.pHttpStatus, .pFault)
    If tCode '= "" Quit ..Conflict($Select(tCode = "TAKEN": ##class(OcuPilot.Api.AnalyticsError).#TERMLISTTAKEN, 1: ##class(OcuPilot.Api.AnalyticsError).#TERMLISTENTRYTAKEN), .pHttpStatus, .pFault)
    Kill tViolations
    Set tSC = ..TermListStateViolations(pType, .tData, pBody, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)

    ; The stored spelling of the list is the vendor's, so every vendor call names it as stored.
    Set tStored = $Select(pType = ..#TYPEADD: pName, 1: tData("name"))
    Set tVendorSC = $$$OK
    Set tCaught = ""
    Set tTransaction = 0
    If pType = ..#TYPEADD {
        Set tVendorSC = ..VendorTermListCreate(pNamespace, tStored, ..Text(pBody, "Caption"), ..FieldListOf(pBody, ""), ..Text(pBody, "Pattern"), ..Text(pBody, "Description"), ..Text(pBody, "SubjectArea"), ..Hidden(pBody, 0), .tCaught)
    } ElseIf pType = ..#TYPEDELETE {
        Set tVendorSC = ..VendorTermListDelete(pNamespace, tStored, .tCaught)
    } ElseIf pType = ..#TYPEENTRYREMOVE {
        Set tVendorSC = ..VendorTermListRemoveEntry(pNamespace, tStored, pKey, .tCaught)
    } ElseIf pType = ..#TYPEUPDATE {
        TSTART
        Set tTransaction = 1
        Set tFields = $Select(pBody.%GetTypeOf("Fields") = "array": ..FieldListOf(pBody, ""), 1: tData("fieldList"))
        Set tHide = ..Hidden(pBody, tData("hide"))
        Set tVendorSC = ..VendorTermListHeader(pNamespace, tStored, ..TextOr(pBody, "Caption", tData("caption")), tFields, ..TextOr(pBody, "Pattern", tData("pattern")), ..TextOr(pBody, "Description", tData("description")), ..TextOr(pBody, "SubjectArea", tData("subjectArea")), .tCaught)
        If $$$ISOK(tVendorSC) && '$IsObject(tCaught) Set tVendorSC = ..VendorTermListHide(pNamespace, tStored, tHide, .tCaught)
    } Else {
        TSTART
        Set tTransaction = 1
        Set tValue = $Select(pBody.%GetTypeOf("Value") = "string": pBody.%Get("Value"), tAt: tData("val", tAt, 0), 1: "")
        Set tVendorSC = ..VendorTermListSetValue(pNamespace, tStored, pKey, tValue, "", .tCaught)
        If pBody.%GetTypeOf("FieldValues") = "array" {
            Set tIterator = pBody.FieldValues.%GetIterator()
            While $$$ISOK(tVendorSC) && '$IsObject(tCaught) && tIterator.%GetNext(.tIndex, .tPair) {
                Set tVendorSC = ..VendorTermListSetValue(pNamespace, tStored, pKey, tPair.%Get("Value"), tPair.%Get("Field"), .tCaught)
            }
        }
    }
    Set tFailed = $IsObject(tCaught) || $$$ISERR(tVendorSC)
    If tTransaction {
        If tFailed {
            TROLLBACK 1
        } Else {
            TCOMMIT
        }
    }
    If tFailed {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Quit ..Statused(tVendorSC, "the term list write failed", .pHttpStatus, .pFault)
    }

    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("termList", tStored, "string")
    If pKey '= "" Do tEffects.%Set("entry", pKey, "string")
    Set tEntity = $Select(pKey = "": ..#ENTITYTERMLIST, 1: ..#ENTITYTERMLISTENTRY)
    Do ..AuditWrite($Case(pType, ..#TYPEADD: ..#VERBTERMLISTADD, ..#TYPEUPDATE: ..#VERBTERMLISTUPDATE, ..#TYPEDELETE: ..#VERBTERMLISTDELETE, ..#TYPEENTRYADD: ..#VERBENTRYADD, ..#TYPEENTRYSET: ..#VERBENTRYSET, : ..#VERBENTRYREMOVE), $Select(pKey = "": tStored, 1: ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tStored, pKey))), tEffects, tEntity)

    Set pResult = {}
    Do pResult.%Set("Namespace", pNamespace, "string")
    If (pType = ..#TYPEDELETE) || (pType = ..#TYPEENTRYREMOVE) {
        Do pResult.%Set($Select(pKey = "": "Name", 1: "TermList"), tStored, "string")
        If pKey '= "" Do pResult.%Set("Key", pKey, "string")
    } Else {
        Kill tAfter
        Do ..ReadTermListData(pNamespace, tStored, .tAfter, .tAfterSC, .tAfterCaught)
        If $IsObject(tAfterCaught) || $$$ISERR(tAfterSC) || '+$Get(tAfter("exists")) {
            Do pResult.%Set($Select(pKey = "": "Name", 1: "TermList"), tStored, "string")
            If pKey '= "" Do pResult.%Set("Key", pKey, "string")
        } ElseIf pKey = "" {
            Set pResult = ..HeaderRow(pNamespace, .tAfter)
        } Else {
            Set tAfterAt = ..EntryAt(.tAfter, pKey)
            If tAfterAt Set pResult = ..EntryRow(pNamespace, .tAfter, tAfterAt)
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The class that answers the path predicates (AD-21). Overridable so a fixture can move the served directory; production never
/// overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>The 409 refusal <var>pCode</var>, with the sentence <method>OcuPilot.Api.Error.ReasonForViolation</method> gives it: a code of this
/// port's own or one of <class>OcuPilot.Port.PathPort</class>'s.</p>
ClassMethod ConflictFor(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), .pHttpStatus, .pFault)
}

/// <p>The read half of the term list gate (AD-29, AD-65, Story 24.10), after the namespace gate: READ on the database
/// <parameter>TERMLISTGLOBAL</parameter> maps to, which an export needs and which changes nothing. 400 <code>PORT.VALIDATION</code> when the
/// instance cannot name the database. Names no vendor class.</p>
ClassMethod AdmitTermListRead(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..AdmitRead(pNamespace, ..#TERMLISTGLOBAL, .pHttpStatus, .pFault)
}

/// <p>The read half of a transfer's destination gate (AD-29, AD-65), after the namespace gate: READ on the database <var>pGlobal</var> maps to,
/// which an export needs and which changes nothing. 400 <code>PORT.VALIDATION</code> when the instance cannot name the database. Names no
/// vendor class.</p>
ClassMethod AdmitRead(pNamespace As %String, pGlobal As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    Set tResource = ""
    Set tReadOnly = 0
    Set tMounted = 0
    If '..DestinationDatabase(pNamespace, pGlobal, .tResource, .tReadOnly, .tMounted) || (tResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tResource, ..#READPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved through <method>PathPortClass</method> as a <code>file</code> with
/// <parameter>EXPORTOVERWRITES</parameter>, each refusal on its field, then <code>EXPLORER.EXPORT.DIRECTORY</code> when the resolved name's
/// directory does not exist; a directory is never created. On success <var>pResolved</var> is the path.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResolved = ""
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTKEY, ..#PATHKEY, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..ConflictFor(##class(OcuPilot.Api.AtelierError).#EXPORTDIRECTORY, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked as the write checks it before its vendor call, for a mint
/// that must refuse what the write would: the pairs of <var>pEndpoint</var>, then <method>ExportFile</method>. Nothing is written.</p>
ClassMethod CheckExport(pEndpoint As %String, pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail("the export's file could not be checked", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The text of the file an import names in <var>pQuery</var>, in <var>pText</var>: the server file <parameter>ROOTKEY</parameter> and
/// <parameter>PATHKEY</parameter> name, resolved through <method>PathPortClass</method> as a <code>source</code> (<var>pResolved</var> is its path)
/// and read as UTF-8 text (<method>OcuPilot.Port.AtelierPort.ReadText</method>), or the local file <parameter>FILENAMEKEY</parameter> and
/// <parameter>CONTENTKEY</parameter> send. Refused before any vendor call: 400 <code>PORT.VALIDATION</code> when both files or neither is named,
/// or a local file's name is longer than 255 characters or holds <code>/</code>, <code>\</code> or a control character; the resolve's own refusal on
/// its field; and 409 <var>pTooLargeCode</var> for text longer than <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ImportText(pTooLargeCode As %String, ByRef pQuery, Output pText As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pResolved As %String) As %Status [ Private ]
{
    Set pText = ""
    Set pResolved = ""
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tFileName = $Get(pQuery(..#FILENAMEKEY))
    Set tContent = $Get(pQuery(..#CONTENTKEY))
    Set tServer = (tRoot '= "") || (tPath '= "")
    Set tLocal = (tFileName '= "") || (tContent '= "")
    If tServer = tLocal Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTSOURCE, .pHttpStatus, .pFault)
    If tLocal {
        If (tFileName = "") || ($Length(tFileName) > ##class(OcuPilot.Port.AtelierPort).#MAXFILENAME) || (tFileName [ "/") || (tFileName [ "\") || ($ZStrip(tFileName, "*C") '= tFileName) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTFILENAME, .pHttpStatus, .pFault)
        }
        If $Length(tContent) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS Quit ..Conflict(pTooLargeCode, .pHttpStatus, .pFault)
        Set pText = tContent
        Quit $$$OK
    }
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", tRoot, tPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTKEY, ..#PATHKEY, .pResolved, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Port.AtelierPort).ReadText(pResolved, .pText, .tTooLarge)
    If $$$ISERR(tSC) Quit ..Fail("the import's file could not be read", tSC, .pHttpStatus, .pFault)
    If tTooLarge {
        Set pText = ""
        Quit ..Conflict(pTooLargeCode, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p><var>pText</var> as a binary stream of its UTF-8 bytes, rewound.</p>
ClassMethod Utf8Stream(pText As %String) As %Stream.GlobalBinary
{
    Set tBytes = ##class(%Stream.GlobalBinary).%New()
    For tAt = 1:30000:$Length(pText) {
        Do tBytes.Write($ZConvert($Extract(pText, tAt, tAt + 29999), "O", "UTF8"))
    }
    Do tBytes.Rewind()
    Quit tBytes
}

/// <p><var>pText</var>'s SHA-256 over its UTF-8 bytes, as lower-case hex; <code>""</code> when it cannot be taken.</p>
ClassMethod TextDigest(pText As %String) As %String
{
    Set tDigest = ""
    Try {
        Set tBytes = ..Utf8Stream(pText)
        Set tHash = $System.Encryption.SHAHashStream(256, tBytes, .tHashSC)
        If $$$ISOK(tHashSC) Set tDigest = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
    } Catch {
        Set tDigest = ""
    }
    Quit tDigest
}

/// <p>The vendor's reading of one CSV line <var>pLine</var> into <var>pRecord</var> (<code>%ParseCSVRecord</code>), which decodes its argument
/// as UTF-8, so the line is encoded first.</p>
ClassMethod ParseRecord(pLine As %String, Output pRecord) [ Private ]
{
    Do ##class(%DeepSee.TermList).%ParseCSVRecord($ZConvert(pLine, "O", "UTF8"), .pRecord)
}

/// <p>Read the CSV text <var>pText</var> of a term list export into <var>pData</var>, in the layout <method>ReadTermListData</method> answers
/// (<code>name</code>, <code>caption</code>, <code>description</code>, <code>pattern</code>, <code>subjectArea</code>, <code>fieldList</code>,
/// <code>hide</code>, <code>keys</code>, <code>key(n)</code> and <code>val(n, f)</code>, <code>f</code> 0 for the entry's own value and the field's
/// piece of the list for each field), and answer whether the text is a term list export: it names a list and holds an entry. Lines end at a line
/// feed, a carriage return before it is dropped and a leading byte order mark is skipped. Leading <code>%%</code> lines are the header, as
/// <code>%ImportCSV</code> reads them (<code>NAME</code>, <code>CAPTION</code>, <code>FIELDLIST</code>, <code>PATTERN</code>,
/// <code>DESCRIPTION</code>, <code>SUBJECTAREA</code> and <code>HIDEVALUE</code>); the other lines, blank ones and <code>%%</code> ones apart, are
/// entries, whose first record is the key, the second the value and record <code>f + 2</code> the value of the field at piece <code>f</code>. A key
/// with no text is skipped; a key held twice keeps its later line, and counts once. Reads nothing from the instance and writes nothing.</p>
ClassMethod TermListParse(pText As %String, Output pData) As %Boolean
{
    Kill pData
    Set pData("exists") = 0
    For tMember = "name", "caption", "description", "pattern", "subjectArea", "fieldList" {
        Set pData(tMember) = ""
    }
    Set pData("hide") = 0
    Set pData("keys") = 0
    Kill tIndex
    Set tHeader = 1
    Set tFirst = 1
    Set tLength = $Length(pText)
    Set tStart = 1
    While tStart <= tLength {
        Set tEnd = $Find(pText, $Char(10), tStart)
        If tEnd = 0 {
            Set tLine = $Extract(pText, tStart, tLength)
            Set tStart = tLength + 1
        } Else {
            Set tLine = $Extract(pText, tStart, tEnd - 2)
            Set tStart = tEnd
        }
        If $Extract(tLine, $Length(tLine)) = $Char(13) Set tLine = $Extract(tLine, 1, $Length(tLine) - 1)
        If tFirst {
            Set tFirst = 0
            If $Extract(tLine, 1) = $Char(65279) Set tLine = $Extract(tLine, 2, $Length(tLine))
        }
        If tHeader && ($Extract(tLine, 1, 2) = "%%") {
            Do ..ParseRecord(tLine, .tRecord)
            Set tValue = $Get(tRecord(2))
            Set tHeaderKey = $ZConvert($Get(tRecord(1)), "U")
            If tHeaderKey = "%%NAME" {
                If pData("name") = "" Set pData("name") = tValue
            } ElseIf tHeaderKey = "%%CAPTION" {
                Set pData("caption") = tValue
            } ElseIf tHeaderKey = "%%FIELDLIST" {
                Set pData("fieldList") = tValue
            } ElseIf tHeaderKey = "%%PATTERN" {
                Set pData("pattern") = tValue
            } ElseIf tHeaderKey = "%%DESCRIPTION" {
                Set pData("description") = tValue
            } ElseIf tHeaderKey = "%%SUBJECTAREA" {
                Set pData("subjectArea") = tValue
            } ElseIf tHeaderKey = "%%HIDEVALUE" {
                Set pData("hide") = ''+tValue
            }
            Continue
        }
        Set tHeader = 0
        Set tLine = $ZStrip(tLine, "<>W")
        If (tLine = "") || ($Extract(tLine, 1, 2) = "%%") Continue
        Do ..ParseRecord(tLine, .tRecord)
        Set tKey = $Get(tRecord(1))
        If tKey = "" Continue
        ; A key past the name bound is refused by the shape rules, so it is not looked up.
        If ($Length(tKey) <= ..#NAMEMAX) && $Data(tIndex(tKey)) {
            Set tEntry = tIndex(tKey)
        } Else {
            Set pData("keys") = pData("keys") + 1
            Set tEntry = pData("keys")
            Set pData("key", tEntry) = tKey
            If $Length(tKey) <= ..#NAMEMAX Set tIndex(tKey) = tEntry
        }
        Set pData("val", tEntry, 0) = $Get(tRecord(2))
        For tAt = 1:1:$Length(pData("fieldList"), "^") {
            If $Piece(pData("fieldList"), "^", tAt) '= "" Set pData("val", tEntry, tAt) = $Get(tRecord(tAt + 2))
        }
    }
    Quit (pData("name") '= "") && (pData("keys") > 0)
}

/// <p>The violations of the whole term list <var>pData</var> (<method>ReadTermListData</method>'s or <method>TermListParse</method>'s layout) as it
/// would be created under the name <var>pName</var>, in <var>pViolations</var> as <method>TermListViolations</method> answers them: the header
/// first, else the first entry that breaks a rule. Pure.</p>
ClassMethod DataViolations(pName As %String, ByRef pData, Output pViolations) As %Status [ Private ]
{
    Kill pViolations
    Set pViolations = 0
    Set tBody = {}
    Do tBody.%Set("Caption", pData("caption"), "string")
    Do tBody.%Set("Description", pData("description"), "string")
    Do tBody.%Set("Pattern", pData("pattern"), "string")
    Do tBody.%Set("SubjectArea", pData("subjectArea"), "string")
    Do tBody.%Set("Fields", ..FieldsOf(.pData))
    Do tBody.%Set("HideValue", ''pData("hide"), "boolean")
    Set tSC = ..TermListViolations(..#TYPEADD, pName, "", tBody, .pViolations)
    If $$$ISERR(tSC) || pViolations Quit tSC
    For tEntry = 1:1:pData("keys") {
        Set tBody = {}
        Do tBody.%Set("Value", $Get(pData("val", tEntry, 0)), "string")
        Set tPairs = []
        For tAt = 1:1:$Length(pData("fieldList"), "^") {
            Set tField = $Piece(pData("fieldList"), "^", tAt)
            If tField '= "" Do tPairs.%Push({"Field": (tField), "Value": ($Get(pData("val", tEntry, tAt)))})
        }
        Do tBody.%Set("FieldValues", tPairs)
        Kill tEntryViolations
        Set tSC = ..TermListViolations(..#TYPEENTRYADD, pName, pData("key", tEntry), tBody, .tEntryViolations)
        If $$$ISERR(tSC) Quit
        If tEntryViolations {
            Merge pViolations = tEntryViolations
            Quit
        }
    }
    Quit tSC
}

/// <p>The names of the fields of the term list <var>pData</var>, in order, as an array of strings. Pure.</p>
ClassMethod FieldsOf(ByRef pData) As %DynamicArray [ Private ]
{
    Set tFields = []
    For tAt = 1:1:$Length(pData("fieldList"), "^") {
        If $Piece(pData("fieldList"), "^", tAt) '= "" Do tFields.%Push($Piece(pData("fieldList"), "^", tAt), "string")
    }
    Quit tFields
}

/// <p>The import file a query names, examined (Story 24.10): its text (<method>ImportText</method>), its digest, and its reading
/// (<method>TermListParse</method>) into <var>pData</var>. 409 <code>ANALYTICS.TERMLIST.IMPORTSHAPE</code> when the text is not a term list export
/// with an entry, or names a list other than <var>pId</var>, unless <var>pId</var> is <parameter>IMPORTID</parameter>. Nothing is written.</p>
ClassMethod TermListImportFile(pId As %String, ByRef pQuery, Output pText As %String, Output pData, Output pDigest As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pDigest = ""
    Set tSC = ..ImportText(##class(OcuPilot.Api.AnalyticsError).#TERMLISTTOOLARGE, .pQuery, .pText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tShaped = ..TermListParse(pText, .pData)
    If 'tShaped || ((pId '= ..#IMPORTID) && (pId '= pData("name"))) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#TERMLISTIMPORTSHAPE, .pHttpStatus, .pFault)
    Set pDigest = ..TextDigest(pText)
    If pDigest = "" Quit ..Fail("the import file's digest could not be taken", $$$ERROR($$$GeneralError, "digest"), .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Whether the term list <var>pName</var> is held in <var>pNamespace</var>, compared without regard to case (<var>pHeld</var>); the
/// <code>pData</code> read (<method>ReadTermListData</method>) too. A fault or a vendor error is the answer's error status.</p>
ClassMethod TermListHeld(pNamespace As %String, pName As %String, Output pHeld As %Boolean, Output pData, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pData
    Set tVendorSC = $$$OK
    Set tCaught = ""
    Do ..ReadTermListData(pNamespace, pName, .pData, .tVendorSC, .tCaught)
    Set pHeld = 0
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the term list could not be read", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the term list could not be read", .pHttpStatus, .pFault)
    Set pHeld = +pData("exists")
    Quit $$$OK
}

/// <p>The term list <var>pName</var> as a read of the export: the header row <method>HeaderRow</method> answers, with the file the query
/// names under <parameter>ROOTKEY</parameter> and <parameter>PATHKEY</parameter>, both empty when none. A list that is not held is 404
/// <code>PORT.NOTFOUND</code>, and with <var>pAction</var> (the read composed for the export) 404 <code>ANALYTICS.TERMLIST.ABSENT</code>.
/// Gated by <method>AdmitTermListRead</method>.</p>
ClassMethod ReadExportList(pNamespace As %String, pName As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..AdmitTermListRead(pNamespace, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..TermListHeld(pNamespace, pName, .tHeld, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld Quit $Select(pAction '= "": ..ListAbsent(.pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
    Set pRow = ..HeaderRow(pNamespace, .tData)
    Do pRow.%Set(..#ROOTKEY, $Get(pQuery(..#ROOTKEY)), "string")
    Do pRow.%Set(..#PATHKEY, $Get(pQuery(..#PATHKEY)), "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Export the term list <var>pName</var> in the vendor's own CSV (<code>%ExportCSV</code>): to the server file <parameter>ROOTKEY</parameter>
/// and <parameter>PATHKEY</parameter> name, resolved and checked by <method>ExportFile</method> before the call, the answer
/// <code>{Name, Namespace, root, path}</code>; or, naming neither, as lines for the browser, the answer <code>{Name, Namespace, lines}</code>, 409
/// <code>ANALYTICS.TERMLIST.TOOLARGE</code> past <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters. It reads only
/// (<method>AdmitTermListRead</method>), writes nothing but the file, and records OcuPilot's own audit row.</p>
ClassMethod PerformExport(pNamespace As %String, pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..AdmitTermListRead(pNamespace, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tToFile = (tRoot '= "") || (tPath '= "")
    Set tSC = ..TermListHeld(pNamespace, pName, .tHeld, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld Quit ..ListAbsent(.pHttpStatus, .pFault)
    Set tResolved = ""
    If tToFile {
        Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tCaught = ""
    Set tTooLarge = 0
    Set tVendorSC = ..VendorTermListExport(pNamespace, tData("name"), tResolved, .tLines, .tTooLarge, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the term list export failed", .pHttpStatus, .pFault)
    If tTooLarge Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#TERMLISTTOOLARGE, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the term list export failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("termList", tData("name"), "string")
    Do tEffects.%Set("entries", tData("keys"), "number")
    Do tEffects.%Set("toFile", ''tToFile, "boolean")
    Do ..AuditWrite(..#VERBTERMLISTEXPORT, tData("name"), tEffects, ..#ENTITYTERMLIST)
    Set pResult = {}
    Do pResult.%Set("Name", tData("name"), "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    If tToFile {
        Do pResult.%Set(..#ROOTKEY, tRoot, "string")
        Do pResult.%Set(..#PATHKEY, tPath, "string")
    } Else {
        Do pResult.%Set("lines", tLines)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's CSV export of the term list <var>pName</var> in <var>pNamespace</var> (<code>%ExportCSV</code>), switched by explicit save and
/// restore (AD-16): to the file <var>pFile</var> in UTF-8 when it is not empty, else inside an output capture, its lines in
/// <var>pLines</var> (an array of strings) unless they pass <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters, which
/// is <var>pTooLarge</var>. An exception is <var>pCaught</var>; a capture that cannot be opened is a failed status. A seam: a fixture overrides it
/// to observe or fail the call.</p>
ClassMethod VendorTermListExport(pNamespace As %String, pName As %String, pFile As %String, Output pLines As %DynamicArray, Output pTooLarge As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set pLines = ""
    Set pTooLarge = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    If pFile '= "" {
        Try {
            Set $NAMESPACE = pNamespace
            Set tSC = ##class(%DeepSee.TermList).%ExportCSV(pName, pFile, 1)
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set pCaught = ex
        }
        Quit tSC
    }
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    If $$$ISERR(tCaptureSC) Quit tCaptureSC
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.TermList).%ExportCSV(pName, "", 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Kill tCaptured
    Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tCaptured)
    If $$$ISERR(tSC) || $IsObject(pCaught) Quit tSC
    If $$$ISERR(tEndSC) Quit tEndSC
    Set pLines = []
    Set tTotal = 0
    If $IsObject($Get(tCaptured)) {
        Set tIterator = tCaptured.%GetIterator()
        While tIterator.%GetNext(.tAt, .tLine) {
            Set tTotal = tTotal + $Length(tLine) + 1
            If tTotal > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS {
                Set pTooLarge = 1
                Set pLines = ""
                Quit
            }
            Do pLines.%Push(tLine, "string")
        }
    }
    Quit $$$OK
}

/// <p>Judge, before any vendor call, the term list <var>pData</var> as it would be created under <var>pName</var> in <var>pNamespace</var>:
/// 422 for the first rule it breaks (<method>DataViolations</method>), then 409 <code>ANALYTICS.TERMLIST.TAKEN</code> when a list of that name
/// is held, compared without regard to case.</p>
ClassMethod CreateRefusal(pNamespace As %String, pName As %String, ByRef pData, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tViolations
    Set tSC = ..DataViolations(pName, .pData, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)
    Set tSC = ..TermListHeld(pNamespace, pName, .tHeld, .tNow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tHeld Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#TERMLISTTAKEN, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Create the term list <var>pName</var> in <var>pNamespace</var> from <var>pData</var> and write every entry's value and field values, all in
/// one transaction through the editor's seams, rolled back on any failure so that no list is left (AD-54). <var>pVendorStatus</var> and
/// <var>pCaught</var> answer the failure. Nothing is audited, spawned or sent inside the transaction.</p>
ClassMethod WriteWholeList(pNamespace As %String, pName As %String, ByRef pData, Output pVendorStatus As %Status, Output pCaught As %Exception.AbstractException) As %Boolean [ Private ]
{
    Set pCaught = ""
    Set tFields = ""
    For tAt = 1:1:$Length(pData("fieldList"), "^") {
        If $Piece(pData("fieldList"), "^", tAt) '= "" Set tFields = tFields _ $Select(tFields = "": "", 1: "^") _ $Piece(pData("fieldList"), "^", tAt)
    }
    TSTART
    Set pVendorStatus = ..VendorTermListCreate(pNamespace, pName, pData("caption"), tFields, pData("pattern"), pData("description"), pData("subjectArea"), ''pData("hide"), .pCaught)
    For tEntry = 1:1:pData("keys") {
        If $$$ISERR(pVendorStatus) || $IsObject(pCaught) Quit
        Set pVendorStatus = ..VendorTermListSetValue(pNamespace, pName, pData("key", tEntry), $Get(pData("val", tEntry, 0)), "", .pCaught)
        For tAt = 1:1:$Length(pData("fieldList"), "^") {
            If $$$ISERR(pVendorStatus) || $IsObject(pCaught) Quit
            Set tField = $Piece(pData("fieldList"), "^", tAt)
            If tField = "" Continue
            Set pVendorStatus = ..VendorTermListSetValue(pNamespace, pName, pData("key", tEntry), $Get(pData("val", tEntry, tAt)), tField, .pCaught)
        }
    }
    Set tFailed = $IsObject(pCaught) || $$$ISERR(pVendorStatus)
    If tFailed {
        TROLLBACK 1
    } Else {
        TCOMMIT
    }
    Quit tFailed
}

/// <p>The answer of a transfer that created the term list <var>pName</var>: the list read again as <method>HeaderRow</method>, or
/// <code>{Name, Namespace}</code> when it cannot be read.</p>
ClassMethod CreatedRow(pNamespace As %String, pName As %String) As %DynamicObject [ Private ]
{
    Kill tAfter
    Do ..ReadTermListData(pNamespace, pName, .tAfter, .tAfterSC, .tAfterCaught)
    If '$IsObject(tAfterCaught) && $$$ISOK(tAfterSC) && +$Get(tAfter("exists")) Quit ..HeaderRow(pNamespace, .tAfter)
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The import file <var>pQuery</var> names as a read (Story 24.10): <code>{Name, FileEntries, Digest, Present, Namespace, root, path,
/// fileName, content}</code>, <code>Name</code> the list the file holds, <code>FileEntries</code> its distinct keys, <code>Digest</code> the text's
/// SHA-256, <code>Present</code> whether a list of that name is held, and <code>root</code>, <code>path</code> and <code>fileName</code> as the
/// query carried them, <code>content</code> always empty. <var>pId</var> is the list the file must hold, or <parameter>IMPORTID</parameter>.
/// With <var>pAction</var> (the read composed for the import) the rules and the taken name are refused as the write refuses them
/// (<method>CreateRefusal</method>).</p>
ClassMethod ReadImportFile(pNamespace As %String, pId As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..TermListImportFile(pId, .pQuery, .tText, .tData, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pAction '= "" {
        Set tSC = ..CreateRefusal(pNamespace, tData("name"), .tData, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tSC = ..TermListHeld(pNamespace, tData("name"), .tHeld, .tNow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pRow = {}
    Do pRow.%Set("Name", tData("name"), "string")
    Do pRow.%Set("FileEntries", tData("keys"), "number")
    Do pRow.%Set("Digest", tDigest, "string")
    Do pRow.%Set("Present", ''tHeld, "boolean")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set(..#ROOTKEY, $Get(pQuery(..#ROOTKEY)), "string")
    Do pRow.%Set(..#PATHKEY, $Get(pQuery(..#PATHKEY)), "string")
    Do pRow.%Set(..#FILENAMEKEY, $Get(pQuery(..#FILENAMEKEY)), "string")
    Do pRow.%Set(..#CONTENTKEY, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create the term list an import file holds (Story 24.10, AD-54). In order, each refusal before any vendor write: the file is examined
/// (<method>TermListImportFile</method>, 409 <code>IMPORTSHAPE</code> or <code>TOOLARGE</code>); its digest must be the reviewed
/// <parameter>DIGESTKEY</parameter> of the query, else 409 <code>ANALYTICS.TERMLIST.IMPORTCHANGED</code>; then
/// <method>CreateRefusal</method> (422 for a rule, 409 <code>TAKEN</code>). The list and every value are then written in one transaction
/// (<method>WriteWholeList</method>). OcuPilot's own audit row counts entries and never holds a value. The answer is the list read again.</p>
ClassMethod PerformImport(pNamespace As %String, pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..TermListImportFile(pId, .pQuery, .tText, .tData, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$Data(pQuery(..#DIGESTKEY)) || (pQuery(..#DIGESTKEY) '= tDigest) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#TERMLISTIMPORTCHANGED, .pHttpStatus, .pFault)
    Set tName = tData("name")
    Set tSC = ..CreateRefusal(pNamespace, tName, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tFailed = ..WriteWholeList(pNamespace, tName, .tData, .tVendorSC, .tCaught)
    If tFailed {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Quit ..Statused(tVendorSC, "the term list import failed", .pHttpStatus, .pFault)
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("termList", tName, "string")
    Do tEffects.%Set("entries", tData("keys"), "number")
    Do ..AuditWrite(..#VERBTERMLISTIMPORT, tName, tEffects, ..#ENTITYTERMLIST)
    Set pResult = ..CreatedRow(pNamespace, tName)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The copy of the term list <var>pName</var> read for a review (Story 24.10): <code>{Name, Modified, Entries, NewName, Present, Namespace}</code>,
/// <code>Name</code> the source as stored, <code>NewName</code> as the query carries it under <parameter>NEWNAMEKEY</parameter> and
/// <code>Present</code> whether a list of that name is held, compared without regard to case. A source that is not held is 404, with
/// <var>pAction</var> <code>ANALYTICS.TERMLIST.ABSENT</code>; with <var>pAction</var> the new name's own rule is 422 and a held name 409
/// <code>TAKEN</code>, as the write refuses them.</p>
ClassMethod ReadCopyTarget(pNamespace As %String, pName As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..TermListHeld(pNamespace, pName, .tHeld, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld Quit $Select(pAction '= "": ..ListAbsent(.pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
    Set tNew = $Get(pQuery(..#NEWNAMEKEY))
    Set tPresent = 0
    If pAction '= "" {
        Kill tViolations
        Set tSC = ..TermListViolations(..#TYPEADD, tNew, "", {}, .tViolations)
        If $$$ISERR(tSC) Quit tSC
        If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)
    }
    If tNew '= "" {
        Set tSC = ..TermListHeld(pNamespace, tNew, .tPresent, .tOther, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    If (pAction '= "") && tPresent Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#TERMLISTTAKEN, .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("Name", tData("name"), "string")
    Do pRow.%Set("Modified", tData("modDate"), "string")
    Do pRow.%Set("Entries", tData("keys"), "number")
    Do pRow.%Set("NewName", tNew, "string")
    Do pRow.%Set("Present", ''tPresent, "boolean")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Copy the term list <var>pName</var> to a new list named <parameter>NEWNAMEKEY</parameter> of the query (Story 24.10, AD-54), the classic
/// Save As without its overwrite. Each refusal before any vendor write: the new name's own rule (422), the source not held (404
/// <code>ABSENT</code>), then <method>CreateRefusal</method>: the whole list's rules under the new name (422), then the new name held (409
/// <code>TAKEN</code>, which includes the source's own name). The new list is the source's header and every entry, written in one transaction
/// (<method>WriteWholeList</method>) with a modification time of its own. The source is only read. The answer is the new list read again.</p>
ClassMethod PerformCopy(pNamespace As %String, pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tNew = $Get(pQuery(..#NEWNAMEKEY))
    Kill tViolations
    Set tSC = ..TermListViolations(..#TYPEADD, tNew, "", {}, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)
    Set tSC = ..TermListHeld(pNamespace, pName, .tHeld, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tHeld Quit ..ListAbsent(.pHttpStatus, .pFault)
    Set tSC = ..CreateRefusal(pNamespace, tNew, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tFailed = ..WriteWholeList(pNamespace, tNew, .tData, .tVendorSC, .tCaught)
    If tFailed {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Quit ..Statused(tVendorSC, "the term list copy failed", .pHttpStatus, .pFault)
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("termList", tNew, "string")
    Do tEffects.%Set("source", tData("name"), "string")
    Do tEffects.%Set("entries", tData("keys"), "number")
    Do ..AuditWrite(..#VERBTERMLISTCOPY, tNew, tEffects, ..#ENTITYTERMLIST)
    Set pResult = ..CreatedRow(pNamespace, tNew)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The string member <var>pName</var> of <var>pBody</var>, <code>""</code> when it holds none. Pure.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String [ Private ]
{
    Quit $Select(pBody.%GetTypeOf(pName) = "string": pBody.%Get(pName), 1: "")
}

/// <p>The string member <var>pName</var> of <var>pBody</var>, else <var>pDefault</var>. Pure.</p>
ClassMethod TextOr(pBody As %DynamicObject, pName As %String, pDefault As %String) As %String [ Private ]
{
    Quit $Select(pBody.%GetTypeOf(pName) = "string": pBody.%Get(pName), 1: pDefault)
}

/// <p>The <code>HideValue</code> member of <var>pBody</var> as 0 or 1, else <var>pDefault</var>. Pure.</p>
ClassMethod Hidden(pBody As %DynamicObject, pDefault As %Boolean) As %Boolean [ Private ]
{
    Set tType = pBody.%GetTypeOf("HideValue")
    If (tType = "boolean") || (tType = "number") Quit ''pBody.%Get("HideValue")
    Quit ''pDefault
}

/// <p>The <code>Fields</code> array of <var>pBody</var> as the vendor's <code>^</code>-delimited text, else <var>pDefault</var>. Pure.</p>
ClassMethod FieldListOf(pBody As %DynamicObject, pDefault As %String) As %String [ Private ]
{
    If pBody.%GetTypeOf("Fields") '= "array" Quit pDefault
    Set tList = ""
    Set tIterator = pBody.Fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tList = tList _ $Select(tList = "": "", 1: "^") _ tField
    }
    Quit tList
}

/// <p>The vendor's create of the term list <var>pName</var> in <var>pNamespace</var> (<code>%CreateTermList</code>), switched by explicit
/// save and restore (AD-16); an exception is <var>pCaught</var>. The vendor's create kills a list of the same name, so the caller has
/// found none first. A seam: a fixture overrides it to observe or fail the call.</p>
ClassMethod VendorTermListCreate(pNamespace As %String, pName As %String, pCaption As %String, pFieldList As %String, pPattern As %String, pDescription As %String, pSubject As %String, pHide As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.TermList).%CreateTermList(pName, pCaption, pFieldList, pPattern, pDescription, pSubject, pHide)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The vendor's header write of the term list <var>pName</var> (<code>%FromObj</code> of a header with no values, which sets the seven
/// header nodes and kills nothing), as <method>VendorTermListCreate</method> is called.</p>
ClassMethod VendorTermListHeader(pNamespace As %String, pName As %String, pCaption As %String, pFieldList As %String, pPattern As %String, pDescription As %String, pSubject As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = ##class(%DeepSee.UserLibrary.TermList).%New()
        Set tObject.name = pName
        Set tObject.caption = pCaption
        Set tObject.fieldListString = pFieldList
        Set tObject.pattern = pPattern
        Set tObject.description = pDescription
        Set tObject.subjectArea = pSubject
        Set tObject.modDate = $ZDateTime($Horolog, 3)
        Set tSC = ##class(%DeepSee.TermList).%FromObj(tObject)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The hide-value flag of the term list <var>pName</var>, the one header node the vendor offers no call for (its own documented layout:
/// <code>^DeepSee.TermList(ID, "hideValue")</code>, which <code>%ToObj</code> never reads): set to 1, or killed for 0, as the vendor's
/// create leaves it. Called as <method>VendorTermListCreate</method> is.</p>
ClassMethod VendorTermListHide(pNamespace As %String, pName As %String, pHide As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tId = $ZConvert(pName, "U")
        If pHide {
            Set ^DeepSee.TermList(tId, "hideValue") = 1
        } Else {
            Kill ^DeepSee.TermList(tId, "hideValue")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The vendor's value write (<code>%SetValue</code>) of <var>pValue</var> into the entry <var>pKey</var> of <var>pName</var>, under the
/// field <var>pField</var> or, when it is <code>""</code>, as the entry's own value. Called as <method>VendorTermListCreate</method> is.</p>
ClassMethod VendorTermListSetValue(pNamespace As %String, pName As %String, pKey As %String, pValue As %String, pField As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.TermList).%SetValue(pName, pKey, pValue, pField)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The removal of the entry <var>pKey</var> of <var>pName</var>, which the vendor's class offers no call for: its own documented layout,
/// <code>Kill ^DeepSee.TermList(ID, "data", key)</code>, then the modified stamp as <code>%SetValue</code> sets it. Called as
/// <method>VendorTermListCreate</method> is.</p>
ClassMethod VendorTermListRemoveEntry(pNamespace As %String, pName As %String, pKey As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tId = $ZConvert(pName, "U")
        Kill ^DeepSee.TermList(tId, "data", pKey)
        Set ^DeepSee.TermList(tId, "modDate") = $ZDateTime($Horolog, 3)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The vendor's delete of the term list <var>pName</var> (<code>%DeleteTermList</code>), as <method>VendorTermListCreate</method> is
/// called.</p>
ClassMethod VendorTermListDelete(pNamespace As %String, pName As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.TermList).%DeleteTermList(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Whether <var>pType</var> is one of the folder manager's three writes (Story 24.10): an export, an import or a delete.</p>
ClassMethod IsFolderItemWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPEDELETE)
}

/// <p>Whether <var>pType</var> is one of the folder items' typed calls: the reads <code>FOLDERITEM</code>, <code>EXPORTITEM</code> and
/// <code>IMPORTFILE</code>, and the three writes.</p>
ClassMethod IsFolderItemType(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEFOLDERITEM) || (pType = ..#TYPEEXPORTITEM) || (pType = ..#TYPEIMPORTFILE) || ..IsFolderItemWrite(pType)
}

/// <p>Whether <var>pType</var>, with <var>pAction</var> as the write it is composed for (<code>""</code> for a plain read), changes a folder item and so needs
/// the destination's gate (<method>AdmitFolderItem</method>): an import or a delete, and the single-object read or the import's file read composed for one.
/// An export reads only. Pure.</p>
ClassMethod ChangesFolderItems(pType As %String, pAction As %String = "") As %Boolean
{
    If pType = ..#TYPEEXPORT Quit 0
    If (pType = ..#TYPEIMPORT) || (pType = ..#TYPEDELETE) Quit 1
    If (pAction = "") || (pAction = ..#TYPEEXPORT) Quit 0
    Quit (pType = ..#TYPEFOLDERITEM) || (pType = ..#TYPEIMPORTFILE)
}

/// <p>The folder manager's destination gate for an import or a delete (Story 24.10, AD-29, AD-65): <method>AdmitJournaled</method> over the database
/// <parameter>FOLDERITEMGLOBAL</parameter> maps to, with the folder items' own refusal codes. Names no vendor class.</p>
ClassMethod AdmitFolderItem(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..AdmitJournaled(pNamespace, ..#FOLDERITEMGLOBAL, ##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMREADONLY, ##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMNOTJOURNALED, .pHttpStatus, .pFault)
}

/// <p>Whether <var>pName</var> can be a folder item's full name: 1 to 600 characters with no control character. Pure.</p>
ClassMethod FolderItemShaped(pName As %String) As %Boolean
{
    Quit (pName '= "") && ($Length(pName) <= 600) && ($ZStrip(pName, "*C") = pName)
}

/// <p>Whether the existence answer <var>pCode</var> of <code>%FolderItemExists</code> is an item the caller may see: 1, or 3 for a locked one. 0 is no item
/// and 2 an item the caller's resources hide, which this port reads as absent. Pure.</p>
ClassMethod FolderItemVisible(pCode As %Integer) As %Boolean
{
    Quit (pCode = 1) || (pCode = 3)
}

/// <p>404 <code>ANALYTICS.FOLDERITEM.ABSENT</code>: the folder item is not there, or not shown to the caller.</p>
ClassMethod FolderItemAbsent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMABSENT, ##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMABSENT, .pHttpStatus, .pFault)
}

/// <p>The folder item <var>pName</var> as the vendor reports it in <var>pNamespace</var>, switched by explicit save and restore (AD-16), into
/// <var>pData</var>: <code>code</code> is <code>%FolderItemExists</code>'s answer (0 none, 1 visible, 2 held but hidden from the caller, 3 locked), and for 1
/// and 3 the item's <code>name</code> as stored, <code>type</code>, <code>owner</code>, <code>modified</code> (the vendor's UTC stamp) and
/// <code>locked</code>. A locked item the caller's resources hide reads 2, since the vendor answers 3 before it checks them. An exception is
/// <var>pCaught</var>. A seam: a fixture overrides it to observe the call.</p>
ClassMethod ReadFolderItem(pNamespace As %String, pName As %String, Output pData, Output pCaught As %Exception.AbstractException)
{
    Kill pData
    Set pData("code") = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCode = ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(pName, .tId)
        If (tCode = 1) || (tCode = 3) {
            Set tItem = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(tId)
            If '$IsObject(tItem) {
                Set tCode = 0
            } ElseIf (tCode = 3) && 'tItem.%CheckResource() {
                Set tCode = 2
            } Else {
                Set pData("name") = tItem.fullName
                Set pData("type") = tItem.%GetTypeName()
                Set pData("owner") = tItem.owner
                Set pData("modified") = tItem.timeModified
                Set pData("locked") = ''tItem.locked
            }
            Set tItem = ""
        }
        Set pData("code") = tCode
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p><method>ReadFolderItem</method> of <var>pName</var>, a name that cannot be a folder item answering none, with a fault as the answer's error
/// status.</p>
ClassMethod FolderItemFacts(pNamespace As %String, pName As %String, Output pData, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pData
    Set pData("code") = 0
    If '..FolderItemShaped(pName) Quit $$$OK
    Set tCaught = ""
    Do ..ReadFolderItem(pNamespace, pName, .pData, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the folder item could not be read", .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The folder item read into <var>pData</var> as a row: <code>{Name, Type, Owner, Modified, Locked, Namespace}</code>, <code>Modified</code> the instance's
/// local <code>YYYY-MM-DD HH:MM:SS</code> as the list shows it. Pure.</p>
ClassMethod FolderItemRow(pNamespace As %String, ByRef pData) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("Name", pData("name"), "string")
    Do tRow.%Set("Type", pData("type"), "string")
    Do tRow.%Set("Owner", pData("owner"), "string")
    Do tRow.%Set("Modified", ..LocalStamp(pData("modified")), "string")
    Do tRow.%Set("Locked", ''pData("locked"), "boolean")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The folder item classes of <var>pNamespace</var> as the vendor lists them (<code>%GetFolderItemClasses</code>), switched by explicit save and
/// restore (AD-16), into <var>pClasses</var>: <code>pClasses(&lt;xml element name&gt;)</code> is <code>$ListBuild(class, item type extension, XML
/// namespace)</code>. A class with no element name or no item type names no item and is left out. A fault, or a vendor error, is <var>pCaught</var>. A
/// seam: a fixture overrides it.</p>
ClassMethod FolderItemClasses(pNamespace As %String, Output pClasses, Output pCaught As %Exception.AbstractException)
{
    Kill pClasses
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.UserLibrary.Utils).%GetFolderItemClasses(.tList)
        If $$$ISERR(tSC) {
            Set pCaught = ##class(%Exception.StatusException).CreateFromStatus(tSC)
        } Else {
            Set tAt = ""
            For {
                Set tAt = $Order(tList(tAt))
                If tAt = "" Quit
                Set tClass = $List(tList(tAt), 1)
                Set tXml = $List(tList(tAt), 2)
                Set tType = $Parameter(tClass, "ITEMTYPE")
                If (tXml '= "") && (tType '= "") Set pClasses(tXml) = $ListBuild(tClass, tType, $Parameter(tClass, "NAMESPACE"))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Read the import text <var>pText</var> as folder items (Story 24.10) and answer whether it is a file this port imports; <var>pCode</var> says why not,
/// <code>SHAPE</code> or <code>TOOLARGE</code> (more than <parameter>MAXIMPORTITEMS</parameter> items). <var>pClasses</var> is
/// <method>FolderItemClasses</method>' answer. It parses with <class>%XML.TextReader</class> alone (no document type definition is read, and nothing is
/// instantiated, so no folder is created) and accepts exactly two shapes:</p>
/// <ul>
/// <li>one folder item element as the root, which is what the export writes;</li>
/// <li>an <code>Export</code> root whose every child is a <code>Document</code> named <code>*.DFI</code> holding exactly one folder item element, which is
/// the classic page's export.</li>
/// </ul>
/// <p>A class, a routine, another document type, a <code>folder</code> element, an element in another XML namespace than its class's, an item with no name
/// or one the vendor cannot address, or a name held twice (without regard to case) is <code>SHAPE</code>. <var>pItems</var> is the count and
/// <code>pItems(n)</code> the full name of item <code>n</code>, in file order: the folder, <code>/</code>, the name, <code>.</code> and the item type.
/// Reads nothing from the instance and writes nothing.</p>
ClassMethod FolderItemsInText(pText As %String, ByRef pClasses, Output pItems, Output pCode As %String) As %Boolean
{
    Kill pItems
    Set pItems = 0
    Set pCode = "SHAPE"
    Try {
        Set tSC = ##class(%XML.TextReader).ParseStream(..Utf8Stream(pText), .tReader, , ..#XMLPARSEFLAGS)
        If $$$ISERR(tSC) Quit
        Set tMode = ""
        Set tDocs = 0
        Set tDocItems = 0
        Set tBad = 0
        Set tBig = 0
        While 'tBad && 'tBig && tReader.Read() {
            If tReader.NodeType '= "element" Continue
            Set tDepth = tReader.Depth
            Set tName = tReader.LocalName
            Set tIsItem = 0
            If tDepth = 1 {
                If $Data(pClasses(tName)) {
                    Set tMode = "item"
                    Set tIsItem = 1
                } ElseIf (tName = "Export") && (tReader.NamespaceUri = "") {
                    Set tMode = "wrapper"
                } Else {
                    Set tBad = 1
                }
            } ElseIf tMode = "wrapper" {
                If tDepth = 2 {
                    Set tDocName = ""
                    If tReader.MoveToAttributeName("name") Set tDocName = tReader.Value
                    Do tReader.MoveToElement()
                    If (tName '= "Document") || (tReader.NamespaceUri '= "") || ($ZConvert($Extract(tDocName, *-3, *), "U") '= ".DFI") || (tDocs && 'tDocItems) Set tBad = 1
                    Set tDocs = tDocs + 1
                    Set tDocItems = 0
                } ElseIf tDepth = 3 {
                    If (tReader.Path '= ("/Export/Document/" _ tName)) || '$Data(pClasses(tName)) {
                        Set tBad = 1
                    } Else {
                        Set tIsItem = 1
                        Set tDocItems = tDocItems + 1
                        If tDocItems > 1 Set tBad = 1
                    }
                }
            }
            If 'tIsItem || tBad Continue
            Set tInfo = pClasses(tName)
            Set tItemName = ""
            Set tFolder = ""
            If tReader.MoveToAttributeName("name") Set tItemName = tReader.Value
            Do tReader.MoveToElement()
            If tReader.MoveToAttributeName("folderName") Set tFolder = tReader.Value
            Do tReader.MoveToElement()
            If (tReader.NamespaceUri '= $List(tInfo, 3)) || (tItemName = "") || ($Length(tItemName) > ..#NAMEMAX) || ($Length(tFolder) > ..#NAMEMAX) || (tItemName [ "/") || ($ZStrip(tItemName _ tFolder, "*C") '= (tItemName _ tFolder)) {
                Set tBad = 1
                Continue
            }
            Set tFull = tFolder _ $Select(tFolder = "": "", 1: "/") _ tItemName _ "." _ $List(tInfo, 2)
            If $Data(tSeen($ZConvert(tFull, "U"))) {
                Set tBad = 1
                Continue
            }
            Set tSeen($ZConvert(tFull, "U")) = ""
            If pItems >= ..#MAXIMPORTITEMS {
                Set tBig = 1
                Continue
            }
            Set pItems = pItems + 1
            Set pItems(pItems) = tFull
        }
        If tBig {
            Set pCode = "TOOLARGE"
            Quit
        }
        If tBad || (pItems < 1) || ((tMode = "wrapper") && (tDocs && 'tDocItems)) Quit
        Set pCode = ""
    } Catch {
        Set pCode = "SHAPE"
    }
    If pCode '= "" {
        Kill pItems
        Set pItems = 0
    }
    Quit pCode = ""
}

/// <p>The import file a query names, examined (Story 24.10): its text (<method>ImportText</method>), its items (<method>FolderItemsInText</method>) and its
/// digest. 409 <code>ANALYTICS.FOLDERITEM.IMPORTSHAPE</code> when the text is not folder items only, or its first item is not <var>pId</var>, unless
/// <var>pId</var> is <parameter>IMPORTID</parameter>; 409 <code>TOOLARGE</code> for text past the bound or a file of more items than
/// <parameter>MAXIMPORTITEMS</parameter>. Nothing is written.</p>
ClassMethod FolderItemImportFile(pNamespace As %String, pId As %String, ByRef pQuery, Output pText As %String, Output pItems, Output pDigest As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pResolved As %String) As %Status [ Private ]
{
    Kill pItems
    Set pItems = 0
    Set pDigest = ""
    Set tSC = ..ImportText(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTOOLARGE, .pQuery, .pText, .pHttpStatus, .pFault, .pResolved)
    If $$$ISERR(tSC) Quit tSC
    Do ..FolderItemClasses(pNamespace, .tClasses, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the folder item classes could not be read", .pHttpStatus, .pFault)
    Set tShaped = ..FolderItemsInText(pText, .tClasses, .pItems, .tCode)
    If tCode = "TOOLARGE" Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTOOLARGE, .pHttpStatus, .pFault)
    If 'tShaped || ((pId '= ..#IMPORTID) && (pId '= pItems(1))) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMIMPORTSHAPE, .pHttpStatus, .pFault)
    Set pDigest = ..TextDigest(pText)
    If pDigest = "" Quit ..Fail("the import file's digest could not be taken", $$$ERROR($$$GeneralError, "digest"), .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Whether the instance holds any of the items <var>pItems</var> names (<var>pTaken</var>), in any letter case and whoever may see it
/// (<code>%FolderItemExists</code> other than 0).</p>
ClassMethod FolderItemsTaken(pNamespace As %String, ByRef pItems, Output pTaken As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pTaken = 0
    Set tSC = $$$OK
    For tAt = 1:1:pItems {
        Set tSC = ..FolderItemFacts(pNamespace, pItems(tAt), .tData, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If +tData("code") {
            Set pTaken = 1
            Quit
        }
    }
    Quit tSC
}

/// <p>Serve the folder items' typed calls after <method>Invoke</method>'s gate (Story 24.10): the reads <code>FOLDERITEM</code> (one item as
/// <method>FolderItemRow</method>), <code>EXPORTITEM</code> and <code>IMPORTFILE</code>, and the writes <code>EXPORT</code>, <code>IMPORT</code> and
/// <code>DELETE</code>. The item is named under <parameter>IDKEY</parameter>, its full name kept exactly (AD-13); an import names the literal
/// <parameter>IMPORTID</parameter> or the first item its file holds. A read carrying <parameter>ACTIONKEY</parameter> is composed for that write: an item
/// that is not there is 404 <code>ANALYTICS.FOLDERITEM.ABSENT</code> and a delete's read of a locked item is 409 <code>LOCKED</code>; a plain read of an item
/// that is not there is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod InvokeFolderItem(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = $Get(pQuery(..#IDKEY))
    If tName = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONFOLDERITEMREQUIRED, .pHttpStatus, .pFault)
    Set tWrite = ..IsFolderItemWrite(pType)
    Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
    If (tAction '= "") && '..IsFolderItemWrite(tAction) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    If pType = ..#TYPEEXPORTITEM Quit ..ReadExportItem(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEEXPORT Quit ..PerformFolderExport(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEIMPORTFILE Quit ..ReadFolderImportFile(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEIMPORT Quit ..PerformFolderImport(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEDELETE Quit ..PerformFolderDelete(pNamespace, tName, .pResult, .pHttpStatus, .pFault)
    Quit ..ReadFolderItemRow(pNamespace, tName, tAction, .pResult, .pHttpStatus, .pFault)
}

/// <p>The single-object read <code>FOLDERITEM</code>: the item <var>pName</var> as <method>FolderItemRow</method>. 404 when it is not there or not shown
/// to the caller, <code>ANALYTICS.FOLDERITEM.ABSENT</code> with <var>pAction</var> (the read composed for a write); with <var>pAction</var>
/// <code>DELETE</code> a locked item is 409 <code>ANALYTICS.FOLDERITEM.LOCKED</code>, as the write refuses it.</p>
ClassMethod ReadFolderItemRow(pNamespace As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..FolderItemFacts(pNamespace, pName, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..FolderItemVisible(tData("code")) Quit $Select(pAction '= "": ..FolderItemAbsent(.pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
    If (pAction = ..#TYPEDELETE) && (tData("code") = 3) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMLOCKED, .pHttpStatus, .pFault)
    Set pRow = ..FolderItemRow(pNamespace, .tData)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The folder item <var>pName</var> as a read of the export: the row <method>ReadFolderItemRow</method> answers, with the file the query names under
/// <parameter>ROOTKEY</parameter> and <parameter>PATHKEY</parameter>, both empty when none. Gated by <method>AdmitRead</method>.</p>
ClassMethod ReadExportItem(pNamespace As %String, pName As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..AdmitRead(pNamespace, ..#FOLDERITEMGLOBAL, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..FolderItemFacts(pNamespace, pName, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..FolderItemVisible(tData("code")) Quit $Select(pAction '= "": ..FolderItemAbsent(.pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
    Set pRow = ..FolderItemRow(pNamespace, .tData)
    Do pRow.%Set(..#ROOTKEY, $Get(pQuery(..#ROOTKEY)), "string")
    Do pRow.%Set(..#PATHKEY, $Get(pQuery(..#PATHKEY)), "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Export the folder item <var>pName</var> as the vendor's own XML (<code>%Export</code>): to the server file <parameter>ROOTKEY</parameter> and
/// <parameter>PATHKEY</parameter> name, resolved and checked by <method>ExportFile</method> before the call, the answer <code>{Name, Namespace, root,
/// path}</code>; or, naming neither, as lines for the browser, the answer <code>{Name, Namespace, lines}</code>, 409
/// <code>ANALYTICS.FOLDERITEM.TOOLARGE</code> past <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters. It reads only
/// (<method>AdmitRead</method>), writes nothing but the file, and records OcuPilot's own audit row. An item that is not there, or not shown to the caller, is 404
/// <code>ANALYTICS.FOLDERITEM.ABSENT</code>.</p>
ClassMethod PerformFolderExport(pNamespace As %String, pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..AdmitRead(pNamespace, ..#FOLDERITEMGLOBAL, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tToFile = (tRoot '= "") || (tPath '= "")
    Set tSC = ..FolderItemFacts(pNamespace, pName, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..FolderItemVisible(tData("code")) Quit ..FolderItemAbsent(.pHttpStatus, .pFault)
    Set tResolved = ""
    If tToFile {
        Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tCaught = ""
    Set tTooLarge = 0
    Set tVendorSC = ..VendorFolderItemExport(pNamespace, tData("name"), tResolved, .tLines, .tTooLarge, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the folder item export failed", .pHttpStatus, .pFault)
    If tTooLarge Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTOOLARGE, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the folder item export failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("folderItem", tData("name"), "string")
    Do tEffects.%Set("toFile", ''tToFile, "boolean")
    Do ..AuditWrite(..#VERBFOLDERITEMEXPORT, tData("name"), tEffects, ..#ENTITYFOLDERITEM)
    Set pResult = {}
    Do pResult.%Set("Name", tData("name"), "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    If tToFile {
        Do pResult.%Set(..#ROOTKEY, tRoot, "string")
        Do pResult.%Set(..#PATHKEY, tPath, "string")
    } Else {
        Do pResult.%Set("lines", tLines)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's export of the folder item <var>pName</var> in <var>pNamespace</var> (<code>%Export</code> with no console output), switched by explicit
/// save and restore (AD-16): to the file <var>pFile</var> when it is not empty, else into a stream whose lines are <var>pLines</var> (an array of strings)
/// unless they pass <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters, which is <var>pTooLarge</var>; the first is
/// <parameter>XMLDECLARATION</parameter>. An exception is <var>pCaught</var>. A seam: a fixture overrides it to observe or fail the call.</p>
ClassMethod VendorFolderItemExport(pNamespace As %String, pName As %String, pFile As %String, Output pLines As %DynamicArray, Output pTooLarge As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set pLines = ""
    Set pTooLarge = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tStream = $Select(pFile = "": ##class(%Stream.TmpCharacter).%New(), 1: "")
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.UserLibrary.Utils).%Export(pName, $Select(pFile = "": tStream, 1: pFile), 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    If (pFile '= "") || $$$ISERR(tSC) || $IsObject(pCaught) Quit tSC
    Set pLines = []
    Do pLines.%Push(..#XMLDECLARATION, "string")
    Set tTotal = $Length(..#XMLDECLARATION) + 1
    Do tStream.Rewind()
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine(##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS)
        Set tTotal = tTotal + $Length(tLine) + 1
        If tTotal > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS {
            Set pTooLarge = 1
            Set pLines = ""
            Quit
        }
        Do pLines.%Push(tLine, "string")
    }
    Quit $$$OK
}

/// <p>The import file <var>pQuery</var> names as a read (Story 24.10): <code>{Items, Count, Digest, Present, Namespace, root, path, fileName,
/// content}</code>, <code>Items</code> the full names the file holds in file order, <code>Count</code> how many, <code>Digest</code> the text's SHA-256,
/// <code>Present</code> whether the instance holds any of them, and <code>root</code>, <code>path</code> and <code>fileName</code> as the query carried
/// them, <code>content</code> always empty. <var>pId</var> is the first item the file must hold, or <parameter>IMPORTID</parameter>. With
/// <var>pAction</var> (the read composed for the import) a name already held is refused 409 <code>TAKEN</code>, as the write refuses it.</p>
ClassMethod ReadFolderImportFile(pNamespace As %String, pId As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..FolderItemImportFile(pNamespace, pId, .pQuery, .tText, .tItems, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..FolderItemsTaken(pNamespace, .tItems, .tTaken, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If (pAction '= "") && tTaken Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTAKEN, .pHttpStatus, .pFault)
    Set tNames = []
    For tAt = 1:1:tItems {
        Do tNames.%Push(tItems(tAt), "string")
    }
    Set pRow = {}
    Do pRow.%Set("Items", tNames)
    Do pRow.%Set("Count", tItems, "number")
    Do pRow.%Set("Digest", tDigest, "string")
    Do pRow.%Set("Present", ''tTaken, "boolean")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set(..#ROOTKEY, $Get(pQuery(..#ROOTKEY)), "string")
    Do pRow.%Set(..#PATHKEY, $Get(pQuery(..#PATHKEY)), "string")
    Do pRow.%Set(..#FILENAMEKEY, $Get(pQuery(..#FILENAMEKEY)), "string")
    Do pRow.%Set(..#CONTENTKEY, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create every folder item an import file holds (Story 24.10, AD-54). In order, each refusal before any vendor write: the file is examined
/// (<method>FolderItemImportFile</method>, 409 <code>IMPORTSHAPE</code> or <code>TOOLARGE</code>); its digest must be the reviewed
/// <parameter>DIGESTKEY</parameter> of the query, else 409 <code>ANALYTICS.FOLDERITEM.IMPORTCHANGED</code>; then no item of the file may be held, else 409
/// <code>TAKEN</code>. The items are then written by one <method>VendorFolderItemImport</method> inside one transaction, rolled back when it fails or
/// creates other than the items the file names, so every item is created or none, and a folder the import would create goes with them. OcuPilot's own audit
/// row counts the items and names the first, and never holds a definition. The answer is the first item read again, with <code>Count</code>.</p>
ClassMethod PerformFolderImport(pNamespace As %String, pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..FolderItemImportFile(pNamespace, pId, .pQuery, .tText, .tItems, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$Data(pQuery(..#DIGESTKEY)) || (pQuery(..#DIGESTKEY) '= tDigest) Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMIMPORTCHANGED, .pHttpStatus, .pFault)
    Set tSC = ..FolderItemsTaken(pNamespace, .tItems, .tTaken, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tTaken Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTAKEN, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tLoaded = 0
    TSTART
    Set tVendorSC = ..VendorFolderItemImport(pNamespace, tText, .tLoaded, .tCaught)
    Set tFailed = $IsObject(tCaught) || $$$ISERR(tVendorSC)
    Set tShort = 'tFailed && (tLoaded '= tItems)
    If tFailed || tShort {
        TROLLBACK 1
    } Else {
        TCOMMIT
    }
    If tShort Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMIMPORTSHAPE, .pHttpStatus, .pFault)
    If tFailed {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Quit ..Statused(tVendorSC, "the folder item import failed", .pHttpStatus, .pFault)
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("folderItem", tItems(1), "string")
    Do tEffects.%Set("items", tItems, "number")
    Do ..AuditWrite(..#VERBFOLDERITEMIMPORT, tItems(1), tEffects, ..#ENTITYFOLDERITEM)
    Set tSC = ..FolderItemFacts(pNamespace, tItems(1), .tAfter, .tAfterHttp, .tAfterFault)
    If $$$ISOK(tSC) && ..FolderItemVisible(tAfter("code")) {
        Set pResult = ..FolderItemRow(pNamespace, .tAfter)
    } Else {
        Set pResult = {}
        Do pResult.%Set("Name", tItems(1), "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
    }
    Do pResult.%Set("Count", tItems, "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's import of the text <var>pText</var> in <var>pNamespace</var> (<code>%Import</code> of its UTF-8 bytes, replacing nothing, killing nothing
/// and printing nothing), switched by explicit save and restore (AD-16); <var>pLoaded</var> is how many items it saved. An exception is
/// <var>pCaught</var>. The caller holds the transaction. A seam: a fixture overrides it to observe the call or to fail after it.</p>
ClassMethod VendorFolderItemImport(pNamespace As %String, pText As %String, Output pLoaded As %Integer, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set pLoaded = 0
    Set tSC = $$$OK
    Set tBytes = ..Utf8Stream(pText)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Kill tLoaded
        Set tSC = ##class(%DeepSee.UserLibrary.Utils).%Import(tBytes, 0, 0, 0, "", .tLoaded)
        Set pLoaded = +$Get(tLoaded)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Delete the folder item <var>pName</var> (Story 24.10): the vendor's <code>%DeleteFolderItem</code>, which removes the item for every user. Each refusal
/// before any vendor write: the item not there or not shown to the caller is 404 <code>ANALYTICS.FOLDERITEM.ABSENT</code>, and a locked one 409
/// <code>LOCKED</code>. The call runs in one transaction, rolled back when it fails or deletes nothing. OcuPilot's own audit row names the item. The answer
/// is <code>{Name, Namespace}</code>.</p>
ClassMethod PerformFolderDelete(pNamespace As %String, pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..FolderItemFacts(pNamespace, pName, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..FolderItemVisible(tData("code")) Quit ..FolderItemAbsent(.pHttpStatus, .pFault)
    If tData("code") = 3 Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMLOCKED, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tCount = 0
    TSTART
    Set tVendorSC = ..VendorFolderItemDelete(pNamespace, tData("name"), .tCount, .tCaught)
    Set tFailed = $IsObject(tCaught) || $$$ISERR(tVendorSC)
    If tFailed || ('tCount) {
        TROLLBACK 1
    } Else {
        TCOMMIT
    }
    If tFailed {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Quit ..Statused(tVendorSC, "the folder item delete failed", .pHttpStatus, .pFault)
    }
    If 'tCount Quit ..FolderItemAbsent(.pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("folderItem", tData("name"), "string")
    Do ..AuditWrite(..#VERBFOLDERITEMDELETE, tData("name"), tEffects, ..#ENTITYFOLDERITEM)
    Set pResult = {}
    Do pResult.%Set("Name", tData("name"), "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's delete of the folder item <var>pName</var> in <var>pNamespace</var> (<code>%DeleteFolderItem</code>), switched by explicit save and
/// restore (AD-16); <var>pCount</var> is how many items it deleted. An exception is <var>pCaught</var>. The caller holds the transaction. A seam: a
/// fixture overrides it to observe or fail the call.</p>
ClassMethod VendorFolderItemDelete(pNamespace As %String, pName As %String, Output pCount As %Integer, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set pCount = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%DeepSee.UserLibrary.Utils).%DeleteFolderItem(pName, .tCount)
        Set pCount = +$Get(tCount)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>The lines <method>Snippet</method> adds for a folder item write <var>pType</var> of the item the id <var>pId</var> names (Story 24.10), the vendor calls
/// <method>InvokeFolderItem</method> makes. An export is <code>%Export</code> of an item that is there, to the server file the query names, resolved as the
/// write resolves it (<method>ExportFile</method>), or to the current device; an import is every item of the file checked free, then <code>%Import</code> of the
/// server file in one transaction; a delete is the item checked there and not locked, then <code>%DeleteFolderItem</code> in one. A file that cannot be read as
/// folder items or holds another first item than the one named, a file that is not the reviewed text, and a file the export cannot resolve are each a script that
/// only sets the refusal. A local file's text is never in a script, so an import of one that reads as folder items has no script form: <code>""</code>.</p>
ClassMethod FolderItemSnippet(pType As %String, pId As %String, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tUtils = "##class(%DeepSee.UserLibrary.Utils)"
    If pType = ..#TYPEIMPORT {
        Set tShape = tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMIMPORTSHAPE) _ ")"
        Set tSC = ..ImportText(##class(OcuPilot.Api.AnalyticsError).#FOLDERITEMTOOLARGE, .pQuery, .tText, .tHttp, .tFault, .tResolved)
        If $$$ISERR(tSC) Quit tShape
        Do ..FolderItemClasses($Get(pQuery(..#NAMESPACEKEY)), .tClasses, .tCaught)
        If $IsObject(tCaught) || '..FolderItemsInText(tText, .tClasses, .tItems, .tCode) || ((pId '= ..#IMPORTID) && (pId '= tItems(1))) Quit tShape
        If $Get(pQuery(..#DIGESTKEY)) '= ..TextDigest(tText) Quit tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMIMPORTCHANGED) _ ")"
        If tResolved = "" Quit ""
        Set tScript = tNL _ " TSTART" _ tNL _ " Set tSC = 1"
        For tAt = 1:1:tItems {
            Set tScript = tScript _ tNL _ " If $System.Status.IsOK(tSC), " _ tUtils _ ".%FolderItemExists(" _ ..Literal(tItems(tAt)) _ ") Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMTAKEN) _ ")"
        }
        Quit tScript _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tUtils _ ".%Import(" _ ..Literal(tResolved) _ ", 0, 0)" _ tNL _ " If $System.Status.IsOK(tSC) { TCOMMIT } Else { TROLLBACK 1 }"
    }
    Set tName = ..Literal(pId)
    Set tAbsent = "$System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMABSENT) _ ")"
    Set tHeld = " Set tExists = " _ tUtils _ ".%FolderItemExists(" _ tName _ "), tSC = $Select((tExists = 1) || (tExists = 3): 1, 1: " _ tAbsent _ ")"
    If pType = ..#TYPEDELETE {
        Quit tNL _ tHeld _ tNL _ " If $System.Status.IsOK(tSC), tExists = 3 Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONFOLDERITEMLOCKED) _ ")" _ tNL _ " TSTART" _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tUtils _ ".%DeleteFolderItem(" _ tName _ ")" _ tNL _ " If $System.Status.IsOK(tSC) { TCOMMIT } Else { TROLLBACK 1 }"
    }
    Set tPath = $Get(pQuery(..#PATHKEY))
    If tPath = "" {
        Quit tNL _ tHeld _ tNL _ " Set tStream = ##class(%Stream.TmpCharacter).%New()" _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tUtils _ ".%Export(" _ tName _ ", tStream, 0)" _ tNL _ " If $System.Status.IsOK(tSC) Do tStream.OutputToDevice()"
    }
    Set tSource = tNL _ " ; The server file is the allowed directory " _ $Translate($Get(pQuery(..#ROOTKEY)), $Char(10) _ $Char(13), "  ") _ " and the name " _ $Translate(tPath, $Char(10) _ $Char(13), "  ")
    Set tSC = ..ExportFile($Get(pQuery(..#ROOTKEY)), tPath, .tResolved, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSource _ tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: $System.Status.GetErrorText(tSC))) _ ")"
    Quit tSource _ tNL _ tHeld _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = " _ tUtils _ ".%Export(" _ tName _ ", " _ ..Literal(tResolved) _ ", 0)"
}

/// <p>Whether <var>pEndpoint</var> is one of the listing group endpoints (Story 24.11).</p>
ClassMethod IsListingGroupEndpoint(pEndpoint As %String) As %Boolean
{
    Quit (pEndpoint = ..#ENDPOINTLISTINGGROUPS) || (pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS)
}

/// <p>Whether <var>pType</var> is one of the listing group writes (Story 24.11): on <code>ListingGroups</code> the add, update, delete and copy, on
/// <code>ListingGroupListings</code> the listing add, change and remove, which reuse <parameter>TYPEENTRYADD</parameter>, <parameter>TYPEENTRYSET</parameter>
/// and <parameter>TYPEENTRYREMOVE</parameter>.</p>
ClassMethod IsListingGroupWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADD) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPECOPY) || (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
}

/// <p>Whether <var>pType</var>, with <var>pAction</var> as the write it is composed for (<code>""</code> for a plain read), changes a listing group and so needs
/// the destination's gate (<method>AdmitListingGroup</method>): a write, and a single-object read composed for one. Pure.</p>
ClassMethod ChangesListingGroups(pType As %String, pAction As %String = "") As %Boolean
{
    If ..IsListingGroupWrite(pType) Quit 1
    Quit (pAction '= "") && ((pType = ..#TYPELISTINGGROUP) || (pType = ..#TYPELISTING) || (pType = ..#TYPECOPYTARGET))
}

/// <p>The listing group writes' gate (AD-29, AD-61, AD-65), after the namespace gate: <parameter>LISTINGGROUPEDITPAIRS</parameter> and
/// the source code API's own pairs (<code>%Development:USE</code>, <method>OcuPilot.Port.AtelierPort.Pairs</method>) and <method>OcuPilot.Port.AtelierPort.WritePairs</method> of the
/// namespace (which adds WRITE on the routines database), because the write saves, compiles and deletes a class, then WRITE on the database <parameter>LISTINGGROUPGLOBAL</parameter> maps to, mounted read-write. 400
/// <code>PORT.VALIDATION</code> when the instance cannot name the databases. Names no vendor class.</p>
ClassMethod AdmitListingGroup(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(pNamespace)
    If tWritePairs = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    Set tFailedPair = ""
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#LISTINGGROUPEDITPAIRS) _ ##class(OcuPilot.Port.AtelierPort).Pairs() _ tWritePairs, .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit ..AdmitDestination(pNamespace, ..#LISTINGGROUPGLOBAL, ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPREADONLY, .pHttpStatus, .pFault)
}

/// <p>The class every listing group write is saved, compiled and deleted through. Overridable so a fixture can fail a call; production never overrides it.</p>
ClassMethod AtelierPortClass() As %String
{
    Quit "OcuPilot.Port.AtelierPort"
}

/// <p>404 <code>ANALYTICS.LISTINGGROUP.ABSENT</code>: the listing group, or the listing, is not there.</p>
ClassMethod ListingGroupAbsent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPABSENT, ##class(OcuPilot.Api.AnalyticsError).#REASONLISTINGGROUPABSENT, .pHttpStatus, .pFault)
}

/// <p>The listing group <var>pGroup</var> as the vendor reports it in <var>pNamespace</var>, switched by explicit save and restore (AD-16), into
/// <var>pData</var>: <code>exists</code> (the saved list the caller may see names it); <code>classes</code>, how many classes declare the name; <code>class</code>, the
/// compiled one else the first; <code>compiled</code>; the model's <code>name</code>, <code>displayName</code>, <code>description</code>, <code>disabled</code>,
/// <code>targetCubes</code>, <code>resource</code> and <code>defaultResource</code>; and <code>count</code> listings, <code>l(n, member)</code> each with its
/// <code>name</code>, <code>displayName</code>, <code>description</code>, <code>disabled</code>, <code>type</code>, <code>fields</code>, <code>formats</code>,
/// <code>orderBy</code>, <code>joins</code>, <code>sql</code>, <code>source</code>, <code>resource</code> and <code>selectMode</code>. An exception is
/// <var>pCaught</var>. A seam: a fixture overrides it.</p>
ClassMethod ReadListingGroupData(pNamespace As %String, pGroup As %String, Output pData, Output pCaught As %Exception.AbstractException)
{
    Kill pData
    Set pData("exists") = 0
    Set pData("classes") = 0
    Set pData("count") = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tGroup = $ZConvert(pGroup, "U")
        Set tSC = ##class(%DeepSee.ListingGroup).%GetListingGroups(.tSaved, 0)
        If $$$ISOK(tSC) Set tSC = ##class(%DeepSee.ListingGroup).%GetListingGroups(.tCompiled, 1)
        If $$$ISOK(tSC) && (tGroup '= "") && $Data(tSaved(tGroup)) {
            Set tClass = $List(tSaved(tGroup, 1), 5)
            Set tAt = ""
            For {
                Set tAt = $Order(tSaved(tGroup, tAt))
                If tAt = "" Quit
                If $Data(tCompiled(tGroup, 1)) && ($List(tCompiled(tGroup, 1), 5) = $List(tSaved(tGroup, tAt), 5)) {
                    Set tClass = $List(tSaved(tGroup, tAt), 5)
                    Quit
                }
            }
            Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(tClass)
            If $IsObject(tModel) && (tModel.name '= "") {
                Set pData("exists") = 1
                Set pData("classes") = +$Get(tSaved(tGroup))
                Set pData("class") = tClass
                Set pData("compiled") = ''($Data(tCompiled(tGroup, 1)) && ($List(tCompiled(tGroup, 1), 5) = tClass))
                Set pData("name") = tModel.name
                Set pData("displayName") = tModel.displayName
                Set pData("description") = tModel.description
                Set pData("disabled") = ''tModel.disabled
                Set pData("targetCubes") = tModel.targetCubes
                Set pData("resource") = tModel.resource
                Set pData("defaultResource") = tModel.defaultResource
                Set pData("count") = tModel.listings.Count()
                For tAt = 1:1:pData("count") {
                    Set tListing = tModel.listings.GetAt(tAt)
                    Set pData("l", tAt, "name") = tListing.name
                    Set pData("l", tAt, "displayName") = tListing.displayName
                    Set pData("l", tAt, "description") = tListing.description
                    Set pData("l", tAt, "disabled") = ''tListing.disabled
                    Set pData("l", tAt, "type") = tListing.listingType
                    Set pData("l", tAt, "fields") = tListing.fieldList
                    Set pData("l", tAt, "formats") = tListing.formatList
                    Set pData("l", tAt, "orderBy") = tListing.orderBy
                    Set pData("l", tAt, "joins") = tListing.joinInfo
                    Set pData("l", tAt, "sql") = tListing.sql
                    Set pData("l", tAt, "source") = tListing.sourceClass
                    Set pData("l", tAt, "resource") = tListing.resource
                    Set pData("l", tAt, "selectMode") = tListing.selectMode
                }
            }
        }
        If $$$ISERR(tSC) Set pCaught = ##class(%Exception.StatusException).CreateFromStatus(tSC)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p><method>ReadListingGroupData</method> of <var>pGroup</var>, a name that cannot be a listing group's answering none, with a fault as the answer's error
/// status.</p>
ClassMethod ListingGroupFacts(pNamespace As %String, pGroup As %String, Output pData, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pData
    Set pData("exists") = 0
    Set pData("classes") = 0
    Set pData("count") = 0
    If '..ListingNameShaped(pGroup) Quit $$$OK
    Set tCaught = ""
    Do ..ReadListingGroupData(pNamespace, pGroup, .pData, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the listing group could not be read", .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The cube names of the comma-separated <var>pText</var> as the write stores them: each stripped of surrounding whitespace, in order, an empty piece dropped. Pure.</p>
ClassMethod CubeList(pText As %String) As %List
{
    Set tCubes = ""
    For tPiece = 1:1:$Length(pText, ",") {
        Set tCube = $ZStrip($Piece(pText, ",", tPiece), "<>W")
        If tCube '= "" Set tCubes = tCubes _ $ListBuild(tCube)
    }
    Quit tCubes
}

/// <p>The target cubes <var>pText</var> as the write stores them (<method>CubeList</method> joined by a comma), the form a caller sends so the read-back finds the value it sent. Pure.</p>
ClassMethod NormalizedCubes(pText As %String) As %String
{
    Quit $ListToString(..CubeList(pText), ",")
}

/// <p>Whether <var>pName</var> can be a listing group's or a listing's name: 1 to <parameter>LISTINGNAMEMAX</parameter> characters with no control character. Pure.</p>
ClassMethod ListingNameShaped(pName As %String) As %Boolean
{
    Quit (pName '= "") && ($Length(pName) <= ..#LISTINGNAMEMAX) && ($ZStrip(pName, "*C") = pName)
}

/// <p>Whether <var>pClass</var> can be a new listing group's class: dotted letters and digits with at least one package, at most 200 characters, outside
/// the <code>%</code> packages (which the pattern excludes) and outside an <code>OcuPilot</code> package, which holds this product's own classes (AD-10). Pure.</p>
ClassMethod ListingClassShaped(pClass As %String) As %Boolean
{
    If '$Match(pClass, "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$") || ($Length(pClass) > 200) Quit 0
    Quit $ZConvert($Piece(pClass, ".", 1), "U") '= "OCUPILOT"
}

/// <p>The listing group <var>pData</var> as a row: <code>{Name, Class, Caption, Description, TargetCubes, Resource, DefaultResource, Disabled, Compiled,
/// Listings, Version, Namespace}</code>, <code>Caption</code> the model's own display name and <code>Version</code> the class's version, <code>""</code>
/// when none was read. Pure.</p>
ClassMethod ListingGroupRow(pNamespace As %String, ByRef pData, pVersion As %String = "") As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("Name", pData("name"), "string")
    Do tRow.%Set("Class", pData("class"), "string")
    Do tRow.%Set("Caption", pData("displayName"), "string")
    Do tRow.%Set("Description", pData("description"), "string")
    Do tRow.%Set("TargetCubes", pData("targetCubes"), "string")
    Do tRow.%Set("Resource", pData("resource"), "string")
    Do tRow.%Set("DefaultResource", pData("defaultResource"), "string")
    Do tRow.%Set("Disabled", ''pData("disabled"), "boolean")
    Do tRow.%Set("Compiled", ''pData("compiled"), "boolean")
    Do tRow.%Set("Listings", pData("count"), "number")
    Do tRow.%Set("Version", pVersion, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The listing at position <var>pAt</var> of the group <var>pData</var> as a row: <code>{ListingGroup, Name, DisplayName, Type, Fields, OrderBy, Joins, Formats,
/// Source, Resource, SelectMode, Disabled, Description, SQL, Version, Namespace}</code>, <code>SQL</code> only when <var>pShowSQL</var>. Pure.</p>
ClassMethod ListingRow(pNamespace As %String, ByRef pData, pAt As %Integer, pShowSQL As %Boolean, pVersion As %String = "") As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("ListingGroup", pData("name"), "string")
    Do tRow.%Set("Name", pData("l", pAt, "name"), "string")
    Do tRow.%Set("DisplayName", pData("l", pAt, "displayName"), "string")
    Do tRow.%Set("Type", pData("l", pAt, "type"), "string")
    Do tRow.%Set("Fields", pData("l", pAt, "fields"), "string")
    Do tRow.%Set("OrderBy", pData("l", pAt, "orderBy"), "string")
    Do tRow.%Set("Joins", pData("l", pAt, "joins"), "string")
    Do tRow.%Set("Formats", pData("l", pAt, "formats"), "string")
    Do tRow.%Set("Source", pData("l", pAt, "source"), "string")
    Do tRow.%Set("Resource", pData("l", pAt, "resource"), "string")
    Do tRow.%Set("SelectMode", pData("l", pAt, "selectMode"), "string")
    Do tRow.%Set("Disabled", ''pData("l", pAt, "disabled"), "boolean")
    Do tRow.%Set("Description", pData("l", pAt, "description"), "string")
    Do tRow.%Set("SQL", $Select(pShowSQL: pData("l", pAt, "sql"), 1: ""), "string")
    Do tRow.%Set("Version", pVersion, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The position of the listing named exactly <var>pName</var> in the group <var>pData</var>; 0 when it holds none. Pure.</p>
ClassMethod ListingAt(ByRef pData, pName As %String) As %Integer
{
    Set tFound = 0
    For tAt = 1:1:+$Get(pData("count")) {
        If pData("l", tAt, "name") = pName {
            Set tFound = tAt
            Quit
        }
    }
    Quit tFound
}

/// <p>The shape violations of a listing group write that need nothing from the instance, in <var>pViolations</var>
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>), every one <code>PORT.FIELD.SHAPE</code>: <var>pType</var> is the
/// write, <var>pGroup</var> and <var>pListing</var> the names it acts on, <var>pBody</var> what the caller sends. A name is
/// <method>ListingNameShaped</method>; a text member is a string within its length (a caption, resource, default resource, display name or source of at most
/// 255 characters, a description and any other of at most 32,000); <code>Disabled</code> is true or false; a listing's <code>Type</code> is <code>table</code> or <code>map</code>
/// and its <code>SelectMode</code> is <code>0</code>, <code>1</code> or <code>2</code>. Pure.</p>
ClassMethod ListingGroupViolations(pType As %String, pGroup As %String, pListing As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tListingWrite = (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    If (pType = ..#TYPEADD) && '..ListingNameShaped(pBody.%Get("Name")) Set pViolations($Increment(pViolations)) = $ListBuild("Name", tShape)
    If tListingWrite && ((pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET)) && '..ListingNameShaped(pListing) Set pViolations($Increment(pViolations)) = $ListBuild("Name", tShape)
    If (pType '= ..#TYPEADD) && (pType '= ..#TYPEUPDATE) && (pType '= ..#TYPEENTRYADD) && (pType '= ..#TYPEENTRYSET) Quit $$$OK
    Set tShort = $Select(tListingWrite: "DisplayName,Resource,Source", 1: "Caption,Resource,DefaultResource")
    Set tLong = $Select(tListingWrite: "Description,Fields,OrderBy,Joins,Formats,SQL", 1: "Description,TargetCubes")
    For tMember = 1:1:$Length(tShort, ",") {
        Set tName = $Piece(tShort, ",", tMember)
        Set tMemberType = pBody.%GetTypeOf(tName)
        If tMemberType = "unassigned" Continue
        If (tMemberType '= "string") || ($Length(pBody.%Get(tName)) > ..#SHORTTEXTMAX) Set pViolations($Increment(pViolations)) = $ListBuild(tName, tShape)
    }
    For tMember = 1:1:$Length(tLong, ",") {
        Set tName = $Piece(tLong, ",", tMember)
        Set tMemberType = pBody.%GetTypeOf(tName)
        If tMemberType = "unassigned" Continue
        If (tMemberType '= "string") || ($Length(pBody.%Get(tName)) > ..#LONGTEXTMAX) Set pViolations($Increment(pViolations)) = $ListBuild(tName, tShape)
    }
    Set tDisabledType = pBody.%GetTypeOf("Disabled")
    If (tDisabledType '= "unassigned") && (tDisabledType '= "boolean") Set pViolations($Increment(pViolations)) = $ListBuild("Disabled", tShape)
    If tListingWrite {
        If (pBody.%GetTypeOf("Type") '= "unassigned") && ((pBody.%GetTypeOf("Type") '= "string") || '$ListFind($ListBuild("table", "map"), pBody.%Get("Type"))) Set pViolations($Increment(pViolations)) = $ListBuild("Type", tShape)
        If (pBody.%GetTypeOf("SelectMode") '= "unassigned") && ((pBody.%GetTypeOf("SelectMode") '= "string") || '$ListFind($ListBuild("0", "1", "2"), pBody.%Get("SelectMode"))) Set pViolations($Increment(pViolations)) = $ListBuild("SelectMode", tShape)
    }
    Quit $$$OK
}

/// <p>The class that holds a write's new text, the cube classes it depends on and its XML, composed from the vendor's own model in <var>pNamespace</var>,
/// switched by explicit save and restore (AD-16): <var>pOp</var> is the write (<parameter>TYPEADD</parameter>, <parameter>TYPEUPDATE</parameter>,
/// <parameter>TYPECOPY</parameter>, <parameter>TYPEENTRYADD</parameter>, <parameter>TYPEENTRYSET</parameter> or <parameter>TYPEENTRYREMOVE</parameter>).
/// A write but an add starts from <code>%GetModel</code> of <var>pClass</var>, read now, so what the caller cannot see is kept as stored; an add starts
/// from a new model. <var>pBody</var> carries the members to set (<method>ListingGroupViolations</method> says which), <var>pListing</var> names the listing a
/// listing write acts on, <var>pNewName</var> and <var>pTargetCubes</var> a copy's name and optional cubes, and <var>pHasSQL</var> whether the caller holds the SQL
/// pair. <var>pXml</var> is the model written by <code>%XML.Writer</code>, as the vendor writes a class's <code>Listings</code>, and <var>pClasses</var> the
/// comma-separated cube classes of its target cubes. <var>pCode</var> is the refusal, <code>""</code> for none: <code>ABSENT</code>, <code>TAKEN</code>
/// (a group name or class already in use), <code>CUBE</code> (no cube, a missing one, or one that takes no listing groups), <code>LISTINGTAKEN</code> (a
/// listing the group repeats, a cube defines, or another group registers), <code>LISTINGHELD</code> (a listing add of a name the group holds) or
/// <code>SQLPAIR</code> (a SQL change without the pair). Nothing is written. An exception is <var>pCaught</var>. A seam: a fixture overrides it.</p>
ClassMethod VendorListingGroupCompose(pNamespace As %String, pOp As %String, pClass As %String, pListing As %String, pBody As %DynamicObject, pNewName As %String, pNewClass As %String, pTargetCubes As %String, pHasSQL As %Boolean, Output pXml As %String, Output pClasses As %String, Output pCode As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pXml = ""
    Set pClasses = ""
    Set pCode = ""
    Set pCaught = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pOp = "ADD" {
            Set tModel = ##class(%DeepSee.Model.ListingGroup.listingGroup).%New()
            Set tModel.name = pBody.%Get("Name")
        } Else {
            Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(pClass)
            If '$IsObject(tModel) || (tModel.name = "") Set pCode = "ABSENT"
        }
        If pCode = "" && ((pOp = "ADD") || (pOp = "UPDATE")) {
            If pBody.%GetTypeOf("Caption") = "string" Set tModel.displayName = pBody.%Get("Caption")
            If pBody.%GetTypeOf("Description") = "string" Set tModel.description = pBody.%Get("Description")
            If pBody.%GetTypeOf("TargetCubes") = "string" Set tModel.targetCubes = pBody.%Get("TargetCubes")
            If pBody.%GetTypeOf("Resource") = "string" Set tModel.resource = pBody.%Get("Resource")
            If pBody.%GetTypeOf("DefaultResource") = "string" Set tModel.defaultResource = pBody.%Get("DefaultResource")
            If pBody.%GetTypeOf("Disabled") = "boolean" Set tModel.disabled = pBody.%Get("Disabled")
        }
        If pCode = "" && (pOp = "COPY") {
            Set tModel.name = pNewName
            If pTargetCubes '= "" Set tModel.targetCubes = pTargetCubes
        }
        If pCode = "" && ((pOp = "ADD") || (pOp = "COPY")) {
            ; A name or class in use, whoever may see it: the saved list omits a group another resource guards, so its registry node is read too.
            Do ##class(%DeepSee.ListingGroup).%GetListingGroups(.tSaved, 0)
            If $Data(tSaved($ZConvert(tModel.name, "U"))) || $Data(^DeepSee.ListingGroups("groups", $ZConvert(tModel.name, "U"))) || ##class(%Dictionary.ClassDefinition).%ExistsId($Select(pOp = "ADD": pBody.%Get("Class"), 1: pNewClass)) Set pCode = "TAKEN"
        }
        If pCode = "" && (pOp = "ENTRYADD") {
            For tAt = 1:1:tModel.listings.Count() {
                If tModel.listings.GetAt(tAt).name = pListing Set pCode = "LISTINGHELD"
            }
            If pCode = "" {
                Set tListing = ##class(%DeepSee.Model.ListingGroup.listing).%New()
                Set tListing.name = pListing
                Do tModel.listings.Insert(tListing)
            }
        }
        If pCode = "" && ((pOp = "ENTRYSET") || (pOp = "ENTRYREMOVE")) {
            Set tIndex = 0
            For tAt = 1:1:tModel.listings.Count() {
                If tModel.listings.GetAt(tAt).name = pListing Set tIndex = tAt Quit
            }
            If 'tIndex {
                Set pCode = "ABSENT"
            } ElseIf pOp = "ENTRYREMOVE" {
                Do tModel.listings.RemoveAt(tIndex)
            } Else {
                Set tListing = tModel.listings.GetAt(tIndex)
            }
        }
        If pCode = "" && ((pOp = "ENTRYADD") || (pOp = "ENTRYSET")) {
            If pBody.%GetTypeOf("DisplayName") = "string" Set tListing.displayName = pBody.%Get("DisplayName")
            If pBody.%GetTypeOf("Description") = "string" Set tListing.description = pBody.%Get("Description")
            If pBody.%GetTypeOf("Disabled") = "boolean" Set tListing.disabled = pBody.%Get("Disabled")
            If pBody.%GetTypeOf("Type") = "string" Set tListing.listingType = pBody.%Get("Type")
            If pBody.%GetTypeOf("Fields") = "string" Set tListing.fieldList = pBody.%Get("Fields")
            If pBody.%GetTypeOf("Formats") = "string" Set tListing.formatList = pBody.%Get("Formats")
            If pBody.%GetTypeOf("OrderBy") = "string" Set tListing.orderBy = pBody.%Get("OrderBy")
            If pBody.%GetTypeOf("Joins") = "string" Set tListing.joinInfo = pBody.%Get("Joins")
            If pBody.%GetTypeOf("Source") = "string" Set tListing.sourceClass = pBody.%Get("Source")
            If pBody.%GetTypeOf("Resource") = "string" Set tListing.resource = pBody.%Get("Resource")
            If pBody.%GetTypeOf("SelectMode") = "string" Set tListing.selectMode = pBody.%Get("SelectMode")
            ; The SQL a caller without the pair cannot read is kept as stored; a change of it, or a new one, needs the pair.
            If pBody.%GetTypeOf("SQL") = "string" && (pBody.%Get("SQL") '= tListing.sql) && (pHasSQL || (pBody.%Get("SQL") '= "")) {
                If pHasSQL {
                    Set tListing.sql = pBody.%Get("SQL")
                } Else {
                    Set pCode = "SQLPAIR"
                }
            }
        }
        If pCode = "" {
            ; The checks the vendor's compile makes, in its order, so that a refusal is known before anything is saved. A disabled group is not checked.
            Set tCubes = ..CubeList(tModel.targetCubes)
            Set tModel.targetCubes = ..NormalizedCubes(tModel.targetCubes)
            If 'tModel.disabled {
                If tCubes = "" Set pCode = "CUBE"
                For tPiece = 1:1:$ListLength(tCubes) {
                    Set tCube = $List(tCubes, tPiece)
                    If '##class(%DeepSee.Utils).%CubeExists(tCube) || $Get(^DeepSee.Cubes("cubes", $ZConvert(tCube, "U"), "disableListingGroups"), 0) {
                        Set pCode = "CUBE"
                        Quit
                    }
                    Set pClasses = pClasses _ $Select(pClasses = "": "", 1: ",") _ ##class(%DeepSee.Utils).%GetCubeClass(tCube)
                }
                Kill tNames
                For tPiece = 1:1:$ListLength(tCubes) {
                    If pCode '= "" Quit
                    Set tCubeU = $ZConvert($List(tCubes, tPiece), "U")
                    ; A removal leaves the relationship's keys with a gap, so the listings are walked by key.
                    Set tKey = ""
                    For {
                        Set tListing = tModel.listings.GetNext(.tKey)
                        If tKey = "" Quit
                        Set tName = tListing.name
                        If $Data(^DeepSee.Cubes("cubes", tCubeU, "listing", tName)) || ($Data(^DeepSee.ListingGroups("cubes", tCubeU, "listing", tName, "group")) && ($Get(^DeepSee.ListingGroups("cubes", tCubeU, "listing", tName, "group")) '= $ZConvert(tModel.name, "U"))) {
                            Set pCode = "LISTINGTAKEN"
                            Quit
                        }
                    }
                }
                Set tKey = ""
                For {
                    Set tListing = tModel.listings.GetNext(.tKey)
                    If (tKey = "") || (pCode '= "") Quit
                    If tListing.disabled Continue
                    If $Data(tNames($ZConvert(tListing.name, "U"))) Set pCode = "LISTINGTAKEN"
                    Set tNames($ZConvert(tListing.name, "U")) = ""
                }
            } Else {
                For tPiece = 1:1:$ListLength(tCubes) {
                    Set tCube = $List(tCubes, tPiece)
                    If ##class(%DeepSee.Utils).%CubeExists(tCube) Set pClasses = pClasses _ $Select(pClasses = "": "", 1: ",") _ ##class(%DeepSee.Utils).%GetCubeClass(tCube)
                }
            }
        }
        If pCode = "" {
            Set tWriter = ##class(%XML.Writer).%New()
            Set tWriter.NoXMLDeclaration = 1
            Set tWriter.Indent = 1
            Set tStream = ##class(%Stream.TmpCharacter).%New()
            Set tSC = tWriter.OutputToStream(tStream)
            If $$$ISOK(tSC) Set tSC = tWriter.RootObject(tModel)
            If $$$ISOK(tSC) {
                Do tStream.Rewind()
                Set pXml = tStream.Read(3000000)
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The refusal for the code <var>pCode</var> <method>VendorListingGroupCompose</method> answered: <code>TAKEN</code> and <code>LISTINGTAKEN</code> 409, <code>LISTINGHELD</code>
/// 409 <code>LISTINGTAKEN</code>, <code>CUBE</code> 422, <code>ABSENT</code> 404 and <code>SQLPAIR</code> 403 naming <parameter>LISTINGGROUPSQLPAIRS</parameter>.</p>
ClassMethod ComposeRefusal(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If pCode = "TAKEN" Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPTAKEN, .pHttpStatus, .pFault)
    If (pCode = "LISTINGTAKEN") || (pCode = "LISTINGHELD") Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPLISTINGTAKEN, .pHttpStatus, .pFault)
    If pCode = "CUBE" Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPCUBE, ##class(OcuPilot.Api.AnalyticsError).#REASONLISTINGGROUPCUBE, .pHttpStatus, .pFault)
    If pCode = "SQLPAIR" Quit ..Deny(..#LISTINGGROUPSQLPAIRS, .pHttpStatus, .pFault)
    Quit ..ListingGroupAbsent(.pHttpStatus, .pFault)
}

/// <p>Serve the listing group endpoints' typed calls after <method>Invoke</method>'s gate (Story 24.11): the reads <code>LISTINGGROUP</code>, <code>LISTING</code> and
/// <code>COPYTARGET</code> (<method>ReadListingGroup</method>) and the seven writes (<method>PerformListingGroup</method>). The group is named under
/// <parameter>IDKEY</parameter>, a listing by the composite <code>[ListingGroup, Name]</code>, each part kept exactly (AD-13). A read carrying
/// <parameter>ACTIONKEY</parameter> is composed for that write: an add's read is 409 when the target is held and 404 when it is not, and the other writes' reads are 404
/// <code>ANALYTICS.LISTINGGROUP.ABSENT</code> when the target is not there and 409 <code>AMBIGUOUS</code> when two classes declare the group.</p>
ClassMethod InvokeListingGroup(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tId = $Get(pQuery(..#IDKEY))
    Set tListings = (pEndpoint = ..#ENDPOINTLISTINGGROUPLISTINGS)
    Set tParts = $Select(tListings: ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId), 1: $ListBuild(tId))
    If tListings && (($ListLength(tParts) '= 2) || ($List(tParts, 2) = "")) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONLISTINGGROUPREQUIRED, .pHttpStatus, .pFault)
    Set tGroup = $List(tParts, 1)
    If tGroup = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONLISTINGGROUPREQUIRED, .pHttpStatus, .pFault)
    Set tListing = $ListGet(tParts, 2)
    Set tWrite = ..IsListingGroupWrite(pType)
    Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
    If (tAction '= "") && '..IsListingGroupWrite(tAction) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    If pType = ..#TYPEADD {
        ; The group's name is the id's, which the body of a confirmed add does not repeat.
        Set pBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
        Do pBody.%Set("Name", tGroup, "string")
    }
    If tWrite Quit ..PerformListingGroup(pNamespace, pType, tGroup, tListing, .pQuery, pBody, 0, .pResult, .pHttpStatus, .pFault)
    Quit ..ReadListingGroup(pNamespace, pType, tGroup, tListing, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
}

/// <p>The single-object reads of the listing group endpoints: <code>LISTINGGROUP</code> (the group as <method>ListingGroupRow</method>), <code>LISTING</code> (one listing as
/// <method>ListingRow</method>, its <code>SQL</code> only to a holder of <parameter>LISTINGGROUPSQLPAIRS</parameter>) and <code>COPYTARGET</code> (<code>{Name, Version,
/// Listings, NewName, NewClass, NewCubes, Present, Namespace}</code>, the group with the copy's own name, class and cubes from the query). A group or listing that
/// is not there is 404 <code>PORT.NOTFOUND</code> on a plain read and <code>ANALYTICS.LISTINGGROUP.ABSENT</code> with <var>pAction</var>. A read composed for a write
/// carries the class's <code>Version</code>, which the proposal's fingerprint covers, and is refused as that write would be refused (<method>PlanListingGroup</method>).</p>
ClassMethod ReadListingGroup(pNamespace As %String, pType As %String, pGroup As %String, pListing As %String, pAction As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ListingGroupFacts(pNamespace, pGroup, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tHeld = +tData("exists")
    If (pAction = ..#TYPEADD) && ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode($Get(pQuery(..#NEWCLASSKEY))) Quit ..OwnCodeRefusal(.pHttpStatus, .pFault)
    If pAction = ..#TYPEADD Quit $Select(tHeld: ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPTAKEN, .pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
    If 'tHeld Quit ..AbsentFor(pAction, .pHttpStatus, .pFault)
    If pAction '= "" {
        If tData("classes") > 1 Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPAMBIGUOUS, .pHttpStatus, .pFault)
        If (pAction '= ..#TYPECOPY) && ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode($Get(tData("class"))) Quit ..OwnCodeRefusal(.pHttpStatus, .pFault)
        Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Version(..AtelierPortClass(), pNamespace, tData("class") _ ".cls", .tVersion, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    } Else {
        Set tVersion = ""
    }
    If pType = ..#TYPELISTINGGROUP {
        Set pResult = ..ListingGroupRow(pNamespace, .tData, tVersion)
    } ElseIf pType = ..#TYPELISTING {
        Set tAt = ..ListingAt(.tData, pListing)
        If pAction = ..#TYPEENTRYADD Quit $Select(tAt: ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPLISTINGTAKEN, .pHttpStatus, .pFault), 1: ..Absent(.pHttpStatus, .pFault))
        If 'tAt Quit ..AbsentFor(pAction, .pHttpStatus, .pFault)
        Set pResult = ..ListingRow(pNamespace, .tData, tAt, $ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#LISTINGGROUPSQLPAIRS)), tVersion)
    } Else {
        Set tNew = $Get(pQuery(..#NEWNAMEKEY))
        Set tNewClass = $Get(pQuery(..#NEWCLASSKEY))
        Set tCubes = $Get(pQuery(..#TARGETCUBESKEY))
        If pAction '= "" {
            Set tSC = ..PlanListingGroup(pNamespace, ..#TYPECOPY, pGroup, "", .pQuery, {}, .tPlan, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit tSC
        }
        Set pResult = {}
        Do pResult.%Set("Name", tData("name"), "string")
        Do pResult.%Set("Version", tVersion, "string")
        Do pResult.%Set("Listings", tData("count"), "number")
        Do pResult.%Set("NewName", tNew, "string")
        Do pResult.%Set("NewClass", tNewClass, "string")
        Do pResult.%Set("NewCubes", tCubes, "string")
        Do pResult.%Set("Present", 0, "boolean")
        Do pResult.%Set("Namespace", pNamespace, "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The refusal of a read of a group or listing that is not there: 404 <code>PORT.NOTFOUND</code> on a plain read, and with <var>pAction</var> (the read composed for a write)
/// <code>ANALYTICS.LISTINGGROUP.ABSENT</code>.</p>
ClassMethod AbsentFor(pAction As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit $Select(pAction = "": ..Absent(.pHttpStatus, .pFault), 1: ..ListingGroupAbsent(.pHttpStatus, .pFault))
}

/// <p>The refusal of a write whose class is one of OcuPilot's own (AD-10): 403 <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter> with its published sentence.</p>
ClassMethod OwnCodeRefusal(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTCODE
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), .pHttpStatus, .pFault)
}

/// <p>Whether the caller lacks WRITE on the resource <var>pResource</var>, which a group names as the one guarding it (the classic page's <code>canWrite</code>); a group
/// that names none is writable. <var>pFailedPair</var> is the pair the caller lacks.</p>
ClassMethod ResourceDenied(pResource As %String, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Set pFailedPair = ""
    If pResource = "" Quit 0
    Quit '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(pResource, ..#WRITEPERMISSION)), .pFailedPair)
}

/// <p>Judge the listing group write <var>pType</var> of <var>pGroup</var> (and of the listing <var>pListing</var>) before anything is written (Story 24.11). In order, each
/// refusal before any save: the shape rules (<method>ListingGroupViolations</method>, 422); a class of OcuPilot's own (the new class of an add or copy, the group's class for the
/// others, 403 <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>); the new class's shape (<code>ANALYTICS.LISTINGGROUP.CLASS</code>, 422); the group read
/// now (<method>ReadListingGroupData</method>): a group not there is 404 <code>ABSENT</code>, one two classes declare 409 <code>AMBIGUOUS</code>, a held name on an add 409
/// <code>TAKEN</code>; WRITE on the group's resource; then the model composed from <code>%GetModel</code> read now (<method>VendorListingGroupCompose</method>), whose refusals
/// are <method>ComposeRefusal</method>'s. <var>pPlan</var> holds what the write needs: <code>class</code> (the class it saves or deletes), <code>text</code> (its new text),
/// <code>prior</code> (the text read, <code>""</code> for a create), <code>version</code>, <code>compiled</code> (whether the group was registered) and <code>name</code>
/// (the group's name after the write). A delete has no text. Nothing is written.</p>
ClassMethod PlanListingGroup(pNamespace As %String, pType As %String, pGroup As %String, pListing As %String, ByRef pQuery, pBody As %DynamicObject, Output pPlan, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pPlan
    Set tNew = $Get(pQuery(..#NEWNAMEKEY))
    Set tNewClass = $Select(pType = ..#TYPEADD: pBody.%Get("Class"), 1: $Get(pQuery(..#NEWCLASSKEY)))
    Kill tViolations
    Set tSC = ..ListingGroupViolations(pType, pGroup, pListing, pBody, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    If (pType = ..#TYPECOPY) && '..ListingNameShaped(tNew) Set tViolations($Increment(tViolations)) = $ListBuild("NewName", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    If tViolations Quit ..ViolationRefusal(.tViolations, .pHttpStatus, .pFault)
    If ((pType = ..#TYPEADD) || (pType = ..#TYPECOPY)) && ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode(tNewClass) Quit ..OwnCodeRefusal(.pHttpStatus, .pFault)
    If ((pType = ..#TYPEADD) || (pType = ..#TYPECOPY)) && '..ListingClassShaped(tNewClass) Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPCLASS, ##class(OcuPilot.Api.AnalyticsError).#REASONLISTINGGROUPCLASS, .pHttpStatus, .pFault)
    Set tSC = ..ListingGroupFacts(pNamespace, pGroup, .tData, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pType = ..#TYPEADD {
        If tData("exists") Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPTAKEN, .pHttpStatus, .pFault)
        If ..ResourceDenied(pBody.%Get("Resource"), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    } Else {
        If 'tData("exists") Quit ..ListingGroupAbsent(.pHttpStatus, .pFault)
        If tData("classes") > 1 Quit ..Conflict(##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPAMBIGUOUS, .pHttpStatus, .pFault)
        If (pType '= ..#TYPECOPY) && ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode($Get(tData("class"))) Quit ..OwnCodeRefusal(.pHttpStatus, .pFault)
        If ..ResourceDenied(tData("resource"), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    }
    Set pPlan("class") = $Select(pType = ..#TYPEADD: tNewClass, pType = ..#TYPECOPY: tNewClass, 1: $Get(tData("class")))
    Set pPlan("name") = $Select(pType = ..#TYPEADD: pGroup, pType = ..#TYPECOPY: tNew, 1: $Get(tData("name")))
    Set pPlan("compiled") = ''$Get(tData("compiled"))
    Set pPlan("text") = ""
    Set pPlan("prior") = ""
    Set pPlan("version") = ""
    If pType = ..#TYPEDELETE Quit $$$OK
    Set tHasSQL = $ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#LISTINGGROUPSQLPAIRS))
    If (pType '= ..#TYPEADD) && (pType '= ..#TYPECOPY) {
        Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Read(..AtelierPortClass(), pNamespace, pPlan("class") _ ".cls", .tPrior, .tVersion, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set pPlan("prior") = tPrior
        Set pPlan("version") = tVersion
    }
    Set tCaught = ""
    Set tCode = ""
    Set tSC = ..VendorListingGroupCompose(pNamespace, pType, $Get(tData("class")), pListing, pBody, tNew, tNewClass, $Get(pQuery(..#TARGETCUBESKEY)), tHasSQL, .tXml, .tClasses, .tCode, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the listing group could not be composed", .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit ..Statused(tSC, "the listing group could not be composed", .pHttpStatus, .pFault)
    If tCode '= "" Quit ..ComposeRefusal(tCode, .pHttpStatus, .pFault)
    If (pType = ..#TYPEADD) || (pType = ..#TYPECOPY) {
        Set pPlan("text") = ##class(OcuPilot.Kernel.ListingGroupText).ClassText(pPlan("class"), tClasses, tXml)
    } ElseIf '##class(OcuPilot.Kernel.ListingGroupText).Splice(pPlan("prior"), tClasses, tXml, .tSpliced) {
        Quit ..ListingGroupAbsent(.pHttpStatus, .pFault)
    } Else {
        Set pPlan("text") = tSpliced
    }
    Quit $$$OK
}

/// <p>The refusal sentence of the write <var>pType</var> of <var>pGroup</var> (<var>pListing</var>) with the members <var>pBody</var>, <code>""</code> when nothing refuses
/// it: <method>PlanListingGroup</method>'s, with nothing written. The mint and a screen's save ask it, so the agent and the person are refused what the write would refuse.</p>
ClassMethod ListingGroupProblem(pNamespace As %String, pType As %String, pGroup As %String, pListing As %String, ByRef pQuery, pBody As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        Set tSC = ..PlanListingGroup(pNamespace, pType, pGroup, pListing, .pQuery, pBody, .tPlan, .tHttp, .tFault)
        If $$$ISERR(tSC) && $IsObject($Get(tFault)) Set tProblem = tFault.%Get("reason")
    } Catch {
        Set tProblem = ""
    }
    Quit tProblem
}

/// <p>Make the listing group write <var>pType</var> (Story 24.11, AD-65): <method>PlanListingGroup</method>, then the class saved, compiled and deleted through
/// <method>AtelierPortClass</method> (AD-61). A create (<code>ADD</code>, <code>COPY</code>) saves a new class and compiles it; the others save the class's text with the
/// <code>Listings</code> XData and <code>DependsOn</code> replaced, against the version read, and compile it; a delete deletes the class. A compile the instance refuses
/// (its own text is logged, never sent) undoes the write: a created class is deleted, and a changed one is saved back as it was and, when the group was registered,
/// compiled again. The answer is 422 <code>ANALYTICS.LISTINGGROUP.COMPILE</code>. Each write that reached the class records OcuPilot's own <code>ConfigChange</code> row
/// (<method>AuditWrite</method>), a restored one with its outcome. With <var>pDry</var> nothing is written and <var>pResult</var> stays empty.</p>
ClassMethod PerformListingGroup(pNamespace As %String, pType As %String, pGroup As %String, pListing As %String, ByRef pQuery, pBody As %DynamicObject, pDry As %Boolean, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..PlanListingGroup(pNamespace, pType, pGroup, pListing, .pQuery, pBody, .tPlan, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || pDry Quit tSC
    Set tClass = tPlan("class")
    Set tName = tClass _ ".cls"
    Set tOutcome = "applied"
    Set tRefused = 0
    If pType = ..#TYPEDELETE {
        Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Remove(..AtelierPortClass(), pNamespace, tName, .tDeleted, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        If 'tDeleted Quit ..Fail("the listing group's class was not deleted", $$$ERROR($$$GeneralError, tName), .pHttpStatus, .pFault)
    } Else {
        Set tCreates = (pType = ..#TYPEADD) || (pType = ..#TYPECOPY)
        Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Save(..AtelierPortClass(), pNamespace, tName, tPlan("text"), $Select(tCreates: "", 1: tPlan("version")), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Compile(..AtelierPortClass(), pNamespace, tName, .tErrors, .tLines, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || tErrors {
            Set tRefused = 1
            If $$$ISOK(tSC) {
                Set tJoined = ""
                Set tIterator = tLines.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tLine) {
                    Set tJoined = tJoined _ $Select(tJoined = "": "", 1: " | ") _ tLine
                }
                Do ..LogFault("the listing group's compile was refused: " _ tJoined, $$$ERROR($$$GeneralError, tName))
            } Else {
                Do ..LogFault("the listing group's compile call failed", tSC)
            }
            Set tOutcome = ..RestoreListingGroup(pNamespace, tName, tCreates, tPlan("prior"), tPlan("compiled"))
        }
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("listingGroup", tPlan("name"), "string")
    Do tEffects.%Set("class", tClass, "string")
    If pListing '= "" Do tEffects.%Set("listing", pListing, "string")
    Do tEffects.%Set("outcome", tOutcome, "string")
    Set tListings = (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    Do ..AuditWrite($Case(pType, ..#TYPEADD: ..#VERBLISTINGGROUPADD, ..#TYPEUPDATE: ..#VERBLISTINGGROUPUPDATE, ..#TYPECOPY: ..#VERBLISTINGGROUPCOPY, ..#TYPEDELETE: ..#VERBLISTINGGROUPDELETE, ..#TYPEENTRYADD: ..#VERBLISTINGADD, ..#TYPEENTRYSET: ..#VERBLISTINGSET, : ..#VERBLISTINGREMOVE), $Select(tListings: ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tPlan("name"), pListing)), 1: tPlan("name")), tEffects, $Select(tListings: ..#ENTITYLISTING, 1: ..#ENTITYLISTINGGROUP))
    If tRefused Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPCOMPILE, ##class(OcuPilot.Api.AnalyticsError).#REASONLISTINGGROUPCOMPILE, .pHttpStatus, .pFault)

    Set pResult = {}
    Do pResult.%Set("Namespace", pNamespace, "string")
    If pType = ..#TYPEDELETE {
        Do pResult.%Set("Name", tPlan("name"), "string")
    } ElseIf pType = ..#TYPEENTRYREMOVE {
        Do pResult.%Set("ListingGroup", tPlan("name"), "string")
        Do pResult.%Set("Name", pListing, "string")
    } Else {
        Do ..ListingGroupFacts(pNamespace, tPlan("name"), .tAfter, .tAfterHttp, .tAfterFault)
        Set tAt = $Select(tListings: ..ListingAt(.tAfter, pListing), 1: 0)
        Set tVersion = ""
        If tAfter("exists") Do ##class(OcuPilot.Kernel.SourceDocument).Version(..AtelierPortClass(), pNamespace, tAfter("class") _ ".cls", .tVersion, .tVersionHttp, .tVersionFault)
        If tAfter("exists") && 'tListings {
            Set pResult = ..ListingGroupRow(pNamespace, .tAfter, tVersion)
        } ElseIf tAfter("exists") && tAt {
            Set pResult = ..ListingRow(pNamespace, .tAfter, tAt, $ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#LISTINGGROUPSQLPAIRS)), tVersion)
        } Else {
            Do pResult.%Set($Select(tListings: "ListingGroup", 1: "Name"), tPlan("name"), "string")
            If tListings Do pResult.%Set("Name", pListing, "string")
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Undo a write whose compile the instance refused (Story 24.11): delete the class a create saved, or save the text <var>pPrior</var> back over the changed class and,
/// when the group had been registered (<var>pCompiled</var>), compile it again. Answers <code>restored</code> when each step reported success and
/// <code>restorefailed</code> otherwise, which is logged: a class that could not be put back is for an operator.</p>
ClassMethod RestoreListingGroup(pNamespace As %String, pName As %String, pCreated As %Boolean, pPrior As %String, pCompiled As %Boolean) As %String [ Private ]
{
    Set tOutcome = "restored"
    Try {
        If pCreated {
            Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Remove(..AtelierPortClass(), pNamespace, pName, .tDeleted, .tHttp, .tFault)
            If $$$ISERR(tSC) || 'tDeleted Set tOutcome = "restorefailed"
        } Else {
            Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Version(..AtelierPortClass(), pNamespace, pName, .tVersion, .tHttp, .tFault)
            If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Save(..AtelierPortClass(), pNamespace, pName, pPrior, tVersion, .tHttp, .tFault)
            If $$$ISOK(tSC) && pCompiled {
                Set tSC = ##class(OcuPilot.Kernel.SourceDocument).Compile(..AtelierPortClass(), pNamespace, pName, .tErrors, .tLines, .tHttp, .tFault)
                If $$$ISOK(tSC) && tErrors Set tSC = $$$ERROR($$$GeneralError, "the restored class did not compile")
            }
            If $$$ISERR(tSC) Set tOutcome = "restorefailed"
        }
    } Catch ex {
        Set tOutcome = "restorefailed"
        Set tSC = ex.AsStatus()
    }
    If tOutcome = "restorefailed" Do ..LogFault("the listing group could not be put back after a refused compile", $Get(tSC, $$$ERROR($$$GeneralError, pName)))
    Quit tOutcome
}

/// <p>The lines <method>Snippet</method> adds for a listing group write <var>pType</var> of the group or listing the id <var>pId</var> names (Story 24.11, AD-59): the class
/// the write would save, compiled, and, as the write does, put back when the compile is refused. A delete is the class's deletion. The text is
/// <method>PlanListingGroup</method>'s, composed from the instance as it stands, and rendered as one string literal; a write that plan refuses is a script that only
/// sets the refusal's sentence. An add's or a copy's steps are each gated on one line by a free-name check applying the port's taken-name rule (the group's name in the
/// saved list or the registry, or its class defined), so a script run after another writer took the name changes and deletes nothing. A script longer than
/// <parameter>OcuPilot.Port.AtelierPort.SNIPPETMAXCHARACTERS</parameter> answers no step.</p>
ClassMethod ListingGroupSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    Set tListings = (pType = ..#TYPEENTRYADD) || (pType = ..#TYPEENTRYSET) || (pType = ..#TYPEENTRYREMOVE)
    Set tParts = $Select(tListings: ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId), 1: $ListBuild(pId))
    Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
    Set tSC = ..PlanListingGroup(tNamespace, pType, $List(tParts, 1), $ListGet(tParts, 2), .pQuery, pBody, .tPlan, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: $System.Status.GetErrorText(tSC))) _ ")"
    Set tClass = ..Literal(tPlan("class"))
    Set tSpace = ..Literal(tNamespace)
    If pType = ..#TYPEDELETE Quit tNL _ " Set tSC = $System.OBJ.Delete(" _ tClass _ ", ""-d"")"
    Set tCreates = (pType = ..#TYPEADD) || (pType = ..#TYPECOPY)
    ; The vendor's text service takes a carriage return and a line feed between lines.
    Set tSave = "##class(%Compiler.UDL.TextServices).SetTextFromString(" _ tSpace _ ", " _ tClass _ ", $Replace(" _ ..Literal(tPlan("text")) _ ", $Char(10), $Char(13, 10)))"
    If tCreates {
        Set tNameU = ..Literal($ZConvert(tPlan("name"), "U"))
        Set tText = tNL _ " Kill tGroups Do ##class(%DeepSee.ListingGroup).%GetListingGroups(.tGroups, 0)"
        Set tText = tText _ tNL _ " Set tMade = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.AnalyticsError).#REASONLISTINGGROUPTAKEN) _ ")"
        Set tText = tText _ tNL _ " If '$Data(tGroups(" _ tNameU _ ")), '$Data(^DeepSee.ListingGroups(""groups"", " _ tNameU _ ")), '##class(%Dictionary.ClassDefinition).%ExistsId(" _ tClass _ ") Set tMade = 1, tSC = " _ tSave
        Set tText = tText _ tNL _ " If tMade, $System.Status.IsOK(tSC) Set tSC = $System.OBJ.Compile(" _ tClass _ ", ""ck"")"
        Set tText = tText _ tNL _ " If tMade, '$System.Status.IsOK(tSC) Do $System.OBJ.Delete(" _ tClass _ ", ""-d"")"
    } Else {
        Set tUndo = " Do ##class(%Compiler.UDL.TextServices).SetTextFromString(" _ tSpace _ ", " _ tClass _ ", $Replace(" _ ..Literal(tPlan("prior")) _ ", $Char(10), $Char(13, 10)))" _ $Select(tPlan("compiled"): " Do $System.OBJ.Compile(" _ tClass _ ", ""ck"")", 1: "")
        Set tText = tNL _ " Set tSC = " _ tSave _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = $System.OBJ.Compile(" _ tClass _ ", ""ck"")" _ tNL _ " If '$System.Status.IsOK(tSC) {" _ tUndo _ " }"
    }
    If $Length(tText) > ##class(OcuPilot.Port.AtelierPort).#SNIPPETMAXCHARACTERS Quit ""
    Quit tText
}

}
