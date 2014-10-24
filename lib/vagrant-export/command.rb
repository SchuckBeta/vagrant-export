#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

module VagrantPlugins
  module Export
    class Command < Vagrant.plugin '2', :command

      def self.synopsis
        'exports a box file with additional actions taken'
      end

      def execute
        options = {}
        options[:quick] = false
        options[:bare] = false

        opts = OptionParser.new do |o|
          o.banner = 'Usage: vagrant export [switches]'
          o.separator ''

          o.on('-f', '--fast', 'Do not perform cleanups.') do |f|
            options[:fast] = f
          end

          o.on('-b', '--bare', 'Do not include additional files.') do |b|
            options[:bare] = b
          end
        end

        argv = parse_options(opts)
        return 1 unless argv

        require_relative 'exporter'
        ex = Exporter.new(@env, @logger)

        with_target_vms argv, reverse: true do |machine|
          ex.handle(machine, options[:fast], options[:bare])
        end
        0
      end
    end
  end
end
