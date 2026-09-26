/// <p>The read-back of a confirmed write (AD-58): after a write reads OK, its caller re-reads the
/// target through the tool's declared port and read type, with the caller's own privileges, and
/// this class says whether the instance now holds what the write sent.</p>
/// <p><b>Three callers, one comparison</b> (AD-53, AD-55): the agent's confirm
/// (<class>OcuPilot.Kernel.Proposal.Confirm</class>), a screen's row action
/// (<class>OcuPilot.Api.ScreenAction</class>) and every screen Save route that writes an instance
/// object. Each calls <method>Of</method> after its write, its ledger row and its marker, outside
/// any transaction and holding no lock, and puts the answer beside the write's own. Nothing here
/// fails, delays or alters that answer: every fault reads <code>unchecked</code>.</p>
/// <p><b>The answer is names and a verdict, never a value</b> (AD-35):
/// <code>{verdict, fields, written, reason?}</code>. <code>fields</code> holds the top-level names
/// that differ and <code>written</code> the secret names sent. A secret's read value is never
/// examined, and no read or sent value reaches the answer or a log line.</p>
/// <p><b>The kind decides the subject</b>, and the kind is derived from the tool's own parameters,
/// never hand-set: a delete (<code>CHANGEACTION</code> <code>deleted</code>) expects absence; a
/// create (<code>CREATES</code>, AD-54) and a merge (<code>SENDSBODY</code> 1) compare every
/// top-level key of the sent body its <class>OcuPilot.Screen.Tool.ToolFields</class> rows name,
/// minus the descriptor's <code>fingerprintExcludes</code>; a secret-only write
/// (<code>SECRETBODY</code>, AD-56 (i)) reports its names written; an action-style write (AD-51)
/// sends no value and says so.</p>
/// <p><b>How a field the instance normalizes on save is compared</b> is the tool's reviewed
/// Classification entry's <code>compare</code> declaration, emitted onto its field rows (AD-3):
/// <code>unordered</code>, <code>unslashed</code>, <code>words</code>, <code>letters</code>,
/// <code>members</code> or <code>written</code>. Every other field takes <method>Same</method>'s
/// default rules.</p>
Class OcuPilot.Kernel.Proposal.ReadBack Extends %RegisteredObject
{

/// <p>The target holds every compared field as sent.</p>
Parameter MATCHES = "matches";

/// <p>At least one compared field reads back differently; <code>fields</code> names each.</p>
Parameter DIFFERS = "differs";

/// <p>The re-read answered 404: after a delete, the expected result.</p>
Parameter NOTFOUND = "notFound";

/// <p>A delete whose target still answers.</p>
Parameter PRESENT = "present";

/// <p>A secret-only write: its names are listed and nothing is read back.</p>
Parameter WRITTEN = "written";

/// <p>An action-style write, which sends no value to compare (AD-51).</p>
Parameter NOTHINGSENT = "nothingSent";

/// <p>No verdict could be reached; <code>reason</code> says why.</p>
Parameter UNCHECKED = "unchecked";

/// <p><code>unchecked</code>'s reason for a write the port answered 202 (AD-26): no re-read is
/// made while it runs.</p>
Parameter REASONRUNNING = "running";

/// <p><code>unchecked</code>'s reason for a re-read that failed other than with 404.</p>
Parameter REASONUNREADABLE = "unreadable";

/// <p>The closed vocabulary of declared comparison modes.</p>
Parameter MODES = "unordered,unslashed,words,letters,members,written";

/// <p>The port a tool's re-read goes through when the caller names none and the tool declares the
/// base's own default (AD-52).</p>
Parameter DEFAULTPORT = "OcuPilot.Port.AdminPort";

/// <p>The generated field lists the compared names and their declared modes are read from.</p>
Parameter TOOLFIELDSCLASS = "OcuPilot.Screen.Tool.ToolFields";

/// <p>The read-back of the write <var>pToolClass</var> just made to the target
/// <var>pIdValue</var>, having sent <var>pSent</var> over the fresh read <var>pFresh</var>.</p>
/// <p><b>Caller contract:</b> called once, after the write read OK and after the caller's ledger
/// row and marker, never inside a transaction. <var>pIdValue</var> is the id the target answers
/// under now -- a create's <code>createdId</code> where its tool answers one; a tool whose read is a
/// list row is asked by the value <var>pSent</var> carries under its row key instead, and a sent
/// name that row does not answer is not compared. <var>pPayloadJson</var> is the payload the tool's own port query is read from (the stored one for
/// the agent's caller). <var>pPort</var> is the port the caller resolved; <code>""</code> resolves
/// the tool's own declaration. A caller whose write answered 202 calls <method>Running</method>
/// instead. The answer is always an object and this method never throws.</p>
ClassMethod Of(pToolClass As %String, pIdValue As %String, pSent As %DynamicObject, pFresh As %DynamicObject, pPayloadJson As %String, pPort As %String = "") As %DynamicObject
{
    Set tAnswer = ""
    Try {
        Set tKind = ..KindOf(pToolClass)
        Set tPort = pPort
        If tPort = "" Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pToolClass, ..#DEFAULTPORT)
        Set tEndpoint = $ClassMethod(pToolClass, "Endpoint")
        Set tIdParam = $ClassMethod(pToolClass, "IdParam")
        ; A list-type read finds its row by the declared row key, so it is asked by the value the
        ; write sent under that key, exactly as the mint's read resolves (AD-51).
        Set tRowKey = ##class(OcuPilot.Kernel.Proposal.Operation).ReadRowKeyOf(pToolClass)
        Set tReadId = pIdValue
        If (tRowKey '= "") && $IsObject(pSent) && (pSent.%GetTypeOf(tRowKey) = "string") && (pSent.%Get(tRowKey) '= "") Set tReadId = pSent.%Get(tRowKey)
        Set tReadSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadAt(pToolClass, tPort, tEndpoint, tIdParam, tReadId, pPayloadJson, .tRead, .tReadHttp, .tReadFault)
        Set tPresent = $$$ISOK(tReadSC) && $IsObject($Get(tRead))
        If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
            Set tAnswer = ..Verdict(..#UNCHECKED, "", "", ..#REASONUNREADABLE)
            Quit
        }
        If $$$ISOK(tReadSC) && 'tPresent {
            Set tAnswer = ..Verdict(..#UNCHECKED, "", "", ..#REASONUNREADABLE)
            Quit
        }
        If tKind = "delete" {
            If 'tPresent {
                Set tAnswer = ..Verdict(..#NOTFOUND)
                Quit
            }
            If ..Gone(pToolClass, tRead, pPayloadJson) {
                Set tAnswer = ..Verdict(..#NOTFOUND)
                Quit
            }
            Set tAnswer = ..Verdict(..#PRESENT)
            Quit
        }
        If 'tPresent {
            Set tAnswer = ..Verdict(..#NOTFOUND)
            Quit
        }
        If tKind = "action" {
            Set tAnswer = ..Verdict(..#NOTHINGSENT)
            Quit
        }
        If tKind = "secret" {
            Set tAnswer = ..Verdict(..#WRITTEN, "", ..SentNames(pSent))
            Quit
        }
        ; A merge or a create. A create compares against an empty fresh read (AD-54).
        Set tBefore = $Select(tKind = "create": {}, $IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject"): pFresh, 1: {})
        If '..Compared(pToolClass, pSent, tBefore, tRead, .tFields, .tWritten, (tRowKey '= "")) {
            Set tAnswer = ..Verdict(..#UNCHECKED, "", "", ..#REASONUNREADABLE)
            Quit
        }
        Set tAnswer = ..Verdict($Select(tFields = "": ..#MATCHES, 1: ..#DIFFERS), tFields, tWritten)
    } Catch {
        Set tAnswer = ""
    }
    If '$IsObject(tAnswer) Set tAnswer = ..Verdict(..#UNCHECKED, "", "", ..#REASONUNREADABLE)
    Quit tAnswer
}

/// <p>The read-back a screen Save answers beside its write (AD-55, AD-58): <method>Of</method> over
/// the body <var>pSent</var> the Save sent for the target <var>pIdValue</var>, the fresh read
/// <var>pFresh</var> it merged over (<code>""</code> for a create), through the port
/// <var>pPort</var> the Save wrote through.</p>
/// <p><b>Caller contract:</b> called once, after the Save's own port call read OK. <var>pWritten</var>
/// is that call's answer, from which a tool that allocates its target's id answers it
/// (<method>OcuPilot.Screen.Tool.Write.CreatedId</method>); <var>pWriteHttp</var> 202 answers
/// <method>Running</method> and reads nothing.</p>
ClassMethod ForSave(pToolClass As %String, pIdValue As %String, pSent As %DynamicObject, pFresh As %DynamicObject = "", pPort As %String = "", pWritten As %RawString = "", pWriteHttp As %Integer = 0) As %DynamicObject
{
    If +pWriteHttp = 202 Quit ..Running()
    Set tId = pIdValue
    Try {
        Set tCreated = $ClassMethod(pToolClass, "CreatedId", pWritten)
        If tCreated '= "" Set tId = tCreated
    } Catch {
        Set tId = pIdValue
    }
    Set tPayloadJson = ""
    If $IsObject(pSent) Set tPayloadJson = pSent.%ToJSON()
    Quit ..Of(pToolClass, tId, pSent, pFresh, tPayloadJson, pPort)
}

/// <p>The read-back of a write the port answered 202 (AD-26): <code>unchecked</code> with reason
/// <code>running</code>, and no re-read is made.</p>
ClassMethod Running() As %DynamicObject
{
    Quit ..Verdict(..#UNCHECKED, "", "", ..#REASONRUNNING)
}

/// <p>The kind of <var>pToolClass</var>'s write, derived from its own parameters:
/// <code>delete</code>, <code>create</code>, <code>merge</code>, <code>secret</code> or
/// <code>action</code>.</p>
ClassMethod KindOf(pToolClass As %String) As %String
{
    If ##class(OcuPilot.Kernel.Proposal.Operation).ChangeAction(pToolClass) = "deleted" Quit "delete"
    If ##class(OcuPilot.Kernel.Proposal.Mint).CreatesOf(pToolClass) Quit "create"
    If ##class(OcuPilot.Kernel.Proposal.Operation).SendsBody(pToolClass) Quit "merge"
    Set tSecrets = ""
    Try {
        Set tSecrets = $ClassMethod(pToolClass, "SecretBodyNames")
    } Catch {
        Set tSecrets = ""
    }
    If tSecrets '= "" Quit "secret"
    Quit "action"
}

/// <p>Whether <var>pToolClass</var>'s tool says its deleted target is gone although the re-read
/// <var>pAfter</var> answered (<method>OcuPilot.Screen.Tool.Write.ReadBackGone</method>). A class
/// that cannot be asked answers 0.</p>
ClassMethod Gone(pToolClass As %String, pAfter As %DynamicObject, pPayloadJson As %String) As %Boolean [ Private ]
{
    Set tGone = 0
    Try {
        Set tGone = ''$ClassMethod(pToolClass, "ReadBackGone", pAfter, ##class(OcuPilot.Kernel.Proposal.Operation).ParsedObject(pPayloadJson))
    } Catch {
        Set tGone = 0
    }
    Quit tGone
}

/// <p>The compared set of a merge or a create: every top-level key of <var>pSent</var> the tool's
/// field rows name, minus the descriptor's <code>fingerprintExcludes</code>. A differing name is
/// appended to <var>pFields</var>; a secret or <code>written</code> name whose sent value is
/// non-empty and differs from <var>pBefore</var>'s is appended to <var>pWritten</var> and never read
/// back.</p>
/// <p><var>pRowOnly</var> is 1 for a tool whose read is a list row (a declared row key): a sent name
/// that row does not answer at all is outside what the tool's read can see, and is not compared.</p>
/// <p>Answers 0 when there is nothing to compare against -- no sent object, or no field rows for the
/// tool -- so the caller reports <code>unchecked</code> rather than a <code>matches</code> over an
/// empty set.</p>
ClassMethod Compared(pToolClass As %String, pSent As %DynamicObject, pBefore As %DynamicObject, pRead As %DynamicObject, Output pFields As %List, Output pWritten As %List, pRowOnly As %Boolean = 0) As %Boolean [ Private ]
{
    Set pFields = ""
    Set pWritten = ""
    If '$IsObject(pSent) || 'pSent.%IsA("%Library.DynamicObject") Quit 0
    Set tToolName = $Parameter(pToolClass, "TOOLNAME")
    If '..Rows(tToolName, .tNamed, .tSecret, .tModes) Quit 0
    Set tDeclaredSecrets = ""
    Try {
        Set tDeclaredSecrets = $ClassMethod(pToolClass, "SecretArguments", "", .tDeclared)
    } Catch {
        Set tDeclaredSecrets = ""
    }
    Set tExcludes = ""
    Try {
        Set tDescriptor = $Parameter(pToolClass, "DESCRIPTORCLASS")
        If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
    } Catch {
        Set tExcludes = ""
    }
    Set tIterator = pSent.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tIsSecret = $Get(tSecret(tName), 0) || ($ListFind(tDeclaredSecrets, tName) > 0)
        If '$Data(tNamed(tName)) && 'tIsSecret Continue
        If $ListFind(tExcludes, tName) || $ListFind(tExcludes, tName _ "[]") Continue
        Set tMode = $Get(tModes(tName))
        If tIsSecret || (tMode = "written") {
            ; AD-35: the sent value is compared only with the value the caller already held before
            ; the write, and the re-read's value of this name is never looked at.
            Set tSentText = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pSent.%Get(tName), pSent.%GetTypeOf(tName))
            If tSentText = "" Continue
            If tSentText = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pBefore.%Get(tName), pBefore.%GetTypeOf(tName)) Continue
            Set pWritten = pWritten _ $ListBuild(tName)
            Continue
        }
        If pRowOnly && (pRead.%GetTypeOf(tName) = "unassigned") Continue
        If '..Compare(pSent, pRead, tName, tMode) Set pFields = pFields _ $ListBuild(tName)
    }
    Quit 1
}

/// <p>Whether member <var>pName</var> of the sent object <var>pSent</var> reads back as sent in
/// <var>pRead</var>, under the declared mode <var>pMode</var> (<code>""</code> for the default
/// rules). The helper the unit tests reach; it answers a boolean and nothing else.</p>
ClassMethod Compare(pSent As %DynamicObject, pRead As %DynamicObject, pName As %String, pMode As %String = "") As %Boolean
{
    Set tSentValue = ""
    Set tSentType = "unassigned"
    Set tReadValue = ""
    Set tReadType = "unassigned"
    If $IsObject(pSent) {
        Set tSentType = pSent.%GetTypeOf(pName)
        If tSentType '= "unassigned" Set tSentValue = pSent.%Get(pName)
    }
    If $IsObject(pRead) {
        Set tReadType = pRead.%GetTypeOf(pName)
        If tReadType '= "unassigned" Set tReadValue = pRead.%Get(pName)
    }
    Quit ..Same(tSentValue, tSentType, tReadValue, tReadType, pMode)
}

/// <p>Whether a sent value and a read value are equal under <var>pMode</var>. Each value is passed
/// with its JSON type as <code>%GetTypeOf</code> answers it.</p>
/// <p>The default rules, in order: both sides empty (<code>""</code>, <code>[]</code>,
/// <code>{}</code>, <code>null</code>, absent) are equal; where either side is a boolean,
/// truthiness is compared; where both are valid numbers, their values are; otherwise their
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> text, an array keeping its order.</p>
ClassMethod Same(pA As %RawString, pAType As %String, pB As %RawString, pBType As %String, pMode As %String = "") As %Boolean
{
    If pMode = "unordered" {
        Set tAArray = (pAType = "array")
        Set tBArray = (pBType = "array")
        If (tAArray || ..Empty(pA, pAType)) && (tBArray || ..Empty(pB, pBType)) && (tAArray || tBArray) {
            Quit ..SameMultiset($Select(tAArray: pA, 1: []), $Select(tBArray: pB, 1: []))
        }
    }
    If pMode = "members" {
        If pAType = "object" {
            Set tRead = $Select(pBType = "object": pB, 1: {})
            Set tSame = 1
            Set tIterator = pA.%GetIterator()
            While tIterator.%GetNext(.tMember, .tValue) {
                If '..Same(pA.%Get(tMember), pA.%GetTypeOf(tMember), tRead.%Get(tMember), tRead.%GetTypeOf(tMember)) {
                    Set tSame = 0
                    Quit
                }
            }
            Quit tSame
        }
    }
    If (pMode = "unslashed") || (pMode = "words") || (pMode = "letters") {
        If '$IsObject(pA) && '$IsObject(pB) && (pAType '= "boolean") && (pBType '= "boolean") {
            Set tA = ..Normalized($Select((pAType = "null") || (pAType = "unassigned"): "", 1: pA), pMode)
            Set tB = ..Normalized($Select((pBType = "null") || (pBType = "unassigned"): "", 1: pB), pMode)
            Quit (tA = tB)
        }
    }
    Quit ..SameByDefault(pA, pAType, pB, pBType)
}

/// <p>The default comparison <method>Same</method> documents.</p>
ClassMethod SameByDefault(pA As %RawString, pAType As %String, pB As %RawString, pBType As %String) As %Boolean [ Private ]
{
    Set tAEmpty = ..Empty(pA, pAType)
    Set tBEmpty = ..Empty(pB, pBType)
    If tAEmpty && tBEmpty Quit 1
    If (pAType = "boolean") || (pBType = "boolean") {
        Set tATruth = ..Truth(pA, pAType, .tAKnown)
        Set tBTruth = ..Truth(pB, pBType, .tBKnown)
        If tAKnown && tBKnown Quit (tATruth = tBTruth)
    }
    If ..IsNumber(pA, pAType) && ..IsNumber(pB, pBType) Quit (+pA = +pB)
    Quit (##class(OcuPilot.Kernel.Proposal.Mint).Display(pA, pAType) = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pB, pBType))
}

/// <p>Whether <var>pValue</var> is empty: <code>""</code>, <code>[]</code>, <code>{}</code>,
/// <code>null</code> or absent.</p>
ClassMethod Empty(pValue As %RawString, pType As %String) As %Boolean [ Private ]
{
    If (pType = "unassigned") || (pType = "null") Quit 1
    If pType = "string" Quit (pValue = "")
    If pType = "array" Quit (pValue.%Size() = 0)
    If pType = "object" {
        Set tIterator = pValue.%GetIterator()
        Quit 'tIterator.%GetNext(.tKey, .tMember)
    }
    Quit 0
}

/// <p>The truthiness of <var>pValue</var>, with <var>pKnown</var> 0 for a value that is neither:
/// <code>true</code>, <code>1</code>, <code>"1"</code> and <code>"true"</code> are true;
/// <code>false</code>, <code>0</code>, <code>"0"</code>, <code>"false"</code>, <code>""</code> and
/// absent are false.</p>
ClassMethod Truth(pValue As %RawString, pType As %String, Output pKnown As %Boolean) As %Boolean [ Private ]
{
    Set pKnown = 1
    If pType = "boolean" Quit ''pValue
    If (pType = "unassigned") || (pType = "null") Quit 0
    If (pType = "object") || (pType = "array") {
        Set pKnown = 0
        Quit 0
    }
    Set tText = $ZConvert(pValue, "L")
    If (tText = "1") || (tText = "true") Quit 1
    If (tText = "0") || (tText = "false") || (tText = "") Quit 0
    Set pKnown = 0
    Quit 0
}

/// <p>Whether <var>pValue</var> is a valid number: a JSON number, or a string
/// <code>$IsValidNum</code> accepts (<code>"0900"</code> reads back as <code>900</code>).</p>
ClassMethod IsNumber(pValue As %RawString, pType As %String) As %Boolean [ Private ]
{
    If pType = "number" Quit 1
    If pType '= "string" Quit 0
    If pValue = "" Quit 0
    Quit ''$IsValidNum(pValue)
}

/// <p><var>pValue</var> as a declared text mode compares it: one trailing <code>/</code> dropped
/// (<code>unslashed</code>), whitespace collapsed (<code>words</code>), or the sorted set of its
/// upper-cased letters (<code>letters</code>).</p>
ClassMethod Normalized(pValue As %String, pMode As %String) As %String [ Private ]
{
    If pMode = "unslashed" {
        If $Extract(pValue, *) = "/" Quit $Extract(pValue, 1, *-1)
        Quit pValue
    }
    If pMode = "words" Quit $ZStrip(pValue, "<=>W")
    If pMode = "letters" {
        Kill tSeen
        Set tUpper = $ZConvert(pValue, "U")
        For tI = 1:1:$Length(tUpper) {
            Set tChar = $Extract(tUpper, tI)
            If tChar?1U Set tSeen(tChar) = ""
        }
        Set tSet = ""
        Set tChar = ""
        For {
            Set tChar = $Order(tSeen(tChar))
            If tChar = "" Quit
            Set tSet = tSet _ tChar
        }
        Quit tSet
    }
    Quit pValue
}

/// <p>Whether two arrays hold the same elements as a multiset of their
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> text, whatever their order.</p>
ClassMethod SameMultiset(pA As %DynamicArray, pB As %DynamicArray) As %Boolean [ Private ]
{
    If pA.%Size() '= pB.%Size() Quit 0
    Kill tCount
    For tI = 0:1:pA.%Size() - 1 {
        Set tKey = ..MultisetKey(##class(OcuPilot.Kernel.Proposal.Mint).Display(pA.%Get(tI), pA.%GetTypeOf(tI)))
        Set tCount(tKey) = $Get(tCount(tKey)) + 1
    }
    For tI = 0:1:pB.%Size() - 1 {
        Set tKey = ..MultisetKey(##class(OcuPilot.Kernel.Proposal.Mint).Display(pB.%Get(tI), pB.%GetTypeOf(tI)))
        Set tCount(tKey) = $Get(tCount(tKey)) - 1
    }
    Set tSame = 1
    Set tKey = ""
    For {
        Set tKey = $Order(tCount(tKey))
        If tKey = "" Quit
        If tCount(tKey) '= 0 {
            Set tSame = 0
            Quit
        }
    }
    Quit tSame
}

/// <p>A local subscript for one element's text: the text itself, prefixed so an empty element is a
/// subscript, or its CRC and length where it is too long to be one.</p>
ClassMethod MultisetKey(pText As %String) As %String [ Private ]
{
    If $Length(pText) <= 200 Quit "v" _ pText
    Quit "h" _ $ZCRC(pText, 7) _ ":" _ $Length(pText)
}

/// <p>The top-level names <var>pToolName</var>'s field rows name, in <var>pNamed</var>; those any
/// of whose rows is classified <code>secret</code>, in <var>pSecret</var>; and each declared
/// comparison mode, in <var>pModes</var>. Answers 0 when the generated block cannot be read, and a
/// caller compares nothing then.</p>
ClassMethod Rows(pToolName As %String, Output pNamed, Output pSecret, Output pModes) As %Boolean
{
    Kill pNamed, pSecret, pModes
    If pToolName = "" Quit 0
    Set tRead = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#TOOLFIELDSCLASS, "Tools", , .tOpenSC)
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        If '$IsObject(tTools) Quit
        Set tEntry = tTools.%Get(pToolName)
        If '$IsObject(tEntry) || (tEntry.%GetTypeOf("fields") '= "array") Quit
        Set tIterator = tEntry.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$IsObject(tField) Continue
            Set tTop = ..TopName(tField.%Get("path"))
            If tTop = "" Continue
            Set pNamed(tTop) = 1
            If tField.%Get("class") = "secret" Set pSecret(tTop) = 1
            If tField.%Get("compare") '= "" Set pModes(tTop) = tField.%Get("compare")
        }
        Set tRead = 1
    } Catch {
        Kill pNamed, pSecret, pModes
        Set tRead = 0
    }
    Quit tRead
}

/// <p>The top-level name a field-row path sits under: <code>Resources[].Name</code> answers
/// <code>Resources</code>.</p>
ClassMethod TopName(pPath As %String) As %String [ Private ]
{
    Quit $Piece($Piece(pPath, ".", 1), "[", 1)
}

/// <p>The top-level names <var>pSent</var> carries, as a <class>%List</class>: a secret-only body's
/// names, which are its whole answer. No value is read.</p>
ClassMethod SentNames(pSent As %DynamicObject) As %List [ Private ]
{
    Set tNames = ""
    If '$IsObject(pSent) || 'pSent.%IsA("%Library.DynamicObject") Quit tNames
    Set tIterator = pSent.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tNames = tNames _ $ListBuild(tName)
    }
    Quit tNames
}

/// <p>The wire answer: <code>{verdict, fields, written}</code>, plus <code>reason</code> where
/// <var>pReason</var> is given. <var>pFields</var> and <var>pWritten</var> are
/// <class>%List</class>s of names.</p>
ClassMethod Verdict(pVerdict As %String, pFields As %List = "", pWritten As %List = "", pReason As %String = "") As %DynamicObject
{
    Set tAnswer = {}
    Do tAnswer.%Set("verdict", pVerdict, "string")
    Set tFields = []
    For tI = 1:1:$ListLength(pFields) {
        Do tFields.%Push($List(pFields, tI), "string")
    }
    Do tAnswer.%Set("fields", tFields)
    Set tWritten = []
    For tI = 1:1:$ListLength(pWritten) {
        Do tWritten.%Push($List(pWritten, tI), "string")
    }
    Do tAnswer.%Set("written", tWritten)
    If pReason '= "" Do tAnswer.%Set("reason", pReason, "string")
    Quit tAnswer
}

}
