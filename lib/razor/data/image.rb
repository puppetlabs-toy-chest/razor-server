module Razor::Data
  class Image < Sequel::Model
    # The only columns that may be set through "mass assignment", which is
    # typically through the constructor.  Only enforced at the Ruby layer, but
    # since we direct everything through the model that is acceptable.
    set_allowed_columns :name, :image_url
  end
end
