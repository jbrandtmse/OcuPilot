/// <p>AD-27's endpoint inventory, checked against the running instance. It re-derives the
/// rows <class>OcuPilot.Test.AdminInventory</class> has checked in and fails on any
/// disagreement, so an IRIS upgrade that moves the vendor's ground is caught here rather
/// than by a user. Story 1.17 puts this class in CI; until then the suite is the gate.</p>
/// <p>Named <code>Inventory</code> rather than <code>AdminInventoryTest</code>, which is 32
/// characters against the 29-character class-name limit (Consistency Conventions).</p>
Class OcuPilot.Test.Inventory Extends %UnitTest.TestCase
{

/// <p>AC5 -- the checked-in inventory and the instance agree, class for class and field for
/// field. Reported as two lists rather than one count, so a failure names the rows.</p>
/// <p>Mutation: change any one <code>&lt;endpoint/&gt;</code> row in
/// <class>OcuPilot.Test.AdminInventory</class>'s XData -> this goes red naming that class.</p>
Method TestTheCheckedInInventoryMatchesTheInstance()
{
    Set tSC = ##class(OcuPilot.Test.AdminInventory).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the inventory derives from the instance")
    Set tStoredSC = ##class(OcuPilot.Test.AdminInventory).Stored(.tStored)
    Do $$$AssertStatusOK(tStoredSC, "the checked-in inventory parses")

    Set tDrift = ""
    Set tClass = ""
    For {
        Set tClass = $Order(tLive(tClass))
        Quit:tClass=""
        If '$Data(tStored(tClass)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tClass _ " is on the instance and not in the fixture"
            Continue
        }
        If tStored(tClass) '= tLive(tClass) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tClass _ " fixture=" _ tStored(tClass) _ " instance=" _ tLive(tClass)
        }
    }
    Set tClass = ""
    For {
        Set tClass = $Order(tStored(tClass))
        Quit:tClass=""
        If '$Data(tLive(tClass)) {
            Set tDrift = tDrift _ $Select(tDrift = "": "", 1: "; ") _ tClass _ " is in the fixture and not on the instance"
        }
    }
    Do $$$AssertEquals(tDrift, "", "the fixture and the instance agree")
}

/// <p>AC5 -- the population figures AD-3 and AD-26 are written against, read back off the
/// live derivation. A count is not a substitute for the row-by-row comparison above; it is
/// the check that the comparison is comparing the right population.</p>
/// <p>Mutation: narrow <method>OcuPilot.Test.AdminInventory.Derive</method>'s query to a
/// sub-package -> the class count goes red before any row does.</p>
Method TestTheCountsMatchTheArchitecture()
{
    Set tSC = ##class(OcuPilot.Test.AdminInventory).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the inventory derives from the instance")

    Set tClasses = 0, tAsync = 0
    Set tClass = ""
    For {
        Set tClass = $Order(tLive(tClass))
        Quit:tClass=""
        Set tClasses = tClasses + 1
        Set tTemplate = $Piece(tLive(tClass), "|", 1)
        If tTemplate '= "" Set tTemplates(tTemplate) = $Get(tTemplates(tTemplate)) + 1
        If $Piece(tLive(tClass), "|", 2) = 1 Set tAsync = tAsync + 1
        Set tCsp = $Piece(tLive(tClass), "|", 3)
        Set tCspCounts(tCsp) = $Get(tCspCounts(tCsp)) + 1
    }

    Do $$$AssertEquals(tClasses, 70, "the endpoint package holds 70 classes")
    Do $$$AssertEquals($Get(tTemplates("RequestBodySchema")), 21, "21 publish RequestBodySchema")
    Do $$$AssertEquals($Get(tTemplates("PutRequestBodySchema")), 17, "17 publish PutRequestBodySchema")
    Do $$$AssertEquals($Get(tTemplates("PutAndPostSchema")), 1, "1 publishes PutAndPostSchema")
    Do $$$AssertEquals($Get(tTemplates("Schema")), 1, "1 publishes Schema")
    Do $$$AssertEquals(tAsync, 7, "7 override ShouldRunAsync themselves")
    Do $$$AssertEquals($Get(tCspCounts("request")), 4, "4 reach for %request")
    Do $$$AssertEquals($Get(tCspCounts("response")), 1, "1 reaches for %response")
    Do $$$AssertEquals($Get(tCspCounts("unreadable")), 3, "and 3 are compiler stubs whose source cannot be fetched")
}

/// <p>AC6 -- AD-26's second async entry and AD-3's template-less mutating population, read back
/// off the live derivation: 3 classes queue their own task, and 16 mutating classes publish no
/// template, among them the five Release 1 endpoints AD-3 names.</p>
/// <p>Mutation: narrow <parameter>OcuPilot.Test.AdminInventory.MUTATINGMETHODS</parameter> to
/// <code>RunPut</code> -> the mutating count goes red.</p>
Method TestQueuedAndMutatingCountsMatchTheArchitecture()
{
    Set tSC = ##class(OcuPilot.Test.AdminInventory).Derive(.tLive)
    Do $$$AssertStatusOK(tSC, "the inventory derives from the instance")

    Set tQueues = 0, tQueueUnreadable = 0, tTemplateless = 0
    Set tClass = ""
    For {
        Set tClass = $Order(tLive(tClass))
        Quit:tClass=""
        Set tRow = tLive(tClass)
        If $Piece(tRow, "|", 4) = 1 Set tQueues = tQueues + 1
        If $Piece(tRow, "|", 4) = "unreadable" Set tQueueUnreadable = tQueueUnreadable + 1
        If ($Piece(tRow, "|", 1) = "") && ($Piece(tRow, "|", 5) = 1) Set tTemplateless = tTemplateless + 1
    }
    Do $$$AssertEquals(tQueues, 3, "3 classes queue their own task from Run()")
    Do $$$AssertEquals(tQueueUnreadable, 3, "and the 3 stubs are unreadable, not scored as queuing nothing")
    For tQueued = "Database.Actions", "Journal.Record", "Security.Audit.Record" {
        Do $$$AssertEquals($Piece($Get(tLive(tQueued)), "|", 4), 1, tQueued _ " queues its own task")
    }
    Do $$$AssertEquals(tTemplateless, 16, "16 mutating classes publish no template")
    For tReleaseOne = "Wallet.Secret", "Security.Audit.Event", "Process", "Lock", "Task.Manager" {
        Set tRow = $Get(tLive(tReleaseOne))
        Do $$$AssertTrue(($Piece(tRow, "|", 1) = "") && ($Piece(tRow, "|", 5) = 1), tReleaseOne _ " is mutating and publishes no template")
    }
}

/// <p>AC5 -- a source lookup that fails is recorded as <code>unreadable</code>, never as
/// <code>none</code>. Scoring a failure as "references neither" reads a failed lookup as a
/// negative result, which is how three stub classes were once counted as four ordinary
/// ones.</p>
/// <p>Mutation: make <method>OcuPilot.Test.AdminInventory.SourceState</method> return
/// <code>none</code> instead of <code>unreadable</code> when the source cannot be read -> this
/// goes red, and so does the <code>unreadable</code> count above.</p>
Method TestAFailedSourceLookupIsNotScoredAsNoMatch()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminInventory).SourceState("OcuPilot.Test.NoSuchClassAtAll"), "unreadable", "a class whose source cannot be fetched is unreadable")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminInventory).SourceState("OcuPilot.Test.AdminApiV1"), "none", "and a class that is readable and mentions neither is none")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.AdminInventory).SourceState("OcuPilot.Test.NoSuchClassAtAll"), "none", "the two are never the same value")
}

/// <p>AC5 -- the two halves the inventory records about a class are read from the compiled
/// method's origin, so an inherited method is never mistaken for a local override. Asserted
/// against this suite's own fixture rather than a vendor class (AD-27).</p>
Method TestAnInheritedMethodIsNotALocalOverride()
{
    Do $$$AssertTrue(##class(OcuPilot.Test.AdminInventory).LocallyDefines("OcuPilot.Test.PortFixture", "AdminApiClass"), "the fixture overrides the seam itself")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminInventory).LocallyDefines("OcuPilot.Test.PortFixture", "VerifyInstance"), 0, "and inherits the verification unchanged")
}

}
