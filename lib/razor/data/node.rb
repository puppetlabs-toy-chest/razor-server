class Razor::Data::Node < Sequel::Model
  plugin :serialization, :json, :facts

  many_to_one :active_model

  def boot
    ActiveModel.boot(self)
  end

  # This is a hack around the fact that the auto_validates plugin does
  # not play nice with the JSON serialization plugin (the serializaton
  # happens in the before_save hook, which runs after validation)
  #
  # To avoid spurious error messages, we tell the validation machinery to
  # expect a Hash resp. an Array
  # FIXME: Figure out a way to address this issue upstream
  def schema_type_class(k)
    if k == :facts
      Hash
    elsif k == :log
      Array
    else
      super
    end
  end

  def self.checkin(hw_id, body)
    if n = lookup(hw_id)
      if body['facts'] != n.facts
        n.facts = body['facts']
        n.save
      end
    else
      n = create(:hw_id => hw_id, :facts => body['facts'])
    end
    # FIXME: determine next action and return it
    { :action => :none }
  end

  def self.lookup(hw_id)
    self[:hw_id => hw_id]
  end
end
