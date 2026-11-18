/// <p>Pins the database half of Story 24.11's listing group write gate (Batch 2: AD-29, AD-61, AD-65) against <code>USER</code>, in process through
/// <class>OcuPilot.Test.AnalyticsListingGroupDatabaseSeam</class>: every one of the seven writes is refused 409 <code>ANALYTICS.LISTINGGROUP.READONLY</code> and before any write when the
/// database the listing groups' global maps to reads read-only or not mounted (a read composed for a write too, a plain read still answers); each is refused 403 naming the pair when
/// the caller lacks READ on a database the namespace maps code from, which <code>AtelierPort.WritePairs</code> adds to the gate, or WRITE on the destination database; and a principal
/// without <code>%DeepSee_ListingGroupSQL:USE</code> mints a listing change that leaves SQL alone, so its refusal of an SQL change is that pair's alone. The helpers are
/// <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named groups and classes in <code>USER</code>, and one probe principal.</p>
Class OcuPilot.Test.AnalyticsListingGroupDatabase Extends OcuPilot.Test.AnalyticsListingGroupBase
{

Parameter SEAM = "OcuPilot.Test.AnalyticsListingGroupDatabaseSeam";

Parameter SETLISTINGTOOL = "OcuPilot.Screen.Tool.AnalyticsListingSet";

/// <p>The seven writes against the group <var>pName</var>, each <code>$ListBuild(endpoint, type, id, body)</code> with the body as JSON text, which a list holds where it could not hold the object.</p>
ClassMethod Writes(pName As %String) As %List
{
    Set tId = ..IdOf(pName, "LGDOne")
    Set tAdd = {"Name": (..#MARKER _ "DbNew"), "Class": (..#CLASSMARKER _ "DbNew"), "TargetCubes": (..#VISITS)}
    Set tCopy = {"Name": (..#MARKER _ "DbCopy"), "Class": (..#CLASSMARKER _ "DbCopy"), "TargetCubes": (..#CATEGORIES)}
    Quit $ListBuild($ListBuild("ListingGroups", "ADD", ..#MARKER _ "DbNew", tAdd.%ToJSON()), $ListBuild("ListingGroups", "UPDATE", pName, "{""Caption"":""x""}"), $ListBuild("ListingGroups", "COPY", pName, tCopy.%ToJSON()), $ListBuild("ListingGroups", "DELETE", pName, "{}"), $ListBuild("ListingGroupListings", "ENTRYADD", ..IdOf(pName, "LGDTwo"), "{""Fields"":""Amount""}"), $ListBuild("ListingGroupListings", "ENTRYSET", tId, "{""Description"":""x""}"), $ListBuild("ListingGroupListings", "ENTRYREMOVE", tId, "{}"))
}

/// <p>Each write answers <var>pExpected</var> and writes nothing: the status and code in one string, then <code>|</code> and the pair for a privilege refusal, as <method>Seamed</method> does.</p>
Method AssertEachRefused(pName As %String, pExpected As %String, pWhy As %String)
{
    Set tWrites = ..Writes(pName)
    For tAt = 1:1:$ListLength(tWrites) {
        Set tWrite = $List(tWrites, tAt)
        Set tResult = ..Seamed($List(tWrite, 1), $List(tWrite, 2), $List(tWrite, 3), ##class(%DynamicObject).%FromJSON($List(tWrite, 4)), .tRes)
        Do $$$AssertEquals(tResult, pExpected, $List(tWrite, 2) _ " " _ pWhy _ ": " _ tResult)
    }
}

/// <p>AC1, AC5: the destination database the listing groups' global maps to is writable and mounted on the instance; with the seam arming it read-only, or not mounted, each of the seven writes
/// is refused 409 <code>ANALYTICS.LISTINGGROUP.READONLY</code> with every pair held and nothing written, and so is the read the agent's mint and the screen's action compose for a change, while
/// the plain read answers 200. Unarmed, the same group takes an update.</p>
/// <p>Mutation (Rule 19): drop the <code>tReadOnly || 'tMounted</code> refusal from <method>OcuPilot.Port.AnalyticsPort.AdmitDestination</method> -- both modes' legs go red.</p>
Method TestADatabaseThatIsReadOnlyOrNotMountedRefusesEveryWrite()
{
    Set tName = ..#MARKER _ "Db"
    Set tClass = ..#CLASSMARKER _ "Db"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGDOne"), "the group is saved and compiled")
    Set tResolved = ##class(OcuPilot.Port.AnalyticsPort).DestinationDatabase(..#NAMESPACE, $Parameter(..#PORT, "LISTINGGROUPGLOBAL"), .tResource, .tReadOnly, .tMounted)
    Do $$$AssertEquals(tResolved _ "|" _ (tResource '= "") _ "|" _ tReadOnly _ "|" _ tMounted, "1|1|0|1", "the instance's own destination database is named, writable and mounted")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Do ..HoldEverythingBut("")
    For tMode = "readonly", "unmounted" {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", "lgdatabase", tMode)
        Do ..AssertEachRefused(tName, "409 ANALYTICS.LISTINGGROUP.READONLY", "with the database " _ tMode)
        Do $$$AssertEquals(..Seamed("ListingGroups", "LISTINGGROUP", tName, "", .tRes, {"action": "UPDATE"}), "409 ANALYTICS.LISTINGGROUP.READONLY", tMode _ ": the read composed for a change is refused")
        Do $$$AssertEquals(..Seamed("ListingGroups", "LISTINGGROUP", tName, "", .tRes), "200 ", tMode _ ": a plain read still answers")
    }
    Do $$$AssertEquals(..Snapshot() _ "|" _ (..TextOf(tClass) = tText), tBefore _ "|1", "nothing was written and the class text is as it was")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..Seamed("ListingGroups", "UPDATE", tName, {"Caption": "applied"}, .tRes), "200 ", "unarmed, the same update is made")
}

/// <p>AC1, AC5: with every other pair held, a caller without READ on a database the namespace maps code from (the pairs <code>AtelierPort.WritePairs</code> adds to the screen's own) or without WRITE on
/// the database the listing groups' global maps to, which the seam moves to another resource so that it is not a pair <code>WritePairs</code> names, is refused 403 naming that pair on each
/// of the seven writes and writes nothing; with the destination's WRITE held the update is made, so the refusal was that pair's alone.</p>
/// <p>Mutation (Rule 19): drop <code>tWritePairs</code> from the pair list of <method>OcuPilot.Port.AnalyticsPort.AdmitListingGroup</method> -- the two READ legs go red; drop the WRITE check from
/// <method>OcuPilot.Port.AnalyticsPort.AdmitDestination</method> -- the destination leg goes red.</p>
Method TestAWriteNeedsEveryDatabasePairItsCodeAndItsDestinationUse()
{
    Set tName = ..#MARKER _ "Db"
    Set tClass = ..#CLASSMARKER _ "Db"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGDOne"), "the group is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(..#NAMESPACE)
    Set tNames = ""
    For tAt = 1:1:$ListLength(tWritePairs) Set tNames = tNames _ "," _ $List($List(tWritePairs, tAt), 1) _ ":" _ $List($List(tWritePairs, tAt), 2)
    Do $$$AssertTrue((tNames [ ",%DB_ENSLIB:READ") && (tNames [ ",%DB_IRISLIB:READ"), "the namespace's write pairs name READ on the code databases beside its own: " _ tNames)
    For tExcept = "%DB_ENSLIB:READ", "%DB_IRISLIB:READ" {
        Do ..HoldEverythingBut(tExcept)
        Do ..AssertEachRefused(tName, "403 AUTH.NOPRIVILEGE|" _ tExcept, "without " _ tExcept _ " is refused naming it")
    }
    Do ..HoldEverythingBut("")
    Do $ClassMethod(..#SEAM, "Arm", "lgresource", "%DB_ENSLIB")
    Do ..AssertEachRefused(tName, "403 AUTH.NOPRIVILEGE|%DB_ENSLIB:WRITE", "without WRITE on the destination database is refused naming it")
    Do $$$AssertEquals(..Snapshot() _ "|" _ (..TextOf(tClass) = tText), tBefore _ "|1", "nothing was written and the class text is as it was")
    Do $ClassMethod(..#GATE, "Hold", "%DB_ENSLIB", "WRITE")
    Do $$$AssertEquals(..Seamed("ListingGroups", "UPDATE", tName, {"Caption": "applied"}, .tRes), "200 ", "with that WRITE held the update is made")
}

/// <p>AC1, AC5: the principal without <code>%DeepSee_ListingGroupSQL:USE</code>, minting in a child process, mints a listing change that sets no SQL and a group's change, so its refusal of
/// a change that sets SQL is that pair's alone and not another missing pair's; the proposal is removed and no class changes.</p>
/// <p>Mutation (Rule 19): require the SQL pair for every listing write in <method>OcuPilot.Port.AnalyticsPort.VendorListingGroupCompose</method> -- the listing change's mint is refused and this goes red.</p>
Method TestAPrincipalWithoutTheSqlPairMintsAChangeThatLeavesSqlAlone()
{
    Set tGroup = ..#MARKER _ "NoSql"
    Set tClass = ..#CLASSMARKER _ "NoSql"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGDOne"), "the group is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tPassword = "OcuP2411Lgd" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#NOSQLPRINCIPAL, tPassword, $CLASSNAME())
    Do $$$AssertStatusOK(tSC, "the principal without the SQL pair is created")
    If $$$ISOK(tSC) {
        For tCase = $ListBuild(..#SETLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGDOne", "Description": "no sql here"}.%ToJSON()), $ListBuild(..#UPDATETOOL, {"Name": (tGroup), "Caption": "from the principal"}.%ToJSON()) {
            Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#NOSQLUSER, "completed", .tTurn), "a turn is seeded for the principal")
            Set tOut = ..MintAsNoSql($List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), $Get(tTurn))
            Do $$$AssertEquals($Select($IsObject(tOut): tOut.%Get("error"), 1: "no answer"), "", $Parameter($List(tCase, 1), "TOOLNAME") _ ": the probe process answered")
            If $IsObject(tOut) && (tOut.%Get("error") = "") {
                Do $$$AssertEquals(tOut.%Get("username") _ "|" _ tOut.%Get("minted") _ "|" _ tOut.%Get("http"), ..#NOSQLUSER _ "|1|200", $Parameter($List(tCase, 1), "TOOLNAME") _ ": the principal mints it")
            }
            Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        }
    }
    Do $$$AssertStatusOK(..RemoveNoSqlPrincipal(), "the principal is removed")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no mint changed a class")
}

}
