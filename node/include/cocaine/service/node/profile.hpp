/*
    Copyright (c) 2011-2014 Andrey Sibiryov <me@kobology.ru>
    Copyright (c) 2014-2016 Evgeny Safronov <division494@gmail.com>
    Copyright (c) 2011-2016 Other contributors as noted in the AUTHORS file.

    This file is part of Cocaine.

    Cocaine is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    Cocaine is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef COCAINE_ENGINE_PROFILE_HPP
#define COCAINE_ENGINE_PROFILE_HPP

#include <cocaine/common.hpp>
#include <cocaine/context/config.hpp>
#include <cocaine/dynamic.hpp>

#include "cocaine/service/node/cached.hpp"

namespace cocaine {

struct profile_t : cached<dynamic_t> {
    profile_t(context_t& context, const std::string& name);

    // The profile name.
    std::string name;

    // Copy all the slave output to the runtime log.
    bool log_output;

    // Timeouts.
    struct {
        unsigned long spawn;
        unsigned long handshake;
        unsigned long heartbeat;
        unsigned long seal;
        unsigned long terminate;
        unsigned long idle;
    } timeout;

    // Limits.
    unsigned long concurrency;
    unsigned long crashlog_limit;
    unsigned long grow_threshold;
    unsigned long pool_limit;
    unsigned long queue_limit;

    // The slave processes are launched in sandboxed environments, called isolates. This one
    // describes the isolate type and arguments.
    struct {
        std::string type;
        dynamic_t args;
    } isolate;


    // This is a temporal hack not to break ABI
    // Should be located in timeout section
    // TODO: fully rework to interface
    unsigned long
    request_timeout() const;
};

}  // namespace cocaine

#endif
