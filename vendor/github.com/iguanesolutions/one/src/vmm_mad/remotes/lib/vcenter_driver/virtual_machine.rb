# -------------------------------------------------------------------------- #
# Copyright 2002-2019, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

module VCenterDriver

class VirtualMachineFolder
    attr_accessor :item, :items

    def initialize(item)
        @item = item
        check_item(@item, nil)
        @items = {}
    end

    ########################################################################
    # Builds a hash with Datastore-Ref / Datastore to be used as a cache
    # @return [Hash] in the form
    #   { ds_ref [Symbol] => Datastore object }
    ########################################################################
    def fetch!
        VIClient.get_entities(@item, "VirtualMachine").each do |item|
            item_name = item._ref
            @items[item_name.to_sym] = VirtualMachine.new_with_item(item)
        end
    end

    def fetch_templates!
        VIClient.get_entities(@item, "VirtualMachine").each do |item|
            if item.config.template
                item_name = item._ref
                @items[item_name.to_sym] = Template.new(item)
            end
        end
    end

    ########################################################################
    # Returns a Datastore. Uses the cache if available.
    # @param ref [Symbol] the vcenter ref
    # @return Datastore
    ########################################################################
    def get(ref)
        if !@items[ref.to_sym]
            rbvmomi_dc = RbVmomi::VIM::Datastore.new(@item._connection, ref)
            @items[ref.to_sym] = Datastore.new(rbvmomi_dc)
        end

        @items[ref.to_sym]
    end
end # class VirtualMachineFolder



class VirtualMachine < VCenterDriver::Template

    ############################################################################
    # Resource Classes
    ############################################################################

    # Resource base class
    #
    # @param id [Integer] The OpenNebula resource id
    # @param one_res [XMLElement] The OpenNebula representation of the object
    # @param vc_res [vCenter_class_specific] vCenter representation of the objecct
    class Resource
        def initialize(id, one_res, vc_res)
            @id      = id
            @one_res = one_res
            @vc_res  = vc_res
        end

        def id
            raise_if_no_exists_in_one

            @id
        end

        def one_item
            raise_if_no_exists_in_one

            @one_res
        end

        def vc_item
            raise_if_no_exists_in_vcenter

            @vc_res
        end

        def one?
            !@one_res.nil?
        end

        def exists?
            !@vc_res.nil?
        end

        # Fails if the device is not present in OpenNebula
        def raise_if_no_exists_in_one
            if !one?
                raise 'OpenNebula device does not exist at the moment'
            end
        end

        # Fails if the device is not present in vCenter
        def raise_if_no_exists_in_vcenter
            if !exists?
                raise 'vCenter device does not exist at the moment'
            end
        end

        def no_exists?
            !exists?
        end

        def synced?
            one? && exists?
        end

        def unsynced?
            !synced?
        end

        def detached?
            !one?
        end

        def managed?
            raise_if_no_exists_in_one
            if @one_res
                !(@one_res['OPENNEBULA_MANAGED'] &&
                  @one_res['OPENNEBULA_MANAGED'].downcase == "no")
            else

            end
        end
    end

    class Nic < Resource
        def initialize(id, one_res, vc_res)
            super(id, one_res, vc_res)
        end

        # Create the OpenNebula nic representation
        # Allow as to create the class without vCenter representation
        # example: attached nics not synced with vCenter
        def self.one_nic(id, one_res)
            self.new(id, one_res, nil)
        end

        # Create the vCenter nic representation
        # Allow as to create the class without OpenNebula representation
        # example: detached nics that not exists in OpenNebula
        def self.vc_nic(vc_res)
            self.new(nil, nil, vc_res)
        end

        def key
            raise_if_no_exists_in_vcenter

            @vc_res.key
        end

        def boot_dev()
             RbVmomi::VIM.VirtualMachineBootOptionsBootableEthernetDevice({deviceKey: key})
        end
    end

    class Disk < Resource
        def initialize(id, one_res, vc_res)
            super(id, one_res, vc_res)
        end

        # Create the OpenNebula disk representation
        # Allow as to create the class without vCenter representation
        # example: attached disks not synced with vCenter
        def self.one_disk(id, one_res)
            self.new(id, one_res, nil)
        end

        # Create the vCenter disk representation
        # Allow as to create the class without OpenNebula representation
        # example: detached disks that not exists in OpenNebula
        def self.vc_disk(vc_res)
            self.new(nil, nil, vc_res)
        end


        def storpod?
           raise_if_no_exists_in_one
           @one_res["VCENTER_DS_REF"].start_with?('group-')
        end

        def device
            raise_if_no_exists_in_vcenter

            @vc_res[:device]
        end

        def node
            raise_if_no_exists_in_vcenter

            @vc_res[:tag]
        end

        def path
            raise_if_no_exists_in_vcenter

            @vc_res[:path_wo_ds]
        end

        def ds
            raise_if_no_exists_in_vcenter

            @vc_res[:datastore]
        end

        def image_ds_ref
            raise_if_no_exists_in_one

            @one_res['VCENTER_DS_REF']
        end

        def key
            raise_if_no_exists_in_vcenter

            @vc_res[:key]
        end

        def prefix
            raise_if_no_exists_in_vcenter

            @vc_res[:prefix]
        end

        def type
            raise_if_no_exists_in_vcenter

            @vc_res[:type]
        end

        def file
            path.split('/').last
        end

        def is_cd?
            raise_if_no_exists_in_vcenter

            @vc_res[:type] == 'CDROM'
        end

        def config(action)
            raise_if_no_exists_in_vcenter

            config = {}

            if action == :delete
                if managed?
                    key = "opennebula.mdisk.#{@id}"
                else
                    key = "opennebula.disk.#{@id}"
                end

                config[:key] = key
                config[:value] = ""
            elsif action == :resize
                if new_size
                    d = device
                    d.capacityInKB = new_size
                    config[:device] = d
                    config[:operation] = :edit
                end
            elsif action == :attach
                puts "not supported"
            end

            config
        end

        def persistent?
            raise_if_no_exists_in_one

            @one_res['PERSISTENT'] == 'YES'
        end

        def volatile?
            raise_if_no_exists_in_one

            @one_res["TYPE"] && @one_res["TYPE"].downcase == "fs"
        end

        def cloned?
            raise_if_no_exists_in_one

            @one_res['SOURCE'] != @vc_res[:path_wo_ds]
        end

        def connected?
            raise_if_no_exists_in_vcenter

            @vc_res[:device].connectable.connected
        end

        def get_size()
            @size if @size
        end

        def boot_dev()
            if is_cd?
                RbVmomi::VIM.VirtualMachineBootOptionsBootableCdromDevice()
            else
                RbVmomi::VIM.VirtualMachineBootOptionsBootableDiskDevice({deviceKey: device.key})
            end
        end

        def set_size(size)
            size=size.to_i

            if @one_res["ORIGINAL_SIZE"] && @one_res["ORIGINAL_SIZE"].to_i >= size
                raise "'disk-resize' cannot decrease the disk's size"
            end

            @size = size
        end

        # Shrink not supported (nil). Size is in KB
        def new_size
            return @size * 1024 if @size

            if @one_res["ORIGINAL_SIZE"]
                osize = @one_res["ORIGINAL_SIZE"].to_i
                nsize = @one_res["SIZE"].to_i

                new_size = nsize > osize ? nsize * 1024 : nil
            end
        end

        def destroy()
            return if is_cd?
            raise_if_no_exists_in_vcenter

            ds       = VCenterDriver::Datastore.new(self.ds)
            img_path = self.path

            begin
                img_dir = File.dirname(img_path)
                search_params = ds.get_search_params(ds['name'],img_dir, File.basename(img_path))
                search_task = ds['browser'].SearchDatastoreSubFolders_Task(search_params)
                search_task.wait_for_completion
                ds.delete_virtual_disk(img_path)
                ds.rm_directory(img_dir) if ds.dir_empty?(img_dir)
            rescue Exception => e
                if !e.message.start_with?('FileNotFound')
                    raise e.message # Ignore FileNotFound
                end
            end
        end
    end

    ############################################################################
    # Virtual Machine main Class
    ############################################################################

    VM_PREFIX_DEFAULT = "one-$i-"

    POLL_ATTRIBUTE    = OpenNebula::VirtualMachine::Driver::POLL_ATTRIBUTE
    VM_STATE          = OpenNebula::VirtualMachine::Driver::VM_STATE

    DNET_CARD         = RbVmomi::VIM::VirtualEthernetCardDistributedVirtualPortBackingInfo
    NET_CARD          = RbVmomi::VIM::VirtualEthernetCardNetworkBackingInfo


    VM_SHUTDOWN_TIMEOUT = 600 #10 minutes til poweroff hard

    attr_accessor :item, :vm_id

    attr_accessor :vm_info

    include Memoize

    def initialize(vi_client, ref, one_id)
        if (ref)
            @item = RbVmomi::VIM::VirtualMachine.new(vi_client.vim, ref)
            check_item(@item, RbVmomi::VIM::VirtualMachine)
        end

        @vi_client = vi_client
        @vm_id     = one_id
        @locking   = true
        @vm_info   = nil
        @disks     = {}
        @nics = {macs: {}}
    end

    ############################################################################
    ############################################################################

    # Attributes that must be defined when the VM does not exist in vCenter
    attr_accessor :vi_client

    # these have their own getter (if they aren't set, we can set them
    # dynamically)
    attr_writer :one_item
    attr_writer :host
    attr_writer :target_ds_ref

    ############################################################################
    ############################################################################

    # The OpenNebula VM
    # @return OpenNebula::VirtualMachine or XMLElement
    def one_item
        if !@one_item
            if @vm_id != -1
                @one_item = VIHelper.one_item(OpenNebula::VirtualMachine, @vm_id)
            else
                raise "VCenterDriver::Virtualmachine: OpenNebula ID is mandatory for this vm!"
            end
        end

        @one_item
    end


    # set the vmware item directly to the vm
    def set_item(item)
        @item = item
    end

    def disk_real_path(disk, disk_id)
        volatile = disk['TYPE'] == 'fs'

        if volatile
            dir = disk['VCENTER_DS_VOLATILE_DIR'] || 'one-volatile'
            img_path = "#{dir}/#{@vm_id}/one-#{@vm_id}-#{disk_id}.vmdk"
        else
            source = disk['SOURCE'].gsub('%20', ' ')
            folder = File.dirname(source)
            ext    = File.extname(source)
            file   = File.basename(source, ext)

            img_path = "#{folder}/#{file}-#{@vm_id}-#{disk_id}#{ext}"
        end

        return img_path
    end

    # The OpenNebula host
    # @return OpenNebula::Host or XMLElement
    def host
        if @host.nil?
            if one_item.nil?
                raise "'one_item' must be previously set to be able to " <<
                      "access the OpenNebula host."
            end

            host_id = one_item["HISTORY_RECORDS/HISTORY[last()]/HID"]
            raise "No valid host_id found." if host_id.nil?

            @host = VIHelper.one_item(OpenNebula::Host, host_id)
        end

        @host
    end

    # Target Datastore VMware reference getter
    # @return
    def target_ds_ref
        if @target_ds_ref.nil?
            if one_item.nil?
                raise "'one_item' must be previously set to be able to " <<
                      "access the target Datastore."
            end

            target_ds_id = one_item["HISTORY_RECORDS/HISTORY[last()]/DS_ID"]
            raise "No valid target_ds_id found." if target_ds_id.nil?

            target_ds = VCenterDriver::VIHelper.one_item(OpenNebula::Datastore,
                                                         target_ds_id)

            @target_ds_ref = target_ds['TEMPLATE/VCENTER_DS_REF']
        end

        @target_ds_ref
    end

    # Cached cluster
    # @return ClusterComputeResource
    def cluster
        if @cluster.nil?
            ccr_ref = host['TEMPLATE/VCENTER_CCR_REF']
            @cluster = ClusterComputeResource.new_from_ref(ccr_ref, vi_client)
        end

        @cluster
    end

    ############################################################################
    ############################################################################

    # @return Boolean whether the VM exists in vCenter
    def is_new?
        one_item["DEPLOY_ID"].empty?
    end

    def wild?
        !!(one_item['TEMPLATE/IMPORTED'] && one_item['TEMPLATE/IMPORTED'] == 'YES')
    end

    # @return Boolean wheter the vm exists in OpenNebula
    def one_exist?
        !@vm_id.nil? && @vm_id != -1
    end

    # @return String the vm_id stored in vCenter
    def get_vm_id(vm_pool = nil)
        if defined?(@vm_id) && @vm_id
            return @vm_id
        end

        vm_ref = self['_ref']
        return nil if !vm_ref

        vc_uuid = get_vcenter_instance_uuid

        one_vm = VCenterDriver::VIHelper.find_by_ref(OpenNebula::VirtualMachinePool,
                                                     "DEPLOY_ID",
                                                     vm_ref,
                                                     vc_uuid,
                                                     vm_pool)
        return nil if !one_vm

        @vm_id = one_vm["ID"]
        return @vm_id
    end

    def get_vcenter_instance_uuid
        @vi_client.vim.serviceContent.about.instanceUuid
    end

    def get_disk_keys
        unmanaged_keys = {}
        @item.config.extraConfig.each do |val|
            u = val[:key].include?("opennebula.disk")
            m = val[:key].include?("opennebula.mdisk")
            unmanaged_keys[val[:key]] = val[:value] if u || m
        end

        return unmanaged_keys
    end

    ############################################################################
    # Getters
    ############################################################################

    # @return RbVmomi::VIM::ResourcePool
    def get_rp

        req_rp = one_item['VCENTER_RESOURCE_POOL'] ||
                 one_item['USER_TEMPLATE/VCENTER_RESOURCE_POOL']

        #Get ref for req_rp
        rp_list    = cluster.get_resource_pool_list
        req_rp_ref = rp_list.select { |rp| rp[:name].downcase == req_rp.downcase }.first[:ref] rescue nil


        if vi_client.rp_confined?
            if req_rp_ref && req_rp_ref != vi_client.rp._ref
                raise "Available resource pool [#{vi_client.rp.name}] in host"\
                      " does not match requested resource pool"\
                      " [#{req_rp}]"
            end

            return vi_client.rp
        else
            if req_rp_ref
                rps = cluster.resource_pools.select{|r| r._ref == req_rp_ref }

                if rps.empty?
                    raise "No matching resource pool found (#{req_rp})."
                else
                    return rps.first
                end
            else
                return cluster['resourcePool']
            end
        end
    end

    # @return RbVmomi::VIM::Datastore or nil
    def get_ds
        ##req_ds = one_item['USER_TEMPLATE/VCENTER_DS_REF']
        current_ds_id  = one_item["HISTORY_RECORDS/HISTORY[last()]/DS_ID"]
        current_ds     = VCenterDriver::VIHelper.one_item(OpenNebula::Datastore, current_ds_id)
        current_ds_ref = current_ds['TEMPLATE/VCENTER_DS_REF']

        if current_ds_ref
            dc = cluster.get_dc

            ds_folder = dc.datastore_folder
            ds = ds_folder.get(current_ds_ref)
            ds_item = ds.item rescue nil

            return ds_item
        else
            return nil
        end
    end

    # StorageResouceManager reference
    def get_sm
        self['_connection.serviceContent.storageResourceManager']
    end

    # @return Customization or nil
    def get_customization
        xpath = "USER_TEMPLATE/VCENTER_CUSTOMIZATION_SPEC"
        customization_spec = one_item[xpath]

        if customization_spec.nil?
            return nil
        end

        begin
            custom_spec = vi_client.vim
                            .serviceContent
                            .customizationSpecManager
                            .GetCustomizationSpec(:name => customization_spec)

            if custom_spec && (spec = custom_spec.spec)
                return spec
            else
                raise "Error getting customization spec"
            end
        rescue
            raise "Customization spec '#{customization_spec}' not found"
        end
    end

    # @return VCenterDriver::Datastore datastore where the disk will live under
    def get_effective_ds(disk)
        if disk["PERSISTENT"] == "YES"
            ds_ref = disk["VCENTER_DS_REF"]
        else
            ds_ref = target_ds_ref

            if ds_ref.nil?
                raise "target_ds_ref must be defined on this object."
            end
        end

        VCenterDriver::Storage.new_from_ref(ds_ref, vi_client)
    end

    # @return String vcenter name
    def get_vcenter_name
        vm_prefix = host['TEMPLATE/VM_PREFIX']
        vm_prefix = VM_PREFIX_DEFAULT if vm_prefix.nil? || vm_prefix.empty?
        vm_prefix.gsub!("$i", one_item['ID'])

        vm_prefix + one_item['NAME']
    end

    ############################################################################
    # Create and reconfigure VM related methods
    ############################################################################

    # This function creates a new VM from the driver_action XML and returns the
    # VMware ref
    # @param drv_action XML representing the deploy action
    # @return String vmware ref
    def clone_vm(drv_action)
        vcenter_name = get_vcenter_name

        vc_template_ref = drv_action['USER_TEMPLATE/VCENTER_TEMPLATE_REF']
        vc_template = RbVmomi::VIM::VirtualMachine(@vi_client.vim, vc_template_ref)

        ds = get_ds

        # Default disk move type (Full Clone)
        disk_move_type = :moveAllDiskBackingsAndDisallowSharing

        if ds.instance_of? RbVmomi::VIM::Datastore
            use_linked_clones = drv_action['USER_TEMPLATE/VCENTER_LINKED_CLONES']
            if use_linked_clones && use_linked_clones.downcase == 'yes'
                # Check if all disks in template has delta disks
                disks = vc_template.config
                                .hardware.device.grep(RbVmomi::VIM::VirtualDisk)

                disks_no_delta = disks.select { |d| d.backing.parent == nil }

                # Can use linked clones if all disks have delta disks
                if (disks_no_delta.size == 0)
                    disk_move_type = :moveChildMostDiskBacking
                end
            end
        end

        spec_hash = spec_hash_clone(disk_move_type)

        clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(spec_hash)

        # Specify vm folder in vSpere's VM and Templates view F#4823
        vcenter_vm_folder = nil
        vcenter_vm_folder = drv_action["USER_TEMPLATE/VCENTER_VM_FOLDER"]
        vcenter_vm_folder_object = nil
        dc = cluster.get_dc
        if !!vcenter_vm_folder && !vcenter_vm_folder.empty?
            vcenter_vm_folder_object = dc.item.find_folder(vcenter_vm_folder)
        end
        vcenter_vm_folder_object = vc_template.parent if vcenter_vm_folder_object.nil?

        if ds.instance_of? RbVmomi::VIM::StoragePod
            # VM is cloned using Storage Resource Manager for StoragePods
            begin
                vm = storagepod_clonevm_task(vc_template, vcenter_name,
                                             clone_spec, ds, vcenter_vm_folder_object, dc)
            rescue Exception => e
                raise "Cannot clone VM Template to StoragePod: #{e.message}"
            end
        else
            vm = nil
            begin
                vm = vc_template.CloneVM_Task(
                    :folder => vcenter_vm_folder_object,
                    :name   => vcenter_name,
                    :spec   => clone_spec).wait_for_completion
            rescue Exception => e
                if !e.message.start_with?('DuplicateName')
                    raise "Cannot clone VM Template: #{e.message}\n#{e.backtrace}"
                end

                vm_folder = dc.vm_folder
                vm_folder.fetch!
                vm = vm_folder.items
                        .select{|k,v| v.item.name == vcenter_name}
                        .values.first.item rescue nil

                if vm
                    # Detach all persistent disks to avoid accidental destruction
                    detach_persistent_disks(vm)

                    vm.Destroy_Task.wait_for_completion
                    vm = vc_template.CloneVM_Task(
                        :folder => vcenter_vm_folder_object,
                        :name   => vcenter_name,
                        :spec   => clone_spec).wait_for_completion
                else
                    raise "Cannot clone VM Template"
                end
            end
        end

        # @item is populated
        @item = vm

        reference_unmanaged_devices(vc_template_ref)

        return self['_ref']
    end

    # This method raises an exception if the timeout is reached
    # The exception needs to be handled in the VMM drivers and any
    # process that uses this method
    def wait_timeout(action, timeout = 300)
        conf = CONFIG[:vm_poweron_wait_default]

        timeout    = conf || timeout
        time_start = Time.now

        begin
            sleep(1)
            condition = (Time.now-time_start).to_i >= timeout
            raise 'Reached deploy timeout' if condition
        end until send(action)
    end

    # TODO: review
    def storagepod_clonevm_task(vc_template, vcenter_name, clone_spec, storpod, vcenter_vm_folder_object, dc)

        storage_manager = vc_template
                            ._connection.serviceContent.storageResourceManager

        storage_spec = RbVmomi::VIM.StoragePlacementSpec(
            type: 'clone',
            cloneName: vcenter_name,
            folder: vcenter_vm_folder_object,
            podSelectionSpec: RbVmomi::VIM.StorageDrsPodSelectionSpec(storagePod: storpod),
            vm: vc_template,
            cloneSpec: clone_spec
        )

        # Query a storage placement recommendation
        result = storage_manager
                    .RecommendDatastores(storageSpec: storage_spec) rescue nil

        raise "Could not get placement specification for StoragePod" if result.nil?

        if !result.respond_to?(:recommendations) || result.recommendations.size == 0
            raise "Could not get placement specification for StoragePod"
        end

        # Get recommendation key to be applied
        key = result.recommendations.first.key ||= ''
        raise "Missing Datastore recommendation for StoragePod" if key.empty?

        begin
            apply_sr = storage_manager
                            .ApplyStorageDrsRecommendation_Task(key: [key])
                            .wait_for_completion
            return apply_sr.vm
        rescue Exception => e
            if !e.message.start_with?('DuplicateName')
                raise "Cannot clone VM Template: #{e.message}\n#{e.backtrace}"
            end

            # The VM already exists, try to find the vm
            vm_folder = dc.vm_folder
            vm_folder.fetch!
            vm = vm_folder.items
                    .select{|k,v| v.item.name == vcenter_name}
                    .values.first.item rescue nil

            if vm

                begin
                    # Detach all persistent disks to avoid accidental destruction
                    detach_persistent_disks(vm)

                    # Destroy the VM with any disks still attached to it
                    vm.Destroy_Task.wait_for_completion

                    # Query a storage placement recommendation
                    result = storage_manager.RecommendDatastores(storageSpec: storage_spec) rescue nil

                    raise "Could not get placement specification for StoragePod" if result.nil?

                    if !result.respond_to?(:recommendations) || result.recommendations.size == 0
                        raise "Could not get placement specification for StoragePod"
                    end

                    # Get recommendation key to be applied
                    key = result.recommendations.first.key ||= ''
                    raise "Missing Datastore recommendation for StoragePod" if key.empty?

                    apply_sr = storage_manager
                            .ApplyStorageDrsRecommendation_Task(key: [key])
                            .wait_for_completion
                    return apply_sr.vm
                rescue Exception => e
                   raise "Failure applying recommendation while cloning VM: #{e.message}"
                end
            end
        end
    end

    # @return clone parameters spec hash
    def spec_hash_clone(disk_move_type)
        # Relocate spec
        relocate_spec_params = {}

        relocate_spec_params[:pool] = get_rp
        relocate_spec_params[:diskMoveType] = disk_move_type

        ds = get_ds

        relocate_spec_params[:datastore] = ds if ds.instance_of? RbVmomi::VIM::Datastore

        relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(
                                                         relocate_spec_params)

        # Running flag - prevents spurious poweroff states in the VM
        running_flag = [{ :key => "opennebula.vm.running", :value => "no"}]

        running_flag_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
            { :extraConfig => running_flag }
        )

        clone_parameters = {
            :location => relocate_spec,
            :powerOn  => false,
            :template => false,
            :config   => running_flag_spec
        }

        cs = get_customization
        clone_parameters[:customization] = cs if cs

        clone_parameters
    end

    ############################################################################
    # VirtualMachine Resource model methods
    ############################################################################

    #
    #gets the representation of the nics
    #
    #@return [Hash(String => self.Nic)
    def nics
        if !@nics[:macs].empty?
            return @nics.reject{|k| k == :macs}
        end

        info_nics
    end

    #gets the representation of the disks
    #
    #@return [Hash(String => self.Disk)
    def disks
        return @disks unless @disks.empty?

        info_disks
    end

    #iterate over the nics model
    #
    #@param condition[Symbol] selects nics that matches certain condition
    #see Self.Nic|Resource class to see some methods: :exits?, :one?...
    #
    #@return yield the nic
    def nics_each(condition)
        res = []
        nics.each do |id, nic|
            next unless nic.method(condition).call

            yield nic if block_given?

            res << nic
        end

        res
    end

    #iterate over the disks model
    #
    #@param condition[Symbol] selects disks that matches certain condition
    #see Self.Disk|Resource class to see some methods: :exits?, :one?...
    #
    #@return yield the disk
    def disks_each(condition)
        res = []
        disks.each do |id, disk|
            next unless disk.method(condition).call

            yield disk if block_given?

            res << disk
        end

        res
    end

    def disks_synced?
        disks_each(:unsynced?){ return false }

        true
    end

    def get_template_ref
        one_item['USER_TEMPLATE/VCENTER_TEMPLATE_REF']
    end

    # Queries to OpenNebula the machine disks xml representation
    def get_one_disks
        one_item.info if one_item.instance_of?(OpenNebula::VirtualMachine)
        one_item.retrieve_xmlelements("TEMPLATE/DISK")
    end

    # Queries to OpenNebula the machine nics xml representation
    def get_one_nics
        one_item.info if one_item.instance_of?(OpenNebula::VirtualMachine)
        one_item.retrieve_xmlelements("TEMPLATE/NIC")
    end

    # perform a query to vCenter asking for the OpenNebula disk
    #
    # @param one_disk [XMLelement]  The OpenNebula object representation of the disk
    # @param keys [Hash (String => String)] Hashmap with the unmanaged keys
    # @param vc_disks [Array (vcenter_disks)] Array of the machine real disks
    # see get_vcenter_disks method
    #
    # @return [vCenter_disk] the proper disk
    def query_disk(one_disk, keys, vc_disks)
        index     = one_disk['DISK_ID']
        cloned    = one_disk["CLONE"].nil? || one_disk["CLONE"] == "YES"
        unmanaged = "opennebula.disk.#{index}"
        managed   = "opennebula.mdisk.#{index}"

        if keys[managed]
            key  = keys[managed].to_i
        elsif keys[unmanaged]
            key  = keys[unmanaged].to_i
        end

        if key
            query = vc_disks.select {|dev| key == dev[:key]}
        else
            if has_snapshots?
                error = 'disk metadata is corrupted and you have snapshots'
                raise error
            end

            path = !cloned ? one_disk['SOURCE'] : disk_real_path(one_disk, index)
            query = vc_disks.select {|dev| path == dev[:path_wo_ds]}
        end

        #raise "opennebula disk #{index} not found in vCenter" unless query.size == 1
        return nil if query.size != 1

        query.first
    end

    # perform a query to vCenter asking for the OpenNebula nic
    #
    # @param vc_disks [String] The mac of the nic
    # @param vc_disks [Array (vcenter_nic)] Array of the machine real nics
    #
    # @return [vCenter_nic] the proper nic
    def query_nic(mac, vc_nics)
        nic = vc_nics.select{|dev| dev.macAddress == mac }.first

        vc_nics.delete(nic) if nic
    end

    # Refresh VcenterDriver machine nics model, does not perform
    # any sync operation!
    #
    # @return [Hash ("String" => self.Nic)] Model representation of nics
    def info_nics
        @nics = {macs: {}}

        vc_nics  = get_vcenter_nics
        one_nics = get_one_nics

        one_nics.each do |one_nic|
            index  = one_nic["NIC_ID"]
            mac    = one_nic["MAC"]
            vc_dev = query_nic(mac, vc_nics)

            if vc_dev
                @nics[index]      = Nic.new(index.to_i, one_nic, vc_dev)
                @nics[:macs][mac] = index
            else
                @nics[index]      = Nic.one_nic(index.to_i, one_nic)
            end
        end

        vc_nics.each do |d|
            backing = d.backing

            if backing.class == NET_CARD
                key = backing.network._ref
            else
                key = backing.port.portgroupKey
            end

            @nics["#{key}#{d.key}"] = Nic.vc_nic(d)
        end

        @nics.reject{|k| k == :macs}
    end

    # Refresh VcenterDriver machine disks model, does not perform any
    # sync operation!
    #
    # @return [Hash ("String" => self.Disk)] Model representation of disks
    def info_disks
        @disks = {}

        keys = get_disk_keys
        vc_disks  = get_vcenter_disks
        one_disks = get_one_disks

        one_disks.each do |one_disk|
            index = one_disk["DISK_ID"]

            disk = query_disk(one_disk, keys, vc_disks)

            vc_dev = vc_disks.delete(disk) if disk

            if vc_dev
                @disks[index] = Disk.new(index.to_i, one_disk, vc_dev)
            else
                @disks[index] = Disk.one_disk(index.to_i, one_disk)
            end
        end

        vc_disks.each {|d| @disks[d[:path_wo_ds]] = Disk.vc_disk(d)}

        @disks
    end

    # Queries for a certain nic
    #
    # @param index [String| Integer] the id of the nic or the mac
    # @param opts [hash (symbol=>boolean)]
    #   :sync : allow you to ignore local class memory
    def nic(index, opts = {})
        index = index.to_s
        is_mac = index.match(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/)

        if is_mac
            mac = index
            index = @nics[:macs][mac]
        end

        return @nics[index] if @nics[index] && opts[:sync].nil?

        if is_mac
            one_nic = one_item.retrieve_xmlelements("TEMPLATE/NIC[MAC='#{mac}']").first rescue nil
            index = one_nic['NIC_ID'] if one_nic
        else
            one_nic = one_item.retrieve_xmlelements("TEMPLATE/NIC[NIC_ID='#{index}']").first rescue nil
            mac     = one_nic['MAC'] if one_nic
        end

        raise "nic #{index} not found" unless one_nic

        vc_nics = get_vcenter_nics
        vc_nic  = query_nic(mac, vc_nics)

        if vc_nic
            Nic.new(index.to_i, one_nic, vc_nic)
        else
            Nic.one_nic(index.to_i, one_nic)
        end
    end

    # Queries for a certain nic
    #
    # @param index [String | Integer] the id of the disk
    # @param opts [hash (symbol=>boolean)]
    #   :sync : allow you to ignore local class memory
    def disk(index, opts = {})
        index = index.to_s

        return @disks[index] if @disks[index] && opts[:sync].nil?

        one_disk = one_item.retrieve_xmlelements("TEMPLATE/DISK[DISK_ID='#{index}']").first rescue nil

        raise "disk #{index} not found" unless one_disk

        keys = opts[:keys].nil? ? get_disk_keys : opts[:keys]
        vc_disks = opts[:disks].nil? ? get_vcenter_disks : opts[:disks]
        vc_disk = query_disk(one_disk, keys, vc_disks)

        if vc_disk
            Disk.new(index.to_i, one_disk, vc_disk)
        else
            Disk.one_disk(index.to_i, one_disk)
        end
    end

    def nic_model_class(nicmodel)
        case nicmodel
        when 'virtuale1000', 'e1000'
            return RbVmomi::VIM::VirtualE1000
        when 'virtuale1000e', 'e1000e'
            return RbVmomi::VIM::VirtualE1000e
        when 'virtualpcnet32', 'pcnet32'
            return RbVmomi::VIM::VirtualPCNet32
        when 'virtualsriovethernetcard', 'sriovethernetcard'
            return RbVmomi::VIM::VirtualSriovEthernetCard
        when 'virtualvmxnetm', 'vmxnetm'
            return RbVmomi::VIM::VirtualVmxnetm
        when 'virtualvmxnet2', 'vmnet2'
            return RbVmomi::VIM::VirtualVmxnet2
        when 'virtualvmxnet3', 'vmxnet3'
            return RbVmomi::VIM::VirtualVmxnet3
        else # If none matches, use vmxnet3
            return RbVmomi::VIM::VirtualVmxnet3
        end
    end

    def reference_unmanaged_devices(template_ref, execute = true)
        extraconfig   = []
        device_change = []
        spec          = {}

        # Get unmanaged disks in OpenNebula's VM template
        xpath = "TEMPLATE/DISK[OPENNEBULA_MANAGED=\"NO\" or OPENNEBULA_MANAGED=\"no\"]"
        unmanaged_disks = one_item.retrieve_xmlelements(xpath)

        # unmanaged disks:
        if !unmanaged_disks.empty? && !instantiated_as_persistent?

            # Get vcenter VM disks to know real path of cloned disk
            vcenter_disks = get_vcenter_disks

            # Create an array with the paths of the disks in vcenter template
            template = VCenterDriver::Template.new_from_ref(template_ref, vi_client)
            template_disks = template.get_vcenter_disks
            template_disks_vector = []
            template_disks.each do |d|
                template_disks_vector << d[:path_wo_ds]
            end

            # Try to find index of disks in template disks
            unmanaged_disks.each do |unmanaged_disk|
                unmanaged_disk_source = VCenterDriver::FileHelper.unescape_path(unmanaged_disk["SOURCE"])
                template_disk = template_disks.select{|d| d[:path_wo_ds] == unmanaged_disk_source }.first

                if template_disk
                    vcenter_disk  = vcenter_disks.select{|d| d[:key] == template_disk[:key] && d[:device].deviceInfo.summary == template_disk[:device].deviceInfo.summary}.first
                end

                raise "disk with path #{unmanaged_disk_source} not found in the vCenter VM" if !vcenter_disk

                reference = {}
                reference[:key]   = "opennebula.disk.#{unmanaged_disk["DISK_ID"]}"
                reference[:value] = "#{vcenter_disk[:key]}"
                extraconfig << reference
            end
        end

        # Add info for existing nics in template in vm xml
        xpath = "TEMPLATE/NIC[OPENNEBULA_MANAGED=\"NO\" or OPENNEBULA_MANAGED=\"no\"]"
        unmanaged_nics = one_item.retrieve_xmlelements(xpath)

        begin
            if !unmanaged_nics.empty?
                nics  = get_vcenter_nics

                select_net =->(ref){
                    device = nil
                    nics.each do |nic|
                        type = nic.backing.class
                        if type == NET_CARD
                            nref = nic.backing.network._ref
                        else
                            nref = nic.backing.port.portgroupKey
                        end

                        next unless nref == ref
                        device = nic
                        break
                    end

                    raise 'Problem with your unmanaged nics!' unless device

                    nics.delete(device)
                }

                unmanaged_nics.each do |unic|
                    vnic      = select_net.call(unic['VCENTER_NET_REF'])
                    nic_class = vnic.class
                    new_model = nic_model_class(unic['MODEL']) if unic['MODEL']

                    # delete actual nic and update the new one.
                    if new_model && new_model != nic_class
                            device_change << { :device => vnic, :operation => :remove }
                            device_change << calculate_add_nic_spec(unic, vnic.unitNumber)
                    else
                            vnic.macAddress   = unic['MAC']
                            device_change << { :device => vnic, :operation => :edit }
                    end
                end

            end
        rescue Exception => e
            raise "There is a problem with your vm NICS, make sure that they are working properly. Error: #{e.message}"
        end

        # Save in extraconfig the key for unmanaged disks
        if !extraconfig.empty? || !device_change.empty?
            spec[:extraConfig]  = extraconfig if !extraconfig.empty?
            spec[:deviceChange] = device_change if !device_change.empty?

            return spec unless execute

            @item.ReconfigVM_Task(:spec => spec).wait_for_completion
        end

        {}
    end

    # TODO: review storagedrs
    def create_storagedrs_disks(device_change_spod, device_change_spod_ids)

        sm = get_sm
        disk_locator = []
        extra_config = []

        device_change_spod.each do |device_spec|
            disk_locator << RbVmomi::VIM.PodDiskLocator(diskId: device_spec[:device].key)
        end

        spec = {}
        spec[:deviceChange] = device_change_spod

        # Disk locator is required for AddDisk
        vmpod_hash = {}
        vmpod_hash[:storagePod] = get_ds
        vmpod_hash[:disk] = disk_locator
        vmpod_config = RbVmomi::VIM::VmPodConfigForPlacement(vmpod_hash)

        # The storage pod selection requires initialize
        spod_hash = {}
        spod_hash[:initialVmConfig] = [ vmpod_config ]
        spod_select = RbVmomi::VIM::StorageDrsPodSelectionSpec(spod_hash)
        storage_spec = RbVmomi::VIM.StoragePlacementSpec(
            type: :reconfigure,
            podSelectionSpec: spod_select,
            vm: self['_ref'],
            configSpec: spec
        )

        # Query a storage placement recommendation
        result = sm.RecommendDatastores(storageSpec: storage_spec) rescue nil

        raise "Could not get placement specification for StoragePod" if result.nil?

        if !result.respond_to?(:recommendations) || result.recommendations.size == 0
            raise "Could not get placement specification for StoragePod"
        end

        # Get recommendation key to be applied
        key = result.recommendations.first.key ||= ''
        raise "Missing Datastore recommendation for StoragePod" if key.empty?

        # Apply recommendation
        sm.ApplyStorageDrsRecommendation_Task(key: [key]).wait_for_completion

        # Set references in opennebula.disk elements
        device_change_spod.each do |device_spec|
            unit_number    = device_spec[:device].unitNumber
            controller_key = device_spec[:device].controllerKey
            key            = get_vcenter_disk_key(unit_number, controller_key)
            disk_id        = device_change_spod_ids["#{controller_key}-#{unit_number}"]
            reference      = {}
            reference[:key]   = "opennebula.disk.#{disk_id}"
            reference[:value] = key.to_s
            extra_config << reference
        end

        extra_config
    end

    # set the boot order of the machine
    #
    # @param index [String | boot_info] boot information stored in
    # the template of the virtual machine. example: disk0, nic0
    #
    # @return [Array (vCenterbootClass)] An array with the vCenter classes
    def set_boot_order(boot_info)
        convert = ->(device_str){
            spl = device_str.scan(/^(nic|disk)(\d+$)/).flatten
            raise "#{device_str} is not supported" if spl.empty?

            sync = "sync_#{spl[0]}s"
            for i in 0..1
                device = send(spl[0], *[spl[1]])
                break if device.exists?
                send(sync)
            end

            device.boot_dev
        }

        boot_order = boot_info.split(',').map{ |str| convert.call(str) }

        RbVmomi::VIM.VirtualMachineBootOptions({bootOrder: boot_order})
    end

    # sync OpenNebula nic model with vCenter
    #
    # @param option  [symbol]  if :all is provided the method will try to sync
    # all the nics (detached and not existing ones) otherwise it will only sync
    # the nics that are not existing
    #
    # @param execute [boolean] indicates if the reconfigure operation is going to
    # be executed
    def sync_nics(option = :none, execute = true)
        device_change = []

        if option == :all
            dchange = []

            # detached? condition indicates that the nic exists in OpeNebula but not
            # in vCenter
            nics_each(:detached?) do |nic|
                dchange << {
                    :operation => :remove,
                    :device    => nic.vc_item
                }
            end
            if !dchange.empty?
                dspec_hash = { :deviceChange => dchange }
                dspec = RbVmomi::VIM.VirtualMachineConfigSpec(dspec_hash)
                @item.ReconfigVM_Task(:spec => dspec).wait_for_completion
            end
        end

        # no_exits? condition indicates that the nic does not exist in vCenter
        nics_each(:no_exists?) do |nic|
            device_change << calculate_add_nic_spec(nic.one_item)
        end

        return device_change unless execute

        spec_hash = { :deviceChange => device_change }

        spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)
        @item.ReconfigVM_Task(:spec => spec).wait_for_completion

        info_nics
    end

    #Get required parameters to use VMware HTML Console SDK
    #To be used with the following SDK:
    #https://code.vmware.com/web/sdk/2.1.0/html-console
    #
    def get_html_console_parameters
      ticket = @item.AcquireTicket( :ticketType => "webmks" )
      ticket_parameters = {:ticket => ticket.ticket, :host => ticket.host, :port => ticket.port}
      ticket_parameters
    end

    # Synchronize the OpenNebula VM representation with vCenter VM
    #
    # if the device exists in vCenter and not in OpenNebula : detach
    # if the device exists in OpenNebula and not in vCenter : attach
    # if the device exists in both : noop
    #
    def sync(deploy = {})
        extraconfig   = []
        device_change = []

        disks = sync_disks(:all, false)
        resize_unmanaged_disks

        if deploy[:boot] && !deploy[:boot].empty?
            boot_opts = set_boot_order(deploy[:boot])
        end

        # changes from sync_disks
        device_change += disks[:deviceChange] if disks[:deviceChange]
        extraconfig   += disks[:extraConfig]  if disks[:extraConfig]

        # get token and context
        extraconfig += extraconfig_context

        # vnc configuration (for config_array hash)
        extraconfig += extraconfig_vnc

        # opennebula.running flag
        extraconfig += set_running(true, false)

        # device_change hash (nics)
        device_change += sync_nics(:all, false)

        # Set CPU, memory and extraconfig
        num_cpus = one_item["TEMPLATE/VCPU"] || 1
        spec_hash = {
            :numCPUs      => num_cpus.to_i,
            :memoryMB     => one_item["TEMPLATE/MEMORY"],
            :extraConfig  => extraconfig,
            :deviceChange => device_change
        }
        spec_hash[:bootOptions] = boot_opts if boot_opts

        spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)

        @item.ReconfigVM_Task(:spec => spec).wait_for_completion
    end

    def extraconfig_context
        context_text = "# Context variables generated by OpenNebula\n"
        one_item.each('TEMPLATE/CONTEXT/*') do |context_element|
            # next if !context_element.text
            context_text += context_element.name + "='" +
                            context_element.text.gsub("'", "\\'") + "'\n"
        end

        # token
        token = File.read(File.join(VAR_LOCATION,
                        'vms',
                        one_item['ID'],
                        'token.txt')).chomp rescue nil

        context_text += "ONEGATE_TOKEN='#{token}'\n" if token

        # context_text
        [
            { :key => "guestinfo.opennebula.context",
              :value => Base64.encode64(context_text) }
        ]
    end

    def extraconfig_vnc
        if one_item["TEMPLATE/GRAPHICS"]
            vnc_port   = one_item["TEMPLATE/GRAPHICS/PORT"] || ''
            vnc_listen = one_item["TEMPLATE/GRAPHICS/LISTEN"] || "0.0.0.0"
            vnc_keymap = one_item["TEMPLATE/GRAPHICS/KEYMAP"]

            conf = [ {:key => "remotedisplay.vnc.enabled",:value => "TRUE"},
                    {:key => "remotedisplay.vnc.port",   :value => vnc_port},
                    {:key => "remotedisplay.vnc.ip",     :value => vnc_listen}]

            conf += [{:key => "remotedisplay.vnc.keymap",
                            :value => vnc_keymap}] if vnc_keymap

            conf
        else
            conf = []
        end
    end

    # Regenerate context when devices are hot plugged (reconfigure)
    def regenerate_context
        spec_hash = { :extraConfig  => extraconfig_context }
        spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)

        begin
            @item.ReconfigVM_Task(:spec => spec).wait_for_completion
        rescue Exception => e
            raise "Cannot create snapshot for VM: #{e.message}\n#{e.backtrace}"
        end
    end

    # Returns an array of actions to be included in :deviceChange
    def calculate_add_nic_spec(nic, unumber = nil)
        mac     = nic["MAC"]
        pg_name = nic["BRIDGE"]
        default = VCenterDriver::VIHelper.get_default('VM/TEMPLATE/NIC/MODEL')
        tmodel  = one_item['USER_TEMPLATE/NIC_DEFAULT/MODEL']

        model   = nic['MODEL'] || tmodel || default
        raise 'nic model cannot be empty!' if model == ''

        vnet_ref  = nic["VCENTER_NET_REF"]
        backing   = nil

        limit_in  = nic["INBOUND_PEAK_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/INBOUND_PEAK_BW")
        limit_out = nic["OUTBOUND_PEAK_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/OUTBOUND_PEAK_BW")
        limit     = nil

        if limit_in && limit_out
            limit=([limit_in.to_i, limit_out.to_i].min / 1024) * 8
        end

        rsrv_in  = nic["INBOUND_AVG_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/INBOUND_AVG_BW")
        rsrv_out = nic["OUTBOUND_AVG_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/OUTBOUND_AVG_BW")
        rsrv     = nil

        if rsrv_in || rsrv_out
            rsrv=([rsrv_in.to_i, rsrv_out.to_i].min / 1024) * 8
        end

        network = self["runtime.host"].network.select do |n|
            n._ref == vnet_ref || n.name == pg_name
        end
        network = network.first

        raise "#{pg_name} not found in #{self['runtime.host'].name}" unless network

        # start in one, we want the next avaliable id
        card_num = 1
        @item["config.hardware.device"].each do |dv|
            card_num += 1 if is_nic?(dv)
        end

        nic_card = nic_model_class(model)

        if network.class == RbVmomi::VIM::Network
            backing = RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
                        :deviceName => pg_name,
                        :network    => network)
        else
            port    = RbVmomi::VIM::DistributedVirtualSwitchPortConnection(
                        :switchUuid =>
                                network.config.distributedVirtualSwitch.uuid,
                        :portgroupKey => network.key)
            backing =
              RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
                 :port => port)
        end

        # grab the last unitNumber to ensure the nic to be added at the end
        if !unumber
            @unic   = @unic || get_vcenter_nics.map{|d| d.unitNumber}.max || 0
            unumber = @unic += 1
        else
            @unic   = unumber
        end

        card_spec = {
            :key => 0,
            :deviceInfo => {
                :label => "net" + card_num.to_s,
                :summary => pg_name
            },
            :backing     => backing,
            :addressType => mac ? 'manual' : 'generated',
            :macAddress  => mac,
            :unitNumber  => unumber
        }

        if (limit || rsrv) && (limit > 0)
            ra_spec = {}
            rsrv = limit if rsrv > limit
            ra_spec[:limit] = limit if limit
            ra_spec[:reservation] = rsrv if rsrv
            ra_spec[:share] =  RbVmomi::VIM.SharesInfo({
                    :level => RbVmomi::VIM.SharesLevel("normal"),
                    :shares => 0
                })
            card_spec[:resourceAllocation] =
               RbVmomi::VIM.VirtualEthernetCardResourceAllocation(ra_spec)
        end

        {
            :operation => :add,
            :device    => nic_card.new(card_spec)
        }
    end

     # Returns an array of actions to be included in :deviceChange
    def calculate_add_nic_spec_autogenerate_mac(nic)
        pg_name = nic["BRIDGE"]
        model   = ''
        default = VCenterDriver::VIHelper.get_default('VM/TEMPLATE/NIC/MODEL')
        tmodel  = one_item['USER_TEMPLATE/NIC_DEFAULT/MODEL']

        model   = nic['MODEL'] || tmodel || default

        vnet_ref  = nic["VCENTER_NET_REF"]
        backing   = nil

        limit_in  = nic["INBOUND_PEAK_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/INBOUND_PEAK_BW")
        limit_out = nic["OUTBOUND_PEAK_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/OUTBOUND_PEAK_BW")
        limit     = nil

        if limit_in && limit_out
            limit=([limit_in.to_i, limit_out.to_i].min / 1024) * 8
        end

        rsrv_in  = nic["INBOUND_AVG_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/INBOUND_AVG_BW")
        rsrv_out = nic["OUTBOUND_AVG_BW"] || VCenterDriver::VIHelper.get_default("VM/TEMPLATE/NIC/OUTBOUND_AVG_BW")
        rsrv     = nil

        if rsrv_in || rsrv_out
            rsrv=([rsrv_in.to_i, rsrv_out.to_i].min / 1024) * 8
        end

        network = self["runtime.host"].network.select do |n|
            n._ref == vnet_ref || n.name == pg_name
        end

        network = network.first

        card_num = 1 # start in one, we want the next available id

        @item["config.hardware.device"].each do |dv|
            card_num += 1 if is_nic?(dv)
        end

        nic_card = nic_model_class(model)

        if network.class == RbVmomi::VIM::Network
            backing = RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
                        :deviceName => pg_name,
                        :network    => network)
        else
            port    = RbVmomi::VIM::DistributedVirtualSwitchPortConnection(
                        :switchUuid =>
                                network.config.distributedVirtualSwitch.uuid,
                        :portgroupKey => network.key)
            backing =
              RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
                 :port => port)
        end

        card_spec = {
            :key => 0,
            :deviceInfo => {
                :label => "net" + card_num.to_s,
                :summary => pg_name
            },
            :backing     => backing,
            :addressType => 'generated'
        }

        if (limit || rsrv) && (limit > 0)
            ra_spec = {}
            rsrv = limit if rsrv > limit
            ra_spec[:limit] = limit if limit
            ra_spec[:reservation] = rsrv if rsrv
            ra_spec[:share] =  RbVmomi::VIM.SharesInfo({
                    :level => RbVmomi::VIM.SharesLevel("normal"),
                    :shares => 0
                })
            card_spec[:resourceAllocation] =
               RbVmomi::VIM.VirtualEthernetCardResourceAllocation(ra_spec)
        end

        {
            :operation => :add,
            :device    => nic_card.new(card_spec)
        }
    end

    # Add NIC to VM
    def attach_nic(one_nic)
        spec_hash = {}

        begin
            # A new NIC requires a vcenter spec
            attach_nic_array = []
            attach_nic_array << calculate_add_nic_spec(one_nic)
            spec_hash[:deviceChange] = attach_nic_array if !attach_nic_array.empty?

            # Reconfigure VM
            spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)

            @item.ReconfigVM_Task(:spec => spec).wait_for_completion
        rescue Exception => e
            raise "Cannot attach NIC to VM: #{e.message}\n#{e.backtrace.join("\n")}"
        end

    end

    # Detach NIC from VM
    def detach_nic(mac)
        spec_hash = {}

        nic = nic(mac) rescue nil

        return if !nic || nic.no_exists?

        # Remove NIC from VM in the ReconfigVM_Task
        spec_hash[:deviceChange] = [
                :operation => :remove,
                :device => nic.vc_item ]
        begin
            @item.ReconfigVM_Task(:spec => spec_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot detach NIC from VM: #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end

    # Detach all nics useful when removing pg and sw so they're not in use
    def detach_all_nics
        spec_hash = {}
        device_change = []

        nics_each(:exists?) do |nic|
            device_change << {:operation => :remove, :device => nic.vc_item}
        end

        return if device_change.empty?

        # Remove NIC from VM in the ReconfigVM_Task
        spec_hash[:deviceChange] = device_change

        begin
            @item.ReconfigVM_Task(:spec => spec_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot detach all NICs from VM: #{e.message}\n#{e.backtrace}"
        end
    end

    # try to get specs for new attached disks
    # using disk_each method with :no_exists? condition
    def attach_disks_specs()
        attach_disk_array     = []
        extraconfig           = []
        attach_spod_array     = []
        attach_spod_disk_info = {}


        pos = {:ide => 0, :scsi => 0}
        disks_each(:no_exists?) do |disk|
            k = disk.one_item['TYPE'] == 'CDROM' ? :ide : :scsi

            if disk.storpod?
                spec = calculate_add_disk_spec(disk.one_item, pos[k])
                attach_spod_array << spec
                unit_ctrl = "#{spec[:device].controllerKey}-#{spec[:device].unitNumber}"
                attach_spod_disk_info[unit_ctrl] = disk.id
            else
                aspec = calculate_add_disk_spec(disk.one_item, pos[k])
                extra_key   = "opennebula.mdisk.#{disk.one_item["DISK_ID"]}"
                extra_value = "#{aspec[:device].key}"

                attach_disk_array << aspec
                extraconfig << {key: extra_key, value: extra_value }
            end

            pos[k]+=1
        end


        { disks:       attach_disk_array,
          spods:       attach_spod_array,
          spod_info:   attach_spod_disk_info,
          extraconfig: extraconfig
        }
    end

    # try to get specs for detached disks
    # using disk_each method with :dechaded? condition
    def detach_disks_specs()
        detach_disk_array = []
        extra_config      = []
        keys = get_disk_keys.invert
        ipool = VCenterDriver::VIHelper.one_pool(OpenNebula::ImagePool)
        disks_each(:detached?) do |d|
            key = d.key.to_s
            source = VCenterDriver::FileHelper.escape_path(d.path)
            persistent = VCenterDriver::VIHelper.find_persistent_image_by_source(source, ipool)

            op = {operation: :remove, device: d.device}
            if !persistent
                op[:fileOperation] = :destroy unless d.type == "CDROM"
            end
            detach_disk_array << op

            # Remove reference opennebula.disk if exist from vmx and cache
            extra_config << d.config(:delete) if keys[key]
        end

        return detach_disk_array, extra_config
    end

    # sync OpenNebula disk model with vCenter
    #
    # @param option  [symbol]  if :all is provided the method will try to sync
    # all the disks (detached and not existing ones) otherwishe it will only sync
    # the disks that are not existing
    #
    # @param execute [boolean] indicates if the reconfigure operation is going to
    # be executed
    def sync_disks(option = :nil, execute = true)
        info_disks

        spec_hash       = {}
        device_change   = []

        if option == :all
            detach_op = {}
            detach_op[:deviceChange], detach_op[:extraConfig] = detach_disks_specs
            perform = !detach_op[:deviceChange].empty? || !detach_op[:extraConfig].empty?
            @item.ReconfigVM_Task(:spec => detach_op).wait_for_completion if perform
        end

        a_specs = attach_disks_specs

        if !a_specs[:spods].empty?
            spec_hash[:extraConfig] = create_storagedrs_disks(a_specs[:spods], a_specs[:spod_info])
        end

        if !a_specs[:disks].empty?
            spec_hash[:deviceChange] = a_specs[:disks]
            spec_hash[:extraConfig]  = a_specs[:extraconfig]
        end

        return spec_hash unless execute

        spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)
        @item.ReconfigVM_Task(:spec => spec).wait_for_completion

        info_disks
    end

    # Attach DISK to VM (hotplug)
    def attach_disk(disk)
        spec_hash     = {}
        device_change = []

        # Extract unmanaged_keys
        unmanaged_keys = get_disk_keys
        vc_disks = get_vcenter_disks

        # Check if we're dealing with a StoragePod SYSTEM ds
        storpod = disk["VCENTER_DS_REF"].start_with?('group-')

        # Check if disk being attached is already connected to the VM
        raise "DISK is already connected to VM" if disk_attached_to_vm(disk, unmanaged_keys, vc_disks)

        # Generate vCenter spec and reconfigure VM
        add_spec = calculate_add_disk_spec(disk)
        device_change << add_spec
        raise "Could not generate DISK spec" if device_change.empty?

        extra_key   = "opennebula.mdisk.#{disk["DISK_ID"]}"
        extra_value = "#{add_spec[:device].key}"

        spec_hash[:deviceChange] = device_change
        spec_hash[:extraConfig]  = [{key: extra_key, value: extra_value }]
        spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)

        begin
            if storpod
                #Ask for StorageDRS recommendation to reconfigure VM (AddDisk)
                sm = get_sm

                # Disk id is -1 as I don't know what disk id is going to be set
                disk_locator = [ RbVmomi::VIM.PodDiskLocator(diskId: -1) ]

                # Disk locator is required for AddDisk
                vmpod_hash = {}
                vmpod_hash[:storagePod] = get_ds
                vmpod_hash[:disk] = disk_locator
                vmpod_config = RbVmomi::VIM::VmPodConfigForPlacement(vmpod_hash)

                # The storage pod selection requires initialize
                spod_hash = {}
                spod_hash[:initialVmConfig] = [ vmpod_config ]
                spod_select = RbVmomi::VIM::StorageDrsPodSelectionSpec(spod_hash)
                storage_spec = RbVmomi::VIM.StoragePlacementSpec(
                    type: :reconfigure,
                    podSelectionSpec: spod_select,
                    vm: self['_ref'],
                    configSpec: spec
                )

                # Query a storage placement recommendation
                result = sm.RecommendDatastores(storageSpec: storage_spec) rescue nil

                raise "Could not get placement specification for StoragePod" if result.nil?

                if !result.respond_to?(:recommendations) || result.recommendations.size == 0
                    raise "Could not get placement specification for StoragePod"
                end

                # Get recommendation key to be applied
                key = result.recommendations.first.key ||= ''
                raise "Missing Datastore recommendation for StoragePod" if key.empty?

                # Apply recommendation
                sm.ApplyStorageDrsRecommendation_Task(key: [key]).wait_for_completion

                # Add the key for the volatile disk to the unmanaged opennebula.disk.id variables
                unit_number    = spec_hash[:deviceChange][0][:device].unitNumber
                controller_key = spec_hash[:deviceChange][0][:device].controllerKey
                key = get_vcenter_disk_key(unit_number, controller_key)
                spec_hash = {}
                reference = {}
                reference[:key]   = "opennebula.disk.#{disk["DISK_ID"]}"
                reference[:value] = key.to_s
                spec_hash[:extraConfig] = [ reference ]
                @item.ReconfigVM_Task(:spec => spec_hash).wait_for_completion
            else
                @item.ReconfigVM_Task(:spec => spec).wait_for_completion
            end
        rescue Exception => e
            raise "Cannot attach DISK to VM: #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end

    # Detach persistent disks to avoid incidental destruction
    def detach_persistent_disks(vm)
        spec_hash = {}
        spec_hash[:deviceChange] = []
        ipool = VCenterDriver::VIHelper.one_pool(OpenNebula::ImagePool)
        if ipool.respond_to?(:message)
            raise "Could not get OpenNebula ImagePool: #{ipool.message}"
        end

        vm.config.hardware.device.each do |disk|
            if is_disk_or_cdrom?(disk)
                # Let's try to find if disks is persistent
                source_unescaped = disk.backing.fileName.sub(/^\[(.*?)\] /, "")
                source = VCenterDriver::FileHelper.escape_path(source_unescaped)

                persistent = VCenterDriver::VIHelper.find_persistent_image_by_source(source, ipool)

                if persistent
                    spec_hash[:deviceChange] << {
                        :operation => :remove,
                        :device => disk
                    }
                end
            end

        end

        return nil if spec_hash[:deviceChange].empty?

        begin
            vm.ReconfigVM_Task(:spec => spec_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot detach all DISKs from VM: #{e.message}\n#{e.backtrace}"
        end
    end

    def detach_disk(disk)
        return unless disk.exists?

        spec_hash = {}
        spec_hash[:extraConfig] = [disk.config(:delete)]
        spec_hash[:deviceChange] = [{
            :operation => :remove,
            :device => disk.device
        }]

        begin
            @item.ReconfigVM_Task(:spec => spec_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot detach DISK from VM: #{e.message}\n#{e.backtrace}"
        end
    end

    def destroy_disk(disk)
        one_vm = one_item

        detachable= !(one_vm["LCM_STATE"].to_i == 11 && !disk.managed?)
        detachable = detachable && !has_snapshots? && disk.exists?

        return unless detachable

        detach_disk(disk)
        disk.destroy()

        @disks.delete(disk.id.to_s)
    end

    # Get vcenter device representing DISK object (hotplug)
    def disk_attached_to_vm(disk, unmanaged_keys, vc_disks)
        img_name = ""
        device_found = nil
        disk_id = disk["DISK_ID"]
        unmanaged_key = unmanaged_keys["opennebula.disk.#{disk_id}"]

        img_name_escaped = VCenterDriver::FileHelper.get_img_name(
                                disk,
                                one_item['ID'],
                                self['name'],
                                instantiated_as_persistent?)

        img_name = VCenterDriver::FileHelper.unescape_path(img_name_escaped)

        vc_disks.each do |d|
            key_matches  = (unmanaged_key && d[:key] == unmanaged_key.to_i)
            path_matches = (d[:path_wo_ds] == img_name)

            if key_matches || path_matches
                device_found = d
                break
            end
        end

        return device_found
    end

    def get_key(type)
        @used_keys = [] unless @used_keys

        if type == "CDROM"
            bound = "is_cdrom?"
            key   = 3000
        else
            bound = "is_disk?"
            key   = 2000
        end

        used = @used_keys
        @item.config.hardware.device.each do |dev|
            used << dev.key
            next unless send(bound, dev)
            key = dev.key
        end

        loop do
            break if !used.include?(key)
            key+=1
        end

        @used_keys << key

        key
    end

    def calculate_add_disk_spec(disk, position=0)
        img_name_escaped = VCenterDriver::FileHelper.get_img_name(
                                disk,
                                one_item['ID'],
                                self['name'],
                                instantiated_as_persistent?)

        img_name = VCenterDriver::FileHelper.unescape_path(img_name_escaped)

        type     = disk["TYPE"]
        size_kb  = disk["SIZE"].to_i * 1024

        if type == "CDROM"
            # CDROM drive will be found in the IMAGE DS
            ds_ref   = disk["VCENTER_DS_REF"]
            ds       = VCenterDriver::Storage.new_from_ref(ds_ref, @vi_client)
            ds_name  = ds['name']

            # CDROM can only be added when the VM is in poweroff state
            vmdk_backing = RbVmomi::VIM::VirtualCdromIsoBackingInfo(
                :datastore => ds.item,
                :fileName  => "[#{ds_name}] #{img_name}"
            )

            if @item["summary.runtime.powerState"] != "poweredOff"
                raise "The CDROM image can only be added as an IDE device "\
                      "when the VM is in the powered off state"
            end

            controller, unit_number = find_free_ide_controller(position)

            device = RbVmomi::VIM::VirtualCdrom(
                :backing       => vmdk_backing,
                :key           => get_key(type),
                :controllerKey => controller.key,
                :unitNumber    => unit_number,

                :connectable => RbVmomi::VIM::VirtualDeviceConnectInfo(
                    :startConnected    => true,
                    :connected         => true,
                    :allowGuestControl => true
                )
            )

            return {
                :operation => :add,
                :device => device
            }

        else
            # TYPE is regular disk (not CDROM)
            controller, unit_number = find_free_controller(position)

            storpod = disk["VCENTER_DS_REF"].start_with?('group-')
            if storpod
                vmdk_backing = RbVmomi::VIM::VirtualDiskFlatVer2BackingInfo(
                  :diskMode  => 'persistent',
                  :fileName  => ""
                )
            else
                ds           = get_effective_ds(disk)
                ds_name      = ds['name']
                vmdk_backing = RbVmomi::VIM::VirtualDiskFlatVer2BackingInfo(
                  :datastore => ds.item,
                  :diskMode  => 'persistent',
                  :fileName  => "[#{ds_name}] #{img_name}"
                )
            end

            device = RbVmomi::VIM::VirtualDisk(
              :backing       => vmdk_backing,
              :capacityInKB  => size_kb,
              :controllerKey => controller.key,
              :key           => get_key(type),
              :unitNumber    => unit_number
            )

            config = {
               :operation => :add,
               :device    => device
            }

            # For StorageDRS vCenter must create the file
            config[:fileOperation] = :create if storpod

            return config
        end
    end

    # Remove the MAC addresses so they cannot be in conflict
    # with OpenNebula assigned mac addresses.
    # We detach all nics from the VM
    def convert_to_template()
            detach_all_nics

            # We attach new NICs where the MAC address is assigned by vCenter
            nic_specs = []
            one_nics = one_item.retrieve_xmlelements("TEMPLATE/NIC")
            one_nics.each do |nic|
                if (nic["OPENNEBULA_MANAGED"] && nic["OPENNEBULA_MANAGED"].upcase == "NO")
                    nic_specs << calculate_add_nic_spec_autogenerate_mac(nic)
                end
            end

            # Reconfigure VM to add unmanaged nics
            spec_hash = {}
            spec_hash[:deviceChange] = nic_specs
            spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)
            @item.ReconfigVM_Task(:spec => spec).wait_for_completion

            # Convert VM to template in vCenter
            mark_as_template

            # Edit the Opennebula template
            one_client = OpenNebula::Client.new
            template_id = one_item['TEMPLATE/TEMPLATE_ID']
            new_template = OpenNebula::Template.new_with_id(template_id, one_client)
            new_template.info

            # Update the template reference
            new_template.update("VCENTER_TEMPLATE_REF=#{@item._ref}", true)
    end

    def resize_unmanaged_disks
        spec = {deviceChange: []}
        disks_each(:one?) do |d|
            next unless !d.managed? && d.new_size
            spec[:deviceChange] << d.config(:resize)
        end

        if !spec[:deviceChange].empty?
            @item.ReconfigVM_Task(:spec => spec).wait_for_completion
        end
    end

    def resize_disk(disk)
        if !disk.exists?
            size = disk.get_size
            sync_disks
            disk = disk(disk.id)
            disk.set_size(size)
        end

        spec = {deviceChange: [disk.config(:resize)]}

        @item.ReconfigVM_Task(spec: spec).wait_for_completion
    end

    def has_snapshots?
        self['rootSnapshot'] && !self['rootSnapshot'].empty?
    end

    def instantiated_as_persistent?
        begin
            !!one_item["TEMPLATE/CLONING_TEMPLATE_ID"]
        rescue
            return false #one_item may not be retrieved if deploy_id hasn't been set
        end
    end

    def use_linked_clone?
        one_item["USER_TEMPLATE/VCENTER_LINKED_CLONES"] && one_item["USER_TEMPLATE/VCENTER_LINKED_CLONES"].upcase == "YES"
    end

    def find_free_ide_controller(position=0)
        free_ide_controllers = []
        ide_schema           = {}

        used_numbers      = []
        available_numbers = []
        devices           = @item.config.hardware.device

        devices.each do |dev|
            if dev.is_a? RbVmomi::VIM::VirtualIDEController
                if ide_schema[dev.key].nil?
                    ide_schema[dev.key] = {}
                end

                ide_schema[dev.key][:device] = dev
            end

            next if dev.class != RbVmomi::VIM::VirtualCdrom
            used_numbers << dev.unitNumber
        end

        2.times do |ide_id|
            available_numbers << ide_id if used_numbers.grep(ide_id).length <= 0
        end

        ide_schema.keys.each do |controller|
            free_ide_controllers << ide_schema[controller][:device].deviceInfo.label
        end

        if free_ide_controllers.empty?
            raise "There are no free IDE controllers to connect this CDROM device"
        end

        available_controller_label = free_ide_controllers[0]

        controller = nil

        devices.each do |device|
            if device.deviceInfo.label == available_controller_label
                controller = device
                break
            end
        end

        new_unit_number = available_numbers.sort[position]

        return controller, new_unit_number
    end

    def find_free_controller(position=0)
        free_scsi_controllers = []
        scsi_schema           = {}

        used_numbers      = []
        available_numbers = []
        devices           = @item.config.hardware.device

        devices.each do |dev|
            if dev.is_a? RbVmomi::VIM::VirtualSCSIController
                if scsi_schema[dev.key].nil?
                    scsi_schema[dev.key] = {}
                end

                used_numbers << dev.scsiCtlrUnitNumber
                scsi_schema[dev.key][:device] = dev
            end

            next if dev.class != RbVmomi::VIM::VirtualDisk
            used_numbers << dev.unitNumber
        end

        15.times do |scsi_id|
            available_numbers << scsi_id if used_numbers.grep(scsi_id).length <= 0
        end

        scsi_schema.keys.each do |controller|
            free_scsi_controllers << scsi_schema[controller][:device].deviceInfo.label
        end

        if free_scsi_controllers.length > 0
            available_controller_label = free_scsi_controllers[0]
        else
            add_new_scsi(scsi_schema, devices)
            return find_free_controller
        end

        controller = nil

        devices.each do |device|
            if device.deviceInfo.label == available_controller_label
                controller = device
                break
            end
        end

        new_unit_number = available_numbers.sort[position]

        return controller, new_unit_number
    end

    def add_new_scsi(scsi_schema, devices)
        controller = nil

        if scsi_schema.keys.length >= 4
            raise "Cannot add a new controller, maximum is 4."
        end

        scsi_key    = 0
        scsi_number = 0

        if scsi_schema.keys.length > 0 && scsi_schema.keys.length < 4
            scsi_key    = scsi_schema.keys.sort[-1] + 1
            scsi_number = scsi_schema[scsi_schema.keys.sort[-1]][:device].busNumber + 1
        end

        controller_device = RbVmomi::VIM::VirtualLsiLogicController(
            :key       => scsi_key,
            :busNumber => scsi_number,
            :sharedBus => :noSharing
        )

        device_config_spec = RbVmomi::VIM::VirtualDeviceConfigSpec(
            :device    => controller_device,
            :operation => :add
        )

        vm_config_spec = RbVmomi::VIM::VirtualMachineConfigSpec(
            :deviceChange => [device_config_spec]
        )

        @item.ReconfigVM_Task(:spec => vm_config_spec).wait_for_completion

        devices.each do |device|
            if device.class == RbVmomi::VIM::VirtualLsiLogicController &&
                device.key == scsi_key

                controller = device.deviceInfo.label
            end
        end

        return controller
    end

    # Create a snapshot for the VM
    def create_snapshot(snap_id, snap_name)
        snapshot_hash = {
            :name        => snap_id,
            :description => "OpenNebula Snapshot: #{snap_name}",
            :memory      => true,
            :quiesce     => true
        }

        vcenter_version = @vi_client.vim.serviceContent.about.apiVersion rescue nil

        if vcenter_version != "5.5"
            begin
                @item.CreateSnapshot_Task(snapshot_hash).wait_for_completion
            rescue Exception => e
                raise "Cannot create snapshot for VM: #{e.message}\n#{e.backtrace.join("\n")}"
            end
        else
            # B#5045 - If vcenter is 5.5 the snapshot may take longer than
            # 15 minutes and it does not report that it has finished using
            # wait_for_completion so we use an active wait instead with a
            # timeout of 1440 minutes = 24 hours
            @item.CreateSnapshot_Task(snapshot_hash)

            snapshot_created  = false
            elapsed_minutes   = 0

            until snapshot_created || elapsed_minutes == 1440
                if !!@item['snapshot']
                    current_snapshot = @item['snapshot.currentSnapshot'] rescue nil
                    snapshot_found = find_snapshot_in_list(@item['snapshot.rootSnapshotList'], snap_id)
                    snapshot_created = !!snapshot_found && !!current_snapshot && current_snapshot._ref == snapshot_found._ref
                end
                sleep(60)
                elapsed_minutes += 1
            end
        end

        return snap_id
    end

    # Revert to a VM snapshot
    def revert_snapshot(snap_id)

        snapshot_list = self["snapshot.rootSnapshotList"]
        snapshot = find_snapshot_in_list(snapshot_list, snap_id)

        return nil if !snapshot

        begin
            revert_snapshot_hash = { :_this => snapshot }
            snapshot.RevertToSnapshot_Task(revert_snapshot_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot revert snapshot of VM: #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end

    # Delete VM snapshot
    def delete_snapshot(snap_id)

        snapshot_list = self["snapshot.rootSnapshotList"]
        snapshot = find_snapshot_in_list(snapshot_list, snap_id)

        return nil if !snapshot

        begin
            delete_snapshot_hash = {
                :_this => snapshot,
                :removeChildren => false
            }
            snapshot.RemoveSnapshot_Task(delete_snapshot_hash).wait_for_completion
        rescue Exception => e
            raise "Cannot delete snapshot of VM: #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end

    def find_snapshot_in_list(list, snap_id)
        list.each do |i|
            if i.name == snap_id.to_s
                return i.snapshot
            elsif !i.childSnapshotList.empty?
                snap = find_snapshot_in_list(i.childSnapshotList, snap_id)
                return snap if snap
            end
        end rescue nil

        nil
    end

    def migrate(config = {})
        raise "You need at least 1 parameter to perform a migration" if config.size == 0

        begin
            # retrieve host from DRS
            one_cluster = config[:cluster]
            resourcepool = one_cluster.item.resourcePool
            datastore    = config[:datastore]

            if datastore
                relocate_spec_params = {
                    pool:      resourcepool,
                    datastore: datastore,
                }

                if config[:esx_migration_list].is_a?(String)
                    if config[:esx_migration_list]==""
                        relocate_spec_params[:host] = config[:cluster].item.host.sample
                    elsif config[:esx_migration_list]!="Selected_by_DRS"
                        hostnames = config[:esx_migration_list].split(' ')
                        hostname = hostnames.sample
                        host_moref = one_cluster.hostname_to_moref(hostname)
                        relocate_spec_params[:host] = host_moref
                    end
                end


                relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(relocate_spec_params)
                @item.RelocateVM_Task(spec: relocate_spec, priority: "defaultPriority").wait_for_completion
            else
                @item.MigrateVM_Task(:pool=> resourcepool, :priority => "defaultPriority").wait_for_completion
            end

        rescue Exception => e
            raise "Cannot migrate VM #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end

    ############################################################################
    # actions
    ############################################################################

    def shutdown
        begin
            if vm_tools?
                @item.ShutdownGuest
            else
                poweroff_hard
            end
        rescue RbVmomi::Fault => e
            error = e.message.split(':').first
            raise e.message if error != 'InvalidPowerState'
        end
        wait_timeout(:is_powered_off?)
    end

    def destroy
        @item.Destroy_Task.wait_for_completion
    end

    def mark_as_template
        @item.MarkAsTemplate
    end

    def reset
        @item.ResetVM_Task.wait_for_completion
    end

    def suspend
        @item.SuspendVM_Task.wait_for_completion
    end

    def reboot
        @item.RebootGuest
    end

    def poweron
        begin
            @item.PowerOnVM_Task.wait_for_completion
        rescue RbVmomi::Fault => e
            error = e.message.split(':').first
            raise e.message if error != 'InvalidPowerState'
        end

        wait_timeout(:is_powered_on?)
    end

    def is_powered_on?
        return @item.runtime.powerState == "poweredOn"
    end

    def is_powered_off?
        return @item.runtime.powerState == "poweredOff"
    end

    def poweroff_hard
        @item.PowerOffVM_Task.wait_for_completion
    end

    def remove_all_snapshots(consolidate = true)
        @item.RemoveAllSnapshots_Task({consolidate: consolidate}).wait_for_completion
        info_disks
    end

    def vm_tools?
        @item.guest.toolsRunningStatus == 'guestToolsRunning'
    end

    def set_running(state, execute = true)
        value = state ? "yes" : "no"

        config_array = [
            { :key => "opennebula.vm.running", :value => value }
        ]

        return config_array unless execute

        spec = RbVmomi::VIM.VirtualMachineConfigSpec(
            { :extraConfig => config_array }
        )

        @item.ReconfigVM_Task(:spec => spec).wait_for_completion
    end

    ############################################################################
    # monitoring
    ############################################################################

    # monitor function used when VMM poll action is called
    def monitor_poll_vm
        reset_monitor

        @state = state_to_c(self["summary.runtime.powerState"])

        if @state != VM_STATE[:active]
            reset_monitor
            return
        end

        cpuMhz = self["runtime.host.summary.hardware.cpuMhz"].to_f

        @monitor[:used_memory] = self["summary.quickStats.hostMemoryUsage"] * 1024

        used_cpu = self["summary.quickStats.overallCpuUsage"].to_f / cpuMhz
        used_cpu = (used_cpu * 100).to_s
        @monitor[:used_cpu]  = sprintf('%.2f', used_cpu).to_s

        # Check for negative values
        @monitor[:used_memory] = 0 if @monitor[:used_memory].to_i < 0
        @monitor[:used_cpu]    = 0 if @monitor[:used_cpu].to_i < 0

        guest_ip_addresses = []
        self["guest.net"].each do |net|
            net.ipConfig.ipAddress.each do |ip|
                guest_ip_addresses << ip.ipAddress
            end if net.ipConfig && net.ipConfig.ipAddress
        end if self["guest.net"]

        @guest_ip_addresses = guest_ip_addresses.join(',')

        pm = self['_connection'].serviceInstance.content.perfManager

        provider = pm.provider_summary(@item)

        refresh_rate = provider.refreshRate

        if get_vm_id
            stats = {}

            if (one_item["MONITORING/LAST_MON"] && one_item["MONITORING/LAST_MON"].to_i != 0 )
                #Real time data stores max 1 hour. 1 minute has 3 samples
                interval = (Time.now.to_i - one_item["MONITORING/LAST_MON"].to_i)

                #If last poll was more than hour ago get 3 minutes,
                #else calculate how many samples since last poll
                samples =  interval > 3600 ? 9 : (interval / refresh_rate) + 1
                max_samples = samples > 0 ? samples : 1

                stats = pm.retrieve_stats(
                    [@item],
                    ['net.transmitted','net.bytesRx','net.bytesTx','net.received',
                    'virtualDisk.numberReadAveraged','virtualDisk.numberWriteAveraged',
                    'virtualDisk.read','virtualDisk.write'],
                    {interval:refresh_rate, max_samples: max_samples}
                ) rescue {}
            else
                # First poll, get at least latest 3 minutes = 9 samples
                stats = pm.retrieve_stats(
                    [@item],
                    ['net.transmitted','net.bytesRx','net.bytesTx','net.received',
                    'virtualDisk.numberReadAveraged','virtualDisk.numberWriteAveraged',
                    'virtualDisk.read','virtualDisk.write'],
                    {interval:refresh_rate, max_samples: 9}
                ) rescue {}
            end

            if !stats.empty? && !stats.first[1][:metrics].empty?
                metrics = stats.first[1][:metrics]

                nettx_kbpersec = 0
                if metrics['net.transmitted']
                    metrics['net.transmitted'].each { |sample|
                        nettx_kbpersec += sample if sample > 0
                    }
                end

                netrx_kbpersec = 0
                if metrics['net.bytesRx']
                    metrics['net.bytesRx'].each { |sample|
                        netrx_kbpersec += sample if sample > 0
                    }
                end

                read_kbpersec = 0
                if metrics['virtualDisk.read']
                    metrics['virtualDisk.read'].each { |sample|
                        read_kbpersec += sample if sample > 0
                    }
                end

                read_iops = 0
                if metrics['virtualDisk.numberReadAveraged']
                    metrics['virtualDisk.numberReadAveraged'].each { |sample|
                        read_iops += sample if sample > 0
                    }
                end

                write_kbpersec = 0
                if metrics['virtualDisk.write']
                    metrics['virtualDisk.write'].each { |sample|
                        write_kbpersec += sample if sample > 0
                    }
                end

                write_iops = 0
                if metrics['virtualDisk.numberWriteAveraged']
                    metrics['virtualDisk.numberWriteAveraged'].each { |sample|
                        write_iops += sample if sample > 0
                    }
                end
            else
                nettx_kbpersec = 0
                netrx_kbpersec = 0
                read_kbpersec  = 0
                read_iops      = 0
                write_kbpersec = 0
                write_iops     = 0
            end

            # Accumulate values if present
            previous_nettx = @one_item && @one_item["MONITORING/NETTX"] ? @one_item["MONITORING/NETTX"].to_i : 0
            previous_netrx = @one_item && @one_item["MONITORING/NETRX"] ? @one_item["MONITORING/NETRX"].to_i : 0
            previous_diskrdiops = @one_item && @one_item["MONITORING/DISKRDIOPS"] ? @one_item["MONITORING/DISKRDIOPS"].to_i : 0
            previous_diskwriops = @one_item && @one_item["MONITORING/DISKWRIOPS"] ? @one_item["MONITORING/DISKWRIOPS"].to_i : 0
            previous_diskrdbytes = @one_item && @one_item["MONITORING/DISKRDBYTES"] ? @one_item["MONITORING/DISKRDBYTES"].to_i : 0
            previous_diskwrbytes = @one_item && @one_item["MONITORING/DISKWRBYTES"] ? @one_item["MONITORING/DISKWRBYTES"].to_i : 0

            @monitor[:nettx] = previous_nettx + (nettx_kbpersec * 1024 * refresh_rate).to_i
            @monitor[:netrx] = previous_netrx + (netrx_kbpersec * 1024 * refresh_rate).to_i

            @monitor[:diskrdiops]  = previous_diskrdiops + read_iops
            @monitor[:diskwriops]  = previous_diskwriops + write_iops
            @monitor[:diskrdbytes] = previous_diskrdbytes + (read_kbpersec * 1024 * refresh_rate).to_i
            @monitor[:diskwrbytes] = previous_diskwrbytes + (write_kbpersec * 1024 * refresh_rate).to_i
        end
    end

    # monitor function used when poll action is called for all vms
    def monitor(stats)

        reset_monitor

        refresh_rate = 20 #20 seconds between samples (realtime)

        @state = state_to_c(@vm_info["summary.runtime.powerState"])

        return if @state != VM_STATE[:active]

        cpuMhz =  @vm_info[:esx_host_cpu]

        @monitor[:used_memory] = @vm_info["summary.quickStats.hostMemoryUsage"].to_i * 1024

        used_cpu = @vm_info["summary.quickStats.overallCpuUsage"].to_f / cpuMhz
        used_cpu = (used_cpu * 100).to_s
        @monitor[:used_cpu]  = sprintf('%.2f', used_cpu).to_s

        # Check for negative values
        @monitor[:used_memory] = 0 if @monitor[:used_memory].to_i < 0
        @monitor[:used_cpu]    = 0 if @monitor[:used_cpu].to_i < 0

        guest_ip_addresses = []
        @vm_info["guest.net"].each do |net|
            net.ipConfig.ipAddress.each do |ip|
                guest_ip_addresses << ip.ipAddress
            end if net.ipConfig && net.ipConfig.ipAddress
        end if self["guest.net"]

        @guest_ip_addresses = guest_ip_addresses.join(',')

        if stats.key?(@item)
            metrics = stats[@item][:metrics]

            nettx_kbpersec = 0
            if metrics['net.transmitted']
                metrics['net.transmitted'].each { |sample|
                    nettx_kbpersec += sample if sample > 0
                }
            end

            netrx_kbpersec = 0
            if metrics['net.bytesRx']
                metrics['net.bytesRx'].each { |sample|
                    netrx_kbpersec += sample if sample > 0
                }
            end

            read_kbpersec = 0
            if metrics['virtualDisk.read']
                metrics['virtualDisk.read'].each { |sample|
                    read_kbpersec += sample if sample > 0
                }
            end

            read_iops = 0
            if metrics['virtualDisk.numberReadAveraged']
                metrics['virtualDisk.numberReadAveraged'].each { |sample|
                    read_iops += sample if sample > 0
                }
            end

            write_kbpersec = 0
            if metrics['virtualDisk.write']
                metrics['virtualDisk.write'].each { |sample|
                    write_kbpersec += sample if sample > 0
                }
            end

            write_iops = 0
            if metrics['virtualDisk.numberWriteAveraged']
                metrics['virtualDisk.numberWriteAveraged'].each { |sample|
                    write_iops += sample if sample > 0
                }
            end
        else
            nettx_kbpersec = 0
            netrx_kbpersec = 0
            read_kbpersec  = 0
            read_iops      = 0
            write_kbpersec = 0
            write_iops     = 0
        end

        # Accumulate values if present
        previous_nettx = @one_item && @one_item["MONITORING/NETTX"] ? @one_item["MONITORING/NETTX"].to_i : 0
        previous_netrx = @one_item && @one_item["MONITORING/NETRX"] ? @one_item["MONITORING/NETRX"].to_i : 0
        previous_diskrdiops = @one_item && @one_item["MONITORING/DISKRDIOPS"] ? @one_item["MONITORING/DISKRDIOPS"].to_i : 0
        previous_diskwriops = @one_item && @one_item["MONITORING/DISKWRIOPS"] ? @one_item["MONITORING/DISKWRIOPS"].to_i : 0
        previous_diskrdbytes = @one_item && @one_item["MONITORING/DISKRDBYTES"] ? @one_item["MONITORING/DISKRDBYTES"].to_i : 0
        previous_diskwrbytes = @one_item && @one_item["MONITORING/DISKWRBYTES"] ? @one_item["MONITORING/DISKWRBYTES"].to_i : 0

        @monitor[:nettx] = previous_nettx + (nettx_kbpersec * 1024 * refresh_rate).to_i
        @monitor[:netrx] = previous_netrx + (netrx_kbpersec * 1024 * refresh_rate).to_i

        @monitor[:diskrdiops]  = previous_diskrdiops + read_iops
        @monitor[:diskwriops]  = previous_diskwriops + write_iops
        @monitor[:diskrdbytes] = previous_diskrdbytes + (read_kbpersec * 1024 * refresh_rate).to_i
        @monitor[:diskwrbytes] = previous_diskwrbytes + (write_kbpersec * 1024 * refresh_rate).to_i
    end



    #  Generates a OpenNebula IM Driver valid string with the monitor info
    def info
        return 'STATE=d' if @state == 'd'

        guest_ip = @vm_info ? @vm_info["guest.ipAddress"] : self["guest.ipAddress"]

        used_cpu    = @monitor[:used_cpu]
        used_memory = @monitor[:used_memory]
        netrx       = @monitor[:netrx]
        nettx       = @monitor[:nettx]
        diskrdbytes = @monitor[:diskrdbytes]
        diskwrbytes = @monitor[:diskwrbytes]
        diskrdiops  = @monitor[:diskrdiops]
        diskwriops  = @monitor[:diskwriops]

        esx_host      = @vm_info ? @vm_info[:esx_host_name].to_s : self["runtime.host.name"].to_s
        guest_state   = @vm_info ? @vm_info["guest.guestState"].to_s : self["guest.guestState"].to_s
        vmware_tools  = @vm_info ? @vm_info["guest.toolsRunningStatus"].to_s : self["guest.toolsRunningStatus"].to_s
        vmtools_ver   = @vm_info ? @vm_info["guest.toolsVersion"].to_s :  self["guest.toolsVersion"].to_s
        vmtools_verst = @vm_info ? @vm_info["guest.toolsVersionStatus2"].to_s : vmtools_verst = self["guest.toolsVersionStatus2"].to_s

        if @vm_info
            rp_name   = @vm_info[:rp_list].select { |item| item[:ref] == @vm_info["resourcePool"]._ref}.first[:name] rescue ""
            rp_name   = "Resources" if rp_name.empty?
        else
            rp_name   = self["resourcePool"].name
        end

        str_info = ""

        str_info = "GUEST_IP=" << guest_ip.to_s << " " if guest_ip

        if @guest_ip_addresses && !@guest_ip_addresses.empty?
            str_info << "GUEST_IP_ADDRESSES=\"" << @guest_ip_addresses.to_s << "\" "
        end

        str_info << "#{POLL_ATTRIBUTE[:state]}="  << @state               << " "
        str_info << "#{POLL_ATTRIBUTE[:cpu]}="    << used_cpu.to_s        << " "
        str_info << "#{POLL_ATTRIBUTE[:memory]}=" << used_memory.to_s     << " "
        str_info << "#{POLL_ATTRIBUTE[:netrx]}="  << netrx.to_s           << " "
        str_info << "#{POLL_ATTRIBUTE[:nettx]}="  << nettx.to_s           << " "

        str_info << "DISKRDBYTES=" << diskrdbytes.to_s << " "
        str_info << "DISKWRBYTES=" << diskwrbytes.to_s << " "
        str_info << "DISKRDIOPS="  << diskrdiops.to_s  << " "
        str_info << "DISKWRIOPS="  << diskwriops.to_s  << " "

        str_info << "VCENTER_ESX_HOST=\""                 << esx_host        << "\" "
        str_info << "VCENTER_GUEST_STATE="                << guest_state     << " "
        str_info << "VCENTER_VMWARETOOLS_RUNNING_STATUS=" << vmware_tools    << " "
        str_info << "VCENTER_VMWARETOOLS_VERSION="        << vmtools_ver     << " "
        str_info << "VCENTER_VMWARETOOLS_VERSION_STATUS=" << vmtools_verst   << " "
        str_info << "VCENTER_RP_NAME=\""                  << rp_name << "\" "
    end

    def reset_monitor
        @monitor = {
            :used_cpu    => 0,
            :used_memory => 0,
            :netrx       => 0,
            :nettx       => 0,
            :diskrdbytes => 0,
            :diskwrbytes => 0,
            :diskrdiops  => 0,
            :diskwriops  => 0
        }
    end

    # Converts the VI string state to OpenNebula state convention
    # Guest states are:
    # - poweredOff   The virtual machine is currently powered off.
    # - poweredOn    The virtual machine is currently powered on.
    # - suspended    The virtual machine is currently suspended.
    def state_to_c(state)
        case state
            when 'poweredOn'
                VM_STATE[:active]
            when 'suspended'
                VM_STATE[:paused]
            when 'poweredOff'
                VM_STATE[:deleted]
            else
                VM_STATE[:unknown]
        end
    end

    # STATIC MEMBERS, ROUTINES AND CONSTRUCTORS
    ###############################################################################################

    def self.get_vm(opts = {})
        # try to retrieve machine from name
        if (opts[:name])
                matches = opts[:name].match(/^one-(\d*)(-(.*))?$/)
                if matches
                    id = matches[1]
                    one_vm = VCenterDriver::VIHelper.one_item(OpenNebula::VirtualMachine, id, false)
                end
        end

        if one_vm.nil?
            one_vm = VCenterDriver::VIHelper.find_by_ref(OpenNebula::VirtualMachinePool,
                                                         "DEPLOY_ID",
                                                         opts[:ref],
                                                         opts[:vc_uuid],
                                                         opts[:pool])
        end

        return one_vm
    end

    # Migrate a VM to another cluster and/or datastore
    # @params [int] vm_id ID of the VM to be migrated
    # params [String] src_host Name of the source cluster
    # params [String] dst_host Name of the target cluster
    # params [Bool] hot_ds Wether this is a DS migration with the VM running or not
    # params [int] ds Destination datastore ID
    def self.migrate_routine(vm_id, src_host, dst_host, hot_ds = false, ds = nil)
        one_client = OpenNebula::Client.new
        pool = OpenNebula::HostPool.new(one_client)
        pool.info

        src_id = pool["/HOST_POOL/HOST[NAME='#{src_host}']/ID"].to_i
        dst_id = pool["/HOST_POOL/HOST[NAME='#{dst_host}']/ID"].to_i

        # different destination ds
        if ds
            ds_pool = OpenNebula::DatastorePool.new(one_client)
            ds_pool.info
            datastore = ds_pool["/DATASTORE_POOL/DATASTORE[ID='#{ds}']/TEMPLATE/VCENTER_DS_REF"]
        end

        vi_client = VCenterDriver::VIClient.new_from_host(src_id)

        # required one objects
        vm = OpenNebula::VirtualMachine.new_with_id(vm_id, one_client)
        dst_host = OpenNebula::Host.new_with_id(dst_id, one_client)

        # get info
        vm.info
        dst_host.info

        esx_migration_list = dst_host['/HOST/TEMPLATE/ESX_MIGRATION_LIST']

        # required vcenter objects
        vc_vm = VCenterDriver::VirtualMachine.new_without_id(vi_client, vm['/VM/DEPLOY_ID'])

        vc_vm.vm_id = vm_id

        ccr_ref  = dst_host['/HOST/TEMPLATE/VCENTER_CCR_REF']
        vc_host  = VCenterDriver::ClusterComputeResource.new_from_ref(ccr_ref, vi_client)

        config = { :cluster => vc_host }

        config[:datastore] = datastore if datastore
        if hot_ds
            config[:esx_migration_list] = esx_migration_list if esx_migration_list
        else
            config[:esx_migration_list] = "Selected_by_DRS"
        end

        vc_vm.migrate(config)

        vm.replace({ 'VCENTER_CCR_REF' => ccr_ref})
    end

    # Try to build the vcenterdriver virtualmachine without
    # any opennebula id or object, this constructor can find
    # inside the opennebula pool until match
    #
    # @param vi_client [vi_client] the vcenterdriver client that allows the connection
    # @param ref [String] vcenter ref to the vm
    # @param opts [Hash] object with pairs that could contain multiple option
    #        :vc_uuid: give the vcenter uuid directly
    #        :name:    the vcenter vm name for extract the opennebula id
    #
    # @return [vcenterdriver::vm] the virtual machine
    def self.new_from_ref(vi_client, ref, name, opts = {})
        unless opts[:vc_uuid]
            opts[:vc_uuid] = vi_client.vim.serviceContent.about.instanceUuid
        end

        opts[:name] = name
        opts[:ref]  = ref

        one_vm = VCenterDriver::VirtualMachine.get_vm(opts)

        self.new_one(vi_client, ref, one_vm)
    end

    # build a vcenterdriver virtual machine from a template
    # this function is used to instantiate vcenter vms
    #
    # @param vi_client [vi_client] the vcenterdriver client that allows the connection
    # @param drv_action [xmleleent] driver_action that contains the info
    # @param id [int] the if of the opennebula virtual machine
    #
    # @return [vcenterdriver::vm] the virtual machine
    def self.new_from_clone(vi_client, drv_action, id )
        spawn = self.new(vi_client, nil, id).tap do |vm|
            vm.clone_vm(drv_action)
        end

        return spawn
    end

    # build a vcenterdriver virtual machine
    # with the vmware item already linked
    #
    # @param vm_item the vmware VM item that it's going to be associated
    #
    # @return [vcenterdriver::vm] the virtual machine
    def self.new_with_item(vm_item)
        self.new(nil, nil, -1).tap do |vm|
            vm.set_item(vm_item)
        end
    end

    # build a vcenterdriver virtual machine
    # with the opennebula object linked
    #
    # @param vi_client [vi_client] the vcenterdriver client that allows the connection
    # @param ref [String] vcenter ref to the vm
    # @param one_item [one::vm] xmlelement of opennebula
    #
    # @return [vcenterdriver::vm] the virtual machine
    def self.new_one(vi_client, ref, one_item)
        id = one_item["ID"] || one_item["VM/ID"] rescue -1

        self.new(vi_client, ref, id).tap do |vm|
            if one_item.instance_of?(OpenNebula::VirtualMachine)
                vm.one_item = one_item
            end
        end
    end

    # build a vcenterdriver virtual machine
    # without opennebula object link, use id = -1 instead
    #
    # @param vi_client [vi_client] the vcenterdriver client that allows the connection
    # @param ref [String] vcenter ref to the vm
    #
    # @return [vcenterdriver::vm] the virtual machine
    def self.new_without_id(vi_client, ref)
        self.new(vi_client, ref, -1)
    end

    ###############################################################################################
end # class VirtualMachine

class VmmImporter < VCenterDriver::VcImporter
    def initialize(one_client, vi_client)
        super(one_client, vi_client)
        @one_class = OpenNebula::VirtualMachine
        @defaults = {}
    end

    def list(key, list)
        @list = {"" => list}
    end

    def request_vnc(vc_vm)
        one_vm = vc_vm.one_item
        vnc_port  = one_vm["TEMPLATE/GRAPHICS/PORT"]
        elapsed_seconds = 0

        # Let's update the info to gather VNC port
        until vnc_port || elapsed_seconds > 30
            sleep(1)
            one_vm.info
            vnc_port  = one_vm["TEMPLATE/GRAPHICS/PORT"]
            elapsed_seconds += 1
        end

        if vnc_port
            extraconfig   = []
            extraconfig  += vc_vm.extraconfig_vnc
            spec_hash     = { :extraConfig  => extraconfig }
            spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)
            vc_vm.item.ReconfigVM_Task(:spec => spec).wait_for_completion
        end
    end

    def build
        xml = OpenNebula::VirtualMachine.build_xml
        vm = OpenNebula::VirtualMachine.new(xml, @one_client)
    end

    def import(selected)
        vm_ref     = selected["DEPLOY_ID"] || selected[:wild]["DEPLOY_ID"]
        vm         = selected[:one_item]   || build
        template   = selected[:template]   || Base64.decode64(selected['IMPORT_TEMPLATE'])
        host_id    = selected[:host]       || @list.keys[0]

        vc_uuid    = @vi_client.vim.serviceContent.about.instanceUuid
        vc_name    = @vi_client.vim.host
        dpool, ipool, npool, hpool = create_pools

        vc_vm = VCenterDriver::VirtualMachine.new_without_id(@vi_client, vm_ref)
        vname = vc_vm['name']

        type = {:object => "VM", :id => vname}
        error, template_disks = vc_vm.import_vcenter_disks(vc_uuid, dpool, ipool, type)
        raise error if !error.empty?

        template << template_disks

        # Create images or get nics information for template
        error, template_nics, ar_ids = vc_vm
                                       .import_vcenter_nics(vc_uuid,
                                                            npool,
                                                            hpool,
                                                            vc_name,
                                                            vm_ref)
        opts = {uuid: vc_uuid, npool: npool, error: error }
        Raction.delete_ars(ar_ids, opts) if !error.empty?

        template << template_nics
        template << "VCENTER_ESX_HOST = #{vc_vm["runtime.host.name"].to_s}\n"

        # Get DS_ID for the deployment, the wild VM needs a System DS
        dc_ref = vc_vm.get_dc.item._ref
        ds_ref = template.match(/^VCENTER_DS_REF *= *"(.*)" *$/)[1]

        ds_one = dpool.select do |e|
            e["TEMPLATE/TYPE"]                == "SYSTEM_DS" &&
            e["TEMPLATE/VCENTER_DS_REF"]      == ds_ref &&
            e["TEMPLATE/VCENTER_DC_REF"]      == dc_ref &&
            e["TEMPLATE/VCENTER_INSTANCE_ID"] == vc_uuid
        end.first
        opts[:error] = "ds with ref #{ds_ref} is not imported, aborting"
        Raction.delete_ars(ar_ids, opts) if !ds_one

        rc = vm.allocate(template)
        if OpenNebula.is_error?(rc)
            Raction.delete_ars(ar_ids, opts.merge({error: rc.message}))
        end

        rc = vm.deploy(host_id, false, ds_one.id)
        if OpenNebula.is_error?(rc)
            Raction.delete_ars(ar_ids, opts.merge({error: rc.message}))
        end

        # Set reference to template disks and nics in VM template
        vc_vm.one_item = vm

        request_vnc(vc_vm)

        return vm.id
    end
end

end # module VCenterDriver
