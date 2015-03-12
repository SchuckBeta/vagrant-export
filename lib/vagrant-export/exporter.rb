#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

require 'fileutils'

module VagrantPlugins
  module Export
    class Exporter

      # @param env Vagrant::Environment
      # @param logger Log4r::Logger
      def initialize(env, logger)
        @env = env
        @logger = logger
      end

      # @param vm Vagrant::Machine
      # @param fast Boolean
      # @param bare Boolean
      # @return string
      def handle(vm, fast, bare)
        @vm = vm
        @did_run = false

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

        @target_box
      end

      protected


      def can_compress
        if @vm.state.short_description == 'running'
          @did_run = true
        else
          @vm.ui.info('Machine not running, bringing it up')
          @vm.action(:up)
        end

        compress_supported = false

        if @vm.config.vm.communicator != :winrm
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


      # Add the private key if we have one
      # Shamelessly stolen from Vagrant::Action::General::Package
      def setup_private_key

        # If we don't have a generated private key, we do nothing
        path = @vm.data_dir.join('private_key')
        return unless path.file?

        # Copy it into our box directory
        new_path = File.join(@tmp_path, 'vagrant_private_key')
        FileUtils.cp(path, new_path)

        # Append it to the Vagrantfile (or create a Vagrantfile)
        vf_path = File.join(@tmp_path, 'Vagrantfile')
        mode = 'w+'
        mode = 'a' if File.file?(vf_path)

        File.open(vf_path, mode) do |f|
          f.binmode
          f.puts
          f.puts %Q[Vagrant.configure("2") do |config|]
          f.puts %Q[  config.ssh.private_key_path = File.expand_path("../vagrant_private_key", __FILE__)]
          f.puts %Q[end]
        end
      end

      def export
        # Halt the machine
        if @vm.state.short_description == 'running'
          @vm.ui.info('Halting VM for export')
          @vm.action(:halt)
        end

        # Export to file
        exported_path = File.join(@env.tmp_path, Time.now.to_i.to_s)
        @tmp_path = exported_path
        FileUtils.mkdir_p(exported_path)

        @vm.ui.info('Exporting machine')

        provider_name = @vm.provider_name.to_s

        if /vmware/i =~ provider_name
          current_dir = File.dirname(@vm.id)
          files = Dir.glob(File.join(current_dir, '**', '*'))

          files.select! {|f| !File.directory?(f) }
          files.select!{ |f| f !~ /\.log$/ }
          files.select!{ |f| f !~ /core$/ }
          files.select!{ |f| f !~ /\.gz$/ }
          files.select!{ |f| f !~ /.lck$/ }

          FileUtils.cp_r(files, exported_path)

          @vm.ui.info('Compacting Vmware virtual disks')

          Dir.glob(File.join(exported_path, '**', '*.vmdk')) { |f|
            Vagrant::Util::Subprocess.execute('vmware-vdiskmanager', '-d', f)
            Vagrant::Util::Subprocess.execute('vmware-vdiskmanager', '-k', f)
          }

        else
          @vm.provider.driver.export File.join(exported_path, 'box.ovf' + ext) do |progress|
            @vm.ui.clear_line
            @vm.ui.report_progress(progress.percent, 100, false)
          end
        end

        @logger.debug("Exported VM to #{exported_path}")
      end

      def files(bare)

        provider_name = @vm.provider_name.to_s

        # For Vmware, the remote provider is generic _desktop
        # the local is a specific _fusion or _workstation
        # Always use vmware_desktop to avoid problems with different provider plugins
        if provider_name =~ /vmware/
          provider_name = 'vmware_desktop'
        end

        # Add metadata json
        begin
          metadata = File.open(File.join(@tmp_path, 'metadata.json'), 'wb')
          metadata.write('{"provider":"' + provider_name + '"}')
        ensure
          metadata.close
        end

        target_include_path = File.join(@tmp_path, 'include')
        source_include_path = File.join(@vm.box.directory, 'include')

        # Copy includes
        if Dir.exist?(source_include_path) && !bare
          FileUtils.cp_r(source_include_path, @tmp_path)
        end

        original_vagrantfile  = File.join(@vm.box.directory, 'Vagrantfile')
        vagrantfile_exists    = File.exist?(original_vagrantfile)
        vagrantfile_has_mac   = false
        vagrantfile_needs_mac = @vm.provider_name.to_s == 'virtualbox'

        # Check the original vagrant file for a mac settings
        if vagrantfile_exists && vagrantfile_needs_mac
          File.readlines(original_vagrantfile).each { |line|
            if line.to_s =~ /base_mac\s*=\s*("|')/i
              vagrantfile_has_mac = true
            end
          }
        end

        # If it has one, just copy it
        if vagrantfile_has_mac || (!vagrantfile_needs_mac && vagrantfile_exists)
          FileUtils.cp(original_vagrantfile, File.join(@tmp_path, 'Vagrantfile'))

        # If none, create a new one that has the mac setting,
        # and includes the original
        # The new Vagrantfile will include the old one, which
        # is put into the includeds directory
        elsif vagrantfile_needs_mac
          File.open(File.join(@tmp_path, 'Vagrantfile'), 'wb') do |file|
            file.write(Vagrant::Util::TemplateRenderer.render('package_Vagrantfile', {
                base_mac: @vm.provider.driver.read_mac_address
            }))
          end

          # If there is a Vagrantfile, but without a mac
          # ensure it is included
          if vagrantfile_exists
            FileUtils.mkdir_p(target_include_path) unless Dir.exist?(target_include_path)
            FileUtils.cp(original_vagrantfile, File.join(target_include_path, '_Vagrantfile'))
          end
        end

        # Copy the private key if available
        setup_private_key

        # Make a box file out of it
        @box_file_name = @tmp_path + '.box'

        @vm.ui.info('Packaging box file')

        Vagrant::Util::SafeChdir.safe_chdir(@tmp_path) do
          files = Dir.glob(File.join('.', '**', '*'))
          Vagrant::Util::Subprocess.execute('bsdtar', '-czf', @box_file_name, *files)
        end

        0
      end

      def finalize
        # Rename the box file
        if File.exist?(@box_file_name)
          box_name = @vm.box.name.gsub('/', '_')
          @target_box = File.join(@env.cwd, box_name + '.box')
          FileUtils.mv(@box_file_name, @target_box)
          @vm.ui.info('Created ' + @target_box)
        end

        # Remove the tmp files
        FileUtils.rm_rf(@tmp_path)

        # Resume the machine
        if @did_run
          @vm.ui.info('Bringing the machine back up')
          @vm.action(:up)
        end
      end
    end
  end
end
