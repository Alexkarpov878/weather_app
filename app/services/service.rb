module Service
  class Result
    def success?
      raise NotImplementedError, "#{self.class} must implement #success?"
    end

    def failure?
      !success?
    end

    def data
      raise NoMethodError, "Data is only available on Success results" unless success?
    end

    def error
      raise NoMethodError, "Error is only available on Failure results" unless failure?
    end
  end

  class Success < Result
    attr_reader :data

    def initialize(data:)
      @data = data
      freeze
    end

    def success?
      true
    end
  end

  class Failure < Result
    attr_reader :error

    def initialize(error:)
      raise ArgumentError, "Failure error cannot be nil" if error.nil?
      @error = error
      freeze
    end

    def success?
      false
    end
  end
end
