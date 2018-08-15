class CreateShoppingMemos < ActiveRecord::Migration[5.2]
  def change
    create_table :shopping_memos do |t|
      t.string :thing, null: false
      t.string :line_id, null: false
      t.boolean :alive, null: false, default: true

      t.timestamps
    end
  end
end
