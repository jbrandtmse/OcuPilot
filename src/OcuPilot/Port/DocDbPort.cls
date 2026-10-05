/// <p>The port to the instance's document databases (AD-29, AD-52, Story 19.17): <b>the only product
/// class that calls <code>%SYSTEM.DocDB</code></b>, in the caller's process, as the signed-in user.
/// Nothing here issues an HTTP request, and nothing names an <code>%Api.DocDB*</code> class.</p>
/// <p><code>%SYSTEM.DocDB</code> checks neither the DocDB service nor <code>%DocDB_Admin</code> when it
/// is called in process (measured by Story 19.9), so <method>Invoke</method> repeats the vendor's
/// gate. <b>The order of every call is fixed</b>, and nothing reaches the vendor before all of it has
/// passed:</p>
/// <ol>
/// <li><parameter>PAIRS</parameter>, through <method>OcuPilot.Screen.Gate.EvaluateRequired</method>; a
/// refusal is 403 naming the failed pair.</li>
/// <li>The namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>), its shape checked.</li>
/// <li>The namespace's pairs: <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> for a read,
/// <method>WritePairs</method> for a create or a drop.</li>
/// <li>The name's rules, for a call that names a database (<method>NameProblem</method>, and the
/// package mapping).</li>
/// <li>The service: <code>$$CheckServiceStatus^%SYS.DOCDB</code>, whose answer other than 1 is 409
/// <parameter>OcuPilot.Api.DocDbError.SERVICEDISABLED</parameter>. Each such refusal writes one vendor
/// <code>%System/%Security/AccessDenied</code> "Doc DB Access" audit row (AD-7's sixth shape); the
/// checks before it write none.</li>
/// <li>The vendor call, in the target namespace, switched by explicit save and restore (AD-16): the
/// restore is the first line of every <code>Catch</code>, and no <code>OcuPilot.*</code> class is
/// called while switched.</li>
/// </ol>
/// <p><b>Its request types</b> on <parameter>ENDPOINT</parameter>: <parameter>TYPELIST</parameter>,
/// <parameter>TYPEDATABASE</parameter>, <parameter>TYPECREATE</parameter> and
/// <parameter>TYPEDROP</parameter> (<method>Invoke</method>). A create sends the name alone: no
/// document type and no resource, so it writes no <code>Security.DocDBs</code> record. The vendor
/// drop's per-database <code>CheckAccess "W"</code> is not repeated: it needs that record, which a
/// database created without a resource lacks (DW-2084).</p>
/// <p><b>Every refusal is a written reason</b> (AD-39): the vendor's text goes to
/// <method>LogFault</method> and nowhere else, and a read answered 404 is not logged (AD-2).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method> and <method>LogFault</method>.
/// Production overrides neither.</p>
Class OcuPilot.Port.DocDbPort Extends %RegisteredObject
{

/// <p>The pair set every call requires whatever its namespace, comma-separated as
/// <code>resource:permission</code>, in the order the gate reports in (AD-8, AD-29): System
/// Explorer's, then the two the vendor's own REST gate checks.</p>
Parameter PAIRS = "%Development:USE,%DocDB_Admin:USE,%Service_DocDB:USE";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The one endpoint this port serves: the namespace's document databases.</p>
Parameter ENDPOINT = "Databases";

/// <p>The namespace's document databases as rows.</p>
Parameter TYPELIST = "LIST";

/// <p>One database's row and the namespace it was read in: the tools' fresh read.</p>
Parameter TYPEDATABASE = "DATABASE";

/// <p>Create one database by name.</p>
Parameter TYPECREATE = "CREATE";

/// <p>Drop one database: its class and every document it holds.</p>
Parameter TYPEDROP = "DROP";

/// <p>The query key naming the namespace a call runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key naming the database a typed call is about.</p>
Parameter NAMEKEY = "name";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The field a name refusal is reported on.</p>
Parameter NAMEFIELD = "Name";

/// <p>A database name: a class name, each dot-separated part starting with a letter (measured: the
/// vendor refuses <code>_</code>, <code>-</code>, a leading digit, a space, <code>%</code>, an empty
/// name and a leading, trailing or double dot with #25053).</p>
Parameter NAMEPATTERN = "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$";

/// <p>The longest class name the vendor stores for a database.</p>
Parameter CLASSNAMEMAX As INTEGER = 220;

/// <p>The package an unqualified name's class is created in.</p>
Parameter DEFAULTPACKAGE = "ISC.DM";

/// <p>The permission a create or a drop requires on the namespace's routines and globals databases.</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The vendor's status codes this port answers in its own words.</p>
Parameter CODENAMETAKEN = 25051;

Parameter CODECLASSTAKEN = 25070;

Parameter CODENAMEINVALID = 25053;

Parameter CODEABSENT = 25351;

/// <p>#5883: the class would be written to a database the caller cannot write.</p>
Parameter CODEWRITEDENIED = 5883;

/// <p>#5092 and #5093: a class, or the package of one, already exists under the same name in another
/// letter case (measured).</p>
Parameter CODECLASSCASE = 5092;

Parameter CODEPACKAGECASE = 5093;

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "docdbport";

/// <p>The reasons this port's own refusals carry.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONNAMESPACESHAPE = "Name the namespace the call runs in.";

Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the databases that namespace reads code from.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
}

/// <p>The class a database named <var>pName</var> creates: the name itself when it is qualified, and
/// <parameter>DEFAULTPACKAGE</parameter> plus the name otherwise (measured). Pure.</p>
ClassMethod ClassNameOf(pName As %String) As %String
{
    If pName [ "." Quit pName
    Quit ..#DEFAULTPACKAGE _ "." _ pName
}

/// <p>The published sentence refusing <var>pName</var> as a database name, or <code>""</code>: it
/// must match <parameter>NAMEPATTERN</parameter>, and its class name (<method>ClassNameOf</method>)
/// must be at most <parameter>CLASSNAMEMAX</parameter> characters. Pure.</p>
ClassMethod NameProblem(pName As %String) As %String
{
    If $IsObject(pName) || '$Match(pName, ..#NAMEPATTERN) || ($Length(..ClassNameOf(pName)) > ..#CLASSNAMEMAX) Quit ##class(OcuPilot.Api.DocDbError).#REASONNAMEINVALID
    Quit ""
}

/// <p>Whether <var>pNamespace</var> keeps the package of <var>pName</var>'s class in a database other
/// than its own routines database (<code>%SYS.Namespace</code>'s package and routine destinations),
/// as <code>Ens</code> resolves to ENSLIB in <code>USER</code> (measured). A name with no package
/// past the default is compared like any other.</p>
ClassMethod IsMapped(pNamespace As %String, pName As %String) As %Boolean
{
    Set tMapped = 1
    Try {
        Set tClass = ..ClassNameOf(pName)
        Set tPackage = $Piece(tClass, ".", 1, $Length(tClass, ".") - 1)
        Set tPackageDest = ##class(%SYS.Namespace).GetPackageDest(pNamespace, tPackage)
        Set tRoutineDest = ##class(%SYS.Namespace).GetRoutineDest(pNamespace)
        Set tMapped = (tRoutineDest = "") || (tPackageDest '= tRoutineDest)
    } Catch {
        Set tMapped = 1
    }
    Quit tMapped
}

/// <p><method>OcuPilot.Port.AtelierPort.WritePairs</method> for <var>pNamespace</var> -- READ on its code
/// databases and WRITE on its routines database -- plus WRITE on its globals database, which holds the
/// database's registry row and its documents, each pair once; <code>""</code> when the namespace's
/// databases cannot be resolved, which the caller refuses rather than admits.</p>
ClassMethod WritePairs(pNamespace As %String) As %List
{
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(pNamespace)
    If tPairs = "" Quit ""
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(pNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    If 'tResolved Quit ""
    If tGlobal '= "" {
        Set tPair = $ListBuild(tGlobal, ..#WRITEPERMISSION)
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit tPairs
}

/// <p>The vendor's service check for a call about <var>pName</var> in <var>pNamespace</var>:
/// <code>$$CheckServiceStatus^%SYS.DOCDB</code>, which answers 1 when <code>%Service_DocDB</code> is
/// enabled and held and an error status (#822) otherwise, writing one
/// <code>%System/%Security/AccessDenied</code> row for each refusal. Its signature is pinned by
/// <class>OcuPilot.Test.DocDbPort</class>.</p>
ClassMethod ServiceStatus(pName As %String, pNamespace As %String) As %Status
{
    Set tStatus = 0
    Try {
        Set tStatus = $$CheckServiceStatus^%SYS.DOCDB(pName, pNamespace)
    } Catch ex {
        Set tStatus = ex.AsStatus()
    }
    Quit tStatus
}

/// <p>Serve <parameter>ENDPOINT</parameter> for request type <var>pType</var>, after this class's
/// header's gate.</p>
/// <p><var>pQuery</var> carries <parameter>NAMESPACEKEY</parameter> (optional: the request's scope when
/// absent), <parameter>NAMEKEY</parameter> for a typed call, and <parameter>MAXROWSKEY</parameter> for a
/// list (optional, a whole number above zero). <var>pBody</var> is not read: a create takes the name
/// alone.</p>
/// <p>On success, at 200, <var>pResult</var> is: for <parameter>TYPELIST</parameter> an array of rows
/// <code>{Name, Class, DocumentType, Resource}</code>, one <code>GetDatabase</code> per name the cut
/// keeps; for <parameter>TYPEDATABASE</parameter> that row plus <code>Namespace</code>; for
/// <parameter>TYPECREATE</parameter>, at 201, the new database's row plus <code>Namespace</code>; and
/// for <parameter>TYPEDROP</parameter> <code>{Name, Namespace}</code>.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace or a cap of the
/// wrong shape, or a namespace whose databases cannot be resolved; 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; 422
/// <parameter>OcuPilot.Api.DocDbError.NAMEINVALID</parameter> or
/// <parameter>OcuPilot.Api.DocDbError.NAMEMAPPED</parameter> on <code>Name</code>; 409
/// <parameter>OcuPilot.Api.DocDbError.SERVICEDISABLED</parameter>; 409
/// <parameter>OcuPilot.Api.DocDbError.NAMETAKEN</parameter> (#25051) or
/// <parameter>OcuPilot.Api.DocDbError.CLASSTAKEN</parameter> (#25070, a class of that name found
/// before the create, or #5092 and #5093 for a class or package of that name in another letter case); 404 <code>PORT.NOTFOUND</code> for an absent database, unlogged on a read, and
/// for a drop answered 0; 403 <code>PORT.ACCESSDENIED</code> for <code>&lt;PROTECT&gt;</code> or #5883;
/// and 500 <code>INTERNAL</code>, logged, for anything else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a PAIRS parameter mis-edited to empty fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If '$Match(tNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tWrite = (pType = ..#TYPECREATE) || (pType = ..#TYPEDROP)
        Set tNamespacePairs = $Select(tWrite: ..WritePairs(tNamespace), 1: ##class(OcuPilot.Port.AtelierPort).NamespacePairs(tNamespace))
        If tNamespacePairs = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
            Quit
        }
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tNamespacePairs, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }

        Set tTyped = tWrite || (pType = ..#TYPEDATABASE)
        If (pEndpoint '= ..#ENDPOINT) || ('tTyped && (pType '= ..#TYPELIST)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = ""
        Set tMax = 0
        If tTyped {
            Set tName = $Get(pQuery(..#NAMEKEY))
            If ..NameProblem(tName) '= "" {
                Set tSC = ..Violation(##class(OcuPilot.Api.DocDbError).#NAMEINVALID, .pHttpStatus, .pFault)
                Quit
            }
            If ..IsMapped(tNamespace, tName) {
                Set tSC = ..Violation(##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, .pHttpStatus, .pFault)
                Quit
            }
        } Else {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = +tMaxText
        }

        ; The vendor's own service check, after every pair this port checks, so a missing pair is
        ; named rather than answered with the vendor's audit row (AD-7, AD-29).
        If ..ServiceStatus(tName, tNamespace) '= 1 {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.DocDbError).#SERVICEDISABLED, ##class(OcuPilot.Api.DocDbError).#REASONSERVICEDISABLED, .pHttpStatus, .pFault)
            Quit
        }

        If pType = ..#TYPELIST {
            Set tSC = ..ListRows(tNamespace, tMax, .pResult, .pHttpStatus, .pFault)
        } ElseIf pType = ..#TYPEDATABASE {
            Set tSC = ..Database(tNamespace, tName, .pResult, .pHttpStatus, .pFault)
        } ElseIf pType = ..#TYPECREATE {
            Set tSC = ..Create(tNamespace, tName, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..Drop(tNamespace, tName, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The namespace's databases, at most <var>pMax</var> of them when it is above zero, in the
/// vendor's order: <code>GetAllDatabases</code>, then one <code>GetDatabase</code> per name the cut
/// keeps. A name gone between the two (#25351) is dropped. Only vendor classes run while the namespace
/// is switched; the rows are built once it is restored.</p>
ClassMethod ListRows(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tNames = ##class(%SYSTEM.DocDB).GetAllDatabases()
        Set tIterator = tNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If (pMax > 0) && (tFound >= pMax) Quit
            Set tDatabase = ""
            Try {
                Set tDatabase = ##class(%SYSTEM.DocDB).GetDatabase(tName)
            } Catch exGone {
                If '$ListFind($ListFromString($System.Status.GetErrorCodes(exGone.AsStatus())), ..#CODEABSENT) Throw exGone
            }
            If '$IsObject(tDatabase) Continue
            Set tFound = tFound + 1
            Set tFound(tFound) = $ListBuild(tDatabase.Name, tDatabase.ClassName, tDatabase.DocumentType, tDatabase.Resource)
        }
        Set tDatabase = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the document database list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..Row(tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One database's row and <code>Namespace</code>; an absent name is 404
/// <code>PORT.NOTFOUND</code>, unlogged (AD-2).</p>
ClassMethod Database(pNamespace As %String, pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tCaught = ""
    Set tValues = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDatabase = ##class(%SYSTEM.DocDB).GetDatabase(pName)
        Set tValues = $ListBuild(tDatabase.Name, tDatabase.ClassName, tDatabase.DocumentType, tDatabase.Resource)
        Set tDatabase = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) {
        If ..IsCode(tCaught, ..#CODEABSENT) Quit ..Absent(.pHttpStatus, .pFault)
        Quit ..Mapped(tCaught, "the document database read failed", .pHttpStatus, .pFault)
    }
    Set pResult = ..Row(tValues)
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create database <var>pName</var> in <var>pNamespace</var> with no document type and no resource.
/// A class of its class name already there refuses it before the vendor call.</p>
ClassMethod Create(pNamespace As %String, pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tCaught = ""
    Set tClassTaken = 0
    Set tValues = ""
    Set tClass = ..ClassNameOf(pName)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) {
            Set tClassTaken = 1
        } Else {
            Set tDatabase = ##class(%SYSTEM.DocDB).CreateDatabase(pName)
            Set tValues = $ListBuild(tDatabase.Name, tDatabase.ClassName, tDatabase.DocumentType, tDatabase.Resource)
            Set tDatabase = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If tClassTaken Quit ..Conflict(##class(OcuPilot.Api.DocDbError).#CLASSTAKEN, .pHttpStatus, .pFault)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the document database create failed", .pHttpStatus, .pFault)
    Set pResult = ..Row(tValues)
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 201
    Quit $$$OK
}

/// <p>Drop database <var>pName</var> in <var>pNamespace</var>: its class, its documents and its row. An
/// answer of 0, no such database, is 404 <code>PORT.NOTFOUND</code>, logged as a write's is (AD-2).</p>
ClassMethod Drop(pNamespace As %String, pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tCaught = ""
    Set tDropped = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDropped = ##class(%SYSTEM.DocDB).DropDatabase(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the document database drop failed", .pHttpStatus, .pFault)
    If 'tDropped {
        Do ..LogFault("the document database drop found no database by that name", $$$ERROR($$$GeneralError, pName), ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The row of a database's <code>$ListBuild(Name, ClassName, DocumentType, Resource)</code>:
/// <code>{Name, Class, DocumentType, Resource}</code>, each a string.</p>
ClassMethod Row(pValues As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", $ListGet(pValues, 1) _ "", "string")
    Do tRow.%Set("Class", $ListGet(pValues, 2) _ "", "string")
    Do tRow.%Set("DocumentType", $ListGet(pValues, 3) _ "", "string")
    Do tRow.%Set("Resource", $ListGet(pValues, 4) _ "", "string")
    Quit tRow
}

/// <p>Whether exception <var>pException</var> carries vendor status code <var>pCode</var>.</p>
ClassMethod IsCode(pException As %Exception.AbstractException, pCode As %Integer) As %Boolean [ Private ]
{
    Set tCodes = ""
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pException.AsStatus())
    } Catch {
        Set tCodes = ""
    }
    Quit ''$ListFind($ListFromString(tCodes), pCode)
}

/// <p>A vendor exception <var>pException</var> in this port's own words: #25051
/// <parameter>OcuPilot.Api.DocDbError.NAMETAKEN</parameter>, #25070, #5092 and #5093
/// <parameter>OcuPilot.Api.DocDbError.CLASSTAKEN</parameter> and #25053
/// <parameter>OcuPilot.Api.DocDbError.NAMEINVALID</parameter>, each unlogged; <code>&lt;PROTECT&gt;</code>
/// and #5883 403 <code>PORT.ACCESSDENIED</code>; anything else 500 <code>INTERNAL</code>. The last two
/// log the vendor's text under <var>pMessage</var>.</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..IsCode(pException, ..#CODENAMETAKEN) Quit ..Conflict(##class(OcuPilot.Api.DocDbError).#NAMETAKEN, .pHttpStatus, .pFault)
    If ..IsCode(pException, ..#CODECLASSTAKEN) || ..IsCode(pException, ..#CODECLASSCASE) || ..IsCode(pException, ..#CODEPACKAGECASE) Quit ..Conflict(##class(OcuPilot.Api.DocDbError).#CLASSTAKEN, .pHttpStatus, .pFault)
    If ..IsCode(pException, ..#CODENAMEINVALID) Quit ..Violation(##class(OcuPilot.Api.DocDbError).#NAMEINVALID, .pHttpStatus, .pFault)
    Set tProtect = 0
    Try {
        Set tProtect = (pException.Name [ "<PROTECT>")
    } Catch {
        Set tProtect = 0
    }
    If tProtect || ..IsCode(pException, ..#CODEWRITEDENIED) {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pException.AsStatus(), ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pException.AsStatus(), .pHttpStatus, .pFault)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
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

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
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
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.DocDbError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The 422 refusal <var>pCode</var> on <parameter>NAMEFIELD</parameter>: the envelope carries the
/// code and its sentence, and <code>detail.violations</code> the one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.DocDbError).ReasonFor(pCode)
    Set tViolation = {}
    Do tViolation.%Set("field", ..#NAMEFIELD, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tViolation)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>404 <code>PORT.NOTFOUND</code>: the database is not there. The caller decides whether to log
/// (AD-2).</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for <parameter>TYPECREATE</parameter> and <parameter>TYPEDROP</parameter>
/// on <parameter>ENDPOINT</parameter>, the writes this port carries; <code>""</code> for
/// <parameter>TYPELIST</parameter>, <parameter>TYPEDATABASE</parameter> and anything else, which
/// have no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint '= ..#ENDPOINT Quit ""
    If (pType = ..#TYPECREATE) || (pType = ..#TYPEDROP) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59), in the namespace
/// <parameter>NAMESPACEKEY</parameter> names: <parameter>TYPECREATE</parameter> is
/// <code>%SYSTEM.DocDB</code>'s <code>CreateDatabase</code> of the one name, with no document type and
/// no resource, and <parameter>TYPEDROP</parameter> its <code>DropDatabase</code>. A read writes
/// nothing and answers no step. Every value is rendered as a string literal, so nothing the query
/// carries runs as code. <code>%SYSTEM.DocDB</code> checks neither the service nor
/// <code>%DocDB_Admin</code>, so whoever runs the script is checked only on the namespace's
/// databases.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tName = ..Literal($Get(pQuery(..#NAMEKEY)))
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pType = ..#TYPECREATE {
        Set tText = tText _ $Char(10) _ " Set tDatabase = ##class(%SYSTEM.DocDB).CreateDatabase(" _ tName _ ")"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tDropped = ##class(%SYSTEM.DocDB).DropDatabase(" _ tName _ ")"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
