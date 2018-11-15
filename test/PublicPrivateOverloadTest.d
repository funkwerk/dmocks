module test.PublicPRivateOverloadTest;

import dmocks.mocks;
import test.ClassWithPublicPrivateOverload;

unittest
{
    auto mocker = new Mocker;

    mocker.mock!ClassWithPublicPrivateOverload;
}
