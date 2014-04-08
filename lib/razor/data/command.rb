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

    def finished?
      status == 'finished'
    end

    # Store (save) the command after setting its status to +status+. If its
    # status is +nil+ and no explicit +status+ is passed in, set it to
    # finished.
    def store(status = nil)
      if self.status.nil? and status.nil?
        self.status = 'finished'
      else
        self.status = status if status
      end
      self.finished_at ||= DateTime.now if finished?
      save
    end

    # Create a new command and fill various fields; besides the passed in
    # +command+ (a string), params hash, and user name, also set the time
    # of the submission.
    #
    # Note that the returned command is not saved yet; that should be done
    # with a call to +store+
    def self.start(command, params, user)
      cmd = Command.new(:command => command,
                        :params => params,
                        :submitted_by => user)
      # @todo lutter 2014-03-24: We would prefer to rely on the
      # 'current_timestamp()' function in the database for this;
      # unfortunately, there doesn't seem to be a way to do this for the
      # +finished_at+ timestamp later on, exposing us to the danger that
      # +submitted_at > finished_at+. Having to choose between correctness
      # and consistency, we choose consistency
      cmd.submitted_at = DateTime.now
      cmd
    end
  end
end
