class Razor::Data::Node < Sequel::Model
  plugin :serialization, :json, :facts

  many_to_one :active_model

  def boot
    ActiveModel.boot(self)
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
