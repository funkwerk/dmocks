module dmocks.arguments;

import dmocks.dynamic;
import dmocks.util;
import std.algorithm;
import std.conv;
import std.range;

interface ArgumentsMatch
{
    bool matches(Dynamic[] args);
    string toString();
    string diffToString(Dynamic[] args);
}

//TODO: allow richer specification of arguments
class StrictArgumentsMatch : ArgumentsMatch
{
    private Dynamic[] _arguments;
    this(Dynamic[] args)
    {
        _arguments = args;
    }

    override bool matches(Dynamic[] args)
    {
        return _arguments == args;
    }

    override string toString()
    {
        return _arguments.formatArguments();
    }

    override string diffToString(Dynamic[] args)
    {
        import std.format : format;

        if (args.length != _arguments.length)
        {
            return toString ~ " " ~ yellow("(length mismatch)");
        }
        string[] argInfos;
        foreach (e; zip(_arguments, args))
        {
            string info = e[0].typename ~ " " ~ e[0].toString();
            if (e[0] != e[1])
            {
                if (e[0].toString() != e[1].toString())
                {
                    info ~= " " ~ yellow(format!"(but got %s)"(e[1]));
                }
                else
                {
                    info ~= " " ~ yellow("(same toString but unequal)");
                }
            }
            argInfos ~= info;
        }
        return "(" ~ argInfos.join(", ") ~ ")";
    }
}

class ArgumentsTypeMatch : ArgumentsMatch
{
    private Dynamic[] _arguments;
    private bool delegate(Dynamic, Dynamic) _del;
    this(Dynamic[] args, bool delegate(Dynamic, Dynamic) del)
    {
        _arguments = args;
        _del = del;
    }

    override bool matches(Dynamic[] args)
    {
        import std.range;

        if (args.length != _arguments.length)
            return false;

        foreach (e; zip(_arguments, args))
        {
            if (e[0].type != e[1].type)
                return false;
            if (!_del(e[0], e[1]))
                return false;
        }
        return true;
    }

    override string toString()
    {
        return "(" ~ _arguments.map!(a => a.typename).join(", ") ~ ")";
    }

    override string diffToString(Dynamic[] args)
    {
        import std.format : format;

        if (args.length != _arguments.length)
        {
            return toString ~ " " ~ yellow("(length mismatch)");
        }
        string[] argInfos = null;
        foreach (e; zip(_arguments, args))
        {
            string info = e[0].typename;
            if (e[0].type != e[1].type)
                info ~= " " ~ yellow(format!"(but got %s)"(e[1].type));
            if (!_del(e[0], e[1]))
            {
                if (e[0].toString() != e[1].toString())
                {
                    import dshould.stringcmp : oneLineDiff;

                    auto diff = oneLineDiff(e[0].toString(), e[1].toString());
                    info ~= " "
                        ~ yellow("(but comparator failed. ")
                        ~ format!"Info: expected.toString %s, got.toString %s"(
                            diff.original, diff.target)
                        ~ yellow(")");
                }
                else
                {
                    info ~= " " ~ yellow("(but comparator failed. Info: expected.toString == got.toString)");
                }
            }
            argInfos ~= info;
        }
        return "(" ~ argInfos.join(", ") ~ ")";
    }
}

interface IArguments
{
    string toString();
    bool opEquals(Object other);
}

auto arguments(ARGS...)(ARGS args)
{
    Dynamic[] res = new Dynamic[](ARGS.length);
    foreach (i, arg; args)
    {
        res[i] = dynamic(arg);
    }
    return res;
}

auto formatArguments(Dynamic[] _arguments)
{
    return "(" ~ _arguments.map!(a => a.typename ~ " " ~ a.toString()).join(", ") ~ ")";
}

@("argument equality")
unittest
{
    auto a = arguments!(int, real)(5, 9.7);
    auto b = arguments!(int, real)(5, 9.7);
    auto c = arguments!(int, real)(9, 1.1);
    auto d = arguments!(int, float)(5, 9.7f);

    assert(a == b);
    assert(a != c);
    assert(a != d);
}

@("argument toString")
unittest
{
    auto a = arguments!(int, real)(5, 9.7);
    a.formatArguments();
}
