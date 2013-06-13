class ActiveModel < Sequel::Model
  def boot(node)
  end

  def self.boot(node)
    if node.active_model
      node.active_model.boot(node)
    else
      # Boot MK
    end
  end
end
