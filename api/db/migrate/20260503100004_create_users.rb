class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :device_token, null: false
      t.string :tier, null: false, default: "anonymous"
      t.string :name
      t.timestamps
    end

    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, :device_token, unique: true
  end
end
