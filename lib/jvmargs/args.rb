module JVMArgs
  class Args
    
    def initialize(*initial_args,&block)
      @args = Hash.new
      @rules = RuleSet.new
      Types.each {|type| @args[type] = Hash.new }
      server_arg = JVMArgs::Standard.new("-server")
      @args[:standard][server_arg.key] = server_arg
      set_default_heap_size
      # in case user passed in an array
      initial_args.flatten!  
      parse_args(initial_args) unless initial_args.empty?
      self.instance_exec &block if block
    end

    def [](key)
      @args[key]
    end

    def add(*args)
      args.flatten!
      parse_args(args)
    end
    
    def process_rules(key)
      unless @rules[key].nil?
        @rules[key].each do |rule|
          rule.call(key,@args)
        end
      end
    end
    
    def parse_args(args)
      args.each do |arg|
        type = nil
        jvm_arg = case arg
                  when /^-?XX.*/
                    type = :unstable
                    JVMArgs::Unstable.new(arg)
                  when /^-?X.*/
                    type = :nonstandard
                    JVMArgs::NonStandard.new(arg)
                  when /^-?D.*/
                    type = :directive
                    JVMArgs::Directive.new(arg)
                  else
                    type = :standard
                    JVMArgs::Standard.new(arg)
                  end
        @args[type][jvm_arg.key] = jvm_arg
      end
      Types.each do |type|
        @args[type].keys.each {|key| process_rules(key) }
      end
    end

    def set_default_heap_size
      if defined? node
        total_ram = node['memory']['total'].sub(/kB/, '')
      else
        total_ram = (JVMArgs::Util.get_system_ram_m.sub(/M/,'').to_i * 0.4).to_i
      end
      @args[:nonstandard]['Xmx'] = JVMArgs::NonStandard.new("Xmx#{total_ram}M")
    end
    
    def to_s
      args_str = ""
      Types.each do |type|
        type_str = @args[type].map {|k,v| v.to_s }
        args_str << " " + type_str.join(' ') + " "
      end
      args_str
    end

    def parse_named_args(named_args)
      named_args.each do |k,v|
        case k.to_sym
        when :jmx
          add_default_jmx
        end
      end
    end

    def jmx(boolean)
      if boolean
        [
         "-Djava.rmi.server.hostname=127.0.0.1",
         "-Dcom.sun.management.jmxremote",
         "-Dcom.sun.management.jmxremote",
         "-Dcom.sun.management.jmxremote.port=9000",
         "-Dcom.sun.management.jmxremote.authenticate=false",
         "-Dcom.sun.management.jmxremote.ssl=false"
        ].each do |arg|
          directive = JVMArgs::Directive.new arg
          @args[:directive][directive.key] = directive
        end
      end
    end

    # def heap_size(percentage)

    # end
    
  end
end
