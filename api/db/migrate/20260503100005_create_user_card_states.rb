class CreateUserCardStates < ActiveRecord::Migration[8.1]
  def change
    create_table :user_card_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :leitner_box, null: false, default: 1
      t.integer :correct_count, null: false, default: 0
      t.integer :incorrect_count, null: false, default: 0
      t.datetime :next_review_at
      t.datetime :last_reviewed_at
      t.timestamps
    end

    add_index :user_card_states, [:user_id, :card_id], unique: true
    add_index :user_card_states, [:user_id, :next_review_at]
  end
end
