module dmocks.dynamic;

import std.conv;
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
    /// converts stored value to given "to" type and returns 1el array of target type vals. conversion must be defined.
    abstract void[] convertTo(TypeInfo to);
    /// checks if stored value can be converted to given "to" type.
    abstract bool canConvertTo(TypeInfo to);
}

/// returns stored value if type T is precisely the type of variable stored, variable stored can be implicitly to that type
T get(T)(Dynamic d)
{
    import std.exception : enforce;
    import std.format : format;

    // in addition to init property requirement disallow user defined value types which can have alias this to null-able type
    static if (!is(T==union) && !is(T==struct) && is(typeof(T.init is null)))
    {
        if (d.type == typeid(typeof(null)))
            return null;
    }
    if (d.type == typeid(T))
        return ((cast(DynamicT!T)d).data());

    enforce(d.canConvertTo(typeid(T)), format!"Cannot convert stored value of type '%s' to '%s'!"(d.type, T.stringof));

    void[] convertResult = d.convertTo(typeid(T));

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
    override string toString()
    {
        static if (is(typeof(_data) == class) && !hasFunctionAttributes!(typeof(_data).toString, "const"))
        {
            return (cast(Unqual!(typeof(_data))) _data).toString();
        }
        else
        {
            return _data.to!string;
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
            if (cast(TypeInfo_Array) to || cast(TypeInfo_Pointer) to)
            {
                return true;
            }
        }

        enum getTypeId(T) = typeid(T);
        alias ConversionTargets = ImplicitConversionTargets!T;

        static if (ConversionTargets.length)
        {
            return type == to || [staticMap!(getTypeId, ConversionTargets)].any!(t => t == to);
        }
        else
        {
            return type == to;
        }
    }

    ///
    override void[] convertTo(TypeInfo to)
    {
        static if (is(T == typeof(null)))
        {
            if (cast(TypeInfo_Array) to)
            {
                auto ret = new void[][1];
                ret[0] = null;
                return ret;
            }
            if (cast(TypeInfo_Pointer) to)
            {
                auto ret = new void*[1];
                ret[0] = null;
                return ret;
            }
        }

        foreach(Target; ImplicitConversionTargets!(T))
        {
            if (typeid(Target) == to)
            {
                auto ret = new Target[1];
                ret[0] = cast(Target) _data;
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
    assert(d.type.toString == "int");
    auto e = dynamic(6);
    assert(e == d);
    assert(e.get!int == 6);
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
