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
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>RoutineResource</method>, <method>Collect</method> and
/// <method>LogFault</method>. Production overrides none.</p>
Class OcuPilot.Port.AnalyticsPort Extends %RegisteredObject
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
