module Clients
  class Common
    extend ActiveSupport::Concern

    def fail!(code, message = nil, **meta)
      raise integration_error code, message, **meta
    end

    def integration_error(code, message = nil, **meta)
      raise pumpkin_rpc_error code, message, **meta
  end
  end
end
