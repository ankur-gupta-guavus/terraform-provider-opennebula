
require 'opennebula'
require 'base64'

class OneDBLive

    EDITOR_PATH='/bin/vi'

    def initialize
        @client = nil
        @system = nil
    end

    def client
        @client ||= OpenNebula::Client.new
    end

    def system_db
        @system ||= OpenNebula::System.new(client)
    end

    def db_escape(string)
        string.gsub("'", "''")
    end

    def delete_sql(table, where)
        "DELETE from #{table} WHERE #{where}"
    end

    def delete(table, where, federate)
        sql = delete_sql(table, where)
        db_exec(sql, "Error deleting record", federate)
    end

    def update_sql(table, values, where)
        str = "UPDATE #{table} SET "

        changes = []

        values.each do |key, value|
            change = "#{key.to_s} = "

            case value
            when String, Symbol
                change << "'#{db_escape(value.to_s)}'"
            when Numeric
                change << value.to_s
            else
                change << value.to_s
            end

            changes << change
        end

        str << changes.join(', ')
        str << " WHERE #{where}"

        str
    end

    def update(table, values, where, federate)
        sql = update_sql(table, values, where)
        db_exec(sql, "Error updating record", federate)
    end

    def update_body_sql(table, body, where)
        "UPDATE #{table} SET body = '#{db_escape(body)}' WHERE #{where}"
    end

    def update_body(table, body, where, federate)
        sql = update_body_sql(table, body, where)
        db_exec(sql, "Error updating record", federate)
    end

    def db_exec(sql, error_msg, federate = false)
        rc = system_db.sql_command(sql, federate)
        if OpenNebula.is_error?(rc)
            raise "#{error_msg}: #{rc.message}"
        end
    end

    def select(table, where)
        sql = "SELECT * FROM #{table} WHERE #{where}"
        res = db_query(sql, "Error querying database")

        element = OpenNebula::XMLElement.new(
            OpenNebula::XMLElement.build_xml(res, '/SQL_COMMAND'))

        hash = element.to_hash
        row  = hash['SQL_COMMAND']['RESULT']['ROW'] rescue nil

        if !row
            raise "Empty SQL query result: "
        end

        [row].flatten.compact
    end

    def db_query(sql, error_msg)
        rc = system_db.sql_query_command(sql)

        if OpenNebula.is_error?(rc)
            raise "#{error_msg}: #{rc.message}"
        end

        rc
    end

    def percentage_line(current, max, carriage_return = false)
        return_symbol = carriage_return ? "\r" : ""
        percentile = current.to_f / max.to_f * 100

        "#{current}/#{max} #{percentile.round(2)}%#{return_symbol}"
    end

    def purge_history(options = {})
        vmpool = OpenNebula::VirtualMachinePool.new(client)
        vmpool.info_all

        ops = {
            start_time: 0,
            end_time: Time.now
        }.merge(options)

        start_time  = ops[:start_time].to_i
        end_time    = ops[:end_time].to_i

        last_id = vmpool["/VM_POOL/VM[last()]/ID"]

        vmpool.each do |vm|
            print percentage_line(vm.id, last_id, true)

            time = vm["STIME"].to_i
            next unless time >= start_time && time < end_time

            # vmpool info only returns the last history record. We can check
            # if this VM can have more than one record using the sequence
            # number. If it's 0 or it does not exist we can skip the VM.
            # Also take tone that xpaths on VM info that comes from VMPool
            # or VM is different. We can not use absolute searches with
            # objects coming from pool.
            seq = vm['HISTORY_RECORDS/HISTORY/SEQ']
            next if !seq || seq == '0'

            # If the history can contain more than one record we get
            # all the info for two reasons:
            #
            #   * Make sure that all the info is written back
            #   * Refresh the information so it's less probable that the info
            #     was modified during this process
            vm.info

            hash = vm.to_hash
            val_history = hash['VM']['HISTORY_RECORDS']['HISTORY']

            history_num = 2

            val_history = [val_history].flatten
            last_seq = val_history.last['SEQ'].to_i rescue 0

            if last_seq >= history_num
                last_history = val_history.last(history_num)

                old_seq = []
                seq_num = last_history.first['SEQ']

                # Renumerate the sequence
                last_history.each_with_index do |history, index|
                    old_seq << history['SEQ'].to_i
                    history['SEQ'] = index
                end

                # Only the last history record is saved in vm_pool
                vm.delete_element('HISTORY_RECORDS/HISTORY')
                vm.add_element('HISTORY_RECORDS',
                               'HISTORY' => last_history.last)

                # Update VM body to leave only the last history record
                body = db_escape(vm.to_xml)
                update_body("vm_pool", vm.to_xml, "oid = #{vm.id}", false)

                # Delete any history record that does not have the same
                # SEQ number as the last history record
                delete("history", "vid = #{vm.id} and seq < #{seq_num}", false)

                # Get VM history
                history = select("history", "vid = #{vm.id}")

                # Renumerate sequence numbers
                old_seq.each_with_index do |seq, index|
                    row = history.find {|r| seq.to_s == r["seq"] }
                    next if !row

                    body = Base64.decode64(row['body64'])

                    doc = Nokogiri::XML(body)
                    doc.xpath("/HISTORY/SEQ").first.content = index.to_s
                    new_body = doc.root.to_xml

                    update("history",
                           { seq: index, body: new_body },
                           "vid = #{vm.id} and seq = #{seq}", false)
                end
            end
        end
    end

    def purge_done_vm(options = {})
        vmpool = OpenNebula::VirtualMachinePool.new(client)
        vmpool.info(OpenNebula::Pool::INFO_ALL,
                    -1,
                    -1,
                    OpenNebula::VirtualMachine::VM_STATE.index('DONE'))

        ops = {
            start_time: 0,
            end_time: Time.now
        }.merge(options)

        start_time  = ops[:start_time].to_i
        end_time    = ops[:end_time].to_i

        last_id = vmpool["/VM_POOL/VM[last()]/ID"]

        vmpool.each do |vm|
            print percentage_line(vm.id, last_id, true)

            time = vm["ETIME"].to_i
            next unless time >= start_time && time < end_time

            delete("vm_pool", "oid = #{vm.id}", false)
            delete("history", "vid = #{vm.id}", false)
        end
    end

    def check_expr(object, expr)
        reg = /^(?<xpath>.+?)(?<operator>=|!=|>=|<=|>|<)(?<value>.*?)$/
        parsed = expr.match(reg)

        raise "Expression malformed: '#{expr}'" unless parsed

        val = object[parsed[:xpath]]
        return false if !val

        p_val = parsed[:value].strip
        val.strip!

        res = false

        res = case parsed[:operator]
        when '='
            val == p_val
        when '!='
            val != p_val
        when '<'
            val.to_i < p_val.to_i
        when '>'
            val.to_i > p_val.to_i
        when '<='
            val.to_i <= p_val.to_i
        when '>='
            val.to_i >= p_val.to_i
        end

        res
    end

    def get_pool_config(object)
        case (object||'').downcase.strip.to_sym
        when :vm
            table = 'vm_pool'
            object = OpenNebula::VirtualMachinePool.new(client)
            federate = false

        when :host
            table = 'host_pool'
            object = OpenNebula::HostPool.new(client)
            federate = false

        when :vnet
            table = 'network_pool'
            object = OpenNebula::VirtualNetworkPool.new(client)
            federate = false

        when :image
            table = 'image_pool'
            object = OpenNebula::ImagePool.new(client)
            federate = false

        when :cluster
            table = 'cluster_pool'
            object = OpenNebula::ClusterPool.new(client)
            federate = false

        when :document
            table = 'document_pool'
            object = OpenNebula::DocumentPool.new(client)
            federate = false

        when :group
            table = 'group_pool'
            object = OpenNebula::GroupPool.new(client)
            federate = true

        when :marketplace
            table = 'marketplace_pool'
            object = OpenNebula::MarketPlacePool.new(client)
            federate = true

        when :marketplaceapp
            table = 'marketplaceapp_pool'
            object = OpenNebula::MarketPlaceAppPool.new(client)
            federate = true

        when :secgroup
            table = 'secgroup_pool'
            object = OpenNebula::SecurityGroupPool.new(client)
            federate = false

        when :template
            table = 'template_pool'
            object = OpenNebula::TemplatePool.new(client)
            federate = false

        when :vrouter
            table = 'vrouter_pool'
            object = OpenNebula::VirtualRouterPool.new(client)
            federate = false

        when :zone
            table = 'zone_pool'
            object = OpenNebula::ZonePool.new(client)
            federate = true

        when :datastore
            table = 'datastore_pool'
            object = OpenNebula::DatastorePool.new(client)
            federate = false

        when :user
            table = 'user_pool'
            object = OpenNebula::UserPool.new(client)
            federate = false

        when :vmgroup
            table = 'vmgroup_pool'
            object = OpenNebula::VMGroupPool.new(client)
            federate = false

        when :vdc
            table = 'vdc_pool'
            object = OpenNebula::VdcPool.new(client)
            federate = false

        else
            raise "Object type '#{object}' not supported"
        end

        return table, object, federate
    end

    def change_history(vid, seq, xpath, value, options)
        begin
            doc = get_history_body(vid, seq)
        rescue => e
            STDERR.puts e.message
            return
        end

        doc.xpath(xpath).each do |e|
            e.content = value
        end

        xml = doc.root.to_xml

        if options[:dry]
            puts xml
        else
            begin
                update_body("history", xml, "vid = #{vid} and seq = #{seq}", false)
            rescue => e
                STDERR.puts "Error updating history recored #{seq} for VM #{vid}"
                STDERR.puts e.message
            end
        end
    end

    def change_body(object, xpath, value, options = {})
        table, object, federate = get_pool_config(object)
        found_id = false

        if !value && !options[:delete]
            raise "A value or --delete should specified"
        end

        rc = object.info_all
        raise rc.message if OpenNebula.is_error?(rc)

        object.each do |o|
            if options[:id]
                found_id = o.id.to_s.strip == options[:id].to_s
                next unless found_id
            elsif options[:xpath]
                next unless o[options[:xpath]]
            elsif options[:expr]
                next unless check_expr(o, options[:expr])
            end
            # Get body from the database
            begin
                db_data = select(table, "oid = #{o.id}")
            rescue => e
                STDERR.puts "Error getting object id #{o.id}"
                STDERR.puts e.message
                next
            end

            row = db_data.first
            body = Base64.decode64(row['body64'])

            doc = Nokogiri::XML(body, nil, NOKOGIRI_ENCODING) do |c|
                c.default_xml.noblanks
            end

            doc.xpath(xpath).each do |e|
                if options[:delete]
                    e.remove
                else
                    e.content = value
                end
            end

            xml = doc.root.to_xml

            if options[:dry]
                puts xml
            else
                begin
                    update_body(table, xml, "oid = #{o.id}", federate)
                rescue => e
                    STDERR.puts "Error updating object id #{o.id}"
                    STDERR.puts e.message
                    next
                end
            end
            break if found_id
        end
        raise "Object with id #{options[:id]} not found" if options[:id] && !found_id
    end

    def editor_body(body_xml)
        #Editor
        require 'tempfile'

        tmp  = Tempfile.new("onedb")

        if body_xml
            tmp << body_xml
            tmp.flush
        end

        editor_path = ENV["EDITOR"] ? ENV["EDITOR"] : EDITOR_PATH

        system("#{editor_path} #{tmp.path}")

        unless $?.exitstatus == 0
            puts "Editor not defined"
            exit -1
        end

        tmp.close

        return File.read(tmp.path)
    end

    def update_body_cli(object, id)
        table, object, federate = get_pool_config(object)

        # Get body from the database
        begin
            db_data = select(table, "oid = #{id}")
        rescue => e
            STDERR.puts "Error getting object id #{o.id}"
            STDERR.puts e.message
        end

        row = db_data.first
        body = Base64.decode64(row['body64'])

        doc = Nokogiri::XML(body, nil, NOKOGIRI_ENCODING) do |c|
            c.default_xml.noblanks
        end

        doc = editor_body(doc.root.to_s)

        begin
            xml_doc = Nokogiri::XML(doc, nil, NOKOGIRI_ENCODING) do |c|
                c.default_xml.noblanks
                c.strict
            end

            xml = xml_doc.root.to_xml

            update_body(table, xml, "oid = #{id}", federate)
        rescue => e
            STDERR.puts "Error updating object id #{id}"
            STDERR.puts e.message
        end
    end

    def update_history_cli(vid, seq)
        begin
            doc = get_history_body(vid, seq)
        rescue => e
            STDERR.puts e.message
            return
        end

        doc = editor_body(doc.root.to_s)

        begin
            xml_doc = Nokogiri::XML(doc, nil, NOKOGIRI_ENCODING) do |c|
                c.default_xml.noblanks
                c.strict
            end

            xml = xml_doc.root.to_xml

            update_body("history", xml, "vid = #{vid} and seq = #{seq}", false)
        rescue => e
            STDERR.puts "Error updating history record #{seq} for VM #{vid}"
            STDERR.puts e.message
        end
    end

    def show_body_cli(object, id)
        table, object, federate = get_pool_config(object)

        # Get body from the database
        begin
            db_data = select(table, "oid = #{id}")
        rescue => e
            STDERR.puts "Error getting object id #{id}"
            STDERR.puts e.message
        end

        row = db_data.first
        body = Base64.decode64(row['body64'])

        doc = Nokogiri::XML(body, nil, NOKOGIRI_ENCODING) do |c|
            c.default_xml.noblanks
        end

        doc.root.to_s
    end

    def show_history_cli(vid, seq)
        begin
            doc = get_history_body(vid, seq)
        rescue => e
            STDERR.puts e.message
            return
        end

        doc.root.to_s
    end

    def get_history_body(vid, seq)
        begin
            db_data = select("history", "vid = #{vid} and seq = #{seq}")
        rescue => e
            error_str = "Error getting history record #{seq} for VM #{vid}"
            error_str << e.message

            raise error_str
        end

        row  = db_data.first
        body = Base64.decode64(row['body64'])

        doc = Nokogiri::XML(body, nil, NOKOGIRI_ENCODING) do |c|
            c.default_xml.noblanks
        end

        return doc
    end
end

