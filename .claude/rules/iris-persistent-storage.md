# `%Persistent` Storage — List Property Projection

List properties on a `%Persistent` class must project to a **subtable**, or be remodeled as a
**relationship**. The IRIS default projection is the wrong default for production code.

```objectscript
Class MyApp.Example.Parent Extends %Persistent
{
    ; WRONG as written — without explicit projection IRIS stores this as a single
    ; $LISTBUILD column on the parent's row, and members are not SQL-queryable.
    Property Children As list Of %String;
}
```

## Why

The default collapses the list into one `$LISTBUILD`-encoded column on the parent row:

1. **No SQL access to members.** Aggregating, filtering or joining on list contents means
   parsing the encoded blob client-side.
2. **Object identity is lost** for `list Of <persistent-class>`. Referenced objects are
   serialized into the parent's row and read back as new transient instances — the same trap
   behind `<INVALID OREF>` errors described in
   [objectscript-basics.md](objectscript-basics.md).
3. **Schema evolution is rigid.** Adding a property to the element type rewrites every parent
   row; a subtable isolates element evolution to the child table.

## How to project

- **`list Of <datatype>`** (`list Of %String`, `list Of %Integer`): use the storage-projection
  mechanism IRIS provides for list subtables. Verify the exact syntax against the docs for the
  running IRIS version — it has changed across releases.
- **`list Of <persistent-class>`**: prefer remodeling as a parent-child **relationship**.
  Relationships are first-class, give each child its own row, and preserve identity:

  ```objectscript
  Relationship Children As MyApp.Example.Child [ Cardinality = many, Inverse = Parent ];
  ```

Either way the result must be: one SQL row per element, independently queryable and joinable,
with object identity intact for object-typed elements.

Projection is configured through property keywords and parameters. **Do not hand-edit the
Storage XData** — it is compiler-managed.

## Documented exception

Embedded-serial projection is acceptable when the list is opaque — a verbatim payload captured
for audit replay, never queried by member, required to round-trip byte-for-byte. Document it at
the property so the next reader does not "fix" it:

```objectscript
/// Stored as embedded $LIST deliberately: the payload is opaque, never queried
/// by member, and must round-trip byte-for-byte for audit fidelity.
Property CapturedSlots As list Of %String;
```

An embedded-serial list with no such comment is a review flag.

## When unsure

1. Will anything need to query, filter, aggregate or join on individual members from SQL,
   now or plausibly later? → subtable / relationship.
2. Does the list hold `%Persistent` objects whose identity must survive a round trip? →
   relationship.
3. Is the collection an opaque, documented payload? → embedded serial is fine.
4. Otherwise → subtable / relationship.

## Storage Definition

Do not include storage default definitions in the %Persistent classes.  They are added by the compiler.
