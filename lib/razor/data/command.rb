module Razor::Data
  class Command < Sequel::Model
    plugin :serialization, :json, :params
    plugin :serialization, :json, :error

    # The 'name' of the command. Since this needs to be unique, we simply
    # use the id of the object
    def name
      # The name must be a string
      id.to_s
    end

    # This is a hack around the fact that the auto_validates plugin does
    # not play nice with the JSON serialization plugin (the serializaton
    # happens in the before_save hook, which runs after validation)
    #
    # To avoid spurious error messages, we tell the validation machinery to
    # expect a Hash
    #
    # FIXME: Figure out a way to address this issue upstream
    def schema_type_class(k)
      if k == :params
        Hash
      elsif k == :error
        Array
      else
        super
      end
    end

    # Store the exception +e+ in the +error+ array. For any attempt to run
    # the command, only the first exception is stored, assuming that that
    # is the most precise cause of the error.
    def add_exception(e, attempt=nil)
      self.error ||= []
      attempt ||= self.error.size
      if self.error[attempt].nil?
        self.error[attempt] = {
          'exception' => e.class.name,
          'message'   => e.to_s,
          'backtrace' => e.backtrace,
          'attempted_at' => DateTime.now
        }
      end
    end
  end
end
