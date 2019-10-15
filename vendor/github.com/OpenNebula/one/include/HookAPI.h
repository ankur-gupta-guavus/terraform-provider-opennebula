/* -------------------------------------------------------------------------- */
/* Copyright 2002-2019, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

#ifndef HOOK_API_H_
#define HOOK_API_H_

#include <string>
#include "HookImplementation.h"

class HookPool;
class Hook;

class ParamList;
class RequestAttributes;

class HookAPI : public HookImplementation
{
public:
    /**
     *  Function to build a XML message for an API hook
     */
    static std::string * format_message(std::string method, ParamList& paramList,
            const RequestAttributes& att);

private:
    friend class HookPool;
    friend class Hook;

    // *************************************************************************
    // Constructor/Destructor
    // *************************************************************************
    HookAPI() = default;

    HookAPI(const std::string& _call): call(_call){};

    virtual ~HookAPI() = default;

    /**
     *  Check if type dependent attributes are well defined.
     *    @param tmpl pointer to the Hook template
     *    @param error_str string with error information
     *    @return 0 on success
     */
    int parse_template(Template *tmpl, std::string& error_str);

    /**
     *  Rebuilds the object from a template
     *    @param tmpl The template
     *
     *    @return 0 on success, -1 otherwise
     */
    int from_template(const Template * tmpl, std::string& error);

    /* Checks the mandatory template attributes
     *    @param tmpl The hook template
     *    @param error string describing the error if any
     *
     *    @return 0 on success
     */
    int post_update_template(Template * tmpl, std::string& error);

    /**
     * Check if an api call does exist in the XMLRPC server.
     *   @param api call
     *
     *   @return 0 if the call exists, -1 otherwise
     */
    bool call_exist(const std::string& api_call);

    // -------------------------------------------------------------------------
    // Hook API Attributes
    // -------------------------------------------------------------------------

    /**
     *  String representation of the API call
     */
    std::string call;

    const static std::string unsupported_calls[];
};

#endif
