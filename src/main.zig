const std = @import("std");
const testing = std.testing;
const builtin = std.builtin;

pub inline fn hasBehaviour(comptime Type: type, comptime Behaviour: type) bool {
    return doHasBehaviour(Type, Behaviour);
}

fn doHasBehaviour(comptime Type: type, comptime Behaviour: type) bool {
    const type_info = @typeInfo(Type);
    const behaviour_info = @typeInfo(Behaviour);

    return switch (behaviour_info) {
        // If `Behaviour` is simply `type`, accept any type.
        .Type => true,

        // If the behaviour is a primitive, expected that type to also be the
        // same primitive.
        .Bool,
        .ComptimeInt,
        .ComptimeFloat => Type == Behaviour,
        // Except integers and floats, which also accept their compile time
        // variants.
        .Int => Type == Behaviour or Type == comptime_int,
        .Float => Type == Behaviour or Type == comptime_int or Type == comptime_float,

        // If the behaviour is a function, then the type must be the same.
        .Fn => Type == Behaviour,

        // If `Behaviour` is an enum, ensure that the subset of the specified
        // fields are supported only.
        .Enum => |behaviour_enum_info| enum_blk: {
            if (type_info == .Enum) {
                const type_enum_info = type_info.Enum;

                inline for (behaviour_enum_info.fields) |behaviour_field| {
                    comptime var missing = true;

                    inline for (type_enum_info.fields) |type_field| {
                        if (comptime std.mem.eql(u8, behaviour_field.name, type_field.name)) {
                            missing = false;
                        }
                    }

                    if (missing) {
                        break :enum_blk false;
                    }
                }

                break :enum_blk true;
            }

            break :enum_blk false;
        },

        // Errors basically have the same behaviour as enums.  If the behaviour
        // is a subset of the error set, everything's good.
        .ErrorSet => |behaviour_error_info| error_blk: {
            if (type_info == .Error) {
                const type_error_info = type_info.Error;

                inline for (behaviour_error_info.?) |behaviour_error| {
                    comptime var missing = true;

                    inline for (type_error_info.?) |type_error| {
                        if (comptime std.mem.eql(u8, behaviour_error.name, type_error.name)) {
                            missing = false;
                        }
                    }

                    if (missing) {
                        break :error_blk false;
                    }
                }

                break :error_blk true;
            }

            break :error_blk false;
        },

        //
        .Struct => |behaviour_struct_info| struct_blk: {
            if (behaviour_struct_info.is_tuple) {
                inline for (behaviour_struct_info.fields) |behaviour_field| {
                    if (!hasBehaviour(Type, behaviour_field.field_type)) {
                        break :struct_blk false;
                    }
                }
            }

            inline for (behaviour_struct_info.decls) |behaviour_decl_info| {
                switch (behaviour_decl_info.data) {
                    .Type, .Var => |behaviour_decl_type| {
                        // If the type does not have a declaration, it is not valid.
                        if (!@hasDecl(Type, behaviour_decl_info.name)) {
                            break :struct_blk false;
                        }

                        const type_decl_info = std.meta.declarationInfo(Type, behaviour_decl_info.name);
                        const type_decl_type = switch (type_decl_info.data) {
                            .Type, .Var => |t| t,
                            .Fn => |f| f.fn_type,
                        };

                        if (!doHasBehaviour(type_decl_type, behaviour_decl_type)) {
                            break :struct_blk false;
                        }
                    },
                    // Ignore function declarations.
                    .Fn => {},
                }
            }

            break :struct_blk true;
        },

        // .Pointer => |type_pointer_info|
        //     if (behaviour_info.Pointer) |behaviour_pointer_info| {

        //     else

        else => @compileError(@typeName(Behaviour) ++ " is not a supported behaviour"),
    };
}

pub fn behaviour(comptime Type: type, comptime Behaviour: type) type {
    doBehaviour(Type, Behaviour, @typeName(Type));
    return Type;
}

fn doBehaviour(comptime Type: type, comptime Behaviour: type, comptime type_path: []const u8) void {
    const type_info = @typeInfo(Type);
    const behaviour_info = @typeInfo(Behaviour);

    switch (behaviour_info) {
        // If `Behaviour` is simply `type`, accept any type.
        .Type => return,

        // If the behaviour is a primitive, expected that type to also be the
        // same primitive.
        .Bool,
        .ComptimeInt,
        .ComptimeFloat => if (Type != Behaviour) {
            @compileError("`" ++ @typeName(Type) ++ "` is not compatible with `" ++ @typeName(Behaviour) ++ "` in `" ++ type_path ++ "`");
        },
        // Except integers and floats, which also accept their compile time
        // variants.
        .Int => if (Type != Behaviour and Type != comptime_int) {
            @compileError("`" ++ @typeName(Type) ++ "` is not compatible with `" ++ @typeName(Behaviour) ++ "` in `" ++ type_path ++ "`");
        },
        .Float => if (Type != Behaviour and Type != comptime_int and Type != comptime_float) {
            @compileError("`" ++ @typeName(Type) ++ "` is not compatible with `" ++ @typeName(Behaviour) ++ "` in `" ++ type_path ++ "`");
        },

        // If the behaviour is a function, then the type must be the same.
        .Fn => if (Type != Behaviour) {
            if (comptime std.mem.eql(u8, type_path, @typeName(Type))) {
                @compileError("`" ++ @typeName(Type) ++ "` is not compatible with `" ++ @typeName(Behaviour) ++ "`");
            } else {
                @compileError("`" ++ @typeName(Type) ++ "` is not compatible with `" ++ @typeName(Behaviour) ++ "` in `" ++ type_path ++ "`");
            }
        },

        // If `Behaviour` is an enum, ensure that the subset of the specified
        // fields are supported only.
        .Enum => |behaviour_enum_info| enum_blk: {
            if (type_info == .Enum) {
                const type_enum_info = type_info.Enum;

                inline for (behaviour_enum_info.fields) |behaviour_field| {
                    comptime var missing = true;

                    inline for (type_enum_info.fields) |type_field| {
                        if (comptime std.mem.eql(u8, behaviour_field.name, type_field.name)) {
                            missing = false;
                        }
                    }

                    if (missing) {
                        @compileError("Missing enum field `" ++ behaviour_field.name ++ "` in `" ++ type_path ++ "`");
                    }
                }

                break :enum_blk;
            }

            @compileError("Expected an enum in `" ++ type_path ++ "`");
        },

        // Errors basically have the same behaviour as enums.  If the behaviour
        // is a subset of the error set, everything's good.
        .ErrorSet => |behaviour_error_info| error_blk: {
            if (type_info == .Error) {
                const type_error_info = type_info.Error;

                inline for (behaviour_error_info.?) |behaviour_error| {
                    comptime var missing = true;

                    inline for (type_error_info.?) |type_error| {
                        if (comptime std.mem.eql(u8, behaviour_error.name, type_error.name)) {
                            missing = false;
                        }
                    }

                    if (missing) {
                        @compileError("Expected an error `" ++ behaviour_field.name ++ "` in `" ++ type_path ++ "`");
                    }
                }

                break :error_blk;
            }

            @compileError("Expected an error set in `" ++ type_path ++ "`");
        },

        //
        .Struct => |behaviour_struct_info| {
            if (behaviour_struct_info.is_tuple) {
                inline for (behaviour_struct_info.fields) |behaviour_field| {
                    doBehaviour(Type, behaviour_field.field_type, type_path);
                }
            }

            inline for (behaviour_struct_info.decls) |behaviour_decl_info| {
                switch (behaviour_decl_info.data) {
                    .Type, .Var => |behaviour_decl_type| {
                        // If the type does not have a declaration, it is not valid.
                        if (!@hasDecl(Type, behaviour_decl_info.name)) {
                            @compileError("Missing a `" ++ behaviour_decl_info.name ++ "` declaration in `" ++ type_path ++ "`");
                        }

                        const type_decl_info = std.meta.declarationInfo(Type, behaviour_decl_info.name);
                        const type_decl_type = switch (type_decl_info.data) {
                            .Type, .Var => |t| t,
                            .Fn => |f| f.fn_type,
                        };

                        doBehaviour(type_decl_type, behaviour_decl_type, type_path ++ "." ++ behaviour_decl_info.name);
                    },
                    // Ignore function declarations.
                    .Fn => {},
                }
            }
        },

        // .Pointer => |type_pointer_info|
        //     if (behaviour_info.Pointer) |behaviour_pointer_info| {

        //     else

        else => @compileError(@typeName(Behaviour) ++ " is not a supported behaviour"),
    }
}

test "hasBehaviour/2 type" {
    const S = struct { a: bool, b: usize };
    const E = enum { a, b, c, d, e, f, g };

    testing.expect(hasBehaviour(u64, type));
    testing.expect(hasBehaviour(S, type));
    testing.expect(hasBehaviour(bool, type));
    testing.expect(hasBehaviour([]const u8, type));
    testing.expect(hasBehaviour(E, type));
    testing.expect(hasBehaviour(struct{}, type));
    testing.expect(hasBehaviour(enum{ foo }, type));
}

test "hasBehaviour/2 scalars" {
    const S = struct { a: bool, b: usize };
    const E = enum { a, b };

    testing.expect(hasBehaviour(u8, u8));
    testing.expect(hasBehaviour(comptime_float, comptime_float));
}

test "hasBehaviour/2 errors" {
    const E = enum { a, b, c, d, e, f, g };
    const SubE = enum { b, d, g };

    testing.expect(hasBehaviour(E, SubE));
    testing.expect(hasBehaviour(E, enum{ f }));
    testing.expect(hasBehaviour(SubE, enum{ g }));
    testing.expect(hasBehaviour(enum{ foo }, enum{ foo }));
    testing.expect(!hasBehaviour(struct {}, SubE));
    testing.expect(!hasBehaviour(u32, SubE));
    testing.expect(!hasBehaviour(enum { bar }, enum { baz }));
}

test "hasBehaviour/2 structs" {
    const S = struct {
        foo: usize,
        bar: bool,

        fn foo(u: u32) void {}
        fn bar() []const u8 { return ""; }
        fn baz(a: bool, b: bool) bool { return false; }
    };

    const S2 = struct {
        pub const S1 = S;
        pub const V = 3;
    };

    testing.expect(hasBehaviour(S, struct {}));
    testing.expect(hasBehaviour(S, struct { pub const foo = fn(u32) void; }));
    testing.expect(hasBehaviour(S, @TypeOf(.{ struct { pub const foo = fn(u32) void; } })));
    testing.expect(hasBehaviour(S2, @TypeOf(.{
        struct {
            pub const S1 = @TypeOf(.{
                struct {
                    pub const baz = fn(bool, bool) bool;
                    pub const V = u32;
                }
            });
        }
    })));
}

pub fn Indexable(comptime Self: type) type {
    return struct {
        pub const Index = type;
        pub const Result = type;

        pub const at = fn(Self, Self.Index) Self.Result;
    };
}

const IndexableTest = struct {
    pub const Index = u32;
    pub const Result = u32;

    pub fn at(self: @This(), index: u32) Result {
        return index;
    }
};

comptime {
    behaviour(IndexableTest, Indexable(IndexableTest));
}
