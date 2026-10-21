/// <p>What pins <class>OcuPilot.Port.AdminPort</class>'s two decisions about a request type
/// directly (AD-2): the HTTP method the request stub carries, and the vendor type number the
/// endpoint is built with. Both are asked through <class>OcuPilot.Test.AdminPortTypeSeam</class>,
/// which inherits the shipped <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> and
/// overrides nothing, so a change to the shipped list is seen once the seam is recompiled.</p>
/// <p>Four <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs, each a different
/// suffix, send their suffix as the method and resolve to the type their endpoint class declares; so does
/// the <parameter>OcuPilot.Port.AdminPort.CHECKTYPES</parameter> pair, for its method.
/// Three pairs outside the list send <code>GET</code>, and two of them -- a write suffix the vendor's
/// class declares but the list does not admit -- resolve to no type at all, which is the 501 the
/// tool path pins in <class>OcuPilot.Test.ToolWrite</class>.</p>
/// <p>It needs nothing from the environment, creates nothing and writes nothing.</p>
Class OcuPilot.Test.AdminPortMutatingPath Extends %UnitTest.TestCase
{

/// <p>The seam every question is asked through.</p>
Parameter SEAM = "OcuPilot.Test.AdminPortTypeSeam";

/// <p>Four <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> members, as
/// <code>endpoint/suffix</code>.</p>
Parameter MUTATING = "WebApp.App/PUT,WebApp.PctClassAccess/DELETE,Security.User/POST,Task.CRUD/RESUME";

/// <p>Two write suffixes the endpoint's class declares and the list does not admit, as
/// <code>endpoint/suffix</code>.</p>
Parameter UNLISTED = "Device.Settings/PUT,Process/DELETE";

/// <p>The pair that is a read, so the method stays <code>GET</code>.</p>
Parameter READPAIR = "WebApp.App/LIST";

/// <p>The <parameter>OcuPilot.Port.AdminPort.CHECKTYPES</parameter> pair, as <code>endpoint/suffix</code>.</p>
Parameter CHECKPAIR = "License.Key/VALIDATE";

/// <p>Each listed pair sends its suffix, and each unlisted or read pair sends <code>GET</code>.</p>
/// <p>Mutations: <method>OcuPilot.Port.AdminPort.HttpMethodFor</method> answering <code>PUT</code> for
/// every mutating pair -> the <code>WebApp.PctClassAccess/DELETE</code>, <code>Security.User/POST</code>
/// and <code>Task.CRUD/RESUME</code> legs go red; answering its suffix for every pair -> the <code>GET</code> legs go red;
/// without its <code>IsCheckType</code> line -> the check pair's leg goes red; removing
/// <code>WebApp.PctClassAccess/DELETE</code> from <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter>
/// with the seam recompiled -> that pair's legs go red.</p>
Method TestAMutatingPairSendsItsSuffixAndAnyOtherSendsGet()
{
    Set tSeam = ..#SEAM
    Set tPairs = $ListFromString(..#MUTATING)
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Set tEndpoint = $Piece(tPair, "/", 1)
        Set tSuffix = $Piece(tPair, "/", 2)
        Do $$$AssertTrue($ClassMethod(tSeam, "IsMutating", tEndpoint, tSuffix), tPair _ " is a member of the shipped list")
        Do $$$AssertEquals($ClassMethod(tSeam, "MethodFor", tEndpoint, tSuffix), tSuffix, tPair _ " sends its suffix as the method")
    }
    Set tCheck = ..#CHECKPAIR
    Do $$$AssertTrue($ClassMethod(tSeam, "IsCheckType", $Piece(tCheck, "/", 1), $Piece(tCheck, "/", 2)), tCheck _ " is a member of the shipped check list")
    Do $$$AssertEquals($ClassMethod(tSeam, "MethodFor", $Piece(tCheck, "/", 1), $Piece(tCheck, "/", 2)), $Piece(tCheck, "/", 2), tCheck _ " sends its suffix as the method")
    Set tOthers = $ListFromString(..#UNLISTED _ "," _ ..#READPAIR)
    For tI = 1:1:$ListLength(tOthers) {
        Set tPair = $List(tOthers, tI)
        Set tEndpoint = $Piece(tPair, "/", 1)
        Set tSuffix = $Piece(tPair, "/", 2)
        Do $$$AssertEquals($ClassMethod(tSeam, "MethodFor", tEndpoint, tSuffix), "GET", tPair _ " sends GET")
    }
    For tI = 1:1:$ListLength($ListFromString(..#UNLISTED)) {
        Set tPair = $List($ListFromString(..#UNLISTED), tI)
        Do $$$AssertTrue('$ClassMethod(tSeam, "IsMutating", $Piece(tPair, "/", 1), $Piece(tPair, "/", 2)), tPair _ " is not a member of the shipped list")
    }
}

/// <p>Each listed pair resolves to the type number its endpoint class declares for that suffix, and
/// each unlisted write suffix resolves to none, although its class declares one -- the control
/// legs that make the empty answer the list's and not the class's.</p>
/// <p>Mutations: <method>OcuPilot.Port.AdminPort.EndpointType</method> without its
/// <code>'..IsMutating(...)</code> term -> the listed legs resolve to none and go red; without its unlisted-suffix
/// <code>Quit ""</code> -> the unlisted legs go red; removing a
/// pair from <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> with the seam recompiled ->
/// that pair's leg goes red.</p>
Method TestAMutatingPairResolvesItsTypeAndAnUnlistedWriteSuffixResolvesNone()
{
    Set tSeam = ..#SEAM
    Set tPairs = $ListFromString(..#MUTATING)
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Set tEndpoint = $Piece(tPair, "/", 1)
        Set tSuffix = $Piece(tPair, "/", 2)
        Set tClass = $ClassMethod(tSeam, "EndpointClass", tEndpoint)
        Do $$$AssertNotEquals(tClass, "", tEndpoint _ " resolves to an endpoint class")
        Set tDeclared = $Parameter(tClass, "TYPE" _ tSuffix)
        Do $$$AssertNotEquals(tDeclared, "", tPair _ "'s class declares TYPE" _ tSuffix)
        Do $$$AssertEquals($ClassMethod(tSeam, "TypeFor", tEndpoint, tSuffix), tDeclared, tPair _ " resolves to the declared type")
    }
    Set tUnlisted = $ListFromString(..#UNLISTED)
    For tI = 1:1:$ListLength(tUnlisted) {
        Set tPair = $List(tUnlisted, tI)
        Set tEndpoint = $Piece(tPair, "/", 1)
        Set tSuffix = $Piece(tPair, "/", 2)
        Set tClass = $ClassMethod(tSeam, "EndpointClass", tEndpoint)
        Do $$$AssertNotEquals(tClass, "", tEndpoint _ " resolves to an endpoint class")
        Do $$$AssertNotEquals($Parameter(tClass, "TYPE" _ tSuffix), "", tPair _ "'s class declares TYPE" _ tSuffix)
        Do $$$AssertEquals($ClassMethod(tSeam, "TypeFor", tEndpoint, tSuffix), "", tPair _ " resolves to no type")
    }
}

}
