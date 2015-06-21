#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

module VagrantPlugins
  module Export
    class VirtualboxExportError < Vagrant::Errors::VagrantError
      error_message('Cannot export Virtualbox machine to appliance')
    end
    class BoxAlreadyExists < Vagrant::Errors::VagrantError
      error_message('A box file for this machine already exists')
    end
    class NotCreated < Vagrant::Errors::VagrantError
      error_message('Cannot export a not created machine. Please make at least one vagrant up')
    end
    class TarFailed < Vagrant::Errors::VagrantError
      error_message('Error during creating the box file')
    end
  end
end
