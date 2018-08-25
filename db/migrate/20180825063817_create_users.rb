class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.boolean :amazon, default: true, null: false
      t.string :line_id, null: false

      t.timestamps
    end
  end
end
