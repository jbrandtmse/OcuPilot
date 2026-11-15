/// <p>The document-hash body (AD-23): a SHA-256 content hash and the last-modified time of each class,
/// routine and include file whose name matches a spec. A harvested handler body, called only through
/// <class>OcuPilot.Port.HarvestPort</class>.</p>
/// <p>The documents are listed with the <code>%RoutineMgr:StudioOpenDialog</code> query, whose own
/// <code>Date</code> column gives the time, so no document is opened twice. The digest is
/// <code>$System.Encryption.SHAHash(256, text)</code> written in hex with
/// <code>$System.Encryption.ToHex</code>; <code>SHAHash</code> answers raw bytes.</p>
Class OcuPilot.Port.Harvest.EnvSync Extends OcuPilot.Port.Harvest.Handler
{

/// <p>Answer the hashes of the documents a spec names, as <code>{documents: [{name, hash, timestamp}],
/// count}</code>. The query keys, or the JSON body's members for a POST, are <code>spec</code>, required
/// (comma-separated names with <code>*</code> and <code>?</code> wildcards), <code>namespace</code>
/// (default the current one), <code>allowWide</code> (0, 1, true or false; default 0), which admits a spec
/// part that is a bare <code>*</code>, and <code>includeGenerated</code> (default 0). Every matching
/// document is read and hashed; the answer has no cap.</p>
ClassMethod DocHashes() As %Status
{
    Set tSC = $$$OK
    Set tResult = ""
    Set tOrigNS = $NAMESPACE
    Set tErrored = 0
    Try {
        ; ---- Parse params from %request (GET query or POST body) BEFORE any namespace switch ----
        Set tSpec = "", tNamespace = "", tAllowWideRaw = "", tIncludeGeneratedRaw = ""
        If (%request.Method = "POST") {
            Set tSC1 = ..ReadRequestBody(.tBody)
            If $$$ISERR(tSC1) {
                Set tErrored = 1
                Set tCmdStatus = tSC1
                Quit
            }
            If $IsObject(tBody) {
                If tBody.%IsDefined("spec") Set tSpec = tBody.%Get("spec")
                If tBody.%IsDefined("namespace") Set tNamespace = tBody.%Get("namespace")
                If tBody.%IsDefined("allowWide") Set tAllowWideRaw = tBody.%Get("allowWide")
                If tBody.%IsDefined("includeGenerated") Set tIncludeGeneratedRaw = tBody.%Get("includeGenerated")
            }
        } Else {
            Set tSpec = $Get(%request.Data("spec",1))
            Set tNamespace = $Get(%request.Data("namespace",1))
            Set tAllowWideRaw = $Get(%request.Data("allowWide",1))
            Set tIncludeGeneratedRaw = $Get(%request.Data("includeGenerated",1))
        }

        Set tAllowWide = ..CoerceBoolean(tAllowWideRaw)
        Set tIncludeGenerated = ..CoerceBoolean(tIncludeGeneratedRaw)

        ; switch to the target namespace (explicit save/restore — Rule #7)
        If tNamespace '= "" {
            Set tSC2 = ..SwitchNamespace(tNamespace, .tOrigNS)
            If $$$ISERR(tSC2) {
                Set tErrored = 1
                Set tCmdStatus = tSC2
                Quit
            }
        }

        Set tSC3 = ..ComputeHashes(tSpec, tAllowWide, tIncludeGenerated, .tResult)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC3) {
            Set tErrored = 1
            Set tCmdStatus = tSC3
            Quit
        }
        Quit
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tErrored = 1
        Set tCmdStatus = ex.AsStatus()
    }

    If tErrored {
        Do ..RenderResponseBody(..SanitizeError(tCmdStatus))
    } Else {
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Quit tSC
}

/// <p>Whether <var>pRaw</var> reads as true: <code>1</code> or <code>true</code>, in any case. Anything
/// else is false, so an unrecognized value never admits a wide scan.</p>
ClassMethod CoerceBoolean(pRaw As %String) As %Boolean
{
    Set tLower = $ZConvert(pRaw, "L")
    Quit ((tLower = "1") || (tLower = "true"))
}

/// <p>Refuse a spec any comma-separated part of which is a bare <code>*</code>, unless
/// <var>pAllowWide</var>: that spec reads the whole namespace. Separate from
/// <method>ComputeHashes</method> so the decision can be tested without a scan.</p>
ClassMethod CheckWideSpec(pSpec As %String, pAllowWide As %Boolean = 0) As %Status
{
    Set tIsWide = 0
    For tI = 1:1:$Length(pSpec, ",") {
        If $ZStrip($Piece(pSpec, ",", tI), "<>W") = "*" Set tIsWide = 1
    }
    If tIsWide && 'pAllowWide {
        Quit $$$ERROR($$$GeneralError, "spec '"_pSpec_"' scans the whole namespace; pass allowWide:true to override. A large namespace may hit the ~60s Web Gateway timeout -- prefer a package-scoped spec.")
    }
    Quit $$$OK
}

/// <p>Validate <var>pSpec</var>, apply <method>CheckWideSpec</method>, list and hash the matching
/// documents in the current namespace; the caller has switched to the target. <var>pResult</var> is the
/// answer <method>DocHashes</method> renders.</p>
ClassMethod ComputeHashes(pSpec As %String, pAllowWide As %Boolean = 0, pIncludeGenerated As %Boolean = 0, Output pResult As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tSpec = $ZStrip(pSpec, "<>W")
        Set tSC = ..ValidateRequired(tSpec, "spec")
        If $$$ISERR(tSC) Quit

        ; Rule #38: reject a wide/whole-namespace spec unless allowWide — an output
        ; cap is NOT a scan cap; the caller controls scan cost via spec, not a
        ; post-hoc limit. Split into CheckWideSpec (below) so the refusal/permit
        ; GATE is unit-testable without ever running the (potentially large) scan.
        Set tSC = ..CheckWideSpec(tSpec, pAllowWide)
        If $$$ISERR(tSC) Quit

        Set tSC = ..EnumerateDocsWithDate(tSpec, pIncludeGenerated, .tNames, .tDates)
        If $$$ISERR(tSC) Quit

        Set tDocs = []
        Set tCount = +$Get(tNames)
        For tI = 1:1:tCount {
            Set tName = tNames(tI)
            Set tHashHex = ""
            Set tSC = ..HashDoc(tName, .tHashHex)
            If $$$ISERR(tSC) Quit
            Set tEntry = {}
            Do tEntry.%Set("name", tName)
            Do tEntry.%Set("hash", tHashHex)
            Do tEntry.%Set("timestamp", $Get(tDates(tI)))
            Do tDocs.%Push(tEntry)
        }
        If $$$ISERR(tSC) Quit

        Set pResult = {}
        Do pResult.%Set("documents", tDocs)
        Do pResult.%Set("count", tDocs.%Size(), "number")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>List the documents in the current namespace that match <var>pSpec</var>, restricted to classes,
/// routines, generated routines and include files, with each one's last-modified time from the same
/// query. <var>pNames</var> is the count with the names at <code>pNames(1..n)</code>; <var>pDates</var>
/// holds the times at the same subscripts.</p>
ClassMethod EnumerateDocsWithDate(pSpec As %String, pIncludeGenerated As %Boolean = 0, Output pNames, Output pDates) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill pNames
        Kill pDates
        Set pNames = 0
        Set tRS = ##class(%ResultSet).%New("%RoutineMgr:StudioOpenDialog")
        Set tSC = tRS.Execute(pSpec, 1, 1, 0, 1, 0, +pIncludeGenerated)
        If $$$ISERR(tSC) Quit
        Set tSCNext = $$$OK
        While tRS.Next(.tSCNext) {
            Set tName = tRS.Get("Name")
            Set tExt = $ZConvert($Piece(tName, ".", *), "L")
            If (tExt '= "cls") && (tExt '= "mac") && (tExt '= "int") && (tExt '= "inc") Continue
            Set pNames = pNames + 1
            Set pNames(pNames) = tName
            Set pDates(pNames) = tRS.Get("Date")
        }
        If $$$ISERR(tSCNext) Set tSC = tSCNext
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The SHA-256 of one document's text, in hex: the lines <method>OcuPilot.Kernel.Utils.DocumentLines</method>
/// answers, each followed by a line feed, so a storage section's change counts as a change. The line
/// count is at <code>pLines(0)</code>.</p>
ClassMethod HashDoc(pDocName As %String, Output pHashHex As %String) As %Status
{
    Set tSC = $$$OK
    Set pHashHex = ""
    Try {
        Set tSC = ..DocumentLines(pDocName, .tLines)
        If $$$ISERR(tSC) Quit
        Set tText = ""
        ; the line COUNT lives at tLines(0), NOT the bare/unsubscripted node
        ; (confirmed against the line classifier's identical
        ; `+$Get(pLines(0))` read of the same GetTextAsArray output shape).
        Set tCount = +$Get(tLines(0))
        For tI = 1:1:tCount {
            Set tText = tText _ $Get(tLines(tI)) _ $Char(10)
        }
        Set tRawHash = $SYSTEM.Encryption.SHAHash(256, tText)
        Set pHashHex = $SYSTEM.Encryption.ToHex(tRawHash)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
