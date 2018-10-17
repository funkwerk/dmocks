module dmocks.arguments;

import dmocks.dynamic;
import std.algorithm;
import std.conv;
import std.range;

interface ArgumentsMatch
{
    bool matches(Dynamic[] args);
    string toString();
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
}

class ArgumentsTypeMatch : ArgumentsMatch
{
    private Dynamic[] _arguments;
    private bool delegate(Dynamic, Dynamic)[] _comparators;
    this(Dynamic[] args, bool delegate(Dynamic, Dynamic) comparator)
    {
        this(args, [comparator]);
    }
    this(Dynamic[] args, bool delegate(Dynamic, Dynamic)[] comparators)
    in
    {
        assert(args.length == comparators.length || comparators.length == 1);
    }
    do
    {
        _arguments = args;
        _comparators = comparators;
    }
    override bool matches(Dynamic[] args)
    {
        import std.range;
        if (args.length != _arguments.length)
            return false;

        if (_comparators.length == 1)
        {
            foreach(e; zip(_arguments, args))
            {
                auto comparator = _comparators[0];

                if (e[0].type != e[1].type)
                    return false;
                if (!comparator(e[0], e[1]))
                    return false;
            }
        }
        else
        {
            assert(_comparators.length == args.length);

            foreach(e; zip(_arguments, args, _comparators))
            {
                auto comparator = e[2];

                if (e[0].type != e[1].type)
                    return false;
                if (!comparator(e[0], e[1]))
                    return false;
            }
        }
        return true;
    }

    override string toString()
    {
        return "("~_arguments.map!(a=>a.type.toString).join(", ")~")";
    }
}


interface IArguments
{
    string toString();
    bool opEquals (Object other);
}

auto arguments(ARGS...)(ARGS args)
{
    Dynamic[] res = new Dynamic[](ARGS.length);
    foreach(i, arg; args)
    {
        res[i] = dynamic(arg);
    }
    return res;
}

auto formatArguments(Dynamic[] _arguments)
{
    return "(" ~ _arguments.map!(a=>a.type.toString ~ " " ~ a.toString()).join(", ") ~")";
}

@("argument equality")
unittest
{
    auto a = arguments!(int, real)(5, 9.7);
    auto b = arguments!(int, real)(5, 9.7);
    auto c = arguments!(int, real)(9, 1.1);
    auto d = arguments!(int, float)(5, 9.7f);

    assert (a == b);
    assert (a != c);
    assert (a != d);
}

@("argument toString")
unittest
{
    auto a = arguments!(int, real)(5, 9.7);
    a.formatArguments();
}
