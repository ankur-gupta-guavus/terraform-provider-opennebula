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

require 'one_helper'
require 'one_helper/onevm_helper'
require 'rubygems'

# implements onehost command
class OneHostHelper < OpenNebulaHelper::OneHelper

    TEMPLATE_XPATH = '//HOST/TEMPLATE'
    HYBRID = {
        :ec2 => {
            :help => <<-EOT.unindent
                #-----------------------------------------------------------------------
                # Supported EC2 AUTH ATTRIBUTTES:
                #
                #  REGION_NAME = <the name of the ec2 region>
                #
                #  EC2_ACCESS = <Your ec2 access key id>
                #  EC2_SECRET = <Your ec2 secret key>
                #
                #  CAPACITY = [
                #    M1_SMALL  = <number of machines m1.small>,
                #    M1_XLARGE = <number of machines m1.xlarge>,
                #    M1_LARGE  = <number of machines m1.large>
                #  ]
                #
                # You can set any machine type supported by ec2
                # See your ec2_driver.conf for more information
                #
                #-----------------------------------------------------------------------
            EOT
        },
        :az => {
            :help => <<-EOT.unindent
                #-----------------------------------------------------------------------
                # Supported AZURE AUTH ATTRIBUTTES:
                #
                #  AZ_ID   = <azure classic id>
                #  AZ_CERT = <azure classic certificate>
                #
                #  REGION_NAME = <the name of the azure region>
                #
                #  CAPACITY = [
                #    Small = <number of small machines>,
                #    Medium = <number of medium machines>,
                #    Large = <number of large machines
                #  ]
                #
                # You can set any machine type supported by azure classic
                # See your az_driver.conf for more information
                #
                # Optionally you can set a endpoint
                #
                #  AZ_ENDPOINT = <endpoint address>
                #
                #-----------------------------------------------------------------------
            EOT
        }
    }

    VERSION_XPATH = "#{TEMPLATE_XPATH}/VERSION"

    def self.rname
        'HOST'
    end

    def self.conf_file
        'onehost.yaml'
    end

    def self.state_to_str(id)
        id        = id.to_i
        state_str = Host::HOST_STATES[id]

        Host::SHORT_HOST_STATES[state_str]
    end

    def format_pool(options)
        config_file = self.class.table_conf

        table = CLIHelper::ShowTable.new(config_file, self) do
            column :ID, 'ONE identifier for Host', :size => 4 do |d|
                d['ID']
            end

            column :NAME, 'Name of the Host', :left, :size => 15 do |d|
                d['NAME']
            end

            column :CLUSTER, 'Name of the Cluster', :left, :size => 9 do |d|
                OpenNebulaHelper.cluster_str(d['CLUSTER'])
            end

            column :TVM, 'Total Virtual Machines allocated to the Host',
                   :size => 3 do |d|
                d['HOST_SHARE']['RUNNING_VMS'] || 0
            end

            column :ZVM, 'Number of Virtual Machine zombies', :size => 3 do |d|
                d['TEMPLATE']['TOTAL_ZOMBIES'] || 0
            end

            column :TCPU, 'Total CPU percentage', :size => 4 do |d|
                d['HOST_SHARE']['MAX_CPU'] || 0
            end

            column :FCPU, 'Free CPU percentage', :size => 4 do |d|
                d['HOST_SHARE']['MAX_CPU'].to_i -
                    d['HOST_SHARE']['USED_CPU'].to_i rescue '-'
            end

            column :ACPU, 'Available cpu percentage (not reserved by VMs)',
                   :size => 4 do |d|
                max_cpu = d['HOST_SHARE']['MAX_CPU'].to_i
                max_cpu = 100 if max_cpu.zero?
                max_cpu - d['HOST_SHARE']['CPU_USAGE'].to_i
            end

            column :TMEM, 'Total Memory', :size => 7 do |d|
                OpenNebulaHelper.unit_to_str(
                    d['HOST_SHARE']['MAX_MEM'].to_i,
                    options
                ) rescue '-'
            end

            column :FMEM, 'Free Memory', :size => 7 do |d|
                OpenNebulaHelper.unit_to_str(
                    d['HOST_SHARE']['FREE_MEM'].to_i,
                    options
                ) rescue '-'
            end

            column :AMEM, 'Available Memory (not reserved by VMs)',
                   :size => 7 do |d|
                acpu = d['HOST_SHARE']['MAX_MEM'].to_i -
                       d['HOST_SHARE']['MEM_USAGE'].to_i
                OpenNebulaHelper.unit_to_str(acpu, options)
            end

            column :REAL_CPU, 'Real CPU', :size => 18 do |d|
                max_cpu = d['HOST_SHARE']['MAX_CPU'].to_i

                if max_cpu != 0
                    used_cpu = d['HOST_SHARE']['USED_CPU'].to_i
                    ratio    = (used_cpu * 100) / max_cpu
                    "#{used_cpu} / #{max_cpu} (#{ratio}%)"
                else
                    '-'
                end
            end

            column :ALLOCATED_CPU, 'Allocated CPU)', :size => 18 do |d|
                max_cpu = d['HOST_SHARE']['MAX_CPU'].to_i
                cpu_usage = d['HOST_SHARE']['CPU_USAGE'].to_i

                if max_cpu.zero? && cpu_usage.zero?
                    '-'
                else
                    cpu_usage = d['HOST_SHARE']['CPU_USAGE'].to_i

                    if max_cpu != 0
                        ratio = (cpu_usage * 100) / max_cpu
                        "#{cpu_usage} / #{max_cpu} (#{ratio}%)"
                    else
                        "#{cpu_usage} / -"
                    end
                end
            end

            column :REAL_MEM, 'Real MEM', :size => 18 do |d|
                max_mem = d['HOST_SHARE']['MAX_MEM'].to_i

                if max_mem != 0
                    used_mem = d['HOST_SHARE']['USED_MEM'].to_i
                    ratio    = (used_mem * 100) / max_mem
                    "#{OpenNebulaHelper.unit_to_str(used_mem, options)} / "\
                        "#{OpenNebulaHelper.unit_to_str(max_mem, options)} "\
                        "(#{ratio}%)"
                else
                    '-'
                end
            end

            column :ALLOCATED_MEM, 'Allocated MEM', :size => 18 do |d|
                max_mem = d['HOST_SHARE']['MAX_MEM'].to_i
                mem_usage = d['HOST_SHARE']['MEM_USAGE'].to_i

                if max_mem.zero? && mem_usage.zero?
                    '-'
                elsif max_mem != 0
                    ratio = (mem_usage * 100) / max_mem
                    "#{OpenNebulaHelper.unit_to_str(mem_usage, options)} / "\
                        "#{OpenNebulaHelper.unit_to_str(max_mem, options)} "\
                        "(#{ratio}%)"
                else
                    "#{OpenNebulaHelper.unit_to_str(mem_usage, options)} / -"
                end
            end

            column :PROVIDER, 'Host provider', :left, :size => 6 do |d|
                d['TEMPLATE']['PM_MAD'].nil? ? '-' : d['TEMPLATE']['PM_MAD']
            end

            column :STAT, 'Host status', :left, :size => 6 do |d|
                OneHostHelper.state_to_str(d['STATE'])
            end

            default :ID, :NAME, :CLUSTER, :TVM,
                    :ALLOCATED_CPU, :ALLOCATED_MEM, :STAT
        end

        table
    end

    def set_hybrid(type, path)
        k = type.to_sym

        return unless HYBRID.key?(k)

        return OpenNebulaHelper.editor_input(HYBRID[k][:help]) if path.nil?

        File.read(path)
    end

    NUM_THREADS = 15
    def sync(host_ids, options)
        if Process.uid.zero? || Process.gid.zero?
            STDERR.puts("Cannot run 'onehost sync' as root")
            exit(-1)
        end

        begin
            current_version = File.read(REMOTES_LOCATION + '/VERSION').strip
        rescue StandardError
            STDERR.puts("Could not read #{REMOTES_LOCATION}/VERSION")
            exit(-1)
        end

        if current_version.empty?
            STDERR.puts 'Remotes version can not be empty'
            exit(-1)
        end

        begin
            current_version = Gem::Version.new(current_version)
        rescue StandardError
            STDERR.puts 'VERSION file is malformed, use semantic versioning.'
        end

        cluster_id = options[:cluster]

        # Get remote_dir (implies oneadmin group)
        rc = OpenNebula::System.new(@client).get_configuration
        return -1, rc.message if OpenNebula.is_error?(rc)

        conf = rc
        remote_dir = conf['SCRIPTS_REMOTE_DIR']

        # Verify the existence of REMOTES_LOCATION
        if !File.directory? REMOTES_LOCATION
            error_msg = "'#{REMOTES_LOCATION}' does not exist. " \
                        'This command must be run in the frontend.'
            return -1, error_msg
        end

        # Touch the update file
        FileUtils.touch(File.join(REMOTES_LOCATION, '.update'))

        # Get the Host pool
        filter_flag ||= OpenNebula::Pool::INFO_ALL

        pool = factory_pool(filter_flag)

        rc = pool.info
        return -1, rc.message if OpenNebula.is_error?(rc)

        # Assign hosts to threads
        queue = []

        pool.each do |host|
            if host_ids
                next unless host_ids.include?(host['ID'].to_i)
            elsif cluster_id
                next if host['CLUSTER_ID'].to_i != cluster_id
            end

            vm_mad = host['VM_MAD'].downcase
            state = host['STATE']

            # Skip this host from remote syncing if it's a PUBLIC_CLOUD host
            next if host['TEMPLATE/PUBLIC_CLOUD'] == 'YES'

            # Skip this host from remote syncing if it's OFFLINE
            next if Host::HOST_STATES[state.to_i] == 'OFFLINE'

            # Skip this host if it is a vCenter cluster
            next if vm_mad == 'vcenter'

            host_version = host['TEMPLATE/VERSION']

            begin
                host_version = Gem::Version.new(host_version)
            rescue StandardError
                nil
            end

            if !options[:force]
                begin
                    next if host_version && host_version >= current_version
                rescue StandardError
                    STDERR.puts 'Error comparing versions '\
                                " for host #{host['NAME']}."
                end
            end

            puts "* Adding #{host['NAME']} to upgrade"

            queue << host
        end

        # Run the jobs in threads
        host_errors = []
        queue_lock = Mutex.new
        error_lock = Mutex.new
        total = queue.length

        if total.zero?
            puts 'No hosts are going to be updated.'
            exit(0)
        end

        ts = (1..NUM_THREADS).map do |_t|
            Thread.new do
                loop do
                    host = nil
                    size = 0

                    queue_lock.synchronize do
                        host = queue.shift
                        size = queue.length
                    end

                    break unless host

                    print_update_info(total - size, total, host['NAME'])

                    if options[:rsync]
                        sync_cmd = "rsync -Laz --delete #{REMOTES_LOCATION}" \
                                   " #{host['NAME']}:#{remote_dir}"
                    else
                        sync_cmd = "ssh #{host['NAME']}" \
                                   " mkdir -p '#{remote_dir}' 2>/dev/null &&" \
                                   " scp -rp #{REMOTES_LOCATION}/*" \
                                   " #{host['NAME']}:#{remote_dir} 2> /dev/null"
                    end

                    retries = 3

                    begin
                        `#{sync_cmd} 2>/dev/null`
                    rescue IOError
                        # Workaround for broken Ruby 2.5
                        # https://github.com/OpenNebula/one/issues/3229
                        if (retries -= 1) > 0
                            sleep 1
                            retry
                        end
                    end

                    if $CHILD_STATUS.nil? || !$CHILD_STATUS.success?
                        error_lock.synchronize do
                            host_errors << host['NAME']
                        end
                    else
                        update_version(host, current_version)
                    end
                end
            end
        end

        # Wait for threads to finish
        ts.each {|t| t.join }

        puts

        if host_errors.empty?
            puts 'All hosts updated successfully.'
            0
        else
            STDERR.puts 'Failed to update the following hosts:'
            host_errors.each {|h| STDERR.puts "* #{h}" }
            -1
        end
    end

    def forceupdate(host_ids, options)
        if Process.uid.zero? || Process.gid.zero?
            STDERR.puts("Cannot run 'onehost forceupdate' as root")
            exit(-1)
        end

        cluster_id = options[:cluster]

        # Get the Host pool
        filter_flag ||= OpenNebula::Pool::INFO_ALL

        pool = factory_pool(filter_flag)

        rc = pool.info
        return -1, rc.message if OpenNebula.is_error?(rc)

        # Assign hosts to threads
        queue = []

        pool.each do |host|
            if host_ids
                next unless host_ids.include?(host['ID'].to_i)
            elsif cluster_id
                next if host['CLUSTER_ID'].to_i != cluster_id
            end

            vm_mad = host['VM_MAD'].downcase
            state = host['STATE']

            # Skip this host from remote syncing if it's a PUBLIC_CLOUD host
            next if host['TEMPLATE/PUBLIC_CLOUD'] == 'YES'

            # Skip this host from remote syncing if it's OFFLINE
            next if Host::HOST_STATES[state.to_i] == 'OFFLINE'

            # Skip this host if it is a vCenter cluster
            next if vm_mad == 'vcenter'

            queue << host
        end

        # Run the jobs in threads
        host_errors = []
        queue_lock = Mutex.new
        error_lock = Mutex.new
        total = queue.length

        if total.zero?
            puts 'No hosts are going to be forced.'
            exit(0)
        end

        ts = (1..NUM_THREADS).map do |_t|
            Thread.new do
                loop do
                    host = nil
                    size = 0

                    queue_lock.synchronize do
                        host = queue.shift
                        size = queue.length
                    end

                    break unless host

                    cmd = 'cat /tmp/one-collectd-client.pid | xargs kill -HUP'
                    system("ssh #{host['NAME']} \"#{cmd}\" 2>/dev/null")

                    if !$CHILD_STATUS.success?
                        error_lock.synchronize do
                            host_errors << host['NAME']
                        end
                    else
                        puts "#{host['NAME']} monitoring forced"
                    end
                end
            end
        end

        # Wait for threads to finish
        ts.each {|t| t.join }

        if host_errors.empty?
            puts 'All hosts updated successfully.'
            0
        else
            STDERR.puts 'Failed to update the following hosts:'
            host_errors.each {|h| STDERR.puts "* #{h}" }
            -1
        end
    end

    private

    def print_update_info(current, total, host)
        bar_length = 40

        percentage = current.to_f / total.to_f
        done = (percentage * bar_length).floor

        bar = '['
        bar += '=' * done
        bar += '-' * (bar_length - done)
        bar += ']'

        info = "#{current}/#{total}"

        str = "#{bar} #{info} "
        name = host[0..(79 - str.length)]
        str += name
        str += ' ' * (80 - str.length)

        print "#{str}\r"
        STDOUT.flush
    end

    def update_version(host, version)
        if host.has_elements?(VERSION_XPATH)
            host.delete_element(VERSION_XPATH)
        end

        host.add_element(TEMPLATE_XPATH, 'VERSION' => version)

        template = host.template_str
        host.update(template)
    end

    def factory(id = nil)
        if id
            OpenNebula::Host.new_with_id(id, @client)
        else
            xml = OpenNebula::Host.build_xml
            OpenNebula::Host.new(xml, @client)
        end
    end

    def factory_pool(_user_flag = -2)
        # TBD OpenNebula::HostPool.new(@client, user_flag)
        OpenNebula::HostPool.new(@client)
    end

    def format_resource(host, _options = {})
        str    = '%-22s: %-20s'
        str_h1 = '%-80s'

        CLIHelper.print_header(
            str_h1 % "HOST #{host.id} INFORMATION", true
        )

        puts format(str, 'ID', host.id.to_s)
        puts format(str, 'NAME', host.name)
        puts format(str, 'CLUSTER',
                    OpenNebulaHelper.cluster_str(host['CLUSTER']))
        puts format(str, 'STATE', host.state_str)
        puts format(str, 'IM_MAD', host['IM_MAD'])
        puts format(str, 'VM_MAD', host['VM_MAD'])
        puts format(str, 'LAST MONITORING TIME',
                    OpenNebulaHelper.time_to_str(host['LAST_MON_TIME']))
        puts

        CLIHelper.print_header(str_h1 % 'HOST SHARES', false)
        puts format(str, 'RUNNING VMS', host['HOST_SHARE/RUNNING_VMS'])

        CLIHelper.print_header(str_h1 % 'MEMORY', false)
        puts format(str, '  TOTAL',
                    OpenNebulaHelper.unit_to_str(host['HOST_SHARE/TOTAL_MEM']
                                    .to_i, {}))
        puts format(str, '  TOTAL +/- RESERVED',
                    OpenNebulaHelper.unit_to_str(host['HOST_SHARE/MAX_MEM']
                                    .to_i, {}))
        puts format(str, '  USED (REAL)',
                    OpenNebulaHelper.unit_to_str(host['HOST_SHARE/USED_MEM']
                                    .to_i, {}))
        puts format(str, '  USED (ALLOCATED)',
                    OpenNebulaHelper.unit_to_str(host['HOST_SHARE/MEM_USAGE']
                                    .to_i, {}))

        CLIHelper.print_header(str_h1 % 'CPU', false)
        puts format(str, '  TOTAL', host['HOST_SHARE/TOTAL_CPU'])
        puts format(str, '  TOTAL +/- RESERVED', host['HOST_SHARE/MAX_CPU'])
        puts format(str, '  USED (REAL)', host['HOST_SHARE/USED_CPU'])
        puts format(str, '  USED (ALLOCATED)', host['HOST_SHARE/CPU_USAGE'])
        puts

        datastores = host.to_hash['HOST']['HOST_SHARE']['DATASTORES']['DS']

        if datastores.nil?
            datastores = []
        else
            datastores = [datastores].flatten
        end

        datastores.each do |datastore|
            CLIHelper.print_header(str_h1 %
                                   'LOCAL SYSTEM DATASTORE '\
                                   "##{datastore['ID']} CAPACITY", false)
            puts format(str, 'TOTAL:',
                        OpenNebulaHelper.unit_to_str(datastore['TOTAL_MB']
                                        .to_i, {}, 'M'))
            puts format(str, 'USED: ',
                        OpenNebulaHelper.unit_to_str(datastore['USED_MB']
                                        .to_i, {}, 'M'))
            puts format(str, 'FREE:',
                        OpenNebulaHelper.unit_to_str(datastore['FREE_MB']
                                        .to_i, {}, 'M'))
            puts
        end

        CLIHelper.print_header(str_h1 % 'MONITORING INFORMATION', false)

        wilds = host.wilds

        begin
            pcis = [host.to_hash['HOST']['HOST_SHARE']['PCI_DEVICES']['PCI']]
            pcis = pcis.flatten.compact
        rescue StandardError
            pcis = nil
        end

        host.delete_element('TEMPLATE/VM')
        host.delete_element('TEMPLATE_WILDS')

        puts host.template_str

        if pcis && !pcis.empty?
            print_pcis(pcis)
        end

        begin
            numa_nodes =
                host.to_hash['HOST']['HOST_SHARE']['NUMA_NODES']['NODE']
        rescue StandardError
            numa_nodes = nil
        end

        if numa_nodes && !numa_nodes.empty?
            print_numa_nodes(numa_nodes)
        end

        puts
        CLIHelper.print_header('WILD VIRTUAL MACHINES', false)
        puts

        format = '%-30.30s %36s %4s %10s'
        CLIHelper.print_header(format(format, 'NAME',
                                      'IMPORT_ID', 'CPU', 'MEMORY'),
                               true)

        wilds.each do |wild|
            if wild['IMPORT_TEMPLATE']
                wild_tmplt = Base64.decode64(wild['IMPORT_TEMPLATE'])
                                   .split("\n")
                name   = wild['VM_NAME']
                import = wild_tmplt.select do |line|
                             line[/^IMPORT_VM_ID/]
                         end[0].split('=')[1].tr('"', ' ').strip
                memory = wild_tmplt.select do |line|
                             line[/^MEMORY/]
                         end[0].split('=')[1].tr('"', ' ').strip
                cpu    = wild_tmplt.select do |line|
                             line[/^CPU/]
                         end[0].split('=')[1].tr('"', ' ').strip
            else
                name = wild['DEPLOY_ID']
                import = memory = cpu = '-'
            end

            puts format(format, name, import, cpu, memory)
        end

        puts
        CLIHelper.print_header('VIRTUAL MACHINES', false)
        puts

        onevm_helper = OneVMHelper.new
        onevm_helper.client = @client
        onevm_helper.list_pool({ :filter => ["HOST=#{host.name}"],
                                 :no_pager => true },
                               false)
    end

    def print_pcis(pcis)
        puts
        CLIHelper.print_header('PCI DEVICES', false)
        puts

        table = CLIHelper::ShowTable.new(nil, self) do
            column :VM, 'Used by VM', :size => 5, :left => false do |d|
                if d['VMID'] == '-1'
                    ''
                else
                    d['VMID']
                end
            end

            column :ADDR, 'PCI Address', :size => 7, :left => true do |d|
                d['SHORT_ADDRESS']
            end

            column :TYPE, 'Type', :size => 14, :left => true do |d|
                d['TYPE']
            end

            column :CLASS, 'Class', :size => 12, :left => true do |d|
                d['CLASS_NAME']
            end

            column :NAME, 'Name', :size => 50, :left => true do |d|
                d['DEVICE_NAME']
            end

            column :VENDOR, 'Vendor', :size => 8, :left => true do |d|
                d['VENDOR_NAME']
            end

            default :VM, :ADDR, :TYPE, :NAME
        end

        table.show(pcis)
    end

    def print_numa_nodes(numa_nodes)
        numa_nodes = get_numa_data(numa_nodes)

        print_numa_cores(numa_nodes)
        print_numa_memory(numa_nodes)
        print_numa_hugepages(numa_nodes)
    end

    def get_numa_data(numa_nodes)
        numa_nodes = [numa_nodes] if numa_nodes.class == Hash

        numa_nodes.map! do |core|
            cores = core['CORE']

            free, used, cores_str = get_numa_cores(cores)

            core['CORE'] = {}
            core['CORE']['CORES'] = cores_str
            core['CORE']['FREE']  = free
            core['CORE']['USED']  = used

            core
        end

        numa_nodes
    end

    def get_numa_cores(cores)
        ret  = ''
        free = 0
        used = 0

        [cores].flatten.each do |info|
            core = info['CPUS'].split(',')

            core.uniq! do |c|
                c = c.split(':')
                c[0]
            end

            core.each do |c|
                c = c.split(':')

                if c[1] == '-1'
                    ret  += '-'
                    free += 1
                elsif c[1] == '-2'
                    ret  += 'I'
                    used += 1
                elsif c[1] != '-1' && info['FREE'] == '0'
                    ret  += 'X'
                    used += 1
                else
                    ret  += 'x'
                    used += 1
                end
            end

            ret += ' '
        end

        [free, used, ret]
    end

    def print_numa_cores(numa_nodes)
        puts
        CLIHelper.print_header('NUMA NODES', false)
        puts

        table = CLIHelper::ShowTable.new(nil, self) do
            column :ID, 'Node ID', :size => 4, :left => false do |d|
                d['NODE_ID']
            end

            column :CORES, 'Cores usage',
                   :left => true,
                   :adjust => true do |d|
                d['CORE']['CORES']
            end

            column :USED, 'Used CPUs', :size => 4, :left => true do |d|
                d['CORE']['USED']
            end

            column :FREE, 'Free CPUs', :size => 4, :left => true do |d|
                d['CORE']['FREE']
            end

            default :ID, :CORES, :USED, :FREE
        end

        table.show(numa_nodes)
    end

    def print_numa_memory(numa_nodes)
        nodes = numa_nodes.clone

        nodes.reject! do |node|
            node['MEMORY'].nil? || node['MEMORY'].empty?
        end

        return if nodes.empty?

        puts
        CLIHelper.print_header('NUMA MEMORY', false)
        puts

        table = CLIHelper::ShowTable.new(nil, self) do
            column :NODE_ID, 'Node ID', :size => 8, :left => false do |d|
                d['NODE_ID']
            end

            column :TOTAL, 'Total memory', :size => 8, :left => true do |d|
                OpenNebulaHelper.unit_to_str(d['MEMORY']['TOTAL'].to_i, {})
            end

            column :USED_REAL, 'Used memory', :size => 20, :left => true do |d|
                OpenNebulaHelper.unit_to_str(d['MEMORY']['USED'].to_i, {})
            end

            column :USED_ALLOCATED, 'U memory',
                   :size => 20, :left => true do |d|
                OpenNebulaHelper.unit_to_str(d['MEMORY']['USAGE'].to_i, {})
            end

            column :FREE, 'Free memory', :size => 8, :left => true do |d|
                OpenNebulaHelper.unit_to_str(d['MEMORY']['FREE'].to_i, {})
            end

            default :NODE_ID, :TOTAL, :USED_REAL, :USED_ALLOCATED, :FREE
        end

        table.show(nodes)
    end

    def print_numa_hugepages(numa_nodes)
        nodes = numa_nodes.clone

        nodes.reject! do |node|
            node['HUGEPAGE'].nil? || node['HUGEPAGE'].empty?
        end

        return if nodes.empty?

        puts
        CLIHelper.print_header('NUMA HUGEPAGES', false)
        puts

        table = CLIHelper::ShowTable.new(nil, self) do
            column :NODE_ID, 'Node ID', :size => 8, :left => false do |d|
                d['NODE_ID']
            end

            column :TOTAL, 'Total pages', :size => 8, :left => true do |d|
                d['HUGEPAGE']['PAGES']
            end

            column :SIZE, 'Pages size', :size => 8, :left => true do |d|
                OpenNebulaHelper.unit_to_str(d['HUGEPAGE']['SIZE'].to_i / 1024,
                                             {},
                                             'M')
            end

            column :FREE, 'Free pages', :size => 8, :left => true do |d|
                d['HUGEPAGE']['FREE']
            end

            column :USED, 'allocated pages', :size => 8, :left => true do |d|
                d['HUGEPAGE']['USAGE']
            end

            default :NODE_ID, :SIZE, :TOTAL, :FREE, :USED
        end

        hugepages = []

        nodes.each do |node|
            [node['HUGEPAGE']].flatten.each do |hugepage|
                h             = {}
                h['NODE_ID']  = node['NODE_ID']
                h['HUGEPAGE'] = hugepage

                hugepages << h
            end
        end

        table.show(hugepages)
    end

end
