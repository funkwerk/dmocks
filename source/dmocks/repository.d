module dmocks.repository;

import dmocks.action;
import std.algorithm;
import std.array;
import dmocks.call;
import dmocks.expectation;
import dmocks.model;
import dmocks.util;
import std.traits;

package:

class MockRepository
{
    // TODO: split this up somehow!
    private bool _allowDefaults = false;
    private bool _recording = true;
    private bool _ordered = false;
    private bool _allowUnexpected = false;
    private bool _fallback = false; // next recorded call is a fallback call (calls that should always succeed)

    private Call[] _unexpectedCalls = [];
    private GroupExpectation _rootGroupExpectation;
    private CallExpectation _lastRecordedCallExpectation; // stores last call added to _lastGroupExpectation
    private Call _lastRecordedCall; // stores last call with which _lastRecordedCallExpectation was created
    private GroupExpectation _lastGroupExpectation; // stores last group added to _rootGroupExpectation

    private GroupExpectation _fallbackGroupExpectation; // stores fallback methods, like toString and opEquals
    private Call _lastRecordedFallbackCall; // like _lastRecordedCall for fallback
    private CallExpectation _lastRecordedFallbackCallExpectation; // like _lastRecordedCallExpectation for fallback

    private void CheckLastCallSetup()
    {
        if (_allowDefaults || _lastRecordedCallExpectation is null || _lastRecordedCallExpectation.action.hasAction)
        {
            return;
        }

        throw new MocksSetupException(
                "Last expectation: if you do not specify the AllowDefaults option, you need to return a value, throw an exception, execute a delegate, or pass through to base function. The expectation is: " ~ _lastRecordedCallExpectation
                .toString());
    }

    this()
    {
        _rootGroupExpectation = createGroupExpectation(false);
        _fallbackGroupExpectation = createGroupExpectation(false);
        Ordered(false);
    }

    void AllowDefaults(bool value)
    {
        _allowDefaults = value;
    }

    void AllowUnexpected(bool value)
    {
        _allowUnexpected = value;
    }

    bool AllowUnexpected()
    {
        return _allowUnexpected;
    }

    bool Recording()
    {
        return _recording;
    }

    bool Ordered()
    {
        return _ordered;
    }

    void Replay()
    {
        CheckLastCallSetup();
        _recording = false;
    }

    void BackToRecord()
    {
        _recording = true;
    }

    void Ordered(bool value)
    {
        debugLog("SETTING ORDERED: %s", value);
        _ordered = value;
        _lastGroupExpectation = createGroupExpectation(_ordered);
        _rootGroupExpectation.addExpectation(_lastGroupExpectation);
    }

    void Record(CallExpectation expectation, Call call)
    {
        CheckLastCallSetup();
        if (_fallback)
        {
            _fallbackGroupExpectation.addExpectation(expectation);
            _lastRecordedFallbackCallExpectation = expectation;
            _lastRecordedFallbackCall = call;
            _fallback = false;
            return;
        }
        _lastGroupExpectation.addExpectation(expectation);
        _lastRecordedCallExpectation = expectation;
        _lastRecordedCall = call;
    }

    @trusted public auto MethodCall(alias METHOD, ARGS...)(MockId mocked, string name, ARGS args)
    {
        alias ReturnType!(FunctionTypeOf!(METHOD)) TReturn;

        auto call = createCall!METHOD(mocked, name, args);
        debugLog("checking Recording...");
        if (Recording)
        {
            auto expectation = createExpectation!(METHOD)(mocked, name, args);

            Record(expectation, call);
            return ReturnOrPass!(TReturn).init;
        }

        debugLog("checking for matching expectation...");
        auto expectation = Match(call);

        debugLog("checking if expectation is null...");
        if (expectation is null)
        {
            if (AllowUnexpected())
                return ReturnOrPass!(TReturn).init;
            throw new ExpectationViolationError(buildExpectationError);
        }

        auto rope = expectation.action.getActor().act!(TReturn, ARGS)(args);
        debugLog("returning...");
        return rope;
    }

    CallExpectation Match(Call call)
    {
        auto exp = _rootGroupExpectation.match(call);
        if (exp is null)
        {
            exp = _fallbackGroupExpectation.match(call);
            if (exp is null)
            {
                _unexpectedCalls ~= call;
            }
        }
        return exp;
    }

    CallExpectation LastRecordedCallExpectation()
    {
        return _lastRecordedCallExpectation;
    }

    Call LastRecordedCall()
    {
        return _lastRecordedCall;
    }

    package CallExpectation LastRecordedFallbackCallExpectation()
    {
        return _lastRecordedFallbackCallExpectation;
    }

    package Call LastRecordedFallbackCall()
    {
        return _lastRecordedFallbackCall;
    }

    void Verify(bool checkUnmatchedExpectations, bool checkUnexpectedCalls)
    {
        auto expectationError = buildExpectationError(checkUnmatchedExpectations, checkUnexpectedCalls);

        if (!expectationError.empty)
        {
            throw new ExpectationViolationException(expectationError);
        }
    }

    string buildExpectationError(bool checkUnmatchedExpectations = true, bool checkUnexpectedCalls = true)
    {
        auto expectationError = appender!string;
        auto unexpectedCalls = _unexpectedCalls;
        Expectation rootGroupExpectation = _rootGroupExpectation;

        void walkExpectations(ref Expectation expectation)
        {
            if (auto groupExpectation = cast(GroupExpectation) expectation)
            {
                auto expectations = groupExpectation.expectations.dup;

                foreach (ref subExpectation; expectations)
                {
                    walkExpectations(subExpectation);
                }
                expectations = expectations.remove!(a => a is null);

                if (expectations.empty)
                {
                    expectation = null;
                    return;
                }
                auto newExpectation = new GroupExpectation;

                newExpectation.expectations = expectations;
                newExpectation.ordered = groupExpectation.ordered;
                newExpectation.repeatInterval = groupExpectation.repeatInterval;
                expectation = newExpectation;
                return;
            }
            if (auto callExpectation = cast(CallExpectation) expectation)
            {
                if (callExpectation.satisfied) return;

                alias pred = unexpectedCall => callExpectation.name.matches(unexpectedCall.name);

                unexpectedCalls.filter!pred.each!((unexpectedCall) {
                    // name matches: assume they are meant to match up, generate parameter diff
                    expectationError ~= "\n";
                    expectationError ~= CallExpectationDiff(unexpectedCall, callExpectation);
                    expectation = null;
                });
                unexpectedCalls = unexpectedCalls.remove!pred;
                return;
            }
            assert(false, "unknown subclass of expectation");
        }
        if (checkUnmatchedExpectations && checkUnexpectedCalls)
        {
            walkExpectations(rootGroupExpectation);
        }
        if (checkUnmatchedExpectations && rootGroupExpectation && !rootGroupExpectation.satisfied)
        {
            expectationError ~= "\n";
            expectationError ~= rootGroupExpectation.toString();
        }
        if (checkUnexpectedCalls && !unexpectedCalls.empty)
        {
            expectationError ~= "\n";
            expectationError ~= UnexpectedCallsReport(unexpectedCalls);
        }

        return expectationError.data;
    }

    package void RecordFallback(T)(lazy T methodCall)
    {
        _fallback = true;
        methodCall();
        assert(_fallback == false);
        return;
    }

    static string UnexpectedCallsReport(Call[] unexpectedCalls)
    {
        import std.array;

        auto apndr = appender!(string);
        apndr.put("Unexpected calls(calls):\n");
        foreach (Call ev; unexpectedCalls)
        {
            apndr.put(ev.toString());
            apndr.put("\n");
        }
        return apndr.data;
    }

    static string CallExpectationDiff(Call call, CallExpectation callExpectation)
    {
        import std.array;
        auto apndr = appender!(string);
        apndr.put("Mismatched call:\n  ");
        apndr.put(callExpectation.diffToString(call));
        return apndr.data;
    }

    @("repository record/replay")
    unittest
    {
        MockRepository r = new MockRepository();
        assert(r.Recording());
        r.Replay();
        assert(!r.Recording());
        r.BackToRecord();
        assert(r.Recording());
    }

    @("test for correctly formulated template")
    unittest
    {
        class A
        {
            public void a()
            {
            }
        }

        auto a = new A;
        auto c = new MockRepository();
        auto mid = new MockId;
        //c.Call!(a.a)(mid, "a");
        static assert(__traits(compiles, c.MethodCall!(a.a)(mid, "a")));
    }
}
