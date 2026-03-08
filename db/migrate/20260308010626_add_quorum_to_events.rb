class AddQuorumToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :quorum, :integer
  end
end
