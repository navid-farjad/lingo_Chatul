class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words do |t|
      t.references :language, null: false, foreign_key: true
      t.string :native, null: false
      t.string :romanization
      t.string :english, null: false
      t.string :part_of_speech
      t.text :notes
      t.timestamps
    end

    add_index :words, [:language_id, :native], unique: true
  end
end
