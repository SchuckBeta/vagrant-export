#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

module VagrantPlugins
  module Export
    class Plugin < Vagrant.plugin '2'

      name 'Vagrant Export'

      description <<-EOF
      Export an existing box to a .box file, like the vagrant repackage command
      Additionally it will include the original Vagrantfile and other included
      files and perform several cleanup operations inside the VM to reduce its
      exported size. The latter requires a Ubuntu or compatible guest.
      EOF

      command 'export' do
        require_relative 'command'
        Command
      end
   	end
  end
end
