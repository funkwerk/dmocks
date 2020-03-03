module dmocks.dynamic;

import std.format;
import std.traits;

/++
+ This is a very very simple class for storing a variable regardless of it's size and type
+/
abstract class Dynamic
{
    // toHash, toString and opEquals are also part of this class
    // but i'm not sure how to express that in code so this comment has to be enough:)

    /// returns stored typeinfo
    abstract TypeInfo type();
    /// returns stored typename (work around dmd bug https://issues.dlang.org/show_bug.cgi?id=3831)
    abstract string typename();
    /// converts stored value to given "to" type and returns 1el array of target type vals. conversion must be defined.
    abstract const(void)[] convertTo(TypeInfo to);
    /// checks if stored value can be converted to given "to" type.
    abstract bool canConvertTo(TypeInfo to);
}

/// returns stored value if type T is precisely the type of variable stored, variable stored can be implicitly to that type
T get(T)(Dynamic d)
{
    import std.exception : enforce;
    import std.format : format;

    if (d.type == typeid(T))
        return ((cast(DynamicT!T)d).data());

    enforce(
        d.canConvertTo(typeid(T)),
        format!"Cannot convert stored value of type '%s' to '%s'!"(d.typename, T.stringof));

    const(void)[] convertResult = d.convertTo(typeid(T));

    return (cast(T*)convertResult.ptr)[0];
}

/// a helper function for creating Dynamic obhects
Dynamic dynamic(T)(auto ref T t)
{
    return new DynamicT!T(t);
}

class DynamicT(T) : Dynamic
{
    private T _data;
    this(T t)
    {
        _data = t;
    }

    ///
    override TypeInfo type()
    {
        return typeid(T);
    }

    ///
    override string typename()
    {
        return T.stringof;
    }

    ///
    override string toString()
    {
        static if (is(typeof(_data) == class) && !hasFunctionAttributes!(typeof(_data).toString, "const"))
        {
            return (cast(Unqual!(typeof(_data))) _data).toString();
        }
        else
        {
            // not to!string: has problem with T == Nullable!string due to implicit conversion
            return format!"%s"(_data);
        }
    }

    /// two dynamics are equal when they store same type and the values pass opEquals
    override bool opEquals(Object object)
    {
        auto dyn = cast(DynamicT!T)object;
        if (dyn is null)
            return false;
        if (dyn.type != type)
            return false;

        return _data == dyn._data;
    }

    ///
    override size_t toHash()
    {
        return typeid(T).getHash(&_data);
    }

    ///
    T data()
    {
        return _data;
    }

    ///
    override bool canConvertTo(TypeInfo to)
    {
        import std.algorithm : any;

        static if (is(T == typeof(null)))
        {
            // types that have implicit conversion from null
            if (cast(TypeInfo_Array) to || cast(TypeInfo_Pointer) to
                || cast(TypeInfo_Class) to || cast(TypeInfo_Interface) to
                || cast(TypeInfo_Function) to || cast(TypeInfo_Delegate) to)
            {
                return true;
            }
        }

        enum getTypeId(T) = typeid(T);
        alias ConversionTargets = ImplicitConversionTargets!T;

        static if (ConversionTargets.length)
        {
            return [staticMap!(getTypeId, ConversionTargets)].any!(t => t == to);
        }
        else
        {
            return false;
        }
    }

    ///
    override const(void)[] convertTo(TypeInfo to)
    {
        import std.format : format;
        import std.meta : AliasSeq;

        static if (is(T == typeof(null)))
        {
            interface Intf
            {
            }
            static foreach (pair; [
                [q{TypeInfo_Array}, q{void[]}],
                [q{TypeInfo_Pointer}, q{void*}],
                [q{TypeInfo_Class}, q{Object}],
                [q{TypeInfo_Interface}, q{Intf}],
                [q{TypeInfo_Function}, q{void function()}],
                [q{TypeInfo_Delegate}, q{void delegate()}],
            ])
            {
                mixin(format!q{
                    if (cast(%s) to)
                    {
                        %s[] ret = [null];
                        return ret;
                    }
                }(pair[0], pair[1]));
            }
        }

        foreach (Target; ImplicitConversionTargets!T)
        {
            if (typeid(Target) == to)
            {
                Target[] ret = [_data];
                return ret;
            }
        }

        assert(false);
    }
}

version (unittest)
{
    class A
    {
    }

    class B : A
    {
    }

    struct C
    {
    }

    struct D
    {
        private C _c;
        alias _c this;
    }
}

unittest
{
    auto d = dynamic(6);
    assert(d.toString == "6");
    assert(d.typename == "int");
    auto e = dynamic(6);
    assert(e == d);
    assert(e.get!int == 6);
}

unittest
{
    auto d = dynamic((void delegate(int)).init);
    assert(d.typename == "void delegate(int)");
}

unittest
{
    auto d = dynamic(new B);
    assert(d.get!A !is null);
    assert(d.get!B !is null);
}

unittest
{
    auto d = dynamic(null);
    assert(d.get!A is null);
}

unittest
{
    int[5] a;
    auto d = dynamic(a);
    assert(d.get!(int[5]) == [0,0,0,0,0]);
}

unittest
{
    import std.exception : assertThrown;

    float f;
    auto d = dynamic(f);

    assertThrown!Exception(d.get!int);
}

/+ ImplicitConversionTargets doesn't include alias thises
unittest
{
    auto d = dynamic(D());
    d.get!C;
    d.get!D;
}
+/

@("supports const object with non-const toString")
unittest
{
    static assert(is(typeof(dynamic(new const Object))));
    static assert(is(typeof(dynamic(new immutable Object))));
}
