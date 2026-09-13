/// <p>The closed archetype vocabulary: every key <file>EXPERIENCE.md</file> `:507-521` publishes
/// as a state-matrix row, plus the two its prose names alongside the table (<code>shell</code>,
/// whose states live in the Shell and Session tables, and <code>external</code>, which opens a
/// new tab and has none) -- each classified by whether a screen of that archetype may link out
/// to the classic portal (AD-44).</p>
/// <p><b>Why the vocabulary is closed at all.</b> AD-44's rule is "a list archetype never
/// carries an outbound classic link; a detail view may". Until this class existed
/// <code>archetype</code> was free text that <method>OcuPilot.Screen.Registry.Validate</method>,
/// <file>ui/tools/screen-mirror.mjs</file> and <file>scripts/check-objectscript.py</file> all
/// ignored, so the rule's predicate had nothing to evaluate: a typo would answer "not a detail
/// view" and pass. Closing the vocabulary is what turns the rule into a refusal.</p>
/// <p><b>Three link-out classes, and the default is refusal.</b> <code>list</code> and
/// <code>none</code> may never declare an exemption; only <code>detail</code> may. An archetype
/// the vocabulary does not hold is refused outright, so a mis-classification refuses a link
/// rather than permitting one.</p>
/// <p><b>How the sixteen keys were classified.</b> The three list shapes and the two that are
/// lists of rows under another name -- <code>list</code>, <code>list (two views)</code>,
/// <code>list (server criteria)</code>, <code>log-viewer</code>, <code>drill-down</code> -- are
/// <code>list</code>. The four entity-at-a-time shapes -- <code>detail</code>,
/// <code>form-page</code>, <code>form-page (tabs)</code>, <code>wizard</code> -- are
/// <code>detail</code>: a reduced form is a form-page (<file>EXPERIENCE.md</file> `:409`) and
/// <file>epics.md</file> `:3325` declares the OAuth 2.0 tabs detail views rather than lists.
/// Everything else -- <code>meters</code>, <code>viewer (OpenAPI)</code>, <code>dialog</code>,
/// <code>home</code>, <code>panel</code>, <code>shell</code>, <code>external</code> -- is
/// <code>none</code>: none of them is a form a reduced form could end, and
/// <code>external</code> is already a link out rather than a screen that carries one.</p>
/// <p><b>One declaration, three readers.</b> This class reads the block through
/// <class>%Dictionary.XDataDefinition</class>; <file>ui/tools/classic-links.mjs</file> and
/// <file>ui/tools/screen-mirror.mjs</file> read the same block off disk. A vocabulary that
/// cannot be read is never treated as an empty set -- an empty set would make every declared
/// archetype unknown and an absent check would make every declared archetype fine, and neither
/// is a negative result (<file>scripts/check-objectscript.py</file> `:663-668` states the
/// rule).</p>
/// <p><b>The two sides report it differently, and a caller should know which it is reading.</b>
/// The build readers <b>name the file</b>: <method>parseArchetypes</method> answers
/// <code>null</code> rather than an empty array, and both callers refuse with the path in the
/// message. The methods below instead <b>fail closed</b>: <method>Find</method> answers
/// <code>""</code> for an unreadable block exactly as it does for an undeclared key, so
/// <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method> refuses the descriptor with
/// "archetype ... is not one OcuPilot.Screen.Archetype declares" rather than with the read
/// failure. The verdict is right and safe either way; the attribution is not, so
/// <method>Declaration</method> and <method>List</method> return the real <class>%Status</class>
/// for a caller that wants it.</p>
Class OcuPilot.Screen.Archetype Extends %RegisteredObject
{

/// <p>The link-out class of an archetype whose screens are rows: never an outbound classic
/// link (AD-44).</p>
Parameter LINKOUTLIST = "list";

/// <p>The link-out class of an archetype that shows one entity: may declare a
/// <code>classicLinkExemption</code>, and is the only class that may.</p>
Parameter LINKOUTDETAIL = "detail";

/// <p>The link-out class of an archetype that is neither: never an outbound classic link.</p>
Parameter LINKOUTNONE = "none";

/// <p>The one declaration. Read here on the server and off disk by
/// <file>ui/tools/classic-links.mjs</file> and <file>ui/tools/screen-mirror.mjs</file>, so the
/// refusal the build makes and the refusal install makes come from the same sixteen lines.</p>
XData Archetypes
{
{"archetypes":[
  {"key":"list","linkOut":"list"},
  {"key":"list (two views)","linkOut":"list"},
  {"key":"list (server criteria)","linkOut":"list"},
  {"key":"log-viewer","linkOut":"list"},
  {"key":"drill-down","linkOut":"list"},
  {"key":"detail","linkOut":"detail"},
  {"key":"form-page","linkOut":"detail"},
  {"key":"form-page (tabs)","linkOut":"detail"},
  {"key":"wizard","linkOut":"detail"},
  {"key":"meters","linkOut":"none"},
  {"key":"viewer (OpenAPI)","linkOut":"none"},
  {"key":"dialog","linkOut":"none"},
  {"key":"home","linkOut":"none"},
  {"key":"panel","linkOut":"none"},
  {"key":"shell","linkOut":"none"},
  {"key":"external","linkOut":"none"}
]}
}

/// <p>The declaration as a <class>%DynamicObject</class>. Re-read on every call rather than
/// cached, for the reason <class>OcuPilot.Screen.Area</class> records: a cached copy is a
/// second source of truth that a recompile does not reach.</p>
ClassMethod Declaration(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Archetypes", , .tOpenSC)
        If '$IsObject(tXData) {
            ; The open status says what actually went wrong -- an uncompiled class, a privilege
            ; fault -- and reporting every one of them as "missing" would read a failed lookup
            ; as a negative result. It is only replaced when the open reported no error at all.
            Set tSC = $Get(tOpenSC, $$$OK)
            If $$$ISOK(tSC) {
                Set tSC = $$$ERROR($$$GeneralError, "the archetype declaration XData is missing from " _ $ClassName())
            }
            Quit
        }
        Do tXData.Data.Rewind()
        Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared archetypes as a <class>%DynamicArray</class>, in declaration order.</p>
ClassMethod List(Output pArchetypes As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pArchetypes = ""
    Try {
        Set tSC = ..Declaration(.tObject)
        If $$$ISERR(tSC) Quit
        Set pArchetypes = tObject.archetypes
        If '$IsObject(pArchetypes) {
            Set pArchetypes = ""
            Set tSC = $$$ERROR($$$GeneralError, "the archetype declaration in " _ $ClassName() _ " carries no archetypes array")
        }
    } Catch ex {
        Set pArchetypes = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared archetype whose <code>key</code> is <var>pKey</var>, or an empty string when
/// there is none.</p>
ClassMethod Find(pKey As %String) As %DynamicObject
{
    Set tFound = ""
    Try {
        Set tSC = ..List(.tArchetypes)
        If $$$ISERR(tSC) Quit
        Set tIterator = tArchetypes.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArchetype) {
            If tArchetype.key = pKey {
                Set tFound = tArchetype
                Quit
            }
        }
    } Catch {
        Set tFound = ""
    }
    Quit tFound
}

/// <p>Whether <var>pKey</var> names a declared archetype. A descriptor naming one that is not
/// here is refused by <class>OcuPilot.Screen.Registry</class> and by
/// <file>ui/tools/classic-links.mjs</file>.</p>
ClassMethod Exists(pKey As %String) As %Boolean
{
    Quit $IsObject(..Find(pKey))
}

/// <p><var>pKey</var>'s link-out class -- <parameter>LINKOUTLIST</parameter>,
/// <parameter>LINKOUTDETAIL</parameter> or <parameter>LINKOUTNONE</parameter> -- and
/// <code>""</code> for an archetype the vocabulary does not declare.</p>
/// <p><b><code>""</code> is not a permission.</b> Every caller compares this against
/// <parameter>LINKOUTDETAIL</parameter> to decide whether an exemption may stand, so an
/// unknown archetype fails closed; the caller still has to refuse it explicitly, because
/// "may not link out" and "is not an archetype" are different faults to report.</p>
ClassMethod LinkOutClass(pKey As %String) As %String
{
    Set tArchetype = ..Find(pKey)
    If '$IsObject(tArchetype) Quit ""
    Quit tArchetype.linkOut
}

/// <p>Whether a screen of archetype <var>pKey</var> may declare a
/// <code>classicLinkExemption</code> (AD-44). Only <parameter>LINKOUTDETAIL</parameter>
/// may.</p>
ClassMethod MayLinkOut(pKey As %String) As %Boolean
{
    Quit ..LinkOutClass(pKey) = ..#LINKOUTDETAIL
}

/// <p>How many archetypes the vocabulary declares. Pinned to a literal by
/// <class>OcuPilot.Test.Descriptor</class>, so a key dropped from the block is noticed.</p>
ClassMethod Count() As %Integer
{
    Set tCount = 0
    Try {
        Set tSC = ..List(.tArchetypes)
        If $$$ISERR(tSC) Quit
        Set tCount = tArchetypes.%Size()
    } Catch {
        Set tCount = 0
    }
    Quit tCount
}

}
