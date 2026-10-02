/// <p>Test-only <class>OcuPilot.Port.RemoteDatabasePort</class> subclass: the listing's seam (Story
/// 18.16). Its child answers the data server's listing without contacting it, so no ECP connection is
/// ever opened, and every vendor call the port makes is recorded as
/// <class>OcuPilot.Test.DatabaseRecordPort</class> records them, in the same process-private record,
/// before it is sent.</p>
/// <p><b>The listing</b> (<method>ListRows</method>, run in the child) is chosen by the data server's
/// name: <parameter>SLOWSERVER</parameter> answers only after <parameter>SLOWSECONDS</parameter> with
/// the row <parameter>LATENAME</parameter>; <parameter>DOWNSERVER</parameter> and
/// <parameter>EMPTYSERVER</parameter> answer no rows, the second reading connected; any
/// other answers three rows, <parameter>LISTEDNAME</parameter> in <parameter>LISTEDDIRECTORY</parameter>,
/// <parameter>SECONDNAME</parameter> in <parameter>SECONDDIRECTORY</parameter> and <code>IRISSYS</code>
/// in the manager directory.</p>
/// <p><b>The parent's seams</b>, each read from a process-private node a test sets:
/// <method>NetworkEnabled</method> answers 1 under <code>^||OcuPilotRemoteLicensed</code> and the
/// instance's own license otherwise; <method>ListSeconds</method> answers
/// <code>^||OcuPilotRemoteBound</code> where set. <method>Directories</method> counts every listing
/// asked for in <code>^||OcuPilotRemoteListings</code> and <method>Spawn</method> every child started
/// in <code>^||OcuPilotRemoteSpawns</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseListingPort Extends OcuPilot.Port.RemoteDatabasePort
{

/// <p>The data server whose listing answers past a one-second bound.</p>
Parameter SLOWSERVER = "OCUPROBE1816SLOW";

Parameter SLOWSECONDS = 3;

Parameter LATENAME = "OCUPROBE1816LATE";

/// <p>The data server whose listing answers no rows.</p>
Parameter DOWNSERVER = "OCUPROBE1816DOWN";

/// <p>The data server whose listing answers no rows while its status reads connected
/// (<method>ServerStatus</method>).</p>
Parameter EMPTYSERVER = "OCUPROBE1816EMPTY";

/// <p>The one listed database the matrix's directory checks name.</p>
Parameter LISTEDNAME = "OCUPROBE1816X";

Parameter LISTEDDIRECTORY = "/ocuprobe1816x/";

/// <p>A second listed database, which a re-point moves to.</p>
Parameter SECONDNAME = "OCUPROBE1816Y";

Parameter SECONDDIRECTORY = "/ocuprobe1816y/";

/// <p>Every vendor call, recorded as <method>OcuPilot.Test.DatabaseRecordPort.Call</method> records
/// one, then sent.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tMutating = ##class(OcuPilot.Port.AdminPort).IsMutating(pEndpoint, pType)
    Set tIndex = $Increment(^||OcuPilotDatabaseCalls)
    Set ^||OcuPilotDatabaseCalls(tIndex) = $ListBuild(pEndpoint _ "/" _ pType, $Get(pQuery("name")) _ $Get(pQuery("dir")), $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), tMutating)
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

ClassMethod NetworkEnabled() As %Boolean
{
    If $Get(^||OcuPilotRemoteLicensed) Quit 1
    Quit ##super()
}

ClassMethod ListSeconds() As %Integer
{
    Set tBound = $Get(^||OcuPilotRemoteBound)
    If tBound '= "" Quit tBound
    Quit ##super()
}

ClassMethod Directories(pServer As %String, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotRemoteListings = $Get(^||OcuPilotRemoteListings) + 1
    Quit ##super(pServer, .pRows, .pTruncated, .pHttpStatus, .pFault)
}

ClassMethod Spawn(pNonce As %String, pServer As %String) As %Boolean
{
    Set ^||OcuPilotRemoteSpawns = $Get(^||OcuPilotRemoteSpawns) + 1
    Quit ##super(pNonce, pServer)
}

/// <p>The seam's listing, by data server name, as this class's header gives it.</p>
ClassMethod ListRows(pServer As %String, pCap As %Integer, Output pRows, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFault = ""
    Set pHttpStatus = 200
    Set tServer = $ZConvert(pServer, "U")
    If tServer = ..#SLOWSERVER {
        Hang ..#SLOWSECONDS
        Set pRows = [{"Name": (..#LATENAME), "Directory": "/ocuprobe1816late/"}]
        Quit $$$OK
    }
    If (tServer = ..#DOWNSERVER) || (tServer = ..#EMPTYSERVER) {
        Set pRows = []
        Quit $$$OK
    }
    Set pRows = [{"Name": (..#LISTEDNAME), "Directory": (..#LISTEDDIRECTORY)}]
    Do pRows.%Push({"Name": (..#SECONDNAME), "Directory": (..#SECONDDIRECTORY)})
    Do pRows.%Push({"Name": "IRISSYS", "Directory": (..Manager())})
    Quit $$$OK
}

/// <p><parameter>EMPTYSERVER</parameter> reads connected, as the shipped port's
/// <parameter>NORMALSTATUS</parameter>; every other server reads its status from the instance.</p>
ClassMethod ServerStatus(pServer As %String) As %String
{
    If $ZConvert(pServer, "U") = ..#EMPTYSERVER Quit ..#NORMALSTATUS
    Quit ##super(pServer)
}

/// <p>The vendor type number the port resolves for the listing (<parameter>SERVERENDPOINT</parameter>
/// <parameter>LISTINGTYPE</parameter>) without sending it, or <code>""</code> when the port does not
/// admit it.</p>
ClassMethod ListingType() As %String
{
    Set tClass = ..EndpointClass(..#SERVERENDPOINT)
    If tClass = "" Quit ""
    Quit ..EndpointType(..#SERVERENDPOINT, tClass, ..#LISTINGTYPE)
}

/// <p>The manager directory, normalized with its trailing separator: the seam's <code>IRISSYS</code>
/// row.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>Forget the counts and the armed license and bound, and the recorded calls.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotRemoteListings, ^||OcuPilotRemoteSpawns, ^||OcuPilotRemoteLicensed, ^||OcuPilotRemoteBound
    Do ##class(OcuPilot.Test.DatabaseRecordPort).Clear()
}

/// <p>How many listings were asked for since <method>Clear</method>.</p>
ClassMethod Listings() As %Integer
{
    Quit +$Get(^||OcuPilotRemoteListings)
}

/// <p>How many listing children were started since <method>Clear</method>.</p>
ClassMethod Spawns() As %Integer
{
    Quit +$Get(^||OcuPilotRemoteSpawns)
}

}
