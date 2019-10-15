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

#ifndef SNAPSHOTS_H_
#define SNAPSHOTS_H_

#include <iostream>
#include <string>
#include <map>

#include <libxml/parser.h>

#include "Template.h"

using namespace std;

class VectorAttribute;

/**
 *  This class represents a list of Snapshots associated to an image or Virtual
 *  Machine Disk. The list is in the form:
 *  <SNAPSHOTS>
 *   <DISK_ID>: of the disk the snapshots are taken from (the initial backing)
 *   <ACTIVE>: the current snapshot in use by the VM. 0 for the original DISK
 *   <SNAPSHOT>
 *     <ID>
 *     <NAME>: Description
 *     <DATE>: the snapshot was taken
 *     <PARENT>: backing for this snapshot, -1 for the original image
 *     <CHILDREN>: comma separated list of children snapshots
 */
class Snapshots
{
public:

    /**
     *  ALLOW_ORPHANS: Define how child snapshots are handled.
     *    - ALLOW: Children can be orphan (no parent snapshot)
     *      |- snap_1
     *      |- snap_2
     *      |- snap_3
     *
     *    - DENY: New snapshots are set active and child of the previous one
     *      |- snap_1
     *         |- snap_2
     *            |- snap_3
     *
     *    - MIXED: Snapshots are children of last snapshot reverted to
     *      |- snap_1 (<--- revert)
     *         |- snap_2
     *         |- snap_3
     */
    enum AllowOrphansMode
    {
        ALLOW = 0,
        DENY  = 1,
        MIXED = 2
    };

    static string allow_orphans_mode_to_str(AllowOrphansMode aom)
    {
        switch (aom)
        {
            case ALLOW: return "YES";
            case DENY:  return "NO";
            case MIXED: return "MIXED";
        }

        return "NO";
    };

    static AllowOrphansMode str_to_allow_orphans_mode(const string& aom)
    {
        if (aom == "YES")
        {
            return ALLOW;
        }
        else if (aom == "MIXED")
        {
            return MIXED;
        }
        else
        {
            return DENY;
        }
    };

    Snapshots(int _disk_id, AllowOrphansMode orphans);

    Snapshots(const Snapshots& s);

    Snapshots& operator= (const Snapshots& s);

    ~Snapshots() = default;

    // *************************************************************************
    // Inititalization functions
    // *************************************************************************

    /**
     *  Builds the snapshot list from its XML representation. This function
     *  is used when importing it from the DB.
     *    @param node xmlNode for the template
     *    @return 0 on success
     */
    int from_xml_node(const xmlNodePtr node);

    /**
     *  XML Representation of the Snapshots
     */
    string& to_xml(string& xml) const
    {
        return snapshot_template.to_xml(xml);
    };

    /**
     * Creates a new (empty) snapshot of the active disk
     *   @param name description of this snapshot (optional)
     *   @param size_mb of the snapshot (virtual size)
     *   @return id of the new snapshot
     */
    int create_snapshot(const string& name, long long size_mb);

    /**
     *  Check if an snapshot can be deleted (no children, no active)
     *    @param id of the snapshot
     *    @param error if any
     *    @return true if can be deleted, false otherwise
     */
    bool test_delete(int id, string& error) const;

    /**
     *  Removes the snapshot from the list
     *    @param id of the snapshot
     */
    void delete_snapshot(int id);

    /**
     *  Set the given snapshot as active. Updates the values of the current
     *  snapshot
     *
     *    @param id id of the snapshot
     *    @param revert true if the cause of changing the active snapshot
     *                  is because a revert
     */
    int active_snapshot(int id, bool revert);

    /**
     * Rename the given snapshot by the given name
     */

    int rename_snapshot(int id, const string& name, string& str_error);

    /**
     *  Clear all the snapshots in the list
     */
    void clear()
    {
        active        = -1;
        disk_id       = -1;

        snapshot_template.clear();
        snapshot_pool.clear();
    }

    /**
     *  Return the disk_id of the snapshot list
     */
    int get_disk_id() const
    {
        return disk_id;
    }

    /**
     *  Return the active snapshot id
     */
    int get_active_id() const
    {
        return active;
    }

    /**
     *   Removes the DISK_ID attribute to link the list to an Image
     */
    void clear_disk_id()
    {
        disk_id = -1;
        snapshot_template.erase("DISK_ID");
    };

    /**
     *  Sets the disk id for this snapshot list
     *    @param did the id
     */
    void set_disk_id(int did)
    {
        disk_id = did;
        snapshot_template.replace("DISK_ID", did);
    };

    /**
     *  @return number of snapshots in the list
     */
    unsigned int size() const
    {
        return snapshot_pool.size();
    };

    /**
     *  @return true if snapshot_pool is empty
     */
    bool empty() const
    {
        return snapshot_pool.empty();
    };

    /**
     *   Check if snapshot exists
     *   @param snap_id of the snapshot
     *   @return true if the snapshot with snap_id exisits
     */
    bool exists(int snap_id) const
    {
        const VectorAttribute * snap = get_snapshot(snap_id);

        return (snap != 0);
    }

    /**
     *  @return total snapshot size (virtual) in mb
     */
    long long get_total_size() const;

    /**
     *  Get the size (virtual) in mb of the given snapshot
     *    @param id of the snapshot
     *    @return size or 0 if not found
     */
    long long get_snapshot_size(int id) const;

    /**
     *  Get Attribute from the given snapshot
     *    @param id of the snapshot
     *    @param name of the attribute
     *
     *    @return value or empty if not found
     */
    string get_snapshot_attribute(int id, const char* name) const;

private:

    /**
     *  Get a snapshot from the pool
     *  @param id of the snapshot
     *  @return pointer to the snapshot (VectorAttribute) or null
     */
    const VectorAttribute * get_snapshot(int id) const;

    VectorAttribute * get_snapshot(int id)
    {
        return const_cast<VectorAttribute *>(
                static_cast<const Snapshots&>(*this).get_snapshot(id));
    };

    /**
     *  Build the object internal representation from an initialized
     *  template
     */
    void init();

    /**
     *  Updates children list for the current base snapshot in the tree
     *    @param snapshot new child to be added
     */
    void add_child_mixed(VectorAttribute *snapshot);

    /**
     *  Updates children list of the active snapshot
     *    @param snapshot new child to be added
     *    @return -1 in case of error (current active does not exist)
     */
    int add_child_deny(VectorAttribute *snapshot);

    /**
     *  Text representation of the snapshot pool. To be stored as part of the
     *  VM or Image Templates
     */
    Template snapshot_template;

    /**
     *  Next id
     */
    int next_snapshot;

    /**
     * Id of the active (current) snapshot, 0 represents the base image
     */
    int active;

    /**
     * Id of the disk associated with this snapshot list
     */
    int disk_id;

    /**
     * Allow to remove parent snapshots and active one
     */
    AllowOrphansMode orphans;

    /**
     * Snapshot pointer map
     */
    map<int, VectorAttribute *> snapshot_pool;

    /**
     * Current snaphsot base for mixed mode
     */
    int current_base;
};

#endif /*SNAPSHOTS_H_*/
