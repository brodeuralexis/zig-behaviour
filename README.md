# Behaviour

A new, *experimental* approach at duck typing in Zig.

## Warning

This is highly experimental, and is published only to show what is possible
and how the API would look like.

It is not tested enough to my liking, and the API should be further elaborated.

## Goal

To make it into the Zig standard library.

## Usage

Declare a behaviour struct.

```zig
pub fn Indexable(comptime Self: type) type {
    return struct {
        pub const Index = type;
        pub const Result = type;

        pub const index = fn(Self, Self.Index) Self.Result;
    };
}
```

Implement the behaviour

```zig
fn BadSliceWrapper(comptime T: type) type {
    return struct {
        pub const Index = u32;
        pub const Result = u32;

        pub fn index(self: @This(), index: Index) Result {
            // ...
        }
    };
}
```

Check for behaviour

```zig
fn withCompileError(xs: anytype) void {
    const XS = @TypeOf(xs);

    // The returned value is the first argument, the validated type.
    _ = behaviour(XS, Indexable(XS));

    var valueAt42 = xs.index(42);
}

fn withConstIf(xs: anytype) void {
    const XS = @TypeOf(xs);

    if (hasBehaviour(XS, Indexable(XS))) {
        var valueAt42 = xs.index(42);
    }
}
```
