class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :languages, :code, unique: true
  end
end
