/// <p>Pins <method>OcuPilot.Install.Installer.BundleIdentity</method>'s fallback and its choice
/// between hashed mains, through <method>OcuPilot.Test.InstallerProbe.BundleIdentityOf</method>: an
/// unset directory, a missing one and one with no <code>main-*.js</code> each answer
/// <parameter>OcuPilot.Install.Installer.BUILDIDENTITY</parameter>, and of two hashed mains the one
/// that sorts last is answered.</p>
/// <p>Needs nothing from the environment beyond a writable temporary directory, where it creates
/// and removes its own files.</p>
Class OcuPilot.Test.BundleIdentity Extends %UnitTest.TestCase
{

/// <p>A directory of this process's own under the instance's temporary directory, created empty.</p>
ClassMethod ScratchDirectory() As %String
{
    Set tDir = ##class(%File).NormalizeDirectory(##class(%File).SubDirectoryName(##class(%SYS.System).TempDirectory(), "OcuPilotBundleIdentity" _ $Job))
    Do ##class(%File).RemoveDirectoryTree(tDir)
    Do ##class(%File).CreateDirectoryChain(tDir)
    Quit tDir
}

/// <p>Write an empty file named <var>pLeaf</var> into <var>pDirectory</var>.</p>
ClassMethod Touch(pDirectory As %String, pLeaf As %String) As %Status
{
    Set tFile = ##class(%Stream.FileCharacter).%New()
    Set tSC = tFile.LinkToFile(pDirectory _ pLeaf)
    If $$$ISERR(tSC) Quit tSC
    Do tFile.Write("")
    Quit tFile.%Save()
}

/// <p>Mutation (Rule 19): initialize the identity to <code>""</code> instead of
/// <parameter>OcuPilot.Install.Installer.BUILDIDENTITY</parameter> in
/// <method>OcuPilot.Install.Installer.BundleIdentity</method> and recompile <code>OcuPilot.*</code>
/// -> the three fallback legs go red.</p>
Method TestEachAbsentBundleAnswersTheFallback()
{
    Set tFallback = ##class(OcuPilot.Install.Installer).#BUILDIDENTITY
    Do $$$AssertNotEquals(tFallback, "", "the fallback is a word, not nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).BundleIdentityOf(""), tFallback, "an unset shell directory answers the fallback")

    Set tDir = ..ScratchDirectory()
    Set tMissing = ##class(%File).NormalizeDirectory(tDir _ "absent")
    Do $$$AssertTrue('##class(%File).DirectoryExists(tMissing), "the missing directory does not exist")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).BundleIdentityOf(tMissing), tFallback, "a missing directory answers the fallback")

    Do $$$AssertStatusOK(..Touch(tDir, "main.js"), "an unhashed main is written")
    Do $$$AssertStatusOK(..Touch(tDir, "polyfills-ABCD1234.js"), "and another hashed file")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).BundleIdentityOf(tDir), tFallback, "a directory with no main-*.js answers the fallback")
    Do ##class(%File).RemoveDirectoryTree(tDir)
}

/// <p>Of two hashed mains, the name that sorts last is answered.</p>
Method TestTheLastOfTwoHashedMainsWins()
{
    Set tDir = ..ScratchDirectory()
    Do $$$AssertStatusOK(..Touch(tDir, "main-BBBB2222.js"), "one hashed main is written")
    Do $$$AssertStatusOK(..Touch(tDir, "main-AAAA1111.js"), "and a second")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).BundleIdentityOf(tDir), "main-BBBB2222.js", "the name that sorts last is the identity")
    Do $$$AssertStatusOK(..Touch(tDir, "main-CCCC3333.js"), "a third that sorts later")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).BundleIdentityOf(tDir), "main-CCCC3333.js", "moves the identity with it")
    Do ##class(%File).RemoveDirectoryTree(tDir)
}

}
