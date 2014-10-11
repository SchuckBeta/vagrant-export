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
      def initialize env, logger
        @env = env
        @logger = logger
      end

      # @param vm Vagrant::Machine
      # @param fast Boolean
      # @param bare Boolean
      def handle vm, fast, bare
        @vm = vm
        @did_run = false

        unless fast
          if can_compress
            compress
          else
            @env.uid.error 'Cannot compress this type of machine'
            return 1
          end
        end

        return 1 unless export

        unless bare
          return 1 unless files
        end

        finalize
      end

      protected


      def can_compress
        if @vm.state.short_description == 'running'
          @did_run = true
        else
          @env.ui.info 'Machine not running, bringing it up'
          @vm.action :up
        end

        compress_supported = false

        if @vm.config.vm.communicator != :winrm
          @vm.communicate.execute 'lsb_release -i -s', error_key: :ssh_bad_exit_status_muted do |type, data|
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

        @logger.debug "Uploading #{source_script} to #{target_script}"
        comm.upload source_script, target_script

        sudo comm, "chmod +x #{target_script}"
        sudo comm, "#{target_script}"

        0
      end

      def sudo communicator, command
        @logger.debug "Execute '#{command}'"
        communicator.sudo command, error_key: :ssh_bad_exit_status_muted do |type, data|
          if [:stderr, :stdout].include?(type)
            return if data.empty?
            data = data.to_s.chomp.strip
            if type == :stdout
                @vm.ui.info data
            else
              @vm.ui.error data
            end
          end
        end
      end

      def export
        # Halt the machine
        if @vm.state.short_description == 'running'
          @env.ui.info 'Halting VM for export'
          @vm.action(:halt)
        end

        # Export to file
        exported_path = File.join @env.tmp_path, Time.now.to_i.to_s
        @tmp_path = exported_path
        FileUtils.mkpath exported_path

        @env.ui.info I18n.t 'vagrant.actions.vm.export.exporting'
        @vm.provider.driver.export File.join(exported_path, 'box.ovf') do |progress|
          @env.ui.clear_line
          @env.ui.report_progress progress.percent, 100, false
        end

        @logger.debug "Exported VM to #{exported_path}"
      end

      def files

        # Add metadata json
        begin
          metadata = File.open(File.join(@tmp_path, 'metadata.json'), 'wb')
          metadata.write '{"provider":"' + @vm.provider_name.to_s + '"}'
        ensure
          metadata.close
        end

        target_include_path = File.join @tmp_path, 'include'
        source_include_path = File.join @vm.box.directory, 'include'

        # Copy includes
        if Dir.exist? source_include_path
          FileUtils.cp_r source_include_path, @tmp_path

        # Add the orignal vagrant file as include
        else
          FileUtils.mkpath target_include_path
          Dir.glob(File.join(@vm.box.directory, '**', '*')).each do |file|
            if file.to_s =~ /Vagrantfile$/
              FileUtils.cp file.to_s, File.join(target_include_path, '_Vagrantfile')
            end
          end
        end

        # Add the mac address setting as a Vagrantfile
        File.open(File.join(@tmp_path, 'Vagrantfile'), 'wb') do |f|
          f.write(Vagrant::Util::TemplateRenderer.render('package_Vagrantfile', {
              base_mac: @vm.provider.driver.read_mac_address
          }))
        end

        # Make a box file out of it
        @box_file_name = @tmp_path + '.box'

        Vagrant::Util::SafeChdir.safe_chdir(@tmp_path) do
          files = Dir.glob File.join('.', '**', '*')
          Vagrant::Util::Subprocess.execute('bsdtar', '-czf', @box_file_name, *files)
        end

        0
      end

      def finalize
        # Rename the box file
        if File.exist? @box_file_name
          box_name = @vm.box.name.gsub '/', '_'
          target_box = File.join @env.cwd, box_name + '.box'
          File.rename @box_file_name, target_box
        end

        # Remove the tmp files
        FileUtils.rm_rf @tmp_path

        # Resume the machine
        if @did_run
          @env.ui.info 'Bringing the machine back up'
          @vm.action :up
        end
      end
    end
  end
end
