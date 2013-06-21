module Razor::Data
  class Image < Sequel::Model
    one_to_many :policies
  end
end
