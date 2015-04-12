#                                                                       #
# This is free software; you can redistribute it and/or modify it under #
# the terms of the MIT- / X11 - License                                 #
#                                                                       #

module VagrantPlugins
  module Export
    class VirtualboxExportError < Vagrant::Errors::VagrantError
      error_message('Cannot export Virtualbox machine to appliance')
    end
  end
end
