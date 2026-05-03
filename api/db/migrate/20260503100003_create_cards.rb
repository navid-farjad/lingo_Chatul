class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :word, null: false, foreign_key: true, index: { unique: true }
      t.text :story_text
      t.string :image_url
      t.string :audio_url
      t.jsonb :generation_metadata, null: false, default: {}
      t.datetime :generated_at
      t.timestamps
    end
  end
end
