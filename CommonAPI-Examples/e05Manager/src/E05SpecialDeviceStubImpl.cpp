/* Copyright (C) 2014 BMW Group
 * Author: Manfred Bathelt (manfred.bathelt@bmw.de)
 * Author: Juergen Gehring (juergen.gehring@bmw.de)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <iostream>

#include "E05SpecialDeviceStubImpl.h"

using namespace commonapi::examples;

E05SpecialDeviceStubImpl::E05SpecialDeviceStubImpl() {
}

E05SpecialDeviceStubImpl::~E05SpecialDeviceStubImpl() {
}

void E05SpecialDeviceStubImpl::doSomethingSpecial() {
    std::cout << "E05SpecialDeviceStubImpl::doSomethingSpecial() called." << std::endl;
}
