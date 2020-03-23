module dmocks.expectation;

import dmocks.action;
import dmocks.arguments;
import dmocks.call;
import dmocks.model;
import dmocks.name_match;
import dmocks.qualifiers;
import dmocks.util;
import std.conv;
import std.range;
import std.traits;

package:

class CallExpectation : Expectation
{
    this(MockId object, NameMatch name, QualifierMatch qualifiers, ArgumentsMatch args, TypeInfo returnType)
    {
        this.object = object;
        this.name = name;
        this.repeatInterval = Interval(1, 1);
        this.arguments = args;
        this.qualifiers = qualifiers;
        this.action = new Action(returnType);
        _matchedCalls = [];
    }

    MockId object;
    NameMatch name;
    QualifierMatch qualifiers;
    ArgumentsMatch arguments;
    private Call[] _matchedCalls;
    Interval repeatInterval;

    Action action;

    override string toString(string indentation)
    {
        auto apndr = appender!(string);
        apndr.put(indentation);
        apndr.put("Expectation: ");
        bool details = !satisfied;

        if (!details)
            apndr.put("satisfied, ");
        else
            apndr.put("not satisfied, ");

        apndr.put("Method: ");
        apndr.put(name.toString());
        apndr.put(" ");
        apndr.put(arguments.toString());
        apndr.put(" ");
        apndr.put(qualifiers.toString());
        apndr.put("\n");
        apndr.put(indentation);
        apndr.put("ExpectedCalls: ");
        apndr.put(repeatInterval.toString());

        if (details)
        {
            apndr.put("\n" ~ indentation ~ "Calls: " ~ _matchedCalls.length.to!string);
            foreach (Call call; _matchedCalls)
            {
                apndr.put("\n" ~ indentation ~ "  " ~ call.toString());
            }
        }
        return apndr.data;
    }

    string diffToString(Call call)
    in (name.matches(call.name), "logic error: trying to format expectation diff to call that doesn't match it")
    {
        string result;

        if (object != call.object)
        {
            result ~= yellow("(different object).");
        }
        result ~= call.name;
        result ~= " ";
        result ~= arguments.diffToString(call.arguments);
        result ~= " ";
        result ~= qualifiers.diffToString(call.qualifiers);
        if (_matchedCalls.length >= repeatInterval.Max)
        {
            result ~= " (called too many times)";
        }
        result ~= "\n";
        return result;
    }

    override string toString()
    {
        return toString("");
    }

    CallExpectation match(Call call)
    {
        debugLog("Expectation.match:");
        if (object != call.object)
        {
            debugLog("object doesn't match");
            return null;
        }
        if (!name.matches(call.name))
        {
            debugLog("name doesn't match");
            return null;
        }
        if (!qualifiers.matches(call.qualifiers))
        {
            debugLog("qualifiers don't match");
            return null;
        }
        if (!arguments.matches(call.arguments))
        {
            debugLog("arguments don't match");
            return null;
        }
        if (_matchedCalls.length >= repeatInterval.Max)
        {
            debugLog("repeat interval desn't match");
            return null;
        }
        debugLog("full match");
        _matchedCalls ~= call;
        return this;
    }

    bool satisfied()
    {
        return _matchedCalls.length <= repeatInterval.Max && _matchedCalls.length >= repeatInterval.Min;
    }
}

class GroupExpectation : Expectation
{
    this()
    {
        repeatInterval = Interval(1, 1);
        expectations = [];
    }

    Expectation[] expectations;
    bool ordered;
    Interval repeatInterval;

    CallExpectation match(Call call)
    {
        // match call to expectation
        foreach (Expectation expectation; expectations)
        {
            CallExpectation e = expectation.match(call);
            if (e !is null)
                return e;
            if (ordered && !expectation.satisfied())
                return null;
        }
        return null;
    }

    void addExpectation(Expectation expectation)
    {
        expectations ~= expectation;
    }

    bool satisfied()
    {
        foreach (Expectation expectation; expectations)
        {
            if (!expectation.satisfied())
                return false;
        }
        return true;
    }

    override string toString(string indentation)
    {
        auto apndr = appender!(string);
        apndr.put(indentation);
        apndr.put("GroupExpectation: ");
        bool details = !satisfied;

        if (!details)
            apndr.put("satisfied, ");
        else
            apndr.put("not satisfied, ");

        if (ordered)
            apndr.put("ordered, ");
        else
            apndr.put("unordered, ");

        apndr.put("Interval: ");
        apndr.put(repeatInterval.toString());

        if (details)
        {
            foreach (Expectation expectation; expectations)
            {
                apndr.put("\n");
                apndr.put(expectation.toString(indentation ~ "  "));
            }
        }
        return apndr.data;
    }

    override string toString()
    {
        return toString("");
    }
}

GroupExpectation createGroupExpectation(bool ordered)
{
    auto ret = new GroupExpectation();
    ret.ordered = ordered;
    return ret;
}

// composite design pattern
interface Expectation
{
    CallExpectation match(Call call);
    bool satisfied();
    string toString(string indentation);
    string toString();
}

CallExpectation createExpectation(alias METHOD, ARGS...)(MockId object, string name, ARGS args)
{
    auto ret = new CallExpectation(object, new NameMatchText(name), qualifierMatch!METHOD,
            new StrictArgumentsMatch(arguments(args)), typeid(ReturnType!(FunctionTypeOf!(METHOD))));
    return ret;
}
