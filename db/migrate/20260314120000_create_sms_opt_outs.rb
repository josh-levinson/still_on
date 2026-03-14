class CreateSmsOptOuts < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_opt_outs, id: :uuid do |t|
      t.string :phone_number, null: false
      t.timestamps
    end
    add_index :sms_opt_outs, :phone_number, unique: true
  end
end
