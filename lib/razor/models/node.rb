class Razor::Models::Node < Sequel::Model

  many_to_one :active_model

  def boot
    ActiveModel.boot(self)
  end

  def self.checkin(id, facts)
    # create Node[id] if it doesn't exist
    # update facts
    # determine next action and return it
  end

  def self.lookup(hw_id)
    self[:hw_id => hw_id]
  end
end
