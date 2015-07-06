#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

require 'fileutils'
require_relative 'error'

module VagrantPlugins
  module Export
    class Exporter

      # @param env Vagrant::Environment
      # @param logger Log4r::Logger
      # @param vm Vagrant::Machine
      def initialize(env, logger, vm)
        @vm = vm
        @env = env
        @logger = logger
      end

      # @param fast Boolean
      # @param bare Boolean
      # @return string
      def handle(fast, bare)
        @private_key   = nil
        @tmp_path      = nil
        @box_file_name = nil

        if @vm.state.short_description == 'not created'
          raise VagrantPlugins::Export::NotCreated
        end

        begin
          ssh_info = @vm.ssh_info
          unless ssh_info == nil
            @private_key = ssh_info[:private_key_path]
          end

          unless fast
            if can_compress
              compress
            else
              @vm.ui.error('Cannot compress this type of machine')
              return 1
            end
          end

          return 1 unless export
          return 1 unless files(bare)

          finalize
        ensure
          FileUtils.rm_rf(@tmp_path) if @tmp_path != nil && Dir.exists?(@tmp_path)
          FileUtils.rm_rf(@box_file_name) if @box_file_name != nil &&  File.file?(@box_file_name)
        end
        target_box
      end

      def target_box
        box_name = @vm.box.name.gsub(/[^a-z0-9\-]+/, '_')
        File.join(@env.cwd, box_name + '.box')
      end

      protected

      def can_compress
        unless @vm.state.short_description == 'running'
          @vm.ui.info('Machine not running, bringing it up')
          @vm.action(:up)
        end

        compress_supported = false

        if @vm.config.vm.communicator != :winrm

          ssh_info = @vm.ssh_info
          unless ssh_info == nil
            @private_key = ssh_info[:private_key_path]
          end

          @vm.communicate.execute('lsb_release -i -s', error_key: :ssh_bad_exit_status_muted) do |type, data|
            if type == :stdout && data.to_s =~ /mint|ubuntu|debian/i
              compress_supported = true
            end
          end
        end

        compress_supported
      end

      def compress

        target_script = "/tmp/_cleanup_#{Time.now.to_i.to_s}.sh"
        source_script = File.expand_path('../../../res/cleanup.sh', __FILE__)
        comm = @vm.communicate

        @logger.debug("Uploading #{source_script} to #{target_script}")
        comm.upload(source_script, target_script)

        sudo(comm, "chmod +x #{target_script}")
        sudo(comm, "#{target_script}")

        0
      end

      def sudo(communicator, command)
        @logger.debug("Execute '#{command}'")
        communicator.sudo(command, error_key: :ssh_bad_exit_status_muted) do |type, data|
          if [:stderr, :stdout].include?(type)
            return if data.empty?
            data = data.to_s.chomp.strip
            if type == :stdout
              @vm.ui.info(data)
            else
              @vm.ui.error(data)
            end
          end
        end
      end

      def export
        # Halt the machine
        if @vm.state.short_description == 'running'
          @vm.ui.info('Halting VM for export')
          @vm.action(:halt)
        end

        # Export to file
        exported_path = File.join(@env.tmp_path, 'export-' + Time.now.strftime('%Y%m%d%H%M%S'))
        @tmp_path = exported_path
        FileUtils.mkdir_p(exported_path)

        @vm.ui.info('Exporting machine')

        provider_name = @vm.provider_name.to_s

        if /vmware/i =~ provider_name

          @logger.debug("Using vmware method for provider #{provider_name}")

          current_dir = File.dirname(@vm.id)
          vm_data_files = Dir.glob(File.join(current_dir, '**', '*'))

          @logger.debug("Files found in #{current_dir}: #{vm_data_files}")

          vm_data_files.select! { |f| !File.directory?(f) }
          vm_data_files.select! { |f| f ~ /\.(vmdk|nvram|vmtm|vmx|vmxf)$/ }

          @logger.debug("Copying #{files} to #{exported_path}")

          FileUtils.cp_r(vm_data_files, exported_path)

          @vm.ui.info('Compacting Vmware virtual disks')

          Dir.glob(File.join(exported_path, '**', '*.vmdk')) { |f|
            @logger.debug("Compacting disk file #{f}")
            Vagrant::Util::Subprocess.execute('vmware-vdiskmanager', '-d', f)
            Vagrant::Util::Subprocess.execute('vmware-vdiskmanager', '-k', f)
          }

        else

          ovf_file = File.join(exported_path, @vm.box.name.gsub(/[^a-zA-Z0-9]+/, '_')) + '.ovf'
          vm_id = @vm.id.to_s

          opts = {}
          opts[:notify] = [:stdout, :stderr]

          @logger.debug("Export #{vm_id} to #{ovf_file}")
          @env.ui.info('0%', new_line: false)

          Vagrant::Util::Subprocess.execute('VBoxManage', 'export', vm_id, '-o', ovf_file, opts) { |io, data|

            d = data.to_s
            @logger.debug(d)

            unless io == :stdout
              @env.ui.clear_line
              if /\d+%/ =~ d
                @env.ui.info(d.match(/\d+%/).to_a.pop, new_line: false)
              else
                @logger.error(d)
                raise VirtualboxExportError
              end
            end
          }
        end

        @env.ui.clear_line
        @logger.debug("Exported VM to #{exported_path}")
      end

      def files(bare)

        provider_name = @vm.provider_name.to_s

        @logger.debug("Provider identified as #{provider_name}")

        # For Vmware, the remote provider is generic _desktop
        # the local is a specific _fusion or _workstation
        # Always use vmware_desktop to avoid problems with different provider plugins
        if provider_name =~ /vmware/
          provider_name = 'vmware_desktop'
          @logger.debug("Forcing provider name #{provider_name}")
        end

        # Add metadata json
        File.open(File.join(@tmp_path, 'metadata.json'), 'wb') do |f|
          f.write('{"provider":"' + provider_name + '"}')
        end

        # Copy additional files
        unless bare
          additional_files = Dir.glob(File.join(@vm.box.directory, '**', '*'))
          additional_files.select! { |f| !File.directory?(f) }
          additional_files.select! { |f| f !~ /(gz|core|lck|log|vmdk|ovf|ova)$/ }
          additional_files.select! { |f| f !~ /(nvram|vmem|vmsd|vmsn|vmss|vmtm|vmx|vmxf)$/ }
          additional_files.select! { |f| !File.file?(f.gsub(@vm.box.directory.to_s, @tmp_path.to_s)) }

          @logger.debug("Copy includes #{additional_files} to #{@tmp_path}")

          FileUtils.cp_r(additional_files, @tmp_path)
        end

        # Make sure the Vagrantfile includes a HMAC when the provider is virtualbox
        if @vm.provider_name.to_s == 'virtualbox'

          @logger.debug('Provider needs a hmac setting in the Vagrantfile')

          vagrantfile_name    = File.join(@tmp_path, 'Vagrantfile')
          vagrantfile_has_mac = false
          mode                = 'w+'

          if File.exist?(vagrantfile_name)
            mode = 'a'
            File.readlines(vagrantfile_name.to_s).each { |line|
              if line.to_s =~ /base_mac\s*=\s*("|')/i
                @logger.debug("Found HMAC setting in file #{vagrantfile_name.to_s}")
                vagrantfile_has_mac = true
              end
            }
          end

          unless vagrantfile_has_mac

            @logger.debug("Found HMAC setting in file #{vagrantfile_name.to_s}")

            File.open(vagrantfile_name.to_s, mode) { |f|
              hmac_address = @vm.provider.driver.read_mac_address
              f.binmode
              f.puts
              f.puts %Q[# Automatically added by export]
              f.puts %Q[Vagrant.configure("2") do |config|]
              f.puts %Q[  config.vm.base_mac = "#{hmac_address}"]
              f.puts %Q[end]
            }
          end
        end

        # Make a box file out of it
        @box_file_name = @tmp_path + '.box'

        @vm.ui.info('Packaging box file')

        Vagrant::Util::SafeChdir.safe_chdir(@tmp_path) do

          box_files = Dir.glob(File.join(@tmp_path, '**', '*'))
          @logger.debug("Create box file #{@box_file_name} containing #{box_files}")
          bash_exec = Vagrant::Util::Which.which('bash').to_s;

          if File.executable?(bash_exec) && ['pv', 'tar', 'gzip'].all? {|cmd| Vagrant::Util::Which.which(cmd) != nil }
            total_size = 0
            files_list = []

            @logger.debug('Using custom packaging command to create progress output')
            @env.ui.info('Starting compression', new_line: false)

            box_files.each { |f|
              total_size += File.size(f)
              files_list.push(f.to_s.gsub(@tmp_path.to_s, '').gsub(/^[\/\\]+/, ''))
            }

            @logger.debug("Complete size of files is #{total_size} bytes")

            opts = {}
            opts[:notify] = [:stderr, :stdout]

            script_file = File.absolute_path(File.expand_path('../../../res/progress_tar.sh', __FILE__))
            files_list  = files_list.join(' ')

            @logger.debug("Files argument for bash script: #{files_list}")

            Vagrant::Util::Subprocess.execute(bash_exec, script_file, @tmp_path.to_s, total_size.to_s, @box_file_name, files_list, opts) { |io, data|
              d = data.to_s
              p = d.match(/\d+/).to_a

              @logger.debug(io.to_s + ': ' + d)

              if p.length > 0
                @env.ui.clear_line
                @env.ui.info(p.pop.to_s + '%', new_line: false)
              end

            }

            @env.ui.clear_line

          else
            Vagrant::Util::Subprocess.execute('bsdtar', '-czf', @box_file_name, *box_files)
          end
        end

        raise TarFailed unless File.file?(@box_file_name)

        0
      end

      def finalize
        # Rename the box file
        if File.exist?(@box_file_name)
          target = target_box
          FileUtils.mv(@box_file_name, target)
          @vm.ui.info('Created ' + target)
        end
      end
    end
  end
end
