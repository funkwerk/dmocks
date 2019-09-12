module test.ImmutableReturnTest;

import dmocks.mocks;

unittest
{
    static interface ImmutableReturnTest
    {
        immutable(int) foo();
    }

    auto mocker = new Mocker;

    mocker.mock!ImmutableReturnTest;
}
