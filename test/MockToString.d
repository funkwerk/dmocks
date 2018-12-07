import dmocks.mocks;

unittest
{
    static class Test
    {
    }

    auto mocker = new Mocker;
    auto test = mocker.mock!Test;

    mocker.replay;

    auto toString = test.toString;
}
