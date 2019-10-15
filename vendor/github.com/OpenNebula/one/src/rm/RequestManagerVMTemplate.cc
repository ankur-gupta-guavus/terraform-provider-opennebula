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

#include "RequestManagerVMTemplate.h"
#include "VirtualMachineDisk.h"
#include "PoolObjectAuth.h"
#include "Nebula.h"
#include "RequestManagerClone.h"

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

void VMTemplateInstantiate::request_execute(xmlrpc_c::paramList const& paramList,
                                            RequestAttributes& att)
{
    int    id   = xmlrpc_c::value_int(paramList.getInt(1));
    string name = xmlrpc_c::value_string(paramList.getString(2));
    bool   on_hold = false;        //Optional XML-RPC argument
    string str_uattrs;             //Optional XML-RPC argument
    bool   clone_template = false; //Optional XML-RPC argument

    if ( paramList.size() > 3 )
    {
        on_hold    = xmlrpc_c::value_boolean(paramList.getBoolean(3));
        str_uattrs = xmlrpc_c::value_string(paramList.getString(4));
    }

    if ( paramList.size() > 5 )
    {
        clone_template = xmlrpc_c::value_boolean(paramList.getBoolean(5));
    }

    VMTemplate * tmpl = static_cast<VMTemplatePool* > (pool)->get_ro(id);

    if ( tmpl == 0 )
    {
        att.resp_id = id;
        failure_response(NO_EXISTS, att);
        return;
    }

    bool is_vrouter = tmpl->is_vrouter();

    string original_tmpl_name = tmpl->get_name();

    tmpl->unlock();

    if (is_vrouter)
    {
        att.resp_msg = "Virtual router templates cannot be instantiated";
        failure_response(ACTION, att);
        return;
    }

    int instantiate_id = id;

    if (clone_template)
    {
        int new_id;

        VMTemplateClone tmpl_clone;
        string          tmpl_name = name;

        ostringstream   oss;

        if (tmpl_name.empty())
        {
            tmpl_name = original_tmpl_name + "-copy";
        }

        ErrorCode ec = tmpl_clone.request_execute(id, tmpl_name, new_id, true,
            str_uattrs, att);

        if (ec != SUCCESS)
        {
            failure_response(ec, att);
            return;
        }

        instantiate_id = new_id;

        oss << "CLONING_TEMPLATE_ID=" << id << "\n";

        str_uattrs = oss.str();
    }

    int       vid;
    ErrorCode ec;

    ec = request_execute(instantiate_id, name, on_hold, str_uattrs, 0, vid, att);

    if ( ec == SUCCESS )
    {
        success_response(vid, att);
    }
    else
    {
        failure_response(ec, att);
    }
}

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

Request::ErrorCode VMTemplateInstantiate::request_execute(int id, string name,
        bool on_hold, const string &str_uattrs, Template* extra_attrs, int& vid,
        RequestAttributes& att)
{
    int rc;
    std::string memory, cpu;

    ostringstream sid;

    PoolObjectAuth perms;

    Nebula& nd = Nebula::instance();

    VirtualMachinePool* vmpool  = nd.get_vmpool();
    VMTemplatePool *    tpool   = nd.get_tpool();

    VirtualMachineTemplate * tmpl;
    VirtualMachineTemplate extended_tmpl;
    VirtualMachineTemplate uattrs;
    VMTemplate *           rtmpl;

    vector<Template *> ds_quotas;
    vector<Template *> applied;
    vector<Template *>::iterator it;

    string aname;
    string tmpl_name;

    /* ---------------------------------------------------------------------- */
    /* Get, check and clone the template                                      */
    /* ---------------------------------------------------------------------- */
    rtmpl = tpool->get_ro(id);

    if ( rtmpl == 0 )
    {
        att.resp_id = id;
        return NO_EXISTS;
    }

    tmpl_name = rtmpl->get_name();
    tmpl      = rtmpl->clone_template();

    rtmpl->get_permissions(perms);

    rtmpl->unlock();

    ErrorCode ec = merge(tmpl, str_uattrs, att);

    if (ec != SUCCESS)
    {
        delete tmpl;
        return ec;
    }

    if ( extra_attrs != 0 )
    {
        tmpl->merge(extra_attrs);
    }

    ec = as_uid_gid(tmpl, att);

    if ( ec != SUCCESS )
    {
        delete tmpl;
        return ec;
    }

    /* ---------------------------------------------------------------------- */
    /* Store the template attributes in the VM                                */
    /* ---------------------------------------------------------------------- */
    tmpl->erase("NAME");
    tmpl->erase("TEMPLATE_NAME");
    tmpl->erase("TEMPLATE_ID");

    sid << id;

    tmpl->set(new SingleAttribute("TEMPLATE_NAME", tmpl_name));
    tmpl->set(new SingleAttribute("TEMPLATE_ID", sid.str()));

    if (!name.empty())
    {
        tmpl->set(new SingleAttribute("NAME",name));
    }

    if (VirtualMachine::parse_topology(tmpl, att.resp_msg) != 0)
    {
        delete tmpl;
        return ALLOCATE;
    }

    //--------------------------------------------------------------------------

    AuthRequest ar(att.uid, att.group_ids);

    ar.add_auth(AuthRequest::USE, perms); //USE TEMPLATE

    if (!str_uattrs.empty())
    {
        string tmpl_str;

        tmpl->to_xml(tmpl_str);

        // CREATE TEMPLATE
        ar.add_create_auth(att.uid, att.gid, PoolObjectSQL::TEMPLATE,
                tmpl_str);
    }

    extended_tmpl = *tmpl;

    VirtualMachineDisks::extended_info(att.uid, &extended_tmpl);

    VirtualMachine::set_auth_request(att.uid, ar, &extended_tmpl, true);

    if (UserPool::authorize(ar) == -1)
    {
        att.resp_msg = ar.message;

        delete tmpl;
        return AUTHORIZATION;
    }

    extended_tmpl.get("MEMORY", memory);
    extended_tmpl.get("CPU", cpu);

    extended_tmpl.add("RUNNING_MEMORY", memory);
    extended_tmpl.add("RUNNING_CPU", cpu);
    extended_tmpl.add("RUNNING_VMS", 1);
    extended_tmpl.add("VMS", 1);

    if (quota_authorization(&extended_tmpl, Quotas::VIRTUALMACHINE, att,
                att.resp_msg) == false)
    {
        delete tmpl;
        return AUTHORIZATION;
    }

    bool ds_quota_auth = true;

    VirtualMachineDisks::image_ds_quotas(&extended_tmpl, ds_quotas);

    for ( it = ds_quotas.begin() ; it != ds_quotas.end() ; ++it )
    {
        if ( quota_authorization(*it, Quotas::DATASTORE, att, att.resp_msg)
                == false )
        {
            ds_quota_auth = false;
            break;
        }
        else
        {
            applied.push_back(*it);
        }
    }

    if ( ds_quota_auth == false )
    {
        quota_rollback(&extended_tmpl, Quotas::VIRTUALMACHINE, att);

        for ( it = applied.begin() ; it != applied.end() ; ++it )
        {
            quota_rollback(*it, Quotas::DATASTORE, att);
        }

        for ( it = ds_quotas.begin() ; it != ds_quotas.end() ; ++it )
        {
            delete *it;
        }

        delete tmpl;

        return AUTHORIZATION;
    }

    rc = vmpool->allocate(att.uid, att.gid, att.uname, att.gname, att.umask,
            tmpl, &vid, att.resp_msg, on_hold);

    if ( rc < 0 )
    {
        quota_rollback(&extended_tmpl, Quotas::VIRTUALMACHINE, att);

        for ( it = ds_quotas.begin() ; it != ds_quotas.end() ; ++it )
        {
            quota_rollback(*it, Quotas::DATASTORE, att);
            delete *it;
        }

        return ALLOCATE;
    }

    for ( it = ds_quotas.begin() ; it != ds_quotas.end() ; ++it )
    {
        delete *it;
    }

    return SUCCESS;
}

/* -------------------------------------------------------------------------- */
/* -------------------------------------------------------------------------- */

Request::ErrorCode VMTemplateInstantiate::merge(
                Template *      tmpl,
                const string    &str_uattrs,
                RequestAttributes& att)
{
	int rc;

	VirtualMachineTemplate  uattrs;
	string                  aname;

	rc = uattrs.parse_str_or_xml(str_uattrs, att.resp_msg);

	if ( rc != 0 )
	{
		return INTERNAL;
    }
    else if (uattrs.empty())
    {
        return SUCCESS;
	}

	if (!att.is_admin())
	{
        if (uattrs.check_restricted(aname, tmpl))
		{
			att.resp_msg ="User Template includes a restricted attribute " + aname;

			return AUTHORIZATION;
		}
	}

	tmpl->merge(&uattrs);

    return SUCCESS;
}
