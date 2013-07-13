module dmocks.caller;

import dmocks.call;
import dmocks.repository;
import dmocks.model;
import dmocks.util;
import dmocks.action;


class Caller
{
    private MockRepository _owner;

    public this (MockRepository owner)
    {
        _owner = owner;
    }

    @trusted public ReturnOrPass!(TReturn) Call (TReturn, U...) (IMocked mocked,
            string name, U args)
    {
        ReturnOrPass!(TReturn) rope;
        debugLog("checking _owner.Recording...");
        if (_owner.Recording)
        {
            _owner.Record!(U)(mocked, name, args, !is (TReturn == void));
            return rope;
        }

        debugLog("checking for matching call...");
        ICall call = _owner.Match!(U)(mocked, name, args);

        debugLog("checking if call is null...");
        if (call is null)
        {
            throw new ExpectationViolationException();
        }

        rope = call.Action.getActor().act!(TReturn, U)(args);
        debugLog("returning...");
        return rope;
    }
}
