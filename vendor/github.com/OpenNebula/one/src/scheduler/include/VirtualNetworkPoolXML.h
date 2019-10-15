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


#ifndef VNET_POOL_XML_H_
#define VNET_POOL_XML_H_

#include "PoolXML.h"
#include "VirtualNetworkXML.h"

using namespace std;

class VirtualNetworkPoolXML : public PoolXML
{
public:

    VirtualNetworkPoolXML(Client* client):PoolXML(client) {};

    ~VirtualNetworkPoolXML(){};

    int set_up();

    /**
     *  Gets an object from the pool
     *   @param oid the object unique identifier
     *
     *   @return a pointer to the object, 0 in case of failure
     */
    VirtualNetworkXML * get(int oid) const
    {
        return static_cast<VirtualNetworkXML *>(PoolXML::get(oid));
    };

protected:

    int get_suitable_nodes(vector<xmlNodePtr>& content)
    {
        return get_nodes("/VNET_POOL/VNET", content);
    };

    void add_object(xmlNodePtr node);

    int load_info(xmlrpc_c::value &result);
};

#endif /* VNET_POOL_XML_H_ */