# Defining and connecting operations

An **operation** is a reusable computation with named, typed inputs and outputs.
Its **definition** declares that interface and describes the computation. An
**invocation** uses the definition and supplies values for its inputs. Several
invocations can share a definition while supplying different values.

These schemas are unstable APIs. Motif makes no guarantees that the messages
will continue to be supported.

## Declarations and bindings

A **slot** is a named input or output carrying values of a declared type and
cardinality. Cardinality specifies how many values the slot carries. A
**declaration** describes a slot's contract. A **binding** connects a source of
values to a declared slot.

For example, an operation can declare a numeric input named `value`. Each
invocation binds that name to a literal number, another invocation's output, or
an input of the enclosing graph. The declaration stays on the definition, while
the binding varies per invocation.

The component messages work together as follows:

| Component | Where it belongs | Purpose |
| --- | --- | --- |
| [InputDeclarations](v1/input_declarations.proto) | Definition entity | Declares named inputs, their types, cardinalities, and optional defaults. |
| [OutputDeclarations](v1/output_declarations.proto) | Definition entity | Declares named outputs and their types and cardinalities. |
| [Script](v1/script.proto) | Script-backed definition entity | Selects the implementation that computes the declared outputs. |
| [InvokeOperation](v1/invoke_operation.proto) | Invocation entity | Selects a definition and binds its inputs. |
| [OutputBindings](v1/output_bindings.proto) | Direct Member children of a graph-backed definition | Connects internal values to the definition's declared outputs. |

A script-backed definition delegates computation to an implementation. A
**graph-backed definition** instead contains invocations and their connections.
Both expose the same declaration-based interface to their callers. A component
is a registered message attached to an entity; supporting messages such as a
binding or slot reference are fields within those components.

Input binding destinations match keys in the called definition's
`InputDeclarations.slots` map. Output binding destinations match keys in the
enclosing graph definition's `OutputDeclarations.slots` map. Slot names are
nonempty, case-sensitive, and at most 50 characters. Each input or output
declaration map may contain up to 250 slots, and each slot description may contain
up to 160 characters. Declaration map order has no argument or display ordering
meaning.

## Example: declare and invoke a numeric operation

Suppose a provider implements an operation that doubles a number. Its definition
entity carries the following three components. The implementation and UUIDs are
illustrative: a provider must register code for the selected implementation ID.
These textproto snippets are individual component payloads, not entity-creation
requests.

`motif.data.operation.v1.InputDeclarations`:

```textproto
slots {
  key: "value"
  value {
    description: "Number to double."
    slot_type {
      type_spec { kind: TYPE_DOUBLE cardinality: CARDINALITY_REQUIRED }
    }
  }
}
```

`motif.data.operation.v1.OutputDeclarations`:

```textproto
slots {
  key: "doubled"
  value {
    description: "Twice the supplied number."
    slot_type {
      type_spec { kind: TYPE_DOUBLE cardinality: CARDINALITY_REQUIRED }
    }
  }
}
```

`motif.data.operation.v1.Script`:

```textproto
native_implementation_id: "\100\000\000\000\000\000\100\000\200\000\000\000\000\000\000\001"
```

Give that definition entity UUID `10000000-0000-4000-8000-000000000001`.
To use it, create a separate invocation entity carrying the following component.
`definition.entity` selects the definition; `input_bindings` supplies the
invocation's data. UUIDs are written as their 16 bytes, using textproto escapes.

`motif.data.operation.v1.InvokeOperation`:

```textproto
definition {
  entity { entity_id: "\020\000\000\000\000\000\100\000\200\000\000\000\000\000\000\001" }
}
input_bindings {
  input_name: "value"
  literal { members { scalar_value { double_value: 3.0 } } }
}
```

The implementation receives `3.0` as `value` and produces `6.0` as `doubled`.
Give the invocation entity UUID `20000000-0000-4000-8000-000000000001`. Another
invocation can consume that result by using the following record in its
`input_bindings`, provided its definition declares a compatible input named `value`.

`motif.data.operation.v1.InputBinding`:

```textproto
input_name: "value"
output {
  invocation { entity_id: "\040\000\000\000\000\000\100\000\200\000\000\000\000\000\000\001" }
  output_name: "doubled"
}
```

Here, `input_name` identifies the destination slot; `output_name` identifies the
source slot on the referenced invocation. An [OutputSlotReference](v1/output_slot_reference.proto) always
selects a whole output slot, including all members when its cardinality is MANY.

## Define a graph-backed operation

A graph-backed definition carries its own input and output declarations. Its
contained invocations bind to one another's outputs to form the computation.
Callers use this definition through InvokeOperation, just as in the previous
example.

To forward an enclosing graph's input to an internal invocation, use an
[InputSlotReference](v1/input_slot_reference.proto). For example, a graph with
UUID `30000000-0000-4000-8000-000000000001` can declare an input named `value` and
contain the doubling invocation above. Replace that invocation's literal
binding with:

`motif.data.operation.v1.InputBinding`:

```textproto
input_name: "value"
input {
  entity { entity_id: "\060\000\000\000\000\000\100\000\200\000\000\000\000\000\000\001" }
  input_name: "value"
}
```

The source entity is the immediately enclosing graph definition, not the
called doubling definition. The reference must match the Member containment
hierarchy exactly; a mismatch is a validation error. Member expresses ownership,
containment, and deletion. Explicit slot references express data dependencies.
When evaluating this graph as an invocation, the source resolves through that
caller's bindings and declaration defaults. Standalone evaluation resolves its
input declarations and defaults without needing a caller.

To expose the internal result as the enclosing graph's declared `doubled` output,
place this component on a direct Member child of the graph definition:

`motif.data.operation.v1.OutputBindings`:

```textproto
bindings {
  output_name: "doubled"
  output {
    invocation { entity_id: "\040\000\000\000\000\000\100\000\200\000\000\000\000\000\000\001" }
    output_name: "doubled"
  }
}
```

This is the other side of the output declaration: the declaration promises a
result, and the binding identifies which internal value fulfills it. Script
implementations instead produce results under the declared output names.

A graph may have one or many OutputBindings components, and each component may
bind several output slots. Each declared slot has exactly one owning component,
including MANY slots. Contributions to the same MANY slot must all be in that
component's ordered binding list; separate components cannot share the slot.
Exposing an output defines a caller-facing result, not where that result is
stored as model data.

## Slot types and cardinality

[SlotType](v1/slot_type.proto) uses `motif.extension.v1.TypeSpec` to declare a
protobuf scalar kind or a registered message name, plus cardinality:

| TypeSpec cardinality | Slot meaning | Permitted member count |
| --- | --- | --- |
| `CARDINALITY_REQUIRED` | ONE | Exactly one |
| `CARDINALITY_OPTIONAL` | ZERO_OR_ONE | Zero or one |
| `CARDINALITY_REPEATED` | MANY | Zero or more |

For a message, set `kind` to `TYPE_MESSAGE` and `type_name` to the exact fully
qualified name, such as `motif.operations.values.v1.NamedValues`, without a
leading dot. A scalar uses its protobuf kind and leaves `type_name` empty.
Standalone enum, group, and unknown kinds are invalid slot types; messages may
contain enum fields.

Equal element types can connect with equal cardinalities. ONE can widen to
ZERO_OR_ONE or MANY; ZERO_OR_ONE can widen to MANY. Widening preserves member
order and treats successful absence as zero members. It does not flatten
repeated fields inside a message. A concrete message may widen to an `Any` slot
while retaining its actual message identity. Narrowing, dynamic extraction,
and numeric conversions require explicit operations.

## Literal values, defaults, and ordering

A [SlotLiteral](v1/slot_literal.proto) contains up to 1,000 ordered
[Value](../values/v1/value.proto) members. Each member is a scalar with an
explicit primitive kind or a message encoded as `google.protobuf.Any`. A message
uses its registered fully qualified name as logical identity; the `type_url`
prefix is transport metadata.

ONE and ZERO_OR_ONE accept at most one binding record per destination. MANY
accepts multiple records, concatenating sources in binding-list order and
preserving each source's member order. Declaration map order does not affect
this sequence. The same ordering rule applies to input and output bindings.

If no binding targets an input, use its declared default. If there is neither a
binding nor a default, report a missing input. A present `literal {}` explicitly
supplies zero members and suppresses the default. This is valid for ZERO_OR_ONE
and MANY, but invalid for ONE. Defaults can themselves contain MANY members;
they are never appended to bound sources. Bindings to names no longer declared
after a definition upgrade are retained and ignored.

## Definition scope and validation

An invocation's `definition.entity` is live in the owning model when
`definition.model` is absent. Setting `definition.model` pins the definition to
that external model version. Omitting `definition.entity` then selects the whole
model definition. This model scope applies only to the definition target;
references in input bindings keep their own scope.

Field validation checks local constraints such as required sources and nonempty
names. Graph validation must also resolve definitions and references, check slot
compatibility, enforce enclosing-input and output-owner rules, and detect cycles.
Execution still validates actual result types and member counts: a declaration
states a contract rather than proving that an implementation fulfills it.
