class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :set_uuid_primary_key

  private

  def set_uuid_primary_key
    pk_col = self.class.columns_hash[self.class.primary_key.to_s]
    self.id = SecureRandom.uuid if id.blank? && pk_col && !%i[integer bigint].include?(pk_col.type)
  end
end
